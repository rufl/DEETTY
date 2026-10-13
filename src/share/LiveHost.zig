const std = @import("std");
const Crypto = @import("Crypto.zig");
const Identity = @import("Identity.zig");
const ShareMutex = @import("Mutex.zig").Mutex;
const Presentation = @import("Presentation.zig");
const Protocol = @import("Protocol.zig");
const Session = @import("Session.zig");
const Transport = @import("Transport.zig");

const keepalive_interval_ms: u64 = 15_000;
const keepalive_timeout_ms: u64 = 45_000;

pub const Status = enum(c_int) {
    listening = 1,
    connected = 2,
    control_requested = 3,
    control_granted = 4,
    stopped = 5,
    failed = 6,
};

pub const TabSpec = struct {
    tab_id: u64,
    title: []const u8,
    active: bool = false,
    active_pane_id: u64,
    zoomed_pane_id: u64 = 0,
    root_node: u16,
    node_count: u16,
};

pub const StreamSpec = struct {
    pane_id: u64,
    tab_id: u64,
    title: []const u8,
};

pub const LayoutSpec = Session.LayoutNodeManifest;

pub const ControlRequest = struct {
    generation: u64,
    stream_id: u32,
    pane_id: u64,
};

const Tab = struct {
    tab_id: u64,
    title: []u8,
    active: bool,
    active_pane_id: u64,
    zoomed_pane_id: u64,
    root_node: u16,
    node_count: u16,
};

const Stream = struct {
    pane_id: u64,
    tab_id: u64,
    title: []u8,
    peer: Session.HostPeer,
};

pub const LiveHost = struct {
    allocator: std.mem.Allocator,
    io: Crypto.RandomContext,
    identity: Crypto.Identity,
    paired_peer: Identity.Peer,
    // Called under the host mutex; false permanently invalidates this host.
    peer_trusted: ?*const fn ([Crypto.public_key_length]u8) bool = null,
    listener: Transport.Listener,
    thread: ?std.Thread = null,
    mutex: ShareMutex = .{},
    streams: std.array_list.Managed(Stream),
    scope: Session.ShareScope,
    tabs: std.array_list.Managed(Tab),
    nodes: std.array_list.Managed(LayoutSpec),
    workspace_send_sequence: Protocol.Sequence = .{},
    workspace_receive_sequence: Protocol.Sequence = .{},
    next_stream_id: u32 = 1,
    queue: std.array_list.Managed([]u8),
    pending_bytes: usize = 0,
    peer_hello_received: bool = false,
    last_peer_activity_ms: u64 = 0,
    last_ping_ms: u64 = 0,
    awaiting_pong: bool = false,
    status: Status = .listening,
    stop_requested: bool = false,
    grant_requested: bool = false,
    revoke_requested: bool = false,
    control_stream_id: u32 = 0,
    control_generation: u64 = 0,
    input_stream_id: u32 = 0,
    input: [Protocol.max_input_bytes]u8 = undefined,
    input_length: usize = 0,

    pub fn create(
        allocator: std.mem.Allocator,
        io: Crypto.RandomContext,
        identity: Crypto.Identity,
        paired_peer: Identity.Peer,
        peer_trusted: ?*const fn ([Crypto.public_key_length]u8) bool,
        host: ?[]const u8,
        listen_port: u16,
        scope: Session.ShareScope,
        tab_specs: []const TabSpec,
        stream_specs: []const StreamSpec,
        layout_specs: []const LayoutSpec,
    ) !*LiveHost {
        if (paired_peer.revoked) return error.PairedDeviceRevoked;
        if (peer_trusted) |check_peer|
            if (!check_peer(paired_peer.public_key)) return error.PairedDeviceRevoked;
        try validateWorkspaceSpec(scope, tab_specs, stream_specs, layout_specs);
        const self = try allocator.create(LiveHost);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .io = io,
            .identity = identity,
            .paired_peer = paired_peer,
            .peer_trusted = peer_trusted,
            .listener = try Transport.Listener.listen(host, listen_port),
            .scope = scope,
            .tabs = std.array_list.Managed(Tab).init(allocator),
            .streams = std.array_list.Managed(Stream).init(allocator),
            .nodes = std.array_list.Managed(LayoutSpec).init(allocator),
            .queue = std.array_list.Managed([]u8).init(allocator),
            .next_stream_id = @intCast(stream_specs.len + 1),
        };
        errdefer self.listener.close();
        errdefer self.deinitWorkspace();
        try self.tabs.ensureTotalCapacity(tab_specs.len);
        try self.streams.ensureTotalCapacity(stream_specs.len);
        try self.nodes.ensureTotalCapacity(layout_specs.len);
        for (tab_specs) |spec| {
            self.tabs.appendAssumeCapacity(.{
                .tab_id = spec.tab_id,
                .title = try allocator.dupe(u8, spec.title),
                .active = spec.active,
                .active_pane_id = spec.active_pane_id,
                .zoomed_pane_id = spec.zoomed_pane_id,
                .root_node = spec.root_node,
                .node_count = spec.node_count,
            });
        }
        for (stream_specs, 0..) |spec, index| {
            self.streams.appendAssumeCapacity(.{
                .pane_id = spec.pane_id,
                .tab_id = spec.tab_id,
                .title = try allocator.dupe(u8, spec.title),
                .peer = try Session.HostPeer.init(@intCast(index + 1)),
            });
        }
        self.nodes.appendSliceAssumeCapacity(layout_specs);
        self.thread = try std.Thread.spawn(.{}, worker, .{self});
        return self;
    }

    pub fn stop(self: *LiveHost) void {
        self.mutex.lock();
        self.stop_requested = true;
        self.wipeInput();
        self.mutex.unlock();
        self.listener.close();
    }

    pub fn destroy(self: *LiveHost) void {
        self.stop();
        if (self.thread) |thread| thread.join();
        self.clearQueue();
        self.queue.deinit();
        self.deinitWorkspace();
        self.identity.deinit();
        self.allocator.destroy(self);
    }

    fn deinitWorkspace(self: *LiveHost) void {
        for (self.streams.items) |*stream| {
            stream.peer.stop();
            self.allocator.free(stream.title);
        }
        self.streams.deinit();
        for (self.tabs.items) |tab| self.allocator.free(tab.title);
        self.tabs.deinit();
        self.nodes.deinit();
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

    pub fn hasPane(self: *LiveHost, pane_id: u64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.streamForPane(pane_id) != null;
    }

    pub fn needsCheckpoint(self: *LiveHost, pane_id: u64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.streamForPane(pane_id) orelse return false;
        return self.isConnected() and stream.peer.checkpoint_required;
    }

    pub fn syncWorkspace(
        self: *LiveHost,
        scope: Session.ShareScope,
        tab_specs: []const TabSpec,
        stream_specs: []const StreamSpec,
        layout_specs: []const LayoutSpec,
    ) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        try validateWorkspaceSpec(scope, tab_specs, stream_specs, layout_specs);
        if (self.workspaceMatches(scope, tab_specs, stream_specs, layout_specs)) return false;

        var new_stream_count: usize = 0;
        for (stream_specs) |spec| {
            if (self.streamForPane(spec.pane_id) == null) new_stream_count += 1;
        }
        if (new_stream_count != 0 and
            (self.next_stream_id == 0 or
                @as(u64, self.next_stream_id) + new_stream_count > std.math.maxInt(u32)))
            return error.ShareStreamLimitReached;

        var new_tabs = std.array_list.Managed(Tab).init(self.allocator);
        errdefer {
            for (new_tabs.items) |tab| self.allocator.free(tab.title);
            new_tabs.deinit();
        }
        try new_tabs.ensureTotalCapacity(tab_specs.len);
        for (tab_specs) |spec| {
            new_tabs.appendAssumeCapacity(.{
                .tab_id = spec.tab_id,
                .title = try self.allocator.dupe(u8, spec.title),
                .active = spec.active,
                .active_pane_id = spec.active_pane_id,
                .zoomed_pane_id = spec.zoomed_pane_id,
                .root_node = spec.root_node,
                .node_count = spec.node_count,
            });
        }
        var new_nodes = std.array_list.Managed(LayoutSpec).init(self.allocator);
        errdefer new_nodes.deinit();
        try new_nodes.appendSlice(layout_specs);

        var owned_titles: [Protocol.max_streams]?[]u8 = @splat(null);
        errdefer for (owned_titles) |owned| if (owned) |title| self.allocator.free(title);
        for (stream_specs, 0..) |spec, index|
            owned_titles[index] = try self.allocator.dupe(u8, spec.title);

        var reordered = std.array_list.Managed(Stream).init(self.allocator);
        errdefer reordered.deinit();
        try reordered.ensureTotalCapacity(stream_specs.len);
        for (stream_specs, 0..) |spec, desired_index| {
            var existing_index: usize = 0;
            while (existing_index < self.streams.items.len and
                self.streams.items[existing_index].pane_id != spec.pane_id) : (existing_index += 1)
            {}
            if (existing_index < self.streams.items.len) {
                var stream = self.streams.orderedRemove(existing_index);
                self.allocator.free(stream.title);
                stream.title = owned_titles[desired_index].?;
                owned_titles[desired_index] = null;
                stream.tab_id = spec.tab_id;
                reordered.appendAssumeCapacity(stream);
            } else {
                const stream_id = self.availableStreamId().?;
                reordered.appendAssumeCapacity(.{
                    .pane_id = spec.pane_id,
                    .tab_id = spec.tab_id,
                    .title = owned_titles[desired_index].?,
                    .peer = Session.HostPeer.init(stream_id) catch unreachable,
                });
                owned_titles[desired_index] = null;
            }
        }

        for (self.streams.items) |*removed| self.retireStream(removed);
        self.streams.deinit();
        self.streams = reordered;
        for (self.tabs.items) |tab| self.allocator.free(tab.title);
        self.tabs.deinit();
        self.tabs = new_tabs;
        self.nodes.deinit();
        self.nodes = new_nodes;
        self.scope = scope;
        if (self.isConnected()) self.enqueueManifest(.workspace_update) catch {
            self.status = .failed;
            self.stop_requested = true;
        };
        return true;
    }

    fn workspaceMatches(
        self: *LiveHost,
        scope: Session.ShareScope,
        tab_specs: []const TabSpec,
        stream_specs: []const StreamSpec,
        layout_specs: []const LayoutSpec,
    ) bool {
        if (self.scope != scope or self.tabs.items.len != tab_specs.len or
            self.streams.items.len != stream_specs.len or
            self.nodes.items.len != layout_specs.len)
            return false;
        for (self.tabs.items, tab_specs) |tab, spec| {
            if (tab.tab_id != spec.tab_id or tab.active != spec.active or
                tab.active_pane_id != spec.active_pane_id or
                tab.zoomed_pane_id != spec.zoomed_pane_id or
                tab.root_node != spec.root_node or tab.node_count != spec.node_count or
                !std.mem.eql(u8, tab.title, spec.title))
                return false;
        }
        for (self.streams.items, stream_specs) |stream, spec| {
            if (stream.pane_id != spec.pane_id or stream.tab_id != spec.tab_id or
                !std.mem.eql(u8, stream.title, spec.title))
                return false;
        }
        for (self.nodes.items, layout_specs) |node, spec|
            if (!std.meta.eql(node, spec)) return false;
        return true;
    }

    fn retireStream(self: *LiveHost, stream: *Stream) void {
        if (self.control_stream_id == stream.peer.stream_id) {
            self.control_stream_id = 0;
            self.grant_requested = false;
            self.revoke_requested = false;
            self.status = if (self.isConnected()) .connected else self.status;
        }
        if (self.input_stream_id == stream.peer.stream_id) self.wipeInput();
        self.dropQueuedStream(stream.peer.stream_id);
        stream.peer.stop();
        self.allocator.free(stream.title);
    }

    fn validateWorkspaceSpec(
        scope: Session.ShareScope,
        tab_specs: []const TabSpec,
        stream_specs: []const StreamSpec,
        layout_specs: []const LayoutSpec,
    ) !void {
        if (tab_specs.len > Protocol.max_tabs or
            stream_specs.len > Protocol.max_streams)
            return error.InvalidShareWorkspace;
        var tabs: [Protocol.max_tabs]Session.TabManifest = undefined;
        for (tab_specs, 0..) |tab, index| {
            tabs[index] = .{
                .tab_id = tab.tab_id,
                .title = tab.title,
                .active = tab.active,
                .active_pane_id = tab.active_pane_id,
                .zoomed_pane_id = tab.zoomed_pane_id,
                .root_node = tab.root_node,
                .node_count = tab.node_count,
            };
        }
        var panes: [Protocol.max_streams]Session.PaneManifest = undefined;
        for (stream_specs, 0..) |stream, index| {
            panes[index] = .{
                .stream_id = @intCast(index + 1),
                .pane_id = stream.pane_id,
                .tab_id = stream.tab_id,
                .title = stream.title,
            };
        }
        try Session.validateWorkspaceManifest(.{
            .scope = scope,
            .tabs = tabs[0..tab_specs.len],
            .panes = panes[0..stream_specs.len],
            .nodes = layout_specs,
        });
    }

    fn availableStreamId(self: *LiveHost) ?u32 {
        if (self.next_stream_id == 0) return null;
        const stream_id = self.next_stream_id;
        self.next_stream_id +%= 1;
        return stream_id;
    }

    fn isConnected(self: *LiveHost) bool {
        return self.status == .connected or self.status == .control_requested or
            self.status == .control_granted;
    }

    pub fn currentStatus(self: *LiveHost) Status {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.status;
    }

    pub fn capture(self: *LiveHost, pane_id: u64, terminal_session: anytype) !void {
        return self.captureGrid(pane_id, &terminal_session.grid);
    }

    pub fn captureGrid(self: *LiveHost, pane_id: u64, grid: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.status != .connected and self.status != .control_requested and self.status != .control_granted)
            return;
        const stream = self.streamForPane(pane_id) orelse return error.SharePaneNotPublished;
        if (stream.peer.checkpoint_required) {
            try self.enqueueCheckpoint(stream, grid);
            stream.peer.checkpoint_required = false;
            stream.peer.publisher.checkpointComplete(grid);
            return;
        }
        switch (stream.peer.publisher.historyDelta(grid)) {
            .unchanged => {},
            .reset => {
                try self.enqueueCheckpoint(stream, grid);
                stream.peer.publisher.checkpointComplete(grid);
                return;
            },
            .append_from => |first| {
                for (first..grid.historyCount()) |row| {
                    const owned = try stream.peer.publisher.historyRowFrameAlloc(
                        self.allocator,
                        grid,
                        row,
                        0,
                        .history_push,
                    );
                    defer owned.deinit(self.allocator);
                    try self.enqueue(owned.frame);
                }
                stream.peer.publisher.historyComplete(grid);
            },
        }
        var rows: [Protocol.max_rows]u8 = undefined;
        _ = stream.peer.publisher.changedRows(grid, rows[0..grid.rows]);
        for (rows[0..grid.rows], 0..) |changed, row| {
            if (changed == 0) continue;
            const owned = try stream.peer.publisher.rowFrameAlloc(self.allocator, grid, row, .damage);
            defer owned.deinit(self.allocator);
            try self.enqueue(owned.frame);
        }
        if (try stream.peer.publisher.cursorFrame(grid)) |cursor_value| {
            var cursor = cursor_value;
            cursor.frame.payload = &cursor.payload;
            try self.enqueue(cursor.frame);
        }
        if (try stream.peer.publisher.titleFrame(grid, false)) |title|
            try self.enqueue(title);
    }

    fn trusted(self: *LiveHost) bool {
        if (self.stop_requested) return false;
        if (self.peer_trusted) |check| {
            if (!check(self.paired_peer.public_key)) {
                self.stop_requested = true;
                self.status = .stopped;
                self.grant_requested = false;
                self.wipeInput();
                return false;
            }
        }
        return true;
    }

    pub fn controlRequest(self: *LiveHost) ?ControlRequest {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (!self.trusted() or self.status != .control_requested or
            self.grant_requested or self.revoke_requested) return null;
        const stream = self.streamForId(self.control_stream_id) orelse return null;
        return .{
            .generation = self.control_generation,
            .stream_id = self.control_stream_id,
            .pane_id = stream.pane_id,
        };
    }

    pub fn respondControl(self: *LiveHost, request: ControlRequest, approved: bool) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (!self.trusted() or self.status != .control_requested or
            self.grant_requested or self.revoke_requested or
            request.generation != self.control_generation or
            request.stream_id != self.control_stream_id) return false;
        const stream = self.streamForId(request.stream_id) orelse return false;
        if (stream.pane_id != request.pane_id) return false;
        if (approved) {
            self.grant_requested = true;
        } else {
            self.wipeInput();
            self.revoke_requested = true;
        }
        return true;
    }

    pub fn revokeControl(self: *LiveHost) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.status == .control_requested or self.status == .control_granted) {
            self.grant_requested = false;
            self.wipeInput();
            self.revoke_requested = true;
        }
    }

    pub fn drainInput(self: *LiveHost, pane_id: u64, terminal_session: anytype) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (!self.trusted() or self.revoke_requested or self.input_length == 0) return 0;
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
        const history_count = @min(
            grid.historyCount(),
            @as(usize, Protocol.max_scrollback_rows),
        );
        var begin = try stream.peer.publisher.snapshotBegin(
            grid,
            @intCast(history_count),
        );
        begin.frame.payload = &begin.payload;
        try self.enqueue(begin.frame);
        const first_history = grid.historyCount() - history_count;
        for (first_history..grid.historyCount(), 0..) |source_row, wire_row| {
            const owned = try stream.peer.publisher.historyRowFrameAlloc(
                self.allocator,
                grid,
                source_row,
                wire_row,
                .history_row,
            );
            defer owned.deinit(self.allocator);
            try self.enqueue(owned.frame);
        }
        for (0..grid.rows) |row| {
            const owned = try stream.peer.publisher.rowFrameAlloc(
                self.allocator,
                grid,
                row,
                .row_chunk,
            );
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
            self.status = .failed;
            self.stop_requested = true;
            return error.SharePeerBackpressureExceeded;
        }
        try self.queue.append(bytes);
        self.pending_bytes += bytes.len;
    }

    fn enqueueWorkspace(
        self: *LiveHost,
        message_type: Protocol.MessageType,
        payload: []const u8,
        final: bool,
    ) !void {
        if (message_type != .workspace_update and message_type != .ping and
            message_type != .disconnect_reason)
            return error.InvalidShareWorkspaceMessage;
        try self.enqueue(.{
            .header = .{
                .message_type = message_type,
                .flags = .{ .final = final },
                .stream_id = 0,
                .sequence = try self.workspace_send_sequence.sending(),
                .payload_length = @intCast(payload.len),
            },
            .payload = payload,
        });
    }

    fn manifestPayloadAlloc(self: *LiveHost) ![]u8 {
        var tabs: [Protocol.max_tabs]Session.TabManifest = undefined;
        for (self.tabs.items, 0..) |tab, index| {
            tabs[index] = .{
                .tab_id = tab.tab_id,
                .title = tab.title,
                .active = tab.active,
                .active_pane_id = tab.active_pane_id,
                .zoomed_pane_id = tab.zoomed_pane_id,
                .root_node = tab.root_node,
                .node_count = tab.node_count,
            };
        }
        var panes: [Protocol.max_streams]Session.PaneManifest = undefined;
        for (self.streams.items, 0..) |stream, index| {
            panes[index] = .{
                .stream_id = stream.peer.stream_id,
                .pane_id = stream.pane_id,
                .tab_id = stream.tab_id,
                .title = stream.title,
            };
        }
        return Session.encodeWorkspaceManifestAlloc(self.allocator, .{
            .scope = self.scope,
            .tabs = tabs[0..self.tabs.items.len],
            .panes = panes[0..self.streams.items.len],
            .nodes = self.nodes.items,
        });
    }

    fn enqueueManifest(self: *LiveHost, message_type: Protocol.MessageType) !void {
        if (message_type != .workspace_update) return error.InvalidShareWorkspaceMessage;
        const payload = try self.manifestPayloadAlloc();
        defer self.allocator.free(payload);
        try self.enqueueWorkspace(message_type, payload, false);
    }

    fn dropQueuedStream(self: *LiveHost, stream_id: u32) void {
        var index: usize = 0;
        while (index < self.queue.items.len) {
            const bytes = self.queue.items[index];
            const frame = Protocol.decodeFrame(bytes) catch {
                index += 1;
                continue;
            };
            if (frame.header.stream_id != stream_id) {
                index += 1;
                continue;
            }
            const removed = self.queue.orderedRemove(index);
            self.pending_bytes -= removed.len;
            self.allocator.free(removed);
        }
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

    fn sendInitial(self: *LiveHost, connection: *Transport.SecureConnection) !void {
        var hello_payload: [Session.hello_payload_length]u8 = undefined;
        try Session.encodeHello(&hello_payload, .{
            .capabilities = Session.required_capabilities,
            .max_stream_count = Protocol.max_streams,
        });
        self.mutex.lock();
        const hello_sequence = self.workspace_send_sequence.sending() catch |err| {
            self.mutex.unlock();
            return err;
        };
        self.mutex.unlock();
        try connection.sendFrame(self.allocator, .{
            .header = .{
                .message_type = .hello,
                .stream_id = 0,
                .sequence = hello_sequence,
                .payload_length = hello_payload.len,
            },
            .payload = &hello_payload,
        });

        if (!try connection.readable(5_000)) return error.ShareHelloTimedOut;
        const response_bytes = try connection.receiveFrameAlloc(self.allocator);
        defer self.allocator.free(response_bytes);
        const response = try Protocol.decodeFrame(response_bytes);
        if (response.header.message_type != .hello or response.header.stream_id != 0 or
            response.header.flags.final)
            return error.InvalidShareHello;

        self.mutex.lock();
        defer self.mutex.unlock();
        if (!self.trusted()) return error.PairedDeviceRevoked;
        try self.workspace_receive_sequence.receive(response.header.sequence);
        if (self.peer_hello_received) return error.InvalidShareHello;
        _ = try Session.decodeHello(response.payload);
        self.peer_hello_received = true;
        const payload = try self.manifestPayloadAlloc();
        defer self.allocator.free(payload);
        try connection.sendFrame(self.allocator, .{
            .header = .{
                .message_type = .workspace_manifest,
                .stream_id = 0,
                .sequence = try self.workspace_send_sequence.sending(),
                .payload_length = @intCast(payload.len),
            },
            .payload = payload,
        });
    }

    fn sendDisconnect(
        self: *LiveHost,
        connection: *Transport.SecureConnection,
        reason: []const u8,
    ) !void {
        try Session.validateDisconnectReason(reason);
        self.mutex.lock();
        const sequence = self.workspace_send_sequence.sending() catch |err| {
            self.mutex.unlock();
            return err;
        };
        self.mutex.unlock();
        try connection.sendFrame(self.allocator, .{
            .header = .{
                .message_type = .disconnect_reason,
                .flags = .{ .final = true },
                .stream_id = 0,
                .sequence = sequence,
                .payload_length = @intCast(reason.len),
            },
            .payload = reason,
        });
    }

    fn prepareReconnect(self: *LiveHost) void {
        self.clearQueue();
        self.workspace_receive_sequence = .{};
        self.workspace_send_sequence = .{};
        self.peer_hello_received = false;
        self.awaiting_pong = false;
        self.last_peer_activity_ms = 0;
        self.last_ping_ms = 0;
        self.control_stream_id = 0;
        self.grant_requested = false;
        self.revoke_requested = false;
        self.wipeInput();
        for (self.streams.items) |*stream| stream.peer.prepareReconnect();
    }

    fn worker(self: *LiveHost) void {
        while (true) {
            self.serveConnection();
            self.mutex.lock();
            if (self.stop_requested) {
                self.status = .stopped;
                self.mutex.unlock();
                return;
            }
            self.prepareReconnect();
            self.status = .listening;
            self.mutex.unlock();
        }
    }

    fn serveConnection(self: *LiveHost) void {
        self.mutex.lock();
        const allowed = self.trusted();
        self.mutex.unlock();
        if (!allowed) return;
        var pending = self.listener.accept(self.io, self.identity, self.paired_peer.public_key) catch {
            self.setTerminalStatus(.failed);
            return;
        };
        var connection = pending.confirm(pending.sas) catch {
            self.setTerminalStatus(.failed);
            return;
        };
        defer connection.close();
        self.mutex.lock();
        const still_allowed = self.trusted();
        self.mutex.unlock();
        if (!still_allowed) return;
        self.sendInitial(connection) catch {
            self.setTerminalStatus(.failed);
            return;
        };
        const connected_at = Transport.monotonicMilliseconds(self.io);
        self.mutex.lock();
        self.status = .connected;
        self.last_peer_activity_ms = connected_at;
        self.last_ping_ms = connected_at;
        self.mutex.unlock();
        while (true) {
            self.mutex.lock();
            const should_stop = !self.trusted();
            const revoke = self.revoke_requested;
            const grant = self.grant_requested and !revoke;
            self.grant_requested = false;
            self.revoke_requested = false;
            const control_stream_id = self.control_stream_id;
            const now = Transport.monotonicMilliseconds(self.io);
            const pong_expired = self.awaiting_pong and now -| self.last_ping_ms >= keepalive_timeout_ms;
            if (!should_stop and !pong_expired and !self.awaiting_pong and
                now -| self.last_peer_activity_ms >= keepalive_interval_ms)
            {
                self.enqueueWorkspace(.ping, "", false) catch {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                };
                self.awaiting_pong = true;
                self.last_ping_ms = now;
            }
            const queued = if (should_stop or pong_expired or self.queue.items.len == 0)
                null
            else
                self.queue.orderedRemove(0);
            if (queued) |bytes| self.pending_bytes -= bytes.len;
            self.mutex.unlock();

            if (should_stop) {
                self.sendDisconnect(connection, "host stopped sharing") catch {};
                self.setTerminalStatus(.stopped);
                return;
            }
            if (pong_expired) {
                self.setTerminalStatus(.failed);
                return;
            }
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
                if (grant or revoke) {
                    self.mutex.lock();
                    self.grant_requested = self.grant_requested or grant;
                    self.revoke_requested = self.revoke_requested or revoke;
                    self.mutex.unlock();
                }
                continue;
            }
            if (grant) {
                self.mutex.lock();
                if (!self.trusted() or self.revoke_requested or
                    self.control_stream_id != control_stream_id or self.status != .control_requested)
                {
                    self.mutex.unlock();
                    continue;
                }
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
            const readable = connection.readable(if (queued == null) 20 else 0) catch {
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
            if (!self.trusted()) {
                self.mutex.unlock();
                return;
            }
            self.last_peer_activity_ms = Transport.monotonicMilliseconds(self.io);
            if (frame.header.stream_id == 0) {
                const final_expected = frame.header.message_type == .disconnect_reason;
                if (frame.header.flags.final != final_expected) {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                }
                self.workspace_receive_sequence.receive(frame.header.sequence) catch {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                };
                switch (frame.header.message_type) {
                    .pong => {
                        if (frame.payload.len != 0 or !self.awaiting_pong) {
                            self.status = .failed;
                            self.mutex.unlock();
                            return;
                        }
                        self.awaiting_pong = false;
                    },
                    .disconnect_reason => {
                        Session.validateDisconnectReason(frame.payload) catch {
                            self.status = .failed;
                            self.mutex.unlock();
                            return;
                        };
                        self.status = .stopped;
                        self.wipeInput();
                        self.mutex.unlock();
                        return;
                    },
                    else => {
                        self.status = .failed;
                        self.mutex.unlock();
                        return;
                    },
                }
                self.mutex.unlock();
                continue;
            }
            if (frame.header.flags.final or !self.peer_hello_received) {
                self.status = .failed;
                self.mutex.unlock();
                return;
            }
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
            if (frame.header.message_type == .resync) {
                self.dropQueuedStream(frame.header.stream_id);
                stream.peer.prepareResync();
                if (self.control_stream_id == frame.header.stream_id) {
                    self.control_stream_id = 0;
                    self.grant_requested = false;
                    self.revoke_requested = false;
                    self.wipeInput();
                    self.status = .connected;
                }
            } else if (frame.header.message_type == .control_release) {
                if (self.control_stream_id != frame.header.stream_id) {
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                }
                self.control_stream_id = 0;
                self.grant_requested = false;
                self.revoke_requested = false;
                self.wipeInput();
                self.status = .connected;
            } else if (input) |bytes| {
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
                if (self.control_generation == std.math.maxInt(u64)) {
                    self.stop_requested = true;
                    self.status = .failed;
                    self.mutex.unlock();
                    return;
                }
                self.control_generation += 1;
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
    const live = try LiveHost.create(
        std.testing.allocator,
        io,
        host_identity,
        host_peer,
        null,
        "127.0.0.1",
        0,
        .pane,
        &.{.{
            .tab_id = 7,
            .title = "Shells",
            .active = true,
            .active_pane_id = 41,
            .root_node = 0,
            .node_count = 1,
        }},
        &.{.{ .pane_id = 41, .tab_id = 7, .title = "Shell" }},
        &.{.{ .tab_id = 7, .kind = .leaf, .pane_id = 41, .ratio_permille = 0 }},
    );
    defer live.destroy();
    const viewer_peer = try Identity.Peer.init(host_identity.public_key, "host", "127.0.0.1", live.port(), 1);
    var viewer = try Link.Viewer.connect(std.testing.allocator, io, "127.0.0.1", live.port(), viewer_identity, &viewer_peer, 1);
    defer viewer.close();
    const hello_bytes = try viewer.connection.receiveFrameAlloc(std.testing.allocator);
    defer std.testing.allocator.free(hello_bytes);
    const hello = try Protocol.decodeFrame(hello_bytes);
    try std.testing.expectEqual(Protocol.MessageType.hello, hello.header.message_type);
    _ = try Session.decodeHello(hello.payload);
    var hello_response: [Session.hello_payload_length]u8 = undefined;
    try Session.encodeHello(&hello_response, .{
        .capabilities = Session.required_capabilities,
        .max_stream_count = Protocol.max_streams,
    });
    try viewer.connection.sendFrame(std.testing.allocator, .{
        .header = .{
            .message_type = .hello,
            .stream_id = 0,
            .sequence = 0,
            .payload_length = hello_response.len,
        },
        .payload = &hello_response,
    });
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
    const original_request = live.controlRequest().?;
    try std.testing.expect(live.respondControl(original_request, true));
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
    while (try viewer.receive(std.testing.allocator) != .control_revoke) {}
    try viewer.requestControl(std.testing.allocator);
    for (0..5000) |_| {
        if (live.currentStatus() == .control_requested) break;
        Transport.sleepMilliseconds(io, 1);
    }
    try std.testing.expect(!live.respondControl(original_request, true));
    const replacement_request = live.controlRequest().?;
    try std.testing.expect(live.respondControl(replacement_request, false));
    try std.testing.expect(!live.respondControl(replacement_request, true));
}

test "live host backpressure frees rejected frame exactly once" {
    var host: LiveHost = undefined;
    host.allocator = std.testing.allocator;
    host.queue = std.array_list.Managed([]u8).init(std.testing.allocator);
    defer host.queue.deinit();
    host.pending_bytes = Protocol.max_pending_peer_bytes;
    host.status = .connected;
    host.stop_requested = false;
    try std.testing.expectError(error.SharePeerBackpressureExceeded, host.enqueue(.{
        .header = .{ .message_type = .ping, .stream_id = 0, .sequence = 0, .payload_length = 0 },
        .payload = "",
    }));
    try std.testing.expect(host.stop_requested);
    try std.testing.expectEqual(Status.failed, host.status);
    try std.testing.expectEqual(@as(usize, 0), host.queue.items.len);
}

test "live host invalidated trust discards input and cannot be revived" {
    const Authority = struct {
        var allowed = true;
        fn check(_: [Crypto.public_key_length]u8) bool {
            return allowed;
        }
    };
    const Sink = struct {
        fn write(_: *@This(), _: []const u8) !void {
            return error.RevokedInputDispatched;
        }
    };
    var host: LiveHost = undefined;
    host.mutex = .{};
    host.stop_requested = false;
    host.peer_trusted = Authority.check;
    host.paired_peer.public_key = @splat(0);
    host.input_length = 4;
    host.input_stream_id = 1;
    @memcpy(host.input[0..4], "late");
    host.status = .control_granted;
    host.grant_requested = false;
    host.revoke_requested = false;
    var sink = Sink{};
    Authority.allowed = false;
    defer Authority.allowed = true;
    try std.testing.expectEqual(@as(usize, 0), try host.drainInput(1, &sink));
    Authority.allowed = true;
    try std.testing.expectEqual(@as(usize, 0), try host.drainInput(1, &sink));
    try std.testing.expect(host.controlRequest() == null);
    try std.testing.expectEqual(Status.stopped, host.currentStatus());
}
