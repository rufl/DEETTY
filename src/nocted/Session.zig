const std = @import("std");
const document = @import("Document.zig");

pub const max_recent_projects: usize = 8;
pub const max_open_files: usize = 32;
pub const max_path_bytes: usize = 4096;
pub const max_display_name_bytes: usize = 1024;
pub const max_state_bytes: usize = 48 * 1024 * 1024;

comptime {
    const dirty_payload_bytes = max_open_files *
        std.base64.standard.Encoder.calcSize(document.editable_byte_limit);
    std.debug.assert(max_state_bytes > dirty_payload_bytes);
}

pub const TabInput = struct {
    path: ?[]const u8,
    display_name: []const u8,
    contents: ?[]const u8 = null,
};

pub const Tab = struct {
    path: ?[]u8,
    display_name: []u8,
    contents: ?[]u8,

    pub fn deinit(self: *Tab, allocator: std.mem.Allocator) void {
        if (self.path) |value| allocator.free(value);
        allocator.free(self.display_name);
        if (self.contents) |value| allocator.free(value);
        self.* = undefined;
    }

    pub fn modified(self: *const Tab) bool {
        return self.contents != null;
    }
};

pub const State = struct {
    recent_projects: std.array_list.Managed([]u8),
    project: ?[]u8 = null,
    tabs: std.array_list.Managed(Tab),
    active_tab: ?usize = null,

    pub fn init(allocator: std.mem.Allocator) State {
        return .{
            .recent_projects = std.array_list.Managed([]u8).init(allocator),
            .tabs = std.array_list.Managed(Tab).init(allocator),
        };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        clearPaths(allocator, &self.recent_projects);
        clearTabs(allocator, &self.tabs);
        if (self.project) |value| allocator.free(value);
        self.recent_projects.deinit();
        self.tabs.deinit();
        self.* = undefined;
    }

    pub fn rememberProject(
        self: *State,
        allocator: std.mem.Allocator,
        project: []const u8,
    ) !void {
        try validatePath(project);
        var existing_index: ?usize = null;
        for (self.recent_projects.items, 0..) |existing, index| {
            if (std.mem.eql(u8, existing, project)) existing_index = index;
        }
        if (existing_index) |index| allocator.free(self.recent_projects.orderedRemove(index));
        try self.recent_projects.insert(0, try allocator.dupe(u8, project));
        while (self.recent_projects.items.len > max_recent_projects)
            allocator.free(self.recent_projects.pop().?);
    }

    pub fn clearRecentProjects(
        self: *State,
        allocator: std.mem.Allocator,
    ) void {
        clearPaths(allocator, &self.recent_projects);
    }

    pub fn setSession(
        self: *State,
        allocator: std.mem.Allocator,
        project: ?[]const u8,
        tabs: []const TabInput,
        active_tab: ?usize,
    ) !void {
        if (tabs.len > max_open_files) return error.TooManyOpenFiles;
        if (project) |value| try validatePath(value);
        if (active_tab) |index| {
            if (index >= tabs.len) return error.ActiveTabNotOpen;
        }
        for (tabs, 0..) |tab, index| {
            try validateTabInput(tab);
            if (tab.path) |path| {
                for (tabs[0..index]) |previous| {
                    if (previous.path) |previous_path| {
                        if (std.mem.eql(u8, path, previous_path))
                            return error.DuplicateOpenFile;
                    }
                }
            }
        }

        const new_project = if (project) |value| try allocator.dupe(u8, value) else null;
        errdefer if (new_project) |value| allocator.free(value);
        var new_tabs = std.array_list.Managed(Tab).init(allocator);
        errdefer {
            clearTabs(allocator, &new_tabs);
            new_tabs.deinit();
        }
        for (tabs) |tab| try new_tabs.append(try cloneTab(allocator, tab));

        if (self.project) |value| allocator.free(value);
        clearTabs(allocator, &self.tabs);
        self.tabs.deinit();
        self.project = new_project;
        self.tabs = new_tabs;
        self.active_tab = active_tab;
    }
};

pub fn loadAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
) !State {
    const bytes = std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(max_state_bytes + 1),
    ) catch |err| switch (err) {
        error.FileNotFound, error.StreamTooLong => return State.init(allocator),
        else => return err,
    };
    defer allocator.free(bytes);
    return parseAlloc(allocator, bytes) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => State.init(allocator),
    };
}

pub fn save(io: std.Io, path: []const u8, state: *const State) !void {
    var output: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    defer output.deinit();
    try output.writer.writeAll("version=2\n");
    if (state.project) |value| try output.writer.print("project={s}\n", .{value});
    if (state.active_tab) |value| try output.writer.print("active={d}\n", .{value});
    for (state.recent_projects.items) |value|
        try output.writer.print("recent={s}\n", .{value});
    for (state.tabs.items) |tab| {
        try output.writer.writeAll(if (tab.modified()) "tab=1\t" else "tab=0\t");
        if (tab.path) |value| try output.writer.printBase64(value);
        try output.writer.writeByte('\t');
        try output.writer.printBase64(tab.display_name);
        try output.writer.writeByte('\t');
        if (tab.contents) |value| try output.writer.printBase64(value);
        try output.writer.writeByte('\n');
        if (output.writer.buffered().len > max_state_bytes)
            return error.SessionStateTooLarge;
    }
    var atomic = try std.Io.Dir.cwd().createFileAtomic(io, path, .{
        .permissions = @enumFromInt(0o600),
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, output.writer.buffered());
    try atomic.replace(io);
}

fn parseAlloc(allocator: std.mem.Allocator, bytes: []const u8) !State {
    if (bytes.len > max_state_bytes) return error.SessionStateTooLarge;
    var state = State.init(allocator);
    errdefer state.deinit(allocator);
    var version: ?u8 = null;
    var active_seen = false;
    var legacy_active: ?[]u8 = null;
    defer if (legacy_active) |value| allocator.free(value);
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, "\r");
        if (line.len == 0) continue;
        const separator = std.mem.indexOfScalar(u8, line, '=') orelse
            return error.InvalidSessionState;
        const key = line[0..separator];
        const value = line[separator + 1 ..];
        if (std.mem.eql(u8, key, "version")) {
            if (version != null) return error.DuplicateSessionField;
            version = if (std.mem.eql(u8, value, "1"))
                1
            else if (std.mem.eql(u8, value, "2"))
                2
            else
                return error.UnsupportedSessionVersion;
            continue;
        }
        const current_version = version orelse return error.InvalidSessionState;
        if (std.mem.eql(u8, key, "project")) {
            try setOptionalPath(allocator, &state.project, value);
        } else if (std.mem.eql(u8, key, "recent")) {
            if (state.recent_projects.items.len >= max_recent_projects)
                return error.TooManyRecentProjects;
            try validatePath(value);
            if (containsPath(state.recent_projects.items, value))
                return error.DuplicateRecentProject;
            try state.recent_projects.append(try allocator.dupe(u8, value));
        } else switch (current_version) {
            1 => {
                if (std.mem.eql(u8, key, "active")) {
                    if (legacy_active != null) return error.DuplicateSessionField;
                    try validatePath(value);
                    legacy_active = try allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, key, "open")) {
                    try appendLegacyTab(allocator, &state.tabs, value);
                } else {
                    return error.InvalidSessionState;
                }
            },
            2 => {
                if (std.mem.eql(u8, key, "active")) {
                    if (active_seen) return error.DuplicateSessionField;
                    active_seen = true;
                    state.active_tab = try std.fmt.parseUnsigned(usize, value, 10);
                } else if (std.mem.eql(u8, key, "tab")) {
                    if (state.tabs.items.len >= max_open_files)
                        return error.TooManyOpenFiles;
                    const tab = try parseTabAlloc(allocator, value);
                    errdefer {
                        var owned = tab;
                        owned.deinit(allocator);
                    }
                    if (tab.path) |path| {
                        if (containsTabPath(state.tabs.items, path))
                            return error.DuplicateOpenFile;
                    }
                    try state.tabs.append(tab);
                } else {
                    return error.InvalidSessionState;
                }
            },
            else => unreachable,
        }
    }
    const current_version = version orelse return error.InvalidSessionState;
    if (current_version == 1) {
        if (legacy_active) |active| {
            state.active_tab = findTabPath(state.tabs.items, active) orelse
                return error.ActiveTabNotOpen;
        }
    } else if (state.active_tab) |index| {
        if (index >= state.tabs.items.len) return error.ActiveTabNotOpen;
    }
    return state;
}

fn parseTabAlloc(allocator: std.mem.Allocator, value: []const u8) !Tab {
    var fields = std.mem.splitScalar(u8, value, '\t');
    const modified_text = fields.next() orelse return error.InvalidSessionTab;
    const encoded_path = fields.next() orelse return error.InvalidSessionTab;
    const encoded_name = fields.next() orelse return error.InvalidSessionTab;
    const encoded_contents = fields.next() orelse return error.InvalidSessionTab;
    if (fields.next() != null) return error.InvalidSessionTab;
    const modified = if (std.mem.eql(u8, modified_text, "1"))
        true
    else if (std.mem.eql(u8, modified_text, "0"))
        false
    else
        return error.InvalidSessionTab;
    const path = if (encoded_path.len == 0)
        null
    else
        try decodeBase64Alloc(allocator, encoded_path);
    errdefer if (path) |owned| allocator.free(owned);
    const display_name = try decodeBase64Alloc(allocator, encoded_name);
    errdefer allocator.free(display_name);
    const contents = if (modified)
        try decodeBase64Alloc(allocator, encoded_contents)
    else blk: {
        if (encoded_contents.len != 0) return error.InvalidSessionTab;
        break :blk null;
    };
    errdefer if (contents) |owned| allocator.free(owned);
    const tab = Tab{
        .path = path,
        .display_name = display_name,
        .contents = contents,
    };
    try validateTabInput(.{
        .path = tab.path,
        .display_name = tab.display_name,
        .contents = tab.contents,
    });
    return tab;
}

fn appendLegacyTab(
    allocator: std.mem.Allocator,
    tabs: *std.array_list.Managed(Tab),
    path: []const u8,
) !void {
    if (tabs.items.len >= max_open_files) return error.TooManyOpenFiles;
    try validatePath(path);
    if (containsTabPath(tabs.items, path)) return error.DuplicateOpenFile;
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);
    const display_name = try allocator.dupe(u8, std.fs.path.basename(path));
    errdefer allocator.free(display_name);
    try validateDisplayName(display_name);
    try tabs.append(.{
        .path = owned_path,
        .display_name = display_name,
        .contents = null,
    });
}

fn cloneTab(allocator: std.mem.Allocator, input: TabInput) !Tab {
    const path = if (input.path) |value| try allocator.dupe(u8, value) else null;
    errdefer if (path) |value| allocator.free(value);
    const display_name = try allocator.dupe(u8, input.display_name);
    errdefer allocator.free(display_name);
    const contents = if (input.contents) |value| try allocator.dupe(u8, value) else null;
    errdefer if (contents) |value| allocator.free(value);
    return .{
        .path = path,
        .display_name = display_name,
        .contents = contents,
    };
}

fn decodeBase64Alloc(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const size = try std.base64.standard.Decoder.calcSizeForSlice(encoded);
    const decoded = try allocator.alloc(u8, size);
    errdefer allocator.free(decoded);
    try std.base64.standard.Decoder.decode(decoded, encoded);
    return decoded;
}

fn validateTabInput(tab: TabInput) !void {
    if (tab.path) |value| try validatePath(value);
    try validateDisplayName(tab.display_name);
    if (tab.contents) |value| {
        if (value.len > document.editable_byte_limit)
            return error.SessionDocumentTooLarge;
        if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidSessionContents;
        if (std.mem.indexOfScalar(u8, value, 0) != null)
            return error.InvalidSessionContents;
    }
}

fn validateDisplayName(value: []const u8) !void {
    if (value.len == 0 or value.len > max_display_name_bytes or
        !std.unicode.utf8ValidateSlice(value) or
        std.mem.indexOfAny(u8, value, "\x00\r\n") != null)
        return error.InvalidSessionDisplayName;
}

fn validatePath(path: []const u8) !void {
    if (path.len == 0 or path.len > max_path_bytes or
        !std.fs.path.isAbsolute(path) or
        !std.unicode.utf8ValidateSlice(path) or
        std.mem.indexOfAny(u8, path, "\x00\r\n") != null)
        return error.InvalidSessionPath;
}

fn setOptionalPath(
    allocator: std.mem.Allocator,
    target: *?[]u8,
    value: []const u8,
) !void {
    if (target.* != null) return error.DuplicateSessionField;
    try validatePath(value);
    target.* = try allocator.dupe(u8, value);
}

fn containsPath(values: []const []u8, needle: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, needle)) return true;
    return false;
}

fn containsTabPath(tabs: []const Tab, needle: []const u8) bool {
    return findTabPath(tabs, needle) != null;
}

fn findTabPath(tabs: []const Tab, needle: []const u8) ?usize {
    for (tabs, 0..) |tab, index| {
        const path = tab.path orelse continue;
        if (std.mem.eql(u8, path, needle)) return index;
    }
    return null;
}

fn clearPaths(
    allocator: std.mem.Allocator,
    list: *std.array_list.Managed([]u8),
) void {
    for (list.items) |value| allocator.free(value);
    list.clearRetainingCapacity();
}

fn clearTabs(
    allocator: std.mem.Allocator,
    tabs: *std.array_list.Managed(Tab),
) void {
    for (tabs.items) |*tab| tab.deinit(allocator);
    tabs.clearRetainingCapacity();
}

test "recent projects are unique most-recent-first and bounded" {
    var state = State.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);
    for (0..max_recent_projects + 3) |index| {
        var buffer: [64]u8 = undefined;
        const path = try std.fmt.bufPrint(&buffer, "/tmp/project-{d}", .{index});
        try state.rememberProject(std.testing.allocator, path);
    }
    try std.testing.expectEqual(max_recent_projects, state.recent_projects.items.len);
    try std.testing.expectEqualStrings("/tmp/project-10", state.recent_projects.items[0]);
    try state.rememberProject(std.testing.allocator, "/tmp/project-7");
    try std.testing.expectEqualStrings("/tmp/project-7", state.recent_projects.items[0]);
    try std.testing.expectEqual(max_recent_projects, state.recent_projects.items.len);
}

test "session rejects tabs beyond the hot-exit ownership cap" {
    var state = State.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);
    const tabs: [max_open_files + 1]TabInput = undefined;
    try std.testing.expectError(
        error.TooManyOpenFiles,
        state.setSession(std.testing.allocator, null, &tabs, null),
    );
}

test "session state retains clean and dirty tabs atomically" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "session.conf", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);

    var expected = State.init(allocator);
    defer expected.deinit(allocator);
    try expected.rememberProject(allocator, "/work/two");
    try expected.rememberProject(allocator, "/work/one");
    try expected.setSession(
        allocator,
        "/work/one",
        &.{
            .{ .path = "/work/one/a.zig", .display_name = "a.zig" },
            .{
                .path = "/work/one/b.zig",
                .display_name = "b.zig",
                .contents = "const dirty = true;\n",
            },
            .{ .path = null, .display_name = "Untitled", .contents = "" },
        },
        2,
    );
    try save(io, path, &expected);

    var actual = try loadAlloc(allocator, io, path);
    defer actual.deinit(allocator);
    try std.testing.expectEqualStrings("/work/one", actual.project.?);
    try std.testing.expectEqual(@as(usize, 3), actual.tabs.items.len);
    try std.testing.expectEqual(@as(?usize, 2), actual.active_tab);
    try std.testing.expectEqualStrings("const dirty = true;\n", actual.tabs.items[1].contents.?);
    try std.testing.expect(actual.tabs.items[2].path == null);
    try std.testing.expect(actual.tabs.items[2].modified());
    const stat = try std.Io.Dir.cwd().statFile(io, path, .{});
    try std.testing.expectEqual(@as(std.posix.mode_t, 0), stat.permissions.toMode() & 0o077);
}

test "version one saved-file sessions remain readable" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{
        .sub_path = "session.conf",
        .data =
        \\version=1
        \\project=/work
        \\active=/work/b.zig
        \\open=/work/a.zig
        \\open=/work/b.zig
        \\
        ,
    });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);
    var state = try loadAlloc(allocator, io, path);
    defer state.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), state.tabs.items.len);
    try std.testing.expectEqual(@as(?usize, 1), state.active_tab);
    try std.testing.expectEqualStrings("b.zig", state.tabs.items[1].display_name);
    try std.testing.expect(!state.tabs.items[1].modified());
}

test "corrupt session falls back to empty state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{
        .sub_path = "session.conf",
        .data = "version=99\nopen=/tmp/a\n",
    });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);
    var state = try loadAlloc(allocator, io, path);
    defer state.deinit(allocator);
    try std.testing.expect(state.project == null);
    try std.testing.expectEqual(@as(usize, 0), state.tabs.items.len);
}

test "semantic session corruption falls back to empty state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{
        .sub_path = "session.conf",
        .data = "version=2\nactive=2\ntab=0\tL3RtcC9h\tYS56aWc=\t\n",
    });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);
    var state = try loadAlloc(allocator, io, path);
    defer state.deinit(allocator);
    try std.testing.expect(state.active_tab == null);
    try std.testing.expectEqual(@as(usize, 0), state.tabs.items.len);
}

test "malformed and oversized session corpus falls back to empty state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "session.conf", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);

    const malformed = [_][]const u8{
        "version=1\nproject=/tmp/a\nproject=/tmp/b\n",
        "version=1\nopen=/tmp/a\nopen=/tmp/a\n",
        "version=1\nopen=relative\n",
        "version=2\nunknown=/tmp/a\n",
        "version=2\ntab=0\t!\tYQ==\t\n",
        "version=2\ntab=1\t\tYQ==\t/w==\n",
    };
    for (malformed) |contents| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = contents });
        var state = try loadAlloc(allocator, io, path);
        defer state.deinit(allocator);
        try std.testing.expect(state.project == null);
        try std.testing.expect(state.active_tab == null);
        try std.testing.expectEqual(@as(usize, 0), state.recent_projects.items.len);
        try std.testing.expectEqual(@as(usize, 0), state.tabs.items.len);
    }

    const oversized = try allocator.alloc(u8, max_state_bytes + 1);
    defer allocator.free(oversized);
    @memset(oversized, 'x');
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = oversized });
    var state = try loadAlloc(allocator, io, path);
    defer state.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), state.tabs.items.len);
}

test "interrupted session replacement preserves the previous state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "session.conf", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);

    var expected = State.init(allocator);
    defer expected.deinit(allocator);
    try expected.setSession(
        allocator,
        "/work",
        &.{.{
            .path = "/work/a.zig",
            .display_name = "a.zig",
            .contents = "dirty\n",
        }},
        0,
    );
    try save(io, path, &expected);
    {
        var interrupted = try std.Io.Dir.cwd().createFileAtomic(io, path, .{
            .make_path = true,
            .replace = true,
        });
        defer interrupted.deinit(io);
        try interrupted.file.writeStreamingAll(io, "version=2\ntab=broken\n");
    }

    var actual = try loadAlloc(allocator, io, path);
    defer actual.deinit(allocator);
    try std.testing.expectEqualStrings("/work", actual.project.?);
    try std.testing.expectEqual(@as(?usize, 0), actual.active_tab);
    try std.testing.expectEqualStrings("dirty\n", actual.tabs.items[0].contents.?);
}
