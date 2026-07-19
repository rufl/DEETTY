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

pub const Theme = struct {
    name: []const u8,
    foreground: Color,
    background: Color,
    cursor: Color,
    palette: [16]Color,

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
        };
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
    var s = std.mem.trim(u8, raw, " \t'\"");
    if (s.len > 0 and s[0] == '#') s = s[1..];
    if (s.len != 6) return error.InvalidColor;
    const value = try std.fmt.parseInt(u24, s, 16);
    return Color.fromHex(value);
}

pub fn formatColor(color: Color, writer: anytype) !void {
    try writer.print("#{x:0>2}{x:0>2}{x:0>2}", .{ color.r, color.g, color.b });
}

pub fn importTheme(format: ImportFormat, name: []const u8, contents: []const u8) !Theme {
    try validateName(name);
    var theme = Theme.builtinDark();
    theme.name = name;

    var it = std.mem.splitScalar(u8, contents, '\n');
    while (it.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        switch (format) {
            .ghostty => applyGhosttyLine(&theme, line) catch {},
            .xresources => applyXresourcesLine(&theme, line) catch {},
            .alacritty_toml => applyAlacrittyLine(&theme, line) catch {},
        }
    }

    return theme;
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

fn applyAlacrittyLine(theme: *Theme, line: []const u8) !void {
    const eq = std.mem.indexOfScalar(u8, line, '=') orelse return;
    const key = std.mem.trim(u8, line[0..eq], " \t");
    const value = std.mem.trim(u8, line[eq + 1 ..], " \t");
    if (std.mem.eql(u8, key, "background")) {
        theme.background = try parseHexColor(value);
    } else if (std.mem.eql(u8, key, "foreground")) {
        theme.foreground = try parseHexColor(value);
    } else if (std.mem.eql(u8, key, "cursor")) {
        theme.cursor = try parseHexColor(value);
    }
}

test "imports ghostty theme colors" {
    const imported = try importTheme(.ghostty, "sample",
        \\background = #000011
        \\foreground = #eeeeee
        \\cursor-color = #ff00aa
        \\palette = 1=#cc0000
    );
    try std.testing.expectEqual(Color.fromHex(0x000011), imported.background);
    try std.testing.expectEqual(Color.fromHex(0xeeeeee), imported.foreground);
    try std.testing.expectEqual(Color.fromHex(0xff00aa), imported.cursor);
    try std.testing.expectEqual(Color.fromHex(0xcc0000), imported.palette[1]);
}

test "theme preview formats gui-facing summary" {
    const preview = Preview.fromTheme(Theme.builtinDark());
    var buf: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try preview.formatSummary(&writer);
    try std.testing.expectEqualStrings("noctty-dark fg=#d7dde8 bg=#0b0d12 cursor=#8fb8ff palette=16", writer.buffered());
}

test "theme import rejects invalid display names" {
    try std.testing.expectError(error.InvalidThemeName, importTheme(.ghostty, "", "background = #000000"));
    try std.testing.expectError(error.InvalidThemeName, importTheme(.ghostty, "bad/name", "background = #000000"));
}

test "imports xresources theme colors" {
    const imported = try importTheme(.xresources, "xr",
        \\*.background: #010203
        \\*.foreground: #aabbcc
        \\*.color2: #00ff00
    );
    try std.testing.expectEqual(Color.fromHex(0x010203), imported.background);
    try std.testing.expectEqual(Color.fromHex(0xaabbcc), imported.foreground);
    try std.testing.expectEqual(Color.fromHex(0x00ff00), imported.palette[2]);
}
