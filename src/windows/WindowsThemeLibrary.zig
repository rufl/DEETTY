//! Portable shared themes with atomic Windows-only selection persistence.
const std = @import("std");
const Share = @import("dintty_share");
const Theme = Share.theme.Theme;
const Storage = Share.theme_storage;

pub const max_custom_themes = 64;
pub const max_file_bytes = Storage.max_theme_file_bytes;
const state_magic = "NWTHMST\x00";
const state_version: u8 = 1;
const header_bytes = state_magic.len + 2;
pub const max_state_bytes = max_file_bytes + header_bytes;
const builtins = [_]Theme{ Theme.builtinDark(), Theme.builtinHighContrast(), Theme.builtinPaseoBlackZinc() };

pub const Library = struct {
    allocator: std.mem.Allocator,
    custom: ?Storage.LoadedThemeLibrary = null,
    selected: usize = 0,

    pub fn init(allocator: std.mem.Allocator, legacy_theme: c_int) Library {
        return .{ .allocator = allocator, .selected = if (legacy_theme >= 0 and legacy_theme < builtins.len) @intCast(legacy_theme) else 0 };
    }

    pub fn deinit(self: *Library) void {
        if (self.custom) |*custom| custom.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn count(self: *const Library) usize {
        return builtins.len + if (self.custom) |custom| custom.entries.len else @as(usize, 0);
    }

    pub fn theme(self: *const Library, index: usize) ?*const Theme {
        if (index < builtins.len) return &builtins[index];
        const custom = self.custom orelse return null;
        if (index - builtins.len >= custom.entries.len) return null;
        return &custom.entries[index - builtins.len].theme;
    }

    pub fn selectedTheme(self: *const Library) *const Theme {
        return self.theme(self.selected) orelse &builtins[0];
    }

    pub fn preferenceTheme(self: *const Library) c_int {
        return @intCast(@min(self.selected, builtins.len));
    }

    pub fn indexedColor(self: *const Library, index: u32) ?u32 {
        if (index >= 16) return null;
        return rgb(self.selectedTheme().palette[index]);
    }

    /// The sink's save(bytes) must commit durably or fail without replacing state.
    pub fn select(self: *Library, index: usize, sink: anytype) !void {
        if (self.theme(index) == null) return error.InvalidThemeSelection;
        const bytes = try self.encodeSelectionAlloc(index);
        defer self.allocator.free(bytes);
        try sink.save(bytes);
        self.selected = index;
    }

    pub fn importPortable(self: *Library, bytes: []const u8, sink: anytype) !void {
        var candidate = Library.init(self.allocator, 0);
        errdefer candidate.deinit();
        candidate.custom = try decodePortable(self.allocator, bytes);
        candidate.selected = builtins.len;
        const state = try candidate.encodeStateAlloc();
        defer self.allocator.free(state);
        try sink.save(state);
        self.deinit();
        self.* = candidate;
    }

    /// Export never exposes the local selection envelope.
    pub fn exportPortableAlloc(self: *const Library) ![]u8 {
        if (self.custom) |custom| {
            var themes: [max_custom_themes]Theme = undefined;
            for (custom.entries, 0..) |entry, index| themes[index] = entry.theme;
            return Storage.exportThemeLibraryAlloc(self.allocator, themes[0..custom.entries.len]);
        }
        return Storage.exportThemeLibraryAlloc(self.allocator, &builtins);
    }

    pub fn encodeStateAlloc(self: *const Library) ![]u8 {
        return self.encodeSelectionAlloc(self.selected);
    }

    fn encodeSelectionAlloc(self: *const Library, selected: usize) ![]u8 {
        if (self.theme(selected) == null) return error.InvalidThemeSelection;
        const portable = if (self.custom != null) try self.exportPortableAlloc() else null;
        defer if (portable) |bytes| self.allocator.free(bytes);
        const length = if (portable) |bytes| bytes.len else 0;
        if (length > max_file_bytes) return error.ThemeLibraryTooLarge;
        const bytes = try self.allocator.alloc(u8, header_bytes + length);
        @memcpy(bytes[0..state_magic.len], state_magic);
        bytes[state_magic.len] = state_version;
        bytes[state_magic.len + 1] = @intCast(selected);
        if (portable) |payload| @memcpy(bytes[header_bytes..], payload);
        return bytes;
    }
};

pub fn rgb(color: Share.theme.Color) u32 {
    return (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;
}

fn decodePortable(allocator: std.mem.Allocator, bytes: []const u8) !Storage.LoadedThemeLibrary {
    if (bytes.len > max_file_bytes) return error.ThemeLibraryTooLarge;
    var loaded = try Storage.importThemeLibraryAlloc(allocator, bytes);
    errdefer loaded.deinit(allocator);
    if (loaded.entries.len > max_custom_themes) return error.ThemeLibraryTooLarge;
    return loaded;
}

pub fn decodeStateAlloc(allocator: std.mem.Allocator, bytes: []const u8) !Library {
    if (bytes.len < header_bytes or bytes.len > max_state_bytes or
        !std.mem.eql(u8, bytes[0..state_magic.len], state_magic)) return error.InvalidWindowsThemeState;
    if (bytes[state_magic.len] != state_version) return error.UnsupportedWindowsThemeState;
    var library = Library.init(allocator, 0);
    errdefer library.deinit();
    if (bytes.len > header_bytes) library.custom = try decodePortable(allocator, bytes[header_bytes..]);
    library.selected = bytes[state_magic.len + 1];
    if (library.theme(library.selected) == null) return error.InvalidThemeSelection;
    return library;
}

const MemorySink = struct {
    bytes: ?[]u8 = null,
    fail: bool = false,

    fn save(self: *MemorySink, bytes: []const u8) !void {
        if (self.fail) return error.DiskFull;
        const replacement = try std.testing.allocator.dupe(u8, bytes);
        if (self.bytes) |previous| std.testing.allocator.free(previous);
        self.bytes = replacement;
    }

    fn deinit(self: *MemorySink) void {
        if (self.bytes) |bytes| std.testing.allocator.free(bytes);
    }
};

test "Windows theme library: selected palette persists and exports portable names" {
    const allocator = std.testing.allocator;
    var library = Library.init(allocator, 2);
    defer library.deinit();
    var sink: MemorySink = .{};
    defer sink.deinit();
    var custom = Theme.builtinDark();
    custom.name = "owned-test";
    custom.foreground = .fromHex(0x123456);
    custom.palette[1] = .fromHex(0xabcdef);
    const bytes = try Storage.exportThemeLibraryAlloc(allocator, &.{custom});
    defer allocator.free(bytes);
    try library.importPortable(bytes, &sink);
    try std.testing.expectEqual(@as(usize, 3), library.selected);
    try std.testing.expectEqual(@as(c_int, 3), library.preferenceTheme());
    var loaded = try decodeStateAlloc(allocator, sink.bytes.?);
    defer loaded.deinit();
    try std.testing.expectEqual(@as(u32, 0x123456), rgb(loaded.selectedTheme().foreground));
    try std.testing.expectEqual(@as(?u32, 0xabcdef), loaded.indexedColor(1));
    try std.testing.expectEqual(@as(?u32, null), loaded.indexedColor(16));
    const exported = try loaded.exportPortableAlloc();
    defer allocator.free(exported);
    var portable = try Storage.importThemeLibraryAlloc(allocator, exported);
    defer portable.deinit(allocator);
    try std.testing.expectEqualStrings("owned-test", portable.entries[0].theme.name);
    try library.select(1, &sink);
    var builtin_selected = try decodeStateAlloc(allocator, sink.bytes.?);
    defer builtin_selected.deinit();
    try std.testing.expectEqual(@as(usize, 1), builtin_selected.selected);
    try std.testing.expectEqual(@as(usize, 4), builtin_selected.count());
}

test "Windows theme library: failed replacement preserves live and durable state and owns names" {
    const allocator = std.testing.allocator;
    var library = Library.init(allocator, 0);
    defer library.deinit();
    var sink: MemorySink = .{};
    defer sink.deinit();
    var custom = Theme.builtinDark();
    custom.name = "first";
    const first = try Storage.exportThemeLibraryAlloc(allocator, &.{custom});
    try library.importPortable(first, &sink);
    allocator.free(first);
    try std.testing.expectEqualStrings("first", library.selectedTheme().name);
    const durable = try allocator.dupe(u8, sink.bytes.?);
    defer allocator.free(durable);
    custom.name = "second";
    const second = try Storage.exportThemeLibraryAlloc(allocator, &.{custom});
    defer allocator.free(second);
    sink.fail = true;
    try std.testing.expectError(error.DiskFull, library.importPortable(second, &sink));
    try std.testing.expectError(error.DiskFull, library.select(2, &sink));
    try std.testing.expectEqualStrings("first", library.selectedTheme().name);
    try std.testing.expectEqualSlices(u8, durable, sink.bytes.?);
    sink.fail = false;
    try library.importPortable(second, &sink);
    try std.testing.expectEqualStrings("second", library.selectedTheme().name);
}

test "Windows theme library: malformed and oversized imports cannot replace state" {
    const allocator = std.testing.allocator;
    var library = Library.init(allocator, 2);
    defer library.deinit();
    var sink: MemorySink = .{};
    defer sink.deinit();
    try library.select(2, &sink);
    const durable = try allocator.dupe(u8, sink.bytes.?);
    defer allocator.free(durable);
    try std.testing.expectError(error.InvalidThemeLibrarySnapshot, library.importPortable("bad", &sink));
    const oversized = try allocator.alloc(u8, max_file_bytes + 1);
    defer allocator.free(oversized);
    try std.testing.expectError(error.ThemeLibraryTooLarge, library.importPortable(oversized, &sink));
    var themes: [max_custom_themes + 1]Theme = undefined;
    var names: [themes.len][16]u8 = undefined;
    for (&themes, 0..) |*theme, index| {
        theme.* = Theme.builtinDark();
        theme.name = try std.fmt.bufPrint(&names[index], "theme-{d}", .{index});
    }
    const too_many = try Storage.exportThemeLibraryAlloc(allocator, &themes);
    defer allocator.free(too_many);
    try std.testing.expectError(error.ThemeLibraryTooLarge, library.importPortable(too_many, &sink));
    try std.testing.expectEqual(@as(usize, 2), library.selected);
    try std.testing.expectEqualSlices(u8, durable, sink.bytes.?);
    const valid = try Storage.exportThemeLibraryAlloc(allocator, themes[0..1]);
    defer allocator.free(valid);
    for (0..valid.len) |length| {
        if (library.importPortable(valid[0..length], &sink)) |_| return error.AcceptedTruncation else |_| {}
    }
    try std.testing.expectEqualSlices(u8, durable, sink.bytes.?);
    try std.testing.expectEqual(@as(usize, 2), library.selected);
    try library.importPortable(valid, &sink);
    const full = try Storage.exportThemeLibraryAlloc(allocator, themes[0..max_custom_themes]);
    defer allocator.free(full);
    try library.importPortable(full, &sink);
    try library.select(66, &sink);
    var last_selected = try decodeStateAlloc(allocator, sink.bytes.?);
    defer last_selected.deinit();
    try std.testing.expectEqualStrings("theme-63", last_selected.selectedTheme().name);
    try std.testing.expectError(error.InvalidThemeSelection, library.select(67, &sink));
}

test "Windows theme library: builtin fallback and invalid local envelopes" {
    const allocator = std.testing.allocator;
    var library = Library.init(allocator, 99);
    defer library.deinit();
    try std.testing.expectEqual(@as(usize, 0), library.selected);
    const portable = try library.exportPortableAlloc();
    defer allocator.free(portable);
    var builtins_loaded = try Storage.importThemeLibraryAlloc(allocator, portable);
    defer builtins_loaded.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 3), builtins_loaded.entries.len);
    const state = try library.encodeStateAlloc();
    defer allocator.free(state);
    var loaded = try decodeStateAlloc(allocator, state);
    defer loaded.deinit();
    try std.testing.expectEqualStrings(Theme.builtinDark().name, loaded.selectedTheme().name);
    state[state_magic.len + 1] = 3;
    try std.testing.expectError(error.InvalidThemeSelection, decodeStateAlloc(allocator, state));
    state[state_magic.len] = 2;
    try std.testing.expectError(error.UnsupportedWindowsThemeState, decodeStateAlloc(allocator, state));
}
