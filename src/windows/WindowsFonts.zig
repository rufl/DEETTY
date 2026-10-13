//! DPI-aware GDI terminal-font ownership for the native Zig host.

const std = @import("std");
const Appearance = @import("WindowsAppearance.zig");

const c = @import("c");

pub export fn noctty_windows_fonts_update(
    window: c.HWND,
    font_size_pt: c_int,
    dpi: c.UINT,
    normal_output: ?*c.HFONT,
    bold_output: ?*c.HFONT,
    cell_width_output: ?*c_int,
    cell_height_output: ?*c_int,
) c_int {
    if (window == null or !Appearance.validFontSize(font_size_pt) or dpi == 0) return 0;
    const normal_slot = normal_output orelse return 0;
    const bold_slot = bold_output orelse return 0;
    const cell_width = cell_width_output orelse return 0;
    const cell_height = cell_height_output orelse return 0;
    const height = -c.MulDiv(font_size_pt, @intCast(dpi), 72);
    const family = std.unicode.utf8ToUtf16LeStringLiteral("Cascadia Mono");
    const normal = c.CreateFontW(
        height,
        0,
        0,
        0,
        c.FW_NORMAL,
        c.FALSE,
        c.FALSE,
        c.FALSE,
        c.DEFAULT_CHARSET,
        c.OUT_TT_PRECIS,
        c.CLIP_DEFAULT_PRECIS,
        c.CLEARTYPE_QUALITY,
        c.FIXED_PITCH | c.FF_MODERN,
        family,
    ) orelse return 0;
    var normal_owned = true;
    defer {
        if (normal_owned) _ = c.DeleteObject(normal);
    }
    const bold = c.CreateFontW(
        height,
        0,
        0,
        0,
        c.FW_BOLD,
        c.FALSE,
        c.FALSE,
        c.FALSE,
        c.DEFAULT_CHARSET,
        c.OUT_TT_PRECIS,
        c.CLIP_DEFAULT_PRECIS,
        c.CLEARTYPE_QUALITY,
        c.FIXED_PITCH | c.FF_MODERN,
        family,
    ) orelse return 0;
    var bold_owned = true;
    defer {
        if (bold_owned) _ = c.DeleteObject(bold);
    }

    const device = c.GetDC(window) orelse return 0;
    defer _ = c.ReleaseDC(window, device);
    const previous = c.SelectObject(device, normal);
    var metrics: c.TEXTMETRICW = undefined;
    if (c.GetTextMetricsW(device, &metrics) == 0) {
        _ = c.SelectObject(device, previous);
        return 0;
    }
    _ = c.SelectObject(device, previous);

    deinitFont(normal_slot);
    deinitFont(bold_slot);
    normal_slot.* = normal;
    bold_slot.* = bold;
    normal_owned = false;
    bold_owned = false;
    cell_width.* = if (metrics.tmAveCharWidth > 0) metrics.tmAveCharWidth else 9;
    const measured_height = metrics.tmHeight + metrics.tmExternalLeading;
    cell_height.* = if (measured_height > 0) measured_height else 18;
    return 1;
}

pub export fn noctty_windows_fonts_deinit(
    normal_output: ?*c.HFONT,
    bold_output: ?*c.HFONT,
) void {
    if (normal_output) |normal| deinitFont(normal);
    if (bold_output) |bold| deinitFont(bold);
}

fn deinitFont(font: *c.HFONT) void {
    if (font.*) |value| _ = c.DeleteObject(value);
    font.* = null;
}
