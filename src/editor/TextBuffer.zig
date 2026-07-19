const std = @import("std");

pub const Language = enum {
    plain_text,
    zig,
    c,
    cpp,
    rust,
    python,
    javascript,
    typescript,
    json,
    markdown,
    shell,
    toml,
    yaml,

    pub fn label(self: Language) []const u8 {
        return switch (self) {
            .plain_text => "Plain text",
            .zig => "Zig",
            .c => "C",
            .cpp => "C++",
            .rust => "Rust",
            .python => "Python",
            .javascript => "JavaScript",
            .typescript => "TypeScript",
            .json => "JSON",
            .markdown => "Markdown",
            .shell => "Shell",
            .toml => "TOML",
            .yaml => "YAML",
        };
    }
};

pub const Cursor = struct {
    offset: usize,
};

pub const Selection = struct {
    anchor: Cursor,
    active: Cursor,

    pub fn start(self: Selection) usize {
        return @min(self.anchor.offset, self.active.offset);
    }

    pub fn end(self: Selection) usize {
        return @max(self.anchor.offset, self.active.offset);
    }
};

pub const TextEdit = struct {
    start: usize,
    end: usize,
    replacement: []const u8,
};

pub const OwnedTextEdit = struct {
    start: usize = 0,
    end: usize = 0,
    replacement: []u8 = &.{},

    pub fn deinit(self: *OwnedTextEdit, allocator: std.mem.Allocator) void {
        allocator.free(self.replacement);
        self.* = .{};
    }

    fn borrowed(self: OwnedTextEdit) TextEdit {
        return .{
            .start = self.start,
            .end = self.end,
            .replacement = self.replacement,
        };
    }
};

const EditTransaction = struct {
    undo: []OwnedTextEdit = &.{},
    redo: []OwnedTextEdit = &.{},

    fn fromEdits(allocator: std.mem.Allocator, original: []const u8, edits_raw: []const TextEdit) !EditTransaction {
        const edits = try allocator.dupe(TextEdit, edits_raw);
        defer allocator.free(edits);
        try validateAndSortEdits(edits, original.len);

        var transaction = EditTransaction{
            .undo = try allocator.alloc(OwnedTextEdit, edits.len),
            .redo = try allocator.alloc(OwnedTextEdit, edits.len),
        };
        for (transaction.undo) |*edit| edit.* = .{};
        for (transaction.redo) |*edit| edit.* = .{};
        errdefer transaction.deinit(allocator);

        var source_cursor: usize = 0;
        var post_cursor: usize = 0;
        for (edits, 0..) |edit, idx| {
            post_cursor = try std.math.add(usize, post_cursor, edit.start - source_cursor);
            transaction.redo[idx] = try cloneOwnedTextEdit(allocator, edit);
            transaction.undo[idx] = .{
                .start = post_cursor,
                .end = try std.math.add(usize, post_cursor, edit.replacement.len),
                .replacement = try allocator.dupe(u8, original[edit.start..edit.end]),
            };
            post_cursor = transaction.undo[idx].end;
            source_cursor = edit.end;
        }

        return transaction;
    }

    fn deinit(self: *EditTransaction, allocator: std.mem.Allocator) void {
        for (self.undo) |*edit| edit.deinit(allocator);
        allocator.free(self.undo);
        for (self.redo) |*edit| edit.deinit(allocator);
        allocator.free(self.redo);
        self.* = .{};
    }
};

pub const SearchOptions = struct {
    case_sensitive: bool = true,
    max_results: usize = std.math.maxInt(usize),
};

pub const SearchMatch = struct {
    start: usize,
    end: usize,
    line: usize,
    column: usize,
};

const LineColumn = struct {
    line: usize,
    column: usize,
};

pub const max_editor_find_matches: usize = 64;
pub const max_editor_undo_transactions: usize = 128;
pub const max_editor_undo_bytes: usize = 4 * 1024 * 1024;

pub const EditorFindDirection = enum {
    forward,
    backward,
};

pub const EditorFindRequest = struct {
    path: []const u8,
    contents: []const u8,
    query: []const u8,
    case_sensitive: bool = true,
    whole_word: bool = false,
    cursor_offset: usize = 0,
    direction: EditorFindDirection = .forward,
    wrap: bool = true,
    max_matches: usize = max_editor_find_matches,
};

pub const EditorFindSummary = struct {
    language: Language,
    query_len: usize,
    case_sensitive: bool,
    whole_word: bool,
    direction: EditorFindDirection,
    wrap_enabled: bool,
    cursor_offset: usize,
    total_matches: usize = 0,
    match_count: usize = 0,
    max_matches: usize = 0,
    current_match_index: ?usize = null,
    current_stored_index: ?usize = null,
    current_match: ?SearchMatch = null,
    wrapped: bool = false,
    matches: [max_editor_find_matches]SearchMatch = undefined,

    pub fn matchSlice(self: *const EditorFindSummary) []const SearchMatch {
        return self.matches[0..self.match_count];
    }

    pub fn truncated(self: EditorFindSummary) bool {
        return self.total_matches > self.match_count;
    }

    pub fn hasCurrent(self: EditorFindSummary) bool {
        return self.current_match != null;
    }
};

pub fn findEditorMatches(request: EditorFindRequest) !EditorFindSummary {
    if (request.path.len == 0) return error.InvalidDocumentPath;
    if (request.query.len == 0) return error.EmptySearchQuery;

    const max_matches = @min(request.max_matches, max_editor_find_matches);
    const cursor_offset = @min(request.cursor_offset, request.contents.len);
    var summary = EditorFindSummary{
        .language = detectLanguage(request.path),
        .query_len = request.query.len,
        .case_sensitive = request.case_sensitive,
        .whole_word = request.whole_word,
        .direction = request.direction,
        .wrap_enabled = request.wrap,
        .cursor_offset = cursor_offset,
        .max_matches = max_matches,
    };

    var first_match: ?SearchMatch = null;
    var first_index: ?usize = null;
    var last_match: ?SearchMatch = null;
    var last_index: ?usize = null;
    var forward_match: ?SearchMatch = null;
    var forward_index: ?usize = null;
    var backward_match: ?SearchMatch = null;
    var backward_index: ?usize = null;

    var idx: usize = 0;
    var line: usize = 1;
    var column: usize = 1;
    while (idx + request.query.len <= request.contents.len) {
        const window = request.contents[idx .. idx + request.query.len];
        if (matchesAt(window, request.query, request.case_sensitive) and
            (!request.whole_word or isWholeWordMatch(request.contents, idx, idx + request.query.len)))
        {
            const match = SearchMatch{
                .start = idx,
                .end = idx + request.query.len,
                .line = line,
                .column = column,
            };
            const match_index = summary.total_matches;
            if (summary.match_count < summary.max_matches) {
                summary.matches[summary.match_count] = match;
                summary.match_count += 1;
            }
            if (first_match == null) {
                first_match = match;
                first_index = match_index;
            }
            last_match = match;
            last_index = match_index;
            if (forward_match == null and match.start >= cursor_offset) {
                forward_match = match;
                forward_index = match_index;
            }
            if (match.start < cursor_offset) {
                backward_match = match;
                backward_index = match_index;
            }
            summary.total_matches += 1;
            advanceLineColumn(request.contents[idx .. idx + request.query.len], &line, &column);
            idx += request.query.len;
        } else {
            advanceLineColumn(request.contents[idx .. idx + 1], &line, &column);
            idx += 1;
        }
    }

    switch (request.direction) {
        .forward => {
            if (forward_match) |match| {
                summary.current_match = match;
                summary.current_match_index = forward_index;
            } else if (request.wrap and first_match != null) {
                summary.current_match = first_match;
                summary.current_match_index = first_index;
                summary.wrapped = true;
            }
        },
        .backward => {
            if (backward_match) |match| {
                summary.current_match = match;
                summary.current_match_index = backward_index;
            } else if (request.wrap and last_match != null) {
                summary.current_match = last_match;
                summary.current_match_index = last_index;
                summary.wrapped = true;
            }
        },
    }

    if (summary.current_match_index) |current_index| {
        if (current_index < summary.match_count) summary.current_stored_index = current_index;
    }

    return summary;
}

pub const max_syntax_highlight_spans: usize = 128;

pub const SyntaxTokenKind = enum {
    keyword,
    string,
    comment,
    number,
    literal,
    heading,
    code_fence,
};

pub const SyntaxHighlightSpan = struct {
    start: usize,
    end: usize,
    kind: SyntaxTokenKind,

    pub fn textMateScope(self: SyntaxHighlightSpan) []const u8 {
        return switch (self.kind) {
            .keyword => "keyword",
            .string => "string",
            .comment => "comment",
            .number => "constant.numeric",
            .literal => "constant.language",
            .heading => "markup.heading",
            .code_fence => "markup.raw.code",
        };
    }
};

pub const SyntaxHighlightOptions = struct {
    max_spans: usize = max_syntax_highlight_spans,
};

pub const SyntaxHighlightRequest = struct {
    path: []const u8,
    contents: []const u8,
    max_spans: usize = max_syntax_highlight_spans,
};

pub const SyntaxHighlightSummary = struct {
    language: Language,
    total_spans: usize = 0,
    span_count: usize = 0,
    max_spans: usize = 0,
    spans: [max_syntax_highlight_spans]SyntaxHighlightSpan = undefined,

    pub fn spanSlice(self: *const SyntaxHighlightSummary) []const SyntaxHighlightSpan {
        return self.spans[0..self.span_count];
    }

    pub fn truncated(self: SyntaxHighlightSummary) bool {
        return self.total_spans > self.span_count;
    }
};

pub fn highlightSyntaxForPath(request: SyntaxHighlightRequest) !SyntaxHighlightSummary {
    if (request.path.len == 0) return error.InvalidDocumentPath;
    return highlightSyntax(detectLanguage(request.path), request.contents, .{ .max_spans = request.max_spans });
}

pub fn highlightSyntax(language: Language, source: []const u8, options: SyntaxHighlightOptions) SyntaxHighlightSummary {
    var summary = SyntaxHighlightSummary{
        .language = language,
        .max_spans = @min(options.max_spans, max_syntax_highlight_spans),
    };

    switch (language) {
        .plain_text => {},
        .markdown => highlightMarkdown(source, &summary),
        else => highlightCodeLike(language, source, &summary),
    }

    return summary;
}

pub const default_editable_byte_limit: usize = 1024 * 1024;
pub const default_preview_byte_limit: usize = 8 * 1024 * 1024;
pub const default_editable_line_limit: usize = 50_000;

pub const EditorOpenMode = enum {
    editable,
    large_read_only,
    metadata_only,
};

pub const EditorOpenReason = enum {
    normal,
    byte_soft_limit,
    byte_hard_limit,
    line_limit,
};

pub const EditorOpenPolicy = struct {
    editable_byte_limit: usize = default_editable_byte_limit,
    preview_byte_limit: usize = default_preview_byte_limit,
    editable_line_limit: usize = default_editable_line_limit,
    allow_large_read_only: bool = true,

    pub fn validate(self: EditorOpenPolicy) !void {
        if (self.editable_byte_limit == 0) return error.InvalidEditorOpenPolicy;
        if (self.preview_byte_limit < self.editable_byte_limit) return error.InvalidEditorOpenPolicy;
        if (self.editable_line_limit == 0) return error.InvalidEditorOpenPolicy;
    }
};

pub const EditorOpenRequest = struct {
    path: []const u8,
    worktree_root: ?[]const u8 = null,
    byte_count: usize,
    line_count: ?usize = null,
};

pub const EditorOpenPlan = struct {
    path: []const u8,
    relative_path: []const u8,
    language: Language,
    mode: EditorOpenMode,
    reason: EditorOpenReason,
    byte_count: usize,
    line_count: ?usize = null,
    can_edit: bool = false,
    loads_buffer: bool = false,
    tracks_undo: bool = false,
    enables_search: bool = false,
    enables_syntax: bool = false,
    requires_confirmation: bool = false,
    warns_large_file: bool = false,

    pub fn canOpen(self: EditorOpenPlan) bool {
        return self.mode != .metadata_only;
    }
};

pub fn planEditorOpen(request: EditorOpenRequest, policy: EditorOpenPolicy) !EditorOpenPlan {
    if (request.path.len == 0) return error.InvalidDocumentPath;
    try policy.validate();

    var mode: EditorOpenMode = .editable;
    var reason: EditorOpenReason = .normal;

    if (request.byte_count > policy.preview_byte_limit) {
        mode = .metadata_only;
        reason = .byte_hard_limit;
    } else if (request.byte_count > policy.editable_byte_limit) {
        mode = if (policy.allow_large_read_only) .large_read_only else .metadata_only;
        reason = .byte_soft_limit;
    } else if (request.line_count) |lines| {
        if (lines > policy.editable_line_limit) {
            mode = if (policy.allow_large_read_only) .large_read_only else .metadata_only;
            reason = .line_limit;
        }
    }

    return .{
        .path = request.path,
        .relative_path = relativePathFor(request.path, request.worktree_root),
        .language = detectLanguage(request.path),
        .mode = mode,
        .reason = reason,
        .byte_count = request.byte_count,
        .line_count = request.line_count,
        .can_edit = mode == .editable,
        .loads_buffer = mode != .metadata_only,
        .tracks_undo = mode == .editable,
        .enables_search = mode != .metadata_only,
        .enables_syntax = mode == .editable,
        .requires_confirmation = mode == .metadata_only,
        .warns_large_file = mode != .editable,
    };
}

pub const TextBuffer = struct {
    allocator: std.mem.Allocator,
    text: std.array_list.Managed(u8),
    selections: std.array_list.Managed(Selection),

    pub fn init(allocator: std.mem.Allocator) TextBuffer {
        return .{
            .allocator = allocator,
            .text = std.array_list.Managed(u8).init(allocator),
            .selections = std.array_list.Managed(Selection).init(allocator),
        };
    }

    pub fn initFromSlice(allocator: std.mem.Allocator, contents: []const u8) !TextBuffer {
        var self = TextBuffer.init(allocator);
        try self.text.appendSlice(contents);
        return self;
    }

    pub fn deinit(self: *TextBuffer) void {
        self.text.deinit();
        self.selections.deinit();
    }

    pub fn addSelection(self: *TextBuffer, selection: Selection) !void {
        if (selection.end() > self.text.items.len) return error.SelectionOutOfBounds;
        try self.selections.append(selection);
    }

    pub fn insert(self: *TextBuffer, offset: usize, bytes: []const u8) !void {
        if (offset > self.text.items.len) return error.OffsetOutOfBounds;
        try self.text.insertSlice(offset, bytes);
    }

    pub fn replaceSelections(self: *TextBuffer, replacement: []const u8) !void {
        if (self.selections.items.len == 0) return;
        const edits = try self.allocator.alloc(TextEdit, self.selections.items.len);
        defer self.allocator.free(edits);
        for (self.selections.items, 0..) |selection, idx| {
            edits[idx] = .{
                .start = selection.start(),
                .end = selection.end(),
                .replacement = replacement,
            };
        }
        try self.applyEdits(edits);
    }

    pub fn replaceSelectionsWith(self: *TextBuffer, replacements: []const []const u8) !void {
        if (self.selections.items.len != replacements.len) return error.ReplacementCountMismatch;
        if (self.selections.items.len == 0) return;
        const edits = try self.allocator.alloc(TextEdit, self.selections.items.len);
        defer self.allocator.free(edits);
        for (self.selections.items, 0..) |selection, idx| {
            edits[idx] = .{
                .start = selection.start(),
                .end = selection.end(),
                .replacement = replacements[idx],
            };
        }
        try self.applyEdits(edits);
    }

    pub fn applyEdits(self: *TextBuffer, edits_raw: []const TextEdit) !void {
        if (edits_raw.len == 0) return;

        const edits = try self.allocator.dupe(TextEdit, edits_raw);
        defer self.allocator.free(edits);
        try validateAndSortEdits(edits, self.text.items.len);

        if (edits.len == 1 and try self.applySingleEditFast(edits[0])) {
            self.selections.clearRetainingCapacity();
            return;
        }

        var final_len = self.text.items.len;
        for (edits) |edit| {
            final_len = try std.math.sub(usize, final_len, edit.end - edit.start);
            final_len = try std.math.add(usize, final_len, edit.replacement.len);
        }

        var next = std.array_list.Managed(u8).init(self.allocator);
        errdefer next.deinit();
        try next.ensureTotalCapacity(final_len);

        var cursor: usize = 0;
        for (edits) |edit| {
            try next.appendSlice(self.text.items[cursor..edit.start]);
            try next.appendSlice(edit.replacement);
            cursor = edit.end;
        }
        try next.appendSlice(self.text.items[cursor..]);

        self.text.deinit();
        self.text = next;
        self.selections.clearRetainingCapacity();
    }

    fn applySingleEditFast(self: *TextBuffer, edit: TextEdit) !bool {
        const removed_len = edit.end - edit.start;
        const inserted_len = edit.replacement.len;
        if (removed_len == inserted_len) {
            if (inserted_len > 0)
                @memcpy(self.text.items[edit.start..edit.end], edit.replacement);
            return true;
        }
        if (removed_len == 0) {
            try self.text.insertSlice(edit.start, edit.replacement);
            return true;
        }
        if (inserted_len == 0) {
            std.mem.copyForwards(u8, self.text.items[edit.start..], self.text.items[edit.end..]);
            self.text.shrinkRetainingCapacity(self.text.items.len - removed_len);
            return true;
        }
        if (edit.end == self.text.items.len) {
            self.text.shrinkRetainingCapacity(edit.start);
            try self.text.appendSlice(edit.replacement);
            return true;
        }
        return false;
    }

    pub fn lineCount(self: TextBuffer) usize {
        if (self.text.items.len == 0) return 1;
        var count: usize = 1;
        for (self.text.items) |c| {
            if (c == '\n') count += 1;
        }
        return count;
    }

    pub fn slice(self: TextBuffer) []const u8 {
        return self.text.items;
    }

    pub fn findAllAlloc(self: TextBuffer, allocator: std.mem.Allocator, needle: []const u8, options: SearchOptions) ![]SearchMatch {
        if (needle.len == 0) return error.EmptySearchQuery;
        var matches = std.array_list.Managed(SearchMatch).init(allocator);
        errdefer matches.deinit();

        var idx: usize = 0;
        var line: usize = 1;
        var column: usize = 1;
        while (idx + needle.len <= self.text.items.len and matches.items.len < options.max_results) {
            if (matchesAt(self.text.items[idx .. idx + needle.len], needle, options.case_sensitive)) {
                if (matches.items.len == 0) {
                    const possible_matches = 1 + (self.text.items.len - needle.len) / needle.len;
                    try matches.ensureTotalCapacity(@min(
                        options.max_results,
                        @min(possible_matches, 64),
                    ));
                }
                try matches.append(.{
                    .start = idx,
                    .end = idx + needle.len,
                    .line = line,
                    .column = column,
                });
                advanceLineColumn(self.text.items[idx .. idx + needle.len], &line, &column);
                idx += needle.len;
            } else {
                advanceLineColumn(self.text.items[idx .. idx + 1], &line, &column);
                idx += 1;
            }
        }

        return matches.toOwnedSlice();
    }
};

pub const EditorDocument = struct {
    allocator: std.mem.Allocator,
    path: []u8,
    worktree_root: ?[]u8 = null,
    language: Language,
    buffer: TextBuffer,
    undo_stack: std.array_list.Managed(EditTransaction),
    redo_stack: std.array_list.Managed(EditTransaction),
    dirty: bool = false,
    revision: u64 = 0,

    pub fn initFromSlice(
        allocator: std.mem.Allocator,
        path: []const u8,
        worktree_root: ?[]const u8,
        contents: []const u8,
    ) !EditorDocument {
        if (path.len == 0) return error.InvalidDocumentPath;
        const owned_path = try allocator.dupe(u8, path);
        errdefer allocator.free(owned_path);
        const owned_root = if (worktree_root) |root| try allocator.dupe(u8, root) else null;
        errdefer if (owned_root) |root| allocator.free(root);
        var buffer = try TextBuffer.initFromSlice(allocator, contents);
        errdefer buffer.deinit();
        var undo_stack = std.array_list.Managed(EditTransaction).init(allocator);
        errdefer undo_stack.deinit();
        var redo_stack = std.array_list.Managed(EditTransaction).init(allocator);
        errdefer redo_stack.deinit();
        return .{
            .allocator = allocator,
            .path = owned_path,
            .worktree_root = owned_root,
            .language = detectLanguage(path),
            .buffer = buffer,
            .undo_stack = undo_stack,
            .redo_stack = redo_stack,
        };
    }

    pub fn deinit(self: *EditorDocument) void {
        self.allocator.free(self.path);
        if (self.worktree_root) |root| self.allocator.free(root);
        self.buffer.deinit();
        clearTransactions(&self.undo_stack, self.allocator);
        self.undo_stack.deinit();
        clearTransactions(&self.redo_stack, self.allocator);
        self.redo_stack.deinit();
        self.* = undefined;
    }

    pub fn applyEdits(self: *EditorDocument, edits: []const TextEdit) !void {
        if (edits.len == 0) return;
        var transaction = try EditTransaction.fromEdits(self.allocator, self.buffer.slice(), edits);
        errdefer transaction.deinit(self.allocator);
        try self.undo_stack.ensureUnusedCapacity(1);
        try applyOwnedEdits(&self.buffer, self.allocator, transaction.redo);
        self.undo_stack.appendAssumeCapacity(transaction);
        trimTransactions(&self.undo_stack, self.allocator);
        clearTransactions(&self.redo_stack, self.allocator);
        self.revision += 1;
        self.dirty = true;
    }

    pub fn undo(self: *EditorDocument) !bool {
        var transaction = self.undo_stack.pop() orelse return false;
        errdefer transaction.deinit(self.allocator);
        try self.redo_stack.ensureUnusedCapacity(1);
        try applyOwnedEdits(&self.buffer, self.allocator, transaction.undo);
        self.redo_stack.appendAssumeCapacity(transaction);
        trimTransactions(&self.redo_stack, self.allocator);
        self.revision += 1;
        self.dirty = true;
        return true;
    }

    pub fn redo(self: *EditorDocument) !bool {
        var transaction = self.redo_stack.pop() orelse return false;
        errdefer transaction.deinit(self.allocator);
        try self.undo_stack.ensureUnusedCapacity(1);
        try applyOwnedEdits(&self.buffer, self.allocator, transaction.redo);
        self.undo_stack.appendAssumeCapacity(transaction);
        trimTransactions(&self.undo_stack, self.allocator);
        self.revision += 1;
        self.dirty = true;
        return true;
    }

    pub fn markSaved(self: *EditorDocument) void {
        self.dirty = false;
    }

    pub fn relativePath(self: EditorDocument) []const u8 {
        return relativePathFor(self.path, self.worktree_root);
    }
};

pub fn relativePathFor(path: []const u8, worktree_root: ?[]const u8) []const u8 {
    const root = worktree_root orelse return path;
    if (!std.mem.startsWith(u8, path, root)) return path;
    var rest = path[root.len..];
    if (std.mem.startsWith(u8, rest, "/")) rest = rest[1..];
    return rest;
}

pub fn detectLanguage(path: []const u8) Language {
    const name = baseName(path);
    if (std.mem.eql(u8, name, "Dockerfile")) return .shell;
    if (std.mem.eql(u8, name, "Makefile")) return .shell;
    if (std.mem.eql(u8, name, ".bashrc")) return .shell;
    if (std.mem.eql(u8, name, ".zshrc")) return .shell;
    if (std.mem.eql(u8, name, "Cargo.toml")) return .toml;
    if (std.mem.eql(u8, name, "build.zig")) return .zig;

    if (hasSuffix(name, ".zig")) return .zig;
    if (hasSuffix(name, ".c") or hasSuffix(name, ".h")) return .c;
    if (hasSuffix(name, ".cc") or hasSuffix(name, ".cpp") or hasSuffix(name, ".cxx") or hasSuffix(name, ".hpp")) return .cpp;
    if (hasSuffix(name, ".rs")) return .rust;
    if (hasSuffix(name, ".py")) return .python;
    if (hasSuffix(name, ".js") or hasSuffix(name, ".mjs") or hasSuffix(name, ".cjs")) return .javascript;
    if (hasSuffix(name, ".ts") or hasSuffix(name, ".tsx")) return .typescript;
    if (hasSuffix(name, ".json")) return .json;
    if (hasSuffix(name, ".md") or hasSuffix(name, ".markdown")) return .markdown;
    if (hasSuffix(name, ".sh") or hasSuffix(name, ".bash") or hasSuffix(name, ".zsh")) return .shell;
    if (hasSuffix(name, ".toml")) return .toml;
    if (hasSuffix(name, ".yaml") or hasSuffix(name, ".yml")) return .yaml;
    return .plain_text;
}

fn validateAndSortEdits(edits: []TextEdit, text_len: usize) !void {
    for (edits) |edit| {
        if (edit.start > edit.end or edit.end > text_len) return error.EditOutOfBounds;
    }
    std.mem.sort(TextEdit, edits, {}, editAsc);
    for (edits[1..], 1..) |edit, idx| {
        if (edit.start < edits[idx - 1].end) return error.OverlappingEdits;
    }
}

fn cloneOwnedTextEdit(allocator: std.mem.Allocator, edit: TextEdit) !OwnedTextEdit {
    return .{
        .start = edit.start,
        .end = edit.end,
        .replacement = try allocator.dupe(u8, edit.replacement),
    };
}

fn applyOwnedEdits(buffer: *TextBuffer, allocator: std.mem.Allocator, owned_edits: []const OwnedTextEdit) !void {
    const edits = try allocator.alloc(TextEdit, owned_edits.len);
    defer allocator.free(edits);
    for (owned_edits, 0..) |edit, idx| edits[idx] = edit.borrowed();
    try buffer.applyEdits(edits);
}

fn trimTransactions(stack: *std.array_list.Managed(EditTransaction), allocator: std.mem.Allocator) void {
    while (stack.items.len > max_editor_undo_transactions) {
        var removed = stack.orderedRemove(0);
        removed.deinit(allocator);
    }
    while (transactionStackByteCost(stack.items) > max_editor_undo_bytes and
        stack.items.len > 1)
    {
        var removed = stack.orderedRemove(0);
        removed.deinit(allocator);
    }
}

fn transactionStackByteCost(stack: []const EditTransaction) usize {
    var total: usize = 0;
    for (stack) |transaction| total += transactionByteCost(transaction);
    return total;
}

fn transactionByteCost(transaction: EditTransaction) usize {
    var total: usize = 0;
    for (transaction.undo) |edit| total += edit.replacement.len;
    for (transaction.redo) |edit| total += edit.replacement.len;
    return total;
}

fn clearTransactions(stack: *std.array_list.Managed(EditTransaction), allocator: std.mem.Allocator) void {
    for (stack.items) |*transaction| transaction.deinit(allocator);
    stack.clearRetainingCapacity();
}

fn editAsc(_: void, lhs: TextEdit, rhs: TextEdit) bool {
    if (lhs.start != rhs.start) return lhs.start < rhs.start;
    return lhs.end < rhs.end;
}

fn baseName(path: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return path;
    return path[slash + 1 ..];
}

fn hasSuffix(value: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, value, suffix);
}

fn appendSyntaxSpan(summary: *SyntaxHighlightSummary, start: usize, end: usize, kind: SyntaxTokenKind) void {
    if (end <= start) return;
    if (summary.span_count < summary.max_spans) {
        summary.spans[summary.span_count] = .{
            .start = start,
            .end = end,
            .kind = kind,
        };
        summary.span_count += 1;
    }
    summary.total_spans += 1;
}

fn highlightMarkdown(source: []const u8, summary: *SyntaxHighlightSummary) void {
    var line_start: usize = 0;
    while (line_start < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
        var first: usize = line_start;
        while (first < line_end and first - line_start < 3 and source[first] == ' ') first += 1;
        const line = source[first..line_end];
        if (std.mem.startsWith(u8, line, "```")) {
            appendSyntaxSpan(summary, first, line_end, .code_fence);
        } else if (markdownHeadingWidth(line)) |width| {
            appendSyntaxSpan(summary, first, first + width, .heading);
        }
        line_start = if (line_end < source.len) line_end + 1 else source.len;
    }
}

fn markdownHeadingWidth(line: []const u8) ?usize {
    var count: usize = 0;
    while (count < line.len and count < 6 and line[count] == '#') count += 1;
    if (count == 0) return null;
    if (count == line.len or line[count] == ' ') return count;
    return null;
}

fn highlightCodeLike(language: Language, source: []const u8, summary: *SyntaxHighlightSummary) void {
    var idx: usize = 0;
    while (idx < source.len) {
        if (lineCommentDelimiter(language)) |delimiter| {
            if (startsWithAt(source, idx, delimiter)) {
                const end = std.mem.indexOfScalarPos(u8, source, idx, '\n') orelse source.len;
                appendSyntaxSpan(summary, idx, end, .comment);
                idx = end;
                continue;
            }
        }

        const byte = source[idx];
        if (isStringQuote(language, byte)) {
            const end = scanString(source, idx, byte);
            appendSyntaxSpan(summary, idx, end, .string);
            idx = end;
            continue;
        }
        if (std.ascii.isDigit(byte)) {
            const end = scanNumber(source, idx);
            appendSyntaxSpan(summary, idx, end, .number);
            idx = end;
            continue;
        }
        if (isIdentStart(byte)) {
            const end = scanIdentifier(source, idx);
            const word = source[idx..end];
            if (isLiteral(language, word)) {
                appendSyntaxSpan(summary, idx, end, .literal);
            } else if (isKeyword(language, word)) {
                appendSyntaxSpan(summary, idx, end, .keyword);
            }
            idx = end;
            continue;
        }
        idx += 1;
    }
}

fn startsWithAt(source: []const u8, idx: usize, needle: []const u8) bool {
    return idx + needle.len <= source.len and std.mem.eql(u8, source[idx .. idx + needle.len], needle);
}

fn lineCommentDelimiter(language: Language) ?[]const u8 {
    return switch (language) {
        .zig, .c, .cpp, .rust, .javascript, .typescript => "//",
        .python, .shell, .toml, .yaml => "#",
        .plain_text, .json, .markdown => null,
    };
}

fn isStringQuote(language: Language, byte: u8) bool {
    return switch (byte) {
        '"' => true,
        '\'' => language != .json and language != .toml and language != .yaml,
        '`' => language == .javascript or language == .typescript or language == .shell,
        else => false,
    };
}

fn scanString(source: []const u8, start: usize, quote: u8) usize {
    var idx = start + 1;
    var escaped = false;
    while (idx < source.len) : (idx += 1) {
        const byte = source[idx];
        if (escaped) {
            escaped = false;
            continue;
        }
        if (byte == '\\') {
            escaped = true;
            continue;
        }
        if (byte == quote) return idx + 1;
        if (byte == '\n') return idx;
    }
    return source.len;
}

fn scanNumber(source: []const u8, start: usize) usize {
    var idx = start;
    while (idx < source.len) : (idx += 1) {
        const byte = source[idx];
        if (!(std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.' or byte == '+' or byte == '-')) break;
    }
    return idx;
}

fn isIdentStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn scanIdentifier(source: []const u8, start: usize) usize {
    var idx = start;
    while (idx < source.len and (std.ascii.isAlphanumeric(source[idx]) or source[idx] == '_')) idx += 1;
    return idx;
}

fn isLiteral(language: Language, word: []const u8) bool {
    return switch (language) {
        .json => eqlAny(word, &.{ "true", "false", "null" }),
        .zig => eqlAny(word, &.{ "true", "false", "null", "undefined" }),
        .rust => eqlAny(word, &.{ "true", "false", "None", "Some" }),
        .python => eqlAny(word, &.{ "True", "False", "None" }),
        .javascript, .typescript => eqlAny(word, &.{ "true", "false", "null", "undefined" }),
        else => false,
    };
}

fn isKeyword(language: Language, word: []const u8) bool {
    return switch (language) {
        .zig => eqlAny(word, &.{
            "addrspace",   "align",  "allowzero", "and",         "anyframe",       "anytype", "asm",      "async",
            "await",       "break",  "callconv",  "catch",       "comptime",       "const",   "continue", "defer",
            "else",        "enum",   "errdefer",  "error",       "export",         "extern",  "fn",       "for",
            "if",          "inline", "noalias",   "noinline",    "nosuspend",      "opaque",  "or",       "orelse",
            "packed",      "pub",    "resume",    "return",      "struct",         "suspend", "switch",   "test",
            "threadlocal", "try",    "union",     "unreachable", "usingnamespace", "var",     "volatile", "while",
        }),
        .c, .cpp => eqlAny(word, &.{
            "auto",   "break",  "case",     "class",   "const",  "continue",  "default", "do",     "else",
            "enum",   "extern", "for",      "if",      "inline", "namespace", "return",  "sizeof", "static",
            "struct", "switch", "template", "typedef", "union",  "while",
        }),
        .rust => eqlAny(word, &.{
            "as",   "break",  "const", "continue", "crate", "else", "enum",   "extern", "fn",
            "for",  "if",     "impl",  "in",       "let",   "loop", "match",  "mod",    "move",
            "mut",  "pub",    "ref",   "return",   "self",  "Self", "static", "struct", "trait",
            "type", "unsafe", "use",   "where",    "while",
        }),
        .python => eqlAny(word, &.{
            "and",    "as",   "assert", "async",  "await",    "break", "class", "continue", "def",
            "del",    "elif", "else",   "except", "finally",  "for",   "from",  "global",   "if",
            "import", "in",   "is",     "lambda", "nonlocal", "not",   "or",    "pass",     "raise",
            "return", "try",  "while",  "with",   "yield",
        }),
        .javascript, .typescript => eqlAny(word, &.{
            "async",   "await",  "break",  "case",      "catch",   "class", "const", "continue",
            "default", "else",   "export", "extends",   "finally", "for",   "from",  "function",
            "if",      "import", "in",     "interface", "let",     "new",   "of",    "return",
            "switch",  "throw",  "try",    "type",      "var",     "while",
        }),
        .shell => eqlAny(word, &.{ "case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if", "in", "then", "while" }),
        .json, .markdown, .plain_text, .toml, .yaml => false,
    };
}

fn eqlAny(word: []const u8, words: []const []const u8) bool {
    for (words) |candidate| {
        if (std.mem.eql(u8, word, candidate)) return true;
    }
    return false;
}

fn lineColumnAtBytes(source: []const u8, offset_raw: usize) LineColumn {
    const offset = @min(offset_raw, source.len);
    var line: usize = 1;
    var column: usize = 1;
    for (source[0..offset]) |byte| {
        if (byte == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
    }
    return .{ .line = line, .column = column };
}

fn advanceLineColumn(bytes: []const u8, line: *usize, column: *usize) void {
    for (bytes) |byte| {
        if (byte == '\n') {
            line.* += 1;
            column.* = 1;
        } else {
            column.* += 1;
        }
    }
}

fn isWholeWordMatch(source: []const u8, start: usize, end: usize) bool {
    const before_ok = start == 0 or !isWordByte(source[start - 1]);
    const after_ok = end >= source.len or !isWordByte(source[end]);
    return before_ok and after_ok;
}

fn isWordByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn matchesAt(haystack: []const u8, needle: []const u8, case_sensitive: bool) bool {
    if (case_sensitive) return std.mem.eql(u8, haystack, needle);
    for (haystack, needle) |lhs, rhs| {
        if (std.ascii.toLower(lhs) != std.ascii.toLower(rhs)) return false;
    }
    return true;
}

test "text buffer supports multiple selection edits" {
    const allocator = std.testing.allocator;
    var buffer = try TextBuffer.initFromSlice(allocator, "alpha beta alpha");
    defer buffer.deinit();

    try buffer.addSelection(.{ .anchor = .{ .offset = 0 }, .active = .{ .offset = 5 } });
    try buffer.addSelection(.{ .anchor = .{ .offset = 11 }, .active = .{ .offset = 16 } });
    try buffer.replaceSelections("omega");

    try std.testing.expectEqualStrings("omega beta omega", buffer.slice());
}

test "text buffer applies transactional multi edits" {
    const allocator = std.testing.allocator;
    var buffer = try TextBuffer.initFromSlice(allocator, "one two three");
    defer buffer.deinit();

    try buffer.applyEdits(&.{
        .{ .start = 0, .end = 3, .replacement = "1" },
        .{ .start = 4, .end = 7, .replacement = "2" },
        .{ .start = 8, .end = 13, .replacement = "3" },
    });
    try std.testing.expectEqualStrings("1 2 3", buffer.slice());

    try std.testing.expectError(error.OverlappingEdits, buffer.applyEdits(&.{
        .{ .start = 0, .end = 3, .replacement = "bad" },
        .{ .start = 2, .end = 5, .replacement = "bad" },
    }));
    try std.testing.expectEqualStrings("1 2 3", buffer.slice());
}

test "text buffer supports per selection replacements" {
    const allocator = std.testing.allocator;
    var buffer = try TextBuffer.initFromSlice(allocator, "alpha beta gamma");
    defer buffer.deinit();

    try buffer.addSelection(.{ .anchor = .{ .offset = 0 }, .active = .{ .offset = 5 } });
    try buffer.addSelection(.{ .anchor = .{ .offset = 6 }, .active = .{ .offset = 10 } });
    try buffer.addSelection(.{ .anchor = .{ .offset = 11 }, .active = .{ .offset = 16 } });
    try buffer.replaceSelectionsWith(&.{ "one", "two", "three" });

    try std.testing.expectEqualStrings("one two three", buffer.slice());
}

test "text buffer searches literal matches with line columns and limits" {
    const allocator = std.testing.allocator;
    var buffer = try TextBuffer.initFromSlice(allocator,
        \\Alpha beta
        \\alpha Beta
        \\beta
    );
    defer buffer.deinit();

    const case_sensitive = try buffer.findAllAlloc(allocator, "beta", .{});
    defer allocator.free(case_sensitive);
    try std.testing.expectEqual(@as(usize, 2), case_sensitive.len);
    try std.testing.expectEqual(@as(usize, 1), case_sensitive[0].line);
    try std.testing.expectEqual(@as(usize, 7), case_sensitive[0].column);
    try std.testing.expectEqual(@as(usize, 3), case_sensitive[1].line);
    try std.testing.expectEqual(@as(usize, 1), case_sensitive[1].column);

    const insensitive = try buffer.findAllAlloc(allocator, "ALPHA", .{ .case_sensitive = false, .max_results = 1 });
    defer allocator.free(insensitive);
    try std.testing.expectEqual(@as(usize, 1), insensitive.len);
    try std.testing.expectEqual(@as(usize, 1), insensitive[0].line);

    const absent = try buffer.findAllAlloc(std.testing.failing_allocator, "missing", .{});
    defer std.testing.failing_allocator.free(absent);
    try std.testing.expectEqual(@as(usize, 0), absent.len);

    try std.testing.expectError(error.EmptySearchQuery, buffer.findAllAlloc(allocator, "", .{}));
}

test "editor find summary supports whole word navigation and truncation" {
    const contents =
        \\Alpha beta
        \\alphabet alpha
        \\ALPHA beta alpha
    ;
    const forward = try findEditorMatches(.{
        .path = "/repo/notes.txt",
        .contents = contents,
        .query = "alpha",
        .case_sensitive = false,
        .whole_word = true,
        .cursor_offset = 8,
        .direction = .forward,
        .max_matches = 2,
    });
    try std.testing.expectEqual(Language.plain_text, forward.language);
    try std.testing.expectEqual(@as(usize, 4), forward.total_matches);
    try std.testing.expectEqual(@as(usize, 2), forward.match_count);
    try std.testing.expect(forward.truncated());
    try std.testing.expect(forward.hasCurrent());
    try std.testing.expectEqual(@as(?usize, 1), forward.current_match_index);
    try std.testing.expectEqual(@as(?usize, 1), forward.current_stored_index);
    try std.testing.expect(!forward.wrapped);
    try std.testing.expectEqual(@as(usize, 2), forward.current_match.?.line);
    try std.testing.expectEqual(@as(usize, 10), forward.current_match.?.column);
    try std.testing.expectEqual(@as(usize, 1), forward.matchSlice()[0].line);
    try std.testing.expectEqual(@as(usize, 1), forward.matchSlice()[0].column);

    const backward = try findEditorMatches(.{
        .path = "/repo/notes.txt",
        .contents = contents,
        .query = "alpha",
        .case_sensitive = false,
        .whole_word = true,
        .cursor_offset = 0,
        .direction = .backward,
        .wrap = true,
    });
    try std.testing.expectEqual(EditorFindDirection.backward, backward.direction);
    try std.testing.expect(backward.wrapped);
    try std.testing.expectEqual(@as(?usize, 3), backward.current_match_index);
    try std.testing.expectEqual(@as(?usize, 3), backward.current_stored_index);
    try std.testing.expectEqual(@as(usize, 3), backward.current_match.?.line);

    const no_wrap = try findEditorMatches(.{
        .path = "/repo/notes.txt",
        .contents = contents,
        .query = "alpha",
        .case_sensitive = false,
        .whole_word = true,
        .cursor_offset = contents.len,
        .direction = .forward,
        .wrap = false,
    });
    try std.testing.expect(!no_wrap.hasCurrent());

    try std.testing.expectError(error.EmptySearchQuery, findEditorMatches(.{
        .path = "/repo/notes.txt",
        .contents = contents,
        .query = "",
    }));
}

test "editor detects common languages from paths" {
    try std.testing.expectEqual(Language.zig, detectLanguage("src/main.zig"));
    try std.testing.expectEqual(Language.rust, detectLanguage("crates/app/src/lib.rs"));
    try std.testing.expectEqual(Language.python, detectLanguage("tools/report.py"));
    try std.testing.expectEqual(Language.typescript, detectLanguage("ui/App.tsx"));
    try std.testing.expectEqual(Language.markdown, detectLanguage("README.md"));
    try std.testing.expectEqual(Language.toml, detectLanguage("Cargo.toml"));
    try std.testing.expectEqual(Language.yaml, detectLanguage(".github/workflows/ci.yml"));
    try std.testing.expectEqual(Language.shell, detectLanguage(".bashrc"));
    try std.testing.expectEqual(Language.plain_text, detectLanguage("LICENSE"));
}

test "editor produces bounded syntax highlight spans" {
    const zig_source =
        \\pub fn main() void {
        \\    const value = 42;
        \\    // comment
        \\    return;
        \\}
    ;
    const zig_summary = highlightSyntax(.zig, zig_source, .{});
    try std.testing.expectEqual(Language.zig, zig_summary.language);
    try std.testing.expectEqual(@as(usize, 6), zig_summary.total_spans);
    try std.testing.expectEqual(@as(usize, 6), zig_summary.span_count);
    try std.testing.expect(!zig_summary.truncated());
    try std.testing.expectEqual(SyntaxTokenKind.keyword, zig_summary.spanSlice()[0].kind);
    try std.testing.expectEqualStrings("pub", zig_source[zig_summary.spanSlice()[0].start..zig_summary.spanSlice()[0].end]);
    try std.testing.expectEqual(SyntaxTokenKind.comment, zig_summary.spanSlice()[4].kind);
    try std.testing.expectEqual(SyntaxTokenKind.keyword, zig_summary.spanSlice()[5].kind);

    const json_summary = highlightSyntax(.json, "{\"ok\": true, \"n\": 12}", .{ .max_spans = 2 });
    try std.testing.expectEqual(@as(usize, 4), json_summary.total_spans);
    try std.testing.expectEqual(@as(usize, 2), json_summary.span_count);
    try std.testing.expect(json_summary.truncated());
    try std.testing.expectEqual(SyntaxTokenKind.string, json_summary.spanSlice()[0].kind);
    try std.testing.expectEqual(SyntaxTokenKind.literal, json_summary.spanSlice()[1].kind);

    const markdown_summary = try highlightSyntaxForPath(.{
        .path = "README.md",
        .contents =
        \\# Title
        \\
        \\```zig
        \\const value = 1;
        \\```
        ,
    });
    try std.testing.expectEqual(Language.markdown, markdown_summary.language);
    try std.testing.expectEqual(@as(usize, 3), markdown_summary.total_spans);
    try std.testing.expectEqual(SyntaxTokenKind.heading, markdown_summary.spanSlice()[0].kind);
    try std.testing.expectEqual(SyntaxTokenKind.code_fence, markdown_summary.spanSlice()[1].kind);
    try std.testing.expectEqual(SyntaxTokenKind.code_fence, markdown_summary.spanSlice()[2].kind);
}

test "editor plans large file handling before opening buffers" {
    const policy = EditorOpenPolicy{
        .editable_byte_limit = 1024,
        .preview_byte_limit = 4096,
        .editable_line_limit = 100,
    };

    const editable = try planEditorOpen(.{
        .path = "/repo/src/main.zig",
        .worktree_root = "/repo",
        .byte_count = 512,
        .line_count = 20,
    }, policy);
    try std.testing.expectEqual(EditorOpenMode.editable, editable.mode);
    try std.testing.expectEqual(EditorOpenReason.normal, editable.reason);
    try std.testing.expectEqual(Language.zig, editable.language);
    try std.testing.expectEqualStrings("src/main.zig", editable.relative_path);
    try std.testing.expect(editable.canOpen());
    try std.testing.expect(editable.can_edit);
    try std.testing.expect(editable.loads_buffer);
    try std.testing.expect(editable.tracks_undo);
    try std.testing.expect(editable.enables_search);
    try std.testing.expect(editable.enables_syntax);
    try std.testing.expect(!editable.warns_large_file);

    const soft_limit = try planEditorOpen(.{
        .path = "/repo/logs/trace.txt",
        .worktree_root = "/repo",
        .byte_count = 2048,
        .line_count = 80,
    }, policy);
    try std.testing.expectEqual(EditorOpenMode.large_read_only, soft_limit.mode);
    try std.testing.expectEqual(EditorOpenReason.byte_soft_limit, soft_limit.reason);
    try std.testing.expect(soft_limit.canOpen());
    try std.testing.expect(!soft_limit.can_edit);
    try std.testing.expect(soft_limit.loads_buffer);
    try std.testing.expect(!soft_limit.tracks_undo);
    try std.testing.expect(soft_limit.enables_search);
    try std.testing.expect(!soft_limit.enables_syntax);
    try std.testing.expect(soft_limit.warns_large_file);

    const hard_limit = try planEditorOpen(.{
        .path = "/repo/dumps/big.json",
        .worktree_root = "/repo",
        .byte_count = 8192,
    }, policy);
    try std.testing.expectEqual(EditorOpenMode.metadata_only, hard_limit.mode);
    try std.testing.expectEqual(EditorOpenReason.byte_hard_limit, hard_limit.reason);
    try std.testing.expect(!hard_limit.canOpen());
    try std.testing.expect(!hard_limit.loads_buffer);
    try std.testing.expect(!hard_limit.enables_search);
    try std.testing.expect(hard_limit.requires_confirmation);

    const line_limit = try planEditorOpen(.{
        .path = "/repo/generated/table.csv",
        .worktree_root = "/repo",
        .byte_count = 900,
        .line_count = 200,
    }, policy);
    try std.testing.expectEqual(EditorOpenMode.large_read_only, line_limit.mode);
    try std.testing.expectEqual(EditorOpenReason.line_limit, line_limit.reason);

    try std.testing.expectError(error.InvalidEditorOpenPolicy, planEditorOpen(.{
        .path = "/repo/file.txt",
        .byte_count = 1,
    }, .{ .editable_byte_limit = 4096, .preview_byte_limit = 1024 }));
}

test "editor document tracks worktree path language dirty state and revision" {
    const allocator = std.testing.allocator;
    var doc = try EditorDocument.initFromSlice(
        allocator,
        "/repo/worktrees/agent/src/main.zig",
        "/repo/worktrees/agent",
        "pub fn main() void {}\n",
    );
    defer doc.deinit();

    try std.testing.expectEqual(Language.zig, doc.language);
    try std.testing.expectEqualStrings("src/main.zig", doc.relativePath());
    try std.testing.expect(!doc.dirty);
    try std.testing.expectEqual(@as(u64, 0), doc.revision);

    try doc.applyEdits(&.{
        .{ .start = 0, .end = 3, .replacement = "export" },
    });
    try std.testing.expect(doc.dirty);
    try std.testing.expectEqual(@as(u64, 1), doc.revision);
    try std.testing.expectEqualStrings("export fn main() void {}\n", doc.buffer.slice());
    doc.markSaved();
    try std.testing.expect(!doc.dirty);
}

test "editor document supports transactional undo and redo" {
    const allocator = std.testing.allocator;
    var doc = try EditorDocument.initFromSlice(allocator, "/repo/file.txt", "/repo", "one two three");
    defer doc.deinit();

    try doc.applyEdits(&.{
        .{ .start = 0, .end = 3, .replacement = "1" },
        .{ .start = 4, .end = 7, .replacement = "2" },
        .{ .start = 8, .end = 13, .replacement = "3" },
    });
    try std.testing.expectEqualStrings("1 2 3", doc.buffer.slice());
    try std.testing.expectEqual(@as(usize, 1), doc.undo_stack.items.len);
    try std.testing.expectEqual(@as(usize, 0), doc.redo_stack.items.len);

    try std.testing.expect(try doc.undo());
    try std.testing.expectEqualStrings("one two three", doc.buffer.slice());
    try std.testing.expectEqual(@as(usize, 0), doc.undo_stack.items.len);
    try std.testing.expectEqual(@as(usize, 1), doc.redo_stack.items.len);

    try std.testing.expect(try doc.redo());
    try std.testing.expectEqualStrings("1 2 3", doc.buffer.slice());
    try std.testing.expectEqual(@as(usize, 1), doc.undo_stack.items.len);
    try std.testing.expectEqual(@as(usize, 0), doc.redo_stack.items.len);
}

test "editor document clears redo stack after a new edit" {
    const allocator = std.testing.allocator;
    var doc = try EditorDocument.initFromSlice(allocator, "/repo/file.txt", null, "alpha beta");
    defer doc.deinit();

    try doc.applyEdits(&.{.{ .start = 0, .end = 5, .replacement = "omega" }});
    try std.testing.expect(try doc.undo());
    try std.testing.expectEqualStrings("alpha beta", doc.buffer.slice());
    try std.testing.expectEqual(@as(usize, 1), doc.redo_stack.items.len);

    try doc.applyEdits(&.{.{ .start = 6, .end = 10, .replacement = "delta" }});
    try std.testing.expectEqualStrings("alpha delta", doc.buffer.slice());
    try std.testing.expectEqual(@as(usize, 0), doc.redo_stack.items.len);
    try std.testing.expect(!(try doc.redo()));
}

test "editor document bounds undo transaction retention" {
    const allocator = std.testing.allocator;
    var doc = try EditorDocument.initFromSlice(allocator, "/repo/file.txt", null, "");
    defer doc.deinit();

    var byte: u8 = 'a';
    for (0..max_editor_undo_transactions + 16) |_| {
        const insert = [_]u8{byte};
        try doc.applyEdits(&.{.{ .start = doc.buffer.slice().len, .end = doc.buffer.slice().len, .replacement = &insert }});
        byte = if (byte == 'z') 'a' else byte + 1;
    }

    try std.testing.expectEqual(max_editor_undo_transactions, doc.undo_stack.items.len);
    try std.testing.expectEqual(@as(usize, max_editor_undo_transactions + 16), doc.buffer.slice().len);
}

test "text buffer applies common single edits without rebuilding whole buffer" {
    const allocator = std.testing.allocator;
    var buffer = try TextBuffer.initFromSlice(allocator, "alpha beta");
    defer buffer.deinit();

    try buffer.applyEdits(&.{.{ .start = 5, .end = 5, .replacement = "!" }});
    try std.testing.expectEqualStrings("alpha! beta", buffer.slice());

    try buffer.applyEdits(&.{.{ .start = 5, .end = 6, .replacement = "" }});
    try std.testing.expectEqualStrings("alpha beta", buffer.slice());

    try buffer.applyEdits(&.{.{ .start = 6, .end = 10, .replacement = "BETA" }});
    try std.testing.expectEqualStrings("alpha BETA", buffer.slice());
}
