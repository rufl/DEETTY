const std = @import("std");

pub const max_import_paths: usize = 16;
pub const max_path_bytes: usize = 4096;
pub const max_state_bytes: usize = 64 * 1024;

pub const Settings = struct {
    syntax_prompt_done: bool = false,
    sidebar_visible: bool = true,
    minimap_visible: bool = true,
    code_folding_enabled: bool = true,
    import_paths: std.array_list.Managed([]u8),

    pub fn init(allocator: std.mem.Allocator) Settings {
        return .{ .import_paths = std.array_list.Managed([]u8).init(allocator) };
    }

    pub fn deinit(self: *Settings, allocator: std.mem.Allocator) void {
        for (self.import_paths.items) |path| allocator.free(path);
        self.import_paths.deinit();
        self.* = undefined;
    }

    pub fn addImportPath(self: *Settings, allocator: std.mem.Allocator, path: []const u8) !bool {
        if (path.len == 0 or path.len > max_path_bytes or
            !std.unicode.utf8ValidateSlice(path) or
            std.mem.indexOfAny(u8, path, "\x00\r\n") != null)
            return error.InvalidSyntaxPath;
        for (self.import_paths.items) |existing| {
            if (std.mem.eql(u8, existing, path)) return false;
        }
        if (self.import_paths.items.len >= max_import_paths)
            return error.TooManySyntaxPaths;
        try self.import_paths.append(try allocator.dupe(u8, path));
        return true;
    }
};

pub fn loadAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
) !Settings {
    const bytes = std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(max_state_bytes + 1),
    ) catch |err| switch (err) {
        error.FileNotFound, error.StreamTooLong => return Settings.init(allocator),
        else => return err,
    };
    defer allocator.free(bytes);
    return parseAlloc(allocator, bytes) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => Settings.init(allocator),
    };
}

fn parseAlloc(allocator: std.mem.Allocator, bytes: []const u8) !Settings {
    if (bytes.len > max_state_bytes) return error.SettingsStateTooLarge;
    var settings = Settings.init(allocator);
    errdefer settings.deinit(allocator);
    var version_seen = false;
    var syntax_prompt_seen = false;
    var sidebar_seen = false;
    var minimap_seen = false;
    var folding_seen = false;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const separator = std.mem.indexOfScalar(u8, line, '=') orelse
            return error.InvalidSettingsState;
        const key = std.mem.trim(u8, line[0..separator], " \t");
        const value = std.mem.trim(u8, line[separator + 1 ..], " \t");
        if (std.mem.eql(u8, key, "version")) {
            if (version_seen or !std.mem.eql(u8, value, "1"))
                return error.UnsupportedSettingsVersion;
            version_seen = true;
        } else if (std.mem.eql(u8, key, "syntax_prompt_done")) {
            if (syntax_prompt_seen) return error.DuplicateSettingsField;
            syntax_prompt_seen = true;
            settings.syntax_prompt_done = try parseBool(value);
        } else if (std.mem.eql(u8, key, "sidebar_visible")) {
            if (sidebar_seen) return error.DuplicateSettingsField;
            sidebar_seen = true;
            settings.sidebar_visible = try parseBool(value);
        } else if (std.mem.eql(u8, key, "minimap_visible")) {
            if (minimap_seen) return error.DuplicateSettingsField;
            minimap_seen = true;
            settings.minimap_visible = try parseBool(value);
        } else if (std.mem.eql(u8, key, "code_folding_enabled")) {
            if (folding_seen) return error.DuplicateSettingsField;
            folding_seen = true;
            settings.code_folding_enabled = try parseBool(value);
        } else if (std.mem.eql(u8, key, "syntax_path")) {
            if (!try settings.addImportPath(allocator, value))
                return error.DuplicateSyntaxPath;
        } else {
            return error.InvalidSettingsState;
        }
    }
    if (!version_seen) return error.InvalidSettingsState;
    return settings;
}

fn parseBool(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return error.InvalidSettingsBoolean;
}

pub fn save(io: std.Io, path: []const u8, settings: *const Settings) !void {
    var output: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    defer output.deinit();
    try output.writer.print(
        "version=1\nsyntax_prompt_done={}\nsidebar_visible={}\nminimap_visible={}\ncode_folding_enabled={}\n",
        .{
            settings.syntax_prompt_done,
            settings.sidebar_visible,
            settings.minimap_visible,
            settings.code_folding_enabled,
        },
    );
    for (settings.import_paths.items) |import_path|
        try output.writer.print("syntax_path={s}\n", .{import_path});
    if (output.writer.buffered().len > max_state_bytes) return error.SettingsStateTooLarge;
    var atomic = try std.Io.Dir.cwd().createFileAtomic(io, path, .{
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, output.writer.buffered());
    try atomic.replace(io);
}

test "settings round trip GUI-owned syntax paths" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "settings.conf", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "settings.conf", allocator);
    defer allocator.free(path);

    var expected = Settings.init(allocator);
    defer expected.deinit(allocator);
    expected.syntax_prompt_done = true;
    expected.sidebar_visible = false;
    expected.code_folding_enabled = false;
    _ = try expected.addImportPath(allocator, "/opt/syntax/language-specs");
    try save(io, path, &expected);

    var actual = try loadAlloc(allocator, io, path);
    defer actual.deinit(allocator);
    try std.testing.expect(actual.syntax_prompt_done);
    try std.testing.expect(!actual.sidebar_visible);
    try std.testing.expect(actual.minimap_visible);
    try std.testing.expect(!actual.code_folding_enabled);
    try std.testing.expectEqual(@as(usize, 1), actual.import_paths.items.len);
    try std.testing.expectEqualStrings(
        "/opt/syntax/language-specs",
        actual.import_paths.items[0],
    );
    try std.testing.expectError(
        error.InvalidSyntaxPath,
        actual.addImportPath(allocator, "/tmp/broken\npath"),
    );
}

test "malformed and oversized settings fall back to defaults" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "settings.conf", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "settings.conf", allocator);
    defer allocator.free(path);

    const malformed = [_][]const u8{
        "version=99\nsidebar_visible=false\n",
        "version=1\nsidebar_visible=maybe\n",
        "version=1\nsidebar_visible=false\nsidebar_visible=true\n",
        "version=1\nsyntax_path=/tmp/ok\nsyntax_path=/tmp/ok\n",
        "version=1\nunknown=value\n",
        "version=1\nsyntax_path=bad\x00path\n",
        "version=1\nsyntax_path=\xff\n",
    };
    for (malformed) |contents| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = contents });
        var settings = try loadAlloc(allocator, io, path);
        defer settings.deinit(allocator);
        try std.testing.expect(!settings.syntax_prompt_done);
        try std.testing.expect(settings.sidebar_visible);
        try std.testing.expect(settings.minimap_visible);
        try std.testing.expect(settings.code_folding_enabled);
        try std.testing.expectEqual(@as(usize, 0), settings.import_paths.items.len);
    }

    const oversized = try allocator.alloc(u8, max_state_bytes + 1);
    defer allocator.free(oversized);
    @memset(oversized, 'x');
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = oversized });
    var settings = try loadAlloc(allocator, io, path);
    defer settings.deinit(allocator);
    try std.testing.expect(settings.sidebar_visible);
    try std.testing.expectEqual(@as(usize, 0), settings.import_paths.items.len);
}

test "interrupted settings replacement preserves the previous state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "settings.conf", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "settings.conf", allocator);
    defer allocator.free(path);

    var expected = Settings.init(allocator);
    defer expected.deinit(allocator);
    expected.sidebar_visible = false;
    try save(io, path, &expected);
    {
        var interrupted = try std.Io.Dir.cwd().createFileAtomic(io, path, .{
            .make_path = true,
            .replace = true,
        });
        defer interrupted.deinit(io);
        try interrupted.file.writeStreamingAll(io, "version=1\nsidebar_visible=true\n");
    }

    var actual = try loadAlloc(allocator, io, path);
    defer actual.deinit(allocator);
    try std.testing.expect(!actual.sidebar_visible);
}
