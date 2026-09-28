//! Pure close coordination, geometry, selection, and input policy for GTK.

const std = @import("std");
const KeyEncoding = @import("terminal_key_encoding");
const SplitRatio = @import("split_ratio");

pub export fn noctty_grid_split_ratio(position: c_int, extent: c_int) callconv(.c) c_int {
    if (extent <= 0) return 0;
    return @intCast(SplitRatio.fromPosition(position, @intCast(extent)));
}

pub export fn noctty_grid_split_position(extent: c_int, ratio: c_int) callconv(.c) c_int {
    if (extent <= 0) return 0;
    return @intCast(SplitRatio.position(@intCast(extent), @intCast(std.math.clamp(ratio, 0, 1000))));
}

test "split ratio ABI bounds signed geometry without multiplication overflow" {
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_split_ratio(-1, 100));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_split_ratio(100, 0));
    try std.testing.expectEqual(@as(c_int, 500), noctty_grid_split_ratio(1_000_000_000, 2_000_000_000));
    try std.testing.expectEqual(std.math.maxInt(c_int), noctty_grid_split_position(std.math.maxInt(c_int), std.math.maxInt(c_int)));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_split_position(100, -1));
}

pub const ScrollbarGeometry = extern struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    thumb_y: f64,
    thumb_height: f64,
    history_lines: u64,
    viewport_offset: u64,
    visible_rows: u32,
};

pub const ScrollbarPressPlan = extern struct {
    action: c_int,
    drag_offset: f64,
    target_offset: u64,
};

pub const scrollbar_press_none: c_int = 0;
pub const scrollbar_press_drag: c_int = 1;
pub const scrollbar_press_page: c_int = 2;
pub const Rectangle = extern struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};
pub const DamageRect = extern struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};

pub const CursorPosition = extern struct {
    column: c_int,
    row: c_int,
    valid: c_int,
};
pub const WheelActionPlan = extern struct {
    steps: c_int,
    direction: c_int,
};

pub const ScrollRoutePlan = extern struct {
    route: c_int,
    steps: c_int,
    direction: c_int,
};

pub const SmartFilterVisibilityPlan = extern struct {
    visible: c_int,
    first_visible: c_int,
    focused_visible: c_int,
};

pub const SmartFilterSummaryPlan = extern struct {
    focus_first: c_int,
    show_empty: c_int,
};

pub const AccessibleOffsetPlan = extern struct {
    start: c_int,
    end: c_int,
    valid: c_int,
};
pub const AccessibleRangePlan = extern struct {
    start: c_int,
    end: c_int,
    valid: c_int,
};
pub const StartupWindowPlan = extern struct {
    start_hidden: c_int,
    apply_activation: c_int,
    show_layout_only: c_int,
};
pub const ControlNameRequestPlan = extern struct {
    registered: c_int,
    conflict: c_int,
};

pub const SmokeScheduleStep = extern struct {
    delay_ms: c_int,
    action: c_int,
    target: c_int,
};
pub const OutputPresentPlan = extern struct {
    schedule: c_int,
    use_tick: c_int,
    timeout_ms: c_int,
};
pub const ZoomPlan = extern struct {
    unzoom: c_int,
    enter: c_int,
};
pub const LayoutPresetPlan = extern struct {
    valid: c_int,
    rows: c_int,
    columns: c_int,
    target_count: c_int,
};

pub const PanelSettings = extern struct {
    panel_padding_px: c_int,
    pane_spacing_px: c_int,
    pane_divider_px: c_int,
    pane_border_px: c_int,
    pane_border_focused_px: c_int,
    pane_border_selected_px: c_int,
    status_border_px: c_int,
    overlay_border_px: c_int,
    window_border_px: c_int,
    dragger_px: c_int,
    pane_gaps_enabled: c_int,
    pane_gaps_transparent: c_int,
    inactive_pane_dim_enabled: c_int,
    inactive_pane_brightness_percent: c_int,
    background_translucency: c_int,
    background_opacity_percent: c_int,
    affects_layout: c_int,
};
pub const CompactSettingPlan = extern struct {
    target: c_int,
    valid: c_int,
};

pub const compact_setting_target_width_percent: c_int = 0;
pub const compact_setting_target_height_percent: c_int = 1;
pub const compact_setting_target_animation: c_int = 2;
pub const compact_setting_target_hide_focus: c_int = 3;
pub const compact_setting_target_focus_pointer: c_int = 4;
pub const compact_setting_target_pane_info: c_int = 5;
pub const compact_setting_target_width_pixels: c_int = 6;
pub const compact_setting_target_height_pixels: c_int = 7;

pub const FontRenderingPlan = extern struct {
    target: c_int,
    value: c_int,
    valid: c_int,
};

pub const font_rendering_target_antialias: c_int = 0;
pub const font_rendering_target_hinting: c_int = 1;

pub const SettingsEventKind = enum(c_int) {
    dropdown_width,
    dropdown_height,
    animation,
    hide_focus,
    focus_pointer,
    mode,
    font_size,
    pane_font_size,
    notifications,
    preset,
    tabs,
    status,
    tab_position,
    high_contrast,
    font_family,
    background_opacity,
    antialias,
    hinting,
    shortcut,
    pane_info,
    scroll_lines,
    smooth_scroll,
    panel_padding,
    pane_spacing,
    pane_gaps_enabled,
    pane_gaps_transparent,
    inactive_pane_dim,
    pane_divider,
    pane_border,
    focused_border,
    selected_border,
    status_border,
    overlay_border,
    window_border,
    dragger,
    scrollback,
    background_translucency,
    inactive_pane_brightness,
};

pub const settings_event_kind_count: c_int = 38;

pub fn settings_event_code(kind: SettingsEventKind) c_int {
    return switch (kind) {
        .dropdown_width => 76,
        .dropdown_height => 77,
        .animation => 72,
        .hide_focus => 73,
        .focus_pointer => 74,
        .mode => 40,
        .font_size => 41,
        .pane_font_size => 96,
        .notifications => 42,
        .preset => 43,
        .tabs => 44,
        .status => 45,
        .tab_position => 63,
        .high_contrast => 48,
        .font_family => 49,
        .background_opacity => 116,
        .antialias => 110,
        .hinting => 111,
        .shortcut => 75,
        .pane_info => 108,
        .scroll_lines => 117,
        .smooth_scroll => 118,
        .panel_padding => 46,
        .pane_spacing => 47,
        .pane_gaps_enabled => 127,
        .pane_gaps_transparent => 128,
        .inactive_pane_dim => 129,
        .pane_divider => 119,
        .pane_border => 120,
        .focused_border => 121,
        .selected_border => 122,
        .status_border => 123,
        .overlay_border => 124,
        .window_border => 125,
        .dragger => 126,
        .scrollback => 109,
        .background_translucency => 115,
        .inactive_pane_brightness => 130,
    };
}

pub export fn noctty_grid_settings_event_code(kind: c_int) callconv(.c) c_int {
    if (kind < 0 or kind >= settings_event_kind_count) return -1;
    return settings_event_code(@enumFromInt(kind));
}

pub const HostEventKind = enum(c_int) {
    session_started,
    session_exited,
    output_activity,
    shortcut_cancelled,
    project_visibility,
    workspace_new_tab,
    workspace_split,
    workspace_split_alt,
    workspace_broadcast,
    workspace_focus,
    broadcast_selection,
    workspace_split_close,
    workspace_split_restore,
    layout_preset_1x1,
    layout_preset_2x2,
    layout_preset_3x3,
    layout_preset_4x4,
    layout_preset_4x2,
    pane_moved,
    workspace_move,
    pane_focus,
    split_rendered_vertical,
    split_rendered_horizontal,
    pane_moved_rendered,
    zoom_toggled,
    command_palette_opened,
    terminal_find_opened,
    directional_focus,
    split_rendered_close,
    split_rendered_restore,
    tab_cycle,
    tab_close,
    tab_reopen,
    pane_cycle,
    title_fallback,
    title_overflow_label,
    title_overflow_tooltip,
    title_renamed,
    dirty_saved,
    session_exit_smoke,
    dirty_marked,
    notification_attention,
    dirty_cleared,
    tab_reordered,
    tab_reorder_persisted,
    rename_validation,
    rename_applied,
    rename_cancelled,
    pane_cycle_shortcut,
    alt_scroll_previous,
    restored_pane,
    alt_scroll_next,
    ctrl_alt_scroll,
    terminal_interrupt_chord,
    terminal_close_chord,
    final_pane_guard,
    profile_menu_opened,
    profile_selected,
    project_tools_opened,
    workspace_new_tab_restore,
    shortcut_conflict,
    shortcut_failed,
};

pub const host_event_kind_count: c_int = 62;

pub fn host_event_code(kind: HostEventKind) c_int {
    return switch (kind) {
        .session_started => 1,
        .session_exited => 3,
        .output_activity => 4,
        .shortcut_cancelled => 11,
        .project_visibility => 19,
        .workspace_new_tab => 20,
        .workspace_split => 21,
        .workspace_split_alt => 22,
        .workspace_broadcast => 23,
        .workspace_focus => 24,
        .broadcast_selection => 33,
        .workspace_split_close => 27,
        .workspace_split_restore => 28,
        .layout_preset_1x1 => 50,
        .layout_preset_2x2 => 51,
        .layout_preset_3x3 => 52,
        .layout_preset_4x4 => 60,
        .layout_preset_4x2 => 61,
        .pane_moved => 55,
        .workspace_move => 56,
        .pane_focus => 57,
        .split_rendered_vertical => 58,
        .split_rendered_horizontal => 59,
        .pane_moved_rendered => 62,
        .zoom_toggled => 64,
        .command_palette_opened => 65,
        .terminal_find_opened => 66,
        .directional_focus => 67,
        .split_rendered_close => 68,
        .split_rendered_restore => 69,
        .tab_cycle => 78,
        .tab_close => 79,
        .tab_reopen => 80,
        .pane_cycle => 81,
        .title_fallback => 82,
        .title_overflow_label => 83,
        .title_overflow_tooltip => 84,
        .title_renamed => 85,
        .dirty_saved => 86,
        .session_exit_smoke => 87,
        .dirty_marked => 88,
        .notification_attention => 89,
        .dirty_cleared => 90,
        .tab_reordered => 91,
        .tab_reorder_persisted => 92,
        .rename_validation => 93,
        .rename_applied => 94,
        .rename_cancelled => 95,
        .pane_cycle_shortcut => 97,
        .alt_scroll_previous => 98,
        .restored_pane => 99,
        .alt_scroll_next => 100,
        .ctrl_alt_scroll => 101,
        .terminal_interrupt_chord => 102,
        .terminal_close_chord => 103,
        .final_pane_guard => 104,
        .profile_menu_opened => 105,
        .profile_selected => 106,
        .project_tools_opened => 108,
        .workspace_new_tab_restore => 26,
        .shortcut_conflict => 14,
        .shortcut_failed => 15,
    };
}

pub export fn noctty_grid_host_event_code(kind: c_int) callconv(.c) c_int {
    if (kind < 0 or kind >= host_event_kind_count) return -1;
    return host_event_code(@enumFromInt(kind));
}

pub const TerminalMenuPlan = extern struct {
    action: c_int,
    selection_end_column: c_int,
    selection_end_row: c_int,
};

pub const terminal_menu_action_none: c_int = 0;
pub const terminal_menu_action_copy: c_int = 1;
pub const terminal_menu_action_paste: c_int = 2;
pub const terminal_menu_action_select_all: c_int = 3;
pub const terminal_menu_action_clear_selection: c_int = 4;
pub const terminal_menu_action_clear_screen: c_int = 5;
pub const terminal_menu_action_clear_scrollback: c_int = 6;
pub const terminal_menu_action_reset: c_int = 7;

pub const profile_preset_first: c_int = 0;
pub const profile_preset_count: c_int = 5;

pub const WindowDimensionsPlan = extern struct {
    width: c_int,
    height: c_int,
};

pub const LaunchProfileControlsPlan = extern struct {
    kind: c_int,
    command_sensitive: c_int,
    ssh_target_sensitive: c_int,
};

pub const WorkspaceEventPlan = extern struct {
    action: c_int,
    bind_layout: c_int,
    restore_missing: c_int,
};

pub const TrayMenuItemPlan = extern struct {
    valid: c_int,
    kind: c_int,
    has_children: c_int,
    action: c_int,
};

pub const LifecycleTimingPlan = extern struct {
    output_deadman_ms: c_int,
    write_flush_ms: c_int,
    exit_poll_us: i64,
    tick_ms: c_int,
    cursor_blink_ms: c_int,
    maintenance_seconds: c_int,
    idle_background_us: i64,
    idle_focused_us: i64,
    idle_steps_per_tick: c_int,
    preset_settle_interval_ms: c_int,
    preset_settle_attempts: c_int,
    status_feedback_ms: c_int,
    pane_cycle_feedback_ms: c_int,
    tab_cycle_feedback_ms: c_int,
    focus_hide_ms: c_int,
    layer_surface_hide_commit_ms: c_int,
    quick_note_save_debounce_ms: c_int,
    sharing_status_refresh_ms: c_int,
    resize_overlay_hide_ms: c_int,
    resize_commit_ms: c_int,
    resize_overlay_arm_ms: c_int,
    even_pane_settle_interval_ms: c_int,
    even_pane_settle_attempts: c_int,
    dbus_call_timeout_ms: c_int,
    dbus_operation_timeout_ms: c_int,
    dbus_notification_timeout_ms: c_int,
    dbus_drain_ms: c_int,
    dbus_poll_us: i64,
};

pub const NativeHostPolicy = extern struct {
    dropdown_min_width_px: c_int,
    dropdown_min_height_px: c_int,
    window_resize_border_px: c_int,
    pane_info_height_px: c_int,
    terminal_scrollbar_width_px: c_int,
    terminal_scrollbar_min_thumb_px: c_int,
    selection_copy_max_bytes: i64,
    event_idle_history_compacted: c_int,
    event_status_notification: c_int,
    event_status_acknowledged: c_int,
    text_action_persistence_failed: c_int,
    ui_color_workspace_background: c_int,
    ui_color_pane_border_active: c_int,
    ui_color_pane_border_selected: c_int,
    ui_color_pane_border_inactive: c_int,
    ui_color_scrollbar_track: c_int,
    ui_color_scrollbar_thumb: c_int,
    ui_color_scrollbar_thumb_hover: c_int,
    ui_color_overlay_background: c_int,
    ui_color_overlay_border: c_int,
    ui_color_overlay_foreground: c_int,
    ui_color_selection_background: c_int,
    ui_color_search_match_background: c_int,
    ui_color_status_info: c_int,
    ui_color_status_success: c_int,
    ui_color_status_warning: c_int,
    ui_color_status_error: c_int,
    ui_color_terminal_cursor: c_int,
    ui_color_pane_gap: c_int,
};

pub const workspace_event_emit: c_int = 0;
pub const workspace_event_create_tab: c_int = 1;
pub const workspace_event_split: c_int = 2;
pub const workspace_event_layout_preset: c_int = 3;
pub const workspace_event_move: c_int = 4;

pub const tray_menu_kind_root: c_int = 0;
pub const tray_menu_kind_standard: c_int = 1;
pub const tray_menu_kind_separator: c_int = 2;

pub const tray_menu_action_none: c_int = 0;
pub const tray_menu_action_toggle: c_int = 1;
pub const tray_menu_action_settings: c_int = 2;
pub const tray_menu_action_close: c_int = 3;



pub const AccessibleTextPlan = extern struct {
    initial_capacity: c_int,
};


pub const SelectionWordPlan = extern struct {
    valid: c_int,
    start_column: c_int,
    end_column: c_int,
};

const CellTextReader = *const fn (
    ?*anyopaque, c_int, c_int, [*]u8, usize,
) callconv(.c) c_int;
const CellHyperlinkReader = *const fn (
    ?*anyopaque, c_int, c_int, [*]u8, usize,
) callconv(.c) c_int;

pub const DirectionalFocusPlan = extern struct {
    source_center_x: f64,
    source_center_y: f64,
    best_score: f64,
    direction_x: c_int,
    direction_y: c_int,
    target_index: c_int,
    active: c_int,
};

pub const KeyCommandPlan = extern struct {
    action: c_int,
    direction: c_int,
    dx: c_int,
    dy: c_int,
    consume_without_effect: c_int,
};

pub const KeyChordPlan = extern struct {
    action: c_int,
    value: c_int,
};

pub const PointerEventPlan = extern struct {
    action: c_int,
};

pub const ResizeEventPlan = extern struct {
    action: c_int,
};

pub const WindowModePlan = extern struct {
    action: c_int,
};

pub const OverlayStackingPlan = extern struct {
    action: c_int,
    lower_parent: c_int,
};

pub const WindowVisibilityPlan = extern struct {
    action: c_int,
};

pub const OverlayGeometryPlan = extern struct {
    left: c_int,
    right: c_int,
    top: c_int,
    bottom: c_int,
};

pub const FullscreenPlan = extern struct {
    action: c_int,
};

pub const LayerGeometryPlan = extern struct {
    action: c_int,
    width: c_int,
    height: c_int,
    left: c_int,
    right: c_int,
    bottom: c_int,
};

pub const MonitorSelectionPlan = extern struct {
    action: c_int,
};

pub const CompactTabMetrics = extern struct {
    label_height: c_int,
    action_extent: c_int,
    strip_limit: c_int,
};

pub const CompactTabMeasurements = extern struct {
    horizontal: c_int,
    notebook_width: c_int,
    notebook_height: c_int,
    page_width: c_int,
    page_height: c_int,
    tab_width: c_int,
    tab_height: c_int,
    max_tab_width: c_int,
    close_width: c_int,
    close_height: c_int,
    action_width: c_int,
    action_height: c_int,
};

pub const CompactTabGeometry = extern struct {
    strip_extent: c_int,
    widget_extent: c_int,
    max_width: c_int,
    close_extent: c_int,
    action_extent: c_int,
};

pub const SettingsGeometryPlan = extern struct {
    width: c_int,
    height: c_int,
    min_width: c_int,
    min_height: c_int,
    max_width: c_int,
    max_height: c_int,
};

pub const CloseCoordinator = extern struct {
    phase: u32 = close_phase_idle,
    origin: u32 = close_origin_none,
    modal_depth: u32 = 0,
};

pub const CloseTransition = extern struct {
    effects: u32 = 0,
    origin: u32 = close_origin_none,
    accepted: u32 = 0,
};

pub const close_origin_none: u32 = 0;
pub const close_origin_toolbar: u32 = 1;
pub const close_origin_tray: u32 = 2;
pub const close_origin_window: u32 = 3;
pub const close_origin_natural: u32 = 4;

pub const close_source_deferred: u32 = 1;
pub const close_source_preflight: u32 = 2;

pub const close_effect_schedule_deferred: u32 = 1 << 0;
pub const close_effect_schedule_preflight: u32 = 1 << 1;
pub const close_effect_schedule_dwell: u32 = 1 << 2;
pub const close_effect_cancel_deferred: u32 = 1 << 3;
pub const close_effect_cancel_preflight: u32 = 1 << 4;
pub const close_effect_run_preflight: u32 = 1 << 5;
pub const close_effect_commit: u32 = 1 << 6;

const close_phase_idle: u32 = 0;
const close_phase_deferred: u32 = 1;
const close_phase_deferred_scheduled: u32 = 2;
const close_phase_preflight_scheduled: u32 = 3;
const close_phase_dwell_scheduled: u32 = 4;
const close_phase_preflight_active: u32 = 5;
const close_phase_committed: u32 = 6;

fn closeTransition(
    effects: u32,
    origin: u32,
    accepted: bool,
) CloseTransition {
    return .{
        .effects = effects,
        .origin = origin,
        .accepted = @intFromBool(accepted),
    };
}

fn closeSchedulePreflight(coordinator: *CloseCoordinator) CloseTransition {
    if (coordinator.origin == close_origin_natural) {
        coordinator.phase = close_phase_dwell_scheduled;
        return closeTransition(close_effect_schedule_dwell, coordinator.origin, true);
    }
    coordinator.phase = close_phase_preflight_scheduled;
    return closeTransition(close_effect_schedule_preflight, coordinator.origin, true);
}

pub export fn noctty_grid_close_request(
    coordinator_output: ?*CloseCoordinator,
    origin: u32,
) callconv(.c) CloseTransition {
    const coordinator = coordinator_output orelse return .{};
    if (origin < close_origin_toolbar or origin > close_origin_natural)
        return .{};
    if (coordinator.phase != close_phase_idle)
        return closeTransition(0, coordinator.origin, false);

    coordinator.origin = origin;
    if (coordinator.modal_depth != 0) {
        coordinator.phase = close_phase_deferred;
        return closeTransition(0, origin, true);
    }
    return closeSchedulePreflight(coordinator);
}

pub export fn noctty_grid_close_modal_begin(
    coordinator_output: ?*CloseCoordinator,
) callconv(.c) CloseTransition {
    const coordinator = coordinator_output orelse return .{};
    if (coordinator.modal_depth != std.math.maxInt(u32))
        coordinator.modal_depth += 1;

    const cancellation = switch (coordinator.phase) {
        close_phase_deferred_scheduled => close_effect_cancel_deferred,
        close_phase_preflight_scheduled, close_phase_dwell_scheduled => close_effect_cancel_preflight,
        else => return closeTransition(0, coordinator.origin, true),
    };
    coordinator.phase = close_phase_deferred;
    return closeTransition(cancellation, coordinator.origin, true);
}

pub export fn noctty_grid_close_modal_end(
    coordinator_output: ?*CloseCoordinator,
) callconv(.c) CloseTransition {
    const coordinator = coordinator_output orelse return .{};
    if (coordinator.modal_depth == 0)
        return closeTransition(0, coordinator.origin, false);
    coordinator.modal_depth -= 1;
    if (coordinator.modal_depth != 0 or coordinator.phase != close_phase_deferred)
        return closeTransition(0, coordinator.origin, true);

    coordinator.phase = close_phase_deferred_scheduled;
    return closeTransition(
        close_effect_schedule_deferred,
        coordinator.origin,
        true,
    );
}

pub export fn noctty_grid_close_source_fired(
    coordinator_output: ?*CloseCoordinator,
    source: u32,
) callconv(.c) CloseTransition {
    const coordinator = coordinator_output orelse return .{};
    if (source == close_source_deferred and
        coordinator.phase == close_phase_deferred_scheduled)
    {
        return closeSchedulePreflight(coordinator);
    }
    if (source == close_source_preflight and
        (coordinator.phase == close_phase_preflight_scheduled or
            coordinator.phase == close_phase_dwell_scheduled))
    {
        coordinator.phase = close_phase_preflight_active;
        return closeTransition(
            close_effect_run_preflight,
            coordinator.origin,
            true,
        );
    }
    return closeTransition(0, coordinator.origin, false);
}

pub export fn noctty_grid_close_preflight_result(
    coordinator_output: ?*CloseCoordinator,
    accepted: c_int,
) callconv(.c) CloseTransition {
    const coordinator = coordinator_output orelse return .{};
    if (coordinator.phase != close_phase_preflight_active)
        return closeTransition(0, coordinator.origin, false);

    const origin = coordinator.origin;
    if (accepted == 0) {
        coordinator.phase = close_phase_idle;
        coordinator.origin = close_origin_none;
        return closeTransition(0, origin, true);
    }
    coordinator.phase = close_phase_committed;
    return closeTransition(close_effect_commit, origin, true);
}

pub const input_pointer: c_int = 1;
pub const input_wheel: c_int = 2;

pub const modifier_shift: u32 = 1 << 0;
pub const modifier_control: u32 = 1 << 1;
pub const modifier_alt: u32 = 1 << 2;
const known_modifiers = modifier_shift | modifier_control | modifier_alt;

const gdk_key_alt_l: u32 = 0xffe9;
const gdk_key_alt_r: u32 = 0xffea;
const gdk_key_meta_l: u32 = 0xffe7;
const gdk_key_meta_r: u32 = 0xffe8;
const gdk_shift_mask: u32 = 1 << 0;
const gdk_control_mask: u32 = 1 << 2;
const gdk_mod1_mask: u32 = 1 << 3;
const gdk_super_mask: u32 = 1 << 26;
const gdk_key_kp_add: u32 = 0xffab;
const gdk_key_kp_subtract: u32 = 0xffad;

pub export fn noctty_grid_is_alt_key(keyval: u32) callconv(.c) c_int {
    return @intFromBool(
        keyval == gdk_key_alt_l or keyval == gdk_key_alt_r or
            keyval == gdk_key_meta_l or keyval == gdk_key_meta_r,
    );
}

pub export fn noctty_grid_input_modifiers(state: u32) callconv(.c) u32 {
    var modifiers: u32 = 0;
    if (state & gdk_shift_mask != 0) modifiers |= modifier_shift;
    if (state & gdk_control_mask != 0) modifiers |= modifier_control;
    if (state & gdk_mod1_mask != 0) modifiers |= modifier_alt;
    return modifiers;
}

pub export fn noctty_grid_cycle_target(
    count: c_int,
    current_index: c_int,
    current_found: c_int,
    direction: c_int,
) callconv(.c) c_int {
    if (count <= 0 or direction == 0) return -1;
    if (current_found == 0) return if (direction < 0) count - 1 else 0;
    if (current_index < 0 or current_index >= count) return -1;
    if (direction < 0)
        return if (current_index == 0) count - 1 else current_index - 1;
    return if (current_index == count - 1) 0 else current_index + 1;
}
pub export fn noctty_grid_tray_menu_plan(
    id: c_int,
    output_optional: ?*TrayMenuItemPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .valid = 0,
        .kind = tray_menu_kind_standard,
        .has_children = 0,
        .action = tray_menu_action_none,
    };
    switch (id) {
        0 => {
            output.* = .{
                .valid = 1,
                .kind = tray_menu_kind_root,
                .has_children = 1,
                .action = tray_menu_action_none,
            };
        },
        1 => {
            output.* = .{
                .valid = 1,
                .kind = tray_menu_kind_standard,
                .has_children = 0,
                .action = tray_menu_action_toggle,
            };
        },
        2 => {
            output.* = .{
                .valid = 1,
                .kind = tray_menu_kind_standard,
                .has_children = 0,
                .action = tray_menu_action_settings,
            };
        },
        3 => {
            output.* = .{
                .valid = 1,
                .kind = tray_menu_kind_separator,
                .has_children = 0,
                .action = tray_menu_action_none,
            };
        },
        4 => {
            output.* = .{
                .valid = 1,
                .kind = tray_menu_kind_standard,
                .has_children = 0,
                .action = tray_menu_action_close,
            };
        },
        else => {},
    }
}


pub export fn noctty_grid_workspace_event_plan(
    event_code: c_int,
    workspace_smoke: c_int,
    output_optional: ?*WorkspaceEventPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .action = workspace_event_emit,
        .bind_layout = 0,
        .restore_missing = 0,
    };
    if (event_code == host_event_code(.workspace_new_tab) or
        event_code == host_event_code(.workspace_new_tab_restore)) {
        output.action = workspace_event_create_tab;
        return;
    }
    if (event_code == host_event_code(.workspace_split) or
        event_code == host_event_code(.workspace_split_alt) or
        event_code == host_event_code(.workspace_split_close) or
        event_code == host_event_code(.workspace_split_restore))
    {
        output.* = .{
            .action = workspace_event_split,
            .bind_layout = 1,
            .restore_missing = 0,
        };
        return;
    }
    if ((event_code >= host_event_code(.layout_preset_1x1) and
            event_code <= host_event_code(.layout_preset_3x3)) or
        event_code == host_event_code(.layout_preset_4x4) or
        event_code == host_event_code(.layout_preset_4x2))
    {
        output.* = .{
            .action = workspace_event_layout_preset,
            .bind_layout = 0,
            .restore_missing = @intFromBool(workspace_smoke != 21),
        };
        return;
    }
    if (event_code == host_event_code(.workspace_move)) output.action = workspace_event_move;
}

pub export fn noctty_grid_smart_filter_visibility_plan(
    filter_active: c_int,
    matches: c_int,
    focused: c_int,
    first_visible_seen: c_int,
    output: ?*SmartFilterVisibilityPlan,
) callconv(.c) void {
    const plan = output orelse return;
    const visible = filter_active == 0 or matches != 0;
    plan.* = .{
        .visible = @intFromBool(visible),
        .first_visible = @intFromBool(visible and first_visible_seen == 0),
        .focused_visible = @intFromBool(visible and focused != 0),
    };
}

pub export fn noctty_grid_smart_filter_summary_plan(
    filter_active: c_int,
    page_available: c_int,
    first_visible: c_int,
    focused_visible: c_int,
    output: ?*SmartFilterSummaryPlan,
) callconv(.c) void {
    const plan = output orelse return;
    plan.* = .{
        .focus_first = @intFromBool(
            filter_active != 0 and first_visible != 0 and focused_visible == 0,
        ),
        .show_empty = @intFromBool(
            filter_active != 0 and page_available != 0 and first_visible == 0,
        ),
    };
}

pub export fn noctty_grid_tray_menu_id_valid(id: c_int) callconv(.c) c_int {
    return @intFromBool(id >= 0 and id <= 4);
}

pub export fn noctty_grid_window_resize_cursor_name(index: c_int) callconv(.c) [*:0]const u8 {
    return if (index == 3 or index == 4) "ew-resize" else "ns-resize";
}

pub export fn noctty_grid_tray_menu_label(id: c_int, window_presented: c_int) callconv(.c) [*:0]const u8 {
    return switch (id) {
        1 => if (window_presented != 0) "Hide NOCTTY" else "Show NOCTTY",
        2 => "Settings…",
        4 => "Close NOCTTY",
        else => "",
    };
}

pub export fn noctty_grid_tray_menu_icon_name(id: c_int) callconv(.c) [*:0]const u8 {
    return switch (id) {
        1 => "view-visible",
        2 => "configure",
        4 => "application-exit",
        else => "",
    };
}

pub export fn noctty_grid_resize_edge(index: c_int) callconv(.c) c_int {
    return if (index >= 0 and index < 8) index else -1;
}

pub export fn noctty_grid_resize_handle_index(stored_index: c_int) callconv(.c) c_int {
    return if (stored_index >= 1 and stored_index <= 8) stored_index - 1 else -1;
}

test "resize edge policy preserves all GTK edge ordinals" {
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_resize_edge(0));
    try std.testing.expectEqual(@as(c_int, 7), noctty_grid_resize_edge(7));
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_resize_edge(-1));
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_resize_edge(8));
}

test "resize handle storage indices normalize bounded handles" {
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_resize_handle_index(1));
    try std.testing.expectEqual(@as(c_int, 7), noctty_grid_resize_handle_index(8));
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_resize_handle_index(0));
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_resize_handle_index(9));
}

fn validRectangle(rectangle: *const Rectangle) bool {
    return std.math.isFinite(rectangle.x) and
        std.math.isFinite(rectangle.y) and
        std.math.isFinite(rectangle.width) and
        std.math.isFinite(rectangle.height) and
        rectangle.width >= 0 and rectangle.height >= 0;
}

pub export fn noctty_grid_directional_focus_begin(
    source_optional: ?*const Rectangle,
    dx: c_int,
    dy: c_int,
    output_optional: ?*DirectionalFocusPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .source_center_x = 0,
        .source_center_y = 0,
        .best_score = std.math.inf(f64),
        .direction_x = dx,
        .direction_y = dy,
        .target_index = -1,
        .active = 0,
    };
    const source = source_optional orelse return;
    const horizontal = (dx == -1 or dx == 1) and dy == 0;
    const vertical = (dy == -1 or dy == 1) and dx == 0;
    if ((!horizontal and !vertical) or !validRectangle(source)) return;

    const center_x = source.x + source.width / 2;
    const center_y = source.y + source.height / 2;
    if (!std.math.isFinite(center_x) or !std.math.isFinite(center_y)) return;
    output.source_center_x = center_x;
    output.source_center_y = center_y;
    output.active = 1;
}

pub export fn noctty_grid_directional_focus_consider(
    plan_optional: ?*DirectionalFocusPlan,
    candidate_optional: ?*const Rectangle,
    candidate_index: c_int,
) callconv(.c) void {
    const plan = plan_optional orelse return;
    const candidate = candidate_optional orelse return;
    if (plan.active == 0 or candidate_index < 0 or
        !validRectangle(candidate)) return;

    const center_x = candidate.x + candidate.width / 2;
    const center_y = candidate.y + candidate.height / 2;
    if (!std.math.isFinite(center_x) or !std.math.isFinite(center_y)) return;
    const delta_x = center_x - plan.source_center_x;
    const delta_y = center_y - plan.source_center_y;
    if (!std.math.isFinite(delta_x) or !std.math.isFinite(delta_y)) return;

    const primary = if (plan.direction_x != 0)
        delta_x * @as(f64, @floatFromInt(plan.direction_x))
    else
        delta_y * @as(f64, @floatFromInt(plan.direction_y));
    if (primary <= 1) return;
    const perpendicular = if (plan.direction_x != 0)
        @abs(delta_y)
    else
        @abs(delta_x);
    const score = primary * 10000 + perpendicular;
    if (!std.math.isFinite(score) or score >= plan.best_score) return;
    plan.best_score = score;
    plan.target_index = candidate_index;
}

pub const route_ignore: c_int = 0;
pub const route_scrollbar: c_int = 1;
pub const route_selection: c_int = 2;
pub const route_application_mouse: c_int = 3;
pub const route_terminal_scroll: c_int = 4;
pub const route_tab_cycle: c_int = 5;
pub const route_pane_cycle: c_int = 6;
pub const route_font_zoom: c_int = 7;
pub const route_local_pointer: c_int = 8;
pub const route_application_keys: c_int = 9;

pub const terminal_mode_mouse: c_int = 1 << 0;
pub const terminal_mode_alternate_screen: c_int = 1 << 1;

pub export fn noctty_grid_input_route(
    input_kind: c_int,
    scrollbar_owned: c_int,
    terminal_mode_flags: c_int,
    history_available: c_int,
    primary_button: c_int,
    modifier_flags: u32,
) callconv(.c) c_int {
    if (input_kind != input_pointer and input_kind != input_wheel)
        return route_ignore;
    if (scrollbar_owned != 0) return route_scrollbar;

    const terminal_mouse_mode = terminal_mode_flags & terminal_mode_mouse != 0;
    if (input_kind == input_pointer) {
        if (terminal_mouse_mode) return route_application_mouse;
        return if (primary_button != 0) route_selection else route_local_pointer;
    }

    const modifiers = modifier_flags & known_modifiers;
    if (terminal_mouse_mode and modifiers == 0)
        return route_application_mouse;
    if (modifiers & modifier_control != 0 and modifiers & modifier_alt != 0)
        return route_tab_cycle;
    if (modifiers & modifier_alt != 0)
        return route_pane_cycle;
    if (modifiers & modifier_control != 0)
        return route_font_zoom;
    if (modifiers & modifier_shift != 0) return route_terminal_scroll;
    if (!terminal_mouse_mode) {
        const alternate_screen =
            terminal_mode_flags & terminal_mode_alternate_screen != 0;
        if (alternate_screen and history_available == 0)
            return route_application_keys;
        return route_terminal_scroll;
    }
    return route_application_mouse;
}
pub export fn noctty_grid_wheel_action_plan(
    route: c_int,
    scroll_direction: c_int,
    delta_y: f64,
    accumulator_output: ?*f64,
    output: ?*WheelActionPlan,
) callconv(.c) void {
    const plan = output orelse return;
    plan.* = .{ .steps = 0, .direction = 0 };
    const accumulator = accumulator_output orelse return;
    const polarity: f64 = switch (route) {
        route_tab_cycle, route_pane_cycle => 1,
        route_font_zoom => -1,
        else => return,
    };
    if (scroll_direction == -1 or scroll_direction == 1) {
        accumulator.* = 0;
        plan.steps = 1;
        plan.direction = if (polarity > 0)
            scroll_direction
        else
            -scroll_direction;
        return;
    }
    if (scroll_direction != 0 or
        !std.math.isFinite(delta_y) or
        !std.math.isFinite(accumulator.*)) return;

    const accumulated = accumulator.* + delta_y * polarity;
    if (!std.math.isFinite(accumulated)) return;
    accumulator.* = accumulated;
    if (accumulated > -1 and accumulated < 1) return;

    const bounded = std.math.clamp(accumulated, -8, 8);
    const signed_steps: c_int = @intFromFloat(bounded);
    accumulator.* -= @floatFromInt(signed_steps);
    plan.steps = if (signed_steps < 0) -signed_steps else signed_steps;
    plan.direction = if (signed_steps < 0) -1 else 1;
}

pub export fn noctty_grid_scroll_route_plan(
    scrollbar_owned: c_int,
    terminal_mode_flags: c_int,
    history_available: c_int,
    modifier_flags: u32,
    scroll_direction: c_int,
    delta_y: f64,
    tab_accumulator: ?*f64,
    pane_accumulator: ?*f64,
    font_accumulator: ?*f64,
    output: ?*ScrollRoutePlan,
) callconv(.c) void {
    const plan = output orelse return;
    plan.* = .{ .route = route_ignore, .steps = 0, .direction = 0 };
    const route = noctty_grid_input_route(
        input_wheel, scrollbar_owned, terminal_mode_flags,
        history_available, 0, modifier_flags);
    plan.route = route;
    const accumulator: ?*f64 = switch (route) {
        route_tab_cycle => tab_accumulator,
        route_pane_cycle => pane_accumulator,
        route_font_zoom => font_accumulator,
        else => null,
    };
    var wheel_plan = WheelActionPlan{ .steps = 0, .direction = 0 };
    noctty_grid_wheel_action_plan(
        route, scroll_direction, delta_y, accumulator, &wheel_plan);
    plan.steps = wheel_plan.steps;
    plan.direction = wheel_plan.direction;
}

fn cell_is_background(
    reader: CellTextReader,
    userdata: ?*anyopaque,
    column: c_int,
    row: c_int,
) bool {
    var text: [64]u8 = undefined;
    const length = reader(userdata, column, row, &text, text.len);
    return noctty_grid_cell_is_background(&text, length) != 0;
}

pub export fn noctty_grid_selection_word_plan(
    userdata: ?*anyopaque,
    column: c_int,
    row: c_int,
    columns: c_int,
    reader_optional: ?CellTextReader,
    output: ?*SelectionWordPlan,
) callconv(.c) void {
    const plan = output orelse return;
    plan.* = .{ .valid = 0, .start_column = 0, .end_column = 0 };
    const reader = reader_optional orelse return;
    if (column < 0 or row < 0 or column >= columns) return;
    if (cell_is_background(reader, userdata, column, row)) return;
    var start = column;
    var end = column;
    while (start > 0 and
        !cell_is_background(reader, userdata, start - 1, row))
        start -= 1;
    while (end + 1 < columns and
        !cell_is_background(reader, userdata, end + 1, row))
        end += 1;
    plan.* = .{
        .valid = 1,
        .start_column = start,
        .end_column = end,
    };
}

pub export fn noctty_grid_read_hyperlink(
    userdata: ?*anyopaque,
    column: c_int,
    row: c_int,
    output: ?[*]u8,
    capacity: usize,
    reader_optional: ?CellHyperlinkReader,
) callconv(.c) c_int {
    const bytes = output orelse return 0;
    const reader = reader_optional orelse return 0;
    if (capacity < 2) return 0;
    const payload_capacity = capacity - 1;
    const length = reader(userdata, column, row, bytes, payload_capacity);
    if (length <= 0) return length;
    const bounded: usize = @min(@as(usize, @intCast(length)), payload_capacity);
    bytes[bounded] = 0;
    if (bounded > std.math.maxInt(u32)) return -1;
    return if (noctty_grid_hyperlink_valid(
        bytes, @intCast(bounded)) != 0)
        @intCast(bounded)
    else
        -1;
}

pub export fn noctty_grid_wheel_key_sequence(
    application_cursor: c_int,
    steps: c_int,
    output: ?[*]u8,
    capacity: u32,
) callconv(.c) c_int {
    const destination = output orelse return 0;
    if (steps == 0) return 0;
    const count: u32 = @min(@abs(steps), 64);
    const length = count * 3;
    if (capacity < length) return 0;
    _ = KeyEncoding.encode(
        if (steps > 0) .up else .down,
        .{ .application_cursor = application_cursor != 0 },
        destination[0..3],
    );
    for (1..count) |index| {
        const start = index * 3;
        @memcpy(destination[start..][0..3], destination[0..3]);
    }
    return @intCast(length);
}

const gdk_key_backspace: u32 = 0xff08;
const gdk_key_tab: u32 = 0xff09;
const gdk_key_return: u32 = 0xff0d;
const gdk_key_escape: u32 = 0xff1b;
const gdk_key_home: u32 = 0xff50;
const gdk_key_end: u32 = 0xff57;
const gdk_key_left: u32 = 0xff51;
const gdk_key_up: u32 = 0xff52;
const gdk_key_right: u32 = 0xff53;
const gdk_key_down: u32 = 0xff54;
const gdk_key_page_up: u32 = 0xff55;
const gdk_key_page_down: u32 = 0xff56;
const gdk_key_insert: u32 = 0xff63;
const gdk_key_kp_enter: u32 = 0xff8d;
const gdk_key_f1: u32 = 0xffbe;
const gdk_key_f12: u32 = 0xffc9;
const gdk_key_delete: u32 = 0xffff;
const gdk_key_iso_left_tab: u32 = 0xfe20;

pub const key_action_none: c_int = 0;
pub const key_action_show_note_overlays: c_int = 1;
pub const key_action_hide_note_overlays: c_int = 2;
pub const key_action_clear_smart_filter: c_int = 3;
pub const key_action_cycle_tab: c_int = 4;
pub const key_action_cycle_pane: c_int = 5;
pub const key_action_focus_direction: c_int = 6;

pub const chord_none: c_int = 0;
pub const chord_command_palette: c_int = 1;
pub const chord_terminal_find: c_int = 2;
pub const chord_quick_note: c_int = 3;
pub const chord_smart_filter: c_int = 4;
pub const chord_tag_selected: c_int = 5;
pub const chord_zoom: c_int = 6;
pub const chord_shortcuts: c_int = 7;
pub const chord_close_tab: c_int = 8;
pub const chord_rename_tab: c_int = 9;
pub const chord_emit_event: c_int = 10;
pub const chord_broadcast: c_int = 11;
pub const chord_tab_color: c_int = 12;
pub const chord_paste: c_int = 13;
pub const chord_copy: c_int = 14;
pub const chord_scroll_keyboard: c_int = 15;
pub const chord_ctrl_d: c_int = 16;
pub const chord_ctrl_c: c_int = 17;

pub const pointer_event_press: c_int = 1;
pub const pointer_event_release: c_int = 2;
pub const pointer_event_double_press: c_int = 3;
pub const pointer_action_none: c_int = 0;
pub const pointer_action_zoom: c_int = 1;
pub const pointer_action_select_word: c_int = 2;
pub const pointer_action_clear_selection: c_int = 3;
pub const pointer_action_open_hyperlink: c_int = 4;
pub const pointer_action_show_hyperlink_menu: c_int = 5;
pub const pointer_action_show_workspace_menu: c_int = 6;
pub const pointer_action_begin_selection: c_int = 7;
pub const pointer_action_update_selection: c_int = 8;
pub const pointer_action_deliver_mouse: c_int = 9;
pub const pointer_action_consume: c_int = 10;
pub const resize_event_press: c_int = 1;
pub const resize_event_motion: c_int = 2;
pub const resize_event_release: c_int = 3;
pub const resize_event_double_press: c_int = 4;
pub const resize_action_none: c_int = 0;
pub const resize_action_toggle_height: c_int = 1;
pub const resize_action_arm_click: c_int = 2;
pub const resize_action_delay_double_click: c_int = 3;
pub const resize_action_begin_drag: c_int = 4;
pub const resize_action_consume: c_int = 5;
pub const resize_action_update_drag: c_int = 6;
pub const resize_action_finish_drag: c_int = 7;
pub const window_mode_action_none: c_int = 0;
pub const window_mode_action_recreate: c_int = 1;
pub const window_mode_action_apply_dropdown: c_int = 2;
pub const window_mode_action_apply_window: c_int = 3;
pub const window_mode_action_apply_fullscreen: c_int = 4;
pub const window_mode_action_apply_layer_geometry: c_int = 5;
pub const overlay_stacking_none: c_int = 0;
pub const overlay_stacking_basic: c_int = 1;
pub const overlay_stacking_existing: c_int = 2;
pub const overlay_stacking_layer: c_int = 3;
pub const visibility_action_none: c_int = 0;
pub const visibility_action_hide: c_int = 1;
pub const visibility_action_show: c_int = 2;
pub const fullscreen_action_window: c_int = 1;
pub const fullscreen_action_current_monitor: c_int = 2;
pub const fullscreen_action_monitor: c_int = 3;
pub const layer_geometry_none: c_int = 0;
pub const layer_geometry_dropdown: c_int = 1;
pub const layer_geometry_zen: c_int = 2;
pub const layer_geometry_window: c_int = 3;
pub const monitor_selection_none: c_int = 0;
pub const monitor_selection_window: c_int = 1;
pub const monitor_selection_primary: c_int = 2;
pub const monitor_selection_pointer: c_int = 3;
pub const monitor_selection_first: c_int = 4;
fn keyCommandPlan(
    action: c_int,
    direction: c_int,
    dx: c_int,
    dy: c_int,
    consume_without_effect: bool,
) KeyCommandPlan {

    return .{
        .action = action,
        .direction = direction,
        .dx = dx,
        .dy = dy,
        .consume_without_effect = @intFromBool(consume_without_effect),
    };
}

pub export fn noctty_grid_key_command_plan(
    pressed: c_int,
    alt_key: c_int,
    smart_filter_clear_available: c_int,
    keyval: u32,
    modifier_flags: u32,
    output_optional: ?*KeyCommandPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = keyCommandPlan(key_action_none, 0, 0, 0, false);
    if (pressed == 0) {
        if (alt_key != 0)
            output.* = keyCommandPlan(
                key_action_hide_note_overlays,
                0,
                0,
                0,
                true,
            );
        return;
    }
    if (alt_key != 0) {
        output.* = keyCommandPlan(
            key_action_show_note_overlays,
            0,
            0,
            0,
            true,
        );
        return;
    }
    if (keyval == gdk_key_escape and smart_filter_clear_available != 0) {
        output.* = keyCommandPlan(
            key_action_clear_smart_filter,
            0,
            0,
            0,
            false,
        );
        return;
    }

    const modifiers = modifier_flags & known_modifiers;
    const control = modifiers & modifier_control != 0;
    const shift = modifiers & modifier_shift != 0;
    const alt = modifiers & modifier_alt != 0;
    if (control and shift and
        (keyval == gdk_key_tab or keyval == gdk_key_iso_left_tab))
    {
        output.* = keyCommandPlan(key_action_cycle_tab, 1, 0, 0, true);
        return;
    }
    if (control and !shift and keyval == gdk_key_tab) {
        output.* = keyCommandPlan(key_action_cycle_pane, 1, 0, 0, false);
        return;
    }
    if (control and !shift and keyval == gdk_key_page_up) {
        output.* = keyCommandPlan(key_action_cycle_tab, -1, 0, 0, false);
        return;
    }
    if (control and !shift and keyval == gdk_key_page_down) {
        output.* = keyCommandPlan(key_action_cycle_tab, 1, 0, 0, false);
        return;
    }
    if (alt and !control and !shift) {
        const direction: [2]c_int = switch (keyval) {
            gdk_key_left => .{ -1, 0 },
            gdk_key_right => .{ 1, 0 },
            gdk_key_up => .{ 0, -1 },
            gdk_key_down => .{ 0, 1 },
            else => return,
        };
        output.* = keyCommandPlan(
            key_action_focus_direction,
            0,
            direction[0],
            direction[1],
            false,
        );
    }
}

fn keyChordPlan(action: c_int, value: c_int) KeyChordPlan {
    return .{ .action = action, .value = value };
}

pub export fn noctty_grid_key_chord_plan(
    keyval: u32,
    state: u32,
    output_optional: ?*KeyChordPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = keyChordPlan(chord_none, 0);
    const control = state & gdk_control_mask != 0;
    const shift = state & gdk_shift_mask != 0;
    const alt = state & gdk_mod1_mask != 0;
    const super = state & gdk_super_mask != 0;
    const lower = if (keyval >= 'A' and keyval <= 'Z')
        keyval + ('a' - 'A')
    else
        keyval;

    if (control and shift) {
        output.* = switch (lower) {
            'p' => keyChordPlan(chord_command_palette, 0),
            'f' => keyChordPlan(chord_terminal_find, 0),
            'n' => keyChordPlan(chord_quick_note, 0),
            'g' => keyChordPlan(chord_smart_filter, 0),
            'y' => keyChordPlan(chord_tag_selected, 0),
            'z' => keyChordPlan(chord_zoom, 0),
            'k' => keyChordPlan(chord_shortcuts, 0),
            'w' => keyChordPlan(chord_close_tab, 0),
            'r' => keyChordPlan(chord_rename_tab, 0),
            't' => keyChordPlan(chord_emit_event, 26),
            's' => keyChordPlan(chord_emit_event, 21),
            'l' => keyChordPlan(chord_emit_event, 22),
            'v' => keyChordPlan(chord_paste, 0),
            'c' => keyChordPlan(chord_copy, 0),
            else => output.*,
        };
        if (output.action != chord_none) return;
    }
    if (control and (shift or alt) and lower == 'b') {
        output.* = keyChordPlan(chord_broadcast, 0);
        return;
    }
    if (control and alt) {
        if (keyval == '=' or keyval == '+' or keyval == gdk_key_kp_add) {
            output.* = keyChordPlan(chord_tab_color, 1);
            return;
        }
        if (keyval == '-' or keyval == gdk_key_kp_subtract) {
            output.* = keyChordPlan(chord_tab_color, -1);
            return;
        }
        if (keyval >= '1' and keyval <= '9') {
            output.* = keyChordPlan(
                chord_emit_event, @intCast(30 + keyval - '0'));
            return;
        }
        if (keyval == '[') {
            output.* = keyChordPlan(chord_emit_event, 25);
            return;
        }
        if (keyval == ']') {
            output.* = keyChordPlan(chord_emit_event, 24);
            return;
        }
    }
    if (shift and !control and !alt and !super and
        (keyval == gdk_key_page_up or keyval == gdk_key_page_down or
         keyval == gdk_key_home or keyval == gdk_key_end)) {
        output.* = keyChordPlan(
            chord_scroll_keyboard, @intCast(keyval));
        return;
    }
    if (control and !shift and !alt and !super) {
        if (lower == 'd') {
            output.* = keyChordPlan(chord_ctrl_d, 0);
            return;
        }
        if (lower == 'c') {
            output.* = keyChordPlan(chord_ctrl_c, 0);
            return;
        }
    }
}

pub export fn noctty_grid_pointer_event_plan(
    event_kind: c_int,
    button: c_int,
    route: c_int,
    hyperlink_point: c_int,
    control_pressed: c_int,
    background: c_int,
    multiple_panes: c_int,
    suppress_primary_release: c_int,
    preserve_double_click_selection: c_int,
    output_optional: ?*PointerEventPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{ .action = pointer_action_none };
    if (event_kind == pointer_event_double_press and button == 1) {
        if (background != 0 and multiple_panes != 0) {
            output.* = .{ .action = pointer_action_zoom };
            return;
        }
        if (background == 0) {
            output.* = .{ .action = pointer_action_select_word };
            return;
        }
        output.* = .{ .action = pointer_action_clear_selection };
        return;
    }
    if (event_kind == pointer_event_release and button == 1 and
        suppress_primary_release != 0) {
        output.* = .{
            .action = if (preserve_double_click_selection != 0)
                pointer_action_consume
            else
                pointer_action_clear_selection,
        };
        return;
    }
    if (event_kind == pointer_event_press and button == 1 and
        hyperlink_point != 0 and control_pressed != 0) {
        output.* = .{ .action = pointer_action_open_hyperlink };
        return;
    }
    if (event_kind == pointer_event_press and button == 3) {
        output.* = .{
            .action = if (hyperlink_point != 0)
                pointer_action_show_hyperlink_menu
            else
                pointer_action_show_workspace_menu,
        };
        return;
    }
    if (route == route_selection) {
        output.* = .{
            .action = if (event_kind == pointer_event_press)
                pointer_action_begin_selection
            else if (event_kind == pointer_event_release)
                pointer_action_update_selection
            else
                pointer_action_consume,
        };
        return;
    }
    if (route == route_application_mouse) {
        output.* = .{ .action = pointer_action_deliver_mouse };
        return;
    }
    output.* = .{ .action = pointer_action_consume };
}

pub export fn noctty_grid_resize_event_plan(
    event_kind: c_int,
    handle: c_int,
    button: c_int,
    mode: c_int,
    drag_active: c_int,
    click_pending: c_int,
    button1_down: c_int,
    motion_distance_squared: f64,
    output_optional: ?*ResizeEventPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{ .action = resize_action_none };
    if (handle < 0 or handle >= 8) return;
    if (event_kind == resize_event_double_press) {
        if (button != 1 or mode != 0 or handle != 6) return;
        output.* = .{ .action = resize_action_toggle_height };
        return;
    }
    if (event_kind == resize_event_press) {
        if (button != 1 or mode == 2) return;
        if (handle == 6 and mode == 0) {
            output.* = .{
                .action = if (click_pending != 0)
                    resize_action_delay_double_click
                else
                    resize_action_arm_click,
            };
            return;
        }
        output.* = .{ .action = resize_action_begin_drag };
        return;
    }
    if (event_kind == resize_event_motion) {
        if (handle == 6 and mode == 0 and drag_active == 0 and
            click_pending == 1) {
            if (motion_distance_squared >= 16.0) {
                output.* = .{ .action = resize_action_begin_drag };
            } else {
                output.* = .{ .action = resize_action_consume };
            }
            return;
        }
        if (drag_active == 0) return;
        output.* = .{
            .action = if (button1_down != 0)
                resize_action_update_drag
            else
                resize_action_finish_drag,
        };
        return;
    }
    if (event_kind == resize_event_release and
        drag_active != 0 and button == 1) {
        output.* = .{ .action = resize_action_finish_drag };
    }
}

pub export fn noctty_grid_window_mode_plan(
    previous_mode: c_int,
    mode: c_int,
    layer_shell_active: c_int,
    output_optional: ?*WindowModePlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{ .action = window_mode_action_none };
    if (previous_mode < 0 or previous_mode > 2 or mode < 0 or mode > 2)
        return;
    if ((previous_mode == 0) != (mode == 0)) {
        output.* = .{ .action = window_mode_action_recreate };
        return;
    }
    if (layer_shell_active != 0) {
        output.* = .{ .action = window_mode_action_apply_layer_geometry };
        return;
    }
    output.* = .{
        .action = switch (mode) {
            0 => window_mode_action_apply_dropdown,
            1 => window_mode_action_apply_window,
            2 => window_mode_action_apply_fullscreen,
            else => window_mode_action_none,
        },
    };
}

pub export fn noctty_grid_overlay_stacking_plan(
    layer_shell_active: c_int,
    layer_shell_library_available: c_int,
    existing_overlay: c_int,
    overlay_count: c_int,
    output_optional: ?*OverlayStackingPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .action = overlay_stacking_none,
        .lower_parent = 0,
    };
    if (existing_overlay != 0) {
        output.* = .{ .action = overlay_stacking_existing, .lower_parent = 0 };
        return;
    }
    if (layer_shell_active == 0 or layer_shell_library_available == 0) {
        output.* = .{ .action = overlay_stacking_basic, .lower_parent = 0 };
        return;
    }
    output.* = .{
        .action = overlay_stacking_layer,
        .lower_parent = @intFromBool(overlay_count <= 0),
    };
}

pub export fn noctty_grid_window_visibility_plan(
    window_presented: c_int,
    window_visible: c_int,
    output_optional: ?*WindowVisibilityPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{ .action = visibility_action_show };
    if (window_presented != 0 and window_visible != 0)
        output.* = .{ .action = visibility_action_hide };
}

pub export fn noctty_grid_overlay_geometry_plan(
    workarea_x: c_int,
    workarea_y: c_int,
    workarea_width: c_int,
    workarea_height: c_int,
    monitor_x: c_int,
    monitor_y: c_int,
    monitor_width: c_int,
    monitor_height: c_int,
    window_width: c_int,
    window_height: c_int,
    output_optional: ?*OverlayGeometryPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    const left = workarea_x - monitor_x + @divTrunc(workarea_width - window_width, 2);
    const top = workarea_y - monitor_y + @divTrunc(workarea_height - window_height, 2);
    output.* = .{
        .left = @max(0, left),
        .right = @max(0, monitor_width - left - window_width),
        .top = @max(0, top),
        .bottom = @max(0, monitor_height - top - window_height),
    };
}

pub export fn noctty_grid_fullscreen_plan(
    gdk_window_present: c_int,
    wayland_display: c_int,
    monitor_index: c_int,
    output_optional: ?*FullscreenPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    if (gdk_window_present == 0) {
        output.* = .{ .action = fullscreen_action_window };
    } else if (wayland_display != 0 or monitor_index < 0) {
        output.* = .{ .action = fullscreen_action_current_monitor };
    } else {
        output.* = .{ .action = fullscreen_action_monitor };
    }
}

pub export fn noctty_grid_layout_preset_plan(
    event_code: c_int,
    output_optional: ?*LayoutPresetPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .valid = 0,
        .rows = 0,
        .columns = 0,
        .target_count = 0,
    };
    var rows: c_int = 0;
    var columns: c_int = 0;
    switch (event_code) {
        50 => {
            rows = 1;
            columns = 1;
        },
        51 => {
            rows = 2;
            columns = 2;
        },
        52 => {
            rows = 3;
            columns = 3;
        },
        60 => {
            rows = 4;
            columns = 4;
        },
        61 => {
            rows = 2;
            columns = 4;
        },
        else => return,
    }
    output.* = .{
        .valid = 1,
        .rows = rows,
        .columns = columns,
        .target_count = rows * columns,
    };
}

pub export fn noctty_grid_layer_geometry_plan(
    mode: c_int,
    monitor_width: c_int,
    monitor_height: c_int,
    dropdown_width_px: c_int,
    dropdown_width_percent: c_int,
    dropdown_height_px: c_int,
    dropdown_height_percent: c_int,
    output_optional: ?*LayerGeometryPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .action = layer_geometry_none,
        .width = 0,
        .height = 0,
        .left = 0,
        .right = 0,
        .bottom = 0,
    };
    if (mode == 0) {
        const width = noctty_grid_dropdown_dimension(
            dropdown_width_px, dropdown_width_percent,
            monitor_width, 480);
        const height = noctty_grid_dropdown_dimension(
            dropdown_height_px, dropdown_height_percent,
            monitor_height, 240);
        const left = @max(0, @divTrunc(monitor_width - width, 2));
        output.* = .{
            .action = layer_geometry_dropdown,
            .width = width,
            .height = height,
            .left = left,
            .right = @max(0, monitor_width - width - left),
            .bottom = @max(0, monitor_height - height),
        };
    } else if (mode == 2) {
        output.* = .{
            .action = layer_geometry_zen,
            .width = -1,
            .height = -1,
            .left = 0,
            .right = 0,
            .bottom = 0,
        };
    } else if (mode == 1) {
        output.* = .{
            .action = layer_geometry_window,
            .width = @max(480, @divTrunc(monitor_width * 80, 100)),
            .height = @max(320, @divTrunc(monitor_height * 75, 100)),
            .left = 0,
            .right = 0,
            .bottom = 0,
        };
    }
}

pub export fn noctty_grid_monitor_selection_plan(
    window_monitor: c_int,
    primary_monitor: c_int,
    pointer_monitor: c_int,
    monitor_count: c_int,
    output_optional: ?*MonitorSelectionPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{ .action = monitor_selection_none };
    if (window_monitor != 0) {
        output.* = .{ .action = monitor_selection_window };
    } else if (primary_monitor != 0) {
        output.* = .{ .action = monitor_selection_primary };
    } else if (pointer_monitor != 0) {
        output.* = .{ .action = monitor_selection_pointer };
    } else if (monitor_count > 0) {
        output.* = .{ .action = monitor_selection_first };
    }
}

pub export fn noctty_grid_monitor_scale_factor(raw_scale_factor: c_int) callconv(.c) c_int {
    return @max(1, raw_scale_factor);
}

pub export fn noctty_grid_monitor_metrics_changed(
    geometry_x: c_int,
    geometry_y: c_int,
    geometry_width: c_int,
    geometry_height: c_int,
    workarea_x: c_int,
    workarea_y: c_int,
    workarea_width: c_int,
    workarea_height: c_int,
    scale_factor: c_int,
    previous_geometry_x: c_int,
    previous_geometry_y: c_int,
    previous_geometry_width: c_int,
    previous_geometry_height: c_int,
    previous_workarea_x: c_int,
    previous_workarea_y: c_int,
    previous_workarea_width: c_int,
    previous_workarea_height: c_int,
    previous_scale_factor: c_int,
) callconv(.c) c_int {
    return @intFromBool(
        geometry_x != previous_geometry_x or
            geometry_y != previous_geometry_y or
            geometry_width != previous_geometry_width or
            geometry_height != previous_geometry_height or
            workarea_x != previous_workarea_x or
            workarea_y != previous_workarea_y or
            workarea_width != previous_workarea_width or
            workarea_height != previous_workarea_height or
            scale_factor != previous_scale_factor,
    );
}

fn terminalKey(keyval: u32) ?KeyEncoding.Key {
    return switch (keyval) {
        gdk_key_up => .up,
        gdk_key_down => .down,
        gdk_key_right => .right,
        gdk_key_left => .left,
        gdk_key_home => .home,
        gdk_key_end => .end,
        gdk_key_insert => .insert,
        gdk_key_delete => .delete,
        gdk_key_page_up => .page_up,
        gdk_key_page_down => .page_down,
        gdk_key_f1 => .f1,
        gdk_key_f1 + 1 => .f2,
        gdk_key_f1 + 2 => .f3,
        gdk_key_f1 + 3 => .f4,
        gdk_key_f1 + 4 => .f5,
        gdk_key_f1 + 5 => .f6,
        gdk_key_f1 + 6 => .f7,
        gdk_key_f1 + 7 => .f8,
        gdk_key_f1 + 8 => .f9,
        gdk_key_f1 + 9 => .f10,
        gdk_key_f1 + 10 => .f11,
        gdk_key_f12 => .f12,
        gdk_key_return, gdk_key_kp_enter => .enter,
        gdk_key_backspace => .backspace,
        gdk_key_tab => .tab,
        gdk_key_escape => .escape,
        else => null,
    };
}

pub export fn noctty_grid_terminal_key_sequence(
    keyval: u32,
    codepoint: u32,
    modifier_flags: u32,
    application_cursor: c_int,
    output_optional: ?[*]u8,
    capacity: u32,
) callconv(.c) c_int {
    const output = output_optional orelse return 0;
    const control = modifier_flags & modifier_control != 0;
    const alt = modifier_flags & modifier_alt != 0;

    var encoded: [4]u8 = undefined;
    var sequence: []const u8 = undefined;
    var meta_prefix = false;
    if (control and ((codepoint >= 'A' and codepoint <= 'Z') or
        (codepoint >= 'a' and codepoint <= 'z')))
    {
        encoded[0] = @intCast((codepoint & 0x1f));
        sequence = encoded[0..1];
    } else if (codepoint >= 0x20 and codepoint != 0x7f and
        codepoint <= 0x10ffff and !(codepoint >= 0xd800 and codepoint <= 0xdfff))
    {
        const length = std.unicode.utf8Encode(@intCast(codepoint), &encoded) catch return 0;
        sequence = encoded[0..length];
        meta_prefix = alt and codepoint <= 0x7e;
    } else {
        const key = terminalKey(keyval) orelse return 0;
        return @intCast(KeyEncoding.encode(
            key,
            .{ .application_cursor = application_cursor != 0 },
            output[0..capacity],
        ));
    }

    const prefix_length: u32 = @intFromBool(meta_prefix and !control);
    const total_length: u32 = prefix_length + @as(u32, @intCast(sequence.len));
    if (capacity < total_length) return 0;
    if (prefix_length != 0) output[0] = 0x1b;
    @memcpy(output[prefix_length..][0..sequence.len], sequence);
    return @intCast(total_length);
}

pub export fn noctty_grid_shortcut_label(
    encoded: u32,
    output_optional: ?[*]u8,
    capacity: u32,
) callconv(.c) c_int {
    const output = output_optional orelse return 0;
    if (capacity == 0) return 0;
    var buffer: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    if (encoded == 0) {
        writer.writeAll("Unassigned") catch return 0;
    } else {
        const key = encoded & 0x01ffffff;
        if (encoded & 0x04000000 != 0) writer.writeAll("Ctrl+") catch return 0;
        if (encoded & 0x02000000 != 0) writer.writeAll("Shift+") catch return 0;
        if (encoded & 0x08000000 != 0) writer.writeAll("Alt+") catch return 0;
        if (encoded & 0x10000000 != 0) writer.writeAll("Super+") catch return 0;
        if ((key >= 'A' and key <= 'Z') or (key >= '0' and key <= '9')) {
            writer.writeByte(@intCast(key)) catch return 0;
        } else if (key >= 0x01000030 and key <= 0x0100003b) {
            writer.print("F{d}", .{key - 0x01000030 + 1}) catch return 0;
        } else {
            const name = switch (key) {
                '`' => "`",
                0x20 => "Space",
                0x01000000 => "Escape",
                0x01000001 => "Tab",
                0x01000003 => "Backspace",
                0x01000004, 0x01000005 => "Enter",
                0x01000006 => "Insert",
                0x01000007 => "Delete",
                0x01000010 => "Home",
                0x01000011 => "End",
                0x01000012 => "Left",
                0x01000013 => "Up",
                0x01000014 => "Right",
                0x01000015 => "Down",
                0x01000016 => "Page Up",
                0x01000017 => "Page Down",
                else => "Unknown",
            };
            writer.writeAll(name) catch return 0;
        }
    }
    const label = writer.buffered();
    if (label.len + 1 > capacity) return 0;
    @memcpy(output[0..label.len], label);
    output[label.len] = 0;
    return @intCast(label.len);
}

pub export fn noctty_grid_shortcut_settings_text(
    encoded: u32,
    plasma_transport: c_int,
    label: ?[*]u8,
    label_capacity: usize,
    tooltip: ?[*]u8,
    tooltip_capacity: usize,
    plan: ?*ShortcutTextPlan,
) callconv(.c) c_int {
    var shortcut_storage: [64]u8 = undefined;
    const shortcut_length = noctty_grid_shortcut_label(
        encoded, &shortcut_storage, shortcut_storage.len);
    if (shortcut_length <= 0) return 0;
    const shortcut = shortcut_storage[0..@intCast(shortcut_length)];
    var result = ShortcutTextPlan{
        .label_length = compactTabFormat(
            label, label_capacity, "{s} — Change shortcut…", .{shortcut}),
        .tooltip_length = 0,
    };
    if (result.label_length <= 0) return 0;
    result.tooltip_length = if (plasma_transport != 0)
        compactTabFormat(
            tooltip,
            tooltip_capacity,
            "Current shortcut: {s}. Select to change the Plasma global shortcut.",
            .{shortcut},
        )
    else
        compactTabFormat(
            tooltip,
            tooltip_capacity,
            "Current shortcut: {s}. Select to record and update the Noctalia binding plan.",
            .{shortcut},
        );
    if (result.tooltip_length <= 0) return 0;
    if (plan) |output| output.* = result;
    return 1;
}

pub export fn noctty_grid_scroll_direction(direction: c_int) callconv(.c) c_int {
    return switch (direction) {
        0 => -1,
        1 => 1,
        2 => 0,
        else => 2,
    };
}

pub export fn noctty_grid_tab_color_preset_name(preset: c_int) callconv(.c) [*:0]const u8 {
    return switch (preset) {
        0 => "Red",
        1 => "Orange",
        2 => "Yellow",
        3 => "Green",
        4 => "Cyan",
        5 => "Blue",
        6 => "Purple",
        7 => "Pink",
        else => "Default",
    };
}

pub export fn noctty_grid_tab_color_shade_name(shade: c_int) callconv(.c) [*:0]const u8 {
    if (shade <= -3) return "much darker";
    if (shade < 0) return "darker";
    if (shade >= 3) return "much lighter";
    if (shade > 0) return "lighter";
    return "base shade";
}

fn validatedGridText(
    text_pointer: ?[*]const u8,
    length: usize,
    max_length: usize,
) ?[]const u8 {
    const pointer = text_pointer orelse return null;
    if (length == 0 or length > max_length) return null;
    const text = pointer[0..length];
    if (!std.unicode.utf8ValidateSlice(text)) return null;
    for (text) |byte| {
        if (byte < 0x20 or byte == 0x7f) return null;
    }
    return text;
}

pub export fn noctty_grid_text_valid(
    text_pointer: ?[*]const u8,
    length: usize,
    max_length: usize,
) callconv(.c) c_int {
    return @intFromBool(validatedGridText(
        text_pointer,
        length,
        max_length,
    ) != null);
}

pub export fn noctty_grid_accessible_offset_plan(
    count: c_int,
    start_offset: c_int,
    end_offset: c_int,
    output: ?*AccessibleOffsetPlan,
) callconv(.c) void {
    const plan = output orelse return;
    const available = @max(count, 0);
    const start = @min(@max(start_offset, 0), available);
    const end = if (end_offset < 0)
        available
    else
        @min(@max(end_offset, start), available);
    plan.* = .{
        .start = start,
        .end = end,
        .valid = @intFromBool(
            available > 0 and start_offset >= 0 and start_offset < available,
        ),
    };
}
fn accessiblePreviousByteOffset(text: []const u8, index: usize) usize {
    if (index == 0) return 0;
    var result = index - 1;
    while (result > 0 and compactTabUtf8Continuation(text[result])) result -= 1;
    return result;
}

fn accessibleCodepointAt(text: []const u8, index: usize) ?u21 {
    if (index >= text.len) return null;
    const length = compactTabUtf8ByteLength(text, index);
    if (index + length > text.len) return null;
    return std.unicode.utf8Decode(text[index .. index + length]) catch null;
}

fn accessibleByteOffset(text: []const u8, offset: usize) usize {
    var index: usize = 0;
    var current: usize = 0;
    while (index < text.len and current < offset) : (current += 1)
        index += compactTabUtf8ByteLength(text, index);
    return index;
}


pub export fn noctty_grid_lifecycle_timing_plan(
    output_optional: ?*LifecycleTimingPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .output_deadman_ms = 200,
        .write_flush_ms = 4,
        .exit_poll_us = 250 * 1000,
        .tick_ms = 16,
        .cursor_blink_ms = 500,
        .maintenance_seconds = 1,
        .idle_background_us = 30 * 1_000_000,
        .idle_focused_us = 300 * 1_000_000,
        .idle_steps_per_tick = 16,
        .preset_settle_interval_ms = 50,
        .preset_settle_attempts = 4,
        .status_feedback_ms = 4500,
        .pane_cycle_feedback_ms = 800,
        .tab_cycle_feedback_ms = 800,
        .focus_hide_ms = 120,
        .layer_surface_hide_commit_ms = 16,
        .quick_note_save_debounce_ms = 250,
        .sharing_status_refresh_ms = 200,
        .resize_overlay_hide_ms = 750,
        .resize_commit_ms = 75,
        .resize_overlay_arm_ms = 250,
        .even_pane_settle_interval_ms = 16,
        .even_pane_settle_attempts = 4,
        .dbus_call_timeout_ms = 1000,
        .dbus_operation_timeout_ms = 1500,
        .dbus_notification_timeout_ms = 5000,
        .dbus_drain_ms = 2000,
        .dbus_poll_us = 1000,
    };
}

pub export fn noctty_grid_native_host_policy(
    output_optional: ?*NativeHostPolicy,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .dropdown_min_width_px = 480,
        .dropdown_min_height_px = 240,
        .window_resize_border_px = 2,
        .pane_info_height_px = 18,
        .terminal_scrollbar_width_px = 12,
        .terminal_scrollbar_min_thumb_px = 24,
        .selection_copy_max_bytes = 4 * 1024 * 1024,
        .event_idle_history_compacted = 112,
        .event_status_notification = 113,
        .event_status_acknowledged = 114,
        .text_action_persistence_failed = -2,
        .ui_color_workspace_background = 0,
        .ui_color_pane_border_active = 1,
        .ui_color_pane_border_selected = 2,
        .ui_color_pane_border_inactive = 3,
        .ui_color_scrollbar_track = 4,
        .ui_color_scrollbar_thumb = 5,
        .ui_color_scrollbar_thumb_hover = 6,
        .ui_color_overlay_background = 7,
        .ui_color_overlay_border = 8,
        .ui_color_overlay_foreground = 9,
        .ui_color_selection_background = 10,
        .ui_color_search_match_background = 11,
        .ui_color_status_info = 12,
        .ui_color_status_success = 13,
        .ui_color_status_warning = 14,
        .ui_color_status_error = 15,
        .ui_color_terminal_cursor = 16,
        .ui_color_pane_gap = 17,
    };
}
fn accessibleCodepointOffset(text: []const u8, byte_offset: usize) usize {
    var index: usize = 0;
    var result: usize = 0;
    while (index < byte_offset and index < text.len) : (result += 1)
        index += compactTabUtf8ByteLength(text, index);
    return result;
}

fn accessibleIsWhitespace(codepoint: u21) bool {
    return switch (codepoint) {
        ' ', '\t', '\n', 0x000b, '\x0c', '\r',
        0x0085, 0x00a0, 0x1680, 0x2000...0x200a,
        0x2028, 0x2029, 0x202f, 0x205f, 0x3000 => true,
        else => false,
    };
}

pub export fn noctty_grid_accessible_range_plan(
    text_pointer: ?[*]const u8,
    length: usize,
    offset: c_int,
    granularity: c_int,
    output: ?*AccessibleRangePlan,
) callconv(.c) void {
    const plan = output orelse return;
    plan.* = .{ .start = 0, .end = 0, .valid = 0 };
    const pointer = text_pointer orelse return;
    if (length == 0) return;
    const text = pointer[0..length];
    if (!std.unicode.utf8ValidateSlice(text) or offset < 0) return;
    const codepoint_count = compactTabUtf8Count(text);
    const start_offset: usize = @intCast(offset);
    if (start_offset >= codepoint_count) return;

    var start_byte = accessibleByteOffset(text, start_offset);
    var end_byte = accessibleByteOffset(text, start_offset + 1);
    if (granularity == 1) {
        while (start_byte > 0) {
            const previous_byte = accessiblePreviousByteOffset(text, start_byte);
            const previous = accessibleCodepointAt(text, previous_byte) orelse break;
            if (accessibleIsWhitespace(previous)) break;
            start_byte = previous_byte;
        }
        while (end_byte < text.len) {
            const next = accessibleCodepointAt(text, end_byte) orelse break;
            if (accessibleIsWhitespace(next)) break;
            end_byte += compactTabUtf8ByteLength(text, end_byte);
        }
    } else if (granularity == 2 or granularity == 3 or granularity == 4) {
        while (start_byte > 0) {
            const previous_byte = accessiblePreviousByteOffset(text, start_byte);
            if (text[previous_byte] == '\n') break;
            start_byte = previous_byte;
        }
        while (end_byte < text.len and text[end_byte] != '\n')
            end_byte += compactTabUtf8ByteLength(text, end_byte);
    }
    plan.* = .{
        .start = @intCast(accessibleCodepointOffset(text, start_byte)),
        .end = @intCast(accessibleCodepointOffset(text, end_byte)),
        .valid = 1,
    };
}

pub export fn noctty_grid_startup_window_plan(
    claim_control: c_int,
    enable_shortcut: c_int,
    control_registered: c_int,
    mode: c_int,
    control_conflict: c_int,
    activation_retained: c_int,
    output_optional: ?*StartupWindowPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    const start_hidden = claim_control != 0 and
        (enable_shortcut == 1 or enable_shortcut == 2) and
        control_registered != 0 and mode == 0;
    output.* = .{
        .start_hidden = @intFromBool(start_hidden),
        .apply_activation = @intFromBool(
            control_conflict == 0 and activation_retained != 0 and !start_hidden,
        ),
        .show_layout_only = @intFromBool(start_hidden or control_conflict != 0),
    };
}
pub export fn noctty_grid_control_name_request_plan(
    request_result: c_int,
    output_optional: ?*ControlNameRequestPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .registered = @intFromBool(request_result == 1 or request_result == 4),
        .conflict = @intFromBool(request_result == 2 or request_result == 3),
    };
}

pub export fn noctty_grid_accessible_text_capacity(
    columns: c_int,
    rows: c_int,
    output_optional: ?*AccessibleTextPlan,
) callconv(.c) c_int {
    const output = output_optional orelse return 0;
    const product: i64 = @as(i64, @max(columns, 0)) *
        @as(i64, @max(rows, 0));
    const max_capacity: i64 = @as(i64, std.math.maxInt(c_int));
    const capacity = @min(@max(product, 64), max_capacity);
    output.* = .{ .initial_capacity = @intCast(capacity) };
    return output.initial_capacity;
}

pub export fn noctty_grid_accessible_cell_length(
    length: c_int,
    capacity: c_int,
) callconv(.c) c_int {
    return if (length > 0 and length < capacity) length else 0;
}

pub export fn noctty_grid_accessible_trim_row_length(
    bytes: [*]const u8,
    length: usize,
) callconv(.c) usize {
    var result = length;
    while (result > 0 and bytes[result - 1] == ' ') result -= 1;
    return result;
}

pub export fn noctty_grid_accessible_trim_newline_length(
    bytes: [*]const u8,
    length: usize,
) callconv(.c) usize {
    var result = length;
    while (result > 0 and bytes[result - 1] == '\n') result -= 1;
    return result;
}
pub export fn noctty_grid_output_present_plan(
    session_available: c_int,
    exited: c_int,
    source_active: c_int,
    mapped: c_int,
    output: ?*OutputPresentPlan,
) callconv(.c) void {
    const plan = output orelse return;
    const schedule = session_available != 0 and exited == 0 and source_active == 0;
    plan.* = .{
        .schedule = @intFromBool(schedule),
        .use_tick = @intFromBool(schedule and mapped != 0),
        .timeout_ms = 100,
    };
}
pub export fn noctty_grid_zoom_plan(
    zoomed_pane_id: u64,
    pane_id: u64,
    output: ?*ZoomPlan,
) callconv(.c) void {
    const plan = output orelse return;
    const unzoom = zoomed_pane_id == pane_id;
    plan.* = .{
        .unzoom = @intFromBool(unzoom),
        .enter = @intFromBool(!unzoom),
    };
}


const smoke_action = struct {
    const write_activation: c_int = 1;
    const emit_tab: c_int = 2;
    const emit_split: c_int = 3;
    const emit_split_left: c_int = 4;
    const emit_broadcast: c_int = 5;
    const emit_select: c_int = 6;
    const emit_tag_filter: c_int = 7;
    const emit_focus: c_int = 8;
    const emit_move: c_int = 9;
    const finish_workspace: c_int = 10;
    const request_new_tab_button: c_int = 11;
    const inspect_compact_tab_geometry: c_int = 12;
    const request_tab_close: c_int = 13;
    const request_clipboard: c_int = 14;
    const inspect_window_toolbar: c_int = 15;
    const request_settings: c_int = 16;
    const request_window_close_button: c_int = 17;
    const request_theme: c_int = 18;
    const request_project: c_int = 19;
    const request_recursive_zoom: c_int = 20;
    const drive_focus_click: c_int = 21;
    const emit_balanced_split: c_int = 22;
    const move_last_pane: c_int = 23;
    const request_compact_hyperlink: c_int = 24;
    const request_compact_palette: c_int = 25;
    const request_compact_find: c_int = 26;
    const request_compact_note: c_int = 27;
    const request_compact_zoom: c_int = 28;
    const request_compact_navigation: c_int = 29;
    const inspect_compact_pane_info: c_int = 30;
    const request_compact_font_scroll: c_int = 31;
    const request_compact_linear_selection: c_int = 32;
    const request_compact_save: c_int = 33;
    const request_pane_scrollbar: c_int = 34;
    const finish_compact: c_int = 35;
    const request_tab_rename: c_int = 36;
    const check_resize_overlay_hidden: c_int = 37;
    const move_resize_overlay: c_int = 38;
    const check_resize_overlay_visible: c_int = 39;
    const finish_resize_overlay: c_int = 40;
    const emit_pane_close_primary: c_int = 41;
    const emit_pane_close_secondary: c_int = 42;
    const inspect_pane_close_layout: c_int = 43;
    const disturb_pane_close_layout: c_int = 44;
    const request_pane_close: c_int = 45;
    const start_layout_preset: c_int = 46;
    const start_tab_navigation: c_int = 47;
    const check_title_fallback: c_int = 48;
    const emit_title_overflow: c_int = 49;
    const check_title_overflow: c_int = 50;
    const check_title_rename: c_int = 51;
    const finish_title: c_int = 52;
    const trigger_dirty: c_int = 53;
    const emit_attention: c_int = 54;
    const check_dirty: c_int = 55;
    const check_attention: c_int = 56;
    const save_dirty: c_int = 57;
    const check_dirty_clear: c_int = 58;
    const acknowledge_attention: c_int = 59;
    const announce_reorder: c_int = 60;
    const check_reorder: c_int = 61;
    const persist_reorder: c_int = 62;
    const palette_rename: c_int = 63;
    const request_tab_color: c_int = 64;
    const request_settings_stacking: c_int = 65;
    const check_settings_stacking: c_int = 66;
    const request_note_overlay_alt: c_int = 67;
    const check_note_overlay: c_int = 68;
    const request_terminal_interrupt: c_int = 69;
    const request_terminal_close: c_int = 70;
    const request_terminal_final_guard: c_int = 71;
    const finish_terminal_chord: c_int = 72;
    const request_profile_preset: c_int = 73;
    const request_recent_workspace_child: c_int = 74;
    const start_presentation: c_int = 75;
    const start_full_stack: c_int = 76;
    const poll_continuity_detach: c_int = 77;
    const start_stability: c_int = 78;
    const request_sharing_scope: c_int = 79;
    const request_window_resize: c_int = 80;
};

const smoke_target_context: c_int = 0;
const smoke_target_peer: c_int = 1;

fn smokeStep(delay_ms: c_int, action: c_int, target: c_int) SmokeScheduleStep {
    return .{ .delay_ms = delay_ms, .action = action, .target = target };
}

const smoke_schedule_activation = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.write_activation, smoke_target_context),
};
const smoke_schedule_1 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.emit_tab, smoke_target_context),
    smokeStep(450, smoke_action.emit_split, smoke_target_context),
    smokeStep(650, smoke_action.emit_split_left, smoke_target_context),
    smokeStep(850, smoke_action.emit_broadcast, smoke_target_context),
    smokeStep(1050, smoke_action.emit_select, smoke_target_context),
    smokeStep(1150, smoke_action.emit_tag_filter, smoke_target_context),
    smokeStep(1250, smoke_action.emit_focus, smoke_target_context),
    smokeStep(1450, smoke_action.emit_move, smoke_target_peer),
    smokeStep(1650, smoke_action.finish_workspace, smoke_target_context),
};
const smoke_schedule_2 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.emit_split, smoke_target_context),
};
const smoke_schedule_3 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.request_new_tab_button, smoke_target_context),
    smokeStep(450, smoke_action.inspect_compact_tab_geometry, smoke_target_context),
    smokeStep(600, smoke_action.request_tab_close, smoke_target_context),
};
const smoke_schedule_4 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.request_clipboard, smoke_target_context),
};
const smoke_schedule_6 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.inspect_window_toolbar, smoke_target_context),
    smokeStep(700, smoke_action.request_settings, smoke_target_context),
    smokeStep(1600, smoke_action.request_window_close_button, smoke_target_context),
};
const smoke_schedule_7 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.request_theme, smoke_target_context),
};
const smoke_schedule_8 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.request_project, smoke_target_context),
    smokeStep(20000, smoke_action.finish_title, smoke_target_context),
};
const smoke_schedule_11 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.emit_split, smoke_target_context),
    smokeStep(500, smoke_action.emit_split, smoke_target_context),
    smokeStep(750, smoke_action.emit_split_left, smoke_target_context),
    smokeStep(900, smoke_action.request_recursive_zoom, smoke_target_context),
};
const smoke_schedule_12 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.emit_split, smoke_target_context),
    smokeStep(350, smoke_action.drive_focus_click, smoke_target_context),
};
const smoke_schedule_13 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.emit_balanced_split, smoke_target_context),
    smokeStep(500, smoke_action.emit_balanced_split, smoke_target_context),
    smokeStep(750, smoke_action.emit_balanced_split, smoke_target_context),
    smokeStep(1000, smoke_action.emit_balanced_split, smoke_target_context),
    smokeStep(1250, smoke_action.emit_balanced_split, smoke_target_context),
    smokeStep(1500, smoke_action.emit_balanced_split, smoke_target_context),
    smokeStep(1750, smoke_action.emit_balanced_split, smoke_target_context),
};
const smoke_schedule_14 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.emit_tab, smoke_target_context),
    smokeStep(500, smoke_action.move_last_pane, smoke_target_context),
};
const smoke_schedule_15 = [_]SmokeScheduleStep{
    smokeStep(150, smoke_action.request_compact_hyperlink, smoke_target_context),
    smokeStep(250, smoke_action.emit_split, smoke_target_context),
    smokeStep(500, smoke_action.request_compact_palette, smoke_target_context),
    smokeStep(700, smoke_action.request_compact_find, smoke_target_context),
    smokeStep(900, smoke_action.request_compact_note, smoke_target_context),
    smokeStep(1100, smoke_action.request_compact_zoom, smoke_target_context),
    smokeStep(1300, smoke_action.request_compact_navigation, smoke_target_context),
    smokeStep(1400, smoke_action.inspect_compact_pane_info, smoke_target_context),
    smokeStep(1500, smoke_action.request_compact_font_scroll, smoke_target_context),
    smokeStep(1625, smoke_action.request_compact_linear_selection, smoke_target_context),
    smokeStep(1700, smoke_action.request_compact_save, smoke_target_context),
    smokeStep(1800, smoke_action.request_pane_scrollbar, smoke_target_context),
    smokeStep(2500, smoke_action.finish_compact, smoke_target_context),
};
const smoke_schedule_17 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.emit_tab, smoke_target_context),
    smokeStep(500, smoke_action.request_tab_rename, smoke_target_context),
};
const smoke_schedule_18 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.check_resize_overlay_hidden, smoke_target_context),
    smokeStep(400, smoke_action.emit_split, smoke_target_context),
    smokeStep(700, smoke_action.move_resize_overlay, smoke_target_context),
    smokeStep(850, smoke_action.move_resize_overlay, smoke_target_context),
    smokeStep(1000, smoke_action.check_resize_overlay_visible, smoke_target_context),
    smokeStep(1700, smoke_action.finish_resize_overlay, smoke_target_context),
};
const smoke_schedule_19 = [_]SmokeScheduleStep{
    smokeStep(250, smoke_action.request_window_resize, smoke_target_context),
};
const smoke_schedule_20 = [_]SmokeScheduleStep{
    smokeStep(180, smoke_action.emit_pane_close_primary, smoke_target_context),
    smokeStep(330, smoke_action.emit_pane_close_secondary, smoke_target_context),
    smokeStep(500, smoke_action.inspect_pane_close_layout, smoke_target_context),
    smokeStep(680, smoke_action.disturb_pane_close_layout, smoke_target_context),
    smokeStep(850, smoke_action.request_pane_close, smoke_target_context),
};
const smoke_schedule_21 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.start_layout_preset, smoke_target_context),
};
const smoke_schedule_22 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.emit_tab, smoke_target_context),
    smokeStep(550, smoke_action.emit_split, smoke_target_context),
    smokeStep(800, smoke_action.start_tab_navigation, smoke_target_context),
};
const smoke_schedule_23 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.check_title_fallback, smoke_target_context),
    smokeStep(700, smoke_action.emit_title_overflow, smoke_target_context),
    smokeStep(1200, smoke_action.check_title_overflow, smoke_target_context),
    smokeStep(1700, smoke_action.check_title_rename, smoke_target_context),
    smokeStep(2300, smoke_action.finish_title, smoke_target_context),
};
const smoke_schedule_24 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.trigger_dirty, smoke_target_context),
    smokeStep(650, smoke_action.emit_attention, smoke_target_context),
    smokeStep(1000, smoke_action.check_dirty, smoke_target_context),
    smokeStep(1200, smoke_action.check_attention, smoke_target_context),
    smokeStep(1450, smoke_action.save_dirty, smoke_target_context),
    smokeStep(1750, smoke_action.check_dirty_clear, smoke_target_context),
    smokeStep(2100, smoke_action.acknowledge_attention, smoke_target_context),
    smokeStep(2400, smoke_action.finish_title, smoke_target_context),
};
const smoke_schedule_25 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.emit_tab, smoke_target_context),
    smokeStep(600, smoke_action.emit_tab, smoke_target_context),
    smokeStep(900, smoke_action.announce_reorder, smoke_target_context),
    smokeStep(6500, smoke_action.check_reorder, smoke_target_context),
    smokeStep(6800, smoke_action.persist_reorder, smoke_target_context),
    smokeStep(7500, smoke_action.finish_title, smoke_target_context),
};
const smoke_schedule_26 = [_]SmokeScheduleStep{
    smokeStep(500, smoke_action.palette_rename, smoke_target_context),
    smokeStep(2200, smoke_action.finish_title, smoke_target_context),
};
const smoke_schedule_27 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.request_tab_color, smoke_target_context),
};
const smoke_schedule_28 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.request_settings_stacking, smoke_target_context),
    smokeStep(700, smoke_action.check_settings_stacking, smoke_target_context),
};
const smoke_schedule_29 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.emit_split, smoke_target_context),
    smokeStep(650, smoke_action.request_note_overlay_alt, smoke_target_context),
    smokeStep(950, smoke_action.check_note_overlay, smoke_target_context),
};
const smoke_schedule_31 = [_]SmokeScheduleStep{
    smokeStep(350, smoke_action.request_terminal_interrupt, smoke_target_context),
    smokeStep(700, smoke_action.request_terminal_close, smoke_target_context),
    smokeStep(950, smoke_action.request_terminal_final_guard, smoke_target_context),
    smokeStep(1200, smoke_action.finish_terminal_chord, smoke_target_context),
};
const smoke_schedule_33 = [_]SmokeScheduleStep{
    smokeStep(350, smoke_action.request_profile_preset, smoke_target_context),
};
const smoke_schedule_35 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.request_recent_workspace_child, smoke_target_context),
    smokeStep(6000, smoke_action.finish_title, smoke_target_context),
};
const smoke_schedule_36 = [_]SmokeScheduleStep{
    smokeStep(350, smoke_action.start_presentation, smoke_target_context),
};
const smoke_schedule_37 = [_]SmokeScheduleStep{
    smokeStep(350, smoke_action.start_full_stack, smoke_target_context),
};
const smoke_schedule_39 = [_]SmokeScheduleStep{
    smokeStep(100, smoke_action.poll_continuity_detach, smoke_target_context),
};
const smoke_schedule_40 = [_]SmokeScheduleStep{
    smokeStep(350, smoke_action.start_stability, smoke_target_context),
};
const smoke_schedule_41 = [_]SmokeScheduleStep{
    smokeStep(300, smoke_action.request_sharing_scope, smoke_target_context),
};
const smoke_schedule_42 = [_]SmokeScheduleStep{
    smokeStep(500, smoke_action.request_pane_scrollbar, smoke_target_context),
};

fn copySmokeSchedule(
    schedule: []const SmokeScheduleStep,
    output_optional: ?*SmokeScheduleStep,
    capacity: c_int,
) c_int {
    if (capacity <= 0) return 0;
    const output = @as([*]SmokeScheduleStep, @ptrCast(output_optional orelse return 0));
    const count = @min(schedule.len, @as(usize, @intCast(capacity)));
    for (0..count) |index| output[index] = schedule[index];
    return @intCast(count);
}

pub export fn noctty_grid_smoke_schedule(
    workspace_smoke: c_int,
    activation_child_receipt: c_int,
    output_optional: ?*SmokeScheduleStep,
    capacity: c_int,
) callconv(.c) c_int {
    if (workspace_smoke < 0)
        return if (activation_child_receipt != 0)
            copySmokeSchedule(&smoke_schedule_activation, output_optional, capacity)
        else
            0;
    return switch (workspace_smoke) {
        1 => copySmokeSchedule(&smoke_schedule_1, output_optional, capacity),
        2 => copySmokeSchedule(&smoke_schedule_2, output_optional, capacity),
        3 => copySmokeSchedule(&smoke_schedule_3, output_optional, capacity),
        4 => copySmokeSchedule(&smoke_schedule_4, output_optional, capacity),
        6 => copySmokeSchedule(&smoke_schedule_6, output_optional, capacity),
        7 => copySmokeSchedule(&smoke_schedule_7, output_optional, capacity),
        8 => copySmokeSchedule(&smoke_schedule_8, output_optional, capacity),
        11 => copySmokeSchedule(&smoke_schedule_11, output_optional, capacity),
        12 => copySmokeSchedule(&smoke_schedule_12, output_optional, capacity),
        13 => copySmokeSchedule(&smoke_schedule_13, output_optional, capacity),
        14 => copySmokeSchedule(&smoke_schedule_14, output_optional, capacity),
        15 => copySmokeSchedule(&smoke_schedule_15, output_optional, capacity),
        17 => copySmokeSchedule(&smoke_schedule_17, output_optional, capacity),
        18 => copySmokeSchedule(&smoke_schedule_18, output_optional, capacity),
        19 => copySmokeSchedule(&smoke_schedule_19, output_optional, capacity),
        20 => copySmokeSchedule(&smoke_schedule_20, output_optional, capacity),
        21, 43 => copySmokeSchedule(&smoke_schedule_21, output_optional, capacity),
        22 => copySmokeSchedule(&smoke_schedule_22, output_optional, capacity),
        23 => copySmokeSchedule(&smoke_schedule_23, output_optional, capacity),
        24 => copySmokeSchedule(&smoke_schedule_24, output_optional, capacity),
        25 => copySmokeSchedule(&smoke_schedule_25, output_optional, capacity),
        26 => copySmokeSchedule(&smoke_schedule_26, output_optional, capacity),
        27 => copySmokeSchedule(&smoke_schedule_27, output_optional, capacity),
        28 => copySmokeSchedule(&smoke_schedule_28, output_optional, capacity),
        29 => copySmokeSchedule(&smoke_schedule_29, output_optional, capacity),
        31 => copySmokeSchedule(&smoke_schedule_31, output_optional, capacity),
        33 => copySmokeSchedule(&smoke_schedule_33, output_optional, capacity),
        35 => copySmokeSchedule(&smoke_schedule_35, output_optional, capacity),
        36 => copySmokeSchedule(&smoke_schedule_36, output_optional, capacity),
        37 => copySmokeSchedule(&smoke_schedule_37, output_optional, capacity),
        39 => copySmokeSchedule(&smoke_schedule_39, output_optional, capacity),
        40 => copySmokeSchedule(&smoke_schedule_40, output_optional, capacity),
        41 => copySmokeSchedule(&smoke_schedule_41, output_optional, capacity),
        42 => copySmokeSchedule(&smoke_schedule_42, output_optional, capacity),
        else => 0,
    };
}

pub export fn noctty_grid_hyperlink_valid(
    uri_pointer: ?[*]const u8,
    length: u32,
) callconv(.c) c_int {
    const uri = validatedGridText(uri_pointer, length, 2048) orelse return 0;
    const separator = std.mem.indexOfScalar(u8, uri, ':') orelse return 0;
    const scheme = uri[0..separator];
    const allowed = std.ascii.eqlIgnoreCase(scheme, "http") or
        std.ascii.eqlIgnoreCase(scheme, "https") or
        std.ascii.eqlIgnoreCase(scheme, "mailto");
    return @intFromBool(allowed);
}

pub export fn noctty_grid_fuzzy_match_ascii(
    haystack_pointer: ?[*]const u8,
    haystack_length: u32,
    needle_pointer: ?[*]const u8,
    needle_length: u32,
) callconv(.c) c_int {
    if (needle_length == 0) return 1;
    const haystack = (haystack_pointer orelse return 0)[0..haystack_length];
    const needle = (needle_pointer orelse return 0)[0..needle_length];
    var cursor: usize = 0;
    for (haystack) |byte| {
        if (std.ascii.toLower(byte) == std.ascii.toLower(needle[cursor]))
            cursor += 1;
        if (cursor == needle.len) return 1;
    }
    return 0;
}

pub export fn noctty_grid_dropdown_dimension(
    stored_px: c_int,
    percent: c_int,
    available_px: c_int,
    minimum_px: c_int,
) callconv(.c) c_int {
    if (available_px <= 0) return 0;
    const lower_bound = std.math.clamp(minimum_px, 0, available_px);
    const bounded_percent = std.math.clamp(percent, 0, 100);
    const requested: i64 = if (stored_px >= lower_bound)
        stored_px
    else
        @divFloor(
            @as(i64, available_px) * @as(i64, bounded_percent),
            100,
        );
    return @intCast(std.math.clamp(
        requested,
        @as(i64, lower_bound),
        @as(i64, available_px),
    ));
}

pub export fn noctty_grid_dialog_dimension(
    available_px: c_int,
    maximum_px: c_int,
    minimum_px: c_int,
    margin_px: c_int,
) callconv(.c) c_int {
    const requested = @as(i64, available_px) - @as(i64, margin_px);
    const lower = @max(minimum_px, 1);
    const upper = @max(maximum_px, lower);
    return @intCast(std.math.clamp(requested, @as(i64, lower), @as(i64, upper)));
}

pub export fn noctty_grid_compact_tab_metrics(
    tab_height: c_int,
    output_optional: ?*CompactTabMetrics,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .label_height = @max(12, tab_height),
        .action_extent = @intCast(std.math.clamp(
            @as(i64, tab_height) + 2,
            @as(i64, 24),
            @as(i64, std.math.maxInt(c_int)),
        )),
        .strip_limit = @intCast(std.math.clamp(
            @divFloor(@as(i64, tab_height) * 3, 2) + 1,
            @as(i64, 30),
            @as(i64, std.math.maxInt(c_int)),
        )),
    };
}

pub export fn noctty_grid_compact_tab_geometry(
    measurements_optional: ?*const CompactTabMeasurements,
    geometry_optional: ?*CompactTabGeometry,
) callconv(.c) void {
    const measurements = measurements_optional orelse return;
    const geometry = geometry_optional orelse return;
    const horizontal = measurements.horizontal != 0;
    geometry.* = .{
        .strip_extent = if (horizontal)
            measurements.notebook_height - measurements.page_height
        else
            measurements.notebook_width - measurements.page_width,
        .widget_extent = if (horizontal)
            measurements.tab_height
        else
            measurements.tab_width,
        .max_width = @max(measurements.tab_width, measurements.max_tab_width),
        .close_extent = @min(measurements.close_width, measurements.close_height),
        .action_extent = @min(measurements.action_width, measurements.action_height),
    };
}
pub export fn noctty_grid_settings_geometry_plan(
    workarea_width: c_int,
    workarea_height: c_int,
    output_optional: ?*SettingsGeometryPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    const width = noctty_grid_dialog_dimension(workarea_width, 980, 720, 96);
    const height = noctty_grid_dialog_dimension(workarea_height, 720, 560, 96);
    output.* = .{
        .width = noctty_grid_dialog_dimension(workarea_width, width, 1, 32),
        .height = noctty_grid_dialog_dimension(workarea_height, height, 1, 32),
        .min_width = @min(720, width),
        .min_height = @min(560, height),
        .max_width = @max(1, workarea_width),
        .max_height = @max(1, workarea_height),
    };
}

pub export fn noctty_grid_percent_dimension(
    available_px: c_int,
    percent: c_int,
    minimum_px: c_int,
) callconv(.c) c_int {
    if (available_px <= 0) return 0;
    const lower = @min(@max(minimum_px, 0), available_px);
    const requested = @divFloor(
        @as(i64, available_px) * @as(i64, std.math.clamp(percent, 0, 100)),
        100,
    );
    return @intCast(std.math.clamp(
        requested,
        @as(i64, lower),
        @as(i64, available_px),
    ));
}

pub export fn noctty_grid_window_dimensions_plan(
    workarea_width: c_int,
    workarea_height: c_int,
    output_optional: ?*WindowDimensionsPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .width = noctty_grid_percent_dimension(workarea_width, 80, 480),
        .height = noctty_grid_percent_dimension(workarea_height, 75, 320),
    };
}


pub export fn noctty_grid_scroll_target_delta(
    history_lines: u64,
    viewport_offset: u64,
    target_offset: u64,
) callconv(.c) c_int {
    const history = history_lines;
    const viewport = @min(viewport_offset, history);
    const target = @min(target_offset, history);
    if (target >= viewport) {
        return std.math.cast(c_int, target - viewport) orelse std.math.maxInt(c_int);
    }
    return -(std.math.cast(c_int, viewport - target) orelse std.math.maxInt(c_int));
}

pub export fn noctty_grid_tab_title_width(title_length: c_int) callconv(.c) c_int {
    return std.math.clamp(title_length, 4, 24);
}

pub export fn noctty_grid_search_display_ordinal(
    ordinal: u64,
    matches: c_int,
) callconv(.c) u64 {
    const count: u64 = @intCast(@max(matches, 1));
    return ordinal % count + 1;
}

pub export fn noctty_grid_selection_end(length: c_int) callconv(.c) c_int {
    return @max(0, length - 1);
}

pub export fn noctty_grid_partition_size(total: c_int, parts: c_int) callconv(.c) c_int {
    if (parts <= 0) return 2;
    return @max(2, @divTrunc(total, parts));
}

pub export fn noctty_grid_dropdown_percent(
    pixels: c_int,
    available_px: c_int,
    fallback_percent: c_int,
) callconv(.c) c_int {
    const fallback = std.math.clamp(fallback_percent, 1, 100);
    if (pixels <= 0 or available_px <= 0 or pixels > available_px) {
        return fallback;
    }
    const numerator = @as(i64, pixels) * 100 +
        @divFloor(@as(i64, available_px), 2);
    return @intCast(std.math.clamp(
        @divFloor(numerator, @as(i64, available_px)),
        1,
        100,
    ));
}

pub const sharing_allow_pairing: u32 = 1 << 0;
pub const sharing_allow_session: u32 = 1 << 1;
pub const sharing_clear_host: u32 = 1 << 2;
pub const sharing_clear_viewer: u32 = 1 << 3;

pub export fn noctty_grid_sharing_status_actions(status: c_int) callconv(.c) u32 {
    var actions: u32 = 0;
    if (status == 0 or status == 104 or status == 105 or status == 401)
        actions |= sharing_allow_pairing;
    if (status == 0 or status == 106 or status == 107 or status == 401)
        actions |= sharing_allow_session;
    if (status >= 201 and status <= 206) actions |= sharing_clear_host;
    if (status >= 301 and status <= 306) actions |= sharing_clear_viewer;
    return actions;
}

pub const SharingControlPlan = extern struct {
    enabled: u32,
    stop_label: c_int,
    stop_receive_label: c_int,
    revoke_label: c_int,
    cancel_pairing_label: c_int,
};

pub const sharing_control_confirm: u32 = 1 << 0;
pub const sharing_control_pairing: u32 = 1 << 1;
pub const sharing_control_discover: u32 = 1 << 2;
pub const sharing_control_session: u32 = 1 << 3;
pub const sharing_control_peers: u32 = 1 << 4;
pub const sharing_control_revoke_device: u32 = 1 << 5;
pub const sharing_control_stop: u32 = 1 << 6;
pub const sharing_control_cancel_pairing: u32 = 1 << 7;
pub const sharing_control_grant: u32 = 1 << 8;
pub const sharing_control_revoke: u32 = 1 << 9;
pub const sharing_control_stop_receive: u32 = 1 << 10;
pub const sharing_control_request_control: u32 = 1 << 11;
pub const sharing_control_reconnect: u32 = 1 << 12;
pub const sharing_control_retry_save: u32 = 1 << 13;

pub export fn noctty_grid_sharing_control_plan(
    status: c_int, active_peer_count: c_int,
    output: *SharingControlPlan,
) callconv(.c) void {
    const actions = noctty_grid_sharing_status_actions(status);
    var enabled: u32 = 0;
    if (status == 102) enabled |= sharing_control_confirm;
    if ((actions & sharing_allow_pairing) != 0)
        enabled |= sharing_control_pairing;
    if (status == 0 or status == 401)
        enabled |= sharing_control_discover;
    if ((actions & sharing_allow_session) != 0 and active_peer_count > 0)
        enabled |= sharing_control_session;
    if (active_peer_count > 0)
        enabled |= sharing_control_peers | sharing_control_revoke_device;
    if ((actions & sharing_clear_host) != 0)
        enabled |= sharing_control_stop;
    if (status == 101 or status == 102 or status == 104 or
        status == 105 or status == 400)
        enabled |= sharing_control_cancel_pairing;
    if (status == 203) enabled |= sharing_control_grant;
    if (status == 203 or status == 204)
        enabled |= sharing_control_revoke;
    if ((actions & sharing_clear_viewer) != 0)
        enabled |= sharing_control_stop_receive;
    if (status == 302) enabled |= sharing_control_request_control;
    if (status == 305 or status == 306)
        enabled |= sharing_control_reconnect;
    if (status == 106) enabled |= sharing_control_retry_save;
    output.* = .{
        .enabled = enabled,
        .stop_label = if (status == 205 or status == 206) 1 else 0,
        .stop_receive_label = if (status == 305 or status == 306) 1 else 0,
        .revoke_label = if (status == 203) 1 else 0,
        .cancel_pairing_label = if (status == 104 or status == 105) 1 else 0,
    };
}

pub const SharingStatusTextPlan = extern struct {
    length: c_int,
    is_error: c_int,
};

fn copyBoundedText(
    output: ?[*]u8,
    capacity: usize,
    text: []const u8,
) c_int {
    const target = output orelse return 0;
    if (capacity == 0) return 0;
    const length = @min(text.len, capacity - 1);
    @memcpy(target[0..length], text[0..length]);
    target[length] = 0;
    return @intCast(length);
}

fn themeDisplayLabel(name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "noctty-dark")) return "NOCTTY Dark";
    if (std.mem.eql(u8, name, "paseo-black-zinc")) return "Paseo Black Zinc";
    if (std.mem.eql(u8, name, "noctty-high-contrast"))
        return "NOCTTY High Contrast";
    return name;
}

pub export fn noctty_grid_theme_display_label(
    name: ?[*]const u8,
    name_length: usize,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const pointer = name orelse return 0;
    if (name_length > 256) return 0;
    return copyBoundedText(
        output,
        capacity,
        themeDisplayLabel(pointer[0..name_length]),
    );
}


pub export fn noctty_grid_sharing_status_text(
    status: c_int,
    sas: u32,
    port: u16,
    alias: [*]const u8,
    alias_length: usize,
    endpoint: [*]const u8,
    endpoint_length: usize,
    discovered_port: u16,
    discovered: c_int,
    output: ?[*]u8,
    capacity: usize,
    plan: ?*SharingStatusTextPlan,
) callconv(.c) c_int {
    var buffer: [640]u8 = undefined;
    const bounded_alias = alias[0..@min(alias_length, buffer.len)];
    const bounded_endpoint = endpoint[0..@min(endpoint_length, buffer.len)];
    const message: []const u8 = if (status == 101)
        "Pairing connection in progress…"
    else if (status == 102)
        std.fmt.bufPrint(&buffer, "Compare on both devices: {d:0>6}. Confirm only if identical.", .{sas}) catch return 0
    else if (status == 104)
        "Pairing rejected."
    else if (status == 105)
        "Pairing failed."
    else if (status == 106)
        "Paired-device changes are active for this run but could not be saved. Check configuration-directory permissions and retry."
    else if (status == 107)
        "The paired-device store is full. Revoke an unused device before pairing a new one."
    else if (status == 201)
        std.fmt.bufPrint(&buffer, "Sharing listener ready on TCP port {d}.", .{port}) catch return 0
    else if (status == 202)
        "Paired viewer connected. View-only."
    else if (status == 203)
        "Viewer requests control. Grant only if expected."
    else if (status == 204)
        "Remote control granted for this share only."
    else if (status == 205)
        "Sharing stopped. Close the sharing session to reset."
    else if (status == 206)
        "Sharing failed. Close the sharing session to reset."
    else if (status < 0)
        "Sharing state synchronization failed. Close and reopen NOCTTY."
    else if (status == 301)
        "Connecting to paired terminal…"
    else if (status == 302)
        "Receiving paired terminal. View-only."
    else if (status == 303)
        "Control requested. Waiting for host approval."
    else if (status == 304)
        "Remote control granted for this connection."
    else if (status == 305)
        "Remote terminal closed. Close this remote session or reconnect."
    else if (status == 306)
        "Remote terminal connection failed. Close this remote session or reconnect."
    else if (status == 400)
        "Discovering pairing listeners on this LAN…"
    else if (status == 401 and discovered != 0)
        std.fmt.bufPrint(
            &buffer,
            "Untrusted LAN hint: {s} at {s}:{d}. Review it, connect, and trust only after the six-digit code matches.",
            .{ bounded_alias, bounded_endpoint, discovered_port },
        ) catch return 0
    else if (status == 401)
        "LAN listener discovery completed."
    else
        "Idle. Pair a device or share with a paired device.";
    const is_error = @intFromBool(
        status == 104 or status == 105 or status == 106 or
            status == 107 or status == 206 or status == 306 or status < 0,
    );
    const length = copyBoundedText(output, capacity, message);
    if (plan) |result| result.* = .{ .length = length, .is_error = is_error };
    return length;
}

pub const CompactTabTextInput = extern struct {
    title: ?[*]const u8,
    title_length: usize,
    filter: ?[*]const u8,
    filter_length: usize,
    status_color: ?[*]const u8,
    status_color_length: usize,
    pane_count: u32,
    selected_count: u32,
    filter_active: c_int,
    attention: c_int,
    dirty: c_int,
    broadcast: c_int,
    active: c_int,
    tab_color_rgb: u32,
    tab_color_preset: c_int,
    tab_color_shade: c_int,
};

pub const CompactTabTextPlan = extern struct {
    markup_length: c_int,
    tooltip_length: c_int,
    close_name_length: c_int,
    title_truncated: c_int,
};

fn compactTabInputSlice(pointer: ?[*]const u8, length: usize) []const u8 {
    const value = pointer orelse return "";
    return value[0..@min(length, 4096)];
}
pub const SmartFilterTextPlan = extern struct {
    empty_length: c_int,
    label_length: c_int,
    tooltip_length: c_int,
};
pub const ShortcutTextPlan = extern struct {
    label_length: c_int,
    tooltip_length: c_int,
};

fn compactTabUtf8Continuation(byte: u8) bool {
    return (byte & 0xc0) == 0x80;
}

fn compactTabUtf8ByteLength(input: []const u8, index: usize) usize {
    const byte = input[index];
    if (byte < 0x80) return 1;
    if ((byte & 0xe0) == 0xc0 and index + 2 <= input.len and
        compactTabUtf8Continuation(input[index + 1]))
        return 2;
    if ((byte & 0xf0) == 0xe0 and index + 3 <= input.len and
        compactTabUtf8Continuation(input[index + 1]) and
        compactTabUtf8Continuation(input[index + 2]))
        return 3;
    if ((byte & 0xf8) == 0xf0 and index + 4 <= input.len and
        compactTabUtf8Continuation(input[index + 1]) and
        compactTabUtf8Continuation(input[index + 2]) and
        compactTabUtf8Continuation(input[index + 3]))
        return 4;
    return 1;
}

fn compactTabUtf8Count(input: []const u8) usize {
    var count: usize = 0;
    var index: usize = 0;
    while (index < input.len) : (count += 1)
        index += compactTabUtf8ByteLength(input, index);
    return count;
}

fn compactTabMarkupEscape(
    input: []const u8,
    max_codepoints: usize,
    output: []u8,
) ?[]const u8 {
    var output_length: usize = 0;
    var index: usize = 0;
    var codepoints: usize = 0;
    while (index < input.len and codepoints < max_codepoints) {
        const byte_length = compactTabUtf8ByteLength(input, index);
        if (byte_length == 1) {
            const escaped: []const u8 = switch (input[index]) {
                '&' => "&amp;",
                '<' => "&lt;",
                '>' => "&gt;",
                else => input[index .. index + 1],
            };
            if (output_length + escaped.len > output.len) return null;
            @memcpy(output[output_length .. output_length + escaped.len], escaped);
            output_length += escaped.len;
        } else {
            if (output_length + byte_length > output.len) return null;
            @memcpy(
                output[output_length .. output_length + byte_length],
                input[index .. index + byte_length],
            );
            output_length += byte_length;
        }
        index += byte_length;
        codepoints += 1;
    }
    return output[0..output_length];
}

fn compactTabColorUsesDarkText(rgb: u32) bool {
    const red: u64 = (rgb >> 16) & 0xff;
    const green: u64 = (rgb >> 8) & 0xff;
    const blue: u64 = rgb & 0xff;
    return red * red * 2126 + green * green * 7152 + blue * blue * 722 >= 116394750;
}

fn compactTabFormat(
    output: ?[*]u8,
    capacity: usize,
    comptime format: []const u8,
    args: anytype,
) c_int {
    const target = output orelse return 0;
    if (capacity == 0) return 0;
    const formatted = std.fmt.bufPrint(target[0 .. capacity - 1], format, args) catch return 0;
    target[formatted.len] = 0;
    return @intCast(formatted.len);
}

pub export fn noctty_grid_compact_tab_text(
    input: *const CompactTabTextInput,
    markup: ?[*]u8,
    markup_capacity: usize,
    tooltip: ?[*]u8,
    tooltip_capacity: usize,
    close_name: ?[*]u8,
    close_name_capacity: usize,
    plan: ?*CompactTabTextPlan,
) callconv(.c) c_int {
    var result = CompactTabTextPlan{
        .markup_length = 0,
        .tooltip_length = 0,
        .close_name_length = 0,
        .title_truncated = 0,
    };
    const title = compactTabInputSlice(input.title, input.title_length);
    const filter = compactTabInputSlice(input.filter, input.filter_length);
    const status_color = compactTabInputSlice(
        input.status_color,
        input.status_color_length,
    );
    const title_codepoints = compactTabUtf8Count(title);
    const title_truncated = title_codepoints > 18;
    var title_storage: [2048]u8 = undefined;
    const escaped_title = compactTabMarkupEscape(
        title,
        if (title_truncated) 17 else title_codepoints,
        &title_storage,
    ) orelse return 0;
    var filter_storage: [4096]u8 = undefined;
    const escaped_filter = if (input.filter_active != 0)
        compactTabMarkupEscape(filter, compactTabUtf8Count(filter), &filter_storage) orelse return 0
    else
        "";
    var title_color_storage: [64]u8 = undefined;
    const title_color_attribute: []const u8 = if (input.tab_color_rgb != 0)
        std.fmt.bufPrint(
            &title_color_storage,
            " foreground='{s}'",
            .{if (compactTabColorUsesDarkText(input.tab_color_rgb)) "#11151b" else "#ffffff"},
        ) catch return 0
    else
        "";
    var filter_suffix_storage: [4096]u8 = undefined;
    const filter_suffix: []const u8 = if (input.filter_active != 0)
        std.fmt.bufPrint(
            &filter_suffix_storage,
            " <span foreground='#b8a7ff'>⌕ {s}</span>",
            .{escaped_filter},
        ) catch return 0
    else
        "";
    var selection_suffix_storage: [64]u8 = undefined;
    const selection_suffix: []const u8 = if (input.selected_count > 0)
        std.fmt.bufPrint(
            &selection_suffix_storage,
            " <span foreground='#f6c85f'>⌁{d}</span>",
            .{input.selected_count},
        ) catch return 0
    else
        "";
    var pane_suffix_storage: [32]u8 = undefined;
    const pane_suffix: []const u8 = if (input.pane_count > 1)
        std.fmt.bufPrint(&pane_suffix_storage, " ×{d}", .{input.pane_count}) catch return 0
    else
        "";
    var tab_color_tooltip_storage: [128]u8 = undefined;
    const tab_color_tooltip: []const u8 = if (input.tab_color_rgb != 0)
        std.fmt.bufPrint(
            &tab_color_tooltip_storage,
            " · tab color {s}, {s}",
            .{
                std.mem.span(noctty_grid_tab_color_preset_name(input.tab_color_preset)),
                std.mem.span(noctty_grid_tab_color_shade_name(input.tab_color_shade)),
            },
        ) catch return 0
    else
        "";
    result.markup_length = compactTabFormat(
        markup,
        markup_capacity,
        "<span size='small' weight='{s}'{s}>{s}{s}{s}</span> <span foreground='{s}'>●</span>{s}{s}{s}{s}",
        .{
            if (input.active != 0) "bold" else "normal",
            title_color_attribute,
            escaped_title,
            if (title_truncated) "…" else "",
            pane_suffix,
            status_color,
            if (input.dirty != 0) " <span foreground='#e8a85c'>◆</span>" else "",
            filter_suffix,
            selection_suffix,
            if (input.broadcast != 0) " <span foreground='#70d6a7'>B</span>" else "",
        },
    );
    if (result.markup_length <= 0) return 0;
    result.tooltip_length = compactTabFormat(
        tooltip,
        tooltip_capacity,
        "{s} · {d} pane{s}{s}{s}{s}{s}{s}{s}",
        .{
            title,
            input.pane_count,
            if (input.pane_count == 1) "" else "s",
            if (input.attention != 0) " · attention requested" else "",
            if (input.dirty != 0) " · unsaved workspace" else "",
            if (input.filter_active != 0) " · Smart Tab filter active" else "",
            if (input.selected_count > 0) " · selection group active" else "",
            if (input.broadcast != 0) " · broadcast on" else "",
            tab_color_tooltip,
        },
    );
    if (result.tooltip_length <= 0) return 0;
    result.close_name_length = compactTabFormat(
        close_name,
        close_name_capacity,
        "Close tab: {s}",
        .{title},
    );
    if (result.close_name_length <= 0) return 0;
    result.title_truncated = @intFromBool(title_truncated);
    if (plan) |output| output.* = result;
    return 1;
}

pub export fn noctty_grid_status_feedback_message(kind: c_int) callconv(.c) [*:0]const u8 {
    return switch (kind) {
        1 => "Could not scroll the terminal history.",
        2 => "Could not paste into every target terminal.",
        3 => "Could not copy the terminal selection.",
        4 => "Could not update the terminal state.",
        5 => "Could not send Ctrl+L to the terminal.",
        6 => "Terminal input flush failed.",
        7 => "Could not save the workspace recovery snapshot.",
        8 => "Could not interrupt the terminal.",
        9 => "Could not deliver input to every target terminal.",
        10 => "Could not open the link in the default browser.",
        11 => "This link type is not allowed.",
        12 => "Link copied.",
        13 => "The application did not accept pointer input.",
        14 => "Broadcast mode disabled.",
        15 => "The application did not accept mouse-wheel input.",
        16 => "Could not deliver alternate-screen scroll input.",
        17 => "Could not deliver composed text to every terminal.",
        else => "",
    };
}

pub export fn noctty_grid_smart_filter_text(
    active: c_int,
    tag: ?[*]const u8,
    tag_length: usize,
    empty_text: ?[*]u8,
    empty_capacity: usize,
    label: ?[*]u8,
    label_capacity: usize,
    tooltip: ?[*]u8,
    tooltip_capacity: usize,
    plan: ?*SmartFilterTextPlan,
) callconv(.c) c_int {
    const tag_text = compactTabInputSlice(tag, tag_length);
    var result = SmartFilterTextPlan{
        .empty_length = 0,
        .label_length = 0,
        .tooltip_length = 0,
    };
    if (active != 0) {
        result.empty_length = compactTabFormat(
            empty_text,
            empty_capacity,
            "No panes match Smart Tab tag: {s}",
            .{tag_text},
        );
        if (result.empty_length <= 0) return 0;
        result.label_length = compactTabFormat(
            label,
            label_capacity,
            "Tag: {s}",
            .{tag_text},
        );
    } else {
        result.label_length = compactTabFormat(label, label_capacity, "Filter", .{});
    }
    if (result.label_length <= 0) return 0;
    result.tooltip_length = compactTabFormat(
        tooltip,
        tooltip_capacity,
        "{s}",
        .{if (active != 0)
            "Smart Tab: clear pane tag filter"
        else
            "Smart Tab: show all panes"},
    );
    if (result.tooltip_length <= 0) return 0;
    if (plan) |output| output.* = result;
    return 1;
}

pub export fn noctty_grid_cycle_feedback_text(
    kind: c_int,
    index: c_int,
    count: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const prefix = switch (kind) {
        0 => "Pane",
        1 => "Tab",
        else => return 0,
    };
    return compactTabFormat(output, capacity, "{s} {d} / {d}", .{
        prefix,
        index,
        count,
    });
}

pub export fn noctty_grid_attention_notification_text(
    pane_id: u64,
    attention: c_int,
    exit_code: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    return if (attention != 0)
        compactTabFormat(
            output,
            capacity,
            "Pane {d} requested attention",
            .{pane_id},
        )
    else
        compactTabFormat(
            output,
            capacity,
            "Pane {d} exited with code {d}",
            .{ pane_id, exit_code },
        );
}

pub export fn noctty_grid_tab_title_text(
    model_title: ?[*]const u8,
    model_length: usize,
    display_title: ?[*]const u8,
    display_length: usize,
    directory_name: ?[*]const u8,
    directory_length: usize,
    page_number: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const model = compactTabInputSlice(model_title, model_length);
    const display = compactTabInputSlice(display_title, display_length);
    const directory = compactTabInputSlice(directory_name, directory_length);
    if (model.len > 0)
        return compactTabFormat(output, capacity, "{s}", .{model});
    if (display.len > 0)
        return compactTabFormat(output, capacity, "{s}", .{display});
    if (directory.len > 0)
        return compactTabFormat(output, capacity, "{s}", .{directory});
    return compactTabFormat(
        output,
        capacity,
        "Tab {d}",
        .{@max(page_number, 1)},
    );
}

pub export fn noctty_grid_pane_zoom_feedback_text(
    pane_id: u64,
    title: ?[*]const u8,
    title_length: usize,
    display_title: ?[*]const u8,
    display_length: usize,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const title_text = if (title) |pointer|
        std.mem.trim(u8, pointer[0..@min(title_length, 512)], " \t\n\r")
    else
        "";
    const display = compactTabInputSlice(display_title, display_length);
    const name = if (title_text.len > 0)
        title_text
    else if (display.len > 0)
        display
    else
        "";
    var name_storage: [64]u8 = undefined;
    const fallback = if (name.len > 0)
        name
    else
        std.fmt.bufPrint(&name_storage, "Pane {d}", .{pane_id}) catch return 0;
    return compactTabFormat(
        output,
        capacity,
        "Session {s} is focused. Double click again on pane to go back.",
        .{fallback},
    );
}

pub export fn noctty_grid_shortcut_feedback_message(
    kind: c_int,
) callconv(.c) [*:0]const u8 {
    return switch (kind) {
        0 => "Shortcut is unavailable. Press another key or Esc.",
        1 => "Use F1-F12, or add Ctrl, Alt, or Super. Esc cancels.",
        2 => "Checking shortcut availability…",
        else => "",
    };
}

pub export fn noctty_grid_note_overlay_label(
    text: ?[*]const u8,
    text_length: usize,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    return compactTabFormat(
        output,
        capacity,
        "Note · {s}",
        .{compactTabInputSlice(text, text_length)},
    );
}

pub export fn noctty_grid_window_title_text(
    mode: c_int,
    title: ?[*]const u8,
    title_length: usize,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const title_text = compactTabInputSlice(title, title_length);
    if (title_text.len == 0) return 0;
    const prefix = switch (mode) {
        0 => "NOCTTY Dropdown — ",
        2 => "NOCTTY Zen — ",
        else => "",
    };
    return compactTabFormat(output, capacity, "{s}{s}", .{ prefix, title_text });
}

pub export fn noctty_grid_close_confirmation_text(
    scope: ?[*]const u8,
    scope_length: usize,
    busy_count: u32,
    title: ?[*]u8,
    title_capacity: usize,
    detail: ?[*]u8,
    detail_capacity: usize,
) callconv(.c) c_int {
    const scope_text = compactTabInputSlice(scope, scope_length);
    const title_text = if (std.mem.eql(u8, scope_text, "application"))
        "Close NOCTTY?"
    else if (std.mem.eql(u8, scope_text, "tab"))
        "Close tab?"
    else
        "Close terminal?";
    const title_length = compactTabFormat(title, title_capacity, "{s}", .{title_text});
    if (title_length <= 0) return 0;
    const detail_length = if (busy_count == 0)
        compactTabFormat(
            detail,
            detail_capacity,
            "Closing NOCTTY ends all terminal sessions in this window.",
            .{},
        )
    else if (busy_count == 1)
        compactTabFormat(
            detail,
            detail_capacity,
            "A foreground process is still running. Closing will stop it and its child processes.",
            .{},
        )
    else
        compactTabFormat(
            detail,
            detail_capacity,
            "{d} terminals have foreground processes. Closing will stop them and their child processes.",
            .{busy_count},
        );
    if (detail_length <= 0) return 0;
    return 1;
}

pub export fn noctty_grid_layout_prompt_title(
    extra_count: u32,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    return compactTabFormat(
        output,
        capacity,
        "Move {d} terminal session{s} to a new tab?",
        .{ extra_count, if (extra_count == 1) "" else "s" },
    );
}

pub export fn noctty_grid_find_status_text(
    state: c_int,
    ordinal: u64,
    matches: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    return switch (state) {
        0 => compactTabFormat(output, capacity, "Type to search scrollback", .{}),
        1 => compactTabFormat(
            output,
            capacity,
            "{d} / {d}  ·  Enter for previous",
            .{ ordinal, matches },
        ),
        else => compactTabFormat(output, capacity, "No matches", .{}),
    };
}

pub export fn noctty_grid_shortcuts_text(
    encoded: u32,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    var shortcut_storage: [64]u8 = undefined;
    const shortcut_length = noctty_grid_shortcut_label(
        encoded, &shortcut_storage, shortcut_storage.len);
    if (shortcut_length <= 0) return 0;
    return compactTabFormat(
        output,
        capacity,
        "Ctrl+Shift+P   Command palette\n" ++
            "Ctrl+Shift+F   Find in scrollback\n" ++
            "Ctrl+Shift+N   Quick note\n" ++
            "Ctrl+Shift+G   Smart Tab filter\n" ++
            "Ctrl+Shift+Y   Tag selected panes\n" ++
            "Ctrl+Shift+Z   Zoom / restore pane\n" ++
            "Ctrl+Tab       Next terminal pane\n" ++
            "Ctrl+Shift+Tab Next tab / Smart Tab\n" ++
            "Hold Alt       Show note in each pane\n" ++
            "Alt+Arrow      Focus pane by direction\n" ++
            "Alt+wheel      Previous / next pane\n" ++
            "Ctrl+Alt+wheel Previous / next tab\n" ++
            "Ctrl+wheel     Pane font up / down\n" ++
            "Shift+PageUp   Scroll terminal history up\n" ++
            "Shift+PageDown Scroll terminal history down\n" ++
            "Shift+Home     Oldest terminal history\n" ++
            "Shift+End      Live terminal output\n" ++
            "Ctrl+C         Interrupt active pane\n" ++
            "Ctrl+D         Close active pane\n" ++
            "Ctrl+PageUp    Previous tab\n" ++
            "Ctrl+PageDown  Next tab\n" ++
            "Ctrl+Shift+W   Close tab\n" ++
            "Ctrl+Shift+R   Rename active tab\n" ++
            "Ctrl+Shift+T   Reopen last tab / new tab\n" ++
            "Ctrl+Shift+S   Split down\n" ++
            "Ctrl+Shift+L   Split left\n" ++
            "Ctrl+Alt+B     Enable / disable broadcast input\n" ++
            "Ctrl+Alt+=     Lighten active tab color\n" ++
            "Ctrl+Alt+-     Darken active tab color\n" ++
            "Ctrl+Shift+K   This shortcut card\n" ++
            "Double-click   Zoom pane\n" ++
            "{s:<15} Show / hide NOCTTY",
        .{shortcut_storage[0..@intCast(shortcut_length)]},
    );
}

pub export fn noctty_grid_sharing_peer_label(
    alias: ?[*]const u8,
    alias_length: usize,
    endpoint: ?[*]const u8,
    endpoint_length: usize,
    port: u32,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    return compactTabFormat(
        output,
        capacity,
        "{s} — {s}:{d}",
        .{
            compactTabInputSlice(alias, alias_length),
            compactTabInputSlice(endpoint, endpoint_length),
            port,
        },
    );
}

pub export fn noctty_grid_sharing_tab_label(
    title: ?[*]const u8,
    title_length: usize,
    tab_id: u64,
    active: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const title_text = compactTabInputSlice(title, title_length);
    if (title_text.len == 0)
        return compactTabFormat(output, capacity, "Tab {d}{s}", .{
            tab_id,
            if (active != 0) " (host active)" else "",
        });
    return compactTabFormat(output, capacity, "{s} — tab {d}{s}", .{
        title_text,
        tab_id,
        if (active != 0) " (host active)" else "",
    });
}

pub export fn noctty_grid_sharing_pane_label(
    title: ?[*]const u8,
    title_length: usize,
    pane_id: u64,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const title_text = compactTabInputSlice(title, title_length);
    if (title_text.len == 0)
        return compactTabFormat(output, capacity, "Pane {d}", .{pane_id});
    return compactTabFormat(output, capacity, "{s} — pane {d}", .{
        title_text,
        pane_id,
    });
}

pub export fn noctty_grid_sharing_revoke_detail(
    peer: ?[*]const u8,
    peer_length: usize,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    return compactTabFormat(
        output,
        capacity,
        "{s} will lose sharing access immediately. Pairing it again will " ++
            "require a new matching six-digit confirmation.",
        .{compactTabInputSlice(peer, peer_length)},
    );
}

const launch_profile_field_max: usize = 64 * 1024;

fn launchProfileInput(
    pointer: ?[*]const u8,
    length: usize,
) ?[]const u8 {
    if (length > launch_profile_field_max) return null;
    if (pointer) |value| return value[0..length];
    return if (length == 0) "" else null;
}

fn appendLaunchProfileLength(total: *usize, value: usize) bool {
    total.* = std.math.add(usize, total.*, value) catch return false;
    return true;
}

fn launchProfilePayloadLength(
    action: c_int,
    name: []const u8,
    shell: []const u8,
    command: []const u8,
    cwd: []const u8,
    ssh_target: []const u8,
    scrollback: c_int,
) ?usize {
    var total: usize = std.fmt.count("{d}", .{scrollback});
    const fields = [_][]const u8{
        name, shell, command, cwd, ssh_target,
    };
    const first_field: usize = if (action == 16) 0 else 1;
    for (fields[first_field..], 0..) |field, index| {
        if (index > 0 and !appendLaunchProfileLength(&total, 1))
            return null;
        if (!appendLaunchProfileLength(&total, field.len))
            return null;
    }
    if (!appendLaunchProfileLength(&total, 1)) return null;
    return total;
}

pub export fn noctty_grid_launch_profile_payload(
    action: c_int,
    name: ?[*]const u8,
    name_length: usize,
    shell: ?[*]const u8,
    shell_length: usize,
    command: ?[*]const u8,
    command_length: usize,
    cwd: ?[*]const u8,
    cwd_length: usize,
    ssh_target: ?[*]const u8,
    ssh_target_length: usize,
    scrollback: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const name_text = launchProfileInput(name, name_length) orelse return -1;
    const shell_text = launchProfileInput(shell, shell_length) orelse return -1;
    const command_text = launchProfileInput(command, command_length) orelse return -1;
    const cwd_text = launchProfileInput(cwd, cwd_length) orelse return -1;
    const ssh_text = launchProfileInput(ssh_target, ssh_target_length) orelse return -1;
    const total = launchProfilePayloadLength(
        action, name_text, shell_text, command_text, cwd_text, ssh_text, scrollback,
    ) orelse return -1;
    const result: c_int = @intCast(total);
    if (output) |target| {
        if (capacity <= total) return -1;
        const payload = if (action == 16)
            std.fmt.bufPrint(
                target[0..total],
                "{s}\t{s}\t{s}\t{s}\t{s}\t{d}",
                .{ name_text, shell_text, command_text, cwd_text, ssh_text, scrollback },
            ) catch return -1
        else
            std.fmt.bufPrint(
                target[0..total],
                "{s}\t{s}\t{s}\t{s}\t{d}",
                .{ shell_text, command_text, cwd_text, ssh_text, scrollback },
            ) catch return -1;
        if (payload.len != total) return -1;
        target[total] = 0;
    }
    return result;
}

pub export fn noctty_grid_launch_profile_name_valid(
    text: ?[*]const u8,
    length: usize,
) callconv(.c) c_int {
    const value = launchProfileInput(text, length) orelse return 0;
    if (value.len == 0) return 0;
    return @intFromBool(
        !std.ascii.isWhitespace(value[0]) and
            !std.ascii.isWhitespace(value[value.len - 1]),
    );
}

pub export fn noctty_grid_launch_profile_status_message(
    kind: c_int,
) callconv(.c) [*:0]const u8 {
    return switch (kind) {
        0 => "Launch profile saved for new sessions.",
        1 => "Profile was not saved. Check absolute paths, environment entries, and fields required by the selected launch type.",
        2 => "Named launch profile saved and selected.",
        3 => "Enter a profile name without leading or trailing spaces.",
        4 => "The selected profile could not be deleted.",
        5 => "Named launch profile deleted.",
        else => "",
    };
}

pub export fn noctty_grid_launch_profile_controls_plan(
    kind: c_int,
    output_optional: ?*LaunchProfileControlsPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    const resolved = std.math.clamp(kind, 0, 4);
    output.* = .{
        .kind = resolved,
        .command_sensitive = @intFromBool(resolved == 1),
        .ssh_target_sensitive = @intFromBool(resolved >= 2),
    };
}


pub export fn noctty_grid_theme_apply_status_text(
    persistence_failed: c_int,
    label: ?[*]const u8,
    label_length: usize,
    variant: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const theme_label = if (variant == 0) "Dark" else "Light";
    return if (persistence_failed != 0)
        compactTabFormat(
            output,
            capacity,
            "Using {s} — {s} for this session; the selection could not be saved.",
            .{ compactTabInputSlice(label, label_length), theme_label },
        )
    else
        compactTabFormat(
            output,
            capacity,
            "Using {s} — {s}.",
            .{ compactTabInputSlice(label, label_length), theme_label },
        );
}

pub export fn noctty_grid_decimal_text(
    value: i64,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    return compactTabFormat(output, capacity, "{d}", .{value});
}

pub export fn noctty_grid_terminal_accessible_name(
    pane_id: u64,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    return compactTabFormat(
        output,
        capacity,
        "Terminal pane {d}",
        .{pane_id},
    );
}

pub export fn noctty_grid_pane_tooltip(
    pane_id: u64,
    status: ?[*]const u8,
    status_length: usize,
    tags: ?[*]const u8,
    tags_length: usize,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const status_text = if (status) |pointer|
        pointer[0..@min(status_length, 256)]
    else
        "";
    const tag_text = if (tags) |pointer|
        pointer[0..@min(tags_length, 256)]
    else
        "";
    return if (tag_text.len > 0)
        compactTabFormat(
            output,
            capacity,
            "Pane {d} · {s} · {s}",
            .{ pane_id, status_text, tag_text },
        )
    else
        compactTabFormat(
            output,
            capacity,
            "Pane {d} · {s}",
            .{ pane_id, status_text },
        );
}

fn appendRecoveryText(
    storage: []u8,
    length: *usize,
    text: []const u8,
) bool {
    if (length.* + text.len > storage.len) return false;
    @memcpy(storage[length.* .. length.* + text.len], text);
    length.* += text.len;
    return true;
}

pub export fn noctty_grid_recovery_notice_text(
    flags: u32,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    if (flags == 0) return 0;
    var message: [1024]u8 = undefined;
    var length: usize = 0;
    const append = struct {
        fn call(storage: []u8, size: *usize, text: []const u8) bool {
            if (size.* > 0 and !appendRecoveryText(storage, size, " ")) return false;
            return appendRecoveryText(storage, size, text);
        }
    }.call;
    if ((flags & (1 << 0)) != 0) {
        if (!append(&message, &length,
            "Settings were damaged. Last-known-good settings were loaded.")) return 0;
    } else if ((flags & (1 << 1)) != 0) {
        if (!append(&message, &length,
            "Settings were damaged. Safe defaults were loaded.")) return 0;
    }
    if ((flags & (1 << 2)) != 0) {
        if (!append(&message, &length,
            "The last-known-good theme library was restored.")) return 0;
    } else if ((flags & (1 << 3)) != 0) {
        if (!append(&message, &length,
            "Built-in themes are available while the damaged library is retained.")) return 0;
    }
    if ((flags & (1 << 4)) != 0) {
        if (!append(&message, &length,
            "The damaged workspace snapshot was skipped; a clean workspace was opened.")) return 0;
    }
    return copyBoundedText(output, capacity, message[0..length]);
}


pub export fn noctty_grid_bracketed_paste_marker(
    kind: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const target = output orelse return 0;
    const marker = switch (kind) {
        0 => "\x1b[200~",
        1 => "\x1b[201~",
        else => return 0,
    };
    if (capacity < marker.len) return 0;
    @memcpy(target[0..marker.len], marker);
    return @intCast(marker.len);
}

pub export fn noctty_grid_sharing_key_sequence(
    kind: c_int,
    application_cursor: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const target = output orelse return 0;
    const key: KeyEncoding.Key = switch (kind) {
        0 => .enter,
        1 => .backspace,
        2 => .tab,
        3 => .backtab,
        4 => .escape,
        5 => .up,
        6 => .down,
        7 => .right,
        8 => .left,
        else => return 0,
    };
    return @intCast(KeyEncoding.encode(
        key,
        .{ .application_cursor = application_cursor != 0 },
        target[0..capacity],
    ));
}

pub export fn noctty_grid_sharing_arrow_sequence(
    arrow: c_int,
    modifier: c_int,
    application_cursor: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const target = output orelse return 0;
    if (arrow < 0 or arrow > 3 or modifier < 1) return 0;
    const key: KeyEncoding.Key = switch (arrow) {
        0 => .up,
        1 => .down,
        2 => .right,
        3 => .left,
        else => unreachable,
    };
    return @intCast(KeyEncoding.encode(
        key,
        .{ .application_cursor = application_cursor != 0, .modifier = modifier },
        target[0..@min(capacity, 8)],
    ));
}

pub export fn noctty_grid_sharing_extended_key_sequence(
    kind: c_int,
    modifier: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const target = output orelse return 0;
    if (modifier < 1) return 0;
    const key: KeyEncoding.Key = switch (kind) {
        0 => .home,
        1 => .end,
        2 => .insert,
        3 => .delete,
        4 => .page_up,
        5 => .page_down,
        6 => .f1,
        7 => .f2,
        8 => .f3,
        9 => .f4,
        10 => .f5,
        11 => .f6,
        12 => .f7,
        13 => .f8,
        14 => .f9,
        15 => .f10,
        16 => .f11,
        17 => .f12,
        else => return 0,
    };
    return @intCast(KeyEncoding.encode(
        key,
        .{ .modifier = modifier },
        target[0..capacity],
    ));
}
pub export fn noctty_grid_sharing_text_sequence(
    alt: c_int,
    input: ?[*]const u8,
    length: usize,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const source = input orelse return 0;
    const target = output orelse return 0;
    const prefix_length: usize = if (alt != 0) 1 else 0;
    if (length == 0 or length > std.math.maxInt(usize) - prefix_length or
        capacity < prefix_length + length)
        return 0;
    if (prefix_length != 0) target[0] = 0x1b;
    @memcpy(target[prefix_length .. prefix_length + length], source[0..length]);
    return @intCast(prefix_length + length);
}

pub export fn noctty_grid_sharing_paste_allowed(length: usize) callconv(.c) c_int {
    return @intFromBool(length <= 64 * 1024);
}

pub export fn noctty_grid_sharing_paste_chunk_size(remaining: usize) usize {
    return @min(remaining, 16 * 1024);
}

pub export fn noctty_grid_damage_buffer_capacity(rows: c_int) usize {
    return @intCast(@max(rows, 1));
}

pub export fn noctty_grid_selection_copy_capacity_next(current: usize) usize {
    const maximum = 4 * 1024 * 1024;
    if (current >= maximum) return maximum;
    return @min(current * 2, maximum);
}

pub export fn noctty_grid_sharing_preview_scroll_lines(
    direction: c_int,
    delta_y: f64,
) callconv(.c) c_int {
    return switch (direction) {
        0 => 3,
        1 => -3,
        4 => if (delta_y < 0.0) 3 else if (delta_y > 0.0) -3 else 0,
        else => 0,
    };
}

pub export fn noctty_grid_sharing_index(
    text: ?[*]const u8,
    length: usize,
) callconv(.c) c_int {
    const bytes = text orelse return -1;
    if (length == 0) return -1;
    var value: usize = 0;
    const maximum: usize = @intCast(std.math.maxInt(c_int));
    for (bytes[0..length]) |byte| {
        if (byte < '0' or byte > '9') return -1;
        const digit = byte - '0';
        if (value > (maximum - digit) / 10) return -1;
        value = value * 10 + digit;
    }
    return @intCast(value);
}

pub export fn noctty_grid_sharing_index_text(
    index: c_int,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const target = output orelse return 0;
    if (index < 0 or capacity == 0) return 0;
    var buffer: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    writer.print("{d}", .{index}) catch return 0;
    const text = writer.buffered();
    if (text.len + 1 > capacity) return 0;
    @memcpy(target[0..text.len], text);
    target[text.len] = 0;
    return @intCast(text.len);
}

pub export fn noctty_grid_sharing_pane_hit(
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    pane_x: f64,
    pane_y: f64,
    pane_width: f64,
    pane_height: f64,
) callconv(.c) c_int {
    if (width <= 0.0 or height <= 0.0 or pane_width <= 0.0 or pane_height <= 0.0)
        return 0;
    const normalized_x = x * 1_000_000.0 / width;
    const normalized_y = y * 1_000_000.0 / height;
    return @intFromBool(
        normalized_x >= pane_x and normalized_x < pane_x + pane_width and
            normalized_y >= pane_y and normalized_y < pane_y + pane_height,
    );
}

pub export fn noctty_grid_theme_color_channel(rgb: u32, channel: c_int) f64 {
    if (channel < 0 or channel > 2) return 0.0;
    const shift: u5 = switch (channel) {
        0 => 16,
        1 => 8,
        2 => 0,
        else => unreachable,
    };
    return @as(f64, @floatFromInt((rgb >> shift) & 0xff)) / 255.0;
}

pub export fn noctty_grid_theme_color_text(
    red: f64,
    green: f64,
    blue: f64,
    output: ?[*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const target = output orelse return 0;
    if (capacity < 8 or !std.math.isFinite(red) or
        !std.math.isFinite(green) or !std.math.isFinite(blue))
        return 0;
    const channel = struct {
        fn convert(value: f64) u8 {
            return @intCast(@as(u16, @intFromFloat(
                std.math.clamp(@round(value * 255.0), 0.0, 255.0),
            )));
        }
    }.convert;
    const hex = "0123456789abcdef";
    const colors = [_]u8{ channel(red), channel(green), channel(blue) };
    target[0] = '#';
    for (colors, 0..) |color, index| {
        target[index * 2 + 1] = hex[color >> 4];
        target[index * 2 + 2] = hex[color & 0x0f];
    }
    target[7] = 0;
    return 7;
}
pub export fn noctty_grid_terminal_scroll_setting(
    event_code: c_int,
    value: c_int,
) callconv(.c) c_int {
    return switch (event_code) {
        117 => std.math.clamp(value, 1, 20),
        118 => @intFromBool(value != 0),
        else => -1,
    };
}

pub export fn noctty_grid_compact_setting_plan(
    field: c_int,
    output_optional: ?*CompactSettingPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    const target: c_int = switch (field) {
        0 => compact_setting_target_width_percent,
        1 => compact_setting_target_height_percent,
        2 => compact_setting_target_animation,
        3 => compact_setting_target_hide_focus,
        4 => compact_setting_target_focus_pointer,
        5 => compact_setting_target_pane_info,
        14 => compact_setting_target_width_pixels,
        15 => compact_setting_target_height_pixels,
        else => {
            output.* = .{ .target = -1, .valid = 0 };
            return;
        },
    };
    output.* = .{ .target = target, .valid = 1 };
}

pub export fn noctty_grid_font_rendering_plan(
    event_code: c_int,
    value: c_int,
    output_optional: ?*FontRenderingPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    const target: c_int = switch (event_code) {
        110 => font_rendering_target_antialias,
        111 => font_rendering_target_hinting,
        else => {
            output.* = .{ .target = -1, .value = 0, .valid = 0 };
            return;
        },
    };
    output.* = .{
        .target = target,
        .value = std.math.clamp(value, 0, 2),
        .valid = 1,
    };
}

pub export fn noctty_grid_terminal_menu_plan(
    action: c_int,
    columns: c_int,
    rows: c_int,
    output_optional: ?*TerminalMenuPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .action = terminal_menu_action_none,
        .selection_end_column = 0,
        .selection_end_row = 0,
    };
    if (action < terminal_menu_action_copy or
        action > terminal_menu_action_reset)
        return;
    output.action = action;
    if (action == terminal_menu_action_select_all) {
        output.selection_end_column = if (columns > 0) columns - 1 else 0;
        output.selection_end_row = if (rows > 0) rows - 1 else 0;
    }
}


pub export fn noctty_grid_font_size_clamp(
    requested: f64,
    minimum: f64,
    maximum: f64,
) callconv(.c) f64 {
    return std.math.clamp(requested, minimum, maximum);
}

pub export fn noctty_grid_font_size_event_value(
    requested: f64,
    minimum: f64,
    maximum: f64,
) callconv(.c) c_int {
    const resolved = noctty_grid_font_size_clamp(requested, minimum, maximum);
    return @intFromFloat(resolved * 100.0 + 0.5);
}

pub export fn noctty_grid_panel_metric_value(
    event_code: c_int,
    value: c_int,
) callconv(.c) c_int {
    return switch (event_code) {
        46, 47 => std.math.clamp(value, 0, 64),
        119 => std.math.clamp(value, 1, 16),
        120 => std.math.clamp(value, 0, 12),
        121, 122, 123, 124 => std.math.clamp(value, 1, 12),
        125 => std.math.clamp(value, 1, 16),
        126 => std.math.clamp(value, 1, 32),
        127, 128, 129 => @intFromBool(value != 0),
        130 => std.math.clamp(value, 20, 100),
        else => -1,
    };
}

pub export fn noctty_grid_background_opacity_value(value: c_int) callconv(.c) c_int {
    return std.math.clamp(value, 10, 100);
}

pub export fn noctty_grid_panel_settings_apply(
    event_code: c_int,
    value: c_int,
    output_optional: ?*PanelSettings,
) callconv(.c) c_int {
    const output = output_optional orelse return 0;
    output.affects_layout = 0;
    switch (event_code) {
        46 => output.panel_padding_px = std.math.clamp(value, 0, 64),
        47 => output.pane_spacing_px = std.math.clamp(value, 0, 64),
        115 => output.background_translucency = @intFromBool(value != 0),
        116 => output.background_opacity_percent =
            noctty_grid_background_opacity_value(value),
        119 => output.pane_divider_px = std.math.clamp(value, 1, 16),
        120 => output.pane_border_px = std.math.clamp(value, 0, 12),
        121 => output.pane_border_focused_px = std.math.clamp(value, 1, 12),
        122 => output.pane_border_selected_px = std.math.clamp(value, 1, 12),
        123 => output.status_border_px = std.math.clamp(value, 1, 12),
        124 => output.overlay_border_px = std.math.clamp(value, 1, 12),
        125 => output.window_border_px = std.math.clamp(value, 1, 16),
        126 => output.dragger_px = std.math.clamp(value, 1, 32),
        127 => output.pane_gaps_enabled = @intFromBool(value != 0),
        128 => output.pane_gaps_transparent = @intFromBool(value != 0),
        129 => output.inactive_pane_dim_enabled = @intFromBool(value != 0),
        130 => output.inactive_pane_brightness_percent =
            std.math.clamp(value, 20, 100),
        else => return 0,
    }
    output.affects_layout = @intFromBool(event_code != 115 and event_code != 116);
    return 1;
}

pub export fn noctty_grid_scrollbar_geometry(
    allocation_width: c_int,
    allocation_height: c_int,
    scrollbar_width: f64,
    thumb_height_min: f64,
    history_lines: u64,
    viewport_offset: u64,
    visible_rows: u32,
    output: ?*ScrollbarGeometry,
) callconv(.c) c_int {
    const geometry = output orelse return 0;
    if (scrollbar_width <= 0 or thumb_height_min <= 0) return 0;
    if (@as(f64, @floatFromInt(allocation_width)) <= scrollbar_width) return 0;
    if (allocation_height <= 4) return 0;
    geometry.x = @as(f64, @floatFromInt(allocation_width)) - scrollbar_width;
    geometry.y = 2;
    geometry.width = scrollbar_width;
    geometry.height = @max(1, @as(f64, @floatFromInt(allocation_height)) - 4);
    geometry.history_lines = history_lines;
    geometry.viewport_offset = @min(viewport_offset, history_lines);
    geometry.visible_rows = @max(visible_rows, 1);
    const total_rows = @as(f64, @floatFromInt(history_lines)) +
        @as(f64, @floatFromInt(geometry.visible_rows));
    geometry.thumb_height = if (history_lines == 0)
        geometry.height
    else
        std.math.clamp(
            geometry.height * @as(f64, @floatFromInt(geometry.visible_rows)) / total_rows,
            @min(thumb_height_min, geometry.height),
            geometry.height,
        );
    const travel = geometry.height - geometry.thumb_height;
    const position = if (history_lines > 0)
        @as(f64, @floatFromInt(history_lines - geometry.viewport_offset)) /
            @as(f64, @floatFromInt(history_lines))
    else
        1;
    geometry.thumb_y = geometry.y + travel * position;
    return 1;
}

fn validScrollbarGeometry(geometry: *const ScrollbarGeometry) bool {
    if (!std.math.isFinite(geometry.y) or
        !std.math.isFinite(geometry.height) or
        !std.math.isFinite(geometry.thumb_y) or
        !std.math.isFinite(geometry.thumb_height) or
        geometry.height <= 0 or
        geometry.thumb_height <= 0 or
        geometry.thumb_height > geometry.height)
    {
        return false;
    }
    const travel = geometry.height - geometry.thumb_height;
    const track_end = geometry.y + travel;
    const thumb_end = geometry.thumb_y + geometry.thumb_height;
    return std.math.isFinite(track_end) and std.math.isFinite(thumb_end) and
        geometry.thumb_y >= geometry.y and geometry.thumb_y <= track_end;
}

pub export fn noctty_grid_scrollbar_press_plan(
    geometry_optional: ?*const ScrollbarGeometry,
    pointer_y: f64,
    output_optional: ?*ScrollbarPressPlan,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = .{
        .action = scrollbar_press_none,
        .drag_offset = 0,
        .target_offset = 0,
    };
    const geometry = geometry_optional orelse return;
    if (!std.math.isFinite(pointer_y) or !validScrollbarGeometry(geometry))
        return;

    const viewport_offset = @min(
        geometry.viewport_offset,
        geometry.history_lines,
    );
    output.target_offset = viewport_offset;
    const thumb_end = geometry.thumb_y + geometry.thumb_height;
    if (pointer_y >= geometry.thumb_y and pointer_y <= thumb_end) {
        output.action = scrollbar_press_drag;
        output.drag_offset = pointer_y - geometry.thumb_y;
        return;
    }

    const page = @max(
        @as(u64, if (geometry.visible_rows > 1)
            geometry.visible_rows - 1
        else
            1),
        1,
    );
    output.action = scrollbar_press_page;
    output.target_offset = if (pointer_y < geometry.thumb_y)
        @min(geometry.history_lines, viewport_offset +| page)
    else
        viewport_offset -| page;
}

pub export fn noctty_grid_scrollbar_drag_target(
    geometry_optional: ?*const ScrollbarGeometry,
    pointer_y: f64,
    drag_offset: f64,
    target_optional: ?*u64,
) callconv(.c) c_int {
    const target = target_optional orelse return 0;
    target.* = 0;
    const geometry = geometry_optional orelse return 0;
    target.* = @min(geometry.viewport_offset, geometry.history_lines);
    if (!std.math.isFinite(pointer_y) or
        !std.math.isFinite(drag_offset) or
        !validScrollbarGeometry(geometry) or
        geometry.history_lines == 0)
    {
        return 0;
    }
    const travel = geometry.height - geometry.thumb_height;
    if (travel <= 0) return 0;
    const requested_thumb_y = pointer_y - drag_offset;
    if (!std.math.isFinite(requested_thumb_y)) return 0;
    const thumb_y = std.math.clamp(
        requested_thumb_y,
        geometry.y,
        geometry.y + travel,
    );
    const position = (thumb_y - geometry.y) / travel;
    const history_float: f64 = @floatFromInt(geometry.history_lines);
    const scaled = @round(position * history_float);
    const target_position: u64 = if (scaled <= 0)
        0
    else if (scaled >= history_float)
        geometry.history_lines
    else
        @intFromFloat(scaled);
    target.* = geometry.history_lines - target_position;
    return 1;
}

pub export fn noctty_grid_cell_selected(
    selecting: c_int,
    start_column: c_int,
    start_row: c_int,
    end_column: c_int,
    end_row: c_int,
    column: c_int,
    row: c_int,
) callconv(.c) c_int {
    if (selecting == 0) return 0;
    var first_column = start_column;
    var first_row = start_row;
    var last_column = end_column;
    var last_row = end_row;
    if (first_row > last_row or first_row == last_row and first_column > last_column) {
        std.mem.swap(c_int, &first_column, &last_column);
        std.mem.swap(c_int, &first_row, &last_row);
    }
    if (row < first_row or row > last_row) return 0;
    if (first_row == last_row) return @intFromBool(column >= first_column and column <= last_column);
    if (row == first_row) return @intFromBool(column >= first_column);
    if (row == last_row) return @intFromBool(column <= last_column);
    return 1;
}

pub const RenderViewport = extern struct {
    first_row: c_int,
    end_row: c_int,
    first_column: c_int,
    end_column: c_int,
};

pub const RenderChrome = extern struct {
    status_role: u32,
    status_fallback: u32,
    pane_role: u32,
    pane_fallback: u32,
    pane_width: c_int,
    pane_inset: f64,
    caret_draw: c_int,
    caret_x: f64,
    caret_y: f64,
    caret_width: f64,
    caret_height: f64,
};

fn renderViewportIndex(value: f64, maximum: c_int, end: bool) c_int {
    const rounded = if (end) @ceil(value) + 1 else @floor(value);
    if (rounded <= 0) return 0;
    if (rounded >= @as(f64, @floatFromInt(maximum))) return maximum;
    return @intFromFloat(rounded);
}

pub export fn noctty_grid_render_viewport(
    clip_x1: f64,
    clip_y1: f64,
    clip_x2: f64,
    clip_y2: f64,
    cell_width: f64,
    cell_height: f64,
    columns: c_int,
    rows: c_int,
    output: ?*RenderViewport,
) callconv(.c) c_int {
    const viewport = output orelse return 0;
    if (!std.math.isFinite(clip_x1) or !std.math.isFinite(clip_y1)) return 0;
    if (!std.math.isFinite(clip_x2) or !std.math.isFinite(clip_y2)) return 0;
    if (!std.math.isFinite(cell_width) or !std.math.isFinite(cell_height)) return 0;
    if (cell_width <= 0 or cell_height <= 0 or columns <= 0 or rows <= 0) return 0;
    viewport.* = .{
        .first_row = renderViewportIndex((clip_y1 - 2) / cell_height, rows, false),
        .end_row = renderViewportIndex((clip_y2 - 2) / cell_height, rows, true),
        .first_column = renderViewportIndex((clip_x1 - 4) / cell_width, columns, false),
        .end_column = renderViewportIndex((clip_x2 - 4) / cell_width, columns, true),
    };
    return @intFromBool(viewport.end_row > viewport.first_row and viewport.end_column > viewport.first_column);
}

pub export fn noctty_grid_render_chrome(
    status_kind: c_int,
    focused: c_int,
    selected: c_int,
    pane_width: c_int,
    focused_width: c_int,
    selected_width: c_int,
    cursor_visible: c_int,
    cursor_live: c_int,
    cursor_column: c_int,
    cursor_row: c_int,
    columns: c_int,
    rows: c_int,
    cell_width: f64,
    cell_height: f64,
    output: ?*RenderChrome,
) callconv(.c) void {
    const chrome = output orelse return;
    var status_color = StatusColorPlan{
        .role = 0,
        .fallback = 0,
        .muted = 1,
    };
    noctty_grid_status_color_plan(status_kind, 0, &status_color);
    const width = if (focused != 0)
        focused_width
    else if (selected != 0)
        selected_width
    else
        pane_width;
    const cell_metrics_valid = std.math.isFinite(cell_width) and
        std.math.isFinite(cell_height) and cell_width > 0 and cell_height > 0;
    const caret_draw = cell_metrics_valid and cursor_visible != 0 and cursor_live != 0 and
        cursor_column >= 0 and cursor_column < columns and
        cursor_row >= 0 and cursor_row < rows;
    chrome.* = .{
        .status_role = status_color.role,
        .status_fallback = status_color.fallback,
        .pane_role = if (focused != 0) 1 else if (selected != 0) 2 else 3,
        .pane_fallback = if (focused != 0 or selected != 0) 0xf2b82e else 0x343848,
        .pane_width = @max(width, 0),
        .pane_inset = @max(0.5, @as(f64, @floatFromInt(width)) / 2),
        .caret_draw = @intFromBool(caret_draw),
        .caret_x = if (caret_draw) 5 + @as(f64, @floatFromInt(cursor_column)) * cell_width else 0,
        .caret_y = if (caret_draw) 3 + @as(f64, @floatFromInt(cursor_row)) * cell_height else 0,
        .caret_width = if (caret_draw) std.math.clamp(cell_width * 0.14, 2, 3) else 0,
        .caret_height = if (caret_draw) @max(1, cell_height - 2) else 0,
    };
}

pub const RenderCell = extern struct {
    codepoint: u32,
    style: u32,
    foreground: u32,
    background: u32,
    face: c_int,
    alpha: f64,
    drawable: c_int,
    ascii: c_int,
    grapheme: c_int,
    decorated: c_int,
};

/// Decodes the packed terminal-cell ABI once so renderer paths cannot diverge
/// on inverse colors, font face, concealment, or dim opacity.
pub export fn noctty_grid_codepoint_utf8(
    codepoint: u32,
    output_raw: ?[*]u8,
    output_size: u32,
) callconv(.c) c_int {
    const output = output_raw orelse return 0;
    if (output_size < 4) return 0;
    if (codepoint < 0x80) {
        output[0] = if (codepoint >= 0x20) @intCast(codepoint) else ' ';
        return 1;
    }
    if (codepoint <= 0x7ff) {
        output[0] = @intCast(0xc0 | (codepoint >> 6));
        output[1] = @intCast(0x80 | (codepoint & 0x3f));
        return 2;
    }
    if (codepoint <= 0xffff) {
        if (codepoint >= 0xd800 and codepoint <= 0xdfff) {
            output[0] = '?';
            return 1;
        }
        output[0] = @intCast(0xe0 | (codepoint >> 12));
        output[1] = @intCast(0x80 | ((codepoint >> 6) & 0x3f));
        output[2] = @intCast(0x80 | (codepoint & 0x3f));
        return 3;
    }
    if (codepoint <= 0x10ffff) {
        output[0] = @intCast(0xf0 | (codepoint >> 18));
        output[1] = @intCast(0x80 | ((codepoint >> 12) & 0x3f));
        output[2] = @intCast(0x80 | ((codepoint >> 6) & 0x3f));
        output[3] = @intCast(0x80 | (codepoint & 0x3f));
        return 4;
    }
    output[0] = '?';
    return 1;
}

pub export fn noctty_grid_render_cell(
    packed_cell: u64,
    output: ?*RenderCell,
) callconv(.c) void {
    const cell = output orelse return;
    const codepoint: u32 = @truncate(packed_cell);
    const style: u32 = @truncate(packed_cell >> 32);
    var foreground = (style >> 8) & 0xfff;
    var background = (style >> 20) & 0xfff;
    if (style & 2 != 0) std.mem.swap(u32, &foreground, &background);
    const renderable = style & 128 == 0 and codepoint >= 0x20;
    const visible = renderable and codepoint != ' ';
    cell.* = .{
        .codepoint = codepoint,
        .style = style,
        .foreground = foreground,
        .background = background,
        .face = @as(c_int, @intFromBool(style & 1 != 0)) |
            (@as(c_int, @intFromBool(style & 4 != 0)) << 1),
        .alpha = if (style & 32 != 0) 0.55 else 1.0,
        .drawable = @intFromBool(visible),
        .ascii = @intFromBool(renderable and codepoint <= 0x7e and style & 64 == 0),
        .grapheme = @intFromBool(visible and style & 64 != 0),
        .decorated = @intFromBool(style & (8 | 16) != 0),
    };
}

pub export fn noctty_grid_render_run_end(
    cells_raw: ?[*]const u64,
    start: c_int,
    end: c_int,
    kind: c_int,
) callconv(.c) c_int {
    const cells = cells_raw orelse return start;
    if (start < 0 or end <= start) return start;
    var reference: RenderCell = undefined;
    noctty_grid_render_cell(cells[@intCast(start)], &reference);
    var index = start + 1;
    while (index < end) : (index += 1) {
        var candidate: RenderCell = undefined;
        noctty_grid_render_cell(cells[@intCast(index)], &candidate);
        const matches = switch (kind) {
            1 => candidate.background == reference.background,
            2 => candidate.ascii != 0 and
                (candidate.style & (1 | 4 | 32)) == (reference.style & (1 | 4 | 32)) and
                candidate.foreground == reference.foreground,
            3 => candidate.decorated != 0 and
                (candidate.style & (8 | 16 | 32)) == (reference.style & (8 | 16 | 32)) and
                candidate.foreground == reference.foreground,
            else => false,
        };
        if (!matches) break;
    }
    return index;
}

pub export fn noctty_grid_cell_span(
    first: c_int,
    end: c_int,
    row: c_int,
    cell_width: f64,
    cell_height: f64,
    snap_horizontal: c_int,
    output: ?*Rectangle,
) callconv(.c) void {
    const rectangle = output orelse return;
    const left_value = 4 + @as(f64, @floatFromInt(first)) * cell_width;
    const right_value = 4 + @as(f64, @floatFromInt(end)) * cell_width;
    const left = if (snap_horizontal != 0) @floor(left_value) else left_value;
    const right = if (snap_horizontal != 0) @ceil(right_value) else right_value;
    const top = @floor(2 + @as(f64, @floatFromInt(row)) * cell_height);
    const bottom = @ceil(2 + @as(f64, @floatFromInt(row + 1)) * cell_height);
    rectangle.* = .{
        .x = left,
        .y = top,
        .width = @max(1, right - left),
        .height = @max(1, bottom - top),
    };
}

pub export fn noctty_grid_row_span(
    first: c_int,
    end: c_int,
    cell_height: f64,
    output: ?*Rectangle,
) callconv(.c) void {
    const rectangle = output orelse return;
    const top = @floor(2 + @as(f64, @floatFromInt(first)) * cell_height);
    const bottom = @ceil(2 + @as(f64, @floatFromInt(end)) * cell_height);
    rectangle.* = .{
        .x = 0,
        .y = top,
        .width = 0,
        .height = @max(1, bottom - top),
    };
}
pub export fn noctty_grid_damage_rect(
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    allocation_width: c_int,
    allocation_height: c_int,
    output: ?*DamageRect,
) callconv(.c) void {
    const damage = output orelse return;
    const left = @max(@as(c_int, 0), @as(c_int, @intFromFloat(x)));
    const top = @max(@as(c_int, 0), @as(c_int, @intFromFloat(y)));
    const right = @min(
        @max(allocation_width, 0),
        @as(c_int, @intFromFloat(x + width)),
    );
    const bottom = @min(
        @max(allocation_height, 0),
        @as(c_int, @intFromFloat(y + height)),
    );
    damage.* = .{
        .x = left,
        .y = top,
        .width = @max(right - left, 1),
        .height = @max(bottom - top, 1),
    };
}

pub export fn noctty_grid_cursor_damage(
    column: c_int,
    row: c_int,
    cell_width: f64,
    cell_height: f64,
    output: ?*DamageRect,
) callconv(.c) void {
    const damage = output orelse return;
    damage.* = .{
        .x = @max(0, @as(c_int, @intFromFloat(@floor(
            4.0 + @as(f64, @floatFromInt(column)) * cell_width,
        )))),
        .y = @max(0, @as(c_int, @intFromFloat(@floor(
            2.0 + @as(f64, @floatFromInt(row)) * cell_height,
        )))),
        .width = @max(1, @as(c_int, @intFromFloat(@ceil(cell_width)))),
        .height = @max(1, @as(c_int, @intFromFloat(@ceil(cell_height)))),
    };
}

pub export fn noctty_grid_cursor_position(
    packed_cursor: u32,
    output: ?*CursorPosition,
) callconv(.c) void {
    const position = output orelse return;
    if (packed_cursor == std.math.maxInt(u32)) {
        position.* = .{ .column = -1, .row = -1, .valid = 0 };
        return;
    }
    position.* = .{
        .column = @intCast(packed_cursor & 0xffff),
        .row = @intCast(packed_cursor >> 16),
        .valid = 1,
    };
}

pub export fn noctty_grid_background_alpha(
    translucency: c_int,
    alpha_supported: c_int,
    opacity_percent: f64,
) callconv(.c) f64 {
    if (translucency == 0 or alpha_supported == 0) return 1.0;
    return opacity_percent / 100.0;
}

pub export fn noctty_grid_scroll_steps(
    configured_lines: c_int,
    smooth_enabled: c_int,
    direction: c_int,
    delta_y: f64,
    accumulator_output: ?*f64,
) callconv(.c) c_int {
    const accumulator = accumulator_output orelse return 0;
    const lines = std.math.clamp(configured_lines, 1, 20);
    if (direction == -1 or direction == 1) {
        accumulator.* = 0;
        return if (direction < 0) lines else -lines;
    }
    if (direction != 0 or !std.math.isFinite(delta_y)) return 0;
    const scale: f64 = if (smooth_enabled != 0) @floatFromInt(lines) else 1;
    accumulator.* -= delta_y * scale;
    if (accumulator.* > -1 and accumulator.* < 1) return 0;
    if (smooth_enabled == 0) {
        const step: c_int = if (accumulator.* > 0) 1 else -1;
        accumulator.* -= @floatFromInt(step);
        return step * lines;
    }
    const steps: c_int = std.math.clamp(@as(c_int, @intFromFloat(accumulator.*)), -64, 64);
    accumulator.* -= @floatFromInt(steps);
    return steps;
}

pub export fn noctty_grid_keyboard_scroll_target(
    history_lines: u64,
    viewport_offset: u64,
    visible_rows: u32,
    action: c_int,
) callconv(.c) u64 {
    const current = @min(viewport_offset, history_lines);
    const page = @max(@as(u64, visible_rows), 1);
    return switch (action) {
        1 => @min(history_lines, current +| page),
        2 => current -| page,
        3 => history_lines,
        4 => 0,
        else => current,
    };
}

pub const FontMetrics = extern struct {
    font_px: f64,
    cell_width: f64,
    cell_height: f64,
};

pub const PanelSpacingPlan = extern struct {
    leading: c_int,
    trailing: c_int,
};

pub const AutoFitBounds = extern struct {
    width: c_int,
    height: c_int,
};

pub const ResizePlan = extern struct {
    terminal_width: c_int,
    columns: c_int,
    rows: c_int,
    changed: c_int,
};

pub const StatusPlan = extern struct {
    active_kind: c_int,
    changed: c_int,
};

pub const StatusColorPlan = extern struct {
    role: u32,
    fallback: u32,
    muted: c_int,
};

pub const NotebookChromePlan = extern struct {
    show: c_int,
};

pub export fn noctty_grid_status_plan(
    status_kind: c_int,
    attention: c_int,
    output: ?*StatusPlan,
) callconv(.c) void {
    const plan = output orelse return;
    const active_kind: c_int = if (status_kind == 4 or attention != 0) 4 else 1;
    plan.* = .{
        .active_kind = active_kind,
        .changed = @intFromBool(status_kind != active_kind),
    };
}

pub export fn noctty_grid_status_color_plan(
    status_kind: c_int,
    attention: c_int,
    output: ?*StatusColorPlan,
) callconv(.c) void {
    const plan = output orelse return;
    const kind: c_int = if (attention != 0) 4 else status_kind;
    plan.* = switch (kind) {
        0 => .{ .role = 0, .fallback = 0, .muted = 1 },
        1 => .{ .role = 12, .fallback = 0x408cf2, .muted = 0 },
        2 => .{ .role = 13, .fallback = 0x40cc66, .muted = 0 },
        4 => .{ .role = 14, .fallback = 0xf5b82e, .muted = 0 },
        else => .{ .role = 15, .fallback = 0xe64040, .muted = 0 },
    };
}

pub export fn noctty_grid_notebook_chrome_plan(
    zoomed_pane_id: u64,
    page_count: c_int,
    output: ?*NotebookChromePlan,
) callconv(.c) void {
    const plan = output orelse return;
    plan.* = .{
        .show = @intFromBool(zoomed_pane_id == 0 and page_count > 0),
    };
}

pub export fn noctty_grid_panel_spacing_plan(
    enabled: c_int,
    spacing_px: c_int,
    output: ?*PanelSpacingPlan,
) callconv(.c) void {
    const plan = output orelse return;
    const gap_width = if (enabled != 0) spacing_px else 0;
    const leading = @divTrunc(gap_width, 2);
    plan.* = .{
        .leading = leading,
        .trailing = gap_width - leading,
    };
}

const default_font_points: f64 = 11;
const font_points_to_pixels: f64 = 96.0 / 72.0;
const cell_width_ratio: f64 = 0.64;
const cell_height_ratio: f64 = 1.28;

fn defaultFontMetrics() FontMetrics {
    const font_px = default_font_points * font_points_to_pixels;
    return .{
        .font_px = font_px,
        .cell_width = @max(3, font_px * cell_width_ratio),
        .cell_height = @max(5, font_px * cell_height_ratio),
    };
}

fn gridFontMetrics(requested_points: f64) FontMetrics {
    if (!std.math.isFinite(requested_points) or requested_points <= 0)
        return defaultFontMetrics();
    const font_px = requested_points * font_points_to_pixels;
    const cell_width = font_px * cell_width_ratio;
    const cell_height = font_px * cell_height_ratio;
    if (!std.math.isFinite(font_px) or
        !std.math.isFinite(cell_width) or
        !std.math.isFinite(cell_height))
    {
        return defaultFontMetrics();
    }
    return .{
        .font_px = font_px,
        .cell_width = @max(3, cell_width),
        .cell_height = @max(5, cell_height),
    };
}

pub export fn noctty_grid_font_metrics(
    requested_points: f64,
    output_optional: ?*FontMetrics,
) callconv(.c) void {
    const output = output_optional orelse return;
    output.* = gridFontMetrics(requested_points);
}

pub export fn noctty_grid_auto_fit(
    base_size: f64,
    fit_width: c_int,
    fit_height: c_int,
    enabled: c_int,
    next_size_output: ?*f64,
    zoom_percent_output: ?*c_int,
    floor_reached_output: ?*c_int,
) callconv(.c) void {
    const next_size = next_size_output orelse return;
    const zoom_percent = zoom_percent_output orelse return;
    const floor_reached = floor_reached_output orelse return;
    var value = base_size;
    var fit_min = std.math.inf(f64);
    if (enabled != 0 and fit_width > 0 and fit_height > 0) {
        const width_fit = @as(f64, @floatFromInt(fit_width)) /
            (80 * (96.0 / 72.0) * 0.64);
        const height_fit = @as(f64, @floatFromInt(fit_height)) /
            (24 * (96.0 / 72.0) * 1.28);
        fit_min = @min(width_fit, height_fit);
        value = @min(base_size, @floor(fit_min * 4) / 4);
        value = @max(3, value);
    }
    next_size.* = value;
    zoom_percent.* = if (base_size > 0)
        std.math.clamp(@as(c_int, @intFromFloat(@round(value * 100 / base_size))), 1, 100)
    else
        100;
    floor_reached.* = @intFromBool(enabled != 0 and fit_min < 3);
}

pub export fn noctty_grid_auto_fit_bounds(
    allocation_width: c_int,
    allocation_height: c_int,
    candidate_width: c_int,
    candidate_height: c_int,
    output: ?*AutoFitBounds,
) callconv(.c) void {
    const bounds = output orelse return;
    bounds.* = .{
        .width = if (candidate_width > 1)
            @min(allocation_width, candidate_width)
        else
            allocation_width,
        .height = if (candidate_height > 1)
            @min(allocation_height, candidate_height)
        else
            allocation_height,
    };
}

pub export fn noctty_grid_dimensions(
    allocation_width: c_int,
    allocation_height: c_int,
    scrollbar_width: f64,
    cell_width: f64,
    cell_height: f64,
    terminal_width_output: ?*c_int,
    columns_output: ?*c_int,
    rows_output: ?*c_int,
) callconv(.c) c_int {
    const terminal_width = terminal_width_output orelse return 0;
    const columns = columns_output orelse return 0;
    const rows = rows_output orelse return 0;
    if (allocation_width <= 0 or allocation_height <= 0) return 0;
    if (scrollbar_width < 0 or cell_width <= 0 or cell_height <= 0) return 0;
    terminal_width.* = @max(1, allocation_width - @as(c_int, @intFromFloat(scrollbar_width)));
    columns.* = @max(2, @as(c_int, @intFromFloat(@as(f64, @floatFromInt(terminal_width.*)) / cell_width)));
    rows.* = @max(2, @as(c_int, @intFromFloat(@as(f64, @floatFromInt(allocation_height)) / cell_height)));
    return 1;
}

pub export fn noctty_grid_resize_plan(
    allocation_width: c_int,
    allocation_height: c_int,
    scrollbar_width: f64,
    cell_width: f64,
    cell_height: f64,
    current_columns: c_int,
    current_rows: c_int,
    output: ?*ResizePlan,
) callconv(.c) c_int {
    const plan = output orelse return 0;
    if (noctty_grid_dimensions(
            allocation_width, allocation_height, scrollbar_width,
            cell_width, cell_height, &plan.terminal_width,
            &plan.columns, &plan.rows) == 0)
        return 0;
    plan.changed = @intFromBool(
        plan.columns != current_columns or plan.rows != current_rows);
    return 1;
}

pub export fn noctty_grid_scale_brightness(
    rgb: u32,
    enabled: c_int,
    active: c_int,
    percent_raw: c_int,
) callconv(.c) u32 {
    if (enabled == 0 or active != 0) return rgb & 0xffffff;
    const percent: u32 = @intCast(std.math.clamp(percent_raw, 20, 100));
    const red = ((rgb >> 16) & 0xff) * percent / 100;
    const green = ((rgb >> 8) & 0xff) * percent / 100;
    const blue = (rgb & 0xff) * percent / 100;
    return (red << 16) | (green << 8) | blue;
}

pub export fn noctty_grid_pane_is_active(
    active_pane_id: u64,
    pane_id: u64,
    focused: c_int,
) callconv(.c) c_int {
    return @intFromBool(if (active_pane_id != 0) active_pane_id == pane_id else focused != 0);
}

pub export fn noctty_grid_status_name(status_kind: c_int) callconv(.c) [*:0]const u8 {
    return switch (status_kind) {
        1 => "running",
        2 => "done",
        3 => "error",
        4 => "pending input",
        else => "idle",
    };
}

pub export fn noctty_grid_profile_preset_label(preset: c_int) callconv(.c) [*:0]const u8 {
    return switch (preset) {
        0 => "Global default",
        1 => "Compact",
        2 => "Readable",
        3 => "High contrast",
        4 => "Mono no ligatures",
        else => "Custom",
    };
}

pub export fn noctty_grid_profile_preset_valid(preset: c_int) callconv(.c) c_int {
    return @intFromBool(
        preset >= profile_preset_first and
        preset < profile_preset_first + profile_preset_count,
    );
}


pub export fn noctty_grid_broadcast_menu_label(enabled: c_int) callconv(.c) [*:0]const u8 {
    return if (enabled != 0) "Disable Broadcast Input" else "Enable Broadcast Input…";
}

pub export fn noctty_grid_shortcut_field(field: c_int, smoke: c_int) callconv(.c) [*:0]const u8 {
    return switch (field) {
        0 => if (smoke != 0) "noctty-smoke" else "noctty",
        1 => if (smoke != 0) "toggle-window-smoke" else "toggle-window",
        2 => if (smoke != 0) "NOCTTY Smoke" else "NOCTTY",
        3 => if (smoke != 0) "Show/hide NOCTTY smoke" else "Show/hide NOCTTY",
        4 => if (smoke != 0) "/component/noctty_smoke" else "/component/noctty",
        else => "",
    };
}

pub const ResizeHandleLayout = extern struct {
    column: c_int,
    row: c_int,
    width: c_int,
    height: c_int,
};

pub export fn noctty_grid_resize_handle_layout(
    index: c_int,
    border_px: c_int,
    dragger_px: c_int,
    output: ?*ResizeHandleLayout,
) callconv(.c) c_int {
    const layout = output orelse return 0;
    if (index < 0 or index >= 8 or border_px < 0 or dragger_px < 0) return 0;
    const columns = [_]c_int{ 0, 1, 2, 0, 2, 0, 1, 2 };
    const rows = [_]c_int{ 0, 0, 0, 1, 1, 2, 2, 2 };
    layout.* = .{
        .column = columns[@intCast(index)],
        .row = rows[@intCast(index)],
        .width = if (index == 1 or index == 6) -1 else border_px,
        .height = if (index == 3 or index == 4)
            -1
        else if (index == 6)
            dragger_px
        else
            border_px,
    };
    return 1;
}

pub export fn noctty_grid_snap_pane_position(
    max_position: c_int,
    position: c_int,
) callconv(.c) c_int {
    if (max_position <= 0 or
        max_position >= @divTrunc(std.math.maxInt(c_int), 2))
        return -1;
    const snap_points = [_]c_int{
        @divTrunc(max_position, 4),
        @divTrunc(max_position, 3),
        @divTrunc(max_position, 2),
        @divTrunc(max_position * 2, 3),
        @divTrunc(max_position * 3, 4),
    };
    const threshold = @max(@as(c_int, 12), @divTrunc(max_position, 32));
    for (snap_points) |snap_point| {
        const distance = @abs(@as(i64, position) - @as(i64, snap_point));
        if (distance <= @as(i64, threshold)) return snap_point;
    }

    return -1;
}

pub const PaletteAction = extern struct {
    id: c_int,
    label: [*:0]const u8,
    hint: [*:0]const u8,
};

pub export fn noctty_grid_palette_actions(
    output: ?[*]PaletteAction,
    capacity: c_uint,
) callconv(.c) c_uint {
    const target = output orelse return 0;
    const actions = [_]PaletteAction{
        .{ .id = 1, .label = "New terminal tab", .hint = "Ctrl+Shift+T · same directory" },
        .{ .id = 2, .label = "Split down", .hint = "Ctrl+Shift+S" },
        .{ .id = 3, .label = "Split left", .hint = "Ctrl+Shift+L" },
        .{ .id = 4, .label = "Zoom or restore pane", .hint = "Ctrl+Shift+Z" },
        .{ .id = 5, .label = "Find in terminal scrollback", .hint = "Ctrl+Shift+F" },
        .{ .id = 6, .label = "Open quick note", .hint = "Ctrl+Shift+N" },
        .{ .id = 7, .label = "Enable or disable broadcast input", .hint = "selected panes · confirms enable" },
        .{ .id = 8, .label = "Move pane to another tab", .hint = "keeps live PTY" },
        .{ .id = 9, .label = "Open settings", .hint = "compact native controls" },
        .{ .id = 10, .label = "Open theme library", .hint = "preview and import" },
        .{ .id = 11, .label = "Open project workspace", .hint = "files, Git, editor" },
        .{ .id = 18, .label = "Open NoctEd here", .hint = "launch NoctEd at the terminal directory" },
        .{ .id = 12, .label = "Save terminal scrollback", .hint = "plain UTF-8 text" },
        .{ .id = 13, .label = "Show keyboard shortcuts", .hint = "Ctrl+Shift+K" },
        .{ .id = 14, .label = "Show or hide NOCTTY", .hint = "F10" },
        .{ .id = 15, .label = "Cycle terminal theme", .hint = "dark / high contrast" },
        .{ .id = 16, .label = "Cycle tab position", .hint = "top / bottom / left / right" },
        .{ .id = 17, .label = "Rename active tab", .hint = "Ctrl+Shift+R" },
        .{ .id = 19, .label = "Set Smart Tab filter", .hint = "Ctrl+Shift+G" },
        .{ .id = 20, .label = "Tag selected panes", .hint = "Ctrl+Shift+Y" },
        .{ .id = 21, .label = "Remove tag from selected panes", .hint = "selection group" },
        .{ .id = 22, .label = "Lighten active tab color", .hint = "Ctrl+Alt+=" },
        .{ .id = 23, .label = "Darken active tab color", .hint = "Ctrl+Alt+-" },
        .{ .id = 24, .label = "Register agent resume reference", .hint = "provider + opaque session ID" },
        .{ .id = 25, .label = "Clear agent resume reference", .hint = "return to ordinary restore" },
        .{ .id = 26, .label = "Export encrypted screen history", .hint = "password-protected local file" },
        .{ .id = 27, .label = "Accept pending agent action", .hint = "explicitly run a safe focus/project action" },
    };
    if (capacity < actions.len) return 0;
    for (actions, 0..) |action, index| target[index] = action;
    return @intCast(actions.len);
}

pub const WorkspaceColor = extern struct {
    label: [*:0]const u8,
    role: c_uint,
};

pub export fn noctty_grid_workspace_color(
    index: c_int,
    output: ?*WorkspaceColor,
) callconv(.c) c_int {
    const target = output orelse return 0;
    if (index < 0 or index >= 17) return 0;
    const labels = [_][*:0]const u8{
        "Focused pane border",
        "Selected pane border",
        "Unselected pane border",
        "Scrollbar track",
        "Scrollbar thumb",
        "Scrollbar hover / drag",
        "Overlay background",
        "Overlay border",
        "Overlay text",
        "Text selection",
        "Search match",
        "Info status",
        "Success status",
        "Warning status",
        "Error status",
        "Terminal caret",
        "Pane gap",
    };
    target.* = .{
        .label = labels[@intCast(index)],
        .role = @intCast(index + 1),
    };
    return 1;
}

pub const AdaptiveWindowGeometry = extern struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};

pub export fn noctty_grid_adapt_window_geometry(
    mode: c_int,
    current_x: c_int,
    current_y: c_int,
    current_width: c_int,
    current_height: c_int,
    workarea_x: c_int,
    workarea_y: c_int,
    workarea_width: c_int,
    workarea_height: c_int,
    dropdown_width: c_int,
    dropdown_height: c_int,
    output_raw: ?*AdaptiveWindowGeometry,
) callconv(.c) c_int {
    const output = output_raw orelse return 0;
    if (mode < 0 or mode > 2 or workarea_width <= 0 or workarea_height <= 0) {
        return 0;
    }
    const width = switch (mode) {
        0 => std.math.clamp(dropdown_width, 1, workarea_width),
        1 => std.math.clamp(current_width, 1, workarea_width),
        2 => workarea_width,
        else => unreachable,
    };
    const height = switch (mode) {
        0 => std.math.clamp(dropdown_height, 1, workarea_height),
        1 => std.math.clamp(current_height, 1, workarea_height),
        2 => workarea_height,
        else => unreachable,
    };
    const x = switch (mode) {
        0 => workarea_x + @divFloor(workarea_width - width, 2),
        1 => std.math.clamp(
            current_x,
            workarea_x,
            workarea_x + workarea_width - width,
        ),
        2 => workarea_x,
        else => unreachable,
    };
    const y = switch (mode) {
        0, 2 => workarea_y,
        1 => std.math.clamp(
            current_y,
            workarea_y,
            workarea_y + workarea_height - height,
        ),
        else => unreachable,
    };
    output.* = .{ .x = x, .y = y, .width = width, .height = height };
    return 1;
}

pub export fn noctty_grid_resize_delta(
    handle: c_int,
    start_x: f64,
    start_y: f64,
    pointer_x: f64,
    pointer_y: f64,
    horizontal_output: ?*f64,
    vertical_output: ?*f64,
) callconv(.c) void {
    const horizontal = horizontal_output orelse return;
    const vertical = vertical_output orelse return;
    horizontal.* = switch (handle) {
        0, 3, 5 => start_x - pointer_x,
        2, 4, 7 => pointer_x - start_x,
        else => 0,
    };
    vertical.* = switch (handle) {
        0, 1, 2 => start_y - pointer_y,
        5, 6, 7 => pointer_y - start_y,
        else => 0,
    };
}

pub export fn noctty_grid_clamp_resize(
    start: c_int,
    delta: f64,
    minimum: c_int,
    maximum: c_int,
) callconv(.c) c_int {
    if (minimum > maximum or !std.math.isFinite(delta)) return start;
    const candidate = @as(i64, start) + @as(i64, @intFromFloat(delta));
    return @intCast(std.math.clamp(candidate, @as(i64, minimum), @as(i64, maximum)));
}

pub export fn noctty_grid_pointer_cell(
    x: f64,
    y: f64,
    cell_width: f64,
    cell_height: f64,
    columns: c_int,
    rows: c_int,
    clamp: c_int,
    column_output: ?*c_int,
    row_output: ?*c_int,
) callconv(.c) c_int {
    const column = column_output orelse return 0;
    const row = row_output orelse return 0;
    if (cell_width <= 0 or cell_height <= 0 or columns <= 0 or rows <= 0) return 0;
    if (!std.math.isFinite(x) or !std.math.isFinite(y)) return 0;
    const integer_min: f64 = @floatFromInt(std.math.minInt(c_int));
    const integer_max: f64 = @floatFromInt(std.math.maxInt(c_int));
    const column_value = std.math.clamp(@floor((x - 4) / cell_width), integer_min, integer_max);
    const row_value = std.math.clamp(@floor((y - 2) / cell_height), integer_min, integer_max);
    const raw_column: c_int = @intFromFloat(column_value);
    const raw_row: c_int = @intFromFloat(row_value);
    if (clamp == 0 and
        (x < 4 or y < 2 or raw_column < 0 or raw_column >= columns or
            raw_row < 0 or raw_row >= rows)) return 0;
    column.* = std.math.clamp(raw_column, 0, columns - 1);
    row.* = std.math.clamp(raw_row, 0, rows - 1);
    return 1;
}

pub export fn noctty_grid_cell_is_background(
    text: ?[*]const u8,
    length: c_int,
) callconv(.c) c_int {
    const bytes = text orelse return 0;
    if (length < 0) return 0;
    for (bytes[0..@intCast(length)]) |byte| {
        if (byte != ' ') return 0;
    }
    return 1;
}

test "pointer mapping distinguishes bounded hits from clamped drags" {
    var column: c_int = 0;
    var row: c_int = 0;
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_pointer_cell(
        13.9,
        21.9,
        10,
        20,
        80,
        24,
        0,
        &column,
        &row,
    ));
    try std.testing.expectEqual(@as(c_int, 0), column);
    try std.testing.expectEqual(@as(c_int, 0), row);
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_pointer_cell(
        -10,
        -10,
        10,
        20,
        80,
        24,
        0,
        &column,
        &row,
    ));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_pointer_cell(
        -10,
        -10,
        10,
        20,
        80,
        24,
        1,
        &column,
        &row,
    ));
}

test "background cell policy accepts only empty and plain spaces" {
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_cell_is_background("".ptr, 0));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_cell_is_background("   ".ptr, 3));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_cell_is_background("x".ptr, 1));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_cell_is_background("\xc2\xa0".ptr, 2));
}

test "inactive pane brightness scales every channel and preserves active panes" {
    try std.testing.expectEqual(
        @as(u32, 0x703818),
        noctty_grid_scale_brightness(0xa05023, 1, 0, 70),
    );
    try std.testing.expectEqual(
        @as(u32, 0xa05023),
        noctty_grid_scale_brightness(0xa05023, 1, 1, 70),
    );
    try std.testing.expectEqual(
        @as(u32, 0xa05023),
        noctty_grid_scale_brightness(0xa05023, 0, 0, 70),
    );
}

test "active pane selection prefers mapped identity over GTK focus" {
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_pane_is_active(7, 7, 0));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_pane_is_active(7, 8, 1));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_pane_is_active(0, 8, 1));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_pane_is_active(0, 8, 0));
}

test "status names cover protocol states and idle fallback" {
    try std.testing.expectEqualStrings("running", std.mem.span(noctty_grid_status_name(1)));
    try std.testing.expectEqualStrings("done", std.mem.span(noctty_grid_status_name(2)));
    try std.testing.expectEqualStrings("error", std.mem.span(noctty_grid_status_name(3)));
    try std.testing.expectEqualStrings("pending input", std.mem.span(noctty_grid_status_name(4)));
    try std.testing.expectEqualStrings("idle", std.mem.span(noctty_grid_status_name(0)));
}

test "status and notebook chrome plans preserve GTK state precedence" {
    var status = StatusPlan{ .active_kind = 0, .changed = 0 };
    noctty_grid_status_plan(3, 0, &status);
    try std.testing.expectEqual(@as(c_int, 1), status.active_kind);
    try std.testing.expectEqual(@as(c_int, 1), status.changed);
    noctty_grid_status_plan(3, 1, &status);
    try std.testing.expectEqual(@as(c_int, 4), status.active_kind);
    try std.testing.expectEqual(@as(c_int, 1), status.changed);

    var chrome = NotebookChromePlan{ .show = 0 };
    noctty_grid_notebook_chrome_plan(0, 2, &chrome);
    try std.testing.expectEqual(@as(c_int, 1), chrome.show);
    noctty_grid_notebook_chrome_plan(99, 2, &chrome);
    try std.testing.expectEqual(@as(c_int, 0), chrome.show);
    noctty_grid_notebook_chrome_plan(0, 0, &chrome);
    try std.testing.expectEqual(@as(c_int, 0), chrome.show);
}

test "status color plan preserves idle, attention, and protocol colors" {
    var color = StatusColorPlan{ .role = 0, .fallback = 0, .muted = 0 };
    noctty_grid_status_color_plan(0, 0, &color);
    try std.testing.expectEqual(@as(u32, 0), color.role);
    try std.testing.expectEqual(@as(u32, 0), color.fallback);
    try std.testing.expectEqual(@as(c_int, 1), color.muted);

    noctty_grid_status_color_plan(3, 0, &color);
    try std.testing.expectEqual(@as(u32, 15), color.role);
    try std.testing.expectEqual(@as(u32, 0xe64040), color.fallback);
    try std.testing.expectEqual(@as(c_int, 0), color.muted);

    noctty_grid_status_color_plan(1, 1, &color);
    try std.testing.expectEqual(@as(u32, 14), color.role);
    try std.testing.expectEqual(@as(u32, 0xf5b82e), color.fallback);
}

test "profile labels cover every preset and custom fallback" {
    try std.testing.expectEqualStrings("Global default", std.mem.span(noctty_grid_profile_preset_label(0)));
    try std.testing.expectEqualStrings("Compact", std.mem.span(noctty_grid_profile_preset_label(1)));
    try std.testing.expectEqualStrings("Readable", std.mem.span(noctty_grid_profile_preset_label(2)));
    try std.testing.expectEqualStrings("High contrast", std.mem.span(noctty_grid_profile_preset_label(3)));
    try std.testing.expectEqualStrings("Mono no ligatures", std.mem.span(noctty_grid_profile_preset_label(4)));
    try std.testing.expectEqualStrings("Custom", std.mem.span(noctty_grid_profile_preset_label(5)));
}

test "broadcast menu labels distinguish enabled state" {
    try std.testing.expectEqualStrings(
        "Disable Broadcast Input",
        std.mem.span(noctty_grid_broadcast_menu_label(1)),
    );
    try std.testing.expectEqualStrings(
        "Enable Broadcast Input…",
        std.mem.span(noctty_grid_broadcast_menu_label(0)),
    );
}

test "shortcut fields preserve normal and smoke identities" {
    try std.testing.expectEqualStrings("noctty", std.mem.span(noctty_grid_shortcut_field(0, 0)));
    try std.testing.expectEqualStrings("noctty-smoke", std.mem.span(noctty_grid_shortcut_field(0, 1)));
    try std.testing.expectEqualStrings("toggle-window", std.mem.span(noctty_grid_shortcut_field(1, 0)));
    try std.testing.expectEqualStrings("NOCTTY Smoke", std.mem.span(noctty_grid_shortcut_field(2, 1)));
    try std.testing.expectEqualStrings("Show/hide NOCTTY", std.mem.span(noctty_grid_shortcut_field(3, 0)));
    try std.testing.expectEqualStrings("/component/noctty_smoke", std.mem.span(noctty_grid_shortcut_field(4, 1)));
    try std.testing.expectEqualStrings("", std.mem.span(noctty_grid_shortcut_field(9, 0)));
}

test "resize handle layout preserves the complete grid geometry" {
    var layout: ResizeHandleLayout = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_resize_handle_layout(0, 6, 4, &layout));
    try std.testing.expectEqual(@as(c_int, 0), layout.column);
    try std.testing.expectEqual(@as(c_int, 0), layout.row);
    try std.testing.expectEqual(@as(c_int, 6), layout.width);
    try std.testing.expectEqual(@as(c_int, 6), layout.height);
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_resize_handle_layout(6, 6, 4, &layout));
    try std.testing.expectEqual(@as(c_int, 1), layout.column);
    try std.testing.expectEqual(@as(c_int, 2), layout.row);
    try std.testing.expectEqual(@as(c_int, -1), layout.width);
    try std.testing.expectEqual(@as(c_int, 4), layout.height);
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_resize_handle_layout(8, 6, 4, &layout));
}

test "resize event planner preserves dragger and native resize precedence" {
    var plan = ResizeEventPlan{ .action = resize_action_none };
    noctty_grid_resize_event_plan(
        resize_event_press, 6, 1, 0, 0, 0, 0, 0.0, &plan);
    try std.testing.expectEqual(
        @as(c_int, resize_action_arm_click), plan.action);
    noctty_grid_resize_event_plan(
        resize_event_press, 6, 1, 0, 0, 1, 0, 0.0, &plan);
    try std.testing.expectEqual(
        @as(c_int, resize_action_delay_double_click), plan.action);
    noctty_grid_resize_event_plan(
        resize_event_double_press, 6, 1, 0, 0, 0, 0, 0.0, &plan);
    try std.testing.expectEqual(
        @as(c_int, resize_action_toggle_height), plan.action);
    noctty_grid_resize_event_plan(
        resize_event_motion, 6, 1, 0, 0, 1, 1, 25.0, &plan);
    try std.testing.expectEqual(
        @as(c_int, resize_action_begin_drag), plan.action);
    noctty_grid_resize_event_plan(
        resize_event_press, 2, 1, 1, 0, 0, 0, 0.0, &plan);
    try std.testing.expectEqual(
        @as(c_int, resize_action_begin_drag), plan.action);
    noctty_grid_resize_event_plan(
        resize_event_motion, 2, 1, 1, 1, 0, 1, 0.0, &plan);
    try std.testing.expectEqual(
        @as(c_int, resize_action_update_drag), plan.action);
    noctty_grid_resize_event_plan(
        resize_event_motion, 2, 1, 1, 1, 0, 0, 0.0, &plan);
    try std.testing.expectEqual(
        @as(c_int, resize_action_finish_drag), plan.action);
}

test "window mode planner preserves recreation and surface precedence" {
    var plan = WindowModePlan{ .action = window_mode_action_none };
    noctty_grid_window_mode_plan(0, 1, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, window_mode_action_recreate), plan.action);
    noctty_grid_window_mode_plan(1, 2, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, window_mode_action_apply_fullscreen), plan.action);
    noctty_grid_window_mode_plan(2, 1, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, window_mode_action_apply_window), plan.action);
    noctty_grid_window_mode_plan(1, 0, 1, &plan);
    try std.testing.expectEqual(
        @as(c_int, window_mode_action_recreate), plan.action);
    noctty_grid_window_mode_plan(1, 1, 1, &plan);
    try std.testing.expectEqual(
        @as(c_int, window_mode_action_apply_layer_geometry), plan.action);
    noctty_grid_window_mode_plan(-1, 1, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, window_mode_action_none), plan.action);
}

test "overlay stacking planner preserves layer and existing precedence" {
    var plan = OverlayStackingPlan{ .action = overlay_stacking_none, .lower_parent = 0 };
    noctty_grid_overlay_stacking_plan(0, 0, 0, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, overlay_stacking_basic), plan.action);
    try std.testing.expectEqual(@as(c_int, 0), plan.lower_parent);
    noctty_grid_overlay_stacking_plan(1, 1, 0, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, overlay_stacking_layer), plan.action);
    try std.testing.expectEqual(@as(c_int, 1), plan.lower_parent);
    noctty_grid_overlay_stacking_plan(1, 1, 0, 2, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.lower_parent);
    noctty_grid_overlay_stacking_plan(1, 1, 1, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, overlay_stacking_existing), plan.action);
    noctty_grid_overlay_stacking_plan(0, 1, 1, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, overlay_stacking_existing), plan.action);
}

test "window visibility planner preserves hide and show transitions" {
    var plan = WindowVisibilityPlan{ .action = visibility_action_none };
    noctty_grid_window_visibility_plan(1, 1, &plan);
    try std.testing.expectEqual(@as(c_int, visibility_action_hide), plan.action);
    noctty_grid_window_visibility_plan(1, 0, &plan);
    try std.testing.expectEqual(@as(c_int, visibility_action_show), plan.action);
    noctty_grid_window_visibility_plan(0, 1, &plan);
    try std.testing.expectEqual(@as(c_int, visibility_action_show), plan.action);
    noctty_grid_window_visibility_plan(0, 0, &plan);
    try std.testing.expectEqual(@as(c_int, visibility_action_show), plan.action);
}

test "overlay geometry planner preserves centered monitor margins" {
    var plan = OverlayGeometryPlan{ .left = -1, .right = -1, .top = -1, .bottom = -1 };
    noctty_grid_overlay_geometry_plan(100, 50, 800, 600, 0, 0, 1920, 1080, 400, 200, &plan);
    try std.testing.expectEqual(@as(c_int, 300), plan.left);
    try std.testing.expectEqual(@as(c_int, 1220), plan.right);
    try std.testing.expectEqual(@as(c_int, 250), plan.top);
    try std.testing.expectEqual(@as(c_int, 630), plan.bottom);
    noctty_grid_overlay_geometry_plan(0, 0, 100, 100, 0, 0, 100, 100, 140, 140, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.left);
    try std.testing.expectEqual(@as(c_int, 0), plan.right);
    try std.testing.expectEqual(@as(c_int, 0), plan.top);
    try std.testing.expectEqual(@as(c_int, 0), plan.bottom);
}

test "fullscreen planner preserves native fallback precedence" {
    var plan = FullscreenPlan{ .action = fullscreen_action_current_monitor };
    noctty_grid_fullscreen_plan(0, 0, -1, &plan);
    try std.testing.expectEqual(@as(c_int, fullscreen_action_window), plan.action);
    noctty_grid_fullscreen_plan(1, 1, 2, &plan);
    try std.testing.expectEqual(@as(c_int, fullscreen_action_current_monitor), plan.action);
    noctty_grid_fullscreen_plan(1, 0, -1, &plan);
    try std.testing.expectEqual(@as(c_int, fullscreen_action_current_monitor), plan.action);
    noctty_grid_fullscreen_plan(1, 0, 2, &plan);
    try std.testing.expectEqual(@as(c_int, fullscreen_action_monitor), plan.action);
}

test "layout preset plan preserves every native preset geometry" {
    var plan = LayoutPresetPlan{
        .valid = 0,
        .rows = 0,
        .columns = 0,
        .target_count = 0,
    };
    const cases = [_]struct {
        event_code: c_int,
        rows: c_int,
        columns: c_int,
        target_count: c_int,
    }{
        .{ .event_code = 50, .rows = 1, .columns = 1, .target_count = 1 },
        .{ .event_code = 51, .rows = 2, .columns = 2, .target_count = 4 },
        .{ .event_code = 52, .rows = 3, .columns = 3, .target_count = 9 },
        .{ .event_code = 60, .rows = 4, .columns = 4, .target_count = 16 },
        .{ .event_code = 61, .rows = 2, .columns = 4, .target_count = 8 },
    };
    for (cases) |expected| {
        noctty_grid_layout_preset_plan(expected.event_code, &plan);
        try std.testing.expectEqual(@as(c_int, 1), plan.valid);
        try std.testing.expectEqual(expected.rows, plan.rows);
        try std.testing.expectEqual(expected.columns, plan.columns);
        try std.testing.expectEqual(expected.target_count, plan.target_count);
    }
    noctty_grid_layout_preset_plan(53, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.valid);
}

test "panel settings plan clamps fields and classifies layout effects" {
    var settings = std.mem.zeroes(PanelSettings);
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_panel_settings_apply(46, -5, &settings),
    );
    try std.testing.expectEqual(@as(c_int, 0), settings.panel_padding_px);
    try std.testing.expectEqual(@as(c_int, 1), settings.affects_layout);
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_panel_settings_apply(115, 7, &settings),
    );
    try std.testing.expectEqual(@as(c_int, 1), settings.background_translucency);
    try std.testing.expectEqual(@as(c_int, 0), settings.affects_layout);
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_panel_settings_apply(130, 101, &settings),
    );
    try std.testing.expectEqual(
        @as(c_int, 100), settings.inactive_pane_brightness_percent);
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_panel_settings_apply(131, 4, &settings),
    );
}

test "layer geometry planner preserves dropdown zen and window sizing" {
    var plan = LayerGeometryPlan{
        .action = layer_geometry_none,
        .width = 0,
        .height = 0,
        .left = 0,
        .right = 0,
        .bottom = 0,
    };
    noctty_grid_layer_geometry_plan(0, 1920, 1080, 900, 50, 420, 50, &plan);
    try std.testing.expectEqual(@as(c_int, layer_geometry_dropdown), plan.action);
    try std.testing.expectEqual(@as(c_int, 900), plan.width);
    try std.testing.expectEqual(@as(c_int, 420), plan.height);
    try std.testing.expectEqual(@as(c_int, 510), plan.left);
    try std.testing.expectEqual(@as(c_int, 510), plan.right);
    try std.testing.expectEqual(@as(c_int, 660), plan.bottom);
    noctty_grid_layer_geometry_plan(2, 1920, 1080, 0, 0, 0, 0, &plan);
    try std.testing.expectEqual(@as(c_int, layer_geometry_zen), plan.action);
    try std.testing.expectEqual(@as(c_int, -1), plan.width);
    try std.testing.expectEqual(@as(c_int, -1), plan.height);
    noctty_grid_layer_geometry_plan(1, 1200, 800, 0, 0, 0, 0, &plan);
    try std.testing.expectEqual(@as(c_int, layer_geometry_window), plan.action);
    try std.testing.expectEqual(@as(c_int, 960), plan.width);
    try std.testing.expectEqual(@as(c_int, 600), plan.height);
}

test "monitor selection planner preserves fallback precedence" {
    var plan = MonitorSelectionPlan{ .action = monitor_selection_none };
    noctty_grid_monitor_selection_plan(1, 1, 1, 3, &plan);
    try std.testing.expectEqual(@as(c_int, monitor_selection_window), plan.action);
    noctty_grid_monitor_selection_plan(0, 1, 1, 3, &plan);
    try std.testing.expectEqual(@as(c_int, monitor_selection_primary), plan.action);
    noctty_grid_monitor_selection_plan(0, 0, 1, 3, &plan);
    try std.testing.expectEqual(@as(c_int, monitor_selection_pointer), plan.action);
    noctty_grid_monitor_selection_plan(0, 0, 0, 2, &plan);
    try std.testing.expectEqual(@as(c_int, monitor_selection_first), plan.action);
    noctty_grid_monitor_selection_plan(0, 0, 0, 0, &plan);
    try std.testing.expectEqual(@as(c_int, monitor_selection_none), plan.action);
}

test "monitor metrics policy clamps scale and detects topology changes" {
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_monitor_scale_factor(0));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_monitor_scale_factor(-2));
    try std.testing.expectEqual(@as(c_int, 2), noctty_grid_monitor_scale_factor(2));
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_monitor_metrics_changed(
            0, 0, 1920, 1080, 0, 24, 1920, 1056, 1,
            0, 0, 1920, 1080, 0, 24, 1920, 1056, 1,
        ),
    );
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_monitor_metrics_changed(
            10, 0, 1920, 1080, 0, 24, 1920, 1056, 2,
            0, 0, 1920, 1080, 0, 24, 1920, 1056, 1,
        ),
    );
}

test "pane snap policy selects nearby thirds and rejects distant positions" {
    try std.testing.expectEqual(@as(c_int, 25), noctty_grid_snap_pane_position(100, 24));
    try std.testing.expectEqual(@as(c_int, 50), noctty_grid_snap_pane_position(100, 51));
    try std.testing.expectEqual(@as(c_int, 66), noctty_grid_snap_pane_position(100, 76));
    try std.testing.expectEqual(@as(c_int, 75), noctty_grid_snap_pane_position(100, 86));
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_snap_pane_position(100, 12));
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_snap_pane_position(0, 12));
}

test "palette action policy preserves ordered ids and labels" {
    var actions: [27]PaletteAction = undefined;
    try std.testing.expectEqual(@as(c_uint, 27), noctty_grid_palette_actions(&actions, actions.len));
    try std.testing.expectEqual(@as(c_int, 1), actions[0].id);
    try std.testing.expectEqualStrings("New terminal tab", std.mem.span(actions[0].label));
    try std.testing.expectEqual(@as(c_int, 18), actions[11].id);
    try std.testing.expectEqualStrings("Open NoctEd here", std.mem.span(actions[11].label));
    try std.testing.expectEqual(@as(c_int, 27), actions[26].id);
    try std.testing.expectEqual(@as(c_uint, 0), noctty_grid_palette_actions(&actions, 26));
}

test "workspace color policy preserves labels and sequential roles" {
    var color: WorkspaceColor = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_workspace_color(0, &color));
    try std.testing.expectEqualStrings("Focused pane border", std.mem.span(color.label));
    try std.testing.expectEqual(@as(c_uint, 1), color.role);
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_workspace_color(16, &color));
    try std.testing.expectEqualStrings("Pane gap", std.mem.span(color.label));
    try std.testing.expectEqual(@as(c_uint, 17), color.role);
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_workspace_color(17, &color));
}

test "resolution adaptation preserves window intent within every workarea" {
    var geometry: AdaptiveWindowGeometry = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_adapt_window_geometry(
        0,
        0,
        0,
        800,
        600,
        100,
        40,
        1200,
        800,
        1000,
        500,
        &geometry,
    ));
    try std.testing.expectEqualDeep(
        AdaptiveWindowGeometry{ .x = 200, .y = 40, .width = 1000, .height = 500 },
        geometry,
    );
    _ = noctty_grid_adapt_window_geometry(
        1,
        900,
        700,
        1400,
        900,
        100,
        40,
        1200,
        800,
        0,
        0,
        &geometry,
    );
    try std.testing.expectEqualDeep(
        AdaptiveWindowGeometry{ .x = 100, .y = 40, .width = 1200, .height = 800 },
        geometry,
    );
    _ = noctty_grid_adapt_window_geometry(
        2,
        900,
        700,
        400,
        300,
        100,
        40,
        1200,
        800,
        0,
        0,
        &geometry,
    );
    try std.testing.expectEqualDeep(
        AdaptiveWindowGeometry{ .x = 100, .y = 40, .width = 1200, .height = 800 },
        geometry,
    );
}

test "resize handles preserve directional deltas and bounds" {
    var horizontal: f64 = 0;
    var vertical: f64 = 0;
    noctty_grid_resize_delta(0, 100, 100, 90, 80, &horizontal, &vertical);
    try std.testing.expectEqual(@as(f64, 10), horizontal);
    try std.testing.expectEqual(@as(f64, 20), vertical);
    try std.testing.expectEqual(@as(c_int, 320), noctty_grid_clamp_resize(300, -50, 320, 900));
    try std.testing.expectEqual(@as(c_int, 900), noctty_grid_clamp_resize(850, 100, 320, 900));
}

test "font metrics convert points once and preserve finite cell floors" {
    var metrics: FontMetrics = undefined;
    noctty_grid_font_metrics(12, &metrics);
    try std.testing.expectApproxEqAbs(@as(f64, 16), metrics.font_px, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 10.24), metrics.cell_width, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 20.48), metrics.cell_height, 0.0001);

    noctty_grid_font_metrics(1, &metrics);
    try std.testing.expectEqual(@as(f64, 3), metrics.cell_width);
    try std.testing.expectEqual(@as(f64, 5), metrics.cell_height);

    var fallback: FontMetrics = undefined;
    noctty_grid_font_metrics(0, &fallback);
    for ([_]f64{
        std.math.nan(f64),
        std.math.inf(f64),
        std.math.floatMax(f64),
    }) |invalid| {
        noctty_grid_font_metrics(invalid, &metrics);
        try std.testing.expectEqualDeep(fallback, metrics);
    }
}

test "auto-fit and grid dimensions remain bounded" {
    var size: f64 = 0;
    var zoom: c_int = 0;
    var floor_reached: c_int = 0;
    noctty_grid_auto_fit(13, 320, 180, 1, &size, &zoom, &floor_reached);
    try std.testing.expect(size >= 3 and size <= 13);
    try std.testing.expect(zoom >= 1 and zoom <= 100);
    var width: c_int = 0;
    var columns: c_int = 0;
    var rows: c_int = 0;
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_dimensions(
        800,
        600,
        10,
        10,
        20,
        &width,
        &columns,
        &rows,
    ));
    try std.testing.expectEqual(@as(c_int, 790), width);
    try std.testing.expectEqual(@as(c_int, 79), columns);
    try std.testing.expectEqual(@as(c_int, 30), rows);
    var spacing: PanelSpacingPlan = undefined;
    noctty_grid_panel_spacing_plan(0, -5, &spacing);
    try std.testing.expectEqual(@as(c_int, 0), spacing.leading);
    try std.testing.expectEqual(@as(c_int, 0), spacing.trailing);
    noctty_grid_panel_spacing_plan(1, 5, &spacing);
    try std.testing.expectEqual(@as(c_int, 2), spacing.leading);
    try std.testing.expectEqual(@as(c_int, 3), spacing.trailing);
    noctty_grid_panel_spacing_plan(1, -5, &spacing);
    try std.testing.expectEqual(@as(c_int, -2), spacing.leading);
    try std.testing.expectEqual(@as(c_int, -3), spacing.trailing);

    var bounds: AutoFitBounds = undefined;
    noctty_grid_auto_fit_bounds(800, 600, 1, 1200, &bounds);
    try std.testing.expectEqual(@as(c_int, 800), bounds.width);
    try std.testing.expectEqual(@as(c_int, 600), bounds.height);
    noctty_grid_auto_fit_bounds(800, 600, 700, 400, &bounds);
    try std.testing.expectEqual(@as(c_int, 700), bounds.width);
    try std.testing.expectEqual(@as(c_int, 400), bounds.height);

    var resize: ResizePlan = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_resize_plan(
        800, 600, 10, 10, 20, 79, 30, &resize,
    ));
    try std.testing.expectEqual(@as(c_int, 790), resize.terminal_width);
    try std.testing.expectEqual(@as(c_int, 79), resize.columns);
    try std.testing.expectEqual(@as(c_int, 30), resize.rows);
    try std.testing.expectEqual(@as(c_int, 0), resize.changed);
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_resize_plan(
        800, 600, 10, 10, 20, 78, 30, &resize,
    ));
    try std.testing.expectEqual(@as(c_int, 1), resize.changed);
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_resize_plan(
        0, 600, 10, 10, 20, 0, 0, &resize,
    ));
}

test "scroll steps preserve discrete and smooth accumulation" {
    var accumulator: f64 = 0;
    try std.testing.expectEqual(@as(c_int, 3), noctty_grid_scroll_steps(3, 0, -1, 0, &accumulator));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_scroll_steps(3, 1, 0, 0.2, &accumulator));
    try std.testing.expectEqual(@as(c_int, -3), noctty_grid_scroll_steps(3, 1, 0, 0.8, &accumulator));
}
test "routed wheel actions preserve every discrete direction convention" {
    const cases = [_]struct {
        modifiers: u32,
        route: c_int,
    }{
        .{ .modifiers = modifier_control | modifier_alt, .route = route_tab_cycle },
        .{ .modifiers = modifier_alt, .route = route_pane_cycle },
        .{ .modifiers = modifier_control, .route = route_font_zoom },
    };
    for (cases) |case| {
        const route = noctty_grid_input_route(
            input_wheel,
            0,
            0,
            0,
            0,
            case.modifiers,
        );
        try std.testing.expectEqual(case.route, route);
        for ([_]c_int{ -1, 1 }) |scroll_direction| {
            var accumulator: f64 = 0.75;
            var plan: WheelActionPlan = undefined;
            noctty_grid_wheel_action_plan(
                route,
                scroll_direction,
                std.math.nan(f64),
                &accumulator,
                &plan,
            );
            try std.testing.expectEqual(@as(c_int, 1), plan.steps);
            const expected_direction = if (route == route_font_zoom)
                -scroll_direction
            else
                scroll_direction;
            try std.testing.expectEqual(expected_direction, plan.direction);
            try std.testing.expectEqual(@as(f64, 0), accumulator);
        }
    }
}

test "wheel action plans accumulate fractions and cross both thresholds" {
    var accumulator: f64 = 0;
    var plan: WheelActionPlan = undefined;

    noctty_grid_wheel_action_plan(route_tab_cycle, 0, 0.4, &accumulator, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.steps);
    try std.testing.expectApproxEqAbs(@as(f64, 0.4), accumulator, 1e-12);
    noctty_grid_wheel_action_plan(route_tab_cycle, 0, 0.6, &accumulator, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.steps);
    try std.testing.expectEqual(@as(c_int, 1), plan.direction);
    try std.testing.expectApproxEqAbs(@as(f64, 0), accumulator, 1e-12);

    noctty_grid_wheel_action_plan(route_pane_cycle, 0, -0.25, &accumulator, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.steps);
    noctty_grid_wheel_action_plan(route_pane_cycle, 0, -0.75, &accumulator, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.steps);
    try std.testing.expectEqual(@as(c_int, -1), plan.direction);
    try std.testing.expectApproxEqAbs(@as(f64, 0), accumulator, 1e-12);

    noctty_grid_wheel_action_plan(route_font_zoom, 0, 1.25, &accumulator, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.steps);
    try std.testing.expectEqual(@as(c_int, -1), plan.direction);
    try std.testing.expectApproxEqAbs(@as(f64, -0.25), accumulator, 1e-12);
}

test "wheel action plans saturate each event while retaining overflow" {
    var accumulator: f64 = 0;
    var plan: WheelActionPlan = undefined;
    noctty_grid_wheel_action_plan(route_tab_cycle, 0, 12.75, &accumulator, &plan);
    try std.testing.expectEqual(@as(c_int, 8), plan.steps);
    try std.testing.expectEqual(@as(c_int, 1), plan.direction);
    try std.testing.expectApproxEqAbs(@as(f64, 4.75), accumulator, 1e-12);
    noctty_grid_wheel_action_plan(route_tab_cycle, 0, 0, &accumulator, &plan);
    try std.testing.expectEqual(@as(c_int, 4), plan.steps);
    try std.testing.expectEqual(@as(c_int, 1), plan.direction);
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), accumulator, 1e-12);

    accumulator = 0;
    noctty_grid_wheel_action_plan(route_pane_cycle, 0, -12.75, &accumulator, &plan);
    try std.testing.expectEqual(@as(c_int, 8), plan.steps);
    try std.testing.expectEqual(@as(c_int, -1), plan.direction);
    try std.testing.expectApproxEqAbs(@as(f64, -4.75), accumulator, 1e-12);
}

test "wheel action plans reject invalid and non-finite smooth inputs" {
    const routes = [_]c_int{
        route_ignore,
        route_scrollbar,
        route_selection,
        route_application_mouse,
        route_terminal_scroll,
        route_local_pointer,
        std.math.maxInt(c_int),
    };
    for (routes) |route| {
        var accumulator: f64 = 0.5;
        var plan = WheelActionPlan{ .steps = 7, .direction = -1 };
        noctty_grid_wheel_action_plan(route, 0, 2, &accumulator, &plan);
        try std.testing.expectEqual(@as(c_int, 0), plan.steps);
        try std.testing.expectEqual(@as(c_int, 0), plan.direction);
        try std.testing.expectEqual(@as(f64, 0.5), accumulator);
    }

    for ([_]f64{ std.math.nan(f64), std.math.inf(f64), -std.math.inf(f64) }) |delta| {
        var accumulator: f64 = 0.5;
        var plan: WheelActionPlan = undefined;
        noctty_grid_wheel_action_plan(route_tab_cycle, 0, delta, &accumulator, &plan);
        try std.testing.expectEqual(@as(c_int, 0), plan.steps);
        try std.testing.expectEqual(@as(c_int, 0), plan.direction);
        try std.testing.expectEqual(@as(f64, 0.5), accumulator);
    }

    for ([_]c_int{ -2, 2, std.math.maxInt(c_int) }) |direction| {
        var accumulator: f64 = 0.5;
        var plan: WheelActionPlan = undefined;
        noctty_grid_wheel_action_plan(route_font_zoom, direction, 2, &accumulator, &plan);
        try std.testing.expectEqual(@as(c_int, 0), plan.steps);
        try std.testing.expectEqual(@as(c_int, 0), plan.direction);
        try std.testing.expectEqual(@as(f64, 0.5), accumulator);
    }
}

test "keyboard scroll targets saturate at history boundaries" {
    try std.testing.expectEqual(@as(u64, 100), noctty_grid_keyboard_scroll_target(100, 90, 20, 1));
    try std.testing.expectEqual(@as(u64, 0), noctty_grid_keyboard_scroll_target(100, 10, 20, 2));
    try std.testing.expectEqual(@as(u64, 100), noctty_grid_keyboard_scroll_target(100, 10, 20, 3));
    try std.testing.expectEqual(@as(u64, 0), noctty_grid_keyboard_scroll_target(100, 90, 20, 4));
}

test "scrollbar geometry clamps offset and thumb" {
    var geometry: ScrollbarGeometry = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_scrollbar_geometry(
        800,
        600,
        10,
        24,
        1000,
        2000,
        40,
        &geometry,
    ));
    try std.testing.expectEqual(@as(u64, 1000), geometry.viewport_offset);
    try std.testing.expect(geometry.thumb_height >= 24);
    try std.testing.expectEqual(geometry.y, geometry.thumb_y);
}

test "scrollbar press planning distinguishes thumb drag and saturated pages" {
    var geometry = ScrollbarGeometry{
        .x = 788,
        .y = 2,
        .width = 12,
        .height = 100,
        .thumb_y = 42,
        .thumb_height = 20,
        .history_lines = 100,
        .viewport_offset = 50,
        .visible_rows = 10,
    };
    var plan: ScrollbarPressPlan = undefined;
    noctty_grid_scrollbar_press_plan(&geometry, 50, &plan);
    try std.testing.expectEqual(scrollbar_press_drag, plan.action);
    try std.testing.expectEqual(@as(f64, 8), plan.drag_offset);
    try std.testing.expectEqual(@as(u64, 50), plan.target_offset);

    noctty_grid_scrollbar_press_plan(&geometry, 41, &plan);
    try std.testing.expectEqual(scrollbar_press_page, plan.action);
    try std.testing.expectEqual(@as(u64, 59), plan.target_offset);
    noctty_grid_scrollbar_press_plan(&geometry, 63, &plan);
    try std.testing.expectEqual(@as(u64, 41), plan.target_offset);

    geometry.viewport_offset = 98;
    noctty_grid_scrollbar_press_plan(&geometry, 41, &plan);
    try std.testing.expectEqual(@as(u64, 100), plan.target_offset);
    geometry.viewport_offset = 2;
    noctty_grid_scrollbar_press_plan(&geometry, 63, &plan);
    try std.testing.expectEqual(@as(u64, 0), plan.target_offset);

    noctty_grid_scrollbar_press_plan(&geometry, std.math.nan(f64), &plan);
    try std.testing.expectEqual(scrollbar_press_none, plan.action);
}

test "scrollbar drag targets map the complete track to history" {
    const geometry = ScrollbarGeometry{
        .x = 788,
        .y = 2,
        .width = 12,
        .height = 100,
        .thumb_y = 42,
        .thumb_height = 20,
        .history_lines = 100,
        .viewport_offset = 50,
        .visible_rows = 10,
    };
    var target: u64 = undefined;
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_scrollbar_drag_target(&geometry, 10, 8, &target),
    );
    try std.testing.expectEqual(@as(u64, 100), target);
    _ = noctty_grid_scrollbar_drag_target(&geometry, 50, 8, &target);
    try std.testing.expectEqual(@as(u64, 50), target);
    _ = noctty_grid_scrollbar_drag_target(&geometry, 90, 8, &target);
    try std.testing.expectEqual(@as(u64, 0), target);
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_scrollbar_drag_target(
            &geometry,
            std.math.inf(f64),
            8,
            &target,
        ),
    );
    try std.testing.expectEqual(@as(u64, 50), target);
}

test "linear selection is direction independent" {
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_cell_selected(1, 4, 3, 1, 1, 1, 1));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_cell_selected(1, 4, 3, 1, 1, 9, 2));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_cell_selected(1, 4, 3, 1, 1, 0, 1));
}

test "cell and row spans preserve seamless pixel bounds" {
    var rectangle: Rectangle = undefined;
    noctty_grid_cell_span(1, 3, 2, 9.5, 18.25, 1, &rectangle);
    try std.testing.expectEqual(@as(f64, 13), rectangle.x);
    try std.testing.expectEqual(@as(f64, 20), rectangle.width);
    try std.testing.expectEqual(@as(f64, 38), rectangle.y);
    try std.testing.expectEqual(@as(f64, 19), rectangle.height);

    noctty_grid_row_span(1, 3, 18.25, &rectangle);
    try std.testing.expectEqual(@as(f64, 0), rectangle.x);
    try std.testing.expectEqual(@as(f64, 20), rectangle.y);
    try std.testing.expectEqual(@as(f64, 0), rectangle.width);
    try std.testing.expectEqual(@as(f64, 37), rectangle.height);
}

test "pointer routing exhaustively preserves scrollbar selection and mouse precedence" {
    const expected = [_]c_int{
        route_local_pointer,
        route_selection,
        route_application_mouse,
        route_application_mouse,
        route_scrollbar,
        route_scrollbar,
        route_scrollbar,
        route_scrollbar,
    };
    for (0..2) |scrollbar_owned| {
        for (0..2) |mouse_mode| {
            for (0..2) |primary| {
                const index = scrollbar_owned * 4 + mouse_mode * 2 + primary;
                for (0..8) |modifiers| {
                    try std.testing.expectEqual(expected[index], noctty_grid_input_route(
                        input_pointer,
                        @intCast(scrollbar_owned),
                        @intCast(mouse_mode),
                        0,
                        @intCast(primary),
                        @intCast(modifiers),
                    ));
                }
            }
        }
    }
}

test "wheel routing exhaustively preserves modifier and mouse mode precedence" {
    const expected_without_mouse = [_]c_int{
        route_terminal_scroll,
        route_terminal_scroll,
        route_font_zoom,
        route_font_zoom,
        route_pane_cycle,
        route_pane_cycle,
        route_tab_cycle,
        route_tab_cycle,
    };
    const expected_with_mouse = [_]c_int{
        route_application_mouse,
        route_terminal_scroll,
        route_font_zoom,
        route_font_zoom,
        route_pane_cycle,
        route_pane_cycle,
        route_tab_cycle,
        route_tab_cycle,
    };
    for (0..8) |modifiers| {
        const flags: u32 = @intCast(modifiers);
        try std.testing.expectEqual(
            expected_without_mouse[modifiers],
            noctty_grid_input_route(input_wheel, 0, 0, 0, 0, flags),
        );
        try std.testing.expectEqual(
            expected_with_mouse[modifiers],
            noctty_grid_input_route(input_wheel, 0, 1, 0, 0, flags),
        );
    }
}

test "alternate-screen wheel falls back to application keys without history" {
    try std.testing.expectEqual(
        route_application_keys,
        noctty_grid_input_route(
            input_wheel,
            0,
            terminal_mode_alternate_screen,
            0,
            0,
            0,
        ),
    );
    try std.testing.expectEqual(
        route_terminal_scroll,
        noctty_grid_input_route(
            input_wheel,
            0,
            terminal_mode_alternate_screen,
            1,
            0,
            0,
        ),
    );
    try std.testing.expectEqual(
        route_terminal_scroll,
        noctty_grid_input_route(
            input_wheel,
            0,
            terminal_mode_alternate_screen,
            0,
            0,
            modifier_shift,
        ),
    );
    try std.testing.expectEqual(
        route_application_mouse,
        noctty_grid_input_route(
            input_wheel,
            0,
            terminal_mode_alternate_screen | terminal_mode_mouse,
            0,
            0,
            0,
        ),
    );
}

test "alternate-screen wheel keys honor direction cursor mode and bounds" {
    var output: [192]u8 = undefined;
    var length = noctty_grid_wheel_key_sequence(0, 2, &output, output.len);
    try std.testing.expectEqual(@as(c_int, 6), length);
    try std.testing.expectEqualStrings("\x1b[A\x1b[A", output[0..@intCast(length)]);

    length = noctty_grid_wheel_key_sequence(1, -2, &output, output.len);
    try std.testing.expectEqual(@as(c_int, 6), length);
    try std.testing.expectEqualStrings("\x1bOB\x1bOB", output[0..@intCast(length)]);

    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_wheel_key_sequence(0, 1, &output, 2),
    );
    try std.testing.expectEqual(
        @as(c_int, 192),
        noctty_grid_wheel_key_sequence(0, std.math.maxInt(c_int), &output, output.len),
    );
}

test "terminal key encoding covers Unicode navigation and function keys" {
    var output: [8]u8 = undefined;
    var length = noctty_grid_terminal_key_sequence(
        'x',
        'x',
        modifier_alt,
        0,
        &output,
        output.len,
    );
    try std.testing.expectEqual(@as(c_int, 2), length);
    try std.testing.expectEqualStrings("\x1bx", output[0..@intCast(length)]);

    length = noctty_grid_terminal_key_sequence(
        'C',
        'C',
        modifier_control | modifier_alt,
        0,
        &output,
        output.len,
    );
    try std.testing.expectEqual(@as(c_int, 1), length);
    try std.testing.expectEqualSlices(u8, &.{3}, output[0..@intCast(length)]);

    length = noctty_grid_terminal_key_sequence(
        0,
        0x1f680,
        0,
        0,
        &output,
        output.len,
    );
    try std.testing.expectEqual(@as(c_int, 4), length);
    try std.testing.expectEqualStrings("🚀", output[0..@intCast(length)]);

    length = noctty_grid_terminal_key_sequence(
        gdk_key_up,
        0,
        0,
        1,
        &output,
        output.len,
    );
    try std.testing.expectEqual(@as(c_int, 3), length);
    try std.testing.expectEqualStrings("\x1bOA", output[0..@intCast(length)]);

    length = noctty_grid_terminal_key_sequence(
        gdk_key_f12,
        0,
        0,
        0,
        &output,
        output.len,
    );
    try std.testing.expectEqual(@as(c_int, 5), length);
    try std.testing.expectEqualStrings("\x1b[24~", output[0..@intCast(length)]);
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_terminal_key_sequence(0, 0xd800, 0, 0, &output, output.len),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_terminal_key_sequence(gdk_key_f12, 0, 0, 0, &output, 4),
    );
}

test "shortcut labels are bounded and name supported keys" {
    var output: [64]u8 = undefined;
    var length = noctty_grid_shortcut_label(0, &output, output.len);
    try std.testing.expectEqualStrings("Unassigned", output[0..@intCast(length)]);
    length = noctty_grid_shortcut_label(
        0x04000000 | 0x02000000 | 'K',
        &output,
        output.len,
    );
    try std.testing.expectEqualStrings("Ctrl+Shift+K", output[0..@intCast(length)]);
    length = noctty_grid_shortcut_label(
        0x08000000 | 0x0100003b,
        &output,
        output.len,
    );
    try std.testing.expectEqualStrings("Alt+F12", output[0..@intCast(length)]);
    length = noctty_grid_shortcut_label(0x01000016, &output, output.len);
    try std.testing.expectEqualStrings("Page Up", output[0..@intCast(length)]);
    length = noctty_grid_shortcut_label(1, &output, output.len);
    try std.testing.expectEqualStrings("Unknown", output[0..@intCast(length)]);
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_shortcut_label(0x04000000 | 'A', &output, 2),
    );
}

test "shortcut settings text preserves transport-specific guidance" {
    var label: [128]u8 = undefined;
    var tooltip: [256]u8 = undefined;
    var plan = ShortcutTextPlan{ .label_length = 0, .tooltip_length = 0 };
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_shortcut_settings_text(
            0x04000000 | 0x02000000 | 'K',
            1,
            &label,
            label.len,
            &tooltip,
            tooltip.len,
            &plan,
        ),
    );
    try std.testing.expectEqualStrings(
        "Ctrl+Shift+K — Change shortcut…",
        label[0..@intCast(plan.label_length)],
    );
    try std.testing.expectEqualStrings(
        "Current shortcut: Ctrl+Shift+K. Select to change the Plasma global shortcut.",
        tooltip[0..@intCast(plan.tooltip_length)],
    );
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_shortcut_settings_text(
            0,
            0,
            &label,
            label.len,
            &tooltip,
            tooltip.len,
            &plan,
        ),
    );
    try std.testing.expectEqualStrings(
        "Unassigned — Change shortcut…",
        label[0..@intCast(plan.label_length)],
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_shortcut_settings_text(
            0,
            0,
            &label,
            8,
            &tooltip,
            tooltip.len,
            &plan,
        ),
    );
}

test "GTK modifier masks and Alt key names map to native flags" {
    try std.testing.expectEqual(@as(u32, modifier_shift | modifier_control | modifier_alt), noctty_grid_input_modifiers(gdk_shift_mask | gdk_control_mask | gdk_mod1_mask));
    try std.testing.expectEqual(@as(u32, modifier_alt), noctty_grid_input_modifiers(gdk_mod1_mask));
    try std.testing.expectEqual(@as(u32, 0), noctty_grid_input_modifiers(0));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_is_alt_key(gdk_key_alt_l));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_is_alt_key(gdk_key_meta_r));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_is_alt_key('A'));
}

test "tray ids and resize cursor policy stay bounded" {
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_tray_menu_id_valid(0));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_tray_menu_id_valid(4));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_tray_menu_id_valid(-1));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_tray_menu_id_valid(5));
    try std.testing.expectEqualStrings("ew-resize", std.mem.span(noctty_grid_window_resize_cursor_name(3)));
    try std.testing.expectEqualStrings("ew-resize", std.mem.span(noctty_grid_window_resize_cursor_name(4)));
    try std.testing.expectEqualStrings("ns-resize", std.mem.span(noctty_grid_window_resize_cursor_name(0)));
}

test "tray labels and icons preserve every menu state" {
    try std.testing.expectEqualStrings("Show NOCTTY", std.mem.span(noctty_grid_tray_menu_label(1, 0)));
    try std.testing.expectEqualStrings("Hide NOCTTY", std.mem.span(noctty_grid_tray_menu_label(1, 1)));
    try std.testing.expectEqualStrings("Settings…", std.mem.span(noctty_grid_tray_menu_label(2, 0)));
    try std.testing.expectEqualStrings("Close NOCTTY", std.mem.span(noctty_grid_tray_menu_label(4, 0)));
    try std.testing.expectEqualStrings("", std.mem.span(noctty_grid_tray_menu_label(3, 0)));
    try std.testing.expectEqualStrings("view-visible", std.mem.span(noctty_grid_tray_menu_icon_name(1)));
    try std.testing.expectEqualStrings("configure", std.mem.span(noctty_grid_tray_menu_icon_name(2)));
    try std.testing.expectEqualStrings("application-exit", std.mem.span(noctty_grid_tray_menu_icon_name(4)));
    try std.testing.expectEqualStrings("", std.mem.span(noctty_grid_tray_menu_icon_name(0)));
}

test "scroll direction and tab color names handle every boundary" {
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_scroll_direction(0));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_scroll_direction(1));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_scroll_direction(2));
    try std.testing.expectEqual(@as(c_int, 2), noctty_grid_scroll_direction(3));
    try std.testing.expectEqualStrings("Red", std.mem.span(noctty_grid_tab_color_preset_name(0)));
    try std.testing.expectEqualStrings("Pink", std.mem.span(noctty_grid_tab_color_preset_name(7)));
    try std.testing.expectEqualStrings("Default", std.mem.span(noctty_grid_tab_color_preset_name(-1)));
    try std.testing.expectEqualStrings("much darker", std.mem.span(noctty_grid_tab_color_shade_name(-3)));
    try std.testing.expectEqualStrings("darker", std.mem.span(noctty_grid_tab_color_shade_name(-1)));
    try std.testing.expectEqualStrings("base shade", std.mem.span(noctty_grid_tab_color_shade_name(0)));
    try std.testing.expectEqualStrings("lighter", std.mem.span(noctty_grid_tab_color_shade_name(1)));
    try std.testing.expectEqualStrings("much lighter", std.mem.span(noctty_grid_tab_color_shade_name(3)));
}

test "bounded text validation enforces UTF-8 and control-free byte limits" {
    const accepted = [_][]const u8{
        "four",
        "Résumé",
        "界",
    };
    for (accepted) |text| {
        try std.testing.expectEqual(
            @as(c_int, 1),
            noctty_grid_text_valid(text.ptr, text.len, text.len),
        );
    }

    const rejected = [_][]const u8{
        "",
        "line\nbreak",
        "nul\x00byte",
        "delete\x7fbyte",
        "\xc3(",
    };
    for (rejected) |text| {
        try std.testing.expectEqual(
            @as(c_int, 0),
            noctty_grid_text_valid(text.ptr, text.len, 128),
        );
    }
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_text_valid(null, 1, 128),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_text_valid("four".ptr, 4, 3),
    );
}

test "accessibility offset plans clamp ranges and reject invalid offsets" {
    var plan = AccessibleOffsetPlan{ .start = 0, .end = 0, .valid = 0 };
    noctty_grid_accessible_offset_plan(5, -2, -1, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.start);
    try std.testing.expectEqual(@as(c_int, 5), plan.end);
    try std.testing.expectEqual(@as(c_int, 0), plan.valid);

    noctty_grid_accessible_offset_plan(5, 2, 99, &plan);
    try std.testing.expectEqual(@as(c_int, 2), plan.start);
    try std.testing.expectEqual(@as(c_int, 5), plan.end);
    try std.testing.expectEqual(@as(c_int, 1), plan.valid);

    noctty_grid_accessible_offset_plan(0, 0, 0, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.valid);
}
test "accessible range plans preserve word and line granularity" {
    const text = "one two\n界 word";
    var plan = AccessibleRangePlan{ .start = 0, .end = 0, .valid = 0 };
    noctty_grid_accessible_range_plan(
        text.ptr,
        text.len,
        1,
        1,
        &plan,
    );
    try std.testing.expectEqual(@as(c_int, 0), plan.start);
    try std.testing.expectEqual(@as(c_int, 3), plan.end);
    noctty_grid_accessible_range_plan(
        text.ptr,
        text.len,
        10,
        1,
        &plan,
    );
    try std.testing.expectEqual(@as(c_int, 10), plan.start);
    try std.testing.expectEqual(@as(c_int, 14), plan.end);
    noctty_grid_accessible_range_plan(
        text.ptr,
        text.len,
        2,
        2,
        &plan,
    );
    try std.testing.expectEqual(@as(c_int, 0), plan.start);
    try std.testing.expectEqual(@as(c_int, 7), plan.end);
    noctty_grid_accessible_range_plan(
        text.ptr,
        text.len,
        99,
        1,
        &plan,
    );
    try std.testing.expectEqual(@as(c_int, 0), plan.valid);
}
test "output presentation plan prefers mapped ticks and bounded fallback" {
    var plan = OutputPresentPlan{
        .schedule = 0,
        .use_tick = 0,
        .timeout_ms = 0,
    };
    noctty_grid_output_present_plan(1, 0, 0, 1, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.schedule);
    try std.testing.expectEqual(@as(c_int, 1), plan.use_tick);
    try std.testing.expectEqual(@as(c_int, 100), plan.timeout_ms);

    noctty_grid_output_present_plan(1, 0, 0, 0, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.schedule);
    try std.testing.expectEqual(@as(c_int, 0), plan.use_tick);
    noctty_grid_output_present_plan(1, 1, 0, 1, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.schedule);
    noctty_grid_output_present_plan(1, 0, 1, 1, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.schedule);
}
test "zoom plan separates enter and unzoom state" {
    var plan = ZoomPlan{ .unzoom = 0, .enter = 0 };
    noctty_grid_zoom_plan(0, 7, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.unzoom);
    try std.testing.expectEqual(@as(c_int, 1), plan.enter);
    noctty_grid_zoom_plan(7, 7, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.unzoom);
    try std.testing.expectEqual(@as(c_int, 0), plan.enter);
}



test "startup window plan separates native effects from visibility policy" {
    var plan = StartupWindowPlan{
        .start_hidden = 0,
        .apply_activation = 0,
        .show_layout_only = 0,
    };
    noctty_grid_startup_window_plan(1, 1, 1, 0, 0, 1, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.start_hidden);
    try std.testing.expectEqual(@as(c_int, 0), plan.apply_activation);
    try std.testing.expectEqual(@as(c_int, 1), plan.show_layout_only);

    noctty_grid_startup_window_plan(0, 0, 1, 1, 0, 1, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.start_hidden);
    try std.testing.expectEqual(@as(c_int, 1), plan.apply_activation);
    try std.testing.expectEqual(@as(c_int, 0), plan.show_layout_only);

    noctty_grid_startup_window_plan(0, 0, 1, 1, 1, 1, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.apply_activation);
    try std.testing.expectEqual(@as(c_int, 1), plan.show_layout_only);
}
test "control name request plan classifies D-Bus ownership results" {
    var plan = ControlNameRequestPlan{ .registered = 0, .conflict = 0 };
    noctty_grid_control_name_request_plan(1, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.registered);
    try std.testing.expectEqual(@as(c_int, 0), plan.conflict);
    noctty_grid_control_name_request_plan(3, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.registered);
    try std.testing.expectEqual(@as(c_int, 1), plan.conflict);
    noctty_grid_control_name_request_plan(0, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.registered);
    try std.testing.expectEqual(@as(c_int, 0), plan.conflict);
}
test "accessible text plan bounds cell data and trims presentation whitespace" {
    var plan = AccessibleTextPlan{ .initial_capacity = 0 };
    try std.testing.expectEqual(
        @as(c_int, 64),
        noctty_grid_accessible_text_capacity(0, 0, &plan),
    );
    try std.testing.expectEqual(@as(c_int, 64), plan.initial_capacity);
    try std.testing.expectEqual(
        @as(c_int, 72),
        noctty_grid_accessible_text_capacity(9, 8, &plan),
    );
    try std.testing.expectEqual(@as(c_int, 72), plan.initial_capacity);
    try std.testing.expectEqual(@as(c_int, 4), noctty_grid_accessible_cell_length(4, 64));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_accessible_cell_length(64, 64));

    const row = "text   ";
    try std.testing.expectEqual(
        @as(usize, 4),
        noctty_grid_accessible_trim_row_length(row.ptr, row.len),
    );
    const lines = "text\n\n";
    try std.testing.expectEqual(
        @as(usize, 4),
        noctty_grid_accessible_trim_newline_length(lines.ptr, lines.len),
    );
}

test "smoke schedule plans preserve scenario timing and targets" {
    var steps: [16]SmokeScheduleStep = undefined;
    var count = noctty_grid_smoke_schedule(1, 0, &steps[0], steps.len);
    try std.testing.expectEqual(@as(c_int, 9), count);
    try std.testing.expectEqual(@as(c_int, 250), steps[0].delay_ms);
    try std.testing.expectEqual(@as(c_int, smoke_action.emit_tab), steps[0].action);
    try std.testing.expectEqual(@as(c_int, smoke_target_peer), steps[7].target);

    count = noctty_grid_smoke_schedule(15, 0, &steps[0], steps.len);
    try std.testing.expectEqual(@as(c_int, 13), count);
    try std.testing.expectEqual(@as(c_int, 2500), steps[12].delay_ms);
    try std.testing.expectEqual(
        @as(c_int, smoke_action.finish_compact),
        steps[12].action,
    );
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_smoke_schedule(10, 0, &steps[0], steps.len));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_smoke_schedule(-1, 1, &steps[0], steps.len));
}


test "hyperlink validation accepts safe browser schemes and rejects controls" {
    const accepted = [_][]const u8{
        "https://example.com/docs",
        "HTTP://example.com",
        "mailto:user@example.com",
    };
    for (accepted) |uri| {
        try std.testing.expectEqual(
            @as(c_int, 1),
            noctty_grid_hyperlink_valid(uri.ptr, @intCast(uri.len)),
        );
    }
    const rejected = [_][]const u8{
        "",
        "javascript:alert(1)",
        "https\x00://example.com",
        "https://example.com\nnext",
        "\xffhttps://example.com",
    };
    for (rejected) |uri| {
        try std.testing.expectEqual(
            @as(c_int, 0),
            noctty_grid_hyperlink_valid(uri.ptr, @intCast(uri.len)),
        );
    }
    var oversized = [_]u8{'a'} ** 2049;
    oversized[4] = ':';
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_hyperlink_valid(&oversized, oversized.len),
    );
}

test "ASCII fuzzy matching preserves ordered case-insensitive subsequences" {
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_fuzzy_match_ascii("Open Theme".ptr, 10, "ot".ptr, 2),
    );
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_fuzzy_match_ascii("anything".ptr, 8, null, 0),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_fuzzy_match_ascii("Open Theme".ptr, 10, "tmx".ptr, 3),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_fuzzy_match_ascii(null, 0, "x".ptr, 1),
    );
}

test "dropdown dimensions reject invalid space and clamp every input" {
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_dropdown_dimension(0, 50, 0, 480));
    try std.testing.expectEqual(@as(c_int, 480), noctty_grid_dropdown_dimension(0, 50, 900, 480));
    try std.testing.expectEqual(@as(c_int, 720), noctty_grid_dropdown_dimension(720, 50, 900, 480));
    try std.testing.expectEqual(@as(c_int, 900), noctty_grid_dropdown_dimension(1200, 50, 900, 480));
    try std.testing.expectEqual(@as(c_int, 400), noctty_grid_dropdown_dimension(0, 200, 400, 480));
}

test "compact tab metrics preserve minimum label and action geometry" {
    var metrics = CompactTabMetrics{
        .label_height = 0,
        .action_extent = 0,
        .strip_limit = 0,
    };
    noctty_grid_compact_tab_metrics(10, &metrics);
    try std.testing.expectEqual(@as(c_int, 12), metrics.label_height);
    try std.testing.expectEqual(@as(c_int, 24), metrics.action_extent);
    try std.testing.expectEqual(@as(c_int, 30), metrics.strip_limit);
    noctty_grid_compact_tab_metrics(40, &metrics);
    try std.testing.expectEqual(@as(c_int, 40), metrics.label_height);
    try std.testing.expectEqual(@as(c_int, 42), metrics.action_extent);
    try std.testing.expectEqual(@as(c_int, 61), metrics.strip_limit);
}

test "compact tab geometry preserves orientation and native extents" {
    var measurements = CompactTabMeasurements{
        .horizontal = 1,
        .notebook_width = 800,
        .notebook_height = 40,
        .page_width = 800,
        .page_height = 32,
        .tab_width = 140,
        .tab_height = 8,
        .max_tab_width = 150,
        .close_width = 28,
        .close_height = 26,
        .action_width = 26,
        .action_height = 30,
    };
    var geometry: CompactTabGeometry = undefined;
    noctty_grid_compact_tab_geometry(&measurements, &geometry);
    try std.testing.expectEqual(@as(c_int, 8), geometry.strip_extent);
    try std.testing.expectEqual(@as(c_int, 8), geometry.widget_extent);
    try std.testing.expectEqual(@as(c_int, 150), geometry.max_width);
    try std.testing.expectEqual(@as(c_int, 26), geometry.close_extent);
    try std.testing.expectEqual(@as(c_int, 26), geometry.action_extent);

    measurements.horizontal = 0;
    noctty_grid_compact_tab_geometry(&measurements, &geometry);
    try std.testing.expectEqual(@as(c_int, 0), geometry.strip_extent);
    try std.testing.expectEqual(@as(c_int, 140), geometry.widget_extent);
}

test "settings geometry planner preserves bounded workarea hints" {
    var plan = SettingsGeometryPlan{
        .width = 0,
        .height = 0,
        .min_width = 0,
        .min_height = 0,
        .max_width = 0,
        .max_height = 0,
    };
    noctty_grid_settings_geometry_plan(1200, 800, &plan);
    try std.testing.expectEqual(@as(c_int, 980), plan.width);
    try std.testing.expectEqual(@as(c_int, 704), plan.height);
    try std.testing.expectEqual(@as(c_int, 720), plan.min_width);
    try std.testing.expectEqual(@as(c_int, 560), plan.min_height);
    try std.testing.expectEqual(@as(c_int, 1200), plan.max_width);
    try std.testing.expectEqual(@as(c_int, 800), plan.max_height);
    noctty_grid_settings_geometry_plan(640, 480, &plan);
    try std.testing.expectEqual(@as(c_int, 608), plan.width);
    try std.testing.expectEqual(@as(c_int, 448), plan.height);
}

test "render damage bounds clip rows cells and cursor rectangles" {
    var damage: DamageRect = undefined;
    noctty_grid_damage_rect(-2, 3, 10, 20, 8, 10, &damage);
    try std.testing.expectEqual(@as(c_int, 0), damage.x);
    try std.testing.expectEqual(@as(c_int, 3), damage.y);
    try std.testing.expectEqual(@as(c_int, 8), damage.width);
    try std.testing.expectEqual(@as(c_int, 7), damage.height);

    noctty_grid_damage_rect(0, 0, 0, 0, 0, 0, &damage);
    try std.testing.expectEqual(@as(c_int, 1), damage.width);
    try std.testing.expectEqual(@as(c_int, 1), damage.height);

    noctty_grid_cursor_damage(2, 3, 9.5, 17.2, &damage);
    try std.testing.expectEqual(@as(c_int, 23), damage.x);
    try std.testing.expectEqual(@as(c_int, 53), damage.y);
    try std.testing.expectEqual(@as(c_int, 10), damage.width);
    try std.testing.expectEqual(@as(c_int, 18), damage.height);
}

test "cursor position and background alpha preserve render input policy" {
    var cursor = CursorPosition{ .column = 0, .row = 0, .valid = 0 };
    noctty_grid_cursor_position(0x00030002, &cursor);
    try std.testing.expectEqual(@as(c_int, 2), cursor.column);
    try std.testing.expectEqual(@as(c_int, 3), cursor.row);
    try std.testing.expectEqual(@as(c_int, 1), cursor.valid);
    noctty_grid_cursor_position(std.math.maxInt(u32), &cursor);
    try std.testing.expectEqual(@as(c_int, -1), cursor.column);
    try std.testing.expectEqual(@as(c_int, -1), cursor.row);
    try std.testing.expectEqual(@as(c_int, 0), cursor.valid);

    try std.testing.expectEqual(
        @as(f64, 0.75),
        noctty_grid_background_alpha(1, 1, 75),
    );
    try std.testing.expectEqual(
        @as(f64, 1.0),
        noctty_grid_background_alpha(0, 1, 75),
    );
}

test "manual dropdown pixels become responsive percentages" {
    try std.testing.expectEqual(@as(c_int, 80), noctty_grid_dropdown_percent(720, 900, 50));
    try std.testing.expectEqual(@as(c_int, 53), noctty_grid_dropdown_percent(481, 900, 50));
    try std.testing.expectEqual(@as(c_int, 96), noctty_grid_dropdown_percent(1200, 900, 96));
    try std.testing.expectEqual(@as(c_int, 55), noctty_grid_dropdown_percent(0, 900, 55));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_dropdown_percent(0, 0, 0));
}

test "bounded host policies preserve scroll and UI ordinal edges" {
    try std.testing.expectEqual(
        @as(c_int, 7),
        noctty_grid_scroll_target_delta(100, 40, 47),
    );
    try std.testing.expectEqual(
        @as(c_int, -40),
        noctty_grid_scroll_target_delta(100, 40, 0),
    );
    try std.testing.expectEqual(
        @as(c_int, 60),
        noctty_grid_scroll_target_delta(100, 40, 120),
    );
    try std.testing.expectEqual(
        @as(c_int, 4),
        noctty_grid_tab_title_width(0),
    );
    try std.testing.expectEqual(
        @as(c_int, 24),
        noctty_grid_tab_title_width(100),
    );
    try std.testing.expectEqual(
        @as(u64, 1),
        noctty_grid_search_display_ordinal(2, 0),
    );
    try std.testing.expectEqual(
        @as(u64, 2),
        noctty_grid_search_display_ordinal(7, 3),
    );
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_selection_end(-1));
    try std.testing.expectEqual(@as(c_int, 4), noctty_grid_selection_end(5));
    try std.testing.expectEqual(
        @as(c_int, 2),
        noctty_grid_partition_size(1, 4),
    );
    try std.testing.expectEqual(
        @as(c_int, 5),
        noctty_grid_partition_size(20, 4),
    );
    try std.testing.expectEqual(
        @as(c_int, 2),
        noctty_grid_partition_size(20, 0),
    );
}

test "dialog and percent dimensions preserve bounded workarea geometry" {
    try std.testing.expectEqual(
        @as(c_int, 660),
        noctty_grid_dialog_dimension(1000, 660, 1, 32),
    );
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_dialog_dimension(20, 660, 1, 32),
    );
    try std.testing.expectEqual(
        @as(c_int, 720),
        noctty_grid_dialog_dimension(800, 980, 720, 96),
    );
    try std.testing.expectEqual(
        @as(c_int, 720),
        noctty_grid_dialog_dimension(400, 980, 720, 96),
    );
    try std.testing.expectEqual(
        @as(c_int, 1536),
        noctty_grid_percent_dimension(1920, 80, 480),
    );
    try std.testing.expectEqual(
        @as(c_int, 400),
        noctty_grid_percent_dimension(400, 80, 480),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_percent_dimension(0, 80, 480),
    );
    try std.testing.expectEqual(
        @as(c_int, 900),
        noctty_grid_percent_dimension(900, 120, 480),
    );
}

test "sharing status actions cover only explicit protocol states" {
    try std.testing.expectEqual(
        sharing_allow_pairing | sharing_allow_session,
        noctty_grid_sharing_status_actions(0),
    );
    try std.testing.expectEqual(
        sharing_allow_pairing,
        noctty_grid_sharing_status_actions(104),
    );
    try std.testing.expectEqual(
        sharing_allow_session,
        noctty_grid_sharing_status_actions(107),
    );
    try std.testing.expectEqual(
        sharing_clear_host,
        noctty_grid_sharing_status_actions(201),
    );
    try std.testing.expectEqual(
        sharing_clear_viewer,
        noctty_grid_sharing_status_actions(306),
    );
    for ([_]c_int{ -1, 1, 103, 108, 200, 207, 300, 307, 402 }) |status|
        try std.testing.expectEqual(
            @as(u32, 0),
            noctty_grid_sharing_status_actions(status),
        );
}

test "sharing status text owns messages errors and discovery hints" {
    var output: [256]u8 = undefined;
    var plan: SharingStatusTextPlan = undefined;
    const alias = "lab";
    const endpoint = "terminal.local";
    var length = noctty_grid_sharing_status_text(
        102, 42, 0,
        alias.ptr, alias.len, endpoint.ptr, endpoint.len,
        0, 0, &output, output.len, &plan);
    try std.testing.expectEqual(
        @as(c_int, "Compare on both devices: 000042. Confirm only if identical.".len),
        length,
    );
    try std.testing.expectEqualStrings(
        "Compare on both devices: 000042. Confirm only if identical.",
        output[0..@intCast(length)],
    );
    try std.testing.expectEqual(@as(c_int, 0), plan.is_error);

    length = noctty_grid_sharing_status_text(
        401, 0, 0,
        alias.ptr, alias.len, endpoint.ptr, endpoint.len,
        4567, 1, &output, output.len, &plan);
    try std.testing.expectEqual(
        @as(c_int, "Untrusted LAN hint: lab at terminal.local:4567. Review it, connect, and trust only after the six-digit code matches.".len),
        length,
    );
    try std.testing.expectEqual(@as(c_int, 0), plan.is_error);

    _ = noctty_grid_sharing_status_text(
        306, 0, 0,
        alias.ptr, alias.len, endpoint.ptr, endpoint.len,
        0, 0, &output, output.len, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.is_error);
    try std.testing.expectEqualStrings(
        "Remote terminal connection failed. Close this remote session or reconnect.",
        output[0..@intCast(plan.length)],
    );

    var tiny: [8]u8 = undefined;
    length = noctty_grid_sharing_status_text(
        0, 0, 0,
        alias.ptr, alias.len, endpoint.ptr, endpoint.len,
        0, 0, &tiny, tiny.len, &plan);
    try std.testing.expectEqual(@as(c_int, 7), length);
    try std.testing.expectEqualStrings("Idle. P", tiny[0..@intCast(length)]);
}

test "compact tab text owns markup tooltip and close labels" {
    const title = "Project & Main";
    const filter = "ci";
    const status_color = "#6f7480";
    var input = CompactTabTextInput{
        .title = title.ptr,
        .title_length = title.len,
        .filter = filter.ptr,
        .filter_length = filter.len,
        .status_color = status_color.ptr,
        .status_color_length = status_color.len,
        .pane_count = 2,
        .selected_count = 1,
        .filter_active = 1,
        .attention = 1,
        .dirty = 1,
        .broadcast = 1,
        .active = 1,
        .tab_color_rgb = 0xff0000,
        .tab_color_preset = 0,
        .tab_color_shade = 1,
    };
    var markup: [1024]u8 = undefined;
    var tooltip: [1024]u8 = undefined;
    var close_name: [256]u8 = undefined;
    var plan: CompactTabTextPlan = undefined;
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_compact_tab_text(
            &input,
            &markup,
            markup.len,
            &tooltip,
            tooltip.len,
            &close_name,
            close_name.len,
            &plan,
        ),
    );
    try std.testing.expectEqualStrings(
        "<span size='small' weight='bold' foreground='#11151b'>Project &amp; Main ×2</span> <span foreground='#6f7480'>●</span> <span foreground='#e8a85c'>◆</span> <span foreground='#b8a7ff'>⌕ ci</span> <span foreground='#f6c85f'>⌁1</span> <span foreground='#70d6a7'>B</span>",
        markup[0..@intCast(plan.markup_length)],
    );
    try std.testing.expectEqualStrings(
        "Project & Main · 2 panes · attention requested · unsaved workspace · Smart Tab filter active · selection group active · broadcast on · tab color Red, lighter",
        tooltip[0..@intCast(plan.tooltip_length)],
    );
    try std.testing.expectEqualStrings(
        "Close tab: Project & Main",
        close_name[0..@intCast(plan.close_name_length)],
    );
    try std.testing.expectEqual(@as(c_int, 0), plan.title_truncated);

    const long_title = "1234567890123456789";
    input.title = long_title.ptr;
    input.title_length = long_title.len;
    input.filter_active = 0;
    input.tab_color_rgb = 0;
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_compact_tab_text(
            &input,
            &markup,
            markup.len,
            &tooltip,
            tooltip.len,
            &close_name,
            close_name.len,
            &plan,
        ),
    );
    try std.testing.expectEqual(@as(c_int, 1), plan.title_truncated);
    try std.testing.expect(std.mem.indexOf(
        u8,
        markup[0..@intCast(plan.markup_length)],
        "12345678901234567…",
    ) != null);
}

test "pane tooltip text owns status and tag composition" {
    var output: [256]u8 = undefined;
    const status = "focused";
    const tags = "build,ui";
    var length = noctty_grid_pane_tooltip(
        42,
        status.ptr,
        status.len,
        tags.ptr,
        tags.len,
        &output,
        output.len,
    );
    try std.testing.expectEqual(@as(c_int, 30), length);
    try std.testing.expectEqualStrings(
        "Pane 42 · focused · build,ui",
        output[0..@intCast(length)],
    );
    length = noctty_grid_pane_tooltip(
        42,
        status.ptr,
        status.len,
        null,
        0,
        &output,
        output.len,
    );
    try std.testing.expectEqual(@as(c_int, 18), length);
    try std.testing.expectEqualStrings(
        "Pane 42 · focused",
        output[0..@intCast(length)],
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_pane_tooltip(
            42,
            status.ptr,
            status.len,
            tags.ptr,
            tags.len,
            &output,
            8,
        ),
    );
}

test "remaining native text policy owns filter feedback and title fallbacks" {
    var empty: [256]u8 = undefined;
    var label: [256]u8 = undefined;
    var tooltip: [256]u8 = undefined;
    var filter_plan = SmartFilterTextPlan{
        .empty_length = 0,
        .label_length = 0,
        .tooltip_length = 0,
    };
    const tag = "ci";
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_smart_filter_text(
            1,
            tag.ptr,
            tag.len,
            &empty,
            empty.len,
            &label,
            label.len,
            &tooltip,
            tooltip.len,
            &filter_plan,
        ),
    );
    try std.testing.expectEqualStrings(
        "No panes match Smart Tab tag: ci",
        empty[0..@intCast(filter_plan.empty_length)],
    );
    try std.testing.expectEqualStrings(
        "Tag: ci",
        label[0..@intCast(filter_plan.label_length)],
    );
    try std.testing.expectEqualStrings(
        "Smart Tab: clear pane tag filter",
        tooltip[0..@intCast(filter_plan.tooltip_length)],
    );
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_smart_filter_text(
            0,
            null,
            0,
            &empty,
            empty.len,
            &label,
            label.len,
            &tooltip,
            tooltip.len,
            &filter_plan,
        ),
    );
    try std.testing.expectEqual(@as(c_int, 0), filter_plan.empty_length);
    try std.testing.expectEqualStrings(
        "Filter",
        label[0..@intCast(filter_plan.label_length)],
    );
    try std.testing.expectEqualStrings(
        "Smart Tab: show all panes",
        tooltip[0..@intCast(filter_plan.tooltip_length)],
    );

    var output: [256]u8 = undefined;
    var length = noctty_grid_cycle_feedback_text(
        0, 2, 4, &output, output.len);
    try std.testing.expectEqualStrings("Pane 2 / 4", output[0..@intCast(length)]);
    length = noctty_grid_cycle_feedback_text(
        1, 3, 5, &output, output.len);
    try std.testing.expectEqualStrings("Tab 3 / 5", output[0..@intCast(length)]);
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_cycle_feedback_text(2, 1, 2, &output, output.len),
    );

    const model = "Model";
    const display = "Display";
    const directory = "Directory";
    length = noctty_grid_tab_title_text(
        model.ptr,
        model.len,
        display.ptr,
        display.len,
        directory.ptr,
        directory.len,
        3,
        &output,
        output.len,
    );
    try std.testing.expectEqualStrings("Model", output[0..@intCast(length)]);
    length = noctty_grid_tab_title_text(
        null,
        0,
        display.ptr,
        display.len,
        directory.ptr,
        directory.len,
        3,
        &output,
        output.len,
    );
    try std.testing.expectEqualStrings("Display", output[0..@intCast(length)]);
    length = noctty_grid_tab_title_text(
        null,
        0,
        null,
        0,
        null,
        0,
        0,
        &output,
        output.len,
    );
    try std.testing.expectEqualStrings("Tab 1", output[0..@intCast(length)]);

    length = noctty_grid_attention_notification_text(
        7, 1, 0, &output, output.len);
    try std.testing.expectEqualStrings(
        "Pane 7 requested attention",
        output[0..@intCast(length)],
    );
    length = noctty_grid_attention_notification_text(
        7, 0, 23, &output, output.len);
    try std.testing.expectEqualStrings(
        "Pane 7 exited with code 23",
        output[0..@intCast(length)],
    );

    const pane_title = "  Shell  ";
    length = noctty_grid_pane_zoom_feedback_text(
        7,
        pane_title.ptr,
        pane_title.len,
        display.ptr,
        display.len,
        &output,
        output.len,
    );
    try std.testing.expectEqualStrings(
        "Session Shell is focused. Double click again on pane to go back.",
        output[0..@intCast(length)],
    );
    length = noctty_grid_pane_zoom_feedback_text(
        7,
        null,
        0,
        null,
        0,
        &output,
        output.len,
    );
    try std.testing.expectEqualStrings(
        "Session Pane 7 is focused. Double click again on pane to go back.",
        output[0..@intCast(length)],
    );
}

test "remaining native UI text composition stays bounded and native-free" {
    var output: [4608]u8 = undefined;
    var secondary: [512]u8 = undefined;
    try std.testing.expectEqualStrings(
        "Shortcut is unavailable. Press another key or Esc.",
        std.mem.span(noctty_grid_shortcut_feedback_message(0)),
    );
    try std.testing.expectEqualStrings(
        "Checking shortcut availability…",
        std.mem.span(noctty_grid_shortcut_feedback_message(2)),
    );

    var length = noctty_grid_note_overlay_label(
        "Remember this", "Remember this".len, &output, output.len);
    try std.testing.expectEqualStrings(
        "Note · Remember this",
        output[0..@intCast(length)],
    );
    length = noctty_grid_window_title_text(
        2, "Terminal", 8, &output, output.len);
    try std.testing.expectEqualStrings(
        "NOCTTY Zen — Terminal",
        output[0..@intCast(length)],
    );

    var title: [64]u8 = undefined;
    var detail: [256]u8 = undefined;
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_close_confirmation_text(
            "application",
            "application".len,
            0,
            &title,
            title.len,
            &detail,
            detail.len,
        ),
    );
    try std.testing.expectEqualStrings(
        "Close NOCTTY?",
        title[0.."Close NOCTTY?".len],
    );
    try std.testing.expectEqualStrings(
        "Closing NOCTTY ends all terminal sessions in this window.",
        detail[0.."Closing NOCTTY ends all terminal sessions in this window.".len],
    );
    length = noctty_grid_layout_prompt_title(2, &output, output.len);
    try std.testing.expectEqualStrings(
        "Move 2 terminal sessions to a new tab?",
        output[0..@intCast(length)],
    );

    length = noctty_grid_find_status_text(1, 3, 9, &output, output.len);
    try std.testing.expectEqualStrings(
        "3 / 9  ·  Enter for previous",
        output[0..@intCast(length)],
    );
    length = noctty_grid_find_status_text(2, 0, 0, &output, output.len);
    try std.testing.expectEqualStrings("No matches", output[0..@intCast(length)]);

    length = noctty_grid_shortcuts_text(0, &output, output.len);
    try std.testing.expect(std.mem.indexOf(
        u8,
        output[0..@intCast(length)],
        "Show / hide NOCTTY",
    ) != null);

    length = noctty_grid_sharing_peer_label(
        "Alice", 5, "host.local", 10, 2200, &output, output.len);
    try std.testing.expectEqualStrings(
        "Alice — host.local:2200",
        output[0..@intCast(length)],
    );
    length = noctty_grid_sharing_tab_label(
        null, 0, 4, 1, &output, output.len);
    try std.testing.expectEqualStrings(
        "Tab 4 (host active)",
        output[0..@intCast(length)],
    );
    length = noctty_grid_sharing_pane_label(
        "Shell", 5, 9, &output, output.len);
    try std.testing.expectEqualStrings(
        "Shell — pane 9",
        output[0..@intCast(length)],
    );
    length = noctty_grid_sharing_revoke_detail(
        "Alice", 5, &secondary, secondary.len);
    try std.testing.expectEqualStrings(
        "Alice will lose sharing access immediately. Pairing it again will require a new matching six-digit confirmation.",
        secondary[0..@intCast(length)],
    );
}

test "launch profile and persistence text policy stays bounded" {
    var payload: [256]u8 = undefined;
    const required = noctty_grid_launch_profile_payload(
        15,
        null, 0,
        "bash", 4,
        "printf hi", 9,
        "/tmp", 4,
        "user@host", 9,
        1000,
        null, 0,
    );
    try std.testing.expectEqual(
        @as(c_int, "bash\tprintf hi\t/tmp\tuser@host\t1000".len),
        required,
    );
    const written = noctty_grid_launch_profile_payload(
        15,
        null, 0,
        "bash", 4,
        "printf hi", 9,
        "/tmp", 4,
        "user@host", 9,
        1000,
        &payload, payload.len,
    );
    try std.testing.expectEqual(required, written);
    try std.testing.expectEqualStrings(
        "bash\tprintf hi\t/tmp\tuser@host\t1000",
        payload[0..@intCast(written)],
    );
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_launch_profile_name_valid("Profile", 7),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_launch_profile_name_valid(" Profile", 8),
    );
    try std.testing.expectEqualStrings(
        "Named launch profile deleted.",
        std.mem.span(noctty_grid_launch_profile_status_message(5)),
    );
    var status: [512]u8 = undefined;
    const status_length = noctty_grid_theme_apply_status_text(
        1, "Solarized", 9, 0, &status, status.len);
    try std.testing.expectEqualStrings(
        "Using Solarized — Dark for this session; the selection could not be saved.",
        status[0..@intCast(status_length)],
    );
    var numeric: [64]u8 = undefined;
    const decimal_length = noctty_grid_decimal_text(
        -42, &numeric, numeric.len);
    try std.testing.expectEqualStrings(
        "-42", numeric[0..@intCast(decimal_length)]);
    const accessible_length = noctty_grid_terminal_accessible_name(
        7, &numeric, numeric.len);
    try std.testing.expectEqualStrings(
        "Terminal pane 7", numeric[0..@intCast(accessible_length)]);
}

test "recovery notice text preserves fallback precedence and ordering" {
    var output: [1024]u8 = undefined;
    const all_flags: u32 =
        (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4);
    const length = noctty_grid_recovery_notice_text(
        all_flags,
        &output,
        output.len,
    );
    try std.testing.expectEqual(
        @as(c_int, 182),
        length,
    );
    try std.testing.expectEqualStrings(
        "Settings were damaged. Last-known-good settings were loaded. " ++
            "The last-known-good theme library was restored. " ++
            "The damaged workspace snapshot was skipped; a clean workspace was opened.",
        output[0..@intCast(length)],
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_recovery_notice_text(0, &output, output.len),
    );
}

test "status feedback labels remain owned by Zig" {
    const expected = [_][]const u8{
        "Could not scroll the terminal history.",
        "Could not paste into every target terminal.",
        "Could not copy the terminal selection.",
        "Could not update the terminal state.",
        "Could not send Ctrl+L to the terminal.",
        "Terminal input flush failed.",
        "Could not save the workspace recovery snapshot.",
        "Could not interrupt the terminal.",
        "Could not deliver input to every target terminal.",
        "Could not open the link in the default browser.",
        "This link type is not allowed.",
        "Link copied.",
        "The application did not accept pointer input.",
        "Broadcast mode disabled.",
        "The application did not accept mouse-wheel input.",
        "Could not deliver alternate-screen scroll input.",
        "Could not deliver composed text to every terminal.",
    };
    for (expected, 1..) |message, index|
        try std.testing.expectEqualStrings(
            message,
            std.mem.span(noctty_grid_status_feedback_message(@intCast(index))),
        );
    try std.testing.expectEqualStrings(
        "",
        std.mem.span(noctty_grid_status_feedback_message(0)),
    );
}

test "bracketed paste markers preserve terminal protocol delimiters" {
    var output: [6]u8 = undefined;
    try std.testing.expectEqual(
        @as(c_int, 6),
        noctty_grid_bracketed_paste_marker(0, &output, output.len),
    );
    try std.testing.expectEqualStrings("\x1b[200~", output[0..]);
    try std.testing.expectEqual(
        @as(c_int, 6),
        noctty_grid_bracketed_paste_marker(1, &output, output.len),
    );
    try std.testing.expectEqualStrings("\x1b[201~", output[0..]);
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_bracketed_paste_marker(2, &output, output.len));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_bracketed_paste_marker(0, &output, 5));
}

test "sharing key sequences preserve terminal control bytes" {
    var output: [3]u8 = undefined;
    const expected = [_][]const u8{
        "\r",
        "\x7f",
        "\t",
        "\x1b[Z",
        "\x1b",
        "\x1bOA",
        "\x1bOB",
        "\x1bOC",
        "\x1bOD",
    };
    for (expected, 0..) |sequence, kind| {
        const length = noctty_grid_sharing_key_sequence(
            @intCast(kind),
            if (kind >= 5) 1 else 0,
            &output,
            output.len,
        );
        try std.testing.expectEqual(@as(c_int, @intCast(sequence.len)), length);
        try std.testing.expectEqualStrings(sequence, output[0..sequence.len]);
    }
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_key_sequence(9, 0, &output, output.len),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_key_sequence(3, 0, &output, 2),
    );
}

test "input routing handles scrollbar overrides and invalid boundaries" {
    for (0..2) |mouse_mode| {
        for (0..8) |modifiers| {
            try std.testing.expectEqual(
                route_scrollbar,
                noctty_grid_input_route(
                    input_wheel,
                    -1,
                    @intCast(mouse_mode),
                    0,
                    0,
                    @intCast(modifiers),
                ),
            );
        }
    }

    try std.testing.expectEqual(
        route_application_mouse,
        noctty_grid_input_route(input_wheel, 0, -1, 0, 0, 1 << 31),
    );
    try std.testing.expectEqual(
        route_ignore,
        noctty_grid_input_route(
            std.math.maxInt(c_int),
            1,
            1,
            1,
            1,
            std.math.maxInt(u32),
        ),
    );
}
test "sharing extended key sequences preserve modifier formats" {
    var output: [16]u8 = undefined;
    const cases = [_]struct { kind: c_int, modifier: c_int, expected: []const u8 }{
        .{ .kind = 0, .modifier = 1, .expected = "\x1b[H" },
        .{ .kind = 1, .modifier = 3, .expected = "\x1b[1;3F" },
        .{ .kind = 2, .modifier = 1, .expected = "\x1b[2~" },
        .{ .kind = 5, .modifier = 4, .expected = "\x1b[6;4~" },
        .{ .kind = 6, .modifier = 1, .expected = "\x1bOP" },
        .{ .kind = 9, .modifier = 5, .expected = "\x1b[1;5S" },
        .{ .kind = 17, .modifier = 2, .expected = "\x1b[24;2~" },
    };
    for (cases) |case| {
        const length = noctty_grid_sharing_extended_key_sequence(
            case.kind,
            case.modifier,
            &output,
            output.len,
        );
        try std.testing.expectEqual(@as(c_int, @intCast(case.expected.len)), length);
        try std.testing.expectEqualStrings(case.expected, output[0..case.expected.len]);
    }
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_extended_key_sequence(18, 1, &output, output.len),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_extended_key_sequence(0, 1, &output, 2),
    );
}

test "sharing adapters retain their modifier sequence bounds" {
    var output = [_]u8{0xa5} ** 32;
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_sharing_arrow_sequence(0, 1000, 1, &output, output.len));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_sharing_extended_key_sequence(17, std.math.maxInt(c_int), &output, 15));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 32), &output);
    const extended_length = noctty_grid_sharing_extended_key_sequence(17, std.math.maxInt(c_int), &output, 16);
    try std.testing.expectEqualStrings("\x1b[24;2147483647~", output[0..@intCast(extended_length)]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[16]);
    output = [_]u8{0xa5} ** 32;
    const length = noctty_grid_sharing_arrow_sequence(0, 100, 1, &output, output.len);
    try std.testing.expectEqualStrings("\x1b[1;100A", output[0..@intCast(length)]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[8]);
}

test "sharing text sequences add bounded Alt prefixes" {
    const input = "xy";
    var output: [3]u8 = undefined;
    try std.testing.expectEqual(
        @as(c_int, 2),
        noctty_grid_sharing_text_sequence(0, input, input.len, &output, output.len),
    );
    try std.testing.expectEqualStrings(input, output[0..2]);
    try std.testing.expectEqual(
        @as(c_int, 3),
        noctty_grid_sharing_text_sequence(1, input, input.len, &output, output.len),
    );
    try std.testing.expectEqualStrings("\x1bxy", output[0..3]);
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_text_sequence(1, input, input.len, &output, 2),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_text_sequence(0, null, input.len, &output, output.len),
    );
}

test "sharing arrow sequences preserve cursor modes and modifiers" {
    var output: [8]u8 = undefined;
    const cases = [_]struct {
        arrow: c_int,
        modifier: c_int,
        application_cursor: c_int,
        expected: []const u8,
    }{
        .{ .arrow = 0, .modifier = 1, .application_cursor = 0, .expected = "\x1b[A" },
        .{ .arrow = 1, .modifier = 1, .application_cursor = 1, .expected = "\x1bOB" },
        .{ .arrow = 2, .modifier = 6, .application_cursor = 0, .expected = "\x1b[1;6C" },
        .{ .arrow = 3, .modifier = 2, .application_cursor = 1, .expected = "\x1b[1;2D" },
    };
    for (cases) |case| {
        const length = noctty_grid_sharing_arrow_sequence(
            case.arrow,
            case.modifier,
            case.application_cursor,
            &output,
            output.len,
        );
        try std.testing.expectEqual(@as(c_int, @intCast(case.expected.len)), length);
        try std.testing.expectEqualStrings(case.expected, output[0..case.expected.len]);
    }
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_arrow_sequence(-1, 1, 0, &output, output.len),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_arrow_sequence(0, 1, 0, &output, 2),
    );
}

test "sharing paste limits and chunks preserve bounded transport" {
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_sharing_paste_allowed(64 * 1024));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_sharing_paste_allowed(64 * 1024 + 1));
    try std.testing.expectEqual(@as(usize, 16 * 1024), noctty_grid_sharing_paste_chunk_size(64 * 1024));
    try std.testing.expectEqual(@as(usize, 7), noctty_grid_sharing_paste_chunk_size(7));
    try std.testing.expectEqual(@as(usize, 0), noctty_grid_sharing_paste_chunk_size(0));
}

test "native buffer policies preserve minimum rows and bounded growth" {
    try std.testing.expectEqual(@as(usize, 1), noctty_grid_damage_buffer_capacity(-4));
    try std.testing.expectEqual(@as(usize, 24), noctty_grid_damage_buffer_capacity(24));
    try std.testing.expectEqual(
        @as(usize, 32 * 1024),
        noctty_grid_selection_copy_capacity_next(16 * 1024),
    );
    try std.testing.expectEqual(
        @as(usize, 4 * 1024 * 1024),
        noctty_grid_selection_copy_capacity_next(3 * 1024 * 1024),
    );
    try std.testing.expectEqual(
        @as(usize, 4 * 1024 * 1024),
        noctty_grid_selection_copy_capacity_next(4 * 1024 * 1024),
    );
}

test "sharing preview scroll lines preserve GTK directions" {
    try std.testing.expectEqual(@as(c_int, 3), noctty_grid_sharing_preview_scroll_lines(0, 0));
    try std.testing.expectEqual(@as(c_int, -3), noctty_grid_sharing_preview_scroll_lines(1, 0));
    try std.testing.expectEqual(@as(c_int, 3), noctty_grid_sharing_preview_scroll_lines(4, -0.5));
    try std.testing.expectEqual(@as(c_int, -3), noctty_grid_sharing_preview_scroll_lines(4, 0.5));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_sharing_preview_scroll_lines(4, 0));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_sharing_preview_scroll_lines(2, -1));
}

test "sharing index parsing accepts bounded decimal identifiers" {
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_sharing_index("0", 1));
    try std.testing.expectEqual(@as(c_int, 42), noctty_grid_sharing_index("42", 2));
    try std.testing.expectEqual(
        std.math.maxInt(c_int),
        noctty_grid_sharing_index("2147483647", 10),
    );
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_sharing_index(null, 1));
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_sharing_index("", 0));
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_sharing_index("4x", 2));
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_sharing_index("2147483648", 10));
}

test "sharing index text formatting stays terminated and bounded" {
    var output: [12]u8 = undefined;
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_sharing_index_text(0, &output, output.len),
    );
    try std.testing.expectEqualStrings("0", std.mem.span(@as([*:0]u8, @ptrCast(&output))));
    try std.testing.expectEqual(
        @as(c_int, 10),
        noctty_grid_sharing_index_text(2_147_483_647, &output, output.len),
    );
    try std.testing.expectEqualStrings(
        "2147483647",
        std.mem.span(@as([*:0]u8, @ptrCast(&output))),
    );
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_sharing_index_text(-1, &output, output.len));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_sharing_index_text(12, &output, 2));
}

test "sharing pane hit testing preserves normalized half-open bounds" {
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_sharing_pane_hit(25, 25, 100, 100, 0, 0, 500_000, 1_000_000),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_pane_hit(50, 25, 100, 100, 0, 0, 500_000, 1_000_000),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_sharing_pane_hit(25, 25, 0, 100, 0, 0, 1_000_000, 1_000_000),
    );
}

test "theme color channels decode RGB model values" {
    try std.testing.expectEqual(@as(f64, 1.0), noctty_grid_theme_color_channel(0xff0000, 0));
    try std.testing.expectEqual(@as(f64, 128.0 / 255.0), noctty_grid_theme_color_channel(0x008000, 1));
    try std.testing.expectEqual(@as(f64, 0.0), noctty_grid_theme_color_channel(0x0000ff, 3));
}

test "theme color text clamps channels and preserves CSS hex format" {
    var output: [8]u8 = undefined;
    try std.testing.expectEqual(
        @as(c_int, 7),
        noctty_grid_theme_color_text(1.0, 0.5, 0.0, &output, output.len),
    );
    try std.testing.expectEqualStrings("#ff8000", output[0..7]);
    try std.testing.expectEqual(
        @as(c_int, 7),
        noctty_grid_theme_color_text(-1.0, 2.0, 0.25, &output, output.len),
    );
    try std.testing.expectEqualStrings("#00ff40", output[0..7]);
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_theme_color_text(std.math.nan(f64), 0.0, 0.0, &output, output.len),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_theme_color_text(0.0, 0.0, 0.0, &output, 7),
    );
}

test "settings policy clamps grouped terminal values at every boundary" {
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_terminal_scroll_setting(117, -5),
    );
    try std.testing.expectEqual(
        @as(c_int, 20),
        noctty_grid_terminal_scroll_setting(117, 99),
    );
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_terminal_scroll_setting(118, 7),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_terminal_scroll_setting(118, 0),
    );
    try std.testing.expectEqual(
        @as(c_int, -1),
        noctty_grid_terminal_scroll_setting(116, 7),
    );


    try std.testing.expectEqual(
        @as(f64, 10.0),
        noctty_grid_font_size_clamp(4.0, 10.0, 24.0),
    );
    try std.testing.expectEqual(
        @as(f64, 24.0),
        noctty_grid_font_size_clamp(30.0, 10.0, 24.0),
    );
    try std.testing.expectEqual(
        @as(c_int, 1575),
        noctty_grid_font_size_event_value(15.745, 10.0, 24.0),
    );

    const panel_cases = [_]struct {
        event_code: c_int,
        low: c_int,
        high: c_int,
    }{
        .{ .event_code = 46, .low = 0, .high = 64 },
        .{ .event_code = 47, .low = 0, .high = 64 },
        .{ .event_code = 119, .low = 1, .high = 16 },
        .{ .event_code = 120, .low = 0, .high = 12 },
        .{ .event_code = 121, .low = 1, .high = 12 },
        .{ .event_code = 122, .low = 1, .high = 12 },
        .{ .event_code = 123, .low = 1, .high = 12 },
        .{ .event_code = 124, .low = 1, .high = 12 },
        .{ .event_code = 125, .low = 1, .high = 16 },
        .{ .event_code = 126, .low = 1, .high = 32 },
        .{ .event_code = 130, .low = 20, .high = 100 },
    };
    for (panel_cases) |case| {
        try std.testing.expectEqual(
            case.low,
            noctty_grid_panel_metric_value(case.event_code, case.low - 1),
        );
        try std.testing.expectEqual(
            case.high,
            noctty_grid_panel_metric_value(case.event_code, case.high + 1),
        );
    }
    for ([_]c_int{ 127, 128, 129 }) |event_code| {
        try std.testing.expectEqual(
            @as(c_int, 1),
            noctty_grid_panel_metric_value(event_code, 9),
        );
    }
    try std.testing.expectEqual(
        @as(c_int, -1),
        noctty_grid_panel_metric_value(131, 5),
    );
    try std.testing.expectEqual(
        @as(c_int, 10),
        noctty_grid_background_opacity_value(-1),
    );
    try std.testing.expectEqual(
        @as(c_int, 100),
        noctty_grid_background_opacity_value(101),
    );
}
test "sharing control plan preserves state gates and labels" {
    var plan: SharingControlPlan = undefined;

    noctty_grid_sharing_control_plan(0, 0, &plan);
    try std.testing.expect((plan.enabled & sharing_control_pairing) != 0);
    try std.testing.expect((plan.enabled & sharing_control_session) == 0);
    try std.testing.expect((plan.enabled & sharing_control_discover) != 0);

    noctty_grid_sharing_control_plan(102, 2, &plan);
    try std.testing.expect((plan.enabled & sharing_control_confirm) != 0);
    try std.testing.expect((plan.enabled & sharing_control_cancel_pairing) != 0);
    try std.testing.expect((plan.enabled & sharing_control_session) == 0);
    try std.testing.expectEqual(@as(c_int, 0), plan.cancel_pairing_label);

    noctty_grid_sharing_control_plan(106, 1, &plan);
    try std.testing.expect((plan.enabled & sharing_control_session) != 0);
    try std.testing.expect((plan.enabled & sharing_control_retry_save) != 0);

    noctty_grid_sharing_control_plan(203, 1, &plan);
    try std.testing.expect((plan.enabled & sharing_control_grant) != 0);
    try std.testing.expect((plan.enabled & sharing_control_revoke) != 0);
    try std.testing.expectEqual(@as(c_int, 1), plan.revoke_label);

    noctty_grid_sharing_control_plan(305, 0, &plan);
    try std.testing.expect((plan.enabled & sharing_control_stop_receive) != 0);
    try std.testing.expect((plan.enabled & sharing_control_reconnect) != 0);
    try std.testing.expectEqual(@as(c_int, 1), plan.stop_receive_label);
}


fn expectCloseTransition(
    expected_effects: u32,
    expected_origin: u32,
    expected_accepted: bool,
    actual: CloseTransition,
) !void {
    try std.testing.expectEqual(expected_effects, actual.effects);
    try std.testing.expectEqual(expected_origin, actual.origin);
    try std.testing.expectEqual(@as(u32, @intFromBool(expected_accepted)), actual.accepted);
}

test "close requests preserve every first origin and natural-only dwell" {
    const origins = [_]u32{
        close_origin_toolbar,
        close_origin_tray,
        close_origin_window,
        close_origin_natural,
    };
    for (origins) |origin| {
        var coordinator: CloseCoordinator = .{};
        const schedule = if (origin == close_origin_natural)
            close_effect_schedule_dwell
        else
            close_effect_schedule_preflight;
        try expectCloseTransition(
            schedule,
            origin,
            true,
            noctty_grid_close_request(&coordinator, origin),
        );
        try expectCloseTransition(
            0,
            origin,
            false,
            noctty_grid_close_request(&coordinator, close_origin_tray),
        );
        try std.testing.expectEqual(origin, coordinator.origin);

        try expectCloseTransition(
            close_effect_run_preflight,
            origin,
            true,
            noctty_grid_close_source_fired(&coordinator, close_source_preflight),
        );
        try expectCloseTransition(
            0,
            origin,
            false,
            noctty_grid_close_request(&coordinator, close_origin_window),
        );
        try expectCloseTransition(
            0,
            origin,
            true,
            noctty_grid_close_preflight_result(&coordinator, 0),
        );
        try std.testing.expectEqual(close_phase_idle, coordinator.phase);
        try std.testing.expectEqual(close_origin_none, coordinator.origin);
    }
}

test "close requests reject invalid origins and null state" {
    var coordinator: CloseCoordinator = .{};
    for ([_]u32{ close_origin_none, close_origin_natural + 1, std.math.maxInt(u32) }) |origin| {
        try expectCloseTransition(
            0,
            close_origin_none,
            false,
            noctty_grid_close_request(&coordinator, origin),
        );
    }
    try expectCloseTransition(
        0,
        close_origin_none,
        false,
        noctty_grid_close_request(null, close_origin_toolbar),
    );
    try std.testing.expectEqual(close_phase_idle, coordinator.phase);
}

test "nested modals defer once at zero depth without underflow" {
    var coordinator: CloseCoordinator = .{};
    try expectCloseTransition(
        0,
        close_origin_none,
        true,
        noctty_grid_close_modal_begin(&coordinator),
    );
    try expectCloseTransition(
        0,
        close_origin_none,
        true,
        noctty_grid_close_modal_begin(&coordinator),
    );
    try expectCloseTransition(
        0,
        close_origin_toolbar,
        true,
        noctty_grid_close_request(&coordinator, close_origin_toolbar),
    );
    try expectCloseTransition(
        0,
        close_origin_toolbar,
        false,
        noctty_grid_close_request(&coordinator, close_origin_tray),
    );
    try expectCloseTransition(
        0,
        close_origin_toolbar,
        true,
        noctty_grid_close_modal_end(&coordinator),
    );
    try expectCloseTransition(
        close_effect_schedule_deferred,
        close_origin_toolbar,
        true,
        noctty_grid_close_modal_end(&coordinator),
    );
    try expectCloseTransition(
        0,
        close_origin_toolbar,
        false,
        noctty_grid_close_modal_end(&coordinator),
    );
    try std.testing.expectEqual(@as(u32, 0), coordinator.modal_depth);
}

test "deferred source restores origin-specific scheduling exactly once" {
    const origins = [_]u32{ close_origin_toolbar, close_origin_natural };
    for (origins) |origin| {
        var coordinator: CloseCoordinator = .{};
        _ = noctty_grid_close_modal_begin(&coordinator);
        _ = noctty_grid_close_request(&coordinator, origin);
        _ = noctty_grid_close_modal_end(&coordinator);

        const expected = if (origin == close_origin_natural)
            close_effect_schedule_dwell
        else
            close_effect_schedule_preflight;
        try expectCloseTransition(
            expected,
            origin,
            true,
            noctty_grid_close_source_fired(&coordinator, close_source_deferred),
        );
        try expectCloseTransition(
            0,
            origin,
            false,
            noctty_grid_close_source_fired(&coordinator, close_source_deferred),
        );
    }
}

test "modal interruption cancels every pending source and preserves dwell origin" {
    var natural: CloseCoordinator = .{};
    _ = noctty_grid_close_request(&natural, close_origin_natural);
    try expectCloseTransition(
        close_effect_cancel_preflight,
        close_origin_natural,
        true,
        noctty_grid_close_modal_begin(&natural),
    );
    try expectCloseTransition(
        close_effect_schedule_deferred,
        close_origin_natural,
        true,
        noctty_grid_close_modal_end(&natural),
    );
    try expectCloseTransition(
        close_effect_schedule_dwell,
        close_origin_natural,
        true,
        noctty_grid_close_source_fired(&natural, close_source_deferred),
    );

    var deferred: CloseCoordinator = .{};
    _ = noctty_grid_close_modal_begin(&deferred);
    _ = noctty_grid_close_request(&deferred, close_origin_tray);
    _ = noctty_grid_close_modal_end(&deferred);
    try expectCloseTransition(
        close_effect_cancel_deferred,
        close_origin_tray,
        true,
        noctty_grid_close_modal_begin(&deferred),
    );
    try expectCloseTransition(
        close_effect_schedule_deferred,
        close_origin_tray,
        true,
        noctty_grid_close_modal_end(&deferred),
    );

    _ = noctty_grid_close_source_fired(&deferred, close_source_deferred);
    try expectCloseTransition(
        close_effect_cancel_preflight,
        close_origin_tray,
        true,
        noctty_grid_close_modal_begin(&deferred),
    );
}

test "preflight rejection resets while retaining modal nesting" {
    var coordinator: CloseCoordinator = .{};
    _ = noctty_grid_close_request(&coordinator, close_origin_window);
    _ = noctty_grid_close_source_fired(&coordinator, close_source_preflight);
    _ = noctty_grid_close_modal_begin(&coordinator);
    try expectCloseTransition(
        0,
        close_origin_window,
        true,
        noctty_grid_close_preflight_result(&coordinator, 0),
    );
    try std.testing.expectEqual(@as(u32, 1), coordinator.modal_depth);
    try expectCloseTransition(
        0,
        close_origin_tray,
        true,
        noctty_grid_close_request(&coordinator, close_origin_tray),
    );
    try expectCloseTransition(
        close_effect_schedule_deferred,
        close_origin_tray,
        true,
        noctty_grid_close_modal_end(&coordinator),
    );
}

test "renderer viewport and chrome plans clamp every visible boundary" {
    var viewport: RenderViewport = undefined;
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_render_viewport(4, 2, 84, 42, 8, 20, 80, 24, &viewport),
    );
    try std.testing.expectEqual(@as(c_int, 0), viewport.first_row);
    try std.testing.expectEqual(@as(c_int, 3), viewport.end_row);
    try std.testing.expectEqual(@as(c_int, 0), viewport.first_column);
    try std.testing.expectEqual(@as(c_int, 11), viewport.end_column);
    try std.testing.expectEqual(
        @as(c_int, 1),
        noctty_grid_render_viewport(-1e300, -1e300, 1e300, 1e300, 8, 20, 80, 24, &viewport),
    );
    try std.testing.expectEqual(@as(c_int, 0), viewport.first_row);
    try std.testing.expectEqual(@as(c_int, 24), viewport.end_row);
    try std.testing.expectEqual(@as(c_int, 0), viewport.first_column);
    try std.testing.expectEqual(@as(c_int, 80), viewport.end_column);

    var chrome: RenderChrome = undefined;
    noctty_grid_render_chrome(
        4,
        0,
        1,
        1,
        3,
        2,
        1,
        1,
        4,
        3,
        80,
        24,
        8,
        20,
        &chrome,
    );
    try std.testing.expectEqual(@as(u32, 14), chrome.status_role);
    try std.testing.expectEqual(@as(u32, 2), chrome.pane_role);
    try std.testing.expectEqual(@as(c_int, 2), chrome.pane_width);
    try std.testing.expectEqual(@as(c_int, 1), chrome.caret_draw);
    try std.testing.expectEqual(@as(f64, 37), chrome.caret_x);
    try std.testing.expectEqual(@as(f64, 63), chrome.caret_y);
}

test "renderer codepoint encoding rejects surrogates and invalid scalars" {
    var output: [4]u8 = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_codepoint_utf8('A', &output, 4));
    try std.testing.expectEqualSlices(u8, "A", output[0..1]);
    try std.testing.expectEqual(@as(c_int, 4), noctty_grid_codepoint_utf8(0x1f642, &output, 4));
    try std.testing.expectEqualSlices(u8, "🙂", output[0..4]);
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_codepoint_utf8(0xd800, &output, 4));
    try std.testing.expectEqual(@as(u8, '?'), output[0]);
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_codepoint_utf8(0x110000, &output, 4));
    try std.testing.expectEqual(@as(u8, '?'), output[0]);
}

test "renderer cell decoding keeps inverse and style policy coherent" {
    var cell: RenderCell = undefined;
    const style: u32 = 1 | 2 | 4 | 8 | 32 | (@as(u32, 7) << 8) |
        (@as(u32, 12) << 20);
    noctty_grid_render_cell((@as(u64, style) << 32) | 'A', &cell);
    try std.testing.expectEqual(@as(u32, 'A'), cell.codepoint);
    try std.testing.expectEqual(@as(u32, 12), cell.foreground);
    try std.testing.expectEqual(@as(u32, 7), cell.background);
    try std.testing.expectEqual(@as(c_int, 3), cell.face);
    try std.testing.expectEqual(@as(f64, 0.55), cell.alpha);
    try std.testing.expectEqual(@as(c_int, 1), cell.ascii);
    try std.testing.expectEqual(@as(c_int, 1), cell.decorated);
}

test "renderer runs stop at the first policy change" {
    const plain: u32 = (@as(u32, 2) << 8) | (@as(u32, 4) << 20);
    const dim: u32 = plain | 32;
    const cells = [_]u64{
        (@as(u64, plain) << 32) | 'a',
        (@as(u64, plain) << 32) | 'b',
        (@as(u64, dim) << 32) | 'c',
    };
    try std.testing.expectEqual(@as(c_int, 3), noctty_grid_render_run_end(&cells, 0, 3, 1));
    try std.testing.expectEqual(@as(c_int, 2), noctty_grid_render_run_end(&cells, 0, 3, 2));
}

test "accepted preflight commits once and rejects all reentrancy" {
    var coordinator: CloseCoordinator = .{};
    _ = noctty_grid_close_request(&coordinator, close_origin_toolbar);
    _ = noctty_grid_close_source_fired(&coordinator, close_source_preflight);
    try expectCloseTransition(
        close_effect_commit,
        close_origin_toolbar,
        true,
        noctty_grid_close_preflight_result(&coordinator, 1),
    );
    try expectCloseTransition(
        0,
        close_origin_toolbar,
        false,
        noctty_grid_close_preflight_result(&coordinator, 1),
    );
    try expectCloseTransition(
        0,
        close_origin_toolbar,
        false,
        noctty_grid_close_request(&coordinator, close_origin_natural),
    );
    try expectCloseTransition(
        0,
        close_origin_toolbar,
        false,
        noctty_grid_close_source_fired(&coordinator, close_source_preflight),
    );
}

test "stale and mismatched close sources never advance state" {
    var coordinator: CloseCoordinator = .{};
    try expectCloseTransition(
        0,
        close_origin_none,
        false,
        noctty_grid_close_source_fired(&coordinator, close_source_deferred),
    );
    _ = noctty_grid_close_request(&coordinator, close_origin_tray);
    try expectCloseTransition(
        0,
        close_origin_tray,
        false,
        noctty_grid_close_source_fired(&coordinator, close_source_deferred),
    );
    try expectCloseTransition(
        0,
        close_origin_tray,
        false,
        noctty_grid_close_source_fired(&coordinator, std.math.maxInt(u32)),
    );
}

test "cycle targets exhaustively preserve signed wraparound and missing focus" {
    for (1..9) |count_raw| {
        const count: c_int = @intCast(count_raw);
        for (0..count_raw) |current_raw| {
            const current: c_int = @intCast(current_raw);
            for ([_]c_int{ std.math.minInt(c_int), -1 }) |direction| {
                const expected = if (current == 0) count - 1 else current - 1;
                try std.testing.expectEqual(
                    expected,
                    noctty_grid_cycle_target(count, current, 1, direction),
                );
            }
            for ([_]c_int{ 1, std.math.maxInt(c_int) }) |direction| {
                const expected = if (current == count - 1) 0 else current + 1;
                try std.testing.expectEqual(
                    expected,
                    noctty_grid_cycle_target(count, current, -1, direction),
                );
            }
        }
        try std.testing.expectEqual(
            count - 1,
            noctty_grid_cycle_target(count, -1, 0, -1),
        );
        try std.testing.expectEqual(
            @as(c_int, 0),
            noctty_grid_cycle_target(count, count, 0, 1),
        );
    }
    try std.testing.expectEqual(
        std.math.maxInt(c_int) - 1,
        noctty_grid_cycle_target(
            std.math.maxInt(c_int),
            0,
            0,
            std.math.minInt(c_int),
        ),
    );
    try std.testing.expectEqual(
        @as(c_int, 0),
        noctty_grid_cycle_target(
            std.math.maxInt(c_int),
            std.math.maxInt(c_int) - 1,
            1,
            std.math.maxInt(c_int),
        ),
    );
}

test "cycle targets reject every invalid boundary" {
    for ([_]c_int{ std.math.minInt(c_int), -1, 0 }) |count| {
        try std.testing.expectEqual(
            @as(c_int, -1),
            noctty_grid_cycle_target(count, 0, 1, 1),
        );
    }
    for ([_]c_int{ -1, 3, std.math.maxInt(c_int) }) |current| {
        try std.testing.expectEqual(
            @as(c_int, -1),
            noctty_grid_cycle_target(3, current, 1, 1),
        );
    }
    try std.testing.expectEqual(
        @as(c_int, -1),
        noctty_grid_cycle_target(3, 1, 1, 0),
    );
}

test "Smart Tab plans preserve visibility focus and empty-state precedence" {
    var visibility = SmartFilterVisibilityPlan{
        .visible = 0,
        .first_visible = 0,
        .focused_visible = 0,
    };
    noctty_grid_smart_filter_visibility_plan(1, 1, 0, 0, &visibility);
    try std.testing.expectEqual(@as(c_int, 1), visibility.visible);
    try std.testing.expectEqual(@as(c_int, 1), visibility.first_visible);
    try std.testing.expectEqual(@as(c_int, 0), visibility.focused_visible);
    noctty_grid_smart_filter_visibility_plan(1, 0, 1, 1, &visibility);
    try std.testing.expectEqual(@as(c_int, 0), visibility.visible);
    try std.testing.expectEqual(@as(c_int, 0), visibility.first_visible);
    try std.testing.expectEqual(@as(c_int, 0), visibility.focused_visible);

    var summary = SmartFilterSummaryPlan{ .focus_first = 0, .show_empty = 0 };
    noctty_grid_smart_filter_summary_plan(1, 1, 1, 0, &summary);
    try std.testing.expectEqual(@as(c_int, 1), summary.focus_first);
    try std.testing.expectEqual(@as(c_int, 0), summary.show_empty);
    noctty_grid_smart_filter_summary_plan(1, 1, 0, 0, &summary);
    try std.testing.expectEqual(@as(c_int, 0), summary.focus_first);
    try std.testing.expectEqual(@as(c_int, 1), summary.show_empty);
    noctty_grid_smart_filter_summary_plan(0, 1, 0, 0, &summary);
    try std.testing.expectEqual(@as(c_int, 0), summary.show_empty);
}

test "directional focus scores every cardinal direction and keeps first ties" {
    const source = Rectangle{ .x = 0, .y = 0, .width = 0, .height = 0 };
    const directions = [_][2]c_int{
        .{ -1, 0 },
        .{ 1, 0 },
        .{ 0, -1 },
        .{ 0, 1 },
    };
    for (directions) |direction| {
        var plan: DirectionalFocusPlan = undefined;
        noctty_grid_directional_focus_begin(
            &source,
            direction[0],
            direction[1],
            &plan,
        );
        try std.testing.expectEqual(@as(c_int, 1), plan.active);

        const off_direction = Rectangle{
            .x = @floatFromInt(-2 * direction[0]),
            .y = @floatFromInt(-2 * direction[1]),
            .width = 0,
            .height = 0,
        };
        noctty_grid_directional_focus_consider(&plan, &off_direction, 0);
        const farther_primary = Rectangle{
            .x = @floatFromInt(3 * direction[0]),
            .y = @floatFromInt(3 * direction[1]),
            .width = 0,
            .height = 0,
        };
        noctty_grid_directional_focus_consider(&plan, &farther_primary, 1);
        const nearer_primary = Rectangle{
            .x = if (direction[0] != 0)
                @floatFromInt(2 * direction[0])
            else
                100,
            .y = if (direction[1] != 0)
                @floatFromInt(2 * direction[1])
            else
                100,
            .width = 0,
            .height = 0,
        };
        noctty_grid_directional_focus_consider(&plan, &nearer_primary, 2);
        noctty_grid_directional_focus_consider(&plan, &nearer_primary, 3);
        try std.testing.expectEqual(@as(c_int, 2), plan.target_index);

        const threshold = Rectangle{
            .x = @floatFromInt(direction[0]),
            .y = @floatFromInt(direction[1]),
            .width = 0,
            .height = 0,
        };
        noctty_grid_directional_focus_consider(&plan, &threshold, 4);
        try std.testing.expectEqual(@as(c_int, 2), plan.target_index);
    }
}

test "directional focus rejects invalid directions rectangles and candidates" {
    const source = Rectangle{ .x = 0, .y = 0, .width = 10, .height = 10 };
    for ([_][2]c_int{
        .{ 0, 0 },
        .{ -2, 0 },
        .{ 2, 0 },
        .{ 0, -2 },
        .{ 0, 2 },
        .{ -1, -1 },
        .{ 1, 1 },
    }) |direction| {
        var plan: DirectionalFocusPlan = undefined;
        noctty_grid_directional_focus_begin(
            &source,
            direction[0],
            direction[1],
            &plan,
        );
        try std.testing.expectEqual(@as(c_int, 0), plan.active);
        try std.testing.expectEqual(@as(c_int, -1), plan.target_index);
    }

    for ([_]Rectangle{
        .{ .x = std.math.nan(f64), .y = 0, .width = 1, .height = 1 },
        .{ .x = 0, .y = std.math.inf(f64), .width = 1, .height = 1 },
        .{ .x = 0, .y = 0, .width = -1, .height = 1 },
        .{ .x = 0, .y = 0, .width = 1, .height = -1 },
    }) |invalid_source| {
        var plan: DirectionalFocusPlan = undefined;
        noctty_grid_directional_focus_begin(&invalid_source, 1, 0, &plan);
        try std.testing.expectEqual(@as(c_int, 0), plan.active);
    }

    var plan: DirectionalFocusPlan = undefined;
    noctty_grid_directional_focus_begin(&source, 1, 0, &plan);
    const valid = Rectangle{ .x = 20, .y = 0, .width = 10, .height = 10 };
    noctty_grid_directional_focus_consider(&plan, &valid, -1);
    try std.testing.expectEqual(@as(c_int, -1), plan.target_index);
    for ([_]Rectangle{
        .{ .x = std.math.nan(f64), .y = 0, .width = 1, .height = 1 },
        .{ .x = 20, .y = 0, .width = -1, .height = 1 },
    }) |invalid_candidate| {
        noctty_grid_directional_focus_consider(&plan, &invalid_candidate, 1);
        try std.testing.expectEqual(@as(c_int, -1), plan.target_index);
    }
    noctty_grid_directional_focus_begin(null, 1, 0, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.active);
    noctty_grid_directional_focus_begin(&source, 1, 0, null);
    noctty_grid_directional_focus_consider(null, &valid, 0);
    noctty_grid_directional_focus_consider(&plan, null, 0);
}

fn expectKeyCommandPlan(
    expected: KeyCommandPlan,
    pressed: c_int,
    alt_key: c_int,
    smart_filter_clear_available: c_int,
    keyval: u32,
    modifiers: u32,
) !void {
    var actual: KeyCommandPlan = undefined;
    noctty_grid_key_command_plan(
        pressed,
        alt_key,
        smart_filter_clear_available,
        keyval,
        modifiers,
        &actual,
    );
    try std.testing.expectEqual(expected.action, actual.action);
    try std.testing.expectEqual(expected.direction, actual.direction);
    try std.testing.expectEqual(expected.dx, actual.dx);
    try std.testing.expectEqual(expected.dy, actual.dy);
    try std.testing.expectEqual(
        expected.consume_without_effect,
        actual.consume_without_effect,
    );
}

test "key command planner exhaustively preserves navigation modifier precedence" {
    const KeyCase = struct {
        keyval: u32,
        actions: [8]c_int,
        direction: c_int = 0,
        dx: c_int = 0,
        dy: c_int = 0,
    };
    const none = key_action_none;
    const tab = key_action_cycle_tab;
    const pane = key_action_cycle_pane;
    const focus = key_action_focus_direction;
    const cases = [_]KeyCase{
        .{
            .keyval = gdk_key_tab,
            .actions = .{ none, none, pane, tab, none, none, pane, tab },
            .direction = 1,
        },
        .{
            .keyval = gdk_key_iso_left_tab,
            .actions = .{ none, none, none, tab, none, none, none, tab },
            .direction = 1,
        },
        .{
            .keyval = gdk_key_page_up,
            .actions = .{ none, none, tab, none, none, none, tab, none },
            .direction = -1,
        },
        .{
            .keyval = gdk_key_page_down,
            .actions = .{ none, none, tab, none, none, none, tab, none },
            .direction = 1,
        },
        .{
            .keyval = gdk_key_left,
            .actions = .{ none, none, none, none, focus, none, none, none },
            .dx = -1,
        },
        .{
            .keyval = gdk_key_right,
            .actions = .{ none, none, none, none, focus, none, none, none },
            .dx = 1,
        },
        .{
            .keyval = gdk_key_up,
            .actions = .{ none, none, none, none, focus, none, none, none },
            .dy = -1,
        },
        .{
            .keyval = gdk_key_down,
            .actions = .{ none, none, none, none, focus, none, none, none },
            .dy = 1,
        },
    };
    for (cases) |case| {
        for (case.actions, 0..) |action, modifiers| {
            const modifier_value: u32 = @intCast(modifiers);
            const consumes = action == key_action_cycle_tab and
                modifier_value & modifier_shift != 0;
            try expectKeyCommandPlan(
                keyCommandPlan(
                    action,
                    if (action == tab) case.direction else if (action == pane) 1 else 0,
                    if (action == focus) case.dx else 0,
                    if (action == focus) case.dy else 0,
                    consumes,
                ),
                1,
                0,
                0,
                case.keyval,
                modifier_value,
            );
        }
    }
}

test "key command planner bounds lifecycle filter and invalid inputs" {
    try expectKeyCommandPlan(
        keyCommandPlan(key_action_hide_note_overlays, 0, 0, 0, true),
        0,
        1,
        1,
        gdk_key_escape,
        std.math.maxInt(u32),
    );
    try expectKeyCommandPlan(
        keyCommandPlan(key_action_none, 0, 0, 0, false),
        0,
        0,
        1,
        gdk_key_escape,
        std.math.maxInt(u32),
    );
    try expectKeyCommandPlan(
        keyCommandPlan(key_action_show_note_overlays, 0, 0, 0, true),
        std.math.minInt(c_int),
        -1,
        1,
        gdk_key_escape,
        modifier_control | modifier_shift,
    );
    try expectKeyCommandPlan(
        keyCommandPlan(key_action_clear_smart_filter, 0, 0, 0, false),
        1,
        0,
        -1,
        gdk_key_escape,
        std.math.maxInt(u32),
    );
    try expectKeyCommandPlan(
        keyCommandPlan(key_action_cycle_pane, 1, 0, 0, false),
        1,
        0,
        0,
        gdk_key_tab,
        modifier_control | (1 << 31),
    );
    try expectKeyCommandPlan(
        keyCommandPlan(key_action_none, 0, 0, 0, false),
        1,
        0,
        0,
        std.math.maxInt(u32),
        std.math.maxInt(u32),
    );
    noctty_grid_key_command_plan(1, 0, 0, gdk_key_tab, modifier_control, null);
}

test "keyboard chord planner preserves shortcut precedence" {
    var plan = KeyChordPlan{ .action = chord_none, .value = 0 };
    noctty_grid_key_chord_plan(
        'p', gdk_control_mask | gdk_shift_mask, &plan);
    try std.testing.expectEqual(@as(c_int, chord_command_palette), plan.action);
    noctty_grid_key_chord_plan(
        'c', gdk_control_mask | gdk_shift_mask, &plan);
    try std.testing.expectEqual(@as(c_int, chord_copy), plan.action);
    noctty_grid_key_chord_plan('c', gdk_control_mask, &plan);
    try std.testing.expectEqual(@as(c_int, chord_ctrl_c), plan.action);
    noctty_grid_key_chord_plan(
        '1', gdk_control_mask | gdk_mod1_mask, &plan);
    try std.testing.expectEqual(@as(c_int, chord_emit_event), plan.action);
    try std.testing.expectEqual(@as(c_int, 31), plan.value);
    noctty_grid_key_chord_plan(
        gdk_key_page_up, gdk_shift_mask, &plan);
    try std.testing.expectEqual(
        @as(c_int, chord_scroll_keyboard), plan.action);
    noctty_grid_key_chord_plan(
        'b', gdk_control_mask | gdk_mod1_mask, &plan);
    try std.testing.expectEqual(@as(c_int, chord_broadcast), plan.action);
}

test "pointer planner preserves double-click and routing precedence" {
    var plan = PointerEventPlan{ .action = pointer_action_none };
    noctty_grid_pointer_event_plan(
        pointer_event_double_press, 1, route_local_pointer,
        0, 0, 1, 1, 0, 0, &plan);
    try std.testing.expectEqual(@as(c_int, pointer_action_zoom), plan.action);
    noctty_grid_pointer_event_plan(
        pointer_event_double_press, 1, route_local_pointer,
        0, 0, 0, 1, 0, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, pointer_action_select_word), plan.action);
    noctty_grid_pointer_event_plan(
        pointer_event_press, 3, route_local_pointer,
        1, 0, 0, 0, 0, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, pointer_action_show_hyperlink_menu), plan.action);
    noctty_grid_pointer_event_plan(
        pointer_event_release, 1, route_selection,
        0, 0, 0, 0, 0, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, pointer_action_update_selection), plan.action);
    noctty_grid_pointer_event_plan(
        pointer_event_press, 1, route_application_mouse,
        0, 0, 0, 0, 0, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, pointer_action_deliver_mouse), plan.action);
}

test "compact setting plans map every persisted field and reject unknowns" {
    const cases = [_]struct { field: c_int, target: c_int }{
        .{ .field = 0, .target = compact_setting_target_width_percent },
        .{ .field = 1, .target = compact_setting_target_height_percent },
        .{ .field = 2, .target = compact_setting_target_animation },
        .{ .field = 3, .target = compact_setting_target_hide_focus },
        .{ .field = 4, .target = compact_setting_target_focus_pointer },
        .{ .field = 5, .target = compact_setting_target_pane_info },
        .{ .field = 14, .target = compact_setting_target_width_pixels },
        .{ .field = 15, .target = compact_setting_target_height_pixels },
    };
    for (cases) |case| {
        var plan = CompactSettingPlan{ .target = -1, .valid = 0 };
        noctty_grid_compact_setting_plan(case.field, &plan);
        try std.testing.expectEqual(@as(c_int, 1), plan.valid);
        try std.testing.expectEqual(case.target, plan.target);
    }
    var invalid = CompactSettingPlan{ .target = 0, .valid = 1 };
    noctty_grid_compact_setting_plan(13, &invalid);
    try std.testing.expectEqual(@as(c_int, 0), invalid.valid);
    try std.testing.expectEqual(@as(c_int, -1), invalid.target);
}

test "font rendering plans clamp combo values and reject unknown events" {
    var plan = FontRenderingPlan{ .target = -1, .value = -1, .valid = 0 };
    noctty_grid_font_rendering_plan(110, -4, &plan);
    try std.testing.expectEqual(@as(c_int, font_rendering_target_antialias), plan.target);
    try std.testing.expectEqual(@as(c_int, 0), plan.value);
    try std.testing.expectEqual(@as(c_int, 1), plan.valid);
    noctty_grid_font_rendering_plan(111, 9, &plan);
    try std.testing.expectEqual(@as(c_int, font_rendering_target_hinting), plan.target);
    try std.testing.expectEqual(@as(c_int, 2), plan.value);
    noctty_grid_font_rendering_plan(112, 1, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.valid);
}

test "terminal menu plans bound actions and select-all geometry" {
    var plan = TerminalMenuPlan{
        .action = terminal_menu_action_none,
        .selection_end_column = 0,
        .selection_end_row = 0,
    };
    noctty_grid_terminal_menu_plan(
        terminal_menu_action_select_all, 6, 4, &plan);

    try std.testing.expectEqual(
        @as(c_int, terminal_menu_action_select_all), plan.action);
    try std.testing.expectEqual(@as(c_int, 5), plan.selection_end_column);
    try std.testing.expectEqual(@as(c_int, 3), plan.selection_end_row);
    noctty_grid_terminal_menu_plan(
        terminal_menu_action_select_all, -1, 0, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.selection_end_column);
    try std.testing.expectEqual(@as(c_int, 0), plan.selection_end_row);
    noctty_grid_terminal_menu_plan(99, 6, 4, &plan);
    try std.testing.expectEqual(@as(c_int, terminal_menu_action_none), plan.action);
}

test "theme display labels and profile validity preserve native boundaries" {
    var output: [64]u8 = undefined;
    var length = noctty_grid_theme_display_label(
        "noctty-dark".ptr, "noctty-dark".len, &output, output.len);
    try std.testing.expectEqualStrings("NOCTTY Dark", output[0..@intCast(length)]);
    length = noctty_grid_theme_display_label(
        "custom".ptr, "custom".len, &output, output.len);
    try std.testing.expectEqualStrings("custom", output[0..@intCast(length)]);
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_profile_preset_valid(0));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_profile_preset_valid(4));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_profile_preset_valid(-1));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_profile_preset_valid(5));
}

test "window dimensions plan preserves percentage floors and available bounds" {
    var plan = WindowDimensionsPlan{ .width = 0, .height = 0 };
    noctty_grid_window_dimensions_plan(1920, 1080, &plan);
    try std.testing.expectEqual(@as(c_int, 1536), plan.width);
    try std.testing.expectEqual(@as(c_int, 810), plan.height);
    noctty_grid_window_dimensions_plan(400, 200, &plan);
    try std.testing.expectEqual(@as(c_int, 400), plan.width);
    try std.testing.expectEqual(@as(c_int, 200), plan.height);
    noctty_grid_window_dimensions_plan(0, -1, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.width);
    try std.testing.expectEqual(@as(c_int, 0), plan.height);
}

test "launch profile controls plan normalizes kinds and sensitivity gates" {
    var plan = LaunchProfileControlsPlan{
        .kind = -1,
        .command_sensitive = 0,
        .ssh_target_sensitive = 0,
    };
    noctty_grid_launch_profile_controls_plan(0, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.kind);
    try std.testing.expectEqual(@as(c_int, 0), plan.command_sensitive);
    try std.testing.expectEqual(@as(c_int, 0), plan.ssh_target_sensitive);
    noctty_grid_launch_profile_controls_plan(1, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.command_sensitive);
    try std.testing.expectEqual(@as(c_int, 0), plan.ssh_target_sensitive);
    noctty_grid_launch_profile_controls_plan(2, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.command_sensitive);
    try std.testing.expectEqual(@as(c_int, 1), plan.ssh_target_sensitive);
    noctty_grid_launch_profile_controls_plan(99, &plan);
    try std.testing.expectEqual(@as(c_int, 4), plan.kind);
    try std.testing.expectEqual(@as(c_int, 1), plan.ssh_target_sensitive);
    noctty_grid_launch_profile_controls_plan(-1, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.kind);
}

test "workspace event plans classify routing actions and restoration" {
    var plan = WorkspaceEventPlan{
        .action = workspace_event_emit,
        .bind_layout = 0,
        .restore_missing = 0,
    };
    noctty_grid_workspace_event_plan(20, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, workspace_event_create_tab), plan.action);
    try std.testing.expectEqual(@as(c_int, 0), plan.bind_layout);
    noctty_grid_workspace_event_plan(21, 0, &plan);
    try std.testing.expectEqual(
        @as(c_int, workspace_event_split), plan.action);
    try std.testing.expectEqual(@as(c_int, 1), plan.bind_layout);
    noctty_grid_workspace_event_plan(50, 21, &plan);
    try std.testing.expectEqual(
        @as(c_int, workspace_event_layout_preset), plan.action);
    try std.testing.expectEqual(@as(c_int, 0), plan.restore_missing);
    noctty_grid_workspace_event_plan(61, 0, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.restore_missing);
    noctty_grid_workspace_event_plan(56, 0, &plan);
    try std.testing.expectEqual(@as(c_int, workspace_event_move), plan.action);
    noctty_grid_workspace_event_plan(999, 0, &plan);
    try std.testing.expectEqual(@as(c_int, workspace_event_emit), plan.action);
}

test "tray menu plans preserve item kinds and actions" {
    var plan = TrayMenuItemPlan{
        .valid = 0,
        .kind = tray_menu_kind_standard,
        .has_children = 0,
        .action = tray_menu_action_none,
    };
    noctty_grid_tray_menu_plan(0, &plan);
    try std.testing.expectEqual(@as(c_int, 1), plan.valid);
    try std.testing.expectEqual(@as(c_int, tray_menu_kind_root), plan.kind);
    try std.testing.expectEqual(@as(c_int, 1), plan.has_children);
    noctty_grid_tray_menu_plan(1, &plan);
    try std.testing.expectEqual(
        @as(c_int, tray_menu_action_toggle), plan.action);
    noctty_grid_tray_menu_plan(2, &plan);
    try std.testing.expectEqual(
        @as(c_int, tray_menu_action_settings), plan.action);
    noctty_grid_tray_menu_plan(3, &plan);
    try std.testing.expectEqual(
        @as(c_int, tray_menu_kind_separator), plan.kind);
    noctty_grid_tray_menu_plan(4, &plan);
    try std.testing.expectEqual(
        @as(c_int, tray_menu_action_close), plan.action);
    noctty_grid_tray_menu_plan(9, &plan);
    try std.testing.expectEqual(@as(c_int, 0), plan.valid);
    try std.testing.expectEqual(@as(c_int, tray_menu_action_none), plan.action);
}

test "settings event policy preserves every native control code" {
    const expected = [_]c_int{
        76, 77, 72, 73, 74, 40, 41, 96, 42, 43,
        44, 45, 63, 48, 49, 116, 110, 111, 75, 108,
        117, 118, 46, 47, 127, 128, 129, 119, 120, 121,
        122, 123, 124, 125, 126, 109, 115, 130,
    };
    for (expected, 0..) |code, index| {
        try std.testing.expectEqual(
            code, noctty_grid_settings_event_code(@intCast(index)));
    }
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_settings_event_code(-1));
    try std.testing.expectEqual(
        @as(c_int, -1),
        noctty_grid_settings_event_code(settings_event_kind_count),
    );
}
test "host event policy preserves native protocol identities" {
    const expected = [_]c_int{
        1, 3, 4, 11, 19, 20, 21, 22, 23, 24, 33, 27, 28,
        50, 51, 52, 60, 61, 55, 56, 57, 58, 59, 62, 64, 65,
        66, 67, 68, 69, 78, 79, 80, 81, 82, 83, 84, 85, 86,
        87, 88, 89, 90, 91, 92, 93, 94, 95, 97, 98, 99, 100,
        101, 102, 103, 104, 105, 106, 108, 26, 14, 15,
    };
    for (expected, 0..) |code, index| {
        try std.testing.expectEqual(
            code, noctty_grid_host_event_code(@intCast(index)));
    }
    try std.testing.expectEqual(@as(c_int, -1), noctty_grid_host_event_code(-1));
    try std.testing.expectEqual(
        @as(c_int, -1),
        noctty_grid_host_event_code(host_event_kind_count),
    );
}


test "lifecycle timing plans keep bounded native scheduling constants" {
    var timing: LifecycleTimingPlan = undefined;
    noctty_grid_lifecycle_timing_plan(&timing);
    try std.testing.expectEqual(@as(c_int, 200), timing.output_deadman_ms);
    try std.testing.expectEqual(@as(c_int, 4), timing.write_flush_ms);
    try std.testing.expectEqual(@as(i64, 250_000), timing.exit_poll_us);
    try std.testing.expectEqual(@as(c_int, 16), timing.tick_ms);
    try std.testing.expectEqual(@as(c_int, 500), timing.cursor_blink_ms);
    try std.testing.expectEqual(@as(c_int, 1), timing.maintenance_seconds);
    try std.testing.expectEqual(@as(i64, 30_000_000), timing.idle_background_us);
    try std.testing.expectEqual(@as(i64, 300_000_000), timing.idle_focused_us);
    try std.testing.expectEqual(@as(c_int, 16), timing.idle_steps_per_tick);
    try std.testing.expectEqual(
        @as(c_int, 50), timing.preset_settle_interval_ms);
    try std.testing.expectEqual(@as(c_int, 4), timing.preset_settle_attempts);
    try std.testing.expectEqual(@as(c_int, 4500), timing.status_feedback_ms);
    try std.testing.expectEqual(@as(c_int, 800), timing.pane_cycle_feedback_ms);
    try std.testing.expectEqual(@as(c_int, 800), timing.tab_cycle_feedback_ms);
    try std.testing.expectEqual(@as(c_int, 120), timing.focus_hide_ms);
    try std.testing.expectEqual(
        @as(c_int, 16), timing.layer_surface_hide_commit_ms);
    try std.testing.expectEqual(
        @as(c_int, 250), timing.quick_note_save_debounce_ms);
    try std.testing.expectEqual(
        @as(c_int, 200), timing.sharing_status_refresh_ms);
    try std.testing.expectEqual(@as(c_int, 750), timing.resize_overlay_hide_ms);
    try std.testing.expectEqual(@as(c_int, 75), timing.resize_commit_ms);
    try std.testing.expectEqual(@as(c_int, 250), timing.resize_overlay_arm_ms);
    try std.testing.expectEqual(
        @as(c_int, 16), timing.even_pane_settle_interval_ms);
    try std.testing.expectEqual(
        @as(c_int, 4), timing.even_pane_settle_attempts);
    try std.testing.expectEqual(@as(c_int, 1000), timing.dbus_call_timeout_ms);
    try std.testing.expectEqual(@as(c_int, 1500), timing.dbus_operation_timeout_ms);
    try std.testing.expectEqual(@as(c_int, 5000), timing.dbus_notification_timeout_ms);
    try std.testing.expectEqual(@as(c_int, 2000), timing.dbus_drain_ms);
    try std.testing.expectEqual(@as(i64, 1000), timing.dbus_poll_us);
}

test "native host policy owns geometry event and color ordinals" {
    var policy: NativeHostPolicy = undefined;
    noctty_grid_native_host_policy(&policy);
    try std.testing.expectEqual(@as(c_int, 480), policy.dropdown_min_width_px);
    try std.testing.expectEqual(@as(c_int, 240), policy.dropdown_min_height_px);
    try std.testing.expectEqual(@as(c_int, 2), policy.window_resize_border_px);
    try std.testing.expectEqual(@as(c_int, 18), policy.pane_info_height_px);
    try std.testing.expectEqual(@as(c_int, 12), policy.terminal_scrollbar_width_px);
    try std.testing.expectEqual(
        @as(c_int, 24), policy.terminal_scrollbar_min_thumb_px);
    try std.testing.expectEqual(
        @as(i64, 4 * 1024 * 1024), policy.selection_copy_max_bytes);
    try std.testing.expectEqual(
        @as(c_int, 112), policy.event_idle_history_compacted);
    try std.testing.expectEqual(@as(c_int, 113), policy.event_status_notification);
    try std.testing.expectEqual(@as(c_int, 114), policy.event_status_acknowledged);
    try std.testing.expectEqual(@as(c_int, -2), policy.text_action_persistence_failed);
    try std.testing.expectEqual(@as(c_int, 0), policy.ui_color_workspace_background);
    try std.testing.expectEqual(@as(c_int, 3), policy.ui_color_pane_border_inactive);
    try std.testing.expectEqual(@as(c_int, 6), policy.ui_color_scrollbar_thumb_hover);
    try std.testing.expectEqual(@as(c_int, 9), policy.ui_color_overlay_foreground);
    try std.testing.expectEqual(@as(c_int, 11), policy.ui_color_search_match_background);
    try std.testing.expectEqual(@as(c_int, 15), policy.ui_color_status_error);
    try std.testing.expectEqual(@as(c_int, 17), policy.ui_color_pane_gap);
}
