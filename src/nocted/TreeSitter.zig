const std = @import("std");
const core = @import("tree_sitter");

pub const max_captures: usize = 4096;

pub const Language = core.Language;
pub const Scope = core.Scope;
pub const Capture = core.Capture;

pub const Document = struct {
    raw: core.Document,
    language: Language,
    capture_buffer: []Capture = &.{},

    pub fn init(language: Language) !Document {
        return .{
            .raw = try core.Document.init(language),
            .language = language,
        };
    }

    pub fn deinit(self: *Document, allocator: std.mem.Allocator) void {
        if (self.capture_buffer.len != 0) allocator.free(self.capture_buffer);
        self.raw.deinit();
        self.* = undefined;
    }

    pub fn update(self: *Document, source: []const u8) !void {
        try self.raw.update(source, null);
    }

    pub fn captures(self: *Document, allocator: std.mem.Allocator) ![]Capture {
        if (self.capture_buffer.len == 0)
            self.capture_buffer = try allocator.alloc(Capture, max_captures);
        const total = try self.raw.collectCaptures(self.capture_buffer);
        if (total > self.capture_buffer.len) return error.TreeSitterCaptureLimitExceeded;
        const slice = self.capture_buffer[0..total];
        std.mem.sort(Capture, slice, {}, struct {
            fn lessThan(_: void, lhs: Capture, rhs: Capture) bool {
                return lhs.start < rhs.start;
            }
        }.lessThan);
        return slice;
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
