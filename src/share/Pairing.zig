const std = @import("std");
const Crypto = @import("Crypto.zig");
const Identity = @import("Identity.zig");
const Protocol = @import("Protocol.zig");
const Transport = @import("Transport.zig");

const confirmation_payload = "DINTTY-PAIR-CONFIRMED-v1";

pub const Session = struct {
    pending: Transport.PendingConnection,
    remote_alias: [Protocol.max_alias_bytes]u8 = @splat(0),
    remote_alias_length: u8,
    remote_endpoint: [Identity.max_endpoint_bytes]u8 = @splat(0),
    remote_endpoint_length: u8,
    remote_port: u16,
    finished: bool = false,

    fn init(pending: Transport.PendingConnection, alias: []const u8, endpoint: []const u8, port: u16) !Session {
        if (alias.len == 0 or alias.len > Protocol.max_alias_bytes or
            endpoint.len == 0 or endpoint.len > Identity.max_endpoint_bytes or port == 0 or
            std.mem.indexOfAny(u8, alias, "\x00\r\n") != null or
            std.mem.indexOfAny(u8, endpoint, "\x00\r\n") != null)
            return error.InvalidPairingPeer;
        var result = Session{
            .pending = pending,
            .remote_alias_length = @intCast(alias.len),
            .remote_endpoint_length = @intCast(endpoint.len),
            .remote_port = port,
        };
        @memcpy(result.remote_alias[0..alias.len], alias);
        @memcpy(result.remote_endpoint[0..endpoint.len], endpoint);
        return result;
    }

    pub fn sas(self: *const Session) u32 {
        return self.pending.sas;
    }

    pub fn formatSas(self: *const Session, output: *[6]u8) void {
        var value = self.sas();
        var index: usize = output.len;
        while (index != 0) {
            index -= 1;
            output[index] = @intCast('0' + value % 10);
            value /= 10;
        }
    }

    pub fn confirm(self: *Session, allocator: std.mem.Allocator, paired_at_seconds: u64) !Identity.Peer {
        if (self.finished) return error.PairingSessionFinished;
        var connection = try self.pending.confirm(self.pending.sas);
        errdefer connection.close();
        try connection.sendFrame(allocator, .{
            .header = .{
                .message_type = .hello,
                .sequence = 0,
                .payload_length = confirmation_payload.len,
            },
            .payload = confirmation_payload,
        });
        const bytes = try connection.receiveFrameAlloc(allocator);
        defer allocator.free(bytes);
        const frame = try Protocol.decodeFrame(bytes);
        if (frame.header.message_type != .hello or frame.header.stream_id != 0 or
            frame.header.sequence != 0 or !std.mem.eql(u8, frame.payload, confirmation_payload))
            return error.InvalidPairingConfirmation;
        connection.close();
        self.finished = true;
        return Identity.Peer.init(
            self.pending.remote_static,
            self.remote_alias[0..self.remote_alias_length],
            self.remote_endpoint[0..self.remote_endpoint_length],
            self.remote_port,
            paired_at_seconds,
        );
    }

    pub fn reject(self: *Session) void {
        if (!self.finished) self.pending.reject();
        self.finished = true;
    }
};

pub fn accept(listener: *Transport.Listener, io: Crypto.RandomContext, identity: Crypto.Identity, alias: []const u8, endpoint: []const u8, port: u16) !Session {
    return Session.init(try listener.accept(io, identity, null), alias, endpoint, port);
}

pub fn connect(allocator: std.mem.Allocator, io: Crypto.RandomContext, host: []const u8, port: u16, identity: Crypto.Identity, alias: []const u8) !Session {
    return Session.init(
        try Transport.connect(allocator, io, host, port, identity, null),
        alias,
        host,
        port,
    );
}

test "pairing requires matching user confirmation on both devices" {
    const ServerContext = struct {
        listener: *Transport.Listener,
        identity: Crypto.Identity,
        io: Crypto.RandomContext,
        peer: ?Identity.Peer = null,
        failed: bool = false,

        fn run(context: *@This()) void {
            var session = accept(context.listener, context.io, context.identity, "client", "127.0.0.1", context.listener.port) catch {
                context.failed = true;
                return;
            };
            context.peer = session.confirm(std.testing.allocator, 10) catch {
                context.failed = true;
                return;
            };
        }
    };

    var listener = try Transport.Listener.listen("127.0.0.1", 0);
    defer listener.close();
    const io = Crypto.testingRandomContext();
    const server_identity = Crypto.Identity.generate(io);
    const client_identity = Crypto.Identity.generate(io);
    var context = ServerContext{ .listener = &listener, .identity = server_identity, .io = io };
    const thread = try std.Thread.spawn(.{}, ServerContext.run, .{&context});
    var client = try connect(std.testing.allocator, io, "127.0.0.1", listener.port, client_identity, "server");
    var sas: [6]u8 = undefined;
    client.formatSas(&sas);
    try std.testing.expect(sas[0] >= '0' and sas[0] <= '9');
    const client_peer = try client.confirm(std.testing.allocator, 11);
    thread.join();
    try std.testing.expect(!context.failed);
    try std.testing.expect(std.crypto.timing_safe.eql([32]u8, client_peer.public_key, server_identity.public_key));
    try std.testing.expect(std.crypto.timing_safe.eql([32]u8, context.peer.?.public_key, client_identity.public_key));
}
