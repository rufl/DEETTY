const std = @import("std");
const Crypto = @import("Crypto.zig");
const Identity = @import("Identity.zig");
const ShareMutex = @import("Mutex.zig").Mutex;
const Pairing = @import("Pairing.zig");
const Protocol = @import("Protocol.zig");
const Transport = @import("Transport.zig");

pub const Status = enum(c_int) {
    connecting = 1,
    sas_ready = 2,
    paired = 3,
    rejected = 4,
    failed = 5,
};

const Mode = enum { listen, connect };

pub const Controller = struct {
    allocator: std.mem.Allocator,
    io: Crypto.RandomContext,
    identity: Crypto.Identity,
    mode: Mode,
    listener: ?Transport.Listener = null,
    thread: ?std.Thread = null,
    mutex: ShareMutex = .{},
    status: Status = .connecting,
    confirm_requested: bool = false,
    reject_requested: bool = false,
    sas_value: u32 = 0,
    peer: ?Identity.Peer = null,
    alias: [Protocol.max_alias_bytes]u8 = [_]u8{0} ** Protocol.max_alias_bytes,
    alias_length: u8,
    endpoint: [Identity.max_endpoint_bytes]u8 = [_]u8{0} ** Identity.max_endpoint_bytes,
    endpoint_length: u8,
    port_value: u16,

    pub fn listen(allocator: std.mem.Allocator, io: Crypto.RandomContext, identity: Crypto.Identity, bind_host: ?[]const u8, bind_port: u16, remote_alias: []const u8, remote_endpoint: []const u8, remote_port: u16) !*Controller {
        const self = try allocate(allocator, io, identity, .listen, remote_alias, remote_endpoint, remote_port);
        errdefer self.destroyUnstarted();
        self.listener = try Transport.Listener.listen(bind_host, bind_port);
        self.thread = try std.Thread.spawn(.{}, worker, .{self});
        return self;
    }

    pub fn connect(allocator: std.mem.Allocator, io: Crypto.RandomContext, identity: Crypto.Identity, host: []const u8, port: u16, remote_alias: []const u8) !*Controller {
        const self = try allocate(allocator, io, identity, .connect, remote_alias, host, port);
        errdefer self.destroyUnstarted();
        self.thread = try std.Thread.spawn(.{}, worker, .{self});
        return self;
    }

    fn allocate(allocator: std.mem.Allocator, io: Crypto.RandomContext, identity: Crypto.Identity, mode: Mode, remote_alias: []const u8, remote_endpoint: []const u8, remote_port: u16) !*Controller {
        if (remote_alias.len == 0 or remote_alias.len > Protocol.max_alias_bytes or
            remote_endpoint.len == 0 or remote_endpoint.len > Identity.max_endpoint_bytes or remote_port == 0)
            return error.InvalidPairingPeer;
        const self = try allocator.create(Controller);
        self.* = .{
            .allocator = allocator,
            .io = io,
            .identity = identity,
            .mode = mode,
            .alias_length = @intCast(remote_alias.len),
            .endpoint_length = @intCast(remote_endpoint.len),
            .port_value = remote_port,
        };
        @memcpy(self.alias[0..remote_alias.len], remote_alias);
        @memcpy(self.endpoint[0..remote_endpoint.len], remote_endpoint);
        return self;
    }

    pub fn destroy(self: *Controller) void {
        self.mutex.lock();
        self.reject_requested = true;
        self.mutex.unlock();
        if (self.thread) |thread| thread.join();
        if (self.listener) |*listener| listener.close();
        self.identity.deinit();
        self.allocator.destroy(self);
    }

    fn destroyUnstarted(self: *Controller) void {
        if (self.listener) |*listener| listener.close();
        self.identity.deinit();
        self.allocator.destroy(self);
    }

    pub fn statusSnapshot(self: *Controller) Status {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.status;
    }

    pub fn sas(self: *Controller) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.sas_value;
    }

    pub fn listeningPort(self: *Controller) u16 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return if (self.listener) |listener| listener.port else 0;
    }

    pub fn confirm(self: *Controller) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.status == .sas_ready) self.confirm_requested = true;
    }

    pub fn reject(self: *Controller) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.reject_requested = true;
    }

    pub fn takePeer(self: *Controller) ?Identity.Peer {
        self.mutex.lock();
        defer self.mutex.unlock();
        const result = self.peer;
        self.peer = null;
        return result;
    }

    fn worker(self: *Controller) void {
        var session = switch (self.mode) {
            .listen => incoming: {
                // Poll in short bounded intervals so explicit cancellation can
                // join this worker without relying on cross-thread close()
                // behavior for a blocking accept call.
                while (true) {
                    self.mutex.lock();
                    const reject_now = self.reject_requested;
                    self.mutex.unlock();
                    if (reject_now) {
                        self.setStatus(.rejected);
                        return;
                    }
                    const readable = self.listener.?.readable(50) catch {
                        self.setStatus(.failed);
                        return;
                    };
                    if (readable) break;
                }
                break :incoming Pairing.accept(
                    &(self.listener.?),
                    self.io,
                    self.identity,
                    self.alias[0..self.alias_length],
                    self.endpoint[0..self.endpoint_length],
                    self.port_value,
                );
            },
            .connect => Pairing.connect(
                self.allocator,
                self.io,
                self.endpoint[0..self.endpoint_length],
                self.port_value,
                self.identity,
                self.alias[0..self.alias_length],
            ),
        } catch {
            self.setStatus(.failed);
            return;
        };
        self.mutex.lock();
        self.sas_value = session.sas();
        self.status = .sas_ready;
        self.mutex.unlock();
        while (true) {
            self.mutex.lock();
            const confirm_now = self.confirm_requested;
            const reject_now = self.reject_requested;
            self.mutex.unlock();
            if (reject_now) {
                session.reject();
                self.setStatus(.rejected);
                return;
            }
            if (confirm_now) break;
            Transport.sleepMilliseconds(self.io, 20);
        }
        const peer = session.confirm(self.allocator, @intCast(Transport.unixTimestamp(self.io))) catch {
            self.setStatus(.failed);
            return;
        };
        self.mutex.lock();
        self.peer = peer;
        self.status = .paired;
        self.mutex.unlock();
    }

    fn setStatus(self: *Controller, value: Status) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.status = value;
    }
};

test "pair controllers wait for explicit SAS confirmation" {
    const io = Crypto.testingRandomContext();
    const listener_identity = Crypto.Identity.generate(io);
    const connector_identity = Crypto.Identity.generate(io);
    const listener = try Controller.listen(
        std.testing.allocator,
        io,
        listener_identity,
        "127.0.0.1",
        0,
        "connector",
        "127.0.0.1",
        49330,
    );
    defer listener.destroy();
    const connector = try Controller.connect(
        std.testing.allocator,
        io,
        connector_identity,
        "127.0.0.1",
        listener.listeningPort(),
        "listener",
    );
    defer connector.destroy();
    for (0..200) |_| {
        if (listener.statusSnapshot() == .sas_ready and connector.statusSnapshot() == .sas_ready) break;
        Transport.sleepMilliseconds(io, 1);
    }
    try std.testing.expectEqual(Status.sas_ready, listener.statusSnapshot());
    try std.testing.expectEqual(listener.sas(), connector.sas());
    listener.confirm();
    connector.confirm();
    for (0..200) |_| {
        if (listener.statusSnapshot() == .paired and connector.statusSnapshot() == .paired) break;
        Transport.sleepMilliseconds(io, 1);
    }
    try std.testing.expect(listener.takePeer() != null);
    try std.testing.expect(connector.takePeer() != null);
}

test "listening pair controller cancellation joins without a peer" {
    const io = Crypto.testingRandomContext();
    const identity = Crypto.Identity.generate(io);
    const controller = try Controller.listen(
        std.testing.allocator,
        io,
        identity,
        "127.0.0.1",
        0,
        "remote",
        "127.0.0.1",
        49330,
    );
    controller.destroy();
}
