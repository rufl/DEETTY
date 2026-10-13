const std = @import("std");

pub const magic = "NCTS";
pub const version: u8 = 4;
pub const header_length: usize = 24;
pub const max_payload_bytes: usize = 60 * 1024;
pub const max_wire_bytes: usize = header_length + max_payload_bytes;
pub const max_streams: usize = 64;
pub const max_tabs: usize = 64;
pub const max_layout_nodes: usize = 2 * max_streams - 1;
pub const max_columns: u16 = 1000;
pub const max_rows: u16 = 500;
pub const max_scrollback_rows: u32 = 64;
pub const max_title_bytes: usize = 4096;
pub const max_alias_bytes: usize = 128;
pub const max_input_bytes: usize = 16 * 1024;
pub const max_pending_peer_bytes: usize = 8 * 1024 * 1024;

pub const MessageType = enum(u8) {
    hello = 1,
    workspace_manifest = 2,
    pane_open = 3,
    pane_close = 4,
    snapshot_begin = 5,
    row_chunk = 6,
    snapshot_end = 7,
    damage = 8,
    cursor = 9,
    title = 10,
    input = 11,
    control_request = 12,
    control_grant = 13,
    control_revoke = 14,
    resync = 15,
    ping = 16,
    pong = 17,
    disconnect_reason = 18,
    workspace_update = 19,
    control_release = 20,
    history_row = 21,
    history_push = 22,
};

pub const Flags = packed struct(u16) {
    optional: bool = false,
    final: bool = false,
    view_only: bool = true,
    _: u13 = 0,
};

pub const Header = struct {
    message_type: MessageType,
    flags: Flags = .{},
    stream_id: u32 = 0,
    sequence: u64 = 0,
    payload_length: u32 = 0,

    pub fn validate(self: Header) !void {
        if (self.payload_length > max_payload_bytes) return error.SharePayloadTooLarge;
        const workspace_message = switch (self.message_type) {
            .hello, .workspace_manifest, .workspace_update, .pane_open, .pane_close, .ping, .pong, .disconnect_reason => true,
            else => false,
        };
        if ((self.stream_id == 0) != workspace_message) return error.InvalidShareStream;
        if (self.message_type == .input and self.payload_length > max_input_bytes)
            return error.ShareInputTooLarge;
    }
};

pub const Frame = struct {
    header: Header,
    payload: []const u8,
};

pub fn encodeHeader(output: *[header_length]u8, header: Header) !void {
    try header.validate();
    @memcpy(output[0..magic.len], magic);
    output[4] = version;
    output[5] = @backingInt(header.message_type);
    std.mem.writeInt(u16, output[6..8], @bitCast(header.flags), .big);
    std.mem.writeInt(u32, output[8..12], header.stream_id, .big);
    std.mem.writeInt(u64, output[12..20], header.sequence, .big);
    std.mem.writeInt(u32, output[20..24], header.payload_length, .big);
}

pub fn decodeHeader(input: *const [header_length]u8) !Header {
    if (!std.mem.eql(u8, input[0..magic.len], magic)) return error.InvalidShareMagic;
    if (input[4] != version) return error.UnsupportedShareProtocol;
    const message_type: MessageType = switch (input[5]) {
        1 => .hello,
        2 => .workspace_manifest,
        3 => .pane_open,
        4 => .pane_close,
        5 => .snapshot_begin,
        6 => .row_chunk,
        7 => .snapshot_end,
        8 => .damage,
        9 => .cursor,
        10 => .title,
        11 => .input,
        12 => .control_request,
        13 => .control_grant,
        14 => .control_revoke,
        15 => .resync,
        16 => .ping,
        17 => .pong,
        18 => .disconnect_reason,
        19 => .workspace_update,
        20 => .control_release,
        21 => .history_row,
        22 => .history_push,
        else => return error.UnknownShareMessage,
    };
    if (std.mem.readInt(u16, input[6..8], .big) & 0xfff8 != 0)
        return error.InvalidShareFlags;
    const header = Header{
        .message_type = message_type,
        .flags = @bitCast(std.mem.readInt(u16, input[6..8], .big)),
        .stream_id = std.mem.readInt(u32, input[8..12], .big),
        .sequence = std.mem.readInt(u64, input[12..20], .big),
        .payload_length = std.mem.readInt(u32, input[20..24], .big),
    };
    try header.validate();
    return header;
}

pub fn encodeFrameAlloc(allocator: std.mem.Allocator, frame: Frame) ![]u8 {
    if (frame.payload.len != frame.header.payload_length) return error.InvalidSharePayloadLength;
    try frame.header.validate();
    const output = try allocator.alloc(u8, header_length + frame.payload.len);
    errdefer allocator.free(output);
    try encodeHeader(output[0..header_length], frame.header);
    @memcpy(output[header_length..], frame.payload);
    return output;
}

pub fn decodeFrame(bytes: []const u8) !Frame {
    if (bytes.len < header_length) return error.TruncatedShareFrame;
    const header = try decodeHeader(bytes[0..header_length]);
    const expected = try std.math.add(usize, header_length, header.payload_length);
    if (bytes.len != expected) return error.InvalidSharePayloadLength;
    return .{ .header = header, .payload = bytes[header_length..] };
}

pub const Permission = enum(u8) {
    view_only,
    control_requested,
    control_granted,
};

pub const PermissionState = struct {
    value: Permission = .view_only,

    pub fn requestControl(self: *PermissionState) !void {
        if (self.value != .view_only) return error.InvalidPermissionTransition;
        self.value = .control_requested;
    }

    pub fn grantControl(self: *PermissionState) !void {
        if (self.value != .control_requested) return error.InvalidPermissionTransition;
        self.value = .control_granted;
    }

    pub fn denyControl(self: *PermissionState) !void {
        if (self.value != .control_requested) return error.InvalidPermissionTransition;
        self.value = .view_only;
    }

    pub fn revoke(self: *PermissionState) void {
        self.value = .view_only;
    }

    pub fn permitsInput(self: PermissionState) bool {
        return self.value == .control_granted;
    }
};

pub const Sequence = struct {
    next_send: u64 = 0,
    next_receive: u64 = 0,

    pub fn sending(self: *Sequence) !u64 {
        if (self.next_send == std.math.maxInt(u64)) return error.ShareSequenceExhausted;
        const value = self.next_send;
        self.next_send += 1;
        return value;
    }

    pub fn receive(self: *Sequence, value: u64) !void {
        if (value != self.next_receive) return error.InvalidShareSequence;
        if (self.next_receive == std.math.maxInt(u64)) return error.ShareSequenceExhausted;
        self.next_receive += 1;
    }
};

test "share frames round trip with fixed endian encoding" {
    const payload = "screen update";
    const encoded = try encodeFrameAlloc(std.testing.allocator, .{
        .header = .{
            .message_type = .damage,
            .stream_id = std.math.maxInt(u32),
            .sequence = 42,
            .payload_length = payload.len,
        },
        .payload = payload,
    });
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeFrame(encoded);
    try std.testing.expectEqual(MessageType.damage, decoded.header.message_type);
    try std.testing.expectEqual(std.math.maxInt(u32), decoded.header.stream_id);
    try std.testing.expectEqual(@as(u64, 42), decoded.header.sequence);
    try std.testing.expectEqualStrings(payload, decoded.payload);
}

test "share frames reject allocations implied by hostile lengths" {
    var bytes: [header_length]u8 = undefined;
    try encodeHeader(&bytes, .{ .message_type = .damage, .stream_id = 1, .payload_length = 0 });
    std.mem.writeInt(u32, bytes[20..24], max_payload_bytes + 1, .big);
    try std.testing.expectError(error.SharePayloadTooLarge, decodeHeader(&bytes));
    try std.testing.expectError(error.TruncatedShareFrame, decodeFrame(bytes[0..12]));
}

test "remote input requires an explicit temporary grant" {
    var state = PermissionState{};
    try std.testing.expect(!state.permitsInput());
    try state.requestControl();
    try state.grantControl();
    try std.testing.expect(state.permitsInput());
    state.revoke();
    try std.testing.expect(!state.permitsInput());
    try std.testing.expectError(error.InvalidPermissionTransition, state.grantControl());
}

test "share sequence rejects replay and gaps" {
    var sequence = Sequence{};
    try sequence.receive(0);
    try std.testing.expectError(error.InvalidShareSequence, sequence.receive(0));
    try std.testing.expectError(error.InvalidShareSequence, sequence.receive(2));
    try sequence.receive(1);
}
