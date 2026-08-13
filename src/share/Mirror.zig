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
    palette: [max_palette_colors]u32 = undefined,
    palette_count: u16 = 0,
    cursor_column: u16 = 0,
    cursor_row: u16 = 0,
    cursor_visible: bool = true,
    application_cursor_keys: bool = false,
    bracketed_paste: bool = false,
    title_storage: [Protocol.max_title_bytes]u8 = [_]u8{0} ** Protocol.max_title_bytes,
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
        self.palette_count = 0;
    }

    pub fn reset(self: *Grid, info: Presentation.SnapshotInfo) !void {
        try info.validate();
        self.clearRows();
        const rows = try self.allocator.alloc(Row, info.rows);
        errdefer self.allocator.free(rows);
        @memset(rows, .{});
        self.row_data = rows;
        self.columns = info.columns;
        self.rows = info.rows;
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

    pub fn applyRow(self: *Grid, payload: []const u8) !u16 {
        if (self.rows == 0) return error.MirrorSnapshotRequired;
        var decoder = try Presentation.RowDecoder.init(payload);
        if (decoder.row >= self.rows or decoder.first_column != 0 or decoder.cell_count != self.columns)
            return error.InvalidMirrorRow;
        const cells = try self.allocator.alloc(Cell, self.columns);
        errdefer self.allocator.free(cells);
        var text = std.array_list.Managed(u8).init(self.allocator);
        errdefer text.deinit();
        try text.ensureTotalCapacity(@min(payload.len, @as(usize, self.columns) * 4));
        var column: usize = 0;
        while (try decoder.next()) |wire_cell| : (column += 1) {
            const text_offset = text.items.len;
            try text.appendSlice(wire_cell.text);
            const codepoint = if (wire_cell.text.len == 0)
                @as(u21, 0)
            else codepoint: {
                const sequence_length = std.unicode.utf8ByteSequenceLength(wire_cell.text[0]) catch
                    return error.InvalidPresentationUtf8;
                if (sequence_length > wire_cell.text.len) return error.InvalidPresentationUtf8;
                break :codepoint std.unicode.utf8Decode(wire_cell.text[0..sequence_length]) catch
                    return error.InvalidPresentationUtf8;
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
        const owned_text = try text.toOwnedSlice();
        var replacement = Row{ .cells = cells, .text = owned_text };
        self.row_data[decoder.row].deinit(self.allocator);
        self.row_data[decoder.row] = replacement;
        replacement = .{};
        return decoder.row;
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

    pub fn packedCell(self: *const Grid, column: usize, row: usize) u64 {
        if (row >= self.rows or column >= self.columns) return ' ';
        const source = &self.row_data[row];
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
        if (row >= self.rows or column >= self.columns) return 0;
        const source = &self.row_data[row];
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
    snapshot_rows: [Protocol.max_rows]bool = [_]bool{false} ** Protocol.max_rows,
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
        self.permission.revoke();
        self.snapshot_active = false;
        @memset(&self.snapshot_rows, false);
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
                self.snapshot_active = true;
            },
            .row_chunk => {
                if (!self.snapshot_active) return error.InvalidMirrorSnapshotState;
                const row = try self.grid.applyRow(frame.payload);
                if (self.snapshot_rows[row]) return error.DuplicateMirrorSnapshotRow;
                self.snapshot_rows[row] = true;
            },
            .snapshot_end => {
                if (!self.snapshot_active or frame.payload.len != 0)
                    return error.InvalidMirrorSnapshotState;
                for (self.snapshot_rows[0..self.grid.rows]) |present| {
                    if (!present) return error.IncompleteMirrorSnapshot;
                }
                self.snapshot_active = false;
            },
            .damage => {
                if (self.snapshot_active) return error.InvalidMirrorSnapshotState;
                _ = try self.grid.applyRow(frame.payload);
            },
            .title => try self.grid.setTitle(frame.payload),
            .control_request => try self.permission.requestControl(),
            .control_grant => try self.permission.grantControl(),
            .control_revoke => self.permission.revoke(),
            .cursor => try self.grid.applyCursor(frame.payload),
            .hello, .ping, .pong, .pane_open, .pane_close, .workspace_manifest, .resync, .disconnect_reason => {},
            .input => return error.UnexpectedRemoteInput,
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
