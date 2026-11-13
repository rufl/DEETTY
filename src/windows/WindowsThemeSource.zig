const std = @import("std");
const Share = @import("dintty_share");

pub const ImportFormat = Share.theme.ImportFormat;

pub fn detect(path: []const u8, contents: []const u8) ?ImportFormat {
    return Share.theme.detectImportFormat(path, contents);
}

test "Windows theme source detection maps every native extension" {
    try std.testing.expectEqual(@as(?ImportFormat, .ghostty), detect("C:\\themes\\night.GHOSTTY", ""));
    try std.testing.expectEqual(@as(?ImportFormat, .ghostty), detect("theme.conf", ""));
    try std.testing.expectEqual(@as(?ImportFormat, .xresources), detect("theme.XDEFAULTS", ""));
    try std.testing.expectEqual(@as(?ImportFormat, .xresources), detect("theme.xresources", ""));
    try std.testing.expectEqual(@as(?ImportFormat, .alacritty_toml), detect("theme.TOML", ""));
    try std.testing.expectEqual(@as(?ImportFormat, .noctalia_dark), detect("theme.json", "{\"dark\":{}}"));
    try std.testing.expectEqual(@as(?ImportFormat, .noctalia_light), detect("theme.json", "{\"light\":{}}"));
    try std.testing.expectEqual(@as(?ImportFormat, .noctalia_active), detect("theme.json", "{}"));
    try std.testing.expectEqual(@as(?ImportFormat, null), detect("theme.yaml", ""));
}

test "Windows theme source detection only uses top-level Noctalia variants" {
    try std.testing.expectEqual(
        @as(?ImportFormat, .noctalia_active),
        detect("theme.json", "{\"metadata\":\"dark\"}"),
    );
    try std.testing.expectEqual(
        @as(?ImportFormat, .noctalia_active),
        detect("theme.json", "{\"schemes\":{\"light\":{}}}"),
    );
    try std.testing.expectEqual(
        @as(?ImportFormat, .noctalia_dark),
        detect("theme.json", "{\"dark\":{},\"metadata\":\"light\"}"),
    );
}

test "Windows theme source detection uses the basename" {
    try std.testing.expectEqual(@as(?ImportFormat, .ghostty), detect("C:\\themes\\nested\\theme.conf", ""));
    try std.testing.expectEqual(@as(?ImportFormat, null), detect("C:\\themes\\theme.conf.bak", ""));
}
