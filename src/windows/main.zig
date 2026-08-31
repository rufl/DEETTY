//! Experimental Windows executable and Zig side of the Win32 host ABI.
//!
//! The shared VT and sharing models remain platform-neutral. Win32 windows,
//! ConPTY, clipboard, menu, font, title, and GDI rendering belong to focused
//! Zig adapters. The shrinking C boundary retains HWND/message orchestration;
//! keep GTK and POSIX-only state out of this build target.

const std = @import("std");
const windows = std.os.windows;
const Share = @import("noctty_share");
const Vt = Share.vt;
const Crypto = Share.crypto;
const Release = @import("noctty_release");
const WindowsHostLogic = @import("WindowsHostLogic.zig");
const WindowsDiagnostics = @import("WindowsDiagnostics.zig");
const WindowsPty = @import("WindowsPty.zig");
const WindowsClipboard = @import("WindowsClipboard.zig");
const WindowsProcess = @import("WindowsProcess.zig");
const WindowsMenu = @import("WindowsMenu.zig");
const WindowsFonts = @import("WindowsFonts.zig");
const WindowsTitle = @import("WindowsTitle.zig");
const WindowsRenderer = @import("WindowsRenderer.zig");
const Dpapi = @import("Dpapi.zig");

comptime {
    _ = WindowsHostLogic.noctty_windows_decode_key_action;
    _ = WindowsHostLogic.noctty_windows_decode_menu_command;
    _ = WindowsHostLogic.noctty_windows_normalize_preferences;
    _ = WindowsHostLogic.noctty_windows_blend_rgb;
    _ = WindowsHostLogic.noctty_windows_rgb_from_colorref;
    _ = WindowsHostLogic.noctty_windows_colorref_from_rgb;
    _ = WindowsHostLogic.noctty_windows_grid_dimensions;
    _ = WindowsHostLogic.noctty_windows_encode_utf16_input;
    _ = WindowsHostLogic.noctty_windows_compute_pane_geometry;
    _ = WindowsHostLogic.noctty_windows_pointer_cell;
    _ = WindowsHostLogic.noctty_windows_cell_selected;
    _ = WindowsHostLogic.noctty_windows_special_key_sequence;
    _ = WindowsDiagnostics.noctty_windows_diagnostics_init;
    _ = WindowsDiagnostics.noctty_windows_diagnostics_write;
    _ = WindowsDiagnostics.noctty_windows_diagnostics_deinit;
    _ = WindowsPty.noctty_windows_pty_create;
    _ = WindowsPty.noctty_windows_pty_destroy;
    _ = WindowsPty.noctty_windows_pty_write;
    _ = WindowsPty.noctty_windows_pty_drain;
    _ = WindowsPty.noctty_windows_pty_resize;
    _ = WindowsPty.noctty_windows_pty_poll_exit;
    _ = WindowsPty.noctty_windows_pty_exited;
    _ = WindowsPty.noctty_windows_pty_exit_code;
    _ = WindowsClipboard.noctty_windows_clipboard_paste;
    _ = WindowsClipboard.noctty_windows_clipboard_copy;
    _ = WindowsProcess.noctty_windows_launch_nocted;
    _ = WindowsMenu.noctty_windows_menu_create;
    _ = WindowsMenu.noctty_windows_menu_update;
    _ = WindowsMenu.noctty_windows_menu_deinit;
    _ = WindowsFonts.noctty_windows_fonts_update;
    _ = WindowsFonts.noctty_windows_fonts_deinit;
    _ = WindowsTitle.noctty_windows_update_title;
    _ = WindowsRenderer.noctty_windows_theme_colors;
    _ = WindowsRenderer.noctty_windows_render;
}

const host_abi_version: u32 = 9;
const columns_initial: usize = 120;
const rows_initial: usize = 36;
const max_tabs: usize = 16;
const max_panes: usize = 32;
const max_layout_nodes: usize = max_panes * 2 - 1;
const invalid_index: u8 = std.math.maxInt(u8);

const LayoutKind = enum(u8) {
    leaf,
    horizontal,
    vertical,
};

const LayoutNode = struct {
    used: bool = false,
    kind: LayoutKind = .leaf,
    parent: u8 = invalid_index,
    first: u8 = invalid_index,
    second: u8 = invalid_index,
    pane: u8 = invalid_index,
};

const WorkspacePane = struct {
    grid: *Vt.Grid,
    tab: u8,
    node: u8,
};

const WorkspaceTab = struct {
    used: bool = false,
    root: u8 = invalid_index,
    active_pane: u8 = invalid_index,
};

const PaneRect = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

const WindowsTheme = enum(u8) {
    dark,
    high_contrast,
};

const WindowsLaunchProfile = enum(u8) {
    powershell,
    command_prompt,
};

const WindowsPreferences = struct {
    theme: WindowsTheme = .dark,
    font_size_pt: u8 = 13,
    launch_profile: WindowsLaunchProfile = .powershell,
    restore_workspace: bool = true,
};

const SnapshotPane = struct {
    used: bool = false,
    tab: u8 = invalid_index,
    node: u8 = invalid_index,
};

const WorkspaceSnapshot = struct {
    panes: [max_panes]SnapshotPane = [_]SnapshotPane{.{}} ** max_panes,
    nodes: [max_layout_nodes]LayoutNode = [_]LayoutNode{.{}} ** max_layout_nodes,
    tabs: [max_tabs]WorkspaceTab = [_]WorkspaceTab{.{}} ** max_tabs,
    tab_count: u8 = 0,
    active_tab: u8 = 0,
};

const PersistedWindowsState = struct {
    preferences: WindowsPreferences = .{},
    workspace: ?WorkspaceSnapshot = null,
};

const WindowsWorkspace = struct {
    allocator: std.mem.Allocator,
    panes: [max_panes]?WorkspacePane = [_]?WorkspacePane{null} ** max_panes,
    nodes: [max_layout_nodes]LayoutNode = [_]LayoutNode{.{}} ** max_layout_nodes,
    tabs: [max_tabs]WorkspaceTab = [_]WorkspaceTab{.{}} ** max_tabs,
    tab_count: usize = 0,
    active_tab: usize = 0,

    fn init(allocator: std.mem.Allocator, columns: usize, rows: usize) !WindowsWorkspace {
        var workspace = WindowsWorkspace{ .allocator = allocator };
        errdefer workspace.deinit();
        _ = try workspace.newTab(columns, rows);
        return workspace;
    }

    fn deinit(self: *WindowsWorkspace) void {
        for (&self.panes) |*pane_slot| {
            if (pane_slot.*) |pane| {
                pane.grid.deinit();
                self.allocator.destroy(pane.grid);
                pane_slot.* = null;
            }
        }
    }

    fn activePaneIndex(self: *const WindowsWorkspace) ?usize {
        if (self.tab_count == 0 or self.active_tab >= self.tab_count) return null;
        const index = self.tabs[self.active_tab].active_pane;
        return if (index == invalid_index) null else index;
    }

    fn activeGrid(self: *WindowsWorkspace) ?*Vt.Grid {
        const index = self.activePaneIndex() orelse return null;
        return if (self.panes[index]) |pane| pane.grid else null;
    }

    fn paneGrid(self: *WindowsWorkspace, index: usize) ?*Vt.Grid {
        if (index >= self.panes.len) return null;
        return if (self.panes[index]) |pane| pane.grid else null;
    }

    fn allocateNode(self: *WindowsWorkspace) !usize {
        for (&self.nodes, 0..) |*node, index| {
            if (node.used) continue;
            node.* = .{ .used = true };
            return index;
        }
        return error.WindowsLayoutFull;
    }

    fn allocatePane(
        self: *WindowsWorkspace,
        tab_index: usize,
        columns: usize,
        rows: usize,
    ) !usize {
        const pane_index = for (&self.panes, 0..) |pane, index| {
            if (pane == null) break index;
        } else return error.WindowsWorkspaceFull;
        const node_index = try self.allocateNode();
        errdefer self.nodes[node_index] = .{};
        const grid = try self.allocator.create(Vt.Grid);
        errdefer self.allocator.destroy(grid);
        grid.* = try Vt.Grid.init(self.allocator, columns, rows);
        self.nodes[node_index] = .{
            .used = true,
            .pane = @intCast(pane_index),
        };
        self.panes[pane_index] = .{
            .grid = grid,
            .tab = @intCast(tab_index),
            .node = @intCast(node_index),
        };
        return pane_index;
    }

    fn releasePane(self: *WindowsWorkspace, pane_index: usize) void {
        const pane = self.panes[pane_index] orelse return;
        pane.grid.deinit();
        self.allocator.destroy(pane.grid);
        self.nodes[pane.node] = .{};
        self.panes[pane_index] = null;
    }

    fn newTab(self: *WindowsWorkspace, columns: usize, rows: usize) !usize {
        if (self.tab_count >= self.tabs.len) return error.WindowsTabLimit;
        const tab_index = self.tab_count;
        const pane_index = try self.allocatePane(tab_index, columns, rows);
        const pane = self.panes[pane_index].?;
        self.tabs[tab_index] = .{
            .used = true,
            .root = pane.node,
            .active_pane = @intCast(pane_index),
        };
        self.tab_count += 1;
        self.active_tab = tab_index;
        return pane_index;
    }

    fn splitActive(
        self: *WindowsWorkspace,
        kind: LayoutKind,
        new_first: bool,
        columns: usize,
        rows: usize,
    ) !usize {
        const active_pane = self.activePaneIndex() orelse return error.NoActivePane;
        const old_pane = self.panes[active_pane].?;
        const branch_index = try self.allocateNode();
        errdefer self.nodes[branch_index] = .{};
        const new_pane_index = self.allocatePane(
            self.active_tab,
            columns,
            rows,
        ) catch |err| return err;
        errdefer self.releasePane(new_pane_index);
        const new_pane = self.panes[new_pane_index].?;
        const old_parent = self.nodes[old_pane.node].parent;
        self.nodes[branch_index] = .{
            .used = true,
            .kind = kind,
            .parent = old_parent,
            .first = if (new_first) new_pane.node else old_pane.node,
            .second = if (new_first) old_pane.node else new_pane.node,
        };
        self.nodes[old_pane.node].parent = @intCast(branch_index);
        self.nodes[new_pane.node].parent = @intCast(branch_index);
        if (old_parent == invalid_index) {
            self.tabs[self.active_tab].root = @intCast(branch_index);
        } else if (self.nodes[old_parent].first == old_pane.node) {
            self.nodes[old_parent].first = @intCast(branch_index);
        } else {
            self.nodes[old_parent].second = @intCast(branch_index);
        }
        self.tabs[self.active_tab].active_pane = @intCast(new_pane_index);
        return new_pane_index;
    }

    fn selectPane(self: *WindowsWorkspace, pane_index: usize) bool {
        const pane = if (pane_index < self.panes.len)
            self.panes[pane_index] orelse return false
        else
            return false;
        const tab_index: usize = pane.tab;
        if (tab_index >= self.tab_count) return false;
        self.active_tab = tab_index;
        self.tabs[tab_index].active_pane = @intCast(pane_index);
        return true;
    }

    fn nextPane(self: *WindowsWorkspace) bool {
        const active = self.activePaneIndex() orelse return false;
        var index = active;
        for (0..self.panes.len - 1) |_| {
            index = (index + 1) % self.panes.len;
            const pane = self.panes[index] orelse continue;
            if (pane.tab != self.active_tab) continue;
            self.tabs[self.active_tab].active_pane = @intCast(index);
            return true;
        }
        return false;
    }

    fn nextTab(self: *WindowsWorkspace) bool {
        if (self.tab_count < 2) return false;
        self.active_tab = (self.active_tab + 1) % self.tab_count;
        return true;
    }

    fn paneTotal(self: *const WindowsWorkspace) usize {
        var count: usize = 0;
        for (self.panes) |pane| count += @intFromBool(pane != null);
        return count;
    }

    fn firstPaneInNode(self: *const WindowsWorkspace, node_index: u8) ?usize {
        if (node_index == invalid_index or !self.nodes[node_index].used) return null;
        const node = self.nodes[node_index];
        if (node.kind == .leaf)
            return if (node.pane == invalid_index) null else node.pane;
        return self.firstPaneInNode(node.first) orelse
            self.firstPaneInNode(node.second);
    }

    fn activeTabPaneCount(self: *const WindowsWorkspace) usize {
        var count: usize = 0;
        for (self.panes) |pane_slot| {
            const pane = pane_slot orelse continue;
            count += @intFromBool(pane.tab == self.active_tab);
        }
        return count;
    }

    fn removeTabRecord(self: *WindowsWorkspace, tab_index: usize) void {
        for (&self.panes) |*pane_slot| {
            if (pane_slot.*) |*pane| {
                if (pane.tab > tab_index) pane.tab -= 1;
            }
        }
        for (tab_index..self.tab_count - 1) |index|
            self.tabs[index] = self.tabs[index + 1];
        self.tab_count -= 1;
        self.tabs[self.tab_count] = .{};
        if (self.active_tab > tab_index) {
            self.active_tab -= 1;
        } else if (self.active_tab >= self.tab_count) {
            self.active_tab = self.tab_count - 1;
        }
    }

    fn closeActivePane(self: *WindowsWorkspace) ?usize {
        if (self.paneTotal() <= 1) return null;
        const pane_index = self.activePaneIndex() orelse return null;
        const pane = self.panes[pane_index].?;
        const tab_index: usize = pane.tab;
        const parent = self.nodes[pane.node].parent;
        if (parent == invalid_index) {
            self.releasePane(pane_index);
            self.removeTabRecord(tab_index);
            return pane_index;
        }
        const sibling = if (self.nodes[parent].first == pane.node)
            self.nodes[parent].second
        else
            self.nodes[parent].first;
        const grandparent = self.nodes[parent].parent;
        self.nodes[sibling].parent = grandparent;
        if (grandparent == invalid_index) {
            self.tabs[tab_index].root = sibling;
        } else if (self.nodes[grandparent].first == parent) {
            self.nodes[grandparent].first = sibling;
        } else {
            self.nodes[grandparent].second = sibling;
        }
        self.nodes[parent] = .{};
        self.releasePane(pane_index);
        self.tabs[tab_index].active_pane =
            @intCast(self.firstPaneInNode(sibling) orelse return null);
        return pane_index;
    }

    fn clearLayout(self: *WindowsWorkspace, node_index: u8) void {
        if (node_index == invalid_index or !self.nodes[node_index].used) return;
        const node = self.nodes[node_index];
        if (node.kind != .leaf) {
            self.clearLayout(node.first);
            self.clearLayout(node.second);
        }
        self.nodes[node_index] = .{};
    }

    fn closeActiveTab(self: *WindowsWorkspace) u32 {
        if (self.tab_count <= 1) return 0;
        const tab_index = self.active_tab;
        const root = self.tabs[tab_index].root;
        var closed: u32 = 0;
        for (&self.panes, 0..) |*pane_slot, pane_index| {
            const pane = pane_slot.* orelse continue;
            if (pane.tab != tab_index) continue;
            pane.grid.deinit();
            self.allocator.destroy(pane.grid);
            pane_slot.* = null;
            closed |= @as(u32, 1) << @intCast(pane_index);
        }
        self.clearLayout(root);
        self.removeTabRecord(tab_index);
        return closed;
    }

    fn activeTabMask(self: *const WindowsWorkspace) u32 {
        if (self.tab_count <= 1) return 0;
        var mask: u32 = 0;
        for (self.panes, 0..) |pane_slot, pane_index| {
            const pane = pane_slot orelse continue;
            if (pane.tab == self.active_tab)
                mask |= @as(u32, 1) << @intCast(pane_index);
        }
        return mask;
    }
    fn highestPaneIndex(self: *const WindowsWorkspace) usize {
        var count: usize = 0;
        for (self.panes, 0..) |pane, index| {
            if (pane != null) count = index + 1;
        }
        return count;
    }

    fn paneRect(self: *const WindowsWorkspace, pane_index: usize) ?PaneRect {
        if (pane_index >= self.panes.len) return null;
        const pane = self.panes[pane_index] orelse return null;
        if (pane.tab != self.active_tab) return null;
        return self.findPaneRect(
            self.tabs[self.active_tab].root,
            pane.node,
            .{ .x = 0, .y = 0, .width = 1_000_000, .height = 1_000_000 },
        );
    }

    fn findPaneRect(
        self: *const WindowsWorkspace,
        node_index: u8,
        target_node: u8,
        rectangle: PaneRect,
    ) ?PaneRect {
        if (node_index == invalid_index or !self.nodes[node_index].used) return null;
        if (node_index == target_node) return rectangle;
        const node = self.nodes[node_index];
        if (node.kind == .leaf) return null;
        var first = rectangle;
        var second = rectangle;
        if (node.kind == .horizontal) {
            first.width = rectangle.width / 2;
            second.x += first.width;
            second.width -= first.width;
        } else {
            first.height = rectangle.height / 2;
            second.y += first.height;
            second.height -= first.height;
        }
        return self.findPaneRect(node.first, target_node, first) orelse
            self.findPaneRect(node.second, target_node, second);
    }

    fn snapshot(self: *const WindowsWorkspace) WorkspaceSnapshot {
        var result = WorkspaceSnapshot{
            .nodes = self.nodes,
            .tabs = self.tabs,
            .tab_count = @intCast(self.tab_count),
            .active_tab = @intCast(self.active_tab),
        };
        for (self.panes, 0..) |pane_slot, index| {
            const pane = pane_slot orelse continue;
            result.panes[index] = .{
                .used = true,
                .tab = pane.tab,
                .node = pane.node,
            };
        }
        return result;
    }

    fn restore(
        self: *WindowsWorkspace,
        snapshot_value: WorkspaceSnapshot,
        columns: usize,
        rows: usize,
    ) !void {
        try validateWorkspaceSnapshot(snapshot_value);
        var candidate = WindowsWorkspace{
            .allocator = self.allocator,
            .nodes = snapshot_value.nodes,
            .tabs = snapshot_value.tabs,
            .tab_count = snapshot_value.tab_count,
            .active_tab = snapshot_value.active_tab,
        };
        errdefer candidate.deinit();
        for (snapshot_value.panes, 0..) |pane, index| {
            if (!pane.used) continue;
            const grid = grid: {
                const allocated = try candidate.allocator.create(Vt.Grid);
                errdefer candidate.allocator.destroy(allocated);
                allocated.* = try Vt.Grid.init(candidate.allocator, columns, rows);
                break :grid allocated;
            };
            candidate.panes[index] = .{
                .grid = grid,
                .tab = pane.tab,
                .node = pane.node,
            };
        }
        self.deinit();
        self.* = candidate;
    }
};

const State = struct {
    workspace: WindowsWorkspace,
    store: Share.identity.Store,
    preferences: WindowsPreferences = .{},
    saved_workspace: ?WorkspaceSnapshot = null,
    live_host: ?*Share.live_host.LiveHost = null,
    shared_pane: ?usize = null,
    live_viewer: ?*Share.live_viewer.LiveViewer = null,
};

const persisted_state_magic = "NWS1";
const persisted_state_capacity = 1024;

const StateWriter = struct {
    bytes: []u8,
    index: usize = 0,

    fn put(self: *StateWriter, value: u8) !void {
        if (self.index >= self.bytes.len) return error.WindowsStateTooLarge;
        self.bytes[self.index] = value;
        self.index += 1;
    }

    fn putU32(self: *StateWriter, value: u32) !void {
        try self.put(@truncate(value));
        try self.put(@truncate(value >> 8));
        try self.put(@truncate(value >> 16));
        try self.put(@truncate(value >> 24));
    }
};

const StateReader = struct {
    bytes: []const u8,
    index: usize = 0,

    fn take(self: *StateReader) !u8 {
        if (self.index >= self.bytes.len) return error.InvalidWindowsState;
        const value = self.bytes[self.index];
        self.index += 1;
        return value;
    }

    fn takeBool(self: *StateReader) !bool {
        return switch (try self.take()) {
            0 => false,
            1 => true,
            else => error.InvalidWindowsState,
        };
    }

    fn takeU32(self: *StateReader) !u32 {
        const first: u32 = try self.take();
        const second: u32 = try self.take();
        const third: u32 = try self.take();
        const fourth: u32 = try self.take();
        return first | (second << 8) | (third << 16) | (fourth << 24);
    }
};

fn windowsStateChecksum(bytes: []const u8) u32 {
    var hash: u32 = 2_166_136_261;
    for (bytes) |byte| {
        hash ^= byte;
        hash *%= 16_777_619;
    }
    return hash;
}

fn validateSnapshotNode(
    snapshot_value: WorkspaceSnapshot,
    visited: *[max_layout_nodes]bool,
    node_index: u8,
    parent: u8,
    tab_index: usize,
    depth: usize,
) !void {
    if (node_index == invalid_index or node_index >= max_layout_nodes or
        depth >= max_layout_nodes)
        return error.InvalidWindowsWorkspace;
    const index: usize = node_index;
    if (visited[index]) return error.InvalidWindowsWorkspace;
    const node = snapshot_value.nodes[index];
    if (!node.used or node.parent != parent) return error.InvalidWindowsWorkspace;
    visited[index] = true;
    if (node.kind == .leaf) {
        if (node.first != invalid_index or node.second != invalid_index or
            node.pane == invalid_index or node.pane >= max_panes)
            return error.InvalidWindowsWorkspace;
        const pane = snapshot_value.panes[node.pane];
        if (!pane.used or pane.node != node_index or pane.tab != tab_index)
            return error.InvalidWindowsWorkspace;
        return;
    }
    if (node.pane != invalid_index or node.first == node.second)
        return error.InvalidWindowsWorkspace;
    try validateSnapshotNode(
        snapshot_value,
        visited,
        node.first,
        node_index,
        tab_index,
        depth + 1,
    );
    try validateSnapshotNode(
        snapshot_value,
        visited,
        node.second,
        node_index,
        tab_index,
        depth + 1,
    );
}

fn validateWorkspaceSnapshot(snapshot_value: WorkspaceSnapshot) !void {
    if (snapshot_value.tab_count == 0 or snapshot_value.tab_count > max_tabs or
        snapshot_value.active_tab >= snapshot_value.tab_count)
        return error.InvalidWindowsWorkspace;
    var visited = [_]bool{false} ** max_layout_nodes;
    for (snapshot_value.tabs, 0..) |tab, index| {
        if (index >= snapshot_value.tab_count) {
            if (tab.used) return error.InvalidWindowsWorkspace;
            continue;
        }
        if (!tab.used or tab.active_pane == invalid_index or
            tab.active_pane >= max_panes)
            return error.InvalidWindowsWorkspace;
        const active = snapshot_value.panes[tab.active_pane];
        if (!active.used or active.tab != index) return error.InvalidWindowsWorkspace;
        try validateSnapshotNode(
            snapshot_value,
            &visited,
            tab.root,
            invalid_index,
            index,
            0,
        );
    }
    for (snapshot_value.nodes, visited) |node, was_visited| {
        if (node.used != was_visited) return error.InvalidWindowsWorkspace;
    }
    for (snapshot_value.panes, 0..) |pane, index| {
        if (!pane.used) continue;
        if (pane.tab >= snapshot_value.tab_count or pane.node >= max_layout_nodes)
            return error.InvalidWindowsWorkspace;
        const node = snapshot_value.nodes[pane.node];
        if (!node.used or node.kind != .leaf or node.pane != index)
            return error.InvalidWindowsWorkspace;
    }
}

fn encodePersistedWindowsState(
    value: PersistedWindowsState,
    output: []u8,
) !usize {
    var writer = StateWriter{ .bytes = output };
    for (persisted_state_magic) |byte| try writer.put(byte);
    try writer.put(@intFromEnum(value.preferences.theme));
    try writer.put(value.preferences.font_size_pt);
    try writer.put(@intFromEnum(value.preferences.launch_profile));
    try writer.put(@intFromBool(value.preferences.restore_workspace));
    try writer.put(@intFromBool(value.workspace != null));
    if (value.workspace) |snapshot_value| {
        try validateWorkspaceSnapshot(snapshot_value);
        try writer.put(snapshot_value.tab_count);
        try writer.put(snapshot_value.active_tab);
        for (snapshot_value.tabs) |tab| {
            try writer.put(@intFromBool(tab.used));
            try writer.put(tab.root);
            try writer.put(tab.active_pane);
        }
        for (snapshot_value.nodes) |node| {
            try writer.put(@intFromBool(node.used));
            try writer.put(@intFromEnum(node.kind));
            try writer.put(node.parent);
            try writer.put(node.first);
            try writer.put(node.second);
            try writer.put(node.pane);
        }
        for (snapshot_value.panes) |pane| {
            try writer.put(@intFromBool(pane.used));
            try writer.put(pane.tab);
            try writer.put(pane.node);
        }
    }
    try writer.putU32(windowsStateChecksum(output[0..writer.index]));
    return writer.index;
}

fn decodePersistedWindowsState(bytes: []const u8) !PersistedWindowsState {
    if (bytes.len < persisted_state_magic.len + 9) return error.InvalidWindowsState;
    const payload = bytes[0 .. bytes.len - 4];
    var checksum_reader = StateReader{ .bytes = bytes[bytes.len - 4 ..] };
    if (try checksum_reader.takeU32() != windowsStateChecksum(payload))
        return error.InvalidWindowsState;
    var reader = StateReader{ .bytes = payload };
    for (persisted_state_magic) |expected|
        if (try reader.take() != expected) return error.InvalidWindowsState;
    const theme: WindowsTheme = switch (try reader.take()) {
        0 => .dark,
        1 => .high_contrast,
        else => return error.InvalidWindowsState,
    };
    const font_size = try reader.take();
    if (font_size < 10 or font_size > 24) return error.InvalidWindowsState;
    const launch_profile: WindowsLaunchProfile = switch (try reader.take()) {
        0 => .powershell,
        1 => .command_prompt,
        else => return error.InvalidWindowsState,
    };
    var result = PersistedWindowsState{ .preferences = .{
        .theme = theme,
        .font_size_pt = font_size,
        .launch_profile = launch_profile,
        .restore_workspace = try reader.takeBool(),
    } };
    if (try reader.takeBool()) {
        var snapshot_value = WorkspaceSnapshot{
            .tab_count = try reader.take(),
            .active_tab = try reader.take(),
        };
        for (&snapshot_value.tabs) |*tab| {
            tab.* = .{
                .used = try reader.takeBool(),
                .root = try reader.take(),
                .active_pane = try reader.take(),
            };
        }
        for (&snapshot_value.nodes) |*node| {
            const used = try reader.takeBool();
            const kind: LayoutKind = switch (try reader.take()) {
                0 => .leaf,
                1 => .horizontal,
                2 => .vertical,
                else => return error.InvalidWindowsState,
            };
            node.* = .{
                .used = used,
                .kind = kind,
                .parent = try reader.take(),
                .first = try reader.take(),
                .second = try reader.take(),
                .pane = try reader.take(),
            };
        }
        for (&snapshot_value.panes) |*pane| {
            pane.* = .{
                .used = try reader.takeBool(),
                .tab = try reader.take(),
                .node = try reader.take(),
            };
        }
        try validateWorkspaceSnapshot(snapshot_value);
        result.workspace = snapshot_value;
    }
    if (reader.index != reader.bytes.len) return error.InvalidWindowsState;
    return result;
}

const Feed = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const Write = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const TakeReply = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const TakeRemote = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const Cell = *const fn (?*anyopaque, c_int, c_int) callconv(.c) u64;
const CellText = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    [*]u8,
    usize,
) callconv(.c) c_int;
const ColorRgb = *const fn (?*anyopaque, u32) callconv(.c) u32;
const Cursor = *const fn (?*anyopaque) callconv(.c) u32;
const Title = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const Resize = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;
const Scroll = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const CursorMode = *const fn (?*anyopaque) callconv(.c) c_int;
const SmokeReady = *const fn (?*anyopaque) callconv(.c) c_int;
const Start = *const fn (?*anyopaque) callconv(.c) c_int;
const Stop = *const fn (?*anyopaque) callconv(.c) c_int;

const NextStream = *const fn (?*anyopaque) callconv(.c) c_int;
const NextTab = *const fn (?*anyopaque) callconv(.c) c_int;
const PaneCount = *const fn (?*anyopaque) callconv(.c) c_int;
const PaneLayout = *const fn (
    ?*anyopaque,
    c_int,
    *u32,
    *u32,
    *u32,
    *u32,
    *c_int,
    *c_int,
) callconv(.c) c_int;
const PaneDimensions = *const fn (
    ?*anyopaque,
    c_int,
    *u16,
    *u16,
) callconv(.c) c_int;
const PaneCell = *const fn (?*anyopaque, c_int, c_int, c_int) callconv(.c) u64;
const PaneCellText = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    c_int,
    [*]u8,
    usize,
) callconv(.c) c_int;
const PaneColorRgb = *const fn (?*anyopaque, c_int, u32) callconv(.c) u32;
const PaneCursor = *const fn (?*anyopaque, c_int) callconv(.c) u32;
const PaneSelect = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const PaneFeed = *const fn (
    ?*anyopaque,
    c_int,
    [*]const u8,
    usize,
) callconv(.c) c_int;
const PaneTakeReply = *const fn (
    ?*anyopaque,
    c_int,
    [*]u8,
    usize,
) callconv(.c) c_int;
const PaneResize = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    c_int,
) callconv(.c) c_int;
const PaneMouseMode = *const fn (?*anyopaque, c_int) callconv(.c) u32;
const PaneMouseEncode = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    [*]u8,
    usize,
) callconv(.c) c_int;
const PaneCopy = *const fn (
    ?*anyopaque,
    c_int,
    [*]u8,
    usize,
    c_int,
    c_int,
    c_int,
    c_int,
) callconv(.c) c_int;
const WorkspaceAction = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    c_int,
) callconv(.c) c_int;
const ActivePane = *const fn (?*anyopaque) callconv(.c) c_int;
const WorkspaceClose = *const fn (?*anyopaque, c_int) callconv(.c) u32;
const PreferenceGet = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const PreferenceSet = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;
const WorkspacePersistence = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    c_int,
) callconv(.c) c_int;
const Callbacks = extern struct {
    abi_version: u32 = host_abi_version,
    struct_size: u32 = @sizeOf(Callbacks),
    userdata: ?*anyopaque,
    feed: Feed,
    write: Write,
    take_reply: TakeReply,
    take_remote: TakeRemote,
    cell: Cell,
    cell_text: CellText,
    color_rgb: ColorRgb,
    cursor: Cursor,
    title: Title,
    resize: Resize,
    scroll: Scroll,
    cursor_mode: CursorMode,
    smoke_ready: SmokeReady,
    start: Start,
    stop: Stop,
    next_stream: NextStream,
    next_tab: NextTab,
    pane_count: PaneCount,
    pane_layout: PaneLayout,
    pane_dimensions: PaneDimensions,
    pane_cell: PaneCell,
    pane_cell_text: PaneCellText,
    pane_color_rgb: PaneColorRgb,
    pane_cursor: PaneCursor,
    pane_select: PaneSelect,
    pane_feed: PaneFeed,
    pane_take_reply: PaneTakeReply,
    pane_resize: PaneResize,
    workspace_action: WorkspaceAction,
    active_pane: ActivePane,
    workspace_close: WorkspaceClose,
    remote_pane: ActivePane,
    preference_get: PreferenceGet,
    preference_set: PreferenceSet,
    workspace_persistence: WorkspacePersistence,
    pane_mouse_mode: PaneMouseMode,
    pane_mouse_encode: PaneMouseEncode,
    pane_copy: PaneCopy,
};

extern fn noctty_windows_host_run(
    instance: windows.HINSTANCE,
    show_command: c_int,
    callbacks: *const Callbacks,
) c_int;
extern "user32" fn MessageBoxW(
    ?windows.HWND,
    [*:0]const u16,
    [*:0]const u16,
    windows.UINT,
) callconv(.winapi) c_int;

fn readPersistedWindowsState() !?PersistedWindowsState {
    var bytes: [persisted_state_capacity]u8 = undefined;
    const length = Dpapi.stateLoad(&bytes) catch return error.WindowsStateLoadFailed;
    return try decodePersistedWindowsState(bytes[0..(length orelse return null)]);
}

fn writePersistedWindowsState(state: *const State) !void {
    var bytes: [persisted_state_capacity]u8 = undefined;
    const length = try encodePersistedWindowsState(.{
        .preferences = state.preferences,
        .workspace = state.saved_workspace,
    }, &bytes);
    Dpapi.stateSave(bytes[0..length]) catch return error.WindowsStateSaveFailed;
}

fn applyPersistedWindowsState(state: *State) void {
    const persisted = readPersistedWindowsState() catch return;
    const value = persisted orelse return;
    state.preferences = value.preferences;
    state.saved_workspace = value.workspace;
    if (state.preferences.restore_workspace) {
        const snapshot_value = state.saved_workspace orelse return;
        state.workspace.restore(
            snapshot_value,
            columns_initial,
            rows_initial,
        ) catch {};
    }
}

pub export fn wWinMain(
    instance: windows.HINSTANCE,
    previous_instance: ?windows.HINSTANCE,
    command_line: [*:0]u16,
    show_command: c_int,
) callconv(.c) c_int {
    _ = previous_instance;

    const command = std.mem.span(command_line);
    if (firstAsciiTokenIs(command, "--version")) {
        const version_text = std.unicode.utf8ToUtf16LeStringLiteral(
            "NOCTTY " ++ Release.version ++ " Windows alpha",
        );
        _ = MessageBoxW(
            null,
            version_text,
            std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY"),
            0x40,
        );
        return 0;
    }
    const self_test_requested = firstAsciiTokenIs(command, "--self-test");

    var threaded: std.Io.Threaded = .init(std.heap.page_allocator, .{});
    defer threaded.deinit();
    const random = Crypto.fromIo(threaded.io());
    var store = loadOrCreateStore() catch return 1;
    const mode = parseShareMode(command) catch {
        showWindowsMessage(
            "Usage: --pair-listen PORT ALIAS REMOTE_HOST, " ++ "--pair-connect HOST PORT ALIAS, --discover, --list-pairs, " ++ "--revoke INDEX, --share INDEX PORT, or --receive INDEX",
        );
        store.deinit();
        return 1;
    };
    if (mode.kind == .pair_listen or mode.kind == .pair_connect) {
        const result = runPairing(&store, random, mode);
        store.deinit();
        return result;
    }
    if (mode.kind == .discover) {
        const result = runDiscovery();
        store.deinit();
        return result;
    }
    if (mode.kind == .list_pairs) {
        showWindowsPeers(&store);
        store.deinit();
        return 0;
    }
    if (mode.kind == .revoke) {
        if (mode.index >= store.peer_count) {
            showWindowsMessage("No paired device has that index.");
            store.deinit();
            return 1;
        }
        store.peerSlice()[mode.index].revoked = true;
        saveStore(&store) catch {
            showWindowsMessage("Could not persist paired-device revocation.");
            store.deinit();
            return 1;
        };
        showWindowsMessage("Paired device revoked.");
        store.deinit();
        return 0;
    }
    var state = State{
        .workspace = WindowsWorkspace.init(
            std.heap.page_allocator,
            columns_initial,
            rows_initial,
        ) catch {
            store.deinit();
            return 1;
        },
        .store = store,
    };
    defer {
        if (state.live_host) |host| host.destroy();
        if (state.live_viewer) |viewer| viewer.destroy();
        state.workspace.deinit();
        state.store.deinit();
    }
    if (!self_test_requested) applyPersistedWindowsState(&state);

    if (self_test_requested) return if (selfTest(&state)) 0 else 1;
    if (mode.kind == .share) {
        if (mode.index >= state.store.peer_count) {
            showWindowsMessage("No paired device has that index.");
            return 1;
        }
        if (state.store.peerSliceConst()[mode.index].revoked) {
            showWindowsMessage(
                "That paired device is revoked. Pair it again before sharing.",
            );
            return 1;
        }
        if (mode.port == 0) {
            showWindowsMessage("Sharing requires a nonzero TCP port.");
            return 1;
        }
        state.live_host = Share.live_host.LiveHost.create(
            std.heap.page_allocator,
            random,
            state.store.identity,
            state.store.peerSliceConst()[mode.index],
            null,
            mode.port,
            .pane,
            &.{.{
                .tab_id = 1,
                .title = "Windows terminal",
                .active = true,
                .active_pane_id = 1,
                .root_node = 0,
                .node_count = 1,
            }},
            &.{.{ .pane_id = 1, .tab_id = 1, .title = "ConPTY" }},
            &.{.{
                .tab_id = 1,
                .kind = .leaf,
                .pane_id = 1,
                .ratio_permille = 0,
            }},
        ) catch {
            showWindowsMessage(
                "Could not start sharing. Check the selected device and port.",
            );
            return 1;
        };
        state.shared_pane = state.workspace.activePaneIndex();
    } else if (mode.kind == .receive) {
        if (mode.index >= state.store.peer_count) {
            showWindowsMessage("No paired device has that index.");
            return 1;
        }
        if (state.store.peerSliceConst()[mode.index].revoked) {
            showWindowsMessage(
                "That paired device is revoked. Pair it again before receiving.",
            );
            return 1;
        }
        state.live_viewer = Share.live_viewer.LiveViewer.create(
            std.heap.page_allocator,
            random,
            state.store.identity,
            state.store.peerSliceConst()[mode.index],
        ) catch {
            showWindowsMessage(
                "Could not receive the selected device. Check its endpoint.",
            );
            return 1;
        };
    }

    const callbacks = Callbacks{
        .userdata = &state,
        .feed = feed,
        .write = localWrite,
        .take_reply = takeReply,
        .take_remote = takeRemote,
        .cell = cell,
        .cell_text = cellText,
        .color_rgb = colorRgb,
        .cursor = cursor,
        .title = title,
        .resize = resize,
        .scroll = scroll,
        .cursor_mode = cursorMode,
        .smoke_ready = smokeReady,
        .start = localStart,
        .stop = localStop,
        .next_stream = nextStream,
        .next_tab = nextTab,
        .pane_count = paneCount,
        .pane_layout = paneLayout,
        .pane_dimensions = paneDimensions,
        .pane_cell = paneCell,
        .pane_cell_text = paneCellText,
        .pane_color_rgb = paneColorRgb,
        .pane_cursor = paneCursor,
        .pane_select = paneSelect,
        .pane_feed = paneFeed,
        .pane_take_reply = paneTakeReply,
        .pane_resize = paneResize,
        .workspace_action = workspaceAction,
        .active_pane = activePane,
        .workspace_close = workspaceClose,
        .remote_pane = remotePane,
        .preference_get = preferenceGet,
        .preference_set = preferenceSet,
        .workspace_persistence = workspacePersistence,
        .pane_mouse_mode = paneMouseMode,
        .pane_mouse_encode = paneMouseEncode,
        .pane_copy = paneCopy,
    };
    return noctty_windows_host_run(instance, show_command, &callbacks);
}

fn loadOrCreateIdentity() !Crypto.Identity {
    var secret: [Crypto.secret_key_length]u8 = undefined;
    defer std.crypto.secureZero(u8, &secret);
    const loaded = Dpapi.identityLoad(&secret) catch
        return error.WindowsIdentityLoadFailed;
    if (loaded) return Crypto.Identity.fromSecret(secret);

    Dpapi.random(&secret) catch return error.WindowsRandomFailed;
    const identity = try Crypto.Identity.fromSecret(secret);
    Dpapi.identitySave(&identity.secret_key) catch
        return error.WindowsIdentitySaveFailed;
    return identity;
}

fn loadOrCreateStore() !Share.identity.Store {
    var bytes: [Share.identity.max_file_bytes]u8 = undefined;
    defer std.crypto.secureZero(u8, &bytes);
    const length = Dpapi.peersLoad(&bytes) catch
        return error.WindowsPeerStoreLoadFailed;
    if (length) |count| return Share.identity.import(bytes[0..count]);
    return Share.identity.Store.init(try loadOrCreateIdentity());
}

fn saveStore(store: *const Share.identity.Store) !void {
    const bytes = try Share.identity.exportAlloc(std.heap.page_allocator, store);
    defer {
        std.crypto.secureZero(u8, bytes);
        std.heap.page_allocator.free(bytes);
    }
    Dpapi.peersSave(bytes) catch return error.WindowsPeerStoreSaveFailed;
}

const ShareMode = struct {
    const Kind = enum { local, pair_listen, pair_connect, discover, list_pairs, revoke, share, receive };
    kind: Kind = .local,
    index: usize = 0,
    port: u16 = 0,
    host: [Share.identity.max_endpoint_bytes]u8 = [_]u8{0} ** Share.identity.max_endpoint_bytes,
    host_length: usize = 0,
    alias: [Share.protocol.max_alias_bytes]u8 = [_]u8{0} ** Share.protocol.max_alias_bytes,
    alias_length: usize = 0,

    fn hostSlice(self: *const ShareMode) []const u8 {
        return self.host[0..self.host_length];
    }

    fn aliasSlice(self: *const ShareMode) []const u8 {
        return self.alias[0..self.alias_length];
    }
};

fn nextAsciiToken(command: []const u16, cursor_index: *usize, output: []u8) ![]const u8 {
    var cursor_index_value = cursor_index.*;
    while (cursor_index_value < command.len and command[cursor_index_value] == ' ')
        cursor_index_value += 1;
    if (cursor_index_value == command.len) return error.MissingWindowsShareArgument;
    const quoted = command[cursor_index_value] == '"';
    if (quoted) cursor_index_value += 1;
    var length: usize = 0;
    while (cursor_index_value < command.len) : (cursor_index_value += 1) {
        const value = command[cursor_index_value];
        if ((quoted and value == '"') or (!quoted and value == ' ')) break;
        if (value > 0x7f or length == output.len) return error.InvalidWindowsShareArgument;
        output[length] = @intCast(value);
        length += 1;
    }
    if (quoted) {
        if (cursor_index_value == command.len or command[cursor_index_value] != '"')
            return error.InvalidWindowsShareArgument;
        cursor_index_value += 1;
    }
    cursor_index.* = cursor_index_value;
    if (length == 0) return error.InvalidWindowsShareArgument;
    return output[0..length];
}

fn parseShareMode(command: []const u16) !ShareMode {
    var cursor_index: usize = 0;
    var token_buffer: [256]u8 = undefined;
    const first = nextAsciiToken(command, &cursor_index, &token_buffer) catch |err| switch (err) {
        error.MissingWindowsShareArgument => return .{},
        else => return err,
    };
    var mode = ShareMode{};
    if (std.mem.eql(u8, first, "--pair-listen")) {
        mode.kind = .pair_listen;
        mode.port = try std.fmt.parseInt(u16, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
        const alias = try nextAsciiToken(command, &cursor_index, &token_buffer);
        if (alias.len > mode.alias.len) return error.InvalidWindowsShareArgument;
        @memcpy(mode.alias[0..alias.len], alias);
        mode.alias_length = alias.len;
        const host = try nextAsciiToken(command, &cursor_index, &token_buffer);
        if (host.len > mode.host.len) return error.InvalidWindowsShareArgument;
        @memcpy(mode.host[0..host.len], host);
        mode.host_length = host.len;
    } else if (std.mem.eql(u8, first, "--pair-connect")) {
        mode.kind = .pair_connect;
        const host = try nextAsciiToken(command, &cursor_index, &token_buffer);
        if (host.len > mode.host.len) return error.InvalidWindowsShareArgument;
        @memcpy(mode.host[0..host.len], host);
        mode.host_length = host.len;
        mode.port = try std.fmt.parseInt(u16, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
        const alias = try nextAsciiToken(command, &cursor_index, &token_buffer);
        if (alias.len > mode.alias.len) return error.InvalidWindowsShareArgument;
        @memcpy(mode.alias[0..alias.len], alias);
        mode.alias_length = alias.len;
    } else if (std.mem.eql(u8, first, "--discover")) {
        mode.kind = .discover;
    } else if (std.mem.eql(u8, first, "--list-pairs")) {
        mode.kind = .list_pairs;
    } else if (std.mem.eql(u8, first, "--revoke")) {
        mode.kind = .revoke;
        mode.index = try std.fmt.parseInt(usize, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
    } else if (std.mem.eql(u8, first, "--share")) {
        mode.kind = .share;
        mode.index = try std.fmt.parseInt(usize, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
        mode.port = try std.fmt.parseInt(u16, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
    } else if (std.mem.eql(u8, first, "--receive")) {
        mode.kind = .receive;
        mode.index = try std.fmt.parseInt(usize, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
    }
    return mode;
}

fn showWindowsMessage(message: []const u8) void {
    var wide: [4096:0]u16 = [_:0]u16{0} ** 4096;
    const count = @min(message.len, wide.len - 1);
    for (message[0..count], 0..) |byte, index| wide[index] = byte;
    _ = MessageBoxW(
        null,
        &wide,
        std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY Session Sharing"),
        0x40,
    );
}

fn showWindowsPeers(store: *const Share.identity.Store) void {
    if (store.peer_count == 0) {
        showWindowsMessage("No paired devices.");
        return;
    }
    var text: [4096]u8 = undefined;
    var length: usize = 0;
    const heading = "Paired devices:\r\n";
    @memcpy(text[0..heading.len], heading);
    length = heading.len;
    for (store.peerSliceConst(), 0..) |peer, index| {
        const line = std.fmt.bufPrint(
            text[length..],
            "{d}: {s} - {s}:{d}{s}\r\n",
            .{
                index,
                peer.alias(),
                peer.endpoint(),
                peer.port,
                if (peer.revoked) " (revoked)" else "",
            },
        ) catch break;
        length += line.len;
    }
    showWindowsMessage(text[0..length]);
}

fn confirmWindowsSas(sas: u32) bool {
    var message: [128]u8 = undefined;
    const text = std.fmt.bufPrint(
        &message,
        "Compare this code on both devices: {d:0>6}. Confirm only if identical.",
        .{sas},
    ) catch return false;
    var wide: [128:0]u16 = [_:0]u16{0} ** 128;
    for (text, 0..) |byte, index| wide[index] = byte;
    return MessageBoxW(
        null,
        &wide,
        std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY Pairing"),
        0x34,
    ) == 6;
}
fn runDiscovery() c_int {
    var discovery = Share.transport.Discovery.open() catch {
        showWindowsMessage("Could not start LAN discovery.");
        return 1;
    };
    defer discovery.close();
    var packet: [Share.transport.max_discovery_bytes]u8 = undefined;
    var source: [64]u8 = undefined;
    for (0..750) |_| {
        if (!(discovery.readable(20) catch false)) continue;
        const found = discovery.receive(&packet, &source) catch continue;
        if (!found.announcement.accepts_sessions) continue;
        var message: [512]u8 = undefined;
        const text = std.fmt.bufPrint(
            &message,
            "Untrusted LAN hint: {s} at {s}:{d}.\r\nUse --pair-connect {s} {d} ALIAS, then trust only if the six-digit code matches.",
            .{
                found.announcement.alias,
                found.source,
                found.announcement.tcp_port,
                found.source,
                found.announcement.tcp_port,
            },
        ) catch return 1;
        showWindowsMessage(text);
        return 0;
    }
    showWindowsMessage("No pairing listener was discovered on this LAN. Use a direct endpoint for tailnets and routed VPNs.");
    return 1;
}

fn runPairing(store: *Share.identity.Store, random: Crypto.RandomContext, mode: ShareMode) c_int {
    const controller = switch (mode.kind) {
        .pair_listen => Share.pair_controller.Controller.listen(
            std.heap.page_allocator,
            random,
            store.identity,
            null,
            mode.port,
            mode.aliasSlice(),
            mode.hostSlice(),
            mode.port,
        ),
        .pair_connect => Share.pair_controller.Controller.connect(
            std.heap.page_allocator,
            random,
            store.identity,
            mode.hostSlice(),
            mode.port,
            mode.aliasSlice(),
        ),
        else => return 1,
    } catch {
        showWindowsMessage("Could not start pairing. Check the endpoint and port.");
        return 1;
    };
    defer controller.destroy();
    var announcement: ?Share.transport.Discovery = if (mode.kind == .pair_listen)
        Share.transport.Discovery.open() catch null
    else
        null;
    defer if (announcement) |*active| active.close();
    var announcement_instance: [16]u8 = undefined;
    if (announcement != null) {
        var ephemeral = Crypto.Identity.generate(random);
        defer ephemeral.deinit();
        announcement_instance = ephemeral.public_key[0..16].*;
    }
    for (0..3000) |attempt| {
        const status = controller.statusSnapshot();
        if (status == .sas_ready or status == .failed or status == .rejected) break;
        if (announcement) |*active| {
            if (attempt % 100 == 0) active.announce(.{
                .instance_id = announcement_instance,
                .tcp_port = controller.listeningPort(),
                .accepts_sessions = true,
                .alias = "NOCTTY Windows pairing listener",
            }) catch {
                active.close();
                announcement = null;
            };
        }
        Share.transport.sleepMilliseconds(random, 20);
    }
    if (controller.statusSnapshot() != .sas_ready) {
        showWindowsMessage("Pairing timed out or failed.");
        return 1;
    }
    if (!confirmWindowsSas(controller.sas())) {
        controller.reject();
        return 1;
    }
    controller.confirm();
    for (0..3000) |_| {
        const status = controller.statusSnapshot();
        if (status == .paired or status == .failed or status == .rejected) break;
        Share.transport.sleepMilliseconds(random, 20);
    }
    const peer = controller.takePeer() orelse {
        showWindowsMessage("Pairing confirmation failed.");
        return 1;
    };
    store.addOrUpdate(peer) catch {
        showWindowsMessage(
            "Could not retain the paired device. Revoke an unused device and " ++
                "try again.",
        );
        return 1;
    };
    saveStore(store) catch {
        showWindowsMessage(
            "The pairing handshake succeeded, but Windows could not save the " ++
                "device. Check profile-storage permissions and pair again.",
        );
        return 1;
    };
    showWindowsMessage("Paired device saved. Use --share 0 PORT or --receive 0.");
    return 0;
}

fn confirmWindowsControl() bool {
    return MessageBoxW(
        null,
        std.unicode.utf8ToUtf16LeStringLiteral(
            "The paired viewer requests terminal control for one shared pane on this connection. Grant it?",
        ),
        std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY Remote Control"),
        0x34,
    ) == 6;
}

fn localWrite(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const viewer = state.live_viewer orelse return 0;
    viewer.sendInput(bytes[0..length]) catch |err| {
        if (err == error.ShareInputNotGranted and viewer.currentStatus() == .connected)
            viewer.requestControl() catch return -1;
        return 0;
    };
    return std.math.cast(c_int, length) orelse -1;
}

fn localStart(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    return @intFromBool(state.live_viewer != null);
}

fn localStop(_: ?*anyopaque) callconv(.c) c_int {
    return 0;
}

fn stateFromRaw(raw: ?*anyopaque) ?*State {
    return @ptrCast(@alignCast(raw orelse return null));
}
const RemoteInputSink = struct {
    output: []u8,
    length: usize = 0,

    pub fn write(self: *RemoteInputSink, bytes: []const u8) !void {
        if (self.length + bytes.len > self.output.len) return error.RemoteInputBufferFull;
        @memcpy(self.output[self.length .. self.length + bytes.len], bytes);
        self.length += bytes.len;
    }
};

fn feed(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const grid = state.workspace.activeGrid() orelse return -1;
    if (length > 2 * 1024 * 1024) return -1;
    grid.feed(bytes[0..length]) catch return -1;
    if (state.live_host) |host| {
        if (state.shared_pane == state.workspace.activePaneIndex())
            host.captureGrid(1, grid) catch return -1;
    }
    return std.math.cast(c_int, length) orelse -1;
}

fn takeReply(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    if (capacity == 0) return 0;
    const grid = state.workspace.activeGrid() orelse return -1;
    const pending = grid.pendingReplies();
    const count = @min(pending.len, capacity);
    @memcpy(output[0..count], pending[0..count]);
    grid.consumeReplies(count);
    return std.math.cast(c_int, count) orelse -1;
}

fn paneFeed(
    raw: ?*anyopaque,
    index_raw: c_int,
    bytes: [*]const u8,
    length: usize,
) callconv(.c) c_int {
    if (index_raw < 0 or length > 2 * 1024 * 1024) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const pane_index: usize = @intCast(index_raw);
    const grid = state.workspace.paneGrid(pane_index) orelse return -1;
    grid.feed(bytes[0..length]) catch return -1;
    if (state.shared_pane == pane_index) {
        if (state.live_host) |host| host.captureGrid(1, grid) catch return -1;
    }
    return std.math.cast(c_int, length) orelse -1;
}

fn paneTakeReply(
    raw: ?*anyopaque,
    index_raw: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    if (index_raw < 0 or capacity == 0) return 0;
    const state = stateFromRaw(raw) orelse return -1;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return -1;
    const pending = grid.pendingReplies();
    const count = @min(pending.len, capacity);
    @memcpy(output[0..count], pending[0..count]);
    grid.consumeReplies(count);
    return std.math.cast(c_int, count) orelse -1;
}

fn paneResize(
    raw: ?*anyopaque,
    index_raw: c_int,
    columns: c_int,
    rows: c_int,
) callconv(.c) c_int {
    if (index_raw < 0 or columns < 1 or rows < 1) return -1;
    if (columns > 1000 or rows > 500) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return -1;
    grid.resize(@intCast(columns), @intCast(rows)) catch return -1;
    return 0;
}

fn workspaceAction(
    raw: ?*anyopaque,
    action: c_int,
    columns: c_int,
    rows: c_int,
) callconv(.c) c_int {
    if (columns < 1 or rows < 1 or columns > 1000 or rows > 500) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    const pane_index = switch (action) {
        1 => state.workspace.newTab(@intCast(columns), @intCast(rows)),
        2 => state.workspace.splitActive(
            .vertical,
            false,
            @intCast(columns),
            @intCast(rows),
        ),
        3 => state.workspace.splitActive(
            .horizontal,
            true,
            @intCast(columns),
            @intCast(rows),
        ),
        else => return -1,
    } catch return -1;
    return std.math.cast(c_int, pane_index + 1) orelse -1;
}

fn activePane(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer|
        return std.math.cast(c_int, viewer.selectedIndex()) orelse -1;
    const pane_index = state.workspace.activePaneIndex() orelse return -1;
    return std.math.cast(c_int, pane_index) orelse -1;
}

fn remotePane(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const pane_index = state.shared_pane orelse return -1;
    return std.math.cast(c_int, pane_index) orelse -1;
}

fn workspaceClose(raw: ?*anyopaque, action: c_int) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0;
    if (state.live_viewer != null) return 0;
    const result: u32 = switch (action) {
        1 => if (state.workspace.closeActivePane()) |pane_index|
            @as(u32, 1) << @intCast(pane_index)
        else
            0,
        2 => state.workspace.closeActiveTab(),
        3 => if (state.workspace.paneTotal() > 1)
            @as(u32, 1) << @intCast(state.workspace.activePaneIndex() orelse return 0)
        else
            0,
        4 => state.workspace.activeTabMask(),
        else => 0,
    };
    if ((action == 3 or action == 4) and result != 0) {
        if (state.shared_pane) |pane_index| {
            if ((result & (@as(u32, 1) << @intCast(pane_index))) != 0) {
                if (state.live_host) |host| host.destroy();
                state.live_host = null;
                state.shared_pane = null;
            }
        }
    }
    return result;
}

fn preferenceGet(raw: ?*anyopaque, field: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    return switch (field) {
        1 => @intFromEnum(state.preferences.theme),
        2 => state.preferences.font_size_pt,
        3 => @intFromEnum(state.preferences.launch_profile),
        4 => @intFromBool(state.preferences.restore_workspace),
        else => -1,
    };
}

fn preferenceSet(
    raw: ?*anyopaque,
    field: c_int,
    value: c_int,
) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const previous = state.preferences;
    switch (field) {
        1 => state.preferences.theme = switch (value) {
            0 => .dark,
            1 => .high_contrast,
            else => return -1,
        },
        2 => {
            if (value < 10 or value > 24) return -1;
            state.preferences.font_size_pt = @intCast(value);
        },
        3 => state.preferences.launch_profile = switch (value) {
            0 => .powershell,
            1 => .command_prompt,
            else => return -1,
        },
        4 => state.preferences.restore_workspace = switch (value) {
            0 => false,
            1 => true,
            else => return -1,
        },
        else => return -1,
    }
    writePersistedWindowsState(state) catch {
        state.preferences = previous;
        return -1;
    };
    return 0;
}

fn workspacePersistence(
    raw: ?*anyopaque,
    action: c_int,
    columns: c_int,
    rows: c_int,
) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_host != null or state.live_viewer != null) return 0;
    switch (action) {
        1 => {
            const previous = state.saved_workspace;
            state.saved_workspace = state.workspace.snapshot();
            writePersistedWindowsState(state) catch {
                state.saved_workspace = previous;
                return -1;
            };
            return 1;
        },
        2 => {
            if (columns < 1 or rows < 1 or columns > 1000 or rows > 500)
                return -1;
            const snapshot_value = state.saved_workspace orelse return 0;
            state.workspace.restore(
                snapshot_value,
                @intCast(columns),
                @intCast(rows),
            ) catch return -1;
            return 1;
        },
        else => return -1,
    }
}

fn takeRemote(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const host = state.live_host orelse return 0;
    if (state.shared_pane) |pane_index| {
        const grid = state.workspace.paneGrid(pane_index) orelse return 0;
        host.captureGrid(1, grid) catch return -1;
    }
    if (host.currentStatus() == .control_requested) {
        if (confirmWindowsControl())
            host.grantControl()
        else
            host.revokeControl();
    }
    var sink = RemoteInputSink{ .output = output[0..capacity] };
    _ = host.drainInput(1, &sink) catch return -1;
    return std.math.cast(c_int, sink.length) orelse -1;
}

fn cell(raw: ?*anyopaque, column: c_int, row: c_int) callconv(.c) u64 {
    const state = stateFromRaw(raw) orelse return ' ';
    if (column < 0 or row < 0) return ' ';
    if (state.live_viewer) |viewer|
        return viewer.packedCell(@intCast(column), @intCast(row));
    const grid = state.workspace.activeGrid() orelse return ' ';
    return grid.packedCell(@intCast(column), @intCast(row));
}

fn cellText(
    raw: ?*anyopaque,
    column: c_int,
    row: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (column < 0 or row < 0 or capacity == 0) return 0;
    if (state.live_viewer) |viewer|
        return std.math.cast(c_int, viewer.cellText(
            @intCast(column),
            @intCast(row),
            output[0..capacity],
        )) orelse -1;
    const grid = state.workspace.activeGrid() orelse return -1;
    const count = grid.cellText(
        @intCast(column),
        @intCast(row),
        output[0..capacity],
    );
    return std.math.cast(c_int, count) orelse -1;
}

fn colorRgb(raw: ?*anyopaque, color_id: u32) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (color_id > std.math.maxInt(u16)) return 0xffffffff;
    if (state.live_viewer) |viewer| return viewer.colorRgb(@intCast(color_id));
    const grid = state.workspace.activeGrid() orelse return 0xffffffff;
    return grid.colorRgb(@intCast(color_id));
}

fn cursor(raw: ?*anyopaque) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (state.live_viewer) |viewer| return viewer.cursor();
    const grid = state.workspace.activeGrid() orelse return 0xffffffff;
    if (!grid.cursor_visible) return 0xffffffff;
    if (grid.cursor_row > std.math.maxInt(u16)) return 0xffffffff;
    if (grid.cursor_column > std.math.maxInt(u16)) return 0xffffffff;
    return (@as(u32, @intCast(grid.cursor_row)) << 16) |
        @as(u32, @intCast(grid.cursor_column));
}

fn title(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        const selected = viewer.streamInfo(viewer.selectedIndex(), &.{}) orelse return 0;
        const scope_label = switch (viewer.shareScope()) {
            .pane => "Pane share · ",
            .tab => "Tab share · ",
            .session => "Session share · ",
        };
        const scope_count = @min(scope_label.len, capacity);
        @memcpy(output[0..scope_count], scope_label[0..scope_count]);
        var count = scope_count;
        var tab_title: [Share.protocol.max_title_bytes]u8 = undefined;
        for (0..viewer.tabCount()) |index| {
            const tab = viewer.tabInfo(index, &tab_title) orelse continue;
            if (tab.tab_id != selected.tab_id) continue;
            const copied = @min(tab.title_length, capacity - count);
            @memcpy(output[count .. count + copied], tab_title[0..copied]);
            count += copied;
        }
        if (count != 0 and count < capacity) {
            const separator = " — ";
            const copied = @min(separator.len, capacity - count);
            @memcpy(output[count .. count + copied], separator[0..copied]);
            count += copied;
        }
        if (count < capacity) count += viewer.title(output[count..capacity]);
        return std.math.cast(c_int, count) orelse -1;
    }
    const grid = state.workspace.activeGrid() orelse return 0;
    var count: usize = 0;
    const pane_count = state.workspace.activeTabPaneCount();
    if (state.workspace.tab_count > 1 or pane_count > 1) {
        var prefix_buffer: [96]u8 = undefined;
        const prefix = std.fmt.bufPrint(
            &prefix_buffer,
            "Tab {d}/{d} · {d} {s} — ",
            .{
                state.workspace.active_tab + 1,
                state.workspace.tab_count,
                pane_count,
                if (pane_count == 1) "pane" else "panes",
            },
        ) catch return -1;
        count = @min(prefix.len, capacity);
        @memcpy(output[0..count], prefix[0..count]);
    }
    const value = grid.titleSlice();
    const title_count = @min(value.len, capacity - count);
    @memcpy(output[count .. count + title_count], value[0..title_count]);
    return std.math.cast(c_int, count + title_count) orelse -1;
}

fn resize(raw: ?*anyopaque, columns: c_int, rows: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    if (columns < 1 or rows < 1) return -1;
    if (columns > 1000 or rows > 500) return -1;
    const grid = state.workspace.activeGrid() orelse return -1;
    grid.resize(@intCast(columns), @intCast(rows)) catch return -1;
    return 0;
}

fn scroll(raw: ?*anyopaque, lines: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        viewer.scrollViewport(lines) catch return -1;
        return 0;
    }
    const grid = state.workspace.activeGrid() orelse return -1;
    grid.scrollViewport(lines);
    return 0;
}

fn cursorMode(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return 0;
    if (state.live_viewer) |viewer|
        return @intFromBool(viewer.applicationCursorKeys());
    const grid = state.workspace.activeGrid() orelse return 0;
    return @intFromBool(grid.application_cursor_keys);
}

fn paneCount(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer|
        return std.math.cast(c_int, viewer.streamCount()) orelse -1;
    return std.math.cast(c_int, state.workspace.highestPaneIndex()) orelse -1;
}

fn paneLayout(
    raw: ?*anyopaque,
    index_raw: c_int,
    x_output: *u32,
    y_output: *u32,
    width_output: *u32,
    height_output: *u32,
    selected_output: *c_int,
    host_active_output: *c_int,
) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        const layout = viewer.paneLayout(@intCast(index_raw)) orelse return -1;
        x_output.* = layout.x;
        y_output.* = layout.y;
        width_output.* = layout.width;
        height_output.* = layout.height;
        selected_output.* = @intFromBool(layout.selected);
        host_active_output.* = @intFromBool(layout.host_active);
        return @intFromBool(layout.visible);
    }
    const pane_index: usize = @intCast(index_raw);
    const rectangle = state.workspace.paneRect(pane_index) orelse return 0;
    x_output.* = rectangle.x;
    y_output.* = rectangle.y;
    width_output.* = rectangle.width;
    height_output.* = rectangle.height;
    const active = state.workspace.activePaneIndex() == pane_index;
    selected_output.* = @intFromBool(active);
    host_active_output.* = @intFromBool(active);
    return 1;
}

fn paneDimensions(
    raw: ?*anyopaque,
    index_raw: c_int,
    columns_output: *u16,
    rows_output: *u16,
) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        const dimensions = viewer.streamDimensions(@intCast(index_raw));
        columns_output.* = dimensions.columns;
        rows_output.* = dimensions.rows;
        return @intFromBool(dimensions.columns != 0 and dimensions.rows != 0);
    }
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0;
    columns_output.* = std.math.cast(u16, grid.columns) orelse return -1;
    rows_output.* = std.math.cast(u16, grid.rows) orelse return -1;
    return 1;
}

fn paneCell(
    raw: ?*anyopaque,
    index_raw: c_int,
    column: c_int,
    row: c_int,
) callconv(.c) u64 {
    if (index_raw < 0 or column < 0 or row < 0) return ' ';
    const state = stateFromRaw(raw) orelse return ' ';
    if (state.live_viewer) |viewer|
        return viewer.streamPackedCell(@intCast(index_raw), @intCast(column), @intCast(row));
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return ' ';
    return grid.packedCell(@intCast(column), @intCast(row));
}

fn paneCellText(
    raw: ?*anyopaque,
    index_raw: c_int,
    column: c_int,
    row: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    if (index_raw < 0 or column < 0 or row < 0 or capacity == 0) return 0;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer|
        return std.math.cast(c_int, viewer.streamCellText(
            @intCast(index_raw),
            @intCast(column),
            @intCast(row),
            output[0..capacity],
        )) orelse -1;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0;
    return std.math.cast(c_int, grid.cellText(
        @intCast(column),
        @intCast(row),
        output[0..capacity],
    )) orelse -1;
}

fn paneColorRgb(raw: ?*anyopaque, index_raw: c_int, color_id: u32) callconv(.c) u32 {
    if (index_raw < 0 or color_id > std.math.maxInt(u16)) return 0xffffffff;
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (state.live_viewer) |viewer|
        return viewer.streamColorRgb(@intCast(index_raw), @intCast(color_id));
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0xffffffff;
    return grid.colorRgb(@intCast(color_id));
}

fn paneCursor(raw: ?*anyopaque, index_raw: c_int) callconv(.c) u32 {
    if (index_raw < 0) return 0xffffffff;
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (state.live_viewer) |viewer| return viewer.streamCursor(@intCast(index_raw));
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0xffffffff;
    if (!grid.cursor_visible or grid.cursor_row > std.math.maxInt(u16) or
        grid.cursor_column > std.math.maxInt(u16)) return 0xffffffff;
    return (@as(u32, @intCast(grid.cursor_row)) << 16) |
        @as(u32, @intCast(grid.cursor_column));
}

fn paneMouseMode(raw: ?*anyopaque, index_raw: c_int) callconv(.c) u32 {
    if (index_raw < 0) return 0;
    const state = stateFromRaw(raw) orelse return 0;
    if (state.live_viewer != null) return 0;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0;
    return grid.mouseModeBits();
}

fn paneMouseEncode(
    raw: ?*anyopaque,
    index_raw: c_int,
    column: c_int,
    row: c_int,
    button: c_int,
    kind_raw: c_int,
    modifiers: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    if (index_raw < 0 or column < 0 or row < 0 or button < 0 or
        button > std.math.maxInt(u8)) return -1;
    const kind: Vt.MouseEventKind = switch (kind_raw) {
        0 => .press,
        1 => .release,
        2 => .motion,
        3 => .wheel,
        else => return -1,
    };
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return -1;
    const length = grid.encodeMouse(.{
        .column = @intCast(column),
        .row = @intCast(row),
        .button = @intCast(button),
        .kind = kind,
        .modifiers = .{
            .shift = modifiers & 1 != 0,
            .alt = modifiers & 2 != 0,
            .control = modifiers & 4 != 0,
        },
    }, output[0..capacity]) orelse return 0;
    return std.math.cast(c_int, length) orelse -1;
}

fn paneCopy(
    raw: ?*anyopaque,
    index_raw: c_int,
    output: [*]u8,
    capacity: usize,
    start_column: c_int,
    start_row: c_int,
    end_column: c_int,
    end_row: c_int,
) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const selected = start_column >= 0 and start_row >= 0 and
        end_column >= 0 and end_row >= 0;
    const range: ?Vt.SelectionRange = if (selected) .{
        .start_column = @intCast(start_column),
        .start_row = @intCast(start_row),
        .end_column = @intCast(end_column),
        .end_row = @intCast(end_row),
    } else null;
    const length = if (state.live_viewer) |viewer|
        viewer.copyStreamSelection(
            @intCast(index_raw),
            output[0..capacity],
            range,
        ) orelse return -1
    else blk: {
        const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse
            return -1;
        break :blk grid.copySelection(output[0..capacity], range) orelse
            return -1;
    };
    return std.math.cast(c_int, length) orelse -1;
}
fn paneSelect(raw: ?*anyopaque, index_raw: c_int) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        viewer.selectStream(@intCast(index_raw)) catch return -1;
        return 0;
    }
    return if (state.workspace.selectPane(@intCast(index_raw))) 0 else -1;
}

fn nextStream(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        const count = viewer.streamCount();
        if (count < 2) return 0;
        const selected_index = viewer.selectedIndex();
        const selected = viewer.streamInfo(selected_index, &.{}) orelse return -1;
        for (1..count) |offset| {
            const next = (selected_index + offset) % count;
            const candidate = viewer.streamInfo(next, &.{}) orelse continue;
            if (candidate.tab_id != selected.tab_id) continue;
            viewer.selectStream(next) catch return -1;
            return std.math.cast(c_int, next + 1) orelse -1;
        }
        return 0;
    }
    return @intFromBool(state.workspace.nextPane());
}

fn nextTab(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        const count = viewer.tabCount();
        if (count < 2) return 0;
        const selected = viewer.streamInfo(viewer.selectedIndex(), &.{}) orelse return -1;
        for (0..count) |index| {
            const tab = viewer.tabInfo(index, &.{}) orelse continue;
            if (tab.tab_id != selected.tab_id) continue;
            const next = (index + 1) % count;
            viewer.selectTab(next) catch return -1;
            return std.math.cast(c_int, next + 1) orelse -1;
        }
        return -1;
    }
    return @intFromBool(state.workspace.nextTab());
}

fn smokeReady(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return 0;
    const grid = state.workspace.activeGrid() orelse return 0;
    const marker = grid.findText(
        "NOCTTY_WINDOWS_HOST_OK",
        false,
        0,
    );
    return @intFromBool(marker != null);
}

fn firstAsciiTokenIs(command: []const u16, expected: []const u8) bool {
    var cursor_index: usize = 0;
    var token_buffer: [256]u8 = undefined;
    const token = nextAsciiToken(
        command,
        &cursor_index,
        &token_buffer,
    ) catch return false;
    return std.mem.eql(u8, token, expected);
}

fn selfTest(state: *State) bool {
    if (!firstAsciiTokenIs(
        std.unicode.utf8ToUtf16LeStringLiteral("--self-test"),
        "--self-test",
    )) return false;
    if (firstAsciiTokenIs(
        std.unicode.utf8ToUtf16LeStringLiteral("device--self-test-backup"),
        "--self-test",
    )) return false;
    const grid = state.workspace.activeGrid() orelse return false;
    grid.feed("\x1b[2J\x1b[3;4H\x1b[1;38;2;143;184;255mWIN_OK") catch
        return false;
    const first = grid.cell(3, 2);
    const last = grid.cell(8, 2);
    if (first.codepoint != 'W' or last.codepoint != 'K') return false;
    if (!first.flags.bold) return false;
    if (grid.colorRgb(first.foreground) != 0x8fb8ff) return false;
    grid.feed("\r\nNOCTTY_WINDOWS_HOST_OK\r\n") catch return false;
    if (smokeReady(state) != 1) return false;

    const lower = state.workspace.splitActive(
        .vertical,
        false,
        columns_initial,
        rows_initial,
    ) catch return false;
    if (lower != 1 or state.workspace.activePaneIndex() != 1) return false;
    const upper_rect = state.workspace.paneRect(0) orelse return false;
    const lower_rect = state.workspace.paneRect(1) orelse return false;
    if (upper_rect.y != 0 or upper_rect.height != 500_000) return false;
    if (lower_rect.y != 500_000 or lower_rect.height != 500_000) return false;

    const lower_left = state.workspace.splitActive(
        .horizontal,
        true,
        columns_initial,
        rows_initial,
    ) catch return false;
    if (lower_left != 2 or state.workspace.activePaneIndex() != 2) return false;
    const left_rect = state.workspace.paneRect(2) orelse return false;
    const right_rect = state.workspace.paneRect(1) orelse return false;
    if (left_rect.x != 0 or left_rect.y != 500_000 or
        left_rect.width != 500_000 or left_rect.height != 500_000) return false;
    if (right_rect.x != 500_000 or right_rect.y != 500_000 or
        right_rect.width != 500_000 or right_rect.height != 500_000) return false;

    const input_grid = state.workspace.paneGrid(0) orelse return false;
    input_grid.feed(
        "\x1b[?1002h\x1b[?1006h\x1b[2J\x1b[HAe\u{301}  \r\n中Z  ",
    ) catch return false;
    if (paneMouseMode(state, 0) != 0x102) return false;
    var mouse_buffer: [64]u8 = undefined;
    const mouse_length = paneMouseEncode(
        state,
        0,
        1,
        1,
        0,
        2,
        4,
        &mouse_buffer,
        mouse_buffer.len,
    );
    if (mouse_length <= 0 or !std.mem.eql(
        u8,
        mouse_buffer[0..@intCast(mouse_length)],
        "\x1b[<48;2;2M",
    )) return false;
    if (paneMouseEncode(
        state,
        0,
        1,
        1,
        3,
        2,
        0,
        &mouse_buffer,
        mouse_buffer.len,
    ) != 0) return false;
    var copy_buffer: [64]u8 = undefined;
    const copied = paneCopy(
        state,
        0,
        &copy_buffer,
        copy_buffer.len,
        7,
        1,
        0,
        0,
    );
    if (copied <= 0 or !std.mem.eql(
        u8,
        copy_buffer[0..@intCast(copied)],
        "Ae\u{301}\n中Z",
    )) return false;

    const second_tab = state.workspace.newTab(
        columns_initial,
        rows_initial,
    ) catch return false;
    if (second_tab != 3 or state.workspace.tab_count != 2) return false;
    if (!state.workspace.nextTab() or state.workspace.active_tab != 0) return false;
    if (!state.workspace.nextPane() or state.workspace.activePaneIndex() != 0)
        return false;
    var title_buffer: [128]u8 = undefined;
    const title_length = title(state, &title_buffer, title_buffer.len);
    if (title_length <= 0) return false;
    if (std.mem.indexOf(
        u8,
        title_buffer[0..@intCast(title_length)],
        "Tab 1/2",
    ) == null) return false;

    const snapshot_value = state.workspace.snapshot();
    var encoded: [persisted_state_capacity]u8 = undefined;
    const encoded_length = encodePersistedWindowsState(.{
        .preferences = .{
            .theme = .high_contrast,
            .font_size_pt = 16,
            .launch_profile = .command_prompt,
            .restore_workspace = true,
        },
        .workspace = snapshot_value,
    }, &encoded) catch return false;
    const decoded = decodePersistedWindowsState(encoded[0..encoded_length]) catch
        return false;
    if (decoded.preferences.theme != .high_contrast or
        decoded.preferences.font_size_pt != 16 or
        decoded.preferences.launch_profile != .command_prompt or
        !decoded.preferences.restore_workspace)
        return false;
    var restored = WindowsWorkspace.init(
        state.workspace.allocator,
        columns_initial,
        rows_initial,
    ) catch return false;
    defer restored.deinit();
    restored.restore(
        decoded.workspace orelse return false,
        columns_initial,
        rows_initial,
    ) catch return false;
    if (restored.tab_count != 2 or restored.paneTotal() != 4 or
        restored.active_tab != 0 or restored.activePaneIndex() != 0)
        return false;
    encoded[encoded_length - 1] ^= 1;
    if (decodePersistedWindowsState(encoded[0..encoded_length])) |_| {
        return false;
    } else |_| {}
    if (state.workspace.closeActivePane() != 0) return false;
    if (state.workspace.paneTotal() != 3 or
        state.workspace.activePaneIndex() != 2) return false;
    if (state.workspace.closeActiveTab() != 0b110) return false;
    return state.workspace.tab_count == 1 and
        state.workspace.paneTotal() == 1 and
        state.workspace.activePaneIndex() == 3;
}
