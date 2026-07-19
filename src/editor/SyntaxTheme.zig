const std = @import("std");
const Theme = @import("../theme/Theme.zig");
const TextBuffer = @import("TextBuffer.zig");

pub const max_rules: usize = 64;
pub const max_scope_bytes: usize = 96;

pub const FontStyle = struct {
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
};

pub const Style = struct {
    foreground: ?Theme.Color = null,
    background: ?Theme.Color = null,
    font: FontStyle = .{},
};

pub const Rule = struct {
    scope: [max_scope_bytes]u8 = undefined,
    scope_len: usize = 0,
    style: Style,

    fn scopeSlice(self: *const Rule) []const u8 {
        return self.scope[0..self.scope_len];
    }
};

pub const SyntaxTheme = struct {
    name: []const u8 = "noctty-syntax-default",
    foreground: Theme.Color = Theme.Color.fromHex(0xd7dde8),
    background: Theme.Color = Theme.Color.fromHex(0x0b0d12),
    rules: [max_rules]Rule = undefined,
    rule_count: usize = 0,

    pub fn default() SyntaxTheme {
        var theme = SyntaxTheme{};
        theme.append("comment", .{ .foreground = Theme.Color.fromHex(0x7f8a9c), .font = .{ .italic = true } });
        theme.append("string", .{ .foreground = Theme.Color.fromHex(0x9ece6a) });
        theme.append("constant.numeric", .{ .foreground = Theme.Color.fromHex(0xffc777) });
        theme.append("constant.language", .{ .foreground = Theme.Color.fromHex(0xe0af68) });
        theme.append("keyword", .{ .foreground = Theme.Color.fromHex(0xbb9af7) });
        theme.append("entity.name.function", .{ .foreground = Theme.Color.fromHex(0x8fb8ff) });
        theme.append("entity.name.type", .{ .foreground = Theme.Color.fromHex(0x7dcfff) });
        theme.append("invalid", .{ .foreground = Theme.Color.fromHex(0xf7768e), .font = .{ .underline = true } });
        return theme;
    }

    pub fn named(name: []const u8) SyntaxTheme {
        var theme = SyntaxTheme.default();
        theme.name = name;
        if (std.mem.eql(u8, name, "noctty-syntax-high-contrast")) {
            theme.foreground = Theme.Color.fromHex(0xffffff);
            theme.background = Theme.Color.fromHex(0x000000);
            theme.append("keyword", .{ .foreground = Theme.Color.fromHex(0xffff00), .font = .{ .bold = true } });
            theme.append("string", .{ .foreground = Theme.Color.fromHex(0x00ff99) });
            theme.append("comment", .{ .foreground = Theme.Color.fromHex(0xb0b0b0), .font = .{ .italic = true } });
        }
        return theme;
    }

    pub fn append(self: *SyntaxTheme, scope: []const u8, style: Style) void {
        if (self.rule_count >= max_rules or scope.len == 0 or scope.len > max_scope_bytes) return;
        var rule = Rule{ .style = style, .scope_len = scope.len };
        @memcpy(rule.scope[0..scope.len], scope);
        self.rules[self.rule_count] = rule;
        self.rule_count += 1;
    }

    pub fn resolve(self: SyntaxTheme, scope: []const u8) Style {
        var best: ?Style = null;
        var best_specificity: usize = 0;
        for (self.rules[0..self.rule_count]) |*rule| {
            var scopes = std.mem.splitScalar(u8, rule.scopeSlice(), ',');
            while (scopes.next()) |candidate_raw| {
                const candidate = std.mem.trim(u8, candidate_raw, " \t\r\n");
                if (candidate.len == 0 or !scopeMatches(candidate, scope)) continue;
                if (candidate.len >= best_specificity) {
                    best = rule.style;
                    best_specificity = candidate.len;
                }
            }
        }
        return best orelse .{};
    }
};

pub fn scopeForToken(kind: TextBuffer.SyntaxTokenKind) []const u8 {
    return (TextBuffer.SyntaxHighlightSpan{ .start = 0, .end = 0, .kind = kind }).textMateScope();
}

pub fn importTokenColors(name: []const u8, contents: []const u8) !SyntaxTheme {
    return importTokenColorsAlloc(std.heap.page_allocator, name, contents);
}

pub fn importTokenColorsAlloc(allocator: std.mem.Allocator, name: []const u8, contents: []const u8) !SyntaxTheme {
    var theme = SyntaxTheme.default();
    theme.name = name;
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch {
        return error.InvalidSyntaxTheme;
    };
    defer parsed.deinit();
    const root = parsed.value.object;
    if (root.get("colors")) |colors| {
        if (colors.object.get("editor.foreground")) |value| theme.foreground = try parseColorValue(value);
        if (colors.object.get("editor.background")) |value| theme.background = try parseColorValue(value);
    }
    if (root.get("tokenColors")) |token_colors| {
        for (token_colors.array.items) |entry| {
            const object = entry.object;
            const scope_value = object.get("scope") orelse continue;
            const scope = switch (scope_value) {
                .string => |value| value,
                else => continue,
            };
            const settings = object.get("settings") orelse continue;
            var style = Style{};
            if (settings.object.get("foreground")) |value| style.foreground = parseColorValue(value) catch null;
            if (settings.object.get("background")) |value| style.background = parseColorValue(value) catch null;
            if (settings.object.get("fontStyle")) |value| {
                if (value == .string) style.font = parseFontStyle(value.string);
            }
            theme.append(scope, style);
        }
    }
    return theme;
}

fn parseColorValue(value: std.json.Value) !Theme.Color {
    return switch (value) {
        .string => |raw| Theme.parseHexColor(raw),
        else => error.InvalidColor,
    };
}

fn parseFontStyle(raw: []const u8) FontStyle {
    var style = FontStyle{};
    var it = std.mem.splitScalar(u8, raw, ' ');
    while (it.next()) |token| {
        if (std.mem.eql(u8, token, "bold")) style.bold = true;
        if (std.mem.eql(u8, token, "italic")) style.italic = true;
        if (std.mem.eql(u8, token, "underline")) style.underline = true;
    }
    return style;
}

fn scopeMatches(rule: []const u8, actual: []const u8) bool {
    return std.mem.eql(u8, rule, actual) or
        (actual.len > rule.len and std.mem.startsWith(u8, actual, rule) and actual[rule.len] == '.');
}

test "canonical token scopes resolve from most specific rule" {
    var theme = SyntaxTheme.default();
    theme.append("entity.name", .{ .foreground = Theme.Color.fromHex(0x111111) });
    theme.append("entity.name.function", .{ .foreground = Theme.Color.fromHex(0x222222) });
    try std.testing.expectEqual(Theme.Color.fromHex(0x222222), theme.resolve("entity.name.function.builtin").foreground.?);
    try std.testing.expectEqualStrings("constant.numeric", scopeForToken(.number));
}

test "imports VS Code tokenColors and editor globals" {
    const source = "{\"colors\":{\"editor.foreground\":\"#eeeeee\",\"editor.background\":\"#101010\"}," ++
        "\"tokenColors\":[{\"scope\":\"keyword.control\",\"settings\":{\"foreground\":\"#c792ea\",\"fontStyle\":\"bold\"}}," ++
        "{\"scope\":\"comment\",\"settings\":{\"foreground\":\"#777777\",\"fontStyle\":\"italic\"}}]}";
    const theme = try importTokenColorsAlloc(std.testing.allocator, "sample", source);
    try std.testing.expectEqual(Theme.Color.fromHex(0x101010), theme.background);
    try std.testing.expect(theme.resolve("keyword.control.if").font.bold);
    try std.testing.expect(theme.resolve("comment.line").font.italic);
}
