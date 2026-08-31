//! Pure, tested policy extracted from the Win32/GDI terminal adapter.
//!
//! The C host temporarily consumes these exports while HWND, ConPTY, and GDI
//! ownership migrates independently. No Windows handles cross this boundary.

const std = @import("std");

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

pub export fn noctty_windows_special_key_sequence(
    key: usize,
    application_cursor: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) usize {
    const sequence = specialKeySequence(key, application_cursor != 0) orelse return 0;
    if (sequence.len > capacity) return 0;
    @memcpy(output[0..sequence.len], sequence);
    return sequence.len;
}

fn specialKeySequence(key: usize, application_cursor: bool) ?[]const u8 {
    return switch (key) {
        0x26 => if (application_cursor) "\x1bOA" else "\x1b[A",
        0x28 => if (application_cursor) "\x1bOB" else "\x1b[B",
        0x27 => if (application_cursor) "\x1bOC" else "\x1b[C",
        0x25 => if (application_cursor) "\x1bOD" else "\x1b[D",
        0x24 => "\x1b[H",
        0x23 => "\x1b[F",
        0x21 => "\x1b[5~",
        0x22 => "\x1b[6~",
        0x2d => "\x1b[2~",
        0x2e => "\x1b[3~",
        0x70 => "\x1bOP",
        0x71 => "\x1bOQ",
        0x72 => "\x1bOR",
        0x73 => "\x1bOS",
        0x74 => "\x1b[15~",
        0x75 => "\x1b[17~",
        0x76 => "\x1b[18~",
        0x77 => "\x1b[19~",
        0x78 => "\x1b[20~",
        0x79 => "\x1b[21~",
        0x7a => "\x1b[23~",
        0x7b => "\x1b[24~",
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
