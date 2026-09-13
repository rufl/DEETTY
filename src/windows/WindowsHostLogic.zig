//! Pure, tested policy consumed by the native Zig Win32 host.
//!
//! Workspace/session and mouse transitions stay independent of Windows
//! handles so the message adapter composes them without recreating decisions.

const std = @import("std");
const KeyEncoding = @import("terminal_key_encoding");
const Appearance = @import("WindowsAppearance.zig");

const layout_scale: u64 = 1_000_000;

pub const PaneGeometry = extern struct {
    pane_left: c_int,
    pane_top: c_int,
    pane_right: c_int,
    pane_bottom: c_int,
    content_left: c_int,
    content_top: c_int,
    content_right: c_int,
    content_bottom: c_int,
};

pub const Preferences = extern struct {
    theme: c_int,
    font_size_pt: c_int,
    launch_profile: c_int,
    restore_workspace: c_int,
};

pub const workspace_max_sessions: c_int = 32;
pub const workspace_startup_reject: c_int = 0;
pub const workspace_startup_remote: c_int = 1;
pub const workspace_startup_local: c_int = 2;
pub const session_start_reject: c_int = 0;
pub const session_start_create: c_int = 1;
pub const session_start_existing: c_int = 2;
pub const session_failure_shutdown: c_int = 0;
pub const session_failure_rollback: c_int = 1;
pub const session_failure_cleanup: c_int = 2;
pub const workspace_action_none: c_int = 0;
pub const workspace_action_start: c_int = 1;
pub const workspace_action_rollback: c_int = 2;
pub const workspace_close_shutdown: c_int = -1;
pub const workspace_close_none: c_int = 0;
pub const workspace_close_cleanup: c_int = 1;

pub const WorkspaceState = extern struct {
    live_sessions: u32,
    pending_close: u32,
};

pub const SessionPlan = extern struct {
    session_index: c_int,
    columns: c_int,
    rows: c_int,
};

pub export fn noctty_windows_workspace_state_init(
    state: ?*WorkspaceState,
) callconv(.c) c_int {
    const current = state orelse return 0;
    current.* = .{ .live_sessions = 0, .pending_close = 0 };
    return 1;
}

pub export fn noctty_windows_workspace_local_operation(
    remote_mode: c_int,
) callconv(.c) c_int {
    return @intFromBool(remote_mode == 0);
}

pub export fn noctty_windows_workspace_startup_plan(
    state: ?*WorkspaceState,
    remote_mode: c_int,
    pane_count: c_int,
    session_count: ?*c_int,
) callconv(.c) c_int {
    const current = state orelse return workspace_startup_reject;
    const count = session_count orelse return workspace_startup_reject;
    count.* = 0;
    if (remote_mode != 0) return workspace_startup_remote;
    if (current.live_sessions != 0 or current.pending_close != 0 or
        pane_count <= 0 or pane_count > workspace_max_sessions)
        return workspace_startup_reject;
    count.* = pane_count;
    return workspace_startup_local;
}

pub export fn noctty_windows_session_start_plan(
    state: ?*const WorkspaceState,
    session_index: c_int,
    dimensions_valid: c_int,
    columns: u16,
    rows: u16,
    output: ?*SessionPlan,
) callconv(.c) c_int {
    const current = state orelse return session_start_reject;
    const plan = output orelse return session_start_reject;
    plan.* = .{ .session_index = -1, .columns = 0, .rows = 0 };
    const bit = sessionBit(session_index) orelse return session_start_reject;
    if (dimensions_valid <= 0 or columns == 0 or rows == 0)
        return session_start_reject;
    plan.* = .{
        .session_index = session_index,
        .columns = columns,
        .rows = rows,
    };
    if ((current.live_sessions & bit) != 0) return session_start_existing;
    return session_start_create;
}

pub export fn noctty_windows_session_started(
    state: ?*WorkspaceState,
    session_index: c_int,
) callconv(.c) c_int {
    const current = state orelse return 0;
    const bit = sessionBit(session_index) orelse return 0;
    if (current.pending_close != 0 or (current.live_sessions & bit) != 0)
        return 0;
    current.live_sessions |= bit;
    return 1;
}

pub export fn noctty_windows_session_start_failed(
    state: ?*WorkspaceState,
    session_index: c_int,
    startup: c_int,
    cleanup_mask: ?*u32,
) callconv(.c) c_int {
    const current = state orelse return session_failure_shutdown;
    const cleanup = cleanup_mask orelse return session_failure_shutdown;
    cleanup.* = 0;
    const bit = sessionBit(session_index) orelse return session_failure_shutdown;
    current.live_sessions &= ~bit;
    if (startup == 0) return session_failure_rollback;
    cleanup.* = current.live_sessions;
    current.* = .{ .live_sessions = 0, .pending_close = 0 };
    return session_failure_cleanup;
}

pub export fn noctty_windows_session_is_live(
    state: ?*const WorkspaceState,
    session_index: c_int,
) callconv(.c) c_int {
    const current = state orelse return 0;
    const bit = sessionBit(session_index) orelse return 0;
    return @intFromBool((current.live_sessions & bit) != 0);
}

pub export fn noctty_windows_workspace_resize_count(
    remote_mode: c_int,
    pane_count: c_int,
) callconv(.c) c_int {
    if (remote_mode != 0 or pane_count <= 0) return 0;
    return @min(pane_count, workspace_max_sessions);
}

pub export fn noctty_windows_session_resize_plan(
    state: ?*const WorkspaceState,
    session_index: c_int,
    columns: c_int,
    rows: c_int,
    output: ?*SessionPlan,
) callconv(.c) c_int {
    const current = state orelse return 0;
    const plan = output orelse return 0;
    plan.* = .{ .session_index = -1, .columns = 0, .rows = 0 };
    const bit = sessionBit(session_index) orelse return 0;
    if ((current.live_sessions & bit) == 0 or columns < 1 or columns > 1000 or
        rows < 1 or rows > 500)
        return 0;
    plan.* = .{
        .session_index = session_index,
        .columns = columns,
        .rows = rows,
    };
    return 1;
}

pub export fn noctty_windows_workspace_action_result(
    remote_mode: c_int,
    callback_result: c_int,
    session_index: ?*c_int,
) callconv(.c) c_int {
    const index = session_index orelse return workspace_action_none;
    index.* = -1;
    if (remote_mode != 0 or callback_result <= 0) return workspace_action_none;
    const candidate = callback_result - 1;
    if (sessionBit(candidate) == null) return workspace_action_rollback;
    index.* = candidate;
    return workspace_action_start;
}

pub export fn noctty_windows_workspace_rollback_matches(
    session_index: c_int,
    committed_mask: u32,
) callconv(.c) c_int {
    const bit = sessionBit(session_index) orelse return 0;
    return @intFromBool(committed_mask == bit);
}

pub export fn noctty_windows_workspace_close_plan(
    state: ?*WorkspaceState,
    remote_mode: c_int,
    session_count: c_int,
    query_mask: u32,
    cleanup_mask: ?*u32,
) callconv(.c) c_int {
    const current = state orelse return workspace_close_shutdown;
    const cleanup = cleanup_mask orelse return workspace_close_shutdown;
    cleanup.* = 0;
    if (remote_mode != 0 or query_mask == 0) return workspace_close_none;
    if (current.pending_close != 0 or
        !validSessionMask(query_mask, session_count))
        return workspace_close_shutdown;
    current.pending_close = query_mask;
    cleanup.* = query_mask;
    return workspace_close_cleanup;
}

pub export fn noctty_windows_workspace_close_commit(
    state: ?*WorkspaceState,
    committed_mask: u32,
) callconv(.c) c_int {
    const current = state orelse return 0;
    const expected = current.pending_close;
    current.pending_close = 0;
    if (expected == 0 or committed_mask != expected) return 0;
    current.live_sessions &= ~expected;
    return 1;
}

pub export fn noctty_windows_workspace_reset(
    state: ?*WorkspaceState,
    cleanup_mask: ?*u32,
) callconv(.c) c_int {
    const current = state orelse return 0;
    const cleanup = cleanup_mask orelse return 0;
    cleanup.* = current.live_sessions;
    current.* = .{ .live_sessions = 0, .pending_close = 0 };
    return 1;
}

fn sessionBit(session_index: c_int) ?u32 {
    if (session_index < 0 or session_index >= workspace_max_sessions) return null;
    return @as(u32, 1) << @intCast(session_index);
}

fn validSessionMask(mask: u32, session_count: c_int) bool {
    if (mask == 0 or session_count <= 0 or session_count > workspace_max_sessions)
        return false;
    const valid = if (session_count == workspace_max_sessions)
        std.math.maxInt(u32)
    else
        (@as(u32, 1) << @intCast(session_count)) - 1;
    return (mask & ~valid) == 0;
}

pub const menu_theme_dark: u32 = 40001;
pub const menu_theme_high_contrast: u32 = 40002;
pub const menu_theme_zinc: u32 = 40003;
pub const menu_font_11: u32 = 40011;
pub const menu_font_13: u32 = 40013;
pub const menu_font_16: u32 = 40016;
pub const menu_font_18: u32 = 40018;
pub const menu_profile_powershell: u32 = 40021;
pub const menu_profile_command: u32 = 40022;
pub const menu_restore_startup: u32 = 40031;
pub const menu_workspace_save: u32 = 40041;
pub const menu_workspace_restore: u32 = 40042;
pub const menu_open_nocted: u32 = 40051;
pub const menu_font_custom: u32 = 40060;
pub const menu_font_increase: u32 = 40061;
pub const menu_font_decrease: u32 = 40062;
pub const menu_font_reset: u32 = 40063;

pub const MenuAction = extern struct {
    kind: c_int,
    value: c_int,
};

pub const MouseState = extern struct {
    selection_active: c_int,
    selection_dragging: c_int,
    selection_pane: c_int,
    selection_anchor_column: c_int,
    selection_anchor_row: c_int,
    selection_extent_column: c_int,
    selection_extent_row: c_int,
    pressed_buttons: u32,
    application_capture: c_int,
    capture_pane: c_int,
    capture_last_column: c_int,
    capture_last_row: c_int,
};

pub const MouseInput = extern struct {
    kind: c_int,
    button: c_int,
    shift: c_int,
    tracking_mode: u32,
    cell_valid: c_int,
    inside_content: c_int,
    pane: c_int,
    column: c_int,
    row: c_int,
};

pub const MouseDecision = extern struct {
    capture: c_int,
    invalidate: c_int,
    select_pane: c_int,
    report_buttons: u32,
    report_kind: c_int,
    report_pane: c_int,
    report_column: c_int,
    report_row: c_int,
};

pub const mouse_event_press: c_int = 1;
pub const mouse_event_release: c_int = 2;
pub const mouse_event_move: c_int = 3;
pub const mouse_event_cancel: c_int = 4;
pub const mouse_event_clear_selection: c_int = 5;
pub const mouse_route_none: c_int = 0;
pub const mouse_route_hit_test: c_int = 1;
pub const mouse_route_selection: c_int = 2;
pub const mouse_route_application: c_int = 3;
pub const mouse_capture_unchanged: c_int = 0;
pub const mouse_capture_set: c_int = 1;
pub const mouse_capture_release: c_int = 2;
pub const mouse_press: c_int = 0;
pub const mouse_release: c_int = 1;
pub const mouse_motion: c_int = 2;

pub const key_action_default: c_int = 0;
pub const key_action_copy: c_int = 1;
pub const key_action_paste: c_int = 2;
pub const key_action_new_tab: c_int = 3;
pub const key_action_split_down: c_int = 4;
pub const key_action_split_left: c_int = 5;
pub const key_action_close_tab: c_int = 6;
pub const key_action_close_pane: c_int = 7;
pub const key_action_cycle: c_int = 8;
pub const key_action_special: c_int = 9;

pub export fn noctty_windows_decode_key_action(
    key: u32,
    control: c_int,
    shift: c_int,
    alt: c_int,
    remote_mode: c_int,
    suppress_character: ?*c_int,
) callconv(.c) c_int {
    const suppress = suppress_character orelse return key_action_default;
    suppress.* = 0;
    if (alt != 0 and key == 0x73) return key_action_default; // VK_F4.
    if (control != 0 and shift != 0 and key == 'C') {
        suppress.* = 1;
        return key_action_copy;
    }
    if (control != 0 and shift != 0 and key == 'V') {
        suppress.* = 1;
        return key_action_paste;
    }
    if (control != 0 and key == 0x09) { // VK_TAB.
        suppress.* = 1;
        return key_action_cycle;
    }
    if (remote_mode == 0 and control != 0 and shift != 0) {
        suppress.* = 1;
        return switch (key) {
            'T' => key_action_new_tab,
            'S' => key_action_split_down,
            'L' => key_action_split_left,
            'W' => key_action_close_tab,
            else => blk: {
                suppress.* = 0;
                break :blk key_action_default;
            },
        };
    }
    if (remote_mode == 0 and control != 0 and shift == 0 and key == 'D') {
        suppress.* = 1;
        return key_action_close_pane;
    }
    if (shift != 0 and key == 0x2d) return key_action_paste; // VK_INSERT.
    if (isSpecialKey(key)) return key_action_special;
    return key_action_default;
}

fn isSpecialKey(key: u32) bool {
    return switch (key) {
        0x21...0x28, 0x2d, 0x2e, 0x70...0x7b => true,
        else => false,
    };
}

pub export fn noctty_windows_decode_menu_command(
    command: u32,
    restore_workspace: c_int,
    output: ?*MenuAction,
) callconv(.c) c_int {
    const action = output orelse return 0;
    action.* = switch (command) {
        menu_theme_dark => .{ .kind = 1, .value = 0 },
        menu_theme_high_contrast => .{ .kind = 1, .value = 1 },
        menu_theme_zinc => .{ .kind = 1, .value = 2 },
        menu_font_11 => .{ .kind = 2, .value = 11 },
        menu_font_13 => .{ .kind = 2, .value = 13 },
        menu_font_16 => .{ .kind = 2, .value = 16 },
        menu_font_18 => .{ .kind = 2, .value = 18 },
        menu_profile_powershell => .{ .kind = 3, .value = 0 },
        menu_profile_command => .{ .kind = 3, .value = 1 },
        menu_restore_startup => .{ .kind = 4, .value = @intFromBool(restore_workspace == 0) },
        menu_workspace_save => .{ .kind = 5, .value = 0 },
        menu_workspace_restore => .{ .kind = 6, .value = 0 },
        menu_open_nocted => .{ .kind = 7, .value = 0 },
        else => return 0,
    };
    return 1;
}

pub export fn noctty_windows_normalize_preferences(
    theme: c_int,
    font_size_pt: c_int,
    launch_profile: c_int,
    restore_workspace: c_int,
    output: ?*Preferences,
) callconv(.c) c_int {
    const result = output orelse return 0;
    const valid = (Appearance.validTheme(theme) or theme == 3) and
        Appearance.validFontSize(font_size_pt) and
        (launch_profile >= 0 and launch_profile <= 2) and
        (restore_workspace == 0 or restore_workspace == 1);
    result.* = .{
        .theme = if (Appearance.validTheme(theme) or theme == 3) theme else 0,
        .font_size_pt = if (Appearance.validFontSize(font_size_pt)) font_size_pt else Appearance.default_font_size,
        .launch_profile = if (launch_profile >= 0 and launch_profile <= 2) launch_profile else 0,
        .restore_workspace = @intFromBool(restore_workspace != 0),
    };
    return @intFromBool(valid);
}

pub export fn noctty_windows_blend_rgb(
    foreground: u32,
    background: u32,
    foreground_weight: u32,
) callconv(.c) u32 {
    return blend(foreground, background, @min(foreground_weight, 255));
}

fn blend(foreground: u32, background: u32, foreground_weight: u32) u32 {
    const background_weight = 255 - foreground_weight;
    const red = (((foreground >> 16) & 0xff) * foreground_weight +
        ((background >> 16) & 0xff) * background_weight) / 255;
    const green = (((foreground >> 8) & 0xff) * foreground_weight +
        ((background >> 8) & 0xff) * background_weight) / 255;
    const blue = ((foreground & 0xff) * foreground_weight +
        (background & 0xff) * background_weight) / 255;
    return (red << 16) | (green << 8) | blue;
}

pub export fn noctty_windows_rgb_from_colorref(color: u32) callconv(.c) u32 {
    return ((color & 0xff) << 16) | (color & 0xff00) | ((color >> 16) & 0xff);
}

pub export fn noctty_windows_colorref_from_rgb(rgb: u32) callconv(.c) u32 {
    return noctty_windows_rgb_from_colorref(rgb);
}

pub export fn noctty_windows_grid_dimensions(
    pixel_width: c_int,
    pixel_height: c_int,
    cell_width: c_int,
    cell_height: c_int,
    columns: *c_int,
    rows: *c_int,
) callconv(.c) c_int {
    if (cell_width <= 0 or cell_height <= 0) return 0;
    columns.* = std.math.clamp(@divTrunc(pixel_width, cell_width), 1, 1000);
    rows.* = std.math.clamp(@divTrunc(pixel_height, cell_height), 1, 500);
    return 1;
}

pub export fn noctty_windows_encode_utf16_input(
    character: u16,
    pending_high_surrogate: *u16,
    output: [*]u8,
    capacity: usize,
) callconv(.c) usize {
    if (character >= 0xd800 and character <= 0xdbff) {
        pending_high_surrogate.* = character;
        return 0;
    }
    var source: [2]u16 = undefined;
    var source_count: usize = 1;
    if (character >= 0xdc00 and character <= 0xdfff and
        pending_high_surrogate.* >= 0xd800 and pending_high_surrogate.* <= 0xdbff)
    {
        source[0] = pending_high_surrogate.*;
        source[1] = character;
        source_count = 2;
    } else {
        source[0] = character;
    }
    pending_high_surrogate.* = 0;
    if (capacity < 4) return 0;
    return std.unicode.utf16LeToUtf8(output[0..capacity], source[0..source_count]) catch 0;
}

pub export fn noctty_windows_compute_pane_geometry(
    client_left: c_int,
    client_top: c_int,
    client_right: c_int,
    client_bottom: c_int,
    x_millionths: u32,
    y_millionths: u32,
    width_millionths: u32,
    height_millionths: u32,
    inset: c_int,
    output: *PaneGeometry,
) callconv(.c) c_int {
    const client_width = client_right - client_left;
    const client_height = client_bottom - client_top;
    if (client_width <= 0 or client_height <= 0 or inset < 0) return 0;
    const x_end = @as(u64, x_millionths) + width_millionths;
    const y_end = @as(u64, y_millionths) + height_millionths;
    if (x_millionths > layout_scale or y_millionths > layout_scale or
        x_end > layout_scale or y_end > layout_scale or
        width_millionths == 0 or height_millionths == 0) return 0;

    output.* = .{
        .pane_left = client_left + scale(client_width, x_millionths),
        .pane_top = client_top + scale(client_height, y_millionths),
        .pane_right = client_left + scale(client_width, x_end),
        .pane_bottom = client_top + scale(client_height, y_end),
        .content_left = 0,
        .content_top = 0,
        .content_right = 0,
        .content_bottom = 0,
    };
    if (output.pane_right - output.pane_left <= inset * 2 or
        output.pane_bottom - output.pane_top <= inset * 2) return 0;
    output.content_left = output.pane_left + inset;
    output.content_top = output.pane_top + inset;
    output.content_right = output.pane_right - inset;
    output.content_bottom = output.pane_bottom - inset;
    return 1;
}

fn scale(value: c_int, millionths: u64) c_int {
    return @intCast(@divFloor(@as(i64, value) * @as(i64, @intCast(millionths)), layout_scale));
}

pub export fn noctty_windows_pointer_cell(
    content_left: c_int,
    content_top: c_int,
    content_right: c_int,
    content_bottom: c_int,
    columns: c_int,
    rows: c_int,
    pointer_x: c_int,
    pointer_y: c_int,
    clamp: c_int,
    column: *c_int,
    row: *c_int,
    inside: *c_int,
) callconv(.c) c_int {
    const width = content_right - content_left;
    const height = content_bottom - content_top;
    if (width <= 0 or height <= 0 or columns <= 0 or rows <= 0) return 0;
    inside.* = @intFromBool(pointer_x >= content_left and pointer_x < content_right and
        pointer_y >= content_top and pointer_y < content_bottom);
    if (inside.* == 0 and clamp == 0) return 1;
    const x = std.math.clamp(pointer_x, content_left, content_right - 1);
    const y = std.math.clamp(pointer_y, content_top, content_bottom - 1);
    column.* = @intCast(@divFloor(@as(i64, x - content_left) * columns, width));
    row.* = @intCast(@divFloor(@as(i64, y - content_top) * rows, height));
    return 1;
}

pub export fn noctty_windows_cell_selected(
    selection_active: c_int,
    selection_pane: c_int,
    pane_index: c_int,
    anchor_column: c_int,
    anchor_row: c_int,
    extent_column: c_int,
    extent_row: c_int,
    column: c_int,
    row: c_int,
) callconv(.c) c_int {
    if (selection_active == 0 or selection_pane != pane_index) return 0;
    const first_column = @min(anchor_column, extent_column);
    const last_column = @max(anchor_column, extent_column);
    const first_row = @min(anchor_row, extent_row);
    const last_row = @max(anchor_row, extent_row);
    return @intFromBool(column >= first_column and column <= last_column and
        row >= first_row and row <= last_row);
}

pub export fn noctty_windows_mouse_route(
    state: ?*const MouseState,
    event_kind: c_int,
    button: c_int,
    pane: ?*c_int,
) callconv(.c) c_int {
    const current = state orelse return mouse_route_none;
    const target = pane orelse return mouse_route_none;
    target.* = -1;
    return switch (event_kind) {
        mouse_event_press => mouse_route_hit_test,
        mouse_event_move => if (current.selection_dragging != 0) blk: {
            target.* = current.selection_pane;
            break :blk mouse_route_selection;
        } else if (current.application_capture != 0 and current.pressed_buttons != 0) blk: {
            target.* = current.capture_pane;
            break :blk mouse_route_application;
        } else mouse_route_hit_test,
        mouse_event_release => if (button == 0 and current.selection_dragging != 0) blk: {
            target.* = current.selection_pane;
            break :blk mouse_route_selection;
        } else if (validButton(button) and
            (current.pressed_buttons & buttonMask(button)) != 0)
        blk: {
            target.* = current.capture_pane;
            break :blk mouse_route_application;
        } else mouse_route_none,
        else => mouse_route_none,
    };
}

pub export fn noctty_windows_mouse_transition(
    state: ?*MouseState,
    input: ?*const MouseInput,
    decision: ?*MouseDecision,
) callconv(.c) c_int {
    const current = state orelse return 0;
    const event = input orelse return 0;
    const effect = decision orelse return 0;
    effect.* = emptyMouseDecision();

    switch (event.kind) {
        mouse_event_press => mousePress(current, event, effect),
        mouse_event_release => mouseRelease(current, event, effect),
        mouse_event_move => mouseMove(current, event, effect),
        mouse_event_cancel => cancelMouseCapture(current, effect),
        mouse_event_clear_selection => clearMouseSelection(current, effect),
        else => return 0,
    }
    return 1;
}

fn emptyMouseDecision() MouseDecision {
    return .{
        .capture = mouse_capture_unchanged,
        .invalidate = 0,
        .select_pane = 0,
        .report_buttons = 0,
        .report_kind = mouse_press,
        .report_pane = -1,
        .report_column = 0,
        .report_row = 0,
    };
}

fn validButton(button: c_int) bool {
    return button >= 0 and button < 3;
}

fn buttonMask(button: c_int) u32 {
    return @as(u32, 1) << @intCast(button);
}

fn setStoredRelease(current: *const MouseState, effect: *MouseDecision) void {
    if (current.application_capture == 0 or current.pressed_buttons == 0 or
        current.capture_pane < 0) return;
    effect.report_buttons = current.pressed_buttons & 0x7;
    effect.report_kind = mouse_release;
    effect.report_pane = current.capture_pane;
    effect.report_column = current.capture_last_column;
    effect.report_row = current.capture_last_row;
}

fn resetCaptureState(current: *MouseState) void {
    current.selection_dragging = 0;
    current.application_capture = 0;
    current.pressed_buttons = 0;
    current.capture_pane = -1;
}

fn cancelMouseCapture(current: *MouseState, effect: *MouseDecision) void {
    setStoredRelease(current, effect);
    resetCaptureState(current);
    effect.capture = mouse_capture_release;
}

fn clearMouseSelection(current: *MouseState, effect: *MouseDecision) void {
    if (current.selection_active == 0 and current.selection_dragging == 0) return;
    if (current.selection_dragging != 0) effect.capture = mouse_capture_release;
    current.selection_active = 0;
    current.selection_dragging = 0;
    current.selection_pane = -1;
    effect.invalidate = 1;
}

fn mousePress(current: *MouseState, event: *const MouseInput, effect: *MouseDecision) void {
    if (!validButton(event.button) or event.cell_valid == 0) return;
    effect.invalidate = 1;
    if (event.inside_content == 0) return;

    if (event.button == 0 and (event.shift != 0 or event.tracking_mode == 0)) {
        setStoredRelease(current, effect);
        resetCaptureState(current);
        current.selection_active = 1;
        current.selection_dragging = 1;
        current.selection_pane = event.pane;
        current.selection_anchor_column = event.column;
        current.selection_anchor_row = event.row;
        current.selection_extent_column = event.column;
        current.selection_extent_row = event.row;
        current.capture_pane = event.pane;
        effect.capture = mouse_capture_set;
        return;
    }
    if (event.tracking_mode == 0) return;

    current.pressed_buttons |= buttonMask(event.button);
    current.application_capture = 1;
    current.capture_pane = event.pane;
    current.capture_last_column = event.column;
    current.capture_last_row = event.row;
    effect.capture = mouse_capture_set;
    effect.report_buttons = buttonMask(event.button);
    effect.report_kind = mouse_press;
    effect.report_pane = event.pane;
    effect.report_column = event.column;
    effect.report_row = event.row;
}

fn mouseRelease(current: *MouseState, event: *const MouseInput, effect: *MouseDecision) void {
    if (!validButton(event.button)) return;
    if (event.button == 0 and current.selection_dragging != 0) {
        if (event.cell_valid != 0) {
            current.selection_extent_column = event.column;
            current.selection_extent_row = event.row;
        }
        cancelMouseCapture(current, effect);
        effect.invalidate = 1;
        return;
    }

    const mask = buttonMask(event.button);
    if ((current.pressed_buttons & mask) != 0 and event.cell_valid != 0) {
        effect.report_buttons = mask;
        effect.report_kind = mouse_release;
        effect.report_pane = event.pane;
        effect.report_column = event.column;
        effect.report_row = event.row;
        current.pressed_buttons &= ~mask;
    }
    if (current.pressed_buttons == 0) {
        resetCaptureState(current);
        effect.capture = mouse_capture_release;
    }
}

fn mouseMove(current: *MouseState, event: *const MouseInput, effect: *MouseDecision) void {
    if (current.selection_dragging != 0) {
        if (event.cell_valid != 0 and
            (event.column != current.selection_extent_column or
                event.row != current.selection_extent_row))
        {
            current.selection_extent_column = event.column;
            current.selection_extent_row = event.row;
            effect.invalidate = 1;
        }
        return;
    }
    if (current.application_capture != 0 and current.pressed_buttons != 0) {
        if (event.cell_valid == 0 or
            (event.column == current.capture_last_column and
                event.row == current.capture_last_row)) return;
        current.capture_last_column = event.column;
        current.capture_last_row = event.row;
        effect.report_buttons = buttonMask(firstPressedButton(current.pressed_buttons));
        effect.report_kind = mouse_motion;
        effect.report_pane = event.pane;
        effect.report_column = event.column;
        effect.report_row = event.row;
        return;
    }
    if (event.cell_valid != 0 and event.inside_content != 0 and
        event.tracking_mode == 3)
    {
        effect.select_pane = 1;
        effect.report_buttons = buttonMask(3);
        effect.report_kind = mouse_motion;
        effect.report_pane = event.pane;
        effect.report_column = event.column;
        effect.report_row = event.row;
    }
}

fn firstPressedButton(mask: u32) c_int {
    if ((mask & 1) != 0) return 0;
    if ((mask & 2) != 0) return 1;
    return 2;
}

pub export fn noctty_windows_special_key_sequence(
    key: usize,
    application_cursor: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) usize {
    const terminal_key = terminalKey(key) orelse return 0;
    return KeyEncoding.encode(
        terminal_key,
        .{ .application_cursor = application_cursor != 0 },
        output[0..capacity],
    );
}

fn terminalKey(key: usize) ?KeyEncoding.Key {
    return switch (key) {
        0x26 => .up,
        0x28 => .down,
        0x27 => .right,
        0x25 => .left,
        0x24 => .home,
        0x23 => .end,
        0x21 => .page_up,
        0x22 => .page_down,
        0x2d => .insert,
        0x2e => .delete,
        0x70 => .f1,
        0x71 => .f2,
        0x72 => .f3,
        0x73 => .f4,
        0x74 => .f5,
        0x75 => .f6,
        0x76 => .f7,
        0x77 => .f8,
        0x78 => .f9,
        0x79 => .f10,
        0x7a => .f11,
        0x7b => .f12,
        else => null,
    };
}

test "RGB blending and COLORREF conversion retain channel order" {
    try std.testing.expectEqual(@as(u32, 0x7f7f7f), blend(0xffffff, 0x000000, 127));
    try std.testing.expectEqual(@as(u32, 0x332211), noctty_windows_rgb_from_colorref(0x112233));
    try std.testing.expectEqual(@as(u32, 0x112233), noctty_windows_colorref_from_rgb(0x332211));
}

test "pane geometry and pointer mapping are bounded" {
    var geometry: PaneGeometry = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_compute_pane_geometry(
        0,
        0,
        1000,
        800,
        500_000,
        0,
        500_000,
        1_000_000,
        3,
        &geometry,
    ));
    try std.testing.expectEqual(@as(c_int, 500), geometry.pane_left);
    try std.testing.expectEqual(@as(c_int, 997), geometry.content_right);
    var column: c_int = -1;
    var row: c_int = -1;
    var inside: c_int = 0;
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_pointer_cell(
        geometry.content_left,
        geometry.content_top,
        geometry.content_right,
        geometry.content_bottom,
        10,
        8,
        geometry.content_right - 1,
        geometry.content_bottom - 1,
        0,
        &column,
        &row,
        &inside,
    ));
    try std.testing.expectEqual(@as(c_int, 9), column);
    try std.testing.expectEqual(@as(c_int, 7), row);
    try std.testing.expectEqual(@as(c_int, 1), inside);
}

test "grid sizing and UTF-16 input stay bounded" {
    var columns: c_int = 0;
    var rows: c_int = 0;
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_grid_dimensions(
        900,
        360,
        9,
        18,
        &columns,
        &rows,
    ));
    try std.testing.expectEqual(@as(c_int, 100), columns);
    try std.testing.expectEqual(@as(c_int, 20), rows);
    var pending: u16 = 0;
    var bytes: [8]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 0), noctty_windows_encode_utf16_input(
        0xd83d,
        &pending,
        &bytes,
        bytes.len,
    ));
    const count = noctty_windows_encode_utf16_input(0xde00, &pending, &bytes, bytes.len);
    try std.testing.expectEqualStrings("😀", bytes[0..count]);
    try std.testing.expectEqual(@as(u16, 0), pending);
}

test "Windows key commands preserve local and remote policy" {
    var suppress: c_int = 0;
    try std.testing.expectEqual(key_action_new_tab, noctty_windows_decode_key_action(
        'T',
        1,
        1,
        0,
        0,
        &suppress,
    ));
    try std.testing.expectEqual(@as(c_int, 1), suppress);
    try std.testing.expectEqual(key_action_default, noctty_windows_decode_key_action(
        'T',
        1,
        1,
        0,
        1,
        &suppress,
    ));
    try std.testing.expectEqual(@as(c_int, 0), suppress);
    try std.testing.expectEqual(key_action_paste, noctty_windows_decode_key_action(
        0x2d,
        0,
        1,
        0,
        0,
        &suppress,
    ));
    try std.testing.expectEqual(@as(c_int, 0), suppress);
    try std.testing.expectEqual(key_action_special, noctty_windows_decode_key_action(
        0x70,
        0,
        0,
        0,
        0,
        &suppress,
    ));
}

test "Ctrl Tab cycles locally and remotely with or without Shift" {
    for ([_]c_int{ 0, 1 }) |remote_mode| {
        for ([_]c_int{ 0, 1 }) |shift| {
            var suppress: c_int = 0;
            try std.testing.expectEqual(key_action_cycle, noctty_windows_decode_key_action(
                0x09,
                1,
                shift,
                0,
                remote_mode,
                &suppress,
            ));
            try std.testing.expectEqual(@as(c_int, 1), suppress);
            try std.testing.expectEqual(key_action_default, noctty_windows_decode_key_action(
                0x09,
                0,
                shift,
                0,
                remote_mode,
                &suppress,
            ));
            try std.testing.expectEqual(@as(c_int, 0), suppress);
        }
    }
}

test "Windows menu commands decode to bounded actions" {
    var action: MenuAction = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_decode_menu_command(
        menu_font_16,
        0,
        &action,
    ));
    try std.testing.expectEqual(@as(c_int, 2), action.kind);
    try std.testing.expectEqual(@as(c_int, 16), action.value);
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_decode_menu_command(
        menu_restore_startup,
        1,
        &action,
    ));
    try std.testing.expectEqual(@as(c_int, 4), action.kind);
    try std.testing.expectEqual(@as(c_int, 0), action.value);
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_decode_menu_command(
        999,
        0,
        &action,
    ));
}

test "Windows appearance: Zinc menu action and host-owned font commands" {
    var action: MenuAction = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_decode_menu_command(menu_theme_zinc, 0, &action));
    try std.testing.expectEqualDeep(MenuAction{ .kind = 1, .value = 2 }, action);
    const previous = action;
    for ([_]u32{ menu_font_custom, menu_font_increase, menu_font_decrease, menu_font_reset }) |command| {
        try std.testing.expectEqual(@as(c_int, 0), noctty_windows_decode_menu_command(command, 0, &action));
        try std.testing.expectEqualDeep(previous, action);
    }
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_decode_menu_command(menu_theme_zinc, 0, null));
}

test "Windows preferences normalize invalid persisted values" {
    var preferences: Preferences = undefined;
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_normalize_preferences(
        7,
        100,
        -1,
        7,
        &preferences,
    ));
    try std.testing.expectEqual(@as(c_int, 0), preferences.theme);
    try std.testing.expectEqual(@as(c_int, 13), preferences.font_size_pt);
    try std.testing.expectEqual(@as(c_int, 0), preferences.launch_profile);
    try std.testing.expectEqual(@as(c_int, 1), preferences.restore_workspace);
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_normalize_preferences(
        1,
        16,
        1,
        0,
        &preferences,
    ));
}

test "Windows appearance: preferences preserve exact font bounds and theme selection" {
    var preferences: Preferences = undefined;
    for ([_]c_int{ 0, 1, 2, 3 }) |theme| {
        for (8..33) |size| {
            try std.testing.expectEqual(@as(c_int, 1), noctty_windows_normalize_preferences(
                theme,
                @intCast(size),
                1,
                0,
                &preferences,
            ));
            try std.testing.expectEqualDeep(Preferences{
                .theme = theme,
                .font_size_pt = @intCast(size),
                .launch_profile = 1,
                .restore_workspace = 0,
            }, preferences);
        }
    }
    for ([_]c_int{ std.math.minInt(c_int), 7, 33, std.math.maxInt(c_int) }) |size| {
        try std.testing.expectEqual(@as(c_int, 0), noctty_windows_normalize_preferences(2, size, 1, 0, &preferences));
        try std.testing.expectEqualDeep(Preferences{
            .theme = 2,
            .font_size_pt = 13,
            .launch_profile = 1,
            .restore_workspace = 0,
        }, preferences);
    }
    for ([_]c_int{ -1, 4 }) |theme| {
        try std.testing.expectEqual(@as(c_int, 0), noctty_windows_normalize_preferences(theme, 32, 0, 1, &preferences));
        try std.testing.expectEqualDeep(Preferences{
            .theme = 0,
            .font_size_pt = 32,
            .launch_profile = 0,
            .restore_workspace = 1,
        }, preferences);
    }
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_normalize_preferences(2, 8, 0, 0, null));
}

test "selection and special keys preserve Win32 host policy" {
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_cell_selected(
        1,
        2,
        2,
        4,
        3,
        1,
        1,
        1,
        1,
    ));
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_cell_selected(
        1,
        2,
        2,
        4,
        3,
        1,
        1,
        0,
        0,
    ));
    var bytes: [16]u8 = undefined;
    const count = noctty_windows_special_key_sequence(0x26, 1, &bytes, bytes.len);
    try std.testing.expectEqualStrings("\x1bOA", bytes[0..count]);
}

test "Windows key adapter preserves cursor mode and atomic capacity failures" {
    var bytes = [_]u8{0xa5} ** 8;
    var count = noctty_windows_special_key_sequence(0x25, 0, &bytes, bytes.len);
    try std.testing.expectEqualStrings("\x1b[D", bytes[0..count]);
    count = noctty_windows_special_key_sequence(0x25, -1, &bytes, bytes.len);
    try std.testing.expectEqualStrings("\x1bOD", bytes[0..count]);
    count = noctty_windows_special_key_sequence(0x24, 1, &bytes, bytes.len);
    try std.testing.expectEqualStrings("\x1b[H", bytes[0..count]);
    bytes = [_]u8{0xa5} ** 8;
    try std.testing.expectEqual(@as(usize, 0), noctty_windows_special_key_sequence(0x7b, 0, &bytes, 4));
    try std.testing.expectEqual(@as(usize, 0), noctty_windows_special_key_sequence(0x0d, 0, &bytes, bytes.len));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &bytes);
    count = noctty_windows_special_key_sequence(0x7b, 0, &bytes, 5);
    try std.testing.expectEqualStrings("\x1b[24~", bytes[0..count]);
    try std.testing.expectEqual(@as(u8, 0xa5), bytes[5]);
}

fn testMouseState() MouseState {
    return .{
        .selection_active = 0,
        .selection_dragging = 0,
        .selection_pane = -1,
        .selection_anchor_column = 0,
        .selection_anchor_row = 0,
        .selection_extent_column = 0,
        .selection_extent_row = 0,
        .pressed_buttons = 0,
        .application_capture = 0,
        .capture_pane = -1,
        .capture_last_column = 0,
        .capture_last_row = 0,
    };
}

fn testMouseInput(kind: c_int) MouseInput {
    return .{
        .kind = kind,
        .button = 0,
        .shift = 0,
        .tracking_mode = 0,
        .cell_valid = 1,
        .inside_content = 1,
        .pane = 2,
        .column = 4,
        .row = 3,
    };
}

test "mouse routing follows selection and application capture priority" {
    var state = testMouseState();
    var pane: c_int = 99;
    try std.testing.expectEqual(mouse_route_hit_test, noctty_windows_mouse_route(
        &state,
        mouse_event_press,
        0,
        &pane,
    ));
    try std.testing.expectEqual(@as(c_int, -1), pane);
    try std.testing.expectEqual(mouse_route_hit_test, noctty_windows_mouse_route(
        &state,
        mouse_event_move,
        0,
        &pane,
    ));

    state.selection_dragging = 1;
    state.selection_pane = 4;
    try std.testing.expectEqual(mouse_route_selection, noctty_windows_mouse_route(
        &state,
        mouse_event_move,
        0,
        &pane,
    ));
    try std.testing.expectEqual(@as(c_int, 4), pane);
    try std.testing.expectEqual(mouse_route_selection, noctty_windows_mouse_route(
        &state,
        mouse_event_release,
        0,
        &pane,
    ));

    state.selection_dragging = 0;
    state.application_capture = 1;
    state.pressed_buttons = 0b110;
    state.capture_pane = 7;
    try std.testing.expectEqual(mouse_route_application, noctty_windows_mouse_route(
        &state,
        mouse_event_move,
        0,
        &pane,
    ));
    try std.testing.expectEqual(@as(c_int, 7), pane);
    try std.testing.expectEqual(mouse_route_application, noctty_windows_mouse_route(
        &state,
        mouse_event_release,
        1,
        &pane,
    ));
    try std.testing.expectEqual(mouse_route_none, noctty_windows_mouse_route(
        &state,
        mouse_event_release,
        0,
        &pane,
    ));
    try std.testing.expectEqual(mouse_route_none, noctty_windows_mouse_route(
        &state,
        mouse_event_release,
        -1,
        &pane,
    ));
}

test "mouse press preserves local selection escape and application priority" {
    var state = testMouseState();
    var decision: MouseDecision = undefined;
    var press = testMouseInput(mouse_event_press);

    press.inside_content = 0;
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_mouse_transition(
        &state,
        &press,
        &decision,
    ));
    try std.testing.expectEqual(@as(c_int, 1), decision.invalidate);
    try std.testing.expectEqual(@as(u32, 0), decision.report_buttons);

    press.inside_content = 1;
    press.tracking_mode = 2;
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_mouse_transition(
        &state,
        &press,
        &decision,
    ));
    try std.testing.expectEqual(@as(c_int, 1), state.application_capture);
    try std.testing.expectEqual(@as(u32, 1), state.pressed_buttons);
    try std.testing.expectEqual(mouse_capture_set, decision.capture);
    try std.testing.expectEqual(mouse_press, decision.report_kind);

    press.shift = 1;
    press.column = 6;
    press.row = 5;
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_mouse_transition(
        &state,
        &press,
        &decision,
    ));
    try std.testing.expectEqual(@as(c_int, 1), state.selection_active);
    try std.testing.expectEqual(@as(c_int, 1), state.selection_dragging);
    try std.testing.expectEqual(@as(c_int, 6), state.selection_anchor_column);
    try std.testing.expectEqual(@as(c_int, 5), state.selection_extent_row);
    try std.testing.expectEqual(@as(u32, 1), decision.report_buttons);
    try std.testing.expectEqual(mouse_release, decision.report_kind);
    try std.testing.expectEqual(mouse_capture_set, decision.capture);

    var clear = testMouseInput(mouse_event_clear_selection);
    _ = noctty_windows_mouse_transition(&state, &clear, &decision);
    try std.testing.expectEqual(@as(c_int, 0), state.selection_active);
    try std.testing.expectEqual(@as(c_int, -1), state.selection_pane);
    try std.testing.expectEqual(mouse_capture_release, decision.capture);

    press = testMouseInput(mouse_event_press);
    press.tracking_mode = 0;
    _ = noctty_windows_mouse_transition(&state, &press, &decision);
    try std.testing.expectEqual(@as(c_int, 1), state.selection_dragging);

    state = testMouseState();
    press.button = 2;
    _ = noctty_windows_mouse_transition(&state, &press, &decision);
    try std.testing.expectEqual(@as(u32, 0), state.pressed_buttons);
    try std.testing.expectEqual(mouse_capture_unchanged, decision.capture);
}

test "application mouse transitions preserve masks motion and release boundaries" {
    var state = testMouseState();
    var decision: MouseDecision = undefined;
    var press = testMouseInput(mouse_event_press);
    press.tracking_mode = 1;
    press.button = 1;
    _ = noctty_windows_mouse_transition(&state, &press, &decision);
    press.button = 0;
    press.column = 5;
    _ = noctty_windows_mouse_transition(&state, &press, &decision);
    try std.testing.expectEqual(@as(u32, 0b11), state.pressed_buttons);

    var move = testMouseInput(mouse_event_move);
    move.column = 5;
    _ = noctty_windows_mouse_transition(&state, &move, &decision);
    try std.testing.expectEqual(@as(u32, 0), decision.report_buttons);
    move.column = -9;
    move.row = 99;
    _ = noctty_windows_mouse_transition(&state, &move, &decision);
    try std.testing.expectEqual(@as(u32, 1), decision.report_buttons);
    try std.testing.expectEqual(mouse_motion, decision.report_kind);
    try std.testing.expectEqual(@as(c_int, -9), state.capture_last_column);
    try std.testing.expectEqual(@as(c_int, 99), state.capture_last_row);

    var release = testMouseInput(mouse_event_release);
    release.button = 1;
    _ = noctty_windows_mouse_transition(&state, &release, &decision);
    try std.testing.expectEqual(@as(u32, 1), state.pressed_buttons);
    try std.testing.expectEqual(mouse_capture_unchanged, decision.capture);
    try std.testing.expectEqual(@as(u32, 2), decision.report_buttons);

    release.button = 0;
    release.cell_valid = 0;
    _ = noctty_windows_mouse_transition(&state, &release, &decision);
    try std.testing.expectEqual(@as(u32, 1), state.pressed_buttons);
    try std.testing.expectEqual(mouse_capture_unchanged, decision.capture);
    release.cell_valid = 1;
    _ = noctty_windows_mouse_transition(&state, &release, &decision);
    try std.testing.expectEqual(@as(u32, 0), state.pressed_buttons);
    try std.testing.expectEqual(@as(c_int, 0), state.application_capture);
    try std.testing.expectEqual(mouse_capture_release, decision.capture);
}

test "selection drag and hover motion preserve coordinate transitions" {
    var state = testMouseState();
    var decision: MouseDecision = undefined;
    var press = testMouseInput(mouse_event_press);
    _ = noctty_windows_mouse_transition(&state, &press, &decision);

    var move = testMouseInput(mouse_event_move);
    _ = noctty_windows_mouse_transition(&state, &move, &decision);
    try std.testing.expectEqual(@as(c_int, 0), decision.invalidate);
    move.column = 0;
    move.row = 35;
    _ = noctty_windows_mouse_transition(&state, &move, &decision);
    try std.testing.expectEqual(@as(c_int, 1), decision.invalidate);
    try std.testing.expectEqual(@as(c_int, 35), state.selection_extent_row);

    var release = testMouseInput(mouse_event_release);
    release.column = 119;
    release.row = 0;
    _ = noctty_windows_mouse_transition(&state, &release, &decision);
    try std.testing.expectEqual(@as(c_int, 0), state.selection_dragging);
    try std.testing.expectEqual(@as(c_int, 1), state.selection_active);
    try std.testing.expectEqual(@as(c_int, 119), state.selection_extent_column);
    try std.testing.expectEqual(mouse_capture_release, decision.capture);

    state = testMouseState();
    move = testMouseInput(mouse_event_move);
    move.tracking_mode = 2;
    _ = noctty_windows_mouse_transition(&state, &move, &decision);
    try std.testing.expectEqual(@as(u32, 0), decision.report_buttons);
    move.tracking_mode = 3;
    _ = noctty_windows_mouse_transition(&state, &move, &decision);
    try std.testing.expectEqual(@as(c_int, 1), decision.select_pane);
    try std.testing.expectEqual(@as(u32, 0b1000), decision.report_buttons);
    try std.testing.expectEqual(mouse_motion, decision.report_kind);
}

test "capture cancellation reports every button and clears only drag state" {
    var state = testMouseState();
    state.selection_active = 1;
    state.selection_dragging = 1;
    state.selection_pane = 2;
    state.application_capture = 1;
    state.pressed_buttons = 0b101;
    state.capture_pane = 3;
    state.capture_last_column = 8;
    state.capture_last_row = 9;
    var decision: MouseDecision = undefined;
    const cancel = testMouseInput(mouse_event_cancel);
    _ = noctty_windows_mouse_transition(&state, &cancel, &decision);
    try std.testing.expectEqual(@as(u32, 0b101), decision.report_buttons);
    try std.testing.expectEqual(mouse_release, decision.report_kind);
    try std.testing.expectEqual(@as(c_int, 3), decision.report_pane);
    try std.testing.expectEqual(@as(c_int, 8), decision.report_column);
    try std.testing.expectEqual(@as(c_int, 9), decision.report_row);
    try std.testing.expectEqual(mouse_capture_release, decision.capture);
    try std.testing.expectEqual(@as(c_int, 1), state.selection_active);
    try std.testing.expectEqual(@as(c_int, 0), state.selection_dragging);
    try std.testing.expectEqual(@as(u32, 0), state.pressed_buttons);

    var clear = testMouseInput(mouse_event_clear_selection);
    _ = noctty_windows_mouse_transition(&state, &clear, &decision);
    try std.testing.expectEqual(@as(c_int, 0), state.selection_active);
    try std.testing.expectEqual(@as(c_int, 1), decision.invalidate);
    try std.testing.expectEqual(mouse_capture_unchanged, decision.capture);

    _ = noctty_windows_mouse_transition(&state, &clear, &decision);
    try std.testing.expectEqual(@as(c_int, 0), decision.invalidate);
}

test "workspace session plans exhaustively enforce index and dimension bounds" {
    var state = WorkspaceState{ .live_sessions = 0, .pending_close = 0 };
    var plan: SessionPlan = undefined;
    var index: c_int = -2;
    while (index <= workspace_max_sessions + 1) : (index += 1) {
        const expected = if (index >= 0 and index < workspace_max_sessions)
            session_start_create
        else
            session_start_reject;
        try std.testing.expectEqual(expected, noctty_windows_session_start_plan(
            &state,
            index,
            1,
            120,
            36,
            &plan,
        ));
        if (expected == session_start_create) {
            try std.testing.expectEqual(@as(c_int, 1), noctty_windows_session_started(
                &state,
                index,
            ));
            try std.testing.expectEqual(@as(c_int, 1), noctty_windows_session_is_live(
                &state,
                index,
            ));
            try std.testing.expectEqual(session_start_existing, noctty_windows_session_start_plan(
                &state,
                index,
                1,
                120,
                36,
                &plan,
            ));
        } else {
            try std.testing.expectEqual(@as(c_int, 0), noctty_windows_session_is_live(
                &state,
                index,
            ));
        }
    }
    try std.testing.expectEqual(session_start_reject, noctty_windows_session_start_plan(
        &state,
        0,
        0,
        120,
        36,
        &plan,
    ));
    try std.testing.expectEqual(session_start_reject, noctty_windows_session_start_plan(
        &state,
        0,
        1,
        0,
        36,
        &plan,
    ));
    try std.testing.expectEqual(session_start_reject, noctty_windows_session_start_plan(
        &state,
        0,
        1,
        120,
        0,
        &plan,
    ));
}

test "workspace startup resize and action planning preserve all bounds" {
    var state = WorkspaceState{ .live_sessions = 0, .pending_close = 0 };
    var session_count: c_int = -1;
    var count: c_int = -2;
    while (count <= workspace_max_sessions + 2) : (count += 1) {
        const expected = if (count >= 1 and count <= workspace_max_sessions)
            workspace_startup_local
        else
            workspace_startup_reject;
        try std.testing.expectEqual(expected, noctty_windows_workspace_startup_plan(
            &state,
            0,
            count,
            &session_count,
        ));
        try std.testing.expectEqual(
            if (expected == workspace_startup_local) count else @as(c_int, 0),
            session_count,
        );
        try std.testing.expectEqual(
            if (count <= 0) @as(c_int, 0) else @min(count, workspace_max_sessions),
            noctty_windows_workspace_resize_count(0, count),
        );
    }
    try std.testing.expectEqual(workspace_startup_remote, noctty_windows_workspace_startup_plan(
        &state,
        1,
        100,
        &session_count,
    ));
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_workspace_resize_count(1, 32));

    var index: c_int = -1;
    var result: c_int = 1;
    while (result <= workspace_max_sessions) : (result += 1) {
        try std.testing.expectEqual(workspace_action_start, noctty_windows_workspace_action_result(
            0,
            result,
            &index,
        ));
        try std.testing.expectEqual(result - 1, index);
    }
    try std.testing.expectEqual(workspace_action_none, noctty_windows_workspace_action_result(
        0,
        0,
        &index,
    ));
    try std.testing.expectEqual(workspace_action_none, noctty_windows_workspace_action_result(
        1,
        1,
        &index,
    ));
    try std.testing.expectEqual(workspace_action_rollback, noctty_windows_workspace_action_result(
        0,
        workspace_max_sessions + 1,
        &index,
    ));
    try std.testing.expectEqual(@as(c_int, -1), index);

    state.live_sessions = 1;
    var resize: SessionPlan = undefined;
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_session_resize_plan(
        &state,
        0,
        1000,
        500,
        &resize,
    ));
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_session_resize_plan(
        &state,
        0,
        1001,
        500,
        &resize,
    ));
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_session_resize_plan(
        &state,
        workspace_max_sessions,
        80,
        24,
        &resize,
    ));
}

test "workspace close masks are exhaustively bounded and commits must match" {
    var session_count: c_int = 1;
    while (session_count <= workspace_max_sessions) : (session_count += 1) {
        var bit_index: c_int = 0;
        while (bit_index < workspace_max_sessions) : (bit_index += 1) {
            var state = WorkspaceState{
                .live_sessions = std.math.maxInt(u32),
                .pending_close = 0,
            };
            const mask = sessionBit(bit_index).?;
            var cleanup: u32 = 99;
            const expected = if (bit_index < session_count)
                workspace_close_cleanup
            else
                workspace_close_shutdown;
            try std.testing.expectEqual(expected, noctty_windows_workspace_close_plan(
                &state,
                0,
                session_count,
                mask,
                &cleanup,
            ));
            if (expected == workspace_close_cleanup) {
                try std.testing.expectEqual(mask, cleanup);
                try std.testing.expectEqual(@as(c_int, 1), noctty_windows_workspace_close_commit(
                    &state,
                    mask,
                ));
                try std.testing.expectEqual(@as(u32, 0), state.live_sessions & mask);
            } else {
                try std.testing.expectEqual(@as(u32, 0), cleanup);
            }
        }
    }

    var state = WorkspaceState{
        .live_sessions = std.math.maxInt(u32),
        .pending_close = 0,
    };
    var cleanup: u32 = 99;
    try std.testing.expectEqual(workspace_close_none, noctty_windows_workspace_close_plan(
        &state,
        0,
        workspace_max_sessions,
        0,
        &cleanup,
    ));
    try std.testing.expectEqual(workspace_close_shutdown, noctty_windows_workspace_close_plan(
        &state,
        0,
        0,
        1,
        &cleanup,
    ));
    try std.testing.expectEqual(workspace_close_shutdown, noctty_windows_workspace_close_plan(
        &state,
        0,
        workspace_max_sessions + 1,
        1,
        &cleanup,
    ));

    var committed: u32 = 0;
    while (committed < 16) : (committed += 1) {
        state = .{ .live_sessions = 0b1111, .pending_close = 0 };
        try std.testing.expectEqual(workspace_close_cleanup, noctty_windows_workspace_close_plan(
            &state,
            0,
            4,
            0b0101,
            &cleanup,
        ));
        try std.testing.expectEqual(
            @as(c_int, @intFromBool(committed == 0b0101)),
            noctty_windows_workspace_close_commit(&state, committed),
        );
        if (committed == 0b0101)
            try std.testing.expectEqual(@as(u32, 0b1010), state.live_sessions)
        else
            try std.testing.expectEqual(@as(u32, 0b1111), state.live_sessions);
    }
}

test "partial startup cleanup and action rollback decisions remain atomic" {
    var state = WorkspaceState{ .live_sessions = 0, .pending_close = 0 };
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_session_started(&state, 0));
    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_session_started(&state, 2));
    var cleanup: u32 = 0;
    try std.testing.expectEqual(session_failure_cleanup, noctty_windows_session_start_failed(
        &state,
        3,
        1,
        &cleanup,
    ));
    try std.testing.expectEqual(@as(u32, 0b0101), cleanup);
    try std.testing.expectEqual(@as(u32, 0), state.live_sessions);

    try std.testing.expectEqual(@as(c_int, 1), noctty_windows_session_started(&state, 7));
    try std.testing.expectEqual(session_failure_rollback, noctty_windows_session_start_failed(
        &state,
        8,
        0,
        &cleanup,
    ));
    try std.testing.expectEqual(@as(u32, 0), cleanup);
    try std.testing.expectEqual(sessionBit(7).?, state.live_sessions);

    var index: c_int = 0;
    while (index < workspace_max_sessions) : (index += 1) {
        const expected = sessionBit(index).?;
        try std.testing.expectEqual(@as(c_int, 1), noctty_windows_workspace_rollback_matches(
            index,
            expected,
        ));
        try std.testing.expectEqual(@as(c_int, 0), noctty_windows_workspace_rollback_matches(
            index,
            expected ^ 1,
        ));
    }
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_workspace_rollback_matches(
        -1,
        0,
    ));
    try std.testing.expectEqual(@as(c_int, 0), noctty_windows_workspace_rollback_matches(
        workspace_max_sessions,
        0,
    ));
}
