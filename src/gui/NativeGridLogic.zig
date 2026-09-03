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

pub export fn noctty_grid_input_route(
    input_kind: c_int,
    scrollbar_owned: c_int,
    terminal_mouse_mode: c_int,
    primary_button: c_int,
    modifier_flags: u32,
) callconv(.c) c_int {
    if (input_kind != input_pointer and input_kind != input_wheel)
        return route_ignore;
    if (scrollbar_owned != 0) return route_scrollbar;

    if (input_kind == input_pointer) {
        if (terminal_mouse_mode != 0) return route_application_mouse;
        return if (primary_button != 0) route_selection else route_local_pointer;
    }

    const modifiers = modifier_flags & known_modifiers;
    if (terminal_mouse_mode != 0 and modifiers == 0)
        return route_application_mouse;
    if (modifiers & modifier_control != 0 and modifiers & modifier_alt != 0)
        return route_tab_cycle;
    if (modifiers & modifier_alt != 0)
        return route_pane_cycle;
    if (modifiers & modifier_control != 0)
        return route_font_zoom;
    if (terminal_mouse_mode == 0 or modifiers & modifier_shift != 0)
        return route_terminal_scroll;
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
            noctty_grid_input_route(input_wheel, 0, 0, 0, flags),
        );
        try std.testing.expectEqual(
            expected_with_mouse[modifiers],
            noctty_grid_input_route(input_wheel, 0, 1, 0, flags),
        );
    }
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
                    @intCast(modifiers),
                ),
            );
        }
    }
    try std.testing.expectEqual(
        route_application_mouse,
        noctty_grid_input_route(input_wheel, 0, -1, 0, 1 << 31),
    );
    try std.testing.expectEqual(
        route_ignore,
        noctty_grid_input_route(std.math.maxInt(c_int), 1, 1, 1, std.math.maxInt(u32)),
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
