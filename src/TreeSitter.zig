const std = @import("std");

const c = @import("c");

extern fn tree_sitter_json() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_c() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_bash() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_markdown() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_zig() callconv(.c) *const c.TSLanguage;

const max_query_captures = 16;

pub const Language = enum(u8) {
    json,
    c,
    shell,
    markdown,
    zig,
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

pub const Point = struct {
    row: u32,
    column: u32,
};

pub const Capture = struct {
    start: u32,
    end: u32,
    start_point: Point,
    end_point: Point,
    scope: Scope,
};

pub const Edit = struct {
    start_byte: u32,
    old_end_byte: u32,
    new_end_byte: u32,
    start_row: u32,
    start_column: u32,
    old_end_row: u32,
    old_end_column: u32,
    new_end_row: u32,
    new_end_column: u32,
};

pub const Document = struct {
    parser: *c.TSParser,
    tree: ?*c.TSTree = null,
    query: *c.TSQuery,
    cursor: *c.TSQueryCursor,
    capture_scopes: [max_query_captures]Scope,

    pub fn init(language: Language) !Document {
        const ts_language = languageFor(language);
        const query_source = queryFor(language);
        const parser = c.ts_parser_new() orelse return error.ParserUnavailable;
        errdefer c.ts_parser_delete(parser);
        if (!c.ts_parser_set_language(parser, ts_language))
            return error.ParserUnavailable;

        var error_offset: u32 = 0;
        var error_type: c.TSQueryError = c.TSQueryErrorNone;
        const query = c.ts_query_new(
            ts_language,
            query_source.ptr,
            @intCast(query_source.len),
            &error_offset,
            &error_type,
        ) orelse return error.QueryUnavailable;
        errdefer c.ts_query_delete(query);
        if (error_type != c.TSQueryErrorNone) return error.QueryUnavailable;

        const cursor = c.ts_query_cursor_new() orelse return error.QueryUnavailable;
        errdefer c.ts_query_cursor_delete(cursor);

        const capture_count = c.ts_query_capture_count(query);
        if (capture_count > max_query_captures) return error.QueryUnavailable;
        var capture_scopes: [max_query_captures]Scope = @splat(.keyword);
        for (0..capture_count) |index| {
            var name_length: u32 = 0;
            const name_ptr = c.ts_query_capture_name_for_id(
                query,
                @intCast(index),
                &name_length,
            );
            if (name_ptr != null)
                capture_scopes[index] = scopeFor(name_ptr[0..name_length]);
        }

        return .{
            .parser = parser,
            .query = query,
            .cursor = cursor,
            .capture_scopes = capture_scopes,
        };
    }

    pub fn deinit(self: *Document) void {
        if (self.tree) |tree| c.ts_tree_delete(tree);
        c.ts_query_cursor_delete(self.cursor);
        c.ts_query_delete(self.query);
        c.ts_parser_delete(self.parser);
        self.* = undefined;
    }

    pub fn update(self: *Document, source: []const u8, edit: ?Edit) !void {
        if (source.len > std.math.maxInt(u32)) return error.SourceTooLarge;
        if (self.tree) |tree| {
            if (edit) |value| {
                var input = c.TSInputEdit{
                    .start_byte = value.start_byte,
                    .old_end_byte = value.old_end_byte,
                    .new_end_byte = value.new_end_byte,
                    .start_point = .{ .row = value.start_row, .column = value.start_column },
                    .old_end_point = .{ .row = value.old_end_row, .column = value.old_end_column },
                    .new_end_point = .{ .row = value.new_end_row, .column = value.new_end_column },
                };
                c.ts_tree_edit(tree, &input);
            }
        }
        const previous = if (edit != null) self.tree else null;
        const next = c.ts_parser_parse_string(
            self.parser,
            previous,
            source.ptr,
            @intCast(source.len),
        ) orelse return error.ParseFailed;
        if (self.tree) |tree| c.ts_tree_delete(tree);
        self.tree = next;
    }

    pub fn collectCaptures(self: *Document, captures: []Capture) !usize {
        const tree = self.tree orelse return error.ParseFailed;
        c.ts_query_cursor_exec(self.cursor, self.query, c.ts_tree_root_node(tree));
        var total: usize = 0;
        var match: c.TSQueryMatch = undefined;
        var capture_index: u32 = 0;
        while (c.ts_query_cursor_next_capture(self.cursor, &match, &capture_index)) {
            const raw = match.captures[capture_index];
            if (total < captures.len) {
                const start = c.ts_node_start_point(raw.node);
                const end = c.ts_node_end_point(raw.node);
                captures[total] = .{
                    .start = c.ts_node_start_byte(raw.node),
                    .end = c.ts_node_end_byte(raw.node),
                    .start_point = .{ .row = start.row, .column = start.column },
                    .end_point = .{ .row = end.row, .column = end.column },
                    .scope = if (raw.index < max_query_captures)
                        self.capture_scopes[raw.index]
                    else
                        .keyword,
                };
            }
            total += 1;
        }
        return total;
    }
};

fn languageFor(language: Language) *const c.TSLanguage {
    return switch (language) {
        .json => tree_sitter_json(),
        .c => tree_sitter_c(),
        .shell => tree_sitter_bash(),
        .markdown => tree_sitter_markdown(),
        .zig => tree_sitter_zig(),
    };
}

fn queryFor(language: Language) []const u8 {
    return switch (language) {
        .json => "(string) @string (number) @number (null) @constant " ++
            "(true) @constant (false) @constant (comment) @comment",
        .c => "(comment) @comment (string_literal) @string (number_literal) @number " ++
            "(identifier) @variable (type_identifier) @type " ++
            "(function_declarator declarator: (identifier) @function) " ++
            "[\"if\" \"else\" \"for\" \"while\" \"return\" \"struct\" \"typedef\" \"const\"] @keyword",
        .shell => "(comment) @comment [(string) (raw_string) (heredoc_body)] @string " ++
            "(command_name) @function (variable_name) @property " ++
            "[\"case\" \"do\" \"done\" \"elif\" \"else\" \"fi\" \"for\" \"function\" \"if\" \"in\" \"then\" \"while\"] @keyword",
        .markdown => "(atx_heading) @heading (setext_heading) @heading " ++
            "(fenced_code_block) @code_fence (indented_code_block) @code_fence " ++
            "(block_quote) @comment",
        .zig => "(line_comment) @comment (doc_comment) @comment " ++
            "(string_literal) @string (string_literal_single) @string " ++
            "(integer) @number (float) @number (identifier) @variable",
    };
}

fn scopeFor(name: []const u8) Scope {
    const info = @typeInfo(Scope).@"enum";
    inline for (info.field_names, info.field_values) |field_name, field_value| {
        if (std.mem.eql(u8, name, field_name)) return @fromBackingInt(@intCast(field_value));
    }
    return .keyword;
}
