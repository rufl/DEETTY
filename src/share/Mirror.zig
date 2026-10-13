const std = @import("std");
const Protocol = @import("Protocol.zig");
const Presentation = @import("Presentation.zig");

pub const max_palette_colors: usize = 4095;

pub const Cell = struct {
    codepoint: u21 = ' ',
    text_offset: u32 = 0,
    text_length: u8 = 1,
    flags: Presentation.CellFlags = .{},
    foreground: u16 = 0,
    background: u16 = 0,
};

const Row = struct {
    cells: []Cell = &.{},
    text: []u8 = &.{},

    fn deinit(self: *Row, allocator: std.mem.Allocator) void {
        if (self.cells.len != 0) allocator.free(self.cells);
        if (self.text.len != 0) allocator.free(self.text);
        self.* = .{};
    }
};

pub const Grid = struct {
    allocator: std.mem.Allocator,
    columns: u16 = 0,
    rows: u16 = 0,
    row_data: []Row = &.{},
    history_rows: u16 = 0,
    viewport_offset: u16 = 0,
    palette: [max_palette_colors]u32 = undefined,
    palette_count: u16 = 0,
    cursor_column: u16 = 0,
    cursor_row: u16 = 0,
    cursor_visible: bool = true,
    application_cursor_keys: bool = false,
    bracketed_paste: bool = false,
    title_storage: [Protocol.max_title_bytes]u8 = @splat(0),
    title_length: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) Grid {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Grid) void {
        self.clearRows();
        self.* = .{ .allocator = self.allocator };
    }

    fn clearRows(self: *Grid) void {
        for (self.row_data) |*row| row.deinit(self.allocator);
        if (self.row_data.len != 0) self.allocator.free(self.row_data);
        self.row_data = &.{};
        self.columns = 0;
        self.rows = 0;
        self.history_rows = 0;
        self.viewport_offset = 0;
        self.palette_count = 0;
    }

    pub fn reset(self: *Grid, info: Presentation.SnapshotInfo) !void {
        try info.validate();
        self.clearRows();
        const capacity =
            @as(usize, Protocol.max_scrollback_rows) + info.rows;
        const rows = try self.allocator.alloc(Row, capacity);
        errdefer self.allocator.free(rows);
        @memset(rows, .{});
        self.row_data = rows;
        self.columns = info.columns;
        self.rows = info.rows;
        self.history_rows = @intCast(info.scrollback_rows);
        self.viewport_offset = 0;
        self.cursor_column = info.cursor_column;
        self.cursor_row = info.cursor_row;
        self.cursor_visible = info.cursor_visible;
        self.application_cursor_keys = info.application_cursor_keys;
        self.bracketed_paste = info.bracketed_paste;
    }

    pub fn applyCursor(self: *Grid, payload: []const u8) !void {
        if (self.rows == 0 or payload.len != Presentation.cursor_payload_length)
            return error.InvalidMirrorCursor;
        const input: *const [Presentation.cursor_payload_length]u8 =
            @ptrCast(payload.ptr);
        const info = try Presentation.decodeCursorInfo(input);
        if (info.column >= self.columns or info.row >= self.rows)
            return error.InvalidMirrorCursor;
        self.cursor_column = info.column;
        self.cursor_row = info.row;
        self.cursor_visible = info.visible;
        self.application_cursor_keys = info.application_cursor_keys;
        self.bracketed_paste = info.bracketed_paste;
    }

    fn decodeRow(
        self: *Grid,
        payload: []const u8,
    ) !struct { row: u16, value: Row } {
        if (self.rows == 0) return error.MirrorSnapshotRequired;
        var decoder = try Presentation.RowDecoder.init(payload);
        if (decoder.first_column != 0 or decoder.cell_count != self.columns)
            return error.InvalidMirrorRow;
        const cells = try self.allocator.alloc(Cell, self.columns);
        errdefer self.allocator.free(cells);
        var text = std.array_list.Managed(u8).init(self.allocator);
        errdefer text.deinit();
        try text.ensureTotalCapacity(
            @min(payload.len, @as(usize, self.columns) * 4),
        );
        var column: usize = 0;
        while (try decoder.next()) |wire_cell| : (column += 1) {
            const text_offset = text.items.len;
            try text.appendSlice(wire_cell.text);
            const codepoint = if (wire_cell.text.len == 0)
                @as(u21, 0)
            else codepoint: {
                const sequence_length =
                    std.unicode.utf8ByteSequenceLength(wire_cell.text[0]) catch
                        return error.InvalidPresentationUtf8;
                if (sequence_length > wire_cell.text.len)
                    return error.InvalidPresentationUtf8;
                break :codepoint std.unicode.utf8Decode(
                    wire_cell.text[0..sequence_length],
                ) catch return error.InvalidPresentationUtf8;
            };
            cells[column] = .{
                .codepoint = codepoint,
                .text_offset = @intCast(text_offset),
                .text_length = @intCast(wire_cell.text.len),
                .flags = wire_cell.flags,
                .foreground = try self.internColor(wire_cell.foreground_rgb),
                .background = try self.internColor(wire_cell.background_rgb),
            };
        }
        if (column != self.columns) return error.InvalidMirrorRow;
        return .{
            .row = decoder.row,
            .value = .{
                .cells = cells,
                .text = try text.toOwnedSlice(),
            },
        };
    }

    pub fn applyRow(self: *Grid, payload: []const u8) !u16 {
        var decoded = try self.decodeRow(payload);
        errdefer decoded.value.deinit(self.allocator);
        if (decoded.row >= self.rows) return error.InvalidMirrorRow;
        const target = @as(usize, Protocol.max_scrollback_rows) + decoded.row;
        self.row_data[target].deinit(self.allocator);
        self.row_data[target] = decoded.value;
        decoded.value = .{};
        return decoded.row;
    }

    pub fn applyHistoryRow(
        self: *Grid,
        payload: []const u8,
        push: bool,
    ) !u16 {
        var decoded = try self.decodeRow(payload);
        errdefer decoded.value.deinit(self.allocator);
        if (!push) {
            if (decoded.row >= self.history_rows)
                return error.InvalidMirrorHistoryRow;
            self.row_data[decoded.row].deinit(self.allocator);
            self.row_data[decoded.row] = decoded.value;
            decoded.value = .{};
            return decoded.row;
        }
        if (decoded.row != 0) return error.InvalidMirrorHistoryRow;
        const maximum: usize = Protocol.max_scrollback_rows;
        const target = if (self.history_rows < maximum) target: {
            const index = self.history_rows;
            self.history_rows += 1;
            break :target index;
        } else target: {
            self.row_data[0].deinit(self.allocator);
            std.mem.copyForwards(
                Row,
                self.row_data[0 .. maximum - 1],
                self.row_data[1..maximum],
            );
            break :target maximum - 1;
        };
        self.row_data[target] = decoded.value;
        decoded.value = .{};
        if (self.viewport_offset != 0)
            self.viewport_offset =
                @min(self.history_rows, self.viewport_offset + 1);
        return @intCast(target);
    }

    fn internColor(self: *Grid, rgb: u32) !u16 {
        for (self.palette[0..self.palette_count], 0..) |existing, index| {
            if (existing == rgb) return @intCast(index);
        }
        if (self.palette_count == max_palette_colors) return error.MirrorPaletteFull;
        const index = self.palette_count;
        self.palette[index] = rgb;
        self.palette_count += 1;
        return index;
    }
    fn displayedRowIndex(self: *const Grid, row: usize) ?usize {
        if (row >= self.rows) return null;
        const visible_offset: usize = Protocol.max_scrollback_rows;
        if (self.viewport_offset == 0) return visible_offset + row;
        const first = @as(usize, self.history_rows) -
            @as(usize, self.viewport_offset);
        const logical = first + row;
        return if (logical < self.history_rows)
            logical
        else
            visible_offset + logical - self.history_rows;
    }

    pub fn scrollViewport(self: *Grid, lines: isize) void {
        if (lines > 0) {
            self.viewport_offset = @intCast(@min(
                @as(usize, self.history_rows),
                @as(usize, self.viewport_offset) +
                    @as(usize, @intCast(lines)),
            ));
        } else {
            self.viewport_offset -|=
                @intCast(@as(usize, @intCast(-lines)));
        }
    }

    pub fn historyCount(self: *const Grid) usize {
        return self.history_rows;
    }

    pub fn packedCell(self: *const Grid, column: usize, row: usize) u64 {
        if (column >= self.columns) return ' ';
        const source = &self.row_data[
            self.displayedRowIndex(row) orelse
                return ' '
        ];
        if (source.cells.len != self.columns) return ' ';
        const cell = source.cells[column];
        const style = @as(u32, if (cell.flags.bold) 1 else 0) |
            @as(u32, if (cell.flags.inverse) 2 else 0) |
            @as(u32, if (cell.flags.italic) 4 else 0) |
            @as(u32, if (cell.flags.underline) 8 else 0) |
            @as(u32, if (cell.flags.strikethrough) 16 else 0) |
            @as(u32, if (cell.flags.dim) 32 else 0) |
            @as(u32, if (cell.text_length > std.unicode.utf8CodepointSequenceLength(cell.codepoint) catch 0) 64 else 0) |
            @as(u32, if (cell.flags.continuation) 128 else 0) |
            (@as(u32, cell.foreground) << 8) |
            (@as(u32, cell.background) << 20);
        return @as(u64, cell.codepoint) | (@as(u64, style) << 32);
    }

    pub fn cellText(self: *const Grid, column: usize, row: usize, output: []u8) usize {
        if (column >= self.columns) return 0;
        const source = &self.row_data[
            self.displayedRowIndex(row) orelse
                return 0
        ];
        if (source.cells.len != self.columns) return 0;
        const cell = source.cells[column];
        if (cell.flags.continuation or cell.text_length > output.len) return 0;
        const start: usize = cell.text_offset;
        const end = start + cell.text_length;
        if (end > source.text.len) return 0;
        @memcpy(output[0..cell.text_length], source.text[start..end]);
        return cell.text_length;
    }

    pub fn colorRgb(self: *const Grid, color_id: u16) u32 {
        return if (color_id < self.palette_count) self.palette[color_id] else 0;
    }

    pub fn setTitle(self: *Grid, value: []const u8) !void {
        if (value.len > Protocol.max_title_bytes or !std.unicode.utf8ValidateSlice(value))
            return error.InvalidMirrorTitle;
        @memcpy(self.title_storage[0..value.len], value);
        @memset(self.title_storage[value.len..], 0);
        self.title_length = @intCast(value.len);
    }

    pub fn title(self: *const Grid) []const u8 {
        return self.title_storage[0..self.title_length];
    }
};

pub const Receiver = struct {
    stream_id: u32,
    sequence: Protocol.Sequence = .{},
    permission: Protocol.PermissionState = .{},
    snapshot_active: bool = false,
    snapshot_rows: [Protocol.max_rows]bool = @splat(false),
    snapshot_history: [Protocol.max_scrollback_rows]bool = @splat(false),
    awaiting_resync: bool = false,
    grid: Grid,

    pub fn init(allocator: std.mem.Allocator, stream_id: u32) !Receiver {
        if (stream_id == 0) return error.InvalidShareStream;
        return .{ .stream_id = stream_id, .grid = Grid.init(allocator) };
    }

    pub fn deinit(self: *Receiver) void {
        self.grid.deinit();
    }

    pub fn beginResync(self: *Receiver) void {
        self.awaiting_resync = true;
        self.permission.value = .view_only;
        self.snapshot_active = false;
        @memset(&self.snapshot_rows, false);
        @memset(&self.snapshot_history, false);
    }

    pub fn apply(self: *Receiver, frame: Protocol.Frame) !void {
        if (frame.header.stream_id != self.stream_id) return error.InvalidShareStream;
        if (self.awaiting_resync) {
            if (frame.header.message_type != .snapshot_begin or frame.header.sequence != 0)
                return error.MirrorResyncPending;
            self.sequence = .{};
            self.grid.clearRows();
            self.awaiting_resync = false;
        }
        try self.sequence.receive(frame.header.sequence);
        switch (frame.header.message_type) {
            .snapshot_begin => {
                if (self.snapshot_active or frame.payload.len != Presentation.snapshot_begin_length)
                    return error.InvalidMirrorSnapshotState;
                const payload: *const [Presentation.snapshot_begin_length]u8 = @ptrCast(frame.payload.ptr);
                try self.grid.reset(try Presentation.decodeSnapshotInfo(payload));
                @memset(&self.snapshot_rows, false);
                @memset(&self.snapshot_history, false);
                self.snapshot_active = true;
            },
            .row_chunk => {
                if (!self.snapshot_active) return error.InvalidMirrorSnapshotState;
                const row = try self.grid.applyRow(frame.payload);
                if (self.snapshot_rows[row]) return error.DuplicateMirrorSnapshotRow;
                self.snapshot_rows[row] = true;
            },
            .history_row => {
                if (!self.snapshot_active)
                    return error.InvalidMirrorSnapshotState;
                const row = try self.grid.applyHistoryRow(frame.payload, false);
                if (self.snapshot_history[row])
                    return error.DuplicateMirrorSnapshotRow;
                self.snapshot_history[row] = true;
            },
            .snapshot_end => {
                if (!self.snapshot_active or frame.payload.len != 0)
                    return error.InvalidMirrorSnapshotState;
                for (self.snapshot_rows[0..self.grid.rows]) |present| {
                    if (!present) return error.IncompleteMirrorSnapshot;
                }
                for (self.snapshot_history[0..self.grid.history_rows]) |present| {
                    if (!present) return error.IncompleteMirrorSnapshot;
                }
                self.snapshot_active = false;
            },
            .damage => {
                if (self.snapshot_active) return error.InvalidMirrorSnapshotState;
                _ = try self.grid.applyRow(frame.payload);
            },
            .history_push => {
                if (self.snapshot_active)
                    return error.InvalidMirrorSnapshotState;
                _ = try self.grid.applyHistoryRow(frame.payload, true);
            },
            .title => try self.grid.setTitle(frame.payload),
            .control_request => try self.permission.requestControl(),
            .control_grant => try self.permission.grantControl(),
            .control_revoke => self.permission.revoke(),
            .cursor => try self.grid.applyCursor(frame.payload),
            .hello, .ping, .pong, .pane_open, .pane_close, .workspace_manifest, .workspace_update, .resync, .disconnect_reason => {},
            .input, .control_release => return error.UnexpectedRemoteInput,
        }
    }
};

test "remote mirror applies a complete structured checkpoint" {
    const Vt = @import("../terminal/Vt.zig");
    var source = try Vt.Grid.init(std.testing.allocator, 8, 2);
    defer source.deinit();
    try source.feed("\x1b[1;38;2;143;184;255mMirror");
    var publisher = try Presentation.Publisher.init(1);
    var receiver = try Receiver.init(std.testing.allocator, 1);
    defer receiver.deinit();
    var begin = try publisher.snapshotBegin(&source, 0);
    begin.frame.payload = &begin.payload;
    try receiver.apply(begin.frame);
    for (0..source.rows) |row| {
        const owned = try publisher.rowFrameAlloc(std.testing.allocator, &source, row, .row_chunk);
        defer owned.deinit(std.testing.allocator);
        try receiver.apply(owned.frame);
    }
    try receiver.apply(try publisher.snapshotEnd());
    var text: [16]u8 = undefined;
    try std.testing.expectEqualStrings("M", text[0..receiver.grid.cellText(0, 0, &text)]);
    try std.testing.expectEqual(@as(u32, 0x8fb8ff), receiver.grid.colorRgb(@intCast((receiver.grid.packedCell(0, 0) >> 40) & 0x0fff)));
}
test "remote mirror retains bounded history and preserves scrolled view" {
    const Vt = @import("../terminal/Vt.zig");
    var source = try Vt.Grid.init(std.testing.allocator, 8, 2);
    defer source.deinit();
    try source.feed("one\r\ntwo\r\ntri");
    try std.testing.expectEqual(@as(usize, 1), source.historyCount());

    var publisher = try Presentation.Publisher.init(1);
    var receiver = try Receiver.init(std.testing.allocator, 1);
    defer receiver.deinit();
    var begin = try publisher.snapshotBegin(&source, 1);
    begin.frame.payload = &begin.payload;
    try receiver.apply(begin.frame);
    const history = try publisher.historyRowFrameAlloc(
        std.testing.allocator,
        &source,
        0,
        0,
        .history_row,
    );
    defer history.deinit(std.testing.allocator);
    try receiver.apply(history.frame);
    for (0..source.rows) |row| {
        const owned = try publisher.rowFrameAlloc(
            std.testing.allocator,
            &source,
            row,
            .row_chunk,
        );
        defer owned.deinit(std.testing.allocator);
        try receiver.apply(owned.frame);
    }
    try receiver.apply(try publisher.snapshotEnd());
    publisher.checkpointComplete(&source);

    var text: [8]u8 = undefined;
    receiver.grid.scrollViewport(1);
    try std.testing.expectEqualStrings(
        "o",
        text[0..receiver.grid.cellText(0, 0, &text)],
    );

    try source.feed("\r\nnew");
    const delta = publisher.historyDelta(&source);
    const first = switch (delta) {
        .append_from => |value| value,
        else => return error.ExpectedHistoryAppend,
    };
    for (first..source.historyCount()) |row| {
        const pushed = try publisher.historyRowFrameAlloc(
            std.testing.allocator,
            &source,
            row,
            0,
            .history_push,
        );
        defer pushed.deinit(std.testing.allocator);
        try receiver.apply(pushed.frame);
    }
    publisher.historyComplete(&source);
    try std.testing.expectEqual(@as(usize, 2), receiver.grid.historyCount());
    try std.testing.expectEqualStrings(
        "o",
        text[0..receiver.grid.cellText(0, 0, &text)],
    );
    receiver.grid.scrollViewport(-100);
    try std.testing.expectEqualStrings(
        "t",
        text[0..receiver.grid.cellText(0, 0, &text)],
    );
}

test "remote mirror rejects incomplete snapshots and input" {
    var receiver = try Receiver.init(std.testing.allocator, 1);
    defer receiver.deinit();
    var info_bytes: [Presentation.snapshot_begin_length]u8 = undefined;
    try Presentation.encodeSnapshotInfo(&info_bytes, .{
        .columns = 2,
        .rows = 1,
        .cursor_column = 0,
        .cursor_row = 0,
        .cursor_visible = true,
        .application_cursor_keys = false,
        .bracketed_paste = false,
    });
    try receiver.apply(.{ .header = .{ .message_type = .snapshot_begin, .stream_id = 1, .sequence = 0, .payload_length = info_bytes.len }, .payload = &info_bytes });
    try std.testing.expectError(error.IncompleteMirrorSnapshot, receiver.apply(.{ .header = .{ .message_type = .snapshot_end, .stream_id = 1, .sequence = 1 }, .payload = "" }));
}
