const std = @import("std");
const Protocol = @import("Protocol.zig");
const Presentation = @import("Presentation.zig");
const Transport = @import("Transport.zig");

pub const HostPeer = struct {
    stream_id: u32,
    publisher: Presentation.Publisher,
    receive_sequence: Protocol.Sequence = .{},
    permission: Protocol.PermissionState = .{},
    changed_rows: [Protocol.max_rows]bool = [_]bool{false} ** Protocol.max_rows,
    checkpoint_required: bool = true,
    stopped: bool = false,

    pub fn init(stream_id: u32) !HostPeer {
        return .{ .stream_id = stream_id, .publisher = try Presentation.Publisher.init(stream_id) };
    }

    // UI-thread observation only records bounded damage. Encoding and socket
    // writes happen later on the network worker via flush().
    pub fn observe(self: *HostPeer, session: anytype) void {
        if (self.stopped or self.checkpoint_required) return;
        var rows: [Protocol.max_rows]u8 = undefined;
        const damage = self.publisher.changedRows(&session.grid, rows[0..session.grid.rows]);
        _ = damage;
        var changed_count: usize = 0;
        for (rows[0..session.grid.rows], 0..) |changed, row| {
            if (changed != 0) self.changed_rows[row] = true;
            if (self.changed_rows[row]) changed_count += 1;
        }
        const estimated = changed_count * @as(usize, session.grid.columns) * Presentation.cell_header_length;
        if (estimated > Protocol.max_pending_peer_bytes) {
            @memset(&self.changed_rows, false);
            self.checkpoint_required = true;
        }
    }

    pub fn flush(self: *HostPeer, allocator: std.mem.Allocator, session: anytype, connection: *Transport.SecureConnection) !void {
        if (self.stopped) return error.ShareStopped;
        if (self.checkpoint_required) {
            try self.sendCheckpoint(allocator, session, connection);
            self.checkpoint_required = false;
            @memset(&self.changed_rows, false);
            self.publisher.checkpointComplete(&session.grid);
            return;
        }
        for (self.changed_rows[0..session.grid.rows], 0..) |*changed, row| {
            if (!changed.*) continue;
            const owned = try self.publisher.rowFrameAlloc(allocator, &session.grid, row, .damage);
            defer owned.deinit(allocator);
            try connection.sendFrame(allocator, owned.frame);
            changed.* = false;
        }
        if (try self.publisher.cursorFrame(&session.grid)) |cursor_value| {
            var cursor = cursor_value;
            cursor.frame.payload = &cursor.payload;
            try connection.sendFrame(allocator, cursor.frame);
        }
        if (try self.publisher.titleFrame(&session.grid, false)) |title|
            try connection.sendFrame(allocator, title);
    }

    fn sendCheckpoint(self: *HostPeer, allocator: std.mem.Allocator, session: anytype, connection: *Transport.SecureConnection) !void {
        var begin = try self.publisher.snapshotBegin(&session.grid, 0);
        begin.frame.payload = &begin.payload;
        try connection.sendFrame(allocator, begin.frame);
        for (0..session.grid.rows) |row| {
            const owned = try self.publisher.rowFrameAlloc(allocator, &session.grid, row, .row_chunk);
            defer owned.deinit(allocator);
            try connection.sendFrame(allocator, owned.frame);
        }
        try connection.sendFrame(allocator, try self.publisher.snapshotEnd());
        if (try self.publisher.titleFrame(&session.grid, true)) |title|
            try connection.sendFrame(allocator, title);
    }

    pub fn receiveControl(self: *HostPeer, frame: Protocol.Frame) !?[]const u8 {
        if (self.stopped or frame.header.stream_id != self.stream_id)
            return error.InvalidShareStream;
        try self.receive_sequence.receive(frame.header.sequence);
        switch (frame.header.message_type) {
            .control_request => {
                if (frame.payload.len != 0) return error.InvalidShareControl;
                try self.permission.requestControl();
                return null;
            },
            .input => {
                if (!self.permission.permitsInput()) return error.ShareInputNotGranted;
                if (frame.payload.len == 0 or frame.payload.len > Protocol.max_input_bytes)
                    return error.ShareInputTooLarge;
                return frame.payload;
            },
            .ping => return null,
            else => return error.InvalidShareControl,
        }
    }

    pub fn grantControl(self: *HostPeer, allocator: std.mem.Allocator, connection: *Transport.SecureConnection) !void {
        try self.permission.grantControl();
        try connection.sendFrame(allocator, .{
            .header = .{
                .message_type = .control_grant,
                .stream_id = self.stream_id,
                .sequence = try self.publisher.sequence.sending(),
                .payload_length = 0,
            },
            .payload = "",
        });
    }

    pub fn denyControl(self: *HostPeer) !void {
        try self.permission.denyControl();
    }

    pub fn revokeControl(self: *HostPeer, allocator: std.mem.Allocator, connection: *Transport.SecureConnection) !void {
        self.permission.revoke();
        try connection.sendFrame(allocator, .{
            .header = .{
                .message_type = .control_revoke,
                .stream_id = self.stream_id,
                .sequence = try self.publisher.sequence.sending(),
                .payload_length = 0,
            },
            .payload = "",
        });
    }

    pub fn stop(self: *HostPeer) void {
        self.permission.revoke();
        self.stopped = true;
        @memset(&self.changed_rows, false);
    }
};

pub const PaneManifest = struct {
    stream_id: u32,
    pane_id: u64,
    title: []const u8,
};

pub fn encodeWorkspaceManifestAlloc(allocator: std.mem.Allocator, panes: []const PaneManifest) ![]u8 {
    if (panes.len == 0 or panes.len > Protocol.max_streams) return error.InvalidShareWorkspace;
    var bytes = std.array_list.Managed(u8).init(allocator);
    errdefer bytes.deinit();
    var count_bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &count_bytes, @intCast(panes.len), .big);
    try bytes.appendSlice(&count_bytes);
    for (panes, 0..) |pane, index| {
        if (pane.stream_id == 0 or pane.stream_id > Protocol.max_streams or
            pane.pane_id == 0 or pane.title.len > Protocol.max_title_bytes or
            !std.unicode.utf8ValidateSlice(pane.title))
            return error.InvalidShareWorkspace;
        for (panes[0..index]) |previous| {
            if (previous.stream_id == pane.stream_id or previous.pane_id == pane.pane_id)
                return error.InvalidShareWorkspace;
        }
        var fixed: [14]u8 = undefined;
        std.mem.writeInt(u32, fixed[0..4], pane.stream_id, .big);
        std.mem.writeInt(u64, fixed[4..12], pane.pane_id, .big);
        std.mem.writeInt(u16, fixed[12..14], @intCast(pane.title.len), .big);
        try bytes.appendSlice(&fixed);
        try bytes.appendSlice(pane.title);
        if (bytes.items.len > Protocol.max_payload_bytes) return error.InvalidShareWorkspace;
    }
    return bytes.toOwnedSlice();
}

pub const ManifestDecoder = struct {
    bytes: []const u8,
    offset: usize = 2,
    remaining: u16,

    pub fn init(bytes: []const u8) !ManifestDecoder {
        if (bytes.len < 2 or bytes.len > Protocol.max_payload_bytes)
            return error.InvalidShareWorkspace;
        const count = std.mem.readInt(u16, bytes[0..2], .big);
        if (count == 0 or count > Protocol.max_streams)
            return error.InvalidShareWorkspace;
        return .{ .bytes = bytes, .remaining = count };
    }

    pub fn next(self: *ManifestDecoder) !?PaneManifest {
        if (self.remaining == 0) {
            if (self.offset != self.bytes.len) return error.InvalidShareWorkspace;
            return null;
        }
        if (self.bytes.len - self.offset < 14) return error.InvalidShareWorkspace;
        const fixed = self.bytes[self.offset .. self.offset + 14];
        const stream_id = std.mem.readInt(u32, fixed[0..4], .big);
        const pane_id = std.mem.readInt(u64, fixed[4..12], .big);
        const title_length: usize = std.mem.readInt(u16, fixed[12..14], .big);
        self.offset += 14;
        if (stream_id == 0 or stream_id > Protocol.max_streams or pane_id == 0 or
            title_length > Protocol.max_title_bytes or
            title_length > self.bytes.len - self.offset)
            return error.InvalidShareWorkspace;
        const title = self.bytes[self.offset .. self.offset + title_length];
        if (!std.unicode.utf8ValidateSlice(title)) return error.InvalidShareWorkspace;
        self.offset += title_length;
        self.remaining -= 1;
        if (self.remaining == 0 and self.offset != self.bytes.len)
            return error.InvalidShareWorkspace;
        return .{ .stream_id = stream_id, .pane_id = pane_id, .title = title };
    }
};

test "host peer coalesces independent row damage and gates input" {
    const Vt = @import("../terminal/Vt.zig");
    const FakeSession = struct { grid: Vt.Grid };
    var session = FakeSession{ .grid = try Vt.Grid.init(std.testing.allocator, 8, 2) };
    defer session.grid.deinit();
    var peer = try HostPeer.init(1);
    peer.checkpoint_required = false;
    peer.publisher.checkpointComplete(&session.grid);
    try session.grid.feed("X");
    peer.observe(&session);
    try std.testing.expect(peer.changed_rows[0]);
    try std.testing.expectError(error.ShareInputNotGranted, peer.receiveControl(.{
        .header = .{ .message_type = .input, .stream_id = 1, .sequence = 0, .payload_length = 1 },
        .payload = "x",
    }));
    try peer.receive_sequence.receive(1);
}

test "workspace manifest is bounded and omits process identifiers" {
    const bytes = try encodeWorkspaceManifestAlloc(std.testing.allocator, &.{
        .{ .stream_id = 1, .pane_id = 41, .title = "Shell" },
        .{ .stream_id = 2, .pane_id = 42, .title = "Logs" },
    });
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(bytes.len < 128);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "/tmp") == null);
}

test "workspace manifest decoder rejects duplicates and trailing bytes" {
    const panes = [_]PaneManifest{
        .{ .stream_id = 1, .pane_id = 41, .title = "Shell" },
        .{ .stream_id = 2, .pane_id = 42, .title = "Logs" },
    };
    const bytes = try encodeWorkspaceManifestAlloc(std.testing.allocator, &panes);
    defer std.testing.allocator.free(bytes);
    var decoder = try ManifestDecoder.init(bytes);
    for (panes) |expected| {
        const decoded = (try decoder.next()).?;
        try std.testing.expectEqual(expected.stream_id, decoded.stream_id);
        try std.testing.expectEqual(expected.pane_id, decoded.pane_id);
        try std.testing.expectEqualStrings(expected.title, decoded.title);
    }
    try std.testing.expect((try decoder.next()) == null);
    try std.testing.expectError(error.InvalidShareWorkspace, encodeWorkspaceManifestAlloc(
        std.testing.allocator,
        &.{
            .{ .stream_id = 1, .pane_id = 41, .title = "Shell" },
            .{ .stream_id = 1, .pane_id = 42, .title = "Duplicate" },
        },
    ));
    const malformed = try std.testing.allocator.alloc(u8, bytes.len + 1);
    defer std.testing.allocator.free(malformed);
    @memcpy(malformed[0..bytes.len], bytes);
    malformed[bytes.len] = 0;
    var malformed_decoder = try ManifestDecoder.init(malformed);
    _ = try malformed_decoder.next();
    try std.testing.expectError(error.InvalidShareWorkspace, malformed_decoder.next());
}
