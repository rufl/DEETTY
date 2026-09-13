//! Win32/GDI terminal renderer behind a state-only C ABI.
//!
//! The HWND remains owned by the message adapter. This module owns every GDI
//! object acquired during a paint and releases it before EndPaint.

const std = @import("std");
const Abi = @import("WindowsHostAbi.zig");
const Logic = @import("WindowsHostLogic.zig");
const Appearance = @import("WindowsAppearance.zig");
const Dividers = @import("WindowsDividers.zig");

const c = Abi.c;

const color_default: u32 = 0x0fff;
const color_invalid: u32 = 0xffffffff;
const style_bold: u32 = 1;
const style_inverse: u32 = 2;
const style_underline: u32 = 8;
const style_strikethrough: u32 = 16;
const style_faint: u32 = 32;
const style_wide_continuation: u32 = 128;

pub const State = Abi.RenderState;

fn callbacks(state: *const State) *const Abi.Callbacks {
    return state.callbacks;
}

const Pane = struct {
    pane: c.RECT,
    content: c.RECT,
    columns: c_int,
    rows: c_int,
    selected: bool,
    host_active: bool,
};

pub export fn noctty_windows_theme_colors(
    theme: c_int,
    foreground: ?*u32,
    background: ?*u32,
) void {
    const foreground_output = foreground orelse return;
    const background_output = background orelse return;
    if (theme == 1) {
        foreground_output.* = Logic.noctty_windows_rgb_from_colorref(
            c.GetSysColor(c.COLOR_WINDOWTEXT),
        );
        background_output.* = Logic.noctty_windows_rgb_from_colorref(
            c.GetSysColor(c.COLOR_WINDOW),
        );
    } else {
        const colors = Appearance.colors(theme);
        foreground_output.* = colors.foreground;
        background_output.* = colors.background;
    }
}

pub export fn noctty_windows_render(state: ?*const State, paint_count: ?*u32) void {
    const render = state orelse return;
    const counter = paint_count orelse return;
    if (render.window == null) return;
    if (callbacks(render).userdata == null) return;
    var paint: c.PAINTSTRUCT = undefined;
    const target = c.BeginPaint(render.window, &paint) orelse return;
    defer _ = c.EndPaint(render.window, &paint);
    var client: c.RECT = undefined;
    if (c.GetClientRect(render.window, &client) == 0) return;
    if (client.right <= 0 or client.bottom <= 0) return;

    const buffer_device = c.CreateCompatibleDC(target) orelse return;
    defer _ = c.DeleteDC(buffer_device);
    const buffer_bitmap = c.CreateCompatibleBitmap(
        target,
        client.right,
        client.bottom,
    ) orelse return;
    defer _ = c.DeleteObject(buffer_bitmap);
    const previous_bitmap = c.SelectObject(buffer_device, buffer_bitmap);
    defer _ = c.SelectObject(buffer_device, previous_bitmap);
    const background = c.CreateSolidBrush(
        Logic.noctty_windows_colorref_from_rgb(render.background),
    ) orelse return;
    defer _ = c.DeleteObject(background);
    _ = c.FillRect(buffer_device, &client, background);

    client.top = @min(render.content_top, client.bottom);
    const pane_count = callbacks(render).pane_count(callbacks(render).userdata);
    if (pane_count > 0) {
        var pane_index: c_int = 0;
        while (pane_index < pane_count) : (pane_index += 1) {
            drawPane(render, buffer_device, client, pane_index);
        }
    } else {
        drawLegacyGrid(render, buffer_device);
    }
    drawDividers(render, buffer_device, client);
    _ = c.BitBlt(
        target,
        0,
        0,
        client.right,
        client.bottom,
        buffer_device,
        0,
        0,
        c.SRCCOPY,
    );
    counter.* +%= 1;
}

fn drawDividers(state: *const State, device: c.HDC, client: c.RECT) void {
    const cb = callbacks(state);
    const count = cb.divider_count(cb.userdata);
    if (count <= 0) return;
    const normal = c.CreateSolidBrush(Logic.noctty_windows_colorref_from_rgb(
        Logic.noctty_windows_blend_rgb(state.foreground, state.background, 110),
    )) orelse return;
    defer _ = c.DeleteObject(normal);
    const dpi = c.GetDpiForWindow(state.window);
    const radius = @max(0, c.MulDiv(1, @intCast(if (dpi == 0) 96 else dpi), 96) - 1);
    var ordinal: c_int = 0;
    while (ordinal < count) : (ordinal += 1) {
        const divider = Dividers.Divider.read(cb, ordinal) orelse continue;
        var line = divider.band(client, radius, divider.ratio);
        _ = c.FillRect(device, &line, normal);
        if (state.divider_preview_node == divider.node) {
            line = divider.band(client, radius + 1, state.divider_preview_ratio);
            _ = c.FillRect(device, &line, c.GetSysColorBrush(c.COLOR_HIGHLIGHT));
        }
    }
}

fn drawLegacyGrid(state: *const State, device: c.HDC) void {
    if (state.columns <= 0 or state.rows <= 0) return;
    var row: c_int = 0;
    while (row < state.rows) : (row += 1) {
        // Wide glyphs paint across their continuation cell. Paint that cell's
        // background first so it cannot erase the glyph's right half.
        var column = state.columns;
        while (column > 0) {
            column -= 1;
            drawCell(
                state,
                device,
                -1,
                0,
                state.content_top,
                state.columns * state.cell_width,
                state.rows * state.cell_height,
                state.columns,
                state.rows,
                column,
                row,
            );
        }
    }
    const cursor = callbacks(state).cursor(callbacks(state).userdata);
    if (cursor == color_invalid or c.GetFocus() != state.window) return;
    const column: c_int = @intCast(cursor & 0xffff);
    const row_index: c_int = @intCast(cursor >> 16);
    if (column < 0 or column >= state.columns or row_index < 0 or row_index >= state.rows) return;
    var rectangle = c.RECT{
        .left = column * state.cell_width,
        .top = state.content_top + row_index * state.cell_height,
        .right = (column + 1) * state.cell_width,
        .bottom = state.content_top + (row_index + 1) * state.cell_height,
    };
    _ = c.InvertRect(device, &rectangle);
}

fn drawPane(state: *const State, device: c.HDC, client: c.RECT, pane_index: c_int) void {
    const pane = paneGeometry(state, client, pane_index) orelse return;
    const width = pane.content.right - pane.content.left;
    const height = pane.content.bottom - pane.content.top;
    var row: c_int = 0;
    while (row < pane.rows) : (row += 1) {
        // Match the remote/legacy path: continuation backgrounds precede the
        // leading glyph's two-cell paint, including selection colors.
        var column = pane.columns;
        while (column > 0) {
            column -= 1;
            drawCell(
                state,
                device,
                pane_index,
                pane.content.left,
                pane.content.top,
                width,
                height,
                pane.columns,
                pane.rows,
                column,
                row,
            );
        }
    }
    if (pane.host_active) {
        const cursor = callbacks(state).pane_cursor(callbacks(state).userdata, pane_index);
        if (cursor != color_invalid) {
            const column: c_int = @intCast(cursor & 0xffff);
            const row_index: c_int = @intCast(cursor >> 16);
            if (column >= 0 and column < pane.columns and
                row_index >= 0 and row_index < pane.rows)
            {
                var rectangle = cellRectangle(
                    pane.content.left,
                    pane.content.top,
                    width,
                    height,
                    pane.columns,
                    pane.rows,
                    column,
                    row_index,
                );
                _ = c.InvertRect(device, &rectangle);
            }
        }
    }
    drawPaneBorder(device, pane);
}

fn paneGeometry(state: *const State, client: c.RECT, pane_index: c_int) ?Pane {
    var x: u32 = 0;
    var y: u32 = 0;
    var width: u32 = 0;
    var height: u32 = 0;
    var selected: c_int = 0;
    var host_active: c_int = 0;
    if (callbacks(state).pane_layout(
        callbacks(state).userdata,
        pane_index,
        &x,
        &y,
        &width,
        &height,
        &selected,
        &host_active,
    ) <= 0) return null;
    var geometry: Logic.PaneGeometry = undefined;
    if (Logic.noctty_windows_compute_pane_geometry(
        client.left,
        client.top,
        client.right,
        client.bottom,
        x,
        y,
        width,
        height,
        3,
        &geometry,
    ) == 0) return null;
    var columns: u16 = 0;
    var rows: u16 = 0;
    if (callbacks(state).pane_dimensions(
        callbacks(state).userdata,
        pane_index,
        &columns,
        &rows,
    ) <= 0 or columns == 0 or rows == 0) return null;
    return .{
        .pane = .{
            .left = geometry.pane_left,
            .top = geometry.pane_top,
            .right = geometry.pane_right,
            .bottom = geometry.pane_bottom,
        },
        .content = .{
            .left = geometry.content_left,
            .top = geometry.content_top,
            .right = geometry.content_right,
            .bottom = geometry.content_bottom,
        },
        .columns = columns,
        .rows = rows,
        .selected = selected != 0,
        .host_active = host_active != 0,
    };
}

fn drawCell(
    state: *const State,
    device: c.HDC,
    pane_index: c_int,
    origin_x: c_int,
    origin_y: c_int,
    content_width: c_int,
    content_height: c_int,
    columns: c_int,
    rows: c_int,
    column: c_int,
    row: c_int,
) void {
    const cell_value = if (pane_index >= 0)
        callbacks(state).pane_cell(callbacks(state).userdata, pane_index, column, row)
    else
        callbacks(state).cell(callbacks(state).userdata, column, row);
    const style: u32 = @truncate(cell_value >> 32);
    var foreground = terminalColor(state, pane_index, (style >> 8) & 0x0fff, state.foreground);
    var background = terminalColor(state, pane_index, (style >> 20) & 0x0fff, state.background);
    if (style & style_inverse != 0) std.mem.swap(u32, &foreground, &background);
    if (style & style_faint != 0) {
        foreground = Logic.noctty_windows_blend_rgb(foreground, background, 150);
    }
    if (pane_index >= 0 and cellSelected(state, pane_index, column, row)) {
        foreground = Logic.noctty_windows_rgb_from_colorref(c.GetSysColor(c.COLOR_HIGHLIGHTTEXT));
        background = Logic.noctty_windows_rgb_from_colorref(c.GetSysColor(c.COLOR_HIGHLIGHT));
    }
    var rectangle = cellRectangle(
        origin_x,
        origin_y,
        content_width,
        content_height,
        columns,
        rows,
        column,
        row,
    );
    _ = c.SetTextColor(device, Logic.noctty_windows_colorref_from_rgb(foreground));
    _ = c.SetBkColor(device, Logic.noctty_windows_colorref_from_rgb(background));
    const previous_mode = c.SetBkMode(device, c.OPAQUE);
    defer _ = c.SetBkMode(device, previous_mode);
    if (style & style_wide_continuation != 0) {
        _ = c.ExtTextOutW(
            device,
            rectangle.left,
            rectangle.top,
            c.ETO_OPAQUE,
            &rectangle,
            wide(""),
            0,
            null,
        );
        return;
    }
    var text_utf8: [128]u8 = undefined;
    const text_length = if (pane_index >= 0)
        callbacks(state).pane_cell_text(
            callbacks(state).userdata,
            pane_index,
            column,
            row,
            &text_utf8,
            text_utf8.len,
        )
    else
        callbacks(state).cell_text(
            callbacks(state).userdata,
            column,
            row,
            &text_utf8,
            text_utf8.len,
        );
    if (text_length <= 0 or text_length > text_utf8.len) {
        _ = c.ExtTextOutW(
            device,
            rectangle.left,
            rectangle.top,
            c.ETO_OPAQUE,
            &rectangle,
            wide(""),
            0,
            null,
        );
        return;
    }
    var text_utf16: [128]u16 = undefined;
    var wide_length = c.MultiByteToWideChar(
        c.CP_UTF8,
        c.MB_ERR_INVALID_CHARS,
        &text_utf8,
        text_length,
        &text_utf16,
        text_utf16.len,
    );
    if (wide_length <= 0) {
        text_utf16[0] = 0xfffd;
        wide_length = 1;
    }
    if (column + 1 < columns and nextCellIsContinuation(state, pane_index, column, row)) {
        rectangle.right = origin_x + @divTrunc((column + 2) * content_width, columns);
    }
    const font = if (style & style_bold != 0) state.font_bold else state.font_normal;
    const previous_font = c.SelectObject(device, font);
    _ = c.ExtTextOutW(
        device,
        rectangle.left,
        rectangle.top,
        c.ETO_OPAQUE | c.ETO_CLIPPED,
        &rectangle,
        &text_utf16,
        @intCast(wide_length),
        null,
    );
    _ = c.SelectObject(device, previous_font);
    if (style & style_underline != 0) drawLine(device, rectangle, rectangle.bottom - 2, foreground);
    if (style & style_strikethrough != 0) {
        drawLine(
            device,
            rectangle,
            rectangle.top + @divTrunc(rectangle.bottom - rectangle.top, 2),
            foreground,
        );
    }
}

fn nextCellIsContinuation(state: *const State, pane_index: c_int, column: c_int, row: c_int) bool {
    const cell_value = if (pane_index >= 0)
        callbacks(state).pane_cell(callbacks(state).userdata, pane_index, column + 1, row)
    else
        callbacks(state).cell(callbacks(state).userdata, column + 1, row);
    return (@as(u32, @truncate(cell_value >> 32)) & style_wide_continuation) != 0;
}

fn terminalColor(state: *const State, pane_index: c_int, color: u32, fallback: u32) u32 {
    if (color == color_default) return fallback;
    const value = if (pane_index >= 0)
        callbacks(state).pane_color_rgb(callbacks(state).userdata, pane_index, color)
    else
        callbacks(state).color_rgb(callbacks(state).userdata, color);
    return if (value == color_invalid) fallback else value;
}

fn cellSelected(state: *const State, pane_index: c_int, column: c_int, row: c_int) bool {
    return Logic.noctty_windows_cell_selected(
        state.selection_active,
        state.selection_pane,
        pane_index,
        state.selection_anchor_column,
        state.selection_anchor_row,
        state.selection_extent_column,
        state.selection_extent_row,
        column,
        row,
    ) != 0;
}

fn cellRectangle(
    origin_x: c_int,
    origin_y: c_int,
    width: c_int,
    height: c_int,
    columns: c_int,
    rows: c_int,
    column: c_int,
    row: c_int,
) c.RECT {
    return .{
        .left = origin_x + @divTrunc(column * width, columns),
        .top = origin_y + @divTrunc(row * height, rows),
        .right = origin_x + @divTrunc((column + 1) * width, columns),
        .bottom = origin_y + @divTrunc((row + 1) * height, rows),
    };
}

fn drawLine(device: c.HDC, rectangle: c.RECT, y: c_int, color: u32) void {
    const pen = c.CreatePen(
        c.PS_SOLID,
        1,
        Logic.noctty_windows_colorref_from_rgb(color),
    ) orelse return;
    defer _ = c.DeleteObject(pen);
    const previous = c.SelectObject(device, pen);
    _ = c.MoveToEx(device, rectangle.left, y, null);
    _ = c.LineTo(device, rectangle.right, y);
    _ = c.SelectObject(device, previous);
}

fn drawPaneBorder(device: c.HDC, pane: Pane) void {
    drawBorder(
        device,
        pane.pane,
        if (pane.selected) 3 else 1,
        if (pane.selected) 0x94e2d5 else 0x45475a,
        1,
    );
    if (pane.host_active) drawBorder(device, pane.pane, 1, 0xf9e2af, 3);
}

fn drawBorder(device: c.HDC, rectangle: c.RECT, thickness: c_int, color: u32, inset: c_int) void {
    const pen = c.CreatePen(
        c.PS_SOLID,
        thickness,
        Logic.noctty_windows_colorref_from_rgb(color),
    ) orelse return;
    defer _ = c.DeleteObject(pen);
    const previous_pen = c.SelectObject(device, pen);
    const previous_brush = c.SelectObject(device, c.GetStockObject(c.NULL_BRUSH));
    _ = c.Rectangle(
        device,
        rectangle.left + inset,
        rectangle.top + inset,
        rectangle.right - inset,
        rectangle.bottom - inset,
    );
    _ = c.SelectObject(device, previous_brush);
    _ = c.SelectObject(device, previous_pen);
}

fn wide(comptime text: []const u8) [*:0]const u16 {
    return @ptrCast(std.unicode.utf8ToUtf16LeStringLiteral(text));
}

test "wide glyph survives full row background painting" {
    const Fixture = struct {
        fn cell(_: ?*anyopaque, column: c_int, _: c_int) callconv(.c) u64 {
            const style = (color_default << 8) | (color_default << 20) |
                @as(u32, if (column == 1) style_wide_continuation else 0);
            return @as(u64, style) << 32;
        }
        fn text(_: ?*anyopaque, column: c_int, _: c_int, output: [*]u8, _: usize) callconv(.c) c_int {
            output[0] = if (column == 0) 'W' else ' ';
            return 1;
        }
        fn color(_: ?*anyopaque, _: u32) callconv(.c) u32 {
            return color_invalid;
        }
        fn cursor(_: ?*anyopaque) callconv(.c) u32 {
            return color_invalid;
        }
    };
    const device = c.CreateCompatibleDC(null) orelse return error.DeviceContextUnavailable;
    defer _ = c.DeleteDC(device);
    var info = std.mem.zeroes(c.BITMAPINFO);
    info.bmiHeader.biSize = @sizeOf(c.BITMAPINFOHEADER);
    info.bmiHeader.biWidth = 24;
    info.bmiHeader.biHeight = -32;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = c.BI_RGB;
    var pixels: ?*anyopaque = null;
    const bitmap = c.CreateDIBSection(device, &info, c.DIB_RGB_COLORS, &pixels, null, 0) orelse
        return error.BitmapUnavailable;
    defer _ = c.DeleteObject(bitmap);
    const previous_bitmap = c.SelectObject(device, bitmap);
    defer _ = c.SelectObject(device, previous_bitmap);
    // Force a glyph wider than one cell without requiring a CJK font on Wine.
    const font = c.CreateFontW(-24, 0, 0, 0, c.FW_NORMAL, 0, 0, 0, c.DEFAULT_CHARSET, c.OUT_DEFAULT_PRECIS, c.CLIP_DEFAULT_PRECIS, c.NONANTIALIASED_QUALITY, c.FIXED_PITCH, wide("Courier New")) orelse return error.FontUnavailable;
    defer _ = c.DeleteObject(font);
    var fixture_callbacks: Abi.Callbacks = undefined;
    fixture_callbacks.cell = Fixture.cell;
    fixture_callbacks.cell_text = Fixture.text;
    fixture_callbacks.color_rgb = Fixture.color;
    fixture_callbacks.cursor = Fixture.cursor;
    fixture_callbacks.userdata = null;
    const state = State{
        .window = null,
        .callbacks = &fixture_callbacks,
        .font_normal = font,
        .font_bold = font,
        .cell_width = 8,
        .cell_height = 32,
        .columns = 3,
        .rows = 1,
        .foreground = 0xffffff,
        .background = 0,
        .selection_active = 0,
        .selection_pane = 0,
        .selection_anchor_column = 0,
        .selection_anchor_row = 0,
        .selection_extent_column = 0,
        .selection_extent_row = 0,
    };
    drawLegacyGrid(&state, device);
    var right_half_ink = false;
    for (8..16) |x| for (0..32) |y| {
        const pixel = c.GetPixel(device, @intCast(x), @intCast(y));
        if (pixel != 0 and pixel != c.CLR_INVALID) right_half_ink = true;
    };
    try std.testing.expect(right_half_ink);
}
