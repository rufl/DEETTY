const std = @import("std");
const Protocol = @import("Protocol.zig");
const Vt = @import("../terminal/Vt.zig");

pub const max_grapheme_bytes: usize = 128;
pub const row_header_length: usize = 6;
pub const cell_header_length: usize = 12;
pub const snapshot_begin_length: usize = 13;
pub const cursor_payload_length: usize = 5;

pub const CursorInfo = struct {
    column: u16,
    row: u16,
    visible: bool,
    application_cursor_keys: bool,
    bracketed_paste: bool,
};

pub fn encodeCursorInfo(output: *[cursor_payload_length]u8, info: CursorInfo) void {
    std.mem.writeInt(u16, output[0..2], info.column, .big);
    std.mem.writeInt(u16, output[2..4], info.row, .big);
    output[4] = @as(u8, @intFromBool(info.visible)) |
        (@as(u8, @intFromBool(info.application_cursor_keys)) << 1) |
        (@as(u8, @intFromBool(info.bracketed_paste)) << 2);
}

pub fn decodeCursorInfo(input: *const [cursor_payload_length]u8) !CursorInfo {
    if (input[4] & 0xf8 != 0) return error.InvalidPresentationCursor;
    return .{
        .column = std.mem.readInt(u16, input[0..2], .big),
        .row = std.mem.readInt(u16, input[2..4], .big),
        .visible = input[4] & 1 != 0,
        .application_cursor_keys = input[4] & 2 != 0,
        .bracketed_paste = input[4] & 4 != 0,
    };
}

pub const CellFlags = packed struct(u16) {
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

pub const SnapshotInfo = struct {
    columns: u16,
    rows: u16,
    scrollback_rows: u32 = 0,
    cursor_column: u16,
    cursor_row: u16,
    cursor_visible: bool,
    application_cursor_keys: bool,
    bracketed_paste: bool,

    pub fn validate(self: SnapshotInfo) !void {
        if (self.columns == 0 or self.columns > Protocol.max_columns or
            self.rows == 0 or self.rows > Protocol.max_rows or
            self.scrollback_rows > Protocol.max_scrollback_rows or
            self.cursor_column >= self.columns or self.cursor_row >= self.rows)
            return error.InvalidPresentationSnapshot;
    }
};

pub fn snapshotInfo(grid: *const Vt.Grid, scrollback_rows: u32) !SnapshotInfo {
    const info = SnapshotInfo{
        .columns = std.math.cast(u16, grid.columns) orelse return error.InvalidPresentationSnapshot,
        .rows = std.math.cast(u16, grid.rows) orelse return error.InvalidPresentationSnapshot,
        .scrollback_rows = @min(scrollback_rows, Protocol.max_scrollback_rows),
        .cursor_column = std.math.cast(u16, grid.cursor_column) orelse return error.InvalidPresentationSnapshot,
        .cursor_row = std.math.cast(u16, grid.cursor_row) orelse return error.InvalidPresentationSnapshot,
        .cursor_visible = grid.cursor_visible,
        .application_cursor_keys = grid.application_cursor_keys,
        .bracketed_paste = grid.bracketed_paste,
    };
    try info.validate();
    return info;
}

fn cursorInfo(grid: *const Vt.Grid) !CursorInfo {
    const info = CursorInfo{
        .column = std.math.cast(u16, grid.cursor_column) orelse
            return error.InvalidPresentationCursor,
        .row = std.math.cast(u16, grid.cursor_row) orelse
            return error.InvalidPresentationCursor,
        .visible = grid.cursor_visible,
        .application_cursor_keys = grid.application_cursor_keys,
        .bracketed_paste = grid.bracketed_paste,
    };
    if (info.column >= grid.columns or info.row >= grid.rows)
        return error.InvalidPresentationCursor;
    return info;
}

pub fn encodeSnapshotInfo(output: *[snapshot_begin_length]u8, info: SnapshotInfo) !void {
    try info.validate();
    std.mem.writeInt(u16, output[0..2], info.columns, .big);
    std.mem.writeInt(u16, output[2..4], info.rows, .big);
    std.mem.writeInt(u32, output[4..8], info.scrollback_rows, .big);
    std.mem.writeInt(u16, output[8..10], info.cursor_column, .big);
    std.mem.writeInt(u16, output[10..12], info.cursor_row, .big);
    output[12] = @as(u8, @intFromBool(info.cursor_visible)) |
        (@as(u8, @intFromBool(info.application_cursor_keys)) << 1) |
        (@as(u8, @intFromBool(info.bracketed_paste)) << 2);
}

pub fn decodeSnapshotInfo(input: *const [snapshot_begin_length]u8) !SnapshotInfo {
    const mode = input[12];
    if (mode & 0xf8 != 0) return error.InvalidPresentationSnapshot;
    const info = SnapshotInfo{
        .columns = std.mem.readInt(u16, input[0..2], .big),
        .rows = std.mem.readInt(u16, input[2..4], .big),
        .scrollback_rows = std.mem.readInt(u32, input[4..8], .big),
        .cursor_column = std.mem.readInt(u16, input[8..10], .big),
        .cursor_row = std.mem.readInt(u16, input[10..12], .big),
        .cursor_visible = mode & 1 != 0,
        .application_cursor_keys = mode & 2 != 0,
        .bracketed_paste = mode & 4 != 0,
    };
    try info.validate();
    return info;
}

pub const OwnedFrame = struct {
    frame: Protocol.Frame,
    bytes: []u8,

    pub fn deinit(self: OwnedFrame, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

pub const Publisher = struct {
    stream_id: u32,
    sequence: Protocol.Sequence = .{},
    damage_generation: u64 = 0,
    cursor_initialized: bool = false,
    last_cursor: CursorInfo = .{
        .column = 0,
        .row = 0,
        .visible = true,
        .application_cursor_keys = false,
        .bracketed_paste = false,
    },
    title_initialized: bool = false,
    last_title_digest: [32]u8 = [_]u8{0} ** 32,

    pub fn init(stream_id: u32) !Publisher {
        if (stream_id == 0 or stream_id > Protocol.max_streams)
            return error.InvalidShareStream;
        return .{ .stream_id = stream_id };
    }

    pub fn snapshotBegin(self: *Publisher, grid: *const Vt.Grid, scrollback_rows: u32) !struct { frame: Protocol.Frame, payload: [snapshot_begin_length]u8 } {
        const info = try snapshotInfo(grid, scrollback_rows);
        var payload: [snapshot_begin_length]u8 = undefined;
        try encodeSnapshotInfo(&payload, info);
        self.last_cursor = try cursorInfo(grid);
        self.cursor_initialized = true;
        return .{
            .frame = .{
                .header = .{
                    .message_type = .snapshot_begin,
                    .stream_id = self.stream_id,
                    .sequence = try self.sequence.sending(),
                    .payload_length = payload.len,
                },
                .payload = &.{},
            },
            .payload = payload,
        };
    }

    pub fn rowFrameAlloc(self: *Publisher, allocator: std.mem.Allocator, grid: *const Vt.Grid, row: usize, message_type: Protocol.MessageType) !OwnedFrame {
        if (message_type != .row_chunk and message_type != .damage)
            return error.InvalidPresentationMessage;
        const bytes = try encodeGridRowAlloc(allocator, grid, row);
        errdefer allocator.free(bytes);
        return .{
            .frame = .{
                .header = .{
                    .message_type = message_type,
                    .stream_id = self.stream_id,
                    .sequence = try self.sequence.sending(),
                    .payload_length = @intCast(bytes.len),
                },
                .payload = bytes,
            },
            .bytes = bytes,
        };
    }

    pub fn snapshotEnd(self: *Publisher) !Protocol.Frame {
        return .{
            .header = .{
                .message_type = .snapshot_end,
                .flags = .{ .final = true },
                .stream_id = self.stream_id,
                .sequence = try self.sequence.sending(),
                .payload_length = 0,
            },
            .payload = "",
        };
    }

    pub fn cursorFrame(self: *Publisher, grid: *const Vt.Grid) !?struct {
        frame: Protocol.Frame,
        payload: [cursor_payload_length]u8,
    } {
        const current = try cursorInfo(grid);
        if (self.cursor_initialized and std.meta.eql(self.last_cursor, current))
            return null;
        var payload: [cursor_payload_length]u8 = undefined;
        encodeCursorInfo(&payload, current);
        self.last_cursor = current;
        self.cursor_initialized = true;
        return .{
            .frame = .{
                .header = .{
                    .message_type = .cursor,
                    .stream_id = self.stream_id,
                    .sequence = try self.sequence.sending(),
                    .payload_length = payload.len,
                },
                .payload = &.{},
            },
            .payload = payload,
        };
    }

    pub fn titleFrame(self: *Publisher, grid: *const Vt.Grid, force: bool) !?Protocol.Frame {
        const title = grid.titleSlice();
        if (title.len > Protocol.max_title_bytes or !std.unicode.utf8ValidateSlice(title))
            return error.InvalidPresentationTitle;
        var digest: [32]u8 = undefined;
        std.crypto.hash.blake2.Blake2s256.hash(title, &digest, .{});
        if (!force and self.title_initialized and
            std.crypto.timing_safe.eql([32]u8, self.last_title_digest, digest))
            return null;
        self.last_title_digest = digest;
        self.title_initialized = true;
        return .{
            .header = .{
                .message_type = .title,
                .stream_id = self.stream_id,
                .sequence = try self.sequence.sending(),
                .payload_length = @intCast(title.len),
            },
            .payload = title,
        };
    }

    pub fn changedRows(self: *Publisher, grid: *const Vt.Grid, output: []u8) Vt.Grid.DamageSnapshot {
        const damage = grid.damageRowsSince(self.damage_generation, output);
        self.damage_generation = damage.generation;
        return damage;
    }

    pub fn checkpointComplete(self: *Publisher, grid: *const Vt.Grid) void {
        self.damage_generation = grid.damage_generation;
    }
};

pub fn encodeGridRowAlloc(allocator: std.mem.Allocator, grid: *const Vt.Grid, row: usize) ![]u8 {
    if (row >= grid.rows or row > std.math.maxInt(u16) or grid.columns > Protocol.max_columns)
        return error.InvalidPresentationRow;
    var bytes = std.array_list.Managed(u8).init(allocator);
    errdefer bytes.deinit();
    try bytes.ensureTotalCapacity(row_header_length + grid.columns * (cell_header_length + 1));
    var row_header: [row_header_length]u8 = undefined;
    std.mem.writeInt(u16, row_header[0..2], @intCast(row), .big);
    std.mem.writeInt(u16, row_header[2..4], 0, .big);
    std.mem.writeInt(u16, row_header[4..6], @intCast(grid.columns), .big);
    try bytes.appendSlice(&row_header);
    for (0..grid.columns) |column| {
        const cell = grid.cell(column, row);
        var text: [max_grapheme_bytes]u8 = undefined;
        const text_length = grid.cellText(column, row, &text);
        if (text_length > max_grapheme_bytes) return error.PresentationGraphemeTooLarge;
        const flags = CellFlags{
            .bold = cell.flags.bold,
            .inverse = cell.flags.inverse,
            .italic = cell.flags.italic,
            .underline = cell.flags.underline,
            .strikethrough = cell.flags.strikethrough,
            .dim = cell.flags.dim,
            .continuation = cell.flags.continuation,
            .width = cell.flags.width,
        };
        var header: [cell_header_length]u8 = undefined;
        header[0] = @intCast(text_length);
        header[1] = 0;
        std.mem.writeInt(u16, header[2..4], @bitCast(flags), .big);
        std.mem.writeInt(u32, header[4..8], grid.colorRgb(cell.foreground), .big);
        std.mem.writeInt(u32, header[8..12], grid.colorRgb(cell.background), .big);
        if (bytes.items.len + header.len + text_length > Protocol.max_payload_bytes)
            return error.PresentationRowTooLarge;
        try bytes.appendSlice(&header);
        try bytes.appendSlice(text[0..text_length]);
    }
    return bytes.toOwnedSlice();
}

pub const RowDecoder = struct {
    bytes: []const u8,
    offset: usize = row_header_length,
    row: u16,
    first_column: u16,
    cell_count: u16,
    decoded_cells: u16 = 0,

    pub const Cell = struct {
        text: []const u8,
        flags: CellFlags,
        foreground_rgb: u32,
        background_rgb: u32,
    };

    pub fn init(bytes: []const u8) !RowDecoder {
        if (bytes.len < row_header_length or bytes.len > Protocol.max_payload_bytes)
            return error.InvalidPresentationRow;
        const decoder = RowDecoder{
            .bytes = bytes,
            .row = std.mem.readInt(u16, bytes[0..2], .big),
            .first_column = std.mem.readInt(u16, bytes[2..4], .big),
            .cell_count = std.mem.readInt(u16, bytes[4..6], .big),
        };
        if (decoder.cell_count == 0 or decoder.cell_count > Protocol.max_columns or
            @as(u32, decoder.first_column) + decoder.cell_count > Protocol.max_columns)
            return error.InvalidPresentationRow;
        return decoder;
    }

    pub fn next(self: *RowDecoder) !?Cell {
        if (self.decoded_cells == self.cell_count) {
            if (self.offset != self.bytes.len) return error.InvalidPresentationRow;
            return null;
        }
        if (self.bytes.len - self.offset < cell_header_length)
            return error.InvalidPresentationRow;
        const header = self.bytes[self.offset..][0..cell_header_length];
        const text_length: usize = header[0];
        if (header[1] != 0 or text_length > max_grapheme_bytes or
            self.bytes.len - self.offset < cell_header_length + text_length)
            return error.InvalidPresentationRow;
        const raw_flags = std.mem.readInt(u16, header[2..4], .big);
        if (raw_flags & 0xfe00 != 0) return error.InvalidPresentationRow;
        const flags: CellFlags = @bitCast(raw_flags);
        if (flags.width > 2) return error.InvalidPresentationRow;
        const text = self.bytes[self.offset + cell_header_length .. self.offset + cell_header_length + text_length];
        if (!flags.continuation and text_length == 0) return error.InvalidPresentationRow;
        if (text_length != 0 and !std.unicode.utf8ValidateSlice(text)) return error.InvalidPresentationUtf8;
        const cell = Cell{
            .text = text,
            .flags = flags,
            .foreground_rgb = std.mem.readInt(u32, header[4..8], .big),
            .background_rgb = std.mem.readInt(u32, header[8..12], .big),
        };
        self.offset += cell_header_length + text_length;
        self.decoded_cells += 1;
        return cell;
    }
};

test "presentation row preserves Unicode styles and resolved colors" {
    var grid = try Vt.Grid.init(std.testing.allocator, 8, 2);
    defer grid.deinit();
    try grid.feed("\x1b[1;38;2;143;184;255mAé");
    const encoded = try encodeGridRowAlloc(std.testing.allocator, &grid, 0);
    defer std.testing.allocator.free(encoded);
    var decoder = try RowDecoder.init(encoded);
    const first = (try decoder.next()).?;
    try std.testing.expectEqualStrings("A", first.text);
    try std.testing.expect(first.flags.bold);
    try std.testing.expectEqual(@as(u32, 0x8fb8ff), first.foreground_rgb);
    const second = (try decoder.next()).?;
    try std.testing.expectEqualStrings("é", second.text);
}

test "presentation publisher observes damage after local renderer consumes it" {
    var grid = try Vt.Grid.init(std.testing.allocator, 8, 3);
    defer grid.deinit();
    var publisher = try Publisher.init(1);
    var rows: [3]u8 = undefined;
    _ = publisher.changedRows(&grid, &rows);
    var renderer_spans: [3]Vt.DirtySpan = undefined;
    _ = grid.takeDirtySpans(&renderer_spans);
    try grid.feed("\x1b[2;1HX");
    _ = grid.takeDirtySpans(&renderer_spans);
    _ = publisher.changedRows(&grid, &rows);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0 }, &rows);
}

test "presentation decoder rejects truncated and invalid UTF-8 rows" {
    var bytes = [_]u8{0} ** (row_header_length + cell_header_length + 1);
    std.mem.writeInt(u16, bytes[4..6], 1, .big);
    bytes[row_header_length] = 1;
    bytes[row_header_length + cell_header_length] = 0xff;
    var decoder = try RowDecoder.init(&bytes);
    try std.testing.expectError(error.InvalidPresentationUtf8, decoder.next());
}
