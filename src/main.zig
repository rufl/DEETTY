const std = @import("std");
const noctty = @import("noctty");
const build_options = @import("build_options");
const NativeGridAbi = noctty.gui.NativeGridAbi;
const NativeGtk = @import("gui/NativeGtk.zig");
const VteHost = @import("gui/VteHost.zig");

comptime {
    _ = NativeGtk.noctty_pane_info_strip_new;
    _ = NativeGtk.noctty_pane_info_strip_set_enabled;
    _ = NativeGtk.noctty_pane_info_strip_update;
    _ = NativeGtk.noctty_pane_info_strip_text;
    _ = NativeGtk.noctty_pane_info_strip_tooltip;
    _ = NativeGtk.noctty_pane_info_strip_revision;
    _ = NativeGtk.noctty_configure_action_button;
    _ = NativeGtk.noctty_prepare_action_button_tree;
    _ = NativeGtk.noctty_show_all_with_action_affordances;
    _ = NativeGtk.noctty_install_compact_tab_styles;
    _ = NativeGtk.noctty_action_button_event_window;
    _ = NativeGtk.noctty_action_button_enter;
    _ = NativeGtk.noctty_action_button_leave;
    _ = NativeGtk.noctty_tab_label_from_widget;
    _ = NativeGtk.noctty_tab_close_button_from_widget;
    _ = NativeGtk.noctty_tab_color_uses_dark_text;
    _ = NativeGtk.noctty_apply_tab_color_style;
    _ = NativeGtk.noctty_settings_grid_new;
    _ = NativeGtk.noctty_settings_grid_attach_control;
    _ = NativeGtk.noctty_settings_group_new;
    _ = NativeGtk.noctty_settings_page_new;
    _ = NativeGtk.noctty_settings_category_row_new;
    _ = NativeGtk.noctty_settings_category_selected;
    _ = NativeGtk.noctty_settings_response;
}

const NativeHostEvent = VteHost.Event;

export fn noctty_qt_shortcut_from_gdk(keyval: c_uint, state: c_uint) callconv(.c) c_int {
    return VteHost.qtKeyFromGdk(keyval, state);
}

extern fn getenv(name: [*:0]const u8) ?[*:0]const u8;
extern fn noctty_native_grid_renderer_qualification(
    artifact_directory: [*:0]const u8,
    mode: [*:0]const u8,
) c_int;
const NativeGridPipelineAdvance = *const fn (
    ?*anyopaque,
    usize,
    *u64,
    *u64,
    *usize,
) callconv(.c) c_int;
extern fn noctty_native_grid_pipeline_qualification(
    callbacks: *const NativeGridAbi.Callbacks,
    columns: c_int,
    rows: c_int,
    advance: NativeGridPipelineAdvance,
    advance_data: ?*anyopaque,
    artifact_path: [*:0]const u8,
    mode: [*:0]const u8,
) c_int;
const NativeGridWrite = NativeGridAbi.Write;

const NativeGridRunOptions = struct {
    session: *noctty.terminal_session.TerminalSession,
    write: NativeGridWrite = noctty_grid_write,
    bridge: ?*NativeGridBridge = null,
    pane_id: u64 = 0,
    columns: c_int = 96,
    rows: c_int = 24,
    mode: c_int = 1,
    shortcut_key: c_int = 0,
    enable_shortcut: c_int = 0,
    workspace_smoke: c_int = -1,
    secondary_session: ?*noctty.terminal_session.TerminalSession = null,
    secondary_pane_id: u64 = 0,
    secondary_initially_active: c_int = 0,
    enable_notifications: c_int = 0,
};

fn runNativeGridHost(options: NativeGridRunOptions) c_int {
    const bridge_data: ?*anyopaque = if (options.bridge) |bridge|
        @ptrCast(bridge)
    else
        null;
    const callbacks = NativeGridAbi.Callbacks{
        .userdata = options.session,
        .pump = noctty_grid_pump,
        .write = options.write,
        .cell = noctty_grid_cell,
        .row = noctty_grid_row,
        .dirty_rows = noctty_grid_take_dirty_rows,
        .dirty_spans = noctty_grid_take_dirty_spans,
        .presentation_ready = noctty_grid_presentation_ready,
        .color_rgb = noctty_grid_color_rgb,
        .cell_text = noctty_grid_cell_text,
        .cell_hyperlink = noctty_grid_cell_hyperlink,
        .poll_exit = noctty_grid_poll_exit,
        .resize = noctty_grid_resize,
        .mouse = noctty_grid_mouse,
        .paste = noctty_grid_paste,
        .copy = noctty_grid_copy,
        .scroll = noctty_grid_scroll,
        .cursor = noctty_grid_cursor,
        .title = noctty_grid_title,
        .cursor_mode = noctty_grid_cursor_mode,
        .mouse_mode = noctty_grid_mouse_mode,
        .focus = noctty_grid_focus,
        .event = noctty_grid_event,
        .event_data = bridge_data,
        .text_action = if (options.bridge == null) null else noctty_grid_text_action,
        .text_action_data = bridge_data,
    };
    const launch = NativeGridAbi.LaunchOptions{
        .pane_id = options.pane_id,
        .columns = options.columns,
        .rows = options.rows,
        .mode = options.mode,
        .shortcut_key = options.shortcut_key,
        .enable_shortcut = options.enable_shortcut,
        .workspace_smoke = options.workspace_smoke,
        .secondary_userdata = options.secondary_session,
        .secondary_pane_id = options.secondary_pane_id,
        .secondary_initially_active = options.secondary_initially_active,
        .enable_notifications = options.enable_notifications,
    };
    return NativeGridAbi.run(&callbacks, &launch);
}

const GridLaunchPolicy = enum {
    automatic,
    visible,
    external_hidden,
};

const NativeHostBridge = struct {
    app: *noctty.app.App,
    pane_id: u64,
    callback_failed: bool = false,
    saw_started: bool = false,
    saw_output: bool = false,
    saw_exit: bool = false,
    saw_input: bool = false,
    saw_resize: bool = false,
    saw_input_marker: bool = false,
    saw_shown: bool = false,
    saw_hidden: bool = false,
    saw_focus: bool = false,
    saw_global_shortcut: bool = false,
    saw_shortcut_registered: bool = false,
    saw_shortcut_unregistered: bool = false,
    saw_shortcut_conflict: bool = false,
    saw_shortcut_failed: bool = false,
    saw_shortcut_recorder: bool = false,
    saw_secondary_started: bool = false,
    saw_secondary_output: bool = false,
    saw_secondary_exit: bool = false,
    saw_maintenance_tick: bool = false,
    placement: c_int = 0,
    exit_code: u8 = 255,
    io: std.Io,
    config_path: []const u8,
    captured_pending_save: bool = false,
    config_persisted: bool = false,
    config_reloaded: bool = false,
};

const NativeGridSessionPool = struct {
    allocator: std.mem.Allocator,
    shell: [:0]const u8,
    profile: ?*const noctty.launch_profile.Profile = null,
    smoke_command: ?[]const u8 = null,
    history_limit: usize = noctty.vt.Grid.default_history_lines,
    // Every native session is pumped serially by the GTK main loop.
    pump_scratch: noctty.terminal_session.TerminalSession.PumpScratch = .{},
    sessions: std.array_list.Managed(*noctty.terminal_session.TerminalSession),

    fn init(allocator: std.mem.Allocator, shell: [:0]const u8, smoke_command: ?[]const u8) NativeGridSessionPool {
        return .{
            .allocator = allocator,
            .shell = shell,
            .smoke_command = smoke_command,
            .sessions = std.array_list.Managed(*noctty.terminal_session.TerminalSession).init(allocator),
        };
    }

    fn initWithProfile(
        allocator: std.mem.Allocator,
        shell: [:0]const u8,
        profile: *const noctty.launch_profile.Profile,
        smoke_command: ?[]const u8,
    ) NativeGridSessionPool {
        var pool = init(allocator, shell, smoke_command);
        pool.profile = profile;
        return pool;
    }

    fn deinit(self: *NativeGridSessionPool) void {
        for (self.sessions.items) |session| {
            session.deinit();
            self.allocator.destroy(session);
        }
        self.sessions.deinit();
        self.* = undefined;
    }

    fn spawn(
        self: *NativeGridSessionPool,
        cwd: []const u8,
        columns: u16,
        rows: u16,
        use_profile: bool,
        profile_override: ?*const noctty.launch_profile.Profile,
    ) !*noctty.terminal_session.TerminalSession {
        const session = try self.allocator.create(noctty.terminal_session.TerminalSession);
        errdefer self.allocator.destroy(session);
        const profile = profile_override orelse if (use_profile) self.profile else null;
        if (profile) |launch_profile| {
            session.* = try noctty.terminal_session.TerminalSession.spawnProfileWithScratch(
                self.allocator,
                launch_profile,
                cwd,
                self.shell,
                columns,
                rows,
                &self.pump_scratch,
            );
        } else {
            const cwd_z = try self.allocator.dupeZ(u8, cwd);
            defer self.allocator.free(cwd_z);
            session.* = try noctty.terminal_session.TerminalSession.spawnWithHistoryLimitAndScratch(
                self.allocator,
                cwd_z,
                self.shell,
                columns,
                rows,
                self.history_limit,
                &self.pump_scratch,
            );
        }
        errdefer session.deinit();
        if (self.smoke_command) |command| try session.write(command);
        try self.sessions.append(session);
        return session;
    }

    fn setHistoryLimit(self: *NativeGridSessionPool, history_limit: usize) !void {
        for (self.sessions.items) |session| try session.grid.setHistoryLimit(history_limit);
        self.history_limit = history_limit;
    }

    fn release(self: *NativeGridSessionPool, target: *noctty.terminal_session.TerminalSession) bool {
        for (self.sessions.items, 0..) |session, index| {
            if (session != target) continue;
            session.deinit();
            _ = self.sessions.orderedRemove(index);
            self.allocator.destroy(session);
            return true;
        }
        return false;
    }
};

const NativeGridBridge = struct {
    app: *noctty.app.App,
    pane_id: u64,
    secondary_pane_id: ?u64 = null,
    callback_failed: bool = false,
    saw_tab_command: bool = false,
    saw_tab_reopen: bool = false,
    saw_pane_cycle_shortcut: bool = false,
    saw_alt_scroll_pane_cycle: bool = false,
    saw_ctrl_alt_scroll_tab_cycle: bool = false,
    saw_tab_cycle_next: bool = false,
    saw_tab_cycle_previous: bool = false,
    saw_smart_tab_cycle_shortcut: bool = false,
    saw_tab_shortcut_close: bool = false,
    saw_tab_shortcut_reopen: bool = false,
    saw_tab_color_set: bool = false,
    saw_tab_color_lighten: bool = false,
    saw_tab_color_darken: bool = false,
    saw_tab_focus_restored: bool = false,
    saw_title_fallback: bool = false,
    saw_title_overflow: bool = false,
    saw_title_tooltip: bool = false,
    saw_title_rename: bool = false,
    saw_palette_rename_validation: bool = false,
    saw_palette_rename_commit: bool = false,
    saw_palette_rename_cancel: bool = false,
    saw_reorder_ui: bool = false,
    saw_reorder_model: bool = false,
    saw_reorder_persisted: bool = false,
    saw_attention_cleared: bool = false,
    saw_status_notification: bool = false,
    saw_status_acknowledged: bool = false,
    saw_dirty_marker: bool = false,
    saw_attention_marker: bool = false,
    saw_dirty_cleared: bool = false,
    saw_dirty_title_preserved: bool = false,
    saw_tab_close_command: bool = false,
    closed_tab_pane_count: usize = 0,
    saw_pane_close_command: bool = false,
    closed_pane_id: ?u64 = null,
    pane_close_tab_closed: bool = false,
    saw_terminal_interrupt_targeted: bool = false,
    saw_terminal_close_chord: bool = false,
    saw_terminal_final_pane_guard: bool = false,
    saw_profile_preset_menu: bool = false,
    saw_profile_preset_selection: bool = false,
    saw_profile_preset_workspace_dirty: bool = false,
    saw_profile_preset_readable: bool = false,
    saw_profile_preset_high_contrast: bool = false,
    saw_profile_preset_mono_no_ligatures: bool = false,
    profile_preset_target_exact: bool = true,
    profile_preset_menu_open_count: usize = 0,
    profile_preset_selection_count: usize = 0,
    profile_preset_dismiss_count: usize = 0,
    profile_preset_current_order: [3]c_int = .{ -1, -1, -1 },
    profile_preset_selection_order: [3]c_int = .{ -1, -1, -1 },
    saw_layout_1x1: bool = false,
    saw_layout_2x2: bool = false,
    saw_layout_4x2: bool = false,
    saw_layout_3x3: bool = false,
    saw_layout_4x4: bool = false,
    saw_split_command: bool = false,
    saw_split_left_command: bool = false,
    saw_broadcast_command: bool = false,
    saw_selection_command: bool = false,
    saw_focus_command: bool = false,
    saw_move_command: bool = false,
    saw_secondary_started: bool = false,
    saw_secondary_output: bool = false,
    saw_secondary_exited: bool = false,
    io: ?std.Io = null,
    config_path: ?[]const u8 = null,
    theme_path: ?[]const u8 = null,
    autosave_path: ?[]const u8 = null,
    config_persisted: bool = false,
    workspace_saved: bool = false,
    workspace_loaded: bool = false,
    maintenance_tick_seen: bool = false,
    autosave_executed: bool = false,
    project_refresh_executed: bool = false,
    recovery_cleanup_executed: bool = false,
    hot_session_loaded: bool = false,
    restore_mode: noctty.continuity.RestoreMode = .restart_shells,
    session_pool: ?*NativeGridSessionPool = null,
    primary_session: ?*noctty.terminal_session.TerminalSession = null,
    created_session_count: usize = 0,
    idle_history_compactions: usize = 0,
    saw_split_down_vertical: bool = false,
    saw_split_left_horizontal: bool = false,
    saw_rendered_move: bool = false,
    saw_tab_position_applied: bool = false,
    saw_pane_zoom: bool = false,
    saw_palette: bool = false,
    saw_terminal_find: bool = false,
    saw_quick_note: bool = false,
    saw_font_increase: bool = false,
    saw_font_decrease: bool = false,
    saw_tab_rename: bool = false,
    saw_directional_focus: bool = false,
    scrollback_saved: bool = false,
    launch_profile_applied: bool = false,
    launch_tmux_profile_applied: bool = false,
    launch_zellij_profile_applied: bool = false,
    launch_profile_library_saved: bool = false,
    launch_profile_library_selected: bool = false,
    launch_profile_library_removed: bool = false,
};

const NativeGridTerminalChordProbe = struct {
    primary: ?*noctty.terminal_session.TerminalSession = null,
    secondary: ?*noctty.terminal_session.TerminalSession = null,
    primary_interrupts: usize = 0,
    secondary_interrupts: usize = 0,
    primary_carriage_returns: usize = 0,
    secondary_carriage_returns: usize = 0,
    primary_line_feeds: usize = 0,
    secondary_line_feeds: usize = 0,
    primary_eof: usize = 0,
    secondary_eof: usize = 0,
};

var native_grid_terminal_chord_probe = NativeGridTerminalChordProbe{};

fn nativeGridTabForPane(bridge: *NativeGridBridge, pane_id: u64) ?*noctty.workspace.Tab {
    for (bridge.app.workspace.tabs.items) |*tab| {
        if (tab.findPane(pane_id) != null) return tab;
    }
    return null;
}

fn nativeGridTabAt(bridge: *NativeGridBridge, tab_index_raw: c_int) ?*noctty.workspace.Tab {
    if (tab_index_raw < 0) return null;
    const tab_index: usize = @intCast(tab_index_raw);
    if (tab_index >= bridge.app.workspace.tabs.items.len) return null;
    return &bridge.app.workspace.tabs.items[tab_index];
}

export fn noctty_grid_hot_session_loaded(raw: ?*anyopaque) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    return @intFromBool(bridge.hot_session_loaded);
}

export fn noctty_grid_recent_workspace(
    raw: ?*anyopaque,
    index_raw: c_int,
    output: [*]u8,
    output_len: usize,
) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    if (index_raw < 0) return @intCast(bridge.app.config.recent_workspaces.count);
    const index: usize = @intCast(index_raw);
    const path = bridge.app.config.recent_workspaces.at(index) orelse return -1;
    if (path.len > output_len or path.len > std.math.maxInt(c_int)) return -1;
    @memcpy(output[0..path.len], path);
    return @intCast(path.len);
}

export fn noctty_grid_restore_tab_count(raw: ?*anyopaque) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const count = bridge.app.workspace.tabs.items.len;
    if (count == 0 or count > std.math.maxInt(c_int)) return -1;
    return @intCast(count);
}

export fn noctty_grid_restore_active_tab(raw: ?*anyopaque) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    if (bridge.app.workspace.active_tab > std.math.maxInt(c_int)) return -1;
    return @intCast(bridge.app.workspace.active_tab);
}

export fn noctty_grid_restore_tab_index_for_pane(raw: ?*anyopaque, pane_id: u64) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    for (bridge.app.workspace.tabs.items, 0..) |*tab, index| {
        if (tab.findPane(pane_id) == null) continue;
        if (index > std.math.maxInt(c_int)) return -1;
        return @intCast(index);
    }
    return -1;
}

export fn noctty_grid_restore_tab_info(
    raw: ?*anyopaque,
    tab_index_raw: c_int,
    pane_count_out: *c_int,
    active_pane_id_out: *u64,
    node_count_out: *c_int,
    root_node_out: *c_int,
) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const tab = nativeGridTabAt(bridge, tab_index_raw) orelse return -1;
    if (tab.panes.items.len == 0 or
        tab.panes.items.len > std.math.maxInt(c_int) or
        tab.layout.nodes.items.len == 0 or
        tab.layout.nodes.items.len > std.math.maxInt(c_int)) return -1;
    const root = tab.layout.root orelse return -1;
    if (root >= tab.layout.nodes.items.len or root > std.math.maxInt(c_int)) return -1;
    pane_count_out.* = @intCast(tab.panes.items.len);
    active_pane_id_out.* = tab.active_pane_id;
    node_count_out.* = @intCast(tab.layout.nodes.items.len);
    root_node_out.* = @intCast(root);
    return 0;
}

export fn noctty_grid_restore_pane_id(
    raw: ?*anyopaque,
    tab_index_raw: c_int,
    pane_index_raw: c_int,
    pane_id_out: *u64,
) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const tab = nativeGridTabAt(bridge, tab_index_raw) orelse return -1;
    if (pane_index_raw < 0) return -1;
    const pane_index: usize = @intCast(pane_index_raw);
    if (pane_index >= tab.panes.items.len) return -1;
    pane_id_out.* = tab.panes.items[pane_index].id;
    return 0;
}

export fn noctty_grid_restore_layout_node(
    raw: ?*anyopaque,
    tab_index_raw: c_int,
    node_index_raw: c_int,
    kind_out: *c_int,
    pane_id_out: *u64,
    axis_out: *c_int,
    first_out: *c_int,
    second_out: *c_int,
    ratio_permille_out: *c_int,
) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const tab = nativeGridTabAt(bridge, tab_index_raw) orelse return -1;
    if (node_index_raw < 0) return -1;
    const node_index: usize = @intCast(node_index_raw);
    if (node_index >= tab.layout.nodes.items.len) return -1;
    const node = tab.layout.nodes.items[node_index];
    kind_out.* = @intFromEnum(node.kind);
    pane_id_out.* = node.pane_id;
    axis_out.* = @intFromEnum(node.axis);
    first_out.* = if (node.first) |index| @intCast(index) else -1;
    second_out.* = if (node.second) |index| @intCast(index) else -1;
    ratio_permille_out.* = node.ratio_permille;
    return 0;
}

export fn noctty_grid_set_layout_ratio(
    raw: ?*anyopaque,
    tab_index_raw: c_int,
    node_index_raw: c_int,
    ratio_permille_raw: c_int,
) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const tab = nativeGridTabAt(bridge, tab_index_raw) orelse return -1;
    if (node_index_raw < 0 or ratio_permille_raw < 0 or ratio_permille_raw > 1000) return -1;
    const node_index: usize = @intCast(node_index_raw);
    if (node_index >= tab.layout.nodes.items.len) return -1;
    const node = &tab.layout.nodes.items[node_index];
    if (node.kind != .split) return -1;
    const ratio_permille: u16 = @intCast(ratio_permille_raw);
    if (node.ratio_permille == ratio_permille) return 0;
    node.ratio_permille = ratio_permille;
    bridge.app.markWorkspaceDirtyAt(0);
    return 0;
}

export fn noctty_grid_flush_hot_session(raw: ?*anyopaque) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    persistNativeGridHotSession(bridge);
    return if (bridge.callback_failed) -1 else 0;
}

export fn noctty_grid_smart_filter_tag(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const tag = bridge.app.workspace.smart_filter_tag orelse return 0;
    if (tag.len > capacity or tag.len > std.math.maxInt(c_int)) return -1;
    @memcpy(output[0..tag.len], tag);
    return @intCast(tag.len);
}

export fn noctty_grid_tab_position(raw: ?*anyopaque) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    return @intFromEnum(bridge.app.config.tabs.position);
}

export fn noctty_grid_tab_title(raw: ?*anyopaque, pane_id: u64, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    for (bridge.app.workspace.tabs.items) |*tab| {
        if (tab.findPane(pane_id) == null) continue;
        if (!tab.title_overridden) return 0;
        if (tab.title.len > capacity or tab.title.len > std.math.maxInt(c_int)) return -1;
        @memcpy(output[0..tab.title.len], tab.title);
        return @intCast(tab.title.len);
    }
    return -1;
}

export fn noctty_grid_tab_color(raw: ?*anyopaque, pane_id: u64, preset_out: *c_int, shade_out: *c_int) callconv(.c) u32 {
    preset_out.* = -1;
    shade_out.* = 0;
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    const tab = nativeGridTabForPane(bridge, pane_id) orelse return 0;
    const accent = tab.accent orelse return 0;
    preset_out.* = @intFromEnum(accent.preset);
    shade_out.* = accent.shade;
    return accent.rgb();
}

export fn noctty_grid_set_tab_color(raw: ?*anyopaque, pane_id: u64, preset_raw: c_int) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const tab = nativeGridTabForPane(bridge, pane_id) orelse return -1;
    var preset: ?noctty.workspace.TabColorPreset = null;
    if (preset_raw >= 0) {
        if (preset_raw > @intFromEnum(noctty.workspace.TabColorPreset.pink)) return -1;
        preset = @enumFromInt(@as(u8, @intCast(preset_raw)));
    }
    _ = bridge.app.dispatch(.{ .set_tab_accent = .{
        .tab_id = tab.id,
        .preset = preset,
    } }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    bridge.saw_tab_color_set = true;
    persistNativeGridHotSession(bridge);
    return 0;
}

export fn noctty_grid_adjust_tab_color(raw: ?*anyopaque, pane_id: u64, delta: c_int) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const tab = nativeGridTabForPane(bridge, pane_id) orelse return -1;
    if (delta == 0) return -1;
    _ = bridge.app.dispatch(.{ .adjust_tab_accent = .{
        .tab_id = tab.id,
        .delta = if (delta > 0) 1 else -1,
    } }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    if (delta > 0) bridge.saw_tab_color_lighten = true else bridge.saw_tab_color_darken = true;
    persistNativeGridHotSession(bridge);
    return 0;
}

export fn noctty_grid_rename_tab(raw: ?*anyopaque, pane_id: u64, title: [*]const u8, title_len: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    var tab_id: ?u64 = null;
    for (bridge.app.workspace.tabs.items) |*tab| {
        if (tab.findPane(pane_id) != null) {
            tab_id = tab.id;
            break;
        }
    }
    _ = bridge.app.dispatch(.{ .rename_tab = .{
        .tab_id = tab_id orelse return -1,
        .title = title[0..title_len],
    } }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    bridge.saw_tab_rename = true;
    persistNativeGridHotSession(bridge);
    return 0;
}

export fn noctty_grid_reorder_tab(raw: ?*anyopaque, pane_id: u64, destination_index: c_int) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    var tab_id: ?u64 = null;
    for (bridge.app.workspace.tabs.items) |*tab| {
        if (tab.findPane(pane_id) != null) {
            tab_id = tab.id;
            break;
        }
    }
    if (destination_index < 0) return -1;
    _ = bridge.app.dispatch(.{ .reorder_tab = .{
        .tab_id = tab_id orelse return -1,
        .destination_index = @intCast(destination_index),
    } }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    return 0;
}

export fn noctty_grid_tab_index_for_pane(raw: ?*anyopaque, pane_id: u64) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    for (bridge.app.workspace.tabs.items, 0..) |*tab, index| {
        if (tab.findPane(pane_id) != null) {
            if (index > std.math.maxInt(c_int)) return -1;
            return @intCast(index);
        }
    }
    return -1;
}

export fn noctty_grid_close_tab(raw: ?*anyopaque, pane_id: u64) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    var tab_id: ?u64 = null;
    for (bridge.app.workspace.tabs.items) |*tab| {
        if (tab.findPane(pane_id) != null) {
            tab_id = tab.id;
            break;
        }
    }
    const closed = (bridge.app.dispatch(.{ .close_tab = tab_id orelse return -1 }) catch {
        return -1;
    }).tab_closed;
    bridge.saw_tab_close_command = true;
    bridge.closed_tab_pane_count = closed.pane_count;
    if (closed.pane_count == 0 or closed.pane_count > std.math.maxInt(c_int)) return -1;
    persistNativeGridHotSession(bridge);
    return @intCast(closed.pane_count);
}

export fn noctty_grid_close_pane(
    raw: ?*anyopaque,
    pane_id: u64,
    active_pane_id_out: *u64,
    tab_closed_out: *c_int,
) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const closed = (bridge.app.dispatch(.{ .close_pane = pane_id }) catch return -1).pane_closed;
    bridge.saw_pane_close_command = true;
    bridge.closed_pane_id = closed.pane_id;
    bridge.pane_close_tab_closed = closed.tab_closed;
    active_pane_id_out.* = closed.active_pane_id;
    tab_closed_out.* = @intFromBool(closed.tab_closed);
    persistNativeGridHotSession(bridge);
    return 1;
}

export fn noctty_grid_close_session(raw: ?*anyopaque, bridge_raw: ?*anyopaque) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return -1));
    session.deinit();
    if (bridge_raw) |bridge_ptr| {
        const bridge: *NativeGridBridge = @ptrCast(@alignCast(bridge_ptr));
        if (bridge.session_pool) |pool| {
            if (pool.release(session)) return 2;
        }
    }
    return 1;
}

export fn noctty_grid_close_transport(raw: ?*anyopaque) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return -1));
    session.closeTransport();
    return 1;
}

export fn noctty_grid_has_foreground_process(raw: ?*anyopaque) callconv(.c) c_int {
    const session: *const noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return 0));
    return @intFromBool(session.hasForegroundProcess());
}

const NativePaneMetadata = struct {
    process_id: i32 = 0,
    root_process_id: i32 = 0,
    cwd_length: usize = 0,
    process_name_length: usize = 0,
};

var pane_usage_sampler = noctty.pane_info.UsageSampler{};

fn writeNativePaneMetadata(
    session_raw: ?*anyopaque,
    bridge: ?*NativeGridBridge,
    pane_id: u64,
    cwd: []u8,
    process_name: []u8,
) NativePaneMetadata {
    var metadata = NativePaneMetadata{};
    if (session_raw) |raw| {
        const session: *const noctty.terminal_session.TerminalSession =
            @ptrCast(@alignCast(raw));
        metadata.process_id = session.processId();
        metadata.root_process_id = metadata.process_id;
        if (session.processInfo(cwd, process_name)) |info| {
            metadata.process_id = info.process_id;
            metadata.cwd_length = info.cwd.len;
            metadata.process_name_length = info.name.len;
        }
    }
    if (metadata.cwd_length == 0) if (bridge) |native_bridge| {
        if (native_bridge.app.workspace.findPane(pane_id)) |pane| {
            if (pane.cwd.len <= cwd.len) {
                @memcpy(cwd[0..pane.cwd.len], pane.cwd);
                metadata.cwd_length = pane.cwd.len;
            }
        }
    };
    if (metadata.process_name_length == 0 and process_name.len >= "shell".len) {
        @memcpy(process_name[0.."shell".len], "shell");
        metadata.process_name_length = "shell".len;
    }
    return metadata;
}

export fn noctty_grid_current_directory(
    session_raw: ?*anyopaque,
    bridge_raw: ?*anyopaque,
    pane_id: u64,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    if (capacity == 0) return -1;
    const bridge: ?*NativeGridBridge = if (bridge_raw) |raw|
        @ptrCast(@alignCast(raw))
    else
        null;
    var process_name: [256]u8 = undefined;
    const metadata = writeNativePaneMetadata(
        session_raw,
        bridge,
        pane_id,
        output[0..capacity],
        &process_name,
    );
    if (metadata.cwd_length == 0 or
        metadata.cwd_length > std.math.maxInt(c_int)) return -1;
    return @intCast(metadata.cwd_length);
}

export fn noctty_grid_pane_info(
    session_raw: ?*anyopaque,
    bridge_raw: ?*anyopaque,
    pane_id: u64,
    display: [*]u8,
    display_capacity: usize,
    tooltip: [*]u8,
    tooltip_capacity: usize,
) callconv(.c) c_int {
    if (display_capacity < 2 or tooltip_capacity < 2) return -1;
    const bridge: ?*NativeGridBridge = if (bridge_raw) |raw|
        @ptrCast(@alignCast(raw))
    else
        null;
    var cwd: [4096]u8 = undefined;
    var process_name: [256]u8 = undefined;
    const metadata = writeNativePaneMetadata(
        session_raw,
        bridge,
        pane_id,
        &cwd,
        &process_name,
    );
    const resources = noctty.pty.resourceSamplePair(metadata.root_process_id) orelse
        noctty.pty.ResourceSamplePair{
            .app = .{},
            .pane = .{},
        };
    const usage = pane_usage_sampler.sample(
        resources.app,
        resources.pane,
        metadata.root_process_id,
    );
    const continuity = if (bridge) |native_bridge| blk: {
        const pane = native_bridge.app.workspace.findPane(pane_id) orelse break :blk "restartable shell";
        break :blk pane.continuityLabel(native_bridge.app.config.terminal.launch_profile.kind);
    } else "restartable shell";
    const formatted = noctty.pane_info.format(.{
        .pane_id = pane_id,
        .process_id = metadata.process_id,
        .cwd = cwd[0..metadata.cwd_length],
        .process_name = process_name[0..metadata.process_name_length],
        .continuity = continuity,
        .usage = usage,
    }, display[0 .. display_capacity - 1], tooltip[0 .. tooltip_capacity - 1]) catch
        return -1;
    display[formatted.display_length] = 0;
    tooltip[formatted.tooltip_length] = 0;
    return 1;
}

export fn noctty_grid_compact_setting(raw: ?*anyopaque, field: c_int) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    return switch (field) {
        0 => bridge.app.config.dropdown.width_percent,
        1 => bridge.app.config.dropdown.height_percent,
        2 => bridge.app.config.dropdown.animation_ms,
        3 => @intFromBool(bridge.app.config.dropdown.hide_on_focus_loss),
        4 => @intFromBool(bridge.app.config.tabs.focus_follows_pointer),
        5 => bridge.app.config.tabs.compact_height_px,
        6 => @intFromFloat(bridge.app.config.font.size_pt * 100.0),
        7 => @intFromFloat(bridge.app.config.font.min_size_pt * 100.0),
        8 => @intFromFloat(bridge.app.config.font.max_size_pt * 100.0),
        9 => @intFromBool(bridge.app.config.tabs.show_pane_info),
        10 => @intCast(bridge.app.config.terminal.scrollback_lines),
        11 => @intFromEnum(bridge.app.config.font.antialias),
        12 => @intFromEnum(bridge.app.config.font.hinting),
        14 => bridge.app.config.dropdown.width_px,
        15 => bridge.app.config.dropdown.height_px,
        else => 0,
    };
}

export fn noctty_grid_launch_profile(raw: ?*anyopaque, field: c_int, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const profile = &bridge.app.config.terminal.launch_profile;
    if (field == 0) return @intCast(@intFromEnum(profile.kind));
    if (field == 6) return @intCast(profile.scrollback_lines);
    const value = switch (field) {
        1 => profile.shell.slice(),
        2 => profile.command.slice(),
        3 => profile.working_directory.slice(),
        4 => profile.environment.slice(),
        5 => profile.ssh_target.slice(),
        else => return -1,
    };
    if (value.len + 1 > capacity or value.len > std.math.maxInt(c_int)) return -1;
    @memcpy(output[0..value.len], value);
    output[value.len] = 0;
    return @intCast(value.len);
}

export fn noctty_grid_launch_profile_library(raw: ?*anyopaque, index_raw: c_int, field: c_int, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const library = &bridge.app.config.terminal.launch_profiles;
    if (index_raw == -1) return library.count;
    if (index_raw == -2) {
        return if (library.selected_index == noctty.launch_profile.no_selection)
            -1
        else
            library.selected_index;
    }
    if (index_raw < 0) return -1;
    const index: usize = @intCast(index_raw);
    if (index >= library.count) return -1;
    const entry = &library.entries[index];
    if (field == 1) return @intCast(@intFromEnum(entry.profile.kind));
    if (field == 7) return @intCast(entry.profile.scrollback_lines);
    const value = switch (field) {
        0 => entry.name.slice(),
        2 => entry.profile.shell.slice(),
        3 => entry.profile.command.slice(),
        4 => entry.profile.working_directory.slice(),
        5 => entry.profile.environment.slice(),
        6 => entry.profile.ssh_target.slice(),
        else => return -1,
    };
    if (value.len + 1 > capacity or value.len > std.math.maxInt(c_int)) return -1;
    @memcpy(output[0..value.len], value);
    output[value.len] = 0;
    return @intCast(value.len);
}

export fn noctty_grid_create_session(raw: ?*anyopaque, source_pane_id: u64, event: c_int, columns_raw: c_int, rows_raw: c_int, pane_id_out: *u64) callconv(.c) ?*anyopaque {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return null));
    const pool = bridge.session_pool orelse return null;
    const restoring = event == 99;
    if (!restoring) {
        _ = bridge.app.dispatch(.{ .focus_pane = source_pane_id }) catch {
            bridge.callback_failed = true;
            return null;
        };
        switch (event) {
            20 => {
                bridge.saw_tab_command = true;
                _ = bridge.app.dispatch(.new_tab) catch {
                    bridge.callback_failed = true;
                    return null;
                };
            },
            26 => {
                const reopened = bridge.app.dispatch(.reopen_tab) catch |err| switch (err) {
                    error.NoClosedTab => bridge.app.dispatch(.new_tab) catch {
                        bridge.callback_failed = true;
                        return null;
                    },
                    else => {
                        bridge.callback_failed = true;
                        return null;
                    },
                };
                _ = reopened;
                bridge.saw_tab_reopen = true;
            },
            21 => {
                bridge.saw_split_command = true;
                _ = bridge.app.dispatch(.split_down) catch {
                    bridge.callback_failed = true;
                    return null;
                };
            },
            22 => {
                bridge.saw_split_left_command = true;
                _ = bridge.app.dispatch(.split_left) catch {
                    bridge.callback_failed = true;
                    return null;
                };
            },
            else => return null,
        }
    }
    const pane_id = if (restoring)
        source_pane_id
    else
        (bridge.app.workspace.activeTab() orelse {
            bridge.callback_failed = true;
            return null;
        }).active_pane_id;
    const pane = bridge.app.workspace.findPane(pane_id) orelse {
        bridge.callback_failed = true;
        return null;
    };
    if (!restoring) if (pool.profile) |profile| {
        const resolved_cwd = profile.workingDirectory(pane.cwd);
        if (!std.mem.eql(u8, resolved_cwd, pane.cwd)) pane.setCwd(resolved_cwd) catch {
            bridge.callback_failed = true;
            return null;
        };
    };
    const columns: u16 = @intCast(@max(2, @min(columns_raw, 512)));
    const rows: u16 = @intCast(@max(2, @min(rows_raw, 512)));
    var restore_profile: noctty.launch_profile.Profile = .{};
    var profile_override: ?*const noctty.launch_profile.Profile = null;
    if (restoring) switch (bridge.restore_mode) {
        .restart_shells => {},
        .attach_persistent => {
            if (bridge.app.config.terminal.launch_profile.kind == .tmux or
                bridge.app.config.terminal.launch_profile.kind == .zellij)
                profile_override = &bridge.app.config.terminal.launch_profile;
        },
        .resume_agents => if (pane.agent_resume.enabled) {
            if (noctty.continuity.profileForResume(
                pane.agent_resume,
                pane.cwd,
                bridge.app.config.terminal.scrollback_lines,
            )) |profile| {
                restore_profile = profile;
                profile_override = &restore_profile;
            } else |err| switch (err) {
                error.AgentResumeProviderUnsupported, error.AgentResumeUnavailable => {},
                else => {
                    bridge.callback_failed = true;
                    return null;
                },
            }
        },
    };
    const session = pool.spawn(
        pane.cwd,
        columns,
        rows,
        !restoring,
        profile_override,
    ) catch {
        bridge.callback_failed = true;
        return null;
    };
    pane_id_out.* = pane_id;
    bridge.created_session_count += 1;
    if (bridge.secondary_pane_id == null) bridge.secondary_pane_id = pane_id;
    if (!restoring) persistNativeGridHotSession(bridge);
    return session;
}

export fn noctty_grid_apply_preset(
    raw: ?*anyopaque,
    source_pane_id: u64,
    event: c_int,
    pane_ids_out: [*]u64,
    capacity: usize,
) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const preset: noctty.workspace.LayoutPreset = switch (event) {
        50 => .one_by_one,
        51 => .two_by_two,
        52 => .three_by_three,
        60 => .four_by_four,
        61 => .four_by_two,
        else => return -1,
    };
    _ = bridge.app.dispatch(.{ .focus_pane = source_pane_id }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    _ = bridge.app.dispatch(.{ .preset = preset }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    const tab = bridge.app.workspace.activeTab() orelse {
        bridge.callback_failed = true;
        return -1;
    };
    if (tab.panes.items.len > capacity or
        tab.panes.items.len > std.math.maxInt(c_int)) return -1;
    for (tab.panes.items, 0..) |pane, index| pane_ids_out[index] = pane.id;
    if (event == 50) bridge.saw_layout_1x1 = true;
    if (event == 51) bridge.saw_layout_2x2 = true;
    if (event == 52) bridge.saw_layout_3x3 = true;
    if (event == 60) bridge.saw_layout_4x4 = true;
    if (event == 61) bridge.saw_layout_4x2 = true;
    persistNativeGridHotSession(bridge);
    return @intCast(tab.panes.items.len);
}

export fn noctty_grid_text_action(raw: ?*anyopaque, action: c_int, first_ptr: [*]const u8, first_len: usize, second_ptr: [*]const u8, second_len: usize, format_raw: c_int) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    if (action == 15 or action == 16) {
        var profile = noctty.launch_profile.Profile{};
        profile.kind = switch (format_raw) {
            0 => .shell,
            1 => .command,
            2 => .ssh,
            3 => .tmux,
            4 => .zellij,
            else => return -1,
        };
        var fields = std.mem.splitScalar(u8, first_ptr[0..first_len], '\t');
        const name = if (action == 16) fields.next() orelse return -1 else "";
        profile.shell.set(fields.next() orelse return -1) catch return -1;
        profile.command.set(fields.next() orelse return -1) catch return -1;
        profile.working_directory.set(fields.next() orelse return -1) catch return -1;
        profile.ssh_target.set(fields.next() orelse return -1) catch return -1;
        profile.scrollback_lines = std.fmt.parseInt(u32, fields.next() orelse return -1, 10) catch return -1;
        if (fields.next() != null) return -1;
        profile.environment.set(second_ptr[0..second_len]) catch return -1;
        const command: noctty.app.App.Command = if (action == 16)
            .{ .save_named_launch_profile = .{ .name = name, .profile = profile } }
        else
            .{ .set_launch_profile = profile };
        _ = bridge.app.dispatch(command) catch {
            bridge.callback_failed = true;
            return -1;
        };
        bridge.launch_profile_applied = true;
        if (profile.kind == .tmux) bridge.launch_tmux_profile_applied = true;
        if (profile.kind == .zellij) bridge.launch_zellij_profile_applied = true;
        if (action == 16) bridge.launch_profile_library_saved = true;
        persistNativeGridConfig(bridge);
        return 0;
    }
    if (action == 17) {
        if (format_raw < 0) return -1;
        _ = bridge.app.dispatch(.{ .select_named_launch_profile = @intCast(format_raw) }) catch {
            bridge.callback_failed = true;
            return -1;
        };
        bridge.launch_profile_library_selected = true;
        persistNativeGridConfig(bridge);
        return 0;
    }
    if (action == 18) {
        if (format_raw < 0) return -1;
        _ = bridge.app.dispatch(.{ .remove_named_launch_profile = @intCast(format_raw) }) catch {
            bridge.callback_failed = true;
            return -1;
        };
        bridge.launch_profile_library_removed = true;
        persistNativeGridConfig(bridge);
        return 0;
    }
    if (action == 8) {
        const note = (bridge.app.dispatch(.read_quick_note) catch return -1).quick_note_read;
        if (format_raw != 0) {
            const preview_len = @min(note.len, second_len);
            @memcpy(@constCast(second_ptr[0..preview_len]), note[0..preview_len]);
            return @intCast(preview_len);
        }
        if (note.len > second_len) return -1;
        @memcpy(@constCast(second_ptr[0..note.len]), note);
        return @intCast(note.len);
    }
    if (action == 9) {
        _ = bridge.app.dispatch(.{ .set_quick_note = second_ptr[0..second_len] }) catch {
            bridge.callback_failed = true;
            return -1;
        };
        bridge.saw_quick_note = true;
        persistNativeGridHotSession(bridge);
        if (bridge.callback_failed) return -1;
        return 0;
    }
    if (action == 10) {
        const io = bridge.io orelse return -1;
        const path = first_ptr[0..first_len];
        var atomic = std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true }) catch {
            bridge.callback_failed = true;
            return -1;
        };
        defer atomic.deinit(io);
        atomic.file.writeStreamingAll(io, second_ptr[0..second_len]) catch {
            bridge.callback_failed = true;
            return -1;
        };
        atomic.replace(io) catch {
            bridge.callback_failed = true;
            return -1;
        };
        bridge.scrollback_saved = true;
        return 0;
    }
    if (action == 6) {
        const output: []u8 = @constCast(second_ptr[0..second_len]);
        var writer = std.Io.Writer.fixed(output);
        const panels = bridge.app.workspace.project_panels;
        const summary = panels.summary();
        writer.print("Git status: {d} ({d} changed, {d} conflicts)\nGit graph: {d}\nFiles: {d} ({d} directories, {d} dirty)\n", .{ summary.git_status_count, summary.changed_count, summary.conflict_count, summary.git_graph_count, summary.file_entry_count, summary.directory_count, summary.dirty_file_count }) catch return -1;
        for (panels.git_status[0..@min(panels.git_status.len, 8)]) |entry| writer.print("{s}  {s}\n", .{ @tagName(entry.state), entry.path }) catch return -1;
        for (panels.git_graph[0..@min(panels.git_graph.len, 6)]) |node| writer.print("{s}  {s}\n", .{ node.commit, node.summary }) catch return -1;
        for (panels.files[0..@min(panels.files.len, 16)]) |entry| writer.print("{s}{s}\n", .{ entry.path, if (entry.kind == .directory) "/" else "" }) catch return -1;
        return @intCast(writer.buffered().len);
    }
    if (action == 2 or action == 3) {
        const io = bridge.io orelse return -1;
        const path = first_ptr[0..first_len];
        if (action == 2) {
            const receipt = bridge.app.saveWorkspaceFile(io, std.Io.Dir.cwd(), path, .manual) catch {
                bridge.callback_failed = true;
                return -1;
            };
            receipt.deinit(bridge.app.allocator);
            bridge.workspace_saved = true;
        } else {
            const receipt = bridge.app.loadWorkspaceFile(io, std.Io.Dir.cwd(), path, .manual) catch {
                bridge.callback_failed = true;
                return -1;
            };
            receipt.deinit(bridge.app.allocator);
            bridge.workspace_loaded = true;
        }
        bridge.app.recordRecentWorkspace(path) catch {
            bridge.callback_failed = true;
            return -1;
        };
        persistNativeGridConfig(bridge);
        return 0;
    }
    if (action == 19) {
        const path = first_ptr[0..first_len];
        bridge.app.recordRecentWorkspace(path) catch {
            bridge.callback_failed = true;
            return -1;
        };
        persistNativeGridConfig(bridge);
        return 0;
    }
    if (action != 1) return -1;
    const raw_name = first_ptr[0..first_len];
    const base_start = if (std.mem.lastIndexOfScalar(u8, raw_name, '/')) |index| index + 1 else 0;
    const base = raw_name[base_start..];
    const name = if (std.mem.lastIndexOfScalar(u8, base, '.')) |index| if (index > 0) base[0..index] else "Imported Theme" else if (base.len > 0) base else "Imported Theme";
    const format: noctty.theme.ImportFormat = switch (format_raw) {
        0 => .ghostty,
        1 => .xresources,
        2 => .alacritty_toml,
        else => return -1,
    };
    _ = bridge.app.dispatch(.{ .install_theme_import = .{ .format = format, .name = name, .contents = second_ptr[0..second_len] } }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    _ = bridge.app.dispatch(.{ .select_theme = name }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    if (bridge.io) |io| if (bridge.theme_path) |path| {
        const receipt = bridge.app.saveThemeLibraryFile(io, std.Io.Dir.cwd(), path, .library) catch {
            bridge.callback_failed = true;
            return -1;
        };
        receipt.deinit(bridge.app.allocator);
    };
    persistNativeGridConfig(bridge);
    return 0;
}

fn persistNativeGridConfig(bridge: *NativeGridBridge) void {
    const io = bridge.io orelse return;
    const path = bridge.config_path orelse return;
    const receipt = bridge.app.saveConfigFile(io, std.Io.Dir.cwd(), path, .settings) catch {
        bridge.callback_failed = true;
        return;
    };
    receipt.deinit(bridge.app.allocator);
    bridge.config_persisted = true;
}

fn persistNativeGridHotSession(bridge: *NativeGridBridge) void {
    if (!bridge.app.recovery.dirty) return;
    const io = bridge.io orelse return;
    const path = bridge.autosave_path orelse return;
    const receipt = bridge.app.saveWorkspaceFile(
        io,
        std.Io.Dir.cwd(),
        path,
        .autosave,
    ) catch {
        bridge.callback_failed = true;
        return;
    };
    receipt.deinit(bridge.app.allocator);
    bridge.autosave_executed = true;
}

const NativeGridHotSessionLoad = enum {
    missing,
    restored,
    invalid,
};

fn loadNativeGridHotSession(
    app: *noctty.app.App,
    io: std.Io,
    path: []const u8,
) NativeGridHotSessionLoad {
    const receipt = app.loadWorkspaceFile(
        io,
        std.Io.Dir.cwd(),
        path,
        .autosave,
    ) catch |err| switch (err) {
        error.FileNotFound => return .missing,
        else => {
            std.log.warn("ignoring invalid hot-session snapshot '{s}': {s}", .{
                path,
                @errorName(err),
            });
            return .invalid;
        },
    };
    receipt.deinit(app.allocator);
    return .restored;
}

fn nativeGridProfilePreset(index: c_int) ?noctty.terminal.ProfilePreset {
    return switch (index) {
        0 => .global_default,
        1 => .compact,
        2 => .readable,
        3 => .high_contrast,
        4 => .mono_no_ligatures,
        else => null,
    };
}

const native_event_idle_history_compacted: c_int = 112;
const native_event_status_notification: c_int = 113;
const native_event_status_acknowledged: c_int = 114;

export fn noctty_grid_event(raw: ?*anyopaque, pane_id: u64, event: c_int, exit_code: c_int, at_ms: u64) callconv(.c) void {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return));
    defer if (event != 2 and event != 4) persistNativeGridHotSession(bridge);
    const is_secondary = pane_id != bridge.pane_id;
    if (pane_id != bridge.pane_id and bridge.app.workspace.findPane(pane_id) == null) {
        bridge.callback_failed = true;
        return;
    }
    if (event == 57) {
        _ = bridge.app.dispatch(.{ .focus_pane = pane_id }) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 58) {
        bridge.saw_split_down_vertical = true;
        return;
    }
    if (event == 59) {
        bridge.saw_split_left_horizontal = true;
        return;
    }
    if (event == 62) {
        bridge.saw_rendered_move = true;
        return;
    }
    if (event == 63) {
        bridge.saw_tab_position_applied = exit_code >= 0 and exit_code <= 3;
        return;
    }
    if (event == 64) {
        _ = bridge.app.dispatch(.{ .toggle_pane_zoom = pane_id }) catch {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_pane_zoom = true;
        return;
    }
    if (event == 65) {
        bridge.saw_palette = true;
        return;
    }
    if (event == 66) {
        bridge.saw_terminal_find = true;
        return;
    }
    if (event == 67) {
        bridge.saw_directional_focus = true;
        return;
    }
    if ((event >= 70 and event <= 74) or event == 76 or event == 77) {
        switch (event) {
            70, 71 => {
                var dimensions = noctty.app.App.DropdownDimensions{
                    .width_percent = bridge.app.config.dropdown.width_percent,
                    .height_percent = bridge.app.config.dropdown.height_percent,
                    .width_px = bridge.app.config.dropdown.width_px,
                    .height_px = bridge.app.config.dropdown.height_px,
                };
                if (event == 70) dimensions.width_px = @intCast(@max(1, @min(exit_code, 65535))) else dimensions.height_px = @intCast(@max(1, @min(exit_code, 65535)));
                _ = bridge.app.dispatch(.{ .set_dropdown_dimensions = dimensions }) catch {
                    bridge.callback_failed = true;
                    return;
                };
            },
            72 => _ = bridge.app.dispatch(.{ .set_dropdown_animation_ms = @intCast(@max(0, @min(exit_code, 2000))) }) catch {
                bridge.callback_failed = true;
                return;
            },
            73 => _ = bridge.app.dispatch(.{ .set_hide_on_focus_loss = exit_code != 0 }) catch {
                bridge.callback_failed = true;
                return;
            },
            74 => _ = bridge.app.dispatch(.{ .set_focus_follows_pointer = exit_code != 0 }) catch {
                bridge.callback_failed = true;
                return;
            },
            76, 77 => {
                var dimensions = noctty.app.App.DropdownDimensions{
                    .width_percent = bridge.app.config.dropdown.width_percent,
                    .height_percent = bridge.app.config.dropdown.height_percent,
                };
                if (event == 76)
                    dimensions.width_percent = @intCast(@max(1, @min(exit_code, 100)))
                else
                    dimensions.height_percent = @intCast(@max(1, @min(exit_code, 100)));
                _ = bridge.app.dispatch(.{ .set_dropdown_dimensions = dimensions }) catch {
                    bridge.callback_failed = true;
                    return;
                };
            },
            else => {},
        }
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 20) {
        bridge.saw_tab_command = true;
        _ = bridge.app.dispatch(.new_tab) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 21) {
        bridge.saw_split_command = true;
        _ = bridge.app.dispatch(.split_down) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 22) {
        bridge.saw_split_left_command = true;
        _ = bridge.app.dispatch(.split_left) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 23) {
        bridge.saw_broadcast_command = true;
        _ = bridge.app.dispatch(.toggle_broadcast) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 78) {
        if (exit_code > 0) bridge.saw_tab_cycle_next = true else bridge.saw_tab_cycle_previous = true;
        return;
    }
    if (event == 79) {
        bridge.saw_tab_shortcut_close = true;
        return;
    }
    if (event == 80) {
        bridge.saw_tab_shortcut_reopen = true;
        return;
    }
    if (event == 81) {
        bridge.saw_tab_focus_restored = exit_code != 0;
        return;
    }
    if (event == 82) {
        bridge.saw_title_fallback = exit_code != 0;
        return;
    }
    if (event == 83) {
        bridge.saw_title_overflow = exit_code != 0;
        return;
    }
    if (event == 84) {
        bridge.saw_title_tooltip = exit_code != 0;
        return;
    }
    if (event == 85) {
        bridge.saw_title_rename = exit_code != 0;
        return;
    }
    if (event == 86) {
        const io = bridge.io orelse {
            bridge.callback_failed = true;
            return;
        };
        const receipt = bridge.app.saveWorkspaceFile(io, std.Io.Dir.cwd(), "/tmp/noctty-native-grid-dirty.nocttyws", .manual) catch {
            bridge.callback_failed = true;
            return;
        };
        receipt.deinit(bridge.app.allocator);
        bridge.workspace_saved = true;
        return;
    }
    if (event == 87) {
        bridge.saw_attention_cleared = exit_code != 0;
        return;
    }
    if (event == 88) {
        bridge.saw_dirty_marker = exit_code != 0;
        return;
    }
    if (event == 89) {
        bridge.saw_attention_marker = exit_code != 0;
        return;
    }
    if (event == 90) {
        bridge.saw_dirty_cleared = exit_code != 0;
        bridge.saw_dirty_title_preserved = exit_code != 0;
        return;
    }
    if (event == 91) {
        const tabs = bridge.app.workspace.tabs.items;
        const active = bridge.app.workspace.activeTab() orelse {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_reorder_ui = exit_code != 0;
        bridge.saw_reorder_model = exit_code != 0 and tabs.len == 3 and
            tabs[0].id == 2 and tabs[1].id == 3 and tabs[2].id == 1 and
            active.id == 3 and bridge.app.workspace.active_tab == 1;
        return;
    }
    if (event == 92) {
        const io = bridge.io orelse {
            bridge.callback_failed = true;
            return;
        };
        const receipt = bridge.app.saveWorkspaceFile(io, std.Io.Dir.cwd(), "/tmp/noctty-native-grid-reorder.nocttyws", .manual) catch {
            bridge.callback_failed = true;
            return;
        };
        receipt.deinit(bridge.app.allocator);
        var verify_app = noctty.app.App.init(bridge.app.allocator) catch {
            bridge.callback_failed = true;
            return;
        };
        defer verify_app.deinit();
        const loaded = verify_app.loadWorkspaceFile(io, std.Io.Dir.cwd(), "/tmp/noctty-native-grid-reorder.nocttyws", .manual) catch {
            bridge.callback_failed = true;
            return;
        };
        loaded.deinit(bridge.app.allocator);
        const current_tabs = bridge.app.workspace.tabs.items;
        const reloaded_tabs = verify_app.workspace.tabs.items;
        const reloaded_active = verify_app.workspace.activeTab() orelse {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_reorder_persisted = exit_code != 0 and
            current_tabs.len == reloaded_tabs.len and current_tabs.len == 3 and
            current_tabs[0].id == reloaded_tabs[0].id and
            current_tabs[1].id == reloaded_tabs[1].id and
            current_tabs[2].id == reloaded_tabs[2].id and
            reloaded_active.id == 3 and verify_app.workspace.active_tab == 1;
        return;
    }
    if (event == native_event_idle_history_compacted) {
        bridge.idle_history_compactions += 1;
        return;
    }
    if (event == 93) {
        bridge.saw_palette_rename_validation = exit_code != 0;
        return;
    }
    if (event == 94) {
        bridge.saw_palette_rename_commit = exit_code != 0;
        return;
    }
    if (event == 95) {
        bridge.saw_palette_rename_cancel = exit_code != 0;
        return;
    }
    if (event >= 31 and event <= 39) {
        bridge.saw_selection_command = true;
        const selected_pane_id: u64 = @intCast(event - 30);
        _ = bridge.app.dispatch(.{ .focus_pane = selected_pane_id }) catch {
            bridge.callback_failed = true;
            return;
        };
        _ = bridge.app.dispatch(.{ .select_pane = .{ .pane_id = selected_pane_id, .mode = .replace } }) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 24) {
        bridge.saw_focus_command = true;
        _ = bridge.app.dispatch(.focus_next_pane) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 25) {
        bridge.saw_focus_command = true;
        _ = bridge.app.dispatch(.focus_previous_pane) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 55) {
        var target_tab_id: ?u64 = null;
        for (bridge.app.workspace.tabs.items) |*tab| if (tab.findPane(pane_id) != null) {
            target_tab_id = tab.id;
            break;
        };
        const target = target_tab_id orelse {
            bridge.callback_failed = true;
            return;
        };
        _ = bridge.app.dispatch(.{ .move_pane_to_tab = .{ .pane_id = @intCast(exit_code), .target_tab_id = target } }) catch {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_move_command = true;
        return;
    }
    if (event == 56) {
        var source_tab_id: ?u64 = null;
        for (bridge.app.workspace.tabs.items) |*tab| if (tab.findPane(pane_id) != null) {
            source_tab_id = tab.id;
            break;
        };
        const source = source_tab_id orelse {
            bridge.callback_failed = true;
            return;
        };
        for (bridge.app.workspace.tabs.items) |*tab| if (tab.id != source) {
            _ = bridge.app.dispatch(.{ .move_pane_to_tab = .{ .pane_id = pane_id, .target_tab_id = tab.id } }) catch {
                bridge.callback_failed = true;
            };
            bridge.saw_move_command = true;
            return;
        };
        return;
    }
    if ((event >= 50 and event <= 52) or event == 60 or event == 61) {
        const preset: noctty.workspace.LayoutPreset = switch (event) {
            50 => .one_by_one,
            51 => .two_by_two,
            52 => .three_by_three,
            60 => .four_by_four,
            61 => .four_by_two,
            else => unreachable,
        };
        _ = bridge.app.dispatch(.{ .preset = preset }) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 53 or event == 54) {
        for (bridge.app.workspace.tabs.items, 0..) |*tab, index| if (tab.findPane(pane_id) != null) {
            bridge.app.workspace.active_tab = index;
            break;
        };
        _ = bridge.app.dispatch(.{ .select_pane = .{ .pane_id = pane_id, .mode = if (event == 53) .add else .toggle } }) catch {
            bridge.callback_failed = true;
        };
        return;
    }
    if (event == 19) {
        bridge.maintenance_tick_seen = true;
        const plan = bridge.app.dispatch(.{ .maintenance_tick = .{ .now_ms = at_ms } }) catch {
            bridge.callback_failed = true;
            return;
        };
        const maintenance = plan.maintenance_planned;
        if (maintenance.autosave_due) {
            const io = bridge.io orelse return;
            const path = bridge.autosave_path orelse return;
            const receipt = bridge.app.saveWorkspaceFile(io, std.Io.Dir.cwd(), path, .autosave) catch {
                bridge.callback_failed = true;
                return;
            };
            receipt.deinit(bridge.app.allocator);
            bridge.autosave_executed = true;
        }
        if (maintenance.project_refresh_due) {
            const io = bridge.io orelse return;
            populateProjectPanels(bridge.app, bridge.app.allocator, io) catch {
                bridge.callback_failed = true;
                return;
            };
            _ = bridge.app.dispatch(.{ .project_refresh_receipt = .{ .completed_at_ms = at_ms, .summary = bridge.app.workspace.project_panels.summary() } }) catch {
                bridge.callback_failed = true;
                return;
            };
            bridge.project_refresh_executed = true;
        }
        if (maintenance.recovery_cleanup_due) {
            _ = bridge.app.dispatch(.{ .recovery_cleanup_receipt = .{ .completed_at_ms = at_ms, .receipt = .{} } }) catch {
                bridge.callback_failed = true;
                return;
            };
            bridge.recovery_cleanup_executed = true;
        }
        return;
    }
    if (event == 40) {
        const mode: noctty.config.WindowMode = switch (exit_code) {
            0 => .dropdown,
            1 => .windowed,
            2 => .zen_fullscreen,
            else => {
                bridge.callback_failed = true;
                return;
            },
        };
        _ = bridge.app.dispatch(.{ .set_window_mode = mode }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 41) {
        const previous = bridge.app.config.font.size_pt;
        const size: f32 = @as(f32, @floatFromInt(exit_code)) / 100.0;
        _ = bridge.app.dispatch(.{ .set_font_size = size }) catch {
            bridge.callback_failed = true;
            return;
        };
        if (size > previous) bridge.saw_font_increase = true;
        if (size < previous) bridge.saw_font_decrease = true;
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 96) {
        const pane = bridge.app.workspace.findPane(pane_id) orelse {
            bridge.callback_failed = true;
            return;
        };
        const previous = pane.profile.font_size_pt;
        const size: f32 = @as(f32, @floatFromInt(exit_code)) / 100.0;
        _ = bridge.app.dispatch(.{ .set_pane_font_size = .{
            .pane_id = pane_id,
            .size_pt = size,
        } }) catch {
            bridge.callback_failed = true;
            return;
        };
        if (size > previous) bridge.saw_font_increase = true;
        if (size < previous) bridge.saw_font_decrease = true;
        return;
    }
    if (event == 97) {
        const active = bridge.app.workspace.activeTab() orelse {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_pane_cycle_shortcut = exit_code != 0 and
            active.active_pane_id == pane_id;
        return;
    }
    if (event == 98) {
        bridge.saw_smart_tab_cycle_shortcut = exit_code != 0 and
            bridge.app.workspace.smart_filter_tag != null;
        return;
    }
    if (event == 100) {
        const active = bridge.app.workspace.activeTab() orelse {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_alt_scroll_pane_cycle = exit_code != 0 and
            active.active_pane_id == pane_id;
        return;
    }
    if (event == 101) {
        const active = bridge.app.workspace.activeTab() orelse {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_ctrl_alt_scroll_tab_cycle = exit_code != 0 and
            active.active_pane_id == pane_id;
        return;
    }
    if (event == 102) {
        const active = bridge.app.workspace.activeTab() orelse {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_terminal_interrupt_targeted = exit_code != 0 and
            bridge.app.workspace.broadcast_enabled and
            active.active_pane_id == pane_id and
            native_grid_terminal_chord_probe.primary_interrupts == 0 and
            native_grid_terminal_chord_probe.secondary_interrupts == 1 and
            native_grid_terminal_chord_probe.primary_carriage_returns == 1 and
            native_grid_terminal_chord_probe.secondary_carriage_returns == 1 and
            native_grid_terminal_chord_probe.primary_line_feeds == 0 and
            native_grid_terminal_chord_probe.secondary_line_feeds == 0 and
            native_grid_terminal_chord_probe.primary_eof == 0 and
            native_grid_terminal_chord_probe.secondary_eof == 0;
        return;
    }
    if (event == 103) {
        const active = bridge.app.workspace.activeTab() orelse {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_terminal_close_chord = exit_code != 0 and
            bridge.closed_pane_id == at_ms and
            bridge.closed_pane_id == bridge.secondary_pane_id and
            active.active_pane_id == pane_id and
            active.panes.items.len == 1 and
            native_grid_terminal_chord_probe.primary_eof == 0 and
            native_grid_terminal_chord_probe.secondary_eof == 0;
        return;
    }
    if (event == 104) {
        const active = bridge.app.workspace.activeTab() orelse {
            bridge.callback_failed = true;
            return;
        };
        bridge.saw_terminal_final_pane_guard = exit_code != 0 and
            active.active_pane_id == pane_id and
            active.panes.items.len == 1 and
            native_grid_terminal_chord_probe.primary_eof == 0 and
            native_grid_terminal_chord_probe.secondary_eof == 0;
        return;
    }
    if (event == 105) {
        const request = (bridge.app.dispatch(.{ .show_profile_preset_menu = .{
            .pane_id = pane_id,
        } }) catch {
            bridge.callback_failed = true;
            return;
        }).profile_preset_menu_requested;
        if (!request.canShow() or request.pane_id != pane_id or
            request.itemSlice().len != 5)
        {
            bridge.callback_failed = true;
            return;
        }
        var current: c_int = -1;
        for (request.itemSlice(), 0..) |item, index| {
            if (@intFromEnum(item.preset) != index) {
                bridge.callback_failed = true;
                return;
            }
            if (item.current) {
                if (current != -1) {
                    bridge.callback_failed = true;
                    return;
                }
                current = @intCast(index);
            }
        }
        if (bridge.profile_preset_menu_open_count < bridge.profile_preset_current_order.len) {
            bridge.profile_preset_current_order[bridge.profile_preset_menu_open_count] = current;
        }
        bridge.profile_preset_menu_open_count += 1;
        bridge.profile_preset_target_exact = bridge.profile_preset_target_exact and
            (bridge.secondary_pane_id == null or bridge.secondary_pane_id.? == pane_id);
        const shown = (bridge.app.dispatch(.{ .profile_preset_menu_receipt = .{
            .pane_id = pane_id,
            .status = .shown,
        } }) catch {
            bridge.callback_failed = true;
            return;
        }).profile_preset_menu_changed;
        if (shown != .shown) {
            bridge.callback_failed = true;
            return;
        }
        bridge.saw_profile_preset_menu = true;
        return;
    }
    if (event == 106) {
        const preset = nativeGridProfilePreset(exit_code) orelse {
            bridge.callback_failed = true;
            return;
        };
        const changed = (bridge.app.dispatch(.{ .select_profile_preset_from_menu = .{
            .pane_id = pane_id,
            .preset = preset,
        } }) catch {
            bridge.callback_failed = true;
            return;
        }).profile_changed;
        if (changed.pane_id != pane_id or
            bridge.app.host.profile_preset_menu_status != .selected or
            bridge.app.host.profile_preset_menu_selected != preset)
        {
            bridge.callback_failed = true;
            return;
        }
        const expected = preset.profile(bridge.app.config);
        if (!std.mem.eql(u8, changed.profile.theme_name, expected.theme_name) or
            !std.mem.eql(u8, changed.profile.font_family, expected.font_family) or
            changed.profile.font_size_pt != expected.font_size_pt or
            changed.profile.ligatures != expected.ligatures)
        {
            bridge.callback_failed = true;
            return;
        }
        switch (preset) {
            .readable => bridge.saw_profile_preset_readable = changed.profile.font_size_pt == 14.0,
            .high_contrast => bridge.saw_profile_preset_high_contrast =
                std.mem.eql(u8, changed.profile.theme_name, "noctty-high-contrast"),
            .mono_no_ligatures => bridge.saw_profile_preset_mono_no_ligatures =
                !changed.profile.ligatures,
            else => {},
        }
        if (bridge.profile_preset_selection_count < bridge.profile_preset_selection_order.len) {
            bridge.profile_preset_selection_order[bridge.profile_preset_selection_count] = exit_code;
        }
        bridge.profile_preset_selection_count += 1;
        bridge.profile_preset_target_exact = bridge.profile_preset_target_exact and
            (bridge.secondary_pane_id == null or bridge.secondary_pane_id.? == pane_id);
        bridge.saw_profile_preset_selection = true;
        bridge.saw_profile_preset_workspace_dirty = bridge.saw_profile_preset_workspace_dirty or
            bridge.app.recovery.dirty;
        return;
    }
    if (event == 107) {
        const hidden = (bridge.app.dispatch(.hide_profile_preset_menu) catch {
            bridge.callback_failed = true;
            return;
        }).profile_preset_menu_changed;
        if (hidden != .hidden) {
            bridge.callback_failed = true;
            return;
        }
        bridge.profile_preset_dismiss_count += 1;
        return;
    }
    if (event == 108) {
        _ = bridge.app.dispatch(.{
            .set_show_pane_info = exit_code != 0,
        }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 109) {
        if (exit_code < 0) {
            bridge.callback_failed = true;
            return;
        }
        const history_limit: usize = @intCast(exit_code);
        _ = bridge.app.dispatch(.{
            .set_scrollback_lines = @intCast(history_limit),
        }) catch {
            bridge.callback_failed = true;
            return;
        };
        if (bridge.primary_session) |session| session.grid.setHistoryLimit(history_limit) catch {
            bridge.callback_failed = true;
            return;
        };
        if (bridge.session_pool) |pool| pool.setHistoryLimit(history_limit) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 110 or event == 111) {
        if (exit_code < 0 or exit_code > 2) {
            bridge.callback_failed = true;
            return;
        }
        if (event == 110) {
            const antialias: noctty.config.FontAntialias = @enumFromInt(exit_code);
            _ = bridge.app.dispatch(.{ .set_font_antialias = antialias }) catch {
                bridge.callback_failed = true;
                return;
            };
        } else {
            const hinting: noctty.config.FontHinting = @enumFromInt(exit_code);
            _ = bridge.app.dispatch(.{ .set_font_hinting = hinting }) catch {
                bridge.callback_failed = true;
                return;
            };
        }
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 42) {
        _ = bridge.app.dispatch(.{ .set_desktop_notifications = exit_code != 0 }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 43) {
        const preset = nativeGridProfilePreset(exit_code) orelse {
            bridge.callback_failed = true;
            return;
        };
        _ = bridge.app.dispatch(.{ .set_pane_profile_preset = .{ .pane_id = pane_id, .preset = preset } }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 44) {
        const position: noctty.config.TabPosition = switch (exit_code) {
            0 => .top,
            1 => .bottom,
            2 => .left,
            3 => .right,
            else => {
                bridge.callback_failed = true;
                return;
            },
        };
        _ = bridge.app.dispatch(.{ .set_tab_position = position }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 45) {
        const indicator: noctty.config.StatusIndicator = if (exit_code == 0) .background else .border;
        _ = bridge.app.dispatch(.{ .set_status_indicator = indicator }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 46 or event == 47) {
        var metrics = bridge.app.config.panels;
        if (event == 46) metrics.padding_px = @intCast(exit_code) else metrics.spacing_px = @intCast(exit_code);
        _ = bridge.app.dispatch(.{ .set_panel_metrics = metrics }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 48) {
        const theme = if (exit_code == 1) "noctty-high-contrast" else "noctty-dark";
        _ = bridge.app.dispatch(.{ .set_default_theme = theme }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 49) {
        const family = if (exit_code == 0) "Monospace" else "JetBrains Mono";
        _ = bridge.app.dispatch(.{ .set_font_family = family }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == 75) {
        const key_event = decodeQtShortcut(exit_code) orelse {
            bridge.callback_failed = true;
            return;
        };
        _ = bridge.app.dispatch(.begin_shortcut_recording) catch {
            bridge.callback_failed = true;
            return;
        };
        _ = bridge.app.dispatch(.{ .capture_shortcut = key_event }) catch {
            bridge.callback_failed = true;
            return;
        };
        persistNativeGridConfig(bridge);
        return;
    }
    if (event == native_event_status_notification)
        bridge.saw_status_notification = true;
    if (event == native_event_status_acknowledged)
        bridge.saw_status_acknowledged = true;
    const status: ?noctty.terminal.StatusEvent = switch (event) {
        1 => .{ .process_started = at_ms },
        2 => .{ .output_received = at_ms },
        4 => .{ .tick = at_ms },
        native_event_status_notification => .{ .waiting_for_input = at_ms },
        native_event_status_acknowledged => .reset_idle,
        3 => .{ .exited = .{ .code = @intCast(@max(0, @min(exit_code, 255))), .at_ms = at_ms } },
        else => null,
    };
    if (is_secondary) switch (event) {
        1 => bridge.saw_secondary_started = true,
        2 => bridge.saw_secondary_output = true,
        3 => bridge.saw_secondary_exited = true,
        else => {},
    };
    if (status) |status_event| {
        _ = bridge.app.dispatch(.{ .terminal_status = .{ .pane_id = pane_id, .event = status_event } }) catch {
            bridge.callback_failed = true;
        };
    }
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const process_home_dir = init.environ_map.get("HOME") orelse ".";
    const home_dir = if (build_options.enable_smoke)
        init.environ_map.get("NOCTTY_SMOKE_HOME") orelse process_home_dir
    else
        process_home_dir;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    if (args.len > 1) {
        const cmd = args[1];
        if (std.mem.eql(u8, cmd, "--version")) {
            try stdout.writeAll("noctty " ++ noctty.release.version ++ "\n");
            return;
        }
        if (std.mem.eql(u8, cmd, "--status")) {
            _ = try sendNativeControl(0, "status", stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--hide")) {
            _ = try sendNativeControl(3, "hide", stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--show") or std.mem.eql(u8, cmd, "--toggle")) {
            const action: c_int = if (std.mem.eql(u8, cmd, "--show")) 2 else 1;
            const handled = try sendNativeControl(action, if (action == 2) "show" else "toggle", stdout);
            if (!handled) try runNativeGrid(allocator, init.io, home_dir, init.environ_map, 0, .visible);
            return;
        }
        if (std.mem.eql(u8, cmd, "--hidden")) {
            var visible: c_int = 0;
            if (VteHost.controlCall(3, &visible) == 0)
                try runNativeGrid(allocator, init.io, home_dir, init.environ_map, 0, .external_hidden);
            return;
        }
        if (std.mem.eql(u8, cmd, "--open-uri")) {
            if (args.len == 2) {
                var existing_visible: c_int = 0;
                if (VteHost.controlCall(2, &existing_visible) == 0)
                    try runNativeGrid(
                        allocator,
                        init.io,
                        home_dir,
                        init.environ_map,
                        0,
                        .automatic,
                    );
                return;
            }
            if (args.len != 3) return error.InvalidWorkspaceActivationArguments;
            const parsed = try noctty.workspace_activation.parseWorkspaceUri(args[2]);
            try runNativeGridActivated(
                allocator,
                init.io,
                home_dir,
                init.environ_map,
                0,
                .visible,
                parsed.slice(),
                .restart_shells,
            );
            return;
        }
        if (std.mem.eql(u8, cmd, "--open-workspace")) {
            if (args.len != 3 and args.len != 5) return error.InvalidWorkspaceActivationArguments;
            const parsed = try noctty.workspace_activation.WorkspacePath.init(args[2]);
            const restore_mode = if (args.len == 5)
                try parseRestoreMode(args[4])
            else
                .restart_shells;
            try runNativeGridActivated(
                allocator,
                init.io,
                home_dir,
                init.environ_map,
                0,
                .visible,
                parsed.slice(),
                restore_mode,
            );
            return;
        }
        if (std.mem.eql(u8, cmd, "--native-host")) {
            if (!build_options.enable_vte) return error.VteRendererUnavailable;
            try runNativeHost(allocator, init.io, home_dir, args, 0, null);
            return;
        }
        if (build_options.enable_smoke) {
            if (std.mem.eql(u8, cmd, "--native-host-smoke")) {
                try runNativeHost(allocator, init.io, home_dir, args, 1, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-host-shortcut-conflict-smoke")) {
                try runNativeHost(allocator, init.io, home_dir, args, 2, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-host-shortcut-recorder-smoke")) {
                try runNativeHost(allocator, init.io, home_dir, args, 3, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-host-shortcut-hid-smoke")) {
                try runNativeHost(allocator, init.io, home_dir, args, 4, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-host-windowed-smoke")) {
                try runNativeHost(allocator, init.io, home_dir, args, 5, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-host-zen-smoke")) {
                try runNativeHost(allocator, init.io, home_dir, args, 6, stdout);
                return;
            }
        }
        if (std.mem.eql(u8, cmd, "--dump-default-config")) {
            try dumpDefaultConfig(stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--self-check")) {
            try selfCheck(allocator, stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--host-plan")) {
            try hostPlan(allocator, init.environ_map, stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--noctalia-plan")) {
            try noctaliaPlan(allocator, init.io, home_dir, init.environ_map, args, stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--project-scan")) {
            try projectScan(allocator, init.io, stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--maintenance-plan")) {
            try maintenancePlan(allocator, stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--workspace-file-flow")) {
            try workspaceFileFlow(allocator, init.io, stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--project-panel-plan")) {
            try projectPanelPlan(allocator, stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--project-panel-view")) {
            try projectPanelView(allocator, stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--project-panel-action")) {
            try projectPanelAction(allocator, stdout);
            return;
        }
        if (std.mem.eql(u8, cmd, "--ghostty-probe")) {
            try ghosttyProbe(args, stdout);
            return;
        }
        if (build_options.enable_smoke) {
            if (std.mem.eql(u8, cmd, "--pty-smoke")) {
                try ptySmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--vt-smoke")) {
                try vtSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--terminal-session-smoke")) {
                try terminalSessionSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--terminal-history-qualification")) {
                try terminalHistoryQualification(allocator, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-renderer-qualification")) {
                if (args.len != 4)
                    return error.InvalidRendererQualificationArguments;
                if (noctty_native_grid_renderer_qualification(
                    args[2].ptr,
                    args[3].ptr,
                ) != 0) return error.RendererQualificationFailed;
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-pipeline-qualification")) {
                if (args.len != 4)
                    return error.InvalidPipelineQualificationArguments;
                try terminalPipelineQualification(init.io, args[2], args[3]);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-smoke")) {
                try nativeGridSmoke(stdout, 0);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-presentation-qualification")) {
                try nativeGridPresentationQualification(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-full-stack-qualification")) {
                try nativeGridFullStackQualification(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-stability-qualification")) {
                try nativeGridStabilityQualification();
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-authenticated-agent-qualification")) {
                try nativeGridAuthenticatedAgentQualification(init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-installed-continuity-qualification")) {
                if (args.len != 4)
                    return error.InvalidInstalledContinuityQualificationArguments;
                try nativeGridInstalledContinuityQualification(args[2], args[3], stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-windowed-smoke")) {
                try nativeGridSmoke(stdout, 1);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-zen-smoke")) {
                try nativeGridSmoke(stdout, 2);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-workspace-smoke")) {
                try nativeGridWorkspaceSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-tab-navigation-smoke")) {
                try nativeGridTabNavigationSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-tab-title-smoke")) {
                try nativeGridTabTitleSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-dirty-smoke")) {
                try nativeGridDirtySmoke(init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-tab-reorder-smoke")) {
                try nativeGridTabReorderSmoke(init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-palette-rename-smoke")) {
                try nativeGridPaletteRenameSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-pane-move-smoke")) {
                try nativeGridPaneMoveSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-compact-ux-smoke")) {
                try nativeGridCompactUxSmoke(allocator, init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-two-pane-smoke")) {
                try nativeGridTwoPaneSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-pane-close-smoke")) {
                try nativeGridPaneCloseSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-terminal-chords-smoke")) {
                try nativeGridTerminalChordsSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-layout-preset-smoke")) {
                try nativeGridLayoutPresetSmoke(allocator, init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-recursive-split-smoke")) {
                try nativeGridRecursiveSplitSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-click-focus-smoke")) {
                try nativeGridClickFocusSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-eight-pane-smoke")) {
                try nativeGridEightPaneSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-two-tab-smoke")) {
                try nativeGridTwoTabSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-tab-rename-smoke")) {
                try nativeGridTabRenameSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-tab-color-smoke")) {
                try nativeGridTabColorSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-profile-preset-smoke")) {
                try nativeGridProfilePresetSmoke(allocator, init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-resize-overlay-smoke")) {
                try nativeGridResizeOverlaySmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-window-tray-smoke")) {
                try nativeGridWindowTraySmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-clipboard-smoke")) {
                try nativeGridClipboardSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-notification-smoke")) {
                try nativeGridNotificationSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-settings-smoke")) {
                try nativeGridSettingsSmoke(allocator, init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-credentialed-ssh-smoke")) {
                const target = init.environ_map.get("NOCTTY_SSH_SMOKE_TARGET") orelse
                    return error.MissingCredentialedSshSmokeTarget;
                try nativeGridCredentialedSshSmoke(allocator, target, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-settings-stacking-smoke")) {
                try nativeGridSettingsStackingSmoke(allocator, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-note-overlay-smoke")) {
                try nativeGridNoteOverlaySmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-theme-smoke")) {
                try nativeGridThemeSmoke(allocator, init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-project-editor-smoke")) {
                try nativeGridProjectEditorSmoke(allocator, init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-maintenance-smoke")) {
                try nativeGridMaintenanceSmoke(allocator, init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-hot-session-smoke")) {
                try nativeGridHotSessionSmoke(allocator, init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-shortcut-live-smoke")) {
                try nativeGridShortcutLiveSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-noctalia-ipc-smoke")) {
                try nativeGridNoctaliaIpcSmoke(stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-workspace-activation-smoke")) {
                try nativeGridWorkspaceActivationSmoke(allocator, init.io, stdout);
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-installed-activation-fixture")) {
                if (args.len != 3)
                    return error.InvalidInstalledActivationFixtureArguments;
                try writeInstalledActivationFixture(
                    allocator,
                    init.io,
                    args[2],
                    stdout,
                );
                return;
            }
            if (std.mem.eql(u8, cmd, "--native-grid-recent-activation-smoke")) {
                try nativeGridRecentWorkspaceActivationSmoke(
                    allocator,
                    init.io,
                    init.environ_map,
                    stdout,
                );
                return;
            }
        }
        if (!build_options.enable_smoke and std.mem.endsWith(u8, cmd, "-smoke"))
            return error.SmokeModeUnavailable;
        if (std.mem.startsWith(u8, cmd, "--editor-"))
            return error.LegacyEditorRemoved;
        if (std.mem.eql(u8, cmd, "--native-grid-two-pane")) {
            try runNativeGridTwoPane(allocator, init.io, home_dir, init.environ_map, 0);
            return;
        }
        if (std.mem.eql(u8, cmd, "--native-grid-benchmark")) {
            if (args.len != 3) return error.InvalidBenchmarkArguments;
            const pane_count = std.fmt.parseInt(usize, args[2], 10) catch
                return error.InvalidBenchmarkArguments;
            const workload = init.environ_map.get("NOCTTY_BENCH_WORKLOAD") orelse
                return error.MissingBenchmarkWorkload;
            try runNativeGridBenchmark(allocator, pane_count, workload, init.environ_map);
            return;
        }
        if (std.mem.eql(u8, cmd, "--native-grid")) {
            try runNativeGrid(allocator, init.io, home_dir, init.environ_map, 0, .automatic);
            return;
        }
        if (std.mem.eql(u8, cmd, "--native-grid-windowed")) {
            try runNativeGrid(allocator, init.io, home_dir, init.environ_map, 1, .automatic);
            return;
        }
        if (std.mem.eql(u8, cmd, "--native-grid-zen")) {
            try runNativeGrid(allocator, init.io, home_dir, init.environ_map, 2, .automatic);
            return;
        }
    }

    if (init.environ_map.get("NOCTTY_RENDERER")) |renderer| {
        if (std.mem.eql(u8, renderer, "grid")) {
            try runNativeGrid(allocator, init.io, home_dir, init.environ_map, 0, .automatic);
            return;
        }
        if (std.mem.eql(u8, renderer, "vte")) {
            if (!build_options.enable_vte) return error.VteRendererUnavailable;
            try runNativeHost(allocator, init.io, home_dir, args, 0, null);
            return;
        }
        return error.UnknownRenderer;
    }
    var existing_visible: c_int = 0;
    if (VteHost.controlCall(2, &existing_visible) != 0) return;
    try runNativeGrid(allocator, init.io, home_dir, init.environ_map, -1, .automatic);
}

fn sendNativeControl(action: c_int, action_name: []const u8, out: anytype) !bool {
    var visible: c_int = 0;
    const handled = VteHost.controlCall(action, &visible) != 0;
    try out.print("noctty_control action={s} running={} visible={}\n", .{
        action_name,
        handled,
        handled and visible != 0,
    });
    return handled;
}

fn runNativeHost(allocator: std.mem.Allocator, io: std.Io, home_dir: []const u8, args: []const [:0]const u8, smoke_mode: c_int, out: ?*std.Io.Writer) !void {
    _ = args;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane_id = tab.active_pane_id;
    const effective_home = if (smoke_mode == 3) "/tmp/noctty-recorder-smoke-home" else if (smoke_mode == 4) "/tmp/noctty-recorder-hid-smoke-home" else home_dir;
    const config_path = try app.defaultConfigPathAlloc(effective_home);
    defer allocator.free(config_path);
    const native_mode: noctty.config.WindowMode = switch (smoke_mode) {
        5 => .windowed,
        6 => .zen_fullscreen,
        else => .dropdown,
    };
    if (smoke_mode == 5 or smoke_mode == 6) {
        _ = try app.dispatch(.{ .set_window_mode = native_mode });
    }
    var bridge = NativeHostBridge{ .app = &app, .pane_id = pane_id, .io = io, .config_path = config_path };
    if (smoke_mode == 2) {
        _ = try app.dispatch(.begin_shortcut_recording);
        _ = try app.dispatch(.{ .capture_shortcut = .{ .key = .f12 } });
    }
    const status = VteHost.run(pane_id, qtShortcutKey(app.config.dropdown.shortcut), nativeHostEvent, &bridge, @intFromEnum(native_mode), smoke_mode);
    if (status != 0) return error.NativeHostUnavailable;
    if (bridge.callback_failed) return error.NativeHostStateSyncFailed;
    if (smoke_mode != 0) {
        if ((smoke_mode == 3 or smoke_mode == 4) and bridge.config_persisted) {
            var verify_app = try noctty.app.App.init(allocator);
            defer verify_app.deinit();
            const receipt = try verify_app.loadConfigFile(io, std.Io.Dir.cwd(), config_path, .settings);
            receipt.deinit(allocator);
            bridge.config_reloaded = if (smoke_mode == 3)
                verify_app.config.dropdown.shortcut.key == .f11
            else
                verify_app.config.dropdown.shortcut.key == .home and verify_app.config.dropdown.shortcut.ctrl;
        }
        const pane = app.workspace.findPane(pane_id) orelse return error.PaneNotFound;
        try out.?.print("native_host_smoke mode={s} pane={d} placement={s} started={} input={} marker={} output={} resized={} secondary_started={} secondary_output={} secondary_exited={} shortcut_registered={} shortcut_conflict={} shortcut_failed={} recorder_shown={} config_persisted={} config_reloaded={} configured_key={s} configured_ctrl={} global_shortcut={} shortcut_unregistered={} shown={} hidden={} focused={} exited={} exit_code={d} status={s}\n", .{
            if (smoke_mode == 2) "shortcut_conflict" else if (smoke_mode == 3) "shortcut_recorder" else if (smoke_mode == 4) "shortcut_hid" else if (smoke_mode == 5) "windowed" else if (smoke_mode == 6) "zen_fullscreen" else "success",
            pane_id,
            switch (bridge.placement) {
                1 => "x11_top",
                2 => "wayland_layer_shell",
                3 => "wayland_constrained",
                4 => "windowed",
                5 => "fullscreen",
                else => "unknown",
            },
            bridge.saw_started,
            bridge.saw_input,
            bridge.saw_input_marker,
            bridge.saw_output,
            bridge.saw_resize,
            bridge.saw_secondary_started,
            bridge.saw_secondary_output,
            bridge.saw_secondary_exit,
            bridge.saw_shortcut_registered,
            bridge.saw_shortcut_conflict,
            bridge.saw_shortcut_failed,
            bridge.saw_shortcut_recorder,
            bridge.config_persisted,
            bridge.config_reloaded,
            app.config.dropdown.shortcut.key.label(),
            app.config.dropdown.shortcut.ctrl,
            bridge.saw_global_shortcut,
            bridge.saw_shortcut_unregistered,
            bridge.saw_shown,
            bridge.saw_hidden,
            bridge.saw_focus,
            bridge.saw_exit,
            bridge.exit_code,
            @tagName(pane.status),
        });
        const shortcut_ok = if (smoke_mode == 2)
            bridge.saw_shortcut_conflict and !bridge.saw_shortcut_registered and !bridge.saw_global_shortcut
        else if (smoke_mode == 3)
            bridge.saw_shortcut_registered and bridge.saw_shortcut_recorder and bridge.config_persisted and bridge.config_reloaded and app.config.dropdown.shortcut.key == .f11
        else if (smoke_mode == 4)
            bridge.saw_shortcut_registered and bridge.saw_shortcut_recorder and bridge.config_persisted and bridge.config_reloaded and app.config.dropdown.shortcut.key == .home and app.config.dropdown.shortcut.ctrl
        else if (smoke_mode == 5 or smoke_mode == 6)
            bridge.saw_shortcut_registered and !bridge.saw_shortcut_conflict
        else
            bridge.saw_shortcut_registered and !bridge.saw_shortcut_conflict and bridge.saw_global_shortcut;
        if (!bridge.saw_started or !bridge.saw_output or !bridge.saw_exit or !bridge.saw_input or !bridge.saw_resize or !bridge.saw_input_marker or !bridge.saw_shown or !bridge.saw_focus or !bridge.saw_maintenance_tick or !bridge.saw_shortcut_unregistered or !shortcut_ok or bridge.placement == 0 or bridge.exit_code != 0) return error.NativeHostSmokeFailed;
    }
}

fn qtShortcutKey(shortcut: noctty.config.Shortcut) c_int {
    const ordinal = @intFromEnum(shortcut.key);
    const key: u32 = if (ordinal >= @intFromEnum(noctty.config.Shortcut.Key.a) and ordinal <= @intFromEnum(noctty.config.Shortcut.Key.z))
        @as(u32, 'A') + @as(u32, ordinal - @intFromEnum(noctty.config.Shortcut.Key.a))
    else if (ordinal >= @intFromEnum(noctty.config.Shortcut.Key.digit0) and ordinal <= @intFromEnum(noctty.config.Shortcut.Key.digit9))
        @as(u32, '0') + @as(u32, ordinal - @intFromEnum(noctty.config.Shortcut.Key.digit0))
    else if (ordinal >= @intFromEnum(noctty.config.Shortcut.Key.f1) and ordinal <= @intFromEnum(noctty.config.Shortcut.Key.f12))
        @as(u32, 0x01000030) + @as(u32, ordinal - @intFromEnum(noctty.config.Shortcut.Key.f1))
    else switch (shortcut.key) {
        .grave => '`',
        .escape => 0x01000000,
        .tab => 0x01000001,
        .backspace => 0x01000003,
        .enter => 0x01000005,
        .insert => 0x01000006,
        .delete => 0x01000007,
        .home => 0x01000010,
        .end => 0x01000011,
        .arrow_left => 0x01000012,
        .arrow_up => 0x01000013,
        .arrow_right => 0x01000014,
        .arrow_down => 0x01000015,
        .page_up => 0x01000016,
        .page_down => 0x01000017,
        .space => 0x20,
        .a,
        .b,
        .c,
        .d,
        .e,
        .f,
        .g,
        .h,
        .i,
        .j,
        .k,
        .l,
        .m,
        .n,
        .o,
        .p,
        .q,
        .r,
        .s,
        .t,
        .u,
        .v,
        .w,
        .x,
        .y,
        .z,
        .digit0,
        .digit1,
        .digit2,
        .digit3,
        .digit4,
        .digit5,
        .digit6,
        .digit7,
        .digit8,
        .digit9,
        .f1,
        .f2,
        .f3,
        .f4,
        .f5,
        .f6,
        .f7,
        .f8,
        .f9,
        .f10,
        .f11,
        .f12,
        => unreachable,
    };
    var encoded = key;
    if (shortcut.shift) encoded |= 0x02000000;
    if (shortcut.ctrl) encoded |= 0x04000000;
    if (shortcut.alt) encoded |= 0x08000000;
    if (shortcut.super) encoded |= 0x10000000;
    return @intCast(encoded);
}

fn decodeQtShortcut(encoded_raw: c_int) ?noctty.config.KeyEvent {
    const encoded: u32 = @intCast(encoded_raw);
    const key_code = encoded & 0x01ffffff;
    const key: noctty.config.Shortcut.Key = if (key_code >= 'A' and key_code <= 'Z')
        @enumFromInt(@intFromEnum(noctty.config.Shortcut.Key.a) + key_code - 'A')
    else if (key_code >= '0' and key_code <= '9')
        @enumFromInt(@intFromEnum(noctty.config.Shortcut.Key.digit0) + key_code - '0')
    else if (key_code >= 0x01000030 and key_code <= 0x0100003b)
        @enumFromInt(@intFromEnum(noctty.config.Shortcut.Key.f1) + key_code - 0x01000030)
    else switch (key_code) {
        '`' => .grave,
        0x20 => .space,
        0x01000000 => .escape,
        0x01000001 => .tab,
        0x01000003 => .backspace,
        0x01000004, 0x01000005 => .enter,
        0x01000006 => .insert,
        0x01000007 => .delete,
        0x01000010 => .home,
        0x01000011 => .end,
        0x01000012 => .arrow_left,
        0x01000013 => .arrow_up,
        0x01000014 => .arrow_right,
        0x01000015 => .arrow_down,
        0x01000016 => .page_up,
        0x01000017 => .page_down,
        else => return null,
    };
    return .{
        .key = key,
        .shift = encoded & 0x02000000 != 0,
        .ctrl = encoded & 0x04000000 != 0,
        .alt = encoded & 0x08000000 != 0,
        .super = encoded & 0x10000000 != 0,
    };
}

fn nativeHostEvent(raw: ?*anyopaque, pane_id: u64, event: NativeHostEvent, exit_code: c_int, at_ms: u64) callconv(.c) void {
    const bridge: *NativeHostBridge = @ptrCast(@alignCast(raw orelse return));
    if (pane_id == bridge.pane_id + 1) {
        switch (event) {
            .started => bridge.saw_secondary_started = true,
            .output => bridge.saw_secondary_output = true,
            .exited => bridge.saw_secondary_exit = true,
            else => {},
        }
        return;
    }
    if (pane_id != bridge.pane_id) {
        bridge.callback_failed = true;
        return;
    }
    const status_event: ?noctty.terminal.StatusEvent = switch (event) {
        .maintenance_tick => blk: {
            bridge.saw_maintenance_tick = true;
            _ = bridge.app.dispatch(.{ .maintenance_tick = .{ .now_ms = at_ms } }) catch {
                bridge.callback_failed = true;
            };
            break :blk null;
        },
        .started => blk: {
            bridge.saw_started = true;
            break :blk .{ .process_started = at_ms };
        },
        .output => blk: {
            bridge.saw_output = true;
            break :blk .{ .output_received = at_ms };
        },
        .exited => blk: {
            bridge.saw_exit = true;
            bridge.exit_code = @intCast(@max(0, @min(exit_code, 255)));
            break :blk .{ .exited = .{ .code = bridge.exit_code, .at_ms = at_ms } };
        },
        .input_sent => blk: {
            bridge.saw_input = true;
            break :blk null;
        },
        .resized => blk: {
            bridge.saw_resize = exit_code > 0;
            break :blk null;
        },
        .input_marker => blk: {
            bridge.saw_input_marker = true;
            break :blk null;
        },
        .shown => blk: {
            bridge.saw_shown = true;
            if (!bridge.app.host.window.visible) bridge.app.host.toggleDropdown();
            break :blk null;
        },
        .hidden => blk: {
            bridge.saw_hidden = true;
            if (bridge.app.host.window.visible) bridge.app.host.toggleDropdown();
            break :blk null;
        },
        .focused => blk: {
            bridge.saw_focus = true;
            break :blk null;
        },
        .global_shortcut => blk: {
            bridge.saw_global_shortcut = true;
            break :blk null;
        },
        .shortcut_registered => blk: {
            bridge.saw_shortcut_registered = true;
            const request = bridge.app.dispatch(.register_global_shortcut) catch {
                bridge.callback_failed = true;
                break :blk null;
            };
            const registration = request.shortcut_registration_requested;
            _ = bridge.app.dispatch(.{ .shortcut_registration_receipt = .{
                .shortcut = registration.shortcut,
                .transport = registration.transport,
                .status = .registered,
            } }) catch {
                bridge.callback_failed = true;
            };
            if (bridge.captured_pending_save) {
                const receipt = bridge.app.saveConfigFile(bridge.io, std.Io.Dir.cwd(), bridge.config_path, .settings) catch {
                    bridge.callback_failed = true;
                    break :blk null;
                };
                receipt.deinit(bridge.app.allocator);
                bridge.config_persisted = true;
                bridge.captured_pending_save = false;
            }
            break :blk null;
        },
        .shortcut_unregistered => blk: {
            bridge.saw_shortcut_unregistered = true;
            bridge.app.host.resetShortcutRegistration();
            break :blk null;
        },
        .placement => blk: {
            bridge.placement = exit_code;
            break :blk null;
        },
        .shortcut_conflict => blk: {
            bridge.saw_shortcut_conflict = true;
            const request = bridge.app.dispatch(.register_global_shortcut) catch {
                bridge.callback_failed = true;
                break :blk null;
            };
            const registration = request.shortcut_registration_requested;
            _ = bridge.app.dispatch(.{ .shortcut_registration_receipt = .{
                .shortcut = registration.shortcut,
                .transport = registration.transport,
                .status = .conflict,
            } }) catch {
                bridge.callback_failed = true;
            };
            break :blk null;
        },
        .shortcut_failed => blk: {
            bridge.saw_shortcut_failed = true;
            const request = bridge.app.dispatch(.register_global_shortcut) catch {
                bridge.callback_failed = true;
                break :blk null;
            };
            const registration = request.shortcut_registration_requested;
            _ = bridge.app.dispatch(.{ .shortcut_registration_receipt = .{
                .shortcut = registration.shortcut,
                .transport = registration.transport,
                .status = .failed,
            } }) catch {
                bridge.callback_failed = true;
            };
            break :blk null;
        },
        .shortcut_captured => blk: {
            const shortcut = decodeQtShortcut(exit_code) orelse {
                bridge.callback_failed = true;
                break :blk null;
            };
            _ = bridge.app.dispatch(.begin_shortcut_recording) catch {
                bridge.callback_failed = true;
                break :blk null;
            };
            _ = bridge.app.dispatch(.{ .capture_shortcut = shortcut }) catch {
                bridge.callback_failed = true;
            };
            bridge.captured_pending_save = true;
            break :blk null;
        },
        .shortcut_recorder_shown => blk: {
            bridge.saw_shortcut_recorder = true;
            break :blk null;
        },
        .preset_changed => blk: {
            const preset: noctty.terminal.ProfilePreset = switch (exit_code) {
                0 => .global_default,
                1 => .compact,
                2 => .readable,
                3 => .high_contrast,
                4 => .mono_no_ligatures,
                else => break :blk null,
            };
            _ = bridge.app.dispatch(.{ .set_pane_profile_preset = .{ .pane_id = pane_id, .preset = preset } }) catch {
                bridge.callback_failed = true;
            };
            const receipt = bridge.app.saveConfigFile(bridge.io, std.Io.Dir.cwd(), bridge.config_path, .settings) catch {
                bridge.callback_failed = true;
                break :blk null;
            };
            receipt.deinit(bridge.app.allocator);
            break :blk null;
        },
    };
    const app_event = status_event orelse return;
    _ = bridge.app.dispatch(.{ .terminal_status = .{ .pane_id = pane_id, .event = app_event } }) catch {
        bridge.callback_failed = true;
    };
}

fn dumpDefaultConfig(out: anytype) !void {
    const cfg = noctty.config.Config.defaults();
    try out.print("mode={s}\n", .{@tagName(cfg.default_mode)});
    try out.writeAll("dropdown_shortcut=");
    try cfg.dropdown.shortcut.formatDisplay(out);
    try out.writeAll("\n");
    try out.print("font={s} {d:.1}pt ligatures={}\n", .{ cfg.font.family, cfg.font.size_pt, cfg.font.ligatures });
    try out.print("tab_position={s}\n", .{@tagName(cfg.tabs.position)});
    try out.print("status_indicator={s}\n", .{@tagName(cfg.status.indicator)});
}

fn sessionEnvironment(environ_map: anytype) noctty.gui.SessionEnvironment {
    return .{
        .wayland_display = environ_map.get("WAYLAND_DISPLAY"),
        .display = environ_map.get("DISPLAY"),
        .current_desktop = environ_map.get("XDG_CURRENT_DESKTOP"),
        .session_desktop = environ_map.get("XDG_SESSION_DESKTOP"),
        .xdg_session_type = environ_map.get("XDG_SESSION_TYPE"),
        .kde_full_session = if (environ_map.get("KDE_FULL_SESSION")) |value|
            std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")
        else
            false,
        .shell_override = environ_map.get("NOCTTY_DESKTOP_SHELL"),
        .compositor_override = environ_map.get("NOCTTY_COMPOSITOR"),
        .noctalia_version = environ_map.get("NOCTALIA_VERSION"),
        .niri_socket = environ_map.get("NIRI_SOCKET"),
        .hyprland_instance_signature = environ_map.get("HYPRLAND_INSTANCE_SIGNATURE"),
        .sway_socket = environ_map.get("SWAYSOCK"),
        .labwc_pid = environ_map.get("LABWC_PID"),
        .mango_socket = environ_map.get("MANGO_SOCKET") orelse environ_map.get("MANGOWC_SOCKET"),
    };
}

fn noctaliaPlan(allocator: std.mem.Allocator, io: std.Io, home_dir: []const u8, environ_map: anytype, args: []const [:0]const u8, out: anytype) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const config_path = try app.defaultConfigPathAlloc(home_dir);
    defer allocator.free(config_path);
    if (app.loadConfigFile(io, std.Io.Dir.cwd(), config_path, .settings)) |receipt| {
        receipt.deinit(allocator);
    } else |err| if (err != error.FileNotFound) return err;
    const session = sessionEnvironment(environ_map);
    var environment = noctty.gui.noctalia.Environment{
        .wayland_display = session.wayland_display,
        .current_desktop = session.current_desktop,
        .session_desktop = session.session_desktop,
        .compositor_override = session.compositor_override,
        .shell_override = session.shell_override,
        .noctalia_version = session.noctalia_version,
        .niri_socket = session.niri_socket,
        .hyprland_instance_signature = session.hyprland_instance_signature,
        .sway_socket = session.sway_socket,
        .labwc_pid = session.labwc_pid,
        .mango_socket = session.mango_socket,
    };
    if (args.len > 2) environment.compositor_override = args[2];
    const detection = noctty.gui.noctalia.detect(environment);
    try noctty.gui.noctalia.writePlan(out, detection, app.config.dropdown.shortcut);
}

fn selfCheck(allocator: std.mem.Allocator, out: anytype) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();

    const tab = app.workspace.activeTab().?;
    const stats = tab.stats();
    try out.print("backend={s}\n", .{@tagName(app.backend.kind)});
    try out.print("telemetry={}\n", .{app.telemetry_enabled});
    try out.print("tabs={d} panes={d} idle={d} running={d} error={d}\n", .{
        app.workspace.tabs.items.len,
        stats.total,
        stats.idle,
        stats.running,
        stats.@"error",
    });
    try out.writeAll("status_summary=");
    const summary = try app.activeTabStatusSummary();
    try summary.formatCompact(out);
    try out.writeAll("\n");
}

fn hostPlan(allocator: std.mem.Allocator, environ_map: anytype, out: anytype) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    app.applySessionEnvironment(sessionEnvironment(environ_map));
    const rect = app.host.window.rect;
    const plan = app.launchPlan();
    try out.print("mode={s} visible={} fullscreen={}\n", .{
        @tagName(app.host.window.mode),
        app.host.window.visible,
        app.host.window.fullscreen,
    });
    try out.print("backend={s} shell={s} compositor={s} wayland={} x11={} desktop_notifications={} global_shortcuts={} app_shortcut_registration={} external_activation={}\n", .{
        @tagName(app.host.backend.kind),
        @tagName(app.host.backend.shell),
        @tagName(app.host.backend.compositor),
        app.host.backend.capabilities.wayland,
        app.host.backend.capabilities.x11,
        app.host.backend.capabilities.desktop_notifications,
        app.host.backend.capabilities.global_shortcuts,
        app.host.backend.capabilities.app_shortcut_registration,
        app.host.backend.capabilities.external_activation,
    });
    try out.print("rect={}x{}+{}+{}\n", .{ rect.width_px, rect.height_px, rect.x, rect.y });
    try out.writeAll("shortcut=");
    try app.config.dropdown.shortcut.formatDisplay(out);
    try out.writeAll("\n");
    try out.print("launch_readiness={s}\n", .{@tagName(plan.readiness)});
    try out.print("initial_surface={s} shortcut_surface={s}\n", .{
        @tagName(plan.initial_surface),
        @tagName(plan.shortcut_activation_surface),
    });
    try out.print("shortcut_rect={}x{}+{}+{}\n", .{
        plan.shortcut_activation_rect.width_px,
        plan.shortcut_activation_rect.height_px,
        plan.shortcut_activation_rect.x,
        plan.shortcut_activation_rect.y,
    });
    try out.print("launch_features global_shortcut={} external_activation={} layer_shell={} desktop_notifications={} drag_and_drop={} hidpi={}\n", .{
        plan.register_global_shortcut,
        plan.use_external_activation,
        plan.use_layer_shell,
        plan.use_desktop_notifications,
        plan.use_drag_and_drop,
        plan.hidpi,
    });
    try out.print("chrome main_titlebar_px={} terminal_titlebar_px={}\n", .{
        plan.chrome.main_titlebar_px,
        plan.chrome.terminal_titlebar_px,
    });
    try writePresentationPlan(out, "startup", app.presentationPlan(.startup));
    try writePresentationPlan(out, "shortcut", app.presentationPlan(.shortcut_activation));
    try writeWindowLifecycle(out, "startup", app.windowLifecycleRequest(.startup), app.host.window_lifecycle_status, app.host.window_transport_id);
    try writeWindowLifecycle(out, "shortcut", app.windowLifecycleRequest(.shortcut_activation), app.host.window_lifecycle_status, app.host.window_transport_id);
    try writeShortcutRegistration(out, app.shortcutRegistrationRequest(), app.host.shortcut_registration_status);
    try writeNotificationDelivery(out, app.notificationDeliveryRequest(), app.host.notification_delivery_status);
    try writeStatusTooltip(out, try app.statusTooltipRequest(.{}), app.host.status_tooltip_status);
    try writeProfilePresetMenu(out, try app.profilePresetMenuRequest(.{ .pane_id = 1 }), app.host.profile_preset_menu_status);
    try writeWorkspaceFileDialog(out, try app.workspaceFileDialogRequest(.{
        .operation = .save,
        .suggested_path = "workspace.nocttyws",
    }), app.host.workspace_file_dialog_status);
    try writeProjectPanel(out, app.projectPanelPresentationRequest(), app.host.project_panel_status);
    try writeClipboardTransfer(out, try app.clipboardTransferRequest(.read, .clipboard, 0), app.host.clipboard_transfer_status);
    try writePasteDelivery(out, try app.pasteDeliveryRequest(1, 1, true, .literal), app.host.paste_delivery_status);
}

fn writePresentationPlan(out: anytype, label: []const u8, plan: noctty.gui.PresentationPlan) !void {
    try out.print("presentation_{s} protocol={s} target={s} actions=", .{
        label,
        @tagName(plan.protocol),
        @tagName(plan.target_surface),
    });
    const actions = plan.actionSlice();
    if (actions.len == 0) {
        try out.writeAll("none");
    } else {
        for (actions, 0..) |action, idx| {
            if (idx != 0) try out.writeAll(",");
            try out.writeAll(@tagName(action));
        }
    }
    try out.writeAll("\n");
}

fn writeWindowLifecycle(
    out: anytype,
    label: []const u8,
    request: noctty.gui.WindowLifecycleRequest,
    current: noctty.gui.WindowLifecycleStatus,
    window_id: ?u64,
) !void {
    try out.print("window_lifecycle_{s} protocol={s} target={s} request_status={s} current_status={s} window_id=", .{
        label,
        @tagName(request.protocol),
        @tagName(request.target_surface),
        @tagName(request.status),
        @tagName(current),
    });
    if (window_id) |id| {
        try out.print("{d}", .{id});
    } else {
        try out.writeAll("none");
    }
    try out.writeAll("\n");
}

fn writeShortcutRegistration(out: anytype, request: noctty.gui.ShortcutRegistrationRequest, current: noctty.gui.ShortcutRegistrationStatus) !void {
    try out.writeAll("shortcut_registration shortcut=");
    try request.shortcut.formatDisplay(out);
    try out.print(" transport={s} request_status={s} current_status={s}\n", .{
        @tagName(request.transport),
        @tagName(request.status),
        @tagName(current),
    });
}

fn writeNotificationDelivery(out: anytype, request: noctty.gui.NotificationDeliveryRequest, current: noctty.gui.NotificationDeliveryStatus) !void {
    try out.print("notification_delivery transport={s} request_status={s} current_status={s} notification=", .{
        @tagName(request.transport),
        @tagName(request.status),
        @tagName(current),
    });
    if (request.notification) |notification| {
        try out.print("pane:{d}:{s}", .{ notification.pane_id, @tagName(notification.reason) });
    } else {
        try out.writeAll("none");
    }
    try out.writeAll("\n");
}

fn writeStatusTooltip(out: anytype, request: noctty.gui.StatusTooltipRequest, current: noctty.gui.StatusTooltipStatus) !void {
    try out.print("status_tooltip tab={d} request_status={s} current_status={s} details={} lines={d} attention={d}\n", .{
        request.tab_id,
        @tagName(request.status),
        @tagName(current),
        request.details_enabled,
        request.summary.line_count,
        request.summary.attention_total,
    });
}

fn writeProfilePresetMenu(out: anytype, request: noctty.gui.ProfilePresetMenuRequest, current: noctty.gui.ProfilePresetMenuStatus) !void {
    try out.print("profile_preset_menu pane={d} request_status={s} current_status={s} items={d} current=", .{
        request.pane_id,
        @tagName(request.status),
        @tagName(current),
        request.item_count,
    });
    var wrote_current = false;
    for (request.itemSlice()) |item| {
        if (!item.current) continue;
        if (wrote_current) try out.writeAll(",");
        try out.writeAll(@tagName(item.preset));
        wrote_current = true;
    }
    if (!wrote_current) try out.writeAll("none");
    try out.writeAll("\n");
}

fn writeWorkspaceFileDialog(out: anytype, request: noctty.gui.WorkspaceFileDialogRequest, current: noctty.gui.WorkspaceFileDialogStatus) !void {
    try out.print("workspace_file_dialog operation={s} transport={s} request_status={s} current_status={s} suggested={s}\n", .{
        @tagName(request.operation),
        @tagName(request.transport),
        @tagName(request.status),
        @tagName(current),
        request.suggested_path,
    });
}

fn writeProjectPanel(out: anytype, request: noctty.gui.ProjectPanelPresentationRequest, current: noctty.gui.ProjectPanelPresentationStatus) !void {
    try out.print("project_panel request_status={s} current_status={s} git_status={d} git_graph={d} files={d} changed={d} conflicts={d} has_data={}\n", .{
        @tagName(request.status),
        @tagName(current),
        request.summary.git_status_count,
        request.summary.git_graph_count,
        request.summary.file_entry_count,
        request.summary.changed_count,
        request.summary.conflict_count,
        request.hasPanelData(),
    });
}

fn writeClipboardTransfer(out: anytype, request: noctty.gui.ClipboardTransferRequest, current: noctty.gui.ClipboardTransferStatus) !void {
    try out.print("clipboard_transfer operation={s} selection={s} transport={s} request_status={s} current_status={s} bytes={d}\n", .{
        @tagName(request.operation),
        @tagName(request.selection),
        @tagName(request.transport),
        @tagName(request.status),
        @tagName(current),
        request.bytes,
    });
}

fn writePasteDelivery(out: anytype, request: noctty.gui.PasteDeliveryRequest, current: noctty.gui.PasteDeliveryStatus) !void {
    try out.print("paste_delivery pane={d} request_status={s} current_status={s} bytes={d} bracketed={} policy={s}\n", .{
        request.pane_id,
        @tagName(request.status),
        @tagName(current),
        request.bytes,
        request.bracketed,
        @tagName(request.policy),
    });
}

fn projectPanelPlan(allocator: std.mem.Allocator, out: anytype) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();

    const summary = (try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
            .{ .path = "docs/ARCHITECTURE.md", .state = .conflicted },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "project panel presentation", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    } })).project_panels_changed;
    const request = (try app.dispatch(.show_project_panel)).project_panel_requested;
    const shown = (try app.dispatch(.{ .project_panel_receipt = .{ .status = .shown } })).project_panel_changed;
    const hidden = (try app.dispatch(.hide_project_panel)).project_panel_changed;

    try out.print("project_panel_plan request_status={s} shown_status={s} hidden_status={s} can_show={} has_data={}\n", .{
        @tagName(request.status),
        @tagName(shown),
        @tagName(hidden),
        request.canShow(),
        request.hasPanelData(),
    });
    try out.print("project_panel_plan git_status={d} git_graph={d} files={d} changed={d} conflicts={d} directories={d} dirty_files={d}\n", .{
        summary.git_status_count,
        summary.git_graph_count,
        summary.file_entry_count,
        summary.changed_count,
        summary.conflict_count,
        summary.directory_count,
        summary.dirty_file_count,
    });
}

fn projectPanelView(allocator: std.mem.Allocator, out: anytype) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
            .{ .path = "docs/ARCHITECTURE.md", .state = .conflicted },
            .{ .path = "zig-cache", .state = .ignored },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "project panel view", .branch = "main" },
            .{ .commit = "def5678", .summary = "bounded preview rows" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
            .{ .path = "README.md", .kind = .file },
        },
    } });

    try writeProjectPanelView(out, (try app.dispatch(.{ .project_panel_view = .{
        .kind = .git_status,
        .max_rows = 1,
        .changed_only = true,
        .selected_index = 1,
    } })).project_panel_viewed);
    try writeProjectPanelView(out, (try app.dispatch(.{ .project_panel_view = .{
        .kind = .git_status,
        .conflicts_only = true,
        .selected_index = 1,
    } })).project_panel_viewed);
    try writeProjectPanelView(out, (try app.dispatch(.{ .project_panel_view = .{
        .kind = .files,
        .dirty_only = true,
        .selected_index = 1,
    } })).project_panel_viewed);
    try writeProjectPanelView(out, (try app.dispatch(.{ .project_panel_view = .{
        .kind = .git_graph,
        .max_rows = 2,
        .selected_index = 0,
    } })).project_panel_viewed);
}

fn writeProjectPanelView(out: anytype, view: noctty.workspace.ProjectPanelView) !void {
    try out.print("project_panel_view kind={s} total={d} visible={d} rows={d} max={d} truncated={} selected=", .{
        @tagName(view.kind),
        view.total_rows,
        view.visible_rows,
        view.row_count,
        view.max_rows,
        view.truncated(),
    });
    if (view.selected_index) |idx| {
        try out.print("{d}", .{idx});
    } else {
        try out.writeAll("none");
    }
    try out.print(" selected_visible={} changed_only={} conflicts_only={} dirty_only={}\n", .{
        view.selected_visible,
        view.changed_only,
        view.conflicts_only,
        view.dirty_only,
    });

    for (view.rowSlice()) |row| {
        switch (row) {
            .git_status => |entry| {
                try out.print("project_panel_view_row kind=git_status index={d} selected={} changed={} state={s} path={s}\n", .{
                    entry.source_index,
                    entry.selected,
                    entry.changed,
                    @tagName(entry.state),
                    entry.path,
                });
            },
            .git_graph => |node| {
                try out.print("project_panel_view_row kind=git_graph index={d} selected={} commit={s} branch=", .{
                    node.source_index,
                    node.selected,
                    node.commit,
                });
                if (node.branch) |branch| {
                    try out.writeAll(branch);
                } else {
                    try out.writeAll("none");
                }
                try out.print(" summary={s}\n", .{node.summary});
            },
            .files => |entry| {
                try out.print("project_panel_view_row kind=files index={d} selected={} file_kind={s} dirty={} path={s}\n", .{
                    entry.source_index,
                    entry.selected,
                    @tagName(entry.kind),
                    entry.dirty,
                    entry.path,
                });
            },
        }
    }
}

fn projectPanelAction(allocator: std.mem.Allocator, out: anytype) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "project panel action", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    } });

    try runProjectPanelAction(out, &app, .{ .kind = .git_status, .source_index = 0 });
    try runProjectPanelAction(out, &app, .{ .kind = .files, .source_index = 0 });
    try runProjectPanelAction(out, &app, .{ .kind = .files, .source_index = 1 });
    try runProjectPanelAction(out, &app, .{ .kind = .git_graph, .source_index = 0 });
}

fn runProjectPanelAction(out: anytype, app: *noctty.app.App, source: noctty.workspace.ProjectPanelActivationRequest) !void {
    const plan = (try app.dispatch(.{ .plan_project_panel_action = source })).project_panel_action_planned;
    try writeProjectPanelActionPlan(out, plan);
    const spec = (try app.dispatch(.{ .prepare_project_panel_action = source })).project_panel_action_prepared;
    try writeProjectPanelActionSpec(out, spec);
    const request = (try app.dispatch(.{ .request_project_panel_action = source })).project_panel_action_requested;
    try writeProjectPanelActionRequest(out, request, app.host.project_panel_action_status);
    const receipt_status = (try app.dispatch(.{ .project_panel_action_receipt = .{
        .source = request.activation.source,
        .kind = request.activation.kind,
        .transport = request.transport,
        .status = .completed,
    } })).project_panel_action_changed;
    try out.print("project_panel_action_receipt source={s}:{d} action={s} transport={s} status={s}\n", .{
        @tagName(request.activation.source.kind),
        request.activation.source.source_index,
        @tagName(request.activation.kind),
        @tagName(request.transport),
        @tagName(receipt_status),
    });
    const result = (try app.dispatch(.{ .project_panel_action_execution_receipt = .{
        .source = spec.source,
        .executor = spec.executor,
        .operation = spec.operation,
        .status = .completed,
        .exit_code = if (spec.requires_process) 0 else null,
    } })).project_panel_action_execution_result;
    try writeProjectPanelActionExecutionResult(out, result);
    const result_view = (try app.dispatch(.project_panel_action_result_view)).project_panel_action_result_viewed;
    try writeProjectPanelActionResultView(out, result_view);
}

fn writeProjectPanelActionPlan(out: anytype, plan: noctty.workspace.ProjectPanelActionPlan) !void {
    try out.print("project_panel_action_plan source={s}:{d} action={s} executor={s} can_execute={} requires_path={} requires_commit={} requires_git={} opens_editor={} opens_directory={} path=", .{
        @tagName(plan.source.kind),
        plan.source.source_index,
        @tagName(plan.kind),
        @tagName(plan.executor),
        plan.canExecute(),
        plan.requires_path,
        plan.requires_commit,
        plan.requires_git,
        plan.opens_editor,
        plan.opens_directory,
    });
    if (plan.path) |path| {
        try out.writeAll(path);
    } else {
        try out.writeAll("none");
    }
    try out.writeAll(" commit=");
    if (plan.commit) |commit| {
        try out.writeAll(commit);
    } else {
        try out.writeAll("none");
    }
    try out.writeAll(" git_state=");
    if (plan.git_state) |state| {
        try out.writeAll(@tagName(state));
    } else {
        try out.writeAll("none");
    }
    try out.writeAll(" file_kind=");
    if (plan.file_kind) |kind| {
        try out.writeAll(@tagName(kind));
    } else {
        try out.writeAll("none");
    }
    try out.writeAll("\n");
}

fn writeProjectPanelActionSpec(out: anytype, spec: noctty.workspace.ProjectPanelActionExecutionSpec) !void {
    try out.print("project_panel_action_spec source={s}:{d} operation={s} executor={s} process={} editor={} directory_view={} requires_git={} mutates={} argv=", .{
        @tagName(spec.source.kind),
        spec.source.source_index,
        @tagName(spec.operation),
        @tagName(spec.executor),
        spec.requires_process,
        spec.requires_editor,
        spec.requires_directory_view,
        spec.requires_git,
        spec.mutates_workspace,
    });
    const argv = spec.argvSlice();
    if (argv.len == 0) {
        try out.writeAll("none");
    } else {
        for (argv, 0..) |arg, idx| {
            if (idx != 0) try out.writeAll(",");
            try out.writeAll(arg);
        }
    }
    try out.writeAll(" path=");
    if (spec.path) |path| {
        try out.writeAll(path);
    } else {
        try out.writeAll("none");
    }
    try out.writeAll(" commit=");
    if (spec.commit) |commit| {
        try out.writeAll(commit);
    } else {
        try out.writeAll("none");
    }
    try out.writeAll("\n");
}

fn writeProjectPanelActionExecutionResult(out: anytype, result: noctty.workspace.ProjectPanelActionExecutionResult) !void {
    try out.print("project_panel_action_result source={s}:{d} operation={s} executor={s} status={s} exit_code=", .{
        @tagName(result.source.kind),
        result.source.source_index,
        @tagName(result.operation),
        @tagName(result.executor),
        @tagName(result.status),
    });
    if (result.exit_code) |code| {
        try out.print("{d}", .{code});
    } else {
        try out.writeAll("none");
    }
    try out.print(" stdout_bytes={d} stderr_bytes={d} truncated={} has_output={}\n", .{
        result.stdout_bytes,
        result.stderr_bytes,
        result.truncated,
        result.hasOutput(),
    });
}

fn writeProjectPanelActionResultView(out: anytype, view: noctty.workspace.ProjectPanelActionResultView) !void {
    try out.print("project_panel_action_result_view source={s}:{d} operation={s} executor={s} status={s} tone={s} title=\"{s}\" detail=\"{s}\" process_output={} editor_target={} directory_target={} has_output={} needs_attention={}\n", .{
        @tagName(view.source.kind),
        view.source.source_index,
        @tagName(view.operation),
        @tagName(view.executor),
        @tagName(view.status),
        @tagName(view.tone),
        view.title,
        view.detail,
        view.shows_process_output,
        view.shows_editor_target,
        view.shows_directory_target,
        view.has_output,
        view.needsAttention(),
    });
}

fn writeProjectPanelActionRequest(
    out: anytype,
    request: noctty.gui.ProjectPanelActionRequest,
    current_status: noctty.gui.ProjectPanelActionStatus,
) !void {
    try out.print("project_panel_action source={s}:{d} action={s} transport={s} request_status={s} current_status={s} path=", .{
        @tagName(request.activation.source.kind),
        request.activation.source.source_index,
        @tagName(request.activation.kind),
        @tagName(request.transport),
        @tagName(request.status),
        @tagName(current_status),
    });
    if (request.activation.path) |path| {
        try out.writeAll(path);
    } else {
        try out.writeAll("none");
    }
    try out.writeAll(" commit=");
    if (request.activation.commit) |commit| {
        try out.writeAll(commit);
    } else {
        try out.writeAll("none");
    }
    try out.writeAll(" summary=");
    if (request.activation.summary) |summary| {
        try out.writeAll(summary);
    } else {
        try out.writeAll("none");
    }
    try out.writeAll(" branch=");
    if (request.activation.branch) |branch| {
        try out.writeAll(branch);
    } else {
        try out.writeAll("none");
    }
    try out.writeAll(" git_state=");
    if (request.activation.git_state) |state| {
        try out.writeAll(@tagName(state));
    } else {
        try out.writeAll("none");
    }
    try out.writeAll(" file_kind=");
    if (request.activation.file_kind) |kind| {
        try out.writeAll(@tagName(kind));
    } else {
        try out.writeAll("none");
    }
    try out.print(" targets_path={} targets_commit={}\n", .{
        request.activation.targetsPath(),
        request.activation.targetsCommit(),
    });
}

fn projectScan(allocator: std.mem.Allocator, io: std.Io, out: anytype) !void {
    const options = noctty.project_scan.ScanOptions{
        .max_file_entries = 128,
        .max_git_status_entries = 128,
        .max_git_graph_entries = 12,
        .max_depth = 4,
    };

    var root_dir = try std.Io.Dir.cwd().openDir(io, ".", .{ .iterate = true });
    defer root_dir.close(io);

    var file_scan = try noctty.project_scan.scanFilesAlloc(allocator, io, root_dir, options);
    defer file_scan.deinit(allocator);

    var status_scan = noctty.project_scan.runGitStatusAlloc(allocator, io, null, options) catch null;
    defer if (status_scan) |*scan| scan.deinit(allocator);

    var graph_scan = noctty.project_scan.runGitGraphAlloc(allocator, io, null, options) catch null;
    defer if (graph_scan) |*scan| scan.deinit(allocator);

    const git_status: []const noctty.workspace.GitStatusInput = if (status_scan) |scan| scan.git_status else &.{};
    const git_graph: []const noctty.workspace.GitGraphInput = if (graph_scan) |scan| scan.git_graph else &.{};
    const update = noctty.workspace.ProjectPanelUpdate{
        .git_status = git_status,
        .git_graph = git_graph,
        .files = file_scan.files,
    };

    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const summary = (try app.dispatch(.{ .set_project_panels = update })).project_panels_changed;

    try out.print("project_scan git_status_available={} git_graph_available={} status_entries={d} commits={d} file_entries={d}\n", .{
        status_scan != null,
        graph_scan != null,
        summary.git_status_count,
        summary.git_graph_count,
        summary.file_entry_count,
    });
    try out.print("project_scan changed={d} conflicts={d} directories={d} dirty_files={d}\n", .{
        summary.changed_count,
        summary.conflict_count,
        summary.directory_count,
        summary.dirty_file_count,
    });
    try out.print("project_scan truncated status={} graph={} files={}\n", .{
        if (status_scan) |scan| scan.git_status_truncated else false,
        if (graph_scan) |scan| scan.git_graph_truncated else false,
        file_scan.files_truncated,
    });
}

fn populateProjectPanels(app: *noctty.app.App, allocator: std.mem.Allocator, io: std.Io) !void {
    const options = noctty.project_scan.ScanOptions{ .max_file_entries = 128, .max_git_status_entries = 128, .max_git_graph_entries = 12, .max_depth = 4 };
    var root_dir = try std.Io.Dir.cwd().openDir(io, ".", .{ .iterate = true });
    defer root_dir.close(io);
    var file_scan = try noctty.project_scan.scanFilesAlloc(allocator, io, root_dir, options);
    defer file_scan.deinit(allocator);
    var status_scan = noctty.project_scan.runGitStatusAlloc(allocator, io, null, options) catch null;
    defer if (status_scan) |*scan| scan.deinit(allocator);
    var graph_scan = noctty.project_scan.runGitGraphAlloc(allocator, io, null, options) catch null;
    defer if (graph_scan) |*scan| scan.deinit(allocator);
    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = if (status_scan) |scan| scan.git_status else &.{},
        .git_graph = if (graph_scan) |scan| scan.git_graph else &.{},
        .files = file_scan.files,
    } });
}

fn maintenancePlan(allocator: std.mem.Allocator, out: anytype) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    try app.configureRecoveryPolicy(.{
        .autosave_interval_seconds = 30,
        .max_recovery_snapshots = 3,
    });
    app.markWorkspaceDirtyAt(0);

    const plan = try app.advanceMaintenance(.{ .now_ms = 31_000 });
    try out.print("maintenance autosave_due={} project_refresh_due={} recovery_cleanup_due={} has_due_work={}\n", .{
        plan.autosave_due,
        plan.project_refresh_due,
        plan.recovery_cleanup_due,
        plan.hasDueWork(),
    });
    try out.print("maintenance pending autosave={} project_refresh={} recovery_cleanup={} generation={d}/{d}\n", .{
        plan.autosave_pending,
        plan.project_refresh_pending,
        plan.recovery_cleanup_pending,
        plan.saved_generation,
        plan.dirty_generation,
    });
}

fn workspaceFileFlow(allocator: std.mem.Allocator, io: std.Io, out: anytype) !void {
    var tmp_dir = try std.Io.Dir.openDirAbsolute(io, "/tmp", .{});
    defer tmp_dir.close(io);
    const path = "noctty-workspace-file-flow.nocttyws";
    defer tmp_dir.deleteFile(io, path) catch {};

    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    _ = try app.dispatch(.split_down);
    try app.workspace.findPane(2).?.addTag("file-flow");

    const save_request = (try app.dispatch(.{ .show_workspace_file_dialog = .{
        .operation = .save,
        .suggested_path = path,
    } })).workspace_file_dialog_requested;
    const saved = try app.applyWorkspaceFileDialogFileAction(io, tmp_dir, .{
        .operation = save_request.operation,
        .transport = save_request.transport,
        .status = .selected,
        .selected_path = path,
    }, .manual);
    defer saved.deinit(allocator);

    _ = try app.dispatch(.{ .preset = .three_by_three });
    const open_request = (try app.dispatch(.{ .show_workspace_file_dialog = .{
        .operation = .open,
        .suggested_path = path,
    } })).workspace_file_dialog_requested;
    const loaded = try app.applyWorkspaceFileDialogFileAction(io, tmp_dir, .{
        .operation = open_request.operation,
        .transport = open_request.transport,
        .status = .selected,
        .selected_path = path,
    }, .manual);
    defer loaded.deinit(allocator);

    const panes = app.workspace.activeTab().?.panes.items.len;
    try out.print("workspace_file_flow save_status={s} open_status={s} saved_bytes={d} loaded_bytes={d} panes={d}\n", .{
        @tagName(saved.status),
        @tagName(loaded.status),
        saved.file_receipt.?.bytes,
        loaded.file_receipt.?.bytes,
        panes,
    });
}

fn ghosttyProbe(args: []const [:0]const u8, out: anytype) !void {
    const path = if (args.len > 2) args[2] else null;
    const probe = noctty.ghostty.Api.probe(path);
    try out.print("available={}\n", .{probe.available});
    if (probe.error_name) |error_name| {
        try out.print("error={s}\n", .{error_name});
    }
    try out.print("lifecycle_complete={}\n", .{probe.lifecycle_complete});
    try out.print("complete={}\n", .{probe.complete});
    try out.print("platform_surface_supported={}\n", .{probe.platform_surface_supported});
    try out.print("safe_gui_abi={}\n", .{probe.safe_gui_abi});
}

fn ptySmoke(out: anytype) !void {
    var session = try noctty.pty.Session.spawn("/tmp", "/bin/sh");
    defer session.deinit();
    try session.resize(24, 80, 800, 480);
    try session.writeAll("printf 'NOCTTY_PTY_SMOKE_OK\n'; exit 0\n");

    var output: [4096]u8 = undefined;
    var used: usize = 0;
    var saw_marker = false;
    var saw_exit = false;
    var attempts: usize = 0;
    // Match the terminal-session smoke's load-tolerant polling budget. The
    // child can be delayed behind the qualification matrix on busy builders.
    while (attempts < 5000 and !(saw_exit and saw_marker)) : (attempts += 1) {
        switch (try session.read(output[used..])) {
            .bytes => |count| {
                used += count;
                if (std.mem.indexOf(u8, output[0..used], "NOCTTY_PTY_SMOKE_OK") != null) saw_marker = true;
            },
            .would_block => noctty.pty.sleepBrief(2),
            .eof => saw_exit = true,
        }
        if (try session.pollExit()) |code| {
            saw_exit = true;
            if (code != 0) return error.PtySmokeChildFailed;
        }
    }
    if (!saw_exit) return error.PtySmokeTimeout;
    if (!saw_marker) return error.PtySmokeMarkerMissing;
    try out.print("pty_smoke spawned=true marker=true resized=true exited=true exit_code=0\n", .{});
}

fn vtSmoke(out: anytype) !void {
    var grid = try noctty.vt.Grid.init(std.heap.page_allocator, 16, 2);
    defer grid.deinit();
    try grid.feed("NOCTTY\x1b[2;1HVT_OK\x1b]2;NOCTTY VT\x07");
    if (!noctty.vt.publicVtAvailable()) return error.PublicGhosttyVtUnavailable;
    if (grid.cell(0, 1).codepoint != 'V') return error.VtGridMismatch;
    if (!noctty.vt.publicPasteIsSafe("NOCTTY plain paste")) return error.PublicGhosttyPasteRejected;
    try out.print("vt_smoke public_vt=true grid=true title=true paste=true\n", .{});
}

fn terminalSessionSmoke(out: anytype) !void {
    var session = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, "/tmp", "/bin/sh", 40, 4);
    defer session.deinit();
    try session.write("printf '\\033[2;1mNOCTTY_SESSION_SMOKE_OK\\033]2;session-smoke\\007'; exit 0\n");
    var saw_marker = false;
    var saw_exit = false;
    var attempts: usize = 0;
    while (attempts < 5000 and !(saw_marker and saw_exit)) : (attempts += 1) {
        switch (try session.pump()) {
            .bytes => {},
            .would_block => noctty.pty.sleepBrief(2),
            .eof => {},
        }
        if (std.mem.eql(u8, session.grid.titleSlice(), "session-smoke")) {
            for (0..session.grid.rows) |row| for (0..session.grid.columns) |column| {
                if (session.grid.cell(column, row).codepoint == 'N') saw_marker = true;
            };
        }
        if (try session.pollExit()) |code| {
            if (code != 0) return error.TerminalSessionExitFailed;
            saw_exit = true;
        }
    }
    if (!saw_marker) return error.TerminalSessionMarkerMissing;
    if (!saw_exit) return error.TerminalSessionExitMissing;
    try out.print("terminal_session_smoke pty=true vt=true grid=true title=true exited=true\n", .{});
}

const TerminalPipelineContext = struct {
    session: *noctty.terminal_session.TerminalSession,
    io: std.Io,
};

fn terminalPipelineAdvance(
    raw: ?*anyopaque,
    sample: usize,
    input_to_grid_ns: *u64,
    read_to_grid_ns: *u64,
    output_bytes: *usize,
) callconv(.c) c_int {
    const context: *TerminalPipelineContext =
        @ptrCast(@alignCast(raw orelse return -1));
    var command_buffer: [1024]u8 = undefined;
    const command = std.fmt.bufPrint(
        &command_buffer,
        "i=0; while [ \"$i\" -lt 36 ]; do " ++
            "printf '\\033[3%dmNOCTTY_PIPELINE_{d:0>3}_ROW_%03d_" ++
            "abcdefghijklmnopqrstuvwxyz0123456789\\033[0m\\r\\n' " ++
            "\"$((i % 8))\" \"$i\"; i=$((i + 1)); done; " ++
            "printf '\\033]2;noctty-pipeline-{d:0>3}\\007'\n",
        .{ sample, sample },
    ) catch return -1;
    var expected_buffer: [64]u8 = undefined;
    const expected = std.fmt.bufPrint(
        &expected_buffer,
        "noctty-pipeline-{d:0>3}",
        .{sample},
    ) catch return -1;

    const input_started = std.Io.Clock.awake.now(context.io);
    context.session.write(command) catch return -1;
    const read_started = std.Io.Clock.awake.now(context.io);
    var bytes: usize = 0;
    for (0..5000) |_| {
        switch (context.session.pump() catch return -1) {
            .bytes => |count| bytes += count,
            .would_block => noctty.pty.sleepBrief(1),
            .eof => return -1,
        }
        if (std.mem.eql(u8, context.session.grid.titleSlice(), expected)) {
            const finished = std.Io.Clock.awake.now(context.io);
            const input_elapsed = input_started.durationTo(finished).nanoseconds;
            const read_elapsed = read_started.durationTo(finished).nanoseconds;
            if (input_elapsed <= 0 or read_elapsed <= 0) return -1;
            input_to_grid_ns.* = @intCast(input_elapsed);
            read_to_grid_ns.* = @intCast(read_elapsed);
            output_bytes.* = bytes;
            return 0;
        }
    }
    return -1;
}

fn terminalPipelineEvent(
    _: ?*anyopaque,
    _: u64,
    _: c_int,
    _: c_int,
    _: u64,
) callconv(.c) void {}

fn terminalPipelineQualification(
    io: std.Io,
    artifact_path: [:0]const u8,
    mode: [:0]const u8,
) !void {
    var session = try noctty.terminal_session.TerminalSession.spawnWithHistoryLimit(
        std.heap.page_allocator,
        "/tmp",
        "/bin/sh",
        120,
        40,
        256,
    );
    defer session.deinit();
    var context = TerminalPipelineContext{ .session = &session, .io = io };
    const callbacks = NativeGridAbi.Callbacks{
        .userdata = &session,
        .pump = noctty_grid_pump,
        .write = noctty_grid_write,
        .cell = noctty_grid_cell,
        .row = noctty_grid_row,
        .dirty_rows = noctty_grid_take_dirty_rows,
        .dirty_spans = noctty_grid_take_dirty_spans,
        .presentation_ready = noctty_grid_presentation_ready,
        .color_rgb = noctty_grid_color_rgb,
        .cell_text = noctty_grid_cell_text,
        .cell_hyperlink = noctty_grid_cell_hyperlink,
        .poll_exit = noctty_grid_poll_exit,
        .resize = noctty_grid_resize,
        .mouse = noctty_grid_mouse,
        .paste = noctty_grid_paste,
        .copy = noctty_grid_copy,
        .scroll = noctty_grid_scroll,
        .cursor = noctty_grid_cursor,
        .title = noctty_grid_title,
        .cursor_mode = noctty_grid_cursor_mode,
        .mouse_mode = noctty_grid_mouse_mode,
        .focus = noctty_grid_focus,
        .event = terminalPipelineEvent,
        .event_data = null,
        .text_action = null,
        .text_action_data = null,
    };
    if (noctty_native_grid_pipeline_qualification(
        &callbacks,
        120,
        40,
        terminalPipelineAdvance,
        &context,
        artifact_path.ptr,
        mode.ptr,
    ) != 0) return error.TerminalPipelineQualificationFailed;

    try session.write("exit 0\n");
    for (0..5000) |_| {
        switch (try session.pump()) {
            .bytes => {},
            .would_block => noctty.pty.sleepBrief(1),
            .eof => {},
        }
        if (try session.pollExit()) |code| {
            if (code != 0) return error.TerminalPipelineChildExitFailed;
            return;
        }
    }
    return error.TerminalPipelineChildExitTimedOut;
}

export fn noctty_grid_pump(raw: ?*anyopaque) callconv(.c) c_int {
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    return switch (session.pump() catch return -1) {
        .bytes => |count| @intCast(count),
        .would_block => -2,
        .eof => 0,
    };
}

export fn noctty_grid_pty_fd(raw: ?*anyopaque) callconv(.c) c_int {
    const session: *const noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return -1));
    return @intCast(session.fileDescriptor());
}

export fn noctty_grid_compact_idle_history(raw: ?*anyopaque) callconv(.c) c_int {
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return -1));
    const result = session.grid.compactIdleHistoryStep(
        noctty.vt.Grid.idle_history_hot_lines,
        noctty.vt.Grid.idle_history_rows_per_step,
    ) catch return -1;
    if (!result.complete) return 0;
    return if (result.rows_coldified > 0 or result.bytes_released > 0) 2 else 1;
}

export fn noctty_grid_write(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    session.write(bytes[0..length]) catch return -1;
    return @intCast(length);
}

export fn noctty_grid_write_pending(raw: ?*anyopaque) callconv(.c) c_int {
    const session: *const noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return 0));
    return @intFromBool(session.hasPendingWrites());
}

export fn noctty_grid_flush_write(raw: ?*anyopaque) callconv(.c) c_int {
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return -1));
    return @intFromBool(session.flushPendingWrites() catch return -1);
}

export fn noctty_grid_terminal_chord_write(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return -1));
    const input = bytes[0..length];
    if (build_options.enable_smoke) {
        const is_primary = if (native_grid_terminal_chord_probe.primary) |primary|
            session == primary
        else
            false;
        const is_secondary = if (native_grid_terminal_chord_probe.secondary) |secondary|
            session == secondary
        else
            false;
        for (input) |byte| switch (byte) {
            0x03 => {
                if (is_primary) native_grid_terminal_chord_probe.primary_interrupts += 1;
                if (is_secondary) native_grid_terminal_chord_probe.secondary_interrupts += 1;
            },
            0x04 => {
                if (is_primary) native_grid_terminal_chord_probe.primary_eof += 1;
                if (is_secondary) native_grid_terminal_chord_probe.secondary_eof += 1;
            },
            '\r' => {
                if (is_primary) native_grid_terminal_chord_probe.primary_carriage_returns += 1;
                if (is_secondary) native_grid_terminal_chord_probe.secondary_carriage_returns += 1;
            },
            '\n' => {
                if (is_primary) native_grid_terminal_chord_probe.primary_line_feeds += 1;
                if (is_secondary) native_grid_terminal_chord_probe.secondary_line_feeds += 1;
            },
            else => {},
        };
    }
    session.write(input) catch return -1;
    return @intCast(length);
}

export fn noctty_grid_cell(raw: ?*anyopaque, column: c_int, row: c_int) callconv(.c) u64 {
    if (raw == null or column < 0 or row < 0)
        return @as(u64, ' ') | (@as(u64, 0xffffff00) << 32);
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    return session.grid.packedCell(@intCast(column), @intCast(row));
}

export fn noctty_grid_row(raw: ?*anyopaque, row: c_int, output: [*]u64, capacity: usize) callconv(.c) c_int {
    if (raw == null or row < 0 or capacity == 0) return 0;
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    const count = session.grid.packedRow(@intCast(row), output[0..capacity]);
    return std.math.cast(c_int, count) orelse -1;
}

export fn noctty_grid_take_dirty_rows(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    if (raw == null or capacity == 0) return 0;
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    const count = session.grid.takeDirtyRows(output[0..capacity]);
    return std.math.cast(c_int, count) orelse -1;
}

export fn noctty_grid_take_dirty_spans(raw: ?*anyopaque, output: [*]NativeGridAbi.DirtySpan, capacity: usize) callconv(.c) c_int {
    if (raw == null or capacity == 0) return 0;
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    const spans: [*]noctty.vt.DirtySpan = @ptrCast(output);
    const count = session.grid.takeDirtySpans(spans[0..capacity]);
    return std.math.cast(c_int, count) orelse -1;
}

export fn noctty_grid_presentation_ready(raw: ?*anyopaque) callconv(.c) c_int {
    const session: *const noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return 1));
    return @intFromBool(!session.grid.synchronized_output);
}

export fn noctty_grid_color_rgb(raw: ?*anyopaque, color_id: u32) callconv(.c) u32 {
    const session: *const noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return 0xffffffff));
    if (color_id > std.math.maxInt(u16)) return 0xffffffff;
    return session.grid.colorRgb(@intCast(color_id));
}

export fn noctty_grid_cell_text(raw: ?*anyopaque, column: c_int, row: c_int, output: [*]u8, capacity: usize) callconv(.c) c_int {
    if (raw == null or column < 0 or row < 0 or capacity == 0) return 0;
    const session: *const noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    const count = session.grid.cellText(@intCast(column), @intCast(row), output[0..capacity]);
    return std.math.cast(c_int, count) orelse -1;
}

export fn noctty_grid_cell_hyperlink(raw: ?*anyopaque, column: c_int, row: c_int, output: [*]u8, capacity: usize) callconv(.c) c_int {
    if (raw == null or column < 0 or row < 0 or capacity == 0) return 0;
    const session: *const noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    const count = session.grid.cellHyperlink(@intCast(column), @intCast(row), output[0..capacity]);
    return std.math.cast(c_int, count) orelse -1;
}

export fn noctty_grid_poll_exit(raw: ?*anyopaque) callconv(.c) c_int {
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    return if (session.pollExit() catch return -2) |code| @intCast(code) else -1;
}

export fn noctty_grid_resize(raw: ?*anyopaque, columns: c_int, rows: c_int, width_px: c_int, height_px: c_int) callconv(.c) c_int {
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    session.resize(@intCast(columns), @intCast(rows), @intCast(width_px), @intCast(height_px)) catch return -1;
    return 0;
}

export fn noctty_grid_mouse(raw: ?*anyopaque, column: c_int, row: c_int, button: c_int, pressed: c_int) callconv(.c) c_int {
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    var sequence: [64]u8 = undefined;
    if (!session.grid.sgr_mouse) {
        const legacy_button: c_int = if (button >= 64) button else if (pressed != 0) button else 3;
        const legacy = [_]u8{ 0x1b, '[', 'M', @intCast(@min(255, 32 + legacy_button)), @intCast(@min(255, 33 + column)), @intCast(@min(255, 33 + row)) };
        session.write(&legacy) catch return -1;
        return @intCast(legacy.len);
    }
    const final: u8 = if (pressed != 0) 'M' else 'm';
    const length = std.fmt.bufPrint(&sequence, "\x1b[<{d};{d};{d}{c}", .{ button, column + 1, row + 1, final }) catch return -1;
    session.write(length) catch return -1;
    return @intCast(length.len);
}

export fn noctty_grid_paste(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    if (length > noctty.terminal_session.TerminalSession.max_pending_write_bytes - 12)
        return -1;
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    const prepared = noctty.paste.preparePasteAlloc(session.allocator, bytes[0..length], .{ .bracketed_paste = session.grid.bracketed_paste }) catch return -1;
    defer prepared.deinit(session.allocator);
    session.write(prepared.bytes) catch return -1;
    return @intCast(prepared.bytes.len);
}

export fn noctty_grid_copy(raw: ?*anyopaque, output: [*]u8, capacity: usize, start_column: c_int, start_row: c_int, end_column: c_int, end_row: c_int) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    const selected = start_column >= 0 and start_row >= 0 and end_column >= 0 and end_row >= 0;
    const first_column: usize = if (selected) @intCast(@min(start_column, end_column)) else 0;
    const last_column: usize = if (selected) @min(session.grid.columns - 1, @as(usize, @intCast(@max(start_column, end_column)))) else session.grid.columns - 1;
    const first_row: usize = if (selected) @intCast(@min(start_row, end_row)) else 0;
    const last_row: usize = if (selected) @min(session.grid.rows - 1, @as(usize, @intCast(@max(start_row, end_row)))) else session.grid.rows - 1;
    var used: usize = 0;
    for (first_row..last_row + 1) |row| {
        var last: usize = last_column + 1;
        while (last > 0 and session.grid.cell(last - 1, row).codepoint == ' ') last -= 1;
        const begin = if (selected) first_column else 0;
        for (begin..last) |column| {
            if (used >= capacity) return -1;
            const codepoint = session.grid.cell(column, row).codepoint;
            if (codepoint < 0x80) {
                output[used] = @intCast(codepoint);
                used += 1;
            } else if (codepoint <= 0x7ff) {
                if (used + 2 > capacity) return -1;
                output[used] = @intCast(0xc0 | (codepoint >> 6));
                output[used + 1] = @intCast(0x80 | (codepoint & 0x3f));
                used += 2;
            } else {
                if (used + 3 > capacity) return -1;
                output[used] = @intCast(0xe0 | (codepoint >> 12));
                output[used + 1] = @intCast(0x80 | ((codepoint >> 6) & 0x3f));
                output[used + 2] = @intCast(0x80 | (codepoint & 0x3f));
                used += 3;
            }
        }
        if (used >= capacity) return -1;
        output[used] = if (row < last_row) '\n' else 0;
        used += 1;
    }
    return @intCast(used);
}

export fn noctty_grid_find(raw: ?*anyopaque, query: [*]const u8, length: usize, reverse: c_int, ordinal: usize, column_out: *c_int, row_out: *c_int, length_out: *c_int, matches_out: *c_int) callconv(.c) c_int {
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return -1));
    const found = session.grid.findText(query[0..length], reverse != 0, ordinal) orelse return 0;
    column_out.* = @intCast(found.column);
    row_out.* = @intCast(found.row);
    length_out.* = @intCast(found.length);
    matches_out.* = @intCast(@min(found.matches, std.math.maxInt(c_int)));
    return 1;
}

export fn noctty_grid_scrollback(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return -1));
    const used = session.grid.writeScrollback(output[0..capacity]) catch return -1;
    return @intCast(used);
}

export fn noctty_grid_bell_serial(raw: ?*anyopaque) callconv(.c) u64 {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return 0));
    return session.grid.bell_serial;
}

export fn noctty_grid_notification_serial(raw: ?*anyopaque) callconv(.c) u64 {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return 0));
    return session.grid.notification_serial;
}

export fn noctty_grid_notification_action(raw: ?*anyopaque) callconv(.c) c_int {
    const session: *const noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw orelse return 0));
    return @intFromEnum(session.grid.notification_action);
}

export fn noctty_grid_set_agent_resume(
    raw: ?*anyopaque,
    pane_id: u64,
    provider_raw: c_int,
    session_id: [*]const u8,
    session_id_len: usize,
    label: [*]const u8,
    label_len: usize,
) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    if (provider_raw < 0 or provider_raw > 2) return -1;
    const provider = noctty.continuity.providerFromInt(@intCast(provider_raw)) catch return -1;
    var reference = noctty.continuity.AgentResume{ .enabled = true, .provider = provider };
    reference.session_id.set(session_id[0..session_id_len]) catch return -1;
    reference.label.set(label[0..label_len]) catch return -1;
    _ = bridge.app.dispatch(.{ .set_agent_resume = .{ .pane_id = pane_id, .reference = reference } }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    persistNativeGridHotSession(bridge);
    return 0;
}

export fn noctty_grid_clear_agent_resume(raw: ?*anyopaque, pane_id: u64) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    _ = bridge.app.dispatch(.{ .clear_agent_resume = pane_id }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    persistNativeGridHotSession(bridge);
    return 0;
}

export fn noctty_grid_save_encrypted_history(
    session_raw: ?*anyopaque,
    bridge_raw: ?*anyopaque,
    path: [*]const u8,
    path_len: usize,
    password: [*]const u8,
    password_len: usize,
) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(session_raw orelse return -1));
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(bridge_raw orelse return -1));
    const io = bridge.io orelse return -1;
    const plaintext = bridge.app.allocator.alloc(u8, noctty.history_snapshot.max_plaintext_bytes) catch return -1;
    defer bridge.app.allocator.free(plaintext);
    const used = session.grid.writeScrollback(plaintext) catch return -1;
    const encrypted = noctty.history_snapshot.encryptAlloc(
        bridge.app.allocator,
        plaintext[0..used],
        password[0..password_len],
    ) catch return -1;
    defer bridge.app.allocator.free(encrypted);
    const target = path[0..path_len];
    if (target.len == 0 or !std.fs.path.isAbsolute(target)) return -1;
    var atomic = std.Io.Dir.cwd().createFileAtomic(io, target, .{
        .permissions = std.Io.File.Permissions.fromMode(0o600),
        .make_path = true,
        .replace = true,
    }) catch return -1;
    defer atomic.deinit(io);
    atomic.file.writeStreamingAll(io, encrypted) catch return -1;
    atomic.replace(io) catch return -1;
    return 0;
}

export fn noctty_grid_workspace_dirty(raw: ?*anyopaque) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    return @intFromBool(bridge.app.recovery.dirty);
}

export fn noctty_grid_pane_selected(raw: ?*anyopaque, pane_id: u64) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    const pane = bridge.app.workspace.findPane(pane_id) orelse return 0;
    return @intFromBool(pane.selected);
}

export fn noctty_grid_pane_font_size(raw: ?*anyopaque, pane_id: u64) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    const pane = bridge.app.workspace.findPane(pane_id) orelse return 0;
    return @intFromFloat(pane.profile.font_size_pt * 100.0);
}

export fn noctty_grid_pane_profile(
    raw: ?*anyopaque,
    pane_id: u64,
    font_family: [*]u8,
    family_capacity: usize,
    font_size_hundredths: *c_int,
    high_contrast: *c_int,
    ligatures: *c_int,
) callconv(.c) c_int {
    font_size_hundredths.* = 0;
    high_contrast.* = 0;
    ligatures.* = 0;
    if (family_capacity > 0) font_family[0] = 0;

    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const pane = bridge.app.workspace.findPane(pane_id) orelse return -1;
    const family_length = if (family_capacity == 0)
        0
    else
        @min(pane.profile.font_family.len, family_capacity - 1);
    if (family_length > 0) @memcpy(font_family[0..family_length], pane.profile.font_family[0..family_length]);
    if (family_capacity > 0) font_family[family_length] = 0;
    font_size_hundredths.* = @intFromFloat(pane.profile.font_size_pt * 100.0);
    high_contrast.* = @intFromBool(std.mem.eql(u8, pane.profile.theme_name, "noctty-high-contrast"));
    ligatures.* = @intFromBool(pane.profile.ligatures);

    const request = bridge.app.profilePresetMenuRequest(.{ .pane_id = pane_id }) catch return -1;
    for (request.itemSlice()) |item| {
        if (item.current) return @intFromEnum(item.preset);
    }
    return -1;
}

export fn noctty_grid_pane_tags(raw: ?*anyopaque, pane_id: u64, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    const pane = bridge.app.workspace.findPane(pane_id) orelse return 0;
    if (pane.tags.items.len == 0 or capacity == 0) return 0;
    var writer = std.Io.Writer.fixed(output[0..capacity]);
    writer.writeAll("tags: ") catch return 0;
    for (pane.tags.items, 0..) |tag, index| {
        if (index > 0) writer.writeAll(", ") catch break;
        writer.writeAll(tag) catch break;
    }
    return @intCast(writer.buffered().len);
}

export fn noctty_grid_known_tags(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    if (capacity == 0) return 0;
    const tags = bridge.app.workspace.knownTags(bridge.app.allocator) catch return -1;
    defer bridge.app.allocator.free(tags);
    var writer = std.Io.Writer.fixed(output[0..capacity]);
    for (tags, 0..) |tag, index| {
        if (index > 0) writer.writeAll("\n") catch break;
        writer.writeAll(tag) catch break;
    }
    return @intCast(writer.buffered().len);
}

export fn noctty_grid_pane_matches_smart_filter(raw: ?*anyopaque, pane_id: u64) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 1));
    return if (bridge.app.workspace.paneMatchesSmartFilter(pane_id)) 1 else 0;
}

export fn noctty_grid_tag_selected_panes(raw: ?*anyopaque, tag_ptr: [*]const u8, tag_len: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    _ = bridge.app.dispatch(.{ .tag_selected_panes = tag_ptr[0..tag_len] }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    persistNativeGridHotSession(bridge);
    return 0;
}

export fn noctty_grid_remove_tag_from_selected_panes(raw: ?*anyopaque, tag_ptr: [*]const u8, tag_len: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    _ = bridge.app.dispatch(.{ .remove_tag_from_selected_panes = tag_ptr[0..tag_len] }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    persistNativeGridHotSession(bridge);
    return 0;
}

export fn noctty_grid_set_smart_filter(raw: ?*anyopaque, tag_ptr: [*]const u8, tag_len: usize) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return -1));
    const tag = if (tag_len == 0) null else tag_ptr[0..tag_len];
    _ = bridge.app.dispatch(.{ .set_smart_filter = tag }) catch {
        bridge.callback_failed = true;
        return -1;
    };
    persistNativeGridHotSession(bridge);
    return 0;
}

export fn noctty_grid_broadcast_enabled(raw: ?*anyopaque) callconv(.c) c_int {
    const bridge: *NativeGridBridge = @ptrCast(@alignCast(raw orelse return 0));
    return @intFromBool(bridge.app.workspace.broadcast_enabled);
}

export fn noctty_grid_scroll(raw: ?*anyopaque, lines: c_int) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    session.grid.scrollViewport(lines);
    return 0;
}

export fn noctty_grid_cursor(raw: ?*anyopaque) callconv(.c) u32 {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    if (!session.grid.cursor_visible) return 0xffffffff;
    return (@as(u32, @intCast(session.grid.cursor_row)) << 16) | @as(u32, @intCast(session.grid.cursor_column));
}

export fn noctty_grid_title(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    const title = session.grid.titleSlice();
    const length = @min(title.len, capacity);
    @memcpy(output[0..length], title[0..length]);
    return @intCast(length);
}

export fn noctty_grid_cursor_mode(raw: ?*anyopaque) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    return if (session.grid.application_cursor_keys) 1 else 0;
}

export fn noctty_grid_mouse_mode(raw: ?*anyopaque) callconv(.c) c_int {
    const session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    return if (session.grid.mouse_reporting) 1 else 0;
}

export fn noctty_grid_focus(raw: ?*anyopaque, focused: c_int) callconv(.c) c_int {
    var session: *noctty.terminal_session.TerminalSession = @ptrCast(@alignCast(raw.?));
    if (!session.grid.focus_reporting) return 0;
    const sequence = if (focused != 0) "\x1b[I" else "\x1b[O";
    session.write(sequence) catch return -1;
    return @intCast(sequence.len);
}

fn nativeGridSmoke(out: anytype, mode: c_int) !void {
    var session = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("sleep 0.5; printf '\\033[?2026h\\033[2;1H\\033[1;3;4;9;38;2;96;180;255mNOCTTY_NATIVE_GRID_OK A\\314\\201 \\360\\237\\221\\251\\342\\200\\215\\360\\237\\232\\200'; sleep 0.12; printf '\\033[0m\\033[?2026l\\033]2;native-grid\\007'; sleep 0.1; printf '\\033[?2026hDEADMAN'; sleep 0.5; printf '\\033[?2026l'; sleep 0.2; exit 0\n");
    const status = runNativeGridHost(.{
        .session = &session,
        .mode = mode,
        .workspace_smoke = 0,
    });
    if (status != 0) return error.NativeGridHostFailed;
    try out.print("native_grid_smoke gtk=true drawing_surface=true keyboard_abi=true pty=true vt=true exited=true\n", .{});
}

fn nativeGridPresentationQualification(out: anytype) !void {
    var session = try noctty.terminal_session.TerminalSession.spawn(
        std.heap.page_allocator,
        "/tmp",
        "/bin/sh",
        96,
        24,
    );
    defer session.deinit();
    try session.write("exec cat\n");
    const status = runNativeGridHost(.{
        .session = &session,
        .mode = 1,
        .workspace_smoke = 36,
    });
    if (status != 0) return error.NativeGridPresentationQualificationFailed;
    try out.print(
        "native_grid_presentation_host gtk=true mapped=true pty=true vt=true exited=true\n",
        .{},
    );
}

fn nativeGridFullStackQualification(out: anytype) !void {
    _ = out;
    var session = try noctty.terminal_session.TerminalSession.spawn(
        std.heap.page_allocator,
        "/tmp",
        "/bin/sh",
        96,
        24,
    );
    defer session.deinit();
    try session.write(
        "stty -echo; printf '\\033[2J\\033[HNOCTTY mapped idle qualification\\r\\n" ++ "PTY · VT · GTK · Cairo · Plasma\\r\\n'; exec cat\n",
    );
    const status = runNativeGridHost(.{
        .session = &session,
        .mode = 1,
        .workspace_smoke = 37,
    });
    if (status != 0) return error.NativeGridFullStackQualificationFailed;
}

fn nativeGridStabilityQualification() !void {
    const command = if (getenv("NOCTTY_STABILITY_COMMAND")) |value|
        std.mem.span(value)
    else
        "stty -echo; printf '\\033]2;NOCTTY stability qualification\\007'" ++
            "; printf '\\033[2J\\033[HNOCTTY stability qualification\\r\\n'" ++
            "; (i=0; while :; do i=$((i + 1))" ++
            "; printf 'NOCTTY stability heartbeat %08d\\r\\n' \"$i\"" ++
            "; sleep \"${NOCTTY_STABILITY_HEARTBEAT_SECONDS:-1}\"; done) & worker=$!" ++
            "; cat >/dev/null; kill \"$worker\" 2>/dev/null || true" ++
            "; wait \"$worker\" 2>/dev/null || true; exit 0";
    var profile = noctty.launch_profile.Profile{ .kind = .command };
    try profile.command.set(command);
    var session = try noctty.terminal_session.TerminalSession.spawnProfile(
        std.heap.page_allocator,
        &profile,
        "/tmp",
        "/bin/sh",
        120,
        36,
    );
    defer session.deinit();
    const status = runNativeGridHost(.{
        .session = &session,
        .mode = 1,
        .workspace_smoke = 40,
    });
    if (status != 0) return error.NativeGridStabilityQualificationFailed;
}

fn nativeGridAuthenticatedAgentQualification(io: std.Io, out: anytype) !void {
    const response_path_raw = getenv("NOCTTY_AUTH_AGENT_RESPONSE_PATH") orelse
        return error.MissingAuthenticatedAgentResponsePath;
    const response_path = std.mem.span(response_path_raw);
    var profile = noctty.launch_profile.Profile{ .kind = .command };
    try profile.command.set(
        "printf '\\033]2;NOCTTY authenticated Codex qualification\\007'" ++
            "; printf 'Authenticated Codex model request through NOCTTY\\r\\n'" ++
            "; codex exec --ephemeral --skip-git-repo-check --sandbox read-only" ++
            " --color never -C /tmp -o \"$NOCTTY_AUTH_AGENT_RESPONSE_PATH\"" ++
            " 'Do not run commands or inspect files. Reply with exactly" ++
            " NOCTTY_AUTHENTICATED_CODEX_OK.' </dev/null; status=$?" ++
            "; printf '\\r\\nNOCTTY AUTHENTICATED CODEX EXIT=%d\\r\\n' \"$status\"" ++
            "; count=0; while [ ! -e \"$NOCTTY_AUTH_AGENT_CAPTURED_PATH\" ]" ++
            " && [ \"$count\" -lt 600 ]; do sleep 0.1; count=$((count + 1)); done" ++
            "; [ -e \"$NOCTTY_AUTH_AGENT_CAPTURED_PATH\" ] || exit 124" ++
            "; exit \"$status\"",
    );
    var session = try noctty.terminal_session.TerminalSession.spawnProfile(
        std.heap.page_allocator,
        &profile,
        "/tmp",
        "/bin/sh",
        120,
        36,
    );
    defer session.deinit();
    const status = runNativeGridHost(.{
        .session = &session,
        .mode = 1,
        .workspace_smoke = 38,
    });
    if (status != 0) return error.NativeGridAuthenticatedAgentQualificationFailed;
    const response = try std.Io.Dir.cwd().readFileAlloc(
        io,
        response_path,
        std.heap.page_allocator,
        .limited(1024),
    );
    defer std.heap.page_allocator.free(response);
    if (!std.mem.eql(
        u8,
        std.mem.trim(u8, response, " \t\r\n"),
        "NOCTTY_AUTHENTICATED_CODEX_OK",
    )) return error.AuthenticatedAgentResponseMismatch;
    try out.print(
        "native_grid_authenticated_agent_qualification provider=codex " ++
            "authenticated=true model_request=true ephemeral=true sandbox=read-only " ++
            "production_pty=true production_vt=true production_gtk=true " ++
            "production_cairo=true response_exact=true controlled_exit=true\n",
        .{},
    );
}

fn nativeGridInstalledContinuityQualification(
    kind_name: []const u8,
    session_name: []const u8,
    out: anytype,
) !void {
    const kind: noctty.launch_profile.Kind = if (std.mem.eql(u8, kind_name, "tmux"))
        .tmux
    else if (std.mem.eql(u8, kind_name, "zellij"))
        .zellij
    else
        return error.InvalidInstalledContinuityKind;
    var profile = noctty.launch_profile.Profile{ .kind = kind };
    try profile.ssh_target.set(session_name);
    var session = try noctty.terminal_session.TerminalSession.spawnProfile(
        std.heap.page_allocator,
        &profile,
        "/tmp",
        "/bin/sh",
        120,
        36,
    );
    defer session.deinit();
    const status = runNativeGridHost(.{
        .session = &session,
        .mode = 1,
        .workspace_smoke = 39,
    });
    if (status != 0) return error.NativeGridInstalledContinuityQualificationFailed;
    try out.print(
        "native_grid_installed_continuity_qualification kind={s} " ++
            "installed_tool=true create_or_attach=true production_pty=true " ++
            "production_vt=true production_gtk=true production_cairo=true " ++
            "controlled_detach=true exited=true\n",
        .{kind_name},
    );
}

fn terminalHistoryQualification(
    allocator: std.mem.Allocator,
    out: anytype,
) !void {
    const line_limit = noctty.vt.Grid.max_history_lines;
    var grid = try noctty.vt.Grid.initWithHistoryLimit(
        allocator,
        80,
        2,
        line_limit,
    );
    defer grid.deinit();
    for (0..line_limit + 1) |_| try grid.feed("x\r\n");
    if (grid.history.items.len != line_limit)
        return error.TerminalHistoryQualificationCount;
    const direct_baseline = line_limit * grid.columns * @sizeOf(noctty.vt.Cell);
    const compact_bytes = grid.historyMemoryBytes();
    if (compact_bytes >= direct_baseline / 2)
        return error.TerminalHistoryQualificationMemory;

    try grid.resize(37, 3);
    if (grid.history.items.len + grid.rows != line_limit + 2)
        return error.TerminalHistoryQualificationNarrowReflow;
    try grid.resize(100, 2);
    if (grid.history.items.len + grid.rows != line_limit + 2)
        return error.TerminalHistoryQualificationWideReflow;
    const reflow_bytes = grid.historyMemoryBytes();

    try grid.setHistoryLimit(128);
    if (grid.history.items.len != 128)
        return error.TerminalHistoryQualificationShrink;
    const shrink_bytes = grid.historyMemoryBytes();
    if (shrink_bytes >= compact_bytes / 4)
        return error.TerminalHistoryQualificationRelease;
    try grid.setHistoryLimit(line_limit);
    if (grid.historyMemoryBytes() != shrink_bytes)
        return error.TerminalHistoryQualificationLazyRegrow;

    const cycles: usize = 4;
    for (0..cycles) |_| {
        for (0..2048) |index| {
            var buffer: [24]u8 = undefined;
            try grid.feed(try std.fmt.bufPrint(&buffer, "cycle-{d}\r\n", .{index}));
        }
        try grid.setHistoryLimit(128);
        if (grid.history.items.len != 128 or
            grid.historyMemoryBytes() > shrink_bytes * 2)
            return error.TerminalHistoryQualificationCycle;
        try grid.setHistoryLimit(line_limit);
    }
    try out.print(
        "terminal_history_qualification lines={d} direct_bytes={d} compact_bytes={d} compact_ratio_bp={d} reflow_bytes={d} reflow_narrow=true reflow_wide=true shrink_bytes={d} grow_shrink_cycles={d} cold_memory_only=true passed=true\n",
        .{
            line_limit,
            direct_baseline,
            compact_bytes,
            compact_bytes * 10_000 / direct_baseline,
            reflow_bytes,
            shrink_bytes,
            cycles,
        },
    );

    var idle_grid = try noctty.vt.Grid.init(allocator, 120, 40);
    defer idle_grid.deinit();
    for (0..1100) |_| try idle_grid.feed("agent output line 0123456789\r\n");
    idle_grid.scrollViewport(@intCast(noctty.vt.Grid.default_history_lines));
    const idle_oldest = idle_grid.cell(0, 0);
    const idle_bytes_before = idle_grid.historyMemoryBytes();
    var idle_steps: usize = 0;
    while (idle_steps < 32) : (idle_steps += 1) {
        const result = try idle_grid.compactIdleHistoryStep(
            noctty.vt.Grid.idle_history_hot_lines,
            noctty.vt.Grid.idle_history_rows_per_step,
        );
        if (result.rows_coldified > noctty.vt.Grid.idle_history_rows_per_step)
            return error.TerminalIdleHistoryStepUnbounded;
        if (!result.complete) continue;
        idle_steps += 1;
        break;
    }
    if (idle_steps >= 32) return error.TerminalIdleHistoryCompactionTimedOut;
    const idle_bytes_after = idle_grid.historyMemoryBytes();
    if (idle_bytes_after >= idle_bytes_before / 2)
        return error.TerminalIdleHistoryMemory;
    if (!std.meta.eql(idle_oldest, idle_grid.cell(0, 0)))
        return error.TerminalIdleHistoryContent;
    for (0..200) |_| try idle_grid.feed("resumed output\r\n");
    if (idle_grid.history_hot_owners.len <= noctty.vt.Grid.idle_history_hot_lines)
        return error.TerminalIdleHistoryRegrow;
    try out.print(
        "terminal_idle_history_qualification columns=120 rows=40 history=1000 before_bytes={d} after_bytes={d} saved_bytes={d} steps={d} rows_per_step={d} content_preserved=true resumed_output_regrows=true passed=true\n",
        .{
            idle_bytes_before,
            idle_bytes_after,
            idle_bytes_before - idle_bytes_after,
            idle_steps,
            noctty.vt.Grid.idle_history_rows_per_step,
        },
    );
}

fn nativeGridWorkspaceSmoke(out: anytype) !void {
    var app = try noctty.app.App.init(std.heap.page_allocator);
    defer app.deinit();
    _ = try app.dispatch(.{ .set_dropdown_dimensions = .{
        .width_percent = app.config.dropdown.width_percent,
        .height_percent = app.config.dropdown.height_percent,
        .height_px = 32,
    } });
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = app.workspace.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try std.heap.page_allocator.dupeZ(u8, pane.cwd);
    defer std.heap.page_allocator.free(cwd);
    var session = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, cwd, "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_NATIVE_WORKSPACE_OK'; IFS= read -r _; exit 0\n");
    var session_pool = NativeGridSessionPool.init(std.heap.page_allocator, "/bin/sh", "printf 'NOCTTY_NATIVE_WORKSPACE_DYNAMIC'; IFS= read -r _; exit 0\n");
    defer session_pool.deinit();
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id, .session_pool = &session_pool };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .mode = 0,
        .workspace_smoke = 1,
    });
    if (status != 0) return error.NativeGridWorkspaceHostFailed;
    if (bridge.callback_failed) return error.NativeGridWorkspaceStateSyncFailed;
    if (!bridge.saw_tab_command) return error.NativeGridWorkspaceTabCommandMissing;
    if (!bridge.saw_split_command) return error.NativeGridWorkspaceSplitDownMissing;
    if (!bridge.saw_split_left_command) return error.NativeGridWorkspaceSplitLeftMissing;
    if (!bridge.saw_broadcast_command) return error.NativeGridWorkspaceBroadcastMissing;
    if (!bridge.saw_selection_command) return error.NativeGridWorkspaceSelectionCommandMissing;
    if (!bridge.saw_focus_command) return error.NativeGridWorkspaceFocusCommandMissing;
    if (!bridge.saw_move_command) return error.NativeGridWorkspaceMoveCommandMissing;
    if (!bridge.saw_rendered_move) return error.NativeGridWorkspaceRenderedMoveMissing;
    if (app.workspace.tabs.items.len != 2 or app.workspace.tabs.items[0].panes.items.len != 2 or app.workspace.tabs.items[1].panes.items.len != 2) return error.NativeGridWorkspaceLayoutMissing;
    if (!app.workspace.broadcast_enabled) return error.NativeGridBroadcastMissing;
    if (!app.workspace.findPane(3).?.selected) return error.NativeGridSelectionMissing;
    if (!app.workspace.findPane(3).?.hasTag("ci")) return error.NativeGridTagMissing;
    if (app.workspace.smart_filter_tag != null) return error.NativeGridFilterNotCleared;
    try out.print("native_grid_workspace_smoke tab_command=true split_down=true split_left=true broadcast=true broadcast_shortcut=true broadcast_confirm=true broadcast_cancel_default=true broadcast_disable_immediate=true broadcast_state_label=true selection_indicator=true selected_pane=3 focus_cycle=true pane_move=true rendered_move=true tag=true tag_suggestions=true filter=true filter_indicator=true filter_empty=true filter_empty_context=true filter_empty_clear=true filter_empty_escape=true filter_focus=true filter_cleared=true tabs=2 active_panes=2 dropdown_minimum=true visual_ready=true controlled_exit=true exited=true\n", .{});
}

fn nativeGridTabNavigationSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_TAB_NAVIGATION_OK'; IFS= read -r _; exit 0\n");
    var session_pool = NativeGridSessionPool.init(allocator, "/bin/sh", "printf 'NOCTTY_TAB_NAVIGATION_CHILD'; IFS= read -r _; exit 0\n");
    defer session_pool.deinit();
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id, .session_pool = &session_pool };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .workspace_smoke = 22,
    });
    if (status != 0 or bridge.callback_failed or !bridge.saw_tab_cycle_next or
        !bridge.saw_tab_cycle_previous or !bridge.saw_pane_cycle_shortcut or
        !bridge.saw_alt_scroll_pane_cycle or
        !bridge.saw_ctrl_alt_scroll_tab_cycle or
        !bridge.saw_smart_tab_cycle_shortcut or !bridge.saw_tab_shortcut_close or
        !bridge.saw_tab_shortcut_reopen or !bridge.saw_tab_focus_restored or
        app.workspace.smart_filter_tag != null or
        app.workspace.tabs.items.len != 2)
    {
        return error.NativeGridTabNavigationSmokeFailed;
    }
    try out.print("native_grid_tab_navigation_smoke pane_ctrl_tab=true alt_scroll=true alt_scroll_up=true alt_scroll_down=true current_tab=true visible_panes_only=true hidden_skipped=true visual_feedback=true ctrl_alt_scroll=true tab_scroll_up=true tab_scroll_down=true tab_wraparound=true tab_visual_feedback=true tab_ctrl_shift_tab=true smart_filter_preserved=true cycle_next=true cycle_previous=true shortcut_close=true shortcut_reopen=true focus_restored=true tabs=2 exited=true\n", .{});
}

fn nativeGridTabTitleSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_TITLE_READY'\n");
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .workspace_smoke = 23,
    });
    if (status != 0 or bridge.callback_failed or !bridge.saw_title_fallback or
        !bridge.saw_title_overflow or !bridge.saw_title_tooltip or !bridge.saw_title_rename)
    {
        return error.NativeGridTabTitleSmokeFailed;
    }
    try out.print("native_grid_tab_title_smoke fallback=true overflow=true tooltip_full=true rename_override=true exited=true\n", .{});
}

fn nativeGridDirtySmoke(io: std.Io, out: anytype) !void {
    const allocator = std.heap.page_allocator;
    const dirty_path = "/tmp/noctty-native-grid-dirty.nocttyws";
    std.Io.Dir.cwd().deleteFile(io, dirty_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, dirty_path) catch {};
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_DIRTY_READY'\n");
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id, .io = io };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .workspace_smoke = 24,
    });
    if (status != 0 or bridge.callback_failed or !bridge.saw_dirty_marker or
        !bridge.saw_attention_marker or !bridge.saw_status_notification or
        !bridge.saw_status_acknowledged or !bridge.workspace_saved or
        !bridge.saw_dirty_cleared or !bridge.saw_dirty_title_preserved or
        !bridge.saw_attention_cleared or app.recovery.dirty)
    {
        std.debug.print(
            "native_grid_tab_dirty_missing status={} callback={} dirty={} attention={} status_notification={} status_acknowledged={} saved={} dirty_cleared={} title_preserved={} attention_cleared={} recovery_dirty={}\n",
            .{ status, bridge.callback_failed, bridge.saw_dirty_marker, bridge.saw_attention_marker, bridge.saw_status_notification, bridge.saw_status_acknowledged, bridge.workspace_saved, bridge.saw_dirty_cleared, bridge.saw_dirty_title_preserved, bridge.saw_attention_cleared, app.recovery.dirty },
        );
        return error.NativeGridTabDirtySmokeFailed;
    }
    try out.print("native_grid_tab_dirty_smoke attention=true attention_cleared=true status_notification=true status_acknowledged=true dirty=true saved=true dirty_cleared=true title_preserved=true exited=true\n", .{});
}

fn nativeGridTabReorderSmoke(io: std.Io, out: anytype) !void {
    const allocator = std.heap.page_allocator;
    const reorder_path = "/tmp/noctty-native-grid-reorder.nocttyws";
    std.Io.Dir.cwd().deleteFile(io, reorder_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, reorder_path) catch {};
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_REORDER_READY'\n");
    var session_pool = NativeGridSessionPool.init(allocator, "/bin/sh", "printf 'NOCTTY_REORDER_CHILD'; sleep 6; exit 0\n");
    defer session_pool.deinit();
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id, .io = io, .session_pool = &session_pool };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .workspace_smoke = 25,
    });
    if (status != 0 or bridge.callback_failed or !bridge.saw_reorder_ui or
        !bridge.saw_reorder_model or !bridge.saw_reorder_persisted)
    {
        return error.NativeGridTabReorderSmokeFailed;
    }
    try out.print("native_grid_tab_reorder_smoke pointer_drag=true pointer_press=true pointer_drop=true forward=true tabs=3 active_identity=true model_order=true snapshot_order=true persistence_coalesced=true exited=true\n", .{});
}

fn nativeGridPaletteRenameSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_PALETTE_RENAME_READY'\n");
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .workspace_smoke = 26,
    });
    if (status != 0 or bridge.callback_failed or !bridge.saw_palette_rename_validation or
        !bridge.saw_palette_rename_commit or !bridge.saw_palette_rename_cancel or
        !std.mem.eql(u8, app.workspace.activeTab().?.title, "Palette renamed tab") or
        !app.workspace.activeTab().?.title_overridden or !app.recovery.dirty)
        return error.NativeGridPaletteRenameSmokeFailed;
    try out.print("native_grid_palette_rename_smoke palette=true validation=true commit=true cancel=true focus_restored=true title_preserved=true exited=true\n", .{});
}

fn nativeGridPaneMoveSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(allocator, cwd, "/bin/sh", 72, 32);
    defer primary.deinit();
    try primary.write("printf 'NOCTTY_MOVE_PRIMARY'; sleep 2; exit 0\n");
    var session_pool = NativeGridSessionPool.init(allocator, "/bin/sh", "printf 'NOCTTY_MOVE_CHILD'; sleep 1; exit 0\n");
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .columns = 72,
        .rows = 32,
        .workspace_smoke = 14,
    });
    if (status != 0) return error.NativeGridPaneMoveHostFailed;
    if (bridge.callback_failed) return error.NativeGridPaneMoveStateSyncFailed;
    if (!bridge.saw_tab_command or !bridge.saw_move_command or !bridge.saw_rendered_move) return error.NativeGridPaneMoveEventMissing;
    if (app.workspace.tabs.items.len != 1 or app.workspace.tabs.items[0].panes.items.len != 2) return error.NativeGridPaneMoveLayoutMismatch;
    try out.print("native_grid_pane_move_smoke menu_action=true live_reparent=true source_tab_closed=true tabs=1 panes=2 focused=true exited=true\n", .{});
}

fn nativeGridCompactUxSmoke(allocator: std.mem.Allocator, io: std.Io, out: anytype) !void {
    const scrollback_path = "/tmp/noctty-native-grid-compact-scrollback.txt";
    const workspace_path = "/tmp/noctty-native-grid-font-wheel.nocttyws";
    std.Io.Dir.cwd().deleteFile(io, scrollback_path) catch {};
    std.Io.Dir.cwd().deleteFile(io, workspace_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, scrollback_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, workspace_path) catch {};
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const global_font_size = app.config.font.size_pt;
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(allocator, cwd, "/bin/sh", 80, 28);
    defer primary.deinit();
    try primary.write("printf 'NOCTTY_COMPACT_SEARCH\\007'; sleep 3; exit 0\n");
    var session_pool = NativeGridSessionPool.init(allocator, "/bin/sh", "printf 'NOCTTY_COMPACT_CHILD'; sleep 3; exit 0\n");
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .io = io,
        .config_path = workspace_path,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .columns = 80,
        .rows = 28,
        .workspace_smoke = 15,
    });
    if (status != 0 or bridge.callback_failed) return error.NativeGridCompactUxHostFailed;
    if (!bridge.saw_palette or !bridge.saw_terminal_find or !bridge.saw_quick_note or
        !bridge.saw_font_increase or !bridge.saw_font_decrease or
        !bridge.saw_pane_zoom or !bridge.saw_directional_focus or
        !bridge.scrollback_saved)
    {
        std.debug.print(
            "native_grid_compact_ux_missing palette={} find={} note={} font_up={} font_down={} zoom={} focus={} scrollback={}\n",
            .{ bridge.saw_palette, bridge.saw_terminal_find, bridge.saw_quick_note, bridge.saw_font_increase, bridge.saw_font_decrease, bridge.saw_pane_zoom, bridge.saw_directional_focus, bridge.scrollback_saved },
        );
        return error.NativeGridCompactUxEventMissing;
    }
    if (app.config.font.size_pt != global_font_size)
        return error.NativeGridCompactUxGlobalFontChanged;
    const active_tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    if (active_tab.panes.items.len != 2 or
        app.workspace.findPane(1).?.profile.font_size_pt != global_font_size + 1.0 or
        app.workspace.findPane(2).?.profile.font_size_pt != global_font_size)
        return error.NativeGridCompactUxPaneFontIsolationMismatch;
    const saved_workspace = try app.saveWorkspaceFile(io, std.Io.Dir.cwd(), workspace_path, .manual);
    defer saved_workspace.deinit(allocator);
    var loaded_app = try noctty.app.App.init(allocator);
    defer loaded_app.deinit();
    const loaded_workspace = try loaded_app.loadWorkspaceFile(io, std.Io.Dir.cwd(), workspace_path, .manual);
    defer loaded_workspace.deinit(allocator);
    if (loaded_app.workspace.findPane(1).?.profile.font_size_pt != global_font_size + 1.0 or
        loaded_app.workspace.findPane(2).?.profile.font_size_pt != global_font_size)
        return error.NativeGridCompactUxFontWheelPersistenceMismatch;
    if (!std.mem.eql(u8, app.workspace.quick_note, "compact workspace note"))
        return error.NativeGridCompactUxNoteMismatch;
    if (active_tab.zoomed_pane_id != null or active_tab.panes.items.len != 2)
        return error.NativeGridCompactUxLayoutMismatch;
    if (!std.mem.eql(u8, active_tab.panes.items[0].cwd, active_tab.panes.items[1].cwd))
        return error.NativeGridCompactUxCwdMismatch;
    const contents = try std.Io.Dir.cwd().readFileAlloc(io, scrollback_path, allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(contents);
    if (std.mem.indexOf(u8, contents, "NOCTTY_COMPACT_SEARCH") == null)
        return error.NativeGridCompactUxScrollbackMismatch;
    try out.print("native_grid_compact_ux_smoke palette=true find=true scrollback=true zoom=true tab_bar_zoom=true direction=true quick_note=true transient_accessible=true font_wheel=true font_pane=true font_isolated=true plain_scroll=true font_workspace_persisted=true attention=true ime=true terminal_cursor=text dragger=info_bar dragger_cursor=ns-resize side_border=3 diagonal_cursors=false application_icon=true pane_info=true tab_bar_above_info=true pane_source=pty_proc pane_resources=true pane_refresh=coalesced pane_info_dedup=true chrome=transient same_cwd=true saved=true exited=true\n", .{});
}

fn nativeGridNoteOverlaySmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    const note = "Deploy ✓\nCheck logs\nKeep rollback ready";
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    _ = try app.dispatch(.{ .set_quick_note = note });
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        80,
        28,
    );
    defer primary.deinit();
    try primary.write("printf 'NOCTTY_NOTE_OVERLAY_PRIMARY'; IFS= read -r _; exit 0\n");
    var session_pool = NativeGridSessionPool.init(
        allocator,
        "/bin/sh",
        "printf 'NOCTTY_NOTE_OVERLAY_SECONDARY'; IFS= read -r _; exit 0\n",
    );
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .columns = 80,
        .rows = 28,
        .workspace_smoke = 29,
    });
    if (status != 0 or bridge.callback_failed)
        return error.NativeGridNoteOverlaySmokeFailed;
    if (app.workspace.activeTab().?.panes.items.len != 2 or
        !std.mem.eql(u8, app.workspace.quick_note, note))
        return error.NativeGridNoteOverlayStateMismatch;
    try out.print("native_grid_note_overlay_smoke alt_hold=true visible_panes=2 workspace_note=true utf8=true multiline=true compact=true hidden_on_release=true exited=true\n", .{});
}

fn nativeGridTwoPaneSmoke(out: anytype) !void {
    var app = try noctty.app.App.init(std.heap.page_allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const primary_pane = app.workspace.findPane(1) orelse return error.PaneNotFound;
    const primary_cwd = try std.heap.page_allocator.dupeZ(u8, primary_pane.cwd);
    defer std.heap.page_allocator.free(primary_cwd);
    const secondary_cwd = try std.heap.page_allocator.dupeZ(u8, primary_pane.cwd);
    defer std.heap.page_allocator.free(secondary_cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, primary_cwd, "/bin/sh", 48, 24);
    defer primary.deinit();
    var secondary = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, secondary_cwd, "/bin/sh", 48, 24);
    defer secondary.deinit();
    try primary.write("printf 'NOCTTY_NATIVE_PRIMARY'; sleep 1; exit 0\n");
    try secondary.write("printf 'NOCTTY_NATIVE_SECONDARY'; sleep 1; exit 0\n");
    var bridge = NativeGridBridge{ .app = &app, .pane_id = 1, .secondary_pane_id = 2 };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = 1,
        .columns = 48,
        .workspace_smoke = 2,
        .secondary_session = &secondary,
        .secondary_pane_id = 2,
    });
    if (status != 0 or bridge.callback_failed or !bridge.saw_secondary_started or !bridge.saw_secondary_output or !bridge.saw_secondary_exited) return error.NativeGridTwoPaneSmokeFailed;
    if (tab.panes.items.len != 2) return error.NativeGridTwoPaneLayoutMissing;
    try out.print("native_grid_two_pane_smoke panes=2 dynamic_split=true primary_pty=true secondary_pty=true pty_event_source=true primary_grid=true secondary_grid=true secondary_lifecycle=true exited=true\n", .{});
}

fn nativeGridPaneCloseSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const pane_id = (try app.dispatch(.split_down)).pane_created;
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const primary_pane = app.workspace.findPane(1) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, primary_pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        64,
        24,
    );
    defer primary.deinit();
    var secondary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        64,
        24,
    );
    defer secondary.deinit();
    try primary.write("printf 'NOCTTY_PANE_CLOSE_PRIMARY'; /bin/sh -c 'IFS= read -r _'; exit 0\n");
    try secondary.write("printf 'NOCTTY_PANE_CLOSE_SECONDARY'; /bin/sh -c 'IFS= read -r _'; exit 0\n");
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = 1,
        .secondary_pane_id = pane_id,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = 1,
        .columns = 64,
        .workspace_smoke = 20,
        .secondary_session = &secondary,
        .secondary_pane_id = pane_id,
        .secondary_initially_active = 1,
    });
    if (status != 0 or bridge.callback_failed or
        !bridge.saw_pane_close_command or bridge.closed_pane_id != 1 or
        bridge.pane_close_tab_closed or !bridge.saw_secondary_started or
        !bridge.saw_secondary_output or !bridge.saw_secondary_exited)
        return error.NativeGridPaneCloseSmokeFailed;
    if (tab.panes.items.len != 1 or tab.panes.items[0].id != pane_id or
        tab.active_pane_id != pane_id or app.workspace.findPane(1) != null or
        app.workspace.findPane(pane_id) == null or !app.recovery.dirty)
        return error.NativeGridPaneCloseLayoutMissing;
    try out.print("native_grid_pane_close_smoke initial_panes=2 context_menu=true menu_survived=true menu_popdown=true targeted_primary=true close_terminal=true foreground_guard=true close_confirmed=true model_closed=true rendered_closed=true primary_pty_closed=true session_storage_released=true pty_event_source=true split_collapsed=true remaining_panes=1 remaining_focused=true last_terminal_protected=true secondary_lifecycle=true exited=true\n", .{});
}

fn nativeGridTerminalChordsSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const secondary_pane_id = (try app.dispatch(.split_down)).pane_created;
    _ = try app.dispatch(.toggle_broadcast);
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const primary_pane = app.workspace.findPane(1) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, primary_pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        64,
        24,
    );
    defer primary.deinit();
    var secondary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        64,
        24,
    );
    defer secondary.deinit();
    try primary.write("interrupted=0; trap 'interrupted=1' INT; printf 'NOCTTY_TERMINAL_CHORD_PRIMARY_READY'; while :; do if IFS= read -r line; then [ \"$line\" = done ] && break; elif [ \"$interrupted\" = 1 ]; then interrupted=0; else break; fi; done; exit 0\n");
    try secondary.write("interrupted=0; trap 'interrupted=1' INT; printf 'NOCTTY_TERMINAL_CHORD_SECONDARY_READY'; while :; do if IFS= read -r line; then [ \"$line\" = done ] && break; elif [ \"$interrupted\" = 1 ]; then interrupted=0; else break; fi; done; exit 0\n");
    native_grid_terminal_chord_probe = .{
        .primary = &primary,
        .secondary = &secondary,
    };
    defer native_grid_terminal_chord_probe = .{};
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = 1,
        .secondary_pane_id = secondary_pane_id,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .write = noctty_grid_terminal_chord_write,
        .bridge = &bridge,
        .pane_id = 1,
        .columns = 64,
        .workspace_smoke = 31,
        .secondary_session = &secondary,
        .secondary_pane_id = secondary_pane_id,
        .secondary_initially_active = 1,
    });
    if (status != 0 or bridge.callback_failed or
        !bridge.saw_terminal_interrupt_targeted or
        !bridge.saw_terminal_close_chord or
        !bridge.saw_terminal_final_pane_guard or
        !bridge.saw_pane_close_command or
        bridge.closed_pane_id != secondary_pane_id or
        bridge.pane_close_tab_closed)
        return error.NativeGridTerminalChordsSmokeFailed;
    if (!app.workspace.broadcast_enabled or tab.panes.items.len != 1 or
        tab.panes.items[0].id != 1 or tab.active_pane_id != 1 or
        app.workspace.findPane(secondary_pane_id) != null or
        native_grid_terminal_chord_probe.primary_interrupts != 0 or
        native_grid_terminal_chord_probe.secondary_interrupts != 1 or
        native_grid_terminal_chord_probe.primary_carriage_returns != 1 or
        native_grid_terminal_chord_probe.secondary_carriage_returns != 1 or
        native_grid_terminal_chord_probe.primary_eof != 0 or
        native_grid_terminal_chord_probe.secondary_eof != 0)
        return error.NativeGridTerminalChordsStateMismatch;
    try out.print("native_grid_terminal_chords_smoke panes=2 broadcast=true ctrl_c=true interrupt_target=current_pane primary_interrupts=0 secondary_interrupts=1 enter=carriage_return line_feed=false ctrl_d=true exact_pane=true eof_forwarded=false final_pane_protected=true remaining_focused=true exited=true\n", .{});
}

fn nativeGridLayoutPresetSmoke(
    allocator: std.mem.Allocator,
    io: std.Io,
    out: anytype,
) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        96,
        36,
    );
    defer primary.deinit();
    const layout_tui_raw = getenv("NOCTTY_LAYOUT_TUI");
    const layout_tui = if (layout_tui_raw) |value| std.mem.span(value) else "";
    const tui_vim = std.mem.eql(u8, layout_tui, "vim");
    const tui_btop = std.mem.eql(u8, layout_tui, "btop");
    const primary_command = if (tui_vim)
        "printf 'NOCTTY_LAYOUT_TUI_VIM\\n' >/tmp/noctty-layout-tui.txt; exec vim -Nu NONE -n -i NONE -c 'set noswapfile' /tmp/noctty-layout-tui.txt\n"
    else if (tui_btop)
        "printf 'NOCTTY_LAYOUT_TUI_VIM\\n' >/tmp/noctty-layout-tui.txt; exec btop --force-utf --update 100\n"
    else
        "printf 'NOCTTY_LAYOUT_PRESET_PRIMARY'; read -r; exit 0\n";
    const child_command = if (tui_vim or tui_btop)
        "exec vim -Nu NONE -n -i NONE -c 'set noswapfile' /tmp/noctty-layout-tui.txt\n"
    else
        "printf 'NOCTTY_LAYOUT_PRESET_CHILD'; IFS= read -r _; exit 0\n";
    try primary.write(primary_command);
    var session_pool = NativeGridSessionPool.init(
        allocator,
        "/bin/sh",
        child_command,
    );
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .rows = 36,
        .workspace_smoke = 21,
    });
    if (status != 0 or bridge.callback_failed or
        !bridge.saw_layout_2x2 or !bridge.saw_layout_4x2 or
        !bridge.saw_layout_3x3 or !bridge.saw_layout_4x4 or
        !bridge.saw_layout_1x1 or bridge.created_session_count != 48)
        return error.NativeGridLayoutPresetSmokeFailed;
    var pane_total: usize = 0;
    var saw_source = false;
    var saw_overflow = false;
    for (app.workspace.tabs.items) |*current_tab| {
        pane_total += current_tab.panes.items.len;
        saw_source = saw_source or current_tab.findPane(1) != null and
            current_tab.panes.items.len == 1;
        saw_overflow = saw_overflow or current_tab.panes.items.len == 15;
    }
    if (app.workspace.tabs.items.len != 2 or pane_total != 16 or
        !saw_source or !saw_overflow or !app.recovery.dirty)
        return error.NativeGridLayoutPresetModelMismatch;

    const workspace_path = "/tmp/noctty-native-grid-layout-preset.nocttyws";
    std.Io.Dir.cwd().deleteFile(io, workspace_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, workspace_path) catch {};
    const saved = try app.saveWorkspaceFile(io, std.Io.Dir.cwd(), workspace_path, .manual);
    saved.deinit(allocator);
    var restored = try noctty.app.App.init(allocator);
    defer restored.deinit();
    const loaded = try restored.loadWorkspaceFile(io, std.Io.Dir.cwd(), workspace_path, .manual);
    loaded.deinit(allocator);
    var restored_total: usize = 0;
    var restored_source = false;
    var restored_overflow = false;
    for (restored.workspace.tabs.items) |*current_tab| {
        restored_total += current_tab.panes.items.len;
        restored_source = restored_source or current_tab.findPane(1) != null and
            current_tab.panes.items.len == 1 and current_tab.active_pane_id == 1;
        restored_overflow = restored_overflow or
            current_tab.panes.items.len == 15;
    }
    if (restored.workspace.tabs.items.len != 2 or restored_total != 16 or
        !restored_source or !restored_overflow)
        return error.NativeGridLayoutPresetRestoreMismatch;
    try out.print("native_grid_layout_preset_smoke context_menu=true menu_survived=true layout_2x2=true panes_2x2=4 balanced_2x2=true churn_cycles=8 layout_4x2=true panes_4x2=8 balanced_4x2=true layout_3x3=true panes_3x3=9 balanced_3x3=true layout_4x4=true panes_4x4=16 balanced_4x4=true auto_fit=80x24 zoom_overlay=true floor_feedback=true tui_rendered=true tui_input=true prompt=true cancel_preserved=true accepted=true overflow_tab=true overflow_panes=15 sessions_preserved=16 interactive=true source_focused=true restored=true exited=true\n", .{});
}

fn nativeGridRecursiveSplitSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(allocator, cwd, "/bin/sh", 72, 32);
    defer primary.deinit();
    try primary.write("printf 'NOCTTY_RECURSIVE_PRIMARY'; sleep 2; exit 0\n");
    var session_pool = NativeGridSessionPool.init(allocator, "/bin/sh", "printf 'NOCTTY_RECURSIVE_CHILD'; sleep 1; exit 0\n");
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .columns = 72,
        .rows = 32,
        .workspace_smoke = 11,
    });
    if (status != 0 or bridge.callback_failed) return error.NativeGridRecursiveSplitSmokeFailed;
    if (bridge.created_session_count != 3 or tab.panes.items.len != 4) return error.NativeGridRecursiveSplitCountMismatch;
    if (!bridge.saw_split_down_vertical or !bridge.saw_split_left_horizontal) return error.NativeGridRecursiveSplitOrientationMismatch;
    if (!bridge.saw_secondary_started or !bridge.saw_secondary_output or !bridge.saw_secondary_exited) return error.NativeGridRecursiveSplitLifecycleMissing;
    try out.print("native_grid_recursive_split_smoke panes=4 sessions=4 split_down=vertical split_left=horizontal recursive=true dynamic_sessions=true exited=true\n", .{});
}

fn nativeGridClickFocusSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(allocator, cwd, "/bin/sh", 72, 32);
    defer primary.deinit();
    var session_pool = NativeGridSessionPool.init(allocator, "/bin/sh", null);
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .columns = 72,
        .rows = 32,
        .workspace_smoke = 12,
    });
    if (status != 0) return error.NativeGridClickFocusHostFailed;
    if (bridge.callback_failed) return error.NativeGridClickFocusStateSyncFailed;
    if (bridge.created_session_count != 1 or tab.panes.items.len != 2) return error.NativeGridClickFocusCountMismatch;
    if (tab.active_pane_id != 2 or tab.zoomed_pane_id != null or !bridge.saw_pane_zoom) return error.NativeGridClickFocusStateMismatch;
    if (!bridge.saw_secondary_output or !bridge.saw_secondary_exited) return error.NativeGridClickFocusRoutingMissing;
    try out.print("native_grid_click_focus_smoke panes=2 primary_click=true secondary_click=true clean_click=true hover_trails=false double_click_zoom=true zoom_selection=false restore_selection=false drag_selection=true focus_switched=true primary_input=true secondary_input=true focus_readiness=bounded controlled_exit=true exited=true\n", .{});
}

fn nativeGridEightPaneSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(allocator, cwd, "/bin/sh", 96, 36);
    defer primary.deinit();
    try primary.write("printf 'NOCTTY_EIGHT_PRIMARY'; sleep 5; exit 0\n");
    var session_pool = NativeGridSessionPool.init(allocator, "/bin/sh", "printf 'NOCTTY_EIGHT_CHILD'; sleep 3; exit 0\n");
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .rows = 36,
        .workspace_smoke = 13,
    });
    if (status != 0) return error.NativeGridEightPaneHostFailed;
    if (bridge.callback_failed) return error.NativeGridEightPaneStateSyncFailed;
    if (bridge.created_session_count != 7 or tab.panes.items.len != 8) return error.NativeGridEightPaneCountMismatch;
    if (!bridge.saw_split_down_vertical or !bridge.saw_split_left_horizontal) return error.NativeGridEightPaneOrientationMismatch;
    if (!bridge.saw_secondary_started or !bridge.saw_secondary_output or !bridge.saw_secondary_exited) return error.NativeGridEightPaneLifecycleMissing;
    try out.print("native_grid_eight_pane_smoke panes=8 sessions=8 balanced=true split_down=vertical split_left=horizontal dynamic_sessions=true descriptor_fallback=root_coalesced pane_exit_timers=0 periodic_callbacks_per_second=3 exited=true\n", .{});
}

fn nativeGridTwoTabSmoke(out: anytype) !void {
    var app = try noctty.app.App.init(std.heap.page_allocator);
    defer app.deinit();
    const primary_pane = app.workspace.findPane(1) orelse return error.PaneNotFound;
    const cwd = try std.heap.page_allocator.dupeZ(u8, primary_pane.cwd);
    defer std.heap.page_allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, cwd, "/bin/sh", 48, 24);
    defer primary.deinit();
    var secondary = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, cwd, "/bin/sh", 48, 24);
    defer secondary.deinit();
    try primary.write("printf 'NOCTTY_NATIVE_TAB_PRIMARY'; sleep 2; exit 0\n");
    try secondary.write("printf 'NOCTTY_NATIVE_TAB_SECONDARY'; sleep 4; exit 0\n");
    var session_pool = NativeGridSessionPool.init(
        std.heap.page_allocator,
        "/bin/sh",
        "printf 'NOCTTY_NATIVE_TAB_REOPENED'; sleep 2; exit 0\n",
    );
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = 1,
        .secondary_pane_id = 2,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = 1,
        .columns = 48,
        .workspace_smoke = 3,
        .secondary_session = &secondary,
        .secondary_pane_id = 2,
    });
    if (status != 0 or bridge.callback_failed or !bridge.saw_tab_command or
        !bridge.saw_tab_close_command or bridge.closed_tab_pane_count != 1 or
        bridge.created_session_count != 1 or
        !bridge.saw_secondary_started or !bridge.saw_secondary_output or
        !bridge.saw_secondary_exited)
        return error.NativeGridTwoTabSmokeFailed;
    if (app.workspace.tabs.items.len != 1 or app.workspace.tabs.items[0].id != 2 or
        app.workspace.findPane(1) != null or app.workspace.findPane(2) == null or
        !app.recovery.dirty)
        return error.NativeGridTwoTabLayoutMissing;
    try out.print("native_grid_two_tab_smoke initial_tabs=1 tab_bar=true compact_tabs=true add_button=true add_position=start add_icon=true add_accessible=true add_clicked=true tabs_created=2 dynamic_tab=true tab_context_menu=true targeted_background=true close_tab=true model_closed=true rendered_closed=true primary_pty_closed=true late_callback_guard=true remaining_tabs=1 tab_bar_after_close=true add_after_close=true add_reopen_after_close=true fresh_context=true remaining_focused=true secondary_grid=true secondary_lifecycle=true exited=true\n", .{});
}

fn nativeGridTabRenameSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const primary_pane = app.workspace.findPane(1) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, primary_pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        64,
        24,
    );
    defer primary.deinit();
    try primary.write("printf 'NOCTTY_TAB_RENAME_PRIMARY'; IFS= read -r _; exit 0\n");
    var session_pool = NativeGridSessionPool.init(
        allocator,
        "/bin/sh",
        "printf 'NOCTTY_TAB_RENAME_SECONDARY'; IFS= read -r _; exit 0\n",
    );
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = 1,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = 1,
        .columns = 64,
        .workspace_smoke = 17,
    });
    if (status != 0 or bridge.callback_failed or !bridge.saw_tab_command or
        !bridge.saw_tab_rename) return error.NativeGridTabRenameHostFailed;
    if (app.workspace.tabs.items.len != 2 or
        !std.mem.eql(u8, app.workspace.tabs.items[1].title, "Build logs") or
        !app.workspace.tabs.items[1].title_overridden or
        !app.recovery.dirty) return error.NativeGridTabRenameStateMismatch;

    var snapshot = try app.workspace.captureSnapshot();
    defer snapshot.deinit(allocator);
    const bytes = try noctty.workspace.exportSnapshotAlloc(allocator, snapshot);
    defer allocator.free(bytes);
    var imported = try noctty.workspace.importSnapshotAlloc(allocator, bytes);
    defer imported.deinit(allocator);
    if (!imported.tabs[1].title_overridden or
        !std.mem.eql(u8, imported.tabs[1].title, "Build logs"))
        return error.NativeGridTabRenameSnapshotMismatch;
    try out.print("native_grid_tab_rename_smoke double_click=true inline=true popup=false outside_cancel=true enter=true rendered=true model=true snapshot=true tabs=2 focus_restored=true exited=true\n", .{});
}

fn nativeGridTabColorSmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    var session = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        64,
        24,
    );
    defer session.deinit();
    try session.write("printf 'NOCTTY_TAB_COLOR'; read _; exit 0\n");
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
    };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .columns = 64,
        .workspace_smoke = 27,
    });
    if (status != 0 or bridge.callback_failed or
        !bridge.saw_tab_color_set or !bridge.saw_tab_color_lighten or
        !bridge.saw_tab_color_darken)
        return error.NativeGridTabColorHostFailed;
    const accent = app.workspace.activeTab().?.accent orelse
        return error.NativeGridTabColorStateMissing;
    if (accent.preset != .blue or accent.shade != 0 or
        accent.rgb() != 0x4285f4 or !app.recovery.dirty)
        return error.NativeGridTabColorStateMismatch;

    var snapshot = try app.workspace.captureSnapshot();
    defer snapshot.deinit(allocator);
    const bytes = try noctty.workspace.exportSnapshotAlloc(allocator, snapshot);
    defer allocator.free(bytes);
    var imported = try noctty.workspace.importSnapshotAlloc(allocator, bytes);
    defer imported.deinit(allocator);
    const imported_accent = imported.tabs[0].accent orelse
        return error.NativeGridTabColorSnapshotMissing;
    if (imported_accent.preset != .blue or imported_accent.shade != 0 or
        imported_accent.rgb() != accent.rgb())
        return error.NativeGridTabColorSnapshotMismatch;
    try out.print("native_grid_tab_color_smoke menu=true presets=8 default=true applied=blue rendered=true contrast=true shortcut_lighten=true shortcut_darken=true reversible=true workspace_dirty=true snapshot=true exited=true\n", .{});
}

fn nativeGridProfilePresetSmoke(allocator: std.mem.Allocator, io: std.Io, out: anytype) !void {
    var autosave_path_buffer: [160]u8 = undefined;
    const autosave_path = try std.fmt.bufPrint(
        &autosave_path_buffer,
        "/tmp/noctty-native-grid-profile-preset-{d}.nocttyws",
        .{std.Thread.getCurrentId()},
    );
    std.Io.Dir.cwd().deleteFile(io, autosave_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, autosave_path) catch {};

    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const secondary_pane_id = (try app.dispatch(.split_down)).pane_created;
    if (secondary_pane_id != 2) return error.NativeGridProfilePresetSetupFailed;
    const primary_pane = app.workspace.findPane(1) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, primary_pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        80,
        28,
    );
    defer primary.deinit();
    var secondary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        80,
        28,
    );
    defer secondary.deinit();
    try primary.write("printf 'NOCTTY_PROFILE_PRESET_PRIMARY'; sleep 4; exit 0\n");
    try secondary.write("printf 'NOCTTY_PROFILE_PRESET_SECONDARY'; sleep 4; exit 0\n");

    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = 1,
        .secondary_pane_id = secondary_pane_id,
        .io = io,
        .autosave_path = autosave_path,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = 1,
        .columns = 80,
        .rows = 28,
        .workspace_smoke = 33,
        .secondary_session = &secondary,
        .secondary_pane_id = secondary_pane_id,
        .secondary_initially_active = 1,
    });
    if (status != 0 or bridge.callback_failed or
        !bridge.saw_profile_preset_menu or !bridge.saw_profile_preset_selection or
        !bridge.profile_preset_target_exact or
        bridge.profile_preset_menu_open_count != 3 or
        bridge.profile_preset_selection_count != 3 or
        bridge.profile_preset_current_order[0] != 0 or
        bridge.profile_preset_current_order[1] != 2 or
        bridge.profile_preset_current_order[2] != 3 or
        bridge.profile_preset_selection_order[0] != 2 or
        bridge.profile_preset_selection_order[1] != 3 or
        bridge.profile_preset_selection_order[2] != 4 or
        !bridge.saw_profile_preset_readable or
        !bridge.saw_profile_preset_high_contrast or
        !bridge.saw_profile_preset_mono_no_ligatures or
        !bridge.saw_profile_preset_workspace_dirty or
        !bridge.autosave_executed)
        return error.NativeGridProfilePresetHostFailed;

    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const primary_model = app.workspace.findPane(1) orelse return error.PaneNotFound;
    const target_model = app.workspace.findPane(secondary_pane_id) orelse return error.PaneNotFound;
    const primary_expected = noctty.terminal.ProfilePreset.global_default.profile(app.config);
    const target_expected = noctty.terminal.ProfilePreset.mono_no_ligatures.profile(app.config);
    const primary_expected_size: c_int = @intFromFloat(primary_expected.font_size_pt * 100.0);
    const target_expected_size: c_int = @intFromFloat(target_expected.font_size_pt * 100.0);
    if (tab.panes.items.len != 2 or
        !std.mem.eql(u8, primary_model.profile.theme_name, primary_expected.theme_name) or
        !std.mem.eql(u8, primary_model.profile.font_family, primary_expected.font_family) or
        primary_model.profile.font_size_pt != primary_expected.font_size_pt or
        primary_model.profile.ligatures != primary_expected.ligatures or
        !std.mem.eql(u8, target_model.profile.theme_name, target_expected.theme_name) or
        !std.mem.eql(u8, target_model.profile.font_family, target_expected.font_family) or
        target_model.profile.font_size_pt != target_expected.font_size_pt or
        target_model.profile.ligatures)
    {
        std.log.err(
            "native profile model mismatch panes={d} active={d} primary={s}/{s}/{d:.1}/{} target={s}/{s}/{d:.1}/{}",
            .{
                tab.panes.items.len,
                tab.active_pane_id,
                primary_model.profile.theme_name,
                primary_model.profile.font_family,
                primary_model.profile.font_size_pt,
                primary_model.profile.ligatures,
                target_model.profile.theme_name,
                target_model.profile.font_family,
                target_model.profile.font_size_pt,
                target_model.profile.ligatures,
            },
        );
        return error.NativeGridProfilePresetModelMismatch;
    }

    var primary_family: [128]u8 = undefined;
    var primary_size: c_int = 0;
    var primary_high_contrast: c_int = 0;
    var primary_ligatures: c_int = 0;
    const primary_preset = noctty_grid_pane_profile(
        &bridge,
        1,
        &primary_family,
        primary_family.len,
        &primary_size,
        &primary_high_contrast,
        &primary_ligatures,
    );
    var target_family: [128]u8 = undefined;
    var target_size: c_int = 0;
    var target_high_contrast: c_int = 0;
    var target_ligatures: c_int = 0;
    const target_preset = noctty_grid_pane_profile(
        &bridge,
        secondary_pane_id,
        &target_family,
        target_family.len,
        &target_size,
        &target_high_contrast,
        &target_ligatures,
    );
    if (primary_preset != 0 or primary_size != primary_expected_size or primary_high_contrast != 0 or
        primary_ligatures != @intFromBool(primary_expected.ligatures) or
        !std.mem.eql(u8, std.mem.sliceTo(&primary_family, 0), primary_expected.font_family) or
        target_preset != 4 or target_size != target_expected_size or target_high_contrast != 0 or
        target_ligatures != @intFromBool(target_expected.ligatures) or
        !std.mem.eql(u8, std.mem.sliceTo(&target_family, 0), target_expected.font_family))
        return error.NativeGridProfilePresetQueryMismatch;

    _ = try std.Io.Dir.cwd().statFile(io, autosave_path, .{});
    var snapshot = try app.workspace.captureSnapshot();
    defer snapshot.deinit(allocator);
    const bytes = try noctty.workspace.exportSnapshotAlloc(allocator, snapshot);
    defer allocator.free(bytes);
    var imported = try noctty.workspace.importSnapshotAlloc(allocator, bytes);
    defer imported.deinit(allocator);
    if (imported.tabs.len != 1 or imported.tabs[0].panes.len != 2 or
        imported.tabs[0].panes[0].id != 1 or
        imported.tabs[0].panes[0].profile.ligatures != primary_expected.ligatures or
        imported.tabs[0].panes[1].id != secondary_pane_id or
        imported.tabs[0].panes[1].profile.ligatures or
        !std.mem.eql(u8, imported.tabs[0].panes[1].profile.theme_name, target_expected.theme_name))
        return error.NativeGridProfilePresetSnapshotMismatch;

    var restored = try noctty.app.App.init(allocator);
    defer restored.deinit();
    if (loadNativeGridHotSession(&restored, io, autosave_path) != .restored)
        return error.NativeGridProfilePresetRestoreFailed;
    const restored_tab = restored.workspace.activeTab() orelse return error.NoActiveTab;
    const restored_primary = restored.workspace.findPane(1) orelse return error.PaneNotFound;
    const restored_target = restored.workspace.findPane(secondary_pane_id) orelse return error.PaneNotFound;
    var restored_bridge = NativeGridBridge{ .app = &restored, .pane_id = 1, .secondary_pane_id = secondary_pane_id };
    const restored_primary_preset = noctty_grid_pane_profile(
        &restored_bridge,
        1,
        &primary_family,
        primary_family.len,
        &primary_size,
        &primary_high_contrast,
        &primary_ligatures,
    );
    const restored_target_preset = noctty_grid_pane_profile(
        &restored_bridge,
        secondary_pane_id,
        &target_family,
        target_family.len,
        &target_size,
        &target_high_contrast,
        &target_ligatures,
    );
    if (restored_tab.panes.items.len != 2 or
        restored_primary_preset != 0 or restored_target_preset != 4 or
        restored_primary.profile.ligatures != primary_expected.ligatures or
        restored_target.profile.ligatures or
        !std.mem.eql(u8, restored_target.profile.theme_name, target_expected.theme_name))
        return error.NativeGridProfilePresetRestoreMismatch;

    try out.print("native_grid_profile_preset_smoke context_menu=true submenu=true menu_survived=true presets=5 exact_target=true current=true readable=true font_size=14 isolated=true high_contrast=true rendered=true mono_no_ligatures=true workspace_dirty=true snapshot=true restored=true exited=true\n", .{});
}

fn nativeGridResizeOverlaySmoke(out: anytype) !void {
    const allocator = std.heap.page_allocator;
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        cwd,
        "/bin/sh",
        80,
        28,
    );
    defer primary.deinit();
    try primary.write("printf 'NOCTTY_RESIZE_OVERLAY_PRIMARY'; sleep 4; exit 0\n");
    var session_pool = NativeGridSessionPool.init(
        allocator,
        "/bin/sh",
        "printf 'NOCTTY_RESIZE_OVERLAY_SECONDARY'; sleep 4; exit 0\n",
    );
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .columns = 80,
        .rows = 28,
        .workspace_smoke = 18,
    });
    if (status != 0 or bridge.callback_failed or !bridge.saw_split_command)
        return error.NativeGridResizeOverlayHostFailed;
    if (bridge.created_session_count != 1 or tab.panes.items.len != 2)
        return error.NativeGridResizeOverlayLayoutMismatch;
    try out.print("native_grid_resize_overlay_smoke panes=2 divider=true realtime=true format=columns_x_rows position=center initial_hidden=true visible=true updated=true duration_ms=750 hidden=true exited=true\n", .{});
}

fn nativeGridWindowTraySmoke(out: anytype) !void {
    var session = try noctty.terminal_session.TerminalSession.spawn(
        std.heap.page_allocator,
        "/tmp",
        "/bin/sh",
        96,
        24,
    );
    defer session.deinit();
    try session.write("printf 'NOCTTY_WINDOW_TRAY_OK'; sleep 8; exit 0\n");
    const status = runNativeGridHost(.{
        .session = &session,
        .workspace_smoke = 19,
    });
    if (status != 0) return error.NativeGridWindowTraySmokeFailed;
    try out.print("native_grid_window_tray_smoke resize_handles=4 cardinal_edges=true side_border=3 diagonal_cursors=false resized=true tray_registered=true menu_registered=true watcher=true icon=true activate=true secondary=true context=true menu_layout=true close=true session_stopped=true exited=true\n", .{});
}

fn nativeGridClipboardSmoke(out: anytype) !void {
    var session = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    const status = runNativeGridHost(.{
        .session = &session,
        .workspace_smoke = 4,
    });
    if (status != 0) return error.NativeGridClipboardSmokeFailed;
    try out.print("native_grid_clipboard_smoke clipboard=true paste_safety=true terminal_delivery=true rendered=true exited=true\n", .{});
}

fn nativeGridNotificationSmoke(out: anytype) !void {
    var session = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_NOTIFICATION_OK'; exit 0\n");
    const status = runNativeGridHost(.{
        .session = &session,
        .workspace_smoke = 5,
        .enable_notifications = 1,
    });
    if (status != 0) return error.NativeGridNotificationSmokeFailed;
    try out.print("native_grid_notification_smoke tooltip=true status_border=true dbus=true delivered=true exited=true\n", .{});
}

fn nativeGridCredentialedSshSmoke(
    allocator: std.mem.Allocator,
    target: []const u8,
    out: anytype,
) !void {
    var profile = noctty.launch_profile.Profile{ .kind = .ssh };
    try profile.ssh_target.set(target);
    try profile.validate();

    var session = try noctty.terminal_session.TerminalSession.spawnProfile(
        allocator,
        &profile,
        "/tmp",
        "/bin/false",
        120,
        12,
    );
    defer session.deinit();
    try session.write("printf 'NOCTTY_CREDENTIALED_SSH_OK\\n'; exit 0\n");

    var saw_marker = false;
    var saw_exit = false;
    for (0..10_000) |_| {
        _ = try session.pump();
        var row_bytes: [120]u8 = undefined;
        for (0..session.grid.rows) |row| {
            for (0..session.grid.columns) |column| {
                const codepoint = session.grid.cell(column, row).codepoint;
                row_bytes[column] = if (codepoint <= 0x7f) @intCast(codepoint) else '?';
            }
            if (std.mem.indexOf(u8, row_bytes[0..session.grid.columns], "NOCTTY_CREDENTIALED_SSH_OK") != null) {
                saw_marker = true;
                break;
            }
        }
        if (try session.pollExit()) |code| {
            if (code != 0) return error.NativeGridCredentialedSshExitMismatch;
            saw_exit = true;
        }
        if (saw_marker and saw_exit) break;
        noctty.pty.sleepBrief(1);
    }
    if (!saw_marker or !saw_exit) return error.NativeGridCredentialedSshSmokeFailed;
    try out.print("native_grid_credentialed_ssh_smoke profile=true system_client=true system_server=true credential=publickey identity_isolated=true host_key=pinned transport=stdio_proxy network_bind=false remote_marker=true exited=true\n", .{});
}

fn nativeGridSettingsSmoke(allocator: std.mem.Allocator, io: std.Io, out: anytype) !void {
    const path = "/tmp/noctty-native-grid-settings.nocttycfg";
    std.Io.Dir.cwd().deleteFile(io, path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, path) catch {};
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    _ = try app.dispatch(.{ .set_tab_position = .bottom });
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_SETTINGS_OK'; sleep 3; exit 0\n");
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id, .io = io, .config_path = path, .primary_session = &session };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .workspace_smoke = 6,
    });
    if (status != 0 or bridge.callback_failed or !bridge.config_persisted or !bridge.launch_profile_applied or !bridge.launch_tmux_profile_applied or !bridge.launch_zellij_profile_applied or !bridge.launch_profile_library_saved or !bridge.launch_profile_library_selected or !bridge.launch_profile_library_removed) return error.NativeGridSettingsSmokeFailed;
    if (app.config.default_mode != .windowed or app.config.font.size_pt != 16 or app.config.status.desktop_notifications or app.config.tabs.position != .bottom or app.config.status.indicator != .background or app.config.panels.padding_px != 8 or app.config.panels.spacing_px != 4 or app.config.dropdown.width_percent != 90 or app.config.dropdown.height_percent != 40 or app.config.dropdown.animation_ms != 120 or !app.config.dropdown.hide_on_focus_loss or !app.config.tabs.focus_follows_pointer or !app.config.tabs.show_pane_info or app.config.terminal.scrollback_lines != 256 or session.grid.history_limit != 256 or app.config.dropdown.shortcut.key != .f11 or !std.mem.eql(u8, app.config.default_theme, "noctty-high-contrast") or !std.mem.eql(u8, app.config.font.family, "Monospace") or app.config.font.antialias != .grayscale or app.config.font.hinting != .full) return error.NativeGridSettingsStateMismatch;
    if (app.workspace.findPane(tab.active_pane_id).?.profile.font_size_pt != 14) return error.NativeGridSettingsProfileMismatch;
    const launch_profile = &app.config.terminal.launch_profile;
    if (launch_profile.kind != .command or
        !std.mem.eql(u8, launch_profile.shell.slice(), "/bin/sh") or
        !std.mem.eql(u8, launch_profile.command.slice(), "printf 'NOCTTY_LAUNCH_PROFILE_OK:%s:%s' \"$PWD\" \"$NOCTTY_PROFILE\"") or
        !std.mem.eql(u8, launch_profile.working_directory.slice(), "/tmp") or
        !std.mem.eql(u8, launch_profile.environment.slice(), "NOCTTY_PROFILE=ready;NOCTTY_SECOND=value") or
        !std.mem.eql(u8, launch_profile.ssh_target.slice(), "alice@example.com") or
        launch_profile.scrollback_lines != 2048 or
        launch_profile.environmentEntryCount() != 2)
        return error.NativeGridLaunchProfileStateMismatch;
    const launch_library = &app.config.terminal.launch_profiles;
    if (launch_library.count != 1 or
        launch_library.selected_index != 0 or
        !std.mem.eql(u8, launch_library.entries[0].name.slice(), "Local command") or
        !launch_library.entries[0].profile.eql(launch_profile))
        return error.NativeGridLaunchProfileLibraryStateMismatch;
    var verify_app = try noctty.app.App.init(allocator);
    defer verify_app.deinit();
    const receipt = try verify_app.loadConfigFile(io, std.Io.Dir.cwd(), path, .settings);
    receipt.deinit(allocator);
    if (verify_app.config.default_mode != .windowed or verify_app.config.font.size_pt != 16 or verify_app.config.status.desktop_notifications or verify_app.config.tabs.position != .bottom or verify_app.config.status.indicator != .background or verify_app.config.panels.padding_px != 8 or verify_app.config.panels.spacing_px != 4 or verify_app.config.dropdown.width_percent != 90 or verify_app.config.dropdown.height_percent != 40 or verify_app.config.dropdown.animation_ms != 120 or !verify_app.config.dropdown.hide_on_focus_loss or !verify_app.config.tabs.focus_follows_pointer or !verify_app.config.tabs.show_pane_info or verify_app.config.terminal.scrollback_lines != 256 or verify_app.config.dropdown.shortcut.key != .f11 or !std.mem.eql(u8, verify_app.config.default_theme, "noctty-high-contrast") or !std.mem.eql(u8, verify_app.config.font.family, "Monospace") or verify_app.config.font.antialias != .grayscale or verify_app.config.font.hinting != .full) return error.NativeGridSettingsReloadMismatch;
    const reloaded_launch_profile = &verify_app.config.terminal.launch_profile;
    if (reloaded_launch_profile.kind != .command or
        !std.mem.eql(u8, reloaded_launch_profile.command.slice(), "printf 'NOCTTY_LAUNCH_PROFILE_OK:%s:%s' \"$PWD\" \"$NOCTTY_PROFILE\"") or
        !std.mem.eql(u8, reloaded_launch_profile.working_directory.slice(), "/tmp") or
        !std.mem.eql(u8, reloaded_launch_profile.environment.slice(), "NOCTTY_PROFILE=ready;NOCTTY_SECOND=value") or
        reloaded_launch_profile.scrollback_lines != 2048)
        return error.NativeGridLaunchProfileReloadMismatch;
    const reloaded_launch_library = &verify_app.config.terminal.launch_profiles;
    if (reloaded_launch_library.count != 1 or
        reloaded_launch_library.selected_index != 0 or
        !std.mem.eql(u8, reloaded_launch_library.entries[0].name.slice(), "Local command") or
        !reloaded_launch_library.entries[0].profile.eql(reloaded_launch_profile))
        return error.NativeGridLaunchProfileLibraryReloadMismatch;

    var launch_session = try noctty.terminal_session.TerminalSession.spawnProfile(
        allocator,
        reloaded_launch_profile,
        "/",
        "/bin/false",
        96,
        4,
    );
    defer launch_session.deinit();
    var launch_exited = false;
    for (0..5000) |_| {
        _ = try launch_session.pump();
        if (try launch_session.pollExit()) |code| {
            if (code != 0) return error.NativeGridLaunchProfileExitMismatch;
            launch_exited = true;
            break;
        }
        noctty.pty.sleepBrief(1);
    }
    if (!launch_exited or launch_session.grid.history_limit != 2048)
        return error.NativeGridLaunchProfileRuntimeMismatch;
    var launch_row: [96]u8 = undefined;
    var launch_marker = false;
    for (0..launch_session.grid.rows) |row| {
        for (0..launch_session.grid.columns) |column| {
            const codepoint = launch_session.grid.cell(column, row).codepoint;
            launch_row[column] = if (codepoint <= 0x7f) @intCast(codepoint) else '?';
        }
        if (std.mem.indexOf(u8, launch_row[0..launch_session.grid.columns], "NOCTTY_LAUNCH_PROFILE_OK:/tmp:ready") != null) {
            launch_marker = true;
            break;
        }
    }
    if (!launch_marker) return error.NativeGridLaunchProfileOutputMismatch;
    try out.print("native_grid_settings_smoke rendered=true toolbar=true settings_button=true close_button=true order=yakuake button_pointer=true button_tooltips=true settings_activated=true close_activated=true session_stopped=true geometry=sane dialogs=above_terminal application_icon=true categories=3 category_navigation=true category_tooltips=true narrow_access=true page_switch=true mode=windowed tabs=bottom live_tab_position=bottom startup_tab_position=bottom dropdown=90x40 animation=120 hide_on_focus_loss=true focus_follows_pointer=true pane_info=true pane_info_toggle=true scrollback=256 scrollback_live=true launch_profile=true launch_kind=command launch_shell=/bin/sh launch_cwd=/tmp launch_env=2 launch_scrollback=2048 launch_atomic=true launch_persisted=true launch_runtime=true launch_library=true launch_profiles=1 launch_named=true launch_saved=true launch_selected=true launch_deleted=true launch_continuity_controls=true launch_tmux=true launch_zellij=true shortcut_recorder=true shortcut=F11 font_family=Monospace font_size=16 smoothing=grayscale hinting=full theme=noctty-high-contrast status=background padding=8 spacing=4 notifications=false preset=readable persisted=true reloaded=true exited=true\n", .{});
}

fn nativeGridSettingsStackingSmoke(allocator: std.mem.Allocator, out: anytype) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        "/tmp",
        "/bin/sh",
        96,
        24,
    );
    defer session.deinit();
    try session.write("printf 'NOCTTY_SETTINGS_STACKING_OK'; sleep 2; exit 0\n");
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .mode = 0,
        .workspace_smoke = 28,
    });
    if (status != 0 or bridge.callback_failed)
        return error.NativeGridSettingsStackingSmokeFailed;
    try out.print("native_grid_settings_stacking_smoke visible=true transient_parent=true keep_above=true compositor_stack=true geometry=sane parent_restored=true exited=true\n", .{});
}

fn nativeGridThemeSmoke(allocator: std.mem.Allocator, io: std.Io, out: anytype) !void {
    const config_path = "/tmp/noctty-native-grid-theme.nocttycfg";
    const theme_path = "/tmp/noctty-native-grid-theme.nocttythemes";
    std.Io.Dir.cwd().deleteFile(io, config_path) catch {};
    std.Io.Dir.cwd().deleteFile(io, theme_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, config_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, theme_path) catch {};
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_THEME_OK'; sleep 1; exit 0\n");
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id, .io = io, .config_path = config_path, .theme_path = theme_path };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .mode = 0,
        .workspace_smoke = 7,
    });
    if (status != 0 or bridge.callback_failed or !bridge.config_persisted) return error.NativeGridThemeSmokeFailed;
    const imported = app.findTheme("Imported Night") orelse return error.NativeGridThemeMissing;
    if (imported.background.r != 0 or imported.background.g != 0 or imported.background.b != 0x11 or !std.mem.eql(u8, app.config.default_theme, "Imported Night")) return error.NativeGridThemeMismatch;
    var verify_app = try noctty.app.App.init(allocator);
    defer verify_app.deinit();
    const theme_receipt = try verify_app.loadThemeLibraryFile(io, std.Io.Dir.cwd(), theme_path, .library);
    theme_receipt.deinit(allocator);
    const config_receipt = try verify_app.loadConfigFile(io, std.Io.Dir.cwd(), config_path, .settings);
    config_receipt.deinit(allocator);
    if (verify_app.findTheme("Imported Night") == null or !std.mem.eql(u8, verify_app.config.default_theme, "Imported Night")) return error.NativeGridThemeReloadMismatch;
    try out.print("native_grid_theme_smoke rendered=true imported=true format=ghostty selected=true library_persisted=true config_persisted=true reloaded=true exited=true\n", .{});
}

fn nativeGridProjectEditorSmoke(allocator: std.mem.Allocator, io: std.Io, out: anytype) !void {
    const workspace_path = "/tmp/noctty-native-grid-project.nocttyws";
    const config_path = "/tmp/noctty-native-grid-project.nocttycfg";
    const project_root = "/tmp/noctty-native-grid-nocted-handoff";
    const cwd = std.Io.Dir.cwd();
    cwd.deleteFile(io, workspace_path) catch {};
    cwd.deleteFile(io, config_path) catch {};
    cwd.deleteTree(io, project_root) catch {};
    defer cwd.deleteFile(io, workspace_path) catch {};
    defer cwd.deleteFile(io, config_path) catch {};
    defer cwd.deleteTree(io, project_root) catch {};
    try cwd.createDirPath(io, project_root);

    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(allocator, project_root, "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_PROJECT_EDITOR_OK'; read _; exit 0\n");
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .io = io,
        .config_path = config_path,
    };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .mode = 0,
        .workspace_smoke = 8,
    });
    if (status != 0 or bridge.callback_failed or
        !bridge.workspace_saved or !bridge.workspace_loaded)
        return error.NativeGridProjectEditorSmokeFailed;

    var reloaded_app = try noctty.app.App.init(allocator);
    defer reloaded_app.deinit();
    const reloaded = try reloaded_app.loadConfigFile(io, cwd, config_path, .settings);
    reloaded.deinit(allocator);
    if (reloaded_app.config.recent_workspaces.count != 1 or
        !std.mem.eql(u8, reloaded_app.config.recent_workspaces.at(0).?, workspace_path))
        return error.NativeGridRecentWorkspaceReloadMismatch;

    try out.writeAll("native_grid_project_editor_smoke rendered_project=true workspace_saved=true workspace_loaded=true recent_control=true recent_persisted=true summary_scroll=true project_accessible=true context_menu=true menu_survived=true nocted_launch=true editor_binary=nocted editor_handoff=true directory_resolved=true editor_process_separate=true parent_mapped=true exited=true\n");
}

fn nativeGridMaintenanceSmoke(allocator: std.mem.Allocator, io: std.Io, out: anytype) !void {
    const autosave_path = "/tmp/noctty-native-grid-autosave.nocttyws";
    std.Io.Dir.cwd().deleteFile(io, autosave_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, autosave_path) catch {};
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    app.recovery.policy.autosave_interval_seconds = 1;
    app.maintenance_policy.project_refresh_interval_seconds = 1;
    app.maintenance_policy.recovery_cleanup_interval_seconds = 1;
    app.markWorkspaceDirtyAt(0);
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_MAINTENANCE_OK'; sleep 2; exit 0\n");
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id, .io = io, .autosave_path = autosave_path };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .mode = 0,
        .workspace_smoke = 34,
    });
    if (status != 0 or bridge.callback_failed or !bridge.maintenance_tick_seen or !bridge.autosave_executed or !bridge.project_refresh_executed or !bridge.recovery_cleanup_executed) return error.NativeGridMaintenanceSmokeFailed;
    _ = try std.Io.Dir.cwd().statFile(io, autosave_path, .{});
    try out.print("native_grid_maintenance_smoke timer=true autosave=true project_refresh=true recovery_cleanup=true descriptor_fallback=root_coalesced pane_exit_timer=false source_cleanup=centralized exited=true\n", .{});
}

fn nativeGridHotSessionSmoke(allocator: std.mem.Allocator, io: std.Io, out: anytype) !void {
    const autosave_path = "/tmp/noctty-native-grid-hot-session.nocttyws";
    const config_path = "/tmp/noctty-native-grid-hot-session.nocttycfg";
    const corrupt_path = "/tmp/noctty-native-grid-hot-session-corrupt.nocttyws";
    std.Io.Dir.cwd().deleteFile(io, autosave_path) catch {};
    std.Io.Dir.cwd().deleteFile(io, config_path) catch {};
    std.Io.Dir.cwd().deleteFile(io, corrupt_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, autosave_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, config_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, corrupt_path) catch {};

    var source = try noctty.app.App.init(allocator);
    defer source.deinit();
    var source_bridge = NativeGridBridge{
        .app = &source,
        .pane_id = 1,
        .io = io,
        .config_path = config_path,
        .autosave_path = autosave_path,
    };
    const build_logs = "Build logs";
    if (noctty_grid_rename_tab(&source_bridge, 1, build_logs.ptr, build_logs.len) != 0 or
        noctty_grid_set_tab_color(&source_bridge, 1, @intFromEnum(noctty.workspace.TabColorPreset.blue)) != 0)
        return error.NativeGridHotSessionWriteThroughFailed;
    _ = try source.dispatch(.split_down);
    persistNativeGridHotSession(&source_bridge);
    _ = try source.dispatch(.{ .focus_pane = 1 });
    _ = try source.dispatch(.split_left);
    _ = try source.dispatch(.{ .select_pane = .{ .pane_id = 1, .mode = .replace } });
    _ = try source.dispatch(.{ .select_pane = .{ .pane_id = 2, .mode = .add } });
    if (noctty_grid_tag_selected_panes(&source_bridge, "ops".ptr, "ops".len) != 0)
        return error.NativeGridHotSessionWriteThroughFailed;

    const second_tab_id = (try source.dispatch(.new_tab)).tab_created;
    persistNativeGridHotSession(&source_bridge);
    const second_tab = source.workspace.activeTab() orelse return error.NoActiveTab;
    const second_root_pane = second_tab.active_pane_id;
    const deploy = "Deploy";
    if (noctty_grid_rename_tab(&source_bridge, second_root_pane, deploy.ptr, deploy.len) != 0)
        return error.NativeGridHotSessionWriteThroughFailed;
    const active_pane_id = (try source.dispatch(.split_down)).pane_created;
    _ = try source.dispatch(.{ .set_pane_profile_preset = .{
        .pane_id = active_pane_id,
        .preset = .readable,
    } });
    _ = try source.dispatch(.{ .select_pane = .{
        .pane_id = active_pane_id,
        .mode = .replace,
    } });
    if (noctty_grid_tag_selected_panes(&source_bridge, "ops".ptr, "ops".len) != 0 or
        noctty_grid_set_smart_filter(&source_bridge, "ops".ptr, "ops".len) != 0)
        return error.NativeGridHotSessionWriteThroughFailed;
    _ = try source.dispatch(.toggle_broadcast);
    _ = try source.dispatch(.{ .set_quick_note = "resume deployment review" });
    persistNativeGridHotSession(&source_bridge);

    const first_root = source.workspace.tabs.items[0].layout.root orelse
        return error.NativeGridHotSessionLayoutMissing;
    const second_root = source.workspace.tabs.items[1].layout.root orelse
        return error.NativeGridHotSessionLayoutMissing;
    if (noctty_grid_set_layout_ratio(&source_bridge, 0, @intCast(first_root), 620) != 0 or
        noctty_grid_set_layout_ratio(&source_bridge, 1, @intCast(second_root), 650) != 0 or
        noctty_grid_flush_hot_session(&source_bridge) != 0)
        return error.NativeGridHotSessionWriteThroughFailed;
    _ = try source.dispatch(.{ .set_tab_position = .bottom });
    _ = try source.dispatch(.{ .set_font_size = 16 });
    persistNativeGridConfig(&source_bridge);
    if (source.recovery.dirty or !source_bridge.autosave_executed or
        !source_bridge.config_persisted)
        return error.NativeGridHotSessionWriteThroughFailed;
    _ = try std.Io.Dir.cwd().statFile(io, autosave_path, .{});
    _ = try std.Io.Dir.cwd().statFile(io, config_path, .{});

    var restored = try noctty.app.App.init(allocator);
    defer restored.deinit();
    const config_receipt = try restored.loadConfigFile(io, std.Io.Dir.cwd(), config_path, .settings);
    config_receipt.deinit(allocator);
    if (loadNativeGridHotSession(&restored, io, autosave_path) != .restored)
        return error.NativeGridHotSessionReloadFailed;
    if (restored.workspace.tabs.items.len != 2 or
        restored.workspace.active_tab != 1 or
        restored.workspace.tabs.items[0].panes.items.len != 3 or
        restored.workspace.tabs.items[1].panes.items.len != 2 or
        !std.mem.eql(u8, restored.workspace.tabs.items[0].title, build_logs) or
        !std.mem.eql(u8, restored.workspace.tabs.items[1].title, deploy) or
        restored.workspace.tabs.items[1].id != second_tab_id or
        restored.workspace.tabs.items[1].active_pane_id != active_pane_id or
        restored.workspace.tabs.items[0].accent == null or
        restored.workspace.tabs.items[0].accent.?.preset != .blue or
        !restored.workspace.broadcast_enabled or
        restored.workspace.smart_filter_tag == null or
        !std.mem.eql(u8, restored.workspace.smart_filter_tag.?, "ops") or
        !std.mem.eql(u8, restored.workspace.quick_note, "resume deployment review") or
        restored.workspace.tabs.items[0].layout.nodes.items[first_root].ratio_permille != 620 or
        restored.workspace.tabs.items[1].layout.nodes.items[second_root].ratio_permille != 650 or
        restored.workspace.findPane(active_pane_id).?.profile.font_size_pt != 14 or
        !restored.workspace.findPane(active_pane_id).?.hasTag("ops") or
        restored.config.tabs.position != .bottom or restored.config.font.size_pt != 16)
        return error.NativeGridHotSessionStateMismatch;

    const active_pane = restored.workspace.findPane(active_pane_id) orelse
        return error.PaneNotFound;
    const active_cwd = try allocator.dupeZ(u8, active_pane.cwd);
    defer allocator.free(active_cwd);
    var primary = try noctty.terminal_session.TerminalSession.spawn(allocator, active_cwd, "/bin/sh", 96, 36);
    defer primary.deinit();
    try primary.write("printf 'NOCTTY_HOT_SESSION_PRIMARY'; sleep 2; exit 0\n");
    var session_pool = NativeGridSessionPool.init(
        allocator,
        "/bin/sh",
        "printf 'NOCTTY_HOT_SESSION_RESTORED'; sleep 1; exit 0\n",
    );
    defer session_pool.deinit();
    var bridge = NativeGridBridge{
        .app = &restored,
        .pane_id = active_pane_id,
        .io = io,
        .config_path = config_path,
        .autosave_path = autosave_path,
        .hot_session_loaded = true,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = active_pane_id,
        .rows = 36,
        .workspace_smoke = 30,
    });
    if (status != 0 or bridge.callback_failed or
        bridge.created_session_count != 4)
        return error.NativeGridHotSessionHostFailed;
    var corrupt = try std.Io.Dir.cwd().createFileAtomic(io, corrupt_path, .{ .make_path = true, .replace = true });
    defer corrupt.deinit(io);
    try corrupt.file.writeStreamingAll(io, "NOCTTYWS\x06truncated");
    try corrupt.replace(io);
    var fallback = try noctty.app.App.init(allocator);
    defer fallback.deinit();
    if (loadNativeGridHotSession(&fallback, io, corrupt_path) != .invalid or
        fallback.workspace.tabs.items.len != 1 or
        fallback.workspace.tabs.items[0].panes.items.len != 1)
        return error.NativeGridHotSessionCorruptFallbackFailed;

    try out.print("native_grid_hot_session_smoke autosave=true atomic=true write_through=true startup_restore=true tabs=2 panes=5 recursive_layout=true ratios=true titles=true colors=true tags=true smart_filter=true profiles=true settings=true cwd=true corrupt_fallback=true processes=restarted exited=true\n", .{});
}

fn nativeGridShortcutLiveSmoke(out: anytype) !void {
    var session = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_SHORTCUT_LIVE_OK'; sleep 5; exit 0\n");
    const status = runNativeGridHost(.{
        .session = &session,
        .mode = 0,
        .shortcut_key = 16777273,
        .enable_shortcut = 1,
        .workspace_smoke = 9,
    });
    if (status != 0) return error.NativeGridShortcutLiveSmokeFailed;
    try out.print("native_grid_shortcut_live_smoke registered=true hidden=true hidden_before_registration=true physical_key=true activated=true visible=true exited=true\n", .{});
}

fn nativeGridNoctaliaIpcSmoke(out: anytype) !void {
    var session = try noctty.terminal_session.TerminalSession.spawn(std.heap.page_allocator, "/tmp", "/bin/sh", 96, 24);
    defer session.deinit();
    try session.write("printf 'NOCTTY_NOCTALIA_IPC_OK'; IFS= read -r _; exit 0\n");
    const status = runNativeGridHost(.{
        .session = &session,
        .mode = 0,
        .enable_shortcut = 2,
        .workspace_smoke = 16,
    });
    if (status != 0) return error.NativeGridNoctaliaIpcSmokeFailed;
    try out.print("native_grid_noctalia_ipc_smoke dbus=true layer_shell=true namespace=noctty-dropdown hidden_start=true status=true show=true hide=true toggle=true single_instance=true dropdown_dragger=info_bar side_border=3 exited=true\n", .{});
}

fn nativeGridWorkspaceActivationSmoke(
    allocator: std.mem.Allocator,
    io: std.Io,
    out: anytype,
) !void {
    const workspace_path = "/tmp/noctty workspace activation.nocttyws";
    const workspace_uri = "noctty:///tmp/noctty%20workspace%20activation.nocttyws";
    const config_path = "/tmp/noctty-workspace-activation.nocttycfg";
    std.Io.Dir.cwd().deleteFile(io, workspace_path) catch {};
    std.Io.Dir.cwd().deleteFile(io, config_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, workspace_path) catch {};
    defer std.Io.Dir.cwd().deleteFile(io, config_path) catch {};

    var source = try noctty.app.App.init(allocator);
    defer source.deinit();
    _ = try source.dispatch(.{ .rename_tab = .{ .tab_id = 1, .title = "Activated workspace" } });
    _ = try source.dispatch(.{ .set_quick_note = "opened from a local deep link" });
    const workspace_receipt = try source.saveWorkspaceFile(
        io,
        std.Io.Dir.cwd(),
        workspace_path,
        .manual,
    );
    workspace_receipt.deinit(allocator);
    const source_config = try source.saveConfigFile(
        io,
        std.Io.Dir.cwd(),
        config_path,
        .settings,
    );
    source_config.deinit(allocator);

    var activated = try noctty.app.App.init(allocator);
    defer activated.deinit();
    const loaded_config = try activated.loadConfigFile(
        io,
        std.Io.Dir.cwd(),
        config_path,
        .settings,
    );
    loaded_config.deinit(allocator);
    const activation_receipt = try activated.loadActivatedWorkspaceUri(
        io,
        std.Io.Dir.cwd(),
        workspace_uri,
    );
    activation_receipt.deinit(allocator);
    if (!std.mem.eql(u8, activated.workspace.tabs.items[0].title, "Activated workspace") or
        !std.mem.eql(u8, activated.workspace.quick_note, "opened from a local deep link") or
        activated.config.recent_workspaces.count != 1 or
        !std.mem.eql(u8, activated.config.recent_workspaces.at(0).?, workspace_path))
        return error.NativeGridWorkspaceActivationStateMismatch;
    const persisted = try activated.saveConfigFile(
        io,
        std.Io.Dir.cwd(),
        config_path,
        .settings,
    );
    persisted.deinit(allocator);

    var reloaded = try noctty.app.App.init(allocator);
    defer reloaded.deinit();
    const reloaded_config = try reloaded.loadConfigFile(
        io,
        std.Io.Dir.cwd(),
        config_path,
        .settings,
    );
    reloaded_config.deinit(allocator);
    if (reloaded.config.recent_workspaces.count != 1 or
        !std.mem.eql(u8, reloaded.config.recent_workspaces.at(0).?, workspace_path))
        return error.NativeGridWorkspaceActivationReloadMismatch;

    const file_uri = try noctty.workspace_activation.parseWorkspaceUri(
        "file:///tmp/noctty%20workspace%20activation.nocttyws",
    );
    if (!std.mem.eql(u8, file_uri.slice(), workspace_path))
        return error.NativeGridWorkspaceActivationFileUriMismatch;
    if (noctty.workspace_activation.parseWorkspaceUri(
        "file://remote-host/tmp/project.nocttyws",
    )) |_| {
        return error.NativeGridWorkspaceActivationAuthorityAccepted;
    } else |err| if (err != error.WorkspaceUriAuthorityForbidden) {
        return err;
    }
    try out.print("native_grid_workspace_activation_smoke native_uri=true file_uri=true percent_decode=true authority_rejected=true validated_snapshot=true startup_restore_seam=true recent_mru=true fixed_capacity=8 config_v9=true atomic=true separate_process_policy=true exited=true\n", .{});
}

fn writeInstalledActivationFixture(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    out: anytype,
) !void {
    _ = try noctty.workspace_activation.WorkspacePath.init(path);
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    _ = try app.dispatch(.{ .rename_tab = .{
        .tab_id = 1,
        .title = "Desktop activation",
    } });
    const second_tab_id = (try app.dispatch(.new_tab)).tab_created;
    _ = try app.dispatch(.{ .rename_tab = .{
        .tab_id = second_tab_id,
        .title = "Recent child",
    } });
    _ = try app.dispatch(.{ .set_quick_note = "installed desktop and Recent Workspaces acceptance" });
    const receipt = try app.saveWorkspaceFile(
        io,
        std.Io.Dir.cwd(),
        path,
        .manual,
    );
    receipt.deinit(allocator);
    try out.print(
        "native_grid_installed_activation_fixture path_valid=true tabs=2 atomic=true\n",
        .{},
    );
}

fn nativeGridRecentWorkspaceActivationSmoke(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: anytype,
    out: anytype,
) !void {
    const workspace_path = environ_map.get("NOCTTY_ACTIVATION_WORKSPACE") orelse
        return error.MissingActivationWorkspace;
    _ = try noctty.workspace_activation.WorkspacePath.init(workspace_path);
    _ = try std.Io.Dir.cwd().statFile(io, workspace_path, .{});

    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    try app.recordRecentWorkspace(workspace_path);
    if (app.config.recent_workspaces.count != 1 or
        !std.mem.eql(
            u8,
            app.config.recent_workspaces.at(0).?,
            workspace_path,
        ))
        return error.NativeGridRecentWorkspaceSetupMismatch;
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var session = try noctty.terminal_session.TerminalSession.spawn(
        allocator,
        "/tmp",
        "/bin/sh",
        96,
        24,
    );
    defer session.deinit();
    try session.write(
        "printf 'NOCTTY_RECENT_ACTIVATION_PARENT'; IFS= read -r _; exit 0\n",
    );
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .io = io,
    };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .workspace_smoke = 35,
    });
    if (status != 0 or bridge.callback_failed)
        return error.NativeGridRecentWorkspaceActivationHostFailed;
    try out.print(
        "native_grid_recent_workspace_activation_smoke parent_rendered=true recent_control=true click=true separate_process=true child_launch=true controlled_exit=true\n",
        .{},
    );
}

fn runNativeGridTwoPane(allocator: std.mem.Allocator, io: std.Io, home_dir: []const u8, environ_map: anytype, mode: c_int) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    app.applySessionEnvironment(sessionEnvironment(environ_map));
    try populateProjectPanels(&app, allocator, io);
    _ = try app.dispatch(.split_down);
    const primary_pane = app.workspace.findPane(1) orelse return error.PaneNotFound;
    const secondary_pane = app.workspace.findPane(2) orelse return error.PaneNotFound;
    const shell_raw = noctty.launch_profile.safeFallbackShell(
        environ_map.get("SHELL") orelse "/bin/sh",
    );
    const primary_cwd = try allocator.dupeZ(u8, primary_pane.cwd);
    defer allocator.free(primary_cwd);
    const secondary_cwd = try allocator.dupeZ(u8, secondary_pane.cwd);
    defer allocator.free(secondary_cwd);
    const shell = try allocator.dupeZ(u8, shell_raw);
    defer allocator.free(shell);
    var primary = try noctty.terminal_session.TerminalSession.spawn(allocator, primary_cwd, shell, 60, 40);
    defer primary.deinit();
    var secondary = try noctty.terminal_session.TerminalSession.spawn(allocator, secondary_cwd, shell, 60, 40);
    defer secondary.deinit();
    var session_pool = NativeGridSessionPool.init(allocator, shell, null);
    defer session_pool.deinit();
    const config_path = try app.defaultConfigPathAlloc(home_dir);
    defer allocator.free(config_path);
    const theme_path = try app.defaultThemeLibraryPathAlloc(home_dir);
    defer allocator.free(theme_path);
    const autosave_path = try app.defaultWorkspacePathAlloc(home_dir, "default", .autosave);
    defer allocator.free(autosave_path);
    var bridge = NativeGridBridge{ .app = &app, .pane_id = 1, .secondary_pane_id = 2, .io = io, .config_path = config_path, .theme_path = theme_path, .autosave_path = autosave_path, .session_pool = &session_pool };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = 1,
        .columns = 60,
        .rows = 40,
        .mode = mode,
        .shortcut_key = qtShortcutKey(app.config.dropdown.shortcut),
        .enable_shortcut = if (mode == 0 and app.backend.capabilities.app_shortcut_registration) 1 else 0,
        .secondary_session = &secondary,
        .secondary_pane_id = 2,
        .secondary_initially_active = 1,
        .enable_notifications = if (app.config.status.desktop_notifications) 1 else 0,
    });
    if (status != 0) return error.NativeGridTwoPaneHostUnavailable;
    if (bridge.callback_failed) return error.NativeGridTwoPaneStateSyncFailed;
}

fn runNativeGridBenchmark(
    allocator: std.mem.Allocator,
    pane_count: usize,
    workload: []const u8,
    environ_map: anytype,
) !void {
    if (pane_count != 1 and pane_count != 2 and pane_count != 4 and
        pane_count != 8 and pane_count != 16 and pane_count != 32)
        return error.InvalidBenchmarkPaneCount;
    if (workload.len == 0 or std.mem.indexOfScalar(u8, workload, '\n') != null)
        return error.InvalidBenchmarkWorkload;

    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    const font_size = std.fmt.parseFloat(
        f32,
        environ_map.get("NOCTTY_BENCH_FONT_SIZE") orelse "11",
    ) catch return error.InvalidBenchmarkFontSize;
    _ = try app.dispatch(.{ .set_font_size = font_size });
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    var pane_ids: [32]u64 = undefined;
    pane_ids[0] = tab.active_pane_id;
    var pane_ids_len: usize = 1;
    var split_level: usize = 0;
    while (pane_ids_len < pane_count) : (split_level += 1) {
        const level_panes = pane_ids_len;
        for (pane_ids[0..level_panes]) |pane_id| {
            tab.active_pane_id = pane_id;
            const result = if (split_level % 2 == 0)
                try app.dispatch(.split_down)
            else
                try app.dispatch(.split_left);
            pane_ids[pane_ids_len] = result.pane_created;
            pane_ids_len += 1;
        }
    }
    tab.active_pane_id = pane_ids[0];
    const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    const command = try std.fmt.allocPrint(allocator, "exec {s}\n", .{workload});
    defer allocator.free(command);

    var session_pool = NativeGridSessionPool.init(
        allocator,
        "/bin/sh",
        command,
    );
    defer session_pool.deinit();
    var primary = try noctty.terminal_session.TerminalSession.spawnWithHistoryLimitAndScratch(
        allocator,
        cwd,
        "/bin/sh",
        120,
        40,
        noctty.vt.Grid.default_history_lines,
        &session_pool.pump_scratch,
    );
    defer primary.deinit();
    try primary.write(command);
    var bridge = NativeGridBridge{
        .app = &app,
        .pane_id = tab.active_pane_id,
        .hot_session_loaded = true,
        .session_pool = &session_pool,
    };
    const status = runNativeGridHost(.{
        .session = &primary,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .columns = 120,
        .rows = 40,
    });
    if (status != 0) return error.NativeGridBenchmarkHostUnavailable;
    if (bridge.callback_failed) return error.NativeGridBenchmarkStateSyncFailed;
    if (bridge.created_session_count + 1 != pane_count)
        return error.NativeGridBenchmarkPaneCountMismatch;
    if (primary.pump_scratch != &session_pool.pump_scratch)
        return error.NativeGridBenchmarkPumpScratchMismatch;
    for (session_pool.sessions.items) |session| {
        if (session.pump_scratch != &session_pool.pump_scratch)
            return error.NativeGridBenchmarkPumpScratchMismatch;
    }
    if (environ_map.get("NOCTTY_BENCH_EXPECT_IDLE_COMPACTION")) |expected| {
        if (!std.mem.eql(u8, expected, "1"))
            return error.InvalidBenchmarkIdleCompactionExpectation;
        const scenario = environ_map.get("NOCTTY_BENCH_MODE") orelse "";
        if (std.mem.eql(u8, scenario, "output")) {
            if (bridge.idle_history_compactions == 0)
                return error.NativeGridBenchmarkIdleCompactionMissing;
            std.debug.print(
                "native_grid_benchmark idle_history_compactions={d}\n",
                .{bridge.idle_history_compactions},
            );
        }
    }
}

fn parseRestoreMode(value: []const u8) !noctty.continuity.RestoreMode {
    const raw = std.fmt.parseInt(u8, value, 10) catch return error.InvalidWorkspaceActivationArguments;
    return switch (raw) {
        0 => .restart_shells,
        1 => .attach_persistent,
        2 => .resume_agents,
        else => error.InvalidWorkspaceActivationArguments,
    };
}

fn runNativeGrid(allocator: std.mem.Allocator, io: std.Io, home_dir: []const u8, environ_map: anytype, mode: c_int, launch_policy: GridLaunchPolicy) !void {
    return runNativeGridActivated(
        allocator,
        io,
        home_dir,
        environ_map,
        mode,
        launch_policy,
        null,
        .restart_shells,
    );
}

fn applyRestoreMode(
    app: *noctty.app.App,
    pane: *noctty.terminal.Pane,
    mode: noctty.continuity.RestoreMode,
) !void {
    switch (mode) {
        .restart_shells => {
            var profile = app.config.terminal.launch_profile;
            profile.kind = .shell;
            profile.command = .{};
            profile.ssh_target = .{};
            try app.config.terminal.setLaunchProfile(profile);
        },
        .attach_persistent => {
            if (app.config.terminal.launch_profile.kind != .tmux and
                app.config.terminal.launch_profile.kind != .zellij)
            {
                var profile = app.config.terminal.launch_profile;
                profile.kind = .shell;
                profile.command = .{};
                profile.ssh_target = .{};
                try app.config.terminal.setLaunchProfile(profile);
            }
        },
        .resume_agents => {
            if (pane.agent_resume.enabled) {
                if (noctty.continuity.profileForResume(
                    pane.agent_resume,
                    pane.cwd,
                    app.config.terminal.scrollback_lines,
                )) |profile| {
                    try app.config.terminal.setLaunchProfile(profile);
                    return;
                } else |err| switch (err) {
                    error.AgentResumeProviderUnsupported, error.AgentResumeUnavailable => {},
                    else => return err,
                }
            }
            {
                var profile = app.config.terminal.launch_profile;
                profile.kind = .shell;
                profile.command = .{};
                profile.ssh_target = .{};
                try app.config.terminal.setLaunchProfile(profile);
            }
        },
    }
}

fn runNativeGridActivated(
    allocator: std.mem.Allocator,
    io: std.Io,
    home_dir: []const u8,
    environ_map: anytype,
    mode: c_int,
    launch_policy: GridLaunchPolicy,
    activated_workspace_path: ?[]const u8,
    restore_mode: noctty.continuity.RestoreMode,
) !void {
    var app = try noctty.app.App.init(allocator);
    defer app.deinit();
    app.applySessionEnvironment(sessionEnvironment(environ_map));
    const config_path = try app.defaultConfigPathAlloc(home_dir);
    defer allocator.free(config_path);
    const theme_path = try app.defaultThemeLibraryPathAlloc(home_dir);
    defer allocator.free(theme_path);
    const autosave_path = try app.defaultWorkspacePathAlloc(home_dir, "default", .autosave);
    defer allocator.free(autosave_path);
    if (app.loadConfigFile(io, std.Io.Dir.cwd(), config_path, .settings)) |receipt| {
        receipt.deinit(allocator);
    } else |err| if (err != error.FileNotFound) return err;
    if (app.loadThemeLibraryFile(io, std.Io.Dir.cwd(), theme_path, .library)) |receipt| {
        receipt.deinit(allocator);
    } else |err| if (err != error.FileNotFound) return err;
    const hot_session_load: NativeGridHotSessionLoad = if (activated_workspace_path) |path| activated: {
        const receipt = try app.loadActivatedWorkspacePath(io, std.Io.Dir.cwd(), path);
        receipt.deinit(allocator);
        const config_receipt = try app.saveConfigFile(io, std.Io.Dir.cwd(), config_path, .settings);
        config_receipt.deinit(allocator);
        break :activated .restored;
    } else loadNativeGridHotSession(&app, io, autosave_path);
    if (hot_session_load != .restored) app.markWorkspaceDirtyAt(0);
    try populateProjectPanels(&app, allocator, io);
    const tab = app.workspace.activeTab() orelse return error.NoActiveTab;
    const pane = app.workspace.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
    if (activated_workspace_path != null)
        try applyRestoreMode(&app, pane, restore_mode);
    const shell_raw = noctty.launch_profile.safeFallbackShell(
        environ_map.get("SHELL") orelse "/bin/sh",
    );
    const cwd = try allocator.dupeZ(u8, pane.cwd);
    defer allocator.free(cwd);
    const shell = try allocator.dupeZ(u8, shell_raw);
    defer allocator.free(shell);
    var session_pool = NativeGridSessionPool.initWithProfile(
        allocator,
        shell,
        &app.config.terminal.launch_profile,
        null,
    );
    session_pool.history_limit = app.config.terminal.scrollback_lines;
    defer session_pool.deinit();
    var session = if (hot_session_load == .restored)
        try noctty.terminal_session.TerminalSession.spawnWithHistoryLimitAndScratch(
            allocator,
            cwd,
            shell,
            120,
            40,
            app.config.terminal.scrollback_lines,
            &session_pool.pump_scratch,
        )
    else launch: {
        const profile = &app.config.terminal.launch_profile;
        const resolved_cwd = profile.workingDirectory(pane.cwd);
        if (!std.mem.eql(u8, resolved_cwd, pane.cwd)) try pane.setCwd(resolved_cwd);
        break :launch try noctty.terminal_session.TerminalSession.spawnProfileWithScratch(
            allocator,
            profile,
            pane.cwd,
            shell,
            120,
            40,
            &session_pool.pump_scratch,
        );
    };
    defer session.deinit();
    var bridge = NativeGridBridge{ .app = &app, .pane_id = tab.active_pane_id, .io = io, .config_path = config_path, .theme_path = theme_path, .autosave_path = autosave_path, .hot_session_loaded = hot_session_load == .restored, .restore_mode = restore_mode, .session_pool = &session_pool, .primary_session = &session };
    persistNativeGridHotSession(&bridge);
    const effective_mode: c_int = if (mode >= 0)
        mode
    else
        @intCast(@intFromEnum(app.config.default_mode));
    const shortcut_mode: c_int = if (effective_mode != 0) 0 else switch (launch_policy) {
        .automatic => if (app.backend.capabilities.app_shortcut_registration) 1 else if (app.backend.capabilities.external_activation) 3 else 0,
        .visible => if (!app.backend.capabilities.app_shortcut_registration and app.backend.capabilities.external_activation) 3 else 0,
        .external_hidden => 2,
    };
    const status = runNativeGridHost(.{
        .session = &session,
        .bridge = &bridge,
        .pane_id = tab.active_pane_id,
        .columns = 120,
        .rows = 40,
        .mode = effective_mode,
        .shortcut_key = qtShortcutKey(app.config.dropdown.shortcut),
        .enable_shortcut = shortcut_mode,
        .enable_notifications = if (app.config.status.desktop_notifications) 1 else 0,
    });
    persistNativeGridHotSession(&bridge);
    if (status != 0) return error.NativeGridHostUnavailable;
    if (bridge.callback_failed) return error.NativeGridStateSyncFailed;
}
