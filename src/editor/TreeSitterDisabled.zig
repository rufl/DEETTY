const std = @import("std");
const TextBuffer = @import("TextBuffer.zig");

pub const Language = enum(c_int) {
    json = 1,
    c = 2,
    shell = 3,
    markdown = 4,
    zig = 5,
};

pub const Edit = extern struct {
    start_byte: usize,
    old_end_byte: usize,
    new_end_byte: usize,
    start_row: u32,
    start_column: u32,
    old_end_row: u32,
    old_end_column: u32,
    new_end_row: u32,
    new_end_column: u32,
};

pub const Document = struct {
    language: Language,

    pub fn init(language: Language) !Document {
        _ = language;
        return error.ParserUnavailable;
    }

    pub fn deinit(self: *Document) void {
        self.* = undefined;
    }

    pub fn update(self: *Document, source: []const u8, edit: ?Edit) !void {
        _ = self;
        _ = source;
        _ = edit;
        return error.ParserUnavailable;
    }

    pub fn highlight(
        self: Document,
        allocator: std.mem.Allocator,
        max_spans: usize,
    ) !TextBuffer.SyntaxHighlightSummary {
        _ = self;
        _ = allocator;
        _ = max_spans;
        return error.ParserUnavailable;
    }
};

pub fn highlight(
    language: Language,
    source: []const u8,
    allocator: std.mem.Allocator,
    max_spans: usize,
) !TextBuffer.SyntaxHighlightSummary {
    _ = language;
    _ = source;
    _ = allocator;
    _ = max_spans;
    return error.ParserUnavailable;
}
