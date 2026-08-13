const std = @import("std");
const Crypto = @import("Crypto.zig");
const Identity = @import("Identity.zig");
const Link = @import("Link.zig");
const Protocol = @import("Protocol.zig");
const ShareMutex = @import("Mutex.zig").Mutex;

pub const Status = enum(c_int) {
    connecting = 1,
    connected = 2,
    control_requested = 3,
    control_granted = 4,
    stopped = 5,
    failed = 6,
};

pub const LiveViewer = struct {
    allocator: std.mem.Allocator,
    random: Crypto.RandomContext,
    identity: Crypto.Identity,
    paired_peer: Identity.Peer,
    stream_id: u32,
    thread: ?std.Thread = null,
    mutex: ShareMutex = .{},
    viewer: ?Link.Viewer = null,
    status: Status = .connecting,
    generation: u64 = 1,
    consumed_generation: u64 = 0,
    stop_requested: bool = false,

    pub fn create(allocator: std.mem.Allocator, random: Crypto.RandomContext, identity: Crypto.Identity, paired_peer: Identity.Peer, stream_id: u32) !*LiveViewer {
        if (paired_peer.revoked) return error.PairedDeviceRevoked;
        const self = try allocator.create(LiveViewer);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .random = random,
            .identity = identity,
            .paired_peer = paired_peer,
            .stream_id = stream_id,
        };
        self.thread = try std.Thread.spawn(.{}, worker, .{self});
        return self;
    }

    pub fn destroy(self: *LiveViewer) void {
        self.mutex.lock();
        self.stop_requested = true;
        self.mutex.unlock();
        if (self.thread) |thread| thread.join();
        self.identity.deinit();
        self.allocator.destroy(self);
    }

    pub fn currentStatus(self: *LiveViewer) Status {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.status;
    }

    pub fn requestControl(self: *LiveViewer) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var viewer = &(self.viewer orelse return error.ShareViewerNotConnected);
        try viewer.requestControl(self.allocator);
        self.status = .control_requested;
    }

    pub fn sendInput(self: *LiveViewer, bytes: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var viewer = &(self.viewer orelse return error.ShareViewerNotConnected);
        try viewer.sendInput(self.allocator, bytes);
    }

    pub fn takeDirtyRows(self: *LiveViewer, output: []u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const viewer = &(self.viewer orelse return 0);
        const count = @min(output.len, @as(usize, viewer.receiver.grid.rows));
        if (self.consumed_generation == self.generation) {
            @memset(output[0..count], 0);
            return count;
        }
        @memset(output[0..count], 1);
        self.consumed_generation = self.generation;
        return count;
    }

    pub fn dimensions(self: *LiveViewer) struct { columns: u16, rows: u16 } {
        self.mutex.lock();
        defer self.mutex.unlock();
        const viewer = &(self.viewer orelse return .{ .columns = 0, .rows = 0 });
        return .{ .columns = viewer.receiver.grid.columns, .rows = viewer.receiver.grid.rows };
    }

    pub fn packedCell(self: *LiveViewer, column: usize, row: usize) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const viewer = &(self.viewer orelse return ' ');
        return viewer.receiver.grid.packedCell(column, row);
    }

    pub fn cellText(self: *LiveViewer, column: usize, row: usize, output: []u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const viewer = &(self.viewer orelse return 0);
        return viewer.receiver.grid.cellText(column, row, output);
    }

    pub fn colorRgb(self: *LiveViewer, color_id: u16) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const viewer = &(self.viewer orelse return 0);
        return viewer.receiver.grid.colorRgb(color_id);
    }

    pub fn cursor(self: *LiveViewer) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const viewer = &(self.viewer orelse return 0xffffffff);
        const grid = &viewer.receiver.grid;
        if (!grid.cursor_visible) return 0xffffffff;
        return (@as(u32, grid.cursor_row) << 16) | grid.cursor_column;
    }

    pub fn title(self: *LiveViewer, output: []u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const viewer = &(self.viewer orelse return 0);
        const value = viewer.receiver.grid.title();
        const count = @min(value.len, output.len);
        @memcpy(output[0..count], value[0..count]);
        return count;
    }

    pub fn applicationCursorKeys(self: *LiveViewer) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const viewer = &(self.viewer orelse return false);
        return viewer.receiver.grid.application_cursor_keys;
    }

    fn worker(self: *LiveViewer) void {
        const viewer = Link.Viewer.connect(
            self.allocator,
            self.random,
            self.paired_peer.endpoint(),
            self.paired_peer.port,
            self.identity,
            &self.paired_peer,
            self.stream_id,
        ) catch {
            self.setStatus(.failed);
            return;
        };
        self.mutex.lock();
        self.viewer = viewer;
        self.status = .connected;
        self.mutex.unlock();

        while (true) {
            self.mutex.lock();
            const stop = self.stop_requested;
            self.mutex.unlock();
            if (stop) break;
            var active = &(self.viewer.?);
            const readable = active.connection.readable(50) catch {
                self.setStatus(.failed);
                return self.finishViewer();
            };
            if (!readable) continue;
            const bytes = active.connection.receiveFrameAlloc(self.allocator) catch {
                self.setStatus(.failed);
                return self.finishViewer();
            };
            defer self.allocator.free(bytes);
            const frame = Protocol.decodeFrame(bytes) catch {
                self.setStatus(.failed);
                return self.finishViewer();
            };
            self.mutex.lock();
            active.receiver.apply(frame) catch {
                self.status = .failed;
                self.mutex.unlock();
                return self.finishViewer();
            };
            self.generation +%= 1;
            if (self.generation == 0) self.generation = 1;
            self.status = switch (active.receiver.permission.value) {
                .view_only => .connected,
                .control_requested => .control_requested,
                .control_granted => .control_granted,
                .revoked => .connected,
            };
            self.mutex.unlock();
        }
        self.setStatus(.stopped);
        self.finishViewer();
    }

    fn finishViewer(self: *LiveViewer) void {
        self.mutex.lock();
        if (self.viewer) |*viewer| viewer.close();
        self.viewer = null;
        self.mutex.unlock();
    }

    fn setStatus(self: *LiveViewer, status: Status) void {
        self.mutex.lock();
        self.status = status;
        self.mutex.unlock();
    }
};

test "live viewer mirrors output and gates remote control" {
    const LiveHost = @import("LiveHost.zig").LiveHost;
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

    const random = Crypto.testingRandomContext();
    const host_identity = Crypto.Identity.generate(random);
    const viewer_identity = Crypto.Identity.generate(random);
    const host_peer = try Identity.Peer.init(viewer_identity.public_key, "viewer", "127.0.0.1", 1, 1);
    const host = try LiveHost.create(std.testing.allocator, random, host_identity, host_peer, "127.0.0.1", 0, 1);
    defer host.destroy();
    const viewer_peer = try Identity.Peer.init(host_identity.public_key, "host", "127.0.0.1", host.port(), 1);
    const viewer = try LiveViewer.create(std.testing.allocator, random, viewer_identity, viewer_peer, 1);
    defer viewer.destroy();
    var terminal_session = FakeSession{ .grid = try Vt.Grid.init(std.testing.allocator, 12, 2) };
    defer terminal_session.grid.deinit();
    try terminal_session.grid.feed("remote pane");

    for (0..5000) |_| {
        if (host.currentStatus() == .connected and viewer.currentStatus() == .connected) break;
        @import("Transport.zig").sleepMilliseconds(random, 1);
    }
    try std.testing.expect(host.currentStatus() == .connected);
    try std.testing.expectEqual(Status.connected, viewer.currentStatus());
    try host.capture(&terminal_session);
    for (0..5000) |_| {
        if ((viewer.packedCell(0, 0) & 0x1fffff) == 'r') break;
        @import("Transport.zig").sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(u21, 'r'), viewer.packedCell(0, 0) & 0x1fffff);
    try terminal_session.grid.feed("\x1b]0;Remote title\x07\x1b[2;3H\x1b[?1h");
    try host.capture(&terminal_session);
    var title_buffer: [32]u8 = undefined;
    for (0..5000) |_| {
        if (viewer.title(&title_buffer) == "Remote title".len and
            viewer.cursor() == (@as(u32, 1) << 16) | 2 and
            viewer.applicationCursorKeys())
            break;
        @import("Transport.zig").sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqualStrings(
        "Remote title",
        title_buffer[0..viewer.title(&title_buffer)],
    );
    try std.testing.expectEqual((@as(u32, 1) << 16) | 2, viewer.cursor());
    try std.testing.expect(viewer.applicationCursorKeys());
    try std.testing.expectError(error.ShareInputNotGranted, viewer.sendInput("id\n"));
    try viewer.requestControl();
    for (0..5000) |_| {
        if (host.currentStatus() == .control_requested) break;
        @import("Transport.zig").sleepMilliseconds(random, 1);
    }
    host.grantControl();
    for (0..5000) |_| {
        if (viewer.currentStatus() == .control_granted) break;
        @import("Transport.zig").sleepMilliseconds(random, 1);
    }
    try viewer.sendInput("id\n");
    for (0..5000) |_| {
        if (try host.drainInput(&terminal_session) != 0) break;
        @import("Transport.zig").sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqualStrings("id\n", terminal_session.written[0..terminal_session.written_length]);
    host.revokeControl();
    for (0..5000) |_| {
        if (viewer.currentStatus() == .connected) break;
        @import("Transport.zig").sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(Status.connected, viewer.currentStatus());
    try std.testing.expectError(error.ShareInputNotGranted, viewer.sendInput("whoami\n"));
}
