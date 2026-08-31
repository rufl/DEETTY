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

pub const Preferences = extern struct {
    theme: c_int,
    font_size_pt: c_int,
    launch_profile: c_int,
    restore_workspace: c_int,
};

pub const menu_theme_dark: u32 = 40001;
pub const menu_theme_high_contrast: u32 = 40002;
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

pub const MenuAction = extern struct {
    kind: c_int,
    value: c_int,
};

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
    if (control != 0 and key == 0x09) { // VK_TAB.
        suppress.* = 1;
        return key_action_cycle;
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
    const valid = (theme == 0 or theme == 1) and
        (font_size_pt >= 10 and font_size_pt <= 24) and
        (launch_profile == 0 or launch_profile == 1) and
        (restore_workspace == 0 or restore_workspace == 1);
    result.* = .{
        .theme = @intFromBool(theme == 1),
        .font_size_pt = if (font_size_pt >= 10 and font_size_pt <= 24) font_size_pt else 13,
        .launch_profile = @intFromBool(launch_profile == 1),
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
