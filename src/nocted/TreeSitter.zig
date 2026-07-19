const std = @import("std");

const c = @cImport({
    @cInclude("tree_sitter_adapter.h");
});

pub const max_captures: usize = 4096;

pub const Language = enum(c_int) {
    json = 1,
    c = 2,
    shell = 3,
    markdown = 4,
    zig = 5,
};

pub const Scope = enum {
    comment,
    string,
    number,
    constant,
    keyword,
    function,
    property,
    type,
    heading,
    code_fence,
    variable,
};

pub const Capture = struct {
    start: u32,
    end: u32,
    scope: Scope,
};

pub const Document = struct {
    raw: *c.NocttyTreeSitterDocument,
    language: Language,

    pub fn init(language: Language) !Document {
        return .{
            .raw = c.noctty_tree_sitter_document_new(@intFromEnum(language)) orelse
                return error.ParserUnavailable,
            .language = language,
        };
    }

    pub fn deinit(self: *Document) void {
        c.noctty_tree_sitter_document_free(self.raw);
        self.* = undefined;
    }

    pub fn update(self: *Document, source: []const u8) !void {
        if (c.noctty_tree_sitter_document_update(
            self.raw,
            source.ptr,
            source.len,
            null,
        ) != 0) return error.ParseFailed;
    }

    pub fn capturesAlloc(
        self: *Document,
        allocator: std.mem.Allocator,
    ) ![]Capture {
        const raw = try allocator.alloc(c.NocttyTreeSitterCapture, max_captures);
        defer allocator.free(raw);
        var total: usize = 0;
        if (c.noctty_tree_sitter_document_highlight(
            self.raw,
            raw.ptr,
            raw.len,
            &total,
        ) != 0) return error.HighlightFailed;
        const count = @min(total, raw.len);
        const captures = try allocator.alloc(Capture, count);
        for (raw[0..count], captures) |source, *capture| {
            capture.* = .{
                .start = source.start,
                .end = source.end,
                .scope = scopeFor(std.mem.sliceTo(source.scope[0..], 0)),
            };
        }
        std.mem.sort(Capture, captures, {}, struct {
            fn lessThan(_: void, lhs: Capture, rhs: Capture) bool {
                return lhs.start < rhs.start;
            }
        }.lessThan);
        return captures;
    }
};

pub fn languageForPath(path: []const u8) ?Language {
    const extension = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(extension, ".zig")) return .zig;
    if (std.ascii.eqlIgnoreCase(extension, ".json")) return .json;
    if (std.ascii.eqlIgnoreCase(extension, ".c") or
        std.ascii.eqlIgnoreCase(extension, ".h")) return .c;
    if (std.ascii.eqlIgnoreCase(extension, ".sh") or
        std.ascii.eqlIgnoreCase(extension, ".bash")) return .shell;
    if (std.ascii.eqlIgnoreCase(extension, ".md") or
        std.ascii.eqlIgnoreCase(extension, ".markdown")) return .markdown;
    return null;
}

fn scopeFor(scope: []const u8) Scope {
    if (std.mem.startsWith(u8, scope, "comment")) return .comment;
    if (std.mem.startsWith(u8, scope, "string")) return .string;
    if (std.mem.startsWith(u8, scope, "number")) return .number;
    if (std.mem.startsWith(u8, scope, "constant")) return .constant;
    if (std.mem.startsWith(u8, scope, "function")) return .function;
    if (std.mem.startsWith(u8, scope, "property")) return .property;
    if (std.mem.startsWith(u8, scope, "type")) return .type;
    if (std.mem.startsWith(u8, scope, "heading")) return .heading;
    if (std.mem.startsWith(u8, scope, "code_fence")) return .code_fence;
    if (std.mem.startsWith(u8, scope, "variable")) return .variable;
    return .keyword;
}
