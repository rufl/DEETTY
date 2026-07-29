const std = @import("std");
const TextBuffer = @import("TextBuffer.zig");
const core = @import("tree_sitter");

pub const Language = core.Language;
pub const Edit = core.Edit;

pub const Document = struct {
    raw: core.Document,
    language: Language,

    pub fn init(language: Language) !Document {
        return .{
            .raw = try core.Document.init(language),
            .language = language,
        };
    }

    pub fn deinit(self: *Document) void {
        self.raw.deinit();
        self.* = undefined;
    }

    pub fn update(self: *Document, source: []const u8, edit: ?Edit) !void {
        try self.raw.update(source, edit);
    }

    pub fn highlight(
        self: *Document,
        allocator: std.mem.Allocator,
        max_spans: usize,
    ) !TextBuffer.SyntaxHighlightSummary {
        _ = allocator;
        const bounded = @min(max_spans, TextBuffer.max_syntax_highlight_spans);
        var captures: [TextBuffer.max_syntax_highlight_spans]core.Capture = undefined;
        const total = try self.raw.collectCaptures(captures[0..bounded]);
        var summary = TextBuffer.SyntaxHighlightSummary{
            .language = switch (self.language) {
                .json => .json,
                .c => .c,
                .shell => .shell,
                .markdown => .markdown,
                .zig => .zig,
            },
            .max_spans = bounded,
            .total_spans = total,
        };
        summary.span_count = @min(total, bounded);
        for (captures[0..summary.span_count], 0..) |capture, index| {
            summary.spans[index] = .{
                .start = capture.start,
                .end = capture.end,
                .kind = kindForScope(capture.scope),
            };
        }
        return summary;
    }
};

pub fn highlight(
    language: Language,
    source: []const u8,
    allocator: std.mem.Allocator,
    max_spans: usize,
) !TextBuffer.SyntaxHighlightSummary {
    var document = try Document.init(language);
    defer document.deinit();
    try document.update(source, null);
    return document.highlight(allocator, max_spans);
}

fn kindForScope(scope: core.Scope) TextBuffer.SyntaxTokenKind {
    return switch (scope) {
        .comment => .comment,
        .heading => .heading,
        .code_fence => .code_fence,
        .string => .string,
        .number => .number,
        .constant => .literal,
        else => .keyword,
    };
}

test "tree-sitter JSON highlights and incrementally updates" {
    var document = try Document.init(.json);
    defer document.deinit();
    const first = "{\"ok\": true}";
    try document.update(first, null);
    const initial = try document.highlight(std.testing.failing_allocator, 16);
    try std.testing.expect(initial.total_spans >= 2);
    const edit = Edit{
        .start_byte = 8,
        .old_end_byte = 12,
        .new_end_byte = 13,
        .start_row = 0,
        .old_end_row = 0,
        .new_end_row = 0,
        .start_column = 8,
        .old_end_column = 12,
        .new_end_column = 13,
    };
    try document.update("{\"ok\": false}", edit);
    const updated = try document.highlight(std.testing.allocator, 16);
    try std.testing.expect(updated.total_spans >= 2);
}

fn expectInitialLanguageCapture(language: Language, source: []const u8) !void {
    const summary = try highlight(language, source, std.testing.allocator, 32);
    try std.testing.expect(summary.total_spans > 0);
}

test "tree-sitter initial C captures" {
    try expectInitialLanguageCapture(.c, "const int value = 42;");
}

test "tree-sitter initial shell captures" {
    try expectInitialLanguageCapture(.shell, "if true; then echo \"ok\"; fi");
}

test "tree-sitter shell comments use the comment scope" {
    var document = try Document.init(.shell);
    defer document.deinit();
    try document.update("# note\n", null);
    var captures: [8]core.Capture = undefined;
    const total = try document.raw.collectCaptures(&captures);
    for (captures[0..@min(total, captures.len)]) |capture| {
        if (capture.scope == .comment) return;
    }
    return error.MissingCommentCapture;
}

test "tree-sitter initial Markdown captures" {
    try expectInitialLanguageCapture(.markdown, "# Heading\n\n```zig\nconst x = 1;\n```");
}

test "tree-sitter initial Zig captures" {
    try expectInitialLanguageCapture(.zig, "pub fn main() void { return; }");
}

test "tree-sitter capture points retain UTF-8 byte columns" {
    var document = try Document.init(.json);
    defer document.deinit();
    try document.update("{\"é\": 1}", null);
    var captures: [8]core.Capture = undefined;
    const total = try document.raw.collectCaptures(&captures);
    const count = @min(total, captures.len);
    for (captures[0..count]) |capture| {
        if (capture.scope != .string) continue;
        try std.testing.expectEqual(
            core.Point{ .row = 0, .column = 1 },
            capture.start_point,
        );
        try std.testing.expectEqual(
            core.Point{ .row = 0, .column = 5 },
            capture.end_point,
        );
        return;
    }
    return error.MissingStringCapture;
}
