const std = @import("std");

pub const max_recent_workspaces: usize = 8;
pub const max_workspace_path_bytes: usize = 4096;

pub const WorkspacePath = struct {
    bytes: [max_workspace_path_bytes]u8 = undefined,
    len: u16 = 0,

    pub fn init(path: []const u8) !WorkspacePath {
        var result = WorkspacePath{};
        try result.set(path);
        return result;
    }

    pub fn set(self: *WorkspacePath, path: []const u8) !void {
        try validateWorkspacePath(path);
        @memcpy(self.bytes[0..path.len], path);
        self.len = @intCast(path.len);
    }

    pub fn slice(self: *const WorkspacePath) []const u8 {
        return self.bytes[0..self.len];
    }
};

pub const RecentWorkspaces = struct {
    entries: [max_recent_workspaces]WorkspacePath = [_]WorkspacePath{.{}} ** max_recent_workspaces,
    count: u8 = 0,

    pub fn validate(self: RecentWorkspaces) !void {
        if (self.count > max_recent_workspaces) return error.InvalidRecentWorkspaceLibrary;
        for (self.entries[0..self.count], 0..) |*entry, index| {
            try validateWorkspacePath(entry.slice());
            for (self.entries[0..index]) |*prior| {
                if (std.mem.eql(u8, prior.slice(), entry.slice()))
                    return error.DuplicateRecentWorkspace;
            }
        }
    }

    pub fn record(self: *RecentWorkspaces, path: []const u8) !void {
        const candidate = try WorkspacePath.init(path);
        var existing: ?usize = null;
        for (self.entries[0..self.count], 0..) |*entry, index| {
            if (std.mem.eql(u8, entry.slice(), candidate.slice())) {
                existing = index;
                break;
            }
        }

        const shift_count: usize = existing orelse @min(
            @as(usize, self.count),
            max_recent_workspaces - 1,
        );
        var index = shift_count;
        while (index > 0) : (index -= 1) self.entries[index] = self.entries[index - 1];
        self.entries[0] = candidate;
        if (existing == null and self.count < max_recent_workspaces) self.count += 1;
        try self.validate();
    }

    pub fn at(self: *const RecentWorkspaces, index: usize) ?[]const u8 {
        if (index >= self.count) return null;
        return self.entries[index].slice();
    }
};

pub fn validateWorkspacePath(path: []const u8) !void {
    if (path.len == 0 or path.len > max_workspace_path_bytes)
        return error.InvalidWorkspacePath;
    if (!std.fs.path.isAbsolute(path)) return error.WorkspacePathMustBeAbsolute;
    if (path.len > 1 and path[1] == '/') return error.WorkspaceNetworkPathForbidden;
    if (!std.unicode.utf8ValidateSlice(path)) return error.InvalidWorkspacePathEncoding;
    if (!std.mem.endsWith(u8, path, ".nocttyws")) return error.InvalidWorkspacePathExtension;
    for (path) |byte| {
        if (byte == 0 or byte < 0x20 or byte == 0x7f)
            return error.InvalidWorkspacePathControl;
    }
}

pub fn parseWorkspaceUri(uri: []const u8) !WorkspacePath {
    const encoded = if (std.mem.startsWith(u8, uri, "noctty://"))
        uri["noctty://".len..]
    else if (std.mem.startsWith(u8, uri, "file://"))
        uri["file://".len..]
    else
        return error.UnsupportedWorkspaceUriScheme;

    if (encoded.len == 0 or encoded[0] != '/') return error.WorkspaceUriAuthorityForbidden;
    if (std.mem.indexOfAny(u8, encoded, "?#") != null) return error.WorkspaceUriSuffixForbidden;
    if (encoded.len > max_workspace_path_bytes * 3) return error.WorkspaceUriTooLong;

    var decoded: [max_workspace_path_bytes]u8 = undefined;
    var read_index: usize = 0;
    var write_index: usize = 0;
    while (read_index < encoded.len) {
        if (write_index >= decoded.len) return error.WorkspaceUriTooLong;
        const byte = encoded[read_index];
        if (byte == '%') {
            if (read_index + 2 >= encoded.len) return error.InvalidWorkspaceUriEscape;
            decoded[write_index] = (try hexNibble(encoded[read_index + 1])) << 4 |
                try hexNibble(encoded[read_index + 2]);
            read_index += 3;
        } else {
            if (byte == ' ') return error.UnescapedWorkspaceUriSpace;
            decoded[write_index] = byte;
            read_index += 1;
        }
        write_index += 1;
    }
    return WorkspacePath.init(decoded[0..write_index]);
}

fn hexNibble(byte: u8) !u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        'A'...'F' => byte - 'A' + 10,
        else => error.InvalidWorkspaceUriEscape,
    };
}

test "workspace URI activation accepts only bounded local snapshot paths" {
    const noctty = try parseWorkspaceUri("noctty:///tmp/Release%20Ops.nocttyws");
    try std.testing.expectEqualStrings("/tmp/Release Ops.nocttyws", noctty.slice());
    const file = try parseWorkspaceUri("file:///home/alice/project.nocttyws");
    try std.testing.expectEqualStrings("/home/alice/project.nocttyws", file.slice());

    try std.testing.expectError(error.UnsupportedWorkspaceUriScheme, parseWorkspaceUri("https:///tmp/project.nocttyws"));
    try std.testing.expectError(error.WorkspaceUriAuthorityForbidden, parseWorkspaceUri("file://host/tmp/project.nocttyws"));
    try std.testing.expectError(error.WorkspaceNetworkPathForbidden, parseWorkspaceUri("file:////host/project.nocttyws"));
    try std.testing.expectError(error.WorkspaceUriSuffixForbidden, parseWorkspaceUri("noctty:///tmp/project.nocttyws?mode=replace"));
    try std.testing.expectError(error.WorkspaceUriSuffixForbidden, parseWorkspaceUri("noctty:///tmp/project.nocttyws#tab-1"));
    try std.testing.expectError(error.InvalidWorkspaceUriEscape, parseWorkspaceUri("noctty:///tmp/%zz.nocttyws"));
    try std.testing.expectError(error.InvalidWorkspacePathControl, parseWorkspaceUri("noctty:///tmp/a%00.nocttyws"));
    try std.testing.expectError(error.UnescapedWorkspaceUriSpace, parseWorkspaceUri("noctty:///tmp/a b.nocttyws"));
    try std.testing.expectError(error.InvalidWorkspacePathExtension, parseWorkspaceUri("noctty:///tmp/project.json"));
}

test "recent workspaces are a fixed deduplicating most-recent-first library" {
    var recent = RecentWorkspaces{};
    for (0..max_recent_workspaces + 2) |index| {
        var buffer: [96]u8 = undefined;
        const path = try std.fmt.bufPrint(&buffer, "/tmp/workspace-{d}.nocttyws", .{index});
        try recent.record(path);
    }
    try std.testing.expectEqual(@as(u8, max_recent_workspaces), recent.count);
    try std.testing.expectEqualStrings("/tmp/workspace-9.nocttyws", recent.at(0).?);
    try std.testing.expectEqualStrings("/tmp/workspace-2.nocttyws", recent.at(7).?);

    try recent.record("/tmp/workspace-5.nocttyws");
    try std.testing.expectEqual(@as(u8, max_recent_workspaces), recent.count);
    try std.testing.expectEqualStrings("/tmp/workspace-5.nocttyws", recent.at(0).?);
    try recent.validate();
}
