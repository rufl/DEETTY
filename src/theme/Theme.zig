const std = @import("std");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 0xff,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn fromHex(hex: u24) Color {
        return .{
            .r = @intCast((hex >> 16) & 0xff),
            .g = @intCast((hex >> 8) & 0xff),
            .b = @intCast(hex & 0xff),
        };
    }
};

pub const ChromeColor = enum(u8) {
    workspace_background,
    pane_border_active,
    pane_border_selected,
    pane_border_inactive,
    scrollbar_track,
    scrollbar_thumb,
    scrollbar_thumb_hover,
    overlay_background,
    overlay_border,
    overlay_foreground,
    selection_background,
    search_match_background,
    status_info,
    status_success,
    status_warning,
    status_error,
    terminal_cursor,
    pane_gap,

    pub const count = @typeInfo(ChromeColor).@"enum".fields.len;
};

pub const Theme = struct {
    name: []const u8,
    foreground: Color,
    background: Color,
    cursor: Color,
    palette: [16]Color,
    chrome: [ChromeColor.count]Color,

    pub fn builtinDark() Theme {
        return .{
            .name = "noctty-dark",
            .foreground = Color.fromHex(0xd7dde8),
            .background = Color.fromHex(0x0b0d12),
            .cursor = Color.fromHex(0x8fb8ff),
            .palette = .{
                Color.fromHex(0x151923),
                Color.fromHex(0xf7768e),
                Color.fromHex(0x9ece6a),
                Color.fromHex(0xe0af68),
                Color.fromHex(0x7aa2f7),
                Color.fromHex(0xbb9af7),
                Color.fromHex(0x7dcfff),
                Color.fromHex(0xc0caf5),
                Color.fromHex(0x565f89),
                Color.fromHex(0xff7a93),
                Color.fromHex(0xb9f27c),
                Color.fromHex(0xffc777),
                Color.fromHex(0x8fb8ff),
                Color.fromHex(0xc7a9ff),
                Color.fromHex(0x9de7ff),
                Color.fromHex(0xe5e9f0),
            },
            .chrome = .{
                Color.fromHex(0x0b0d12),
                Color.fromHex(0xf9e2af),
                Color.fromHex(0xf9e2af),
                Color.fromHex(0x343848),
                Color.fromHex(0x0e1016),
                Color.fromHex(0x8c96aa),
                Color.fromHex(0xf2b82e),
                Color.fromHex(0x12151d),
                Color.fromHex(0xf2b82e),
                Color.fromHex(0xf7f8ff),
                Color.fromHex(0x3d609f),
                Color.fromHex(0xf2e68c),
                Color.fromHex(0x408cf2),
                Color.fromHex(0x40cc66),
                Color.fromHex(0xf5b82e),
                Color.fromHex(0xe64040),
                Color.fromHex(0x8fb8ff),
                Color.fromHex(0x0b0d12),
            },
        };
    }

    pub fn builtinPaseoBlackZinc() Theme {
        return .{
            .name = "paseo-black-zinc",
            .foreground = Color.fromHex(0xf4f4f5),
            .background = Color.fromHex(0x000000),
            .cursor = Color.fromHex(0xfafafa),
            .palette = .{
                Color.fromHex(0x000000),
                Color.fromHex(0xf87171),
                Color.fromHex(0xa3e635),
                Color.fromHex(0xfacc15),
                Color.fromHex(0x60a5fa),
                Color.fromHex(0xe879f9),
                Color.fromHex(0x22d3ee),
                Color.fromHex(0xd4d4d8),
                Color.fromHex(0x52525b),
                Color.fromHex(0xfca5a5),
                Color.fromHex(0xbef264),
                Color.fromHex(0xfde68a),
                Color.fromHex(0x93c5fd),
                Color.fromHex(0xf0abfc),
                Color.fromHex(0x67e8f9),
                Color.fromHex(0xfafafa),
            },
            .chrome = .{
                Color.fromHex(0x000000),
                Color.fromHex(0xfafafa),
                Color.fromHex(0xd4d4d8),
                Color.fromHex(0x27272a),
                Color.fromHex(0x18181b),
                Color.fromHex(0x71717a),
                Color.fromHex(0xa1a1aa),
                Color.fromHex(0x09090b),
                Color.fromHex(0x52525b),
                Color.fromHex(0xf4f4f5),
                Color.fromHex(0x3f3f46),
                Color.fromHex(0xfacc15),
                Color.fromHex(0x60a5fa),
                Color.fromHex(0x4ade80),
                Color.fromHex(0xfacc15),
                Color.fromHex(0xf87171),
                Color.fromHex(0xfafafa),
                Color.fromHex(0x000000),
            },
        };
    }

    pub fn builtinHighContrast() Theme {
        var theme = builtinDark();
        theme.name = "noctty-high-contrast";
        theme.foreground = Color.fromHex(0xffffff);
        theme.background = Color.fromHex(0x000000);
        theme.cursor = Color.fromHex(0xffffff);
        theme.chrome = .{
            Color.fromHex(0x000000), Color.fromHex(0xffffff),
            Color.fromHex(0xffffff), Color.fromHex(0xffffff),
            Color.fromHex(0x000000), Color.fromHex(0xffffff),
            Color.fromHex(0xffffff), Color.fromHex(0x000000),
            Color.fromHex(0xffffff), Color.fromHex(0xffffff),
            Color.fromHex(0xffffff), Color.fromHex(0xffff00),
            Color.fromHex(0xffffff), Color.fromHex(0xffffff),
            Color.fromHex(0xffffff), Color.fromHex(0xffffff),
            Color.fromHex(0xffffff), Color.fromHex(0x000000),
        };
        return theme;
    }

    pub fn chromeColor(self: Theme, color: ChromeColor) Color {
        return self.chrome[@intFromEnum(color)];
    }

    pub fn setChromeColor(self: *Theme, color: ChromeColor, value: Color) void {
        self.chrome[@intFromEnum(color)] = value;
    }
};

pub const Preview = struct {
    name: []const u8,
    foreground: Color,
    background: Color,
    cursor: Color,
    palette_count: usize = 16,

    pub fn fromTheme(theme: Theme) Preview {
        return .{
            .name = theme.name,
            .foreground = theme.foreground,
            .background = theme.background,
            .cursor = theme.cursor,
            .palette_count = theme.palette.len,
        };
    }

    pub fn formatSummary(self: Preview, writer: anytype) !void {
        try writer.print("{s} fg=", .{self.name});
        try formatColor(self.foreground, writer);
        try writer.writeAll(" bg=");
        try formatColor(self.background, writer);
        try writer.writeAll(" cursor=");
        try formatColor(self.cursor, writer);
        try writer.print(" palette={d}", .{self.palette_count});
    }
};

pub const ImportFormat = enum {
    ghostty,
    xresources,
    alacritty_toml,
    noctalia_dark,
    noctalia_light,
    noctalia_active,
};

pub fn validateName(name: []const u8) !void {
    const trimmed = std.mem.trim(u8, name, " \t\r\n");
    if (trimmed.len == 0) return error.InvalidThemeName;
    if (trimmed.len > 96) return error.InvalidThemeName;
    for (trimmed) |ch| {
        if (std.ascii.isAlphanumeric(ch) or ch == '-' or ch == '_' or ch == '.' or ch == ' ') continue;
        return error.InvalidThemeName;
    }
}

pub fn parseHexColor(raw: []const u8) !Color {
    var s = std.mem.trim(u8, raw, " \t\r\n");
    if (s.len >= 2 and (s[0] == '"' or s[0] == '\'')) {
        const quote = s[0];
        const end = std.mem.indexOfScalarPos(u8, s, 1, quote) orelse return error.InvalidColor;
        s = s[1..end];
    }
    if (s.len > 0 and s[0] == '#') {
        s = s[1..];
    } else if (s.len >= 2 and s[0] == '0' and (s[1] == 'x' or s[1] == 'X')) {
        s = s[2..];
    }
    if (s.len != 6) return error.InvalidColor;
    const value = try std.fmt.parseInt(u24, s, 16);
    return Color.fromHex(value);
}

pub fn formatColor(color: Color, writer: anytype) !void {
    try writer.print("#{x:0>2}{x:0>2}{x:0>2}", .{ color.r, color.g, color.b });
}

pub fn importTheme(
    allocator: std.mem.Allocator,
    format: ImportFormat,
    name: []const u8,
    contents: []const u8,
) !Theme {
    try validateName(name);
    var theme = Theme.builtinDark();
    theme.name = name;

    switch (format) {
        .noctalia_dark, .noctalia_light, .noctalia_active => try applyNoctaliaTheme(allocator, &theme, format, contents),
        else => {
            var alacritty_section: []const u8 = "";
            var it = std.mem.splitScalar(u8, contents, '\n');
            while (it.next()) |line_raw| {
                const line = std.mem.trim(u8, line_raw, " \t\r");
                if (line.len == 0 or line[0] == '#') continue;
                if (format == .alacritty_toml and line[0] == '[' and line[line.len - 1] == ']') {
                    alacritty_section = std.mem.trim(u8, line[1 .. line.len - 1], " \t");
                    continue;
                }
                switch (format) {
                    .ghostty => applyGhosttyLine(&theme, line) catch {},
                    .xresources => applyXresourcesLine(&theme, line) catch {},
                    .alacritty_toml => applyAlacrittyLine(&theme, alacritty_section, line) catch {},
                    else => unreachable,
                }
            }
            theme.setChromeColor(.workspace_background, theme.background);
            theme.setChromeColor(.overlay_background, theme.background);
            theme.setChromeColor(.overlay_foreground, theme.foreground);
            theme.setChromeColor(.terminal_cursor, theme.cursor);
            theme.setChromeColor(.pane_gap, theme.background);
        },
    }
    return theme;
}

fn jsonColor(object: *const std.json.ObjectMap, key: []const u8) ?Color {
    const value = object.get(key) orelse return null;
    if (value != .string) return null;
    return parseHexColor(value.string) catch null;
}

fn setJsonColor(
    object: *const std.json.ObjectMap,
    key: []const u8,
    target: *Color,
) bool {
    target.* = jsonColor(object, key) orelse return false;
    return true;
}

fn noctaliaObject(
    root: *std.json.ObjectMap,
    format: ImportFormat,
) ?*const std.json.ObjectMap {
    const key = switch (format) {
        .noctalia_dark => "dark",
        .noctalia_light => "light",
        .noctalia_active => return root,
        else => unreachable,
    };
    const value = root.getPtr(key) orelse return null;
    if (value.* != .object) return null;
    return &value.object;
}

fn applyNoctaliaTerminal(
    theme: *Theme,
    terminal: *const std.json.ObjectMap,
) usize {
    var applied: usize = 0;
    applied += @intFromBool(setJsonColor(terminal, "foreground", &theme.foreground));
    applied += @intFromBool(setJsonColor(terminal, "background", &theme.background));
    applied += @intFromBool(setJsonColor(terminal, "cursor", &theme.cursor));
    if (jsonColor(terminal, "selectionBg")) |color| {
        theme.setChromeColor(.selection_background, color);
        applied += 1;
    }
    const names = [_][]const u8{
        "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
    };
    if (terminal.get("normal")) |normal| if (normal == .object) {
        for (names, 0..) |key, index| {
            if (jsonColor(&normal.object, key)) |color| {
                theme.palette[index] = color;
                applied += 1;
            }
        }
    };
    if (terminal.get("bright")) |bright| if (bright == .object) {
        for (names, 0..) |key, index| {
            if (jsonColor(&bright.object, key)) |color| {
                theme.palette[index + 8] = color;
                applied += 1;
            }
        }
    };
    return applied;
}

fn applyNoctaliaTheme(
    allocator: std.mem.Allocator,
    theme: *Theme,
    format: ImportFormat,
    contents: []const u8,
) !void {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch
        return error.InvalidNoctaliaTheme;
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidNoctaliaTheme;
    const source = noctaliaObject(&parsed.value.object, format) orelse
        return error.InvalidNoctaliaTheme;

    var applied: usize = 0;
    applied += @intFromBool(setJsonColor(source, "mOnSurface", &theme.foreground));
    applied += @intFromBool(setJsonColor(source, "mSurface", &theme.background));
    if (jsonColor(source, "mPrimary")) |color| {
        theme.cursor = color;
        theme.setChromeColor(.pane_border_active, color);
        theme.setChromeColor(.selection_background, color);
        theme.setChromeColor(.status_info, color);
        applied += 1;
    }
    if (jsonColor(source, "mTertiary")) |color| {
        theme.setChromeColor(.pane_border_selected, color);
        theme.setChromeColor(.search_match_background, color);
        theme.setChromeColor(.status_success, color);
        applied += 1;
    }
    if (jsonColor(source, "mOutline")) |color| {
        theme.setChromeColor(.pane_border_inactive, color);
        theme.setChromeColor(.overlay_border, color);
        applied += 1;
    }
    if (jsonColor(source, "mSurfaceVariant")) |color| {
        theme.setChromeColor(.scrollbar_track, color);
        theme.setChromeColor(.overlay_background, color);
        applied += 1;
    }
    if (jsonColor(source, "mOnSurfaceVariant")) |color| {
        theme.setChromeColor(.scrollbar_thumb, color);
        applied += 1;
    }
    if (jsonColor(source, "mHover")) |color| {
        theme.setChromeColor(.scrollbar_thumb_hover, color);
        applied += 1;
    }
    if (jsonColor(source, "mSecondary")) |color| {
        theme.setChromeColor(.status_warning, color);
        applied += 1;
    }
    if (jsonColor(source, "mError")) |color| {
        theme.setChromeColor(.status_error, color);
        applied += 1;
    }
    if (source.get("terminal")) |terminal| {
        if (terminal == .object) {
            applied += applyNoctaliaTerminal(theme, &terminal.object);
        }
    }
    if (applied == 0) return error.InvalidNoctaliaTheme;

    theme.setChromeColor(.workspace_background, theme.background);
    theme.setChromeColor(.overlay_foreground, theme.foreground);
    theme.setChromeColor(.terminal_cursor, theme.cursor);
    theme.setChromeColor(.pane_gap, theme.background);
}

fn applyGhosttyLine(theme: *Theme, line: []const u8) !void {
    const eq = std.mem.indexOfScalar(u8, line, '=') orelse return;
    const key = std.mem.trim(u8, line[0..eq], " \t");
    const value = std.mem.trim(u8, line[eq + 1 ..], " \t");
    if (std.mem.eql(u8, key, "background")) {
        theme.background = try parseHexColor(value);
    } else if (std.mem.eql(u8, key, "foreground")) {
        theme.foreground = try parseHexColor(value);
    } else if (std.mem.eql(u8, key, "cursor-color")) {
        theme.cursor = try parseHexColor(value);
    } else if (std.mem.eql(u8, key, "palette")) {
        if (std.mem.indexOfScalar(u8, value, '=')) |inner_eq| {
            const idx_raw = std.mem.trim(u8, value[0..inner_eq], " \t");
            const color_raw = std.mem.trim(u8, value[inner_eq + 1 ..], " \t");
            const idx = try std.fmt.parseInt(usize, idx_raw, 10);
            if (idx < theme.palette.len) theme.palette[idx] = try parseHexColor(color_raw);
        }
    }
}

fn applyXresourcesLine(theme: *Theme, line: []const u8) !void {
    const colon = std.mem.indexOfScalar(u8, line, ':') orelse return;
    const key = std.mem.trim(u8, line[0..colon], " \t*.");
    const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
    if (std.mem.eql(u8, key, "background")) {
        theme.background = try parseHexColor(value);
    } else if (std.mem.eql(u8, key, "foreground")) {
        theme.foreground = try parseHexColor(value);
    } else if (std.mem.eql(u8, key, "cursorColor")) {
        theme.cursor = try parseHexColor(value);
    } else if (std.mem.startsWith(u8, key, "color")) {
        const idx = try std.fmt.parseInt(usize, key["color".len..], 10);
        if (idx < theme.palette.len) theme.palette[idx] = try parseHexColor(value);
    }
}

fn applyAlacrittyLine(theme: *Theme, section: []const u8, line: []const u8) !void {
    const eq = std.mem.indexOfScalar(u8, line, '=') orelse return;
    const key = std.mem.trim(u8, line[0..eq], " \t");
    const value = std.mem.trim(u8, line[eq + 1 ..], " \t");
    if (std.mem.eql(u8, key, "background")) {
        theme.background = try parseHexColor(value);
    } else if (std.mem.eql(u8, key, "foreground")) {
        theme.foreground = try parseHexColor(value);
    } else if (std.mem.eql(u8, key, "cursor") or
        (std.mem.eql(u8, section, "colors.cursor") and std.mem.eql(u8, key, "text")))
    {
        theme.cursor = try parseHexColor(value);
    } else if (std.mem.eql(u8, section, "colors.primary")) {
        if (std.mem.eql(u8, key, "background")) {
            theme.background = try parseHexColor(value);
        } else if (std.mem.eql(u8, key, "foreground")) {
            theme.foreground = try parseHexColor(value);
        }
    } else if (std.mem.eql(u8, section, "colors.normal") or
        std.mem.eql(u8, section, "colors.bright"))
    {
        const names = [_][]const u8{
            "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
        };
        for (names, 0..) |name, index| {
            if (std.mem.eql(u8, key, name)) {
                const offset: usize = if (std.mem.eql(u8, section, "colors.bright")) 8 else 0;
                theme.palette[index + offset] = try parseHexColor(value);
                break;
            }
        }
    }
}

test "imports ghostty theme colors" {
    const imported = try importTheme(std.testing.allocator, .ghostty, "sample",
        \\background = #000011
        \\foreground = #eeeeee
        \\cursor-color = #ff00aa
        \\palette = 1=#cc0000
    );
    try std.testing.expectEqual(Color.fromHex(0x000011), imported.background);
    try std.testing.expectEqual(Color.fromHex(0xeeeeee), imported.foreground);
    try std.testing.expectEqual(Color.fromHex(0xff00aa), imported.cursor);
    try std.testing.expectEqual(Color.fromHex(0xcc0000), imported.palette[1]);
    try std.testing.expectEqual(
        imported.background,
        imported.chromeColor(.workspace_background),
    );
    try std.testing.expectEqual(imported.background, imported.chromeColor(.overlay_background));
    try std.testing.expectEqual(imported.foreground, imported.chromeColor(.overlay_foreground));
}

test "imports complete Noctalia terminal and chrome color schemes" {
    const imported = try importTheme(std.testing.allocator, .noctalia_dark, "Noctalia Tokyo",
        \\{"dark":{"mPrimary":"#112233","mSecondary":"#223344","mTertiary":"#334455","mError":"#ff0011","mSurface":"#010203","mOnSurface":"#f1f2f3","mSurfaceVariant":"#101112","mOnSurfaceVariant":"#d1d2d3","mOutline":"#445566","mHover":"#556677","terminal":{"foreground":"#a9b1d6","background":"#1f2335","selectionBg":"#4b517a","cursor":"#abcdef","normal":{"black":"#000001","red":"#000002","green":"#000003","yellow":"#000004","blue":"#000005","magenta":"#000006","cyan":"#000007","white":"#000008"},"bright":{"black":"#000009","red":"#00000a","green":"#00000b","yellow":"#00000c","blue":"#00000d","magenta":"#00000e","cyan":"#00000f","white":"#000010"}}}}
    );
    try std.testing.expectEqual(Color.fromHex(0xa9b1d6), imported.foreground);
    try std.testing.expectEqual(Color.fromHex(0x1f2335), imported.background);
    try std.testing.expectEqual(Color.fromHex(0xabcdef), imported.cursor);
    try std.testing.expectEqual(Color.fromHex(0x000002), imported.palette[1]);
    try std.testing.expectEqual(Color.fromHex(0x000010), imported.palette[15]);
    try std.testing.expectEqual(
        Color.fromHex(0x4b517a),
        imported.chromeColor(.selection_background),
    );
    try std.testing.expectEqual(
        Color.fromHex(0xabcdef),
        imported.chromeColor(.terminal_cursor),
    );
    try std.testing.expectEqual(
        Color.fromHex(0xff0011),
        imported.chromeColor(.status_error),
    );

    const light = try importTheme(std.testing.allocator, .noctalia_light, "Noctalia Light",
        \\{"light":{"mSurface":"#f0f2f7","mOnSurface":"#4e70c2","terminal":{"background":"#ffffff","foreground":"#111111"}}}
    );
    try std.testing.expectEqual(Color.fromHex(0xffffff), light.background);
    try std.testing.expectEqual(Color.fromHex(0x111111), light.foreground);
}

test "imports active Noctalia material colors without a terminal section" {
    const imported = try importTheme(std.testing.allocator, .noctalia_active, "Noctalia Active",
        \\{"mPrimary":"#adc6ff","mError":"#ffb4ab","mSurface":"#121316","mOnSurface":"#e3e2e6","mOutline":"#44474f"}
    );
    try std.testing.expectEqual(Color.fromHex(0x121316), imported.background);
    try std.testing.expectEqual(Color.fromHex(0xe3e2e6), imported.foreground);
    try std.testing.expectEqual(
        Color.fromHex(0xadc6ff),
        imported.chromeColor(.terminal_cursor),
    );
}

test "Paseo black zinc theme uses pure black and zinc chrome" {
    const theme = Theme.builtinPaseoBlackZinc();
    try std.testing.expectEqualStrings("paseo-black-zinc", theme.name);
    try std.testing.expectEqual(Color.fromHex(0x000000), theme.background);
    try std.testing.expectEqual(Color.fromHex(0xf4f4f5), theme.foreground);
    try std.testing.expectEqual(Color.fromHex(0x18181b), theme.chromeColor(.scrollbar_track));
    try std.testing.expectEqual(Color.fromHex(0x27272a), theme.chromeColor(.pane_border_inactive));
    try std.testing.expectEqual(Color.fromHex(0x3f3f46), theme.chromeColor(.selection_background));
    try std.testing.expectEqual(Color.fromHex(0xfafafa), theme.palette[15]);
}

test "built-in theme exposes independently configurable workspace colors" {
    var theme = Theme.builtinDark();
    const selected_before = theme.chromeColor(.pane_border_selected);
    theme.setChromeColor(.scrollbar_thumb, Color.fromHex(0x123456));

    try std.testing.expectEqual(Color.fromHex(0x123456), theme.chromeColor(.scrollbar_thumb));
    try std.testing.expectEqual(selected_before, theme.chromeColor(.pane_border_selected));
}

test "theme preview formats gui-facing summary" {
    const preview = Preview.fromTheme(Theme.builtinDark());
    var buf: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try preview.formatSummary(&writer);
    try std.testing.expectEqualStrings("noctty-dark fg=#d7dde8 bg=#0b0d12 cursor=#8fb8ff palette=16", writer.buffered());
}

test "theme import rejects invalid display names" {
    try std.testing.expectError(error.InvalidThemeName, importTheme(std.testing.allocator, .ghostty, "", "background = #000000"));
    try std.testing.expectError(error.InvalidThemeName, importTheme(std.testing.allocator, .ghostty, "bad/name", "background = #000000"));
}

test "imports xresources theme colors" {
    const imported = try importTheme(std.testing.allocator, .xresources, "xr",
        \\*.background: #010203
        \\*.foreground: #aabbcc
        \\*.color2: #00ff00
    );
    try std.testing.expectEqual(Color.fromHex(0x010203), imported.background);
    try std.testing.expectEqual(Color.fromHex(0xaabbcc), imported.foreground);
    try std.testing.expectEqual(Color.fromHex(0x00ff00), imported.palette[2]);
}

test "imports real Alacritty TOML color sections" {
    const imported = try importTheme(std.testing.allocator, .alacritty_toml, "alacritty",
        \\[colors.primary]
        \\background = "0x101820"
        \\foreground = "#f0f4f8"
        \\
        \\[colors.cursor]
        \\text = "#ffffff"
        \\
        \\[colors.normal]
        \\black = "#000001"
        \\red = "0x000002"
        \\white = "#000008"
        \\
        \\[colors.bright]
        \\black = "#000009"
        \\white = "#000010"
    );
    try std.testing.expectEqual(Color.fromHex(0x101820), imported.background);
    try std.testing.expectEqual(Color.fromHex(0xf0f4f8), imported.foreground);
    try std.testing.expectEqual(Color.fromHex(0xffffff), imported.cursor);
    try std.testing.expectEqual(Color.fromHex(0x000001), imported.palette[0]);
    try std.testing.expectEqual(Color.fromHex(0x000002), imported.palette[1]);
    try std.testing.expectEqual(Color.fromHex(0x000008), imported.palette[7]);
    try std.testing.expectEqual(Color.fromHex(0x000009), imported.palette[8]);
    try std.testing.expectEqual(Color.fromHex(0x000010), imported.palette[15]);
}
