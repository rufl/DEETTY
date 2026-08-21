const std = @import("std");

pub const max_import_paths: usize = 16;
pub const max_path_bytes: usize = 4096;
pub const max_state_bytes: usize = 64 * 1024;
pub const ui_font_size_pt_default: u8 = 11;
pub const ui_font_size_pt_min: u8 = 8;
pub const ui_font_size_pt_max: u8 = 32;

pub const Settings = struct {
    syntax_prompt_done: bool = false,
    sidebar_visible: bool = true,
    minimap_visible: bool = true,
    code_folding_enabled: bool = true,
    word_wrap_enabled: bool = false,
    ui_font_size_pt: u8 = ui_font_size_pt_default,
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

    pub fn setUiFontSize(self: *Settings, value: u8) !void {
        try validateUiFontSize(value);
        self.ui_font_size_pt = value;
    }
};

pub fn validateUiFontSize(value: u8) !void {
    if (value < ui_font_size_pt_min or value > ui_font_size_pt_max)
        return error.InvalidUiFontSize;
}

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
    var version: ?u8 = null;
    var syntax_prompt_seen = false;
    var sidebar_seen = false;
    var minimap_seen = false;
    var folding_seen = false;
    var word_wrap_seen = false;
    var ui_font_size_seen = false;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const separator = std.mem.indexOfScalar(u8, line, '=') orelse
            return error.InvalidSettingsState;
        const key = std.mem.trim(u8, line[0..separator], " \t");
        const value = std.mem.trim(u8, line[separator + 1 ..], " \t");
        if (std.mem.eql(u8, key, "version")) {
            if (version != null) return error.DuplicateSettingsField;
            version = if (std.mem.eql(u8, value, "1"))
                1
            else if (std.mem.eql(u8, value, "2"))
                2
            else if (std.mem.eql(u8, value, "3"))
                3
            else
                return error.UnsupportedSettingsVersion;
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
        } else if (std.mem.eql(u8, key, "word_wrap_enabled")) {
            if (word_wrap_seen) return error.DuplicateSettingsField;
            word_wrap_seen = true;
            settings.word_wrap_enabled = try parseBool(value);
        } else if (std.mem.eql(u8, key, "editor_font_size_pt")) {
            if (version != 2 or ui_font_size_seen)
                return error.InvalidSettingsState;
            ui_font_size_seen = true;
            try settings.setUiFontSize(try std.fmt.parseUnsigned(u8, value, 10));
        } else if (std.mem.eql(u8, key, "ui_font_size_pt")) {
            if (version != 3 or ui_font_size_seen)
                return error.InvalidSettingsState;
            ui_font_size_seen = true;
            try settings.setUiFontSize(try std.fmt.parseUnsigned(u8, value, 10));
        } else if (std.mem.eql(u8, key, "syntax_path")) {
            if (!try settings.addImportPath(allocator, value))
                return error.DuplicateSyntaxPath;
        } else {
            return error.InvalidSettingsState;
        }
    }
    if (version == null) return error.InvalidSettingsState;
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
        "version=3\nsyntax_prompt_done={}\nsidebar_visible={}\nminimap_visible={}\ncode_folding_enabled={}\nword_wrap_enabled={}\nui_font_size_pt={d}\n",
        .{
            settings.syntax_prompt_done,
            settings.sidebar_visible,
            settings.minimap_visible,
            settings.code_folding_enabled,
            settings.word_wrap_enabled,
            settings.ui_font_size_pt,
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
    expected.word_wrap_enabled = true;
    try expected.setUiFontSize(18);
    _ = try expected.addImportPath(allocator, "/opt/syntax/language-specs");
    try save(io, path, &expected);

    var actual = try loadAlloc(allocator, io, path);
    defer actual.deinit(allocator);
    try std.testing.expect(actual.syntax_prompt_done);
    try std.testing.expect(!actual.sidebar_visible);
    try std.testing.expect(actual.minimap_visible);
    try std.testing.expect(!actual.code_folding_enabled);
    try std.testing.expect(actual.word_wrap_enabled);
    try std.testing.expectEqual(@as(u8, 18), actual.ui_font_size_pt);
    try std.testing.expectEqual(@as(usize, 1), actual.import_paths.items.len);
    try std.testing.expectEqualStrings(
        "/opt/syntax/language-specs",
        actual.import_paths.items[0],
    );
    try std.testing.expectError(
        error.InvalidSyntaxPath,
        actual.addImportPath(allocator, "/tmp/broken\npath"),
    );
    try std.testing.expectError(
        error.InvalidUiFontSize,
        actual.setUiFontSize(ui_font_size_pt_max + 1),
    );
    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = path,
        .data = "version=1\nsidebar_visible=true\n",
    });
    var legacy = try loadAlloc(allocator, io, path);
    defer legacy.deinit(allocator);
    try std.testing.expectEqual(
        ui_font_size_pt_default,
        legacy.ui_font_size_pt,
    );
    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = path,
        .data = "version=2\neditor_font_size_pt=18\n",
    });
    var prior = try loadAlloc(allocator, io, path);
    defer prior.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 18), prior.ui_font_size_pt);
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
        "version=1\nword_wrap_enabled=true\nword_wrap_enabled=false\n",
        "version=1\nsyntax_path=/tmp/ok\nsyntax_path=/tmp/ok\n",
        "version=1\nunknown=value\n",
        "version=1\nsyntax_path=bad\x00path\n",
        "version=1\nsyntax_path=\xff\n",
        "version=1\neditor_font_size_pt=14\n",
        "version=2\nui_font_size_pt=14\n",
        "version=2\neditor_font_size_pt=7\n",
        "version=2\neditor_font_size_pt=33\n",
        "version=2\neditor_font_size_pt=12\neditor_font_size_pt=13\n",
        "version=3\neditor_font_size_pt=14\n",
        "version=3\nui_font_size_pt=7\n",
        "version=3\nui_font_size_pt=33\n",
        "version=3\nui_font_size_pt=12\nui_font_size_pt=13\n",
    };
    for (malformed) |contents| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = contents });
        var settings = try loadAlloc(allocator, io, path);
        defer settings.deinit(allocator);
        try std.testing.expect(!settings.syntax_prompt_done);
        try std.testing.expect(settings.sidebar_visible);
        try std.testing.expect(settings.minimap_visible);
        try std.testing.expect(settings.code_folding_enabled);
        try std.testing.expect(!settings.word_wrap_enabled);
        try std.testing.expectEqual(
            ui_font_size_pt_default,
            settings.ui_font_size_pt,
        );
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
