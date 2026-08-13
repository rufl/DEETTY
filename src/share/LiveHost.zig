const std = @import("std");
const Crypto = @import("Crypto.zig");
const Identity = @import("Identity.zig");
const ShareMutex = @import("Mutex.zig").Mutex;
const Presentation = @import("Presentation.zig");
const Protocol = @import("Protocol.zig");
const Session = @import("Session.zig");
const Transport = @import("Transport.zig");

pub const Status = enum(c_int) {
    listening = 1,
    connected = 2,
    control_requested = 3,
    control_granted = 4,
    stopped = 5,
    failed = 6,
};

pub const StreamSpec = struct {
    pane_id: u64,
    title: []const u8,
};

const Stream = struct {
    pane_id: u64,
    title: []u8,
    peer: Session.HostPeer,
};

pub const LiveHost = struct {
    allocator: std.mem.Allocator,
    io: Crypto.RandomContext,
    identity: Crypto.Identity,
    paired_peer: Identity.Peer,
    listener: Transport.Listener,
    thread: ?std.Thread = null,
    mutex: ShareMutex = .{},
    streams: std.array_list.Managed(Stream),
    workspace_sequence: Protocol.Sequence = .{},
    queue: std.array_list.Managed([]u8),
    pending_bytes: usize = 0,
    status: Status = .listening,
    stop_requested: bool = false,
    grant_requested: bool = false,
    revoke_requested: bool = false,
    control_stream_id: u32 = 0,
    input_stream_id: u32 = 0,
    input: [Protocol.max_input_bytes]u8 = undefined,
    input_length: usize = 0,

    pub fn create(
        allocator: std.mem.Allocator,
        io: Crypto.RandomContext,
        identity: Crypto.Identity,
        paired_peer: Identity.Peer,
        host: ?[]const u8,
        listen_port: u16,
        specs: []const StreamSpec,
    ) !*LiveHost {
        if (paired_peer.revoked) return error.PairedDeviceRevoked;
        if (specs.len == 0 or specs.len > Protocol.max_streams)
            return error.InvalidShareWorkspace;
        const self = try allocator.create(LiveHost);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .io = io,
            .identity = identity,
            .paired_peer = paired_peer,
            .listener = try Transport.Listener.listen(host, listen_port),
            .streams = std.array_list.Managed(Stream).init(allocator),
            .queue = std.array_list.Managed([]u8).init(allocator),
        };
        errdefer self.listener.close();
        errdefer self.deinitStreams();
        for (specs, 0..) |spec, index| {
            if (spec.pane_id == 0 or spec.title.len > Protocol.max_title_bytes or
                !std.unicode.utf8ValidateSlice(spec.title))
                return error.InvalidShareWorkspace;
            for (specs[0..index]) |previous| {
                if (previous.pane_id == spec.pane_id) return error.InvalidShareWorkspace;
            }
            const title = try allocator.dupe(u8, spec.title);
            errdefer allocator.free(title);
            try self.streams.append(.{
                .pane_id = spec.pane_id,
                .title = title,
                .peer = try Session.HostPeer.init(@intCast(index + 1)),
            });
        }
        self.thread = try std.Thread.spawn(.{}, worker, .{self});
        return self;
    }

    pub fn destroy(self: *LiveHost) void {
        self.mutex.lock();
        self.stop_requested = true;
        self.wipeInput();
        self.mutex.unlock();
        self.listener.close();
        if (self.thread) |thread| thread.join();
        self.clearQueue();
        self.queue.deinit();
        self.deinitStreams();
        self.identity.deinit();
        self.allocator.destroy(self);
    }

    fn deinitStreams(self: *LiveHost) void {
        for (self.streams.items) |stream| self.allocator.free(stream.title);
        self.streams.deinit();
    }

    pub fn port(self: *LiveHost) u16 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.listener.port;
    }

    pub fn streamCount(self: *LiveHost) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.streams.items.len;
    }

    pub fn currentStatus(self: *LiveHost) Status {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.status;
    }

    pub fn capture(self: *LiveHost, pane_id: u64, terminal_session: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.status != .connected and self.status != .control_requested and self.status != .control_granted)
            return;
        const stream = self.streamForPane(pane_id) orelse return error.SharePaneNotPublished;
        if (stream.peer.checkpoint_required) {
            try self.enqueueCheckpoint(stream, &terminal_session.grid);
            stream.peer.checkpoint_required = false;
            stream.peer.publisher.checkpointComplete(&terminal_session.grid);
            return;
        }
        var rows: [Protocol.max_rows]u8 = undefined;
        _ = stream.peer.publisher.changedRows(&terminal_session.grid, rows[0..terminal_session.grid.rows]);
        for (rows[0..terminal_session.grid.rows], 0..) |changed, row| {
            if (changed == 0) continue;
            const owned = try stream.peer.publisher.rowFrameAlloc(self.allocator, &terminal_session.grid, row, .damage);
            defer owned.deinit(self.allocator);
            try self.enqueue(owned.frame);
        }
        if (try stream.peer.publisher.cursorFrame(&terminal_session.grid)) |cursor_value| {
            var cursor = cursor_value;
            cursor.frame.payload = &cursor.payload;
            try self.enqueue(cursor.frame);
        }
        if (try stream.peer.publisher.titleFrame(&terminal_session.grid, false)) |title|
            try self.enqueue(title);
    }

    pub fn grantControl(self: *LiveHost) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.status == .control_requested and self.control_stream_id != 0)
            self.grant_requested = true;
    }

    pub fn revokeControl(self: *LiveHost) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.status == .control_requested or self.status == .control_granted) {
            self.wipeInput();
            self.revoke_requested = true;
        }
    }

    pub fn drainInput(self: *LiveHost, pane_id: u64, terminal_session: anytype) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.input_length == 0) return 0;
        const stream = self.streamForPane(pane_id) orelse return 0;
        if (stream.peer.stream_id != self.input_stream_id or
            !stream.peer.permission.permitsInput())
            return 0;
        const count = self.input_length;
        try terminal_session.write(self.input[0..count]);
        self.wipeInput();
        return count;
    }

    fn streamForPane(self: *LiveHost, pane_id: u64) ?*Stream {
        for (self.streams.items) |*stream| {
            if (stream.pane_id == pane_id) return stream;
        }
        return null;
    }

    fn streamForId(self: *LiveHost, stream_id: u32) ?*Stream {
        for (self.streams.items) |*stream| {
            if (stream.peer.stream_id == stream_id) return stream;
        }
        return null;
    }

    fn enqueueCheckpoint(self: *LiveHost, stream: *Stream, grid: anytype) !void {
        var begin = try stream.peer.publisher.snapshotBegin(grid, 0);
        begin.frame.payload = &begin.payload;
        try self.enqueue(begin.frame);
        for (0..grid.rows) |row| {
            const owned = try stream.peer.publisher.rowFrameAlloc(self.allocator, grid, row, .row_chunk);
            defer owned.deinit(self.allocator);
            try self.enqueue(owned.frame);
        }
        try self.enqueue(try stream.peer.publisher.snapshotEnd());
        if (try stream.peer.publisher.titleFrame(grid, true)) |title|
            try self.enqueue(title);
    }

    fn enqueue(self: *LiveHost, frame: Protocol.Frame) !void {
        const bytes = try Protocol.encodeFrameAlloc(self.allocator, frame);
        errdefer self.allocator.free(bytes);
        if (self.pending_bytes + bytes.len > Protocol.max_pending_peer_bytes) {
            self.allocator.free(bytes);
            self.status = .failed;
            self.stop_requested = true;
            return error.SharePeerBackpressureExceeded;
        }
        try self.queue.append(bytes);
        self.pending_bytes += bytes.len;
    }

    fn clearQueue(self: *LiveHost) void {
        for (self.queue.items) |bytes| self.allocator.free(bytes);
        self.queue.clearRetainingCapacity();
        self.pending_bytes = 0;
    }

    fn wipeInput(self: *LiveHost) void {
        std.crypto.secureZero(u8, self.input[0..self.input_length]);
        self.input_length = 0;
        self.input_stream_id = 0;
    }

    fn sendManifest(self: *LiveHost, connection: *Transport.SecureConnection) !void {
        var panes: [Protocol.max_streams]Session.PaneManifest = undefined;
        for (self.streams.items, 0..) |stream, index| {
            panes[index] = .{
                .stream_id = stream.peer.stream_id,
                .pane_id = stream.pane_id,
                .title = stream.title,
            };
        }
        const payload = try Session.encodeWorkspaceManifestAlloc(
            self.allocator,
            panes[0..self.streams.items.len],
        );
        defer self.allocator.free(payload);
        try connection.sendFrame(self.allocator, .{
            .header = .{
                .message_type = .workspace_manifest,
                .stream_id = 0,
                .sequence = try self.workspace_sequence.sending(),
                .payload_length = @intCast(payload.len),
            },
            .payload = payload,
        });
    }

    fn worker(self: *LiveHost) void {
        var pending = self.listener.accept(self.io, self.identity, self.paired_peer.public_key) catch {
            self.setTerminalStatus(.failed);
            return;
        };
        var connection = pending.confirm(pending.sas) catch {
            self.setTerminalStatus(.failed);
            return;
        };
        defer connection.close();
        self.sendManifest(connection) catch {
            self.setTerminalStatus(.failed);
            return;
        };
        self.setTerminalStatus(.connected);
        while (true) {
            self.mutex.lock();
            if (self.stop_requested) {
                self.status = .stopped;
                self.wipeInput();
                self.mutex.unlock();
                return;
            }
            const queued = if (self.queue.items.len == 0) null else self.queue.orderedRemove(0);
            if (queued) |bytes| self.pending_bytes -= bytes.len;
            const grant = self.grant_requested;
            self.grant_requested = false;
            const revoke = self.revoke_requested;
            self.revoke_requested = false;
            const control_stream_id = self.control_stream_id;
            self.mutex.unlock();

            if (queued) |bytes| {
                defer self.allocator.free(bytes);
                const frame = Protocol.decodeFrame(bytes) catch {
                    self.setTerminalStatus(.failed);
                    return;
                };
                connection.sendFrame(self.allocator, frame) catch {
                    self.setTerminalStatus(.failed);
                    return;
                };
                continue;
            }
            if (grant) {
                self.mutex.lock();
                const stream = self.streamForId(control_stream_id) orelse {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                };
                stream.peer.grantControl(self.allocator, connection) catch {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                };
                self.status = .control_granted;
                self.mutex.unlock();
                continue;
            }
            if (revoke) {
                self.mutex.lock();
                const stream = self.streamForId(control_stream_id) orelse {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                };
                stream.peer.revokeControl(self.allocator, connection) catch {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                };
                self.control_stream_id = 0;
                self.status = .connected;
                self.mutex.unlock();
                continue;
            }
            const readable = connection.readable(20) catch {
                self.setTerminalStatus(.failed);
                return;
            };
            if (!readable) continue;
            const plaintext = connection.receiveFrameAlloc(self.allocator) catch {
                self.setTerminalStatus(.stopped);
                return;
            };
            defer self.allocator.free(plaintext);
            const frame = Protocol.decodeFrame(plaintext) catch {
                self.setTerminalStatus(.failed);
                return;
            };
            self.mutex.lock();
            const stream = self.streamForId(frame.header.stream_id) orelse {
                self.status = .failed;
                self.mutex.unlock();
                return;
            };
            const input = stream.peer.receiveControl(frame) catch {
                self.status = .failed;
                self.mutex.unlock();
                return;
            };
            if (input) |bytes| {
                if ((self.input_length != 0 and self.input_stream_id != frame.header.stream_id) or
                    self.input_length + bytes.len > self.input.len)
                {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                }
                self.input_stream_id = frame.header.stream_id;
                @memcpy(self.input[self.input_length .. self.input_length + bytes.len], bytes);
                self.input_length += bytes.len;
            } else if (frame.header.message_type == .control_request) {
                if (self.control_stream_id != 0 and self.control_stream_id != frame.header.stream_id) {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                }
                self.control_stream_id = frame.header.stream_id;
                self.status = .control_requested;
            }
            self.mutex.unlock();
        }
    }

    fn setTerminalStatus(self: *LiveHost, status: Status) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (status == .failed or status == .stopped) self.wipeInput();
        self.status = status;
    }
};

test "live host publishes damage and dispatches only granted input" {
    const Link = @import("Link.zig");
    const Vt = @import("../terminal/Vt.zig");
    const FakeSession = struct {
        grid: Vt.Grid,
        written: [16]u8 = undefined,
        written_length: usize = 0,

        pub fn write(self: *@This(), bytes: []const u8) !void {
            if (self.written_length + bytes.len > self.written.len) return error.InputOverflow;
            @memcpy(self.written[self.written_length .. self.written_length + bytes.len], bytes);
            self.written_length += bytes.len;
        }
    };

    const io = Crypto.testingRandomContext();
    const host_identity = Crypto.Identity.generate(io);
    const viewer_identity = Crypto.Identity.generate(io);
    const host_peer = try Identity.Peer.init(viewer_identity.public_key, "viewer", "127.0.0.1", 1, 1);
    const live = try LiveHost.create(std.testing.allocator, io, host_identity, host_peer, "127.0.0.1", 0, &.{
        .{ .pane_id = 41, .title = "Shell" },
    });
    defer live.destroy();
    const viewer_peer = try Identity.Peer.init(host_identity.public_key, "host", "127.0.0.1", live.port(), 1);
    var viewer = try Link.Viewer.connect(std.testing.allocator, io, "127.0.0.1", live.port(), viewer_identity, &viewer_peer, 1);
    defer viewer.close();
    const manifest_bytes = try viewer.connection.receiveFrameAlloc(std.testing.allocator);
    defer std.testing.allocator.free(manifest_bytes);
    const manifest = try Protocol.decodeFrame(manifest_bytes);
    try std.testing.expectEqual(Protocol.MessageType.workspace_manifest, manifest.header.message_type);
    var terminal_session = FakeSession{ .grid = try Vt.Grid.init(std.testing.allocator, 12, 2) };
    defer terminal_session.grid.deinit();
    try terminal_session.grid.feed("live pane");
    for (0..100) |_| {
        if (live.currentStatus() == .connected) break;
        Transport.sleepMilliseconds(io, 1);
    }
    try live.capture(41, &terminal_session);
    while (try viewer.receive(std.testing.allocator) != .snapshot_end) {}
    try viewer.requestControl(std.testing.allocator);
    for (0..100) |_| {
        if (live.currentStatus() == .control_requested) break;
        Transport.sleepMilliseconds(io, 1);
    }
    try std.testing.expectEqual(Status.control_requested, live.currentStatus());
    live.grantControl();
    while (try viewer.receive(std.testing.allocator) != .control_grant) {}
    try viewer.sendInput(std.testing.allocator, "pwd\n");
    var dispatched: usize = 0;
    for (0..100) |_| {
        dispatched = try live.drainInput(41, &terminal_session);
        if (dispatched != 0) break;
        Transport.sleepMilliseconds(io, 1);
    }
    try std.testing.expectEqual(@as(usize, 4), dispatched);
    try std.testing.expectEqualStrings("pwd\n", terminal_session.written[0..terminal_session.written_length]);
    try viewer.sendInput(std.testing.allocator, "late");
    for (0..5000) |_| {
        live.mutex.lock();
        const pending_input = live.input_length;
        live.mutex.unlock();
        if (pending_input == 4) break;
        Transport.sleepMilliseconds(io, 1);
    }
    live.mutex.lock();
    const pending_before_revoke = live.input_length;
    live.mutex.unlock();
    try std.testing.expectEqual(@as(usize, 4), pending_before_revoke);
    live.revokeControl();
    for (0..5000) |_| {
        if (live.currentStatus() == .connected) break;
        Transport.sleepMilliseconds(io, 1);
    }
    try std.testing.expectEqual(@as(usize, 0), try live.drainInput(41, &terminal_session));
}
