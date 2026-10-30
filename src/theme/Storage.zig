const std = @import("std");
const ThemeMod = @import("Theme.zig");

const Io = std.Io;
const Dir = std.Io.Dir;

const theme_magic = "NOCTTYTHM";
const theme_version: u8 = 4;
const max_theme_count: usize = 1024;

pub const max_theme_file_bytes: usize = 4 * 1024 * 1024;

pub fn backupPathAlloc(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (path.len == 0) return error.InvalidThemeLibraryPath;
    return std.fmt.allocPrint(allocator, "{s}.bak", .{path});
}

pub fn rejectedPathAlloc(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (path.len == 0) return error.InvalidThemeLibraryPath;
    return std.fmt.allocPrint(allocator, "{s}.rejected", .{path});
}

pub const ThemeFileRole = enum {
    library,
    backup,
};

pub const ThemeFileReceipt = struct {
    path: []u8,
    role: ThemeFileRole,
    bytes: usize,
    theme_count: usize,

    pub fn deinit(self: ThemeFileReceipt, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

pub const ThemeRecord = struct {
    theme: ThemeMod.Theme,
    owned_name: []u8,
};

pub const LoadedThemeLibrary = struct {
    entries: []ThemeRecord,

    pub fn deinit(self: *LoadedThemeLibrary, allocator: std.mem.Allocator) void {
        for (self.entries) |entry| allocator.free(entry.owned_name);
        allocator.free(self.entries);
        self.* = undefined;
    }
};

pub const LoadedThemeLibraryFile = struct {
    loaded: LoadedThemeLibrary,
    receipt: ThemeFileReceipt,

    pub fn deinit(self: *LoadedThemeLibraryFile, allocator: std.mem.Allocator) void {
        self.loaded.deinit(allocator);
        self.receipt.deinit(allocator);
        self.* = undefined;
    }
};

pub fn defaultThemeLibraryPathAlloc(allocator: std.mem.Allocator, home_dir: []const u8) ![]u8 {
    if (home_dir.len == 0) return error.InvalidThemeLibraryPath;
    return std.fs.path.join(allocator, &.{
        home_dir,
        ".config",
        "noctty",
        "themes.nocttythemes",
    });
}

pub fn exportThemeLibraryAlloc(allocator: std.mem.Allocator, themes: []const ThemeMod.Theme) ![]u8 {
    try validateThemeLibrary(themes);
    var writer = ThemeWriter.init(allocator);
    errdefer writer.deinit();

    try writer.bytes.appendSlice(theme_magic);
    try writer.writeU8(theme_version);
    try writer.writeU64(themes.len);
    for (themes) |theme| {
        try writer.writeTheme(theme);
    }

    return writer.bytes.toOwnedSlice();
}

pub fn importThemeLibraryAlloc(allocator: std.mem.Allocator, bytes: []const u8) !LoadedThemeLibrary {
    var reader = ThemeReader{
        .allocator = allocator,
        .bytes = bytes,
    };
    try reader.expectMagic();
    const version = try reader.readU8();
    if (version == 0 or version > theme_version) return error.UnsupportedThemeLibrarySnapshot;
    reader.version = version;

    const count = try reader.readU64AsUsize();
    if (count == 0) return error.EmptyThemeLibrary;
    if (count > max_theme_count) return error.ThemeLibraryTooLarge;

    const entries = try allocator.alloc(ThemeRecord, count);
    var initialized: usize = 0;
    errdefer {
        for (entries[0..initialized]) |entry| allocator.free(entry.owned_name);
        allocator.free(entries);
    }

    while (initialized < count) : (initialized += 1) {
        entries[initialized] = try reader.readThemeRecord();
        for (entries[0..initialized]) |previous| {
            if (std.mem.eql(u8, previous.theme.name, entries[initialized].theme.name)) {
                allocator.free(entries[initialized].owned_name);
                return error.DuplicateThemeName;
            }
        }
    }

    if (!reader.finished()) return error.InvalidThemeLibrarySnapshot;
    return .{ .entries = entries };
}

pub fn saveThemeLibraryFile(
    allocator: std.mem.Allocator,
    io: Io,
    dir: Dir,
    path: []const u8,
    themes: []const ThemeMod.Theme,
    role: ThemeFileRole,
) !ThemeFileReceipt {
    if (path.len == 0) return error.InvalidThemeLibraryPath;

    const bytes = try exportThemeLibraryAlloc(allocator, themes);
    defer allocator.free(bytes);

    if (role == .library) try backupValidThemeLibraryFile(allocator, io, dir, path);
    try replaceFileAtomic(io, dir, path, bytes);

    return .{
        .path = try allocator.dupe(u8, path),
        .role = role,
        .bytes = bytes.len,
        .theme_count = themes.len,
    };
}

fn backupValidThemeLibraryFile(
    allocator: std.mem.Allocator,
    io: Io,
    dir: Dir,
    path: []const u8,
) !void {
    const existing = dir.readFileAlloc(
        io,
        path,
        allocator,
        .limited(max_theme_file_bytes),
    ) catch |err| switch (err) {
        error.FileNotFound => return,
        error.StreamTooLong => {
            const rejected_path = try rejectedPathAlloc(allocator, path);
            defer allocator.free(rejected_path);
            try dir.rename(path, dir, rejected_path, io);
            return;
        },
        else => return err,
    };
    defer allocator.free(existing);

    var validated = importThemeLibraryAlloc(allocator, existing) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            const rejected_path = try rejectedPathAlloc(allocator, path);
            defer allocator.free(rejected_path);
            try replaceFileAtomic(io, dir, rejected_path, existing);
            return;
        },
    };
    validated.deinit(allocator);

    const backup_path = try backupPathAlloc(allocator, path);
    defer allocator.free(backup_path);
    try replaceFileAtomic(io, dir, backup_path, existing);
}

fn replaceFileAtomic(io: Io, dir: Dir, path: []const u8, bytes: []const u8) !void {
    var atomic = try dir.createFileAtomic(io, path, .{
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, bytes);
    try atomic.replace(io);
}

pub fn loadThemeLibraryFile(
    allocator: std.mem.Allocator,
    io: Io,
    dir: Dir,
    path: []const u8,
    role: ThemeFileRole,
) !LoadedThemeLibraryFile {
    if (path.len == 0) return error.InvalidThemeLibraryPath;

    const bytes = try dir.readFileAlloc(io, path, allocator, .limited(max_theme_file_bytes));
    defer allocator.free(bytes);

    var loaded = try importThemeLibraryAlloc(allocator, bytes);
    errdefer loaded.deinit(allocator);
    return .{
        .loaded = loaded,
        .receipt = .{
            .path = try allocator.dupe(u8, path),
            .role = role,
            .bytes = bytes.len,
            .theme_count = loaded.entries.len,
        },
    };
}

fn validateThemeLibrary(themes: []const ThemeMod.Theme) !void {
    if (themes.len == 0) return error.EmptyThemeLibrary;
    if (themes.len > max_theme_count) return error.ThemeLibraryTooLarge;
    for (themes, 0..) |theme, idx| {
        try ThemeMod.validateName(theme.name);
        var previous: usize = 0;
        while (previous < idx) : (previous += 1) {
            if (std.mem.eql(u8, themes[previous].name, theme.name)) return error.DuplicateThemeName;
        }
    }
}

const ThemeWriter = struct {
    bytes: std.array_list.Managed(u8),

    fn init(allocator: std.mem.Allocator) ThemeWriter {
        return .{ .bytes = std.array_list.Managed(u8).init(allocator) };
    }

    fn deinit(self: *ThemeWriter) void {
        self.bytes.deinit();
    }

    fn writeTheme(self: *ThemeWriter, theme: ThemeMod.Theme) !void {
        try self.writeString(theme.name);
        try self.writeColor(theme.foreground);
        try self.writeColor(theme.background);
        try self.writeColor(theme.cursor);
        for (theme.palette) |color| try self.writeColor(color);
        for (theme.chrome) |color| try self.writeColor(color);
    }

    fn writeString(self: *ThemeWriter, value: []const u8) !void {
        try self.writeU64(value.len);
        try self.bytes.appendSlice(value);
    }

    fn writeColor(self: *ThemeWriter, color: ThemeMod.Color) !void {
        try self.writeU8(color.r);
        try self.writeU8(color.g);
        try self.writeU8(color.b);
        try self.writeU8(color.a);
    }

    fn writeU8(self: *ThemeWriter, value: u8) !void {
        try self.bytes.append(value);
    }

    fn writeU64(self: *ThemeWriter, value: anytype) !void {
        try self.writeIntLittle(@as(u64, @intCast(value)), 8);
    }

    fn writeIntLittle(self: *ThemeWriter, value: u64, comptime byte_count: usize) !void {
        var idx: usize = 0;
        while (idx < byte_count) : (idx += 1) {
            const shift: u6 = @intCast(idx * 8);
            try self.bytes.append(@intCast((value >> shift) & 0xff));
        }
    }
};

const ThemeReader = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    offset: usize = 0,
    version: u8 = 0,

    fn expectMagic(self: *ThemeReader) !void {
        if (self.bytes.len < theme_magic.len) return error.InvalidThemeLibrarySnapshot;
        if (!std.mem.eql(u8, self.bytes[0..theme_magic.len], theme_magic)) return error.InvalidThemeLibrarySnapshot;
        self.offset = theme_magic.len;
    }

    fn finished(self: ThemeReader) bool {
        return self.offset == self.bytes.len;
    }

    fn readThemeRecord(self: *ThemeReader) !ThemeRecord {
        const name = try self.readStringAlloc();
        errdefer self.allocator.free(name);
        try ThemeMod.validateName(name);

        const foreground = try self.readColor();
        const background = try self.readColor();
        const cursor = try self.readColor();
        var palette: [16]ThemeMod.Color = undefined;
        for (&palette) |*color| color.* = try self.readColor();
        var chrome = ThemeMod.Theme.builtinDark().chrome;
        const cursor_index = @backingInt(ThemeMod.ChromeColor.terminal_cursor);
        if (self.version >= 2) {
            for (chrome[0..cursor_index]) |*color| color.* = try self.readColor();
            if (self.version >= 3) chrome[cursor_index] = try self.readColor();
            if (self.version >= 4) {
                chrome[@backingInt(ThemeMod.ChromeColor.pane_gap)] =
                    try self.readColor();
            }
        } else {
            chrome[@backingInt(ThemeMod.ChromeColor.workspace_background)] = background;
            chrome[@backingInt(ThemeMod.ChromeColor.overlay_background)] = background;
            chrome[@backingInt(ThemeMod.ChromeColor.overlay_foreground)] = foreground;
        }
        if (self.version < 3) chrome[cursor_index] = cursor;
        if (self.version < 4) {
            chrome[@backingInt(ThemeMod.ChromeColor.pane_gap)] = background;
        }

        return .{
            .theme = .{
                .name = name,
                .foreground = foreground,
                .background = background,
                .cursor = cursor,
                .palette = palette,
                .chrome = chrome,
            },
            .owned_name = name,
        };
    }

    fn readStringAlloc(self: *ThemeReader) ![]u8 {
        const len = try self.readU64AsUsize();
        if (len > self.bytes.len - self.offset) return error.InvalidThemeLibrarySnapshot;
        const slice = self.bytes[self.offset .. self.offset + len];
        self.offset += len;
        return self.allocator.dupe(u8, slice);
    }

    fn readColor(self: *ThemeReader) !ThemeMod.Color {
        return .{
            .r = try self.readU8(),
            .g = try self.readU8(),
            .b = try self.readU8(),
            .a = try self.readU8(),
        };
    }

    fn readU8(self: *ThemeReader) !u8 {
        if (self.offset >= self.bytes.len) return error.InvalidThemeLibrarySnapshot;
        const value = self.bytes[self.offset];
        self.offset += 1;
        return value;
    }

    fn readU64AsUsize(self: *ThemeReader) !usize {
        const value = try self.readIntLittle(8);
        if (value > std.math.maxInt(usize)) return error.InvalidThemeLibrarySnapshot;
        return @intCast(value);
    }

    fn readIntLittle(self: *ThemeReader, comptime byte_count: usize) !u64 {
        if (byte_count > self.bytes.len - self.offset) return error.InvalidThemeLibrarySnapshot;
        var value: u64 = 0;
        var idx: usize = 0;
        while (idx < byte_count) : (idx += 1) {
            const shift: u6 = @intCast(idx * 8);
            value |= @as(u64, self.bytes[self.offset + idx]) << shift;
        }
        self.offset += byte_count;
        return value;
    }
};

test "theme libraries export and import owned themes" {
    const allocator = std.testing.allocator;
    const workspace = try ThemeMod.importTheme(allocator, .ghostty, "Workspace Night",
        \\background = #000011
        \\foreground = #eeeeee
        \\cursor-color = #ff00aa
        \\palette = 3=#123456
    );
    const themes = [_]ThemeMod.Theme{ ThemeMod.Theme.builtinDark(), workspace };

    const bytes = try exportThemeLibraryAlloc(allocator, &themes);
    defer allocator.free(bytes);
    try std.testing.expect(bytes.len > theme_magic.len);

    var loaded = try importThemeLibraryAlloc(allocator, bytes);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), loaded.entries.len);
    try std.testing.expectEqualStrings("noctty-dark", loaded.entries[0].theme.name);
    try std.testing.expectEqualStrings("Workspace Night", loaded.entries[1].theme.name);
    try std.testing.expectEqual(ThemeMod.Color.fromHex(0x000011), loaded.entries[1].theme.background);
    try std.testing.expectEqual(ThemeMod.Color.fromHex(0x123456), loaded.entries[1].theme.palette[3]);
    try std.testing.expectEqual(
        workspace.chromeColor(.scrollbar_thumb),
        loaded.entries[1].theme.chromeColor(.scrollbar_thumb),
    );
    try std.testing.expect(loaded.entries[1].theme.name.ptr != workspace.name.ptr);
}

test "version one themes retain their colors in workspace chrome" {
    const allocator = std.testing.allocator;
    var legacy_theme = ThemeMod.Theme.builtinDark();
    legacy_theme.name = "Legacy";
    legacy_theme.background = ThemeMod.Color.fromHex(0x102030);
    legacy_theme.foreground = ThemeMod.Color.fromHex(0xe0d0c0);

    const current = try exportThemeLibraryAlloc(allocator, &.{legacy_theme});
    defer allocator.free(current);
    const chrome_bytes = ThemeMod.ChromeColor.count * 4;
    const legacy = try allocator.dupe(u8, current[0 .. current.len - chrome_bytes]);
    defer allocator.free(legacy);
    legacy[theme_magic.len] = 1;

    var loaded = try importThemeLibraryAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(
        legacy_theme.background,
        loaded.entries[0].theme.chromeColor(.workspace_background),
    );
    try std.testing.expectEqual(
        legacy_theme.background,
        loaded.entries[0].theme.chromeColor(.overlay_background),
    );
    try std.testing.expectEqual(
        legacy_theme.foreground,
        loaded.entries[0].theme.chromeColor(.overlay_foreground),
    );
}

test "version two themes carry terminal cursor color into chrome" {
    const allocator = std.testing.allocator;
    var legacy_theme = ThemeMod.Theme.builtinDark();
    legacy_theme.cursor = ThemeMod.Color.fromHex(0xabcdef);

    const current = try exportThemeLibraryAlloc(allocator, &.{legacy_theme});
    defer allocator.free(current);
    const legacy = try allocator.dupe(u8, current[0 .. current.len - 8]);
    defer allocator.free(legacy);
    legacy[theme_magic.len] = 2;

    var loaded = try importThemeLibraryAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(
        legacy_theme.cursor,
        loaded.entries[0].theme.chromeColor(.terminal_cursor),
    );
}

test "version three themes use their background for pane gaps" {
    const allocator = std.testing.allocator;
    var legacy_theme = ThemeMod.Theme.builtinDark();
    legacy_theme.background = ThemeMod.Color.fromHex(0x123456);

    const current = try exportThemeLibraryAlloc(allocator, &.{legacy_theme});
    defer allocator.free(current);
    const legacy = try allocator.dupe(u8, current[0 .. current.len - 4]);
    defer allocator.free(legacy);
    legacy[theme_magic.len] = 3;

    var loaded = try importThemeLibraryAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(
        legacy_theme.background,
        loaded.entries[0].theme.chromeColor(.pane_gap),
    );
}

test "theme libraries reject malformed or duplicate snapshots" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidThemeLibrarySnapshot, importThemeLibraryAlloc(allocator, "not-noctty-theme-library"));

    const duplicate = [_]ThemeMod.Theme{ ThemeMod.Theme.builtinDark(), ThemeMod.Theme.builtinDark() };
    try std.testing.expectError(error.DuplicateThemeName, exportThemeLibraryAlloc(allocator, &duplicate));

    const themes = [_]ThemeMod.Theme{ThemeMod.Theme.builtinDark()};
    const bytes = try exportThemeLibraryAlloc(allocator, &themes);
    defer allocator.free(bytes);
    const bad = try allocator.dupe(u8, bytes);
    defer allocator.free(bad);
    bad[theme_magic.len] = 99;
    try std.testing.expectError(error.UnsupportedThemeLibrarySnapshot, importThemeLibraryAlloc(allocator, bad));
}

test "theme import releases duplicate records on rejection" {
    const allocator = std.testing.allocator;
    const bytes = try exportThemeLibraryAlloc(allocator, &.{ThemeMod.Theme.builtinDark()});
    defer allocator.free(bytes);
    const header_length = theme_magic.len + 1 + 8;
    const duplicate = try allocator.alloc(u8, bytes.len * 2 - header_length);
    defer allocator.free(duplicate);
    @memcpy(duplicate[0..bytes.len], bytes);
    @memcpy(duplicate[bytes.len..], bytes[header_length..]);
    duplicate[theme_magic.len + 1] = 2;
    try std.testing.expectError(error.DuplicateThemeName, importThemeLibraryAlloc(allocator, duplicate));
}

test "theme import rejects overflowing name length" {
    const bytes = "NOCTTYTHM\x04\x01\x00\x00\x00\x00\x00\x00\x00" ++ "\xff\xff\xff\xff\xff\xff\xff\xff";
    try std.testing.expectError(error.InvalidThemeLibrarySnapshot, importThemeLibraryAlloc(std.testing.allocator, bytes));
}

test "default theme library path uses native config location" {
    const allocator = std.testing.allocator;
    const path = try defaultThemeLibraryPathAlloc(allocator, "/home/alice");
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/home/alice/.config/noctty/themes.nocttythemes", path);
}

test "theme libraries save and load through atomic storage" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const workspace = try ThemeMod.importTheme(allocator, .xresources, "Workspace Night",
        \\*.background: #010203
        \\*.foreground: #aabbcc
    );
    const themes = [_]ThemeMod.Theme{ ThemeMod.Theme.builtinDark(), workspace };

    const saved = try saveThemeLibraryFile(allocator, io, tmp.dir, "themes/library.nocttythemes", &themes, .library);
    defer saved.deinit(allocator);
    try std.testing.expect(saved.bytes > theme_magic.len);
    try std.testing.expectEqual(@as(usize, 2), saved.theme_count);

    var loaded = try loadThemeLibraryFile(allocator, io, tmp.dir, "themes/library.nocttythemes", .library);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(ThemeFileRole.library, loaded.receipt.role);
    try std.testing.expectEqual(@as(usize, 2), loaded.receipt.theme_count);
    try std.testing.expectEqualStrings("Workspace Night", loaded.loaded.entries[1].theme.name);
    try std.testing.expectEqual(ThemeMod.Color.fromHex(0x010203), loaded.loaded.entries[1].theme.background);
}

test "theme writes retain only a validated last-known-good backup" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "themes/themes.nocttythemes";
    const original = [_]ThemeMod.Theme{ThemeMod.Theme.builtinDark()};
    const first = try saveThemeLibraryFile(
        allocator,
        io,
        tmp.dir,
        path,
        &original,
        .library,
    );
    first.deinit(allocator);

    const replacement = try ThemeMod.importTheme(allocator, .ghostty, "Replacement",
        \\background = #f0f0f0
        \\foreground = #101010
    );
    const updated = [_]ThemeMod.Theme{replacement};
    const second = try saveThemeLibraryFile(
        allocator,
        io,
        tmp.dir,
        path,
        &updated,
        .library,
    );
    second.deinit(allocator);

    var backup = try loadThemeLibraryFile(
        allocator,
        io,
        tmp.dir,
        "themes/themes.nocttythemes.bak",
        .backup,
    );
    defer backup.deinit(allocator);
    try std.testing.expectEqualStrings("noctty-dark", backup.loaded.entries[0].theme.name);

    try replaceFileAtomic(io, tmp.dir, path, "damaged themes");
    const third = try saveThemeLibraryFile(
        allocator,
        io,
        tmp.dir,
        path,
        &original,
        .library,
    );
    third.deinit(allocator);

    var retained = try loadThemeLibraryFile(
        allocator,
        io,
        tmp.dir,
        "themes/themes.nocttythemes.bak",
        .backup,
    );
    defer retained.deinit(allocator);
    try std.testing.expectEqualStrings("noctty-dark", retained.loaded.entries[0].theme.name);
    const rejected = try tmp.dir.readFileAlloc(
        io,
        "themes/themes.nocttythemes.rejected",
        allocator,
        .limited(64),
    );
    defer allocator.free(rejected);
    try std.testing.expectEqualStrings("damaged themes", rejected);
}

test "oversized theme libraries remain recoverable before a valid replacement" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "themes/themes.nocttythemes";
    const oversized = try allocator.alloc(u8, max_theme_file_bytes + 1);
    defer allocator.free(oversized);
    @memset(oversized, 0x5a);
    try replaceFileAtomic(io, tmp.dir, path, oversized);

    const themes = [_]ThemeMod.Theme{ThemeMod.Theme.builtinDark()};
    const saved = try saveThemeLibraryFile(
        allocator,
        io,
        tmp.dir,
        path,
        &themes,
        .library,
    );
    saved.deinit(allocator);

    const rejected = try tmp.dir.readFileAlloc(
        io,
        "themes/themes.nocttythemes.rejected",
        allocator,
        .limited(max_theme_file_bytes + 2),
    );
    defer allocator.free(rejected);
    try std.testing.expectEqual(oversized.len, rejected.len);
    try std.testing.expectEqual(@as(u8, 0x5a), rejected[0]);
    try std.testing.expectEqual(@as(u8, 0x5a), rejected[rejected.len - 1]);

    var loaded = try loadThemeLibraryFile(allocator, io, tmp.dir, path, .library);
    defer loaded.deinit(allocator);
}
