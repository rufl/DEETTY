//! Standalone NoctEd GTK application and UI-thread lifecycle owner.
//!
//! Reusable document, indexing, search, session, and worker behavior belongs in
//! sibling modules. This file coordinates widgets and callbacks; worker jobs
//! may compute off-thread but must return ownership through the bounded GLib
//! completion path before mutating GTK state.

const std = @import("std");
const Compat = @import("compat");
const core = @import("nocted_core");
const build_options = @import("build_options");

const c = @import("gtk.zig");
const worker = @import("Worker.zig");
const tree_sitter = @import("TreeSitter.zig");

const version = @import("dintty_release").version;
const log = std.log.scoped(.nocted);

const project_root_entry = std.math.maxInt(u64);
const project_placeholder_entry = project_root_entry - 1;
const max_project_monitors: usize = 512;
const max_project_monitor_changes = core.project_index.max_filesystem_changes;
const document_page_key = "nocted-document";
const WorkerJob = worker.Job;
const instance_lock_exclusive: c_int = 2;
const instance_lock_nonblocking: c_int = 4;
const editor_zoom_percent_default: i16 = 100;
const editor_zoom_percent_min: i16 = 60;
const editor_zoom_percent_max: i16 = 240;
const editor_zoom_percent_step: i16 = 10;
const editor_font_size_pt_default: i16 = 11;

extern fn flock(fd: c_int, operation: c_int) c_int;

const InstanceLock = struct {
    fd: c_int,

    fn acquire(allocator: std.mem.Allocator, io: std.Io, config_directory: []const u8) !InstanceLock {
        try std.Io.Dir.cwd().createDirPath(io, config_directory);
        const path = try std.fs.path.join(allocator, &.{ config_directory, "instance.lock" });
        defer allocator.free(path);
        const path_z = try Compat.dupeZ(allocator, path);
        defer allocator.free(path_z);
        const fd = std.posix.openatZ(
            std.posix.AT.FDCWD,
            path_z,
            .{ .ACCMODE = .RDWR, .CREAT = true, .CLOEXEC = true },
            0o600,
        ) catch return error.InstanceLockUnavailable;
        if (flock(fd, instance_lock_exclusive | instance_lock_nonblocking) != 0) {
            _ = std.c.close(fd);
            return error.InstanceAlreadyRunning;
        }
        return .{ .fd = fd };
    }

    fn deinit(self: *InstanceLock) void {
        _ = flock(self.fd, 8);
        _ = std.c.close(self.fd);
        self.* = undefined;
    }
};
const InstanceRegistration = struct {
    application: ?*c.GApplication = null,
    lock: ?InstanceLock = null,
};
const WorkerJobKind = worker.Kind;

const Fold = struct {
    anchor_line: u32,
    first_hidden_line: u32,
    end_line_exclusive: u32,
    anchor_mark: *c.GtkTextMark,
    start_mark: *c.GtkTextMark,
    end_mark: *c.GtkTextMark,
};

const SecondarySelection = struct {
    start_mark: *c.GtkTextMark,
    end_mark: *c.GtkTextMark,
};

const RecentProjectAction = struct {
    app: *App,
    index: usize,
};

const SmokePreview = enum {
    none,
    fold,
    search,
    quick_open,
};

const LatencySummary = struct {
    p50_ns: u64,
    p95_ns: u64,
    p99_ns: u64,
};

const ProjectLoad = struct {
    resolved: ?[]u8,
    index: core.project_index.Index = .{},
    delta: bool = false,
    delta_stats: core.project_index.DeltaStats = .{},
    staging_store: ?*c.GtkTreeStore = null,
    root_iter: c.GtkTreeIter = undefined,
    next_entry: usize = 0,

    fn deinit(self: *ProjectLoad, allocator: std.mem.Allocator) void {
        self.index.deinit(allocator);
        if (self.staging_store) |store| c.g_object_unref(@ptrCast(store));
        if (self.resolved) |resolved| allocator.free(resolved);
        self.* = undefined;
    }
};

const SyntaxTags = struct {
    comment: *c.GtkTextTag,
    string: *c.GtkTextTag,
    number: *c.GtkTextTag,
    constant: *c.GtkTextTag,
    keyword: *c.GtkTextTag,
    function: *c.GtkTextTag,
    property: *c.GtkTextTag,
    type_name: *c.GtkTextTag,
    heading: *c.GtkTextTag,
    code_fence: *c.GtkTextTag,
    variable: *c.GtkTextTag,

    fn get(self: SyntaxTags, scope: tree_sitter.Scope) *c.GtkTextTag {
        return switch (scope) {
            .comment => self.comment,
            .string => self.string,
            .number => self.number,
            .constant => self.constant,
            .keyword => self.keyword,
            .function => self.function,
            .property => self.property,
            .type => self.type_name,
            .heading => self.heading,
            .code_fence => self.code_fence,
            .variable => self.variable,
        };
    }
};

const Document = struct {
    app: *App,
    path: ?[:0]u8,
    display_name: [:0]u8,
    page: *c.GtkWidget,
    view: *c.GtkWidget,
    map: ?*c.GtkWidget,
    buffer: *c.GtkSourceBuffer,
    tab_label: *c.GtkWidget,
    tab_close: *c.GtkWidget,
    search_settings: ?*c.GtkSourceSearchSettings = null,
    search_context: ?*c.GtkSourceSearchContext = null,
    fold_tag: *c.GtkTextTag,
    folds: std.array_list.Managed(Fold),
    selection_tag: *c.GtkTextTag,
    secondary_selections: std.array_list.Managed(SecondarySelection),
    multi_editing: bool = false,
    editable: bool,
    loading: bool = false,
    identity: ?core.document.FileIdentity = null,
    external_change_pending: bool = false,
    external_identity: ?core.document.FileIdentity = null,
    change_serial: u64 = 0,
    reload_serial: u64 = 0,
    syntax: ?tree_sitter.Document = null,
    syntax_tags: SyntaxTags,
    syntax_source: c.guint = 0,
    syntax_capture_count: usize = 0,

    fn deinit(self: *Document) void {
        self.cancelTreeSitterRefresh();
        if (self.syntax) |*syntax| syntax.deinit(self.app.allocator);
        self.clearMultiSelections();
        self.secondary_selections.deinit();
        _ = self.clearFolds();
        self.folds.deinit();
        if (self.search_context) |context| c.g_object_unref(@ptrCast(context));
        if (self.search_settings) |settings| c.g_object_unref(@ptrCast(settings));
        c.g_object_unref(@ptrCast(self.buffer));
        if (self.path) |path| self.app.allocator.free(path);
        self.app.allocator.free(self.display_name);
        self.* = undefined;
    }

    fn cancelTreeSitterRefresh(self: *Document) void {
        if (self.syntax_source == 0) return;
        _ = c.g_source_remove(self.syntax_source);
        self.syntax_source = 0;
    }

    fn configureTreeSitter(self: *Document, path: ?[]const u8) void {
        self.cancelTreeSitterRefresh();
        if (self.syntax) |*syntax| syntax.deinit(self.app.allocator);
        self.syntax = null;
        self.syntax_capture_count = 0;
        const language = tree_sitter.languageForPath(path orelse "") orelse {
            c.gtk_source_buffer_set_highlight_syntax(self.buffer, 1);
            return;
        };
        self.syntax = tree_sitter.Document.init(language) catch {
            c.gtk_source_buffer_set_highlight_syntax(self.buffer, 1);
            return;
        };
        c.gtk_source_buffer_set_highlight_syntax(self.buffer, 0);
        self.refreshTreeSitter() catch |err| self.fallbackToSourceViewSyntax(err);
    }

    fn fallbackToSourceViewSyntax(self: *Document, err: anyerror) void {
        if (self.syntax) |*syntax| syntax.deinit(self.app.allocator);
        self.syntax = null;
        self.syntax_capture_count = 0;
        var start: c.GtkTextIter = undefined;
        var end: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_bounds(@ptrCast(self.buffer), &start, &end);
        self.removeTreeSitterTags(&start, &end);
        c.gtk_source_buffer_set_highlight_syntax(self.buffer, 1);
        switch (err) {
            error.TreeSitterDocumentTooLarge,
            error.TreeSitterCaptureLimitExceeded,
            => self.app.updateStatus("Large or complex file: using lightweight highlighting"),
            else => self.app.updateStatus("Using lightweight syntax highlighting"),
        }
    }

    fn removeTreeSitterTags(
        self: *Document,
        start: *c.GtkTextIter,
        end: *c.GtkTextIter,
    ) void {
        const info = @typeInfo(SyntaxTags).@"struct";
        inline for (info.field_names) |field_name| {
            c.gtk_text_buffer_remove_tag(
                @ptrCast(self.buffer),
                @field(self.syntax_tags, field_name),
                start,
                end,
            );
        }
    }

    fn scheduleTreeSitterRefresh(self: *Document) void {
        if (self.syntax == null) return;
        self.cancelTreeSitterRefresh();
        self.syntax_source = c.g_timeout_add(100, onTreeSitterRefresh, self);
    }

    fn refreshTreeSitter(self: *Document) !void {
        var start: c.GtkTextIter = undefined;
        var end: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_bounds(@ptrCast(self.buffer), &start, &end);
        const text_z = c.gtk_text_buffer_get_text(
            @ptrCast(self.buffer),
            &start,
            &end,
            1,
        ) orelse return error.TextUnavailable;
        defer c.g_free(text_z);
        const text = std.mem.span(text_z);
        // ponytail: Direct highlighting stays below the measured GTK-thread budget;
        // use the existing worker lanes if dogfood proves the native fallback insufficient.
        if (!core.document.useDirectTreeSitter(text.len))
            return error.TreeSitterDocumentTooLarge;
        const syntax = if (self.syntax) |*value| value else return;
        try syntax.update(text);
        const captures = try syntax.captures(self.app.allocator);
        self.syntax_capture_count = captures.len;

        self.removeTreeSitterTags(&start, &end);
        for (captures) |capture| {
            if (capture.end <= capture.start or capture.end > text.len or
                capture.start_point.row > std.math.maxInt(c_int) or
                capture.start_point.column > std.math.maxInt(c_int) or
                capture.end_point.row > std.math.maxInt(c_int) or
                capture.end_point.column > std.math.maxInt(c_int)) continue;
            var capture_start: c.GtkTextIter = undefined;
            var capture_end: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_iter_at_line_index(
                @ptrCast(self.buffer),
                &capture_start,
                @intCast(capture.start_point.row),
                @intCast(capture.start_point.column),
            );
            c.gtk_text_buffer_get_iter_at_line_index(
                @ptrCast(self.buffer),
                &capture_end,
                @intCast(capture.end_point.row),
                @intCast(capture.end_point.column),
            );
            c.gtk_text_buffer_apply_tag(
                @ptrCast(self.buffer),
                self.syntax_tags.get(capture.scope),
                &capture_start,
                &capture_end,
            );
        }
    }

    fn clearMultiSelections(self: *Document) void {
        if (self.secondary_selections.items.len == 0) return;
        var start: c.GtkTextIter = undefined;
        var end: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_bounds(@ptrCast(self.buffer), &start, &end);
        c.gtk_text_buffer_remove_tag(
            @ptrCast(self.buffer),
            self.selection_tag,
            &start,
            &end,
        );
        for (self.secondary_selections.items) |selection| {
            c.gtk_text_buffer_delete_mark(
                @ptrCast(self.buffer),
                selection.start_mark,
            );
            c.gtk_text_buffer_delete_mark(
                @ptrCast(self.buffer),
                selection.end_mark,
            );
        }
        self.secondary_selections.clearRetainingCapacity();
    }

    fn selectAllOccurrences(self: *Document) !core.multi_selection.Matches {
        var primary_start: c.GtkTextIter = undefined;
        var primary_end: c.GtkTextIter = undefined;
        if (c.gtk_text_buffer_get_selection_bounds(
            @ptrCast(self.buffer),
            &primary_start,
            &primary_end,
        ) == 0) return error.EmptySelection;
        const selected_z = c.gtk_text_buffer_get_text(
            @ptrCast(self.buffer),
            &primary_start,
            &primary_end,
            1,
        ) orelse return error.SelectionUnavailable;
        defer c.g_free(selected_z);
        var buffer_start: c.GtkTextIter = undefined;
        var buffer_end: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_bounds(
            @ptrCast(self.buffer),
            &buffer_start,
            &buffer_end,
        );
        const text_z = c.gtk_text_buffer_get_text(
            @ptrCast(self.buffer),
            &buffer_start,
            &buffer_end,
            1,
        ) orelse return error.EditorTextUnavailable;
        defer c.g_free(text_z);
        var matches = try core.multi_selection.findAllAlloc(
            self.app.allocator,
            std.mem.span(text_z),
            std.mem.span(selected_z),
        );
        errdefer matches.deinit(self.app.allocator);
        if (matches.ranges.len < 2) return error.SingleOccurrence;
        const text = std.mem.span(text_z);
        var byte_cursor: usize = 0;
        var char_cursor: u32 = 0;
        for (matches.ranges) |*range| {
            while (char_cursor < range.start) : (char_cursor += 1) {
                byte_cursor += std.unicode.utf8ByteSequenceLength(text[byte_cursor]) catch
                    return error.InvalidUtf8;
            }
            const start_byte = byte_cursor;
            while (char_cursor < range.end) : (char_cursor += 1) {
                byte_cursor += std.unicode.utf8ByteSequenceLength(text[byte_cursor]) catch
                    return error.InvalidUtf8;
            }
            range.* = .{ .start = @intCast(start_byte), .end = @intCast(byte_cursor) };
        }

        self.clearMultiSelections();
        errdefer self.clearMultiSelections();
        _ = self.clearFolds();
        try self.secondary_selections.ensureTotalCapacity(matches.ranges.len - 1);
        const primary = core.multi_selection.Range{
            .start = @intCast(c.gtk_text_iter_get_offset(&primary_start)),
            .end = @intCast(c.gtk_text_iter_get_offset(&primary_end)),
        };
        for (matches.ranges) |range| {
            if (range.start == primary.start and range.end == primary.end) continue;
            var start: c.GtkTextIter = undefined;
            var end: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_iter_at_offset(
                @ptrCast(self.buffer),
                &start,
                @intCast(range.start),
            );
            c.gtk_text_buffer_get_iter_at_offset(
                @ptrCast(self.buffer),
                &end,
                @intCast(range.end),
            );
            const start_mark = c.gtk_text_buffer_create_mark(
                @ptrCast(self.buffer),
                null,
                &start,
                1,
            ) orelse return error.SelectionMarkCreationFailed;
            const end_mark = c.gtk_text_buffer_create_mark(
                @ptrCast(self.buffer),
                null,
                &end,
                0,
            ) orelse {
                c.gtk_text_buffer_delete_mark(@ptrCast(self.buffer), start_mark);
                return error.SelectionMarkCreationFailed;
            };
            self.secondary_selections.appendAssumeCapacity(.{
                .start_mark = start_mark,
                .end_mark = end_mark,
            });
            c.gtk_text_buffer_apply_tag(
                @ptrCast(self.buffer),
                self.selection_tag,
                &start,
                &end,
            );
        }
        c.gtk_text_buffer_select_range(
            @ptrCast(self.buffer),
            &primary_end,
            &primary_start,
        );
        return matches;
    }

    fn replaceMultiSelections(self: *Document, replacement: []const u8) bool {
        if (!self.editable or self.secondary_selections.items.len == 0 or
            !std.unicode.utf8ValidateSlice(replacement)) return false;
        var primary_start: c.GtkTextIter = undefined;
        var primary_end: c.GtkTextIter = undefined;
        if (c.gtk_text_buffer_get_selection_bounds(
            @ptrCast(self.buffer),
            &primary_start,
            &primary_end,
        ) == 0) return false;
        var ranges: [core.multi_selection.max_selections]core.multi_selection.Range = undefined;
        ranges[0] = .{
            .start = @intCast(c.gtk_text_iter_get_offset(&primary_start)),
            .end = @intCast(c.gtk_text_iter_get_offset(&primary_end)),
        };
        var count: usize = 1;
        for (self.secondary_selections.items) |selection| {
            if (count >= ranges.len) break;
            var start: c.GtkTextIter = undefined;
            var end: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_iter_at_mark(
                @ptrCast(self.buffer),
                &start,
                selection.start_mark,
            );
            c.gtk_text_buffer_get_iter_at_mark(
                @ptrCast(self.buffer),
                &end,
                selection.end_mark,
            );
            ranges[count] = .{
                .start = @intCast(c.gtk_text_iter_get_offset(&start)),
                .end = @intCast(c.gtk_text_iter_get_offset(&end)),
            };
            count += 1;
        }
        count = core.multi_selection.normalize(ranges[0..count]);
        if (count == 0) return false;
        const earliest = ranges[0].start;
        const caret_offset: u32 = earliest + @as(u32, @intCast(replacement.len));
        self.multi_editing = true;
        defer self.multi_editing = false;
        _ = self.clearFolds();
        self.clearMultiSelections();
        c.gtk_text_buffer_begin_user_action(@ptrCast(self.buffer));
        var index = count;
        while (index > 0) {
            index -= 1;
            var start: c.GtkTextIter = undefined;
            var end: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_iter_at_offset(
                @ptrCast(self.buffer),
                &start,
                @intCast(ranges[index].start),
            );
            c.gtk_text_buffer_get_iter_at_offset(
                @ptrCast(self.buffer),
                &end,
                @intCast(ranges[index].end),
            );
            c.gtk_text_buffer_delete(@ptrCast(self.buffer), &start, &end);
            if (replacement.len > 0)
                c.gtk_text_buffer_insert(
                    @ptrCast(self.buffer),
                    &start,
                    replacement.ptr,
                    @intCast(replacement.len),
                );
        }
        c.gtk_text_buffer_end_user_action(@ptrCast(self.buffer));
        var caret: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_iter_at_offset(
            @ptrCast(self.buffer),
            &caret,
            @intCast(caret_offset),
        );
        c.gtk_text_buffer_select_range(@ptrCast(self.buffer), &caret, &caret);
        self.scheduleTreeSitterRefresh();
        return true;
    }

    fn ensureSearchContext(self: *Document) !*c.GtkSourceSearchContext {
        if (self.search_context) |context| return context;
        const settings = c.gtk_source_search_settings_new() orelse
            return error.SearchSettingsCreationFailed;
        errdefer c.g_object_unref(@ptrCast(settings));
        const context = c.gtk_source_search_context_new(self.buffer, settings) orelse
            return error.SearchContextCreationFailed;
        self.search_settings = settings;
        self.search_context = context;
        connect(
            context,
            "notify::occurrences-count",
            @ptrCast(&onSearchCountChanged),
            self.app,
        );
        return context;
    }

    fn ensureMinimap(self: *Document) !*c.GtkWidget {
        if (self.map) |map| return map;
        const map = c.gtk_source_map_new() orelse return error.MinimapCreationFailed;
        c.gtk_source_map_set_view(@ptrCast(map), @ptrCast(self.view));
        c.gtk_widget_set_size_request(map, 112, -1);
        c.gtk_widget_set_name(map, "nocted-minimap");
        c.gtk_box_pack_end(asBox(self.page), map, 0, 0, 0);
        self.map = map;
        return map;
    }

    fn cursorLine(self: *Document) u32 {
        var iter: c.GtkTextIter = undefined;
        const mark = c.gtk_text_buffer_get_insert(@ptrCast(self.buffer));
        c.gtk_text_buffer_get_iter_at_mark(@ptrCast(self.buffer), &iter, mark);
        return @intCast(@max(c.gtk_text_iter_get_line(&iter), 0));
    }

    fn analyzeFolds(self: *Document) !core.folding.Analysis {
        var start: c.GtkTextIter = undefined;
        var end: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_bounds(@ptrCast(self.buffer), &start, &end);
        const text = c.gtk_text_buffer_get_text(
            @ptrCast(self.buffer),
            &start,
            &end,
            1,
        ) orelse return error.FoldTextUnavailable;
        defer c.g_free(text);
        return core.folding.analyzeAlloc(
            self.app.allocator,
            std.mem.span(text),
            4,
        );
    }

    fn hasFoldAt(self: *Document, anchor_line: u32) bool {
        for (self.folds.items) |fold| {
            var anchor: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_iter_at_mark(
                @ptrCast(self.buffer),
                &anchor,
                fold.anchor_mark,
            );
            if (c.gtk_text_iter_get_line(&anchor) == @as(c_int, @intCast(anchor_line)))
                return true;
        }
        return false;
    }

    fn regionIntersectsFold(
        self: *Document,
        region: core.folding.Region,
    ) bool {
        for (self.folds.items) |fold| {
            if (region.first_hidden_line < fold.end_line_exclusive and
                region.end_line_exclusive > fold.first_hidden_line)
                return true;
        }
        return false;
    }

    fn iterAtLineBoundary(
        self: *Document,
        line: u32,
        iter: *c.GtkTextIter,
    ) bool {
        const line_count = c.gtk_text_buffer_get_line_count(@ptrCast(self.buffer));
        if (line_count <= 0 or line > @as(u32, @intCast(line_count))) return false;
        if (line == @as(u32, @intCast(line_count))) {
            c.gtk_text_buffer_get_end_iter(@ptrCast(self.buffer), iter);
        } else {
            c.gtk_text_buffer_get_iter_at_line(
                @ptrCast(self.buffer),
                iter,
                @intCast(line),
            );
        }
        return true;
    }

    fn applyFold(self: *Document, region: core.folding.Region) !bool {
        if (region.hiddenLineCount() == 0 or self.regionIntersectsFold(region))
            return false;
        try self.folds.ensureUnusedCapacity(1);
        var anchor: c.GtkTextIter = undefined;
        var start: c.GtkTextIter = undefined;
        var end: c.GtkTextIter = undefined;
        if (!self.iterAtLineBoundary(region.anchor_line, &anchor) or
            !self.iterAtLineBoundary(region.first_hidden_line, &start) or
            !self.iterAtLineBoundary(region.end_line_exclusive, &end))
            return error.InvalidFoldRegion;

        const cursor_line = self.cursorLine();
        if (cursor_line >= region.first_hidden_line and
            cursor_line < region.end_line_exclusive)
            c.gtk_text_buffer_select_range(@ptrCast(self.buffer), &anchor, &anchor);

        const anchor_mark = c.gtk_text_buffer_create_mark(
            @ptrCast(self.buffer),
            null,
            &anchor,
            1,
        ) orelse return error.FoldMarkCreationFailed;
        errdefer c.gtk_text_buffer_delete_mark(@ptrCast(self.buffer), anchor_mark);
        const start_mark = c.gtk_text_buffer_create_mark(
            @ptrCast(self.buffer),
            null,
            &start,
            1,
        ) orelse return error.FoldMarkCreationFailed;
        errdefer c.gtk_text_buffer_delete_mark(@ptrCast(self.buffer), start_mark);
        const end_mark = c.gtk_text_buffer_create_mark(
            @ptrCast(self.buffer),
            null,
            &end,
            0,
        ) orelse return error.FoldMarkCreationFailed;
        errdefer c.gtk_text_buffer_delete_mark(@ptrCast(self.buffer), end_mark);
        c.gtk_text_buffer_apply_tag(
            @ptrCast(self.buffer),
            self.fold_tag,
            &start,
            &end,
        );

        self.folds.appendAssumeCapacity(.{
            .anchor_line = region.anchor_line,
            .first_hidden_line = region.first_hidden_line,
            .end_line_exclusive = region.end_line_exclusive,
            .anchor_mark = anchor_mark,
            .start_mark = start_mark,
            .end_mark = end_mark,
        });
        var fold_index = self.folds.items.len - 1;
        while (fold_index > 0 and
            self.folds.items[fold_index - 1].anchor_line >
                self.folds.items[fold_index].anchor_line) : (fold_index -= 1)
        {
            std.mem.swap(
                Fold,
                &self.folds.items[fold_index - 1],
                &self.folds.items[fold_index],
            );
        }
        return true;
    }

    fn unfoldIndex(self: *Document, index: usize) void {
        const fold = self.folds.orderedRemove(index);
        var start: c.GtkTextIter = undefined;
        var end: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_iter_at_mark(
            @ptrCast(self.buffer),
            &start,
            fold.start_mark,
        );
        c.gtk_text_buffer_get_iter_at_mark(
            @ptrCast(self.buffer),
            &end,
            fold.end_mark,
        );
        c.gtk_text_buffer_remove_tag(
            @ptrCast(self.buffer),
            self.fold_tag,
            &start,
            &end,
        );
        c.gtk_text_buffer_delete_mark(@ptrCast(self.buffer), fold.anchor_mark);
        c.gtk_text_buffer_delete_mark(@ptrCast(self.buffer), fold.start_mark);
        c.gtk_text_buffer_delete_mark(@ptrCast(self.buffer), fold.end_mark);
    }

    fn unfoldAtCursor(self: *Document) bool {
        const line = self.cursorLine();
        for (self.folds.items, 0..) |fold, index| {
            var anchor: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_iter_at_mark(
                @ptrCast(self.buffer),
                &anchor,
                fold.anchor_mark,
            );
            if (c.gtk_text_iter_get_line(&anchor) != @as(c_int, @intCast(line)))
                continue;
            self.unfoldIndex(index);
            return true;
        }
        return false;
    }

    fn foldTopLevel(self: *Document, analysis: *const core.folding.Analysis) !usize {
        _ = self.clearFolds();
        var selected = std.array_list.Managed(core.folding.Region).init(self.app.allocator);
        defer selected.deinit();
        var covered_until: u32 = 0;
        for (analysis.regions.items) |region| {
            if (region.anchor_line < covered_until) continue;
            try selected.append(region);
            covered_until = region.end_line_exclusive;
        }
        var index = selected.items.len;
        while (index > 0) {
            index -= 1;
            if (!try self.applyFold(selected.items[index])) continue;
        }
        return self.folds.items.len;
    }

    fn clearFolds(self: *Document) usize {
        const count = self.folds.items.len;
        while (self.folds.items.len > 0) {
            self.unfoldIndex(self.folds.items.len - 1);
        }
        return count;
    }

    fn completeTextAlloc(self: *Document) ![]u8 {
        var start: c.GtkTextIter = undefined;
        var end: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_bounds(@ptrCast(self.buffer), &start, &end);
        const text = c.gtk_text_buffer_get_text(
            @ptrCast(self.buffer),
            &start,
            &end,
            1,
        ) orelse return error.FoldTextUnavailable;
        defer c.g_free(text);
        return self.app.allocator.dupe(u8, std.mem.span(text));
    }
};

fn createSyntaxTag(buffer: *c.GtkSourceBuffer, color: [*:0]const u8) !*c.GtkTextTag {
    return c.gtk_text_buffer_create_tag(
        @ptrCast(buffer),
        null,
        "foreground",
        color,
        @as(?*anyopaque, null),
    ) orelse error.SyntaxTagCreationFailed;
}

fn createSyntaxTags(buffer: *c.GtkSourceBuffer) !SyntaxTags {
    return .{
        .comment = try createSyntaxTag(buffer, "#6b7280"),
        .string = try createSyntaxTag(buffer, "#9ece6a"),
        .number = try createSyntaxTag(buffer, "#ff9e64"),
        .constant = try createSyntaxTag(buffer, "#bb9af7"),
        .keyword = try createSyntaxTag(buffer, "#7aa2f7"),
        .function = try createSyntaxTag(buffer, "#7dcfff"),
        .property = try createSyntaxTag(buffer, "#73daca"),
        .type_name = try createSyntaxTag(buffer, "#2ac3de"),
        .heading = try createSyntaxTag(buffer, "#e0af68"),
        .code_fence = try createSyntaxTag(buffer, "#565f89"),
        .variable = try createSyntaxTag(buffer, "#c0caf5"),
    };
}

fn utf8ByteOffset(text: []const u8, character_offset: usize) ?usize {
    var view = std.unicode.Utf8View.init(text) catch return null;
    var iterator = view.iterator();
    for (0..character_offset) |_| _ = iterator.nextCodepoint() orelse return null;
    return iterator.i;
}

fn appendOwnedLanguagePath(
    allocator: std.mem.Allocator,
    paths: *std.array_list.Managed([:0]u8),
    path: []const u8,
) !void {
    const owned_path = try Compat.dupeZ(allocator, path);
    errdefer allocator.free(owned_path);
    try paths.append(owned_path);
}

const App = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    home: []const u8,
    settings_path: []u8,
    session_path: []u8,
    generated_language_path: []u8,
    resource_root: []u8,
    settings: core.settings.Settings,
    session: core.session.State,
    recent_project_items: [core.session.max_recent_projects]?*c.GtkWidget =
        @splat(null),
    recent_project_actions: [core.session.max_recent_projects]RecentProjectAction = undefined,
    suppress_session_persist: bool = false,
    session_persist_source: c_uint = 0,
    synchronous_worker_running: bool = false,
    session_restores: usize = 0,
    recent_project_activations: usize = 0,
    default_language_paths: std.array_list.Managed([]u8),
    documents: std.array_list.Managed(*Document),
    documents_by_path: std.StringHashMap(*Document),
    active_document: ?*Document = null,
    worker_pools: worker.Pools = .{},
    worker_jobs: std.array_list.Managed(*WorkerJob),
    worker_peak_pending: usize = 0,
    worker_peak_search_batches: u8 = 0,
    worker_cancelled_jobs: usize = 0,
    project_generation: u64 = 0,
    project_search_generation: u64 = 0,
    lsp_generation: u64 = 0,
    task_generation: u64 = 0,
    project_load_ok: bool = true,
    project_search_ok: bool = true,
    project_surface_open: bool = false,
    project_file_path: ?[]u8 = null,
    project_root: ?[]u8 = null,
    project_index: core.project_index.Index = .{},
    project_entry_count: usize = 0,
    project_truncated: bool = false,
    project_load: ?*ProjectLoad = null,
    project_load_source: c_uint = 0,
    project_monitors: std.array_list.Managed(*c.GFileMonitor),
    project_monitor_changes: std.array_list.Managed(core.project_index.FilesystemChange),
    project_monitor_source: c_uint = 0,
    project_monitor_rescan: bool = false,
    project_monitor_truncated: bool = false,
    project_monitor_events: usize = 0,
    project_delta_updates: usize = 0,
    project_delta_fallbacks: usize = 0,
    project_delta_added: usize = 0,
    project_delta_removed: usize = 0,
    project_load_started: ?std.Io.Timestamp = null,
    project_draw_started: ?std.Io.Timestamp = null,
    project_model_commits: usize = 0,
    project_draw_commits: usize = 0,
    project_last_model_ns: u64 = 0,
    project_last_draw_ns: u64 = 0,
    project_lifecycle_smoke: bool = false,
    project_lifecycle_mutate: bool = false,
    project_lifecycle_started: bool = false,
    project_lifecycle_passed: bool = false,
    project_monitor_late_callbacks: usize = 0,
    external_clean_prompts: usize = 0,
    external_dirty_prompts: usize = 0,
    external_reloads: usize = 0,
    untitled_serial: usize = 0,
    language_manager: *c.GtkSourceLanguageManager,
    style_manager: *c.GtkSourceStyleSchemeManager,
    ui_font_provider: *c.GtkCssProvider,
    ui_font_screen: *c.GdkScreen,
    editor_zoom_provider: *c.GtkCssProvider,
    editor_zoom_percent: i16 = editor_zoom_percent_default,
    editor_zoom_scroll_delta: f64 = 0,
    window: *c.GtkWidget = undefined,
    ui_built: bool = false,
    window_destroyed: bool = false,
    main_paned: *c.GtkWidget = undefined,
    sidebar: *c.GtkWidget = undefined,
    sidebar_toggle_button: *c.GtkWidget = undefined,
    project_parent_button: *c.GtkWidget = undefined,
    tree: *c.GtkWidget = undefined,
    tree_store: *c.GtkTreeStore = undefined,
    tree_store_owned: bool = false,
    notebook: *c.GtkWidget = undefined,
    top_bar: *c.GtkWidget = undefined,
    status_bar: *c.GtkWidget = undefined,
    windowed_mode_item: *c.GtkWidget = undefined,
    zen_mode_item: *c.GtkWidget = undefined,
    window_mode: core.settings.WindowMode = .windowed,
    search_box: *c.GtkWidget = undefined,
    search_entry: *c.GtkWidget = undefined,
    search_status: *c.GtkWidget = undefined,
    project_search_box: *c.GtkWidget = undefined,
    project_search_entry: *c.GtkWidget = undefined,
    project_search_status: *c.GtkWidget = undefined,
    project_search_tree: *c.GtkWidget = undefined,
    project_search_store: *c.GtkTreeStore = undefined,
    project_search_store_owned: bool = false,
    project_search_result_count: usize = 0,
    project_search_truncated: bool = false,
    project_search_activations: usize = 0,
    project_search_started: ?std.Io.Timestamp = null,
    project_search_draw_started: ?std.Io.Timestamp = null,
    project_search_cancel_started: ?std.Io.Timestamp = null,
    project_search_cancel_generation: u64 = 0,
    project_search_first_commits: usize = 0,
    project_search_completion_commits: usize = 0,
    project_search_draw_commits: usize = 0,
    project_search_cancel_commits: usize = 0,
    project_search_last_first_ns: u64 = 0,
    project_search_last_total_ns: u64 = 0,
    project_search_last_draw_ns: u64 = 0,
    project_search_last_cancel_ns: u64 = 0,
    quick_open_box: *c.GtkWidget = undefined,
    quick_open_entry: *c.GtkWidget = undefined,
    quick_open_status: *c.GtkWidget = undefined,
    quick_open_tree: *c.GtkWidget = undefined,
    quick_open_store: *c.GtkTreeStore = undefined,
    quick_open_store_owned: bool = false,
    quick_open_result_count: usize = 0,
    quick_open_truncated: bool = false,
    quick_open_activations: usize = 0,
    quick_open_source: c_uint = 0,
    status_label: *c.GtkWidget = undefined,
    position_label: *c.GtkWidget = undefined,
    language_label: *c.GtkWidget = undefined,
    status_widgets_ready: bool = false,
    folding_item: *c.GtkWidget = undefined,
    word_wrap_item: *c.GtkWidget = undefined,
    smoke: bool = false,
    startup_smoke: bool = false,
    window_mode_smoke: bool = false,
    session_restore_smoke: bool = false,
    resource_smoke: bool = false,
    smoke_passed: bool = false,
    smoke_preview: SmokePreview = .none,
    smoke_screenshot_path: ?[]const u8 = null,
    smoke_save_as_path: ?[]const u8 = null,
    smoke_textmate_grammar_path: ?[]const u8 = null,
    smoke_textmate_document_path: ?[]const u8 = null,
    smoke_lifecycle_root: ?[]const u8 = null,
    smoke_search_load_root: ?[]const u8 = null,
    shutting_down: bool = false,

    fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        environ_map: *const std.process.Environ.Map,
        home: []const u8,
        config_home: ?[]const u8,
    ) !App {
        var init_owned = true;
        const settings_path = if (config_home) |root|
            try std.fs.path.join(allocator, &.{ root, "nocted/settings.conf" })
        else
            try std.fs.path.join(allocator, &.{
                home,
                ".config/nocted/settings.conf",
            });
        errdefer if (init_owned) allocator.free(settings_path);
        const settings_directory = std.fs.path.dirname(settings_path) orelse ".";
        const session_path = try std.fs.path.join(allocator, &.{
            settings_directory,
            "session.conf",
        });
        errdefer if (init_owned) allocator.free(session_path);
        const generated_language_path = try std.fs.path.join(allocator, &.{
            settings_directory,
            "imported-language-specs",
        });
        errdefer if (init_owned) allocator.free(generated_language_path);
        var settings = try core.settings.loadAlloc(allocator, io, settings_path);
        errdefer if (init_owned) settings.deinit(allocator);
        var session = try core.session.loadAlloc(allocator, io, session_path);
        errdefer if (init_owned) session.deinit(allocator);
        const resource_root = try locateResourceRoot(allocator, io);
        errdefer if (init_owned) allocator.free(resource_root);
        const ui_font_screen = c.gdk_screen_get_default() orelse
            return error.UiFontScreenUnavailable;
        const native = blk: {
            const language_manager = c.gtk_source_language_manager_new() orelse
                return error.LanguageManagerUnavailable;
            errdefer c.g_object_unref(@ptrCast(language_manager));
            const style_manager = c.gtk_source_style_scheme_manager_new() orelse
                return error.StyleManagerUnavailable;
            errdefer c.g_object_unref(@ptrCast(style_manager));
            const ui_font_provider = c.gtk_css_provider_new() orelse
                return error.UiFontProviderUnavailable;
            errdefer c.g_object_unref(@ptrCast(ui_font_provider));
            const editor_zoom_provider = c.gtk_css_provider_new() orelse
                return error.EditorZoomProviderUnavailable;
            errdefer c.g_object_unref(@ptrCast(editor_zoom_provider));
            break :blk .{
                .language_manager = language_manager,
                .style_manager = style_manager,
                .ui_font_provider = ui_font_provider,
                .editor_zoom_provider = editor_zoom_provider,
            };
        };
        init_owned = false;
        var app = App{
            .allocator = allocator,
            .io = io,
            .environ_map = environ_map,
            .home = home,
            .settings_path = settings_path,
            .session_path = session_path,
            .generated_language_path = generated_language_path,
            .resource_root = resource_root,
            .settings = settings,
            .session = session,
            .default_language_paths = std.array_list.Managed([]u8).init(allocator),
            .documents = std.array_list.Managed(*Document).init(allocator),
            .documents_by_path = std.StringHashMap(*Document).init(allocator),
            .worker_jobs = std.array_list.Managed(*WorkerJob).init(allocator),
            .project_monitors = std.array_list.Managed(*c.GFileMonitor).init(allocator),
            .project_monitor_changes = std.array_list.Managed(
                core.project_index.FilesystemChange,
            ).init(allocator),
            .language_manager = native.language_manager,
            .style_manager = native.style_manager,
            .ui_font_provider = native.ui_font_provider,
            .ui_font_screen = ui_font_screen,
            .editor_zoom_provider = native.editor_zoom_provider,
        };
        errdefer app.deinit();
        app.discardLegacyProjectState();
        try app.applyUiFontCss(app.settings.ui_font_size_pt);
        c.gtk_style_context_add_provider_for_screen(
            app.ui_font_screen,
            @ptrCast(app.ui_font_provider),
            c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 1,
        );
        try app.applyEditorZoomCss(editor_zoom_percent_default);
        try app.captureDefaultLanguagePaths();
        try app.applySyntaxPaths();
        const style_path = try std.fs.path.join(allocator, &.{ resource_root, "styles" });
        defer allocator.free(style_path);
        const style_path_z = try Compat.dupeZ(allocator, style_path);
        defer allocator.free(style_path_z);
        c.gtk_source_style_scheme_manager_prepend_search_path(
            native.style_manager,
            style_path_z.ptr,
        );
        return app;
    }

    fn deinit(self: *App) void {
        if (self.ui_built and !self.window_destroyed)
            c.gtk_widget_destroy(self.window);
        self.cancelSessionPersist();
        self.cancelProjectLoad();
        self.cancelProjectSearch();
        self.cancelQuickOpenUpdate();
        self.cancelProjectMonitoring();
        self.shutdownWorker();
        self.active_document = null;
        self.documents_by_path.deinit();
        while (self.documents.items.len > 0) {
            const document = self.documents.pop().?;
            document.deinit();
            self.allocator.destroy(document);
        }
        self.documents.deinit();
        self.project_index.deinit(self.allocator);
        self.project_monitors.deinit();
        self.project_monitor_changes.deinit();
        for (self.default_language_paths.items) |path| self.allocator.free(path);
        self.default_language_paths.deinit();
        self.settings.deinit(self.allocator);
        self.session.deinit(self.allocator);
        if (self.project_file_path) |path| self.allocator.free(path);
        if (self.project_root) |root| self.allocator.free(root);
        self.allocator.free(self.settings_path);
        self.allocator.free(self.session_path);
        self.allocator.free(self.generated_language_path);
        self.allocator.free(self.resource_root);
        if (self.tree_store_owned) c.g_object_unref(@ptrCast(self.tree_store));
        if (self.project_search_store_owned)
            c.g_object_unref(@ptrCast(self.project_search_store));
        if (self.quick_open_store_owned)
            c.g_object_unref(@ptrCast(self.quick_open_store));
        c.g_object_unref(@ptrCast(self.language_manager));
        c.g_object_unref(@ptrCast(self.style_manager));
        c.gtk_style_context_remove_provider_for_screen(
            self.ui_font_screen,
            @ptrCast(self.ui_font_provider),
        );
        c.g_object_unref(@ptrCast(self.ui_font_provider));
        c.g_object_unref(@ptrCast(self.editor_zoom_provider));
    }

    fn applyUiFontCss(self: *App, font_size_pt: u8) !void {
        var css_buffer: [160]u8 = undefined;
        const css = try Compat.bufPrintZ(
            &css_buffer,
            "label, button, entry, spinbutton, treeview, menuitem " ++
                "{{ font-size: {d}pt; }}",
            .{font_size_pt},
        );
        var error_ptr: ?*c.GError = null;
        if (c.gtk_css_provider_load_from_data(
            self.ui_font_provider,
            css.ptr,
            @intCast(css.len),
            &error_ptr,
        ) == 0) {
            if (error_ptr) |err| c.g_error_free(err);
            return error.UiFontCssFailed;
        }
        if (error_ptr) |err| c.g_error_free(err);
    }

    fn applyEditorZoomCss(self: *App, zoom_percent: i16) !void {
        const scaled_points = @divTrunc(
            editor_font_size_pt_default * zoom_percent + 50,
            100,
        );
        var css_buffer: [72]u8 = undefined;
        const css = try Compat.bufPrintZ(
            &css_buffer,
            "#nocted-editor {{ font-size: {d}pt; }}",
            .{scaled_points},
        );
        var error_ptr: ?*c.GError = null;
        if (c.gtk_css_provider_load_from_data(
            self.editor_zoom_provider,
            css.ptr,
            @intCast(css.len),
            &error_ptr,
        ) == 0) {
            if (error_ptr) |err| c.g_error_free(err);
            return error.EditorZoomCssFailed;
        }
        if (error_ptr) |err| c.g_error_free(err);
    }

    fn setUiFontSize(self: *App, value: u8) !void {
        try core.settings.validateUiFontSize(value);
        const previous = self.settings.ui_font_size_pt;
        if (value == previous) return;

        // Do not leave the current process or its persisted settings half-updated.
        try self.applyUiFontCss(value);
        var candidate = self.settings;
        candidate.ui_font_size_pt = value;
        core.settings.save(self.io, self.settings_path, &candidate) catch |err| {
            self.applyUiFontCss(previous) catch |rollback_err| {
                log.err(
                    "could not restore interface font after settings write failure: {s}",
                    .{@errorName(rollback_err)},
                );
            };
            return err;
        };
        self.settings.ui_font_size_pt = value;

        var status_buffer: [48]u8 = undefined;
        const status = Compat.bufPrintZ(
            &status_buffer,
            "Interface font size: {d} pt",
            .{value},
        ) catch return;
        self.updateStatus(status.ptr);
    }

    fn setEditorZoom(self: *App, percent: i16) !void {
        const bounded = std.math.clamp(
            percent,
            editor_zoom_percent_min,
            editor_zoom_percent_max,
        );
        if (bounded == self.editor_zoom_percent) return;
        try self.applyEditorZoomCss(bounded);
        self.editor_zoom_percent = bounded;
        var status_buffer: [32]u8 = undefined;
        const status = Compat.bufPrintZ(
            &status_buffer,
            "Editor zoom: {d}%",
            .{bounded},
        ) catch return;
        self.updateStatus(status.ptr);
    }

    fn adjustEditorZoom(self: *App, delta: i16) !void {
        try self.setEditorZoom(self.editor_zoom_percent + delta);
    }

    fn showUiFontSettings(self: *App) void {
        const dialog = c.gtk_dialog_new_with_buttons(
            "NoctEd Settings",
            asWindow(self.window),
            c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
            "Cancel",
            c.GTK_RESPONSE_CANCEL,
            "Apply",
            c.GTK_RESPONSE_ACCEPT,
            @as(?*anyopaque, null),
        ) orelse return;
        defer c.gtk_widget_destroy(dialog);
        c.gtk_window_set_resizable(asWindow(dialog), 0);
        c.gtk_dialog_set_default_response(@ptrCast(dialog), c.GTK_RESPONSE_ACCEPT);

        const row = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 12) orelse return;
        c.gtk_widget_set_margin_start(row, 18);
        c.gtk_widget_set_margin_end(row, 18);
        c.gtk_widget_set_margin_top(row, 18);
        c.gtk_widget_set_margin_bottom(row, 18);
        const label = c.gtk_label_new("Interface font size (points)") orelse return;
        c.gtk_label_set_xalign(asLabel(label), 0.0);
        const spin = c.gtk_spin_button_new_with_range(
            core.settings.ui_font_size_pt_min,
            core.settings.ui_font_size_pt_max,
            1,
        ) orelse return;
        c.gtk_spin_button_set_value(
            @ptrCast(spin),
            @floatFromInt(self.settings.ui_font_size_pt),
        );
        c.gtk_spin_button_set_numeric(@ptrCast(spin), 1);
        setAccessibleName(spin, "Interface font size in points");
        c.gtk_widget_set_tooltip_text(
            spin,
            "Sets menus, tabs, sidebar, dialogs, and status text. Document text size is unchanged.",
        );
        c.gtk_box_pack_start(asBox(row), label, 1, 1, 0);
        c.gtk_box_pack_start(asBox(row), spin, 0, 0, 0);
        const area = c.gtk_dialog_get_content_area(@ptrCast(dialog)) orelse return;
        c.gtk_box_pack_start(asBox(area), row, 1, 1, 0);
        c.gtk_widget_show_all(dialog);
        c.gtk_widget_grab_focus(spin);

        if (c.gtk_dialog_run(@ptrCast(dialog)) != c.GTK_RESPONSE_ACCEPT) return;
        const value = c.gtk_spin_button_get_value_as_int(@ptrCast(spin));
        self.setUiFontSize(@intCast(value)) catch
            self.updateStatusError("Interface font size could not be applied");
    }

    fn shutdownWorker(self: *App) void {
        for (self.worker_jobs.items) |job| job.cancelled.store(true, .release);
        while (self.worker_jobs.items.len > 0)
            _ = c.g_main_context_iteration(null, 1);
        self.worker_pools.shutdown();
        self.worker_jobs.deinit();
    }

    fn submitWorkerJob(self: *App, job: *WorkerJob) !void {
        job.environ_map = self.environ_map;
        const admission = worker.admit(self.worker_jobs.items, job);
        self.worker_cancelled_jobs += admission.cancelled_jobs;
        switch (admission.status) {
            .accepted => {},
            .queue_full => return error.WorkerQueueFull,
            .lane_full => return error.WorkerLaneQueueFull,
        }
        const pending_jobs = try worker.enqueue(
            &self.worker_pools,
            &self.worker_jobs,
            job,
            admission.lane,
        );
        self.worker_peak_pending = @max(
            self.worker_peak_pending,
            pending_jobs,
        );
    }

    fn cancelWorkerJobs(self: *App, kind: WorkerJobKind) void {
        self.worker_cancelled_jobs += worker.cancelKind(
            self.worker_jobs.items,
            kind,
        );
    }

    fn hasWorkerJob(self: *App, kind: WorkerJobKind) bool {
        return worker.hasKind(self.worker_jobs.items, kind);
    }

    fn detachWorkerJob(self: *App, job: *WorkerJob) bool {
        return worker.detach(&self.worker_jobs, job);
    }

    fn destroyWorkerJob(self: *App, job: *WorkerJob) void {
        if (!self.detachWorkerJob(job)) return;
        job.deinit();
        self.allocator.destroy(job);
    }

    fn waitWorkerJob(self: *App, job: *WorkerJob) void {
        _ = self;
        while (!job.main_done) _ = c.g_main_context_iteration(null, 1);
    }

    fn resolveSavePathOnWorker(
        self: *App,
        requested_path: []const u8,
    ) ![:0]u8 {
        if (self.synchronous_worker_running)
            return error.SynchronousWorkerReentry;
        self.synchronous_worker_running = true;
        defer self.synchronous_worker_running = false;
        const path = try self.allocator.dupe(u8, requested_path);
        var path_owned = true;
        errdefer if (path_owned) self.allocator.free(path);
        const job = try self.allocator.create(WorkerJob);
        var job_owned = true;
        errdefer if (job_owned) self.allocator.destroy(job);
        job.* = WorkerJob.init(
            self,
            self.allocator,
            self.io,
            0,
            true,
            .{ .resolve_save_path = .{ .requested_path = path } },
            onWorkerComplete,
        );
        path_owned = false;
        errdefer if (job_owned) job.deinit();
        try self.submitWorkerJob(job);
        job_owned = false;
        self.waitWorkerJob(job);
        if (job.failure) |err| {
            self.destroyWorkerJob(job);
            return err;
        }
        const resolved = job.payload.resolve_save_path.resolved orelse {
            self.destroyWorkerJob(job);
            return error.SavePathResolutionFailed;
        };
        job.payload.resolve_save_path.resolved = null;
        self.destroyWorkerJob(job);
        return resolved;
    }

    fn saveContentsOnWorker(
        self: *App,
        path: []const u8,
        contents: []const u8,
        expected_identity: ?core.document.FileIdentity,
    ) !core.document.FileIdentity {
        if (self.synchronous_worker_running)
            return error.SynchronousWorkerReentry;
        self.synchronous_worker_running = true;
        defer self.synchronous_worker_running = false;
        const path_copy = try self.allocator.dupe(u8, path);
        var path_owned = true;
        errdefer if (path_owned) self.allocator.free(path_copy);
        const contents_copy = try self.allocator.dupe(u8, contents);
        var contents_owned = true;
        errdefer if (contents_owned) self.allocator.free(contents_copy);
        const job = try self.allocator.create(WorkerJob);
        var job_owned = true;
        errdefer if (job_owned) self.allocator.destroy(job);
        job.* = WorkerJob.init(
            self,
            self.allocator,
            self.io,
            0,
            true,
            .{ .document_save = .{
                .path = path_copy,
                .contents = contents_copy,
                .expected_identity = expected_identity,
            } },
            onWorkerComplete,
        );
        path_owned = false;
        contents_owned = false;
        errdefer if (job_owned) job.deinit();
        try self.submitWorkerJob(job);
        job_owned = false;
        self.waitWorkerJob(job);
        if (job.failure) |err| {
            self.destroyWorkerJob(job);
            return err;
        }
        const saved_identity = job.payload.document_save.saved_identity orelse {
            self.destroyWorkerJob(job);
            return error.SavedIdentityUnavailable;
        };
        self.destroyWorkerJob(job);
        return saved_identity;
    }

    fn drainWorkerKind(self: *App, kind: WorkerJobKind) void {
        while (self.hasWorkerJob(kind))
            _ = c.g_main_context_iteration(null, 1);
    }

    fn nextProjectGeneration(self: *App) u64 {
        self.project_generation +%= 1;
        if (self.project_generation == 0) self.project_generation = 1;
        return self.project_generation;
    }

    fn nextProjectSearchGeneration(self: *App) u64 {
        self.project_search_generation +%= 1;
        if (self.project_search_generation == 0)
            self.project_search_generation = 1;
        return self.project_search_generation;
    }

    fn showWorkerError(self: *App, prefix: []const u8, err: anyerror) void {
        const status = std.fmt.allocPrintSentinel(
            self.allocator,
            "{s}: {s}",
            .{ prefix, @errorName(err) },
            0,
        ) catch return;
        defer self.allocator.free(status);
        self.updateStatusError(status.ptr);
    }

    fn completeWorkerJob(self: *App, job: *WorkerJob) void {
        if (job.synchronous) {
            job.main_done = true;
            return;
        }
        if (job.kind() == .project_search and job.isCancelled() and
            self.project_search_cancel_started != null and
            job.generation == self.project_search_cancel_generation)
        {
            self.project_search_last_cancel_ns = elapsedNanoseconds(
                self.project_search_cancel_started.?,
                self.io,
            );
            self.project_search_cancel_started = null;
            self.project_search_cancel_generation = 0;
            self.project_search_cancel_commits +|= 1;
        }
        defer self.destroyWorkerJob(job);
        if (self.shutting_down or job.isCancelled()) return;
        if (job.failure) |err| {
            switch (job.kind()) {
                .project_scan => {
                    const payload = &job.payload.project_scan;
                    if (payload.changes.len != 0 and
                        err == error.ProjectDeltaRequiresRescan)
                    {
                        self.project_delta_fallbacks +|= 1;
                        const root = payload.root orelse return;
                        self.openProject(root) catch |fallback_err| {
                            self.project_load_ok = false;
                            self.showWorkerError(
                                "Project fallback scan failed",
                                fallback_err,
                            );
                        };
                        return;
                    }
                    self.project_load_ok = false;
                    self.showWorkerError("Project open failed", err);
                },
                .project_search => {
                    self.project_search_ok = false;
                    const message: [*:0]const u8 = switch (err) {
                        error.SearchQueryTooLong => "Search is limited to 256 bytes",
                        error.InvalidSearchQuery => "Search must be one UTF-8 line",
                        else => "Project search failed",
                    };
                    setStatusFeedback(self.project_search_status, message, true);
                },
                .document_load => {
                    const requested = job.payload.document_load.requested_path;
                    if (self.documents_by_path.get(requested)) |document| {
                        document.loading = false;
                        c.gtk_text_view_set_editable(
                            @ptrCast(document.view),
                            @intFromBool(document.editable),
                        );
                    }
                    self.showWorkerError("Open failed", err);
                },
                .document_save, .resolve_save_path => {},
                .lsp_request => self.showWorkerError("Language service failed", err),
                .task_request => self.showWorkerError("Project task failed", err),
            }
            return;
        }
        switch (job.kind()) {
            .project_scan => {
                if (job.generation != self.project_generation) return;
                self.beginProjectPopulation(job) catch |err| {
                    self.project_load_ok = false;
                    self.showWorkerError("Project open failed", err);
                };
            },
            .project_search => {
                if (job.generation != self.project_search_generation) return;
                self.publishProjectSearch(job);
            },
            .document_load => self.finishDocumentLoad(job),
            .lsp_request => self.finishLanguageFeature(job),
            .task_request => self.finishProjectTask(job),
            .document_save, .resolve_save_path => unreachable,
        }
    }

    fn captureDefaultLanguagePaths(self: *App) !void {
        const paths = c.gtk_source_language_manager_get_search_path(self.language_manager) orelse return;
        var index: usize = 0;
        while (paths[index] != null) : (index += 1) {
            const path = std.mem.span(paths[index].?);
            const owned_path = try self.allocator.dupe(u8, path);
            errdefer self.allocator.free(owned_path);
            try self.default_language_paths.append(owned_path);
        }
    }

    fn applySyntaxPaths(self: *App) !void {
        var owned = std.array_list.Managed([:0]u8).init(self.allocator);
        defer {
            for (owned.items) |path| self.allocator.free(path);
            owned.deinit();
        }
        var pointers = std.array_list.Managed(?[*:0]const u8).init(self.allocator);
        defer pointers.deinit();
        const bundled = try std.fs.path.join(self.allocator, &.{
            self.resource_root,
            "language-specs",
        });
        defer self.allocator.free(bundled);
        try appendOwnedLanguagePath(
            self.allocator,
            &owned,
            self.generated_language_path,
        );
        try pointers.append(owned.items[owned.items.len - 1].ptr);
        try appendOwnedLanguagePath(self.allocator, &owned, bundled);
        try pointers.append(owned.items[owned.items.len - 1].ptr);
        for (self.settings.import_paths.items) |path| {
            try appendOwnedLanguagePath(self.allocator, &owned, path);
            try pointers.append(owned.items[owned.items.len - 1].ptr);
        }
        for (self.default_language_paths.items) |path| {
            try appendOwnedLanguagePath(self.allocator, &owned, path);
            try pointers.append(owned.items[owned.items.len - 1].ptr);
        }
        try pointers.append(null);
        c.gtk_source_language_manager_set_search_path(
            self.language_manager,
            @ptrCast(pointers.items.ptr),
        );
    }

    fn reloadSyntaxPaths(self: *App) !void {
        const previous = self.language_manager;
        const replacement = c.gtk_source_language_manager_new() orelse
            return error.LanguageManagerUnavailable;
        self.language_manager = replacement;
        self.applySyntaxPaths() catch |err| {
            self.language_manager = previous;
            c.g_object_unref(@ptrCast(replacement));
            return err;
        };
        self.refreshDocumentLanguages();
        c.g_object_unref(@ptrCast(previous));
    }

    fn buildUi(self: *App) !void {
        installCss();
        self.window = c.gtk_window_new(c.GTK_WINDOW_TOPLEVEL) orelse
            return error.WindowCreationFailed;
        c.gtk_window_set_title(asWindow(self.window), "NoctEd");
        c.gtk_window_set_default_size(asWindow(self.window), 1220, 760);
        c.gtk_window_set_icon_name(asWindow(self.window), "com.dintty.NoctEd");
        c.gtk_widget_set_name(self.window, "nocted-window");
        setAccessibleName(self.window, "NoctEd editor window");
        connect(self.window, "delete-event", @ptrCast(&onWindowDelete), self);
        connect(self.window, "destroy", @ptrCast(&onWindowDestroy), self);
        connect(self.window, "key-press-event", @ptrCast(&onWindowKeyPress), self);
        connect(self.window, "window-state-event", @ptrCast(&onWindowStateChanged), self);

        const root_box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse unreachable;
        const top_bar = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0) orelse unreachable;
        c.gtk_widget_set_name(top_bar, "nocted-topbar");
        self.top_bar = top_bar;
        self.sidebar_toggle_button = iconButton(
            "view-list-symbolic",
            "Toggle file tree sidebar (Ctrl+B)",
        );
        c.gtk_widget_set_name(self.sidebar_toggle_button, "nocted-chrome-button");
        connect(
            self.sidebar_toggle_button,
            "clicked",
            @ptrCast(&onToggleSidebar),
            self,
        );
        const menu = self.buildMenuBar();
        c.gtk_widget_set_hexpand(menu, 1);
        c.gtk_box_pack_start(asBox(top_bar), self.sidebar_toggle_button, 0, 0, 2);
        c.gtk_box_pack_start(asBox(top_bar), menu, 1, 1, 0);
        self.main_paned = c.gtk_paned_new(c.GTK_ORIENTATION_HORIZONTAL) orelse unreachable;
        c.gtk_widget_set_name(self.main_paned, "nocted-main");
        self.sidebar = try self.buildSidebar();
        self.notebook = c.gtk_notebook_new() orelse unreachable;
        c.gtk_notebook_set_scrollable(asNotebook(self.notebook), 1);
        c.gtk_notebook_set_show_border(asNotebook(self.notebook), 0);
        c.gtk_widget_set_name(self.notebook, "nocted-tabs");
        setAccessibleName(self.notebook, "Open files");
        connect(self.notebook, "switch-page", @ptrCast(&onNotebookSwitch), self);
        connect(self.notebook, "page-reordered", @ptrCast(&onNotebookPageReordered), self);
        c.gtk_paned_pack1(asPaned(self.main_paned), self.sidebar, 0, 0);
        c.gtk_paned_pack2(asPaned(self.main_paned), self.notebook, 1, 0);
        c.gtk_paned_set_position(asPaned(self.main_paned), 238);
        self.search_box = self.buildSearchBar();
        self.project_search_box = try self.buildProjectSearchPanel();
        self.quick_open_box = try self.buildQuickOpenPanel();
        const status = self.buildStatusBar();
        self.status_bar = status;
        c.gtk_box_pack_start(asBox(root_box), top_bar, 0, 0, 0);
        c.gtk_box_pack_start(asBox(root_box), self.main_paned, 1, 1, 0);
        c.gtk_box_pack_start(asBox(root_box), self.quick_open_box, 0, 0, 0);
        c.gtk_box_pack_start(asBox(root_box), self.project_search_box, 0, 0, 0);
        c.gtk_box_pack_start(asBox(root_box), self.search_box, 0, 0, 0);
        c.gtk_box_pack_end(asBox(root_box), status, 0, 0, 0);
        c.gtk_container_add(asContainer(self.window), root_box);
        c.gtk_widget_show_all(self.window);
        self.refreshRecentProjectsMenu();
        // The cached tree stays closed until an explicit .npr project opens it.
        c.gtk_widget_hide(self.sidebar);
        c.gtk_widget_hide(self.quick_open_box);
        c.gtk_widget_hide(self.project_search_box);
        c.gtk_widget_hide(self.search_box);
        self.window_mode = self.settings.window_mode;
        self.applyWindowMode(self.window_mode, false);
        self.updateStatus("Ready");
        self.ui_built = true;
    }

    fn buildMenuBar(self: *App) *c.GtkWidget {
        const bar = c.gtk_menu_bar_new() orelse unreachable;
        c.gtk_widget_set_name(bar, "nocted-menu");
        const file_menu = c.gtk_menu_new() orelse unreachable;
        appendMenuAction(file_menu, "New File", &onNewFile, self);
        appendMenuAction(file_menu, "Open File...", &onOpenFile, self);
        appendMenuAction(file_menu, "Quick Open...", &onShowQuickOpen, self);
        appendMenuAction(
            file_menu,
            "Create Project from Folder...",
            &onOpenFolder,
            self,
        );
        appendMenuAction(file_menu, "Open Project...", &onOpenProject, self);
        const recent_root = c.gtk_menu_item_new_with_label("Open Recent") orelse unreachable;
        const recent_menu = c.gtk_menu_new() orelse unreachable;
        for (0..core.session.max_recent_projects) |index| {
            const item = c.gtk_menu_item_new_with_label("Recent project") orelse unreachable;
            self.recent_project_actions[index] = .{ .app = self, .index = index };
            self.recent_project_items[index] = item;
            connect(
                item,
                "activate",
                @ptrCast(&onRecentProject),
                &self.recent_project_actions[index],
            );
            c.gtk_menu_shell_append(@ptrCast(recent_menu), item);
        }
        appendMenuSeparator(recent_menu);
        appendMenuAction(
            recent_menu,
            "Clear Recent Projects",
            &onClearRecentProjects,
            self,
        );
        c.gtk_menu_item_set_submenu(@ptrCast(recent_root), recent_menu);
        c.gtk_menu_shell_append(@ptrCast(file_menu), recent_root);
        appendMenuSeparator(file_menu);
        appendMenuAction(file_menu, "Save", &onSave, self);
        appendMenuAction(file_menu, "Save As...", &onSaveAs, self);
        appendMenuAction(file_menu, "Close File", &onCloseFile, self);
        appendMenuAction(file_menu, "Close Other Files", &onCloseOtherFiles, self);
        appendMenuAction(file_menu, "Close All Files", &onCloseAllFiles, self);
        appendMenuSeparator(file_menu);
        appendMenuAction(file_menu, "Previous File", &onPreviousFile, self);
        appendMenuAction(file_menu, "Next File", &onNextFile, self);
        appendMenuSeparator(file_menu);
        appendMenuAction(file_menu, "Quit", &onQuit, self);
        appendMenuRoot(bar, "File", file_menu);

        const edit_menu = c.gtk_menu_new() orelse unreachable;
        appendMenuAction(edit_menu, "Undo", &onUndo, self);
        appendMenuAction(edit_menu, "Redo", &onRedo, self);
        appendMenuSeparator(edit_menu);
        appendMenuAction(edit_menu, "Cut", &onCut, self);
        appendMenuAction(edit_menu, "Copy", &onCopy, self);
        appendMenuAction(edit_menu, "Paste", &onPaste, self);
        appendMenuSeparator(edit_menu);
        appendMenuAction(
            edit_menu,
            "Select All Occurrences",
            &onSelectAllOccurrences,
            self,
        );
        appendMenuRoot(bar, "Edit", edit_menu);

        const find_menu = c.gtk_menu_new() orelse unreachable;
        appendMenuAction(find_menu, "Find...", &onShowFind, self);
        appendMenuAction(find_menu, "Find in Files...", &onShowProjectFind, self);
        appendMenuSeparator(find_menu);
        appendMenuAction(find_menu, "Find Next", &onFindNext, self);
        appendMenuAction(find_menu, "Find Previous", &onFindPrevious, self);
        appendMenuRoot(bar, "Find", find_menu);

        const view_menu = c.gtk_menu_new() orelse unreachable;
        appendMenuAction(view_menu, "Zoom In", &onZoomIn, self);
        appendMenuAction(view_menu, "Zoom Out", &onZoomOut, self);
        appendMenuAction(view_menu, "Reset Zoom", &onResetZoom, self);
        appendMenuSeparator(view_menu);
        appendMenuAction(view_menu, "Toggle Side Bar", &onToggleSidebar, self);
        appendMenuAction(view_menu, "Toggle Minimap", &onToggleMinimap, self);
        self.word_wrap_item = appendCheckMenuAction(
            view_menu,
            "Word Wrap",
            self.settings.word_wrap_enabled,
            &onToggleWordWrap,
            self,
        );
        appendMenuSeparator(view_menu);
        self.folding_item = appendCheckMenuAction(
            view_menu,
            "Code Folding Enabled",
            self.settings.code_folding_enabled,
            &onToggleCodeFolding,
            self,
        );
        appendMenuAction(view_menu, "Fold Current Region", &onFoldCurrent, self);
        appendMenuAction(view_menu, "Unfold Current Region", &onUnfoldCurrent, self);
        appendMenuAction(view_menu, "Fold All", &onFoldAll, self);
        appendMenuAction(view_menu, "Unfold All", &onUnfoldAll, self);
        appendMenuSeparator(view_menu);
        self.windowed_mode_item = appendCheckMenuAction(
            view_menu,
            "Windowed",
            self.settings.window_mode == .windowed,
            &onWindowModeWindowed,
            self,
        );
        self.zen_mode_item = appendCheckMenuAction(
            view_menu,
            "Zen Fullscreen (F11)",
            self.settings.window_mode == .zen_fullscreen,
            &onWindowModeZen,
            self,
        );
        appendMenuRoot(bar, "View", view_menu);

        const settings_menu = c.gtk_menu_new() orelse unreachable;
        appendMenuAction(
            settings_menu,
            "Interface Font Size...",
            &onShowUiFontSettings,
            self,
        );
        appendMenuRoot(bar, "Settings", settings_menu);

        const tools_menu = c.gtk_menu_new() orelse unreachable;
        appendMenuAction(
            tools_menu,
            "Import GtkSourceView Definitions...",
            &onImportSyntax,
            self,
        );
        appendMenuAction(
            tools_menu,
            "Import TextMate JSON Grammar...",
            &onImportTextMateGrammar,
            self,
        );
        appendMenuSeparator(tools_menu);
        appendToolAction(tools_menu, "Language Diagnostics", .diagnostics, self);
        appendToolAction(tools_menu, "Language Completion", .completion, self);
        appendToolAction(tools_menu, "Language Hover", .hover, self);
        appendToolAction(tools_menu, "Go to Definition", .definition, self);
        appendToolAction(tools_menu, "Find References", .references, self);
        appendToolAction(tools_menu, "Rename Symbol...", .rename, self);
        appendToolAction(tools_menu, "Document Symbols", .symbols, self);
        appendToolAction(tools_menu, "Format Document", .formatting, self);
        appendMenuSeparator(tools_menu);
        appendToolAction(tools_menu, "Check Project", .check, self);
        appendToolAction(tools_menu, "Build Project", .build, self);
        appendToolAction(tools_menu, "Test Project", .test_project, self);
        appendToolAction(tools_menu, "Run Project", .run, self);
        appendMenuRoot(bar, "Tools", tools_menu);

        const help_menu = c.gtk_menu_new() orelse unreachable;
        appendMenuAction(help_menu, "About NoctEd", &onAbout, self);
        appendMenuRoot(bar, "Help", help_menu);
        return bar;
    }

    fn discardLegacyProjectState(self: *App) void {
        if (self.session.project) |project| self.allocator.free(project);
        self.session.project = null;
        var index: usize = 0;
        while (index < self.session.recent_projects.items.len) {
            const path = self.session.recent_projects.items[index];
            if (isProjectFilePath(path)) {
                index += 1;
            } else {
                self.allocator.free(self.session.recent_projects.orderedRemove(index));
            }
        }
    }

    fn refreshRecentProjectsMenu(self: *App) void {
        for (self.recent_project_items, 0..) |maybe_item, index| {
            const item = maybe_item orelse continue;
            if (index >= self.session.recent_projects.items.len) {
                c.gtk_widget_hide(item);
                continue;
            }
            const path_z = Compat.dupeZ(
                self.allocator,
                self.session.recent_projects.items[index],
            ) catch continue;
            defer self.allocator.free(path_z);
            c.gtk_menu_item_set_label(@ptrCast(item), path_z.ptr);
            c.gtk_widget_show(item);
        }
    }

    fn cancelSessionPersist(self: *App) void {
        if (self.session_persist_source == 0) return;
        _ = c.g_source_remove(self.session_persist_source);
        self.session_persist_source = 0;
    }

    fn scheduleSessionPersist(self: *App) void {
        if (self.suppress_session_persist or self.shutting_down) return;
        self.cancelSessionPersist();
        // ponytail: Snapshot after an edit pause; move encoding to the worker if
        // maximum-size sessions measurably block the GTK thread.
        self.session_persist_source = c.g_timeout_add(1000, onSessionPersist, self);
    }

    fn persistSessionReported(self: *App) bool {
        self.persistSession() catch |err| {
            self.reportSessionPersistError(err);
            return false;
        };
        return true;
    }

    fn reportSessionPersistError(self: *App, err: anyerror) void {
        if (err == error.SessionDocumentTooLarge or
            err == error.SessionStateTooLarge)
        {
            self.updateStatusError("Session is too large; save or close large dirty files");
            return;
        }
        if (err == error.TooManyOpenFiles) {
            self.updateStatusError("Too many open tabs for hot exit; close or save some tabs");
            return;
        }
        var status_buffer: [160]u8 = undefined;
        const status = Compat.bufPrintZ(
            &status_buffer,
            "Unable to preserve unsaved files: {s}",
            .{@errorName(err)},
        ) catch return;
        self.updateStatusError(status.ptr);
    }

    fn persistSession(self: *App) !void {
        if (self.suppress_session_persist) return;
        self.cancelSessionPersist();
        var tabs: [core.session.max_open_files]core.session.TabInput = undefined;
        var snapshots: [core.session.max_open_files]?[]u8 = @splat(null);
        defer for (snapshots) |snapshot| {
            if (snapshot) |contents| self.allocator.free(contents);
        };
        var tab_count: usize = 0;
        var active_tab: ?usize = null;
        const page_count = c.gtk_notebook_get_n_pages(asNotebook(self.notebook));
        if (page_count > core.session.max_open_files)
            return error.TooManyOpenFiles;
        var page_index: c_int = 0;
        while (page_index < page_count and tab_count < tabs.len) : (page_index += 1) {
            const page = c.gtk_notebook_get_nth_page(
                asNotebook(self.notebook),
                page_index,
            ) orelse continue;
            const raw = c.g_object_get_data(@ptrCast(page), document_page_key) orelse
                continue;
            const document: *Document = @ptrCast(@alignCast(raw));
            if (c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) != 0) {
                snapshots[tab_count] = try document.completeTextAlloc();
            }
            tabs[tab_count] = .{
                .path = document.path,
                .display_name = document.display_name,
                .contents = snapshots[tab_count],
            };
            if (self.active_document == document) active_tab = tab_count;
            tab_count += 1;
        }
        try self.session.setSession(
            self.allocator,
            null,
            tabs[0..tab_count],
            active_tab,
        );
        try core.session.save(self.io, self.session_path, &self.session);
    }

    fn rememberProject(self: *App, path: []const u8) void {
        self.session.rememberProject(self.allocator, path) catch return;
        self.refreshRecentProjectsMenu();
        _ = self.persistSessionReported();
    }

    fn openRecentProject(self: *App, index: usize) void {
        if (index >= self.session.recent_projects.items.len) return;
        const path = self.session.recent_projects.items[index];
        self.openProjectFile(path) catch |err| {
            self.showWorkerError("Recent project unavailable", err);
            return;
        };
        self.recent_project_activations +|= 1;
    }

    fn clearRecentProjects(self: *App) void {
        self.session.clearRecentProjects(self.allocator);
        self.refreshRecentProjectsMenu();
        _ = self.persistSessionReported();
        self.updateStatus("Recent projects cleared");
    }

    fn restoreSession(self: *App) bool {
        if (self.session.project == null and self.session.tabs.items.len == 0)
            return false;
        const was_suppressed = self.suppress_session_persist;
        self.suppress_session_persist = true;
        defer self.suppress_session_persist = was_suppressed;
        var restored: [core.session.max_open_files]?*Document = @splat(null);
        var restored_named_edits = false;
        for (self.session.tabs.items, 0..) |tab, index| {
            if (tab.contents) |contents| {
                if (tab.path == null) self.rememberUntitledSerial(tab.display_name);
                const document = self.createDocument(
                    tab.path,
                    tab.display_name,
                    contents,
                    true,
                    null,
                ) catch continue;
                // Session snapshots do not carry their original disk identity.
                // Never bless whatever appeared at the path while we were closed.
                restored_named_edits = restored_named_edits or tab.path != null;
                c.gtk_text_buffer_set_modified(@ptrCast(document.buffer), 1);
                self.updateTabLabel(document);
                restored[index] = document;
                continue;
            }
            if (tab.path) |path| {
                self.openDocument(path) catch continue;
                self.drainDocumentLoads();
                restored[index] = self.documents_by_path.get(path);
            } else {
                self.rememberUntitledSerial(tab.display_name);
                restored[index] = self.createDocument(
                    null,
                    tab.display_name,
                    "",
                    true,
                    null,
                ) catch null;
            }
        }
        if (self.session.active_tab) |index| {
            if (restored[index]) |document| self.focusDocument(document);
        }
        self.session_restores +|= 1;
        if (restored_named_edits)
            self.updateStatusError("Restored unsaved files: use Save As to save a copy; original disk versions are unknown");
        return true;
    }

    fn sessionMatchesOpenTabs(self: *App, state: *const core.session.State) bool {
        const page_count = c.gtk_notebook_get_n_pages(asNotebook(self.notebook));
        if (page_count != state.tabs.items.len) return false;
        var page_index: c_int = 0;
        while (page_index < page_count) : (page_index += 1) {
            const page = c.gtk_notebook_get_nth_page(
                asNotebook(self.notebook),
                page_index,
            ) orelse return false;
            const raw = c.g_object_get_data(@ptrCast(page), document_page_key) orelse
                return false;
            const document: *Document = @ptrCast(@alignCast(raw));
            const tab = state.tabs.items[@intCast(page_index)];
            if (document.path == null and tab.path != null) return false;
            if (document.path != null and tab.path == null) return false;
            if (document.path) |path| {
                if (!std.mem.eql(u8, path, tab.path.?)) return false;
            }
            if (!std.mem.eql(u8, document.display_name, tab.display_name))
                return false;
            const modified = c.gtk_text_buffer_get_modified(
                @ptrCast(document.buffer),
            ) != 0;
            if (modified != tab.modified()) return false;
            if (tab.contents) |expected| {
                const actual = document.completeTextAlloc() catch return false;
                defer self.allocator.free(actual);
                if (!std.mem.eql(u8, actual, expected)) return false;
            }
        }
        const active_page = c.gtk_notebook_get_current_page(asNotebook(self.notebook));
        if (state.active_tab) |index| return active_page == index;
        return active_page < 0;
    }

    fn rememberUntitledSerial(self: *App, display_name: []const u8) void {
        if (std.mem.eql(u8, display_name, "Untitled")) {
            self.untitled_serial = @max(self.untitled_serial, 1);
            return;
        }
        const prefix = "Untitled ";
        if (!std.mem.startsWith(u8, display_name, prefix)) return;
        const serial = std.fmt.parseUnsigned(
            usize,
            display_name[prefix.len..],
            10,
        ) catch return;
        self.untitled_serial = @max(self.untitled_serial, serial);
    }

    fn buildSidebar(self: *App) !*c.GtkWidget {
        const box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse unreachable;
        c.gtk_widget_set_name(box, "nocted-sidebar");
        const header = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0) orelse unreachable;
        c.gtk_widget_set_name(header, "nocted-sidebar-header");
        const title = c.gtk_label_new("FOLDERS") orelse unreachable;
        c.gtk_widget_set_name(title, "nocted-sidebar-title");
        c.gtk_label_set_xalign(asLabel(title), 0.0);
        self.project_parent_button = iconButton(
            "go-up-symbolic",
            "Open parent folder",
        );
        c.gtk_widget_set_name(self.project_parent_button, "nocted-chrome-button");
        c.gtk_widget_set_sensitive(self.project_parent_button, 0);
        const hide_sidebar = iconButton(
            "go-previous-symbolic",
            "Hide file tree sidebar",
        );
        c.gtk_widget_set_name(hide_sidebar, "nocted-chrome-button");
        connect(
            self.project_parent_button,
            "clicked",
            @ptrCast(&onOpenParentFolder),
            self,
        );
        connect(hide_sidebar, "clicked", @ptrCast(&onToggleSidebar), self);
        c.gtk_box_pack_start(asBox(header), title, 1, 1, 0);
        c.gtk_box_pack_end(asBox(header), hide_sidebar, 0, 0, 1);
        c.gtk_box_pack_end(
            asBox(header),
            self.project_parent_button,
            0,
            0,
            1,
        );
        self.tree_store = try createProjectTreeStore();
        self.tree_store_owned = true;
        self.tree = c.gtk_tree_view_new_with_model(@ptrCast(self.tree_store)) orelse unreachable;
        c.gtk_tree_view_set_headers_visible(asTreeView(self.tree), 0);
        c.gtk_tree_view_set_enable_search(asTreeView(self.tree), 1);
        c.gtk_tree_view_set_search_column(asTreeView(self.tree), 0);
        c.gtk_widget_set_name(self.tree, "nocted-project-tree");
        setAccessibleName(self.tree, "Project files");
        const icon = c.gtk_cell_renderer_pixbuf_new() orelse unreachable;
        const text = c.gtk_cell_renderer_text_new() orelse unreachable;
        const column = c.gtk_tree_view_column_new() orelse unreachable;
        c.gtk_tree_view_column_pack_start(column, icon, 0);
        c.gtk_tree_view_column_add_attribute(column, icon, "icon-name", 3);
        c.gtk_tree_view_column_pack_start(column, text, 1);
        c.gtk_tree_view_column_add_attribute(column, text, "text", 0);
        _ = c.gtk_tree_view_append_column(asTreeView(self.tree), column);
        connect(self.tree, "row-activated", @ptrCast(&onProjectRowActivated), self);
        connect(self.tree, "row-expanded", @ptrCast(&onProjectRowExpanded), self);
        connect(self.tree, "draw", @ptrCast(&onProjectTreeDraw), self);
        const scroll = c.gtk_scrolled_window_new(null, null) orelse unreachable;
        c.gtk_scrolled_window_set_policy(
            asScrolled(scroll),
            c.GTK_POLICY_AUTOMATIC,
            c.GTK_POLICY_AUTOMATIC,
        );
        c.gtk_container_add(asContainer(scroll), self.tree);
        c.gtk_box_pack_start(asBox(box), header, 0, 0, 0);
        c.gtk_box_pack_start(asBox(box), scroll, 1, 1, 0);
        c.gtk_widget_set_size_request(box, 180, -1);
        return box;
    }

    fn buildSearchBar(self: *App) *c.GtkWidget {
        const box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 6) orelse unreachable;
        c.gtk_widget_set_name(box, "nocted-search");
        self.search_entry = c.gtk_search_entry_new() orelse unreachable;
        c.gtk_widget_set_hexpand(self.search_entry, 1);
        setAccessibleName(self.search_entry, "Find in current file");
        c.gtk_entry_set_placeholder_text(
            @ptrCast(self.search_entry),
            "Find in current file",
        );
        const previous = iconButton("go-up-symbolic", "Find previous");
        const next = iconButton("go-down-symbolic", "Find next");
        const close = iconButton("window-close-symbolic", "Close find");
        self.search_status = c.gtk_label_new("") orelse unreachable;
        c.gtk_label_set_ellipsize(asLabel(self.search_status), c.PANGO_ELLIPSIZE_END);
        setAccessibleName(self.search_status, "Find status");
        connect(self.search_entry, "search-changed", @ptrCast(&onSearchChanged), self);
        connect(self.search_entry, "activate", @ptrCast(&onFindNext), self);
        connect(previous, "clicked", @ptrCast(&onFindPrevious), self);
        connect(next, "clicked", @ptrCast(&onFindNext), self);
        connect(close, "clicked", @ptrCast(&onHideFind), self);
        c.gtk_box_pack_start(asBox(box), self.search_entry, 1, 1, 8);
        c.gtk_box_pack_start(asBox(box), previous, 0, 0, 0);
        c.gtk_box_pack_start(asBox(box), next, 0, 0, 0);
        c.gtk_box_pack_start(asBox(box), self.search_status, 0, 0, 8);
        c.gtk_box_pack_end(asBox(box), close, 0, 0, 6);
        return box;
    }

    fn buildProjectSearchPanel(self: *App) !*c.GtkWidget {
        const box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse unreachable;
        c.gtk_widget_set_name(box, "nocted-project-search");
        c.gtk_widget_set_size_request(box, -1, 190);
        const controls = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 6) orelse unreachable;
        self.project_search_entry = c.gtk_search_entry_new() orelse unreachable;
        c.gtk_widget_set_hexpand(self.project_search_entry, 1);
        setAccessibleName(self.project_search_entry, "Find in project files");
        c.gtk_entry_set_placeholder_text(
            @ptrCast(self.project_search_entry),
            "Find in project files",
        );
        c.gtk_widget_set_tooltip_text(
            self.project_search_entry,
            "Find matching lines in project files",
        );
        const run = iconButton("edit-find-symbolic", "Find in files");
        const close = iconButton("window-close-symbolic", "Close project search");
        self.project_search_status = c.gtk_label_new("Enter search text") orelse unreachable;
        c.gtk_label_set_xalign(asLabel(self.project_search_status), 0.0);
        c.gtk_label_set_ellipsize(
            asLabel(self.project_search_status),
            c.PANGO_ELLIPSIZE_END,
        );
        setAccessibleName(self.project_search_status, "Project search status");
        connect(self.project_search_entry, "activate", @ptrCast(&onProjectSearch), self);
        connect(run, "clicked", @ptrCast(&onProjectSearch), self);
        connect(close, "clicked", @ptrCast(&onHideProjectFind), self);
        c.gtk_box_pack_start(asBox(controls), self.project_search_entry, 1, 1, 8);
        c.gtk_box_pack_start(asBox(controls), run, 0, 0, 0);
        c.gtk_box_pack_start(asBox(controls), self.project_search_status, 1, 1, 8);
        c.gtk_box_pack_end(asBox(controls), close, 0, 0, 6);

        const column_types = [_]c.GType{
            c.G_TYPE_STRING,
            c.G_TYPE_UINT64,
            c.G_TYPE_UINT64,
        };
        self.project_search_store = c.gtk_tree_store_newv(
            @intCast(column_types.len),
            @constCast(&column_types),
        ) orelse return error.ProjectSearchTreeCreationFailed;
        self.project_search_store_owned = true;
        self.project_search_tree = c.gtk_tree_view_new_with_model(
            @ptrCast(self.project_search_store),
        ) orelse unreachable;
        c.gtk_tree_view_set_headers_visible(asTreeView(self.project_search_tree), 0);
        c.gtk_tree_view_set_enable_search(asTreeView(self.project_search_tree), 1);
        c.gtk_tree_view_set_search_column(asTreeView(self.project_search_tree), 0);
        c.gtk_widget_set_name(self.project_search_tree, "nocted-project-search-results");
        setAccessibleName(self.project_search_tree, "Project search results");
        const text = c.gtk_cell_renderer_text_new() orelse unreachable;
        const column = c.gtk_tree_view_column_new() orelse unreachable;
        c.gtk_tree_view_column_pack_start(column, text, 1);
        c.gtk_tree_view_column_add_attribute(column, text, "text", 0);
        _ = c.gtk_tree_view_append_column(asTreeView(self.project_search_tree), column);
        connect(
            self.project_search_tree,
            "row-activated",
            @ptrCast(&onProjectSearchRowActivated),
            self,
        );
        connect(
            self.project_search_tree,
            "draw",
            @ptrCast(&onProjectSearchTreeDraw),
            self,
        );
        const scroll = c.gtk_scrolled_window_new(null, null) orelse unreachable;
        c.gtk_scrolled_window_set_policy(
            asScrolled(scroll),
            c.GTK_POLICY_AUTOMATIC,
            c.GTK_POLICY_AUTOMATIC,
        );
        c.gtk_container_add(asContainer(scroll), self.project_search_tree);
        c.gtk_box_pack_start(asBox(box), controls, 0, 0, 0);
        c.gtk_box_pack_start(asBox(box), scroll, 1, 1, 0);
        return box;
    }

    fn buildQuickOpenPanel(self: *App) !*c.GtkWidget {
        const box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse unreachable;
        c.gtk_widget_set_name(box, "nocted-quick-open");
        c.gtk_widget_set_size_request(box, -1, 220);
        const controls = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 6) orelse unreachable;
        self.quick_open_entry = c.gtk_search_entry_new() orelse unreachable;
        c.gtk_widget_set_hexpand(self.quick_open_entry, 1);
        setAccessibleName(self.quick_open_entry, "Quick Open file");
        c.gtk_entry_set_placeholder_text(
            @ptrCast(self.quick_open_entry),
            "Quick Open project files",
        );
        self.quick_open_status = c.gtk_label_new("") orelse unreachable;
        c.gtk_label_set_xalign(asLabel(self.quick_open_status), 0.0);
        c.gtk_label_set_ellipsize(
            asLabel(self.quick_open_status),
            c.PANGO_ELLIPSIZE_END,
        );
        setAccessibleName(self.quick_open_status, "Quick Open status");
        const close = iconButton("window-close-symbolic", "Close quick open");
        connect(self.quick_open_entry, "search-changed", @ptrCast(&onQuickOpenChanged), self);
        connect(self.quick_open_entry, "activate", @ptrCast(&onQuickOpenActivate), self);
        connect(
            self.quick_open_entry,
            "key-press-event",
            @ptrCast(&onQuickOpenEntryKeyPress),
            self,
        );
        connect(close, "clicked", @ptrCast(&onHideQuickOpen), self);
        c.gtk_box_pack_start(asBox(controls), self.quick_open_entry, 1, 1, 8);
        c.gtk_box_pack_start(asBox(controls), self.quick_open_status, 1, 1, 8);
        c.gtk_box_pack_end(asBox(controls), close, 0, 0, 6);

        const column_types = [_]c.GType{ c.G_TYPE_STRING, c.G_TYPE_UINT64 };
        self.quick_open_store = c.gtk_tree_store_newv(
            @intCast(column_types.len),
            @constCast(&column_types),
        ) orelse return error.QuickOpenTreeCreationFailed;
        self.quick_open_store_owned = true;
        self.quick_open_tree = c.gtk_tree_view_new_with_model(
            @ptrCast(self.quick_open_store),
        ) orelse unreachable;
        c.gtk_tree_view_set_headers_visible(asTreeView(self.quick_open_tree), 0);
        c.gtk_tree_view_set_enable_search(asTreeView(self.quick_open_tree), 0);
        c.gtk_widget_set_name(self.quick_open_tree, "nocted-quick-open-results");
        setAccessibleName(self.quick_open_tree, "Quick Open results");
        const text = c.gtk_cell_renderer_text_new() orelse unreachable;
        const column = c.gtk_tree_view_column_new() orelse unreachable;
        c.gtk_tree_view_column_pack_start(column, text, 1);
        c.gtk_tree_view_column_add_attribute(column, text, "text", 0);
        _ = c.gtk_tree_view_append_column(asTreeView(self.quick_open_tree), column);
        connect(
            self.quick_open_tree,
            "row-activated",
            @ptrCast(&onQuickOpenRowActivated),
            self,
        );
        const scroll = c.gtk_scrolled_window_new(null, null) orelse unreachable;
        c.gtk_scrolled_window_set_policy(
            asScrolled(scroll),
            c.GTK_POLICY_AUTOMATIC,
            c.GTK_POLICY_AUTOMATIC,
        );
        c.gtk_container_add(asContainer(scroll), self.quick_open_tree);
        c.gtk_box_pack_start(asBox(box), controls, 0, 0, 0);
        c.gtk_box_pack_start(asBox(box), scroll, 1, 1, 0);
        return box;
    }

    fn buildStatusBar(self: *App) *c.GtkWidget {
        const box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10) orelse unreachable;
        c.gtk_widget_set_name(box, "nocted-status");
        self.status_label = c.gtk_label_new("") orelse unreachable;
        self.position_label = c.gtk_label_new("Line 1, Column 1") orelse unreachable;
        self.language_label = c.gtk_label_new("Plain Text") orelse unreachable;
        c.gtk_label_set_xalign(asLabel(self.status_label), 0.0);
        c.gtk_label_set_ellipsize(asLabel(self.status_label), c.PANGO_ELLIPSIZE_END);
        setAccessibleName(self.status_label, "Editor status");
        setAccessibleName(self.position_label, "Cursor position");
        setAccessibleName(self.language_label, "Document language");
        self.status_widgets_ready = true;
        c.gtk_box_pack_start(asBox(box), self.status_label, 1, 1, 8);
        c.gtk_box_pack_end(asBox(box), self.language_label, 0, 0, 8);
        c.gtk_box_pack_end(asBox(box), self.position_label, 0, 0, 0);
        return box;
    }

    fn resolveExistingPath(self: *App, requested_path: []const u8) ![]u8 {
        if (std.fs.path.isAbsolute(requested_path))
            return self.allocator.dupe(u8, requested_path);
        var buffer: [std.fs.max_path_bytes]u8 = undefined;
        const length = try std.Io.Dir.realPathFile(.cwd(), self.io, requested_path, &buffer);
        return self.allocator.dupe(u8, buffer[0..length]);
    }

    fn openProjectFile(self: *App, requested_path: []const u8) !void {
        if (!isProjectFilePath(requested_path)) return error.ProjectFileRequired;
        const resolved = try self.resolveExistingPath(requested_path);
        defer self.allocator.free(resolved);
        var project = try core.project.loadAlloc(self.allocator, self.io, resolved);
        defer project.deinit(self.allocator);
        try self.openProject(project.root);

        const project_file_path = try self.allocator.dupe(u8, resolved);
        if (self.project_file_path) |previous| self.allocator.free(previous);
        self.project_file_path = project_file_path;
        self.project_surface_open = true;
        c.gtk_widget_set_visible(self.sidebar, @intFromBool(self.sidebarShouldShow()));
        self.rememberProject(resolved);
    }

    fn createProjectFileForRoot(self: *App, requested_root: []const u8) !void {
        const root = try self.resolveExistingPath(requested_root);
        defer self.allocator.free(root);
        const project_file_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}",
            .{ root, core.project.extension },
        );
        defer self.allocator.free(project_file_path);
        try core.project.save(self.io, project_file_path, root);
        try self.openProjectFile(project_file_path);
    }

    fn openProject(self: *App, requested_path: []const u8) !void {
        if (self.smoke or self.project_lifecycle_smoke) {
            self.project_surface_open = true;
            c.gtk_widget_set_visible(self.sidebar, @intFromBool(self.sidebarShouldShow()));
        }
        const resolved = try self.resolveExistingPath(requested_path);
        var resolved_owned = true;
        errdefer if (resolved_owned) self.allocator.free(resolved);
        self.cancelProjectLoad();
        self.cancelProjectSearch();
        self.cancelProjectMonitoring();
        const job = try self.allocator.create(WorkerJob);
        errdefer self.allocator.destroy(job);
        job.* = WorkerJob.init(
            self,
            self.allocator,
            self.io,
            self.nextProjectGeneration(),
            false,
            .{ .project_scan = .{ .root = resolved } },
            onWorkerComplete,
        );
        resolved_owned = false;
        errdefer job.deinit();
        self.project_load_started = std.Io.Clock.awake.now(self.io);
        try self.submitWorkerJob(job);
        self.project_load_ok = false;
        self.updateStatus("Opening folder...");
    }

    fn cancelProjectLoad(self: *App) void {
        self.cancelWorkerJobs(.project_scan);
        if (self.project_load_source != 0) {
            _ = c.g_source_remove(self.project_load_source);
            self.project_load_source = 0;
        }
        self.destroyProjectLoad();
    }

    fn destroyProjectLoad(self: *App) void {
        const load = self.project_load orelse return;
        self.project_load = null;
        load.deinit(self.allocator);
        self.allocator.destroy(load);
    }

    fn advanceProjectLoad(self: *App) !bool {
        const load = self.project_load orelse return true;
        const roots = load.index.rootIndices();
        const end = @min(load.next_entry + 128, roots.len);
        while (load.next_entry < end) : (load.next_entry += 1) {
            try self.appendProjectTreeEntry(
                load.staging_store.?,
                &load.root_iter,
                load.index,
                roots[load.next_entry],
            );
        }
        if (load.next_entry < roots.len) return false;
        self.commitProjectLoad(load);
        return true;
    }

    fn appendProjectTreeEntry(
        self: *App,
        store: *c.GtkTreeStore,
        parent: *c.GtkTreeIter,
        index: core.project_index.Index,
        entry_index: u32,
    ) !void {
        if (entry_index >= index.entries.len) return error.InvalidProjectEntry;
        const entry = index.entries[entry_index];
        var iter: c.GtkTreeIter = undefined;
        c.gtk_tree_store_append(store, &iter, parent);
        try treeStoreSet(
            self.allocator,
            store,
            &iter,
            index.basename(entry),
            entry_index,
            entry.kind == .directory,
        );
        if (entry.kind == .directory and entry.child_count != 0) {
            var placeholder: c.GtkTreeIter = undefined;
            c.gtk_tree_store_append(store, &placeholder, &iter);
            try treeStoreSet(
                self.allocator,
                store,
                &placeholder,
                "",
                project_placeholder_entry,
                false,
            );
        }
    }

    fn populateProjectDirectory(self: *App, parent: *c.GtkTreeIter) !void {
        const model: *c.GtkTreeModel = @ptrCast(self.tree_store);
        var child: c.GtkTreeIter = undefined;
        if (c.gtk_tree_model_iter_children(model, &child, parent) == 0) return;
        if (treeValueUInt64(model, &child, 1) != project_placeholder_entry) return;
        _ = c.gtk_tree_store_remove(self.tree_store, &child);
        const parent_index = treeValueUInt64(model, parent, 1);
        if (parent_index >= self.project_index.entries.len) return;
        for (self.project_index.childIndices(
            self.project_index.entries[parent_index],
        )) |entry_index| {
            try self.appendProjectTreeEntry(
                self.tree_store,
                parent,
                self.project_index,
                entry_index,
            );
        }
    }

    fn drainProjectLoad(self: *App) bool {
        self.drainWorkerKind(.project_scan);
        if (self.project_load_source != 0) {
            _ = c.g_source_remove(self.project_load_source);
            self.project_load_source = 0;
        }
        while (self.project_load != null) {
            const complete = self.advanceProjectLoad() catch {
                self.destroyProjectLoad();
                return false;
            };
            if (!complete) continue;
            self.destroyProjectLoad();
        }
        return self.project_load_ok;
    }

    fn beginProjectPopulation(self: *App, job: *WorkerJob) !void {
        var payload = &job.payload.project_scan;
        const resolved = payload.root orelse return error.ProjectRootUnavailable;
        const load = try self.allocator.create(ProjectLoad);
        load.* = .{
            .resolved = resolved,
            .index = payload.index,
            .delta = payload.changes.len != 0,
            .delta_stats = payload.delta_stats,
        };
        payload.root = null;
        payload.index = .{};
        errdefer {
            load.deinit(self.allocator);
            self.allocator.destroy(load);
        }
        load.staging_store = try createProjectTreeStore();
        c.gtk_tree_store_append(load.staging_store.?, &load.root_iter, null);
        try treeStoreSet(
            self.allocator,
            load.staging_store.?,
            &load.root_iter,
            std.fs.path.basename(resolved),
            project_root_entry,
            true,
        );
        self.project_load = load;
        self.project_load_source = c.g_idle_add(onProjectLoadStep, self);
        if (self.project_load_source == 0) {
            self.project_load = null;
            return error.ProjectLoadSourceUnavailable;
        }
    }

    fn commitProjectLoad(self: *App, load: *ProjectLoad) void {
        const draw_started = self.project_load_started orelse
            std.Io.Clock.awake.now(self.io);
        self.project_last_model_ns = elapsedNanoseconds(draw_started, self.io);
        self.project_load_started = null;
        self.project_draw_started = draw_started;
        self.project_model_commits +|= 1;
        self.cancelProjectSearch();
        self.cancelQuickOpenUpdate();
        const old_store = self.tree_store;
        c.gtk_tree_view_set_model(
            asTreeView(self.tree),
            @ptrCast(load.staging_store.?),
        );
        self.tree_store = load.staging_store.?;
        load.staging_store = null;
        if (self.tree_store_owned) c.g_object_unref(@ptrCast(old_store));
        self.tree_store_owned = true;

        if (self.project_root) |old| self.allocator.free(old);
        self.project_root = load.resolved.?;
        load.resolved = null;
        self.project_index.deinit(self.allocator);
        self.project_index = load.index;
        load.index = .{};
        self.project_entry_count = self.project_index.entries.len;
        self.project_truncated = self.project_index.truncated;
        self.project_load_ok = true;
        self.updateProjectNavigationControls();
        if (load.delta) {
            self.project_delta_updates +|= 1;
            self.project_delta_added +|= load.delta_stats.added_entries;
            self.project_delta_removed +|= load.delta_stats.removed_entries;
        }
        self.startProjectMonitoring() catch |err| {
            self.showWorkerError("File monitoring unavailable", err);
        };

        c.gtk_tree_store_clear(self.project_search_store);
        c.gtk_tree_store_clear(self.quick_open_store);
        self.project_search_result_count = 0;
        self.project_search_truncated = false;
        self.quick_open_result_count = 0;
        self.quick_open_truncated = false;
        c.gtk_label_set_text(asLabel(self.project_search_status), "Enter search text");
        c.gtk_label_set_text(asLabel(self.quick_open_status), "");

        if (c.gtk_tree_path_new_first()) |tree_path| {
            _ = c.gtk_tree_view_expand_row(asTreeView(self.tree), tree_path, 0);
            c.gtk_tree_path_free(tree_path);
        }
        const root_name = std.fs.path.basename(self.project_root.?);
        const title = std.fmt.allocPrintSentinel(
            self.allocator,
            "NOCTED - {s}",
            .{root_name},
            0,
        ) catch null;
        if (title) |value| {
            c.gtk_window_set_title(asWindow(self.window), value.ptr);
            self.allocator.free(value);
        }
        var status_buffer: [96]u8 = undefined;
        const status = if (load.delta)
            Compat.bufPrintZ(
                &status_buffer,
                "Project updated (+{d}/-{d})",
                .{ load.delta_stats.added_entries, load.delta_stats.removed_entries },
            ) catch return
        else if (self.project_truncated)
            Compat.bufPrintZ(
                &status_buffer,
                "{d} project items (bounded)",
                .{self.project_entry_count},
            ) catch return
        else
            Compat.bufPrintZ(
                &status_buffer,
                "{d} project items",
                .{self.project_entry_count},
            ) catch return;
        self.updateStatus(status.ptr);
        if (self.project_file_path) |path| self.rememberProject(path);
        if (c.gtk_widget_get_visible(self.quick_open_box) != 0)
            self.scheduleQuickOpenUpdate();
    }

    fn startProjectMonitoring(self: *App) !void {
        self.cancelProjectMonitoring();
        const root = self.project_root orelse return;
        _ = try self.addProjectMonitor(root);
        for (self.project_index.entries) |entry| {
            if (entry.kind != .directory) continue;
            if (self.project_monitors.items.len >= max_project_monitors) {
                self.project_monitor_truncated = true;
                break;
            }
            const full_path = try std.fs.path.join(
                self.allocator,
                &.{ root, self.project_index.path(entry) },
            );
            defer self.allocator.free(full_path);
            _ = try self.addProjectMonitor(full_path);
        }
    }

    fn addProjectMonitor(self: *App, path: []const u8) !bool {
        const path_z = try Compat.dupeZ(self.allocator, path);
        defer self.allocator.free(path_z);
        const file = c.g_file_new_for_path(path_z.ptr) orelse return false;
        defer c.g_object_unref(@ptrCast(file));
        var error_ptr: ?*c.GError = null;
        const monitor = c.g_file_monitor_directory(
            file,
            c.G_FILE_MONITOR_NONE,
            null,
            &error_ptr,
        );
        if (error_ptr) |err| c.g_error_free(err);
        const value = monitor orelse return false;
        errdefer {
            _ = c.g_file_monitor_cancel(value);
            c.g_object_unref(@ptrCast(value));
        }
        c.g_file_monitor_set_rate_limit(value, 50);
        connect(value, "changed", @ptrCast(&onProjectMonitorChanged), self);
        try self.project_monitors.append(value);
        return true;
    }

    fn cancelProjectMonitoring(self: *App) void {
        if (self.project_monitor_source != 0) {
            _ = c.g_source_remove(self.project_monitor_source);
            self.project_monitor_source = 0;
        }
        for (self.project_monitors.items) |monitor| {
            _ = c.g_file_monitor_cancel(monitor);
            c.g_object_unref(@ptrCast(monitor));
        }
        self.project_monitors.clearRetainingCapacity();
        self.clearProjectMonitorChanges();
        self.project_monitor_rescan = false;
        self.project_monitor_truncated = false;
    }

    fn clearProjectMonitorChanges(self: *App) void {
        for (self.project_monitor_changes.items) |change| {
            self.allocator.free(change.path);
            if (change.other_path) |other| self.allocator.free(other);
        }
        self.project_monitor_changes.clearRetainingCapacity();
    }

    fn queueProjectMonitorChange(
        self: *App,
        kind: core.project_index.FilesystemChangeKind,
        path: []const u8,
        other_path: ?[]const u8,
    ) !void {
        if (self.project_monitor_changes.items.len >= max_project_monitor_changes) {
            self.clearProjectMonitorChanges();
            self.project_monitor_rescan = true;
            self.project_delta_fallbacks +|= 1;
            return;
        }
        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);
        const owned_other = if (other_path) |other|
            try self.allocator.dupe(u8, other)
        else
            null;
        errdefer if (owned_other) |other| self.allocator.free(other);
        try self.project_monitor_changes.append(.{
            .kind = kind,
            .path = owned_path,
            .other_path = owned_other,
        });
    }

    fn scheduleProjectMonitorFlush(self: *App, requires_rescan: bool) void {
        if (self.shutting_down) return;
        self.project_monitor_rescan = self.project_monitor_rescan or requires_rescan;
        self.project_monitor_events +|= 1;
        if (self.project_monitor_source != 0) return;
        self.project_monitor_source = c.g_timeout_add(75, onProjectMonitorFlush, self);
    }

    fn flushProjectMonitor(self: *App) void {
        self.project_monitor_source = 0;
        if (self.shutting_down) return;
        self.checkExternalDocuments();
        const root = self.project_root orelse return;
        if (self.project_monitor_rescan) {
            self.project_monitor_rescan = false;
            self.clearProjectMonitorChanges();
            self.openProject(root) catch |err| {
                self.showWorkerError("Project refresh failed", err);
                self.startProjectMonitoring() catch {};
            };
            return;
        }
        if (self.project_monitor_changes.items.len == 0) return;
        self.submitProjectDelta(root) catch |err| {
            self.project_delta_fallbacks +|= 1;
            self.clearProjectMonitorChanges();
            self.openProject(root) catch {
                self.showWorkerError("Project delta failed", err);
                self.startProjectMonitoring() catch {};
            };
        };
    }

    fn submitProjectDelta(self: *App, root: []const u8) !void {
        self.cancelProjectLoad();
        const resolved = try self.allocator.dupe(u8, root);
        var resolved_owned = true;
        errdefer if (resolved_owned) self.allocator.free(resolved);
        const changes = try self.project_monitor_changes.toOwnedSlice();
        var changes_owned = true;
        errdefer if (changes_owned) {
            for (changes) |change| {
                self.allocator.free(change.path);
                if (change.other_path) |other| self.allocator.free(other);
            }
            self.allocator.free(changes);
        };
        const job = try self.allocator.create(WorkerJob);
        errdefer self.allocator.destroy(job);
        job.* = WorkerJob.init(
            self,
            self.allocator,
            self.io,
            self.nextProjectGeneration(),
            false,
            .{ .project_scan = .{
                .root = resolved,
                .index = self.project_index.retain(),
                .changes = changes,
            } },
            onWorkerComplete,
        );
        resolved_owned = false;
        changes_owned = false;
        errdefer job.deinit();
        self.project_load_started = std.Io.Clock.awake.now(self.io);
        try self.submitWorkerJob(job);
        self.updateStatus("Applying project changes...");
    }

    fn openDocument(self: *App, requested_path: []const u8) !void {
        return self.openDocumentAtLine(requested_path, null);
    }

    fn openDocumentAtLine(
        self: *App,
        requested_path: []const u8,
        reveal_line: ?u32,
    ) !void {
        const path = try self.resolveExistingPath(requested_path);
        var path_owned = true;
        errdefer if (path_owned) self.allocator.free(path);
        const job = try self.allocator.create(WorkerJob);
        errdefer self.allocator.destroy(job);
        job.* = WorkerJob.init(
            self,
            self.allocator,
            self.io,
            0,
            false,
            .{ .document_load = .{
                .requested_path = path,
                .reveal_line = reveal_line,
            } },
            onWorkerComplete,
        );
        path_owned = false;
        errdefer job.deinit();
        try self.submitWorkerJob(job);
        self.updateStatus("Opening file...");
    }

    fn finishDocumentLoad(self: *App, job: *WorkerJob) void {
        const payload = &job.payload.document_load;
        const loaded = &(payload.loaded orelse return);
        if (self.documents_by_path.get(loaded.path)) |document| {
            if (document.loading) self.applyReloadedDocument(document, loaded);
            self.focusDocument(document);
            if (payload.reveal_line) |line| self.revealDocumentLine(document, line);
            self.scheduleSessionPersist();
            return;
        }
        const document = self.createDocument(
            loaded.path,
            std.fs.path.basename(loaded.path),
            loaded.contents,
            loaded.mode == .editable,
            loaded.identity,
        ) catch |err| {
            self.showWorkerError("Open failed", err);
            return;
        };
        if (payload.reveal_line) |line| self.revealDocumentLine(document, line);
        self.scheduleSessionPersist();
    }

    fn applyReloadedDocument(
        self: *App,
        document: *Document,
        loaded: *const core.document.LoadedFile,
    ) void {
        if (document.change_serial != document.reload_serial) {
            document.loading = false;
            c.gtk_text_view_set_editable(
                @ptrCast(document.view),
                @intFromBool(document.editable),
            );
            self.scheduleSessionPersist();
            self.updateStatusError("Reload canceled: newer edits remain unsaved");
            return;
        }
        _ = document.clearFolds();
        c.gtk_source_buffer_begin_not_undoable_action(document.buffer);
        c.gtk_text_buffer_set_text(
            @ptrCast(document.buffer),
            loaded.contents.ptr,
            @intCast(loaded.contents.len),
        );
        c.gtk_source_buffer_end_not_undoable_action(document.buffer);
        c.gtk_text_buffer_set_modified(@ptrCast(document.buffer), 0);
        document.editable = loaded.mode == .editable;
        document.identity = loaded.identity;
        document.external_change_pending = false;
        document.loading = false;
        document.scheduleTreeSitterRefresh();
        c.gtk_text_view_set_editable(
            @ptrCast(document.view),
            @intFromBool(document.editable),
        );
        self.updateTabLabel(document);
        self.updateDocumentStatus(document);
        self.external_reloads +|= 1;
        self.updateStatus("Reloaded external change");
    }

    fn checkExternalDocuments(self: *App) void {
        if (self.synchronous_worker_running) return;
        var index: usize = 0;
        while (index < self.documents.items.len) {
            const document = self.documents.items[index];
            index += 1;
            if (document.loading) continue;
            const path = document.path orelse continue;
            const current = core.document.identityForPath(self.io, path) catch null;
            if (document.external_change_pending) {
                if (document.external_identity) |observed| {
                    if (current) |value| {
                        if (observed.eql(value)) continue;
                    }
                } else if (current == null) continue;
            }
            if (document.identity == null and current == null) continue;
            if (document.identity) |previous| {
                if (current) |value| {
                    if (previous.eql(value)) continue;
                }
            }
            const count_before = self.documents.items.len;
            self.resolveExternalDocumentChange(document, current);
            if (self.documents.items.len < count_before) index -|= 1;
        }
    }

    fn resolveExternalDocumentChange(
        self: *App,
        document: *Document,
        current: ?core.document.FileIdentity,
    ) void {
        const dirty = c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) != 0;
        if (current == null) {
            const message: [*:0]const u8 = if (dirty)
                "This file was removed from disk while it has unsaved edits."
            else
                "This file was removed from disk.";
            const dialog = c.gtk_message_dialog_new(
                asWindow(self.window),
                c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
                c.GTK_MESSAGE_WARNING,
                c.GTK_BUTTONS_NONE,
                message,
            ) orelse return;
            _ = c.gtk_dialog_add_button(
                @ptrCast(dialog),
                if (dirty) "Keep Edits" else "Keep Open",
                c.GTK_RESPONSE_CANCEL,
            );
            _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Close File", c.GTK_RESPONSE_REJECT);
            const response = self.runExternalDecisionDialog(
                dialog,
                c.GTK_RESPONSE_CANCEL,
            );
            c.gtk_widget_destroy(dialog);
            document.external_change_pending = true;
            document.external_identity = null;
            if (response == c.GTK_RESPONSE_REJECT) {
                _ = self.closeDocument(document);
            } else if (!dirty) {
                c.gtk_text_buffer_set_modified(@ptrCast(document.buffer), 1);
            }
            return;
        }

        const dialog = c.gtk_message_dialog_new(
            asWindow(self.window),
            c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
            c.GTK_MESSAGE_WARNING,
            c.GTK_BUTTONS_NONE,
            if (dirty)
                "This file changed on disk while it has unsaved edits."
            else
                "This file changed on disk.",
        ) orelse return;
        _ = c.gtk_dialog_add_button(
            @ptrCast(dialog),
            if (dirty) "Keep Edits" else "Keep Current",
            c.GTK_RESPONSE_CANCEL,
        );
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Reload", c.GTK_RESPONSE_ACCEPT);
        if (dirty)
            self.external_dirty_prompts +|= 1
        else
            self.external_clean_prompts +|= 1;
        const response = self.runExternalDecisionDialog(
            dialog,
            if (dirty) c.GTK_RESPONSE_CANCEL else c.GTK_RESPONSE_ACCEPT,
        );
        c.gtk_widget_destroy(dialog);
        if (response == c.GTK_RESPONSE_ACCEPT) {
            document.reload_serial = document.change_serial;
            document.loading = true;
            c.gtk_text_view_set_editable(@ptrCast(document.view), 0);
            self.openDocument(document.path.?) catch |err| {
                document.loading = false;
                c.gtk_text_view_set_editable(
                    @ptrCast(document.view),
                    @intFromBool(document.editable),
                );
                self.showWorkerError("Reload failed", err);
            };
        } else {
            document.external_change_pending = true;
            document.external_identity = current;
            if (!dirty) c.gtk_text_buffer_set_modified(@ptrCast(document.buffer), 1);
            self.updateStatusError("Kept local edits; use Save As to save a copy without replacing the external file");
        }
    }

    fn runExternalDecisionDialog(
        self: *App,
        dialog: *c.GtkWidget,
        smoke_response: c_int,
    ) c_int {
        if (!self.smoke) return c.gtk_dialog_run(@ptrCast(dialog));
        var request = SmokeDialogResponse{
            .dialog = dialog,
            .response = smoke_response,
        };
        if (c.g_idle_add(onSmokeDialogResponse, &request) == 0)
            return smoke_response;
        return c.gtk_dialog_run(@ptrCast(dialog));
    }

    fn smokeExternalChanges(self: *App, document: *Document) bool {
        const path = document.path orelse return false;
        if (c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) != 0)
            return false;
        const original = document.completeTextAlloc() catch return false;
        defer self.allocator.free(original);
        const clean_prompts_before = self.external_clean_prompts;
        const reloads_before = self.external_reloads;
        const events_before = self.project_monitor_events;
        std.Io.Dir.cwd().writeFile(self.io, .{
            .sub_path = path,
            .data = "const external_clean = true;\n",
        }) catch return false;
        for (0..500) |_| {
            while (c.g_main_context_iteration(null, 0) != 0) {}
            if (self.external_clean_prompts > clean_prompts_before and
                self.external_reloads > reloads_before)
                break;
            self.io.sleep(.fromMilliseconds(2), .awake) catch {};
        }
        self.drainDocumentLoads();
        const clean_text = document.completeTextAlloc() catch return false;
        defer self.allocator.free(clean_text);
        const clean_ok = self.external_clean_prompts == clean_prompts_before + 1 and
            self.external_reloads == reloads_before + 1 and
            self.project_monitor_events > events_before and
            std.mem.eql(u8, clean_text, "const external_clean = true;\n") and
            c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) == 0;
        if (!clean_ok) return false;

        var end: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_end_iter(@ptrCast(document.buffer), &end);
        c.gtk_text_buffer_insert(
            @ptrCast(document.buffer),
            &end,
            "// local dirty marker\n",
            -1,
        );
        const dirty_prompts_before = self.external_dirty_prompts;
        std.Io.Dir.cwd().writeFile(self.io, .{
            .sub_path = path,
            .data = "const external_disk = true;\n",
        }) catch return false;
        for (0..500) |_| {
            while (c.g_main_context_iteration(null, 0) != 0) {}
            if (self.external_dirty_prompts > dirty_prompts_before) break;
            self.io.sleep(.fromMilliseconds(2), .awake) catch {};
        }
        const dirty_text = document.completeTextAlloc() catch return false;
        defer self.allocator.free(dirty_text);
        const dirty_ok = self.external_dirty_prompts == dirty_prompts_before + 1 and
            std.mem.indexOf(u8, dirty_text, "local dirty marker") != null and
            c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) != 0;
        std.Io.Dir.cwd().writeFile(self.io, .{
            .sub_path = path,
            .data = original,
        }) catch return false;
        c.gtk_source_buffer_begin_not_undoable_action(document.buffer);
        c.gtk_text_buffer_set_text(
            @ptrCast(document.buffer),
            original.ptr,
            @intCast(original.len),
        );
        c.gtk_source_buffer_end_not_undoable_action(document.buffer);
        c.gtk_text_buffer_set_modified(@ptrCast(document.buffer), 0);
        document.identity = core.document.identityForPath(self.io, path) catch null;
        return dirty_ok;
    }

    fn drainDocumentLoads(self: *App) void {
        self.drainWorkerKind(.document_load);
    }

    fn newDocument(self: *App) !void {
        self.untitled_serial +%= 1;
        if (self.untitled_serial == 0) self.untitled_serial = 1;
        const name = if (self.untitled_serial == 1)
            try self.allocator.dupe(u8, "Untitled")
        else
            try std.fmt.allocPrint(
                self.allocator,
                "Untitled {d}",
                .{self.untitled_serial},
            );
        defer self.allocator.free(name);
        _ = try self.createDocument(null, name, "", true, null);
        self.updateStatus("New file. Press Ctrl+S to save");
    }

    fn createDocument(
        self: *App,
        path: ?[]const u8,
        display_name: []const u8,
        contents: []const u8,
        editable: bool,
        identity: ?core.document.FileIdentity,
    ) !*Document {
        if (self.documents.items.len >= core.session.max_open_files)
            return error.TooManyOpenFiles;
        const language = if (path) |value| blk: {
            const path_z = try Compat.dupeZ(self.allocator, value);
            defer self.allocator.free(path_z);
            break :blk c.gtk_source_language_manager_guess_language(
                self.language_manager,
                path_z.ptr,
                null,
            );
        } else null;
        try self.documents.ensureUnusedCapacity(1);
        if (path != null) try self.documents_by_path.ensureUnusedCapacity(1);
        var metadata_owned = true;
        const owned_path = if (path) |value|
            try Compat.dupeZ(self.allocator, value)
        else
            null;
        errdefer if (metadata_owned) {
            if (owned_path) |value| self.allocator.free(value);
        };
        const owned_display_name = try Compat.dupeZ(self.allocator, display_name);
        errdefer if (metadata_owned) self.allocator.free(owned_display_name);
        const document = try self.allocator.create(Document);
        var document_initialized = false;
        errdefer if (!document_initialized) self.allocator.destroy(document);
        const buffer = (if (language) |detected|
            c.gtk_source_buffer_new_with_language(detected)
        else
            c.gtk_source_buffer_new(null)) orelse return error.EditorBufferCreationFailed;
        var buffer_owned = true;
        errdefer if (buffer_owned) c.g_object_unref(@ptrCast(buffer));
        c.gtk_source_buffer_set_highlight_syntax(buffer, 1);
        c.gtk_source_buffer_set_highlight_matching_brackets(buffer, 1);
        c.gtk_source_buffer_set_max_undo_levels(buffer, 128);
        c.gtk_source_buffer_set_implicit_trailing_newline(buffer, 0);
        if (c.gtk_source_style_scheme_manager_get_scheme(self.style_manager, "nocted-dark")) |scheme|
            c.gtk_source_buffer_set_style_scheme(buffer, scheme);
        c.gtk_source_buffer_begin_not_undoable_action(buffer);
        c.gtk_text_buffer_set_text(
            @ptrCast(buffer),
            contents.ptr,
            @intCast(contents.len),
        );
        c.gtk_source_buffer_end_not_undoable_action(buffer);
        var start: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_start_iter(@ptrCast(buffer), &start);
        c.gtk_text_buffer_select_range(@ptrCast(buffer), &start, &start);
        c.gtk_text_buffer_set_modified(@ptrCast(buffer), 0);
        const fold_tag = c.gtk_text_buffer_create_tag(
            @ptrCast(buffer),
            null,
            "invisible",
            @as(c_int, 1),
            "scale",
            @as(f64, 0.01),
            "pixels-above-lines",
            @as(c_int, 0),
            "pixels-below-lines",
            @as(c_int, 0),
            @as(?*anyopaque, null),
        ) orelse return error.FoldTagCreationFailed;
        const selection_tag = c.gtk_text_buffer_create_tag(
            @ptrCast(buffer),
            null,
            "background",
            "#263249",
            "foreground",
            "#d7dde8",
            @as(?*anyopaque, null),
        ) orelse return error.SelectionTagCreationFailed;
        const syntax_tags = try createSyntaxTags(buffer);

        const view = c.gtk_source_view_new_with_buffer(buffer) orelse unreachable;
        c.gtk_source_view_set_show_line_numbers(@ptrCast(view), 1);
        c.gtk_source_view_set_highlight_current_line(@ptrCast(view), 1);
        c.gtk_source_view_set_auto_indent(@ptrCast(view), 1);
        c.gtk_source_view_set_indent_on_tab(@ptrCast(view), 1);
        c.gtk_source_view_set_smart_backspace(@ptrCast(view), 1);
        c.gtk_source_view_set_smart_home_end(@ptrCast(view), c.GTK_SOURCE_SMART_HOME_END_BEFORE);
        c.gtk_source_view_set_tab_width(@ptrCast(view), 4);
        c.gtk_source_view_set_insert_spaces_instead_of_tabs(@ptrCast(view), 1);
        c.gtk_text_view_set_monospace(@ptrCast(view), 1);
        c.gtk_text_view_set_wrap_mode(
            @ptrCast(view),
            if (self.settings.word_wrap_enabled) c.GTK_WRAP_WORD else c.GTK_WRAP_NONE,
        );
        c.gtk_text_view_set_editable(
            @ptrCast(view),
            @intFromBool(editable),
        );
        c.gtk_widget_set_name(view, "nocted-editor");
        c.gtk_style_context_add_provider(
            c.gtk_widget_get_style_context(view),
            @ptrCast(self.editor_zoom_provider),
            c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 2,
        );
        c.gtk_widget_add_events(
            view,
            c.GDK_SCROLL_MASK | c.GDK_SMOOTH_SCROLL_MASK,
        );
        setAccessibleName(view, "Document editor");
        const editor_scroll = c.gtk_scrolled_window_new(null, null) orelse unreachable;
        c.gtk_scrolled_window_set_policy(
            asScrolled(editor_scroll),
            c.GTK_POLICY_AUTOMATIC,
            c.GTK_POLICY_AUTOMATIC,
        );
        c.gtk_container_add(asContainer(editor_scroll), view);
        const page_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0) orelse unreachable;
        c.gtk_box_pack_start(asBox(page_box), editor_scroll, 1, 1, 0);

        const tab_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 4) orelse unreachable;
        const tab_label = c.gtk_label_new(owned_display_name.ptr) orelse unreachable;
        const close = iconButton("window-close-symbolic", "Close file");
        c.gtk_widget_set_name(close, "nocted-tab-close");
        c.gtk_widget_set_size_request(close, 28, 18);
        c.gtk_box_pack_start(asBox(tab_box), tab_label, 1, 1, 0);
        c.gtk_box_pack_end(asBox(tab_box), close, 0, 0, 0);

        document.* = .{
            .app = self,
            .path = owned_path,
            .display_name = owned_display_name,
            .page = page_box,
            .view = view,
            .map = null,
            .buffer = buffer,
            .tab_label = tab_label,
            .tab_close = close,
            .identity = identity,
            .syntax_tags = syntax_tags,
            .fold_tag = fold_tag,
            .folds = std.array_list.Managed(Fold).init(self.allocator),
            .selection_tag = selection_tag,
            .secondary_selections = std.array_list.Managed(SecondarySelection).init(self.allocator),
            .editable = editable,
        };
        document_initialized = true;
        metadata_owned = false;
        buffer_owned = false;
        document.configureTreeSitter(path);
        errdefer {
            document.deinit();
            self.allocator.destroy(document);
        }
        self.documents.appendAssumeCapacity(document);
        if (document.path) |document_path|
            self.documents_by_path.putAssumeCapacity(document_path, document);
        c.g_object_set_data(
            @ptrCast(page_box),
            document_page_key,
            @ptrCast(document),
        );
        if (self.settings.minimap_visible) _ = document.ensureMinimap() catch null;
        connect(buffer, "changed", @ptrCast(&onBufferChanged), document);
        connect(buffer, "modified-changed", @ptrCast(&onBufferModified), document);
        connect(buffer, "mark-set", @ptrCast(&onBufferMarkSet), document);
        connect(view, "key-press-event", @ptrCast(&onEditorKeyPress), document);
        connect(view, "scroll-event", @ptrCast(&onEditorScroll), document);
        connect(close, "clicked", @ptrCast(&onTabClose), document);
        const page_number = c.gtk_notebook_append_page(
            asNotebook(self.notebook),
            page_box,
            tab_box,
        );
        c.gtk_notebook_set_tab_reorderable(asNotebook(self.notebook), page_box, 1);
        c.gtk_widget_show_all(page_box);
        c.gtk_widget_show_all(tab_box);
        c.gtk_notebook_set_current_page(asNotebook(self.notebook), page_number);
        self.active_document = document;
        c.gtk_widget_grab_focus(view);
        self.updateDocumentStatus(document);
        self.updateTabLabel(document);
        self.updateStatus(if (document.editable) "Ready" else "Read-only preview");
        self.scheduleSessionPersist();
        return document;
    }

    fn focusDocument(self: *App, document: *Document) void {
        self.active_document = document;
        const page = c.gtk_notebook_page_num(asNotebook(self.notebook), document.page);
        if (page >= 0) c.gtk_notebook_set_current_page(asNotebook(self.notebook), page);
        c.gtk_widget_grab_focus(document.view);
        self.scheduleSessionPersist();
    }

    fn selectAllOccurrences(self: *App) void {
        const document = self.currentDocument() orelse return;
        var matches = document.selectAllOccurrences() catch |err| {
            self.updateStatus(switch (err) {
                error.EmptySelection => "Select text before adding occurrences",
                error.SingleOccurrence => "No other occurrences",
                error.SelectionTooLarge => "Selection is too large",
                else => "Unable to select occurrences",
            });
            return;
        };
        defer matches.deinit(self.allocator);
        var buffer: [128]u8 = undefined;
        const status = if (matches.truncated)
            Compat.bufPrintZ(
                &buffer,
                "{d} occurrences selected (bounded)",
                .{matches.ranges.len},
            ) catch return
        else
            Compat.bufPrintZ(
                &buffer,
                "{d} occurrences selected",
                .{matches.ranges.len},
            ) catch return;
        self.updateStatus(status.ptr);
    }

    fn currentDocument(self: *App) ?*Document {
        if (self.shutting_down) return null;
        return self.active_document;
    }

    fn saveDocument(self: *App, document: *Document) bool {
        if (!document.editable) {
            self.updateStatus("Read-only preview");
            return false;
        }
        const path = document.path orelse return self.promptSaveAs(document);
        if (!self.writeDocumentContents(document, path)) return false;
        if (!self.persistSessionReported()) return true;
        self.updateStatus(if (c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) == 0)
            "Saved"
        else
            "Saved; newer edits remain unsaved");
        return true;
    }

    fn writeDocumentContents(
        self: *App,
        document: *Document,
        path: [:0]const u8,
    ) bool {
        if (document.loading) {
            self.updateStatusError("Save blocked: wait for reload to finish");
            return false;
        }
        const same_file = if (document.path) |original|
            std.mem.eql(u8, original, path)
        else
            false;
        const expected_identity: ?core.document.FileIdentity = if (same_file)
            document.identity orelse {
                self.updateStatusError("Save blocked: original disk version is unknown; use Save As to save a copy");
                return false;
            }
        else blk: {
            _ = std.Io.Dir.cwd().statFile(self.io, path, .{}) catch |err| {
                if (err == error.FileNotFound) break :blk null;
                self.showWorkerError("Save failed", err);
                return false;
            };
            break :blk core.document.identityForPath(self.io, path) catch |err| {
                self.showWorkerError("Save failed", err);
                return false;
            };
        };
        const contents = document.completeTextAlloc() catch {
            self.updateStatusError("Save failed: unable to restore folded text");
            return false;
        };
        defer self.allocator.free(contents);
        self.updateStatus("Saving...");
        const saved_identity = self.saveContentsOnWorker(path, contents, expected_identity) catch |err| {
            if (err == error.DocumentSaveConflict) {
                self.updateStatusError("Save blocked: file changed or was removed on disk; use Save As to save a copy");
                return false;
            }
            const status = std.fmt.allocPrintSentinel(
                self.allocator,
                "Save failed: {s}",
                .{@errorName(err)},
                0,
            ) catch return false;
            defer self.allocator.free(status);
            self.updateStatusError(status);
            return false;
        };
        document.identity = saved_identity;
        document.external_change_pending = false;
        const current = document.completeTextAlloc() catch return true;
        defer self.allocator.free(current);
        if (std.mem.eql(u8, current, contents))
            c.gtk_text_buffer_set_modified(@ptrCast(document.buffer), 0);
        return true;
    }

    fn saveDocumentAsPath(
        self: *App,
        document: *Document,
        requested_path: []const u8,
    ) bool {
        if (!document.editable) {
            self.updateStatus("Read-only preview");
            return false;
        }
        const resolved = self.resolveSavePathOnWorker(requested_path) catch |err| {
            const status = std.fmt.allocPrintSentinel(
                self.allocator,
                "Save As failed: {s}",
                .{@errorName(err)},
                0,
            ) catch return false;
            defer self.allocator.free(status);
            self.updateStatusError(status.ptr);
            return false;
        };
        var resolved_owned = true;
        defer if (resolved_owned) self.allocator.free(resolved);
        if (self.documents_by_path.get(resolved)) |candidate| {
            if (candidate != document) {
                self.updateStatusError("File is already open");
                return false;
            }
        }
        self.documents_by_path.ensureUnusedCapacity(1) catch {
            self.updateStatusError("Save As failed: out of memory");
            return false;
        };
        const display_name = Compat.dupeZ(
            self.allocator,
            std.fs.path.basename(resolved),
        ) catch {
            self.updateStatusError("Save As failed: out of memory");
            return false;
        };
        var display_name_owned = true;
        defer if (display_name_owned) self.allocator.free(display_name);
        const previous_identity = document.identity;
        var published = false;
        defer if (!published) {
            document.identity = previous_identity;
        };
        if (!self.writeDocumentContents(document, resolved)) return false;
        // Worker waits dispatch document loads, so the map may have changed
        // since the preflight collision check and reservation.
        if (self.documents_by_path.get(resolved)) |candidate| {
            if (candidate != document) {
                c.gtk_text_buffer_set_modified(@ptrCast(document.buffer), 1);
                self.updateStatusError("Copy written, but destination opened during save; original edits retained");
                return false;
            }
        }
        self.documents_by_path.ensureUnusedCapacity(1) catch {
            c.gtk_text_buffer_set_modified(@ptrCast(document.buffer), 1);
            self.updateStatusError("Copy written, but Save As could not finish; original edits retained");
            return false;
        };

        if (document.path) |old_path| {
            _ = self.documents_by_path.remove(old_path);
            self.allocator.free(old_path);
        }
        self.allocator.free(document.display_name);
        document.path = resolved;
        resolved_owned = false;
        self.documents_by_path.putAssumeCapacity(document.path.?, document);
        document.display_name = display_name;
        display_name_owned = false;
        published = true;
        _ = self.persistSessionReported();
        const language = c.gtk_source_language_manager_guess_language(
            self.language_manager,
            resolved.ptr,
            null,
        );
        c.gtk_source_buffer_set_language(document.buffer, language);
        document.configureTreeSitter(resolved);
        self.updateTabLabel(document);
        self.updateDocumentStatus(document);
        if (self.project_root) |root| {
            if (projectRelativePath(root, resolved)) |relative| {
                self.queueProjectMonitorChange(.created, relative, null) catch {
                    self.project_monitor_rescan = true;
                    self.project_delta_fallbacks +|= 1;
                };
                self.scheduleProjectMonitorFlush(self.project_monitor_rescan);
                if (self.project_monitor_source != 0) {
                    _ = c.g_source_remove(self.project_monitor_source);
                    self.project_monitor_source = 0;
                }
                self.flushProjectMonitor();
            }
        }
        self.focusDocument(document);
        self.updateStatus(if (c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) == 0)
            "Saved As"
        else
            "Saved As; newer edits remain unsaved");
        return true;
    }

    fn promptSaveAs(self: *App, document: *Document) bool {
        const dialog = c.gtk_file_chooser_dialog_new(
            "Save File As",
            asWindow(self.window),
            c.GTK_FILE_CHOOSER_ACTION_SAVE,
            "Cancel",
            c.GTK_RESPONSE_CANCEL,
            "Save",
            c.GTK_RESPONSE_ACCEPT,
            @as(?*anyopaque, null),
        ) orelse return false;
        defer c.gtk_widget_destroy(dialog);
        c.gtk_file_chooser_set_local_only(@ptrCast(dialog), 1);
        c.gtk_file_chooser_set_do_overwrite_confirmation(@ptrCast(dialog), 1);
        const folder = if (document.path) |path|
            std.fs.path.dirname(path)
        else
            self.project_root;
        if (folder) |value| {
            const folder_z = Compat.dupeZ(self.allocator, value) catch null;
            if (folder_z) |folder_path| {
                _ = c.gtk_file_chooser_set_current_folder(
                    @ptrCast(dialog),
                    folder_path.ptr,
                );
                self.allocator.free(folder_path);
            }
        }
        const name_z = Compat.dupeZ(self.allocator, document.display_name) catch null;
        if (name_z) |name| {
            c.gtk_file_chooser_set_current_name(@ptrCast(dialog), name.ptr);
            self.allocator.free(name);
        }
        if (c.gtk_dialog_run(@ptrCast(dialog)) != c.GTK_RESPONSE_ACCEPT) {
            self.updateStatus("Save canceled");
            return false;
        }
        const selected = c.gtk_file_chooser_get_filename(@ptrCast(dialog)) orelse
            return false;
        defer c.g_free(selected);
        return self.saveDocumentAsPath(document, std.mem.span(selected));
    }

    fn savedFileMatchesBuffer(self: *App, document: *Document) bool {
        const path = document.path orelse return false;
        const text = document.completeTextAlloc() catch return false;
        defer self.allocator.free(text);
        var loaded = core.document.loadFileAlloc(
            self.allocator,
            self.io,
            path,
        ) catch return false;
        defer loaded.deinit(self.allocator);
        return std.mem.eql(u8, text, loaded.contents);
    }

    fn confirmCloseDocument(self: *App, document: *Document) bool {
        if (self.synchronous_worker_running) {
            self.updateStatus("Wait for the current save to finish");
            return false;
        }
        if (c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) == 0) return true;
        const basename_z = Compat.dupeZ(self.allocator, document.display_name) catch return false;
        defer self.allocator.free(basename_z);
        const dialog = c.gtk_message_dialog_new(
            asWindow(self.window),
            c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
            c.GTK_MESSAGE_WARNING,
            c.GTK_BUTTONS_NONE,
            "Save changes to %s?",
            basename_z.ptr,
        ) orelse return false;
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Cancel", c.GTK_RESPONSE_CANCEL);
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Discard", c.GTK_RESPONSE_REJECT);
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Save", c.GTK_RESPONSE_ACCEPT);
        c.gtk_dialog_set_default_response(@ptrCast(dialog), c.GTK_RESPONSE_ACCEPT);
        const response = c.gtk_dialog_run(@ptrCast(dialog));
        c.gtk_widget_destroy(dialog);
        if (response == c.GTK_RESPONSE_ACCEPT) {
            if (!self.saveDocument(document)) return false;
            return c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) == 0;
        }
        return response == c.GTK_RESPONSE_REJECT;
    }

    fn closeDocument(self: *App, document: *Document) bool {
        if (!self.confirmCloseDocument(document)) return false;
        if (document.path) |path| _ = self.documents_by_path.remove(path);
        if (self.active_document == document) self.active_document = null;
        const page = c.gtk_notebook_page_num(asNotebook(self.notebook), document.page);
        if (page >= 0) c.gtk_notebook_remove_page(asNotebook(self.notebook), page);
        for (self.documents.items, 0..) |candidate, index| {
            if (candidate != document) continue;
            _ = self.documents.orderedRemove(index);
            break;
        }
        document.deinit();
        self.allocator.destroy(document);
        if (self.currentDocument()) |current| self.updateDocumentStatus(current) else {
            c.gtk_label_set_text(asLabel(self.language_label), "Plain Text");
            c.gtk_label_set_text(asLabel(self.position_label), "Line 1, Column 1");
            self.updateStatus("No file open; use File > New File or Open File");
        }
        _ = self.persistSessionReported();
        return true;
    }

    fn closeOtherDocuments(self: *App) bool {
        const keep = self.currentDocument() orelse return true;
        var index: usize = 0;
        while (index < self.documents.items.len) {
            const document = self.documents.items[index];
            if (document == keep) {
                index += 1;
                continue;
            }
            if (!self.closeDocument(document)) return false;
        }
        self.updateStatus("Closed other files");
        return true;
    }

    fn closeAllDocuments(self: *App) bool {
        while (self.documents.items.len > 0) {
            const document = self.documents.items[self.documents.items.len - 1];
            if (!self.closeDocument(document)) return false;
        }
        return true;
    }

    fn cycleDocument(self: *App, direction: i32) bool {
        const count = c.gtk_notebook_get_n_pages(asNotebook(self.notebook));
        if (count < 2) return false;
        const current = c.gtk_notebook_get_current_page(asNotebook(self.notebook));
        if (current < 0) return false;
        const target = @mod(current + direction, count);
        c.gtk_notebook_set_current_page(asNotebook(self.notebook), target);
        if (self.currentDocument()) |document| c.gtk_widget_grab_focus(document.view);
        return true;
    }

    fn prepareHotExit(self: *App) bool {
        if (self.synchronous_worker_running) {
            self.updateStatus("Wait for the current save to finish");
            return false;
        }
        self.persistSession() catch |err| {
            self.reportSessionPersistError(err);
            return false;
        };
        self.shutting_down = true;
        return true;
    }

    fn updateStatus(self: *App, message: [*:0]const u8) void {
        if (!self.status_widgets_ready) return;
        setStatusFeedback(self.status_label, message, false);
    }

    fn updateStatusError(self: *App, message: [*:0]const u8) void {
        if (!self.status_widgets_ready) return;
        setStatusFeedback(self.status_label, message, true);
    }

    fn updateDocumentStatus(self: *App, document: *Document) void {
        if (!self.status_widgets_ready) return;
        var iter: c.GtkTextIter = undefined;
        const mark = c.gtk_text_buffer_get_insert(@ptrCast(document.buffer));
        c.gtk_text_buffer_get_iter_at_mark(@ptrCast(document.buffer), &iter, mark);
        var position_buffer: [64]u8 = undefined;
        const position = Compat.bufPrintZ(
            &position_buffer,
            "Line {d}, Column {d}",
            .{
                c.gtk_text_iter_get_line(&iter) + 1,
                c.gtk_text_iter_get_line_offset(&iter) + 1,
            },
        ) catch return;
        c.gtk_label_set_text(asLabel(self.position_label), position.ptr);
        const language = c.gtk_source_buffer_get_language(document.buffer);
        c.gtk_label_set_text(
            asLabel(self.language_label),
            if (language) |value| c.gtk_source_language_get_name(value) else "Plain Text",
        );
    }

    fn updateTabLabel(self: *App, document: *Document) void {
        _ = self;
        const dirty = c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) != 0;
        var close_buffer: [std.fs.max_path_bytes + 16]u8 = undefined;
        var close_name: [*:0]const u8 = "Close file";
        if (Compat.bufPrintZ(
            &close_buffer,
            "Close file: {s}",
            .{document.display_name},
        )) |formatted| {
            close_name = formatted.ptr;
        } else |_| {}
        c.gtk_widget_set_tooltip_text(document.tab_close, close_name);
        setAccessibleName(document.tab_close, close_name);
        if (!dirty) {
            c.gtk_label_set_text(asLabel(document.tab_label), document.display_name.ptr);
            return;
        }
        var label_buffer: [std.fs.max_path_bytes + 4]u8 = undefined;
        const label = Compat.bufPrintZ(
            &label_buffer,
            "{s} *",
            .{document.display_name},
        ) catch return;
        c.gtk_label_set_text(asLabel(document.tab_label), label.ptr);
    }

    fn showFind(self: *App) void {
        c.gtk_widget_hide(self.quick_open_box);
        c.gtk_widget_hide(self.project_search_box);
        c.gtk_widget_show(self.search_box);
        c.gtk_widget_grab_focus(self.search_entry);
    }

    fn hideFind(self: *App) void {
        c.gtk_widget_hide(self.search_box);
        if (self.currentDocument()) |document| c.gtk_widget_grab_focus(document.view);
    }

    fn showProjectFind(self: *App) void {
        c.gtk_widget_hide(self.quick_open_box);
        c.gtk_widget_hide(self.search_box);
        c.gtk_widget_show(self.project_search_box);
        c.gtk_widget_grab_focus(self.project_search_entry);
    }

    fn hideProjectFind(self: *App) void {
        self.cancelProjectSearch();
        c.gtk_widget_hide(self.project_search_box);
        if (self.currentDocument()) |document| c.gtk_widget_grab_focus(document.view);
    }

    fn showQuickOpen(self: *App) void {
        c.gtk_widget_hide(self.search_box);
        c.gtk_widget_hide(self.project_search_box);
        c.gtk_entry_set_text(@ptrCast(self.quick_open_entry), "");
        self.scheduleQuickOpenUpdate();
        c.gtk_widget_show(self.quick_open_box);
        c.gtk_widget_grab_focus(self.quick_open_entry);
    }

    fn hideQuickOpen(self: *App) void {
        self.cancelQuickOpenUpdate();
        c.gtk_widget_hide(self.quick_open_box);
        if (self.currentDocument()) |document| c.gtk_widget_grab_focus(document.view);
    }

    fn scheduleQuickOpenUpdate(self: *App) void {
        self.cancelQuickOpenUpdate();
        self.quick_open_source = c.g_timeout_add(30, onQuickOpenUpdate, self);
    }

    fn cancelQuickOpenUpdate(self: *App) void {
        if (self.quick_open_source == 0) return;
        _ = c.g_source_remove(self.quick_open_source);
        self.quick_open_source = 0;
    }

    fn updateQuickOpen(self: *App) void {
        c.gtk_tree_store_clear(self.quick_open_store);
        self.quick_open_result_count = 0;
        self.quick_open_truncated = false;
        if (self.project_root == null) {
            setStatusFeedback(self.quick_open_status, "Open a folder first", true);
            return;
        }
        const query = std.mem.span(c.gtk_entry_get_text(@ptrCast(self.quick_open_entry)));
        var results = core.quick_open.filterAlloc(
            self.allocator,
            self.project_index,
            query,
        ) catch |err| {
            const message: [*:0]const u8 = switch (err) {
                error.QuickOpenQueryTooLong => "Quick Open is limited to 256 bytes",
                error.InvalidQuickOpenQuery => "Quick Open requires one UTF-8 line",
                else => "Quick Open failed",
            };
            setStatusFeedback(self.quick_open_status, message, true);
            return;
        };
        defer results.deinit(self.allocator);
        for (results.matches) |match| {
            if (match.entry_index >= self.project_index.entries.len) continue;
            const entry = self.project_index.entries[match.entry_index];
            var iter: c.GtkTreeIter = undefined;
            c.gtk_tree_store_append(self.quick_open_store, &iter, null);
            quickOpenStoreSet(
                self.allocator,
                self.quick_open_store,
                &iter,
                self.project_index.path(entry),
                match.entry_index,
            ) catch continue;
        }
        self.quick_open_result_count = results.matches.len;
        self.quick_open_truncated = results.truncated;
        var status_buffer: [96]u8 = undefined;
        const status = if (results.truncated)
            Compat.bufPrintZ(
                &status_buffer,
                "{d} of {d} files",
                .{ results.matches.len, results.total_matches },
            ) catch return
        else if (results.matches.len == 1)
            "1 file"
        else
            Compat.bufPrintZ(
                &status_buffer,
                "{d} files",
                .{results.matches.len},
            ) catch return;
        setStatusFeedback(self.quick_open_status, status.ptr, false);
        if (results.matches.len > 0) {
            const first = c.gtk_tree_path_new_first() orelse return;
            defer c.gtk_tree_path_free(first);
            c.gtk_tree_selection_select_path(
                c.gtk_tree_view_get_selection(asTreeView(self.quick_open_tree)),
                first,
            );
        }
    }

    fn activateSelectedQuickOpen(self: *App) bool {
        const selection = c.gtk_tree_view_get_selection(asTreeView(self.quick_open_tree));
        var model: *c.GtkTreeModel = undefined;
        var iter: c.GtkTreeIter = undefined;
        if (c.gtk_tree_selection_get_selected(selection, &model, &iter) == 0)
            return false;
        return self.activateQuickOpenIter(model, &iter);
    }

    fn activateQuickOpenIter(
        self: *App,
        model: *c.GtkTreeModel,
        iter: *c.GtkTreeIter,
    ) bool {
        const entry_index = treeValueUInt64(model, iter, 1);
        const full_path = (self.projectEntryPathAlloc(entry_index) catch return false) orelse
            return false;
        defer self.allocator.free(full_path);
        self.openDocument(full_path) catch |err| {
            const status = std.fmt.allocPrintSentinel(
                self.allocator,
                "Open failed: {s}",
                .{@errorName(err)},
                0,
            ) catch return false;
            defer self.allocator.free(status);
            self.updateStatusError(status.ptr);
            return false;
        };
        self.quick_open_activations += 1;
        self.hideQuickOpen();
        return true;
    }

    fn runProjectSearch(self: *App) void {
        self.cancelProjectSearch();
        c.gtk_tree_store_clear(self.project_search_store);
        self.project_search_result_count = 0;
        self.project_search_truncated = false;
        const root = self.project_root orelse {
            setStatusFeedback(self.project_search_status, "Open a folder first", true);
            return;
        };
        const query = std.mem.span(c.gtk_entry_get_text(@ptrCast(self.project_search_entry)));
        if (query.len == 0) {
            setStatusFeedback(self.project_search_status, "Enter search text", false);
            return;
        }
        const root_copy = self.allocator.dupe(u8, root) catch {
            setStatusFeedback(self.project_search_status, "Project search failed", true);
            return;
        };
        var root_owned = true;
        defer if (root_owned) self.allocator.free(root_copy);
        const query_copy = self.allocator.dupe(u8, query) catch {
            setStatusFeedback(self.project_search_status, "Project search failed", true);
            return;
        };
        var query_owned = true;
        defer if (query_owned) self.allocator.free(query_copy);
        var index = self.project_index.retain();
        var index_owned = true;
        defer if (index_owned) index.deinit(self.allocator);
        const snapshots = self.captureSearchSnapshots(root, index) catch {
            setStatusFeedback(self.project_search_status, "Project search failed", true);
            return;
        };
        var snapshots_owned = true;
        defer if (snapshots_owned) self.freeSearchSnapshots(snapshots);
        const job = self.allocator.create(WorkerJob) catch {
            setStatusFeedback(self.project_search_status, "Project search failed", true);
            return;
        };
        var job_owned = true;
        defer if (job_owned) self.allocator.destroy(job);
        const generation = self.nextProjectSearchGeneration();
        job.* = WorkerJob.init(
            self,
            self.allocator,
            self.io,
            generation,
            false,
            .{ .project_search = .{
                .root = root_copy,
                .query = query_copy,
                .index = index,
                .snapshots = snapshots,
            } },
            onWorkerComplete,
        );
        job.batch_completion = onFilesystemSearchBatch;
        root_owned = false;
        query_owned = false;
        index_owned = false;
        snapshots_owned = false;
        self.submitWorkerJob(job) catch {
            job.deinit();
            setStatusFeedback(self.project_search_status, "Project search failed", true);
            return;
        };
        job_owned = false;
        self.project_search_started = std.Io.Clock.awake.now(self.io);
        self.project_search_draw_started = null;
        self.project_search_ok = false;
        setStatusFeedback(self.project_search_status, "Searching...", false);
    }

    fn captureSearchSnapshots(
        self: *App,
        root: []const u8,
        index: core.project_index.Index,
    ) ![]core.project_search.BufferSnapshot {
        var snapshots = std.array_list.Managed(core.project_search.BufferSnapshot).init(
            self.allocator,
        );
        errdefer {
            for (snapshots.items) |snapshot| self.allocator.free(snapshot.contents);
            snapshots.deinit();
        }
        for (self.documents.items) |document| {
            if (c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) == 0) continue;
            const path_z = document.path orelse continue;
            const path: []const u8 = path_z;
            const relative = projectRelativePath(root, path) orelse continue;
            const entry_index = index.findPath(relative) orelse continue;
            if (index.entries[entry_index].kind != .file) continue;
            const contents = try document.completeTextAlloc();
            snapshots.append(.{
                .entry_index = entry_index,
                .contents = contents,
            }) catch |err| {
                self.allocator.free(contents);
                return err;
            };
        }
        return snapshots.toOwnedSlice();
    }

    fn freeSearchSnapshots(
        self: *App,
        snapshots: []core.project_search.BufferSnapshot,
    ) void {
        for (snapshots) |snapshot| self.allocator.free(snapshot.contents);
        if (snapshots.len != 0) self.allocator.free(snapshots);
    }

    fn cancelProjectSearch(self: *App) void {
        if (self.project_search_started != null) {
            for (self.worker_jobs.items) |job| {
                if (job.kind() != .project_search or job.isCancelled() or
                    job.generation != self.project_search_generation)
                    continue;
                self.project_search_cancel_started = std.Io.Clock.awake.now(self.io);
                self.project_search_cancel_generation = job.generation;
                break;
            }
        }
        self.cancelWorkerJobs(.project_search);
        self.project_search_started = null;
        self.project_search_draw_started = null;
        if (self.ui_built) {
            c.gtk_tree_store_clear(self.project_search_store);
            self.project_search_result_count = 0;
            self.project_search_truncated = false;
        }
    }

    fn publishProjectSearch(self: *App, job: *WorkerJob) void {
        const payload = &job.payload.project_search;
        self.worker_peak_search_batches = @max(
            self.worker_peak_search_batches,
            job.batch_peak,
        );
        self.project_search_truncated = payload.search.truncated;
        if (self.project_search_started) |started| {
            self.project_search_last_total_ns = elapsedNanoseconds(started, self.io);
            self.project_search_completion_commits +|= 1;
            self.project_search_started = null;
        }

        var status_buffer: [128]u8 = undefined;
        const status = if (payload.search.truncated)
            Compat.bufPrintZ(
                &status_buffer,
                "{d} matching lines in {d} files (bounded)",
                .{ payload.search.results.len, payload.search.files_scanned },
            ) catch return
        else
            Compat.bufPrintZ(
                &status_buffer,
                "{d} matching lines in {d} files",
                .{ payload.search.results.len, payload.search.files_scanned },
            ) catch return;
        setStatusFeedback(self.project_search_status, status.ptr, false);
        self.project_search_ok = true;
    }

    fn publishProjectSearchBatch(
        self: *App,
        job: *WorkerJob,
        results: []const core.project_search.Result,
    ) void {
        if (self.shutting_down or job.isCancelled() or
            job.generation != self.project_search_generation)
            return;
        if (results.len != 0 and self.project_search_result_count == 0) {
            if (self.project_search_started) |started| {
                self.project_search_last_first_ns = elapsedNanoseconds(started, self.io);
                self.project_search_first_commits +|= 1;
                self.project_search_draw_started = std.Io.Clock.awake.now(self.io);
            }
        }
        for (results) |result| {
            var iter: c.GtkTreeIter = undefined;
            c.gtk_tree_store_append(self.project_search_store, &iter, null);
            searchStoreSet(
                self.allocator,
                self.project_search_store,
                &iter,
                result,
            ) catch continue;
            self.project_search_result_count += 1;
        }
        var status_buffer: [80]u8 = undefined;
        const status = Compat.bufPrintZ(
            &status_buffer,
            "Searching... {d} matches",
            .{self.project_search_result_count},
        ) catch return;
        setStatusFeedback(self.project_search_status, status.ptr, false);
        if (self.project_search_draw_started != null)
            c.gtk_widget_queue_draw(self.project_search_tree);
    }

    fn drainProjectSearch(self: *App) bool {
        self.drainWorkerKind(.project_search);
        return self.project_search_ok;
    }

    fn revealDocumentLine(self: *App, document: *Document, line: u32) void {
        _ = document.clearFolds();
        const line_count = c.gtk_text_buffer_get_line_count(@ptrCast(document.buffer));
        if (line_count <= 0) return;
        const target_line = @min(line -| 1, @as(u32, @intCast(line_count - 1)));
        var iter: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_iter_at_line(
            @ptrCast(document.buffer),
            &iter,
            @intCast(target_line),
        );
        c.gtk_text_buffer_select_range(@ptrCast(document.buffer), &iter, &iter);
        _ = c.gtk_text_view_scroll_to_iter(
            @ptrCast(document.view),
            &iter,
            0.18,
            1,
            0.0,
            0.35,
        );
        c.gtk_widget_grab_focus(document.view);
        self.updateDocumentStatus(document);
    }

    fn projectEntryPathAlloc(self: *App, entry_index: u64) !?[]u8 {
        const root = self.project_root orelse return null;
        if (entry_index == project_root_entry)
            return try self.allocator.dupe(u8, root);
        const index = std.math.cast(usize, entry_index) orelse return null;
        if (index >= self.project_index.entries.len) return null;
        return try std.fs.path.join(
            self.allocator,
            &.{ root, self.project_index.pathAt(index) },
        );
    }

    fn updateSearch(self: *App) void {
        const document = self.currentDocument() orelse return;
        const context = document.ensureSearchContext() catch {
            setStatusFeedback(self.search_status, "Search unavailable", true);
            return;
        };
        const settings = document.search_settings.?;
        const query = c.gtk_entry_get_text(@ptrCast(self.search_entry));
        c.gtk_source_search_settings_set_search_text(settings, query);
        c.gtk_source_search_settings_set_wrap_around(settings, 1);
        c.gtk_source_search_context_set_highlight(context, 1);
        const count = c.gtk_source_search_context_get_occurrences_count(context);
        var status_buffer: [64]u8 = undefined;
        const status = if (count < 0)
            "..."
        else
            Compat.bufPrintZ(&status_buffer, "{d} matches", .{count}) catch return;
        setStatusFeedback(self.search_status, status.ptr, false);
    }

    fn find(self: *App, forward: bool) void {
        const document = self.currentDocument() orelse return;
        _ = document.clearFolds();
        self.updateSearch();
        const context = document.search_context orelse return;
        var origin: c.GtkTextIter = undefined;
        const mark = c.gtk_text_buffer_get_insert(@ptrCast(document.buffer));
        c.gtk_text_buffer_get_iter_at_mark(@ptrCast(document.buffer), &origin, mark);
        var match_start: c.GtkTextIter = undefined;
        var match_end: c.GtkTextIter = undefined;
        const found = if (forward)
            c.gtk_source_search_context_forward(
                context,
                &origin,
                &match_start,
                &match_end,
                null,
            )
        else
            c.gtk_source_search_context_backward(
                context,
                &origin,
                &match_start,
                &match_end,
                null,
            );
        if (found == 0) return;
        c.gtk_text_buffer_select_range(
            @ptrCast(document.buffer),
            &match_start,
            &match_end,
        );
        _ = c.gtk_text_view_scroll_to_iter(
            @ptrCast(document.view),
            &match_start,
            0.15,
            0,
            0.0,
            0.0,
        );
    }

    fn updateProjectNavigationControls(self: *App) void {
        const root = self.project_root orelse {
            c.gtk_widget_set_sensitive(self.project_parent_button, 0);
            return;
        };
        const parent = std.fs.path.dirname(root);
        const can_open_parent = parent != null and
            parent.?.len > 0 and
            !std.mem.eql(u8, parent.?, root);
        c.gtk_widget_set_sensitive(
            self.project_parent_button,
            @intFromBool(can_open_parent),
        );
    }

    fn openParentFolder(self: *App) void {
        const root = self.project_root orelse {
            self.updateStatus("Open a folder first");
            return;
        };
        const parent = std.fs.path.dirname(root) orelse {
            self.updateStatus("Already at the filesystem root");
            return;
        };
        if (parent.len == 0 or std.mem.eql(u8, parent, root)) {
            self.updateStatus("Already at the filesystem root");
            return;
        }
        self.openProject(parent) catch |err|
            self.showWorkerError("Parent folder unavailable", err);
    }

    fn toggleSidebar(self: *App) void {
        if (!self.project_surface_open) {
            self.updateStatus("Open a .npr project to show the file tree");
            return;
        }
        self.settings.sidebar_visible = !self.settings.sidebar_visible;
        c.gtk_widget_set_visible(self.sidebar, @intFromBool(self.sidebarShouldShow()));
        self.persistSettings();
    }

    fn toggleMinimap(self: *App) void {
        self.settings.minimap_visible = !self.settings.minimap_visible;
        for (self.documents.items) |document| {
            if (self.settings.minimap_visible) {
                const map = document.ensureMinimap() catch continue;
                c.gtk_widget_show(map);
            } else if (document.map) |map| {
                c.gtk_widget_hide(map);
            }
        }
        self.persistSettings();
    }

    fn setWordWrapEnabled(self: *App, enabled: bool) void {
        if (self.settings.word_wrap_enabled == enabled) return;
        self.settings.word_wrap_enabled = enabled;
        for (self.documents.items) |document|
            c.gtk_text_view_set_wrap_mode(
                @ptrCast(document.view),
                if (enabled) c.GTK_WRAP_WORD else c.GTK_WRAP_NONE,
            );
        self.persistSettings();
        self.updateStatus(if (enabled) "Word wrap enabled" else "Word wrap disabled");
        c.gtk_check_menu_item_set_active(
            @ptrCast(self.word_wrap_item),
            @intFromBool(enabled),
        );
    }

    fn toggleWordWrap(self: *App) void {
        const enabled = !self.settings.word_wrap_enabled;
        c.gtk_check_menu_item_set_active(
            @ptrCast(self.word_wrap_item),
            @intFromBool(enabled),
        );
        self.setWordWrapEnabled(enabled);
    }
    fn sidebarShouldShow(self: *App) bool {
        return self.settings.sidebar_visible and self.project_surface_open and
            self.window_mode != .zen_fullscreen;
    }

    fn setWindowMode(self: *App, mode: core.settings.WindowMode) void {
        if (self.window_mode == mode) return;
        self.window_mode = mode;
        self.settings.window_mode = mode;
        self.applyWindowMode(mode, true);
    }

    fn applyWindowMode(self: *App, mode: core.settings.WindowMode, persist: bool) void {
        const zen = mode == .zen_fullscreen;
        // Wayland (Aqueous/Pearl) fullscreens through xdg-shell with
        // server-side decorations; X11 uses the EWMH request. No CSD
        // assumptions, so GTK_CSD=0 sessions behave the same.
        if (zen)
            c.gtk_window_fullscreen(asWindow(self.window))
        else
            c.gtk_window_unfullscreen(asWindow(self.window));
        self.syncWindowChrome(mode);
        self.syncWindowModeMenu();
        if (persist) self.persistSettings();
        self.updateStatus(if (zen) "Zen fullscreen" else "Windowed");
    }

    fn syncWindowChrome(self: *App, mode: core.settings.WindowMode) void {
        const zen = mode == .zen_fullscreen;
        c.gtk_widget_set_visible(self.top_bar, @intFromBool(!zen));
        c.gtk_widget_set_visible(self.status_bar, @intFromBool(!zen));
        c.gtk_notebook_set_show_tabs(asNotebook(self.notebook), @intFromBool(!zen));
        c.gtk_widget_set_visible(self.sidebar, @intFromBool(self.sidebarShouldShow()));
    }

    fn syncWindowModeMenu(self: *App) void {
        c.gtk_check_menu_item_set_active(
            @ptrCast(self.windowed_mode_item),
            @intFromBool(self.window_mode == .windowed),
        );
        c.gtk_check_menu_item_set_active(
            @ptrCast(self.zen_mode_item),
            @intFromBool(self.window_mode == .zen_fullscreen),
        );
    }

    fn setCodeFoldingEnabled(self: *App, enabled: bool) void {
        if (self.settings.code_folding_enabled == enabled) return;
        self.settings.code_folding_enabled = enabled;
        if (!enabled) {
            for (self.documents.items) |document| _ = document.clearFolds();
        }
        self.persistSettings();
        self.updateStatus(if (enabled) "Code folding enabled" else "Code folding disabled");
    }

    fn foldCurrent(self: *App) void {
        if (!self.settings.code_folding_enabled) {
            self.updateStatus("Code folding is disabled");
            return;
        }
        const document = self.currentDocument() orelse {
            self.updateStatus("No file open; use File > New File or Open File");
            return;
        };
        if (document.hasFoldAt(document.cursorLine())) {
            self.updateStatus("Region is already folded");
            return;
        }
        const line = document.cursorLine();
        var analysis = document.analyzeFolds() catch {
            self.updateStatus("Unable to analyze fold regions");
            return;
        };
        defer analysis.deinit();
        const region = analysis.regionAtLine(line) orelse {
            self.updateStatus("No foldable region on this line");
            return;
        };
        const applied = document.applyFold(region) catch {
            self.updateStatus("Unable to fold this region");
            return;
        };
        if (!applied) {
            self.updateStatus("Region overlaps an existing fold");
            return;
        }
        const status = std.fmt.allocPrintSentinel(
            self.allocator,
            "Folded {d} lines",
            .{region.hiddenLineCount()},
            0,
        ) catch return;
        defer self.allocator.free(status);
        self.updateStatus(status.ptr);
    }

    fn unfoldCurrent(self: *App) void {
        const document = self.currentDocument() orelse {
            self.updateStatus("No file open; use File > New File or Open File");
            return;
        };
        if (document.unfoldAtCursor())
            self.updateStatus("Unfolded region")
        else
            self.updateStatus("No folded region on this line");
    }

    fn foldAll(self: *App) void {
        if (!self.settings.code_folding_enabled) {
            self.updateStatus("Code folding is disabled");
            return;
        }
        const document = self.currentDocument() orelse {
            self.updateStatus("No file open; use File > New File or Open File");
            return;
        };
        _ = document.clearFolds();
        var analysis = document.analyzeFolds() catch {
            self.updateStatus("Unable to analyze fold regions");
            return;
        };
        defer analysis.deinit();
        const folded = document.foldTopLevel(&analysis) catch {
            _ = document.clearFolds();
            self.updateStatus("Unable to fold this document");
            return;
        };
        const status = if (analysis.truncated)
            std.fmt.allocPrintSentinel(
                self.allocator,
                "Folded {d} regions (bounded)",
                .{folded},
                0,
            ) catch return
        else
            std.fmt.allocPrintSentinel(
                self.allocator,
                "Folded {d} regions",
                .{folded},
                0,
            ) catch return;
        defer self.allocator.free(status);
        self.updateStatus(status.ptr);
    }

    fn unfoldAll(self: *App) void {
        const document = self.currentDocument() orelse {
            self.updateStatus("No file open; use File > New File or Open File");
            return;
        };
        const count = document.clearFolds();
        const status = std.fmt.allocPrintSentinel(
            self.allocator,
            "Unfolded {d} regions",
            .{count},
            0,
        ) catch return;
        defer self.allocator.free(status);
        self.updateStatus(status.ptr);
    }

    fn runProjectTask(self: *App, action: core.task.Action) void {
        const root = self.project_root orelse {
            self.updateStatus("Open a project before running a task");
            return;
        };
        const plan = core.task.detect(self.io, root, action) orelse {
            self.updateStatus("No supported project task detected");
            return;
        };
        const root_copy = self.allocator.dupe(u8, root) catch return;
        const job = self.allocator.create(WorkerJob) catch {
            self.allocator.free(root_copy);
            return;
        };
        job.* = WorkerJob.init(
            self,
            self.allocator,
            self.io,
            self.task_generation +% 1,
            false,
            .{ .task_request = .{ .root = root_copy, .plan = plan } },
            onWorkerComplete,
        );
        self.task_generation +%= 1;
        self.cancelWorkerJobs(.task_request);
        self.submitWorkerJob(job) catch |err| {
            job.deinit();
            self.allocator.destroy(job);
            self.showWorkerError("Project task unavailable", err);
            return;
        };
        self.updateStatus("Project task running...");
    }

    fn finishProjectTask(self: *App, job: *WorkerJob) void {
        if (job.generation != self.task_generation) return;
        const payload = &job.payload.task_request;
        const raw = payload.output orelse "Task produced no output";
        var length = @min(raw.len, 16 * 1024);
        while (length > 0 and !std.unicode.utf8ValidateSlice(raw[0..length])) length -= 1;
        const output = if (length == 0) "Task output was not UTF-8" else raw[0..length];
        const output_z = Compat.dupeZ(self.allocator, output) catch return;
        defer self.allocator.free(output_z);
        const dialog = c.gtk_message_dialog_new(
            asWindow(self.window),
            c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
            if (payload.success) c.GTK_MESSAGE_INFO else c.GTK_MESSAGE_WARNING,
            c.GTK_BUTTONS_CLOSE,
            "%s",
            output_z.ptr,
        ) orelse return;
        _ = c.gtk_dialog_run(@ptrCast(dialog));
        c.gtk_widget_destroy(dialog);
        if (payload.success)
            self.updateStatus("Project task passed")
        else
            self.updateStatusError("Project task failed");
    }

    const language_snapshot_key = "nocted-language-snapshot";
    const max_language_snapshots = 128;

    const LanguageDocumentSnapshot = struct {
        allocator: std.mem.Allocator,
        generation: u64,
        change_serial: u64,
        path: []u8,
        disk_identity: ?core.document.FileIdentity,

        fn destroy(data: ?*anyopaque) callconv(.c) void {
            const snapshot: *LanguageDocumentSnapshot = @ptrCast(@alignCast(data orelse return));
            const allocator = snapshot.allocator;
            allocator.free(snapshot.path);
            allocator.destroy(snapshot);
        }
    };

    fn captureLanguageDocument(self: *App, document: *Document, generation: u64, additional: bool) !bool {
        const path = document.path orelse return false;
        if (document.loading or !document.editable) return false;
        var disk_identity: ?core.document.FileIdentity = null;
        if (additional) {
            // Only the requesting document is sent with didOpen. Other buffers
            // must still represent the disk version the server can read.
            if (c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) != 0) return false;
            const previous = document.identity orelse return false;
            const current = core.document.identityForPath(self.io, path) catch return false;
            if (!previous.eql(current)) return false;
            disk_identity = current;
        }
        const snapshot = try self.allocator.create(LanguageDocumentSnapshot);
        errdefer self.allocator.destroy(snapshot);
        snapshot.* = .{
            .allocator = self.allocator,
            .generation = generation,
            .change_serial = document.change_serial,
            .path = try self.allocator.dupe(u8, path),
            .disk_identity = disk_identity,
        };
        c.g_object_set_data_full(
            @ptrCast(document.buffer),
            language_snapshot_key,
            snapshot,
            LanguageDocumentSnapshot.destroy,
        );
        return true;
    }

    fn captureLanguageDocuments(self: *App, document: *Document, job: *WorkerJob) !void {
        if (!try self.captureLanguageDocument(document, job.generation, false))
            return error.DocumentNotEditable;
        if (job.payload.lsp_request.feature != .rename) return;
        var count: usize = 1;
        for (self.documents.items) |candidate| {
            if (count == max_language_snapshots) break;
            if (candidate == document) continue;
            if (try self.captureLanguageDocument(candidate, job.generation, true)) count += 1;
        }
    }

    fn languageDocumentForPath(self: *App, job: *WorkerJob, path: []const u8) ?*Document {
        if (job.generation != self.lsp_generation) {
            self.updateStatusError("Language-service response superseded; retry the request");
            return null;
        }
        const document = self.documents_by_path.get(path) orelse {
            self.updateStatusError("Language-service target closed or not snapshotted; open the file and retry");
            return null;
        };
        const raw = c.g_object_get_data(@ptrCast(document.buffer), language_snapshot_key) orelse {
            self.updateStatusError("Language-service target has no safe snapshot; save the file and retry");
            return null;
        };
        const snapshot: *const LanguageDocumentSnapshot = @ptrCast(@alignCast(raw));
        if (snapshot.generation != job.generation or
            !std.mem.eql(u8, snapshot.path, path) or
            snapshot.change_serial != document.change_serial or
            document.loading or !document.editable)
        {
            self.updateStatusError("Language-service target changed or was replaced; retry the request");
            return null;
        }
        if (snapshot.disk_identity) |previous| {
            const current = core.document.identityForPath(self.io, document.path orelse return null) catch {
                self.updateStatusError("Language-service target changed on disk; reload and retry");
                return null;
            };
            if (!previous.eql(current)) {
                self.updateStatusError("Language-service target changed on disk; reload and retry");
                return null;
            }
        }
        return document;
    }

    fn languageRequestDocument(self: *App, job: *WorkerJob) ?*Document {
        const payload = &job.payload.lsp_request;
        const path = core.lsp.filePathAlloc(self.allocator, payload.uri) catch {
            self.updateStatusError("Invalid language-service target");
            return null;
        };
        defer self.allocator.free(path);
        const document = self.languageDocumentForPath(job, path) orelse return null;
        const text = document.completeTextAlloc() catch {
            self.updateStatusError("Unable to verify language-service target text");
            return null;
        };
        defer self.allocator.free(text);
        if (!std.mem.eql(u8, text, payload.text)) {
            self.updateStatusError("Language-service target text changed; retry the request");
            return null;
        }
        return document;
    }

    fn runLanguageFeature(
        self: *App,
        feature: core.lsp.Feature,
        new_name: ?[]const u8,
    ) void {
        const document = self.currentDocument() orelse {
            self.updateStatus("No file open; use File > New File or Open File");
            return;
        };
        const path = document.path orelse {
            self.updateStatus("Save the file before using a language service");
            return;
        };
        const cwd_source = self.project_root orelse std.fs.path.dirname(path) orelse ".";
        const server = core.lsp.serverForPathInRoot(self.io, path, cwd_source) orelse {
            self.updateStatus("No language-service preset for this file type");
            return;
        };
        const text = document.completeTextAlloc() catch {
            self.updateStatus("Unable to read document text");
            return;
        };
        var text_owned = true;
        defer if (text_owned) self.allocator.free(text);
        const uri = core.lsp.fileUriAlloc(self.allocator, path) catch return;
        var uri_owned = true;
        defer if (uri_owned) self.allocator.free(uri);
        const cwd = self.allocator.dupe(u8, cwd_source) catch return;
        var cwd_owned = true;
        defer if (cwd_owned) self.allocator.free(cwd);
        const root_uri = core.lsp.fileUriAlloc(self.allocator, cwd_source) catch return;
        var root_uri_owned = true;
        defer if (root_uri_owned) self.allocator.free(root_uri);
        const owned_name = if (new_name) |name| self.allocator.dupe(u8, name) catch return else null;
        var name_owned = owned_name != null;
        defer if (name_owned) self.allocator.free(owned_name.?);

        var cursor: c.GtkTextIter = undefined;
        c.gtk_text_buffer_get_iter_at_mark(
            @ptrCast(document.buffer),
            &cursor,
            c.gtk_text_buffer_get_insert(@ptrCast(document.buffer)),
        );
        const line: u32 = @intCast(@max(c.gtk_text_iter_get_line(&cursor), 0));
        const line_offset: usize = @intCast(@max(c.gtk_text_iter_get_line_offset(&cursor), 0));
        var line_start: usize = 0;
        var line_number: u32 = 0;
        while (line_number < line) : (line_number += 1) {
            line_start = (std.mem.indexOfScalarPos(u8, text, line_start, '\n') orelse text.len) +| 1;
            line_start = @min(line_start, text.len);
        }
        const line_end = std.mem.indexOfScalarPos(u8, text, line_start, '\n') orelse text.len;
        const byte_offset = utf8ByteOffset(text[line_start..line_end], line_offset) orelse {
            self.updateStatus("Unable to map cursor position");
            return;
        };
        const character = core.lsp.utf16Column(text[line_start..line_end], byte_offset) catch return;

        const job = self.allocator.create(WorkerJob) catch return;
        job.* = WorkerJob.init(
            self,
            self.allocator,
            self.io,
            self.lsp_generation +% 1,
            false,
            .{ .lsp_request = .{
                .server = server,
                .cwd = cwd,
                .root_uri = root_uri,
                .uri = uri,
                .text = text,
                .line = line,
                .character = character,
                .feature = feature,
                .new_name = owned_name,
            } },
            onWorkerComplete,
        );
        text_owned = false;
        uri_owned = false;
        cwd_owned = false;
        root_uri_owned = false;
        name_owned = false;
        self.lsp_generation +%= 1;
        self.cancelWorkerJobs(.lsp_request);
        self.captureLanguageDocuments(document, job) catch |err| {
            job.deinit();
            self.allocator.destroy(job);
            self.showWorkerError("Unable to snapshot language-service targets", err);
            return;
        };
        self.submitWorkerJob(job) catch |err| {
            job.deinit();
            self.allocator.destroy(job);
            self.showWorkerError("Language service unavailable", err);
            return;
        };
        self.updateStatus("Language service working...");
    }

    fn applyLanguageEdits(
        self: *App,
        response: []const u8,
        job: *WorkerJob,
        workspace: bool,
    ) bool {
        const payload = &job.payload.lsp_request;
        const sets = core.lsp.editsAlloc(self.allocator, response, payload.uri) catch return false;
        defer {
            for (sets) |*set| set.deinit(self.allocator);
            self.allocator.free(sets);
        }
        if (sets.len == 0) {
            self.updateStatus("Language service returned no edits");
            return true;
        }
        const requested = self.languageRequestDocument(job) orelse return true;
        const requested_path = requested.path.?;
        const PreparedEdit = struct { document: *Document, text: []u8 };
        var prepared = std.array_list.Managed(PreparedEdit).init(self.allocator);
        defer {
            for (prepared.items) |edit| self.allocator.free(edit.text);
            prepared.deinit();
        }
        prepared.ensureTotalCapacity(sets.len) catch return false;
        for (sets) |set| {
            const path = core.lsp.filePathAlloc(self.allocator, set.uri) catch {
                self.updateStatus("Language service returned a non-local edit");
                return true;
            };
            defer self.allocator.free(path);
            const allowed = if (workspace)
                if (payload.cwd) |root|
                    std.mem.eql(u8, path, root) or
                        (std.mem.startsWith(u8, path, root) and path.len > root.len and
                            std.fs.path.isSep(path[root.len]))
                else
                    std.mem.eql(u8, path, requested_path)
            else
                std.mem.eql(u8, path, requested_path);
            if (!allowed) {
                self.updateStatus("Language service edit escaped the active workspace");
                return true;
            }

            const document = self.languageDocumentForPath(job, path) orelse return true;
            for (prepared.items) |edit| {
                if (edit.document == document) {
                    self.updateStatusError("Language service returned duplicate file edits; nothing applied");
                    return true;
                }
            }
            const before = document.completeTextAlloc() catch return false;
            defer self.allocator.free(before);
            const after = core.lsp.applyTextEditsAlloc(self.allocator, before, set.edits) catch {
                self.updateStatusError("Invalid language-service edits; nothing applied");
                return true;
            };
            prepared.appendAssumeCapacity(.{ .document = document, .text = after });
        }
        // Finish validation and allocation for every file before changing any
        // buffer. Unopened files have no request-time baseline and are rejected.
        for (prepared.items) |edit| {
            _ = edit.document.clearFolds();
            c.gtk_text_buffer_begin_user_action(@ptrCast(edit.document.buffer));
            c.gtk_text_buffer_set_text(
                @ptrCast(edit.document.buffer),
                edit.text.ptr,
                @intCast(edit.text.len),
            );
            c.gtk_text_buffer_end_user_action(@ptrCast(edit.document.buffer));
        }
        const changed_files = prepared.items.len;
        const status = std.fmt.allocPrintSentinel(
            self.allocator,
            "Applied language-service edits to {d} file{s}",
            .{ changed_files, if (changed_files == 1) "" else "s" },
            0,
        ) catch return true;
        defer self.allocator.free(status);
        self.updateStatus(status.ptr);
        return true;
    }

    fn chooseCompletion(self: *App, job: *WorkerJob, response: []const u8) bool {
        const payload = &job.payload.lsp_request;
        const completions = core.lsp.completionsAlloc(
            self.allocator,
            response,
            payload.line,
            payload.character,
        ) catch return false;
        defer {
            for (completions) |*completion| completion.deinit(self.allocator);
            self.allocator.free(completions);
        }
        if (completions.len == 0) {
            self.updateStatus("No completions");
            return true;
        }
        const dialog = c.gtk_message_dialog_new(
            asWindow(self.window),
            c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
            c.GTK_MESSAGE_QUESTION,
            c.GTK_BUTTONS_NONE,
            "%s",
            "Choose completion",
        ) orelse return false;
        defer c.gtk_widget_destroy(dialog);
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Cancel", c.GTK_RESPONSE_CANCEL);
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Insert", c.GTK_RESPONSE_ACCEPT);
        const combo = c.gtk_combo_box_text_new() orelse return false;
        setAccessibleName(combo, "Language-service completions");
        for (completions) |completion| {
            const label = Compat.dupeZ(self.allocator, completion.label) catch return false;
            defer self.allocator.free(label);
            c.gtk_combo_box_text_append_text(@ptrCast(combo), label.ptr);
        }
        c.gtk_combo_box_set_active(@ptrCast(combo), 0);
        const area = c.gtk_dialog_get_content_area(@ptrCast(dialog)) orelse return false;
        c.gtk_box_pack_start(asBox(area), combo, 0, 0, 8);
        c.gtk_widget_show(combo);
        if (c.gtk_dialog_run(@ptrCast(dialog)) != c.GTK_RESPONSE_ACCEPT) return true;
        const selected = c.gtk_combo_box_get_active(@ptrCast(combo));
        if (selected < 0 or selected >= completions.len) return true;
        // gtk_dialog_run dispatches nested events: the tab may have closed,
        // changed, or been replaced since the chooser was displayed.
        const document = self.languageRequestDocument(job) orelse return true;
        const after = core.lsp.applyTextEditsAlloc(
            self.allocator,
            payload.text,
            &.{completions[@intCast(selected)].edit},
        ) catch return false;
        defer self.allocator.free(after);
        _ = document.clearFolds();
        c.gtk_text_buffer_begin_user_action(@ptrCast(document.buffer));
        c.gtk_text_buffer_set_text(@ptrCast(document.buffer), after.ptr, @intCast(after.len));
        c.gtk_text_buffer_end_user_action(@ptrCast(document.buffer));
        self.updateStatus("Inserted completion");
        return true;
    }

    fn finishLanguageFeature(self: *App, job: *WorkerJob) void {
        if (job.generation != self.lsp_generation) return;
        const payload = &job.payload.lsp_request;
        const response = payload.response orelse return;
        _ = self.languageRequestDocument(job) orelse return;
        if (payload.feature == .completion and self.chooseCompletion(job, response)) return;
        if (payload.feature == .definition) {
            if (core.lsp.firstLocationAlloc(self.allocator, response) catch null) |location_value| {
                var location = location_value;
                defer location.deinit(self.allocator);
                const path = core.lsp.filePathAlloc(self.allocator, location.uri) catch return;
                defer self.allocator.free(path);
                self.openDocumentAtLine(path, location.line + 1) catch |err| {
                    self.showWorkerError("Unable to open definition", err);
                };
                return;
            }
        }
        if (payload.feature == .formatting or payload.feature == .rename) {
            if (self.applyLanguageEdits(response, job, payload.feature == .rename))
                return;
        }
        const summary = core.lsp.summaryAlloc(self.allocator, response) catch {
            self.updateStatusError("Invalid language-service response");
            return;
        };
        defer self.allocator.free(summary);
        const summary_z = Compat.dupeZ(self.allocator, summary) catch return;
        defer self.allocator.free(summary_z);
        const dialog = c.gtk_message_dialog_new(
            asWindow(self.window),
            c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
            c.GTK_MESSAGE_INFO,
            c.GTK_BUTTONS_CLOSE,
            "%s",
            summary_z.ptr,
        ) orelse return;
        _ = c.gtk_dialog_run(@ptrCast(dialog));
        c.gtk_widget_destroy(dialog);
        self.updateStatus("Language service response received");
    }

    fn promptRename(self: *App) void {
        const dialog = c.gtk_message_dialog_new(
            asWindow(self.window),
            c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
            c.GTK_MESSAGE_QUESTION,
            c.GTK_BUTTONS_NONE,
            "%s",
            "New symbol name",
        ) orelse return;
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Cancel", c.GTK_RESPONSE_CANCEL);
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Rename", c.GTK_RESPONSE_ACCEPT);
        const entry = c.gtk_entry_new() orelse {
            c.gtk_widget_destroy(dialog);
            return;
        };
        c.gtk_entry_set_placeholder_text(@ptrCast(entry), "New name");
        setAccessibleName(entry, "New symbol name");
        const area = c.gtk_dialog_get_content_area(@ptrCast(dialog)) orelse {
            c.gtk_widget_destroy(dialog);
            return;
        };
        c.gtk_box_pack_start(asBox(area), entry, 0, 0, 8);
        c.gtk_widget_show(entry);
        const response = c.gtk_dialog_run(@ptrCast(dialog));
        if (response == c.GTK_RESPONSE_ACCEPT) {
            const name = std.mem.span(c.gtk_entry_get_text(@ptrCast(entry)));
            if (name.len != 0) self.runLanguageFeature(.rename, name);
        }
        c.gtk_widget_destroy(dialog);
    }

    fn persistSettings(self: *App) void {
        core.settings.save(self.io, self.settings_path, &self.settings) catch |err| {
            log.err("settings save failed: {s}", .{@errorName(err)});
            const status = std.fmt.allocPrintSentinel(
                self.allocator,
                "Settings save failed: {s}",
                .{@errorName(err)},
                0,
            ) catch return;
            defer self.allocator.free(status);
            self.updateStatus(status.ptr);
        };
    }

    fn importSyntaxDirectory(self: *App, path: []const u8) void {
        const count = core.syntax_discovery.countLanguageSpecs(
            self.io,
            path,
        ) catch {
            self.updateStatus("No compatible .lang definitions found");
            return;
        };
        if (count == 0) {
            self.updateStatus("No compatible .lang definitions found");
            return;
        }
        const retained_count = self.settings.import_paths.items.len;
        const added = self.settings.addImportPath(self.allocator, path) catch |err| {
            self.showWorkerError("Syntax path unavailable", err);
            return;
        };
        if (added) {
            self.reloadSyntaxPaths() catch |err| {
                self.settings.truncateImportPaths(self.allocator, retained_count);
                self.showWorkerError("Unable to reload syntax definitions", err);
                return;
            };
            self.persistSettings();
        }
        const status = std.fmt.allocPrintSentinel(
            self.allocator,
            "{d} syntax definitions available",
            .{count},
            0,
        ) catch return;
        defer self.allocator.free(status);
        self.updateStatus(status.ptr);
    }

    fn importTextMateGrammarFile(self: *App, path: []const u8) bool {
        const source = std.Io.Dir.cwd().readFileAlloc(
            self.io,
            path,
            self.allocator,
            .limited(core.textmate_grammar.max_source_bytes),
        ) catch |err| {
            self.showWorkerError("TextMate grammar import failed", err);
            return false;
        };
        defer self.allocator.free(source);
        var conversion = core.textmate_grammar.convertAlloc(
            self.allocator,
            source,
        ) catch |err| {
            self.showWorkerError("TextMate grammar import failed", err);
            return false;
        };
        defer conversion.deinit(self.allocator);
        const filename = std.fmt.allocPrint(
            self.allocator,
            "{s}.lang",
            .{conversion.language_id},
        ) catch return false;
        defer self.allocator.free(filename);
        const output_path = std.fs.path.join(self.allocator, &.{
            self.generated_language_path,
            filename,
        }) catch return false;
        defer self.allocator.free(output_path);
        var atomic = std.Io.Dir.cwd().createFileAtomic(self.io, output_path, .{
            .make_path = true,
            .replace = true,
        }) catch |err| {
            self.showWorkerError("TextMate grammar import failed", err);
            return false;
        };
        defer atomic.deinit(self.io);
        atomic.file.writeStreamingAll(self.io, conversion.xml) catch |err| {
            self.showWorkerError("TextMate grammar import failed", err);
            return false;
        };
        atomic.replace(self.io) catch |err| {
            self.showWorkerError("TextMate grammar import failed", err);
            return false;
        };
        self.reloadSyntaxPaths() catch |err| {
            self.showWorkerError("TextMate grammar activation failed", err);
            return false;
        };
        const status = std.fmt.allocPrintSentinel(
            self.allocator,
            "Imported {s}: {d} rules ({d} skipped)",
            .{
                conversion.display_name,
                conversion.pattern_count,
                conversion.skipped_patterns,
            },
            0,
        ) catch return true;
        defer self.allocator.free(status);
        self.updateStatus(status.ptr);
        return true;
    }

    fn refreshDocumentLanguages(self: *App) void {
        for (self.documents.items) |document| {
            const path = document.path orelse continue;
            const language = c.gtk_source_language_manager_guess_language(
                self.language_manager,
                path.ptr,
                null,
            );
            c.gtk_source_buffer_set_language(document.buffer, language);
            if (document == self.active_document) self.updateDocumentStatus(document);
        }
    }

    fn promptLegacySyntax(self: *App) void {
        if (self.settings.syntax_prompt_done) return;
        const candidates = core.syntax_discovery.discoverLegacyCandidatesAlloc(
            self.allocator,
            self.io,
            self.home,
        ) catch return;
        defer core.syntax_discovery.deinitCandidates(self.allocator, candidates);
        if (candidates.len == 0) return;
        var total: usize = 0;
        for (candidates) |candidate| total += candidate.additional_specs;
        const message = std.fmt.allocPrintSentinel(
            self.allocator,
            "Import {d} compatible syntax definitions from existing editor installations?",
            .{total},
            0,
        ) catch return;
        defer self.allocator.free(message);
        const dialog = c.gtk_message_dialog_new(
            asWindow(self.window),
            c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
            c.GTK_MESSAGE_QUESTION,
            c.GTK_BUTTONS_NONE,
            "%s",
            message.ptr,
        ) orelse return;
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Not Now", c.GTK_RESPONSE_CANCEL);
        _ = c.gtk_dialog_add_button(@ptrCast(dialog), "Import", c.GTK_RESPONSE_ACCEPT);
        const response = c.gtk_dialog_run(@ptrCast(dialog));
        c.gtk_widget_destroy(dialog);
        self.settings.syntax_prompt_done = true;
        if (response == c.GTK_RESPONSE_ACCEPT) {
            const retained_count = self.settings.import_paths.items.len;
            for (candidates) |candidate| {
                _ = self.settings.addImportPath(
                    self.allocator,
                    candidate.path,
                ) catch |err| {
                    self.settings.truncateImportPaths(self.allocator, retained_count);
                    self.settings.syntax_prompt_done = false;
                    self.showWorkerError("Legacy syntax import failed", err);
                    return;
                };
            }
            self.applySyntaxPaths() catch |err| {
                self.settings.truncateImportPaths(self.allocator, retained_count);
                self.settings.syntax_prompt_done = false;
                self.showWorkerError("Legacy syntax activation failed", err);
                return;
            };
        }
        self.persistSettings();
    }

    fn languageCount(self: *App) usize {
        const ids = c.gtk_source_language_manager_get_language_ids(self.language_manager) orelse return 0;
        var count: usize = 0;
        while (ids[count] != null) : (count += 1) {}
        return count;
    }

    fn waitForProjectModel(
        self: *App,
        previous_models: usize,
        expected_path: ?[]const u8,
    ) bool {
        for (0..2500) |_| {
            while (c.g_main_context_iteration(null, 0) != 0) {}
            const expected_indexed = if (expected_path) |path|
                self.project_index.findPath(path) != null
            else
                true;
            if (self.project_model_commits > previous_models and
                self.project_load == null and
                !self.hasWorkerJob(.project_scan) and
                expected_indexed)
                return true;
            self.io.sleep(.fromMilliseconds(2), .awake) catch {};
        }
        return false;
    }

    fn waitForProjectDraw(
        self: *App,
        previous_draws: usize,
        expected_path: ?[]const u8,
    ) bool {
        for (0..2500) |_| {
            while (c.g_main_context_iteration(null, 0) != 0) {}
            const expected_visible = if (expected_path) |path|
                self.project_index.findPath(path) != null
            else
                true;
            if (self.project_draw_commits > previous_draws and
                self.project_load == null and
                !self.hasWorkerJob(.project_scan) and
                expected_visible)
                return true;
            self.io.sleep(.fromMilliseconds(2), .awake) catch {};
        }
        return false;
    }

    fn runRealProjectLifecycleSmoke(self: *App) bool {
        const cycles: usize = 8;
        const root = self.allocator.dupe(
            u8,
            self.project_root orelse return false,
        ) catch return false;
        defer self.allocator.free(root);
        if (self.project_draw_commits == 0 or self.project_entry_count < 32)
            return false;
        const expected_entries = self.project_entry_count;
        var model_values: [cycles]u64 = undefined;
        var draw_values: [cycles]u64 = undefined;
        model_values[0] = self.project_last_model_ns;
        draw_values[0] = self.project_last_draw_ns;
        for (1..cycles) |cycle| {
            const previous_draws = self.project_draw_commits;
            self.openProject(root) catch return false;
            if (!self.waitForProjectDraw(previous_draws, null)) return false;
            if (self.project_entry_count != expected_entries or
                self.project_truncated)
                return false;
            model_values[cycle] = self.project_last_model_ns;
            draw_values[cycle] = self.project_last_draw_ns;
        }
        const model = summarizeLatencies(&model_values);
        const draw = summarizeLatencies(&draw_values);
        const passed = self.worker_jobs.items.len == 0 and
            self.project_load == null and
            self.project_load_source == 0 and
            self.project_monitors.items.len > 0 and
            !self.project_monitor_truncated and
            model.p50_ns > 0 and draw.p50_ns >= model.p50_ns;
        var receipt_buffer: [1024]u8 = undefined;
        const receipt = Compat.bufPrintZ(
            &receipt_buffer,
            "nocted_project_real_project_qualification pass={d} cycles={d} " ++
                "entries={d} model_p50_ns={d} model_p95_ns={d} model_p99_ns={d} " ++
                "draw_p50_ns={d} draw_p95_ns={d} draw_p99_ns={d} " ++
                "monitors={d} retained_real_project=true gtk_tree_draw=true " ++
                "worker_drained={d} project_drained={d}\n",
            .{
                @intFromBool(passed),
                cycles,
                self.project_entry_count,
                model.p50_ns,
                model.p95_ns,
                model.p99_ns,
                draw.p50_ns,
                draw.p95_ns,
                draw.p99_ns,
                self.project_monitors.items.len,
                @intFromBool(self.worker_jobs.items.len == 0),
                @intFromBool(self.project_load == null),
            },
        ) catch return false;
        c.g_print("%s", receipt.ptr);
        return passed;
    }

    fn runProjectMonitorLifecycleSmoke(self: *App) bool {
        const burst_cycles: usize = 8;
        const files_per_burst: usize = 12;
        const root_path = self.project_root orelse return false;
        var root = std.Io.Dir.openDirAbsolute(self.io, root_path, .{}) catch
            return false;
        defer root.close(self.io);
        root.createDirPath(self.io, "src") catch return false;
        var publication_values: [burst_cycles]u64 = undefined;
        const events_before = self.project_monitor_events;
        const updates_before = self.project_delta_updates;
        const fallbacks_before = self.project_delta_fallbacks;
        for (0..burst_cycles) |cycle| {
            const previous_draws = self.project_draw_commits;
            const previous_updates = self.project_delta_updates;
            const started = std.Io.Clock.awake.now(self.io);
            var expected_buffer: [128]u8 = undefined;
            var expected_path: []const u8 = undefined;
            for (0..files_per_burst) |file_index| {
                var path_buffer: [128]u8 = undefined;
                const path = std.fmt.bufPrint(
                    &path_buffer,
                    "src/lifecycle-{d:0>2}-{d:0>2}.zig",
                    .{ cycle, file_index },
                ) catch return false;
                root.writeFile(self.io, .{
                    .sub_path = path,
                    .data = "const lifecycle_monitor = true;\n",
                }) catch return false;
                if (file_index + 1 == files_per_burst) {
                    expected_path = std.fmt.bufPrint(
                        &expected_buffer,
                        "src/lifecycle-{d:0>2}-{d:0>2}.zig",
                        .{ cycle, file_index },
                    ) catch return false;
                }
            }
            if (!self.waitForProjectDraw(previous_draws, expected_path))
                return false;
            if (self.project_delta_updates <= previous_updates or
                self.project_delta_fallbacks != fallbacks_before)
                return false;
            publication_values[cycle] = elapsedNanoseconds(started, self.io);
        }
        const publication = summarizeLatencies(&publication_values);

        self.cancelProjectMonitoring();
        root.writeFile(self.io, .{
            .sub_path = "src/overflow-sentinel.zig",
            .data = "const overflow_recovered = true;\n",
        }) catch return false;
        const overflow_draws = self.project_draw_commits;
        const overflow_started = std.Io.Clock.awake.now(self.io);
        for (0..max_project_monitor_changes + 1) |change_index| {
            var path_buffer: [128]u8 = undefined;
            const path = std.fmt.bufPrint(
                &path_buffer,
                "src/overflow-injected-{d:0>3}.zig",
                .{change_index},
            ) catch return false;
            self.queueProjectMonitorChange(.created, path, null) catch
                return false;
        }
        self.scheduleProjectMonitorFlush(false);
        if (!self.waitForProjectDraw(
            overflow_draws,
            "src/overflow-sentinel.zig",
        )) return false;
        const overflow_ns = elapsedNanoseconds(overflow_started, self.io);
        const burst_events = self.project_monitor_events - events_before;
        const burst_updates = self.project_delta_updates - updates_before;
        const bounded_fallbacks = self.project_delta_fallbacks - fallbacks_before;
        const passed = burst_events >= burst_cycles and
            burst_updates >= burst_cycles and
            bounded_fallbacks == 1 and
            self.project_index.findPath("src/overflow-sentinel.zig") != null and
            self.project_monitor_changes.items.len == 0 and
            self.worker_jobs.items.len == 0 and
            self.project_load == null and
            self.project_load_source == 0 and
            publication.p50_ns > 0 and overflow_ns > 0;
        var receipt_buffer: [1200]u8 = undefined;
        const receipt = Compat.bufPrintZ(
            &receipt_buffer,
            "nocted_project_monitor_qualification pass={d} burst_cycles={d} " ++
                "files_per_burst={d} monitor_events={d} delta_updates={d} " ++
                "bounded_fallbacks={d} publication_p50_ns={d} " ++
                "publication_p95_ns={d} publication_p99_ns={d} " ++
                "overflow_recovery_ns={d} exact_index=true actual_gio_burst=true " ++
                "overflow_admission_injected=true overflow_full_scan=true " ++
                "worker_drained={d} project_drained={d}\n",
            .{
                @intFromBool(passed),
                burst_cycles,
                files_per_burst,
                burst_events,
                burst_updates,
                bounded_fallbacks,
                publication.p50_ns,
                publication.p95_ns,
                publication.p99_ns,
                overflow_ns,
                @intFromBool(self.worker_jobs.items.len == 0),
                @intFromBool(self.project_load == null),
            },
        ) catch return false;
        c.g_print("%s", receipt.ptr);
        return passed;
    }

    fn runCombinedProjectLifecycleSmoke(
        self: *App,
        real_project_root: []const u8,
    ) bool {
        if (!self.runProjectMonitorLifecycleSmoke()) return false;
        const previous_draws = self.project_draw_commits;
        self.openProject(real_project_root) catch return false;
        if (!self.waitForProjectDraw(previous_draws, null)) return false;
        return self.runRealProjectLifecycleSmoke();
    }

    fn drawWidgetForQualification(widget: *c.GtkWidget) bool {
        c.gtk_container_check_resize(@ptrCast(widget));
        while (c.g_main_context_iteration(null, 0) != 0) {}
        const window = c.gtk_widget_get_window(widget) orelse return false;
        const width = c.gdk_window_get_width(window);
        const height = c.gdk_window_get_height(window);
        if (width <= 0 or height <= 0) return false;
        const surface = c.cairo_image_surface_create(
            c.CAIRO_FORMAT_ARGB32,
            width,
            height,
        );
        defer c.cairo_surface_destroy(surface);
        if (c.cairo_surface_status(surface) != c.CAIRO_STATUS_SUCCESS)
            return false;
        const context = c.cairo_create(surface);
        defer c.cairo_destroy(context);
        if (c.cairo_status(context) != c.CAIRO_STATUS_SUCCESS) return false;
        c.gtk_widget_draw(widget, context);
        return true;
    }

    fn waitForSearchQualification(
        self: *App,
        first_before: usize,
        completion_before: usize,
        draw_before: usize,
    ) bool {
        for (0..5000) |_| {
            while (c.g_main_context_iteration(null, 0) != 0) {}
            const search_complete =
                self.project_search_first_commits > first_before and
                self.project_search_completion_commits > completion_before and
                !self.hasWorkerJob(.project_search);
            if (search_complete and
                self.project_search_draw_commits <= draw_before)
                _ = drawWidgetForQualification(self.window);
            if (search_complete and
                self.project_search_draw_commits > draw_before)
                return true;
            self.io.sleep(.fromMilliseconds(2), .awake) catch {};
        }
        return false;
    }

    fn waitForSearchCancellation(self: *App, commits_before: usize) bool {
        for (0..5000) |_| {
            while (c.g_main_context_iteration(null, 0) != 0) {}
            if (self.project_search_cancel_commits > commits_before) return true;
            self.io.sleep(.fromMilliseconds(2), .awake) catch {};
        }
        return false;
    }

    fn quickOpenFingerprint(self: *App) ?u64 {
        const model = c.gtk_tree_view_get_model(asTreeView(self.quick_open_tree)) orelse
            return null;
        var iter: c.GtkTreeIter = undefined;
        if (c.gtk_tree_model_get_iter_first(model, &iter) == 0) return null;
        var fingerprint: u64 = 14695981039346656037;
        var count: usize = 0;
        while (true) {
            const entry_index = treeValueUInt64(model, &iter, 1);
            fingerprint = (fingerprint ^ entry_index) *% 1099511628211;
            count += 1;
            if (c.gtk_tree_model_iter_next(model, &iter) == 0) break;
        }
        return if (count == self.quick_open_result_count) fingerprint else null;
    }

    fn waitForQuickOpen(self: *App) bool {
        for (0..2500) |_| {
            while (c.g_main_context_iteration(null, 0) != 0) {}
            if (self.quick_open_source == 0 and self.quick_open_result_count > 0)
                return true;
            self.io.sleep(.fromMilliseconds(2), .awake) catch {};
        }
        return false;
    }

    fn searchLoadFailure(stage: []const u8) bool {
        std.debug.print(
            "nocted_search_load_qualification pass=0 stage={s}\n",
            .{stage},
        );
        return false;
    }

    fn runSearchLoadQualification(self: *App, root: []const u8) bool {
        const cycles: usize = 8;
        const ranking_queries = [_][]const u8{
            "ranktarget",
            "qf000",
            "group03qf",
        };
        const quick_samples = cycles * ranking_queries.len;
        var first_values: [cycles]u64 = undefined;
        var total_values: [cycles]u64 = undefined;
        var draw_values: [cycles]u64 = undefined;
        var cancel_values: [cycles]u64 = undefined;
        var open_values: [cycles]u64 = undefined;
        var save_values: [cycles]u64 = undefined;
        var quick_values: [quick_samples]u64 = undefined;
        var ranking_fingerprints: [ranking_queries.len]?u64 = @splat(null);

        const previous_models = self.project_model_commits;
        self.openProject(root) catch return searchLoadFailure("open_project");
        if (!self.waitForProjectModel(previous_models, "src/rank-target.zig")) {
            std.debug.print(
                "nocted_search_load_state models_before={d} models_after={d} " ++
                    "project_load={d} project_scan={d} entries={d} " ++
                    "truncated={d} expected_path={d}\n",
                .{
                    previous_models,
                    self.project_model_commits,
                    @intFromBool(self.project_load != null),
                    @intFromBool(self.hasWorkerJob(.project_scan)),
                    self.project_entry_count,
                    @intFromBool(self.project_truncated),
                    @intFromBool(
                        self.project_index.findPath("src/rank-target.zig") != null,
                    ),
                },
            );
            return searchLoadFailure("initial_project_model");
        }
        if (self.project_entry_count < 200 or self.project_truncated)
            return searchLoadFailure("initial_project_bounds");
        const target_path = std.fs.path.join(
            self.allocator,
            &.{ root, "src/rank-target.zig" },
        ) catch return searchLoadFailure("target_path");
        defer self.allocator.free(target_path);
        const save_path = std.fs.path.joinZ(
            self.allocator,
            &.{ root, "src/qualification-save.zig" },
        ) catch return searchLoadFailure("save_path");
        defer self.allocator.free(save_path);

        self.showQuickOpen();
        for (0..cycles) |cycle| {
            for (ranking_queries, 0..) |query, query_index| {
                c.gtk_entry_set_text(@ptrCast(self.quick_open_entry), "");
                self.cancelQuickOpenUpdate();
                const started = std.Io.Clock.awake.now(self.io);
                const query_z = Compat.dupeZ(self.allocator, query) catch
                    return searchLoadFailure("quick_open_query");
                defer self.allocator.free(query_z);
                c.gtk_entry_set_text(@ptrCast(self.quick_open_entry), query_z.ptr);
                self.scheduleQuickOpenUpdate();
                if (!self.waitForQuickOpen())
                    return searchLoadFailure("quick_open_wait");
                quick_values[cycle * ranking_queries.len + query_index] =
                    elapsedNanoseconds(started, self.io);
                const fingerprint = self.quickOpenFingerprint() orelse
                    return searchLoadFailure("quick_open_fingerprint");
                if (ranking_fingerprints[query_index]) |expected| {
                    if (fingerprint != expected)
                        return searchLoadFailure("quick_open_ranking");
                } else {
                    ranking_fingerprints[query_index] = fingerprint;
                }
            }
        }
        self.hideQuickOpen();
        self.showProjectFind();

        for (0..cycles) |cycle| {
            const first_before = self.project_search_first_commits;
            const completion_before = self.project_search_completion_commits;
            const draw_before = self.project_search_draw_commits;
            c.gtk_entry_set_text(
                @ptrCast(self.project_search_entry),
                "qualification_search_marker",
            );
            self.runProjectSearch();
            if (!self.waitForSearchQualification(
                first_before,
                completion_before,
                draw_before,
            )) return searchLoadFailure("search_wait");
            first_values[cycle] = self.project_search_last_first_ns;
            total_values[cycle] = self.project_search_last_total_ns;
            draw_values[cycle] = self.project_search_last_draw_ns;
            if (self.project_search_result_count < 200 or
                self.project_search_truncated)
                return searchLoadFailure("search_result_bounds");
        }

        for (0..cycles) |cycle| {
            c.gtk_entry_set_text(
                @ptrCast(self.project_search_entry),
                "qualification_absent_marker",
            );
            self.runProjectSearch();
            if (!self.hasWorkerJob(.project_search))
                return searchLoadFailure("cancel_search_admission");
            const cancel_before = self.project_search_cancel_commits;
            const first_before = self.project_search_first_commits;
            const completion_before = self.project_search_completion_commits;
            const draw_before = self.project_search_draw_commits;
            c.gtk_entry_set_text(
                @ptrCast(self.project_search_entry),
                "qualification_search_marker",
            );
            self.runProjectSearch();
            if (!self.waitForSearchCancellation(cancel_before))
                return searchLoadFailure("search_cancel_wait");
            if (!self.waitForSearchQualification(
                first_before,
                completion_before,
                draw_before,
            )) return searchLoadFailure("cancel_replacement_wait");
            cancel_values[cycle] = self.project_search_last_cancel_ns;
        }

        for (0..cycles) |cycle| {
            c.gtk_entry_set_text(
                @ptrCast(self.project_search_entry),
                "qualification_absent_marker",
            );
            self.runProjectSearch();
            if (!self.hasWorkerJob(.project_search))
                return searchLoadFailure("open_search_admission");
            const started = std.Io.Clock.awake.now(self.io);
            self.openDocument(target_path) catch
                return searchLoadFailure("open_under_search");
            self.drainWorkerKind(.document_load);
            open_values[cycle] = elapsedNanoseconds(started, self.io);
            self.cancelProjectSearch();
            self.drainWorkerKind(.project_search);
        }

        for (0..cycles) |cycle| {
            const refresh_models = self.project_model_commits;
            self.openProject(root) catch return searchLoadFailure("refresh_project");
            if (!self.hasWorkerJob(.project_scan))
                return searchLoadFailure("refresh_scan_admission");
            const started = std.Io.Clock.awake.now(self.io);
            _ = self.saveContentsOnWorker(
                save_path,
                "const qualification_save = true;\n",
                core.document.identityForPath(self.io, save_path) catch null,
            ) catch return searchLoadFailure("save_under_refresh");
            save_values[cycle] = elapsedNanoseconds(started, self.io);
            if (!self.waitForProjectModel(refresh_models, null))
                return searchLoadFailure("refresh_project_model");
        }

        self.cancelProjectSearch();
        self.drainWorkerKind(.project_search);
        self.drainWorkerKind(.document_load);
        self.drainWorkerKind(.project_scan);
        const first = summarizeLatencies(&first_values);
        const total = summarizeLatencies(&total_values);
        const draw = summarizeLatencies(&draw_values);
        const cancel = summarizeLatencies(&cancel_values);
        const open = summarizeLatencies(&open_values);
        const save = summarizeLatencies(&save_values);
        const quick = summarizeLatencies(&quick_values);
        const passed = first.p50_ns > 0 and total.p50_ns >= first.p50_ns and
            draw.p50_ns > 0 and cancel.p50_ns > 0 and open.p95_ns > 0 and
            save.p95_ns > 0 and quick.p50_ns > 0 and
            self.worker_peak_search_batches <= WorkerJob.max_search_batches and
            self.worker_peak_search_batches > 0 and self.worker_jobs.items.len == 0;
        var receipt_buffer: [2048]u8 = undefined;
        const receipt = Compat.bufPrintZ(
            &receipt_buffer,
            "nocted_search_load_qualification pass={d} cycles={d} entries={d} " ++
                "first_p50_ns={d} first_p95_ns={d} first_p99_ns={d} " ++
                "total_p50_ns={d} total_p95_ns={d} total_p99_ns={d} " ++
                "cancel_p50_ns={d} cancel_p95_ns={d} cancel_p99_ns={d} " ++
                "ui_draw_p50_ns={d} ui_draw_p95_ns={d} ui_draw_p99_ns={d} " ++
                "open_under_search_p95_ns={d} save_under_refresh_p95_ns={d} " ++
                "quick_open_samples={d} quick_open_p50_ns={d} " ++
                "quick_open_p95_ns={d} quick_open_p99_ns={d} " ++
                "ranking_queries={d} ranking_cycles={d} ranking_deterministic=true " ++
                "gtk_batch_peak={d} gtk_batch_cap={d} foreground_lane=true " ++
                "scan_lane=true worker_drained={d}\n",
            .{
                @intFromBool(passed),
                cycles,
                self.project_entry_count,
                first.p50_ns,
                first.p95_ns,
                first.p99_ns,
                total.p50_ns,
                total.p95_ns,
                total.p99_ns,
                cancel.p50_ns,
                cancel.p95_ns,
                cancel.p99_ns,
                draw.p50_ns,
                draw.p95_ns,
                draw.p99_ns,
                open.p95_ns,
                save.p95_ns,
                quick_samples,
                quick.p50_ns,
                quick.p95_ns,
                quick.p99_ns,
                ranking_queries.len,
                cycles,
                self.worker_peak_search_batches,
                WorkerJob.max_search_batches,
                @intFromBool(self.worker_jobs.items.len == 0),
            },
        ) catch return false;
        c.g_print("%s", receipt.ptr);
        return passed;
    }

    fn finishProjectLifecycleSmoke(self: *App, qualification_passed: bool) void {
        const worker_drained = self.worker_jobs.items.len == 0 and
            self.project_load == null and self.project_load_source == 0;
        const changes_before = self.project_monitor_changes.items.len;
        const late_before = self.project_monitor_late_callbacks;
        const hot_exit = self.prepareHotExit();
        if (!hot_exit) self.shutting_down = true;
        c.gtk_widget_destroy(self.window);
        onProjectMonitorChanged(
            null,
            null,
            null,
            c.G_FILE_MONITOR_EVENT_CREATED,
            self,
        );
        const late_guard = self.project_monitor_late_callbacks == late_before + 1 and
            self.project_monitor_changes.items.len == changes_before and
            self.project_monitor_source == 0 and worker_drained;
        self.project_lifecycle_passed = qualification_passed and hot_exit and late_guard;
        var receipt_buffer: [512]u8 = undefined;
        const receipt = Compat.bufPrintZ(
            &receipt_buffer,
            "nocted_project_lifecycle_teardown pass={d} callback_after_widget=true " ++
                "late_callback_ignored={d} source_scheduled={d} worker_drained={d}\n",
            .{
                @intFromBool(self.project_lifecycle_passed),
                @intFromBool(late_guard),
                @intFromBool(self.project_monitor_source != 0),
                @intFromBool(worker_drained),
            },
        ) catch return;
        c.g_print("%s", receipt.ptr);
    }

    fn runResourceSmoke(self: *App) bool {
        const cycles: usize = 8;
        const root = self.allocator.dupe(
            u8,
            self.project_root orelse return false,
        ) catch return false;
        defer self.allocator.free(root);
        var source_path: ?[]u8 = null;
        for (self.documents.items) |document| {
            const path = document.path orelse continue;
            if (!pathIsWithin(root, path)) continue;
            source_path = self.allocator.dupe(u8, path) catch return false;
            break;
        }
        const source = source_path orelse return false;
        defer self.allocator.free(source);
        const directory = std.fs.path.dirname(
            self.smoke_save_as_path orelse return false,
        ) orelse return false;
        const baseline_documents = self.documents.items.len;
        const cancelled_before = self.worker_cancelled_jobs;

        for (0..cycles) |cycle| {
            self.openProject(root) catch return false;
            self.openProject(root) catch return false;
            if (!self.drainProjectLoad()) return false;

            c.gtk_entry_set_text(@ptrCast(self.project_search_entry), "message");
            self.runProjectSearch();
            c.gtk_entry_set_text(@ptrCast(self.project_search_entry), "const");
            self.runProjectSearch();
            if (!self.drainProjectSearch()) return false;

            for (0..3) |_| self.openDocument(source) catch return false;
            self.drainDocumentLoads();
            if (self.documents.items.len != baseline_documents) return false;

            self.newDocument() catch return false;
            const created = self.currentDocument() orelse return false;
            if (created.path != null) return false;
            var end: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_end_iter(@ptrCast(created.buffer), &end);
            c.gtk_text_buffer_insert(
                @ptrCast(created.buffer),
                &end,
                "const resource_cycle = true;\n",
                -1,
            );
            const save_path = std.fmt.allocPrint(
                self.allocator,
                "{s}/.nocted-resource-{d}.zig",
                .{ directory, cycle },
            ) catch return false;
            defer self.allocator.free(save_path);
            std.Io.Dir.cwd().deleteFile(self.io, save_path) catch {};
            if (!self.saveDocumentAsPath(created, save_path)) return false;
            if (!self.closeDocument(created)) return false;
            std.Io.Dir.cwd().deleteFile(self.io, save_path) catch return false;
            if (!self.drainProjectLoad()) return false;
            if (self.documents.items.len != baseline_documents) return false;
        }
        self.openProject(root) catch return false;
        if (!self.drainProjectLoad()) return false;
        const cancelled = self.worker_cancelled_jobs - cancelled_before;
        const passed = self.worker_jobs.items.len == 0 and
            self.project_load == null and self.project_load_source == 0 and
            self.worker_peak_pending >= 2 and cancelled >= cycles * 2 and
            self.documents.items.len == baseline_documents and
            self.active_document != null;
        c.g_print(
            "nocted_resource_smoke pass=%d cycles=%zu queue_cap=%zu queue_peak=%zu cancelled_jobs=%zu documents=%zu worker_drained=%d project_drained=%d\n",
            @as(c_int, @intFromBool(passed)),
            cycles,
            WorkerJob.max_pending,
            self.worker_peak_pending,
            cancelled,
            self.documents.items.len,
            @as(c_int, @intFromBool(self.worker_jobs.items.len == 0)),
            @as(c_int, @intFromBool(self.project_load == null)),
        );
        return passed;
    }

    fn runSmoke(self: *App) bool {
        var textmate_import_ok = false;
        var textmate_language_ok = false;
        var textmate_rendered_ok = false;
        var textmate_precedence_ok = false;
        const textmate_malformed_rejected = blk: {
            var converted = core.textmate_grammar.convertAlloc(
                self.allocator,
                "{broken",
            ) catch |err| break :blk err == error.InvalidTextMateGrammar;
            converted.deinit(self.allocator);
            break :blk false;
        };
        const document_before_textmate_import = self.currentDocument();
        if (self.smoke_textmate_grammar_path) |grammar_path| {
            if (self.smoke_textmate_document_path) |document_path| {
                textmate_import_ok = self.importTextMateGrammarFile(grammar_path);
                const search_paths = c.gtk_source_language_manager_get_search_path(
                    self.language_manager,
                );
                textmate_precedence_ok = search_paths != null and
                    search_paths.?[0] != null and
                    std.mem.eql(
                        u8,
                        std.mem.span(search_paths.?[0].?),
                        self.generated_language_path,
                    );
                if (textmate_import_ok) {
                    self.openDocument(document_path) catch {};
                    self.drainDocumentLoads();
                    if (self.currentDocument()) |imported_document| {
                        const imported_language = c.gtk_source_buffer_get_language(
                            imported_document.buffer,
                        );
                        textmate_language_ok = if (imported_language) |language|
                            std.mem.eql(
                                u8,
                                std.mem.span(c.gtk_source_language_get_id(language)),
                                "task-note",
                            ) and std.mem.eql(
                                u8,
                                std.mem.span(c.gtk_source_language_get_name(language)),
                                "Task Notes",
                            )
                        else
                            false;
                        textmate_rendered_ok = imported_document.path != null and
                            std.mem.eql(u8, imported_document.path.?, document_path) and
                            c.gtk_notebook_page_num(
                                asNotebook(self.notebook),
                                imported_document.page,
                            ) >= 0;
                    }
                }
                if (document_before_textmate_import) |document|
                    self.focusDocument(document);
            }
        }
        var project_activation_ok = false;
        var project_tree_lazy_ok = false;
        if (c.gtk_tree_path_new_from_string("0:0")) |directory_path| {
            const model = c.gtk_tree_view_get_model(asTreeView(self.tree));
            var directory_iter: c.GtkTreeIter = undefined;
            var child_before: c.GtkTreeIter = undefined;
            const directory_found = model != null and
                c.gtk_tree_model_get_iter(model.?, &directory_iter, directory_path) != 0;
            const placeholder_before = directory_found and
                c.gtk_tree_model_iter_children(model.?, &child_before, &directory_iter) != 0 and
                treeValueUInt64(model.?, &child_before, 1) == project_placeholder_entry;
            _ = c.gtk_tree_view_expand_row(asTreeView(self.tree), directory_path, 0);
            c.gtk_tree_path_free(directory_path);
            if (c.gtk_tree_path_new_from_string("0:0:0")) |first_file_path| {
                var first_file_iter: c.GtkTreeIter = undefined;
                const file_materialized = model != null and
                    c.gtk_tree_model_get_iter(model.?, &first_file_iter, first_file_path) != 0 and
                    treeValueUInt64(model.?, &first_file_iter, 1) != project_placeholder_entry;
                project_tree_lazy_ok = placeholder_before and file_materialized;
                c.gtk_tree_path_free(first_file_path);
            }
            if (self.project_index.findPath("src/sample.zig")) |sample_index| {
                const source_index = self.project_index.findPath("src") orelse
                    project_placeholder_entry;
                if (source_index < self.project_index.entries.len) {
                    var sample_ordinal: ?usize = null;
                    for (self.project_index.childIndices(
                        self.project_index.entries[source_index],
                    ), 0..) |entry_index, ordinal| {
                        if (entry_index == sample_index) sample_ordinal = ordinal;
                    }
                    var path_buffer: [32]u8 = undefined;
                    const sample_path_text = if (sample_ordinal) |ordinal|
                        Compat.bufPrintZ(&path_buffer, "0:0:{d}", .{ordinal}) catch null
                    else
                        null;
                    if (sample_path_text) |path_text| {
                        if (c.gtk_tree_path_new_from_string(path_text.ptr)) |file_path| {
                            const expected_path = self.projectEntryPathAlloc(sample_index) catch null;
                            defer if (expected_path) |value| self.allocator.free(value);
                            onProjectRowActivated(@ptrCast(self.tree), file_path, null, self);
                            c.gtk_tree_path_free(file_path);
                            self.drainDocumentLoads();
                            const active_path = if (self.currentDocument()) |value| value.path else null;
                            const status = std.mem.span(c.gtk_label_get_text(asLabel(self.status_label)));
                            project_activation_ok = expected_path != null and active_path != null and
                                std.mem.eql(u8, expected_path.?, active_path.?) and
                                !std.mem.startsWith(u8, status, "Open failed:");
                        }
                    }
                }
            }
        }
        var project_parent_navigation_ok = false;
        if (self.project_root) |root| {
            const original_root = self.allocator.dupe(u8, root) catch null;
            defer if (original_root) |value| self.allocator.free(value);
            if (original_root) |original| {
                const child_root = std.fs.path.join(
                    self.allocator,
                    &.{ original, "src" },
                ) catch null;
                defer if (child_root) |value| self.allocator.free(value);
                if (child_root) |child| {
                    if (pathIsDirectory(self.io, child)) {
                        self.openProject(child) catch {};
                        const entered_child = self.drainProjectLoad() and
                            self.project_root != null and
                            std.mem.eql(u8, self.project_root.?, child) and
                            c.gtk_widget_get_sensitive(
                                self.project_parent_button,
                            ) != 0;
                        if (entered_child) {
                            onOpenParentFolder(
                                self.project_parent_button,
                                self,
                            );
                            project_parent_navigation_ok =
                                self.drainProjectLoad() and
                                self.project_root != null and
                                std.mem.eql(
                                    u8,
                                    self.project_root.?,
                                    original,
                                );
                        }
                        if (self.project_root == null or
                            !std.mem.eql(u8, self.project_root.?, original))
                        {
                            self.openProject(original) catch {};
                            _ = self.drainProjectLoad();
                        }
                    }
                }
            }
        }
        const document = self.currentDocument();
        const language = if (document) |value|
            c.gtk_source_buffer_get_language(value.buffer)
        else
            null;
        const language_id = if (language) |value|
            c.gtk_source_language_get_id(value)
        else
            "none";
        const language_ok = std.mem.eql(u8, std.mem.span(language_id), "zig");
        const tree_sitter_ok = if (document) |value|
            value.syntax != null and value.syntax_capture_count > 0
        else
            false;
        const line_numbers_ok = if (document) |value|
            c.gtk_source_view_get_show_line_numbers(@ptrCast(value.view)) != 0
        else
            false;
        const minimap_bound = if (document) |value|
            if (value.map) |map|
                c.gtk_source_map_get_view(@ptrCast(map)) ==
                    @as(*c.GtkSourceView, @ptrCast(value.view))
            else
                false
        else
            false;
        const minimap_geometry = if (document) |value|
            if (value.map) |map| geometry: {
                const width = c.gtk_widget_get_allocated_width(map);
                break :geometry width >= 64 and width <= 160;
            } else false
        else
            false;
        const editor_zoom_ok = if (document) |value| zoom: {
            const initial_zoom = self.editor_zoom_percent;
            const initial_ui_font = self.settings.ui_font_size_pt;
            const grows = initial_zoom < editor_zoom_percent_max;
            const changed_zoom = if (grows)
                initial_zoom + editor_zoom_percent_step
            else
                initial_zoom - editor_zoom_percent_step;
            const change_direction: c_int =
                if (grows) c.GDK_SCROLL_UP else c.GDK_SCROLL_DOWN;
            const restore_direction: c_int =
                if (grows) c.GDK_SCROLL_DOWN else c.GDK_SCROLL_UP;
            var scroll_event = std.mem.zeroes(c.GdkEventScroll);
            scroll_event.state = c.GDK_CONTROL_MASK;
            scroll_event.direction = change_direction;
            const zoomed = onEditorScroll(
                value.view,
                &scroll_event,
                value,
            ) != 0 and self.editor_zoom_percent == changed_zoom and
                self.settings.ui_font_size_pt == initial_ui_font;
            scroll_event.direction = restore_direction;
            const restored = onEditorScroll(
                value.view,
                &scroll_event,
                value,
            ) != 0 and self.editor_zoom_percent == initial_zoom and
                self.settings.ui_font_size_pt == initial_ui_font;
            scroll_event.direction = c.GDK_SCROLL_SMOOTH;
            scroll_event.delta_y = if (grows) -1 else 1;
            const smooth_zoomed = onEditorScroll(
                value.view,
                &scroll_event,
                value,
            ) != 0 and self.editor_zoom_percent == changed_zoom and
                self.settings.ui_font_size_pt == initial_ui_font;
            scroll_event.delta_y = if (grows) 1 else -1;
            const smooth_restored = onEditorScroll(
                value.view,
                &scroll_event,
                value,
            ) != 0 and self.editor_zoom_percent == initial_zoom and
                self.settings.ui_font_size_pt == initial_ui_font;
            scroll_event.state = 0;
            scroll_event.direction = c.GDK_SCROLL_UP;
            const ordinary_scroll = onEditorScroll(
                value.view,
                &scroll_event,
                value,
            ) == 0 and self.editor_zoom_percent == initial_zoom and
                self.settings.ui_font_size_pt == initial_ui_font;
            break :zoom zoomed and restored and smooth_zoomed and
                smooth_restored and ordinary_scroll;
        } else false;
        const project_ok = self.project_entry_count > 0 and !self.project_truncated;
        const language_count = self.languageCount();
        var undo_ok = false;
        var redo_ok = false;
        var multi_selection_ok = false;
        var multi_selection_undo_ok = false;
        var multi_selection_rendered_ok = false;
        var save_ok = false;
        var search_ok = false;
        var fold_ok = false;
        var unfold_ok = false;
        var folded_save_ok = false;
        var folded_edit_restore_ok = false;
        var fold_undo_preserved_ok = false;
        var folding_config_ok = false;
        var word_wrap_config_ok = false;
        var folded_regions: usize = 0;
        var find_in_files_ok = false;
        var search_snapshot_ok = false;
        var external_changes_ok = false;
        var project_search_activation_ok = false;
        var multi_file_tabs_ok = false;
        var tab_navigation_ok = false;
        var close_other_ok = false;
        var close_all_ok = false;
        var document_reopen_ok = false;
        var untitled_ok = false;
        var untitled_dirty_ok = false;
        var save_as_ok = false;
        var save_as_collision_ok = false;
        var save_as_atomic_ok = false;
        var save_as_language_ok = false;
        var quick_open_ok = false;
        var quick_open_bounded_ok = false;
        var quick_open_activation_ok = false;
        var session_persist_ok = false;
        var session_restore_ok = false;
        var session_dirty_restore_ok = false;
        var recent_project_ok = false;
        const original_path = if (document) |value|
            if (value.path) |path|
                self.allocator.dupe(u8, path) catch null
            else
                null
        else
            null;
        defer if (original_path) |path| self.allocator.free(path);
        if (document) |value| {
            const before_multi = value.completeTextAlloc() catch null;
            defer if (before_multi) |text| self.allocator.free(text);
            if (before_multi != null and before_multi.?.len >= 5 and
                std.mem.eql(u8, before_multi.?[0..5], "const"))
            {
                var selection_start: c.GtkTextIter = undefined;
                var selection_end: c.GtkTextIter = undefined;
                c.gtk_text_buffer_get_iter_at_offset(
                    @ptrCast(value.buffer),
                    &selection_start,
                    0,
                );
                c.gtk_text_buffer_get_iter_at_offset(
                    @ptrCast(value.buffer),
                    &selection_end,
                    5,
                );
                c.gtk_text_buffer_select_range(
                    @ptrCast(value.buffer),
                    &selection_end,
                    &selection_start,
                );
                if (value.selectAllOccurrences()) |matches_value| {
                    var matches = matches_value;
                    defer matches.deinit(self.allocator);
                    multi_selection_ok = matches.ranges.len >= 3 and
                        value.secondary_selections.items.len + 1 == matches.ranges.len;
                    if (value.secondary_selections.items.len > 0) {
                        var rendered: c.GtkTextIter = undefined;
                        c.gtk_text_buffer_get_iter_at_mark(
                            @ptrCast(value.buffer),
                            &rendered,
                            value.secondary_selections.items[0].start_mark,
                        );
                        multi_selection_rendered_ok = c.gtk_text_iter_has_tag(
                            &rendered,
                            value.selection_tag,
                        ) != 0;
                    }
                    multi_selection_ok = multi_selection_ok and
                        value.replaceMultiSelections("var");
                    const after_multi = value.completeTextAlloc() catch null;
                    if (after_multi) |text| {
                        multi_selection_ok = multi_selection_ok and
                            std.mem.count(u8, text, "var") >= matches.ranges.len;
                        self.allocator.free(text);
                    }
                    if (c.gtk_source_buffer_can_undo(value.buffer) != 0) {
                        c.gtk_source_buffer_undo(value.buffer);
                        const restored = value.completeTextAlloc() catch null;
                        if (restored) |text| {
                            multi_selection_undo_ok = std.mem.eql(
                                u8,
                                text,
                                before_multi.?,
                            );
                            self.allocator.free(text);
                        }
                    }
                    var unicode_ok = false;
                    {
                        var prefix_start: c.GtkTextIter = undefined;
                        c.gtk_text_buffer_get_start_iter(@ptrCast(value.buffer), &prefix_start);
                        c.gtk_text_buffer_insert(@ptrCast(value.buffer), &prefix_start, "λ ", 3);
                        const full = value.completeTextAlloc() catch null;
                        if (full) |text| {
                            defer self.allocator.free(text);
                            const second = std.mem.indexOf(u8, text[3..], "const");
                            var sel_start: c.GtkTextIter = undefined;
                            var sel_end: c.GtkTextIter = undefined;
                            c.gtk_text_buffer_get_iter_at_offset(@ptrCast(value.buffer), &sel_start, 3);
                            c.gtk_text_buffer_get_iter_at_offset(@ptrCast(value.buffer), &sel_end, 8);
                            c.gtk_text_buffer_select_range(@ptrCast(value.buffer), &sel_end, &sel_start);
                            if (value.selectAllOccurrences()) |m| {
                                var mm = m;
                                defer mm.deinit(self.allocator);
                                if (value.secondary_selections.items.len > 0 and second != null) {
                                    var mark_iter: c.GtkTextIter = undefined;
                                    c.gtk_text_buffer_get_iter_at_mark(
                                        @ptrCast(value.buffer),
                                        &mark_iter,
                                        value.secondary_selections.items[0].start_mark,
                                    );
                                    unicode_ok = c.gtk_text_iter_get_offset(&mark_iter) ==
                                        @as(c_int, @intCast(3 + second.?));
                                }
                                value.clearMultiSelections();
                            } else |_| {}
                        }
                        var p_start: c.GtkTextIter = undefined;
                        var p_end: c.GtkTextIter = undefined;
                        c.gtk_text_buffer_get_iter_at_offset(@ptrCast(value.buffer), &p_start, 0);
                        c.gtk_text_buffer_get_iter_at_offset(@ptrCast(value.buffer), &p_end, 3);
                        c.gtk_text_buffer_delete(@ptrCast(value.buffer), &p_start, &p_end);
                    }
                    multi_selection_ok = multi_selection_ok and unicode_ok;
                    c.gtk_text_buffer_set_modified(@ptrCast(value.buffer), 0);
                } else |_| {}
            }
            var end: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_end_iter(@ptrCast(value.buffer), &end);
            c.gtk_text_buffer_insert(
                @ptrCast(value.buffer),
                &end,
                "// nocted native smoke\n",
                -1,
            );
            undo_ok = c.gtk_source_buffer_can_undo(value.buffer) != 0;
            if (undo_ok) {
                c.gtk_source_buffer_undo(value.buffer);
                redo_ok = c.gtk_source_buffer_can_redo(value.buffer) != 0;
                if (redo_ok) c.gtk_source_buffer_redo(value.buffer);
            }
            c.gtk_check_menu_item_set_active(@ptrCast(self.folding_item), 0);
            const disabled = !self.settings.code_folding_enabled;
            c.gtk_check_menu_item_set_active(@ptrCast(self.folding_item), 1);
            folding_config_ok = disabled and self.settings.code_folding_enabled and
                c.gtk_check_menu_item_get_active(@ptrCast(self.folding_item)) != 0;
            var wrap_key: c.GdkEventKey = std.mem.zeroes(c.GdkEventKey);
            wrap_key.state = c.GDK_MOD1_MASK;
            wrap_key.keyval = c.GDK_KEY_z;
            const initial_word_wrap = self.settings.word_wrap_enabled;
            const switched_word_wrap = onEditorKeyPress(value.view, &wrap_key, value) != 0 and
                self.settings.word_wrap_enabled != initial_word_wrap;
            const restored_word_wrap = onEditorKeyPress(value.view, &wrap_key, value) != 0 and
                self.settings.word_wrap_enabled == initial_word_wrap;
            word_wrap_config_ok = switched_word_wrap and restored_word_wrap and
                c.gtk_check_menu_item_get_active(@ptrCast(self.word_wrap_item)) ==
                    @intFromBool(initial_word_wrap);
            if (value.analyzeFolds()) |analysis_value| {
                var analysis = analysis_value;
                defer analysis.deinit();
                folded_regions = value.foldTopLevel(&analysis) catch 0;
                if (value.folds.items.len > 0) {
                    var folded_start: c.GtkTextIter = undefined;
                    c.gtk_text_buffer_get_iter_at_mark(
                        @ptrCast(value.buffer),
                        &folded_start,
                        value.folds.items[0].start_mark,
                    );
                    fold_ok = c.gtk_text_iter_has_tag(
                        &folded_start,
                        value.fold_tag,
                    ) != 0;
                    save_ok = self.saveDocument(value);
                    folded_save_ok = save_ok and self.savedFileMatchesBuffer(value);
                    unfold_ok = value.clearFolds() == folded_regions and
                        value.folds.items.len == 0 and
                        self.savedFileMatchesBuffer(value);
                    const undo_before_refold = c.gtk_source_buffer_can_undo(value.buffer) != 0;
                    if (unfold_ok and (value.foldTopLevel(&analysis) catch 0) > 0) {
                        fold_undo_preserved_ok = undo_before_refold and
                            c.gtk_source_buffer_can_undo(value.buffer) != 0;
                        var edit_at_fold: c.GtkTextIter = undefined;
                        c.gtk_text_buffer_get_iter_at_mark(
                            @ptrCast(value.buffer),
                            &edit_at_fold,
                            value.folds.items[0].start_mark,
                        );
                        c.gtk_text_buffer_insert(
                            @ptrCast(value.buffer),
                            &edit_at_fold,
                            " ",
                            1,
                        );
                        folded_edit_restore_ok = value.folds.items.len == 0 and
                            c.gtk_source_buffer_can_undo(value.buffer) != 0;
                        if (folded_edit_restore_ok) {
                            c.gtk_source_buffer_undo(value.buffer);
                            folded_edit_restore_ok = self.savedFileMatchesBuffer(value);
                            if (folded_edit_restore_ok)
                                c.gtk_text_buffer_set_modified(
                                    @ptrCast(value.buffer),
                                    0,
                                );
                        }
                    }
                }
            } else |_| {}
            self.focusDocument(value);
            c.gtk_entry_set_text(@ptrCast(self.search_entry), "const");
            self.updateSearch();
            if (value.search_context) |context| {
                while (c.gtk_source_search_context_get_occurrences_count(context) < 0)
                    _ = c.g_main_context_iteration(null, 1);
            }
            var origin: c.GtkTextIter = undefined;
            var match_start: c.GtkTextIter = undefined;
            var match_end: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_start_iter(@ptrCast(value.buffer), &origin);
            if (value.search_context) |context|
                search_ok = c.gtk_source_search_context_forward(
                    context,
                    &origin,
                    &match_start,
                    &match_end,
                    null,
                ) != 0;
        }
        if (self.smoke_save_as_path) |save_as_path| {
            self.newDocument() catch {};
            if (self.currentDocument()) |created| {
                untitled_ok = created.path == null and
                    std.mem.startsWith(u8, created.display_name, "Untitled") and
                    c.gtk_text_buffer_get_modified(@ptrCast(created.buffer)) == 0;
                var end: c.GtkTextIter = undefined;
                c.gtk_text_buffer_get_end_iter(@ptrCast(created.buffer), &end);
                c.gtk_text_buffer_insert(
                    @ptrCast(created.buffer),
                    &end,
                    "const smoke_created = true;\n",
                    -1,
                );
                untitled_dirty_ok = c.gtk_text_buffer_get_modified(
                    @ptrCast(created.buffer),
                ) != 0;
                if (original_path) |open_path| {
                    save_as_collision_ok = !self.saveDocumentAsPath(created, open_path) and
                        created.path == null and
                        c.gtk_text_buffer_get_modified(@ptrCast(created.buffer)) != 0;
                }
                save_as_ok = self.saveDocumentAsPath(created, save_as_path);
                if (save_as_ok and self.drainProjectLoad()) {
                    save_as_atomic_ok = self.savedFileMatchesBuffer(created) and
                        c.gtk_text_buffer_get_modified(@ptrCast(created.buffer)) == 0 and
                        std.mem.eql(
                            u8,
                            std.mem.span(c.gtk_label_get_text(asLabel(created.tab_label))),
                            "created.zig",
                        );
                    const created_language = c.gtk_source_buffer_get_language(created.buffer);
                    save_as_language_ok = if (created_language) |value|
                        std.mem.eql(
                            u8,
                            std.mem.span(c.gtk_source_language_get_id(value)),
                            "zig",
                        )
                    else
                        false;
                    c.gtk_entry_set_text(@ptrCast(self.quick_open_entry), "created");
                    self.updateQuickOpen();
                    quick_open_ok = self.quick_open_result_count == 1;
                    quick_open_bounded_ok = self.quick_open_result_count <=
                        core.quick_open.max_results and !self.quick_open_truncated;
                    const quick_activations_before = self.quick_open_activations;
                    quick_open_activation_ok = self.activateSelectedQuickOpen() and
                        self.quick_open_activations == quick_activations_before + 1 and
                        self.currentDocument() == created;
                }
            }
        }
        if (self.currentDocument()) |snapshot_document| {
            var snapshot_end: c.GtkTextIter = undefined;
            c.gtk_text_buffer_get_end_iter(@ptrCast(snapshot_document.buffer), &snapshot_end);
            c.gtk_text_buffer_insert(
                @ptrCast(snapshot_document.buffer),
                &snapshot_end,
                "const snapshot_only_marker = true;\n",
                -1,
            );
            c.gtk_entry_set_text(
                @ptrCast(self.project_search_entry),
                "snapshot_only_marker",
            );
            self.runProjectSearch();
            search_snapshot_ok = self.drainProjectSearch() and
                self.project_search_result_count == 1;
            if (c.gtk_source_buffer_can_undo(snapshot_document.buffer) != 0)
                c.gtk_source_buffer_undo(snapshot_document.buffer);
            c.gtk_text_buffer_set_modified(@ptrCast(snapshot_document.buffer), 0);
        }
        c.gtk_entry_set_text(@ptrCast(self.project_search_entry), "const");
        self.runProjectSearch();
        find_in_files_ok = self.drainProjectSearch() and
            self.project_search_result_count >= 50 and
            !self.project_search_truncated and
            self.worker_peak_search_batches == WorkerJob.max_search_batches;
        const activations_before = self.project_search_activations;
        if (c.gtk_tree_path_new_from_string("0")) |path| {
            onProjectSearchRowActivated(
                @ptrCast(self.project_search_tree),
                path,
                null,
                self,
            );
            c.gtk_tree_path_free(path);
        }
        project_search_activation_ok = self.project_search_activations ==
            activations_before + 1;
        if (self.currentDocument()) |external_document|
            external_changes_ok = self.smokeExternalChanges(external_document);
        self.newDocument() catch {};
        if (self.currentDocument()) |dirty_document| {
            if (dirty_document.path == null) {
                var dirty_end: c.GtkTextIter = undefined;
                c.gtk_text_buffer_get_end_iter(@ptrCast(dirty_document.buffer), &dirty_end);
                c.gtk_text_buffer_insert(
                    @ptrCast(dirty_document.buffer),
                    &dirty_end,
                    "const hot_exit_marker = true;\n",
                    -1,
                );
            }
        }
        _ = self.persistSessionReported();
        if (core.session.loadAlloc(
            self.allocator,
            self.io,
            self.session_path,
        )) |loaded_value| {
            var loaded = loaded_value;
            defer loaded.deinit(self.allocator);
            session_persist_ok = loaded.project == null and
                loaded.tabs.items.len >= 2 and
                loaded.active_tab != null and
                loaded.recent_projects.items.len > 0;
            if (session_persist_ok) {
                self.suppress_session_persist = true;
                for (self.documents.items) |open_document|
                    c.gtk_text_buffer_set_modified(
                        @ptrCast(open_document.buffer),
                        0,
                    );
                const closed_for_restore = self.closeAllDocuments();
                self.suppress_session_persist = false;
                const restores_before = self.session_restores;
                session_restore_ok = closed_for_restore and self.restoreSession() and
                    self.session_restores == restores_before + 1 and
                    self.sessionMatchesOpenTabs(&loaded);
                if (session_restore_ok) {
                    if (self.currentDocument()) |restored_document| {
                        const restored_text = restored_document.completeTextAlloc() catch null;
                        defer if (restored_text) |text| self.allocator.free(text);
                        session_dirty_restore_ok = restored_document.path == null and
                            restored_text != null and
                            std.mem.indexOf(
                                u8,
                                restored_text.?,
                                "const hot_exit_marker = true;\n",
                            ) != null and
                            c.gtk_text_buffer_get_modified(
                                @ptrCast(restored_document.buffer),
                            ) != 0;
                        c.gtk_text_buffer_set_modified(
                            @ptrCast(restored_document.buffer),
                            0,
                        );
                    }
                }
                const recent_before = self.recent_project_activations;
                self.openRecentProject(0);
                recent_project_ok = self.drainProjectLoad() and
                    self.recent_project_activations == recent_before + 1 and
                    self.project_file_path != null and
                    std.mem.eql(
                        u8,
                        self.project_file_path.?,
                        self.session.recent_projects.items[0],
                    ) and self.recent_project_items[0] != null and
                    c.gtk_widget_get_visible(self.recent_project_items[0].?) != 0;
            }
        } else |_| {}
        multi_file_tabs_ok = self.documents.items.len >= 2;
        if (multi_file_tabs_ok) {
            const page_before = c.gtk_notebook_get_current_page(asNotebook(self.notebook));
            tab_navigation_ok = self.cycleDocument(1) and
                c.gtk_notebook_get_current_page(asNotebook(self.notebook)) != page_before and
                self.cycleDocument(-1) and
                c.gtk_notebook_get_current_page(asNotebook(self.notebook)) == page_before;
            close_other_ok = self.closeOtherDocuments() and self.documents.items.len == 1;
            close_all_ok = self.closeAllDocuments() and self.documents.items.len == 0;
            if (original_path) |path| {
                self.openDocument(path) catch {};
                self.drainDocumentLoads();
                document_reopen_ok = self.currentDocument() != null;
            }
        }
        const sidebar_button_visible =
            c.gtk_widget_get_visible(self.sidebar_toggle_button) != 0;
        onToggleSidebar(self.sidebar_toggle_button, self);
        const sidebar_hidden =
            !self.settings.sidebar_visible and
            c.gtk_widget_get_visible(self.sidebar) == 0 and
            c.gtk_widget_get_visible(self.sidebar_toggle_button) != 0;
        onToggleSidebar(self.sidebar_toggle_button, self);
        const sidebar_controls_ok =
            sidebar_button_visible and
            sidebar_hidden and
            self.settings.sidebar_visible and
            c.gtk_widget_get_visible(self.sidebar) != 0;
        const about_close_ok = runAboutDialog(self, true);
        const pass = self.currentDocument() != null and language_ok and tree_sitter_ok and line_numbers_ok and
            minimap_bound and minimap_geometry and editor_zoom_ok and project_ok and
            project_activation_ok and project_tree_lazy_ok and
            project_parent_navigation_ok and sidebar_controls_ok and
            language_count >= 100 and undo_ok and redo_ok and save_ok and
            multi_selection_ok and multi_selection_undo_ok and
            multi_selection_rendered_ok and
            search_ok and fold_ok and unfold_ok and folded_save_ok and
            folded_edit_restore_ok and fold_undo_preserved_ok and
            folding_config_ok and word_wrap_config_ok and find_in_files_ok and search_snapshot_ok and
            external_changes_ok and
            project_search_activation_ok and multi_file_tabs_ok and
            tab_navigation_ok and close_other_ok and close_all_ok and
            document_reopen_ok and untitled_ok and untitled_dirty_ok and
            save_as_ok and save_as_collision_ok and save_as_atomic_ok and
            save_as_language_ok and
            quick_open_ok and quick_open_bounded_ok and quick_open_activation_ok and
            session_persist_ok and session_restore_ok and
            session_dirty_restore_ok and recent_project_ok and
            textmate_import_ok and textmate_language_ok and textmate_rendered_ok and
            textmate_precedence_ok and textmate_malformed_rejected and
            self.worker_pools.foreground != null and self.worker_pools.scan != null and
            self.project_monitors.items.len > 0 and
            self.project_monitors.items.len <= max_project_monitors and
            !self.project_monitor_truncated and
            self.project_delta_updates > 0 and
            self.project_delta_added > 0 and
            self.project_index.retainedCount() == 1 and
            self.settings.minimap_visible and
            self.settings.sidebar_visible and about_close_ok;
        c.g_print(
            "nocted_word_wrap_configurable=%d\n",
            @as(c_int, @intFromBool(word_wrap_config_ok)),
        );
        c.g_print(
            "nocted_tree_navigation parent=%d sidebar_toggle=%d\n",
            @as(c_int, @intFromBool(project_parent_navigation_ok)),
            @as(c_int, @intFromBool(sidebar_controls_ok)),
        );
        c.g_print(
            "nocted_about_dialog close_visible=%d close_response=%d\n",
            @as(c_int, @intFromBool(about_close_ok)),
            @as(c_int, @intFromBool(about_close_ok)),
        );
        c.g_print(
            "nocted_native_smoke_diagnostic pass=%d documents=%zu language=%s language_ok=%d tree_sitter=%d line_numbers=%d minimap_bound=%d minimap_geometry=%d editor_zoom=%d project=%d project_activation=%d project_tree_lazy=%d project_items=%zu project_truncated=%d project_index_bytes=%zu project_index_refs=%zu project_monitors=%zu monitor_events=%zu project_delta_updates=%zu project_delta_fallbacks=%zu project_delta_added=%zu project_delta_removed=%zu external_clean_reload=%d external_dirty_keep=%d installed_syntaxes=%zu undo=%d redo=%d multi_selection=%d multi_selection_undo=%d multi_selection_rendered=%d save=%d search=%d fold=%d unfold=%d folded_save=%d folded_edit_restore=%d fold_undo_preserved=%d folding_configurable=%d folded_regions=%zu find_in_files=%d search_snapshot_first=%d project_search_results=%zu search_batch_peak=%u search_batch_cap=%zu worker_lanes=2 project_search_activation=%d multi_file_tabs=%d tab_navigation=%d close_other=%d close_all=%d document_reopen=%d untitled=%d untitled_dirty=%d save_as=%d save_as_collision=%d save_as_atomic=%d save_as_language=%d quick_open=%d quick_open_bounded=%d quick_open_activation=%d session_persist=%d session_restore=%d session_dirty_restore=%d recent_project=%d textmate_import=%d textmate_language=%d textmate_rendered=%d textmate_precedence=%d textmate_malformed_rejected=%d minimap_visible=%d sidebar_visible=%d\n",
            @as(c_int, @intFromBool(pass)),
            self.documents.items.len,
            language_id,
            @as(c_int, @intFromBool(language_ok)),
            @as(c_int, @intFromBool(tree_sitter_ok)),
            @as(c_int, @intFromBool(line_numbers_ok)),
            @as(c_int, @intFromBool(minimap_bound)),
            @as(c_int, @intFromBool(minimap_geometry)),
            @as(c_int, @intFromBool(editor_zoom_ok)),
            @as(c_int, @intFromBool(project_ok)),
            @as(c_int, @intFromBool(project_activation_ok)),
            @as(c_int, @intFromBool(project_tree_lazy_ok)),
            self.project_entry_count,
            @as(c_int, @intFromBool(self.project_truncated)),
            self.project_index.memoryBytes(),
            self.project_index.retainedCount(),
            self.project_monitors.items.len,
            self.project_monitor_events,
            self.project_delta_updates,
            self.project_delta_fallbacks,
            self.project_delta_added,
            self.project_delta_removed,
            @as(c_int, @intFromBool(self.external_clean_prompts > 0 and self.external_reloads > 0)),
            @as(c_int, @intFromBool(self.external_dirty_prompts > 0)),
            language_count,
            @as(c_int, @intFromBool(undo_ok)),
            @as(c_int, @intFromBool(redo_ok)),
            @as(c_int, @intFromBool(multi_selection_ok)),
            @as(c_int, @intFromBool(multi_selection_undo_ok)),
            @as(c_int, @intFromBool(multi_selection_rendered_ok)),
            @as(c_int, @intFromBool(save_ok)),
            @as(c_int, @intFromBool(search_ok)),
            @as(c_int, @intFromBool(fold_ok)),
            @as(c_int, @intFromBool(unfold_ok)),
            @as(c_int, @intFromBool(folded_save_ok)),
            @as(c_int, @intFromBool(folded_edit_restore_ok)),
            @as(c_int, @intFromBool(fold_undo_preserved_ok)),
            @as(c_int, @intFromBool(folding_config_ok)),
            folded_regions,
            @as(c_int, @intFromBool(find_in_files_ok)),
            @as(c_int, @intFromBool(search_snapshot_ok)),
            self.project_search_result_count,
            self.worker_peak_search_batches,
            WorkerJob.max_search_batches,
            @as(c_int, @intFromBool(project_search_activation_ok)),
            @as(c_int, @intFromBool(multi_file_tabs_ok)),
            @as(c_int, @intFromBool(tab_navigation_ok)),
            @as(c_int, @intFromBool(close_other_ok)),
            @as(c_int, @intFromBool(close_all_ok)),
            @as(c_int, @intFromBool(document_reopen_ok)),
            @as(c_int, @intFromBool(untitled_ok)),
            @as(c_int, @intFromBool(untitled_dirty_ok)),
            @as(c_int, @intFromBool(save_as_ok)),
            @as(c_int, @intFromBool(save_as_collision_ok)),
            @as(c_int, @intFromBool(save_as_atomic_ok)),
            @as(c_int, @intFromBool(save_as_language_ok)),
            @as(c_int, @intFromBool(quick_open_ok)),
            @as(c_int, @intFromBool(quick_open_bounded_ok)),
            @as(c_int, @intFromBool(quick_open_activation_ok)),
            @as(c_int, @intFromBool(session_persist_ok)),
            @as(c_int, @intFromBool(session_restore_ok)),
            @as(c_int, @intFromBool(session_dirty_restore_ok)),
            @as(c_int, @intFromBool(recent_project_ok)),
            @as(c_int, @intFromBool(textmate_import_ok)),
            @as(c_int, @intFromBool(textmate_language_ok)),
            @as(c_int, @intFromBool(textmate_rendered_ok)),
            @as(c_int, @intFromBool(textmate_precedence_ok)),
            @as(c_int, @intFromBool(textmate_malformed_rejected)),
            @as(c_int, @intFromBool(self.settings.minimap_visible)),
            @as(c_int, @intFromBool(self.settings.sidebar_visible)),
        );
        return pass;
    }
};

fn onWorkerComplete(job: *WorkerJob) void {
    const app: *App = @ptrCast(@alignCast(job.owner));
    app.completeWorkerJob(job);
}

fn onFilesystemSearchBatch(
    job: *WorkerJob,
    results: []const core.project_search.Result,
) void {
    const app: *App = @ptrCast(@alignCast(job.owner));
    app.publishProjectSearchBatch(job, results);
}

const SmokeDialogResponse = struct {
    dialog: *c.GtkWidget,
    response: c_int,
};

fn onSmokeDialogResponse(data: ?*anyopaque) callconv(.c) c.gboolean {
    const request: *SmokeDialogResponse = @ptrCast(@alignCast(data.?));
    c.gtk_dialog_response(@ptrCast(request.dialog), request.response);
    return c.G_SOURCE_REMOVE;
}

fn pathIsDirectory(io: std.Io, path: []const u8) bool {
    const directory = if (std.fs.path.isAbsolute(path))
        std.Io.Dir.openDirAbsolute(io, path, .{})
    else
        std.Io.Dir.cwd().openDir(io, path, .{});
    if (directory) |dir| {
        dir.close(io);
        return true;
    } else |_| return false;
}

fn isProjectFilePath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, core.project.extension);
}

fn openApplicationPath(app: *App, path: []const u8) void {
    if (isProjectFilePath(path)) {
        app.openProjectFile(path) catch |err| {
            app.showWorkerError("Project open failed", err);
        };
        return;
    }
    if (pathIsDirectory(app.io, path)) {
        app.updateStatus("Choose File > Create Project to save and open a .npr project");
        return;
    }
    app.openDocument(path) catch |err| {
        app.showWorkerError("Open failed", err);
    };
}

fn onApplicationActivate(
    _: *c.GApplication,
    data: ?*anyopaque,
) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.shutting_down) return;
    c.gtk_widget_show(app.window);
    c.gtk_window_present(asWindow(app.window));
    if (app.currentDocument()) |document| c.gtk_widget_grab_focus(document.view);
}

fn onApplicationOpen(
    _: *c.GApplication,
    files: [*]*c.GFile,
    file_count: c_int,
    hint: [*:0]const u8,
    data: ?*anyopaque,
) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.shutting_down or file_count <= 0) return;
    const project_hint = std.mem.span(hint);
    if (project_hint.len > 0) app.openProjectFile(project_hint) catch |err| {
        app.showWorkerError("Project open failed", err);
    };
    for (0..@intCast(file_count)) |index| {
        const path_z = c.g_file_get_path(files[index]) orelse continue;
        defer c.g_free(path_z);
        const path = std.mem.span(path_z);
        if (project_hint.len > 0 and std.mem.eql(u8, path, project_hint)) continue;
        if (project_hint.len > 0)
            app.openDocument(path) catch |err| app.showWorkerError("Open failed", err)
        else
            openApplicationPath(app, path);
    }
    _ = app.persistSessionReported();
}

fn appendApplicationFile(
    allocator: std.mem.Allocator,
    files: *std.array_list.Managed(*c.GFile),
    path: []const u8,
) !void {
    const path_z = try Compat.dupeZ(allocator, path);
    defer allocator.free(path_z);
    try files.append(c.g_file_new_for_path(path_z) orelse
        return error.ApplicationFileUnavailable);
}

// Reject misspelled options before registering or forwarding to an existing
// editor. Otherwise a command-line error can silently activate a live session.
fn validateApplicationArguments(args: []const []const u8) !void {
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--")) return;
        if (std.mem.eql(u8, arg, "--project") or std.mem.eql(u8, arg, "--open")) {
            index += 1;
            if (index >= args.len) return error.MissingApplicationPath;
        } else if (std.mem.eql(u8, arg, "--smoke") or
            std.mem.eql(u8, arg, "--startup-smoke") or
            std.mem.eql(u8, arg, "--session-restore-smoke") or
            std.mem.eql(u8, arg, "--project-lifecycle-smoke") or
            std.mem.eql(u8, arg, "--window-mode-smoke"))
        {
            if (!build_options.enable_smoke) return error.SmokeModeUnavailable;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("Unknown option: {s}\nRun 'nocted --help' for usage.\n", .{arg});
            return error.UnknownArgument;
        }
    }
}

fn forwardApplicationOpen(
    application: *c.GApplication,
    allocator: std.mem.Allocator,
    args: []const []const u8,
) !void {
    var files = std.array_list.Managed(*c.GFile).init(allocator);
    defer {
        for (files.items) |file| c.g_object_unref(@ptrCast(file));
        files.deinit();
    }
    var project: ?[]const u8 = null;
    var index: usize = 1;
    var literal_paths = false;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (literal_paths) {
            try appendApplicationFile(allocator, &files, arg);
        } else if (std.mem.eql(u8, arg, "--")) {
            literal_paths = true;
        } else if (std.mem.eql(u8, arg, "--project")) {
            index += 1;
            if (index >= args.len) return error.MissingApplicationPath;
            project = args[index];
        } else if (std.mem.eql(u8, arg, "--open")) {
            index += 1;
            if (index >= args.len) return error.MissingApplicationPath;
            try appendApplicationFile(allocator, &files, args[index]);
        } else if (!std.mem.startsWith(u8, arg, "--")) {
            try appendApplicationFile(allocator, &files, arg);
        }
    }
    if (project) |path| {
        if (files.items.len == 0) try appendApplicationFile(allocator, &files, path);
    }
    if (files.items.len == 0) {
        c.g_application_activate(application);
        return;
    }
    var hint_buffer: [std.fs.max_path_bytes:0]u8 = undefined;
    const hint = if (project) |path| blk: {
        const copied = Compat.bufPrintZ(&hint_buffer, "{s}", .{path}) catch
            return error.ApplicationPathTooLong;
        break :blk copied.ptr;
    } else "";
    c.g_application_open(application, files.items.ptr, @intCast(files.items.len), hint);
}

fn applicationConfigDirectoryAlloc(
    allocator: std.mem.Allocator,
    home: []const u8,
    config_home: ?[]const u8,
) ![]u8 {
    return if (config_home) |root|
        std.fs.path.join(allocator, &.{ root, "nocted" })
    else
        std.fs.path.join(allocator, &.{ home, ".config/nocted" });
}

fn shouldUseSingleInstance(env: *const std.process.Environ.Map) bool {
    return !std.mem.eql(
        u8,
        env.get("NOCTED_DISABLE_SINGLE_INSTANCE") orelse "0",
        "1",
    );
}

fn applicationIdForDirectory(directory: []const u8, buffer: *[64:0]u8) [*:0]const u8 {
    var hash: u64 = 14695981039346656037;
    for (directory) |byte| {
        hash ^= byte;
        hash *%= 1099511628211;
    }
    const formatted = Compat.bufPrintZ(
        buffer,
        "com.dintty.NoctEd.n{x}",
        .{hash},
    ) catch unreachable;
    return formatted.ptr;
}

fn registerApplication(
    allocator: std.mem.Allocator,
    init: std.process.Init,
    args: []const []const u8,
    home: []const u8,
    config_home: ?[]const u8,
) !InstanceRegistration {
    if (!shouldUseSingleInstance(init.environ_map)) return .{};
    const directory = try applicationConfigDirectoryAlloc(allocator, home, config_home);
    defer allocator.free(directory);
    var application_id: [64:0]u8 = undefined;
    const application = c.g_application_new(
        applicationIdForDirectory(directory, &application_id),
        c.G_APPLICATION_HANDLES_OPEN,
    ) orelse return error.ApplicationUnavailable;
    var error_ptr: ?*c.GError = null;
    if (c.g_application_register(application, null, &error_ptr) != 0) {
        if (c.g_application_get_is_remote(application) != 0) {
            defer c.g_object_unref(@ptrCast(application));
            try forwardApplicationOpen(application, allocator, args);
            return error.ApplicationForwarded;
        }
    } else if (error_ptr) |err| {
        c.g_error_free(err);
    }
    const lock = InstanceLock.acquire(allocator, init.io, directory) catch |err| {
        c.g_object_unref(@ptrCast(application));
        return err;
    };
    return .{
        .application = application,
        .lock = lock,
    };
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1 and (std.mem.eql(u8, args[1], "--version") or
        std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")))
    {
        var buffer: [2048]u8 = undefined;
        var writer: std.Io.File.Writer = .init(.stdout(), init.io, &buffer);
        if (std.mem.eql(u8, args[1], "--version")) {
            try writer.interface.print("nocted {s}\n", .{version});
        } else {
            try writer.interface.writeAll(
                \\Usage: nocted [OPTIONS] [FILE ...]
                \\
                \\  -h, --help         Show this help without opening a window
                \\  --version          Print the version
                \\  --open FILE        Open a file (repeatable)
                \\  --project FILE.npr Open a saved NoctEd project
                \\  --                 Treat remaining arguments as file paths
                \\
                \\With no files, restore the previous session or open an untitled
                \\buffer. File paths are forwarded to the running editor.
                \\Use the File menu to create a project or save your work.
                \\
            );
        }
        try writer.interface.flush();
        return;
    }
    if (args.len > 3 and std.mem.eql(u8, args[1], "--task-probe")) {
        const action: core.task.Action = if (std.mem.eql(u8, args[3], "check"))
            .check
        else if (std.mem.eql(u8, args[3], "build"))
            .build
        else if (std.mem.eql(u8, args[3], "test"))
            .test_project
        else if (std.mem.eql(u8, args[3], "run"))
            .run
        else
            return error.InvalidTaskAction;
        const plan = core.task.detect(init.io, args[2], action) orelse
            return error.ProjectTaskUnavailable;
        const result = try core.task.runControlledAlloc(
            allocator,
            init.io,
            args[2],
            plan,
            .{ .environ_map = init.environ_map },
        );
        defer allocator.free(result.output);
        var buffer: [4096]u8 = undefined;
        var writer: std.Io.File.Writer = .init(.stdout(), init.io, &buffer);
        try writer.interface.print(
            "nocted_task_probe project={s} action={s} success={} output={s}\n",
            .{ plan.name, args[3], result.success, result.output },
        );
        try writer.interface.flush();
        if (!result.success) return error.ProjectTaskFailed;
        return;
    }
    if (args.len > 2 and std.mem.eql(u8, args[1], "--lsp-probe")) {
        var loaded = try core.document.loadFileAlloc(allocator, init.io, args[2]);
        defer loaded.deinit(allocator);
        const cwd = std.fs.path.dirname(loaded.path) orelse ".";
        const server = core.lsp.serverForPathInRoot(init.io, loaded.path, cwd) orelse
            return error.LanguageServerUnavailable;
        const uri = try core.lsp.fileUriAlloc(allocator, loaded.path);
        defer allocator.free(uri);
        const root_uri = try core.lsp.fileUriAlloc(allocator, cwd);
        defer allocator.free(root_uri);
        const response = try core.lsp.runFeatureAlloc(
            allocator,
            init.io,
            server,
            cwd,
            root_uri,
            uri,
            loaded.contents,
            0,
            0,
            .symbols,
            null,
        );
        defer allocator.free(response);
        const summary = try core.lsp.summaryAlloc(allocator, response);
        defer allocator.free(summary);
        var buffer: [4096]u8 = undefined;
        var writer: std.Io.File.Writer = .init(.stdout(), init.io, &buffer);
        try writer.interface.print(
            "nocted_lsp_probe server={s} language={s} response={s}\n",
            .{ server.argv[0], server.language_id, summary },
        );
        try writer.interface.flush();
        return;
    }
    if (args.len > 1 and std.mem.eql(u8, args[1], "--runtime-contract")) {
        var document = try tree_sitter.Document.init(.zig);
        defer document.deinit(allocator);
        try document.update("const runtime_contract = true;\n");
        const captures = try document.captures(allocator);
        if (captures.len == 0) return error.TreeSitterContractFailed;
        const overflow_line = "const value: usize = 1;\n";
        var overflow_source: [overflow_line.len * 2000]u8 = undefined;
        for (0..2000) |line_index| {
            const start = line_index * overflow_line.len;
            @memcpy(overflow_source[start..][0..overflow_line.len], overflow_line);
        }
        try document.update(&overflow_source);
        if (document.captures(allocator)) |_| {
            return error.TreeSitterCaptureLimitMissing;
        } else |err| if (err != error.TreeSitterCaptureLimitExceeded) return err;
        var buffer: [192]u8 = undefined;
        var writer: std.Io.File.Writer = .init(.stdout(), init.io, &buffer);
        try writer.interface.print(
            "nocted_runtime_contract tree_sitter=true captures={d} " ++
                "capture_limit={d} direct_limit_bytes={d}\n",
            .{
                captures.len,
                tree_sitter.max_captures,
                core.document.direct_tree_sitter_byte_limit,
            },
        );
        try writer.interface.flush();
        return;
    }
    try validateApplicationArguments(args);
    if (c.gtk_init_check(null, null) == 0) return error.GtkUnavailable;
    const home = init.environ_map.get("HOME") orelse ".";
    var registration = registerApplication(
        allocator,
        init,
        args,
        home,
        init.environ_map.get("XDG_CONFIG_HOME"),
    ) catch |err| switch (err) {
        error.ApplicationForwarded => return,
        else => return err,
    };
    defer if (registration.lock) |*lock| lock.deinit();
    defer if (registration.application) |application|
        c.g_object_unref(@ptrCast(application));
    var app = try App.init(
        allocator,
        init.io,
        init.environ_map,
        home,
        init.environ_map.get("XDG_CONFIG_HOME"),
    );
    defer app.deinit();
    if (build_options.enable_smoke and
        std.mem.eql(
            u8,
            init.environ_map.get("NOCTED_QUALIFICATION_SMOKE") orelse "0",
            "1",
        ))
        app.resource_smoke = true;
    try app.buildUi();
    if (registration.application) |application| {
        connect(application, "open", @ptrCast(&onApplicationOpen), &app);
        connect(application, "activate", @ptrCast(&onApplicationActivate), &app);
    }

    var project: ?[]const u8 = null;
    var files = std.array_list.Managed([]const u8).init(allocator);
    defer files.deinit();
    var index: usize = 1;
    var literal_paths = false;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (literal_paths) {
            try files.append(arg);
        } else if (std.mem.eql(u8, arg, "--")) {
            literal_paths = true;
        } else if (std.mem.eql(u8, arg, "--smoke")) {
            if (!build_options.enable_smoke) return error.SmokeModeUnavailable;
            app.smoke = true;
        } else if (std.mem.eql(u8, arg, "--startup-smoke")) {
            if (!build_options.enable_smoke) return error.SmokeModeUnavailable;
            app.startup_smoke = true;
        } else if (std.mem.eql(u8, arg, "--window-mode-smoke")) {
            if (!build_options.enable_smoke) return error.SmokeModeUnavailable;
            app.window_mode_smoke = true;
        } else if (std.mem.eql(u8, arg, "--session-restore-smoke")) {
            if (!build_options.enable_smoke) return error.SmokeModeUnavailable;
            app.session_restore_smoke = true;
        } else if (std.mem.eql(u8, arg, "--project-lifecycle-smoke")) {
            if (!build_options.enable_smoke) return error.SmokeModeUnavailable;
            app.project_lifecycle_smoke = true;
        } else if (std.mem.eql(u8, arg, "--project")) {
            index += 1;
            if (index >= args.len) return error.MissingProjectPath;
            project = args[index];
        } else if (std.mem.eql(u8, arg, "--open")) {
            index += 1;
            if (index >= args.len) return error.MissingDocumentPath;
            try files.append(args[index]);
        } else if (!std.mem.startsWith(u8, arg, "--")) {
            try files.append(arg);
        }
    }
    const restore_requested = !app.smoke and !app.startup_smoke and
        !app.project_lifecycle_smoke and !app.window_mode_smoke;
    _ = restore_requested and app.restoreSession();
    if (project) |project_path| {
        app.openProjectFile(project_path) catch |err| {
            const status = try std.fmt.allocPrintSentinel(
                allocator,
                "Project open failed: {s}",
                .{@errorName(err)},
                0,
            );
            defer allocator.free(status);
            app.updateStatus(status.ptr);
        };
    }
    for (files.items) |path| {
        if (isProjectFilePath(path)) {
            app.openProjectFile(path) catch |err| {
                app.showWorkerError("Project open failed", err);
            };
            continue;
        }
        app.openDocument(path) catch |err| {
            const status = try std.fmt.allocPrintSentinel(
                allocator,
                "Open failed: {s}",
                .{@errorName(err)},
                0,
            );
            defer allocator.free(status);
            app.updateStatus(status.ptr);
        };
    }
    if (files.items.len == 0 and
        !app.hasWorkerJob(.document_load) and
        c.gtk_notebook_get_n_pages(asNotebook(app.notebook)) == 0)
        app.newDocument() catch |err| app.showWorkerError("New file unavailable", err);
    app.promptLegacySyntax();
    if (build_options.enable_smoke and app.startup_smoke) {
        if (c.g_idle_add(onStartupSmoke, &app) == 0)
            return error.StartupSmokeSourceUnavailable;
    } else if (build_options.enable_smoke and app.window_mode_smoke) {
        if (c.g_idle_add(onWindowModeSmoke, &app) == 0)
            return error.WindowModeSmokeSourceUnavailable;
    } else if (build_options.enable_smoke and app.session_restore_smoke) {
        if (c.g_idle_add(onSessionRestoreSmoke, &app) == 0)
            return error.SessionRestoreSmokeSourceUnavailable;
    } else if (build_options.enable_smoke and app.project_lifecycle_smoke) {
        app.project_lifecycle_mutate = std.mem.eql(
            u8,
            init.environ_map.get("NOCTED_LIFECYCLE_MUTATE") orelse "0",
            "1",
        );
        if (c.g_timeout_add(180, onProjectLifecycleSmoke, &app) == 0)
            return error.ProjectLifecycleSmokeSourceUnavailable;
    } else if (build_options.enable_smoke and app.smoke) {
        if (files.items.len == 0) return error.SmokeDocumentRequired;
        app.smoke_save_as_path = init.environ_map.get("NOCTED_SMOKE_SAVE_AS") orelse
            return error.SmokeSaveAsPathRequired;
        app.smoke_textmate_grammar_path = init.environ_map.get(
            "NOCTED_SMOKE_TEXTMATE_GRAMMAR",
        );
        app.smoke_textmate_document_path = init.environ_map.get(
            "NOCTED_SMOKE_TEXTMATE_DOCUMENT",
        );
        if (init.environ_map.get("NOCTED_PROJECT_LIFECYCLE_ROOT")) |root| {
            if (root.len != 0) app.smoke_lifecycle_root = root;
        }
        if (init.environ_map.get("NOCTED_SEARCH_LOAD_ROOT")) |root| {
            if (root.len != 0) app.smoke_search_load_root = root;
        }
        if (init.environ_map.get("NOCTED_SMOKE_PREVIEW")) |preview| {
            app.smoke_preview = if (std.mem.eql(u8, preview, "fold"))
                .fold
            else if (std.mem.eql(u8, preview, "search"))
                .search
            else if (std.mem.eql(u8, preview, "quick-open"))
                .quick_open
            else
                .none;
        }
        app.smoke_screenshot_path = init.environ_map.get("NOCTED_SMOKE_SCREENSHOT");
        _ = c.g_timeout_add(180, onSmoke, &app);
    }
    c.gtk_main();
    if (build_options.enable_smoke and app.smoke and
        !app.project_lifecycle_smoke and !app.smoke_passed)
        return error.NoctEdNativeSmokeFailed;
    if (build_options.enable_smoke and app.project_lifecycle_smoke and
        !app.project_lifecycle_passed)
        return error.NoctEdProjectLifecycleSmokeFailed;
}

fn elapsedNanoseconds(started: std.Io.Timestamp, io: std.Io) u64 {
    const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return @intCast(@max(elapsed, 0));
}

fn summarizeLatencies(values: []u64) LatencySummary {
    std.mem.sort(u64, values, {}, std.sort.asc(u64));
    return .{
        .p50_ns = latencyPercentile(values, 50),
        .p95_ns = latencyPercentile(values, 95),
        .p99_ns = latencyPercentile(values, 99),
    };
}

fn latencyPercentile(values: []const u64, percent: usize) u64 {
    const rank = (values.len * percent + 99) / 100;
    return values[@max(rank, 1) - 1];
}

fn locateResourceRoot(allocator: std.mem.Allocator, io: std.Io) ![]u8 {
    const exe_dir = try std.process.executableDirPathAlloc(io, allocator);
    defer allocator.free(exe_dir);
    const candidates = [_][]const []const u8{
        &.{ exe_dir, "../share/nocted" },
        &.{ exe_dir, "../../share/nocted" },
        &.{"resources/nocted"},
    };
    for (candidates) |parts| {
        const candidate = try std.fs.path.resolve(allocator, parts);
        const opened = if (std.fs.path.isAbsolute(candidate))
            std.Io.Dir.openDirAbsolute(io, candidate, .{})
        else
            std.Io.Dir.cwd().openDir(io, candidate, .{});
        if (opened) |directory| {
            directory.close(io);
            return candidate;
        } else |_| {
            allocator.free(candidate);
        }
    }
    return error.NoctEdResourcesUnavailable;
}

fn installCss() void {
    const css =
        \\#nocted-window { background: #0b0d12; color: #d7dde8; }
        \\#nocted-menu { background: #11151d; color: #d7dde8; padding: 1px 4px; }
        \\#nocted-menu menuitem { padding: 3px 8px; }
        \\#nocted-topbar { background: #11151d; border-bottom: 1px solid #222a38; }
        \\#nocted-main { background: #0b0d12; }
        \\#nocted-sidebar { background: #11151d; border-right: 1px solid #222a38; }
        \\#nocted-sidebar-header { border-bottom: 1px solid #222a38; min-height: 32px; }
        \\#nocted-sidebar-title { color: #7f8a9c; font-size: 0.9em; font-weight: bold; padding: 7px 9px 5px; }
        \\#nocted-chrome-button { min-width: 28px; min-height: 28px; padding: 0; border: 0; border-radius: 5px; background: transparent; color: #aeb7c6; }
        \\#nocted-chrome-button:hover { background: #242c3a; color: #ffffff; }
        \\#nocted-chrome-button:active { background: #263249; }
        \\#nocted-chrome-button:focus { outline: 2px solid #8fb8ff; outline-offset: -2px; }
        \\#nocted-chrome-button:disabled { color: #4f5969; }
        \\#nocted-about-title { color: #202631; font-size: 1.25em; font-weight: bold; }
        \\#nocted-about-close { min-width: 88px; min-height: 36px; padding: 4px 14px; border: 1px solid #5676a8; border-radius: 5px; background: #263249; color: #ffffff; }
        \\#nocted-about-close:hover { background: #334369; border-color: #8fb8ff; }
        \\#nocted-about-close:active { background: #1d2840; }
        \\#nocted-about-close:focus { outline: 2px solid #8fb8ff; outline-offset: -3px; }
        \\#nocted-project-tree { background: #11151d; color: #c3cad6; }
        \\#nocted-project-tree:selected { background: #263249; color: #ffffff; }
        \\#nocted-project-tree:focus { outline: 2px solid #8fb8ff; outline-offset: -2px; }
        \\#nocted-tabs header { background: #11151d; border: 0; padding: 0 5px; }
        \\#nocted-tabs tab { background: #1a202b; color: #aeb7c6; border: 0; border-radius: 7px 7px 0 0; margin: 0 4px 0 0; padding: 0 9px 1px; font-size: 0.9em; }
        \\#nocted-tabs tab:hover { background: #242c3a; color: #ffffff; }
        \\#nocted-tabs tab:checked { background: #0b0d12; color: #e5e9f0; box-shadow: inset 0 2px #8fb8ff; }
        \\#nocted-tabs tab:focus { outline: 2px solid #8fb8ff; outline-offset: -2px; }
        \\#nocted-tab-close { min-width: 28px; min-height: 18px; padding: 0; border: 0; border-radius: 7px; background: transparent; }
        \\#nocted-tab-close:hover { background: #242c3a; color: #ffffff; }
        \\#nocted-tab-close:active { background: #263249; }
        \\#nocted-tab-close:focus { outline: 2px solid #8fb8ff; outline-offset: -2px; }
        \\#nocted-search { background: #11151d; border-top: 1px solid #222a38; padding: 5px; }
        \\#nocted-project-search { background: #11151d; border-top: 1px solid #222a38; }
        \\#nocted-project-search > box { padding: 5px; }
        \\#nocted-project-search-results { background: #0b0d12; color: #c3cad6; }
        \\#nocted-project-search-results:selected { background: #263249; color: #ffffff; }
        \\#nocted-project-search-results:focus { outline: 2px solid #8fb8ff; outline-offset: -2px; }
        \\#nocted-quick-open { background: #11151d; border-top: 1px solid #222a38; }
        \\#nocted-quick-open > box { padding: 5px; }
        \\#nocted-quick-open-results { background: #0b0d12; color: #c3cad6; }
        \\#nocted-quick-open-results:selected { background: #263249; color: #ffffff; }
        \\#nocted-quick-open-results:focus { outline: 2px solid #8fb8ff; outline-offset: -2px; }
        \\#nocted-status { background: #151923; color: #c3cad6; border-top: 1px solid #222a38; min-height: 22px; }
        \\#nocted-minimap { background: #11151d; border-left: 1px solid #222a38; }
        \\#nocted-minimap.scrubber { background-color: rgba(143, 184, 255, 0.18); }
        \\#nocted-editor { font-family: monospace; }
    ;
    const provider = c.gtk_css_provider_new() orelse return;
    var error_ptr: ?*c.GError = null;
    _ = c.gtk_css_provider_load_from_data(
        provider,
        css.ptr,
        @intCast(css.len),
        &error_ptr,
    );
    if (error_ptr) |err| c.g_error_free(err);
    if (c.gdk_screen_get_default()) |screen|
        c.gtk_style_context_add_provider_for_screen(
            screen,
            @ptrCast(provider),
            c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    c.g_object_unref(@ptrCast(provider));
}

fn createProjectTreeStore() !*c.GtkTreeStore {
    const column_types = [_]c.GType{
        c.G_TYPE_STRING,
        c.G_TYPE_UINT64,
        c.G_TYPE_BOOLEAN,
        c.G_TYPE_STRING,
    };
    return c.gtk_tree_store_newv(
        @intCast(column_types.len),
        @constCast(&column_types),
    ) orelse error.ProjectTreeCreationFailed;
}

fn connect(instance: anytype, signal: [*:0]const u8, callback: c.GCallback, data: anytype) void {
    _ = c.g_signal_connect_data(
        @ptrCast(instance),
        signal,
        callback,
        @ptrCast(data),
        null,
        0,
    );
}

fn appendMenuRoot(bar: *c.GtkWidget, label: [*:0]const u8, menu: *c.GtkWidget) void {
    const root = c.gtk_menu_item_new_with_label(label) orelse unreachable;
    c.gtk_menu_item_set_submenu(@ptrCast(root), menu);
    c.gtk_menu_shell_append(@ptrCast(bar), root);
}

fn appendMenuAction(menu: *c.GtkWidget, label: [*:0]const u8, callback: anytype, app: *App) void {
    const item = c.gtk_menu_item_new_with_label(label) orelse unreachable;
    connect(item, "activate", @ptrCast(callback), app);
    c.gtk_menu_shell_append(@ptrCast(menu), item);
}

const ToolAction = enum(usize) {
    diagnostics,
    completion,
    hover,
    definition,
    references,
    rename,
    symbols,
    formatting,
    check,
    build,
    test_project,
    run,
};

fn appendToolAction(menu: *c.GtkWidget, label: [*:0]const u8, action: ToolAction, app: *App) void {
    const item = c.gtk_menu_item_new_with_label(label) orelse unreachable;
    c.g_object_set_data(item, "nocted-tool-action", @ptrFromInt(@backingInt(action) + 1));
    connect(item, "activate", @ptrCast(&onToolAction), app);
    c.gtk_menu_shell_append(@ptrCast(menu), item);
}

fn appendCheckMenuAction(
    menu: *c.GtkWidget,
    label: [*:0]const u8,
    active: bool,
    callback: anytype,
    app: *App,
) *c.GtkWidget {
    const item = c.gtk_check_menu_item_new_with_label(label) orelse unreachable;
    c.gtk_check_menu_item_set_active(@ptrCast(item), @intFromBool(active));
    connect(item, "toggled", @ptrCast(callback), app);
    c.gtk_menu_shell_append(@ptrCast(menu), item);
    return item;
}

fn appendMenuSeparator(menu: *c.GtkWidget) void {
    c.gtk_menu_shell_append(
        @ptrCast(menu),
        c.gtk_separator_menu_item_new() orelse unreachable,
    );
}

fn iconButton(icon: [*:0]const u8, tooltip: [*:0]const u8) *c.GtkWidget {
    const button = c.gtk_button_new_from_icon_name(icon, c.GTK_ICON_SIZE_MENU) orelse unreachable;
    c.gtk_button_set_relief(@ptrCast(button), c.GTK_RELIEF_NONE);
    c.gtk_widget_set_size_request(button, 28, 28);
    c.gtk_widget_set_tooltip_text(button, tooltip);
    setAccessibleName(button, tooltip);
    return button;
}

fn setAccessibleName(widget: *c.GtkWidget, name: [*:0]const u8) void {
    c.atk_object_set_name(c.gtk_widget_get_accessible(widget), name);
}

fn setStatusFeedback(
    widget: *c.GtkWidget,
    message: [*:0]const u8,
    is_error: bool,
) void {
    const accessible = c.gtk_widget_get_accessible(widget);
    const target_role = if (is_error) c.ATK_ROLE_ALERT else c.ATK_ROLE_STATUSBAR;
    const text_changed = !std.mem.eql(
        u8,
        std.mem.span(c.gtk_label_get_text(asLabel(widget))),
        std.mem.span(message),
    );
    const role_changed = c.atk_object_get_role(accessible) != target_role;
    const current_description = c.atk_object_get_description(accessible);
    const description_changed = current_description == null or !std.mem.eql(
        u8,
        std.mem.span(current_description.?),
        std.mem.span(message),
    );
    if (text_changed) c.gtk_label_set_text(asLabel(widget), message);
    if (role_changed) c.atk_object_set_role(accessible, target_role);
    if (description_changed) c.atk_object_set_description(accessible, message);
    if (text_changed or role_changed or description_changed)
        c.g_signal_emit_by_name(accessible, "visible-data-changed");
}

fn treeStoreSet(
    allocator: std.mem.Allocator,
    store: *c.GtkTreeStore,
    iter: *c.GtkTreeIter,
    name: []const u8,
    entry_index: u64,
    is_directory: bool,
) !void {
    const name_z = try Compat.dupeZ(allocator, name);
    defer allocator.free(name_z);
    const icon = if (is_directory) "folder-symbolic" else "text-x-generic-symbolic";
    c.gtk_tree_store_set(
        store,
        iter,
        @as(c_int, 0),
        name_z.ptr,
        @as(c_int, 1),
        entry_index,
        @as(c_int, 2),
        @as(c_int, @intFromBool(is_directory)),
        @as(c_int, 3),
        icon.ptr,
        @as(c_int, -1),
    );
}

fn quickOpenStoreSet(
    allocator: std.mem.Allocator,
    store: *c.GtkTreeStore,
    iter: *c.GtkTreeIter,
    relative_path: []const u8,
    entry_index: usize,
) !void {
    const relative_z = try Compat.dupeZ(allocator, relative_path);
    defer allocator.free(relative_z);
    c.gtk_tree_store_set(
        store,
        iter,
        @as(c_int, 0),
        relative_z.ptr,
        @as(c_int, 1),
        @as(u64, @intCast(entry_index)),
        @as(c_int, -1),
    );
}

fn pathIsWithin(root: []const u8, path: []const u8) bool {
    if (!std.mem.startsWith(u8, path, root)) return false;
    if (path.len == root.len) return true;
    return root.len > 0 and root[root.len - 1] == std.fs.path.sep or
        path[root.len] == std.fs.path.sep;
}

fn projectRelativePath(root: []const u8, path: []const u8) ?[]const u8 {
    if (!pathIsWithin(root, path) or path.len == root.len) return null;
    var start = root.len;
    if (root.len == 0 or root[root.len - 1] != std.fs.path.sep) start += 1;
    if (start >= path.len) return null;
    return path[start..];
}

fn searchStoreSet(
    allocator: std.mem.Allocator,
    store: *c.GtkTreeStore,
    iter: *c.GtkTreeIter,
    result: core.project_search.Result,
) !void {
    const display = try std.fmt.allocPrintSentinel(
        allocator,
        "{s}:{d}:{d}  {s}",
        .{ result.relative_path, result.line, result.column, result.preview },
        0,
    );
    defer allocator.free(display);
    c.gtk_tree_store_set(
        store,
        iter,
        @as(c_int, 0),
        display.ptr,
        @as(c_int, 1),
        @as(u64, @intCast(result.entry_index)),
        @as(c_int, 2),
        @as(u64, result.line),
        @as(c_int, -1),
    );
}

fn treeValueStringAlloc(
    allocator: std.mem.Allocator,
    model: *c.GtkTreeModel,
    iter: *c.GtkTreeIter,
    column: c_int,
) !?[]u8 {
    var value: c.GValue = std.mem.zeroes(c.GValue);
    c.gtk_tree_model_get_value(model, iter, column, &value);
    defer c.g_value_unset(&value);
    const raw = c.g_value_get_string(&value) orelse return null;
    return try allocator.dupe(u8, std.mem.span(raw));
}

fn treeValueBool(model: *c.GtkTreeModel, iter: *c.GtkTreeIter, column: c_int) bool {
    var value: c.GValue = std.mem.zeroes(c.GValue);
    c.gtk_tree_model_get_value(model, iter, column, &value);
    defer c.g_value_unset(&value);
    return c.g_value_get_boolean(&value) != 0;
}

fn treeValueUInt64(model: *c.GtkTreeModel, iter: *c.GtkTreeIter, column: c_int) u64 {
    var value: c.GValue = std.mem.zeroes(c.GValue);
    c.gtk_tree_model_get_value(model, iter, column, &value);
    defer c.g_value_unset(&value);
    return c.g_value_get_uint64(&value);
}

fn onWindowDestroy(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.window_destroyed = true;
    if (!app.shutting_down) app.persistSession() catch |err| {
        log.err("session save failed during window teardown: {s}", .{@errorName(err)});
    };
    app.shutting_down = true;
    app.status_widgets_ready = false;
    if (c.gtk_main_level() > 0) c.gtk_main_quit();
}

fn onWindowDelete(_: ?*c.GtkWidget, _: ?*c.GdkEvent, data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    return @intFromBool(!app.prepareHotExit());
}

fn onWindowKeyPress(_: ?*c.GtkWidget, event: ?*c.GdkEventKey, data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    const key = event orelse return 0;
    const modifiers = key.state & c.gtk_accelerator_get_default_mod_mask();
    const lowered = c.gdk_keyval_to_lower(key.keyval);
    if (key.keyval == c.GDK_KEY_Escape) {
        if (c.gtk_widget_get_visible(app.quick_open_box) != 0) {
            app.hideQuickOpen();
            return 1;
        }
        if (c.gtk_widget_get_visible(app.project_search_box) != 0) {
            app.hideProjectFind();
            return 1;
        }
        if (c.gtk_widget_get_visible(app.search_box) != 0) {
            app.hideFind();
            return 1;
        }
        if (app.currentDocument()) |document| {
            if (document.secondary_selections.items.len > 0) {
                document.clearMultiSelections();
                app.updateStatus("Secondary selections cleared");
                return 1;
            }
        }
        if (app.window_mode == .zen_fullscreen) {
            app.setWindowMode(.windowed);
            return 1;
        }
    }
    if (key.keyval == c.GDK_KEY_F3) {
        app.find((modifiers & c.GDK_SHIFT_MASK) == 0);
        return 1;
    }
    if (key.keyval == c.GDK_KEY_F11) {
        app.setWindowMode(if (app.window_mode == .zen_fullscreen) .windowed else .zen_fullscreen);
        return 1;
    }
    if ((modifiers == c.GDK_CONTROL_MASK or
        modifiers == (c.GDK_CONTROL_MASK | c.GDK_SHIFT_MASK)) and
        (key.keyval == c.GDK_KEY_plus or key.keyval == c.GDK_KEY_equal or
            key.keyval == c.GDK_KEY_KP_Add))
    {
        app.adjustEditorZoom(editor_zoom_percent_step) catch
            app.updateStatusError("Editor zoom could not be increased");
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and
        (key.keyval == c.GDK_KEY_minus or key.keyval == c.GDK_KEY_KP_Subtract))
    {
        app.adjustEditorZoom(-editor_zoom_percent_step) catch
            app.updateStatusError("Editor zoom could not be decreased");
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and
        (key.keyval == c.GDK_KEY_0 or key.keyval == c.GDK_KEY_KP_0))
    {
        app.setEditorZoom(editor_zoom_percent_default) catch
            app.updateStatusError("Editor zoom could not be reset");
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and lowered == c.GDK_KEY_s) {
        if (app.currentDocument()) |document| _ = app.saveDocument(document);
        return 1;
    }
    if (modifiers == (c.GDK_CONTROL_MASK | c.GDK_SHIFT_MASK) and
        lowered == c.GDK_KEY_s)
    {
        if (app.currentDocument()) |document| _ = app.promptSaveAs(document);
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and lowered == c.GDK_KEY_n) {
        app.newDocument() catch |err| {
            const status = std.fmt.allocPrintSentinel(
                app.allocator,
                "New file failed: {s}",
                .{@errorName(err)},
                0,
            ) catch return 1;
            defer app.allocator.free(status);
            app.updateStatus(status.ptr);
        };
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and lowered == c.GDK_KEY_o) {
        onOpenFile(null, data);
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and lowered == c.GDK_KEY_p) {
        app.showQuickOpen();
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and lowered == c.GDK_KEY_f) {
        app.showFind();
        return 1;
    }
    if (modifiers == (c.GDK_CONTROL_MASK | c.GDK_SHIFT_MASK) and
        lowered == c.GDK_KEY_f)
    {
        app.showProjectFind();
        return 1;
    }
    if (modifiers == (c.GDK_CONTROL_MASK | c.GDK_SHIFT_MASK) and
        lowered == c.GDK_KEY_l)
    {
        app.selectAllOccurrences();
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and lowered == c.GDK_KEY_w) {
        if (app.currentDocument()) |document| _ = app.closeDocument(document);
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and key.keyval == c.GDK_KEY_Page_Up) {
        _ = app.cycleDocument(-1);
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and key.keyval == c.GDK_KEY_Page_Down) {
        _ = app.cycleDocument(1);
        return 1;
    }
    if (modifiers == c.GDK_CONTROL_MASK and lowered == c.GDK_KEY_b) {
        app.toggleSidebar();
        return 1;
    }
    if (modifiers == (c.GDK_CONTROL_MASK | c.GDK_SHIFT_MASK) and
        (key.keyval == c.GDK_KEY_bracketleft or
            key.keyval == c.GDK_KEY_braceleft))
    {
        app.foldCurrent();
        return 1;
    }
    if (modifiers == (c.GDK_CONTROL_MASK | c.GDK_SHIFT_MASK) and
        (key.keyval == c.GDK_KEY_bracketright or
            key.keyval == c.GDK_KEY_braceright))
    {
        app.unfoldCurrent();
        return 1;
    }
    return 0;
}

fn onNotebookSwitch(_: ?*c.GtkNotebook, page: ?*c.GtkWidget, _: c.guint, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.shutting_down) return;
    app.active_document = if (page) |widget|
        if (c.g_object_get_data(@ptrCast(widget), document_page_key)) |raw|
            @ptrCast(@alignCast(raw))
        else
            null
    else
        null;
    if (app.active_document) |document| app.updateDocumentStatus(document);
    if (c.gtk_widget_get_visible(app.search_box) != 0) app.updateSearch();
    app.scheduleSessionPersist();
}

fn onNotebookPageReordered(_: ?*c.GtkNotebook, _: ?*c.GtkWidget, _: c.guint, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.scheduleSessionPersist();
}

fn onBufferModified(_: ?*c.GtkTextBuffer, data: ?*anyopaque) callconv(.c) void {
    const document: *Document = @ptrCast(@alignCast(data.?));
    if (document.loading) return;
    document.app.updateTabLabel(document);
    document.app.updateStatus(
        if (c.gtk_text_buffer_get_modified(@ptrCast(document.buffer)) != 0)
            "Modified"
        else
            "Ready",
    );
}

fn onProjectMonitorChanged(
    _: ?*c.GFileMonitor,
    file: ?*c.GFile,
    other_file: ?*c.GFile,
    event_type: c_int,
    data: ?*anyopaque,
) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.shutting_down) {
        app.project_monitor_late_callbacks +|= 1;
        return;
    }
    const content_only = switch (event_type) {
        c.G_FILE_MONITOR_EVENT_CHANGED,
        c.G_FILE_MONITOR_EVENT_CHANGES_DONE_HINT,
        c.G_FILE_MONITOR_EVENT_ATTRIBUTE_CHANGED,
        => true,
        else => false,
    };
    if (content_only) {
        var requires_rescan = false;
        if (file) |changed_file| {
            if (c.g_file_get_path(changed_file)) |path_z| {
                defer c.g_free(path_z);
                const basename = std.fs.path.basename(std.mem.span(path_z));
                requires_rescan = std.mem.eql(u8, basename, ".gitignore") or
                    std.mem.eql(u8, basename, ".ignore");
            }
        }
        app.scheduleProjectMonitorFlush(requires_rescan);
        return;
    }

    const root = app.project_root orelse {
        app.scheduleProjectMonitorFlush(true);
        return;
    };
    const path = monitorRelativePathAlloc(app, root, file) catch {
        app.scheduleProjectMonitorFlush(true);
        return;
    } orelse {
        app.scheduleProjectMonitorFlush(true);
        return;
    };
    defer app.allocator.free(path);
    const other_path = monitorRelativePathAlloc(app, root, other_file) catch {
        app.scheduleProjectMonitorFlush(true);
        return;
    };
    defer if (other_path) |other| app.allocator.free(other);
    if (isProjectIgnoreControl(path) or
        (other_path != null and isProjectIgnoreControl(other_path.?)))
    {
        app.scheduleProjectMonitorFlush(true);
        return;
    }
    const kind: core.project_index.FilesystemChangeKind = switch (event_type) {
        c.G_FILE_MONITOR_EVENT_CREATED => .created,
        c.G_FILE_MONITOR_EVENT_DELETED => .deleted,
        c.G_FILE_MONITOR_EVENT_RENAMED,
        c.G_FILE_MONITOR_EVENT_MOVED,
        => if (other_path != null) .renamed else {
            app.scheduleProjectMonitorFlush(true);
            return;
        },
        c.G_FILE_MONITOR_EVENT_MOVED_IN => .moved_in,
        c.G_FILE_MONITOR_EVENT_MOVED_OUT => .moved_out,
        else => {
            app.scheduleProjectMonitorFlush(true);
            return;
        },
    };
    app.queueProjectMonitorChange(kind, path, other_path) catch {
        app.scheduleProjectMonitorFlush(true);
        return;
    };
    app.scheduleProjectMonitorFlush(app.project_monitor_rescan);
}

fn onProjectTreeDraw(
    _: ?*c.GtkWidget,
    _: ?*anyopaque,
    data: ?*anyopaque,
) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    const started = app.project_draw_started orelse return 0;
    app.project_last_draw_ns = elapsedNanoseconds(started, app.io);
    app.project_draw_started = null;
    app.project_draw_commits +|= 1;
    return 0;
}

fn onProjectSearchTreeDraw(
    _: ?*c.GtkWidget,
    _: ?*anyopaque,
    data: ?*anyopaque,
) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    const started = app.project_search_draw_started orelse return 0;
    app.project_search_last_draw_ns = elapsedNanoseconds(started, app.io);
    app.project_search_draw_started = null;
    app.project_search_draw_commits +|= 1;
    return 0;
}

fn monitorRelativePathAlloc(
    app: *App,
    root: []const u8,
    file: ?*c.GFile,
) !?[]u8 {
    const value = file orelse return null;
    const path_z = c.g_file_get_path(value) orelse return null;
    defer c.g_free(path_z);
    const relative = projectRelativePath(root, std.mem.span(path_z)) orelse return null;
    return try app.allocator.dupe(u8, relative);
}

fn isProjectIgnoreControl(path: []const u8) bool {
    const basename = std.fs.path.basename(path);
    return std.mem.eql(u8, basename, ".gitignore") or
        std.mem.eql(u8, basename, ".ignore");
}

fn onProjectMonitorFlush(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.flushProjectMonitor();
    return c.G_SOURCE_REMOVE;
}

fn onSessionPersist(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.session_persist_source = 0;
    _ = app.persistSessionReported();
    return c.G_SOURCE_REMOVE;
}

fn onBufferChanged(_: ?*c.GtkTextBuffer, data: ?*anyopaque) callconv(.c) void {
    const document: *Document = @ptrCast(@alignCast(data.?));
    document.change_serial +%= 1;
    if (document.loading) {
        document.app.scheduleSessionPersist();
        return;
    }
    document.app.scheduleSessionPersist();
    if (document.multi_editing) return;
    document.clearMultiSelections();
    _ = document.clearFolds();
    document.scheduleTreeSitterRefresh();
}

fn onTreeSitterRefresh(data: ?*anyopaque) callconv(.c) c.gboolean {
    const document: *Document = @ptrCast(@alignCast(data orelse return c.G_SOURCE_REMOVE));
    document.syntax_source = 0;
    document.refreshTreeSitter() catch |err| document.fallbackToSourceViewSyntax(err);
    return c.G_SOURCE_REMOVE;
}

fn onEditorScroll(
    _: ?*c.GtkWidget,
    event: ?*c.GdkEventScroll,
    data: ?*anyopaque,
) callconv(.c) c.gboolean {
    const document: *Document = @ptrCast(@alignCast(data.?));
    const scroll = event orelse return 0;
    const modifiers = scroll.state & c.gtk_accelerator_get_default_mod_mask();
    if ((modifiers & c.GDK_CONTROL_MASK) == 0) return 0;

    var delta: i16 = 0;
    switch (scroll.direction) {
        c.GDK_SCROLL_UP => {
            document.app.editor_zoom_scroll_delta = 0;
            delta = 1;
        },
        c.GDK_SCROLL_DOWN => {
            document.app.editor_zoom_scroll_delta = 0;
            delta = -1;
        },
        c.GDK_SCROLL_SMOOTH => {
            document.app.editor_zoom_scroll_delta += scroll.delta_y;
            if (document.app.editor_zoom_scroll_delta <= -1) {
                document.app.editor_zoom_scroll_delta += 1;
                delta = 1;
            } else if (document.app.editor_zoom_scroll_delta >= 1) {
                document.app.editor_zoom_scroll_delta -= 1;
                delta = -1;
            } else return 1;
        },
        else => return 0,
    }
    document.app.adjustEditorZoom(delta * editor_zoom_percent_step) catch
        document.app.updateStatusError("Editor zoom could not be changed");
    return 1;
}

fn onEditorKeyPress(_: ?*c.GtkWidget, event: ?*c.GdkEventKey, data: ?*anyopaque) callconv(.c) c.gboolean {
    const document: *Document = @ptrCast(@alignCast(data.?));
    const key = event orelse return 0;
    const modifiers = key.state & c.gtk_accelerator_get_default_mod_mask();
    const lowered = c.gdk_keyval_to_lower(key.keyval);
    if (modifiers == c.GDK_MOD1_MASK and lowered == c.GDK_KEY_z) {
        document.app.toggleWordWrap();
        return 1;
    }
    if (document.secondary_selections.items.len == 0) return 0;
    if (key.keyval == c.GDK_KEY_BackSpace or key.keyval == c.GDK_KEY_Delete)
        return @intFromBool(document.replaceMultiSelections(""));
    if ((modifiers & (c.GDK_CONTROL_MASK | c.GDK_MOD1_MASK)) != 0 or
        key.length <= 0) return 0;
    const raw = key.string orelse return 0;
    const replacement = raw[0..@intCast(key.length)];
    if (!std.unicode.utf8ValidateSlice(replacement)) return 0;
    if (replacement.len == 1 and replacement[0] == '\r')
        return @intFromBool(document.replaceMultiSelections("\n"));
    return @intFromBool(document.replaceMultiSelections(replacement));
}

fn onBufferMarkSet(buffer: ?*c.GtkTextBuffer, _: ?*c.GtkTextIter, mark: ?*c.GtkTextMark, data: ?*anyopaque) callconv(.c) void {
    const document: *Document = @ptrCast(@alignCast(data.?));
    const text_buffer = buffer orelse return;
    if (mark != c.gtk_text_buffer_get_insert(text_buffer)) return;
    if (document.app.active_document == document)
        document.app.updateDocumentStatus(document);
}

fn onProjectRowActivated(tree: ?*c.GtkTreeView, path: ?*c.GtkTreePath, _: ?*c.GtkTreeViewColumn, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const model = c.gtk_tree_view_get_model(tree.?) orelse return;
    const tree_path = path orelse return;
    var iter: c.GtkTreeIter = undefined;
    if (c.gtk_tree_model_get_iter(model, &iter, tree_path) == 0)
        return;
    if (treeValueBool(model, &iter, 2)) {
        if (c.gtk_tree_view_row_expanded(tree.?, tree_path) != 0)
            _ = c.gtk_tree_view_collapse_row(tree.?, tree_path)
        else
            _ = c.gtk_tree_view_expand_row(tree.?, tree_path, 0);
        return;
    }
    const entry_index = treeValueUInt64(model, &iter, 1);
    const full_path = (app.projectEntryPathAlloc(entry_index) catch return) orelse return;
    defer app.allocator.free(full_path);
    app.openDocument(full_path) catch |err| {
        const status = std.fmt.allocPrintSentinel(
            app.allocator,
            "Open failed: {s}",
            .{@errorName(err)},
            0,
        ) catch return;
        defer app.allocator.free(status);
        app.updateStatus(status.ptr);
    };
}

fn onProjectRowExpanded(_: ?*c.GtkTreeView, iter: ?*c.GtkTreeIter, _: ?*c.GtkTreePath, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.populateProjectDirectory(iter orelse return) catch |err| {
        app.showWorkerError("Folder expansion failed", err);
    };
}

fn onProjectSearchRowActivated(tree: ?*c.GtkTreeView, path: ?*c.GtkTreePath, _: ?*c.GtkTreeViewColumn, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const model = c.gtk_tree_view_get_model(tree.?) orelse return;
    const tree_path = path orelse return;
    var iter: c.GtkTreeIter = undefined;
    if (c.gtk_tree_model_get_iter(model, &iter, tree_path) == 0) return;
    const entry_index = treeValueUInt64(model, &iter, 1);
    const full_path = (app.projectEntryPathAlloc(entry_index) catch return) orelse return;
    defer app.allocator.free(full_path);
    const line = std.math.cast(u32, treeValueUInt64(model, &iter, 2)) orelse return;
    app.openDocumentAtLine(full_path, line) catch |err| {
        const status = std.fmt.allocPrintSentinel(
            app.allocator,
            "Open failed: {s}",
            .{@errorName(err)},
            0,
        ) catch return;
        defer app.allocator.free(status);
        app.updateStatus(status.ptr);
        return;
    };
    app.project_search_activations += 1;
    const status = std.fmt.allocPrintSentinel(
        app.allocator,
        "{s}:{d}",
        .{ std.fs.path.basename(full_path), line },
        0,
    ) catch return;
    defer app.allocator.free(status);
    app.updateStatus(status.ptr);
}

fn onTabClose(_: ?*c.GtkButton, data: ?*anyopaque) callconv(.c) void {
    const document: *Document = @ptrCast(@alignCast(data.?));
    _ = document.app.closeDocument(document);
}

fn onNewFile(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.newDocument() catch |err| {
        const status = std.fmt.allocPrintSentinel(
            app.allocator,
            "New file failed: {s}",
            .{@errorName(err)},
            0,
        ) catch return;
        defer app.allocator.free(status);
        app.updateStatus(status.ptr);
    };
}

fn onOpenFile(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const dialog = c.gtk_file_chooser_dialog_new(
        "Open File",
        asWindow(app.window),
        c.GTK_FILE_CHOOSER_ACTION_OPEN,
        "Cancel",
        c.GTK_RESPONSE_CANCEL,
        "Open",
        c.GTK_RESPONSE_ACCEPT,
        @as(?*anyopaque, null),
    ) orelse return;
    c.gtk_file_chooser_set_local_only(@ptrCast(dialog), 1);
    if (app.project_root) |root| {
        const root_z = Compat.dupeZ(app.allocator, root) catch null;
        if (root_z) |value| {
            _ = c.gtk_file_chooser_set_current_folder(@ptrCast(dialog), value.ptr);
            app.allocator.free(value);
        }
    }
    if (c.gtk_dialog_run(@ptrCast(dialog)) == c.GTK_RESPONSE_ACCEPT) {
        if (c.gtk_file_chooser_get_filename(@ptrCast(dialog))) |path| {
            app.openDocument(std.mem.span(path)) catch |err| {
                const status = std.fmt.allocPrintSentinel(
                    app.allocator,
                    "Open failed: {s}",
                    .{@errorName(err)},
                    0,
                ) catch null;
                if (status) |message| {
                    app.updateStatus(message.ptr);
                    app.allocator.free(message);
                }
            };
            c.g_free(path);
        }
    }
    c.gtk_widget_destroy(dialog);
}

fn onProjectLoadStep(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    const complete = app.advanceProjectLoad() catch |err| {
        app.project_load_source = 0;
        app.destroyProjectLoad();
        var status_buffer: [128]u8 = undefined;
        const status = Compat.bufPrintZ(
            &status_buffer,
            "Folder open failed: {s}",
            .{@errorName(err)},
        ) catch return c.G_SOURCE_REMOVE;
        app.updateStatus(status.ptr);
        return c.G_SOURCE_REMOVE;
    };
    if (!complete) return c.G_SOURCE_CONTINUE;
    app.project_load_source = 0;
    app.destroyProjectLoad();
    return c.G_SOURCE_REMOVE;
}

fn onOpenFolder(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const dialog = c.gtk_file_chooser_dialog_new(
        "Create NoctEd Project",
        asWindow(app.window),
        c.GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER,
        "Cancel",
        c.GTK_RESPONSE_CANCEL,
        "Create",
        c.GTK_RESPONSE_ACCEPT,
        @as(?*anyopaque, null),
    ) orelse return;
    c.gtk_file_chooser_set_local_only(@ptrCast(dialog), 1);
    if (c.gtk_dialog_run(@ptrCast(dialog)) == c.GTK_RESPONSE_ACCEPT) {
        if (c.gtk_file_chooser_get_filename(@ptrCast(dialog))) |path| {
            app.createProjectFileForRoot(std.mem.span(path)) catch |err| {
                app.showWorkerError("Project creation failed", err);
            };
            c.g_free(path);
        }
    }
    c.gtk_widget_destroy(dialog);
}

fn onOpenProject(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const dialog = c.gtk_file_chooser_dialog_new(
        "Open NoctEd Project",
        asWindow(app.window),
        c.GTK_FILE_CHOOSER_ACTION_OPEN,
        "Cancel",
        c.GTK_RESPONSE_CANCEL,
        "Open",
        c.GTK_RESPONSE_ACCEPT,
        @as(?*anyopaque, null),
    ) orelse return;
    c.gtk_file_chooser_set_local_only(@ptrCast(dialog), 1);
    if (c.gtk_dialog_run(@ptrCast(dialog)) == c.GTK_RESPONSE_ACCEPT) {
        if (c.gtk_file_chooser_get_filename(@ptrCast(dialog))) |path| {
            app.openProjectFile(std.mem.span(path)) catch |err| {
                app.showWorkerError("Project open failed", err);
            };
            c.g_free(path);
        }
    }
    c.gtk_widget_destroy(dialog);
}

fn onRecentProject(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const action: *RecentProjectAction = @ptrCast(@alignCast(data.?));
    action.app.openRecentProject(action.index);
}

fn onClearRecentProjects(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.clearRecentProjects();
}

fn onSave(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.currentDocument()) |document| _ = app.saveDocument(document);
}

fn onSaveAs(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.currentDocument()) |document| _ = app.promptSaveAs(document);
}

fn onCloseFile(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.currentDocument()) |document| _ = app.closeDocument(document);
}

fn onCloseOtherFiles(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    _ = app.closeOtherDocuments();
}

fn onCloseAllFiles(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    _ = app.closeAllDocuments();
}

fn onPreviousFile(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    _ = app.cycleDocument(-1);
}

fn onNextFile(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    _ = app.cycleDocument(1);
}

fn onQuit(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.prepareHotExit()) c.gtk_widget_destroy(app.window);
}

fn onUndo(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.currentDocument()) |document| {
        document.clearMultiSelections();
        _ = document.clearFolds();
        if (c.gtk_source_buffer_can_undo(document.buffer) != 0)
            c.gtk_source_buffer_undo(document.buffer);
    }
}

fn onRedo(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.currentDocument()) |document| {
        document.clearMultiSelections();
        _ = document.clearFolds();
        if (c.gtk_source_buffer_can_redo(document.buffer) != 0)
            c.gtk_source_buffer_redo(document.buffer);
    }
}

fn onCut(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.currentDocument()) |document|
        c.gtk_text_buffer_cut_clipboard(
            @ptrCast(document.buffer),
            c.gtk_clipboard_get_default(c.gdk_display_get_default()),
            @intFromBool(document.editable),
        );
}

fn onCopy(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.currentDocument()) |document|
        c.gtk_text_buffer_copy_clipboard(
            @ptrCast(document.buffer),
            c.gtk_clipboard_get_default(c.gdk_display_get_default()),
        );
}

fn onPaste(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.currentDocument()) |document| {
        if (document.editable)
            c.gtk_text_buffer_paste_clipboard(
                @ptrCast(document.buffer),
                c.gtk_clipboard_get_default(c.gdk_display_get_default()),
                null,
                1,
            );
    }
}

fn onSelectAllOccurrences(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.selectAllOccurrences();
}

fn onShowFind(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.showFind();
}

fn onShowProjectFind(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.showProjectFind();
}

fn onShowQuickOpen(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.showQuickOpen();
}

fn onHideQuickOpen(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.hideQuickOpen();
}

fn onQuickOpenChanged(_: ?*c.GtkEntry, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.scheduleQuickOpenUpdate();
}

fn onQuickOpenUpdate(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.quick_open_source = 0;
    app.updateQuickOpen();
    return c.G_SOURCE_REMOVE;
}

fn onQuickOpenActivate(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    _ = app.activateSelectedQuickOpen();
}

fn onQuickOpenEntryKeyPress(_: ?*c.GtkWidget, event: ?*c.GdkEventKey, data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    const key = event orelse return 0;
    if (key.keyval != c.GDK_KEY_Down) return 0;
    c.gtk_widget_grab_focus(app.quick_open_tree);
    return 1;
}

fn onQuickOpenRowActivated(tree: ?*c.GtkTreeView, path: ?*c.GtkTreePath, _: ?*c.GtkTreeViewColumn, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const model = c.gtk_tree_view_get_model(tree.?) orelse return;
    const tree_path = path orelse return;
    var iter: c.GtkTreeIter = undefined;
    if (c.gtk_tree_model_get_iter(model, &iter, tree_path) == 0) return;
    _ = app.activateQuickOpenIter(model, &iter);
}

fn onHideProjectFind(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.hideProjectFind();
}

fn onProjectSearch(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.runProjectSearch();
}

fn onHideFind(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.hideFind();
}

fn onSearchChanged(_: ?*c.GtkEntry, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.updateSearch();
}

fn onSearchCountChanged(_: ?*anyopaque, _: ?*anyopaque, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.updateSearch();
}

fn onFindNext(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.find(true);
}

fn onFindPrevious(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.find(false);
}

fn onOpenParentFolder(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.openParentFolder();
}

fn onToggleSidebar(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.toggleSidebar();
}
fn onWindowModeWindowed(widget: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const active = c.gtk_check_menu_item_get_active(@ptrCast(widget.?)) != 0;
    app.setWindowMode(if (active) .windowed else .zen_fullscreen);
}

fn onWindowModeZen(widget: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const active = c.gtk_check_menu_item_get_active(@ptrCast(widget.?)) != 0;
    app.setWindowMode(if (active) .zen_fullscreen else .windowed);
}

fn onWindowStateChanged(_: ?*c.GtkWidget, event: ?*c.GdkEventWindowState, data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    const state = event orelse return 0;
    if ((state.changed_mask & c.GDK_WINDOW_STATE_FULLSCREEN) == 0) return 0;
    const mode: core.settings.WindowMode =
        if ((state.new_window_state & c.GDK_WINDOW_STATE_FULLSCREEN) != 0)
            .zen_fullscreen
        else
            .windowed;
    if (app.window_mode == mode) return 0;
    app.window_mode = mode;
    app.settings.window_mode = mode;
    app.syncWindowChrome(mode);
    app.syncWindowModeMenu();
    app.persistSettings();
    return 0;
}
fn onToggleWordWrap(widget: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const enabled = c.gtk_check_menu_item_get_active(@ptrCast(widget.?)) != 0;
    app.setWordWrapEnabled(enabled);
}

fn onToggleMinimap(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.toggleMinimap();
}

fn onToggleCodeFolding(widget: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const enabled = c.gtk_check_menu_item_get_active(@ptrCast(widget.?)) != 0;
    app.setCodeFoldingEnabled(enabled);
}

fn onFoldCurrent(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.foldCurrent();
}

fn onUnfoldCurrent(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.unfoldCurrent();
}

fn onFoldAll(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.foldAll();
}

fn onUnfoldAll(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.unfoldAll();
}

fn onZoomIn(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.adjustEditorZoom(editor_zoom_percent_step) catch
        app.updateStatusError("Editor zoom could not be increased");
}

fn onZoomOut(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.adjustEditorZoom(-editor_zoom_percent_step) catch
        app.updateStatusError("Editor zoom could not be decreased");
}

fn onResetZoom(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.setEditorZoom(editor_zoom_percent_default) catch
        app.updateStatusError("Editor zoom could not be reset");
}

fn onShowUiFontSettings(
    _: ?*c.GtkWidget,
    data: ?*anyopaque,
) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.showUiFontSettings();
}

fn onImportSyntax(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const dialog = c.gtk_file_chooser_dialog_new(
        "Import Syntax Definitions",
        asWindow(app.window),
        c.GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER,
        "Cancel",
        c.GTK_RESPONSE_CANCEL,
        "Import",
        c.GTK_RESPONSE_ACCEPT,
        @as(?*anyopaque, null),
    ) orelse return;
    c.gtk_file_chooser_set_local_only(@ptrCast(dialog), 1);
    if (c.gtk_dialog_run(@ptrCast(dialog)) == c.GTK_RESPONSE_ACCEPT) {
        if (c.gtk_file_chooser_get_filename(@ptrCast(dialog))) |path| {
            app.importSyntaxDirectory(std.mem.span(path));
            c.g_free(path);
        }
    }
    c.gtk_widget_destroy(dialog);
}

fn onImportTextMateGrammar(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    const dialog = c.gtk_file_chooser_dialog_new(
        "Import TextMate JSON Grammar",
        asWindow(app.window),
        c.GTK_FILE_CHOOSER_ACTION_OPEN,
        "Cancel",
        c.GTK_RESPONSE_CANCEL,
        "Import",
        c.GTK_RESPONSE_ACCEPT,
        @as(?*anyopaque, null),
    ) orelse return;
    c.gtk_file_chooser_set_local_only(@ptrCast(dialog), 1);
    if (c.gtk_dialog_run(@ptrCast(dialog)) == c.GTK_RESPONSE_ACCEPT) {
        if (c.gtk_file_chooser_get_filename(@ptrCast(dialog))) |path| {
            _ = app.importTextMateGrammarFile(std.mem.span(path));
            c.g_free(path);
        }
    }
    c.gtk_widget_destroy(dialog);
}

fn onToolAction(widget: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const raw = c.g_object_get_data(widget, "nocted-tool-action") orelse return;
    const action: ToolAction = @fromBackingInt(@intCast(@intFromPtr(raw) - 1));
    const app: *App = @ptrCast(@alignCast(data.?));
    switch (action) {
        .diagnostics => app.runLanguageFeature(.diagnostics, null),
        .completion => app.runLanguageFeature(.completion, null),
        .hover => app.runLanguageFeature(.hover, null),
        .definition => app.runLanguageFeature(.definition, null),
        .references => app.runLanguageFeature(.references, null),
        .rename => app.promptRename(),
        .symbols => app.runLanguageFeature(.symbols, null),
        .formatting => app.runLanguageFeature(.formatting, null),
        .check => app.runProjectTask(.check),
        .build => app.runProjectTask(.build),
        .test_project => app.runProjectTask(.test_project),
        .run => app.runProjectTask(.run),
    }
}

fn runAboutDialog(app: *App, auto_close: bool) bool {
    const dialog = c.gtk_dialog_new_with_buttons(
        "About NoctEd",
        asWindow(app.window),
        c.GTK_DIALOG_MODAL | c.GTK_DIALOG_DESTROY_WITH_PARENT,
        "Close",
        c.GTK_RESPONSE_CLOSE,
        @as(?*anyopaque, null),
    ) orelse return false;
    defer c.gtk_widget_destroy(dialog);
    c.gtk_window_set_resizable(asWindow(dialog), 0);
    c.gtk_dialog_set_default_response(@ptrCast(dialog), c.GTK_RESPONSE_CLOSE);

    const body = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 10) orelse return false;
    c.gtk_widget_set_margin_start(body, 32);
    c.gtk_widget_set_margin_end(body, 32);
    c.gtk_widget_set_margin_top(body, 24);
    c.gtk_widget_set_margin_bottom(body, 24);
    const title = c.gtk_label_new("NoctEd") orelse return false;
    c.gtk_widget_set_name(title, "nocted-about-title");
    const version_label = c.gtk_label_new(version) orelse return false;
    const comments = c.gtk_label_new(
        "Native project editor with a project tree and minimap",
    ) orelse return false;
    c.gtk_box_pack_start(asBox(body), title, 0, 0, 0);
    c.gtk_box_pack_start(asBox(body), version_label, 0, 0, 0);
    c.gtk_box_pack_start(asBox(body), comments, 0, 0, 0);
    const content = c.gtk_dialog_get_content_area(@ptrCast(dialog)) orelse
        return false;
    c.gtk_box_pack_start(asBox(content), body, 1, 1, 0);

    const close_button = c.gtk_dialog_get_widget_for_response(
        @ptrCast(dialog),
        c.GTK_RESPONSE_CLOSE,
    ) orelse return false;
    c.gtk_widget_set_name(close_button, "nocted-about-close");
    c.gtk_widget_set_size_request(close_button, 88, 36);
    c.gtk_widget_set_tooltip_text(close_button, "Close About NoctEd");
    setAccessibleName(close_button, "Close About NoctEd");
    c.gtk_widget_show_all(dialog);
    const close_visible = c.gtk_widget_get_visible(close_button) != 0 and
        c.gtk_widget_get_sensitive(close_button) != 0;
    if (auto_close) {
        var request = SmokeDialogResponse{
            .dialog = dialog,
            .response = c.GTK_RESPONSE_CLOSE,
        };
        if (c.g_idle_add(onSmokeDialogResponse, &request) == 0) return false;
        return close_visible and
            c.gtk_dialog_run(@ptrCast(dialog)) == c.GTK_RESPONSE_CLOSE;
    }
    _ = c.gtk_dialog_run(@ptrCast(dialog));
    return close_visible;
}

fn onAbout(_: ?*c.GtkWidget, data: ?*anyopaque) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(data.?));
    _ = runAboutDialog(app, false);
}

fn onSessionRestoreSmoke(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    const restored = app.session_restores > 0 and app.documents.items.len > 0 and
        app.active_document != null;
    c.g_print(
        "nocted_session_restore_smoke restored=%d documents=%zu status_widgets=%d\n",
        @as(c_int, @intFromBool(restored)),
        app.documents.items.len,
        @as(c_int, @intFromBool(app.status_widgets_ready)),
    );
    app.shutting_down = true;
    c.gtk_widget_destroy(app.window);
    return c.G_SOURCE_REMOVE;
}

fn onStartupSmoke(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    const tree_closed = c.gtk_widget_get_visible(app.sidebar) == 0;
    const no_project = app.project_root == null and app.project_load == null and
        !app.hasWorkerJob(.project_scan);
    const visible = c.gtk_widget_get_visible(app.window) != 0;
    c.g_print(
        "nocted_startup_smoke visible=%d tree_closed=%d project_scan=%d\n",
        @as(c_int, @intFromBool(visible)),
        @as(c_int, @intFromBool(tree_closed)),
        @as(c_int, @intFromBool(!no_project)),
    );
    app.shutting_down = true;
    c.gtk_widget_destroy(app.window);
    return c.G_SOURCE_REMOVE;
}
fn onWindowModeSmoke(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    app.setWindowMode(.zen_fullscreen);
    const zen_ok = app.window_mode == .zen_fullscreen and
        c.gtk_widget_get_visible(app.top_bar) == 0 and
        c.gtk_widget_get_visible(app.status_bar) == 0 and
        c.gtk_notebook_get_show_tabs(asNotebook(app.notebook)) == 0 and
        c.gtk_check_menu_item_get_active(@ptrCast(app.zen_mode_item)) != 0 and
        c.gtk_check_menu_item_get_active(@ptrCast(app.windowed_mode_item)) == 0;
    var zen_persisted = false;
    var zen_settings = core.settings.loadAlloc(app.allocator, app.io, app.settings_path) catch null;
    if (zen_settings) |*settings| {
        zen_persisted = settings.window_mode == .zen_fullscreen;
        settings.deinit(app.allocator);
    }
    app.setWindowMode(.windowed);
    const windowed_ok = app.window_mode == .windowed and
        c.gtk_widget_get_visible(app.top_bar) != 0 and
        c.gtk_widget_get_visible(app.status_bar) != 0 and
        c.gtk_notebook_get_show_tabs(asNotebook(app.notebook)) != 0 and
        c.gtk_check_menu_item_get_active(@ptrCast(app.windowed_mode_item)) != 0 and
        c.gtk_check_menu_item_get_active(@ptrCast(app.zen_mode_item)) == 0;
    var persisted = false;
    var windowed_settings = core.settings.loadAlloc(app.allocator, app.io, app.settings_path) catch null;
    if (windowed_settings) |*settings| {
        persisted = settings.window_mode == .windowed;
        settings.deinit(app.allocator);
    }
    c.g_print(
        "nocted_window_mode_smoke zen=%d windowed=%d zen_persisted=%d persisted=%d\n",
        @as(c_int, @intFromBool(zen_ok)),
        @as(c_int, @intFromBool(windowed_ok)),
        @as(c_int, @intFromBool(zen_persisted)),
        @as(c_int, @intFromBool(persisted)),
    );
    app.shutting_down = true;
    c.gtk_widget_destroy(app.window);
    return c.G_SOURCE_REMOVE;
}

fn onSmoke(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.project_load != null or
        app.hasWorkerJob(.project_scan) or
        app.hasWorkerJob(.document_load))
        return c.G_SOURCE_CONTINUE;
    app.smoke_passed = app.runSmoke();
    if (app.smoke_passed and app.resource_smoke)
        app.smoke_passed = app.runResourceSmoke();
    if (app.smoke_passed) {
        if (app.smoke_search_load_root) |root|
            app.smoke_passed = app.runSearchLoadQualification(root);
    }
    if (app.smoke_passed) {
        if (app.smoke_lifecycle_root) |root|
            app.smoke_passed = app.runCombinedProjectLifecycleSmoke(root);
    }
    if (app.smoke_passed) {
        c.g_print(
            "nocted_native_smoke binary=nocted process=standalone ui=compact sidebar=true project_activation=true tabs=true minimap=true minimap_overlay_translucent=true line_numbers=true editor_zoom=true search=true find_in_files=true project_search_activation=true multi_file_tabs=true tab_navigation=true close_other=true close_all=true untitled=true untitled_dirty=true save_as=true save_as_collision=true save_as_atomic=true save_as_language=true quick_open=true quick_open_bounded=true quick_open_activation=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true session_dirty_restore=true hot_exit=true recent_project=true undo_redo=true code_folding=true folding_configurable=true fold_all=true unfold_all=true folded_save=true folded_edit_restore=true fold_undo_preserved=true atomic_save=true permissions_preserved=true zig_syntax=true tree_sitter=true installed_syntaxes=%zu project_items=%zu rendered=true\n",
            app.languageCount(),
            app.project_entry_count,
        );
    }
    if (app.smoke_passed and app.smoke_preview != .none) {
        switch (app.smoke_preview) {
            .fold => app.foldAll(),
            .search => app.showProjectFind(),
            .quick_open => {
                if (app.currentDocument()) |document| {
                    var start: c.GtkTextIter = undefined;
                    var end: c.GtkTextIter = undefined;
                    c.gtk_text_buffer_get_iter_at_offset(
                        @ptrCast(document.buffer),
                        &start,
                        0,
                    );
                    c.gtk_text_buffer_get_iter_at_offset(
                        @ptrCast(document.buffer),
                        &end,
                        5,
                    );
                    c.gtk_text_buffer_select_range(
                        @ptrCast(document.buffer),
                        &end,
                        &start,
                    );
                    if (document.selectAllOccurrences()) |matches_value| {
                        var matches = matches_value;
                        matches.deinit(app.allocator);
                    } else |_| {}
                }
                app.showQuickOpen();
                c.gtk_entry_set_text(@ptrCast(app.quick_open_entry), "sample");
                app.updateQuickOpen();
            },
            .none => unreachable,
        }
        if (app.smoke_screenshot_path != null)
            _ = c.g_timeout_add(300, onSmokeCapture, app);
        _ = c.g_timeout_add(
            if (app.smoke_screenshot_path != null) 900 else 60000,
            onSmokePreviewDone,
            app,
        );
        return c.G_SOURCE_REMOVE;
    }
    if (app.smoke_lifecycle_root != null) {
        app.finishProjectLifecycleSmoke(app.smoke_passed);
        app.smoke_passed = app.project_lifecycle_passed;
    } else {
        app.smoke_passed = app.prepareHotExit();
        if (!app.smoke_passed) app.shutting_down = true;
        c.gtk_widget_destroy(app.window);
    }
    return c.G_SOURCE_REMOVE;
}

fn onProjectLifecycleSmoke(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.project_load != null or
        app.hasWorkerJob(.project_scan) or
        app.project_draw_started != null or
        app.project_draw_commits == 0)
        return c.G_SOURCE_CONTINUE;
    if (app.project_lifecycle_started) return c.G_SOURCE_REMOVE;
    app.project_lifecycle_started = true;
    const passed = if (app.project_lifecycle_mutate)
        app.runProjectMonitorLifecycleSmoke()
    else
        app.runRealProjectLifecycleSmoke();
    app.finishProjectLifecycleSmoke(passed);
    return c.G_SOURCE_REMOVE;
}

fn onSmokePreviewDone(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    if (app.smoke_lifecycle_root != null) {
        app.finishProjectLifecycleSmoke(app.smoke_passed);
        app.smoke_passed = app.project_lifecycle_passed;
    } else {
        app.smoke_passed = app.prepareHotExit();
        if (!app.smoke_passed) app.shutting_down = true;
        c.gtk_widget_destroy(app.window);
    }
    return c.G_SOURCE_REMOVE;
}

fn onSmokeCapture(data: ?*anyopaque) callconv(.c) c.gboolean {
    const app: *App = @ptrCast(@alignCast(data.?));
    const path = app.smoke_screenshot_path orelse return c.G_SOURCE_REMOVE;
    c.gtk_container_check_resize(@ptrCast(app.window));
    while (c.g_main_context_iteration(null, 0) != 0) {}
    const window = c.gtk_widget_get_window(app.window) orelse return c.G_SOURCE_REMOVE;
    const width = c.gdk_window_get_width(window);
    const height = c.gdk_window_get_height(window);
    if (width <= 0 or height <= 0) return c.G_SOURCE_REMOVE;
    const surface = c.cairo_image_surface_create(c.CAIRO_FORMAT_ARGB32, width, height);
    defer c.cairo_surface_destroy(surface);
    if (c.cairo_surface_status(surface) != c.CAIRO_STATUS_SUCCESS)
        return c.G_SOURCE_REMOVE;
    const context = c.cairo_create(surface);
    defer c.cairo_destroy(context);
    if (c.cairo_status(context) != c.CAIRO_STATUS_SUCCESS)
        return c.G_SOURCE_REMOVE;
    c.gtk_widget_draw(app.window, context);
    c.cairo_surface_flush(surface);
    const pixels = c.cairo_image_surface_get_data(surface) orelse
        return c.G_SOURCE_REMOVE;
    const stride: usize = @intCast(c.cairo_image_surface_get_stride(surface));
    var nonblack_samples: usize = 0;
    var sample_y: usize = 0;
    while (sample_y < @as(usize, @intCast(height))) : (sample_y += 8) {
        var sample_x: usize = 0;
        while (sample_x < @as(usize, @intCast(width))) : (sample_x += 8) {
            const offset = sample_y * stride + sample_x * 4;
            if (pixels[offset] != 0 or pixels[offset + 1] != 0 or
                pixels[offset + 2] != 0)
                nonblack_samples += 1;
        }
    }
    if (nonblack_samples < 64) return c.G_SOURCE_REMOVE;
    const path_z = Compat.dupeZ(app.allocator, path) catch return c.G_SOURCE_REMOVE;
    defer app.allocator.free(path_z);
    const saved = c.cairo_surface_write_to_png(surface, path_z.ptr) ==
        c.CAIRO_STATUS_SUCCESS;
    c.g_print(
        "nocted_smoke_screenshot saved=%d width=%d height=%d " ++
            "render=widget nonblack_samples=%zu path=%s\n",
        @as(c_int, @intFromBool(saved)),
        width,
        height,
        nonblack_samples,
        path_z.ptr,
    );
    return c.G_SOURCE_REMOVE;
}

fn asWindow(widget: *c.GtkWidget) *c.GtkWindow {
    return @ptrCast(widget);
}
fn asContainer(widget: *c.GtkWidget) *c.GtkContainer {
    return @ptrCast(widget);
}
fn asBox(widget: *c.GtkWidget) *c.GtkBox {
    return @ptrCast(widget);
}
fn asPaned(widget: *c.GtkWidget) *c.GtkPaned {
    return @ptrCast(widget);
}
fn asNotebook(widget: *c.GtkWidget) *c.GtkNotebook {
    return @ptrCast(widget);
}
fn asLabel(widget: *c.GtkWidget) *c.GtkLabel {
    return @ptrCast(widget);
}
fn asTreeView(widget: *c.GtkWidget) *c.GtkTreeView {
    return @ptrCast(widget);
}
fn asScrolled(widget: *c.GtkWidget) *c.GtkScrolledWindow {
    return @ptrCast(widget);
}
