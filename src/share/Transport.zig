const std = @import("std");
const Protocol = @import("Protocol.zig");
const Crypto = @import("Crypto.zig");
const Net = @import("Net.zig");

pub const discovery_port: u16 = 49330;
pub const discovery_magic = "NCTD";
pub const discovery_version: u8 = 1;
pub const max_discovery_bytes: usize = 1024;
pub const max_endpoint_host_bytes: usize = 253;

const Socket = Net.Socket;
const invalid_socket = Net.invalid_socket;

pub const Announcement = struct {
    instance_id: [16]u8,
    tcp_port: u16,
    accepts_sessions: bool,
    alias: []const u8,

    pub fn validate(self: Announcement) !void {
        if (self.tcp_port == 0) return error.InvalidSharePort;
        if (self.alias.len == 0 or self.alias.len > Protocol.max_alias_bytes)
            return error.InvalidShareAlias;
        if (std.mem.indexOfAny(u8, self.alias, "\x00\r\n") != null)
            return error.InvalidShareAlias;
    }
};

pub const ParsedAnnouncement = struct {
    instance_id: [16]u8,
    tcp_port: u16,
    accepts_sessions: bool,
    alias: []const u8,
};

pub fn encodeAnnouncement(output: []u8, announcement: Announcement) !usize {
    try announcement.validate();
    const required = 25 + announcement.alias.len;
    if (output.len < required or required > max_discovery_bytes)
        return error.ShareDiscoveryBufferTooSmall;
    @memcpy(output[0..4], discovery_magic);
    output[4] = discovery_version;
    output[5] = @intFromBool(announcement.accepts_sessions);
    std.mem.writeInt(u16, output[6..8], announcement.tcp_port, .big);
    @memcpy(output[8..24], &announcement.instance_id);
    output[24] = @intCast(announcement.alias.len);
    @memcpy(output[25..required], announcement.alias);
    return required;
}

pub fn decodeAnnouncement(bytes: []const u8) !ParsedAnnouncement {
    if (bytes.len < 25 or bytes.len > max_discovery_bytes)
        return error.InvalidShareDiscoveryPacket;
    if (!std.mem.eql(u8, bytes[0..4], discovery_magic))
        return error.InvalidShareDiscoveryPacket;
    if (bytes[4] != discovery_version) return error.UnsupportedShareDiscovery;
    if (bytes[5] > 1) return error.InvalidShareDiscoveryPacket;
    const alias_length: usize = bytes[24];
    if (alias_length == 0 or alias_length > Protocol.max_alias_bytes or
        bytes.len != 25 + alias_length)
        return error.InvalidShareDiscoveryPacket;
    const parsed = ParsedAnnouncement{
        .instance_id = bytes[8..24].*,
        .tcp_port = std.mem.readInt(u16, bytes[6..8], .big),
        .accepts_sessions = bytes[5] == 1,
        .alias = bytes[25..],
    };
    try Announcement.validate(.{
        .instance_id = parsed.instance_id,
        .tcp_port = parsed.tcp_port,
        .accepts_sessions = parsed.accepts_sessions,
        .alias = parsed.alias,
    });
    return parsed;
}

pub const Discovery = struct {
    socket: Socket = invalid_socket,

    pub fn open() !Discovery {
        const socket = Net.discoveryOpen(discovery_port);
        if (socket == invalid_socket) return error.ShareDiscoveryUnavailable;
        return .{ .socket = socket };
    }

    pub fn close(self: *Discovery) void {
        if (self.socket != invalid_socket) Net.socketClose(self.socket);
        self.socket = invalid_socket;
    }

    pub fn announce(self: *Discovery, announcement: Announcement) !void {
        var bytes: [max_discovery_bytes]u8 = undefined;
        const count = try encodeAnnouncement(&bytes, announcement);
        if (Net.discoveryAnnounce(self.socket, discovery_port, bytes[0..count]) != @as(c_int, @intCast(count)))
            return error.ShareDiscoverySendFailed;
    }
    pub fn readable(self: *Discovery, timeout_milliseconds: u32) !bool {
        const result = Net.socketReadable(self.socket, timeout_milliseconds);
        if (result < 0) return error.ShareDiscoveryPollFailed;
        return result == 1;
    }

    pub fn receive(self: *Discovery, packet: *[max_discovery_bytes]u8, source: *[64]u8) !struct { announcement: ParsedAnnouncement, source: []const u8 } {
        const count = Net.discoveryReceive(self.socket, packet, source);
        if (count <= 0) return error.ShareDiscoveryReceiveFailed;
        const source_end = std.mem.indexOfScalar(u8, source, 0) orelse source.len;
        return .{
            .announcement = try decodeAnnouncement(packet[0..@intCast(count)]),
            .source = source[0..source_end],
        };
    }
};

pub fn sleepMilliseconds(io: Crypto.RandomContext, milliseconds: u64) void {
    io.sleep(.fromMilliseconds(@intCast(milliseconds)), .awake) catch {};
}

pub fn monotonicMilliseconds(io: Crypto.RandomContext) u64 {
    const timestamp = std.Io.Clock.awake.now(io);
    return @intCast(@divFloor(@max(timestamp.nanoseconds, 0), std.time.ns_per_ms));
}

pub fn unixTimestamp(io: Crypto.RandomContext) i64 {
    return std.Io.Timestamp.now(io, .real).toSeconds();
}

pub const Listener = struct {
    socket: Socket = invalid_socket,
    port: u16 = 0,

    pub fn listen(host: ?[]const u8, port: u16) !Listener {
        var host_buffer: [max_endpoint_host_bytes + 1]u8 = undefined;
        const host_z: ?[*:0]const u8 = if (host) |value| value_z: {
            if (value.len == 0 or value.len > max_endpoint_host_bytes or
                std.mem.indexOfScalar(u8, value, 0) != null)
                return error.InvalidShareEndpoint;
            @memcpy(host_buffer[0..value.len], value);
            host_buffer[value.len] = 0;
            break :value_z @ptrCast(host_buffer[0..value.len :0]);
        } else null;
        var bound_port: u16 = port;
        const socket = Net.tcpListen(host_z, port, &bound_port);
        if (socket == invalid_socket) return error.ShareListenFailed;
        return .{ .socket = socket, .port = bound_port };
    }

    pub fn accept(self: *Listener, io: Crypto.RandomContext, identity: Crypto.Identity, pinned_remote: ?[Crypto.public_key_length]u8) !PendingConnection {
        const socket = Net.tcpAccept(self.socket);
        if (socket == invalid_socket) return error.ShareAcceptFailed;
        errdefer Net.socketClose(socket);
        var responder = Crypto.Responder.init(identity, io);
        defer responder.deinit();
        var message1: [Crypto.message1_length]u8 = undefined;
        try readExact(socket, &message1);
        try responder.readMessage1(&message1);
        const message2 = try responder.writeMessage2();
        try writeExact(socket, &message2);
        var message3: [Crypto.message3_length]u8 = undefined;
        try readExact(socket, &message3);
        try responder.readMessage3(&message3);
        const result = try responder.finish(pinned_remote);
        return PendingConnection.init(socket, result);
    }

    pub fn readable(self: *Listener, timeout_milliseconds: u32) !bool {
        const result = Net.socketReadable(
            self.socket,
            timeout_milliseconds,
        );
        if (result < 0) return error.ShareListenerPollFailed;
        return result == 1;
    }

    pub fn close(self: *Listener) void {
        if (self.socket != invalid_socket) Net.socketClose(self.socket);
        self.socket = invalid_socket;
        self.port = 0;
    }
};

pub fn connect(allocator: std.mem.Allocator, io: Crypto.RandomContext, host: []const u8, port: u16, identity: Crypto.Identity, pinned_remote: ?[Crypto.public_key_length]u8) !PendingConnection {
    if (host.len == 0 or host.len > max_endpoint_host_bytes or port == 0 or
        std.mem.indexOfScalar(u8, host, 0) != null)
        return error.InvalidShareEndpoint;
    const host_z = try allocator.dupeZ(u8, host);
    defer allocator.free(host_z);
    const socket = Net.tcpConnect(host_z.ptr, port);
    if (socket == invalid_socket) return error.ShareConnectFailed;
    errdefer Net.socketClose(socket);
    var initiator = Crypto.Initiator.init(identity, io);
    defer initiator.deinit();
    const message1 = try initiator.writeMessage1();
    try writeExact(socket, &message1);
    var message2: [Crypto.message2_length]u8 = undefined;
    try readExact(socket, &message2);
    try initiator.readMessage2(&message2);
    const message3 = try initiator.writeMessage3();
    try writeExact(socket, &message3);
    const result = try initiator.finish(pinned_remote);
    return PendingConnection.init(socket, result);
}

pub const PendingConnection = struct {
    connection: SecureConnection,
    remote_static: [Crypto.public_key_length]u8,
    sas: u32,
    confirmed: bool = false,

    fn init(socket: Socket, result: Crypto.HandshakeResult) PendingConnection {
        return .{
            .connection = .{ .socket = socket, .transport = result.transport },
            .remote_static = result.remote_static,
            .sas = result.sas,
        };
    }

    pub fn confirm(self: *PendingConnection, displayed_sas: u32) !*SecureConnection {
        if (self.confirmed or displayed_sas != self.sas) {
            self.connection.close();
            return error.SharePairingConfirmationFailed;
        }
        self.confirmed = true;
        return &self.connection;
    }

    pub fn reject(self: *PendingConnection) void {
        self.connection.close();
    }
};

pub const SecureConnection = struct {
    socket: Socket = invalid_socket,
    transport: Crypto.Transport,

    pub fn sendFrame(self: *SecureConnection, allocator: std.mem.Allocator, frame: Protocol.Frame) !void {
        const plaintext = try Protocol.encodeFrameAlloc(allocator, frame);
        defer allocator.free(plaintext);
        const ciphertext = try allocator.alloc(u8, plaintext.len + Crypto.transport_tag_length);
        defer allocator.free(ciphertext);
        const count = try self.transport.seal(ciphertext, plaintext);
        if (count > std.math.maxInt(u16)) return error.ShareEncryptedFrameTooLarge;
        var prefix: [2]u8 = undefined;
        std.mem.writeInt(u16, &prefix, @intCast(count), .big);
        try writeExact(self.socket, &prefix);
        try writeExact(self.socket, ciphertext[0..count]);
    }
    pub fn readable(self: *SecureConnection, timeout_milliseconds: u32) !bool {
        const result = Net.socketReadable(self.socket, timeout_milliseconds);
        if (result < 0) return error.ShareSocketPollFailed;
        return result == 1;
    }

    pub fn receiveFrameAlloc(self: *SecureConnection, allocator: std.mem.Allocator) ![]u8 {
        var prefix: [2]u8 = undefined;
        try readExact(self.socket, &prefix);
        const encrypted_length = std.mem.readInt(u16, &prefix, .big);
        if (encrypted_length < Crypto.transport_tag_length or
            encrypted_length > Protocol.max_wire_bytes + Crypto.transport_tag_length)
            return error.InvalidShareEncryptedLength;
        const ciphertext = try allocator.alloc(u8, encrypted_length);
        defer allocator.free(ciphertext);
        try readExact(self.socket, ciphertext);
        const plaintext = try allocator.alloc(u8, encrypted_length - Crypto.transport_tag_length);
        errdefer allocator.free(plaintext);
        const count = try self.transport.open(plaintext, ciphertext);
        if (count != plaintext.len) return error.InvalidShareEncryptedLength;
        _ = try Protocol.decodeFrame(plaintext);
        return plaintext;
    }

    pub fn close(self: *SecureConnection) void {
        if (self.socket != invalid_socket) Net.socketClose(self.socket);
        self.socket = invalid_socket;
        self.transport.deinit();
    }
};

fn readExact(socket: Socket, output: []u8) !void {
    var offset: usize = 0;
    while (offset < output.len) {
        const request = @min(output.len - offset, @as(usize, std.math.maxInt(u16)));
        const count = Net.socketRead(socket, output[offset..][0..request]);
        if (count <= 0) return error.ShareConnectionClosed;
        offset += @intCast(count);
    }
}

fn writeExact(socket: Socket, bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const request = @min(bytes.len - offset, @as(usize, std.math.maxInt(u16)));
        const count = Net.socketWrite(socket, bytes[offset..][0..request]);
        if (count <= 0 or count > @as(c_int, @intCast(request)))
            return error.ShareWriteFailed;
        offset += @intCast(count);
    }
}

test "discovery announcements are bounded and omit identity keys" {
    const announcement = Announcement{
        .instance_id = [_]u8{7} ** 16,
        .tcp_port = 45123,
        .accepts_sessions = true,
        .alias = "Release workstation",
    };
    var bytes: [max_discovery_bytes]u8 = undefined;
    const count = try encodeAnnouncement(&bytes, announcement);
    const decoded = try decodeAnnouncement(bytes[0..count]);
    try std.testing.expectEqual(announcement.instance_id, decoded.instance_id);
    try std.testing.expectEqual(announcement.tcp_port, decoded.tcp_port);
    try std.testing.expect(decoded.accepts_sessions);
    try std.testing.expectEqualStrings(announcement.alias, decoded.alias);
    try std.testing.expect(count < 128);
}

test "discovery rejects malformed aliases and lengths" {
    var bytes: [max_discovery_bytes]u8 = undefined;
    try std.testing.expectError(error.InvalidShareAlias, encodeAnnouncement(&bytes, .{
        .instance_id = [_]u8{0} ** 16,
        .tcp_port = 1,
        .accepts_sessions = false,
        .alias = "bad\nname",
    }));
    try std.testing.expectError(error.InvalidShareDiscoveryPacket, decodeAnnouncement("NCTD"));
}
test "opt-in LAN discovery receives a bounded announcement" {
    var discovery = Discovery.open() catch return error.SkipZigTest;
    defer discovery.close();
    const expected = Announcement{
        .instance_id = [_]u8{9} ** 16,
        .tcp_port = 49331,
        .accepts_sessions = true,
        .alias = "NOCTTY discovery smoke",
    };
    try discovery.announce(expected);
    for (0..50) |_| {
        if (!try discovery.readable(10)) continue;
        var packet: [max_discovery_bytes]u8 = undefined;
        var source: [64]u8 = undefined;
        const found = try discovery.receive(&packet, &source);
        try std.testing.expectEqual(expected.instance_id, found.announcement.instance_id);
        try std.testing.expectEqual(expected.tcp_port, found.announcement.tcp_port);
        try std.testing.expectEqualStrings(expected.alias, found.announcement.alias);
        try std.testing.expect(found.source.len != 0);
        return;
    }
    return error.ShareDiscoveryReceiveTimedOut;
}

test "loopback pairing carries authenticated framed terminal data" {
    const ServerContext = struct {
        listener: *Listener,
        identity: Crypto.Identity,
        io: Crypto.RandomContext,
        received: bool = false,
        failed: bool = false,

        fn run(context: *@This()) void {
            var pending = context.listener.accept(context.io, context.identity, null) catch {
                context.failed = true;
                return;
            };
            const connection = pending.confirm(pending.sas) catch {
                context.failed = true;
                return;
            };
            defer connection.close();
            const plaintext = connection.receiveFrameAlloc(std.heap.page_allocator) catch {
                context.failed = true;
                return;
            };
            defer std.heap.page_allocator.free(plaintext);
            const frame = Protocol.decodeFrame(plaintext) catch {
                context.failed = true;
                return;
            };
            context.received = frame.header.message_type == .title and
                std.mem.eql(u8, frame.payload, "paired pane");
        }
    };

    var listener = try Listener.listen("127.0.0.1", 0);
    defer listener.close();
    var context = ServerContext{
        .listener = &listener,
        .io = Crypto.testingRandomContext(),
        .identity = try Crypto.Identity.fromSecret([_]u8{21} ** 32),
    };
    const thread = try std.Thread.spawn(.{}, ServerContext.run, .{&context});
    var pending = try connect(
        std.testing.allocator,
        Crypto.testingRandomContext(),
        "127.0.0.1",
        listener.port,
        try Crypto.Identity.fromSecret([_]u8{22} ** 32),
        null,
    );
    const connection = try pending.confirm(pending.sas);
    try connection.sendFrame(std.testing.allocator, .{
        .header = .{
            .message_type = .title,
            .stream_id = 1,
            .payload_length = "paired pane".len,
        },
        .payload = "paired pane",
    });
    connection.close();
    thread.join();
    try std.testing.expect(!context.failed);
    try std.testing.expect(context.received);
}
