const std = @import("std");
const Crypto = @import("Crypto.zig");
const Identity = @import("Identity.zig");
const Mirror = @import("Mirror.zig");
const Protocol = @import("Protocol.zig");
const Session = @import("Session.zig");
const ShareMutex = @import("Mutex.zig").Mutex;
const Transport = @import("Transport.zig");

pub const Status = enum(c_int) {
    connecting = 1,
    connected = 2,
    control_requested = 3,
    control_granted = 4,
    stopped = 5,
    failed = 6,
};

const Stream = struct {
    pane_id: u64,
    title: []u8,
    receiver: Mirror.Receiver,
    send_sequence: Protocol.Sequence = .{},
};

pub const LiveViewer = struct {
    allocator: std.mem.Allocator,
    random: Crypto.RandomContext,
    identity: Crypto.Identity,
    paired_peer: Identity.Peer,
    thread: ?std.Thread = null,
    mutex: ShareMutex = .{},
    connection: ?Transport.SecureConnection = null,
    streams: std.array_list.Managed(Stream),
    workspace_sequence: Protocol.Sequence = .{},
    selected_index: usize = 0,
    manifest_received: bool = false,
    status: Status = .connecting,
    generation: u64 = 1,
    consumed_generation: u64 = 0,
    stop_requested: bool = false,

    pub fn create(
        allocator: std.mem.Allocator,
        random: Crypto.RandomContext,
        identity: Crypto.Identity,
        paired_peer: Identity.Peer,
    ) !*LiveViewer {
        if (paired_peer.revoked) return error.PairedDeviceRevoked;
        const self = try allocator.create(LiveViewer);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .random = random,
            .identity = identity,
            .paired_peer = paired_peer,
            .streams = std.array_list.Managed(Stream).init(allocator),
        };
        self.thread = try std.Thread.spawn(.{}, worker, .{self});
        return self;
    }

    pub fn destroy(self: *LiveViewer) void {
        self.mutex.lock();
        self.stop_requested = true;
        self.mutex.unlock();
        if (self.thread) |thread| thread.join();
        self.deinitStreams();
        self.streams.deinit();
        self.identity.deinit();
        self.allocator.destroy(self);
    }

    fn deinitStreams(self: *LiveViewer) void {
        for (self.streams.items) |*stream| {
            stream.receiver.deinit();
            self.allocator.free(stream.title);
        }
        self.streams.clearRetainingCapacity();
    }

    pub fn currentStatus(self: *LiveViewer) Status {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.status;
    }

    pub fn streamCount(self: *LiveViewer) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.streams.items.len;
    }

    pub fn streamInfo(self: *LiveViewer, index: usize, title_output: []u8) ?struct {
        pane_id: u64,
        title_length: usize,
        selected: bool,
    } {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return null;
        const stream = &self.streams.items[index];
        const count = @min(stream.title.len, title_output.len);
        @memcpy(title_output[0..count], stream.title[0..count]);
        return .{
            .pane_id = stream.pane_id,
            .title_length = count,
            .selected = index == self.selected_index,
        };
    }

    pub fn selectStream(self: *LiveViewer, index: usize) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return error.InvalidShareStream;
        self.selected_index = index;
        self.bumpGeneration();
        self.updateStatusFromSelected();
    }

    pub fn requestControl(self: *LiveViewer) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const selected_index = self.selected_index;
        const stream = self.selectedStream() orelse return error.ShareViewerNotConnected;
        for (self.streams.items, 0..) |other, index| {
            if (index != selected_index and
                (other.receiver.permission.value == .control_requested or
                    other.receiver.permission.value == .control_granted))
                return error.ShareControlActiveOnAnotherPane;
        }
        if (stream.receiver.permission.value != .view_only)
            return error.InvalidPermissionTransition;
        try self.send(stream, .control_request, "");
        stream.receiver.permission.value = .control_requested;
        self.status = .control_requested;
    }

    pub fn sendInput(self: *LiveViewer, bytes: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return error.ShareViewerNotConnected;
        if (!stream.receiver.permission.permitsInput()) return error.ShareInputNotGranted;
        if (bytes.len == 0 or bytes.len > Protocol.max_input_bytes)
            return error.ShareInputTooLarge;
        try self.send(stream, .input, bytes);
    }

    pub fn takeDirtyRows(self: *LiveViewer, output: []u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return 0;
        const count = @min(output.len, @as(usize, stream.receiver.grid.rows));
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
        const stream = self.selectedStream() orelse return .{ .columns = 0, .rows = 0 };
        return .{
            .columns = stream.receiver.grid.columns,
            .rows = stream.receiver.grid.rows,
        };
    }

    pub fn packedCell(self: *LiveViewer, column: usize, row: usize) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return ' ';
        return stream.receiver.grid.packedCell(column, row);
    }

    pub fn cellText(self: *LiveViewer, column: usize, row: usize, output: []u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return 0;
        return stream.receiver.grid.cellText(column, row, output);
    }

    pub fn colorRgb(self: *LiveViewer, color_id: u16) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return 0;
        return stream.receiver.grid.colorRgb(color_id);
    }

    pub fn cursor(self: *LiveViewer) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return 0xffffffff;
        const grid = &stream.receiver.grid;
        if (!grid.cursor_visible) return 0xffffffff;
        return (@as(u32, grid.cursor_row) << 16) | grid.cursor_column;
    }

    pub fn title(self: *LiveViewer, output: []u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return 0;
        const value = stream.receiver.grid.title();
        const count = @min(value.len, output.len);
        @memcpy(output[0..count], value[0..count]);
        return count;
    }

    pub fn applicationCursorKeys(self: *LiveViewer) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return false;
        return stream.receiver.grid.application_cursor_keys;
    }

    fn selectedStream(self: *LiveViewer) ?*Stream {
        if (self.selected_index >= self.streams.items.len) return null;
        return &self.streams.items[self.selected_index];
    }

    fn streamForId(self: *LiveViewer, stream_id: u32) ?*Stream {
        for (self.streams.items) |*stream| {
            if (stream.receiver.stream_id == stream_id) return stream;
        }
        return null;
    }

    fn send(self: *LiveViewer, stream: *Stream, message_type: Protocol.MessageType, payload: []const u8) !void {
        var connection = &(self.connection orelse return error.ShareViewerNotConnected);
        try connection.sendFrame(self.allocator, .{
            .header = .{
                .message_type = message_type,
                .stream_id = stream.receiver.stream_id,
                .sequence = try stream.send_sequence.sending(),
                .payload_length = @intCast(payload.len),
            },
            .payload = payload,
        });
    }

    fn applyManifest(self: *LiveViewer, frame: Protocol.Frame) !void {
        if (self.manifest_received or frame.header.stream_id != 0)
            return error.InvalidShareWorkspace;
        try self.workspace_sequence.receive(frame.header.sequence);
        var decoder = try Session.ManifestDecoder.init(frame.payload);
        while (try decoder.next()) |pane| {
            for (self.streams.items) |stream| {
                if (stream.receiver.stream_id == pane.stream_id or stream.pane_id == pane.pane_id)
                    return error.InvalidShareWorkspace;
            }
            const owned_title = try self.allocator.dupe(u8, pane.title);
            errdefer self.allocator.free(owned_title);
            var receiver = try Mirror.Receiver.init(self.allocator, pane.stream_id);
            errdefer receiver.deinit();
            try self.streams.append(.{
                .pane_id = pane.pane_id,
                .title = owned_title,
                .receiver = receiver,
            });
        }
        if (self.streams.items.len == 0) return error.InvalidShareWorkspace;
        self.selected_index = 0;
        self.manifest_received = true;
        self.status = .connected;
        self.bumpGeneration();
    }

    fn bumpGeneration(self: *LiveViewer) void {
        self.generation +%= 1;
        if (self.generation == 0) self.generation = 1;
    }

    fn updateStatusFromSelected(self: *LiveViewer) void {
        const stream = self.selectedStream() orelse {
            if (self.status != .failed and self.status != .stopped)
                self.status = .connecting;
            return;
        };
        self.status = switch (stream.receiver.permission.value) {
            .view_only => .connected,
            .control_requested => .control_requested,
            .control_granted => .control_granted,
            .revoked => .connected,
        };
    }

    fn worker(self: *LiveViewer) void {
        var pending = Transport.connect(
            self.allocator,
            self.random,
            self.paired_peer.endpoint(),
            self.paired_peer.port,
            self.identity,
            self.paired_peer.public_key,
        ) catch {
            self.setStatus(.failed);
            return;
        };
        const connection = (pending.confirm(pending.sas) catch {
            self.setStatus(.failed);
            return;
        }).*;
        self.mutex.lock();
        self.connection = connection;
        self.mutex.unlock();

        while (true) {
            self.mutex.lock();
            const stop = self.stop_requested;
            self.mutex.unlock();
            if (stop) break;
            var active = &(self.connection.?);
            const readable = active.readable(50) catch {
                self.setStatus(.failed);
                return self.finishConnection();
            };
            if (!readable) continue;
            const bytes = active.receiveFrameAlloc(self.allocator) catch {
                self.setStatus(.failed);
                return self.finishConnection();
            };
            defer self.allocator.free(bytes);
            const frame = Protocol.decodeFrame(bytes) catch {
                self.setStatus(.failed);
                return self.finishConnection();
            };
            self.mutex.lock();
            if (frame.header.message_type == .workspace_manifest) {
                self.applyManifest(frame) catch {
                    self.status = .failed;
                    self.mutex.unlock();
                    return self.finishConnection();
                };
            } else {
                const stream = self.streamForId(frame.header.stream_id) orelse {
                    self.status = .failed;
                    self.mutex.unlock();
                    return self.finishConnection();
                };
                stream.receiver.apply(frame) catch {
                    self.status = .failed;
                    self.mutex.unlock();
                    return self.finishConnection();
                };
                self.bumpGeneration();
                self.updateStatusFromSelected();
            }
            self.mutex.unlock();
        }
        self.setStatus(.stopped);
        self.finishConnection();
    }

    fn finishConnection(self: *LiveViewer) void {
        self.mutex.lock();
        if (self.connection) |*connection| connection.close();
        self.connection = null;
        self.mutex.unlock();
    }

    fn setStatus(self: *LiveViewer, status: Status) void {
        self.mutex.lock();
        self.status = status;
        self.mutex.unlock();
    }
};

test "live viewer multiplexes panes and gates control per selected stream" {
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
    const host = try LiveHost.create(std.testing.allocator, random, host_identity, host_peer, "127.0.0.1", 0, &.{
        .{ .pane_id = 41, .title = "Shell" },
        .{ .pane_id = 42, .title = "Logs" },
    });
    defer host.destroy();
    const viewer_peer = try Identity.Peer.init(host_identity.public_key, "host", "127.0.0.1", host.port(), 1);
    const viewer = try LiveViewer.create(std.testing.allocator, random, viewer_identity, viewer_peer);
    defer viewer.destroy();
    var shell = FakeSession{ .grid = try Vt.Grid.init(std.testing.allocator, 12, 2) };
    defer shell.grid.deinit();
    var logs = FakeSession{ .grid = try Vt.Grid.init(std.testing.allocator, 12, 2) };
    defer logs.grid.deinit();
    try shell.grid.feed("shell pane");
    try logs.grid.feed("logs pane");

    for (0..5000) |_| {
        if (host.currentStatus() == .connected and viewer.streamCount() == 2) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(usize, 2), viewer.streamCount());
    try host.capture(41, &shell);
    try host.capture(42, &logs);
    for (0..5000) |_| {
        if ((viewer.packedCell(0, 0) & 0x1fffff) == 's') break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(u21, 's'), viewer.packedCell(0, 0) & 0x1fffff);
    try viewer.selectStream(1);
    for (0..5000) |_| {
        if ((viewer.packedCell(0, 0) & 0x1fffff) == 'l') break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(u21, 'l'), viewer.packedCell(0, 0) & 0x1fffff);
    var title: [16]u8 = undefined;
    const info = viewer.streamInfo(1, &title).?;
    try std.testing.expectEqual(@as(u64, 42), info.pane_id);
    try std.testing.expectEqualStrings("Logs", title[0..info.title_length]);
    try std.testing.expectError(error.ShareInputNotGranted, viewer.sendInput("id\n"));
    try viewer.requestControl();
    for (0..5000) |_| {
        if (host.currentStatus() == .control_requested) break;
        Transport.sleepMilliseconds(random, 1);
    }
    host.grantControl();
    for (0..5000) |_| {
        if (viewer.currentStatus() == .control_granted) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try viewer.selectStream(0);
    try std.testing.expectError(error.ShareControlActiveOnAnotherPane, viewer.requestControl());
    try std.testing.expectEqual(@import("LiveHost.zig").Status.control_granted, host.currentStatus());
    try viewer.selectStream(1);
    try viewer.sendInput("id\n");
    for (0..5000) |_| {
        if (try host.drainInput(42, &logs) != 0) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqualStrings("id\n", logs.written[0..logs.written_length]);
    try std.testing.expectEqual(@as(usize, 0), shell.written_length);
    host.revokeControl();
    for (0..5000) |_| {
        if (viewer.currentStatus() == .connected) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectError(error.ShareInputNotGranted, viewer.sendInput("whoami\n"));
}
