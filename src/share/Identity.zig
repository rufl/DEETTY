const std = @import("std");
const Crypto = @import("Crypto.zig");
const Protocol = @import("Protocol.zig");

const magic = "NCTPAIR";
const version: u8 = 1;
pub const max_file_bytes: usize = 64 * 1024;
pub const max_peers: usize = 64;
pub const max_endpoint_bytes: usize = 253;

pub const Peer = struct {
    public_key: [Crypto.public_key_length]u8,
    alias_storage: [Protocol.max_alias_bytes]u8 = @splat(0),
    alias_length: u8 = 0,
    endpoint_storage: [max_endpoint_bytes]u8 = @splat(0),
    endpoint_length: u8 = 0,
    port: u16 = 0,
    paired_at_seconds: u64 = 0,
    revoked: bool = false,

    pub fn init(public_key: [Crypto.public_key_length]u8, alias_value: []const u8, endpoint_value: []const u8, port: u16, paired_at_seconds: u64) !Peer {
        var peer = Peer{ .public_key = public_key, .port = port, .paired_at_seconds = paired_at_seconds };
        try peer.setAlias(alias_value);
        try peer.setEndpoint(endpoint_value);
        try peer.validate();
        return peer;
    }

    pub fn alias(self: *const Peer) []const u8 {
        return self.alias_storage[0..self.alias_length];
    }

    pub fn endpoint(self: *const Peer) []const u8 {
        return self.endpoint_storage[0..self.endpoint_length];
    }

    pub fn setAlias(self: *Peer, value: []const u8) !void {
        if (value.len == 0 or value.len > Protocol.max_alias_bytes or
            std.mem.indexOfAny(u8, value, "\x00\r\n") != null)
            return error.InvalidPairedDeviceAlias;
        @memcpy(self.alias_storage[0..value.len], value);
        @memset(self.alias_storage[value.len..], 0);
        self.alias_length = @intCast(value.len);
    }

    pub fn setEndpoint(self: *Peer, value: []const u8) !void {
        if (value.len == 0 or value.len > max_endpoint_bytes or
            std.mem.indexOfAny(u8, value, "\x00\r\n") != null)
            return error.InvalidPairedDeviceEndpoint;
        @memcpy(self.endpoint_storage[0..value.len], value);
        @memset(self.endpoint_storage[value.len..], 0);
        self.endpoint_length = @intCast(value.len);
    }

    pub fn validate(self: *const Peer) !void {
        if (self.alias_length == 0 or self.endpoint_length == 0 or self.port == 0)
            return error.InvalidPairedDevice;
        if (self.alias_length > Protocol.max_alias_bytes or
            self.endpoint_length > max_endpoint_bytes)
            return error.InvalidPairedDevice;
    }
};

pub const Store = struct {
    identity: Crypto.Identity,
    peers: [max_peers]Peer = undefined,
    peer_count: u8 = 0,

    pub fn init(identity: Crypto.Identity) Store {
        return .{ .identity = identity };
    }

    pub fn deinit(self: *Store) void {
        self.identity.deinit();
        std.crypto.secureZero(u8, std.mem.asBytes(&self.peers));
        self.peer_count = 0;
    }

    pub fn peerSlice(self: *Store) []Peer {
        return self.peers[0..self.peer_count];
    }

    pub fn peerSliceConst(self: *const Store) []const Peer {
        return self.peers[0..self.peer_count];
    }

    pub fn find(self: *Store, public_key: [Crypto.public_key_length]u8) ?*Peer {
        for (self.peerSlice()) |*peer| {
            if (std.crypto.timing_safe.eql([32]u8, peer.public_key, public_key)) return peer;
        }
        return null;
    }

    pub fn addOrUpdate(self: *Store, peer: Peer) !void {
        try peer.validate();
        if (self.find(peer.public_key)) |existing| {
            existing.* = peer;
            return;
        }
        // Revocation removes trust; keeping the record is useful until the
        // bounded store needs room for a newly confirmed device. Reclaim only
        // then so a history of revoked peers cannot permanently exhaust every
        // future pairing slot.
        if (self.peer_count == max_peers) _ = self.removeRevoked();
        if (self.peer_count == max_peers) return error.TooManyPairedDevices;
        self.peers[self.peer_count] = peer;
        self.peer_count += 1;
    }

    pub fn revoke(self: *Store, public_key: [Crypto.public_key_length]u8) !void {
        const peer = self.find(public_key) orelse return error.PairedDeviceNotFound;
        peer.revoked = true;
    }

    pub fn removeRevoked(self: *Store) usize {
        var write_index: usize = 0;
        const original_count = self.peer_count;
        for (self.peerSliceConst()) |peer| {
            if (peer.revoked) continue;
            self.peers[write_index] = peer;
            write_index += 1;
        }
        if (write_index < original_count)
            std.crypto.secureZero(u8, std.mem.sliceAsBytes(self.peers[write_index..original_count]));
        self.peer_count = @intCast(write_index);
        return original_count - write_index;
    }
};

pub fn defaultPathAlloc(allocator: std.mem.Allocator, base_dir: []const u8) ![]u8 {
    if (base_dir.len == 0) return error.InvalidPairedDevicePath;
    return std.fs.path.join(allocator, &.{ base_dir, "dintty", "paired-devices.dinttypair" });
}

pub fn exportAlloc(allocator: std.mem.Allocator, store: *const Store) ![]u8 {
    if (store.peer_count > max_peers) return error.TooManyPairedDevices;
    var bytes = std.array_list.Managed(u8).init(allocator);
    errdefer bytes.deinit();
    try bytes.appendSlice(magic);
    try bytes.append(version);
    try bytes.appendSlice(&store.identity.secret_key);
    try bytes.append(store.peer_count);
    for (store.peerSliceConst()) |peer| {
        try peer.validate();
        try bytes.appendSlice(&peer.public_key);
        try bytes.append(@intFromBool(peer.revoked));
        try bytes.append(peer.alias_length);
        try bytes.append(peer.endpoint_length);
        var number: [8]u8 = undefined;
        std.mem.writeInt(u16, number[0..2], peer.port, .little);
        try bytes.appendSlice(number[0..2]);
        std.mem.writeInt(u64, &number, peer.paired_at_seconds, .little);
        try bytes.appendSlice(&number);
        try bytes.appendSlice(peer.alias());
        try bytes.appendSlice(peer.endpoint());
        if (bytes.items.len > max_file_bytes) return error.PairedDeviceStoreTooLarge;
    }
    return bytes.toOwnedSlice();
}

pub fn import(bytes: []const u8) !Store {
    if (bytes.len < magic.len + 1 + Crypto.secret_key_length + 1 or
        bytes.len > max_file_bytes)
        return error.InvalidPairedDeviceStore;
    if (!std.mem.eql(u8, bytes[0..magic.len], magic)) return error.InvalidPairedDeviceStore;
    if (bytes[magic.len] != version) return error.UnsupportedPairedDeviceStore;
    var offset = magic.len + 1;
    const identity = Crypto.Identity.fromSecret(bytes[offset..][0..Crypto.secret_key_length].*) catch
        return error.InvalidPairedDeviceStore;
    offset += Crypto.secret_key_length;
    var store = Store.init(identity);
    errdefer store.deinit();
    const count = bytes[offset];
    offset += 1;
    if (count > max_peers) return error.InvalidPairedDeviceStore;
    for (0..count) |_| {
        const fixed_length = Crypto.public_key_length + 1 + 1 + 1 + 2 + 8;
        if (bytes.len - offset < fixed_length) return error.InvalidPairedDeviceStore;
        const public_key = bytes[offset..][0..Crypto.public_key_length].*;
        offset += Crypto.public_key_length;
        const revoked_byte = bytes[offset];
        const alias_length: usize = bytes[offset + 1];
        const endpoint_length: usize = bytes[offset + 2];
        offset += 3;
        if (revoked_byte > 1 or alias_length == 0 or alias_length > Protocol.max_alias_bytes or
            endpoint_length == 0 or endpoint_length > max_endpoint_bytes or
            bytes.len - offset < 10 + alias_length + endpoint_length)
            return error.InvalidPairedDeviceStore;
        const port_bytes = bytes[offset..][0..2].*;
        const port = std.mem.readInt(u16, &port_bytes, .little);
        offset += 2;
        const paired_at_bytes = bytes[offset..][0..8].*;
        const paired_at = std.mem.readInt(u64, &paired_at_bytes, .little);
        offset += 8;
        var peer = try Peer.init(
            public_key,
            bytes[offset .. offset + alias_length],
            bytes[offset + alias_length .. offset + alias_length + endpoint_length],
            port,
            paired_at,
        );
        peer.revoked = revoked_byte == 1;
        try store.addOrUpdate(peer);
        offset += alias_length + endpoint_length;
    }
    if (offset != bytes.len) return error.InvalidPairedDeviceStore;
    return store;
}

pub fn saveFile(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8, store: *const Store) !void {
    if (path.len == 0) return error.InvalidPairedDevicePath;
    const bytes = try exportAlloc(allocator, store);
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    var atomic = try dir.createFileAtomic(io, path, .{
        .permissions = std.Io.File.Permissions.fromMode(0o600),
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, bytes);
    try atomic.replace(io);
}

pub fn loadFile(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) !Store {
    if (path.len == 0) return error.InvalidPairedDevicePath;
    const bytes = try dir.readFileAlloc(io, path, allocator, .limited(max_file_bytes));
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    return import(bytes);
}

test "paired device store round trips identity peers and revocation" {
    var store = Store.init(try Crypto.Identity.fromSecret(@as([32]u8, @splat(11))));
    defer store.deinit();
    try store.addOrUpdate(try Peer.init(@as([32]u8, @splat(12)), "Laptop", "laptop.tailnet.ts.net", 45123, 123456));
    try store.addOrUpdate(try Peer.init(@as([32]u8, @splat(13)), "Workstation", "10.0.0.7", 45124, 123457));
    try store.revoke(@as([32]u8, @splat(13)));
    const encoded = try exportAlloc(std.testing.allocator, &store);
    defer std.testing.allocator.free(encoded);
    var decoded = try import(encoded);
    defer decoded.deinit();
    try std.testing.expectEqual(store.identity.public_key, decoded.identity.public_key);
    try std.testing.expectEqual(@as(u8, 2), decoded.peer_count);
    try std.testing.expectEqualStrings("Laptop", decoded.peers[0].alias());
    try std.testing.expect(decoded.peers[1].revoked);
    try std.testing.expectEqual(@as(usize, 1), decoded.removeRevoked());
}

test "paired device store rejects truncation and duplicate overflow" {
    try std.testing.expectError(error.InvalidPairedDeviceStore, import("NCTPAIR"));
    var store = Store.init(try Crypto.Identity.fromSecret(@as([32]u8, @splat(14))));
    defer store.deinit();
    var index: usize = 0;
    while (index < max_peers) : (index += 1) {
        var key: [32]u8 = @splat(15);
        key[0] = @intCast(index);
        try store.addOrUpdate(try Peer.init(key, "Peer", "127.0.0.1", 1, 0));
    }
    try std.testing.expectError(error.TooManyPairedDevices, store.addOrUpdate(
        try Peer.init(@as([32]u8, @splat(255)), "Overflow", "127.0.0.1", 1, 0),
    ));
}

test "paired device store reclaims revoked capacity for a new confirmed peer" {
    var store = Store.init(try Crypto.Identity.fromSecret(@as([32]u8, @splat(16))));
    defer store.deinit();
    var index: usize = 0;
    while (index < max_peers) : (index += 1) {
        var key: [32]u8 = @splat(17);
        key[0] = @intCast(index);
        try store.addOrUpdate(try Peer.init(key, "Peer", "127.0.0.1", 1, 0));
    }
    store.peers[7].revoked = true;
    const replacement = try Peer.init(
        @as([32]u8, @splat(254)),
        "Replacement",
        "127.0.0.2",
        2,
        1,
    );
    try store.addOrUpdate(replacement);
    try std.testing.expectEqual(@as(u8, max_peers), store.peer_count);
    try std.testing.expect(store.find(replacement.public_key) != null);
    for (store.peerSliceConst()) |peer|
        try std.testing.expect(!peer.revoked);
}
