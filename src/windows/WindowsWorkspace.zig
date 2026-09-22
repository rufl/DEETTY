//! Bounded native Windows workspace and versioned persistence; no Win32 dependencies.

const std = @import("std");
const Vt = @import("noctty_share").vt;
const SplitRatio = @import("noctty_share").split_ratio;
const WindowsAppearance = @import("WindowsAppearance.zig");

const max_tabs: usize = 16;
pub const max_panes: usize = 32;
const max_layout_nodes: usize = max_panes * 2 - 1;
const invalid_index: u8 = std.math.maxInt(u8);
pub const max_tab_name_bytes = 128;

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
    ratio_permille: u16 = 500,
};

const WorkspacePane = struct {
    grid: *Vt.Grid,
    tab: u8,
    node: u8,
    tag_mask: u8 = 0,
};

const WorkspaceTab = struct {
    used: bool = false,
    root: u8 = invalid_index,
    active_pane: u8 = invalid_index,
    /// Stable automatic label, independent of visual position and pane reuse.
    label: u8 = 0,
    name_length: u8 = 0,
    name: [max_tab_name_bytes]u8 = [_]u8{0} ** max_tab_name_bytes,
};

const PaneRect = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

pub const Divider = struct {
    node: usize,
    axis: u1,
    rectangle: PaneRect,
    ratio_permille: u16,
};

const WindowsTheme = enum(u8) {
    dark,
    high_contrast,
    paseo_black_zinc,
};

const WindowsLaunchProfile = enum(u8) {
    powershell,
    command_prompt,
};

pub const WindowsPreferences = struct {
    theme: WindowsTheme = .dark,
    font_size_pt: u8 = 13,
    launch_profile: WindowsLaunchProfile = .powershell,
    restore_workspace: bool = true,
};

const SnapshotPane = struct {
    used: bool = false,
    tab: u8 = invalid_index,
    node: u8 = invalid_index,
    tag_mask: u8 = 0,
};

pub const WorkspaceSnapshot = struct {
    panes: [max_panes]SnapshotPane = [_]SnapshotPane{.{}} ** max_panes,
    nodes: [max_layout_nodes]LayoutNode = [_]LayoutNode{.{}} ** max_layout_nodes,
    tabs: [max_tabs]WorkspaceTab = [_]WorkspaceTab{.{}} ** max_tabs,
    tab_count: u8 = 0,
    active_tab: u8 = 0,
};

pub const PersistedWindowsState = struct {
    preferences: WindowsPreferences = .{},
    workspace: ?WorkspaceSnapshot = null,
};

pub const WindowsWorkspace = struct {
    allocator: std.mem.Allocator,
    panes: [max_panes]?WorkspacePane = [_]?WorkspacePane{null} ** max_panes,
    nodes: [max_layout_nodes]LayoutNode = [_]LayoutNode{.{}} ** max_layout_nodes,
    tabs: [max_tabs]WorkspaceTab = [_]WorkspaceTab{.{}} ** max_tabs,
    tab_count: usize = 0,
    active_tab: usize = 0,
    /// Volatile view query; tags remain persisted, filter resets on restart.
    smart_filter_mask: u8 = 0,

    pub fn init(allocator: std.mem.Allocator, columns: usize, rows: usize) !WindowsWorkspace {
        var workspace = WindowsWorkspace{ .allocator = allocator };
        errdefer workspace.deinit();
        _ = try workspace.newTab(columns, rows);
        return workspace;
    }

    pub fn deinit(self: *WindowsWorkspace) void {
        for (&self.panes) |*pane_slot| {
            if (pane_slot.*) |pane| {
                pane.grid.deinit();
                self.allocator.destroy(pane.grid);
                pane_slot.* = null;
            }
        }
    }

    pub fn activePaneIndex(self: *const WindowsWorkspace) ?usize {
        if (self.tab_count == 0 or self.active_tab >= self.tab_count) return null;
        const index = self.tabs[self.active_tab].active_pane;
        return if (index == invalid_index) null else index;
    }

    pub fn activeGrid(self: *WindowsWorkspace) ?*Vt.Grid {
        const index = self.activePaneIndex() orelse return null;
        return if (self.panes[index]) |pane| pane.grid else null;
    }

    pub fn paneGrid(self: *WindowsWorkspace, index: usize) ?*Vt.Grid {
        if (index >= self.panes.len) return null;
        return if (self.panes[index]) |pane| pane.grid else null;
    }

    pub fn paneTagMask(self: *const WindowsWorkspace, index: usize) ?u8 {
        if (index >= self.panes.len) return null;
        return if (self.panes[index]) |pane| pane.tag_mask else null;
    }

    pub fn setPaneTagMask(self: *WindowsWorkspace, index: usize, tag_mask: u8) !bool {
        if (index >= self.panes.len or self.panes[index] == null)
            return error.InvalidWindowsPane;
        if (self.panes[index].?.tag_mask == tag_mask) return false;
        self.panes[index].?.tag_mask = tag_mask;
        return true;
    }

    pub fn paneMatchesTag(self: *const WindowsWorkspace, index: usize, filter_mask: u8) bool {
        const pane_tags = self.paneTagMask(index) orelse return false;
        return filter_mask == 0 or (pane_tags & filter_mask) != 0;
    }

    pub fn smartFilterMask(self: *const WindowsWorkspace) u8 {
        return self.smart_filter_mask;
    }

    pub fn setSmartFilterMask(self: *WindowsWorkspace, filter_mask: u8) bool {
        if (self.smart_filter_mask == filter_mask) return false;
        if (filter_mask != 0) {
            var has_match = false;
            for (self.panes, 0..) |pane_slot, index| {
                const pane = pane_slot orelse continue;
                if (pane.tab == self.active_tab and self.paneMatchesTag(index, filter_mask)) {
                    has_match = true;
                    break;
                }
            }
            if (!has_match) return false;
        }
        self.smart_filter_mask = filter_mask;
        if (filter_mask != 0 and !self.paneMatchesTag(self.activePaneIndex() orelse 0, filter_mask)) {
            for (self.panes, 0..) |pane_slot, index| {
                const pane = pane_slot orelse continue;
                if (pane.tab == self.active_tab and self.paneMatchesTag(index, filter_mask)) {
                    self.tabs[self.active_tab].active_pane = @intCast(index);
                    break;
                }
            }
        }
        return true;
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

    pub fn newTab(self: *WindowsWorkspace, columns: usize, rows: usize) !usize {
        if (self.tab_count >= self.tabs.len) return error.WindowsTabLimit;
        const tab_index = self.tab_count;
        const pane_index = try self.allocatePane(tab_index, columns, rows);
        const pane = self.panes[pane_index].?;
        var labels = [_]bool{false} ** (max_tabs + 1);
        for (self.tabs[0..self.tab_count]) |tab| labels[tab.label] = true;
        const label = for (1..labels.len) |index| {
            if (!labels[index]) break index;
        } else unreachable;
        self.tabs[tab_index] = .{
            .used = true,
            .root = pane.node,
            .active_pane = @intCast(pane_index),
            .label = @intCast(label),
        };
        self.tab_count += 1;
        self.active_tab = tab_index;
        return pane_index;
    }

    pub fn splitActive(
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

    pub fn selectPane(self: *WindowsWorkspace, pane_index: usize) bool {
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

    pub fn nextPane(self: *WindowsWorkspace) bool {
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

    pub fn selectTab(self: *WindowsWorkspace, index: usize) !bool {
        if (index >= self.tab_count) return error.InvalidWindowsTab;
        if (index == self.active_tab) return false;
        self.active_tab = index;
        return true;
    }

    pub fn renameTab(self: *WindowsWorkspace, index: usize, name: []const u8) !bool {
        if (index >= self.tab_count) return error.InvalidWindowsTab;
        try validateTabName(name);
        const tab = &self.tabs[index];
        if (std.mem.eql(u8, tab.name[0..tab.name_length], name)) return false;
        std.mem.copyForwards(u8, tab.name[0..name.len], name);
        @memset(tab.name[name.len..], 0);
        tab.name_length = @intCast(name.len);
        return true;
    }

    /// Only tab records and pane ownership indices move. Grid pointers, pane
    /// slots (and therefore ConPTY slots), split trees and pane focus survive.
    pub fn moveTab(self: *WindowsWorkspace, from: usize, to: usize) !bool {
        if (from >= self.tab_count or to >= self.tab_count)
            return error.InvalidWindowsTab;
        if (from == to) return false;
        const moving = self.tabs[from];
        if (from < to) {
            for (from..to) |index| self.tabs[index] = self.tabs[index + 1];
        } else {
            var index = from;
            while (index > to) : (index -= 1)
                self.tabs[index] = self.tabs[index - 1];
        }
        self.tabs[to] = moving;
        self.active_tab = movedIndex(self.active_tab, from, to);
        for (&self.panes) |*pane_slot| {
            if (pane_slot.*) |*pane|
                pane.tab = @intCast(movedIndex(pane.tab, from, to));
        }
        return true;
    }

    pub fn tabTitle(self: *const WindowsWorkspace, index: usize, output: []u8) !usize {
        if (index >= self.tab_count) return error.InvalidWindowsTab;
        const tab = &self.tabs[index];
        if (tab.name_length != 0)
            return copyTitle(tab.name[0..tab.name_length], output);
        if (self.panes[tab.active_pane]) |pane| {
            const automatic = pane.grid.titleSlice();
            if (automatic.len != 0) return copyTitle(automatic, output);
        }
        var fallback: [16]u8 = undefined;
        return copyTitle(try std.fmt.bufPrint(&fallback, "Tab {d}", .{tab.label}), output);
    }

    pub fn paneTotal(self: *const WindowsWorkspace) usize {
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

    pub fn activeTabPaneCount(self: *const WindowsWorkspace) usize {
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

    pub fn closeActivePane(self: *WindowsWorkspace) ?usize {
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

    pub fn closeActiveTab(self: *WindowsWorkspace) u32 {
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

    pub fn activeTabMask(self: *const WindowsWorkspace) u32 {
        var mask: u32 = 0;
        for (self.panes, 0..) |pane_slot, pane_index| {
            const pane = pane_slot orelse continue;
            if (pane.tab == self.active_tab)
                mask |= @as(u32, 1) << @intCast(pane_index);
        }
        return mask;
    }
    pub fn highestPaneIndex(self: *const WindowsWorkspace) usize {
        var count: usize = 0;
        for (self.panes, 0..) |pane, index| {
            if (pane != null) count = index + 1;
        }
        return count;
    }

    pub fn paneRect(self: *const WindowsWorkspace, pane_index: usize) ?PaneRect {
        if (pane_index >= self.panes.len) return null;
        const pane = self.panes[pane_index] orelse return null;
        if (pane.tab != self.active_tab or !self.paneMatchesTag(pane_index, self.smart_filter_mask))
            return null;
        return self.findFilteredPaneRect(
            self.tabs[self.active_tab].root,
            pane.node,
            .{ .x = 0, .y = 0, .width = 1_000_000, .height = 1_000_000 },
        );
    }

    pub fn dividerCount(self: *const WindowsWorkspace) usize {
        return self.activeTabPaneCount() -| 1;
    }

    /// Node slots remain stable while a split survives; tab reorders never move them.
    pub fn dividerInfo(self: *const WindowsWorkspace, ordinal: usize) ?Divider {
        if (self.active_tab >= self.tab_count) return null;
        var remaining = ordinal;
        for (self.nodes, 0..) |node, index| {
            if (!node.used or node.kind == .leaf) continue;
            const rectangle = self.findPaneRect(
                self.tabs[self.active_tab].root,
                @intCast(index),
                .{ .x = 0, .y = 0, .width = 1_000_000, .height = 1_000_000 },
            ) orelse continue;
            if (remaining != 0) {
                remaining -= 1;
                continue;
            }
            return .{
                .node = index,
                .axis = if (node.kind == .horizontal) 0 else 1,
                .rectangle = rectangle,
                .ratio_permille = node.ratio_permille,
            };
        }
        return null;
    }

    pub fn setDividerRatio(self: *WindowsWorkspace, index: usize, ratio: i64) !bool {
        if (index >= self.nodes.len or self.active_tab >= self.tab_count)
            return error.InvalidWindowsDivider;
        const node = &self.nodes[index];
        if (!node.used or node.kind == .leaf) return error.InvalidWindowsDivider;
        var root: usize = index;
        while (self.nodes[root].parent != invalid_index) root = self.nodes[root].parent;
        if (root != self.tabs[self.active_tab].root) return error.InvalidWindowsDivider;
        const bounded: u16 = @intCast(std.math.clamp(ratio, 50, 950));
        if (node.ratio_permille == bounded) return false;
        node.ratio_permille = bounded;
        return true;
    }

    /// Grow the focused subtree at its nearest ancestor with the requested axis.
    pub fn adjustDivider(self: *WindowsWorkspace, axis: u1, delta: i32) !bool {
        const pane = self.activePaneIndex() orelse return error.InvalidWindowsDivider;
        var child = self.panes[pane].?.node;
        var parent = self.nodes[child].parent;
        while (parent != invalid_index) {
            const node = self.nodes[parent];
            if (node.kind == (if (axis == 0) LayoutKind.horizontal else LayoutKind.vertical)) {
                const signed_delta: i64 = if (node.first == child) @as(i64, delta) else -@as(i64, delta);
                return self.setDividerRatio(parent, @as(i64, node.ratio_permille) + signed_delta);
            }
            child = parent;
            parent = node.parent;
        }
        return false;
    }

    pub fn resetDividers(self: *WindowsWorkspace) bool {
        var changed = false;
        for (0..self.dividerCount()) |ordinal| {
            const divider = self.dividerInfo(ordinal) orelse continue;
            const node = &self.nodes[divider.node];
            changed = changed or node.ratio_permille != 500;
            node.ratio_permille = 500;
        }
        return changed;
    }

    fn filteredSubtreeMatches(self: *const WindowsWorkspace, node_index: u8) bool {
        if (node_index == invalid_index or !self.nodes[node_index].used) return false;
        const node = self.nodes[node_index];
        if (node.kind == .leaf) {
            if (node.pane >= self.panes.len) return false;
            const pane = self.panes[node.pane] orelse return false;
            return pane.tab == self.active_tab and self.paneMatchesTag(node.pane, self.smart_filter_mask);
        }
        return self.filteredSubtreeMatches(node.first) or self.filteredSubtreeMatches(node.second);
    }

    fn findFilteredPaneRect(
        self: *const WindowsWorkspace,
        node_index: u8,
        target_node: u8,
        rectangle: PaneRect,
    ) ?PaneRect {
        if (node_index == invalid_index or !self.nodes[node_index].used) return null;
        if (node_index == target_node) return rectangle;
        const node = self.nodes[node_index];
        if (node.kind == .leaf) return null;
        const first_matches = self.filteredSubtreeMatches(node.first);
        const second_matches = self.filteredSubtreeMatches(node.second);
        if (!first_matches and !second_matches) return null;
        if (!first_matches) return self.findFilteredPaneRect(node.second, target_node, rectangle);
        if (!second_matches) return self.findFilteredPaneRect(node.first, target_node, rectangle);
        var first = rectangle;
        var second = rectangle;
        if (node.kind == .horizontal) {
            first.width = SplitRatio.position(rectangle.width, node.ratio_permille);
            second.x += first.width;
            second.width -= first.width;
        } else {
            first.height = SplitRatio.position(rectangle.height, node.ratio_permille);
            second.y += first.height;
            second.height -= first.height;
        }
        return self.findFilteredPaneRect(node.first, target_node, first) orelse
            self.findFilteredPaneRect(node.second, target_node, second);
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
            first.width = SplitRatio.position(rectangle.width, node.ratio_permille);
            second.x += first.width;
            second.width -= first.width;
        } else {
            first.height = SplitRatio.position(rectangle.height, node.ratio_permille);
            second.y += first.height;
            second.height -= first.height;
        }
        return self.findPaneRect(node.first, target_node, first) orelse
            self.findPaneRect(node.second, target_node, second);
    }

    pub fn snapshot(self: *const WindowsWorkspace) WorkspaceSnapshot {
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
                .tag_mask = pane.tag_mask,
            };
        }
        return result;
    }

    pub fn restore(
        self: *WindowsWorkspace,
        snapshot_value: WorkspaceSnapshot,
        columns: usize,
        rows: usize,
    ) !void {
        try validateWorkspaceSnapshot(&snapshot_value);
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
                .tag_mask = pane.tag_mask,
            };
        }
        self.deinit();
        self.* = candidate;
    }
};

fn movedIndex(index: usize, from: usize, to: usize) usize {
    if (index == from) return to;
    if (from < to and index > from and index <= to) return index - 1;
    if (from > to and index >= to and index < from) return index + 1;
    return index;
}

fn validateTabName(name: []const u8) !void {
    if (name.len > max_tab_name_bytes or !std.unicode.utf8ValidateSlice(name))
        return error.InvalidWindowsTabName;
    for (name) |byte| {
        if (byte < 0x20 or byte == 0x7f) return error.InvalidWindowsTabName;
    }
}

/// Never split a UTF-8 codepoint when a native caller supplies a short buffer.
pub fn copyTitle(value: []const u8, output: []u8) usize {
    var length = @min(value.len, output.len);
    while (length != 0 and length < value.len and value[length] & 0xc0 == 0x80)
        length -= 1;
    @memcpy(output[0..length], value[0..length]);
    return length;
}

pub const persisted_state_capacity = 4096;
const persisted_state_magic = "NWS4";
const StateWriter = struct {
    bytes: []u8,
    index: usize = 0,

    fn put(self: *StateWriter, value: u8) !void {
        if (self.index >= self.bytes.len) return error.WindowsStateTooLarge;
        self.bytes[self.index] = value;
        self.index += 1;
    }

    fn putU16(self: *StateWriter, value: u16) !void {
        try self.put(@truncate(value));
        try self.put(@truncate(value >> 8));
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

    fn takeU16(self: *StateReader) !u16 {
        const first: u16 = try self.take();
        const second: u16 = try self.take();
        return first | (second << 8);
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
    snapshot_value: *const WorkspaceSnapshot,
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
            node.pane == invalid_index or node.pane >= max_panes or node.ratio_permille != 500)
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

fn validateWorkspaceSnapshot(snapshot_value: *const WorkspaceSnapshot) !void {
    if (snapshot_value.tab_count == 0 or snapshot_value.tab_count > max_tabs or
        snapshot_value.active_tab >= snapshot_value.tab_count)
        return error.InvalidWindowsWorkspace;
    var visited = [_]bool{false} ** max_layout_nodes;
    var labels = [_]bool{false} ** (max_tabs + 1);
    for (snapshot_value.tabs, 0..) |tab, index| {
        if (tab.name_length > max_tab_name_bytes) return error.InvalidWindowsWorkspace;
        validateTabName(tab.name[0..tab.name_length]) catch
            return error.InvalidWindowsWorkspace;
        for (tab.name[tab.name_length..]) |byte| {
            if (byte != 0) return error.InvalidWindowsWorkspace;
        }
        if (index >= snapshot_value.tab_count) {
            if (tab.used or tab.root != invalid_index or tab.active_pane != invalid_index or
                tab.label != 0 or tab.name_length != 0)
                return error.InvalidWindowsWorkspace;
            continue;
        }
        if (tab.label == 0 or tab.label > max_tabs or labels[tab.label])
            return error.InvalidWindowsWorkspace;
        labels[tab.label] = true;
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
        if (node.ratio_permille > 1000) return error.InvalidWindowsWorkspace;
        if (!node.used and (node.kind != .leaf or node.parent != invalid_index or
            node.first != invalid_index or node.second != invalid_index or
            node.pane != invalid_index or node.ratio_permille != 500))
            return error.InvalidWindowsWorkspace;
    }
    for (snapshot_value.panes, 0..) |pane, index| {
        if (!pane.used) {
            if (pane.tab != invalid_index or pane.node != invalid_index or pane.tag_mask != 0)
                return error.InvalidWindowsWorkspace;
            continue;
        }
        const node = snapshot_value.nodes[pane.node];
        if (!node.used or node.kind != .leaf or node.pane != index)
            return error.InvalidWindowsWorkspace;
    }
}

pub fn encodePersistedWindowsState(
    value: PersistedWindowsState,
    output: []u8,
) !usize {
    if (!WindowsAppearance.validTheme(@intFromEnum(value.preferences.theme)) or
        !WindowsAppearance.validFontSize(value.preferences.font_size_pt))
        return error.InvalidWindowsState;
    var writer = StateWriter{ .bytes = output };
    for (persisted_state_magic) |byte| try writer.put(byte);
    try writer.put(@intFromEnum(value.preferences.theme));
    try writer.put(value.preferences.font_size_pt);
    try writer.put(@intFromEnum(value.preferences.launch_profile));
    try writer.put(@intFromBool(value.preferences.restore_workspace));
    try writer.put(@intFromBool(value.workspace != null));
    if (value.workspace) |snapshot_value| {
        try validateWorkspaceSnapshot(&snapshot_value);
        try writer.put(snapshot_value.tab_count);
        try writer.put(snapshot_value.active_tab);
        for (snapshot_value.tabs) |tab| {
            try writer.put(@intFromBool(tab.used));
            try writer.put(tab.root);
            try writer.put(tab.active_pane);
            try writer.put(tab.label);
            try writer.put(tab.name_length);
            for (tab.name[0..tab.name_length]) |byte| try writer.put(byte);
        }
        for (snapshot_value.nodes) |node| {
            try writer.put(@intFromBool(node.used));
            try writer.put(@intFromEnum(node.kind));
            try writer.put(node.parent);
            try writer.put(node.first);
            try writer.put(node.second);
            try writer.put(node.pane);
            try writer.putU16(node.ratio_permille);
        }
        for (snapshot_value.panes) |pane| {
            try writer.put(@intFromBool(pane.used));
            try writer.put(pane.tab);
            try writer.put(pane.node);
            try writer.put(pane.tag_mask);
        }
    }
    try writer.putU32(windowsStateChecksum(output[0..writer.index]));
    return writer.index;
}

pub fn decodePersistedWindowsState(bytes: []const u8) !PersistedWindowsState {
    if (bytes.len < persisted_state_magic.len + 9 or bytes.len > persisted_state_capacity)
        return error.InvalidWindowsState;
    const payload = bytes[0 .. bytes.len - 4];
    var checksum_reader = StateReader{ .bytes = bytes[bytes.len - 4 ..] };
    if (try checksum_reader.takeU32() != windowsStateChecksum(payload))
        return error.InvalidWindowsState;
    var reader = StateReader{ .bytes = payload };
    for ("NWS") |expected|
        if (try reader.take() != expected) return error.InvalidWindowsState;
    const version = try reader.take();
    if (version != '1' and version != '2' and version != '3' and version != '4')
        return error.InvalidWindowsState;
    const theme_value = try reader.take();
    if (!WindowsAppearance.validTheme(theme_value) or
        ((version != '3' and version != '4') and theme_value > 1))
        return error.InvalidWindowsState;
    const theme: WindowsTheme = @enumFromInt(theme_value);
    const font_size = try reader.take();
    if (!WindowsAppearance.validFontSize(font_size) or
        ((version != '3' and version != '4') and (font_size < 10 or font_size > 24)))
        return error.InvalidWindowsState;
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
        for (&snapshot_value.tabs, 0..) |*tab, index| {
            tab.* = .{
                .used = try reader.takeBool(),
                .root = try reader.take(),
                .active_pane = try reader.take(),
            };
            if (version != '1') {
                tab.label = try reader.take();
                tab.name_length = try reader.take();
                if (tab.name_length > max_tab_name_bytes) return error.InvalidWindowsWorkspace;
                for (tab.name[0..tab.name_length]) |*byte| byte.* = try reader.take();
            } else if (tab.used) {
                tab.label = @intCast(index + 1);
            }
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
                .ratio_permille = if (version == '3' or version == '4') try reader.takeU16() else 500,
            };
        }
        for (&snapshot_value.panes) |*pane| {
            pane.* = .{
                .used = try reader.takeBool(),
                .tab = try reader.take(),
                .node = try reader.take(),
                .tag_mask = if (version == '4') try reader.take() else 0,
            };
        }
        try validateWorkspaceSnapshot(&snapshot_value);
        result.workspace = snapshot_value;
    }
    if (reader.index != reader.bytes.len) return error.InvalidWindowsState;
    return result;
}

test "Windows workspace: tab moves preserve selected identity, split geometry and pane slots in both directions" {
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    const first = workspace.paneGrid(0).?;
    try first.feed("first");
    const second = try workspace.newTab(12, 4);
    const split = try workspace.splitActive(.horizontal, false, 12, 4);
    const moved_divider = workspace.dividerInfo(0).?;
    _ = try workspace.setDividerRatio(moved_divider.node, 321);
    const selected = workspace.paneGrid(split).?;
    try selected.feed("selected");
    const rectangle = workspace.paneRect(split).?;
    const third = try workspace.newTab(12, 4);
    const last = workspace.paneGrid(third).?;
    _ = try workspace.renameTab(1, "second");
    _ = try workspace.selectTab(1);

    try std.testing.expect(try workspace.moveTab(1, 2));
    try std.testing.expectEqual(@as(usize, 2), workspace.active_tab);
    try std.testing.expectEqual(selected, workspace.activeGrid().?);
    try std.testing.expectEqualDeep(rectangle, workspace.paneRect(split).?);
    try std.testing.expect(try workspace.moveTab(2, 0));
    try std.testing.expectEqual(@as(usize, 0), workspace.active_tab);
    try std.testing.expectEqual(selected, workspace.activeGrid().?);
    try std.testing.expectEqualDeep(rectangle, workspace.paneRect(split).?);

    // A nonselected tab crossing focus shifts its position, never its identity.
    try std.testing.expect(try workspace.moveTab(2, 0));
    try std.testing.expectEqual(@as(usize, 1), workspace.active_tab);
    try std.testing.expectEqual(selected, workspace.activeGrid().?);
    try std.testing.expect(try workspace.moveTab(0, 2));
    try std.testing.expectEqual(@as(usize, 0), workspace.active_tab);
    try std.testing.expectEqual(selected, workspace.activeGrid().?);
    try std.testing.expectEqual(first, workspace.paneGrid(0).?);
    try std.testing.expectEqual(selected, workspace.paneGrid(split).?);
    try std.testing.expectEqual(last, workspace.paneGrid(third).?);
    try std.testing.expectEqual(@as(u21, 's'), selected.cell(0, 0).codepoint);
    try std.testing.expectEqualDeep(rectangle, workspace.paneRect(split).?);

    _ = try workspace.selectTab(1);
    try std.testing.expectEqual(first, workspace.activeGrid().?);
    _ = try workspace.selectTab(0);
    try std.testing.expectEqual(selected, workspace.activeGrid().?);
    try std.testing.expect(workspace.selectPane(second));
    _ = try workspace.selectTab(2);
    _ = try workspace.selectTab(0);
    try std.testing.expectEqual(second, workspace.activePaneIndex().?);
    var title_buffer: [128]u8 = undefined;
    try std.testing.expectEqualStrings("second", title_buffer[0..try workspace.tabTitle(0, &title_buffer)]);
}

test "Windows workspace: close after reorder releases only moved tab and reuses its pane slots without its name" {
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    const first = workspace.paneGrid(0).?;
    _ = try workspace.newTab(12, 4);
    _ = try workspace.splitActive(.vertical, false, 12, 4);
    _ = try workspace.renameTab(1, "closing");
    const third = try workspace.newTab(12, 4);
    const last = workspace.paneGrid(third).?;
    _ = try workspace.selectTab(1);
    _ = try workspace.moveTab(1, 0);
    try std.testing.expectEqual(@as(u32, 0b110), workspace.closeActiveTab());
    try std.testing.expectEqual(first, workspace.activeGrid().?);
    try std.testing.expectEqual(last, workspace.paneGrid(third).?);
    try std.testing.expectEqual(@as(usize, 1), try workspace.newTab(12, 4));
    var buffer: [32]u8 = undefined;
    try std.testing.expectEqualStrings("Tab 2", buffer[0..try workspace.tabTitle(2, &buffer)]);
    try std.testing.expectEqual(@as(usize, 2), try workspace.splitActive(.horizontal, false, 12, 4));
    try std.testing.expectEqual(first, workspace.paneGrid(0).?);
    try std.testing.expectEqual(last, workspace.paneGrid(third).?);
    const snapshot_value = workspace.snapshot();
    try validateWorkspaceSnapshot(&snapshot_value);
}

test "Windows workspace: bounded UTF-8 names reset to automatic titles and roundtrip maximum ordering" {
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    var buffer: [128]u8 = undefined;
    try std.testing.expectEqualStrings("Tab 1", buffer[0..try workspace.tabTitle(0, &buffer)]);
    try workspace.activeGrid().?.feed("\x1b]2;automatic\x07");
    try std.testing.expect(try workspace.renameTab(0, "界é"));
    try std.testing.expectEqualStrings("界é", buffer[0..try workspace.tabTitle(0, &buffer)]);
    try std.testing.expectEqualStrings("界", buffer[0..try workspace.tabTitle(0, buffer[0..4])]);
    try std.testing.expect(!(try workspace.renameTab(0, "界é")));
    try std.testing.expect(try workspace.renameTab(0, ""));
    try std.testing.expectEqualStrings("automatic", buffer[0..try workspace.tabTitle(0, &buffer)]);
    for ([_][]const u8{ "\xff", "\xc0\xaf", "bad\nname", "bad\x7f", "bad\x00", "a" ** 129 }) |invalid| {
        try std.testing.expectError(error.InvalidWindowsTabName, workspace.renameTab(0, invalid));
    }
    try std.testing.expectError(error.InvalidWindowsTab, workspace.renameTab(1, "missing"));
    try std.testing.expectError(error.InvalidWindowsTab, workspace.selectTab(1));
    try std.testing.expectError(error.InvalidWindowsTab, workspace.moveTab(0, 1));
    try std.testing.expect(!(try workspace.selectTab(0)));
    try std.testing.expect(!(try workspace.moveTab(0, 0)));

    const maximum_name = "界" ** 42 ++ "aa";
    _ = try workspace.renameTab(0, maximum_name);
    for (1..max_tabs) |_| {
        _ = try workspace.newTab(12, 4);
        _ = try workspace.renameTab(workspace.active_tab, maximum_name);
    }
    try std.testing.expectError(error.WindowsTabLimit, workspace.newTab(12, 4));
    _ = try workspace.moveTab(max_tabs - 1, 0);
    var encoded: [persisted_state_capacity]u8 = undefined;
    const length = try encodePersistedWindowsState(.{
        .preferences = .{ .theme = .high_contrast, .font_size_pt = 20 },
        .workspace = workspace.snapshot(),
    }, &encoded);
    const decoded = try decodePersistedWindowsState(encoded[0..length]);
    try std.testing.expectEqual(.high_contrast, decoded.preferences.theme);
    try std.testing.expectEqual(@as(u8, 20), decoded.preferences.font_size_pt);
    var restored = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer restored.deinit();
    try restored.restore(decoded.workspace.?, 12, 4);
    try std.testing.expectEqual(@as(usize, max_tabs - 1), restored.activePaneIndex().?);
    for (0..max_tabs) |index| {
        try std.testing.expectEqualStrings(maximum_name, buffer[0..try restored.tabTitle(index, &buffer)]);
    }
    _ = try restored.renameTab(0, "");
    try std.testing.expectEqualStrings("Tab 16", buffer[0..try restored.tabTitle(0, &buffer)]);
    _ = try restored.selectTab(1);
    try std.testing.expectEqual(@as(usize, 0), restored.activePaneIndex().?);
}

fn signTestState(bytes: []u8) void {
    std.mem.writeInt(u32, bytes[bytes.len - 4 ..][0..4], windowsStateChecksum(bytes[0 .. bytes.len - 4]), .little);
}

test "Windows workspace: NWS1 migrates to NWS3 preserving order with automatic labels" {
    // Two leaf tabs, second selected. This is the original NWS1 wire format,
    // independent of the current encoder.
    const payload = "NWS1\x00\x0d\x00\x01\x01\x02\x01" ++
        "\x01\x00\x00\x01\x01\x01" ++ "\x00\xff\xff" ** 14 ++
        "\x01\x00\xff\xff\xff\x00\x01\x00\xff\xff\xff\x01" ++
        "\x00\x00\xff\xff\xff\xff" ** 61 ++
        "\x01\x00\x00\x01\x01\x01" ++ "\x00\xff\xff" ** 30;
    var legacy: [payload.len + 4]u8 = undefined;
    @memcpy(legacy[0..payload.len], payload);
    signTestState(&legacy);
    const decoded = try decodePersistedWindowsState(&legacy);
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    try workspace.restore(decoded.workspace.?, 12, 4);
    try std.testing.expectEqual(@as(usize, 1), workspace.activePaneIndex().?);
    _ = try workspace.moveTab(1, 0);
    var title_buffer: [32]u8 = undefined;
    try std.testing.expectEqualStrings("Tab 2", title_buffer[0..try workspace.tabTitle(0, &title_buffer)]);
    _ = try workspace.renameTab(1, "legacy");
    var encoded: [persisted_state_capacity]u8 = undefined;
    const length = try encodePersistedWindowsState(.{ .workspace = workspace.snapshot() }, &encoded);
    try std.testing.expectEqualStrings("NWS4", encoded[0..4]);
    const migrated = try decodePersistedWindowsState(encoded[0..length]);
    try workspace.restore(migrated.workspace.?, 12, 4);
    try std.testing.expectEqual(@as(usize, 1), workspace.activePaneIndex().?);
    try std.testing.expectEqualStrings("legacy", title_buffer[0..try workspace.tabTitle(1, &title_buffer)]);
    legacy[18] = 0; // Unused third tab must not carry a root.
    signTestState(&legacy);
    try std.testing.expectError(error.InvalidWindowsWorkspace, decodePersistedWindowsState(&legacy));
}

test "Windows workspace: persisted metadata rejects corrupt checksum, UTF-8, lengths and unused records" {
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    _ = try workspace.renameTab(0, "é");
    var encoded: [persisted_state_capacity]u8 = undefined;
    const length = try encodePersistedWindowsState(.{ .workspace = workspace.snapshot() }, &encoded);
    var corrupt = encoded;
    corrupt[16] ^= 1;
    try std.testing.expectError(error.InvalidWindowsState, decodePersistedWindowsState(corrupt[0..length]));
    for ([_]struct { offset: usize, value: u8 }{
        .{ .offset = 16, .value = 0xff }, // Malformed UTF-8.
        .{ .offset = 16, .value = 0x00 }, // Embedded control.
        .{ .offset = 15, .value = 129 }, // Name length exceeds bound.
        .{ .offset = 19, .value = 0 }, // Unused tab root.
        .{ .offset = 21, .value = 1 }, // Unused tab stable label.
        .{ .offset = 14, .value = 0 }, // Used tab requires stable label.
    }) |mutation| {
        corrupt = encoded;
        corrupt[mutation.offset] = mutation.value;
        signTestState(corrupt[0..length]);
        try std.testing.expectError(error.InvalidWindowsWorkspace, decodePersistedWindowsState(corrupt[0..length]));
    }
    corrupt = encoded;
    signTestState(corrupt[0 .. length - 1]);
    try std.testing.expectError(error.InvalidWindowsState, decodePersistedWindowsState(corrupt[0 .. length - 1]));
    corrupt = encoded;
    corrupt[length - 4] = 0;
    signTestState(corrupt[0 .. length + 1]);
    try std.testing.expectError(error.InvalidWindowsState, decodePersistedWindowsState(corrupt[0 .. length + 1]));
    var invalid = workspace.snapshot();
    invalid.tabs[1].name[127] = 'x';
    try std.testing.expectError(error.InvalidWindowsWorkspace, workspace.restore(invalid, 12, 4));
    try std.testing.expectEqualStrings("é", corrupt[0..try workspace.tabTitle(0, &corrupt)]);
}

test "Windows workspace: nested dividers partition odd extents without gaps" {
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    const right = try workspace.splitActive(.horizontal, false, 12, 4);
    const root = workspace.dividerInfo(0).?.node;
    _ = try workspace.setDividerRatio(root, 333);
    const bottom = try workspace.splitActive(.vertical, false, 12, 4);
    const vertical = workspace.dividerInfo(1).?.node;
    _ = try workspace.setDividerRatio(vertical, 667);
    const bottom_right = try workspace.splitActive(.horizontal, false, 12, 4);
    const nested = workspace.dividerInfo(2).?;
    _ = try workspace.setDividerRatio(nested.node, 333);
    try std.testing.expectEqual(@as(usize, 3), workspace.dividerCount());
    try std.testing.expectEqualDeep(PaneRect{ .x = 333_000, .y = 667_000, .width = 667_000, .height = 333_000 }, nested.rectangle);
    try std.testing.expectEqualDeep(PaneRect{ .x = 0, .y = 0, .width = 333_000, .height = 1_000_000 }, workspace.paneRect(0).?);
    try std.testing.expectEqualDeep(PaneRect{ .x = 333_000, .y = 0, .width = 667_000, .height = 667_000 }, workspace.paneRect(right).?);
    const left_rect = workspace.paneRect(bottom).?;
    const right_rect = workspace.paneRect(bottom_right).?;
    try std.testing.expectEqual(@as(u32, 222_111), left_rect.width);
    try std.testing.expectEqual(left_rect.x + left_rect.width, right_rect.x);
    try std.testing.expectEqual(@as(u32, 1_000_000), right_rect.x + right_rect.width);
    // Exercise rounding at a non-permille-aligned parent width.
    const deepest = try workspace.splitActive(.horizontal, false, 12, 4);
    _ = try workspace.setDividerRatio(workspace.dividerInfo(3).?.node, 500);
    const odd_first = workspace.paneRect(bottom_right).?;
    const odd_second = workspace.paneRect(deepest).?;
    try std.testing.expectEqual(@as(u32, 222_445), odd_first.width);
    try std.testing.expectEqual(@as(u32, 222_444), odd_second.width);
    try std.testing.expectEqual(odd_first.x + odd_first.width, odd_second.x);
    try std.testing.expectEqual(@as(u32, 1_000_000), odd_second.x + odd_second.width);
    try std.testing.expect(workspace.dividerInfo(4) == null);
}

test "Windows workspace: focused adjustment follows child side and nearest matching axis" {
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    try std.testing.expect(!(try workspace.adjustDivider(0, 50)));
    const right = try workspace.splitActive(.horizontal, false, 12, 4);
    const root = workspace.dividerInfo(0).?.node;
    const lower = try workspace.splitActive(.vertical, false, 12, 4);
    const vertical = workspace.dividerInfo(1).?.node;
    const inner_right = try workspace.splitActive(.horizontal, false, 12, 4);
    const inner = workspace.dividerInfo(2).?.node;
    const selected = workspace.activeGrid().?;
    try selected.feed("retained");
    try std.testing.expect(try workspace.adjustDivider(0, 100));
    try std.testing.expectEqual(@as(u32, 300_000), workspace.paneRect(inner_right).?.width);
    try std.testing.expectEqual(@as(u16, 500), workspace.nodes[root].ratio_permille);
    try std.testing.expect(try workspace.adjustDivider(1, 100));
    try std.testing.expectEqual(@as(u32, 600_000), workspace.paneRect(inner_right).?.height);
    try std.testing.expect(workspace.selectPane(lower));
    try std.testing.expect(try workspace.adjustDivider(0, 100));
    try std.testing.expectEqual(@as(u16, 500), workspace.nodes[inner].ratio_permille);
    try std.testing.expect(workspace.selectPane(right));
    try std.testing.expect(try workspace.adjustDivider(1, 100));
    try std.testing.expectEqual(@as(u16, 500), workspace.nodes[vertical].ratio_permille);
    try std.testing.expect(workspace.selectPane(0));
    try std.testing.expect(try workspace.adjustDivider(0, std.math.maxInt(i32)));
    try std.testing.expectEqual(@as(u32, 950_000), workspace.paneRect(0).?.width);
    try std.testing.expect(!(try workspace.adjustDivider(0, 1)));
    try std.testing.expect(try workspace.adjustDivider(0, std.math.minInt(i32)));
    try std.testing.expectEqual(@as(u32, 50_000), workspace.paneRect(0).?.width);
    try std.testing.expect(workspace.selectPane(inner_right));
    try std.testing.expect(try workspace.adjustDivider(0, std.math.minInt(i32)));
    try std.testing.expectEqual(@as(u16, 950), workspace.nodes[inner].ratio_permille);
    const other = try workspace.newTab(12, 4);
    const other_grid = workspace.paneGrid(other).?;
    _ = try workspace.splitActive(.vertical, true, 12, 4);
    const other_divider = workspace.dividerInfo(0).?.node;
    _ = try workspace.setDividerRatio(other_divider, 700);
    try std.testing.expectError(error.InvalidWindowsDivider, workspace.setDividerRatio(root, 500));
    _ = try workspace.selectTab(0);
    try std.testing.expect(workspace.resetDividers());
    try std.testing.expect(!workspace.resetDividers());
    try std.testing.expectEqual(@as(u16, 700), workspace.nodes[other_divider].ratio_permille);
    try std.testing.expectEqual(@as(u32, 250_000), workspace.paneRect(inner_right).?.width);
    try std.testing.expectEqual(@as(u32, 500_000), workspace.paneRect(inner_right).?.height);
    try std.testing.expectEqual(selected, workspace.activeGrid().?);
    try std.testing.expectEqual(@as(u21, 'r'), selected.cell(0, 0).codepoint);
    _ = try workspace.setDividerRatio(root, 350);
    _ = try workspace.setDividerRatio(vertical, 650);
    _ = try workspace.setDividerRatio(inner, 250);
    try std.testing.expect(workspace.selectPane(right));
    try std.testing.expectEqual(right, workspace.closeActivePane().?);
    try std.testing.expectEqual(@as(u16, 350), workspace.nodes[root].ratio_permille);
    try std.testing.expectEqual(@as(u16, 250), workspace.nodes[inner].ratio_permille);
    try std.testing.expectEqual(@as(u32, 1_000_000), workspace.paneRect(inner_right).?.height);
    try std.testing.expectEqual(selected, workspace.paneGrid(inner_right).?);
    try std.testing.expectError(error.InvalidWindowsDivider, workspace.setDividerRatio(vertical, 500));
    try std.testing.expectError(error.InvalidWindowsDivider, workspace.setDividerRatio(workspace.panes[lower].?.node, 500));
    try std.testing.expectEqual(other_grid, workspace.paneGrid(other).?);
    const snapshot_value = workspace.snapshot();
    try validateWorkspaceSnapshot(&snapshot_value);
}

test "Windows workspace: NWS2 split ratios migrate to equal and NWS4 preserves boundary ratios" {
    const payload = "NWS2\x00\x0d\x00\x01\x01\x01\x00" ++
        "\x01\x01\x01\x01\x03old" ++ "\x00\xff\xff\x00\x00" ** 15 ++
        "\x01\x00\x01\xff\xff\x00" ++ // First leaf.
        "\x01\x01\xff\x00\x02\xff" ++ // Horizontal root.
        "\x01\x00\x01\xff\xff\x01" ++ // Second leaf.
        "\x00\x00\xff\xff\xff\xff" ** 60 ++
        "\x01\x00\x00\x01\x00\x02" ++ "\x00\xff\xff" ** 30;
    var legacy: [payload.len + 4]u8 = undefined;
    @memcpy(legacy[0..payload.len], payload);
    signTestState(&legacy);
    const decoded = try decodePersistedWindowsState(&legacy);
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    try workspace.restore(decoded.workspace.?, 12, 4);
    try std.testing.expectEqual(@as(u32, 500_000), workspace.paneRect(1).?.x);
    var title_buffer: [32]u8 = undefined;
    try std.testing.expectEqualStrings("old", title_buffer[0..try workspace.tabTitle(0, &title_buffer)]);
    var encoded: [persisted_state_capacity]u8 = undefined;
    for ([_]u16{ 0, 1, 999, 1000 }) |ratio| {
        var snapshot_value = workspace.snapshot();
        snapshot_value.nodes[1].ratio_permille = ratio;
        const length = try encodePersistedWindowsState(.{
            .preferences = .{ .theme = .paseo_black_zinc, .font_size_pt = 32 },
            .workspace = snapshot_value,
        }, &encoded);
        const roundtrip = try decodePersistedWindowsState(encoded[0..length]);
        try workspace.restore(roundtrip.workspace.?, 12, 4);
        try std.testing.expectEqual(@as(u32, ratio) * 1000, workspace.paneRect(1).?.x);
        try std.testing.expectEqual(.paseo_black_zinc, roundtrip.preferences.theme);
        try std.testing.expectEqual(@as(u8, 32), roundtrip.preferences.font_size_pt);
    }
    const length = try encodePersistedWindowsState(.{ .preferences = .{ .font_size_pt = 8 } }, &encoded);
    try std.testing.expectEqual(@as(u8, 8), (try decodePersistedWindowsState(encoded[0..length])).preferences.font_size_pt);
    try std.testing.expectError(error.InvalidWindowsState, encodePersistedWindowsState(.{ .preferences = .{ .font_size_pt = 33 } }, &encoded));
}

test "Windows workspace: signed NWS4 rejects malicious ratios and noncanonical node metadata" {
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    _ = try workspace.splitActive(.horizontal, false, 12, 4);
    var encoded: [persisted_state_capacity]u8 = undefined;
    const length = try encodePersistedWindowsState(.{ .workspace = workspace.snapshot() }, &encoded);
    const nodes_offset = 11 + 5;
    for ([_]struct { node: usize, ratio: u16 }{
        .{ .node = 0, .ratio = 499 }, // Used leaf is canonical, not proportional.
        .{ .node = 1, .ratio = 1001 }, // Branch must fit permille domain.
        .{ .node = 1, .ratio = std.math.maxInt(u16) },
        .{ .node = 3, .ratio = 0 }, // Unused node retains canonical default.
    }) |mutation| {
        var corrupt = encoded;
        const offset = nodes_offset + mutation.node * 8 + 6;
        std.mem.writeInt(u16, corrupt[offset..][0..2], mutation.ratio, .little);
        signTestState(corrupt[0..length]);
        try std.testing.expectError(error.InvalidWindowsWorkspace, decodePersistedWindowsState(corrupt[0..length]));
    }
    for ([_]struct { offset: usize, value: u8 }{
        .{ .offset = nodes_offset + 3 * 8 + 1, .value = 1 },
        .{ .offset = nodes_offset + 3 * 8 + 2, .value = 0 },
        .{ .offset = nodes_offset + 8 * max_layout_nodes + 3 * 4 + 1, .value = 0 },
    }) |mutation| {
        var corrupt = encoded;
        corrupt[mutation.offset] = mutation.value;
        signTestState(corrupt[0..length]);
        try std.testing.expectError(error.InvalidWindowsWorkspace, decodePersistedWindowsState(corrupt[0..length]));
    }
    for ([_]struct { offset: usize, value: u8 }{
        .{ .offset = 4, .value = 3 },
        .{ .offset = 5, .value = 7 },
        .{ .offset = 5, .value = 33 },
    }) |mutation| {
        var corrupt = encoded;
        corrupt[mutation.offset] = mutation.value;
        signTestState(corrupt[0..length]);
        try std.testing.expectError(error.InvalidWindowsState, decodePersistedWindowsState(corrupt[0..length]));
    }
}

test "Windows workspace: pane tags roundtrip and matching remain bounded" {
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    const second = try workspace.splitActive(.horizontal, false, 12, 4);
    try std.testing.expect(try workspace.setPaneTagMask(0, 0b001));
    try std.testing.expect(try workspace.setPaneTagMask(second, 0b100));
    try std.testing.expect(!try workspace.setPaneTagMask(0, 0b001));
    try std.testing.expect(workspace.paneMatchesTag(0, 0));
    try std.testing.expect(workspace.paneMatchesTag(0, 0b001));
    try std.testing.expect(!workspace.paneMatchesTag(0, 0b100));
    var encoded: [persisted_state_capacity]u8 = undefined;
    const length = try encodePersistedWindowsState(.{ .workspace = workspace.snapshot() }, &encoded);
    const decoded = try decodePersistedWindowsState(encoded[0..length]);
    try std.testing.expectEqual(@as(u8, 0b001), decoded.workspace.?.panes[0].tag_mask);
    try std.testing.expectEqual(@as(u8, 0b100), decoded.workspace.?.panes[second].tag_mask);
    var corrupt = encoded;
    corrupt[length - 1] ^= 1;
    try std.testing.expectError(error.InvalidWindowsState, decodePersistedWindowsState(corrupt[0..length]));
}

test "Windows workspace: Smart Tab filter hides unmatched panes and hands focus to a match" {
    var workspace = try WindowsWorkspace.init(std.testing.allocator, 12, 4);
    defer workspace.deinit();
    const second = try workspace.splitActive(.horizontal, false, 12, 4);
    try std.testing.expect(try workspace.setPaneTagMask(0, 0b001));
    try std.testing.expect(try workspace.setPaneTagMask(second, 0b100));
    try std.testing.expect(!workspace.setSmartFilterMask(0b010));
    try std.testing.expectEqual(@as(u8, 0), workspace.smartFilterMask());
    try std.testing.expect(workspace.selectPane(0));
    try std.testing.expect(workspace.setSmartFilterMask(0b100));
    try std.testing.expectEqual(@as(u8, 0b100), workspace.smartFilterMask());
    try std.testing.expectEqual(second, workspace.activePaneIndex().?);
    const filtered_rect = workspace.paneRect(second).?;
    try std.testing.expectEqual(@as(u32, 0), filtered_rect.x);
    try std.testing.expectEqual(@as(u32, 1_000_000), filtered_rect.width);
    try std.testing.expect(workspace.paneRect(0) == null);
    try std.testing.expect(workspace.setSmartFilterMask(0));
    try std.testing.expect(workspace.setSmartFilterMask(0b101));
    const first_both = workspace.paneRect(0).?;
    const second_both = workspace.paneRect(second).?;
    try std.testing.expectEqual(@as(u32, 500_000), first_both.width);
    try std.testing.expectEqual(@as(u32, 500_000), second_both.width);
    try std.testing.expectEqual(first_both.x + first_both.width, second_both.x);
    try std.testing.expect(workspace.paneRect(0) != null);
}
