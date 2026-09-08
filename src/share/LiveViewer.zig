const std = @import("std");
const Crypto = @import("Crypto.zig");
const Identity = @import("Identity.zig");
const Mirror = @import("Mirror.zig");
const Protocol = @import("Protocol.zig");
const Session = @import("Session.zig");
const ShareMutex = @import("Mutex.zig").Mutex;
const Transport = @import("Transport.zig");
const Vt = @import("../terminal/Vt.zig");

pub const Status = enum(c_int) {
    connecting = 1,
    connected = 2,
    control_requested = 3,
    control_granted = 4,
    stopped = 5,
    failed = 6,
};

const Tab = struct {
    tab_id: u64,
    title: []u8,
    active: bool,
    active_pane_id: u64,
    zoomed_pane_id: u64,
    root_node: u16,
    node_start: u16,
    node_count: u16,
};

const Stream = struct {
    pane_id: u64,
    tab_id: u64,
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
    scope: Session.ShareScope = .pane,
    tabs: std.array_list.Managed(Tab),
    nodes: std.array_list.Managed(Session.LayoutNodeManifest),
    workspace_receive_sequence: Protocol.Sequence = .{},
    workspace_send_sequence: Protocol.Sequence = .{},
    selected_index: usize = 0,
    hello_received: bool = false,
    stream_revision: u64 = 1,
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
            .tabs = std.array_list.Managed(Tab).init(allocator),
            .streams = std.array_list.Managed(Stream).init(allocator),
            .nodes = std.array_list.Managed(Session.LayoutNodeManifest).init(allocator),
        };
        self.thread = try std.Thread.spawn(.{}, worker, .{self});
        return self;
    }

    pub fn destroy(self: *LiveViewer) void {
        self.mutex.lock();
        self.stop_requested = true;
        self.mutex.unlock();
        if (self.thread) |thread| thread.join();
        self.deinitWorkspace();
        self.streams.deinit();
        self.tabs.deinit();
        self.nodes.deinit();
        self.identity.deinit();
        self.allocator.destroy(self);
    }

    fn deinitWorkspace(self: *LiveViewer) void {
        for (self.streams.items) |*stream| {
            stream.receiver.deinit();
            self.allocator.free(stream.title);
        }
        self.streams.clearRetainingCapacity();
        for (self.tabs.items) |tab| self.allocator.free(tab.title);
        self.tabs.clearRetainingCapacity();
        self.nodes.clearRetainingCapacity();
    }

    pub fn currentStatus(self: *LiveViewer) Status {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.status;
    }
    pub fn reconnect(self: *LiveViewer) !void {
        self.mutex.lock();
        if (self.status != .failed and self.status != .stopped) {
            self.mutex.unlock();
            return error.ShareReconnectNotAvailable;
        }
        self.mutex.unlock();
        if (self.thread) |thread| thread.join();
        self.thread = null;

        self.mutex.lock();
        self.deinitWorkspace();
        self.connection = null;
        self.scope = .pane;
        self.workspace_receive_sequence = .{};
        self.workspace_send_sequence = .{};
        self.selected_index = 0;
        self.hello_received = false;
        self.manifest_received = false;
        self.stop_requested = false;
        self.status = .connecting;
        self.bumpStreamRevision();
        self.bumpGeneration();
        self.mutex.unlock();

        self.thread = std.Thread.spawn(.{}, worker, .{self}) catch |err| {
            self.setStatus(.failed);
            return err;
        };
    }

    pub fn streamCount(self: *LiveViewer) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.streams.items.len;
    }

    pub fn shareScope(self: *LiveViewer) Session.ShareScope {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.scope;
    }

    pub fn tabCount(self: *LiveViewer) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.tabs.items.len;
    }

    pub fn tabInfo(self: *LiveViewer, index: usize, title_output: []u8) ?struct {
        tab_id: u64,
        title_length: usize,
        selected: bool,
        active: bool,
    } {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.tabs.items.len) return null;
        const tab = &self.tabs.items[index];
        const count = @min(tab.title.len, title_output.len);
        @memcpy(title_output[0..count], tab.title[0..count]);
        const selected_tab_id = if (self.selectedStream()) |stream| stream.tab_id else 0;
        return .{
            .tab_id = tab.tab_id,
            .title_length = count,
            .selected = tab.tab_id == selected_tab_id,
            .active = tab.active,
        };
    }

    pub fn selectedIndex(self: *LiveViewer) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.selected_index;
    }

    pub fn streamRevision(self: *LiveViewer) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stream_revision;
    }

    pub fn streamInfo(self: *LiveViewer, index: usize, title_output: []u8) ?struct {
        pane_id: u64,
        tab_id: u64,
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
            .tab_id = stream.tab_id,
            .title_length = count,
            .selected = index == self.selected_index,
        };
    }

    pub fn selectStream(self: *LiveViewer, index: usize) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return error.InvalidShareStream;
        const stream = self.streams.items[index];
        for (self.tabs.items) |tab| {
            if (tab.tab_id == stream.tab_id and tab.zoomed_pane_id != 0 and
                tab.zoomed_pane_id != stream.pane_id)
                return error.SharePaneHiddenByZoom;
        }
        try self.releaseControlForSelectionChange(index);
        self.selected_index = index;
        self.bumpGeneration();
        self.updateStatusFromSelected();
    }

    pub fn selectTab(self: *LiveViewer, index: usize) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.tabs.items.len) return error.InvalidShareTab;
        const tab = self.tabs.items[index];
        const target_pane_id = if (tab.zoomed_pane_id != 0)
            tab.zoomed_pane_id
        else
            tab.active_pane_id;
        for (self.streams.items, 0..) |stream, stream_index| {
            if (stream.tab_id != tab.tab_id or stream.pane_id != target_pane_id) continue;
            try self.releaseControlForSelectionChange(stream_index);
            self.selected_index = stream_index;
            self.bumpGeneration();
            self.updateStatusFromSelected();
            return;
        }
        return error.InvalidShareTab;
    }

    pub fn requestControl(self: *LiveViewer) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return error.ShareViewerNotConnected;
        for (self.streams.items, 0..) |*other, index| {
            if (index == self.selected_index or
                (other.receiver.permission.value != .control_requested and
                    other.receiver.permission.value != .control_granted))
                continue;
            try self.send(other, .control_release, "");
            other.receiver.permission.revoke();
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
    pub fn scrollViewport(self: *LiveViewer, lines: isize) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse
            return error.ShareViewerNotConnected;
        stream.receiver.grid.scrollViewport(lines);
        self.bumpGeneration();
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
    pub const PaneLayout = struct {
        x: u32 = 0,
        y: u32 = 0,
        width: u32 = 0,
        height: u32 = 0,
        visible: bool = false,
        selected: bool = false,
        host_active: bool = false,
    };

    const layout_extent: u32 = 1_000_000;

    pub fn paneLayout(self: *LiveViewer, index: usize) ?PaneLayout {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return null;
        const stream = &self.streams.items[index];
        const selected = self.selectedStream() orelse return null;
        if (stream.tab_id != selected.tab_id) return .{};
        var tab: ?*const Tab = null;
        for (self.tabs.items) |*candidate| {
            if (candidate.tab_id == stream.tab_id) {
                tab = candidate;
                break;
            }
        }
        const current_tab = tab orelse return null;
        const state = PaneLayout{
            .selected = index == self.selected_index,
            .host_active = stream.pane_id == current_tab.active_pane_id,
        };
        if (current_tab.zoomed_pane_id != 0) {
            if (stream.pane_id != current_tab.zoomed_pane_id) return state;
            return .{
                .width = layout_extent,
                .height = layout_extent,
                .visible = true,
                .selected = state.selected,
                .host_active = state.host_active,
            };
        }
        const rect = self.findPaneRect(
            current_tab,
            current_tab.root_node,
            stream.pane_id,
            .{ .width = layout_extent, .height = layout_extent, .visible = true },
        ) orelse return state;
        return .{
            .x = rect.x,
            .y = rect.y,
            .width = rect.width,
            .height = rect.height,
            .visible = true,
            .selected = state.selected,
            .host_active = state.host_active,
        };
    }

    fn findPaneRect(
        self: *LiveViewer,
        tab: *const Tab,
        node_index: u16,
        pane_id: u64,
        rect: PaneLayout,
    ) ?PaneLayout {
        if (node_index >= tab.node_count) return null;
        const node = self.nodes.items[@as(usize, tab.node_start) + node_index];
        if (node.kind == .leaf)
            return if (node.pane_id == pane_id) rect else null;
        const first_extent: u32 = switch (node.axis) {
            .horizontal => @intCast(
                (@as(u64, rect.width) * node.ratio_permille) / 1000,
            ),
            .vertical => @intCast(
                (@as(u64, rect.height) * node.ratio_permille) / 1000,
            ),
        };
        var first = rect;
        var second = rect;
        switch (node.axis) {
            .horizontal => {
                first.width = first_extent;
                second.x += first_extent;
                second.width -= first_extent;
            },
            .vertical => {
                first.height = first_extent;
                second.y += first_extent;
                second.height -= first_extent;
            },
        }
        return self.findPaneRect(tab, node.first, pane_id, first) orelse
            self.findPaneRect(tab, node.second, pane_id, second);
    }

    pub fn streamDimensions(self: *LiveViewer, index: usize) struct { columns: u16, rows: u16 } {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return .{ .columns = 0, .rows = 0 };
        const grid = &self.streams.items[index].receiver.grid;
        return .{ .columns = grid.columns, .rows = grid.rows };
    }

    pub fn streamPackedCell(self: *LiveViewer, index: usize, column: usize, row: usize) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return ' ';
        return self.streams.items[index].receiver.grid.packedCell(column, row);
    }

    pub fn streamCellText(
        self: *LiveViewer,
        index: usize,
        column: usize,
        row: usize,
        output: []u8,
    ) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return 0;
        return self.streams.items[index].receiver.grid.cellText(column, row, output);
    }

    pub fn copyStreamSelection(
        self: *LiveViewer,
        index: usize,
        output: []u8,
        selection: ?Vt.SelectionRange,
    ) ?usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return null;
        return Vt.copySelectionFromGrid(
            &self.streams.items[index].receiver.grid,
            output,
            selection,
        );
    }

    pub fn streamColorRgb(self: *LiveViewer, index: usize, color_id: u16) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return 0;
        return self.streams.items[index].receiver.grid.colorRgb(color_id);
    }

    pub fn streamCursor(self: *LiveViewer, index: usize) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (index >= self.streams.items.len) return 0xffffffff;
        const grid = &self.streams.items[index].receiver.grid;
        if (!grid.cursor_visible) return 0xffffffff;
        return (@as(u32, grid.cursor_row) << 16) | grid.cursor_column;
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

    pub fn bracketedPaste(self: *LiveViewer) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stream = self.selectedStream() orelse return false;
        return stream.receiver.grid.bracketed_paste;
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
    fn releaseControlForSelectionChange(self: *LiveViewer, next_index: usize) !void {
        if (next_index == self.selected_index) return;
        const current = self.selectedStream() orelse return;
        if (current.receiver.permission.value != .control_requested and
            current.receiver.permission.value != .control_granted)
            return;
        try self.send(current, .control_release, "");
        current.receiver.permission.revoke();
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

    fn sendWorkspace(
        self: *LiveViewer,
        message_type: Protocol.MessageType,
        payload: []const u8,
        final: bool,
    ) !void {
        var connection = &(self.connection orelse return error.ShareViewerNotConnected);
        try connection.sendFrame(self.allocator, .{
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

    fn applyManifest(self: *LiveViewer, frame: Protocol.Frame, update: bool) !void {
        if (!self.hello_received or frame.header.stream_id != 0 or
            self.manifest_received == !update)
            return error.InvalidShareWorkspace;
        var decoder = try Session.ManifestDecoder.init(frame.payload);
        var tab_specs: [Protocol.max_tabs]Session.TabManifest = undefined;
        var tab_count: usize = 0;
        while (try decoder.nextTab()) |tab| {
            tab_specs[tab_count] = tab;
            tab_count += 1;
        }
        var pane_specs: [Protocol.max_streams]Session.PaneManifest = undefined;
        var pane_count: usize = 0;
        while (try decoder.nextPane()) |pane| {
            pane_specs[pane_count] = pane;
            pane_count += 1;
        }
        var node_specs: [Protocol.max_layout_nodes]Session.LayoutNodeManifest = undefined;
        var node_count: usize = 0;
        while (try decoder.nextNode()) |node| {
            node_specs[node_count] = node;
            node_count += 1;
        }
        if (tab_count != decoder.tabCount() or pane_count != decoder.paneCount() or
            node_count != decoder.nodeCount())
            return error.InvalidShareWorkspace;
        try Session.validateWorkspaceManifest(.{
            .scope = decoder.scope,
            .tabs = tab_specs[0..tab_count],
            .panes = pane_specs[0..pane_count],
            .nodes = node_specs[0..node_count],
        });

        const selected_pane_id = if (self.selectedStream()) |stream| stream.pane_id else 0;
        var new_tabs = std.array_list.Managed(Tab).init(self.allocator);
        errdefer {
            for (new_tabs.items) |tab| self.allocator.free(tab.title);
            new_tabs.deinit();
        }
        try new_tabs.ensureTotalCapacity(tab_count);
        var node_start: u16 = 0;
        for (tab_specs[0..tab_count]) |tab| {
            new_tabs.appendAssumeCapacity(.{
                .tab_id = tab.tab_id,
                .title = try self.allocator.dupe(u8, tab.title),
                .active = tab.active,
                .active_pane_id = tab.active_pane_id,
                .zoomed_pane_id = tab.zoomed_pane_id,
                .root_node = tab.root_node,
                .node_start = node_start,
                .node_count = tab.node_count,
            });
            node_start += tab.node_count;
        }
        var new_nodes = std.array_list.Managed(Session.LayoutNodeManifest).init(self.allocator);
        errdefer new_nodes.deinit();
        try new_nodes.appendSlice(node_specs[0..node_count]);

        var owned_titles: [Protocol.max_streams]?[]u8 =
            [_]?[]u8{null} ** Protocol.max_streams;
        errdefer for (owned_titles) |owned|
            if (owned) |owned_title| self.allocator.free(owned_title);
        var new_receivers: [Protocol.max_streams]?Mirror.Receiver =
            [_]?Mirror.Receiver{null} ** Protocol.max_streams;
        errdefer for (&new_receivers) |*receiver|
            if (receiver.*) |*value| value.deinit();
        for (pane_specs[0..pane_count], 0..) |pane, index| {
            owned_titles[index] = try self.allocator.dupe(u8, pane.title);
            var exists = false;
            for (self.streams.items) |stream| {
                if (stream.pane_id == pane.pane_id and
                    stream.receiver.stream_id == pane.stream_id)
                {
                    exists = true;
                    break;
                }
            }
            if (!exists)
                new_receivers[index] = try Mirror.Receiver.init(self.allocator, pane.stream_id);
        }

        var reordered = std.array_list.Managed(Stream).init(self.allocator);
        errdefer reordered.deinit();
        try reordered.ensureTotalCapacity(pane_count);
        for (pane_specs[0..pane_count], 0..) |pane, desired_index| {
            var existing_index: usize = 0;
            while (existing_index < self.streams.items.len and
                (self.streams.items[existing_index].pane_id != pane.pane_id or
                    self.streams.items[existing_index].receiver.stream_id != pane.stream_id)) : (existing_index += 1)
            {}
            if (existing_index < self.streams.items.len) {
                var stream = self.streams.orderedRemove(existing_index);
                self.allocator.free(stream.title);
                stream.title = owned_titles[desired_index].?;
                owned_titles[desired_index] = null;
                stream.tab_id = pane.tab_id;
                reordered.appendAssumeCapacity(stream);
            } else {
                reordered.appendAssumeCapacity(.{
                    .pane_id = pane.pane_id,
                    .tab_id = pane.tab_id,
                    .title = owned_titles[desired_index].?,
                    .receiver = new_receivers[desired_index].?,
                });
                owned_titles[desired_index] = null;
                new_receivers[desired_index] = null;
            }
        }
        for (self.streams.items) |*removed| {
            removed.receiver.deinit();
            self.allocator.free(removed.title);
        }
        self.streams.deinit();
        self.streams = reordered;

        var selected_index: usize = 0;
        var selected_found = false;
        for (self.streams.items, 0..) |stream, index| {
            if (stream.pane_id == selected_pane_id) {
                selected_index = index;
                selected_found = true;
                break;
            }
        }
        if (selected_found) {
            const selected_stream = self.streams.items[selected_index];
            for (new_tabs.items) |tab| {
                if (tab.tab_id != selected_stream.tab_id or
                    tab.zoomed_pane_id == 0 or
                    tab.zoomed_pane_id == selected_stream.pane_id)
                    continue;
                for (self.streams.items, 0..) |stream, index| {
                    if (stream.pane_id == tab.zoomed_pane_id) {
                        selected_index = index;
                        break;
                    }
                }
                break;
            }
        }
        if (!selected_found) {
            var active_pane_id: u64 = 0;
            for (new_tabs.items) |tab| {
                if (tab.active) {
                    active_pane_id = if (tab.zoomed_pane_id != 0)
                        tab.zoomed_pane_id
                    else
                        tab.active_pane_id;
                    break;
                }
            }
            for (self.streams.items, 0..) |stream, index| {
                if (stream.pane_id == active_pane_id) {
                    selected_index = index;
                    break;
                }
            }
        }

        for (self.tabs.items) |tab| self.allocator.free(tab.title);
        self.tabs.deinit();
        self.tabs = new_tabs;
        self.nodes.deinit();
        self.nodes = new_nodes;
        self.scope = decoder.scope;
        self.selected_index = selected_index;
        self.manifest_received = true;
        self.status = .connected;
        self.updateStatusFromSelected();
        self.bumpStreamRevision();
        self.bumpGeneration();
    }

    fn bumpStreamRevision(self: *LiveViewer) void {
        self.stream_revision +%= 1;
        if (self.stream_revision == 0) self.stream_revision = 1;
    }

    fn bumpGeneration(self: *LiveViewer) void {
        self.generation +%= 1;
        if (self.generation == 0) self.generation = 1;
    }

    fn updateStatusFromSelected(self: *LiveViewer) void {
        const stream = self.selectedStream() orelse {
            if (self.status != .failed and self.status != .stopped)
                self.status = if (self.manifest_received) .connected else .connecting;
            return;
        };
        self.status = switch (stream.receiver.permission.value) {
            .view_only => .connected,
            .control_requested => .control_requested,
            .control_granted => .control_granted,
        };
    }

    fn applyWorkspaceFrame(self: *LiveViewer, frame: Protocol.Frame) !bool {
        if (frame.header.stream_id != 0) return error.InvalidShareWorkspace;
        const final_expected = frame.header.message_type == .disconnect_reason;
        if (frame.header.flags.final != final_expected)
            return error.InvalidShareWorkspaceFlags;
        try self.workspace_receive_sequence.receive(frame.header.sequence);
        switch (frame.header.message_type) {
            .hello => {
                if (self.hello_received or self.manifest_received) return error.InvalidShareHello;
                _ = try Session.decodeHello(frame.payload);
                var hello_payload: [Session.hello_payload_length]u8 = undefined;
                try Session.encodeHello(&hello_payload, .{
                    .capabilities = Session.required_capabilities,
                    .max_stream_count = Protocol.max_streams,
                });
                try self.sendWorkspace(.hello, &hello_payload, false);
                self.hello_received = true;
            },
            .workspace_manifest => try self.applyManifest(frame, false),
            .workspace_update => try self.applyManifest(frame, true),
            .ping => {
                if (!self.manifest_received or frame.payload.len != 0)
                    return error.InvalidShareKeepalive;
                try self.sendWorkspace(.pong, "", false);
            },
            .disconnect_reason => {
                if (!frame.header.flags.final) return error.InvalidShareDisconnectReason;
                try Session.validateDisconnectReason(frame.payload);
                self.status = .stopped;
                return true;
            },
            else => return error.InvalidShareWorkspaceMessage,
        }
        return false;
    }

    fn applyStreamFrame(
        self: *LiveViewer,
        stream: *Stream,
        frame: Protocol.Frame,
    ) !void {
        stream.receiver.apply(frame) catch |err| switch (err) {
            error.MirrorResyncPending => return,
            error.InvalidShareSequence,
            error.MirrorSnapshotRequired,
            error.InvalidMirrorSnapshotState,
            error.DuplicateMirrorSnapshotRow,
            error.IncompleteMirrorSnapshot,
            => {
                stream.receiver.beginResync();
                self.bumpGeneration();
                self.updateStatusFromSelected();
                try self.send(stream, .resync, "");
                return;
            },
            else => return err,
        };
        self.bumpGeneration();
        self.updateStatusFromSelected();
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
            const should_stop = self.stop_requested;
            if (should_stop) {
                self.sendWorkspace(.disconnect_reason, "viewer stopped receiving", true) catch {};
                self.status = .stopped;
            }
            self.mutex.unlock();
            if (should_stop) break;
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
            if (frame.header.stream_id == 0) {
                const remote_stopped = self.applyWorkspaceFrame(frame) catch {
                    self.status = .failed;
                    self.mutex.unlock();
                    return self.finishConnection();
                };
                self.mutex.unlock();
                if (remote_stopped) return self.finishConnection();
                continue;
            }
            if (!self.manifest_received) {
                self.status = .failed;
                self.mutex.unlock();
                return self.finishConnection();
            }
            const stream = self.streamForId(frame.header.stream_id) orelse {
                self.status = .failed;
                self.mutex.unlock();
                return self.finishConnection();
            };
            self.applyStreamFrame(stream, frame) catch {
                self.status = .failed;
                self.mutex.unlock();
                return self.finishConnection();
            };
            self.mutex.unlock();
        }
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
    const host = try LiveHost.create(
        std.testing.allocator,
        random,
        host_identity,
        host_peer,
        null,
        "127.0.0.1",
        0,
        .session,
        &.{
            .{
                .tab_id = 7,
                .title = "Shells",
                .active = true,
                .active_pane_id = 41,
                .root_node = 0,
                .node_count = 1,
            },
            .{
                .tab_id = 8,
                .title = "Logs",
                .active_pane_id = 42,
                .root_node = 0,
                .node_count = 1,
            },
        },
        &.{
            .{ .pane_id = 41, .tab_id = 7, .title = "Shell" },
            .{ .pane_id = 42, .tab_id = 8, .title = "Logs" },
        },
        &.{
            .{ .tab_id = 7, .kind = .leaf, .pane_id = 41, .ratio_permille = 0 },
            .{ .tab_id = 8, .kind = .leaf, .pane_id = 42, .ratio_permille = 0 },
        },
    );
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
    var metrics = FakeSession{ .grid = try Vt.Grid.init(std.testing.allocator, 12, 2) };
    defer metrics.grid.deinit();
    try metrics.grid.feed("metrics pane");

    for (0..5000) |_| {
        if (host.currentStatus() == .connected and viewer.streamCount() == 2) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(usize, 2), viewer.streamCount());
    try std.testing.expectEqual(@as(usize, 2), viewer.tabCount());
    try std.testing.expectEqual(Session.ShareScope.session, viewer.shareScope());
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
    try std.testing.expectEqual(@as(u64, 8), info.tab_id);
    var tab_title: [16]u8 = undefined;
    const tab_info = viewer.tabInfo(1, &tab_title).?;
    try std.testing.expectEqual(@as(u64, 8), tab_info.tab_id);
    try std.testing.expectEqualStrings("Logs", tab_title[0..tab_info.title_length]);
    try viewer.selectTab(0);
    try std.testing.expectEqual(@as(usize, 0), viewer.selectedIndex());
    const initial_revision = viewer.streamRevision();
    try std.testing.expect(try host.syncWorkspace(
        .session,
        &.{
            .{
                .tab_id = 7,
                .title = "Shells",
                .active = true,
                .active_pane_id = 41,
                .root_node = 0,
                .node_count = 1,
            },
            .{
                .tab_id = 8,
                .title = "Logs",
                .active_pane_id = 42,
                .root_node = 0,
                .node_count = 3,
            },
        },
        &.{
            .{ .pane_id = 41, .tab_id = 7, .title = "Shell" },
            .{ .pane_id = 42, .tab_id = 8, .title = "Logs" },
            .{ .pane_id = 43, .tab_id = 8, .title = "Metrics" },
        },
        &.{
            .{ .tab_id = 7, .kind = .leaf, .pane_id = 41, .ratio_permille = 0 },
            .{ .tab_id = 8, .kind = .split, .first = 1, .second = 2, .ratio_permille = 400 },
            .{ .tab_id = 8, .kind = .leaf, .pane_id = 42, .ratio_permille = 0 },
            .{ .tab_id = 8, .kind = .leaf, .pane_id = 43, .ratio_permille = 0 },
        },
    ));
    try std.testing.expect(!host.needsCheckpoint(41));
    try std.testing.expect(!host.needsCheckpoint(42));
    try std.testing.expect(host.needsCheckpoint(43));
    try host.capture(43, &metrics);
    for (0..5000) |_| {
        if (viewer.streamCount() == 3) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(usize, 3), viewer.streamCount());
    try std.testing.expectEqual(
        @as(u21, 'l'),
        viewer.streamPackedCell(1, 0, 0) & 0x1fffff,
    );
    try viewer.selectStream(1);
    const logs_layout = viewer.paneLayout(1).?;
    const metrics_layout = viewer.paneLayout(2).?;
    try std.testing.expect(logs_layout.visible);
    try std.testing.expectEqual(@as(u32, 400_000), logs_layout.width);
    try std.testing.expect(metrics_layout.visible);
    try std.testing.expectEqual(@as(u32, 400_000), metrics_layout.x);
    try std.testing.expectEqual(@as(u32, 600_000), metrics_layout.width);
    try std.testing.expect(viewer.streamRevision() != initial_revision);
    try std.testing.expect(try host.syncWorkspace(
        .session,
        &.{
            .{
                .tab_id = 7,
                .title = "Shells",
                .active = true,
                .active_pane_id = 41,
                .root_node = 0,
                .node_count = 1,
            },
            .{
                .tab_id = 8,
                .title = "Logs",
                .active_pane_id = 43,
                .zoomed_pane_id = 43,
                .root_node = 0,
                .node_count = 3,
            },
        },
        &.{
            .{ .pane_id = 41, .tab_id = 7, .title = "Shell" },
            .{ .pane_id = 42, .tab_id = 8, .title = "Logs" },
            .{ .pane_id = 43, .tab_id = 8, .title = "Metrics" },
        },
        &.{
            .{ .tab_id = 7, .kind = .leaf, .pane_id = 41, .ratio_permille = 0 },
            .{ .tab_id = 8, .kind = .split, .first = 1, .second = 2, .ratio_permille = 400 },
            .{ .tab_id = 8, .kind = .leaf, .pane_id = 42, .ratio_permille = 0 },
            .{ .tab_id = 8, .kind = .leaf, .pane_id = 43, .ratio_permille = 0 },
        },
    ));
    for (0..5000) |_| {
        if (viewer.selectedIndex() == 2 and viewer.paneLayout(2).?.width == 1_000_000)
            break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(usize, 2), viewer.selectedIndex());
    try std.testing.expect(!viewer.paneLayout(1).?.visible);
    const zoomed_layout = viewer.paneLayout(2).?;
    try std.testing.expect(zoomed_layout.visible);
    try std.testing.expect(zoomed_layout.selected);
    try std.testing.expect(zoomed_layout.host_active);
    try std.testing.expectEqual(@as(u32, 1_000_000), zoomed_layout.width);
    try std.testing.expectEqual(@as(u32, 1_000_000), zoomed_layout.height);
    try std.testing.expectError(error.SharePaneHiddenByZoom, viewer.selectStream(1));
    try std.testing.expect(!host.needsCheckpoint(41));
    try std.testing.expect(!host.needsCheckpoint(42));
    try std.testing.expect(!host.needsCheckpoint(43));
    try viewer.selectStream(2);
    for (0..5000) |_| {
        if ((viewer.packedCell(0, 0) & 0x1fffff) == 'm') break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(u21, 'm'), viewer.packedCell(0, 0) & 0x1fffff);
    try std.testing.expect(try host.syncWorkspace(
        .session,
        &.{
            .{
                .tab_id = 8,
                .title = "Observability",
                .active = true,
                .active_pane_id = 42,
                .root_node = 0,
                .node_count = 1,
            },
            .{
                .tab_id = 7,
                .title = "Shells",
                .active_pane_id = 41,
                .root_node = 0,
                .node_count = 1,
            },
        },
        &.{
            .{ .pane_id = 42, .tab_id = 8, .title = "Logs" },
            .{ .pane_id = 41, .tab_id = 7, .title = "Shell" },
        },
        &.{
            .{ .tab_id = 8, .kind = .leaf, .pane_id = 42, .ratio_permille = 0 },
            .{ .tab_id = 7, .kind = .leaf, .pane_id = 41, .ratio_permille = 0 },
        },
    ));
    for (0..5000) |_| {
        if (viewer.streamCount() == 2) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(usize, 2), viewer.streamCount());
    const first_reordered_tab = viewer.tabInfo(0, &tab_title).?;
    try std.testing.expectEqual(@as(u64, 8), first_reordered_tab.tab_id);
    try std.testing.expect(first_reordered_tab.active);
    try std.testing.expectEqualStrings(
        "Observability",
        tab_title[0..first_reordered_tab.title_length],
    );
    const second_reordered_tab = viewer.tabInfo(1, &tab_title).?;
    try std.testing.expectEqual(@as(u64, 7), second_reordered_tab.tab_id);
    try std.testing.expect(!second_reordered_tab.active);
    try std.testing.expectEqualStrings(
        "Shells",
        tab_title[0..second_reordered_tab.title_length],
    );
    try std.testing.expectEqual(
        @as(u64, 42),
        viewer.streamInfo(0, &.{}).?.pane_id,
    );
    try std.testing.expectEqual(
        @as(u64, 41),
        viewer.streamInfo(1, &.{}).?.pane_id,
    );
    try viewer.selectTab(1);
    try std.testing.expectEqual(@as(usize, 1), viewer.selectedIndex());
    try std.testing.expect(!host.needsCheckpoint(41));
    try std.testing.expect(!host.needsCheckpoint(42));

    viewer.mutex.lock();
    viewer.streams.items[1].receiver.sequence.next_receive += 1;
    viewer.mutex.unlock();
    try shell.grid.feed("\rresynced");
    try host.capture(41, &shell);
    for (0..5000) |_| {
        if (host.needsCheckpoint(41)) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expect(host.needsCheckpoint(41));
    try host.capture(41, &shell);
    try viewer.selectStream(1);
    for (0..5000) |_| {
        if ((viewer.packedCell(0, 0) & 0x1fffff) == 'r') break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(@as(u21, 'r'), viewer.packedCell(0, 0) & 0x1fffff);
    try viewer.selectStream(0);
    try std.testing.expectError(error.ShareInputNotGranted, viewer.sendInput("id\n"));
    try viewer.requestControl();
    const requested_pane_id = (viewer.streamInfo(viewer.selectedIndex(), &.{}) orelse
        return error.InvalidSharePaneClose).pane_id;
    for (0..5000) |_| {
        if (host.currentStatus() == .control_requested) break;
        Transport.sleepMilliseconds(random, 1);
    }
    const original_request = host.controlRequest().?;
    try std.testing.expect(host.respondControl(original_request, true));
    for (0..5000) |_| {
        if (viewer.currentStatus() == .control_granted) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try viewer.selectStream(1);
    for (0..5000) |_| {
        if (viewer.currentStatus() == .connected and
            host.currentStatus() == .connected) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectError(error.ShareInputNotGranted, viewer.sendInput("id\n"));
    try viewer.requestControl();
    const transferred_pane_id = (viewer.streamInfo(viewer.selectedIndex(), &.{}) orelse
        return error.InvalidSharePaneClose).pane_id;
    try std.testing.expect(transferred_pane_id != requested_pane_id);
    for (0..5000) |_| {
        if (host.currentStatus() == .control_requested) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expect(!host.respondControl(original_request, true));
    try std.testing.expect(host.respondControl(host.controlRequest().?, true));
    for (0..5000) |_| {
        if (viewer.currentStatus() == .control_granted) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try viewer.sendInput("id\n");
    for (0..5000) |_| {
        const count = if (transferred_pane_id == 41)
            try host.drainInput(41, &shell)
        else if (transferred_pane_id == 42)
            try host.drainInput(42, &logs)
        else
            0;
        if (count != 0) break;
        Transport.sleepMilliseconds(random, 1);
    }
    const controlled = if (transferred_pane_id == 41) &shell else &logs;
    const passive = if (transferred_pane_id == 41) &logs else &shell;
    try std.testing.expectEqualStrings("id\n", controlled.written[0..controlled.written_length]);
    try std.testing.expectEqual(@as(usize, 0), passive.written_length);
    host.revokeControl();
    for (0..5000) |_| {
        if (viewer.currentStatus() == .connected) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectError(error.ShareInputNotGranted, viewer.sendInput("whoami\n"));
    try viewer.requestControl();
    for (0..5000) |_| {
        if (host.currentStatus() == .control_requested) break;
        Transport.sleepMilliseconds(random, 1);
    }
    const disconnected_request = host.controlRequest().?;
    viewer.mutex.lock();
    viewer.stop_requested = true;
    viewer.mutex.unlock();
    for (0..5000) |_| {
        if (viewer.currentStatus() == .stopped and
            host.currentStatus() == .listening) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(Status.stopped, viewer.currentStatus());
    try std.testing.expectEqual(
        @import("LiveHost.zig").Status.listening,
        host.currentStatus(),
    );
    try viewer.reconnect();
    for (0..5000) |_| {
        if (viewer.currentStatus() == .connected and
            host.currentStatus() == .connected) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expectEqual(Status.connected, viewer.currentStatus());
    try std.testing.expectEqual(
        @import("LiveHost.zig").Status.connected,
        host.currentStatus(),
    );
    try std.testing.expectEqual(@as(usize, 2), viewer.streamCount());
    try std.testing.expectError(
        error.ShareInputNotGranted,
        viewer.sendInput("control must not survive reconnect\n"),
    );
    try viewer.requestControl();
    for (0..5000) |_| {
        if (host.currentStatus() == .control_requested) break;
        Transport.sleepMilliseconds(random, 1);
    }
    try std.testing.expect(!host.respondControl(disconnected_request, true));
    try std.testing.expect(host.respondControl(host.controlRequest().?, false));
}
