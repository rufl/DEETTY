const std = @import("std");
const Share = @import("noctty_share");

pub const ImportFormat = Share.theme.ImportFormat;

pub fn detect(path: []const u8, contents: []const u8) ?ImportFormat {
    const basename_start = std.mem.lastIndexOfAny(u8, path, "/\\") orelse 0;
    const name = if (basename_start < path.len and (path[basename_start] == '/' or path[basename_start] == '\\'))
        path[basename_start + 1 ..]
    else
        path;
    if (std.ascii.endsWithIgnoreCase(name, ".conf") or std.ascii.endsWithIgnoreCase(name, ".ghostty")) return .ghostty;
    if (std.ascii.endsWithIgnoreCase(name, ".xresources") or std.ascii.endsWithIgnoreCase(name, ".xdefaults")) return .xresources;
    if (std.ascii.endsWithIgnoreCase(name, ".toml")) return .alacritty_toml;
    if (std.ascii.endsWithIgnoreCase(name, ".json")) {
        if (std.mem.indexOf(u8, contents, "\"dark\"") != null) return .noctalia_dark;
        if (std.mem.indexOf(u8, contents, "\"light\"") != null) return .noctalia_light;
        return .noctalia_active;
    }
    return null;
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

test "Windows theme source detection uses the basename" {
    try std.testing.expectEqual(@as(?ImportFormat, .ghostty), detect("C:\\themes\\nested\\theme.conf", ""));
    try std.testing.expectEqual(@as(?ImportFormat, null), detect("C:\\themes\\theme.conf.bak", ""));
}
