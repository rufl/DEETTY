const std = @import("std");
const Protocol = @import("Protocol.zig");
const Presentation = @import("Presentation.zig");
const Transport = @import("Transport.zig");

pub const HostPeer = struct {
    stream_id: u32,
    publisher: Presentation.Publisher,
    receive_sequence: Protocol.Sequence = .{},
    permission: Protocol.PermissionState = .{},
    changed_rows: [Protocol.max_rows]bool = [_]bool{false} ** Protocol.max_rows,
    checkpoint_required: bool = true,
    stopped: bool = false,

    pub fn init(stream_id: u32) !HostPeer {
        return .{ .stream_id = stream_id, .publisher = try Presentation.Publisher.init(stream_id) };
    }

    pub fn prepareResync(self: *HostPeer) void {
        self.publisher.prepareResync();
        self.checkpoint_required = true;
        self.permission.value = .view_only;
        @memset(&self.changed_rows, false);
    }
    pub fn prepareReconnect(self: *HostPeer) void {
        const stream_id = self.stream_id;
        self.* = .{
            .stream_id = stream_id,
            .publisher = Presentation.Publisher.init(stream_id) catch
                unreachable,
        };
    }

    // UI-thread observation only records bounded damage. Encoding and socket
    // writes happen later on the network worker via flush().
    pub fn observe(self: *HostPeer, session: anytype) void {
        if (self.stopped or self.checkpoint_required) return;
        var rows: [Protocol.max_rows]u8 = undefined;
        const damage = self.publisher.changedRows(&session.grid, rows[0..session.grid.rows]);
        _ = damage;
        var changed_count: usize = 0;
        for (rows[0..session.grid.rows], 0..) |changed, row| {
            if (changed != 0) self.changed_rows[row] = true;
            if (self.changed_rows[row]) changed_count += 1;
        }
        const estimated = changed_count * @as(usize, session.grid.columns) * Presentation.cell_header_length;
        if (estimated > Protocol.max_pending_peer_bytes) {
            @memset(&self.changed_rows, false);
            self.checkpoint_required = true;
        }
    }

    pub fn flush(self: *HostPeer, allocator: std.mem.Allocator, session: anytype, connection: *Transport.SecureConnection) !void {
        if (self.stopped) return error.ShareStopped;
        if (self.checkpoint_required) {
            try self.sendCheckpoint(allocator, session, connection);
            self.checkpoint_required = false;
            @memset(&self.changed_rows, false);
            self.publisher.checkpointComplete(&session.grid);
            return;
        }
        switch (self.publisher.historyDelta(&session.grid)) {
            .unchanged => {},
            .reset => {
                try self.sendCheckpoint(allocator, session, connection);
                @memset(&self.changed_rows, false);
                self.publisher.checkpointComplete(&session.grid);
                return;
            },
            .append_from => |first| {
                for (first..session.grid.historyCount()) |row| {
                    const owned = try self.publisher.historyRowFrameAlloc(
                        allocator,
                        &session.grid,
                        row,
                        0,
                        .history_push,
                    );
                    defer owned.deinit(allocator);
                    try connection.sendFrame(allocator, owned.frame);
                }
                self.publisher.historyComplete(&session.grid);
            },
        }
        for (self.changed_rows[0..session.grid.rows], 0..) |*changed, row| {
            if (!changed.*) continue;
            const owned = try self.publisher.rowFrameAlloc(allocator, &session.grid, row, .damage);
            defer owned.deinit(allocator);
            try connection.sendFrame(allocator, owned.frame);
            changed.* = false;
        }
        if (try self.publisher.cursorFrame(&session.grid)) |cursor_value| {
            var cursor = cursor_value;
            cursor.frame.payload = &cursor.payload;
            try connection.sendFrame(allocator, cursor.frame);
        }
        if (try self.publisher.titleFrame(&session.grid, false)) |title|
            try connection.sendFrame(allocator, title);
    }

    fn sendCheckpoint(self: *HostPeer, allocator: std.mem.Allocator, session: anytype, connection: *Transport.SecureConnection) !void {
        const history_count = @min(
            session.grid.historyCount(),
            @as(usize, Protocol.max_scrollback_rows),
        );
        var begin = try self.publisher.snapshotBegin(
            &session.grid,
            @intCast(history_count),
        );
        begin.frame.payload = &begin.payload;
        try connection.sendFrame(allocator, begin.frame);
        const first_history = session.grid.historyCount() - history_count;
        for (
            first_history..session.grid.historyCount(),
            0..,
        ) |source_row, wire_row| {
            const owned = try self.publisher.historyRowFrameAlloc(
                allocator,
                &session.grid,
                source_row,
                wire_row,
                .history_row,
            );
            defer owned.deinit(allocator);
            try connection.sendFrame(allocator, owned.frame);
        }
        for (0..session.grid.rows) |row| {
            const owned = try self.publisher.rowFrameAlloc(
                allocator,
                &session.grid,
                row,
                .row_chunk,
            );
            defer owned.deinit(allocator);
            try connection.sendFrame(allocator, owned.frame);
        }
        try connection.sendFrame(allocator, try self.publisher.snapshotEnd());
        if (try self.publisher.titleFrame(&session.grid, true)) |title|
            try connection.sendFrame(allocator, title);
    }

    pub fn receiveControl(self: *HostPeer, frame: Protocol.Frame) !?[]const u8 {
        if (self.stopped or frame.header.stream_id != self.stream_id)
            return error.InvalidShareStream;
        try self.receive_sequence.receive(frame.header.sequence);
        switch (frame.header.message_type) {
            .control_request => {
                if (frame.payload.len != 0) return error.InvalidShareControl;
                try self.permission.requestControl();
                return null;
            },
            .input => {
                if (!self.permission.permitsInput()) return error.ShareInputNotGranted;
                if (frame.payload.len == 0 or frame.payload.len > Protocol.max_input_bytes)
                    return error.ShareInputTooLarge;
                return frame.payload;
            },
            .resync => {
                if (frame.payload.len != 0) return error.InvalidShareControl;
                return null;
            },
            .control_release => {
                if (frame.payload.len != 0) return error.InvalidShareControl;
                self.permission.revoke();
                return null;
            },
            else => return error.InvalidShareControl,
        }
    }

    pub fn grantControl(self: *HostPeer, allocator: std.mem.Allocator, connection: *Transport.SecureConnection) !void {
        try self.permission.grantControl();
        try connection.sendFrame(allocator, .{
            .header = .{
                .message_type = .control_grant,
                .stream_id = self.stream_id,
                .sequence = try self.publisher.sequence.sending(),
                .payload_length = 0,
            },
            .payload = "",
        });
    }

    pub fn denyControl(self: *HostPeer) !void {
        try self.permission.denyControl();
    }

    pub fn revokeControl(self: *HostPeer, allocator: std.mem.Allocator, connection: *Transport.SecureConnection) !void {
        self.permission.revoke();
        try connection.sendFrame(allocator, .{
            .header = .{
                .message_type = .control_revoke,
                .stream_id = self.stream_id,
                .sequence = try self.publisher.sequence.sending(),
                .payload_length = 0,
            },
            .payload = "",
        });
    }

    pub fn stop(self: *HostPeer) void {
        self.permission.revoke();
        self.stopped = true;
        @memset(&self.changed_rows, false);
    }
};

pub const capability_workspace_multiplex: u32 = 1 << 0;
pub const capability_dynamic_panes: u32 = 1 << 1;
pub const capability_resync: u32 = 1 << 2;
pub const capability_keepalive: u32 = 1 << 3;
pub const capability_per_pane_control: u32 = 1 << 4;
pub const capability_tab_hierarchy: u32 = 1 << 5;
pub const capability_share_scopes: u32 = 1 << 6;
pub const capability_split_layout: u32 = 1 << 7;
pub const required_capabilities: u32 =
    capability_workspace_multiplex |
    capability_dynamic_panes |
    capability_resync |
    capability_keepalive |
    capability_per_pane_control |
    capability_tab_hierarchy |
    capability_share_scopes |
    capability_split_layout;
pub const hello_payload_length: usize = 8;
pub const pane_close_payload_length: usize = 12;
pub const max_disconnect_reason_bytes: usize = 256;
const manifest_header_length: usize = 8;
const tab_manifest_fixed_length: usize = 31;
const pane_manifest_fixed_length: usize = 22;
const layout_manifest_fixed_length: usize = 24;

pub const ShareScope = enum(u8) {
    pane = 1,
    tab = 2,
    session = 3,
};

pub const Hello = struct {
    capabilities: u32,
    max_stream_count: u16,

    pub fn validate(self: Hello) !void {
        if (self.capabilities != required_capabilities or
            self.max_stream_count != Protocol.max_streams)
            return error.UnsupportedShareCapabilities;
    }
};

pub fn encodeHello(output: *[hello_payload_length]u8, hello: Hello) !void {
    try hello.validate();
    std.mem.writeInt(u32, output[0..4], hello.capabilities, .big);
    std.mem.writeInt(u16, output[4..6], hello.max_stream_count, .big);
    @memset(output[6..8], 0);
}

pub fn decodeHello(payload: []const u8) !Hello {
    if (payload.len != hello_payload_length or payload[6] != 0 or payload[7] != 0)
        return error.InvalidShareHello;
    const hello = Hello{
        .capabilities = std.mem.readInt(u32, payload[0..4], .big),
        .max_stream_count = std.mem.readInt(u16, payload[4..6], .big),
    };
    try hello.validate();
    return hello;
}

pub const PaneClose = struct {
    stream_id: u32,
    pane_id: u64,
};

pub fn encodePaneClose(output: *[pane_close_payload_length]u8, closed: PaneClose) !void {
    if (closed.stream_id == 0 or closed.pane_id == 0) return error.InvalidSharePaneClose;
    std.mem.writeInt(u32, output[0..4], closed.stream_id, .big);
    std.mem.writeInt(u64, output[4..12], closed.pane_id, .big);
}

pub fn decodePaneClose(payload: []const u8) !PaneClose {
    if (payload.len != pane_close_payload_length) return error.InvalidSharePaneClose;
    const closed = PaneClose{
        .stream_id = std.mem.readInt(u32, payload[0..4], .big),
        .pane_id = std.mem.readInt(u64, payload[4..12], .big),
    };
    if (closed.stream_id == 0 or closed.pane_id == 0) return error.InvalidSharePaneClose;
    return closed;
}

pub fn validateDisconnectReason(payload: []const u8) !void {
    if (payload.len == 0 or payload.len > max_disconnect_reason_bytes or
        !std.unicode.utf8ValidateSlice(payload))
        return error.InvalidShareDisconnectReason;
}

pub const LayoutKind = enum(u8) {
    leaf = 0,
    split = 1,
};

pub const LayoutAxis = enum(u8) {
    horizontal = 0,
    vertical = 1,
};

pub const LayoutNodeManifest = struct {
    tab_id: u64,
    kind: LayoutKind,
    pane_id: u64 = 0,
    axis: LayoutAxis = .horizontal,
    first: u16 = 0,
    second: u16 = 0,
    ratio_permille: u16 = 500,
};

pub const TabManifest = struct {
    tab_id: u64,
    title: []const u8,
    active: bool = false,
    active_pane_id: u64,
    zoomed_pane_id: u64 = 0,
    root_node: u16,
    node_count: u16,
};

pub const PaneManifest = struct {
    stream_id: u32,
    pane_id: u64,
    tab_id: u64,
    title: []const u8,
};

pub const WorkspaceManifest = struct {
    scope: ShareScope,
    tabs: []const TabManifest,
    panes: []const PaneManifest,
    nodes: []const LayoutNodeManifest,
};

pub fn validateWorkspaceManifest(manifest: WorkspaceManifest) !void {
    if (manifest.tabs.len == 0 or manifest.tabs.len > Protocol.max_tabs or
        manifest.panes.len == 0 or manifest.panes.len > Protocol.max_streams or
        manifest.nodes.len == 0 or manifest.nodes.len > Protocol.max_layout_nodes)
        return error.InvalidShareWorkspace;
    if ((manifest.scope == .pane and
        (manifest.tabs.len != 1 or manifest.panes.len != 1)) or
        (manifest.scope == .tab and manifest.tabs.len != 1))
        return error.InvalidShareWorkspace;

    var active_tabs: usize = 0;
    var node_offset: usize = 0;
    for (manifest.tabs, 0..) |tab, tab_index| {
        if (tab.tab_id == 0 or tab.active_pane_id == 0 or
            tab.title.len > Protocol.max_title_bytes or
            !std.unicode.utf8ValidateSlice(tab.title))
            return error.InvalidShareWorkspace;
        for (manifest.tabs[0..tab_index]) |previous|
            if (previous.tab_id == tab.tab_id) return error.InvalidShareWorkspace;
        active_tabs += @intFromBool(tab.active);

        var tab_pane_count: usize = 0;
        var active_found = false;
        var zoomed_found = tab.zoomed_pane_id == 0;
        for (manifest.panes, 0..) |pane, pane_index| {
            if (pane.stream_id == 0 or pane.pane_id == 0 or pane.tab_id == 0 or
                pane.title.len > Protocol.max_title_bytes or
                !std.unicode.utf8ValidateSlice(pane.title))
                return error.InvalidShareWorkspace;
            for (manifest.panes[0..pane_index]) |previous| {
                if (previous.stream_id == pane.stream_id or
                    previous.pane_id == pane.pane_id)
                    return error.InvalidShareWorkspace;
            }
            var pane_tab_found = false;
            for (manifest.tabs) |candidate| {
                if (candidate.tab_id == pane.tab_id) {
                    pane_tab_found = true;
                    break;
                }
            }
            if (!pane_tab_found) return error.InvalidShareWorkspace;
            if (pane.tab_id != tab.tab_id) continue;
            tab_pane_count += 1;
            active_found = active_found or pane.pane_id == tab.active_pane_id;
            zoomed_found = zoomed_found or pane.pane_id == tab.zoomed_pane_id;
        }
        if (tab_pane_count == 0 or !active_found or !zoomed_found or
            tab.node_count != 2 * tab_pane_count - 1 or
            tab.root_node >= tab.node_count or
            node_offset + tab.node_count > manifest.nodes.len)
            return error.InvalidShareWorkspace;

        const nodes = manifest.nodes[node_offset .. node_offset + tab.node_count];
        var visited = [_]bool{false} ** Protocol.max_layout_nodes;
        var stack: [Protocol.max_layout_nodes]u16 = undefined;
        var stack_len: usize = 1;
        stack[0] = tab.root_node;
        var leaf_count: usize = 0;
        while (stack_len != 0) {
            stack_len -= 1;
            const index = stack[stack_len];
            if (index >= nodes.len or visited[index])
                return error.InvalidShareWorkspace;
            visited[index] = true;
            const node = nodes[index];
            if (node.tab_id != tab.tab_id) return error.InvalidShareWorkspace;
            switch (node.kind) {
                .leaf => {
                    if (node.pane_id == 0 or node.first != 0 or node.second != 0 or
                        node.ratio_permille != 0)
                        return error.InvalidShareWorkspace;
                    var pane_found = false;
                    for (manifest.panes) |pane| {
                        if (pane.tab_id == tab.tab_id and pane.pane_id == node.pane_id) {
                            pane_found = true;
                            break;
                        }
                    }
                    if (!pane_found) return error.InvalidShareWorkspace;
                    for (nodes[0..index]) |previous|
                        if (previous.kind == .leaf and previous.pane_id == node.pane_id)
                            return error.InvalidShareWorkspace;
                    leaf_count += 1;
                },
                .split => {
                    if (node.pane_id != 0 or node.first >= nodes.len or
                        node.second >= nodes.len or node.first == node.second or
                        node.ratio_permille == 0 or node.ratio_permille >= 1000)
                        return error.InvalidShareWorkspace;
                    if (stack_len > stack.len - 2)
                        return error.InvalidShareWorkspace;
                    stack[stack_len] = node.first;
                    stack_len += 1;
                    stack[stack_len] = node.second;
                    stack_len += 1;
                },
            }
        }
        if (leaf_count != tab_pane_count) return error.InvalidShareWorkspace;
        for (visited[0..nodes.len]) |seen|
            if (!seen) return error.InvalidShareWorkspace;
        node_offset += tab.node_count;
    }
    if (active_tabs != 1 or node_offset != manifest.nodes.len)
        return error.InvalidShareWorkspace;
}

pub fn encodeWorkspaceManifestAlloc(
    allocator: std.mem.Allocator,
    manifest: WorkspaceManifest,
) ![]u8 {
    try validateWorkspaceManifest(manifest);
    var bytes = std.array_list.Managed(u8).init(allocator);
    errdefer bytes.deinit();
    var header: [manifest_header_length]u8 = undefined;
    header[0] = @intFromEnum(manifest.scope);
    header[1] = 0;
    std.mem.writeInt(u16, header[2..4], @intCast(manifest.tabs.len), .big);
    std.mem.writeInt(u16, header[4..6], @intCast(manifest.panes.len), .big);
    std.mem.writeInt(u16, header[6..8], @intCast(manifest.nodes.len), .big);
    try bytes.appendSlice(&header);

    for (manifest.tabs) |tab| {
        var fixed: [tab_manifest_fixed_length]u8 = undefined;
        std.mem.writeInt(u64, fixed[0..8], tab.tab_id, .big);
        fixed[8] = @intFromBool(tab.active);
        std.mem.writeInt(u16, fixed[9..11], @intCast(tab.title.len), .big);
        std.mem.writeInt(u64, fixed[11..19], tab.active_pane_id, .big);
        std.mem.writeInt(u64, fixed[19..27], tab.zoomed_pane_id, .big);
        std.mem.writeInt(u16, fixed[27..29], tab.root_node, .big);
        std.mem.writeInt(u16, fixed[29..31], tab.node_count, .big);
        try bytes.appendSlice(&fixed);
        try bytes.appendSlice(tab.title);
    }
    for (manifest.panes) |pane| {
        var fixed: [pane_manifest_fixed_length]u8 = undefined;
        std.mem.writeInt(u32, fixed[0..4], pane.stream_id, .big);
        std.mem.writeInt(u64, fixed[4..12], pane.pane_id, .big);
        std.mem.writeInt(u64, fixed[12..20], pane.tab_id, .big);
        std.mem.writeInt(u16, fixed[20..22], @intCast(pane.title.len), .big);
        try bytes.appendSlice(&fixed);
        try bytes.appendSlice(pane.title);
    }
    for (manifest.nodes) |node| {
        var fixed: [layout_manifest_fixed_length]u8 = undefined;
        std.mem.writeInt(u64, fixed[0..8], node.tab_id, .big);
        fixed[8] = @intFromEnum(node.kind);
        fixed[9] = @intFromEnum(node.axis);
        std.mem.writeInt(u16, fixed[10..12], node.ratio_permille, .big);
        std.mem.writeInt(u64, fixed[12..20], node.pane_id, .big);
        std.mem.writeInt(u16, fixed[20..22], node.first, .big);
        std.mem.writeInt(u16, fixed[22..24], node.second, .big);
        try bytes.appendSlice(&fixed);
        if (bytes.items.len > Protocol.max_payload_bytes)
            return error.InvalidShareWorkspace;
    }
    return bytes.toOwnedSlice();
}

pub const ManifestDecoder = struct {
    bytes: []const u8,
    scope: ShareScope,
    offset: usize = manifest_header_length,
    remaining_tabs: u16,
    remaining_panes: u16,
    remaining_nodes: u16,
    initial_tab_count: u16,
    initial_pane_count: u16,
    initial_node_count: u16,

    pub fn init(bytes: []const u8) !ManifestDecoder {
        if (bytes.len < manifest_header_length or
            bytes.len > Protocol.max_payload_bytes or bytes[1] != 0)
            return error.InvalidShareWorkspace;
        const scope: ShareScope = switch (bytes[0]) {
            1 => .pane,
            2 => .tab,
            3 => .session,
            else => return error.InvalidShareWorkspace,
        };
        const tab_count = std.mem.readInt(u16, bytes[2..4], .big);
        const pane_count = std.mem.readInt(u16, bytes[4..6], .big);
        const node_count = std.mem.readInt(u16, bytes[6..8], .big);
        if (tab_count == 0 or tab_count > Protocol.max_tabs or
            pane_count == 0 or pane_count > Protocol.max_streams or
            node_count == 0 or node_count > Protocol.max_layout_nodes or
            (scope == .pane and (tab_count != 1 or pane_count != 1)) or
            (scope == .tab and tab_count != 1))
            return error.InvalidShareWorkspace;
        return .{
            .bytes = bytes,
            .scope = scope,
            .remaining_tabs = tab_count,
            .remaining_panes = pane_count,
            .remaining_nodes = node_count,
            .initial_tab_count = tab_count,
            .initial_pane_count = pane_count,
            .initial_node_count = node_count,
        };
    }

    pub fn tabCount(self: ManifestDecoder) usize {
        return self.initial_tab_count;
    }

    pub fn paneCount(self: ManifestDecoder) usize {
        return self.initial_pane_count;
    }

    pub fn nodeCount(self: ManifestDecoder) usize {
        return self.initial_node_count;
    }

    pub fn nextTab(self: *ManifestDecoder) !?TabManifest {
        if (self.remaining_tabs == 0) return null;
        if (self.bytes.len - self.offset < tab_manifest_fixed_length)
            return error.InvalidShareWorkspace;
        const fixed = self.bytes[self.offset .. self.offset + tab_manifest_fixed_length];
        const title_length: usize = std.mem.readInt(u16, fixed[9..11], .big);
        self.offset += tab_manifest_fixed_length;
        if (title_length > Protocol.max_title_bytes or
            title_length > self.bytes.len - self.offset)
            return error.InvalidShareWorkspace;
        const title = self.bytes[self.offset .. self.offset + title_length];
        if (!std.unicode.utf8ValidateSlice(title)) return error.InvalidShareWorkspace;
        self.offset += title_length;
        self.remaining_tabs -= 1;
        return .{
            .tab_id = std.mem.readInt(u64, fixed[0..8], .big),
            .title = title,
            .active = fixed[8] == 1,
            .active_pane_id = std.mem.readInt(u64, fixed[11..19], .big),
            .zoomed_pane_id = std.mem.readInt(u64, fixed[19..27], .big),
            .root_node = std.mem.readInt(u16, fixed[27..29], .big),
            .node_count = std.mem.readInt(u16, fixed[29..31], .big),
        };
    }

    pub fn nextPane(self: *ManifestDecoder) !?PaneManifest {
        if (self.remaining_tabs != 0) return error.InvalidShareWorkspace;
        if (self.remaining_panes == 0) return null;
        if (self.bytes.len - self.offset < pane_manifest_fixed_length)
            return error.InvalidShareWorkspace;
        const fixed = self.bytes[self.offset .. self.offset + pane_manifest_fixed_length];
        const title_length: usize = std.mem.readInt(u16, fixed[20..22], .big);
        self.offset += pane_manifest_fixed_length;
        if (title_length > Protocol.max_title_bytes or
            title_length > self.bytes.len - self.offset)
            return error.InvalidShareWorkspace;
        const title = self.bytes[self.offset .. self.offset + title_length];
        if (!std.unicode.utf8ValidateSlice(title)) return error.InvalidShareWorkspace;
        self.offset += title_length;
        self.remaining_panes -= 1;
        return .{
            .stream_id = std.mem.readInt(u32, fixed[0..4], .big),
            .pane_id = std.mem.readInt(u64, fixed[4..12], .big),
            .tab_id = std.mem.readInt(u64, fixed[12..20], .big),
            .title = title,
        };
    }

    pub fn nextNode(self: *ManifestDecoder) !?LayoutNodeManifest {
        if (self.remaining_tabs != 0 or self.remaining_panes != 0)
            return error.InvalidShareWorkspace;
        if (self.remaining_nodes == 0) {
            if (self.offset != self.bytes.len) return error.InvalidShareWorkspace;
            return null;
        }
        if (self.bytes.len - self.offset < layout_manifest_fixed_length)
            return error.InvalidShareWorkspace;
        const fixed = self.bytes[self.offset .. self.offset + layout_manifest_fixed_length];
        self.offset += layout_manifest_fixed_length;
        self.remaining_nodes -= 1;
        const kind: LayoutKind = switch (fixed[8]) {
            0 => .leaf,
            1 => .split,
            else => return error.InvalidShareWorkspace,
        };
        const axis: LayoutAxis = switch (fixed[9]) {
            0 => .horizontal,
            1 => .vertical,
            else => return error.InvalidShareWorkspace,
        };
        return .{
            .tab_id = std.mem.readInt(u64, fixed[0..8], .big),
            .kind = kind,
            .axis = axis,
            .ratio_permille = std.mem.readInt(u16, fixed[10..12], .big),
            .pane_id = std.mem.readInt(u64, fixed[12..20], .big),
            .first = std.mem.readInt(u16, fixed[20..22], .big),
            .second = std.mem.readInt(u16, fixed[22..24], .big),
        };
    }
};

test "session metadata codecs reject unsupported capabilities and malformed pane closes" {
    var hello_bytes: [hello_payload_length]u8 = undefined;
    try encodeHello(&hello_bytes, .{
        .capabilities = required_capabilities,
        .max_stream_count = Protocol.max_streams,
    });
    const hello = try decodeHello(&hello_bytes);
    try std.testing.expectEqual(required_capabilities, hello.capabilities);
    var unsupported = hello_bytes;
    unsupported[2] |= 0x01;
    try std.testing.expectError(error.UnsupportedShareCapabilities, decodeHello(&unsupported));

    var wrong_limit = hello_bytes;
    std.mem.writeInt(u16, wrong_limit[4..6], Protocol.max_streams - 1, .big);
    try std.testing.expectError(error.UnsupportedShareCapabilities, decodeHello(&wrong_limit));
    var close_bytes: [pane_close_payload_length]u8 = undefined;
    try encodePaneClose(&close_bytes, .{ .stream_id = 2, .pane_id = 42 });
    const closed = try decodePaneClose(&close_bytes);
    try std.testing.expectEqual(@as(u32, 2), closed.stream_id);
    try std.testing.expectEqual(@as(u64, 42), closed.pane_id);
    try std.testing.expectError(error.InvalidSharePaneClose, decodePaneClose(close_bytes[0..11]));
    try validateDisconnectReason("host stopped sharing");
    try std.testing.expectError(error.InvalidShareDisconnectReason, validateDisconnectReason(""));
}

test "host peer coalesces independent row damage and gates input" {
    const Vt = @import("../terminal/Vt.zig");
    const FakeSession = struct { grid: Vt.Grid };
    var session = FakeSession{ .grid = try Vt.Grid.init(std.testing.allocator, 8, 2) };
    defer session.grid.deinit();
    var peer = try HostPeer.init(1);
    peer.checkpoint_required = false;
    peer.publisher.checkpointComplete(&session.grid);
    try session.grid.feed("X");
    peer.observe(&session);
    try std.testing.expect(peer.changed_rows[0]);
    try std.testing.expectError(error.ShareInputNotGranted, peer.receiveControl(.{
        .header = .{ .message_type = .input, .stream_id = 1, .sequence = 0, .payload_length = 1 },
        .payload = "x",
    }));
    try peer.receive_sequence.receive(1);
}

test "workspace manifest preserves share scope, tab hierarchy, and layouts" {
    const tabs = [_]TabManifest{
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
            .zoomed_pane_id = 42,
            .root_node = 0,
            .node_count = 1,
        },
    };
    const panes = [_]PaneManifest{
        .{ .stream_id = 1, .pane_id = 41, .tab_id = 7, .title = "Shell" },
        .{ .stream_id = 2, .pane_id = 42, .tab_id = 8, .title = "Logs" },
    };
    const nodes = [_]LayoutNodeManifest{
        .{ .tab_id = 7, .kind = .leaf, .pane_id = 41, .ratio_permille = 0 },
        .{ .tab_id = 8, .kind = .leaf, .pane_id = 42, .ratio_permille = 0 },
    };
    const bytes = try encodeWorkspaceManifestAlloc(std.testing.allocator, .{
        .scope = .session,
        .tabs = &tabs,
        .panes = &panes,
        .nodes = &nodes,
    });
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(bytes.len < 256);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "/tmp") == null);
    var decoder = try ManifestDecoder.init(bytes);
    try std.testing.expectEqual(ShareScope.session, decoder.scope);
    for (tabs) |expected| {
        const decoded = (try decoder.nextTab()).?;
        try std.testing.expectEqual(expected.tab_id, decoded.tab_id);
        try std.testing.expectEqual(expected.active, decoded.active);
        try std.testing.expectEqual(expected.active_pane_id, decoded.active_pane_id);
        try std.testing.expectEqual(expected.zoomed_pane_id, decoded.zoomed_pane_id);
        try std.testing.expectEqualStrings(expected.title, decoded.title);
    }
    try std.testing.expect((try decoder.nextTab()) == null);
    for (panes) |expected| {
        const decoded = (try decoder.nextPane()).?;
        try std.testing.expectEqual(expected.stream_id, decoded.stream_id);
        try std.testing.expectEqual(expected.pane_id, decoded.pane_id);
        try std.testing.expectEqual(expected.tab_id, decoded.tab_id);
        try std.testing.expectEqualStrings(expected.title, decoded.title);
    }
    try std.testing.expect((try decoder.nextPane()) == null);
    for (nodes) |expected|
        try std.testing.expect(std.meta.eql(expected, (try decoder.nextNode()).?));
    try std.testing.expect((try decoder.nextNode()) == null);
}

test "workspace manifest decoder rejects duplicates and trailing bytes" {
    const tabs = [_]TabManifest{
        .{
            .tab_id = 7,
            .title = "Shells",
            .active = true,
            .active_pane_id = 41,
            .root_node = 0,
            .node_count = 3,
        },
    };
    const panes = [_]PaneManifest{
        .{ .stream_id = 1, .pane_id = 41, .tab_id = 7, .title = "Shell" },
        .{ .stream_id = 2, .pane_id = 42, .tab_id = 7, .title = "Logs" },
    };
    const nodes = [_]LayoutNodeManifest{
        .{ .tab_id = 7, .kind = .split, .first = 1, .second = 2, .ratio_permille = 400 },
        .{ .tab_id = 7, .kind = .leaf, .pane_id = 41, .ratio_permille = 0 },
        .{ .tab_id = 7, .kind = .leaf, .pane_id = 42, .ratio_permille = 0 },
    };
    const bytes = try encodeWorkspaceManifestAlloc(std.testing.allocator, .{
        .scope = .tab,
        .tabs = &tabs,
        .panes = &panes,
        .nodes = &nodes,
    });
    defer std.testing.allocator.free(bytes);
    try std.testing.expectError(error.InvalidShareWorkspace, encodeWorkspaceManifestAlloc(
        std.testing.allocator,
        .{
            .scope = .tab,
            .tabs = &tabs,
            .panes = &.{
                .{ .stream_id = 1, .pane_id = 41, .tab_id = 7, .title = "Shell" },
                .{ .stream_id = 1, .pane_id = 42, .tab_id = 7, .title = "Duplicate" },
            },
            .nodes = &nodes,
        },
    ));
    const malformed = try std.testing.allocator.alloc(u8, bytes.len + 1);
    defer std.testing.allocator.free(malformed);
    @memcpy(malformed[0..bytes.len], bytes);
    malformed[bytes.len] = 0;
    var malformed_decoder = try ManifestDecoder.init(malformed);
    _ = try malformed_decoder.nextTab();
    _ = try malformed_decoder.nextPane();
    _ = try malformed_decoder.nextPane();
    _ = try malformed_decoder.nextNode();
    _ = try malformed_decoder.nextNode();
    _ = try malformed_decoder.nextNode();
    try std.testing.expectError(error.InvalidShareWorkspace, malformed_decoder.nextNode());
}

test "workspace manifest rejects split chain that exhausts traversal stack" {
    var panes: [Protocol.max_streams]PaneManifest = undefined;
    for (&panes, 0..) |*pane, index| {
        pane.* = .{
            .stream_id = @intCast(index + 1),
            .pane_id = @intCast(index + 1),
            .tab_id = 1,
            .title = "",
        };
    }
    var nodes: [Protocol.max_layout_nodes]LayoutNodeManifest = undefined;
    for (&nodes, 0..) |*node, index| {
        node.* = .{
            .tab_id = 1,
            .kind = .split,
            .first = 0,
            .second = @intCast(if (index + 1 == nodes.len) 1 else index + 1),
            .ratio_permille = 500,
        };
    }
    try std.testing.expectError(error.InvalidShareWorkspace, validateWorkspaceManifest(.{
        .scope = .tab,
        .tabs = &.{.{
            .tab_id = 1,
            .title = "",
            .active = true,
            .active_pane_id = 1,
            .root_node = 0,
            .node_count = nodes.len,
        }},
        .panes = &panes,
        .nodes = &nodes,
    }));
}
