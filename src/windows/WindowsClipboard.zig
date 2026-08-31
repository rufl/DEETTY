//! Bounded Unicode clipboard ownership for the Win32 terminal host.
//!
//! Clipboard handles, global-memory transfers, and UTF conversion remain in
//! one Zig adapter. Callbacks receive borrowed buffers valid only for the call.

const std = @import("std");

const c = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "");
    @cDefine("NOMINMAX", "");
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("windows.h");
});

const paste_bytes_max: usize = 8 * 1024 * 1024;
const copy_bytes_max: usize = 2 * 1024 * 1024;

const Write = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const Copy = *const fn (
    ?*anyopaque,
    c_int,
    [*]u8,
    usize,
    c_int,
    c_int,
    c_int,
    c_int,
) callconv(.c) c_int;

pub export fn noctty_windows_clipboard_paste(
    owner: c.HWND,
    userdata: ?*anyopaque,
    write: ?Write,
) c_int {
    const sink = write orelse return 0;
    if (c.OpenClipboard(owner) == 0) return 0;
    defer _ = c.CloseClipboard();
    const memory = c.GetClipboardData(c.CF_UNICODETEXT) orelse return 0;
    const allocation_bytes: usize = c.GlobalSize(memory);
    if (allocation_bytes < @sizeOf(u16)) return 0;
    const raw_text = c.GlobalLock(memory) orelse return 0;
    defer _ = c.GlobalUnlock(memory);

    const allocation_characters = allocation_bytes / @sizeOf(u16);
    const characters_max = @min(allocation_characters, paste_bytes_max / @sizeOf(u16));
    const text: [*]const u16 = @ptrCast(@alignCast(raw_text));
    var character_count: usize = 0;
    while (character_count < characters_max and text[character_count] != 0) {
        character_count += 1;
    }
    if (character_count == characters_max and text[character_count - 1] != 0) return 0;
    if (character_count > std.math.maxInt(c_int)) return 0;

    const wide_count: c_int = @intCast(character_count);
    const utf8_bytes = c.WideCharToMultiByte(
        c.CP_UTF8,
        c.WC_ERR_INVALID_CHARS,
        text,
        wide_count,
        null,
        0,
        null,
        null,
    );
    if (utf8_bytes <= 0 or @as(usize, @intCast(utf8_bytes)) > paste_bytes_max) return 0;
    const heap = c.GetProcessHeap() orelse return 0;
    const raw_utf8 = c.HeapAlloc(heap, 0, @intCast(utf8_bytes)) orelse return 0;
    defer _ = c.HeapFree(heap, 0, raw_utf8);
    const utf8: [*]u8 = @ptrCast(raw_utf8);
    if (c.WideCharToMultiByte(
        c.CP_UTF8,
        c.WC_ERR_INVALID_CHARS,
        text,
        wide_count,
        utf8,
        utf8_bytes,
        null,
        null,
    ) != utf8_bytes) return 0;
    return @intFromBool(sink(userdata, utf8, @intCast(utf8_bytes)) == utf8_bytes);
}

pub export fn noctty_windows_clipboard_copy(
    owner: c.HWND,
    userdata: ?*anyopaque,
    pane_index: c_int,
    copy: ?Copy,
    anchor_column: c_int,
    anchor_row: c_int,
    extent_column: c_int,
    extent_row: c_int,
) c_int {
    const source = copy orelse return 0;
    if (pane_index < 0) return 0;
    const heap = c.GetProcessHeap() orelse return 0;
    const raw_utf8 = c.HeapAlloc(heap, 0, copy_bytes_max) orelse return 0;
    defer _ = c.HeapFree(heap, 0, raw_utf8);
    const utf8: [*]u8 = @ptrCast(raw_utf8);
    const copied = source(
        userdata,
        pane_index,
        utf8,
        copy_bytes_max,
        anchor_column,
        anchor_row,
        extent_column,
        extent_row,
    );
    if (copied < 0 or @as(usize, @intCast(copied)) > copy_bytes_max) return 0;
    return setUtf8(owner, utf8[0..@intCast(copied)]);
}

fn setUtf8(owner: c.HWND, utf8: []const u8) c_int {
    if (utf8.len > std.math.maxInt(c_int)) return 0;
    const wide_count = if (utf8.len == 0)
        0
    else
        c.MultiByteToWideChar(
            c.CP_UTF8,
            c.MB_ERR_INVALID_CHARS,
            utf8.ptr,
            @intCast(utf8.len),
            null,
            0,
        );
    if (utf8.len != 0 and wide_count <= 0) return 0;
    const allocation_bytes = (@as(usize, @intCast(wide_count)) + 1) * @sizeOf(u16);
    var memory: c.HGLOBAL = c.GlobalAlloc(c.GMEM_MOVEABLE, allocation_bytes);
    if (memory == null) return 0;
    defer {
        if (memory) |owned| _ = c.GlobalFree(owned);
    }
    const raw_wide = c.GlobalLock(memory) orelse return 0;
    const wide: [*]u16 = @ptrCast(@alignCast(raw_wide));
    if (wide_count > 0 and c.MultiByteToWideChar(
        c.CP_UTF8,
        c.MB_ERR_INVALID_CHARS,
        utf8.ptr,
        @intCast(utf8.len),
        wide,
        wide_count,
    ) != wide_count) {
        _ = c.GlobalUnlock(memory);
        return 0;
    }
    wide[@intCast(wide_count)] = 0;
    _ = c.GlobalUnlock(memory);

    if (c.OpenClipboard(owner) == 0) return 0;
    defer _ = c.CloseClipboard();
    if (c.EmptyClipboard() == 0) return 0;
    if (c.SetClipboardData(c.CF_UNICODETEXT, memory) == null) return 0;
    memory = null;
    return 1;
}
