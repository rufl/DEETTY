//! Common dialogs own their modal HWNDs; the host owns the parent HWND.
//! Successful UTF-8 paths belong to the caller; cancellation returns null.
const std = @import("std");
const Abi = @import("WindowsHostAbi.zig");
const c = Abi.c;

pub fn show(parent: c.HWND, allocator: std.mem.Allocator, exporting: bool) !?[]u8 {
    return open(parent, allocator, exporting, false);
}

fn open(parent: c.HWND, allocator: std.mem.Allocator, exporting: bool, cancel_probe: bool) !?[]u8 {
    _ = parent;
    const path = try allocator.alloc(u16, 32768);
    defer allocator.free(path);
    @memset(path, 0);
    if (exporting) {
        const initial = wide("themes.nocttythemes");
        @memcpy(path[0..initial.len], initial);
    }
    var dialog: c.OPENFILENAMEW = std.mem.zeroes(c.OPENFILENAMEW);
    dialog.lStructSize = @sizeOf(c.OPENFILENAMEW);
    dialog.lpstrFilter = if (exporting)
        wide("NOCTTY theme libraries (*.nocttythemes)\x00*.nocttythemes\x00")
    else
        wide("Theme sources and libraries (*.nocttythemes;*.conf;*.Xresources;*.toml;*.json)\x00*.nocttythemes;*.conf;*.Xresources;*.toml;*.json\x00All files (*.*)\x00*.*\x00");
    dialog.nFilterIndex = 1;
    dialog.lpstrFile = path.ptr;
    dialog.nMaxFile = @intCast(path.len);
    dialog.lpstrDefExt = if (exporting) wide("nocttythemes") else wide("conf");
    dialog.lpstrTitle = if (exporting) wide("Export NOCTTY theme library") else wide("Import terminal theme source or library");
    dialog.Flags = @intCast(c.OFN_EXPLORER | c.OFN_NOCHANGEDIR | c.OFN_PATHMUSTEXIST |
        (if (exporting) c.OFN_OVERWRITEPROMPT else c.OFN_FILEMUSTEXIST));
    if (cancel_probe) {
        dialog.Flags |= c.OFN_ENABLEHOOK;
        dialog.lpfnHook = cancelHook;
    }
    const result = if (exporting) c.GetSaveFileNameW(&dialog) else c.GetOpenFileNameW(&dialog);
    if (result == 0) {
        if (c.CommDlgExtendedError() != 0) return error.NativeFileDialogFailed;
        return null;
    }
    const length = std.mem.indexOfScalar(u16, path, 0) orelse return error.InvalidPath;
    return try utf8Path(allocator, path[0..length]);
}

fn utf8Path(allocator: std.mem.Allocator, path: []const u16) ![]u8 {
    if (path.len == 0) return error.InvalidPath;
    return std.unicode.utf16LeToUtf8Alloc(allocator, path);
}

fn cancelHook(window: c.HWND, message: c.UINT, _: c.WPARAM, _: c.LPARAM) callconv(.winapi) c.UINT_PTR {
    if (message == c.WM_INITDIALOG) {
        const dialog = c.GetParent(window);
        _ = c.ShowWindow(dialog, c.SW_HIDE);
        _ = c.PostMessageW(dialog, c.WM_COMMAND, c.IDCANCEL, 0);
    }
    return 0;
}

/// Exercise real import/export dialog cancellation without touching a file.
pub fn qualify(parent: c.HWND) bool {
    const allocator = std.heap.page_allocator;
    const encoded = utf8Path(allocator, wide("C:\\NOCTTY-中-😀\\themes.nocttythemes")) catch return false;
    defer allocator.free(encoded);
    if (!std.mem.eql(u8, encoded, "C:\\NOCTTY-中-😀\\themes.nocttythemes")) return false;
    for ([_]bool{ false, true }) |exporting| {
        const result = open(parent, allocator, exporting, true) catch return false;
        if (result) |path| {
            allocator.free(path);
            return false;
        }
    }
    return true;
}

fn wide(comptime text: []const u8) [:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}
