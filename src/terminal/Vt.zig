const std = @import("std");
const VtParser = @import("VtParser.zig");
const Unicode = @import("Unicode.zig");
const GhosttyVt = @import("ghostty_vt_public");

pub const Cell = struct {
    const Flags = packed struct(u16) {
        bold: bool = false,
        inverse: bool = false,
        italic: bool = false,
        underline: bool = false,
        strikethrough: bool = false,
        dim: bool = false,
        continuation: bool = false,
        width: u2 = 1,
        _: u7 = 0,
    };

    // Two-byte alignment keeps the direct cell at 14 bytes without narrowing values.
    codepoint: u21 align(2) = ' ',
    flags: Flags = .{},
    grapheme_id: u16 = 0,
    hyperlink_id: u16 = 0,
    foreground: u16 = default_color_id,
    background: u16 = default_color_id,
};

pub const default_color_id: u16 = 0x0fff;

pub const NotificationAction = enum(u8) {
    none,
    focus_pane,
    open_project,
};
pub const first_truecolor_id: u16 = 256;

pub const MouseTracking = enum(u2) {
    none = 0,
    normal = 1,
    button_event = 2,
    any_event = 3,
};

pub const MouseEncoding = enum(u1) {
    legacy = 0,
    sgr = 1,
};

pub const MouseEventKind = enum(u2) {
    press = 0,
    release = 1,
    motion = 2,
    wheel = 3,
};

pub const MouseModifiers = packed struct(u3) {
    shift: bool = false,
    alt: bool = false,
    control: bool = false,
};

pub const MouseEvent = struct {
    column: usize,
    row: usize,
    button: u8,
    kind: MouseEventKind,
    modifiers: MouseModifiers = .{},
};

pub const SelectionRange = struct {
    start_column: usize,
    start_row: usize,
    end_column: usize,
    end_row: usize,
};

pub fn copySelectionFromGrid(
    grid: anytype,
    output: []u8,
    selection: ?SelectionRange,
) ?usize {
    const columns: usize = @intCast(grid.columns);
    const rows: usize = @intCast(grid.rows);
    if (columns == 0 or rows == 0) return 0;
    const first_column = if (selection) |range|
        @min(@min(range.start_column, range.end_column), columns - 1)
    else
        0;
    const last_column = if (selection) |range|
        @min(@max(range.start_column, range.end_column), columns - 1)
    else
        columns - 1;
    const first_row = if (selection) |range|
        @min(@min(range.start_row, range.end_row), rows - 1)
    else
        0;
    const last_row = if (selection) |range|
        @min(@max(range.start_row, range.end_row), rows - 1)
    else
        rows - 1;

    var required: usize = 0;
    var text: [128]u8 = undefined;
    for (first_row..last_row + 1) |row| {
        var start = first_column;
        while (start > 0 and
            (@as(u32, @truncate(grid.packedCell(start, row) >> 32)) & 128) != 0)
            start -= 1;
        var end = last_column + 1;
        while (end > start) {
            const packed_cell = grid.packedCell(end - 1, row);
            const codepoint: u32 = @truncate(packed_cell);
            const style: u32 = @truncate(packed_cell >> 32);
            if (codepoint != ' ' or (style & (64 | 128)) != 0) break;
            end -= 1;
        }
        for (start..end) |column| {
            const style: u32 = @truncate(grid.packedCell(column, row) >> 32);
            if ((style & 128) != 0) continue;
            const length = grid.cellText(column, row, &text);
            required = std.math.add(usize, required, length) catch return null;
        }
        if (row != last_row)
            required = std.math.add(usize, required, 1) catch return null;
    }
    if (required > output.len) return null;

    var used: usize = 0;
    for (first_row..last_row + 1) |row| {
        var start = first_column;
        while (start > 0 and
            (@as(u32, @truncate(grid.packedCell(start, row) >> 32)) & 128) != 0)
            start -= 1;
        var end = last_column + 1;
        while (end > start) {
            const packed_cell = grid.packedCell(end - 1, row);
            const codepoint: u32 = @truncate(packed_cell);
            const style: u32 = @truncate(packed_cell >> 32);
            if (codepoint != ' ' or (style & (64 | 128)) != 0) break;
            end -= 1;
        }
        for (start..end) |column| {
            const style: u32 = @truncate(grid.packedCell(column, row) >> 32);
            if ((style & 128) != 0) continue;
            const length = grid.cellText(column, row, &text);
            @memcpy(output[used..][0..length], text[0..length]);
            used += length;
        }
        if (row != last_row) {
            output[used] = '\n';
            used += 1;
        }
    }
    return used;
}
pub const max_truecolor_count: usize = default_color_id - first_truecolor_id;

test "terminal cells remain compact" {
    try std.testing.expectEqual(@as(usize, 14), @sizeOf(Cell));
}

pub const DirtySpan = extern struct {
    first: u32 = 0,
    end: u32 = 0,
};

pub const SearchMatch = struct {
    column: usize,
    row: usize,
    length: usize,
    matches: usize,
    viewport_offset: usize,
    anchor: Anchor,
};

pub const Anchor = struct {
    line_id: u64,
    grapheme_offset: u32,
    generation: u32,
};

pub const ResolvedAnchor = struct {
    line_index: usize,
    column: usize,
};

pub const HistoryIdentity = struct {
    line_id: u64,
    generation: u32,
    grapheme_start: u32,
};

const RowMeta = struct {
    line_id: u64,
    generation: u32,
    grapheme_start: u32 = 0,
    wrap_continues: bool = false,
    used_columns: u16 = 0,
};

const ColdRow = struct {
    byte_offset: u32,
    byte_length: u32,
    glyph_offset: u32,
    glyph_count: u16,
    run_offset: u32,
    run_count: u16,
};

const ColdGlyph = packed struct(u32) {
    byte_length: u8,
    width: u2,
    grapheme_id: u12,
    padding: u10 = 0,
};

const ColdStyle = packed struct(u64) {
    bold: bool,
    inverse: bool,
    italic: bool,
    underline: bool,
    strikethrough: bool,
    dim: bool,
    foreground: u12,
    background: u12,
    hyperlink_id: u11,
    padding: u23 = 0,
};

const ColdStyleRun = packed struct(u96) {
    first: u16,
    count: u16,
    style: ColdStyle,
};

const GraphemeStore = struct {
    const max_entries = 4094;
    const max_bytes = 256 * 1024;
    const max_cluster_bytes = 128;

    const Entry = struct {
        offset: u32,
        length: u16,
    };

    entries: std.array_list.Managed(Entry),
    bytes: std.array_list.Managed(u8),

    fn init(allocator: std.mem.Allocator) GraphemeStore {
        return .{
            .entries = std.array_list.Managed(Entry).init(allocator),
            .bytes = std.array_list.Managed(u8).init(allocator),
        };
    }

    fn deinit(self: *GraphemeStore) void {
        self.entries.deinit();
        self.bytes.deinit();
    }

    fn extend(self: *GraphemeStore, current_id: u16, base: u21, codepoint: u21) !u16 {
        var base_buffer: [4]u8 = undefined;
        const base_length = if (current_id == 0)
            try encodeCodepoint(base, &base_buffer)
        else
            self.text(current_id).len;
        var codepoint_buffer: [4]u8 = undefined;
        const codepoint_length = try encodeCodepoint(codepoint, &codepoint_buffer);
        const length = base_length + codepoint_length;
        if (self.entries.items.len >= max_entries or
            self.bytes.items.len + length > max_bytes or
            length > max_cluster_bytes)
            return error.GraphemeStoreFull;

        try self.entries.ensureUnusedCapacity(1);
        try self.bytes.ensureUnusedCapacity(length);
        const offset = self.bytes.items.len;
        if (current_id == 0) {
            for (base_buffer[0..base_length]) |byte| self.bytes.appendAssumeCapacity(byte);
        } else {
            const source = self.text(current_id);
            for (source) |byte| self.bytes.appendAssumeCapacity(byte);
        }
        for (codepoint_buffer[0..codepoint_length]) |byte| self.bytes.appendAssumeCapacity(byte);
        self.entries.appendAssumeCapacity(.{
            .offset = @intCast(offset),
            .length = @intCast(length),
        });
        return @intCast(self.entries.items.len);
    }

    fn text(self: GraphemeStore, id: u16) []const u8 {
        if (id == 0 or id > self.entries.items.len) return &.{};
        const entry = self.entries.items[id - 1];
        return self.bytes.items[entry.offset .. entry.offset + entry.length];
    }
};

const HyperlinkStore = struct {
    const max_entries = 1024;
    const max_bytes = 128 * 1024;
    const max_uri_bytes = 2048;

    const Entry = struct { offset: u32, length: u16 };
    entries: std.array_list.Managed(Entry),
    bytes: std.array_list.Managed(u8),

    fn init(allocator: std.mem.Allocator) HyperlinkStore {
        return .{
            .entries = std.array_list.Managed(Entry).init(allocator),
            .bytes = std.array_list.Managed(u8).init(allocator),
        };
    }

    fn deinit(self: *HyperlinkStore) void {
        self.entries.deinit();
        self.bytes.deinit();
    }

    fn intern(self: *HyperlinkStore, value: []const u8) !u16 {
        if (value.len == 0 or value.len > max_uri_bytes or
            self.entries.items.len >= max_entries or
            self.bytes.items.len + value.len > max_bytes)
            return error.HyperlinkStoreFull;
        for (self.entries.items, 0..) |entry, index| {
            const existing = self.bytes.items[entry.offset .. entry.offset + entry.length];
            if (std.mem.eql(u8, existing, value)) return @intCast(index + 1);
        }
        try self.entries.ensureUnusedCapacity(1);
        try self.bytes.ensureUnusedCapacity(value.len);
        const offset = self.bytes.items.len;
        for (value) |byte| self.bytes.appendAssumeCapacity(byte);
        self.entries.appendAssumeCapacity(.{
            .offset = @intCast(offset),
            .length = @intCast(value.len),
        });
        return @intCast(self.entries.items.len);
    }

    fn uri(self: HyperlinkStore, id: u16) []const u8 {
        if (id == 0 or id > self.entries.items.len) return &.{};
        const entry = self.entries.items[id - 1];
        return self.bytes.items[entry.offset .. entry.offset + entry.length];
    }
};

pub const Grid = struct {
    allocator: std.mem.Allocator,
    history_allocator: std.mem.Allocator,
    history_capacity_eager: bool,
    columns: usize,
    rows: usize,
    cells: []Cell,
    row_meta: []RowMeta,
    dirty_rows: []bool,
    dirty_spans: []DirtySpan,
    // Non-destructive row generations let the renderer and any number of
    // remote presentation consumers observe the same damage independently.
    row_damage_generation: []u64,
    damage_generation: u64 = 1,
    all_rows_dirty: bool = true,
    screen_origin: usize = 0,
    tab_stops: []bool,
    alternate_cells: ?[]Cell = null,
    alternate_row_meta: ?[]RowMeta = null,
    alternate_screen_origin: usize = 0,
    saved_cursor_column: usize = 0,
    saved_cursor_row: usize = 0,
    saved_wrap_pending: bool = false,
    alternate_saved_cursor_column: usize = 0,
    alternate_saved_cursor_row: usize = 0,
    alternate_saved_wrap_pending: bool = false,
    alternate_saved_margin_top: usize = 0,
    alternate_saved_margin_bottom: usize = 0,
    alternate_saved_origin_mode: bool = false,
    saved_origin_mode: bool = false,
    saved_charset_g0_dec_special: bool = false,
    saved_charset_g1_dec_special: bool = false,
    saved_charset_use_g1: bool = false,
    cursor_visible: bool = true,
    bracketed_paste: bool = false,
    application_cursor_keys: bool = false,
    insert_mode: bool = false,
    auto_wrap: bool = true,
    wrap_pending: bool = false,
    origin_mode: bool = false,
    charset_g0_dec_special: bool = false,
    charset_g1_dec_special: bool = false,
    charset_use_g1: bool = false,
    mouse_tracking: MouseTracking = .none,
    mouse_encoding: MouseEncoding = .legacy,
    focus_reporting: bool = false,
    synchronized_output: bool = false,
    synchronized_output_begins: u64 = 0,
    blocked_osc52: u64 = 0,
    parser_string_overflows: u64 = 0,
    reply_overflows: u64 = 0,
    bell_serial: u64 = 0,
    notification_serial: u64 = 0,
    notification_action: NotificationAction = .none,
    history: std.array_list.Managed([]Cell),
    history_meta: std.array_list.Managed(RowMeta),
    history_cold: std.array_list.Managed(?ColdRow),
    history_cells: []Cell,
    history_hot_owners: []u32,
    history_next_hot: usize = 0,
    history_scratch: []Cell,
    cold_bytes: std.array_list.Managed(u8),
    cold_glyphs: std.array_list.Managed(ColdGlyph),
    cold_runs: std.array_list.Managed(ColdStyleRun),
    cold_dead_bytes: usize = 0,
    cold_dead_glyphs: usize = 0,
    cold_dead_runs: usize = 0,
    history_limit: usize,
    history_start: usize = 0,
    viewport_offset: usize = 0,
    margin_top: usize = 0,
    margin_bottom: usize,
    cursor_column: usize = 0,
    cursor_row: usize = 0,
    title: std.array_list.Managed(u8),
    true_colors: std.array_list.Managed(u32),
    graphemes: GraphemeStore,
    hyperlinks: HyperlinkStore,
    active_hyperlink: u16 = 0,
    hyperlink_overflows: u64 = 0,
    grapheme_stream: Unicode.Stream = .{},
    last_grapheme_row: usize = 0,
    last_grapheme_column: usize = 0,
    last_grapheme_valid: bool = false,
    last_printed_codepoint: ?u21 = null,
    grapheme_overflows: u64 = 0,
    wide_cells_present: bool = false,
    parser: VtParser.Parser = .{},
    bold: bool = false,
    inverse: bool = false,
    italic: bool = false,
    underline: bool = false,
    strikethrough: bool = false,
    dim: bool = false,
    foreground: u16 = default_color_id,
    background: u16 = default_color_id,
    saved_style_bold: bool = false,
    saved_style_inverse: bool = false,
    saved_style_italic: bool = false,
    saved_style_underline: bool = false,
    saved_style_strikethrough: bool = false,
    saved_style_dim: bool = false,
    saved_style_foreground: u16 = default_color_id,
    saved_style_background: u16 = default_color_id,
    utf8_codepoint: u21 = 0,
    utf8_minimum: u21 = 0,
    utf8_expected: u3 = 0,
    reply_buffer: [4096]u8 = undefined,
    reply_start: usize = 0,
    reply_length: usize = 0,
    next_line_id: u64 = 1,
    next_generation: u32 = 1,

    pub const default_history_lines = 1000;
    pub const max_history_lines = 100_000;
    pub const idle_history_hot_lines = 128;
    pub const idle_history_rows_per_step = 64;
    const initial_history_lines = 32;
    // ponytail: keep only a small hot window; older scrollback is compact cold storage.
    const hot_history_lines = 1024;
    const no_history_owner = std.math.maxInt(u32);
    const max_cached_find_matches = 1024;

    const SearchLocation = struct {
        line_index: usize,
        column: usize,
    };

    pub const IdleHistoryCompaction = struct {
        rows_coldified: usize,
        bytes_released: usize,
        complete: bool,
    };

    pub fn init(allocator: std.mem.Allocator, columns: usize, rows: usize) !Grid {
        return initWithHistoryLimit(allocator, columns, rows, default_history_lines);
    }

    pub fn initWithHistoryLimit(
        allocator: std.mem.Allocator,
        columns: usize,
        rows: usize,
        history_limit: usize,
    ) !Grid {
        return initWithHistoryOptions(
            allocator,
            allocator,
            false,
            columns,
            rows,
            history_limit,
        );
    }

    /// Reserves bounded virtual hot-history capacity through a reclaimable slab allocator.
    pub fn initWithHistoryAllocator(
        allocator: std.mem.Allocator,
        history_allocator: std.mem.Allocator,
        columns: usize,
        rows: usize,
        history_limit: usize,
    ) !Grid {
        return initWithHistoryOptions(
            allocator,
            history_allocator,
            true,
            columns,
            rows,
            history_limit,
        );
    }

    fn initWithHistoryOptions(
        allocator: std.mem.Allocator,
        history_allocator: std.mem.Allocator,
        history_capacity_eager: bool,
        columns: usize,
        rows: usize,
        history_limit: usize,
    ) !Grid {
        if (columns == 0 or rows == 0) return error.InvalidGridSize;
        if (columns > std.math.maxInt(u16)) return error.InvalidGridSize;
        if (history_limit > max_history_lines) return error.InvalidHistoryLimit;
        const cells = try allocator.alloc(Cell, columns * rows);
        errdefer allocator.free(cells);
        const row_meta = try allocator.alloc(RowMeta, rows);
        errdefer allocator.free(row_meta);
        const dirty_rows = try allocator.alloc(bool, rows);
        errdefer allocator.free(dirty_rows);
        const dirty_spans = try allocator.alloc(DirtySpan, rows);
        errdefer allocator.free(dirty_spans);
        const row_damage_generation = try allocator.alloc(u64, rows);
        errdefer allocator.free(row_damage_generation);
        const tab_stops = try allocator.alloc(bool, columns);
        errdefer allocator.free(tab_stops);
        const initial_lines = @min(
            hot_history_lines,
            @min(initial_history_lines, history_limit),
        );
        const history_capacity = if (history_capacity_eager)
            @min(hot_history_lines, history_limit)
        else
            initial_lines;
        const history_cells = try history_allocator.alloc(Cell, history_capacity * columns);
        errdefer history_allocator.free(history_cells);
        const history_hot_owners = try allocator.alloc(u32, history_capacity);
        errdefer allocator.free(history_hot_owners);
        const history_scratch = try allocator.alloc(Cell, columns);
        errdefer allocator.free(history_scratch);
        var history = std.array_list.Managed([]Cell).init(allocator);
        errdefer history.deinit();
        var history_meta = std.array_list.Managed(RowMeta).init(allocator);
        errdefer history_meta.deinit();
        var history_cold = std.array_list.Managed(?ColdRow).init(allocator);
        errdefer history_cold.deinit();
        try history.ensureTotalCapacity(initial_lines);
        try history_meta.ensureTotalCapacity(initial_lines);
        try history_cold.ensureTotalCapacity(initial_lines);
        @memset(cells, .{});
        for (row_meta, 0..) |*meta, row| meta.* = .{
            .line_id = row + 1,
            .generation = @intCast(row + 1),
        };
        @memset(dirty_rows, true);
        @memset(dirty_spans, .{ .first = 0, .end = @intCast(columns) });
        @memset(row_damage_generation, 1);
        @memset(tab_stops, false);
        @memset(history_hot_owners, no_history_owner);
        @memset(history_scratch, .{});
        for (0..columns) |column| {
            if (column % 8 == 0) tab_stops[column] = true;
        }
        return .{
            .allocator = allocator,
            .history_allocator = history_allocator,
            .history_capacity_eager = history_capacity_eager,
            .columns = columns,
            .rows = rows,
            .cells = cells,
            .row_meta = row_meta,
            .dirty_rows = dirty_rows,
            .dirty_spans = dirty_spans,
            .row_damage_generation = row_damage_generation,
            .tab_stops = tab_stops,
            .history = history,
            .history_meta = history_meta,
            .history_cold = history_cold,
            .history_cells = history_cells,
            .history_hot_owners = history_hot_owners,
            .history_scratch = history_scratch,
            .cold_bytes = std.array_list.Managed(u8).init(allocator),
            .cold_glyphs = std.array_list.Managed(ColdGlyph).init(allocator),
            .cold_runs = std.array_list.Managed(ColdStyleRun).init(allocator),
            .history_limit = history_limit,
            .margin_bottom = rows - 1,
            .title = std.array_list.Managed(u8).init(allocator),
            .true_colors = std.array_list.Managed(u32).init(allocator),
            .graphemes = GraphemeStore.init(allocator),
            .hyperlinks = HyperlinkStore.init(allocator),
            .next_line_id = rows + 1,
            .next_generation = @intCast(rows + 1),
        };
    }

    pub fn deinit(self: *Grid) void {
        if (self.alternate_cells) |cells| self.allocator.free(cells);
        if (self.alternate_row_meta) |meta| self.allocator.free(meta);
        self.history.deinit();
        self.history_meta.deinit();
        self.history_cold.deinit();
        self.cold_bytes.deinit();
        self.cold_glyphs.deinit();
        self.cold_runs.deinit();
        self.history_allocator.free(self.history_cells);
        self.allocator.free(self.history_hot_owners);
        self.allocator.free(self.history_scratch);
        self.allocator.free(self.tab_stops);
        self.allocator.free(self.dirty_rows);
        self.allocator.free(self.dirty_spans);
        self.allocator.free(self.row_damage_generation);
        self.title.deinit();
        self.true_colors.deinit();
        self.graphemes.deinit();
        self.hyperlinks.deinit();
        self.allocator.free(self.row_meta);
        self.allocator.free(self.cells);
    }

    pub fn resize(self: *Grid, columns: usize, rows: usize) !void {
        if (columns == 0 or rows == 0) return error.InvalidGridSize;
        if (columns > std.math.maxInt(u16)) return error.InvalidGridSize;
        if (columns == self.columns and rows == self.rows) return;
        if (columns != self.columns and self.alternate_cells == null)
            return self.resizePrimaryReflow(columns, rows);
        if (columns != self.columns and self.alternate_cells != null)
            return self.resizeAlternateWithPrimaryReflow(columns, rows);

        const old_columns = self.columns;
        const old_rows = self.rows;
        const cells = try resizeCellBuffer(
            self.allocator,
            self.cells,
            old_columns,
            old_rows,
            self.screen_origin,
            columns,
            rows,
        );
        errdefer self.allocator.free(cells);
        const row_meta = try self.resizeRowMetaBuffer(
            self.row_meta,
            old_rows,
            self.screen_origin,
            rows,
        );
        errdefer self.allocator.free(row_meta);

        const alternate_cells = if (self.alternate_cells) |primary|
            try resizeCellBuffer(
                self.allocator,
                primary,
                old_columns,
                old_rows,
                self.alternate_screen_origin,
                columns,
                rows,
            )
        else
            null;
        errdefer if (alternate_cells) |primary| self.allocator.free(primary);
        const alternate_row_meta = if (self.alternate_row_meta) |primary|
            try self.resizeRowMetaBuffer(
                primary,
                old_rows,
                self.alternate_screen_origin,
                rows,
            )
        else
            null;
        errdefer if (alternate_row_meta) |primary| self.allocator.free(primary);

        const columns_changed = columns != old_columns;
        const dirty_rows = try self.allocator.alloc(bool, rows);
        errdefer self.allocator.free(dirty_rows);
        @memset(dirty_rows, true);
        const dirty_spans = try self.allocator.alloc(DirtySpan, rows);
        errdefer self.allocator.free(dirty_spans);
        @memset(dirty_spans, .{ .first = 0, .end = @intCast(columns) });
        const row_damage_generation = try self.allocator.alloc(u64, rows);
        errdefer self.allocator.free(row_damage_generation);
        const next_damage_generation = self.damage_generation +% 1;
        @memset(row_damage_generation, if (next_damage_generation == 0) 1 else next_damage_generation);
        const tab_stops = if (columns_changed) blk: {
            const next = try self.allocator.alloc(bool, columns);
            @memset(next, false);
            for (0..columns) |column| {
                if (column % 8 == 0) next[column] = true;
            }
            break :blk next;
        } else self.tab_stops;
        errdefer if (columns_changed) self.allocator.free(tab_stops);

        const history_capacity = if (old_columns == 0) 0 else self.history_cells.len / old_columns;
        const history_cells = if (columns_changed)
            try self.history_allocator.alloc(Cell, history_capacity * columns)
        else
            self.history_cells;
        errdefer if (columns_changed) self.history_allocator.free(history_cells);
        const history_scratch = if (columns_changed)
            try self.allocator.alloc(Cell, columns)
        else
            self.history_scratch;
        errdefer if (columns_changed) self.allocator.free(history_scratch);

        if (columns_changed) {
            @memset(history_scratch, .{});
            const copy_columns = @min(old_columns, columns);
            for (self.history_hot_owners, 0..) |owner, hot_slot| {
                if (owner == no_history_owner) continue;
                const source = self.historySlot(hot_slot);
                const destination = history_cells[hot_slot * columns .. (hot_slot + 1) * columns];
                @memset(destination, .{});
                @memcpy(destination[0..copy_columns], source[0..copy_columns]);
            }
        }

        self.allocator.free(self.cells);
        if (self.alternate_cells) |primary| self.allocator.free(primary);
        self.allocator.free(self.row_meta);
        if (self.alternate_row_meta) |primary| self.allocator.free(primary);
        self.allocator.free(self.dirty_rows);
        self.allocator.free(self.dirty_spans);
        self.allocator.free(self.row_damage_generation);
        if (columns_changed) {
            self.allocator.free(self.tab_stops);
            self.history_allocator.free(self.history_cells);
            self.allocator.free(self.history_scratch);
            for (self.history_hot_owners, 0..) |owner, hot_slot| {
                if (owner == no_history_owner) continue;
                self.history.items[owner] = history_cells[hot_slot * columns .. (hot_slot + 1) * columns];
            }
        }
        self.cells = cells;
        self.row_meta = row_meta;
        self.dirty_rows = dirty_rows;
        self.dirty_spans = dirty_spans;
        self.row_damage_generation = row_damage_generation;
        self.damage_generation = if (next_damage_generation == 0) 1 else next_damage_generation;
        self.all_rows_dirty = true;
        self.screen_origin = 0;
        self.alternate_cells = alternate_cells;
        self.alternate_row_meta = alternate_row_meta;
        self.alternate_screen_origin = 0;
        self.tab_stops = tab_stops;
        self.history_cells = history_cells;
        self.history_scratch = history_scratch;
        self.columns = columns;
        self.rows = rows;
        self.margin_top = 0;
        self.margin_bottom = rows - 1;
        self.cursor_column = @min(self.cursor_column, columns - 1);
        self.cursor_row = @min(self.cursor_row, rows - 1);
        self.saved_cursor_column = @min(self.saved_cursor_column, columns - 1);
        self.saved_cursor_row = @min(self.saved_cursor_row, rows - 1);
        self.alternate_saved_cursor_column = @min(
            self.alternate_saved_cursor_column,
            columns - 1,
        );
        self.alternate_saved_cursor_row = @min(self.alternate_saved_cursor_row, rows - 1);
        self.alternate_saved_margin_top = @min(self.alternate_saved_margin_top, rows - 1);
        self.alternate_saved_margin_bottom = @min(
            self.alternate_saved_margin_bottom,
            rows - 1,
        );
        self.viewport_offset = @min(self.viewport_offset, self.history.items.len);
        self.wrap_pending = false;
        self.resetGraphemeInput();
    }

    fn resizeAlternateWithPrimaryReflow(
        self: *Grid,
        columns: usize,
        rows: usize,
    ) !void {
        const old_columns = self.columns;
        const old_rows = self.rows;
        const active_cells = self.cells;
        const active_meta = self.row_meta;
        const active_origin = self.screen_origin;
        const active_cursor_column = self.cursor_column;
        const active_cursor_row = self.cursor_row;
        const active_wrap_pending = self.wrap_pending;
        const primary_cells = self.alternate_cells.?;
        const primary_meta = self.alternate_row_meta.?;
        const primary_origin = self.alternate_screen_origin;

        const resized_active = try resizeCellBuffer(
            self.allocator,
            active_cells,
            old_columns,
            old_rows,
            active_origin,
            columns,
            rows,
        );
        errdefer self.allocator.free(resized_active);
        const resized_active_meta = try self.resizeRowMetaBuffer(
            active_meta,
            old_rows,
            active_origin,
            rows,
        );
        errdefer self.allocator.free(resized_active_meta);

        self.cells = primary_cells;
        self.row_meta = primary_meta;
        self.screen_origin = primary_origin;
        self.alternate_cells = null;
        self.alternate_row_meta = null;
        self.alternate_screen_origin = 0;
        self.cursor_column = self.alternate_saved_cursor_column;
        self.cursor_row = self.alternate_saved_cursor_row;
        self.wrap_pending = self.alternate_saved_wrap_pending;
        self.resizePrimaryReflow(columns, rows) catch |err| {
            self.cells = active_cells;
            self.row_meta = active_meta;
            self.screen_origin = active_origin;
            self.alternate_cells = primary_cells;
            self.alternate_row_meta = primary_meta;
            self.alternate_screen_origin = primary_origin;
            self.cursor_column = active_cursor_column;
            self.cursor_row = active_cursor_row;
            self.wrap_pending = active_wrap_pending;
            return err;
        };

        self.allocator.free(active_cells);
        self.allocator.free(active_meta);
        self.alternate_cells = self.cells;
        self.alternate_row_meta = self.row_meta;
        self.alternate_screen_origin = self.screen_origin;
        self.cells = resized_active;
        self.row_meta = resized_active_meta;
        self.screen_origin = 0;
        self.alternate_saved_cursor_column = self.cursor_column;
        self.alternate_saved_cursor_row = self.cursor_row;
        self.alternate_saved_wrap_pending = self.wrap_pending;
        self.alternate_saved_margin_top = 0;
        self.alternate_saved_margin_bottom = rows - 1;
        self.alternate_saved_origin_mode = false;
        self.cursor_column = @min(active_cursor_column, columns - 1);
        self.cursor_row = @min(active_cursor_row, rows - 1);
        self.wrap_pending = false;
        self.markAllDirty();
    }

    fn resizePrimaryReflow(self: *Grid, columns: usize, rows: usize) !void {
        const cursor_anchor = self.anchorForLineColumn(
            self.history.items.len + self.cursor_row,
            self.cursor_column,
        );
        const viewport_anchor = if (self.viewport_offset > 0)
            self.anchorForLineColumn(
                self.history.items.len -| self.viewport_offset,
                0,
            )
        else
            null;

        var target = try Grid.initWithHistoryOptions(
            self.allocator,
            self.history_allocator,
            self.history_capacity_eager,
            columns,
            rows,
            self.history_limit,
        );
        var target_geometry_transferred = false;
        defer if (!target_geometry_transferred) target.deinit();
        target.next_line_id = self.next_line_id;
        target.next_generation = self.next_generation;
        try target.graphemes.entries.appendSlice(self.graphemes.entries.items);
        try target.graphemes.bytes.appendSlice(self.graphemes.bytes.items);

        var logical = std.array_list.Managed(Cell).init(self.allocator);
        defer logical.deinit();
        const row_buffer = try self.allocator.alloc(Cell, columns);
        defer self.allocator.free(row_buffer);
        var pending_rows: usize = 0;
        var group_meta: ?RowMeta = null;
        var visible_lines = self.rows;
        const minimum_visible_lines = self.cursor_row + 1;
        while (visible_lines > minimum_visible_lines) {
            const row = visible_lines - 1;
            const meta = self.constRowMeta(row);
            if (meta.used_columns != 0 or meta.wrap_continues) break;
            if (row > 0 and self.constRowMeta(row - 1).wrap_continues) break;
            var blank = true;
            for (self.constRowSlice(row)) |value| {
                if (!isDefaultCell(value)) {
                    blank = false;
                    break;
                }
            }
            if (!blank) break;
            visible_lines -= 1;
        }
        const total_lines = self.history.items.len + visible_lines;
        for (0..total_lines) |line_index| {
            const meta = self.lineMeta(line_index);
            if (group_meta == null) group_meta = meta;
            const source = self.lineSlice(line_index);
            var width = source.len;
            if (!meta.wrap_continues) {
                while (width > 0 and isDefaultCell(source[width - 1]))
                    width -= 1;
            }
            try logical.ensureUnusedCapacity(width);
            for (source[0..width]) |value| {
                if (!value.flags.continuation) logical.appendAssumeCapacity(value);
            }
            if (meta.wrap_continues) continue;
            try self.flushReflowLine(
                &target,
                logical.items,
                group_meta.?,
                row_buffer,
                &pending_rows,
            );
            logical.clearRetainingCapacity();
            group_meta = null;
        }
        if (group_meta) |meta| {
            try self.flushReflowLine(
                &target,
                logical.items,
                meta,
                row_buffer,
                &pending_rows,
            );
        }

        self.allocator.free(self.cells);
        self.allocator.free(self.row_meta);
        self.allocator.free(self.dirty_rows);
        self.allocator.free(self.dirty_spans);
        self.allocator.free(self.row_damage_generation);
        self.allocator.free(self.tab_stops);
        self.history.deinit();
        self.history_meta.deinit();
        self.history_cold.deinit();
        self.cold_bytes.deinit();
        self.cold_glyphs.deinit();
        self.cold_runs.deinit();
        self.history_allocator.free(self.history_cells);
        self.allocator.free(self.history_hot_owners);
        self.allocator.free(self.history_scratch);

        self.cells = target.cells;
        self.row_meta = target.row_meta;
        self.dirty_rows = target.dirty_rows;
        self.dirty_spans = target.dirty_spans;
        self.row_damage_generation = target.row_damage_generation;
        self.damage_generation = target.damage_generation;
        self.all_rows_dirty = target.all_rows_dirty;
        self.screen_origin = target.screen_origin;
        self.tab_stops = target.tab_stops;
        self.history = target.history;
        self.history_meta = target.history_meta;
        self.history_cold = target.history_cold;
        self.history_cells = target.history_cells;
        self.history_hot_owners = target.history_hot_owners;
        self.history_next_hot = target.history_next_hot;
        self.history_scratch = target.history_scratch;
        self.cold_bytes = target.cold_bytes;
        self.cold_glyphs = target.cold_glyphs;
        self.cold_runs = target.cold_runs;
        self.cold_dead_bytes = target.cold_dead_bytes;
        self.cold_dead_glyphs = target.cold_dead_glyphs;
        self.cold_dead_runs = target.cold_dead_runs;
        self.history_start = target.history_start;
        self.columns = columns;
        self.rows = rows;
        self.margin_top = 0;
        self.margin_bottom = rows - 1;
        self.viewport_offset = 0;
        self.cursor_column = @min(self.cursor_column, columns - 1);
        self.cursor_row = @min(self.cursor_row, rows - 1);

        target.title.deinit();
        target.true_colors.deinit();
        target.graphemes.deinit();
        target.hyperlinks.deinit();
        target_geometry_transferred = true;

        if (cursor_anchor) |anchor| {
            if (self.resolveAnchor(anchor)) |resolved| {
                if (resolved.line_index >= self.history.items.len) {
                    self.cursor_row = @min(
                        resolved.line_index - self.history.items.len,
                        rows - 1,
                    );
                    self.cursor_column = @min(resolved.column, columns - 1);
                }
            }
        }
        self.saved_cursor_column = @min(self.saved_cursor_column, columns - 1);
        self.saved_cursor_row = @min(self.saved_cursor_row, rows - 1);
        self.wrap_pending = false;
        if (viewport_anchor) |anchor| {
            if (self.resolveAnchor(anchor)) |resolved| {
                if (resolved.line_index < self.history.items.len)
                    self.viewport_offset = self.history.items.len - resolved.line_index;
            }
        }
        self.resetGraphemeInput();
        self.markAllDirty();
    }

    fn flushReflowLine(
        self: *Grid,
        target: *Grid,
        cells: []const Cell,
        source_meta: RowMeta,
        row_buffer: []Cell,
        pending_rows: *usize,
    ) !void {
        _ = self;
        if (cells.len == 0) {
            @memset(row_buffer, .{});
            var meta = source_meta;
            meta.wrap_continues = false;
            try pushReflowRow(target, row_buffer, meta, pending_rows);
            return;
        }
        var cell_index: usize = 0;
        var grapheme_offset = source_meta.grapheme_start;
        while (cell_index < cells.len) {
            @memset(row_buffer, .{});
            const first_cell = cell_index;
            var column: usize = 0;
            while (cell_index < cells.len) {
                var value = cells[cell_index];
                var width: usize = @max(@as(usize, 1), value.flags.width);
                if (width > target.columns) {
                    width = 1;
                    value.flags.width = 1;
                }
                if (column != 0 and column + width > target.columns) break;
                row_buffer[column] = value;
                if (width == 2 and column + 1 < target.columns) {
                    var continuation = value;
                    continuation.codepoint = 0;
                    continuation.flags.width = 0;
                    continuation.flags.continuation = true;
                    continuation.grapheme_id = 0;
                    row_buffer[column + 1] = continuation;
                }
                column += width;
                cell_index += 1;
                if (column == target.columns) break;
            }
            var meta = source_meta;
            meta.grapheme_start = grapheme_offset;
            meta.wrap_continues = cell_index < cells.len;
            try pushReflowRow(target, row_buffer, meta, pending_rows);
            grapheme_offset +|= @intCast(cell_index - first_cell);
        }
    }

    fn pushReflowRow(
        target: *Grid,
        cells: []const Cell,
        meta: RowMeta,
        pending_rows: *usize,
    ) !void {
        if (pending_rows.* < target.rows) {
            @memcpy(target.rowSlice(pending_rows.*), cells);
            target.rowMeta(pending_rows.*).* = meta;
            pending_rows.* += 1;
            return;
        }
        try target.retainHistoryLine(
            target.constRowSlice(0),
            target.constRowMeta(0),
        );
        target.screen_origin += 1;
        if (target.screen_origin == target.rows) target.screen_origin = 0;
        @memcpy(target.rowSlice(target.rows - 1), cells);
        target.rowMeta(target.rows - 1).* = meta;
    }

    fn resizeRowMetaBuffer(
        self: *Grid,
        source: []const RowMeta,
        source_rows: usize,
        source_origin: usize,
        rows: usize,
    ) ![]RowMeta {
        const output = try self.allocator.alloc(RowMeta, rows);
        const copy_rows = @min(source_rows, rows);
        for (0..copy_rows) |row| {
            const candidate = source_origin + row;
            const source_row = if (candidate >= source_rows)
                candidate - source_rows
            else
                candidate;
            output[row] = source[source_row];
        }
        for (copy_rows..rows) |row| output[row] = self.freshRowMeta();
        return output;
    }

    pub fn setHistoryLimit(self: *Grid, history_limit: usize) !void {
        if (history_limit > max_history_lines) return error.InvalidHistoryLimit;
        if (history_limit == self.history_limit) return;
        const retained_count = @min(history_limit, self.history.items.len);
        const dropped = self.history.items.len - retained_count;
        const target_hot_capacity = @min(
            history_limit,
            @min(hot_history_lines, @max(retained_count, @min(initial_history_lines, history_limit))),
        );
        const current_hot_capacity = self.history_hot_owners.len;
        if (dropped == 0 and current_hot_capacity <= target_hot_capacity) {
            self.history_limit = history_limit;
            return;
        }

        const retained_slots = try self.allocator.alloc(u32, retained_count);
        defer self.allocator.free(retained_slots);
        for (retained_slots, 0..) |*slot, index|
            slot.* = @intCast((self.history_start + dropped + index) % self.history.items.len);

        var history = std.array_list.Managed([]Cell).init(self.allocator);
        errdefer history.deinit();
        var history_meta = std.array_list.Managed(RowMeta).init(self.allocator);
        errdefer history_meta.deinit();
        var history_cold = std.array_list.Managed(?ColdRow).init(self.allocator);
        errdefer history_cold.deinit();
        try history.ensureTotalCapacity(retained_count);
        try history_meta.ensureTotalCapacity(retained_count);
        try history_cold.ensureTotalCapacity(retained_count);
        const hot_cells = try self.history_allocator.alloc(Cell, target_hot_capacity * self.columns);
        errdefer self.history_allocator.free(hot_cells);
        const hot_owners = try self.allocator.alloc(u32, target_hot_capacity);
        errdefer self.allocator.free(hot_owners);
        @memset(hot_cells, .{});
        @memset(hot_owners, no_history_owner);

        var retained_hot: usize = 0;
        for (retained_slots) |slot| {
            if (self.history.items[slot].len != 0) retained_hot += 1;
        }
        for (retained_slots) |slot| {
            if (retained_hot <= target_hot_capacity) break;
            if (self.history.items[slot].len == 0) continue;
            try self.coldifyHistoryRecord(slot);
            retained_hot -= 1;
        }

        var hot_slot: usize = 0;
        for (retained_slots, 0..) |old_slot, new_slot| {
            const old_index: usize = old_slot;
            const direct = self.history.items[old_index];
            if (direct.len != 0) {
                const start = hot_slot * self.columns;
                @memcpy(hot_cells[start .. start + self.columns], direct);
                history.appendAssumeCapacity(hot_cells[start .. start + self.columns]);
                hot_owners[hot_slot] = @intCast(new_slot);
                hot_slot += 1;
            } else {
                history.appendAssumeCapacity(&.{});
            }
            history_meta.appendAssumeCapacity(self.history_meta.items[old_index]);
            history_cold.appendAssumeCapacity(self.history_cold.items[old_index]);
        }

        for (0..dropped) |index| {
            const old_slot = (self.history_start + index) % self.history.items.len;
            self.discardHistoryRecord(old_slot);
        }
        self.history.deinit();
        self.history_meta.deinit();
        self.history_cold.deinit();
        self.history_allocator.free(self.history_cells);
        self.allocator.free(self.history_hot_owners);
        self.history = history;
        self.history_meta = history_meta;
        self.history_cold = history_cold;
        self.history_cells = hot_cells;
        self.history_hot_owners = hot_owners;
        self.history_next_hot = if (target_hot_capacity == 0)
            0
        else
            hot_slot % target_hot_capacity;
        self.history_start = 0;
        self.viewport_offset = @min(self.viewport_offset, retained_count);
        self.history_limit = history_limit;
        try self.maybeCompactColdHistory(true);
        self.markAllDirty();
    }

    pub fn compactIdleHistoryStep(
        self: *Grid,
        target_hot_lines: usize,
        rows_per_step: usize,
    ) !IdleHistoryCompaction {
        if (target_hot_lines > hot_history_lines)
            return error.InvalidIdleHistoryTarget;
        if (rows_per_step == 0) return error.InvalidIdleHistoryStep;

        const bytes_before = self.historyMemoryBytes();
        var hot_count: usize = 0;
        for (self.history_hot_owners) |owner| {
            if (owner != no_history_owner) hot_count += 1;
        }

        var rows_coldified: usize = 0;
        if (hot_count > target_hot_lines) {
            const target_rows = @min(rows_per_step, hot_count - target_hot_lines);
            for (0..self.history.items.len) |line_index| {
                const record_slot = (self.history_start + line_index) % self.history.items.len;
                if (self.history.items[record_slot].len == 0) continue;
                try self.coldifyHistoryRecord(record_slot);
                rows_coldified += 1;
                if (rows_coldified == target_rows) break;
            }
            hot_count -= rows_coldified;
        }

        const complete = hot_count <= target_hot_lines;
        if (complete and self.history_hot_owners.len > target_hot_lines) {
            try self.shrinkHistoryHotStorage(target_hot_lines, hot_count);
            try self.maybeCompactColdHistory(true);
        }
        const bytes_after = self.historyMemoryBytes();
        return .{
            .rows_coldified = rows_coldified,
            .bytes_released = bytes_before -| bytes_after,
            .complete = complete,
        };
    }

    fn shrinkHistoryHotStorage(
        self: *Grid,
        target_hot_lines: usize,
        hot_count: usize,
    ) !void {
        std.debug.assert(hot_count <= target_hot_lines);
        std.debug.assert(target_hot_lines < self.history_hot_owners.len);

        const hot_cells = try self.history_allocator.alloc(Cell, target_hot_lines * self.columns);
        errdefer self.history_allocator.free(hot_cells);
        const hot_owners = try self.allocator.alloc(u32, target_hot_lines);
        errdefer self.allocator.free(hot_owners);
        @memset(hot_cells, .{});
        @memset(hot_owners, no_history_owner);

        var hot_slot: usize = 0;
        for (self.history.items, 0..) |line, record_slot| {
            if (line.len == 0) continue;
            const start = hot_slot * self.columns;
            @memcpy(hot_cells[start .. start + self.columns], line);
            self.history.items[record_slot] = hot_cells[start .. start + self.columns];
            hot_owners[hot_slot] = @intCast(record_slot);
            hot_slot += 1;
        }
        std.debug.assert(hot_slot == hot_count);

        self.history_allocator.free(self.history_cells);
        self.allocator.free(self.history_hot_owners);
        self.history_cells = hot_cells;
        self.history_hot_owners = hot_owners;
        self.history_next_hot = if (target_hot_lines == 0)
            0
        else
            hot_slot % target_hot_lines;
    }

    pub fn feed(self: *Grid, bytes: []const u8) !void {
        var index: usize = 0;
        while (index < bytes.len) {
            if (self.parser.isGround() and self.utf8_expected == 0 and
                !self.insert_mode and self.auto_wrap and !self.wide_cells_present and
                !self.activeDecSpecialCharset())
            {
                var end = index;
                while (end < bytes.len and bytes[end] >= 0x20 and bytes[end] <= 0x7e) : (end += 1) {}
                if (end > index) {
                    try self.putAscii(bytes[index..end]);
                    index = end;
                    continue;
                }
            }
            try self.feedByte(bytes[index]);
            index += 1;
        }
    }

    pub fn feedByte(self: *Grid, byte: u8) !void {
        if (self.utf8_expected > 0) {
            if (byte >= 0x80 and byte <= 0xbf) {
                self.utf8_codepoint = (self.utf8_codepoint << 6) | (byte & 0x3f);
                self.utf8_expected -= 1;
                if (self.utf8_expected == 0) {
                    const codepoint = self.utf8_codepoint;
                    const valid = codepoint >= self.utf8_minimum and
                        codepoint <= 0x10ffff and
                        !(codepoint >= 0xd800 and codepoint <= 0xdfff);
                    self.utf8_codepoint = 0;
                    self.utf8_minimum = 0;
                    try self.putCodepoint(if (valid) codepoint else 0xfffd);
                }
                return;
            }
            try self.putCodepoint(0xfffd);
            self.utf8_codepoint = 0;
            self.utf8_minimum = 0;
            self.utf8_expected = 0;
        }

        if (byte == 0x1b) self.resetGraphemeInput();
        switch (self.parser.feed(byte)) {
            .none => {},
            .print => |printable| try self.consumePrintableByte(printable),
            .execute => |control| {
                self.resetGraphemeInput();
                try self.executeControl(control);
            },
            .escape => |escape| {
                self.resetGraphemeInput();
                try self.applyEscape(escape);
            },
            .csi => |csi| {
                self.resetGraphemeInput();
                try self.applyCsi(csi);
            },
            .string => |string| {
                self.resetGraphemeInput();
                try self.applyString(string);
            },
        }
    }

    fn resetGraphemeInput(self: *Grid) void {
        self.grapheme_stream.reset();
        self.last_grapheme_valid = false;
    }

    fn activeDecSpecialCharset(self: Grid) bool {
        return if (self.charset_use_g1)
            self.charset_g1_dec_special
        else
            self.charset_g0_dec_special;
    }

    fn translateCharset(self: Grid, byte: u8) u21 {
        if (!self.activeDecSpecialCharset()) return byte;
        return switch (byte) {
            '_' => ' ',
            '`' => 0x25c6,
            'a' => 0x2592,
            'b' => 0x2409,
            'c' => 0x240c,
            'd' => 0x240d,
            'e' => 0x240a,
            'f' => 0x00b0,
            'g' => 0x00b1,
            'h' => 0x2424,
            'i' => 0x240b,
            'j' => 0x2518,
            'k' => 0x2510,
            'l' => 0x250c,
            'm' => 0x2514,
            'n' => 0x253c,
            'o' => 0x23ba,
            'p' => 0x23bb,
            'q' => 0x2500,
            'r' => 0x23bc,
            's' => 0x23bd,
            't' => 0x251c,
            'u' => 0x2524,
            'v' => 0x2534,
            'w' => 0x252c,
            'x' => 0x2502,
            'y' => 0x2264,
            'z' => 0x2265,
            '{' => 0x03c0,
            '|' => 0x2260,
            '}' => 0x00a3,
            '~' => 0x00b7,
            else => byte,
        };
    }

    fn consumePrintableByte(self: *Grid, byte: u8) !void {
        if (byte < 0x80) {
            try self.putCodepoint(self.translateCharset(byte));
        } else if (byte >= 0xc2 and byte <= 0xdf) {
            self.utf8_codepoint = byte & 0x1f;
            self.utf8_minimum = 0x80;
            self.utf8_expected = 1;
        } else if (byte >= 0xe0 and byte <= 0xef) {
            self.utf8_codepoint = byte & 0x0f;
            self.utf8_minimum = 0x800;
            self.utf8_expected = 2;
        } else if (byte >= 0xf0 and byte <= 0xf4) {
            self.utf8_codepoint = byte & 0x07;
            self.utf8_minimum = 0x10000;
            self.utf8_expected = 3;
        } else {
            try self.putCodepoint(0xfffd);
        }
    }

    fn executeControl(self: *Grid, byte: u8) !void {
        self.last_printed_codepoint = null;
        switch (byte) {
            0x07 => self.bell_serial +%= 1,
            0x08 => {
                self.wrap_pending = false;
                self.cursor_column -|= 1;
            },
            '\t' => {
                self.wrap_pending = false;
                self.nextTabStop();
            },
            '\n', 0x0b, 0x0c => try self.lineFeed(false),
            '\r' => {
                self.wrap_pending = false;
                self.cursor_column = 0;
            },
            0x0e => self.charset_use_g1 = true,
            0x0f => self.charset_use_g1 = false,
            else => {},
        }
    }

    fn applyEscape(self: *Grid, escape: VtParser.Escape) !void {
        self.last_printed_codepoint = null;
        if (escape.intermediate_count == 1 and
            (escape.intermediates[0] == '(' or escape.intermediates[0] == ')'))
        {
            const dec_special = escape.final == '0';
            if (!dec_special and escape.final != 'B') return;
            if (escape.intermediates[0] == '(') {
                self.charset_g0_dec_special = dec_special;
            } else {
                self.charset_g1_dec_special = dec_special;
            }
            return;
        }
        if (escape.intermediate_count != 0) return;
        if (escape.final != '7' and escape.final != '8') self.wrap_pending = false;
        switch (escape.final) {
            '7' => {
                self.saved_cursor_column = self.cursor_column;
                self.saved_cursor_row = self.cursor_row;
                self.saved_wrap_pending = self.wrap_pending;
                self.saved_origin_mode = self.origin_mode;
                self.saved_charset_g0_dec_special = self.charset_g0_dec_special;
                self.saved_charset_g1_dec_special = self.charset_g1_dec_special;
                self.saved_charset_use_g1 = self.charset_use_g1;
                self.saved_style_bold = self.bold;
                self.saved_style_inverse = self.inverse;
                self.saved_style_italic = self.italic;
                self.saved_style_underline = self.underline;
                self.saved_style_strikethrough = self.strikethrough;
                self.saved_style_dim = self.dim;
                self.saved_style_foreground = self.foreground;
                self.saved_style_background = self.background;
            },
            '8' => {
                self.cursor_column = @min(self.saved_cursor_column, self.columns - 1);
                self.cursor_row = @min(self.saved_cursor_row, self.rows - 1);
                self.wrap_pending = self.saved_wrap_pending;
                self.origin_mode = self.saved_origin_mode;
                self.charset_g0_dec_special = self.saved_charset_g0_dec_special;
                self.charset_g1_dec_special = self.saved_charset_g1_dec_special;
                self.charset_use_g1 = self.saved_charset_use_g1;
                self.bold = self.saved_style_bold;
                self.inverse = self.saved_style_inverse;
                self.italic = self.saved_style_italic;
                self.underline = self.saved_style_underline;
                self.strikethrough = self.saved_style_strikethrough;
                self.dim = self.saved_style_dim;
                self.foreground = self.saved_style_foreground;
                self.background = self.saved_style_background;
            },
            'D' => try self.lineFeed(false),
            'E' => {
                self.cursor_column = 0;
                try self.lineFeed(false);
            },
            'H' => self.tab_stops[self.cursor_column] = true,
            'M' => {
                if (self.cursor_row < self.margin_top or
                    self.cursor_row > self.margin_bottom)
                {
                    self.cursor_row -|= 1;
                } else if (self.cursor_row > self.margin_top) {
                    self.cursor_row -= 1;
                } else {
                    self.reverseScrollRegion();
                }
            },
            'c' => {
                self.bold = false;
                self.inverse = false;
                self.italic = false;
                self.underline = false;
                self.strikethrough = false;
                self.dim = false;
                self.foreground = default_color_id;
                self.background = default_color_id;
                self.active_hyperlink = 0;
                self.cursor_column = 0;
                self.cursor_row = 0;
                self.margin_top = 0;
                self.margin_bottom = self.rows - 1;
                self.insert_mode = false;
                self.auto_wrap = true;
                self.origin_mode = false;
                self.charset_g0_dec_special = false;
                self.charset_g1_dec_special = false;
                self.charset_use_g1 = false;
                self.last_printed_codepoint = null;
                self.markAllDirty();
                @memset(self.cells, .{});
                for (0..self.rows) |row| self.rowMeta(row).* = self.freshRowMeta();
            },
            else => {},
        }
    }

    fn applyString(self: *Grid, event: VtParser.StringEvent) !void {
        self.last_printed_codepoint = null;
        if (event.overflow) {
            self.parser_string_overflows +%= 1;
            return;
        }
        const payload = self.parser.stringSlice();
        switch (event.kind) {
            .osc => {
                const separator = std.mem.indexOfScalar(u8, payload, ';') orelse return;
                const command = std.fmt.parseUnsigned(u16, payload[0..separator], 10) catch return;
                const value = payload[separator + 1 ..];
                switch (command) {
                    0, 2 => {
                        self.title.clearRetainingCapacity();
                        try self.title.appendSlice(value[0..@min(value.len, 512)]);
                    },
                    8 => {
                        const uri_separator = std.mem.indexOfScalar(u8, value, ';') orelse return;
                        const uri = value[uri_separator + 1 ..];
                        if (uri.len == 0) {
                            self.active_hyperlink = 0;
                        } else if (std.unicode.utf8ValidateSlice(uri) and
                            std.mem.indexOfAny(u8, uri, "\x00\r\n\t") == null)
                        {
                            self.active_hyperlink = self.hyperlinks.intern(uri) catch blk: {
                                self.hyperlink_overflows +%= 1;
                                break :blk 0;
                            };
                        }
                    },
                    9 => {
                        if (value.len > 0 and !std.mem.eql(u8, value, "4") and
                            !std.mem.startsWith(u8, value, "4;"))
                            self.notification_serial +%= 1;
                    },
                    52 => self.blocked_osc52 +%= 1,
                    99 => {
                        if (value.len > 0 and std.mem.indexOf(u8, value, "p=?") == null) {
                            self.notification_action = notificationAction(value);
                            self.notification_serial +%= 1;
                        }
                    },
                    777 => {
                        if (std.mem.startsWith(u8, value, "notify;") and value.len > 7) {
                            self.notification_action = notificationAction(value);
                            self.notification_serial +%= 1;
                        }
                    },
                    else => {},
                }
            },
            .dcs => self.applyDcs(payload),
            .sos_pm_apc => {},
        }
    }

    pub fn pendingReplies(self: *const Grid) []const u8 {
        return self.reply_buffer[self.reply_start .. self.reply_start + self.reply_length];
    }

    pub fn consumeReplies(self: *Grid, count: usize) void {
        const consumed = @min(count, self.reply_length);
        self.reply_start += consumed;
        self.reply_length -= consumed;
        if (self.reply_length == 0) self.reply_start = 0;
    }

    fn appendReply(self: *Grid, bytes: []const u8) void {
        if (bytes.len > self.reply_buffer.len - self.reply_length) {
            self.reply_overflows +%= 1;
            return;
        }
        if (self.reply_start + self.reply_length + bytes.len > self.reply_buffer.len) {
            std.mem.copyForwards(
                u8,
                self.reply_buffer[0..self.reply_length],
                self.pendingReplies(),
            );
            self.reply_start = 0;
        }
        const end = self.reply_start + self.reply_length;
        @memcpy(self.reply_buffer[end .. end + bytes.len], bytes);
        self.reply_length += bytes.len;
    }

    fn appendFormattedReply(self: *Grid, comptime format: []const u8, args: anytype) void {
        var buffer: [96]u8 = undefined;
        const reply = std.fmt.bufPrint(&buffer, format, args) catch {
            self.reply_overflows +%= 1;
            return;
        };
        self.appendReply(reply);
    }

    fn applyDcs(self: *Grid, payload: []const u8) void {
        const header = self.parser.dcsHeader();
        if (header.final != 'q' or !header.hasIntermediate('+')) return;

        var requests = std.mem.splitScalar(u8, payload, ';');
        while (requests.next()) |request| {
            if (request.len == 0) continue;
            self.appendTermcapReply(request);
        }
    }

    fn appendTermcapReply(self: *Grid, request: []const u8) void {
        var name_buffer: [32]u8 = undefined;
        const name = decodeHex(request, &name_buffer) orelse {
            self.appendTermcapFailure(request);
            return;
        };
        const value: ?[]const u8 = if (std.mem.eql(u8, name, "TN"))
            "xterm-256color"
        else if (std.mem.eql(u8, name, "Co"))
            "256"
        else if (std.mem.eql(u8, name, "RGB") or std.mem.eql(u8, name, "Tc"))
            ""
        else
            null;
        const capability = value orelse {
            self.appendTermcapFailure(request);
            return;
        };

        var reply: [192]u8 = undefined;
        var used: usize = 0;
        used += copyBounded(reply[used..], "\x1bP1+r") orelse {
            self.reply_overflows +%= 1;
            return;
        };
        used += copyBounded(reply[used..], request) orelse {
            self.reply_overflows +%= 1;
            return;
        };
        used += copyBounded(reply[used..], "=") orelse unreachable;
        for (capability) |byte| {
            if (used + 2 > reply.len) {
                self.reply_overflows +%= 1;
                return;
            }
            reply[used] = hexDigit(byte >> 4);
            reply[used + 1] = hexDigit(byte & 0x0f);
            used += 2;
        }
        used += copyBounded(reply[used..], "\x1b\\") orelse unreachable;
        self.appendReply(reply[0..used]);
    }

    fn appendTermcapFailure(self: *Grid, request: []const u8) void {
        var reply: [96]u8 = undefined;
        const value = std.fmt.bufPrint(&reply, "\x1bP0+r{s}\x1b\\", .{request}) catch {
            self.reply_overflows +%= 1;
            return;
        };
        self.appendReply(value);
    }

    pub fn cell(self: Grid, column: usize, row: usize) Cell {
        // GTK can still paint one frame using the previous allocation while a
        // pane reparent/resize has already changed the Zig grid dimensions.
        // Treat that stale renderer read as an empty cell instead of indexing
        // beyond the current grid.
        if (column >= self.columns or row >= self.rows) return .{};
        const line = self.visibleRowSlice(row);
        return if (column < line.len) line[column] else .{};
    }
    pub fn historyCount(self: Grid) usize {
        return self.history.items.len;
    }

    pub fn historyRowIdentity(self: Grid, row: usize) ?HistoryIdentity {
        if (row >= self.history.items.len) return null;
        const meta = self.historyMeta(row);
        return .{
            .line_id = meta.line_id,
            .generation = meta.generation,
            .grapheme_start = meta.grapheme_start,
        };
    }

    pub fn historyCell(self: Grid, column: usize, row: usize) Cell {
        if (row >= self.history.items.len or column >= self.columns) return .{};
        const line = self.historyLine(row);
        return if (column < line.len) line[column] else .{};
    }

    pub fn historyCellText(
        self: Grid,
        column: usize,
        row: usize,
        output: []u8,
    ) usize {
        return self.writeCellText(self.historyCell(column, row), output);
    }

    pub fn scrollViewport(self: *Grid, lines: isize) void {
        const previous = self.viewport_offset;
        if (lines > 0) self.viewport_offset = @min(self.history.items.len, self.viewport_offset + @as(usize, @intCast(lines))) else self.viewport_offset -|= @as(usize, @intCast(-lines));
        if (self.viewport_offset != previous) self.markAllDirty();
    }

    pub fn takeDirtyRows(self: *Grid, output: []u8) usize {
        const count = @min(output.len, self.rows);
        if (self.all_rows_dirty) {
            @memset(output[0..count], 1);
            @memset(self.dirty_rows[0..count], false);
            @memset(self.dirty_spans[0..count], .{});
        } else for (output[0..count], self.dirty_rows[0..count], self.dirty_spans[0..count]) |*result, *dirty, *span| {
            result.* = @intFromBool(dirty.*);
            dirty.* = false;
            span.* = .{};
        }
        if (count == self.rows) self.all_rows_dirty = false;
        return count;
    }

    pub fn takeDirtySpans(self: *Grid, output: []DirtySpan) usize {
        const count = @min(output.len, self.rows);
        if (self.all_rows_dirty) {
            @memset(output[0..count], .{ .first = 0, .end = @intCast(self.columns) });
            @memset(self.dirty_rows[0..count], false);
            @memset(self.dirty_spans[0..count], .{});
        } else for (output[0..count], self.dirty_rows[0..count], self.dirty_spans[0..count]) |*result, *dirty, *span| {
            result.* = span.*;
            dirty.* = false;
            span.* = .{};
        }
        if (count == self.rows) self.all_rows_dirty = false;
        return count;
    }

    pub const DamageSnapshot = struct {
        generation: u64,
        row_count: usize,
    };

    pub fn damageRowsSince(self: Grid, since: u64, output: []u8) DamageSnapshot {
        const count = @min(output.len, self.rows);
        const reset = since == 0 or since > self.damage_generation;
        for (output[0..count], self.row_damage_generation[0..count]) |*changed, generation| {
            changed.* = @intFromBool(reset or generation > since);
        }
        return .{ .generation = self.damage_generation, .row_count = count };
    }

    pub fn markAllDirty(self: *Grid) void {
        self.all_rows_dirty = true;
        const generation = self.beginDamage();
        @memset(self.row_damage_generation, generation);
    }

    fn beginDamage(self: *Grid) u64 {
        if (self.damage_generation == std.math.maxInt(u64)) {
            self.damage_generation = 1;
            @memset(self.row_damage_generation, 0);
        } else {
            self.damage_generation += 1;
        }
        return self.damage_generation;
    }

    fn markDirtyRange(self: *Grid, first: usize, last_inclusive: usize) void {
        if (first >= self.rows) return;
        const end = @min(last_inclusive + 1, self.rows);
        const generation = self.beginDamage();
        @memset(self.row_damage_generation[first..end], generation);
        if (first == 0 and end == self.rows) {
            self.all_rows_dirty = true;
            return;
        }
        @memset(self.dirty_rows[first..end], true);
        @memset(self.dirty_spans[first..end], .{
            .first = 0,
            .end = @intCast(self.columns),
        });
    }

    fn markDirtySpan(self: *Grid, row: usize, first: usize, end: usize) void {
        if (row >= self.rows or first >= end or first >= self.columns) return;
        const bounded_end = @min(end, self.columns);
        const meta = self.rowMeta(row);
        meta.used_columns = @max(meta.used_columns, @as(u16, @intCast(bounded_end)));
        self.row_damage_generation[row] = self.beginDamage();
        if (self.all_rows_dirty) return;
        self.dirty_rows[row] = true;
        const span = &self.dirty_spans[row];
        if (span.end == 0) {
            span.* = .{ .first = @intCast(first), .end = @intCast(bounded_end) };
        } else {
            span.first = @min(span.first, @as(u32, @intCast(first)));
            span.end = @max(span.end, @as(u32, @intCast(bounded_end)));
        }
    }

    pub fn titleSlice(self: Grid) []const u8 {
        return self.title.items;
    }

    pub fn styleBits(self: Grid, column: usize, row: usize) u32 {
        const cell_value = self.cell(column, row);
        return styleBitsForCell(cell_value);
    }

    pub fn packedCell(self: Grid, column: usize, row: usize) u64 {
        const cell_value = self.cell(column, row);
        return @as(u64, cell_value.codepoint) |
            (@as(u64, styleBitsForCell(cell_value)) << 32);
    }

    pub fn packedRow(self: Grid, row: usize, output: []u64) usize {
        if (row >= self.rows) return 0;
        const line = self.visibleRowSlice(row);
        const count = @min(output.len, @min(self.columns, line.len));
        for (output[0..count], line[0..count]) |*packed_cell, cell_value|
            packed_cell.* = @as(u64, cell_value.codepoint) |
                (@as(u64, styleBitsForCell(cell_value)) << 32);
        return count;
    }

    pub fn cellText(self: Grid, column: usize, row: usize, output: []u8) usize {
        return self.writeCellText(self.cell(column, row), output);
    }

    pub fn mouseModeBits(self: Grid) u32 {
        return @as(u32, @intFromEnum(self.mouse_tracking)) |
            (if (self.mouse_encoding == .sgr) @as(u32, 0x100) else 0);
    }

    pub fn encodeMouse(
        self: Grid,
        event: MouseEvent,
        output: []u8,
    ) ?usize {
        const allowed = switch (self.mouse_tracking) {
            .none => false,
            .normal => event.kind != .motion,
            .button_event => event.kind != .motion or event.button <= 2,
            .any_event => true,
        };
        if (!allowed) return null;
        if (event.kind == .wheel and event.button != 64 and event.button != 65)
            return null;
        if (event.kind != .wheel and event.button > 3) return null;

        const modifier_code: u8 =
            (if (event.modifiers.shift) @as(u8, 4) else 0) |
            (if (event.modifiers.alt) @as(u8, 8) else 0) |
            (if (event.modifiers.control) @as(u8, 16) else 0);
        var button_code: u8 = event.button | modifier_code;
        if (event.kind == .motion) button_code |= 32;

        if (self.mouse_encoding == .sgr) {
            if (event.column == std.math.maxInt(usize) or
                event.row == std.math.maxInt(usize)) return null;
            const final: u8 = if (event.kind == .release) 'm' else 'M';
            const sequence = std.fmt.bufPrint(
                output,
                "\x1b[<{d};{d};{d}{c}",
                .{ button_code, event.column + 1, event.row + 1, final },
            ) catch return null;
            return sequence.len;
        }

        if (event.column > 222 or event.row > 222) return null;
        if (event.kind == .release)
            button_code = 3 | modifier_code;
        if (button_code > 223 or output.len < 6) return null;
        output[0..6].* = .{
            0x1b,
            '[',
            'M',
            32 + button_code,
            @intCast(33 + event.column),
            @intCast(33 + event.row),
        };
        return 6;
    }

    pub fn copySelection(
        self: Grid,
        output: []u8,
        selection: ?SelectionRange,
    ) ?usize {
        return copySelectionFromGrid(&self, output, selection);
    }

    pub fn cellHyperlink(self: Grid, column: usize, row: usize, output: []u8) usize {
        const uri = self.hyperlinks.uri(self.cell(column, row).hyperlink_id);
        const count = @min(uri.len, output.len);
        @memcpy(output[0..count], uri[0..count]);
        return count;
    }

    fn writeCellText(self: Grid, cell_value: Cell, output: []u8) usize {
        if (cell_value.flags.continuation) return 0;
        if (cell_value.grapheme_id != 0) {
            const text = self.graphemes.text(cell_value.grapheme_id);
            const count = @min(text.len, output.len);
            @memcpy(output[0..count], text[0..count]);
            return count;
        }
        return encodeCodepoint(cell_value.codepoint, output) catch 0;
    }

    fn styleBitsForCell(cell_value: Cell) u32 {
        return @as(u32, if (cell_value.flags.bold) 1 else 0) |
            @as(u32, if (cell_value.flags.inverse) 2 else 0) |
            @as(u32, if (cell_value.flags.italic) 4 else 0) |
            @as(u32, if (cell_value.flags.underline) 8 else 0) |
            @as(u32, if (cell_value.hyperlink_id != 0) 8 else 0) |
            @as(u32, if (cell_value.flags.strikethrough) 16 else 0) |
            @as(u32, if (cell_value.flags.dim) 32 else 0) |
            @as(u32, if (cell_value.grapheme_id != 0) 64 else 0) |
            @as(u32, if (cell_value.flags.continuation) 128 else 0) |
            (@as(u32, cell_value.foreground) << 8) |
            (@as(u32, cell_value.background) << 20);
    }

    pub fn colorRgb(self: Grid, color_id: u16) u32 {
        if (color_id < first_truecolor_id) return paletteColor(color_id);
        const index = color_id - first_truecolor_id;
        if (index < self.true_colors.items.len) return self.true_colors.items[index];
        return 0xffffffff;
    }

    pub fn findText(self: *Grid, query: []const u8, reverse: bool, ordinal: usize) ?SearchMatch {
        var points: [128]u21 = undefined;
        const point_count = decodeSearchQuery(query, &points) orelse return null;
        if (point_count == 0) return null;

        const total_lines = self.history.items.len + self.rows;
        var match_count: usize = 0;
        var locations: [max_cached_find_matches]SearchLocation = undefined;
        for (0..total_lines) |line_index| {
            const width = self.lineWidth(line_index);
            for (0..width) |column| {
                if (self.lineCell(line_index, column).flags.continuation) continue;
                if (self.logicalLineMatches(line_index, column, points[0..point_count])) {
                    if (match_count < locations.len)
                        locations[match_count] = .{
                            .line_index = line_index,
                            .column = column,
                        };
                    match_count += 1;
                }
            }
        }
        if (match_count == 0) return null;

        const target = if (reverse)
            match_count - 1 - (ordinal % match_count)
        else
            ordinal % match_count;
        if (target < locations.len) {
            return self.matchAtLocation(locations[target], point_count, match_count);
        }
        var current: usize = 0;
        for (0..total_lines) |line_index| {
            const width = self.lineWidth(line_index);
            for (0..width) |column| {
                if (self.lineCell(line_index, column).flags.continuation or
                    !self.logicalLineMatches(line_index, column, points[0..point_count]))
                    continue;
                if (current == target) {
                    return self.matchAtLocation(.{
                        .line_index = line_index,
                        .column = column,
                    }, point_count, match_count);
                }
                current += 1;
            }
        }
        return null;
    }

    fn matchAtLocation(
        self: *Grid,
        location: SearchLocation,
        point_count: usize,
        match_count: usize,
    ) ?SearchMatch {
        const display_row = if (location.line_index < self.history.items.len) blk: {
            self.viewport_offset = self.history.items.len - location.line_index;
            break :blk 0;
        } else blk: {
            self.viewport_offset = 0;
            break :blk location.line_index - self.history.items.len;
        };
        self.markAllDirty();
        return .{
            .column = location.column,
            .row = display_row,
            .length = point_count,
            .matches = match_count,
            .viewport_offset = self.viewport_offset,
            .anchor = self.anchorForLineColumn(
                location.line_index,
                location.column,
            ) orelse return null,
        };
    }

    pub fn anchorAt(self: Grid, column: usize, row: usize) ?Anchor {
        if (column >= self.columns or row >= self.rows) return null;
        const line_index = if (self.viewport_offset > 0) blk: {
            const first_visible = self.history.items.len -| self.viewport_offset;
            break :blk first_visible + row;
        } else self.history.items.len + row;
        return self.anchorForLineColumn(line_index, column);
    }

    pub fn resolveAnchor(self: Grid, anchor: Anchor) ?ResolvedAnchor {
        const total_lines = self.history.items.len + self.rows;
        for (0..total_lines) |line_index| {
            const meta = self.lineMeta(line_index);
            if (meta.line_id != anchor.line_id or meta.generation != anchor.generation)
                continue;
            const count = self.lineGraphemeCount(line_index);
            if (anchor.grapheme_offset < meta.grapheme_start or
                anchor.grapheme_offset > meta.grapheme_start + count)
                continue;
            const within = anchor.grapheme_offset - meta.grapheme_start;
            var seen: u32 = 0;
            for (0..self.lineWidth(line_index)) |column| {
                if (seen == within) return .{ .line_index = line_index, .column = column };
                if (!self.lineCell(line_index, column).flags.continuation) seen += 1;
            }
            if (seen == within)
                return .{ .line_index = line_index, .column = self.lineWidth(line_index) -| 1 };
        }
        return null;
    }

    fn anchorForLineColumn(
        self: Grid,
        line_index: usize,
        column: usize,
    ) ?Anchor {
        if (line_index >= self.history.items.len + self.rows) return null;
        const meta = self.lineMeta(line_index);
        var offset = meta.grapheme_start;
        const end = @min(column, self.lineWidth(line_index));
        for (0..end) |current| {
            if (!self.lineCell(line_index, current).flags.continuation) offset +|= 1;
        }
        return .{
            .line_id = meta.line_id,
            .grapheme_offset = offset,
            .generation = meta.generation,
        };
    }

    fn lineMeta(self: Grid, line_index: usize) RowMeta {
        if (line_index < self.history.items.len) return self.historyMeta(line_index);
        const row = line_index - self.history.items.len;
        if (row >= self.rows) return .{ .line_id = 0, .generation = 0 };
        return self.constRowMeta(row);
    }

    fn lineGraphemeCount(self: Grid, line_index: usize) u32 {
        var count: u32 = 0;
        for (self.lineSlice(line_index)) |value| {
            if (!value.flags.continuation) count +|= 1;
        }
        return count;
    }

    pub fn writeScrollback(self: Grid, output: []u8) !usize {
        const total_lines = self.history.items.len + self.rows;
        var used: usize = 0;
        for (0..total_lines) |line_index| {
            const line = self.lineSlice(line_index);
            var last = line.len;
            while (last > 0) {
                const tail = line[last - 1];
                if (tail.flags.continuation or tail.codepoint == ' ')
                    last -= 1
                else
                    break;
            }
            for (line[0..last]) |current| {
                if (current.flags.continuation) continue;
                const written = self.writeCellText(current, output[used..]);
                if (written == 0 and current.codepoint != 0) return error.NoSpaceLeft;
                used += written;
            }
            if (line_index + 1 < total_lines and
                !self.lineMeta(line_index).wrap_continues)
            {
                if (used >= output.len) return error.NoSpaceLeft;
                output[used] = '\n';
                used += 1;
            }
        }
        return used;
    }

    fn lineWidth(self: Grid, line_index: usize) usize {
        return self.lineSlice(line_index).len;
    }

    fn lineCell(self: Grid, line_index: usize, column: usize) Cell {
        const line = self.lineSlice(line_index);
        return if (column < line.len) line[column] else .{};
    }

    fn lineSlice(self: Grid, line_index: usize) []const Cell {
        if (line_index < self.history.items.len) return self.historyLine(line_index);
        const row = line_index - self.history.items.len;
        if (row >= self.rows) return &.{};
        return self.constRowSlice(row);
    }

    fn visibleRowSlice(self: Grid, row: usize) []const Cell {
        if (row >= self.rows) return &.{};
        if (self.viewport_offset == 0) return self.constRowSlice(row);
        const first_visible = self.history.items.len -| self.viewport_offset;
        return self.lineSlice(first_visible + row);
    }

    fn physicalRow(self: Grid, logical_row: usize) usize {
        const candidate = self.screen_origin + logical_row;
        return if (candidate >= self.rows) candidate - self.rows else candidate;
    }

    fn rowSlice(self: *Grid, logical_row: usize) []Cell {
        const start = self.physicalRow(logical_row) * self.columns;
        return self.cells[start .. start + self.columns];
    }

    fn constRowSlice(self: Grid, logical_row: usize) []const Cell {
        const start = self.physicalRow(logical_row) * self.columns;
        return self.cells[start .. start + self.columns];
    }

    fn rowMeta(self: *Grid, logical_row: usize) *RowMeta {
        return &self.row_meta[self.physicalRow(logical_row)];
    }

    fn constRowMeta(self: Grid, logical_row: usize) RowMeta {
        return self.row_meta[self.physicalRow(logical_row)];
    }

    fn freshRowMeta(self: *Grid) RowMeta {
        const meta = RowMeta{
            .line_id = self.next_line_id,
            .generation = self.next_generation,
        };
        self.next_line_id +%= 1;
        if (self.next_line_id == 0) self.next_line_id = 1;
        self.next_generation +%= 1;
        if (self.next_generation == 0) self.next_generation = 1;
        return meta;
    }

    fn touchRow(self: *Grid, logical_row: usize) void {
        const generation = self.next_generation;
        self.next_generation +%= 1;
        if (self.next_generation == 0) self.next_generation = 1;
        const line_id = self.constRowMeta(logical_row).line_id;
        self.rowMeta(logical_row).generation = generation;
        var row = logical_row;
        while (row > 0 and self.constRowMeta(row - 1).line_id == line_id) {
            row -= 1;
            self.rowMeta(row).generation = generation;
        }
        row = logical_row + 1;
        while (row < self.rows and self.constRowMeta(row).line_id == line_id) : (row += 1)
            self.rowMeta(row).generation = generation;
    }

    fn historyLine(self: Grid, line_index: usize) []Cell {
        const length = self.history.items.len;
        if (length == 0) unreachable;
        const slot = (self.history_start + line_index) % length;
        const hot = self.history.items[slot];
        if (hot.len != 0) return hot;
        self.decodeColdHistoryRow(slot);
        return self.history_scratch;
    }

    fn historyMeta(self: Grid, line_index: usize) RowMeta {
        const length = self.history_meta.items.len;
        if (length == 0) unreachable;
        return self.history_meta.items[(self.history_start + line_index) % length];
    }

    fn historySlot(self: Grid, slot: usize) []Cell {
        const start = slot * self.columns;
        return self.history_cells[start .. start + self.columns];
    }

    fn ensureHistoryLineCapacity(self: *Grid, required_lines: usize) !void {
        const current_lines = self.history_cells.len / self.columns;
        const maximum = @min(self.history_limit, hot_history_lines);
        if (required_lines <= current_lines or current_lines >= maximum) return;
        const target_lines = if (self.history_capacity_eager)
            maximum
        else
            @min(
                maximum,
                @max(required_lines, @max(initial_history_lines, current_lines * 2)),
            );
        const owners = try self.allocator.alloc(u32, target_lines);
        errdefer self.allocator.free(owners);
        @memset(owners, no_history_owner);
        @memcpy(owners[0..current_lines], self.history_hot_owners);
        const next = try self.history_allocator.realloc(
            self.history_cells,
            target_lines * self.columns,
        );
        self.allocator.free(self.history_hot_owners);
        self.history_cells = next;
        self.history_hot_owners = owners;
        for (owners, 0..) |owner, hot_slot| {
            if (owner != no_history_owner and owner < self.history.items.len)
                self.history.items[owner] = self.historySlot(hot_slot);
        }
    }

    fn retainHistoryLine(self: *Grid, source: []const Cell, meta: RowMeta) !void {
        if (self.history_limit == 0) return;
        if (self.history.items.len < self.history_limit) {
            const record_slot = self.history.items.len;
            try self.history.ensureUnusedCapacity(1);
            try self.history_meta.ensureUnusedCapacity(1);
            try self.history_cold.ensureUnusedCapacity(1);
            self.history.appendAssumeCapacity(&.{});
            self.history_meta.appendAssumeCapacity(meta);
            self.history_cold.appendAssumeCapacity(null);
            errdefer {
                _ = self.history.pop();
                _ = self.history_meta.pop();
                _ = self.history_cold.pop();
            }
            const line = try self.acquireHistoryHotSlot(record_slot);
            @memcpy(line, source[0..self.columns]);
            if (self.viewport_offset > 0)
                self.viewport_offset = @min(
                    self.viewport_offset + 1,
                    self.history.items.len,
                );
            return;
        }
        if (self.history.items.len == 0) return;
        const record_slot = self.history_start;
        const existing = self.history.items[record_slot];
        if (existing.len != 0) {
            @memcpy(existing, source[0..self.columns]);
        } else {
            self.discardHistoryRecord(record_slot);
            const line = try self.acquireHistoryHotSlot(record_slot);
            @memcpy(line, source[0..self.columns]);
        }
        self.history_meta.items[record_slot] = meta;
        self.history_start = (self.history_start + 1) % self.history.items.len;
        if (self.viewport_offset > 0)
            self.viewport_offset = @min(
                self.viewport_offset + 1,
                self.history.items.len,
            );
    }

    fn acquireHistoryHotSlot(self: *Grid, record_slot: usize) ![]Cell {
        var hot_count = self.history_hot_owners.len;
        var free_slot: ?usize = null;
        const maximum = @min(self.history_limit, hot_history_lines);
        for (0..hot_count) |offset| {
            const slot = (self.history_next_hot + offset) % hot_count;
            if (self.history_hot_owners[slot] == no_history_owner) {
                free_slot = slot;
                break;
            }
        }
        if (free_slot == null and hot_count < maximum) {
            try self.ensureHistoryLineCapacity(hot_count + 1);
            hot_count = self.history_hot_owners.len;
            free_slot = self.history_next_hot % hot_count;
            while (self.history_hot_owners[free_slot.?] != no_history_owner)
                free_slot.? = (free_slot.? + 1) % hot_count;
        }
        const slot = free_slot orelse blk: {
            const selected = self.history_next_hot % hot_count;
            const owner = self.history_hot_owners[selected];
            if (owner != no_history_owner and owner != record_slot)
                try self.coldifyHistoryRecord(owner);
            break :blk selected;
        };
        self.history_hot_owners[slot] = @intCast(record_slot);
        self.history_next_hot = (slot + 1) % hot_count;
        const line = self.historySlot(slot);
        self.history.items[record_slot] = line;
        self.history_cold.items[record_slot] = null;
        return line;
    }

    fn discardHistoryRecord(self: *Grid, record_slot: usize) void {
        if (self.history.items[record_slot].len != 0) {
            self.releaseHistoryHotLine(self.history.items[record_slot]);
        } else if (self.history_cold.items[record_slot]) |cold| {
            self.cold_dead_bytes += cold.byte_length;
            self.cold_dead_glyphs += cold.glyph_count;
            self.cold_dead_runs += cold.run_count;
        }
        self.history.items[record_slot] = &.{};
        self.history_cold.items[record_slot] = null;
    }

    fn coldifyHistoryRecord(self: *Grid, record_slot: usize) !void {
        const source = self.history.items[record_slot];
        if (source.len == 0) return;
        try self.maybeCompactColdHistory(false);
        const byte_start = self.cold_bytes.items.len;
        const glyph_start = self.cold_glyphs.items.len;
        const run_start = self.cold_runs.items.len;
        errdefer {
            self.cold_bytes.shrinkRetainingCapacity(byte_start);
            self.cold_glyphs.shrinkRetainingCapacity(glyph_start);
            self.cold_runs.shrinkRetainingCapacity(run_start);
        }

        var last = @min(source.len, self.history_meta.items[record_slot].used_columns);
        while (last > 0 and isDefaultCell(source[last - 1])) last -= 1;
        if (last > 0 and last <= std.math.maxInt(u16)) {
            const style = coldStyle(source[0]);
            var plain_ascii = true;
            for (source[0..last]) |cell_value| {
                if (cell_value.flags.continuation or cell_value.flags.width != 1 or
                    cell_value.grapheme_id != 0 or cell_value.codepoint < 0x20 or
                    cell_value.codepoint > 0x7e or coldStyle(cell_value) != style)
                {
                    plain_ascii = false;
                    break;
                }
            }
            if (plain_ascii) {
                try self.cold_bytes.ensureUnusedCapacity(last);
                for (source[0..last]) |cell_value|
                    self.cold_bytes.appendAssumeCapacity(@intCast(cell_value.codepoint));
                try self.cold_runs.append(.{
                    .first = 0,
                    .count = @intCast(last),
                    .style = style,
                });
                self.history_cold.items[record_slot] = .{
                    .byte_offset = @intCast(byte_start),
                    .byte_length = @intCast(last),
                    .glyph_offset = @intCast(glyph_start),
                    .glyph_count = 0,
                    .run_offset = @intCast(run_start),
                    .run_count = 1,
                };
                self.releaseHistoryHotLine(source);
                self.history.items[record_slot] = &.{};
                return;
            }
        }
        var glyph_index: usize = 0;
        var text_buffer: [GraphemeStore.max_cluster_bytes]u8 = undefined;
        for (source[0..last]) |cell_value| {
            if (cell_value.flags.continuation) continue;
            const text_length = self.writeCellText(cell_value, &text_buffer);
            if (text_length == 0 or text_length > std.math.maxInt(u8))
                return error.InvalidColdHistoryGlyph;
            try self.cold_bytes.appendSlice(text_buffer[0..text_length]);
            try self.cold_glyphs.append(.{
                .byte_length = @intCast(text_length),
                .width = cell_value.flags.width,
                .grapheme_id = @intCast(cell_value.grapheme_id),
            });
            const style = coldStyle(cell_value);
            if (self.cold_runs.items.len > run_start and
                self.cold_runs.items[self.cold_runs.items.len - 1].style == style)
            {
                self.cold_runs.items[self.cold_runs.items.len - 1].count += 1;
            } else {
                try self.cold_runs.append(.{
                    .first = @intCast(glyph_index),
                    .count = 1,
                    .style = style,
                });
            }
            glyph_index += 1;
        }
        if (glyph_index > std.math.maxInt(u16) or
            self.cold_runs.items.len - run_start > std.math.maxInt(u16) or
            byte_start > std.math.maxInt(u32) or
            glyph_start > std.math.maxInt(u32) or run_start > std.math.maxInt(u32) or
            self.cold_bytes.items.len - byte_start > std.math.maxInt(u32))
            return error.ColdHistoryLimitExceeded;

        self.history_cold.items[record_slot] = .{
            .byte_offset = @intCast(byte_start),
            .byte_length = @intCast(self.cold_bytes.items.len - byte_start),
            .glyph_offset = @intCast(glyph_start),
            .glyph_count = @intCast(glyph_index),
            .run_offset = @intCast(run_start),
            .run_count = @intCast(self.cold_runs.items.len - run_start),
        };
        self.releaseHistoryHotLine(source);
        self.history.items[record_slot] = &.{};
    }

    fn releaseHistoryHotLine(self: *Grid, line: []const Cell) void {
        const byte_offset = @intFromPtr(line.ptr) - @intFromPtr(self.history_cells.ptr);
        const hot_slot = byte_offset / (self.columns * @sizeOf(Cell));
        self.history_hot_owners[hot_slot] = no_history_owner;
    }

    fn decodeColdHistoryRow(self: Grid, record_slot: usize) void {
        @memset(self.history_scratch, .{});
        const cold = self.history_cold.items[record_slot] orelse return;
        const runs = self.cold_runs.items[cold.run_offset .. cold.run_offset + cold.run_count];
        if (cold.glyph_count == 0 and cold.byte_length > 0 and runs.len == 1) {
            const text = self.cold_bytes.items[cold.byte_offset .. cold.byte_offset + cold.byte_length];
            for (text, self.history_scratch[0..text.len]) |byte, *cell_value| {
                cell_value.* = cellFromColdStyle(runs[0].style);
                cell_value.codepoint = byte;
            }
            return;
        }
        const glyphs = self.cold_glyphs.items[cold.glyph_offset .. cold.glyph_offset + cold.glyph_count];
        var byte_offset: usize = cold.byte_offset;
        var column: usize = 0;
        var run_index: usize = 0;
        for (glyphs, 0..) |glyph, glyph_index| {
            if (column >= self.columns) break;
            while (run_index + 1 < runs.len and
                glyph_index >= runs[run_index].first + runs[run_index].count)
                run_index += 1;
            const text = self.cold_bytes.items[byte_offset .. byte_offset + glyph.byte_length];
            byte_offset += glyph.byte_length;
            const sequence_length = std.unicode.utf8ByteSequenceLength(text[0]) catch 1;
            const codepoint = std.unicode.utf8Decode(text[0..@min(sequence_length, text.len)]) catch 0xfffd;
            var value = if (runs.len == 0) Cell{} else cellFromColdStyle(runs[run_index].style);
            value.codepoint = codepoint;
            value.flags.width = @max(@as(u2, 1), glyph.width);
            value.grapheme_id = glyph.grapheme_id;
            self.history_scratch[column] = value;
            if (value.flags.width == 2 and column + 1 < self.columns) {
                var continuation = value;
                continuation.codepoint = 0;
                continuation.flags.width = 0;
                continuation.flags.continuation = true;
                continuation.grapheme_id = 0;
                self.history_scratch[column + 1] = continuation;
            }
            column += value.flags.width;
        }
    }

    fn maybeCompactColdHistory(self: *Grid, force: bool) !void {
        const dead_total = self.cold_dead_bytes +
            self.cold_dead_glyphs * @sizeOf(ColdGlyph) +
            self.cold_dead_runs * @sizeOf(ColdStyleRun);
        const allocated_total = self.cold_bytes.items.len +
            self.cold_glyphs.items.len * @sizeOf(ColdGlyph) +
            self.cold_runs.items.len * @sizeOf(ColdStyleRun);
        if (dead_total == 0) return;
        if (!force and
            (dead_total < 1024 * 1024 or dead_total * 2 < allocated_total))
            return;

        var bytes = std.array_list.Managed(u8).init(self.allocator);
        errdefer bytes.deinit();
        var glyphs = std.array_list.Managed(ColdGlyph).init(self.allocator);
        errdefer glyphs.deinit();
        var runs = std.array_list.Managed(ColdStyleRun).init(self.allocator);
        errdefer runs.deinit();
        for (self.history_cold.items) |*entry| {
            const cold = entry.* orelse continue;
            const byte_offset = bytes.items.len;
            const glyph_offset = glyphs.items.len;
            const run_offset = runs.items.len;
            try bytes.appendSlice(self.cold_bytes.items[cold.byte_offset .. cold.byte_offset + cold.byte_length]);
            try glyphs.appendSlice(self.cold_glyphs.items[cold.glyph_offset .. cold.glyph_offset + cold.glyph_count]);
            try runs.appendSlice(self.cold_runs.items[cold.run_offset .. cold.run_offset + cold.run_count]);
            entry.* = .{
                .byte_offset = @intCast(byte_offset),
                .byte_length = cold.byte_length,
                .glyph_offset = @intCast(glyph_offset),
                .glyph_count = cold.glyph_count,
                .run_offset = @intCast(run_offset),
                .run_count = cold.run_count,
            };
        }
        self.cold_bytes.deinit();
        self.cold_glyphs.deinit();
        self.cold_runs.deinit();
        self.cold_bytes = bytes;
        self.cold_glyphs = glyphs;
        self.cold_runs = runs;
        self.cold_dead_bytes = 0;
        self.cold_dead_glyphs = 0;
        self.cold_dead_runs = 0;
    }

    pub fn historyMemoryBytes(self: Grid) usize {
        return self.history_cells.len * @sizeOf(Cell) +
            self.history_hot_owners.len * @sizeOf(u32) +
            self.history_scratch.len * @sizeOf(Cell) +
            self.history.capacity * @sizeOf([]Cell) +
            self.history_meta.capacity * @sizeOf(RowMeta) +
            self.history_cold.capacity * @sizeOf(?ColdRow) +
            self.cold_bytes.capacity +
            self.cold_glyphs.capacity * @sizeOf(ColdGlyph) +
            self.cold_runs.capacity * @sizeOf(ColdStyleRun);
    }

    fn logicalLineMatches(
        self: Grid,
        first_line: usize,
        first_column: usize,
        query: []const u21,
    ) bool {
        var line_index = first_line;
        var column = first_column;
        for (query, 0..) |expected, query_index| {
            if (line_index >= self.history.items.len + self.rows or
                column >= self.lineWidth(line_index))
                return false;
            const current = self.lineCell(line_index, column);
            if (current.flags.continuation or
                foldSearchCodepoint(current.codepoint) != foldSearchCodepoint(expected))
                return false;
            if (query_index + 1 == query.len) return true;
            column += @max(@as(usize, 1), current.flags.width);
            while (column >= self.lineWidth(line_index)) {
                if (!self.lineMeta(line_index).wrap_continues) return false;
                line_index += 1;
                column = 0;
            }
        }
        return true;
    }

    fn putCodepoint(self: *Grid, codepoint: u21) !void {
        if (self.last_grapheme_valid) {
            const starts_cluster = self.grapheme_stream.push(codepoint);
            if (!starts_cluster and
                self.last_grapheme_row < self.rows and
                self.last_grapheme_column < self.columns)
            {
                if (!self.rowSlice(self.last_grapheme_row)[self.last_grapheme_column].flags.continuation) {
                    self.touchRow(self.last_grapheme_row);
                    const previous = &self.rowSlice(self.last_grapheme_row)[self.last_grapheme_column];
                    previous.grapheme_id = self.graphemes.extend(
                        previous.grapheme_id,
                        previous.codepoint,
                        codepoint,
                    ) catch {
                        self.grapheme_overflows +%= 1;
                        return;
                    };
                    self.markDirtySpan(
                        self.last_grapheme_row,
                        self.last_grapheme_column,
                        self.last_grapheme_column + previous.flags.width,
                    );
                    if (codepoint == 0xfe0f and previous.flags.width == 1 and
                        Unicode.isExtendedPictographic(previous.codepoint) and
                        self.last_grapheme_row == self.cursor_row and
                        self.cursor_column == self.last_grapheme_column + 1 and
                        self.cursor_column < self.columns)
                    {
                        previous.flags.width = 2;
                        var continuation = self.currentCell(0);
                        continuation.flags.width = 0;
                        continuation.flags.continuation = true;
                        self.rowSlice(self.cursor_row)[self.cursor_column] = continuation;
                        self.markDirtySpan(self.cursor_row, self.cursor_column, self.cursor_column + 1);
                        self.wide_cells_present = true;
                        if (self.cursor_column + 1 == self.columns) {
                            self.wrap_pending = self.auto_wrap;
                        } else {
                            self.cursor_column += 1;
                        }
                    }
                    return;
                }
            }
        } else {
            self.grapheme_stream.reset();
            _ = self.grapheme_stream.push(codepoint);
        }
        self.last_printed_codepoint = codepoint;

        var width: usize = Unicode.scalarWidth(codepoint);
        if (width == 0 or self.columns < 2) width = 1;
        if (self.wrap_pending) {
            self.cursor_column = 0;
            try self.lineFeed(true);
        }
        if (width == 2 and self.cursor_column + width > self.columns and self.auto_wrap) {
            self.cursor_column = 0;
            try self.lineFeed(true);
        }
        if (self.insert_mode) self.insertCharacters(width);
        const row = self.cursor_row;
        const column = self.cursor_column;
        self.touchRow(row);
        self.clearWideCellAt(row, column);
        self.markDirtySpan(row, column, column + width);
        var cell_value = self.currentCell(codepoint);
        cell_value.flags.width = @intCast(width);
        self.rowSlice(row)[column] = cell_value;
        if (width == 2 and column + 1 < self.columns) {
            self.clearWideCellAt(row, column + 1);
            var continuation = self.currentCell(0);
            continuation.flags.width = 0;
            continuation.flags.continuation = true;
            self.rowSlice(row)[column + 1] = continuation;
            self.wide_cells_present = true;
        }
        self.last_grapheme_row = row;
        self.last_grapheme_column = column;
        self.last_grapheme_valid = true;
        if (column + width >= self.columns) {
            self.cursor_column = self.columns - 1;
            self.wrap_pending = self.auto_wrap;
        } else self.cursor_column = column + width;
    }

    fn currentCell(self: Grid, codepoint: u21) Cell {
        return .{
            .codepoint = codepoint,
            .flags = .{
                .bold = self.bold,
                .inverse = self.inverse,
                .italic = self.italic,
                .underline = self.underline,
                .strikethrough = self.strikethrough,
                .dim = self.dim,
            },
            .hyperlink_id = self.active_hyperlink,
            .foreground = self.foreground,
            .background = self.background,
        };
    }

    fn clearWideCellAt(self: *Grid, row: usize, column: usize) void {
        const current_row = self.rowSlice(row);
        if (current_row[column].flags.continuation and column > 0) {
            current_row[column - 1] = .{};
            self.markDirtySpan(row, column - 1, column + 1);
        } else if (current_row[column].flags.width == 2 and column + 1 < self.columns) {
            current_row[column + 1] = .{};
            self.markDirtySpan(row, column, column + 2);
        }
    }

    fn putAscii(self: *Grid, bytes: []const u8) !void {
        var offset: usize = 0;
        var last_row: usize = self.cursor_row;
        var last_column: usize = self.cursor_column;
        var last_survives = false;
        const style = Cell{
            .flags = .{
                .bold = self.bold,
                .inverse = self.inverse,
                .italic = self.italic,
                .underline = self.underline,
                .strikethrough = self.strikethrough,
                .dim = self.dim,
            },
            .hyperlink_id = self.active_hyperlink,
            .foreground = self.foreground,
            .background = self.background,
        };
        while (offset < bytes.len) {
            if (self.wrap_pending) {
                self.cursor_column = 0;
                try self.lineFeed(true);
            }
            const available = self.columns - self.cursor_column;
            const count = @min(available, bytes.len - offset);
            self.touchRow(self.cursor_row);
            const current_row = self.rowSlice(self.cursor_row);
            last_row = self.cursor_row;
            last_column = self.cursor_column + count - 1;
            last_survives = true;
            self.markDirtySpan(self.cursor_row, self.cursor_column, self.cursor_column + count);
            const chunk = bytes[offset .. offset + count];
            if (chunk[0] == ' ') {
                var spaces = true;
                for (chunk[1..]) |byte| {
                    if (byte != ' ') {
                        spaces = false;
                        break;
                    }
                }
                if (spaces) {
                    @memset(current_row[self.cursor_column .. self.cursor_column + count], style);
                } else for (chunk, self.cursor_column..) |byte, column| {
                    current_row[column] = style;
                    current_row[column].codepoint = byte;
                }
            } else for (chunk, self.cursor_column..) |byte, column| {
                current_row[column] = style;
                current_row[column].codepoint = byte;
            }
            offset += count;
            if (count == available) {
                self.cursor_column = self.columns - 1;
                self.wrap_pending = true;
            } else {
                self.cursor_column += count;
            }
        }
        self.grapheme_stream.reset();
        self.last_printed_codepoint = bytes[bytes.len - 1];
        self.last_grapheme_valid = last_survives;
        if (last_survives) {
            self.grapheme_stream.startAscii();
            self.last_grapheme_row = last_row;
            self.last_grapheme_column = last_column;
        }
    }

    fn lineFeed(self: *Grid, wrapped: bool) !void {
        self.wrap_pending = false;
        if (self.cursor_row < self.margin_top or self.cursor_row > self.margin_bottom) {
            if (self.cursor_row + 1 < self.rows) self.cursor_row += 1;
            return;
        }
        const current_meta = self.rowMeta(self.cursor_row);
        current_meta.wrap_continues = wrapped;
        const next_meta = if (wrapped) RowMeta{
            .line_id = current_meta.line_id,
            .generation = current_meta.generation,
            .grapheme_start = current_meta.grapheme_start +|
                @as(u32, @intCast(self.rowGraphemeCount(self.cursor_row))),
        } else self.freshRowMeta();
        if (self.cursor_row < self.margin_bottom) {
            self.cursor_row += 1;
            self.rowMeta(self.cursor_row).* = next_meta;
        } else {
            const saved = self.constRowSlice(self.margin_top);
            const saved_meta = self.constRowMeta(self.margin_top);
            if (self.margin_top != 0 or self.margin_bottom != self.rows - 1) {
                self.scrollRegionWithMeta(next_meta);
                return;
            }
            if (self.alternate_cells == null)
                try self.retainHistoryLine(saved, saved_meta);
            self.scrollRegionWithMeta(next_meta);
        }
    }

    fn rowGraphemeCount(self: Grid, logical_row: usize) usize {
        if (!self.wide_cells_present)
            return self.constRowMeta(logical_row).used_columns;
        var count: usize = 0;
        for (self.constRowSlice(logical_row)) |cell_value| {
            if (!cell_value.flags.continuation) count += 1;
        }
        return count;
    }

    fn nextTabStop(self: *Grid) void {
        var column = self.cursor_column + 1;
        while (column < self.columns and !self.tab_stops[column]) : (column += 1) {}
        self.cursor_column = @min(self.columns - 1, column);
    }

    fn previousTabStop(self: *Grid) void {
        if (self.cursor_column == 0) return;
        var column = self.cursor_column - 1;
        while (column > 0 and !self.tab_stops[column]) : (column -= 1) {}
        self.cursor_column = column;
    }

    fn scrollRegion(self: *Grid) void {
        self.scrollRegionWithMeta(self.freshRowMeta());
    }

    fn replaceRow(self: *Grid, logical_row: usize, replacement: RowMeta) void {
        @memset(self.rowSlice(logical_row), .{});
        self.rowMeta(logical_row).* = replacement;
    }

    fn scrollRegionWithMeta(self: *Grid, replacement_meta: RowMeta) void {
        if (self.margin_top >= self.margin_bottom) return;
        self.markDirtyRange(self.margin_top, self.margin_bottom);
        if (self.margin_top == 0 and self.margin_bottom == self.rows - 1) {
            self.screen_origin += 1;
            if (self.screen_origin == self.rows) self.screen_origin = 0;
            self.replaceRow(self.rows - 1, replacement_meta);
            return;
        }
        for (self.margin_top..self.margin_bottom) |logical_row| {
            @memcpy(self.rowSlice(logical_row), self.constRowSlice(logical_row + 1));
            self.rowMeta(logical_row).* = self.constRowMeta(logical_row + 1);
        }
        self.replaceRow(self.margin_bottom, replacement_meta);
    }

    fn reverseScrollRegion(self: *Grid) void {
        if (self.margin_top >= self.margin_bottom) return;
        self.markDirtyRange(self.margin_top, self.margin_bottom);
        if (self.margin_top == 0 and self.margin_bottom == self.rows - 1) {
            self.screen_origin = if (self.screen_origin == 0)
                self.rows - 1
            else
                self.screen_origin - 1;
            self.replaceRow(0, self.freshRowMeta());
            return;
        }
        var logical_row = self.margin_bottom;
        while (logical_row > self.margin_top) : (logical_row -= 1) {
            @memcpy(self.rowSlice(logical_row), self.constRowSlice(logical_row - 1));
            self.rowMeta(logical_row).* = self.constRowMeta(logical_row - 1);
        }
        self.replaceRow(self.margin_top, self.freshRowMeta());
    }

    fn applyCsi(self: *Grid, csi: *const VtParser.Csi) !void {
        if (csi.final != 'b') self.last_printed_codepoint = null;
        if (csi.private_marker != 0) {
            var switches_alternate_screen = false;
            if (csi.private_marker == '?' and (csi.final == 'h' or csi.final == 'l')) {
                for (0..csi.parameter_count) |index| switch (csi.parameter(index).valueOr(0, 0)) {
                    47, 1047, 1049 => switches_alternate_screen = true,
                    else => {},
                };
            }
            if (csi.final != 'm' and !switches_alternate_screen)
                self.wrap_pending = false;
            const first = @as(usize, csi.valueOr(0, 0));
            switch (csi.final) {
                'c' => if (csi.private_marker == '>')
                    self.appendReply("\x1b[>0;1;0c"),
                'n' => self.replyDeviceStatus(csi),
                'p' => if (csi.hasIntermediate('$')) self.replyModeStatus(csi),
                'h', 'l' => if (csi.private_marker == '?') {
                    const enabled = csi.final == 'h';
                    for (0..csi.parameter_count) |index|
                        self.applyMode(
                            true,
                            csi.parameter(index).valueOr(0, 0),
                            enabled,
                        );
                },
                'J' => if (csi.private_marker == '?') self.eraseDisplay(first),
                'K' => if (csi.private_marker == '?') self.eraseLine(first),
                'u' => if (csi.private_marker == '?') {
                    // NOCTTY emits legacy key sequences, so advertise no Kitty flags.
                    self.appendReply("\x1b[?0u");
                },
                else => {},
            }
            return;
        }

        if (csi.final != 'm' and csi.final != 's' and csi.final != 'u')
            self.wrap_pending = false;
        const first = @as(usize, csi.valueOr(0, 0));
        const amount = @max(@as(usize, 1), first);
        const origin_row_min = if (self.origin_mode) self.margin_top else 0;
        const origin_row_max = if (self.origin_mode) self.margin_bottom else self.rows - 1;
        const movement_row_min = if (self.cursor_row >= self.margin_top)
            self.margin_top
        else
            0;
        const movement_row_max = if (self.cursor_row <= self.margin_bottom)
            self.margin_bottom
        else
            self.rows - 1;
        switch (csi.final) {
            'c' => self.appendReply("\x1b[?1;2c"),
            'n' => self.replyDeviceStatus(csi),
            'p' => if (csi.hasIntermediate('$')) self.replyModeStatus(csi),
            'H', 'f' => {
                const row = @max(@as(usize, 1), csi.valueOr(0, 1));
                const column = @max(@as(usize, 1), csi.valueOr(1, 1));
                self.cursor_row = @min(origin_row_max, origin_row_min + row - 1);
                self.cursor_column = @min(self.columns - 1, column - 1);
            },
            'm' => self.applySgrSequence(csi),
            'J' => self.eraseDisplay(first),
            'K' => self.eraseLine(first),
            'G', '`' => self.cursor_column = @min(
                self.columns - 1,
                @max(@as(usize, 1), csi.valueOr(0, 1)) - 1,
            ),
            'd' => {
                const row = @max(@as(usize, 1), csi.valueOr(0, 1));
                self.cursor_row = @min(origin_row_max, origin_row_min + row - 1);
            },
            'g' => {
                if (first == 0)
                    self.tab_stops[self.cursor_column] = false
                else if (first == 3)
                    @memset(self.tab_stops, false);
            },
            'r' => {
                const top = @as(usize, csi.valueOr(0, 1));
                const bottom = @as(usize, csi.valueOr(1, @intCast(self.rows)));
                if (top >= 1 and bottom > top and bottom <= self.rows) {
                    self.margin_top = top - 1;
                    self.margin_bottom = bottom - 1;
                    self.cursor_row = if (self.origin_mode) self.margin_top else 0;
                    self.cursor_column = 0;
                }
            },
            'h', 'l' => {
                const enabled = csi.final == 'h';
                for (0..csi.parameter_count) |index|
                    self.applyMode(
                        false,
                        csi.parameter(index).valueOr(0, 0),
                        enabled,
                    );
            },
            'A' => self.cursor_row = @max(movement_row_min, self.cursor_row -| amount),
            'B', 'e' => self.cursor_row = @min(
                movement_row_max,
                self.cursor_row +| amount,
            ),
            'C', 'a' => self.cursor_column = @min(
                self.columns - 1,
                self.cursor_column +| amount,
            ),
            'D' => self.cursor_column -|= amount,
            'E' => {
                self.cursor_row = @min(movement_row_max, self.cursor_row +| amount);
                self.cursor_column = 0;
            },
            'F' => {
                self.cursor_row = @max(movement_row_min, self.cursor_row -| amount);
                self.cursor_column = 0;
            },
            'I' => for (0..amount) |_| self.nextTabStop(),
            'Z' => for (0..amount) |_| self.previousTabStop(),
            '@' => self.insertCharacters(amount),
            'P' => self.deleteCharacters(amount),
            'X' => self.eraseCharacters(amount),
            'L' => {
                if (self.cursor_row >= self.margin_top and
                    self.cursor_row <= self.margin_bottom)
                {
                    self.insertLines(amount);
                    self.cursor_column = 0;
                }
            },
            'M' => {
                if (self.cursor_row >= self.margin_top and
                    self.cursor_row <= self.margin_bottom)
                {
                    self.deleteLines(amount);
                    self.cursor_column = 0;
                }
            },
            'S' => for (0..amount) |_| self.scrollRegion(),
            'T' => for (0..amount) |_| self.reverseScrollRegion(),
            'b' => if (self.last_printed_codepoint) |codepoint| {
                for (0..amount) |_| try self.putCodepoint(codepoint);
                self.last_printed_codepoint = null;
            },
            's' => {
                self.saved_cursor_column = self.cursor_column;
                self.saved_cursor_row = self.cursor_row;
                self.saved_wrap_pending = self.wrap_pending;
                self.saved_origin_mode = self.origin_mode;
                self.saved_charset_g0_dec_special = self.charset_g0_dec_special;
                self.saved_charset_g1_dec_special = self.charset_g1_dec_special;
                self.saved_charset_use_g1 = self.charset_use_g1;
            },
            'u' => {
                self.cursor_column = @min(self.saved_cursor_column, self.columns - 1);
                self.cursor_row = @min(self.saved_cursor_row, self.rows - 1);
                self.wrap_pending = self.saved_wrap_pending;
                self.origin_mode = self.saved_origin_mode;
                self.charset_g0_dec_special = self.saved_charset_g0_dec_special;
                self.charset_g1_dec_special = self.saved_charset_g1_dec_special;
                self.charset_use_g1 = self.saved_charset_use_g1;
            },
            else => {},
        }
    }

    fn replyDeviceStatus(self: *Grid, csi: *const VtParser.Csi) void {
        const request = csi.valueOr(0, 0);
        if (request == 5 and csi.private_marker == 0) {
            self.appendReply("\x1b[0n");
        } else if (request == 6) {
            if (csi.private_marker == '?') {
                self.appendFormattedReply(
                    "\x1b[?{d};{d}R",
                    .{ self.cursor_row + 1, self.cursor_column + 1 },
                );
            } else if (csi.private_marker == 0) {
                self.appendFormattedReply(
                    "\x1b[{d};{d}R",
                    .{ self.cursor_row + 1, self.cursor_column + 1 },
                );
            }
        }
    }

    fn replyModeStatus(self: *Grid, csi: *const VtParser.Csi) void {
        const mode = csi.valueOr(0, 0);
        const status: u8 = if (self.modeStatus(csi.private_marker == '?', mode)) |enabled|
            if (enabled) 1 else 2
        else
            0;
        if (csi.private_marker == '?') {
            self.appendFormattedReply("\x1b[?{d};{d}$y", .{ mode, status });
        } else if (csi.private_marker == 0) {
            self.appendFormattedReply("\x1b[{d};{d}$y", .{ mode, status });
        }
    }

    fn modeStatus(self: Grid, private: bool, mode: u16) ?bool {
        if (!private) return if (mode == 4) self.insert_mode else null;
        return switch (mode) {
            1 => self.application_cursor_keys,
            6 => self.origin_mode,
            7 => self.auto_wrap,
            25 => self.cursor_visible,
            47, 1047, 1049 => self.alternate_cells != null,
            1000 => self.mouse_tracking == .normal,
            1002 => self.mouse_tracking == .button_event,
            1003 => self.mouse_tracking == .any_event,
            1004 => self.focus_reporting,
            1006 => self.mouse_encoding == .sgr,
            2004 => self.bracketed_paste,
            2026 => self.synchronized_output,
            else => null,
        };
    }

    fn applyMode(self: *Grid, private: bool, mode: u16, enabled: bool) void {
        if (!private and mode == 4) {
            self.insert_mode = enabled;
            return;
        }
        if (!private) return;
        switch (mode) {
            1 => self.application_cursor_keys = enabled,
            6 => {
                self.origin_mode = enabled;
                self.cursor_row = if (enabled) self.margin_top else 0;
                self.cursor_column = 0;
            },
            7 => self.auto_wrap = enabled,
            25 => self.cursor_visible = enabled,
            47, 1047, 1049 => if (enabled) self.enterAlternate() else self.leaveAlternate(),
            1000, 1002, 1003 => {
                const requested: MouseTracking = switch (mode) {
                    1000 => .normal,
                    1002 => .button_event,
                    1003 => .any_event,
                    else => unreachable,
                };
                if (enabled) {
                    self.mouse_tracking = requested;
                } else if (self.mouse_tracking == requested) {
                    self.mouse_tracking = .none;
                }
            },
            1004 => self.focus_reporting = enabled,
            1006 => self.mouse_encoding = if (enabled) .sgr else .legacy,
            2004 => self.bracketed_paste = enabled,
            2026 => {
                if (enabled and !self.synchronized_output)
                    self.synchronized_output_begins +%= 1;
                self.synchronized_output = enabled;
            },
            else => {},
        }
    }

    fn applySgrSequence(self: *Grid, csi: *const VtParser.Csi) void {
        var index: usize = 0;
        while (index < csi.parameter_count) : (index += 1) {
            const parameter = csi.parameter(index);
            const value = parameter.valueOr(0, 0);
            if ((value == 38 or value == 48) and parameter.count > 1) {
                self.applyColonColor(value == 38, parameter);
                continue;
            }
            if ((value == 38 or value == 48) and index + 1 < csi.parameter_count) {
                const model = csi.valueOr(index + 1, 0);
                if (model == 5 and index + 2 < csi.parameter_count) {
                    self.setColor(value == 38, @intCast(@min(csi.valueOr(index + 2, 0), 255)));
                    index += 2;
                    continue;
                }
                if (model == 2 and index + 4 < csi.parameter_count) {
                    self.setTrueColor(
                        value == 38,
                        csi.valueOr(index + 2, 0),
                        csi.valueOr(index + 3, 0),
                        csi.valueOr(index + 4, 0),
                    );
                    index += 4;
                    continue;
                }
            }
            self.applySgr(value);
        }
    }

    fn applyColonColor(self: *Grid, foreground: bool, parameter: *const VtParser.Parameter) void {
        const model = parameter.valueOr(1, 0);
        if (model == 5 and parameter.isPresent(2)) {
            self.setColor(foreground, @intCast(@min(parameter.valueOr(2, 0), 255)));
            return;
        }
        if (model != 2) return;
        const first_component: usize = if (parameter.count >= 6 and !parameter.isPresent(2)) 3 else 2;
        if (first_component + 2 >= parameter.count) return;
        self.setTrueColor(
            foreground,
            parameter.valueOr(first_component, 0),
            parameter.valueOr(first_component + 1, 0),
            parameter.valueOr(first_component + 2, 0),
        );
    }

    fn setTrueColor(self: *Grid, foreground: bool, red: u16, green: u16, blue: u16) void {
        const rgb = (@as(u32, @min(red, 255)) << 16) |
            (@as(u32, @min(green, 255)) << 8) |
            @as(u32, @min(blue, 255));
        self.setColor(foreground, self.internTrueColor(rgb));
    }

    fn setColor(self: *Grid, foreground: bool, color: u16) void {
        if (foreground) self.foreground = color else self.background = color;
    }

    fn internTrueColor(self: *Grid, rgb: u32) u16 {
        for (self.true_colors.items, 0..) |existing, index| {
            if (existing == rgb) return @intCast(first_truecolor_id + index);
        }
        if (self.true_colors.items.len >= max_truecolor_count)
            return nearestPaletteColor(rgb);
        self.true_colors.append(rgb) catch return nearestPaletteColor(rgb);
        return @intCast(first_truecolor_id + self.true_colors.items.len - 1);
    }

    fn applySgr(self: *Grid, value: usize) void {
        switch (value) {
            0 => {
                self.bold = false;
                self.inverse = false;
                self.italic = false;
                self.underline = false;
                self.strikethrough = false;
                self.dim = false;
                self.foreground = default_color_id;
                self.background = default_color_id;
            },
            1 => self.bold = true,
            2 => self.dim = true,
            3 => self.italic = true,
            4, 21 => self.underline = true,
            7 => self.inverse = true,
            9 => self.strikethrough = true,
            22 => {
                self.bold = false;
                self.dim = false;
            },
            23 => self.italic = false,
            24 => self.underline = false,
            27 => self.inverse = false,
            29 => self.strikethrough = false,
            30...37 => self.foreground = @intCast(value - 30),
            40...47 => self.background = @intCast(value - 40),
            39 => self.foreground = default_color_id,
            49 => self.background = default_color_id,
            90...97 => self.foreground = @intCast(value - 90 + 8),
            100...107 => self.background = @intCast(value - 100 + 8),
            else => {},
        }
    }

    fn eraseLine(self: *Grid, mode: usize) void {
        const start = if (mode == 1) 0 else self.cursor_column;
        const end = if (mode == 1) self.cursor_column + 1 else self.columns;
        self.touchRow(self.cursor_row);
        self.markDirtySpan(self.cursor_row, start, end);
        const current_row = self.rowSlice(self.cursor_row);
        if (mode == 2)
            @memset(current_row, .{})
        else
            @memset(current_row[start..@min(end, self.columns)], .{});
    }

    fn insertCharacters(self: *Grid, count: usize) void {
        self.touchRow(self.cursor_row);
        const current_row = self.rowSlice(self.cursor_row);
        const column = self.cursor_column;
        const amount = @min(count, self.columns - column);
        self.markDirtySpan(self.cursor_row, column, self.columns);
        std.mem.copyBackwards(Cell, current_row[column + amount ..], current_row[column .. self.columns - amount]);
        @memset(current_row[column .. column + amount], .{});
    }

    fn deleteCharacters(self: *Grid, count: usize) void {
        self.touchRow(self.cursor_row);
        const current_row = self.rowSlice(self.cursor_row);
        const column = self.cursor_column;
        const amount = @min(count, self.columns - column);
        self.markDirtySpan(self.cursor_row, column, self.columns);
        std.mem.copyForwards(Cell, current_row[column .. self.columns - amount], current_row[column + amount ..]);
        @memset(current_row[self.columns - amount ..], .{});
    }

    fn eraseCharacters(self: *Grid, count: usize) void {
        const amount = @min(count, self.columns - self.cursor_column);
        self.touchRow(self.cursor_row);
        self.markDirtySpan(
            self.cursor_row,
            self.cursor_column,
            self.cursor_column + amount,
        );
        const current_row = self.rowSlice(self.cursor_row);
        @memset(current_row[self.cursor_column .. self.cursor_column + amount], .{});
    }

    fn insertLines(self: *Grid, count: usize) void {
        if (self.cursor_row < self.margin_top or self.cursor_row > self.margin_bottom) return;
        self.markDirtyRange(self.cursor_row, self.margin_bottom);
        const amount = @min(count, self.margin_bottom - self.cursor_row + 1);
        var logical_row = self.margin_bottom + 1;
        while (logical_row > self.cursor_row + amount) {
            logical_row -= 1;
            @memcpy(self.rowSlice(logical_row), self.constRowSlice(logical_row - amount));
            self.rowMeta(logical_row).* = self.constRowMeta(logical_row - amount);
        }
        for (self.cursor_row..self.cursor_row + amount) |row_index| {
            @memset(self.rowSlice(row_index), .{});
            self.rowMeta(row_index).* = self.freshRowMeta();
        }
    }

    fn deleteLines(self: *Grid, count: usize) void {
        if (self.cursor_row < self.margin_top or self.cursor_row > self.margin_bottom) return;
        self.markDirtyRange(self.cursor_row, self.margin_bottom);
        const amount = @min(count, self.margin_bottom - self.cursor_row + 1);
        const moved_end = self.margin_bottom + 1 - amount;
        for (self.cursor_row..moved_end) |logical_row| {
            @memcpy(self.rowSlice(logical_row), self.constRowSlice(logical_row + amount));
            self.rowMeta(logical_row).* = self.constRowMeta(logical_row + amount);
        }
        for (moved_end..self.margin_bottom + 1) |logical_row| {
            @memset(self.rowSlice(logical_row), .{});
            self.rowMeta(logical_row).* = self.freshRowMeta();
        }
    }

    fn eraseDisplay(self: *Grid, mode: usize) void {
        if (mode == 3) {
            self.clearHistory();
        } else if (mode == 2) {
            self.markAllDirty();
            @memset(self.cells, .{});
            for (0..self.rows) |row| self.rowMeta(row).* = self.freshRowMeta();
        } else if (mode == 0) {
            self.touchRow(self.cursor_row);
            self.markDirtyRange(self.cursor_row, self.rows - 1);
            @memset(self.rowSlice(self.cursor_row)[self.cursor_column..], .{});
            for (self.cursor_row + 1..self.rows) |logical_row| {
                @memset(self.rowSlice(logical_row), .{});
                self.rowMeta(logical_row).* = self.freshRowMeta();
            }
        } else if (mode == 1) {
            self.touchRow(self.cursor_row);
            self.markDirtyRange(0, self.cursor_row);
            for (0..self.cursor_row) |logical_row| {
                @memset(self.rowSlice(logical_row), .{});
                self.rowMeta(logical_row).* = self.freshRowMeta();
            }
            @memset(self.rowSlice(self.cursor_row)[0 .. self.cursor_column + 1], .{});
        }
    }

    fn clearHistory(self: *Grid) void {
        for (0..self.history.items.len) |record_slot|
            self.discardHistoryRecord(record_slot);
        self.history.clearRetainingCapacity();
        self.history_meta.clearRetainingCapacity();
        self.history_cold.clearRetainingCapacity();
        self.cold_bytes.clearRetainingCapacity();
        self.cold_glyphs.clearRetainingCapacity();
        self.cold_runs.clearRetainingCapacity();
        self.cold_dead_bytes = 0;
        self.cold_dead_glyphs = 0;
        self.cold_dead_runs = 0;
        self.history_start = 0;
        self.history_next_hot = 0;
        self.viewport_offset = 0;
        self.markAllDirty();
    }

    fn enterAlternate(self: *Grid) void {
        if (self.alternate_cells != null) return;
        const alternate = self.allocator.alloc(Cell, self.cells.len) catch return;
        const alternate_meta = self.allocator.alloc(RowMeta, self.rows) catch {
            self.allocator.free(alternate);
            return;
        };
        @memset(alternate, .{});
        for (alternate_meta) |*meta| meta.* = self.freshRowMeta();
        self.alternate_cells = self.cells;
        self.alternate_row_meta = self.row_meta;
        self.alternate_screen_origin = self.screen_origin;
        self.cells = alternate;
        self.row_meta = alternate_meta;
        self.screen_origin = 0;
        self.alternate_saved_cursor_column = self.cursor_column;
        self.alternate_saved_cursor_row = self.cursor_row;
        self.alternate_saved_wrap_pending = self.wrap_pending;
        self.alternate_saved_margin_top = self.margin_top;
        self.alternate_saved_margin_bottom = self.margin_bottom;
        self.alternate_saved_origin_mode = self.origin_mode;
        self.cursor_column = 0;
        self.cursor_row = 0;
        self.wrap_pending = false;
        self.margin_top = 0;
        self.margin_bottom = self.rows - 1;
        self.origin_mode = false;
        self.markAllDirty();
    }

    fn leaveAlternate(self: *Grid) void {
        const primary = self.alternate_cells orelse return;
        const primary_meta = self.alternate_row_meta orelse return;
        self.allocator.free(self.cells);
        self.allocator.free(self.row_meta);
        self.cells = primary;
        self.row_meta = primary_meta;
        self.screen_origin = self.alternate_screen_origin;
        self.alternate_cells = null;
        self.alternate_row_meta = null;
        self.alternate_screen_origin = 0;
        self.cursor_column = self.alternate_saved_cursor_column;
        self.cursor_row = self.alternate_saved_cursor_row;
        self.wrap_pending = self.alternate_saved_wrap_pending;
        self.margin_top = self.alternate_saved_margin_top;
        self.margin_bottom = self.alternate_saved_margin_bottom;
        self.origin_mode = self.alternate_saved_origin_mode;
        self.markAllDirty();
    }
};

fn isDefaultCell(value: Cell) bool {
    return std.meta.eql(value, Cell{});
}

fn coldStyle(value: Cell) ColdStyle {
    return .{
        .bold = value.flags.bold,
        .inverse = value.flags.inverse,
        .italic = value.flags.italic,
        .underline = value.flags.underline,
        .strikethrough = value.flags.strikethrough,
        .dim = value.flags.dim,
        .foreground = @intCast(value.foreground),
        .background = @intCast(value.background),
        .hyperlink_id = @intCast(value.hyperlink_id),
    };
}

fn cellFromColdStyle(style: ColdStyle) Cell {
    return .{
        .flags = .{
            .bold = style.bold,
            .inverse = style.inverse,
            .italic = style.italic,
            .underline = style.underline,
            .strikethrough = style.strikethrough,
            .dim = style.dim,
        },
        .foreground = style.foreground,
        .background = style.background,
        .hyperlink_id = style.hyperlink_id,
    };
}

fn resizeCellBuffer(
    allocator: std.mem.Allocator,
    source: []const Cell,
    source_columns: usize,
    source_rows: usize,
    source_origin: usize,
    columns: usize,
    rows: usize,
) ![]Cell {
    const cells = try allocator.alloc(Cell, columns * rows);
    @memset(cells, .{});
    const copy_columns = @min(source_columns, columns);
    const copy_rows = @min(source_rows, rows);
    for (0..copy_rows) |row| {
        const candidate = source_origin + row;
        const source_row = if (candidate >= source_rows) candidate - source_rows else candidate;
        @memcpy(
            cells[row * columns .. row * columns + copy_columns],
            source[source_row * source_columns .. source_row * source_columns + copy_columns],
        );
    }
    return cells;
}

fn foldSearchCodepoint(codepoint: u21) u21 {
    if (codepoint >= 'A' and codepoint <= 'Z') return codepoint + 32;
    if ((codepoint >= 0x00c0 and codepoint <= 0x00d6) or
        (codepoint >= 0x00d8 and codepoint <= 0x00de)) return codepoint + 32;
    return codepoint;
}

fn copyBounded(destination: []u8, source: []const u8) ?usize {
    if (source.len > destination.len) return null;
    @memcpy(destination[0..source.len], source);
    return source.len;
}

fn decodeHex(source: []const u8, output: *[32]u8) ?[]const u8 {
    if (source.len == 0 or source.len % 2 != 0 or source.len / 2 > output.len)
        return null;
    var index: usize = 0;
    while (index < source.len) : (index += 2) {
        const high = hexValue(source[index]) orelse return null;
        const low = hexValue(source[index + 1]) orelse return null;
        output[index / 2] = (high << 4) | low;
    }
    return output[0 .. source.len / 2];
}

fn hexValue(byte: u8) ?u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        'A'...'F' => byte - 'A' + 10,
        else => null,
    };
}

fn hexDigit(value: u8) u8 {
    return if (value < 10) '0' + value else 'a' + value - 10;
}

const ansi_palette = [_]u32{
    0x1a1a1f, 0xcc3333, 0x40b34d, 0xcca633,
    0x4073d9, 0xb34db3, 0x33a6b3, 0xc7c7d1,
    0x595966, 0xff5959, 0x66e673, 0xffd959,
    0x6699ff, 0xf273f2, 0x59e6f2, 0xffffff,
};

fn paletteColor(color_id: u16) u32 {
    if (color_id < ansi_palette.len) return ansi_palette[color_id];
    if (color_id < 232) {
        const offset = color_id - 16;
        const red = xtermCubeComponent(offset / 36);
        const green = xtermCubeComponent((offset / 6) % 6);
        const blue = xtermCubeComponent(offset % 6);
        return (@as(u32, red) << 16) | (@as(u32, green) << 8) | blue;
    }
    if (color_id < 256) {
        const gray: u32 = 8 + @as(u32, color_id - 232) * 10;
        return (gray << 16) | (gray << 8) | gray;
    }
    return 0xffffffff;
}

fn xtermCubeComponent(value: u16) u32 {
    return if (value == 0) 0 else 55 + @as(u32, value) * 40;
}

fn nearestPaletteColor(rgb: u32) u16 {
    const red = @as(i32, @intCast((rgb >> 16) & 0xff));
    const green = @as(i32, @intCast((rgb >> 8) & 0xff));
    const blue = @as(i32, @intCast(rgb & 0xff));
    var best: u16 = 0;
    var best_distance: u32 = std.math.maxInt(u32);
    for (0..256) |index| {
        const candidate = paletteColor(@intCast(index));
        const delta_red = red - @as(i32, @intCast((candidate >> 16) & 0xff));
        const delta_green = green - @as(i32, @intCast((candidate >> 8) & 0xff));
        const delta_blue = blue - @as(i32, @intCast(candidate & 0xff));
        const distance: u32 = @intCast(
            delta_red * delta_red + delta_green * delta_green + delta_blue * delta_blue,
        );
        if (distance < best_distance) {
            best_distance = distance;
            best = @intCast(index);
        }
    }
    return best;
}

fn decodeSearchQuery(bytes: []const u8, output: *[128]u21) ?usize {
    var used: usize = 0;
    var index: usize = 0;
    while (index < bytes.len) {
        if (used >= output.len) return null;
        const first = bytes[index];
        var codepoint: u21 = undefined;
        var length: usize = 1;
        if (first < 0x80) {
            codepoint = first;
        } else if (first >= 0xc2 and first <= 0xdf and index + 1 < bytes.len) {
            codepoint = (@as(u21, first & 0x1f) << 6) | (bytes[index + 1] & 0x3f);
            length = 2;
        } else if (first >= 0xe0 and first <= 0xef and index + 2 < bytes.len) {
            codepoint = (@as(u21, first & 0x0f) << 12) |
                (@as(u21, bytes[index + 1] & 0x3f) << 6) |
                (bytes[index + 2] & 0x3f);
            length = 3;
        } else if (first >= 0xf0 and first <= 0xf4 and index + 3 < bytes.len) {
            codepoint = (@as(u21, first & 0x07) << 18) |
                (@as(u21, bytes[index + 1] & 0x3f) << 12) |
                (@as(u21, bytes[index + 2] & 0x3f) << 6) |
                (bytes[index + 3] & 0x3f);
            length = 4;
        } else return null;
        for (bytes[index + 1 .. index + length]) |continuation| {
            if (continuation < 0x80 or continuation > 0xbf) return null;
        }
        output[used] = codepoint;
        used += 1;
        index += length;
    }
    return used;
}

fn encodeCodepoint(codepoint: u21, output: []u8) !usize {
    if (codepoint < 0x80) {
        if (output.len < 1) return error.NoSpaceLeft;
        output[0] = @intCast(codepoint);
        return 1;
    }
    if (codepoint <= 0x7ff) {
        if (output.len < 2) return error.NoSpaceLeft;
        output[0] = @intCast(0xc0 | (codepoint >> 6));
        output[1] = @intCast(0x80 | (codepoint & 0x3f));
        return 2;
    }
    if (codepoint <= 0xffff) {
        if (output.len < 3) return error.NoSpaceLeft;
        output[0] = @intCast(0xe0 | (codepoint >> 12));
        output[1] = @intCast(0x80 | ((codepoint >> 6) & 0x3f));
        output[2] = @intCast(0x80 | (codepoint & 0x3f));
        return 3;
    }
    if (output.len < 4) return error.NoSpaceLeft;
    output[0] = @intCast(0xf0 | (codepoint >> 18));
    output[1] = @intCast(0x80 | ((codepoint >> 12) & 0x3f));
    output[2] = @intCast(0x80 | ((codepoint >> 6) & 0x3f));
    output[3] = @intCast(0x80 | (codepoint & 0x3f));
    return 4;
}

pub fn publicVtAvailable() bool {
    return GhosttyVt.available();
}

pub fn publicPasteIsSafe(bytes: []const u8) bool {
    return GhosttyVt.pasteIsSafe(bytes);
}

fn fixtureNibble(value: u8) !u8 {
    return switch (value) {
        '0'...'9' => value - '0',
        'a'...'f' => value - 'a' + 10,
        'A'...'F' => value - 'A' + 10,
        else => error.InvalidFixtureHex,
    };
}

fn decodeFixtureHex(encoded: []const u8, output: []u8) ![]const u8 {
    if (std.mem.eql(u8, encoded, "-")) return output[0..0];
    if (encoded.len % 2 != 0 or encoded.len / 2 > output.len)
        return error.InvalidFixtureHex;
    for (0..encoded.len / 2) |index| {
        output[index] = (try fixtureNibble(encoded[index * 2])) << 4 |
            try fixtureNibble(encoded[index * 2 + 1]);
    }
    return output[0 .. encoded.len / 2];
}

fn feedFixtureChunks(grid: *Grid, bytes: []const u8, seed: usize) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const count = @min(bytes.len - offset, 1 + (offset * 17 + seed * 13) % 47);
        try grid.feed(bytes[offset .. offset + count]);
        offset += count;
    }
}

fn nextFixtureByte(state: *u64) u8 {
    state.* ^= state.* << 13;
    state.* ^= state.* >> 7;
    state.* ^= state.* << 17;
    return @truncate(state.*);
}

test "terminal compatibility corpus matches bounded protocol replies and state" {
    var lines = std.mem.splitScalar(
        u8,
        @embedFile("fixtures/agent-compat-vt-corpus.tsv"),
        '\n',
    );
    var case_count: usize = 0;
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \r");
        if (line.len == 0 or line[0] == '#') continue;
        var fields = std.mem.splitScalar(u8, line, '\t');
        const name = fields.next() orelse return error.InvalidFixture;
        const input_hex = fields.next() orelse return error.InvalidFixture;
        const reply_hex = fields.next() orelse return error.InvalidFixture;
        const expected_column = try std.fmt.parseInt(usize, fields.next() orelse return error.InvalidFixture, 10);
        const expected_row = try std.fmt.parseInt(usize, fields.next() orelse return error.InvalidFixture, 10);
        const expected_bracketed = std.mem.eql(u8, fields.next() orelse return error.InvalidFixture, "1");
        const expected_synchronized = std.mem.eql(u8, fields.next() orelse return error.InvalidFixture, "1");
        const expected_blocked_osc52 = try std.fmt.parseInt(
            u64,
            fields.next() orelse return error.InvalidFixture,
            10,
        );
        const title = fields.next() orelse return error.InvalidFixture;
        if (fields.next() != null) return error.InvalidFixture;

        var input_buffer: [512]u8 = undefined;
        var reply_buffer: [512]u8 = undefined;
        const input = try decodeFixtureHex(input_hex, &input_buffer);
        const expected_reply = try decodeFixtureHex(reply_hex, &reply_buffer);
        const expected_title = if (std.mem.eql(u8, title, "-")) "" else title;
        var grid = try Grid.init(std.testing.allocator, 80, 24);
        defer grid.deinit();
        try grid.feed(input);

        if (!std.mem.eql(u8, expected_reply, grid.pendingReplies()))
            std.debug.print("protocol corpus reply mismatch: {s}\n", .{name});
        try std.testing.expectEqualStrings(expected_reply, grid.pendingReplies());
        try std.testing.expectEqual(expected_column, grid.cursor_column);
        try std.testing.expectEqual(expected_row, grid.cursor_row);
        try std.testing.expectEqual(expected_bracketed, grid.bracketed_paste);
        try std.testing.expectEqual(expected_synchronized, grid.synchronized_output);
        try std.testing.expectEqual(expected_blocked_osc52, grid.blocked_osc52);
        try std.testing.expectEqualStrings(expected_title, grid.titleSlice());
        case_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 23), case_count);
}

test "terminal parser is deterministic across malformed corpus chunk boundaries" {
    for (0..64) |seed| {
        var bytes: [2048]u8 = undefined;
        var random_state: u64 = 0x9e3779b97f4a7c15 ^ @as(u64, seed + 1);
        for (&bytes, 0..) |*byte, index| {
            byte.* = nextFixtureByte(&random_state);
            if (index % 113 == 0) byte.* = 0x1b;
            if (index % 113 == 1) byte.* = '[';
            if (index % 127 == 2) byte.* = ']';
        }

        var direct = try Grid.initWithHistoryLimit(std.testing.allocator, 32, 8, 64);
        defer direct.deinit();
        var chunked = try Grid.initWithHistoryLimit(std.testing.allocator, 32, 8, 64);
        defer chunked.deinit();
        try direct.feed(bytes[0 .. bytes.len / 2]);
        try feedFixtureChunks(&chunked, bytes[0 .. bytes.len / 2], seed);
        const columns = 8 + seed % 41;
        const rows = 2 + seed % 11;
        try direct.resize(columns, rows);
        try chunked.resize(columns, rows);
        try direct.feed(bytes[bytes.len / 2 ..]);
        try feedFixtureChunks(&chunked, bytes[bytes.len / 2 ..], seed + 1);

        try std.testing.expectEqual(direct.cursor_column, chunked.cursor_column);
        try std.testing.expectEqual(direct.cursor_row, chunked.cursor_row);
        try std.testing.expectEqual(direct.saved_wrap_pending, chunked.saved_wrap_pending);
        try std.testing.expectEqual(direct.saved_origin_mode, chunked.saved_origin_mode);
        try std.testing.expectEqual(
            direct.alternate_saved_cursor_column,
            chunked.alternate_saved_cursor_column,
        );
        try std.testing.expectEqual(
            direct.alternate_saved_cursor_row,
            chunked.alternate_saved_cursor_row,
        );
        try std.testing.expectEqual(
            direct.alternate_saved_wrap_pending,
            chunked.alternate_saved_wrap_pending,
        );
        try std.testing.expectEqual(
            direct.alternate_saved_margin_top,
            chunked.alternate_saved_margin_top,
        );
        try std.testing.expectEqual(
            direct.alternate_saved_margin_bottom,
            chunked.alternate_saved_margin_bottom,
        );
        try std.testing.expectEqual(
            direct.alternate_saved_origin_mode,
            chunked.alternate_saved_origin_mode,
        );
        try std.testing.expectEqual(
            direct.saved_charset_g0_dec_special,
            chunked.saved_charset_g0_dec_special,
        );
        try std.testing.expectEqual(
            direct.saved_charset_g1_dec_special,
            chunked.saved_charset_g1_dec_special,
        );
        try std.testing.expectEqual(
            direct.saved_charset_use_g1,
            chunked.saved_charset_use_g1,
        );
        try std.testing.expectEqual(direct.wrap_pending, chunked.wrap_pending);
        try std.testing.expectEqual(direct.origin_mode, chunked.origin_mode);
        try std.testing.expectEqual(
            direct.charset_g0_dec_special,
            chunked.charset_g0_dec_special,
        );
        try std.testing.expectEqual(
            direct.charset_g1_dec_special,
            chunked.charset_g1_dec_special,
        );
        try std.testing.expectEqual(direct.charset_use_g1, chunked.charset_use_g1);
        try std.testing.expectEqual(
            direct.last_printed_codepoint,
            chunked.last_printed_codepoint,
        );
        try std.testing.expectEqual(direct.parser.state, chunked.parser.state);
        try std.testing.expectEqual(direct.bracketed_paste, chunked.bracketed_paste);
        try std.testing.expectEqual(direct.synchronized_output, chunked.synchronized_output);
        try std.testing.expectEqual(direct.history.items.len, chunked.history.items.len);
        try std.testing.expectEqualStrings(direct.titleSlice(), chunked.titleSlice());
        try std.testing.expectEqualStrings(direct.pendingReplies(), chunked.pendingReplies());
        try std.testing.expect(direct.pendingReplies().len <= direct.reply_buffer.len);
        try std.testing.expect(direct.history.items.len <= direct.history_limit);
        var direct_row: [48]u64 = undefined;
        var chunked_row: [48]u64 = undefined;
        for (0..rows) |row| {
            const direct_count = direct.packedRow(row, &direct_row);
            const chunked_count = chunked.packedRow(row, &chunked_row);
            try std.testing.expectEqual(direct_count, chunked_count);
            try std.testing.expectEqualSlices(
                u64,
                direct_row[0..direct_count],
                chunked_row[0..chunked_count],
            );
        }
    }
}

test "zig terminal grid consumes shell output and public VT paste utility" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("hello\x1b[2;1H\x1b[1;31mworld\x1b]2;NOCTTY\x07");
    try std.testing.expectEqual(@as(u21, 'w'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u32, 1), grid.styleBits(0, 1) & 1);
    const packed_value = grid.packedCell(0, 1);
    try std.testing.expectEqual(@as(u32, 'w'), @as(u32, @truncate(packed_value)));
    try std.testing.expectEqual(grid.styleBits(0, 1), @as(u32, @truncate(packed_value >> 32)));
    var packed_row: [8]u64 = undefined;
    try std.testing.expectEqual(@as(usize, 8), grid.packedRow(1, &packed_row));
    try std.testing.expectEqual(packed_value, packed_row[0]);
    const packed_before = packed_row[0];
    try grid.feed("\x1b[2;1Hz");
    try std.testing.expectEqual(@as(usize, 8), grid.packedRow(1, &packed_row));
    try std.testing.expect(packed_before != packed_row[0]);
    try std.testing.expectEqual(@as(u16, 1), grid.cell(0, 1).foreground);
    try std.testing.expectEqualStrings("NOCTTY", grid.titleSlice());
    try std.testing.expect(publicVtAvailable());
    try std.testing.expect(publicPasteIsSafe("plain text"));
}

test "terminal grid printable run path matches byte feeding" {
    const input = "\x1b[1;31mABCDEFGHIJK\r\nsecond line\r\ncaf\xc3\xa9\x1b[0m\r\nlast\x1b]2;fast-path\x07";
    var fast = try Grid.init(std.testing.allocator, 8, 3);
    defer fast.deinit();
    var bytewise = try Grid.init(std.testing.allocator, 8, 3);
    defer bytewise.deinit();

    try fast.feed(input);
    for (input) |byte| try bytewise.feedByte(byte);

    try std.testing.expectEqual(bytewise.cursor_column, fast.cursor_column);
    try std.testing.expectEqual(bytewise.cursor_row, fast.cursor_row);
    try std.testing.expectEqual(bytewise.wrap_pending, fast.wrap_pending);
    try std.testing.expectEqual(bytewise.screen_origin, fast.screen_origin);
    try std.testing.expectEqual(bytewise.history.items.len, fast.history.items.len);
    try std.testing.expectEqualStrings(bytewise.titleSlice(), fast.titleSlice());
    const total_lines = fast.history.items.len + fast.rows;
    for (0..total_lines) |line_index| {
        for (0..fast.columns) |column| {
            try std.testing.expectEqualDeep(
                bytewise.lineCell(line_index, column),
                fast.lineCell(line_index, column),
            );
        }
    }
}

test "terminal grid applies rich SGR and bounded truecolor IDs" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("\x1b[1;2;3;4;9;38;5;202;48;2;1;2;3mX" ++
        "\x1b[22;23;24;29;38:2::10:20:30;48:5:17mY");

    const first = grid.cell(0, 0);
    try std.testing.expect(first.flags.bold);
    try std.testing.expect(first.flags.dim);
    try std.testing.expect(first.flags.italic);
    try std.testing.expect(first.flags.underline);
    try std.testing.expect(first.flags.strikethrough);
    try std.testing.expectEqual(@as(u16, 202), first.foreground);
    try std.testing.expect(first.background >= first_truecolor_id);
    try std.testing.expectEqual(@as(u32, 0x010203), grid.colorRgb(first.background));

    const second = grid.cell(1, 0);
    try std.testing.expect(!second.flags.bold and !second.flags.dim and !second.flags.italic);
    try std.testing.expect(!second.flags.underline and !second.flags.strikethrough);
    try std.testing.expectEqual(@as(u32, 0x0a141e), grid.colorRgb(second.foreground));
    try std.testing.expectEqual(@as(u16, 17), second.background);
    try std.testing.expectEqual(second.foreground, @as(u16, @truncate((grid.styleBits(1, 0) >> 8) & 0xfff)));
    try std.testing.expectEqual(second.background, @as(u16, @truncate(grid.styleBits(1, 0) >> 20)));

    for (0..max_truecolor_count + 32) |index| {
        const rgb: u32 = @intCast(index * 4093 % 0x1000000);
        _ = grid.internTrueColor(rgb);
    }
    try std.testing.expectEqual(max_truecolor_count, grid.true_colors.items.len);
}

test "terminal grid returns blank cells for stale renderer dimensions" {
    var grid = try Grid.init(std.testing.allocator, 4, 2);
    defer grid.deinit();
    try grid.feed("\x1b[1;31mX");
    try grid.resize(2, 1);

    const blank = Cell{};
    try std.testing.expectEqualDeep(blank, grid.cell(2, 0));
    try std.testing.expectEqualDeep(blank, grid.cell(0, 1));
    try std.testing.expectEqual(@as(u32, 0xffffff00), grid.styleBits(2, 0));
}

test "terminal grid searches scrollback and preserves unicode when exporting" {
    var grid = try Grid.init(std.testing.allocator, 12, 2);
    defer grid.deinit();
    try grid.feed("first line\r\nsecond café\r\nthird line\r\nfourth line");

    const found = grid.findText("CAFÉ", true, 0) orelse return error.SearchMatchMissing;
    try std.testing.expectEqual(@as(usize, 1), found.matches);
    try std.testing.expect(found.viewport_offset > 0);
    try std.testing.expectEqual(@as(usize, 7), found.column);

    var output: [512]u8 = undefined;
    const length = try grid.writeScrollback(&output);
    try std.testing.expect(std.mem.indexOf(u8, output[0..length], "second café") != null);
}

test "terminal grid records bell attention serials" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("ready\x07\x07");
    try std.testing.expectEqual(@as(u64, 2), grid.bell_serial);
}

test "terminal grid retains scrollback for wheel navigation" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    try grid.feed("one\ntwo\nthree");
    try std.testing.expect(grid.history.items.len >= 1);
    grid.scrollViewport(@intCast(grid.history.items.len));
    try std.testing.expectEqual(@as(u21, 'o'), grid.cell(0, 0).codepoint);
    grid.scrollViewport(-@as(isize, @intCast(grid.history.items.len)));
    try std.testing.expectEqual(@as(usize, 0), grid.viewport_offset);
}

test "terminal grid keeps a scrolled viewport stable while output continues" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    try grid.feed("alpha\r\nbravo\r\ncharly\r\ndelta");

    grid.scrollViewport(1);
    try std.testing.expectEqual(@as(u21, 'a'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'b'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 'c'), grid.cell(0, 2).codepoint);

    try grid.feed("\r\necho");
    try std.testing.expectEqual(@as(usize, 2), grid.viewport_offset);
    try std.testing.expectEqual(@as(u21, 'a'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'b'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 'c'), grid.cell(0, 2).codepoint);
}

test "terminal grid rotates full-screen rows and blends viewport history" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();

    const allocation = grid.cells.ptr;
    try grid.feed("alpha\r\nbravo\r\ncharly\r\ndelta");

    try std.testing.expectEqual(allocation, grid.cells.ptr);
    try std.testing.expectEqual(@as(usize, 1), grid.screen_origin);
    try std.testing.expectEqual(@as(u21, 'b'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'c'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 'd'), grid.cell(0, 2).codepoint);

    grid.scrollViewport(1);
    try std.testing.expectEqual(@as(u21, 'a'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'b'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 'c'), grid.cell(0, 2).codepoint);
}

test "terminal grid preserves logical operations across wrapped physical rows" {
    var grid = try Grid.init(std.testing.allocator, 8, 4);
    defer grid.deinit();
    try grid.feed("zero\r\none\r\ntwo\r\nthree\r\nfour");
    try std.testing.expectEqual(@as(usize, 1), grid.screen_origin);

    try grid.feed("\x1b[3;4r\x1b[4;1HNEW\r\nlast");
    try std.testing.expectEqual(@as(u21, 'o'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 't'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 'N'), grid.cell(0, 2).codepoint);
    try std.testing.expectEqual(@as(u21, 'l'), grid.cell(0, 3).codepoint);

    try grid.feed("\x1b[r\x1b[2;1H\x1b[1L");
    try std.testing.expectEqual(@as(u21, ' '), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 't'), grid.cell(0, 2).codepoint);
    try grid.feed("\x1b[2;1H\x1b[1M");
    try std.testing.expectEqual(@as(u21, 't'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 'N'), grid.cell(0, 2).codepoint);
}

test "terminal grid keeps rotated primary screen through alternate resize" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    try grid.feed("alpha\r\nbravo\r\ncharly\r\ndelta");
    const history_count = grid.history.items.len;

    try grid.feed("\x1b[?1049halt-1\r\nalt-2\r\nalt-3\r\nalt-4");
    try std.testing.expectEqual(history_count, grid.history.items.len);
    try grid.resize(10, 4);
    try grid.feed("\x1b[?1049l");

    try std.testing.expectEqual(@as(usize, 0), grid.screen_origin);
    try std.testing.expectEqual(@as(u21, 'a'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'b'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 'c'), grid.cell(0, 2).codepoint);
    try std.testing.expectEqual(@as(u21, 'd'), grid.cell(0, 3).codepoint);
}

test "terminal grid caps scrollback without shifting retained history" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();

    var buffer: [16]u8 = undefined;
    for (0..Grid.default_history_lines + 8) |index| {
        const line = try std.fmt.bufPrint(&buffer, "{d:0>4}\r\n", .{index});
        try grid.feed(line);
    }

    try std.testing.expectEqual(@as(usize, Grid.default_history_lines), grid.history.items.len);
    try std.testing.expect(grid.history_start != 0);
    try std.testing.expectEqual(@as(u21, '7'), grid.lineCell(0, 3).codepoint);
    try std.testing.expectEqual(@as(u21, '1'), grid.lineCell(Grid.default_history_lines - 1, 0).codepoint);
    try std.testing.expectEqual(@as(u21, '6'), grid.lineCell(Grid.default_history_lines - 1, 3).codepoint);

    grid.scrollViewport(@intCast(Grid.default_history_lines));
    try std.testing.expectEqual(@as(u21, '7'), grid.cell(3, 0).codepoint);
}

test "terminal grid grows its bounded scrollback slab lazily" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();

    try std.testing.expectEqual(
        @min(Grid.initial_history_lines, Grid.hot_history_lines) * grid.columns,
        grid.history_cells.len,
    );
    for (0..Grid.initial_history_lines + 8) |_| {
        try grid.feed("line\r\n");
    }

    try std.testing.expect(grid.history.items.len > Grid.initial_history_lines);
    try std.testing.expect(grid.history_cells.len < Grid.default_history_lines * grid.columns);
    for (grid.history.items) |line| {
        try std.testing.expect(line.len == 0 or line.len == grid.columns);
    }
}

test "terminal grid cold-packs idle history in bounded steps and regrows on output" {
    var grid = try Grid.init(std.testing.allocator, 80, 24);
    defer grid.deinit();
    for (0..1100) |_| try grid.feed("agent output line\r\n");

    const oldest = grid.lineCell(0, 0);
    const bytes_before = grid.historyMemoryBytes();
    var result = try grid.compactIdleHistoryStep(
        Grid.idle_history_hot_lines,
        Grid.idle_history_rows_per_step,
    );
    try std.testing.expectEqual(Grid.idle_history_rows_per_step, result.rows_coldified);
    try std.testing.expect(!result.complete);

    var steps: usize = 1;
    while (!result.complete and steps < 32) : (steps += 1) {
        result = try grid.compactIdleHistoryStep(
            Grid.idle_history_hot_lines,
            Grid.idle_history_rows_per_step,
        );
    }
    try std.testing.expect(result.complete);
    try std.testing.expect(steps < 32);
    try std.testing.expect(grid.historyMemoryBytes() < bytes_before / 2);
    try std.testing.expectEqualDeep(oldest, grid.lineCell(0, 0));
    try std.testing.expectEqual(Grid.idle_history_hot_lines, grid.history_hot_owners.len);

    for (0..200) |_| try grid.feed("resumed output\r\n");
    try std.testing.expect(grid.history_hot_owners.len > Grid.idle_history_hot_lines);
}

test "terminal grid reuses row-stable history and resizes both alternate screens" {
    var grid = try Grid.init(std.testing.allocator, 6, 2);
    defer grid.deinit();
    try grid.feed("one\r\ntwo\r\nthree");

    const history_count = grid.history.items.len;
    const oldest = grid.lineCell(0, 0);
    try grid.resize(6, 3);
    try std.testing.expectEqual(history_count, grid.history.items.len);
    try std.testing.expectEqualDeep(oldest, grid.lineCell(0, 0));

    try grid.feed("\x1b[?1049hALT");
    try std.testing.expect(grid.alternate_cells != null);
    try grid.resize(8, 4);
    try std.testing.expectEqual(@as(usize, 32), grid.cells.len);
    try std.testing.expectEqual(@as(usize, 32), grid.alternate_cells.?.len);
    try grid.feed("\x1b[?1049l");
    try std.testing.expectEqual(@as(?[]Cell, null), grid.alternate_cells);
    try std.testing.expectEqual(@as(u21, 'o'), grid.cell(0, 0).codepoint);
}

test "terminal grid preserves logical scrollback across column changes" {
    var grid = try Grid.init(std.testing.allocator, 6, 2);
    defer grid.deinit();
    try grid.feed("one\r\ntwo\r\nthree");
    grid.scrollViewport(1);

    try grid.resize(9, 3);
    try std.testing.expectEqual(@as(usize, 0), grid.history.items.len);
    try std.testing.expectEqual(@as(usize, 0), grid.viewport_offset);
    try std.testing.expectEqual(@as(u21, 'o'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, ' '), grid.cell(8, 0).codepoint);

    try grid.resize(3, 2);
    try std.testing.expectEqual(@as(usize, 2), grid.history.items.len);
    try std.testing.expectEqual(@as(u21, 'e'), grid.lineCell(0, 2).codepoint);
}

test "terminal reflow ignores blank rows below the cursor when shrinking" {
    var grid = try Grid.init(std.testing.allocator, 8, 6);
    defer grid.deinit();
    try grid.feed("A\r\nB\r\nC");

    try grid.resize(4, 3);

    try std.testing.expectEqual(@as(usize, 0), grid.history.items.len);
    try std.testing.expectEqual(@as(u21, 'A'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'B'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 'C'), grid.cell(0, 2).codepoint);
}

test "terminal reflow preserves grapheme anchors across width changes" {
    var grid = try Grid.init(std.testing.allocator, 4, 2);
    defer grid.deinit();
    try grid.feed("abcdef");
    const anchor = grid.anchorAt(1, 1) orelse return error.ExpectedAnchor;
    try std.testing.expectEqual(@as(u21, 'f'), grid.cell(1, 1).codepoint);

    try grid.resize(8, 2);
    const resolved = grid.resolveAnchor(anchor) orelse return error.ExpectedResolvedAnchor;
    try std.testing.expectEqual(@as(usize, 5), resolved.column);
    try std.testing.expectEqual(@as(u21, 'f'), grid.lineCell(resolved.line_index, resolved.column).codepoint);

    try grid.resize(3, 2);
    const narrowed = grid.resolveAnchor(anchor) orelse return error.ExpectedResolvedAnchor;
    try std.testing.expectEqual(@as(u21, 'f'), grid.lineCell(narrowed.line_index, narrowed.column).codepoint);
}

test "terminal anchors fail after bounded history drops their logical line" {
    var grid = try Grid.initWithHistoryLimit(std.testing.allocator, 8, 2, 2);
    defer grid.deinit();
    try grid.feed("one\r\ntwo\r\nthree");
    const anchor = grid.anchorForLineColumn(0, 0) orelse return error.ExpectedAnchor;
    try grid.feed("\r\nfour\r\nfive\r\nsix");
    try std.testing.expectEqual(@as(?ResolvedAnchor, null), grid.resolveAnchor(anchor));
}

test "terminal cold history preserves styled Unicode with a bounded hot window" {
    var grid = try Grid.initWithHistoryLimit(std.testing.allocator, 12, 2, 1400);
    defer grid.deinit();
    for (0..1320) |_| try grid.feed("\x1b[1;31me\xcc\x81 line\x1b[0m\r\n");
    try std.testing.expectEqual(@as(usize, 1319), grid.history.items.len);
    const oldest_slot = grid.history_start;
    try std.testing.expectEqual(@as(usize, 0), grid.history.items[oldest_slot].len);
    const first = grid.lineCell(0, 0);
    try std.testing.expect(first.flags.bold);
    try std.testing.expect(first.grapheme_id != 0);
    var text: [16]u8 = undefined;
    const text_length = grid.writeCellText(first, &text);
    try std.testing.expectEqualStrings("e\xcc\x81", text[0..text_length]);
}

test "terminal 100000 line history remains compact and releases shrink storage" {
    var grid = try Grid.initWithHistoryLimit(
        std.testing.allocator,
        80,
        2,
        Grid.max_history_lines,
    );
    defer grid.deinit();
    for (0..Grid.max_history_lines + 1) |_| try grid.feed("x\r\n");
    try std.testing.expectEqual(Grid.max_history_lines, grid.history.items.len);
    const direct_baseline = Grid.max_history_lines * grid.columns * @sizeOf(Cell);
    const compact_bytes = grid.historyMemoryBytes();
    try std.testing.expect(compact_bytes < direct_baseline / 2);

    try grid.setHistoryLimit(128);
    try std.testing.expectEqual(@as(usize, 128), grid.history.items.len);
    try std.testing.expect(grid.historyMemoryBytes() < compact_bytes / 4);
    const shrunken_bytes = grid.historyMemoryBytes();
    try grid.setHistoryLimit(Grid.max_history_lines);
    try std.testing.expectEqual(shrunken_bytes, grid.historyMemoryBytes());
}

test "terminal grid applies bounded scrollback limits without retaining excess slabs" {
    var grid = try Grid.initWithHistoryLimit(std.testing.allocator, 8, 2, 4);
    defer grid.deinit();
    for (0..9) |index| {
        var buffer: [16]u8 = undefined;
        try grid.feed(try std.fmt.bufPrint(&buffer, "{d}\r\n", .{index}));
    }
    try std.testing.expectEqual(@as(usize, 4), grid.history.items.len);

    try grid.setHistoryLimit(2);
    try std.testing.expectEqual(@as(usize, 2), grid.history.items.len);
    try std.testing.expectEqual(@as(usize, 2 * 8), grid.history_cells.len);
    try std.testing.expectEqual(@as(u21, '6'), grid.lineCell(0, 0).codepoint);

    try grid.setHistoryLimit(0);
    try std.testing.expectEqual(@as(usize, 0), grid.history.items.len);
    try std.testing.expectEqual(@as(usize, 0), grid.history_cells.len);
    try grid.feed("new\r\nlines\r\n");
    try std.testing.expectEqual(@as(usize, 0), grid.history.items.len);
}

test "terminal grid reports and clears terminal-owned dirty rows" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    var dirty: [3]u8 = undefined;

    try std.testing.expectEqual(@as(usize, 3), grid.takeDirtyRows(&dirty));
    try std.testing.expectEqualSlices(u8, &.{ 1, 1, 1 }, &dirty);
    _ = grid.takeDirtyRows(&dirty);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0 }, &dirty);

    try grid.feed("\x1b[2;1HX");
    _ = grid.takeDirtyRows(&dirty);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0 }, &dirty);

    grid.scrollViewport(1);
    _ = grid.takeDirtyRows(&dirty);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0 }, &dirty);
    try grid.resize(9, 4);
    var resized_dirty: [4]u8 = undefined;
    _ = grid.takeDirtyRows(&resized_dirty);
    try std.testing.expectEqualSlices(u8, &.{ 1, 1, 1, 1 }, &resized_dirty);
}

test "terminal grid damage generations support independent consumers" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    var first_rows: [3]u8 = undefined;
    var second_rows: [3]u8 = undefined;
    const first_initial = grid.damageRowsSince(0, &first_rows);
    const second_initial = grid.damageRowsSince(0, &second_rows);
    try std.testing.expectEqualSlices(u8, &.{ 1, 1, 1 }, &first_rows);
    try std.testing.expectEqualSlices(u8, &.{ 1, 1, 1 }, &second_rows);

    // The local renderer consumes its legacy dirty spans. Generation-based
    // remote consumers must still observe the same subsequent row damage.
    var spans: [3]DirtySpan = undefined;
    _ = grid.takeDirtySpans(&spans);
    try grid.feed("\x1b[2;1HX");
    _ = grid.takeDirtySpans(&spans);
    const first_next = grid.damageRowsSince(first_initial.generation, &first_rows);
    const second_next = grid.damageRowsSince(second_initial.generation, &second_rows);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0 }, &first_rows);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0 }, &second_rows);
    try std.testing.expectEqual(first_next.generation, second_next.generation);
}

test "terminal grid merges and clears bounded dirty column spans" {
    var grid = try Grid.init(std.testing.allocator, 12, 3);
    defer grid.deinit();
    var spans: [3]DirtySpan = undefined;

    _ = grid.takeDirtySpans(&spans);
    try std.testing.expectEqual(DirtySpan{ .first = 0, .end = 12 }, spans[0]);
    _ = grid.takeDirtySpans(&spans);
    try std.testing.expectEqual(DirtySpan{}, spans[0]);

    try grid.feed("\x1b[2;4Habc");
    _ = grid.takeDirtySpans(&spans);
    try std.testing.expectEqual(DirtySpan{}, spans[0]);
    try std.testing.expectEqual(DirtySpan{ .first = 3, .end = 6 }, spans[1]);

    try grid.feed("\x1b[2;2HX\x1b[2;9HY");
    _ = grid.takeDirtySpans(&spans);
    try std.testing.expectEqual(DirtySpan{ .first = 1, .end = 9 }, spans[1]);

    try grid.feed("\x1b[2;5H\x1b[K");
    _ = grid.takeDirtySpans(&spans);
    try std.testing.expectEqual(DirtySpan{ .first = 4, .end = 12 }, spans[1]);
}

test "terminal grid survives malformed control streams during resize churn" {
    var grid = try Grid.initWithHistoryLimit(std.testing.allocator, 80, 24, 64);
    defer grid.deinit();
    const corpus = [_][]const u8{
        "plain output\r\n",
        "\x1b[",
        "\x1b[999999999999999999999999;999999999999999999999H",
        "\x1b[?1049halternate\x1b[?1049l",
        "\x1b]2;unterminated title",
        "\x1b\\",
        "\xc0\xaf\xed\xa0\x80\xf5\x80\x80\x80",
        "\x1b[1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20m",
        "\x1b[0;0r\x1b[999P\x1b[999L\x1b[999M",
        "\x00\x01\x02\x07\x08\x09\x0b\x0c\x0e\x1f",
    };

    var dirty: [32]u8 = undefined;
    for (0..256) |iteration| {
        const input = corpus[iteration % corpus.len];
        for (input) |byte| try grid.feedByte(byte);
        const columns = 1 + (iteration * 17) % 120;
        const rows = 1 + (iteration * 7) % dirty.len;
        try grid.resize(columns, rows);
        if (iteration % 19 == 0)
            try grid.setHistoryLimit((iteration * 13) % 65);
        try std.testing.expectEqual(columns * rows, grid.cells.len);
        try std.testing.expect(grid.cursor_column < grid.columns);
        try std.testing.expect(grid.cursor_row < grid.rows);
        try std.testing.expect(grid.history.items.len <= grid.history_limit);
        if (grid.alternate_cells) |alternate|
            try std.testing.expectEqual(grid.cells.len, alternate.len);
        try std.testing.expectEqual(rows, grid.takeDirtyRows(dirty[0..rows]));
    }
}

test "terminal grid honors row and column cursor addressing" {
    var grid = try Grid.init(std.testing.allocator, 8, 4);
    defer grid.deinit();
    try grid.feed("\x1b[3;5HX");
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(4, 2).codepoint);
    try std.testing.expectEqual(@as(usize, 5), grid.cursor_column);
    try std.testing.expectEqual(@as(usize, 2), grid.cursor_row);
}

test "terminal grid decodes UTF-8 output into Unicode cells" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed(&[_]u8{ 'c', 'a', 'f', 0xc3, 0xa9 });
    try std.testing.expectEqual(@as(u21, 0xE9), grid.cell(3, 0).codepoint);
}

test "terminal grid keeps combining and ZWJ graphemes atomic" {
    var grid = try Grid.init(std.testing.allocator, 12, 2);
    defer grid.deinit();
    const combining = "A\xcc\x81";
    try grid.feed(combining);
    try std.testing.expectEqual(@as(usize, 1), grid.cursor_column);
    try std.testing.expect(grid.cell(0, 0).grapheme_id != 0);
    var text: [128]u8 = undefined;
    const combining_length = grid.cellText(0, 0, &text);
    try std.testing.expectEqualStrings(combining, text[0..combining_length]);

    try grid.feed("\r\xf0\x9f\x91\xa9\xe2\x80\x8d\xf0\x9f\x9a\x80");
    try std.testing.expectEqual(@as(usize, 2), grid.cursor_column);
    try std.testing.expectEqual(@as(u2, 2), grid.cell(0, 0).flags.width);
    try std.testing.expect(grid.cell(1, 0).flags.continuation);
    const emoji_length = grid.cellText(0, 0, &text);
    try std.testing.expectEqualStrings(
        "\xf0\x9f\x91\xa9\xe2\x80\x8d\xf0\x9f\x9a\x80",
        text[0..emoji_length],
    );
}

test "terminal grid assigns wide cells and exports no continuation bytes" {
    var grid = try Grid.init(std.testing.allocator, 6, 2);
    defer grid.deinit();
    try grid.feed("\xe7\x95\x8cX");
    try std.testing.expectEqual(@as(u2, 2), grid.cell(0, 0).flags.width);
    try std.testing.expect(grid.cell(1, 0).flags.continuation);
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(2, 0).codepoint);
    try std.testing.expectEqual(@as(usize, 3), grid.cursor_column);
    var output: [64]u8 = undefined;
    const count = try grid.writeScrollback(&output);
    try std.testing.expect(std.mem.startsWith(u8, output[0..count], "\xe7\x95\x8cX"));
    try std.testing.expect(std.mem.indexOfScalar(u8, output[0..count], 0) == null);
}

test "terminal grid honors erase modes and absolute cursor moves" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    try grid.feed("abcdefgh\x1b[1;4H\x1b[0K\x1b[6G\x1b[3dX");
    try std.testing.expectEqual(@as(u21, 'a'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, ' '), grid.cell(3, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(5, 2).codepoint);
}

test "terminal grid honors display erase modes" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    try grid.feed("abcd\nefgh\x1b[1;2H\x1b[0J");
    try std.testing.expectEqual(@as(u21, 'a'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, ' '), grid.cell(1, 0).codepoint);
    try std.testing.expectEqual(@as(u21, ' '), grid.cell(0, 1).codepoint);
}

test "terminal grid erases scrollback with ED 3" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("one\r\ntwo\r\nthree");
    try std.testing.expect(grid.history.items.len > 0);
    grid.scrollViewport(1);

    try grid.feed("\x1b[3J");

    try std.testing.expectEqual(@as(usize, 0), grid.history.items.len);
    try std.testing.expectEqual(@as(usize, 0), grid.viewport_offset);
    for (grid.history_hot_owners) |owner|
        try std.testing.expectEqual(Grid.no_history_owner, owner);
    try std.testing.expectEqual(@as(u21, 't'), grid.cell(0, 0).codepoint);
}

test "terminal grid scrolls only inside configured margins" {
    var grid = try Grid.init(std.testing.allocator, 4, 4);
    defer grid.deinit();
    try grid.feed("top\nkeep\nold\nbase\x1b[2;3r\x1b[3;1H\nnew");
    try std.testing.expectEqual(@as(usize, 1), grid.margin_top);
    try std.testing.expectEqual(@as(usize, 2), grid.margin_bottom);
}

test "terminal grid keeps line feed and reverse index outside scroll margins" {
    var line_feed = try Grid.init(std.testing.allocator, 4, 4);
    defer line_feed.deinit();
    try line_feed.feed("1111\r\n2222\r\n3333\r\n4444\x1b[2;3r\x1b[4;1H\nZZ");
    try std.testing.expectEqual(@as(u21, '2'), line_feed.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, '3'), line_feed.cell(0, 2).codepoint);
    try std.testing.expectEqual(@as(u21, 'Z'), line_feed.cell(0, 3).codepoint);

    var reverse_index = try Grid.init(std.testing.allocator, 4, 4);
    defer reverse_index.deinit();
    try reverse_index.feed(
        "1111\r\n2222\r\n3333\r\n4444\x1b[2;3r\x1b[1;1H\x1bMZZ",
    );
    try std.testing.expectEqual(@as(u21, '2'), reverse_index.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, '3'), reverse_index.cell(0, 2).codepoint);
}

test "terminal grid clamps vertical movement at scroll margins" {
    var grid = try Grid.init(std.testing.allocator, 4, 4);
    defer grid.deinit();
    try grid.feed("\x1b[2;3r\x1b[1;1H\x1b[4B");
    try std.testing.expectEqual(@as(usize, 2), grid.cursor_row);
    try grid.feed("\x1b[4;1H\x1b[4A");
    try std.testing.expectEqual(@as(usize, 1), grid.cursor_row);
    try grid.feed("\x1b[4;1H\x1b[2B");
    try std.testing.expectEqual(@as(usize, 3), grid.cursor_row);
    try grid.feed("\x1b[1;1H\x1b[2A");
    try std.testing.expectEqual(@as(usize, 0), grid.cursor_row);
}

test "terminal grid clears rows vacated by explicit scrolling" {
    var upward = try Grid.init(std.testing.allocator, 4, 4);
    defer upward.deinit();
    try upward.feed("1111\r\n2222\r\n3333\r\n4444\x1b[2;3r\x1b[1S");
    try std.testing.expectEqual(@as(u21, '3'), upward.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, ' '), upward.cell(0, 2).codepoint);

    var downward = try Grid.init(std.testing.allocator, 4, 4);
    defer downward.deinit();
    try downward.feed("1111\r\n2222\r\n3333\r\n4444\x1b[2;3r\x1b[1T");
    try std.testing.expectEqual(@as(u21, ' '), downward.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, '2'), downward.cell(0, 2).codepoint);
}

test "terminal grid honors origin mode and validates scroll margins" {
    var grid = try Grid.init(std.testing.allocator, 4, 4);
    defer grid.deinit();
    try grid.feed("1111\r\n2222\r\n3333\r\n4444\x1b[2;3r\x1b[?6h\x1b[1;1HO");
    try std.testing.expect(grid.origin_mode);
    try std.testing.expectEqual(@as(usize, 1), grid.cursor_row);
    try std.testing.expectEqual(@as(u21, 'O'), grid.cell(0, 1).codepoint);

    try grid.feed("\x1b[?6l\x1b[0;0r");
    try std.testing.expect(!grid.origin_mode);
    try std.testing.expectEqual(@as(usize, 1), grid.margin_top);
    try std.testing.expectEqual(@as(usize, 2), grid.margin_bottom);

    try grid.feed("\x1b[r");
    try std.testing.expectEqual(@as(usize, 0), grid.margin_top);
    try std.testing.expectEqual(@as(usize, 3), grid.margin_bottom);
    try std.testing.expectEqual(@as(usize, 0), grid.cursor_row);

    var restored_outside = try Grid.init(std.testing.allocator, 4, 4);
    defer restored_outside.deinit();
    try restored_outside.feed("\x1b[2;3r\x1b[?6h\x1b[u\x1b[2A");
    try std.testing.expect(!restored_outside.origin_mode);
    try std.testing.expectEqual(@as(usize, 0), restored_outside.cursor_row);

    try restored_outside.feed("\x1b[?6h\x1b[s\x1b[?6l\x1b[u\x1b[1;1HX");
    try std.testing.expect(restored_outside.origin_mode);
    try std.testing.expectEqual(@as(u21, 'X'), restored_outside.cell(0, 1).codepoint);
}

test "terminal grid repeats the preceding graphic character" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("X\x1b[5b");
    for (0..6) |column|
        try std.testing.expectEqual(@as(u21, 'X'), grid.cell(column, 0).codepoint);
    try std.testing.expectEqual(@as(usize, 6), grid.cursor_column);

    try grid.feed("\x1b[2;1HX\x1b[31m\x1b[2b");
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(u21, ' '), grid.cell(1, 1).codepoint);

    try grid.feed("\x1b[2;3HX\x1b[2b\x1b[3b");
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(2, 1).codepoint);
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(4, 1).codepoint);
    try std.testing.expectEqual(@as(u21, ' '), grid.cell(5, 1).codepoint);
}

test "terminal grid translates DEC special graphics charsets" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("\x1b(0lqqk\x1b(B");
    try std.testing.expectEqual(@as(u21, 0x250c), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 0x2500), grid.cell(1, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 0x2510), grid.cell(3, 0).codepoint);
}

test "terminal alternate screen has independent saved cursor state" {
    var grid = try Grid.init(std.testing.allocator, 8, 4);
    defer grid.deinit();
    try grid.feed("abcd\n1234\x1b[?1049h\x1b[2;3H\x1b7\x1b[1;1H\x1b8\x1b[?1049lX");
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(0, 2).codepoint);
    try std.testing.expectEqual(@as(usize, 1), grid.cursor_column);
    try std.testing.expectEqual(@as(usize, 2), grid.cursor_row);
}

test "terminal alternate screen restores primary scroll margins" {
    var grid = try Grid.init(std.testing.allocator, 8, 4);
    defer grid.deinit();
    try grid.feed(
        "\x1b[1;1HA\x1b[2;1HB\x1b[3;1HC\x1b[4;1HD" ++
            "\x1b[2;3r\x1b[?1049h\x1b[?1049l\x1b[2;1H\x1bM",
    );
    try std.testing.expectEqual(@as(u21, 'A'), grid.cell(0, 0).codepoint);
    try std.testing.expect(grid.cell(0, 1).codepoint == 0 or
        grid.cell(0, 1).codepoint == ' ');
    try std.testing.expectEqual(@as(u21, 'B'), grid.cell(0, 2).codepoint);
    try std.testing.expectEqual(@as(u21, 'D'), grid.cell(0, 3).codepoint);
    try std.testing.expectEqual(@as(usize, 1), grid.margin_top);
    try std.testing.expectEqual(@as(usize, 2), grid.margin_bottom);
}

test "terminal alternate screen restores primary origin mode" {
    var grid = try Grid.init(std.testing.allocator, 8, 4);
    defer grid.deinit();
    try grid.feed(
        "\x1b[2;3r\x1b[?6h\x1b[?1049h\x1b[?6l\x1b[?1049l\x1b[1;1HX",
    );
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(0, 1).codepoint);
    try std.testing.expect(grid.origin_mode);
}

test "terminal cursor saves preserve DEC character sets" {
    var designation = try Grid.init(std.testing.allocator, 8, 2);
    defer designation.deinit();
    try designation.feed("12345678\x1b(BX");
    try std.testing.expectEqual(@as(u21, 'X'), designation.cell(0, 1).codepoint);

    var dec_save = try Grid.init(std.testing.allocator, 8, 2);
    defer dec_save.deinit();
    try dec_save.feed("\x1b(0\x1b7\x1b(B\x1b8q");
    try std.testing.expectEqual(@as(u21, 0x2500), dec_save.cell(0, 0).codepoint);

    var csi_save = try Grid.init(std.testing.allocator, 8, 2);
    defer csi_save.deinit();
    try csi_save.feed("\x1b)0\x0e\x1b[s\x0f\x1b[uq");
    try std.testing.expectEqual(@as(u21, 0x2500), csi_save.cell(0, 0).codepoint);

    var dec_wrap = try Grid.init(std.testing.allocator, 8, 2);
    defer dec_wrap.deinit();
    try dec_wrap.feed("12345678\x1b7\rA\x1b8X");
    try std.testing.expectEqual(@as(u21, 'X'), dec_wrap.cell(0, 1).codepoint);

    var csi_wrap = try Grid.init(std.testing.allocator, 8, 2);
    defer csi_wrap.deinit();
    try csi_wrap.feed("12345678\x1b[s\rA\x1b[uX");
    try std.testing.expectEqual(@as(u21, 'X'), csi_wrap.cell(0, 1).codepoint);
}

test "terminal grid ignores private CSI collisions it does not implement" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("\x1b[>4;2mX");
    const cell = grid.cell(0, 0);
    try std.testing.expect(!cell.flags.dim);
    try std.testing.expect(!cell.flags.underline);
}

test "terminal grid preserves the primary screen across alternate screen mode" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("primary\x1b[?1049hALT\x1b[?1049l");
    try std.testing.expectEqual(@as(u21, 'p'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(?[]Cell, null), grid.alternate_cells);
}

test "terminal grid saves cursor and honors cursor visibility modes" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("\x1b[2;4H\x1b7\x1b[1;1H\x1b8\x1b[?25l");
    try std.testing.expectEqual(@as(usize, 3), grid.cursor_column);
    try std.testing.expectEqual(@as(usize, 1), grid.cursor_row);
    try std.testing.expect(!grid.cursor_visible);
    try grid.feed("\x1b[?25h");
    try std.testing.expect(grid.cursor_visible);
}

test "terminal grid tracks bracketed paste mode" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("\x1b[?2004h");
    try std.testing.expect(grid.bracketed_paste);
    try grid.feed("\x1b[?2004l");
    try std.testing.expect(!grid.bracketed_paste);
}

test "terminal grid queues bounded DA DSR and mode replies" {
    var grid = try Grid.init(std.testing.allocator, 80, 24);
    defer grid.deinit();
    try grid.feed("\x1b[3;5H\x1b[c\x1b[>c\x1b[5n\x1b[6n\x1b[?6n\x1b[?2004$p");
    try std.testing.expectEqualStrings(
        "\x1b[?1;2c\x1b[>0;1;0c\x1b[0n\x1b[3;5R\x1b[?3;5R\x1b[?2004;2$y",
        grid.pendingReplies(),
    );

    grid.consumeReplies(7);
    try std.testing.expectEqualStrings(
        "\x1b[>0;1;0c\x1b[0n\x1b[3;5R\x1b[?3;5R\x1b[?2004;2$y",
        grid.pendingReplies(),
    );
    grid.consumeReplies(std.math.maxInt(usize));
    try std.testing.expectEqual(@as(usize, 0), grid.pendingReplies().len);

    try grid.feed("\x1b[?2004h\x1b[?2004$p\x1b[?9999$p");
    try std.testing.expectEqualStrings(
        "\x1b[?2004;1$y\x1b[?9999;0$y",
        grid.pendingReplies(),
    );
}

test "terminal grid answers common XTGETTCAP without allocation" {
    var grid = try Grid.init(std.testing.allocator, 80, 24);
    defer grid.deinit();
    try grid.feed("\x1bP+q544e;436f;524742;5463;626164\x1b\\");
    try std.testing.expectEqualStrings(
        "\x1bP1+r544e=787465726d2d323536636f6c6f72\x1b\\" ++
            "\x1bP1+r436f=323536\x1b\\" ++
            "\x1bP1+r524742=\x1b\\" ++
            "\x1bP1+r5463=\x1b\\" ++
            "\x1bP0+r626164\x1b\\",
        grid.pendingReplies(),
    );
}

test "terminal grid recognizes standard bounded notification sequences" {
    var grid = try Grid.init(std.testing.allocator, 20, 4);
    defer grid.deinit();

    try grid.feed("\x1b]9;agent needs input\x1b\\");
    try grid.feed("\x1b]99;i=agent:d=0;task finished\x1b\\");
    try grid.feed("\x1b]777;notify;Build;complete\x1b\\");
    try std.testing.expectEqual(@as(u64, 3), grid.notification_serial);

    try grid.feed("\x1b]9;4;1;50\x1b\\");
    try grid.feed("\x1b]99;i=query:p=?;\x1b\\");
    try grid.feed("\x1b]777;progress;50\x1b\\");
    try std.testing.expectEqual(@as(u64, 3), grid.notification_serial);
}

fn notificationAction(value: []const u8) NotificationAction {
    if (std.mem.indexOf(u8, value, "a=focus-pane") != null or
        std.mem.indexOf(u8, value, "action=focus-pane") != null)
        return .focus_pane;
    if (std.mem.indexOf(u8, value, "a=open-project") != null or
        std.mem.indexOf(u8, value, "action=open-project") != null)
        return .open_project;
    return .none;
}

test "terminal grid maps only bounded safe notification actions" {
    var grid = try Grid.init(std.testing.allocator, 20, 4);
    defer grid.deinit();
    try grid.feed("\x1b]99;i=agent;a=focus-pane\x1b\\");
    try std.testing.expectEqual(NotificationAction.focus_pane, grid.notification_action);
    try grid.feed("\x1b]777;notify;a=open-project\x1b\\");
    try std.testing.expectEqual(NotificationAction.open_project, grid.notification_action);
    try grid.feed("\x1b]99;i=agent;a=run-command\x1b\\");
    try std.testing.expectEqual(NotificationAction.none, grid.notification_action);
}

test "terminal grid stores bounded OSC 8 hyperlinks outside cells" {
    var grid = try Grid.init(std.testing.allocator, 16, 2);
    defer grid.deinit();
    try grid.feed("\x1b]8;id=docs;https://example.com/docs\x1b\\link" ++
        "\x1b]8;;\x1b\\ plain");
    try std.testing.expect(grid.cell(0, 0).hyperlink_id != 0);
    try std.testing.expectEqual(@as(u16, 0), grid.cell(5, 0).hyperlink_id);
    try std.testing.expect(grid.cell(0, 0).flags.underline == false);
    try std.testing.expect(grid.styleBits(0, 0) & 8 != 0);
    var uri: [128]u8 = undefined;
    const length = grid.cellHyperlink(0, 0, &uri);
    try std.testing.expectEqualStrings("https://example.com/docs", uri[0..length]);

    try grid.feed("\x1b]8;;https://example.com/docs\x1b\\x\x1b]8;;\x1b\\");
    try std.testing.expectEqual(grid.cell(0, 0).hyperlink_id, grid.cell(10, 0).hyperlink_id);
    try std.testing.expectEqual(@as(usize, 1), grid.hyperlinks.entries.items.len);
}

test "terminal grid drops whole replies when its fixed queue is full" {
    var grid = try Grid.init(std.testing.allocator, 80, 24);
    defer grid.deinit();
    for (0..600) |_| try grid.feed("\x1b[c");
    try std.testing.expect(grid.pendingReplies().len <= grid.reply_buffer.len);
    try std.testing.expect(grid.reply_overflows > 0);
}

test "terminal grid does not mistake Kitty keyboard negotiation for cursor restore" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    try grid.feed("\x1b[2;4H\x1b[s\x1b[1;1H\x1b[>7u\x1b[?u\x1b[<u");

    try std.testing.expectEqual(@as(usize, 0), grid.cursor_column);
    try std.testing.expectEqual(@as(usize, 0), grid.cursor_row);
    try std.testing.expectEqualStrings("\x1b[?0u", grid.pendingReplies());

    try grid.feed("\x1b[u");
    try std.testing.expectEqual(@as(usize, 3), grid.cursor_column);
    try std.testing.expectEqual(@as(usize, 1), grid.cursor_row);
}

test "terminal grid tracks application cursor key mode" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("\x1b[?1h");
    try std.testing.expect(grid.application_cursor_keys);
    try grid.feed("\x1b[?1l");
    try std.testing.expect(!grid.application_cursor_keys);
}

test "terminal grid distinguishes and encodes mouse reporting modes" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();

    try grid.feed("\x1b[?1000h\x1b[?1002h");
    try std.testing.expectEqual(MouseTracking.button_event, grid.mouse_tracking);
    try grid.feed("\x1b[?1000l");
    try std.testing.expectEqual(MouseTracking.button_event, grid.mouse_tracking);
    try grid.feed("\x1b[?1003h\x1b[?1002l\x1b[?1006h\x1b[?1004h");
    try std.testing.expectEqual(MouseTracking.any_event, grid.mouse_tracking);
    try std.testing.expectEqual(MouseEncoding.sgr, grid.mouse_encoding);
    try std.testing.expect(grid.mouse_tracking != .none);
    try std.testing.expect(grid.focus_reporting);

    var output: [64]u8 = undefined;
    const sgr_length = grid.encodeMouse(.{
        .column = 2,
        .row = 3,
        .button = 0,
        .kind = .motion,
        .modifiers = .{ .shift = true, .control = true },
    }, &output) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("\x1b[<52;3;4M", output[0..sgr_length]);

    try grid.feed("\x1b[?1003l\x1b[?1000h\x1b[?1006l");
    try std.testing.expectEqual(MouseTracking.normal, grid.mouse_tracking);
    try std.testing.expectEqual(MouseEncoding.legacy, grid.mouse_encoding);
    try std.testing.expect(grid.encodeMouse(.{
        .column = 0,
        .row = 0,
        .button = 0,
        .kind = .motion,
    }, &output) == null);
    const legacy_length = grid.encodeMouse(.{
        .column = 0,
        .row = 0,
        .button = 0,
        .kind = .release,
    }, &output) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("\x1b[M#!!", output[0..legacy_length]);
    try std.testing.expect(grid.encodeMouse(.{
        .column = 223,
        .row = 0,
        .button = 0,
        .kind = .press,
    }, &output) == null);
}

test "terminal grid extracts bounded normalized Unicode selection" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("\x1b[2J\x1b[HAe\u{301}  \r\n中Z  ");

    var output: [64]u8 = undefined;
    const selection = SelectionRange{
        .start_column = 7,
        .start_row = 1,
        .end_column = 0,
        .end_row = 0,
    };
    const length = grid.copySelection(&output, selection) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("Ae\u{301}\n中Z", output[0..length]);
    try std.testing.expect(grid.copySelection(output[0 .. length - 1], selection) == null);
    const wide_length = grid.copySelection(&output, .{
        .start_column = 1,
        .start_row = 1,
        .end_column = 1,
        .end_row = 1,
    }) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("中", output[0..wide_length]);
}

test "terminal grid counts synchronized output begin transitions" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("\x1b[?2026h\x1b[?2026h");
    try std.testing.expect(grid.synchronized_output);
    try std.testing.expectEqual(@as(u64, 1), grid.synchronized_output_begins);
    try grid.feed("\x1b[?2026l\x1b[?2026h\x1b[?2026l");
    try std.testing.expect(!grid.synchronized_output);
    try std.testing.expectEqual(@as(u64, 2), grid.synchronized_output_begins);
}

test "terminal grid delays autowrap until the next printable cell" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();

    try grid.feed("ABCDEFGH\x1b[0m\x1b]8;;\x07\r\r\nNEXT");

    try std.testing.expectEqual(@as(usize, 0), grid.history.items.len);
    try std.testing.expectEqual(@as(u21, 'A'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'H'), grid.cell(7, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'N'), grid.cell(0, 1).codepoint);
    try std.testing.expectEqual(@as(usize, 4), grid.cursor_column);
    try std.testing.expectEqual(@as(usize, 1), grid.cursor_row);
    try std.testing.expect(!grid.wrap_pending);

    try grid.feed("1234");
    try std.testing.expect(grid.wrap_pending);
    try std.testing.expectEqual(@as(usize, 7), grid.cursor_column);
    try grid.feed("X");
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(0, 2).codepoint);
    try std.testing.expectEqual(@as(usize, 1), grid.cursor_column);
    try std.testing.expectEqual(@as(usize, 2), grid.cursor_row);
}

test "terminal grid honors DEC autowrap mode" {
    var grid = try Grid.init(std.testing.allocator, 3, 2);
    defer grid.deinit();
    try grid.feed("\x1b[?7lABCX");
    try std.testing.expectEqual(@as(u21, 'X'), grid.cell(2, 0).codepoint);
    try std.testing.expectEqual(@as(usize, 2), grid.cursor_column);
    try std.testing.expect(!grid.wrap_pending);
}

test "terminal grid honors configurable tab stops" {
    var grid = try Grid.init(std.testing.allocator, 16, 2);
    defer grid.deinit();
    try grid.feed("\x1b[5G\x1bH\x1b[1G\t");
    try std.testing.expectEqual(@as(usize, 4), grid.cursor_column);
    try grid.feed("\x1b[5G\x1b[0g\x1b[1G\t");
    try std.testing.expectEqual(@as(usize, 8), grid.cursor_column);
}

test "terminal line insertion and deletion reset the cursor column" {
    var grid = try Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    try grid.feed("\x1b[2;5H\x1b[1L");
    try std.testing.expectEqual(@as(usize, 0), grid.cursor_column);
    try grid.feed("\x1b[2;5H\x1b[1M");
    try std.testing.expectEqual(@as(usize, 0), grid.cursor_column);

    try grid.feed("\x1b[2;3r\x1b[1;5H\x1b[1L\x1b[1M");
    try std.testing.expectEqual(@as(usize, 4), grid.cursor_column);
}

test "terminal grid supports insert delete and erase character operations" {
    var grid = try Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("abcd\x1b[1;3H\x1b[4hX\x1b[4l\x1b[2PX\x1b[1X");
    try std.testing.expectEqual(@as(u21, 'a'), grid.cell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u21, 'b'), grid.cell(1, 0).codepoint);
}
