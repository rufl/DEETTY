//! Shared built-in theme and point-size policy for native Windows consumers.

const std = @import("std");
const Share = @import("dintty_share");
const Theme = Share.theme;

pub const min_font_size = 8;
pub const max_font_size = 32;
pub const default_font_size = 13;

const themes = [_]Theme.Theme{
    Theme.Theme.builtinDark(),
    Theme.Theme.builtinHighContrast(),
    Theme.Theme.builtinPaseoBlackZinc(),
};

pub fn validTheme(theme: c_int) bool {
    return theme >= 0 and theme < themes.len;
}

pub fn validFontSize(font_size_pt: c_int) bool {
    return font_size_pt >= min_font_size and font_size_pt <= max_font_size;
}

/// Packed 0xRRGGBB defaults. The renderer must use GetSysColor for theme 1's
/// foreground/background so Windows high-contrast settings remain authoritative.
pub fn colors(theme: c_int) struct { foreground: u32, background: u32 } {
    const selected = selectedTheme(theme);
    return .{
        .foreground = rgb(selected.foreground),
        .background = rgb(selected.background),
    };
}

/// Only ANSI colors are themed. Null preserves the terminal's 256-color and
/// interned truecolor resolution, including its invalid-color sentinel.
pub fn indexedColor(theme: c_int, index: u32) ?u32 {
    if (index >= 16) return null;
    return rgb(selectedTheme(theme).palette[index]);
}

fn selectedTheme(theme: c_int) *const Theme.Theme {
    return &themes[if (validTheme(theme)) @as(usize, @intCast(theme)) else 0];
}

fn rgb(color: Theme.Color) u32 {
    return (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;
}

test "Windows appearance: theme and exact font bounds reject invalid values" {
    for ([_]c_int{ 0, 1, 2 }) |theme| try std.testing.expect(validTheme(theme));
    for ([_]c_int{ std.math.minInt(c_int), -1, 3, std.math.maxInt(c_int) }) |theme| {
        try std.testing.expect(!validTheme(theme));
    }
    for (8..33) |size| try std.testing.expect(validFontSize(@intCast(size)));
    for ([_]c_int{ std.math.minInt(c_int), 0, 7, 33, std.math.maxInt(c_int) }) |size| {
        try std.testing.expect(!validFontSize(size));
    }
}

test "Windows appearance: shared themes resolve defaults and all ANSI colors" {
    const expected = [_]Theme.Theme{
        Theme.Theme.builtinDark(),
        Theme.Theme.builtinHighContrast(),
        Theme.Theme.builtinPaseoBlackZinc(),
    };
    for (expected, 0..) |theme, theme_id| {
        const defaults = colors(@intCast(theme_id));
        try expectRgb(theme.foreground, defaults.foreground);
        try expectRgb(theme.background, defaults.background);
        for (theme.palette, 0..) |color, index| {
            try expectRgb(color, indexedColor(@intCast(theme_id), @intCast(index)).?);
        }
    }
    for ([_]c_int{ -1, 3, std.math.maxInt(c_int) }) |theme| {
        try std.testing.expectEqualDeep(colors(0), colors(theme));
        try std.testing.expectEqual(indexedColor(0, 15), indexedColor(theme, 15));
    }
}

test "Windows appearance: extended and truecolor IDs retain terminal resolution" {
    var grid = try Share.vt.Grid.init(std.testing.allocator, 4, 1);
    defer grid.deinit();
    try grid.feed("\x1b[31mA\x1b[38;5;202mB\x1b[38;2;1;2;3mC");
    const ansi = grid.cell(0, 0).foreground;
    const extended = grid.cell(1, 0).foreground;
    const truecolor = grid.cell(2, 0).foreground;
    for ([_]c_int{ 0, 1, 2 }) |theme| {
        try expectRgb(selectedTheme(theme).palette[1], indexedColor(theme, ansi).?);
        try std.testing.expectEqual(@as(?u32, null), indexedColor(theme, extended));
        try std.testing.expectEqual(@as(?u32, null), indexedColor(theme, truecolor));
        try std.testing.expectEqual(@as(u32, 0xff5f00), indexedColor(theme, extended) orelse grid.colorRgb(extended));
        try std.testing.expectEqual(@as(u32, 0x010203), indexedColor(theme, truecolor) orelse grid.colorRgb(truecolor));
        try std.testing.expectEqual(@as(?u32, null), indexedColor(theme, 16));
        try std.testing.expectEqual(@as(?u32, null), indexedColor(theme, std.math.maxInt(u32)));
    }
}

fn expectRgb(expected: Theme.Color, actual: u32) !void {
    try std.testing.expectEqual(@as(u32, expected.r), actual >> 16);
    try std.testing.expectEqual(expected.g, @as(u8, @truncate(actual >> 8)));
    try std.testing.expectEqual(expected.b, @as(u8, @truncate(actual)));
}
