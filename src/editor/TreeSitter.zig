const std = @import("std");
const TextBuffer = @import("TextBuffer.zig");

const c = @cImport({
    @cInclude("tree_sitter_adapter.h");
});

pub const Language = enum(c_int) {
    json = 1,
    c = 2,
    shell = 3,
    markdown = 4,
    zig = 5,
};

pub const Edit = c.NocttyTreeSitterEdit;

pub const Document = struct {
    raw: *c.NocttyTreeSitterDocument,
    language: Language,

    pub fn init(language: Language) !Document {
        return .{ .raw = c.noctty_tree_sitter_document_new(@intFromEnum(language)) orelse return error.ParserUnavailable, .language = language };
    }

    pub fn deinit(self: *Document) void {
        c.noctty_tree_sitter_document_free(self.raw);
        self.* = undefined;
    }

    pub fn update(self: *Document, source: []const u8, edit: ?Edit) !void {
        if (c.noctty_tree_sitter_document_update(self.raw, source.ptr, source.len, if (edit) |value| &value else null) != 0)
            return error.ParseFailed;
    }

    pub fn highlight(self: Document, allocator: std.mem.Allocator, max_spans: usize) !TextBuffer.SyntaxHighlightSummary {
        _ = allocator;
        const bounded = @min(max_spans, TextBuffer.max_syntax_highlight_spans);
        var captures: [TextBuffer.max_syntax_highlight_spans]c.NocttyTreeSitterCapture = undefined;
        var total: usize = 0;
        if (c.noctty_tree_sitter_document_highlight(self.raw, &captures, bounded, &total) != 0)
            return error.HighlightFailed;
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
            const scope = std.mem.sliceTo(capture.scope[0..], 0);
            summary.spans[index] = .{
                .start = capture.start,
                .end = capture.end,
                .kind = kindForScope(scope),
            };
        }
        return summary;
    }
};

pub fn highlight(language: Language, source: []const u8, allocator: std.mem.Allocator, max_spans: usize) !TextBuffer.SyntaxHighlightSummary {
    var document = try Document.init(language);
    defer document.deinit();
    try document.update(source, null);
    return document.highlight(allocator, max_spans);
}

fn kindForScope(scope: []const u8) TextBuffer.SyntaxTokenKind {
    if (std.mem.startsWith(u8, scope, "comment")) return .comment;
    if (std.mem.startsWith(u8, scope, "heading")) return .heading;
    if (std.mem.startsWith(u8, scope, "code_fence")) return .code_fence;
    if (std.mem.startsWith(u8, scope, "string")) return .string;
    if (std.mem.startsWith(u8, scope, "number")) return .number;
    if (std.mem.startsWith(u8, scope, "constant")) return .literal;
    if (std.mem.startsWith(u8, scope, "keyword")) return .keyword;
    return .keyword;
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

test "tree-sitter initial Markdown captures" {
    try expectInitialLanguageCapture(.markdown, "# Heading\n\n```zig\nconst x = 1;\n```");
}

test "tree-sitter initial Zig captures" {
    try expectInitialLanguageCapture(.zig, "pub fn main() void { return; }");
}
