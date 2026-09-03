//! Pure close coordination, geometry, selection, and input policy for GTK.

const std = @import("std");

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

pub const Rectangle = extern struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};
pub const WheelActionPlan = extern struct {
    steps: c_int,
    direction: c_int,
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
    const introducer: u8 = if (application_cursor != 0) 'O' else '[';
    const final: u8 = if (steps > 0) 'A' else 'B';
    for (0..count) |index| {
        const start = index * 3;
        destination[start..][0..3].* = .{ 0x1b, introducer, final };
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

fn terminalSpecialKeySequence(keyval: u32, application_cursor: bool) ?[]const u8 {
    return switch (keyval) {
        gdk_key_up => if (application_cursor) "\x1bOA" else "\x1b[A",
        gdk_key_down => if (application_cursor) "\x1bOB" else "\x1b[B",
        gdk_key_right => if (application_cursor) "\x1bOC" else "\x1b[C",
        gdk_key_left => if (application_cursor) "\x1bOD" else "\x1b[D",
        gdk_key_home => "\x1b[H",
        gdk_key_end => "\x1b[F",
        gdk_key_insert => "\x1b[2~",
        gdk_key_delete => "\x1b[3~",
        gdk_key_page_up => "\x1b[5~",
        gdk_key_page_down => "\x1b[6~",
        gdk_key_f1 => "\x1bOP",
        gdk_key_f1 + 1 => "\x1bOQ",
        gdk_key_f1 + 2 => "\x1bOR",
        gdk_key_f1 + 3 => "\x1bOS",
        gdk_key_f1 + 4 => "\x1b[15~",
        gdk_key_f1 + 5 => "\x1b[17~",
        gdk_key_f1 + 6 => "\x1b[18~",
        gdk_key_f1 + 7 => "\x1b[19~",
        gdk_key_f1 + 8 => "\x1b[20~",
        gdk_key_f1 + 9 => "\x1b[21~",
        gdk_key_f1 + 10 => "\x1b[23~",
        gdk_key_f12 => "\x1b[24~",
        gdk_key_return, gdk_key_kp_enter => "\r",
        gdk_key_backspace => "\x7f",
        gdk_key_tab => "\t",
        gdk_key_escape => "\x1b",
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
        sequence = terminalSpecialKeySequence(
            keyval,
            application_cursor != 0,
        ) orelse return 0;
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

pub export fn noctty_grid_hyperlink_valid(
    uri_pointer: ?[*]const u8,
    length: u32,
) callconv(.c) c_int {
    const pointer = uri_pointer orelse return 0;
    if (length == 0 or length > 2048) return 0;
    const uri = pointer[0..length];
    if (!std.unicode.utf8ValidateSlice(uri)) return 0;
    for (uri) |byte| {
        if (byte < 0x20 or byte == 0x7f) return 0;
    }
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
    const status_role: u32 = switch (status_kind) {
        1 => 12,
        2 => 13,
        4 => 14,
        else => if (status_kind == 0) 0 else 15,
    };
    const status_fallback: u32 = switch (status_kind) {
        1 => 0x408cf2,
        2 => 0x40cc66,
        4 => 0xf5b82e,
        else => if (status_kind == 0) 0 else 0xe64040,
    };
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
        .status_role = status_role,
        .status_fallback = status_fallback,
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
        const width_fit = @as(f64, @floatFromInt(fit_width)) / (80 * (96.0 / 72.0) * 0.64);
        const height_fit = @as(f64, @floatFromInt(fit_height)) / (24 * (96.0 / 72.0) * 1.28);
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

test "linear selection is direction independent" {
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_cell_selected(1, 4, 3, 1, 1, 1, 1));
    try std.testing.expectEqual(@as(c_int, 1), noctty_grid_cell_selected(1, 4, 3, 1, 1, 9, 2));
    try std.testing.expectEqual(@as(c_int, 0), noctty_grid_cell_selected(1, 4, 3, 1, 1, 0, 1));
}

test "cell spans preserve seamless pixel bounds" {
    var rectangle: Rectangle = undefined;
    noctty_grid_cell_span(1, 3, 2, 9.5, 18.25, 1, &rectangle);
    try std.testing.expectEqual(@as(f64, 13), rectangle.x);
    try std.testing.expectEqual(@as(f64, 20), rectangle.width);
    try std.testing.expectEqual(@as(f64, 38), rectangle.y);
    try std.testing.expectEqual(@as(f64, 19), rectangle.height);
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
