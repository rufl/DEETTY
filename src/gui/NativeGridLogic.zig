//! Pure geometry and selection policy extracted from the GTK grid adapter.

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
