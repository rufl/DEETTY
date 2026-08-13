const std = @import("std");
const Crypto = @import("Crypto.zig");
const Identity = @import("Identity.zig");
const Mirror = @import("Mirror.zig");
const Protocol = @import("Protocol.zig");
const Session = @import("Session.zig");
const Transport = @import("Transport.zig");

pub const Host = struct {
    peer: Session.HostPeer,
    connection: Transport.SecureConnection,

    pub fn accept(listener: *Transport.Listener, io: Crypto.RandomContext, identity: Crypto.Identity, paired_peer: *const Identity.Peer, stream_id: u32) !Host {
        if (paired_peer.revoked) return error.PairedDeviceRevoked;
        var pending = try listener.accept(io, identity, paired_peer.public_key);
        var connection = (try pending.confirm(pending.sas)).*;
        errdefer connection.close();
        return .{ .peer = try Session.HostPeer.init(stream_id), .connection = connection };
    }

    pub fn close(self: *Host) void {
        self.peer.stop();
        self.connection.close();
    }

    pub fn publish(self: *Host, allocator: std.mem.Allocator, terminal_session: anytype) !void {
        try self.peer.flush(allocator, terminal_session, &self.connection);
    }

    pub fn receiveControl(self: *Host, allocator: std.mem.Allocator) !?[]u8 {
        const bytes = try self.connection.receiveFrameAlloc(allocator);
        defer allocator.free(bytes);
        const frame = try Protocol.decodeFrame(bytes);
        const input = try self.peer.receiveControl(frame) orelse return null;
        return try allocator.dupe(u8, input);
    }

    pub fn grantControl(self: *Host, allocator: std.mem.Allocator) !void {
        try self.peer.grantControl(allocator, &self.connection);
    }

    pub fn revokeControl(self: *Host, allocator: std.mem.Allocator) !void {
        try self.peer.revokeControl(allocator, &self.connection);
    }
};

pub const Viewer = struct {
    receiver: Mirror.Receiver,
    connection: Transport.SecureConnection,
    send_sequence: Protocol.Sequence = .{},

    pub fn connect(allocator: std.mem.Allocator, io: Crypto.RandomContext, host: []const u8, port: u16, identity: Crypto.Identity, paired_peer: *const Identity.Peer, stream_id: u32) !Viewer {
        if (paired_peer.revoked) return error.PairedDeviceRevoked;
        var pending = try Transport.connect(allocator, io, host, port, identity, paired_peer.public_key);
        var connection = (try pending.confirm(pending.sas)).*;
        errdefer connection.close();
        return .{
            .receiver = try Mirror.Receiver.init(allocator, stream_id),
            .connection = connection,
        };
    }

    pub fn close(self: *Viewer) void {
        self.connection.close();
        self.receiver.deinit();
    }

    pub fn receive(self: *Viewer, allocator: std.mem.Allocator) !Protocol.MessageType {
        const bytes = try self.connection.receiveFrameAlloc(allocator);
        defer allocator.free(bytes);
        const frame = try Protocol.decodeFrame(bytes);
        try self.receiver.apply(frame);
        return frame.header.message_type;
    }

    pub fn requestControl(self: *Viewer, allocator: std.mem.Allocator) !void {
        try self.send(allocator, .control_request, "");
        self.receiver.permission.value = .control_requested;
    }

    pub fn sendInput(self: *Viewer, allocator: std.mem.Allocator, bytes: []const u8) !void {
        if (!self.receiver.permission.permitsInput()) return error.ShareInputNotGranted;
        if (bytes.len == 0 or bytes.len > Protocol.max_input_bytes) return error.ShareInputTooLarge;
        try self.send(allocator, .input, bytes);
    }

    fn send(self: *Viewer, allocator: std.mem.Allocator, message_type: Protocol.MessageType, payload: []const u8) !void {
        try self.connection.sendFrame(allocator, .{
            .header = .{
                .message_type = message_type,
                .stream_id = self.receiver.stream_id,
                .sequence = try self.send_sequence.sending(),
                .payload_length = @intCast(payload.len),
            },
            .payload = payload,
        });
    }
};

test "paired session link mirrors a pane and gates remote input" {
    const Vt = @import("../terminal/Vt.zig");
    const FakeSession = struct { grid: Vt.Grid };
    const ServerContext = struct {
        listener: *Transport.Listener,
        io: Crypto.RandomContext,
        identity: Crypto.Identity,
        peer: Identity.Peer,
        input: [8]u8 = undefined,
        input_length: usize = 0,
        failed: bool = false,

        fn run(context: *@This()) void {
            var terminal_session = FakeSession{ .grid = Vt.Grid.init(std.testing.allocator, 12, 2) catch {
                context.failed = true;
                return;
            } };
            defer terminal_session.grid.deinit();
            terminal_session.grid.feed("shared pane") catch {
                context.failed = true;
                return;
            };
            var host = Host.accept(context.listener, context.io, context.identity, &context.peer, 1) catch {
                context.failed = true;
                return;
            };
            defer host.close();
            host.publish(std.testing.allocator, &terminal_session) catch {
                context.failed = true;
                return;
            };
            _ = host.receiveControl(std.testing.allocator) catch {
                context.failed = true;
                return;
            };
            host.grantControl(std.testing.allocator) catch {
                context.failed = true;
                return;
            };
            const input = host.receiveControl(std.testing.allocator) catch {
                context.failed = true;
                return;
            } orelse {
                context.failed = true;
                return;
            };
            defer std.testing.allocator.free(input);
            @memcpy(context.input[0..input.len], input);
            context.input_length = input.len;
        }
    };

    var listener = try Transport.Listener.listen("127.0.0.1", 0);
    defer listener.close();
    const io = Crypto.testingRandomContext();
    const host_identity = Crypto.Identity.generate(io);
    const viewer_identity = Crypto.Identity.generate(io);
    const host_peer = try Identity.Peer.init(viewer_identity.public_key, "viewer", "127.0.0.1", listener.port, 1);
    const viewer_peer = try Identity.Peer.init(host_identity.public_key, "host", "127.0.0.1", listener.port, 1);
    var context = ServerContext{ .listener = &listener, .io = io, .identity = host_identity, .peer = host_peer };
    const thread = try std.Thread.spawn(.{}, ServerContext.run, .{&context});
    var thread_joined = false;
    defer if (!thread_joined) thread.join();
    var viewer = try Viewer.connect(std.testing.allocator, io, "127.0.0.1", listener.port, viewer_identity, &viewer_peer, 1);
    defer viewer.close();
    while (try viewer.receive(std.testing.allocator) != .snapshot_end) {}
    try std.testing.expectEqual(@as(u21, 's'), viewer.receiver.grid.packedCell(0, 0) & 0x1fffff);
    try std.testing.expectError(error.ShareInputNotGranted, viewer.sendInput(std.testing.allocator, "id\n"));
    try viewer.requestControl(std.testing.allocator);
    while (try viewer.receive(std.testing.allocator) != .control_grant) {}
    try viewer.sendInput(std.testing.allocator, "id\n");
    thread.join();
    thread_joined = true;
    try std.testing.expect(!context.failed);
    try std.testing.expectEqualStrings("id\n", context.input[0..context.input_length]);
}
