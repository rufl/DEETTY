//! Native common-control tab strip and bounded, system-styled rename dialog.
//! Child HWNDs belong to the host; cached labels avoid rebuilding controls on ticks.
const std = @import("std");
const Abi = @import("WindowsHostAbi.zig");
const c = Abi.c;
const Protocol = @import("noctty_share").protocol;

pub const control_id = 40301;
const edit_id = 40302;
const error_id = 40303;
const name_capacity = 128;

// Like NoctedHost, permit integer child IDs in CreateWindowExW's HMENU slot.
const CreateWindowExW = *const fn (
    c.DWORD,
    c.LPCWSTR,
    c.LPCWSTR,
    c.DWORD,
    c_int,
    c_int,
    c_int,
    c_int,
    c.HWND,
    ?*align(1) anyopaque,
    c.HINSTANCE,
    c.LPVOID,
) callconv(.winapi) c.HWND;
const createWindowExW: CreateWindowExW = @ptrCast(&c.CreateWindowExW);

pub const Strip = struct {
    window: c.HWND = null,
    count: usize = 0,
    height: c_int = 0,
    lengths: [Protocol.max_tabs]usize = [_]usize{0} ** Protocol.max_tabs,
    labels: [Protocol.max_tabs][Protocol.max_title_bytes]u8 = undefined,

    pub fn create(self: *Strip, parent: c.HWND) bool {
        var controls = c.INITCOMMONCONTROLSEX{ .dwSize = @sizeOf(c.INITCOMMONCONTROLSEX), .dwICC = c.ICC_TAB_CLASSES };
        if (c.InitCommonControlsEx(&controls) == 0) return false;
        self.window = createWindowExW(0, wide("SysTabControl32"), wide("Workspace tabs"), c.WS_CHILD | c.WS_VISIBLE | c.WS_TABSTOP | c.WS_CLIPSIBLINGS | c.TCS_FOCUSONBUTTONDOWN, 0, 0, 0, 0, parent, @ptrFromInt(control_id), c.GetModuleHandleW(null), null);
        return self.window != null;
    }

    pub fn setFont(self: *Strip, font: c.HFONT, dpi: c.UINT, cell_height: c_int) void {
        if (self.window == null) return;
        _ = c.SendMessageW(self.window, c.WM_SETFONT, @intFromPtr(font), 1);
        // Single-line tabs retain native overflow scrolling in narrow windows.
        self.height = @max(c.MulDiv(30, @intCast(dpi), 96), cell_height + c.MulDiv(12, @intCast(dpi), 96));
    }

    pub fn layout(self: *Strip, width: c_int, height: c_int) c_int {
        if (self.window == null) return 0;
        const inset = @min(self.height, @max(height, 0));
        _ = c.MoveWindow(self.window, 0, 0, @max(width, 0), inset, c.TRUE);
        return inset;
    }

    pub fn sync(self: *Strip, callbacks: *const Abi.Callbacks) bool {
        if (self.window == null) return false;
        const requested = callbacks.tab_count(callbacks.userdata);
        if (requested < 0 or requested > Protocol.max_tabs) return false;
        const count: usize = @intCast(requested);
        while (self.count > count) {
            if (c.SendMessageW(self.window, c.TCM_DELETEITEM, self.count - 1, 0) == 0) return false;
            self.count -= 1;
        }
        for (0..count) |index| {
            var bytes: [Protocol.max_title_bytes]u8 = undefined;
            const length = callbacks.tab_title(callbacks.userdata, @intCast(index), &bytes, bytes.len);
            if (length < 0 or length > bytes.len) return false;
            const len: usize = @intCast(length);
            const insert = index == self.count;
            if (!insert and self.lengths[index] == len and std.mem.eql(u8, self.labels[index][0..len], bytes[0..len])) continue;
            var text: [Protocol.max_title_bytes * 2 + 1]u16 = undefined;
            const wide_length = if (len == 0) 0 else c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, @ptrCast(&bytes), length, &text, @intCast(text.len - 1));
            if (len != 0 and wide_length <= 0) return false;
            // Native tab text uses DrawText mnemonic syntax; titles are literal.
            var end: usize = @intCast(wide_length);
            for (text[0..end]) |unit| end += @intFromBool(unit == '&');
            text[end] = 0;
            var source: usize = @intCast(wide_length);
            while (source > 0) {
                source -= 1;
                const unit = text[source];
                end -= 1;
                text[end] = unit;
                if (unit == '&') {
                    end -= 1;
                    text[end] = unit;
                }
            }
            var item: c.TCITEMW = std.mem.zeroes(c.TCITEMW);
            item.mask = c.TCIF_TEXT;
            item.pszText = &text;
            const result = c.SendMessageW(self.window, if (insert) c.TCM_INSERTITEMW else c.TCM_SETITEMW, index, pointer(&item));
            if ((insert and result < 0) or (!insert and result == 0)) return false;
            if (insert) self.count += 1;
            @memcpy(self.labels[index][0..len], bytes[0..len]);
            self.lengths[index] = len;
        }
        const active = callbacks.tab_active(callbacks.userdata);
        if (active >= 0 and active < requested and self.selected() != active)
            _ = c.SendMessageW(self.window, c.TCM_SETCURSEL, @intCast(active), 0);
        return true;
    }

    pub fn selected(self: *const Strip) c_int {
        return @intCast(c.SendMessageW(self.window, c.TCM_GETCURSEL, 0, 0));
    }

    pub fn matches(self: *const Strip, callbacks: *const Abi.Callbacks) bool {
        if (c.SendMessageW(self.window, c.TCM_GETITEMCOUNT, 0, 0) != callbacks.tab_count(callbacks.userdata) or
            self.selected() != callbacks.tab_active(callbacks.userdata)) return false;
        for (0..self.count) |index| {
            var text: [Protocol.max_title_bytes * 2 + 1]u16 = undefined;
            var item: c.TCITEMW = std.mem.zeroes(c.TCITEMW);
            item.mask = c.TCIF_TEXT;
            item.pszText = &text;
            item.cchTextMax = text.len;
            if (c.SendMessageW(self.window, c.TCM_GETITEMW, index, pointer(&item)) == 0) return false;
            const text_length = std.mem.indexOfScalar(u16, &text, 0) orelse return false;
            var source: usize = 0;
            var decoded_length: usize = 0;
            while (source < text_length) : (source += 1) {
                const unit = text[source];
                if (unit == '&') {
                    source += 1;
                    if (source >= text_length or text[source] != '&') return false;
                }
                text[decoded_length] = unit;
                decoded_length += 1;
            }
            var bytes: [Protocol.max_title_bytes]u8 = undefined;
            const len = c.WideCharToMultiByte(c.CP_UTF8, c.WC_ERR_INVALID_CHARS, &text, @intCast(decoded_length), @ptrCast(&bytes), bytes.len, null, null);
            if (len < 0 or len != self.lengths[index] or !std.mem.eql(u8, bytes[0..@intCast(len)], self.labels[index][0..self.lengths[index]])) return false;
        }
        return true;
    }
};

const Rename = struct {
    callbacks: *const Abi.Callbacks,
    index: c_int,
    pane: c_int,
    initial: [name_capacity + 1]u16 = [_]u16{0} ** (name_capacity + 1),
    modal: bool = true,
    result: c_int = 0,
};

pub fn rename(parent: c.HWND, callbacks: *const Abi.Callbacks, remote: bool) c_int {
    if (remote) return -1;
    var state = renameState(callbacks) orelse return -1;
    var template = dialogTemplate();
    const result = c.DialogBoxIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, renameProc, pointer(&state));
    return if (result == -1) -1 else state.result;
}

fn renameState(callbacks: *const Abi.Callbacks) ?Rename {
    const index = callbacks.tab_active(callbacks.userdata);
    if (index < 0 or index >= callbacks.tab_count(callbacks.userdata)) return null;
    const pane = callbacks.active_pane(callbacks.userdata);
    if (pane < 0) return null;
    var state = Rename{ .callbacks = callbacks, .index = index, .pane = pane };
    // Automatic terminal titles can exceed the editable name bound. Leave those
    // blank instead of silently truncating a name into a different UTF-8 string.
    var bytes: [Protocol.max_title_bytes]u8 = undefined;
    const len = callbacks.tab_title(callbacks.userdata, index, &bytes, bytes.len);
    if (len > 0 and len <= name_capacity) {
        const count = c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, @ptrCast(&bytes), len, &state.initial, name_capacity);
        if (count > 0) state.initial[@intCast(count)] = 0;
    }
    return state;
}

fn finishRename(window: c.HWND, state: *Rename) void {
    if (state.modal) _ = c.EndDialog(window, c.IDOK) else _ = c.DestroyWindow(window);
}

fn renameProc(window: c.HWND, message: c.UINT, word: c.WPARAM, long_value: c.LPARAM) callconv(.winapi) c.INT_PTR {
    if (message == c.WM_INITDIALOG) {
        const state: *Rename = @ptrFromInt(@as(usize, @bitCast(long_value)));
        _ = c.SetWindowLongPtrW(window, c.GWLP_USERDATA, long_value);
        const edit = c.GetDlgItem(window, edit_id);
        _ = c.SendMessageW(edit, c.EM_SETLIMITTEXT, name_capacity, 0);
        _ = c.SetWindowTextW(edit, &state.initial);
        _ = c.SendMessageW(edit, c.EM_SETSEL, 0, -1);
        _ = c.SetFocus(edit);
        return 0;
    }
    const raw = c.GetWindowLongPtrW(window, c.GWLP_USERDATA);
    if (raw == 0) return 0;
    const state: *Rename = @ptrFromInt(@as(usize, @bitCast(raw)));
    if (message == c.WM_CLOSE or (message == c.WM_COMMAND and (word & 0xffff) == c.IDCANCEL)) {
        state.result = 0;
        finishRename(window, state);
        return 1;
    }
    if (message == c.WM_COMMAND and (word & 0xffff) == c.IDOK) {
        if (state.callbacks.tab_active(state.callbacks.userdata) != state.index or
            state.callbacks.active_pane(state.callbacks.userdata) != state.pane)
        {
            _ = c.SetDlgItemTextW(window, error_id, wide("The active tab changed. Cancel and open Rename Tab again."));
            return 1;
        }
        if (c.GetWindowTextLengthW(c.GetDlgItem(window, edit_id)) > name_capacity) {
            _ = c.SetDlgItemTextW(window, error_id, wide("Use at most 128 UTF-8 bytes, without control characters."));
            _ = c.SetFocus(c.GetDlgItem(window, edit_id));
            return 1;
        }
        var text: [name_capacity + 1]u16 = undefined;
        const count = c.GetDlgItemTextW(window, edit_id, &text, text.len);
        var bytes: [name_capacity]u8 = undefined;
        const length = if (count == 0) 0 else c.WideCharToMultiByte(c.CP_UTF8, c.WC_ERR_INVALID_CHARS, &text, @intCast(count), @ptrCast(&bytes), bytes.len, null, null);
        var valid = count == 0 or length > 0;
        if (valid) for (bytes[0..@intCast(length)]) |byte| {
            if (byte < 0x20 or byte == 0x7f) valid = false;
        };
        if (!valid) {
            _ = c.SetDlgItemTextW(window, error_id, wide("Use at most 128 UTF-8 bytes, without control characters."));
            _ = c.SetFocus(c.GetDlgItem(window, edit_id));
            return 1;
        }
        const result = state.callbacks.tab_rename(state.callbacks.userdata, state.index, &bytes, @intCast(length));
        if (result < 0) {
            _ = c.SetDlgItemTextW(window, error_id, wide("The tab could not be renamed. Please try again."));
            return 1;
        }
        state.result = result;
        finishRename(window, state);
        return 1;
    }
    return 0;
}

// Standard DLGTEMPLATE/ITEMTEMPLATE serialization, word-sized fields with
// DWORD-aligned controls. Dialog manager supplies system colors and keyboard
// navigation (label mnemonic, Tab, Enter/default OK, Escape/Cancel).
const Template = struct {
    words: [512]u16 align(4) = [_]u16{0} ** 512,
    used: usize = 0,
    fn word(self: *Template, value: u16) void {
        self.words[self.used] = value;
        self.used += 1;
    }
    fn dword(self: *Template, value: u32) void {
        self.word(@truncate(value));
        self.word(@truncate(value >> 16));
    }
    fn text(self: *Template, comptime value: []const u8) void {
        for (std.unicode.utf8ToUtf16LeStringLiteral(value)) |unit| self.word(unit);
        self.word(0);
    }
    fn control(self: *Template, style: u32, x: u16, y: u16, width: u16, height: u16, id: u16, class: u16, comptime title: []const u8) void {
        if (self.used % 2 != 0) self.word(0);
        self.dword(@as(u32, @intCast(c.WS_CHILD | c.WS_VISIBLE)) | style);
        self.dword(0);
        self.word(x);
        self.word(y);
        self.word(width);
        self.word(height);
        self.word(id);
        self.word(0xffff);
        self.word(class);
        self.text(title);
        self.word(0);
    }
};

fn dialogTemplate() Template {
    var result: Template = .{};
    result.dword(c.WS_POPUP | c.WS_CAPTION | c.WS_SYSMENU | c.DS_MODALFRAME | c.DS_SETFONT | c.DS_CENTER);
    result.dword(0);
    result.word(6);
    result.word(0);
    result.word(0);
    result.word(270);
    result.word(116);
    result.word(0);
    result.word(0);
    result.text("Rename Tab");
    result.word(9);
    result.text("Segoe UI");
    result.control(0, 10, 9, 250, 10, 0xffff, 0x82, "Tab &name:");
    result.control(c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL, 10, 22, 250, 15, edit_id, 0x81, "");
    result.control(0, 10, 43, 250, 20, 0xffff, 0x82, "Blank resets the automatic title. Maximum 128 UTF-8 bytes.");
    result.control(0, 10, 66, 250, 20, error_id, 0x82, "");
    result.control(c.WS_TABSTOP | c.BS_DEFPUSHBUTTON, 148, 92, 52, 16, c.IDOK, 0x80, "OK");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 208, 92, 52, 16, c.IDCANCEL, 0x80, "Cancel");
    return result;
}

/// Exercises the same dialog procedure and callback as the modal UI, without
/// showing a desktop surface or entering an unbounded interactive dialog loop.
pub fn qualifyRename(parent: c.HWND, callbacks: *const Abi.Callbacks) bool {
    var template = dialogTemplate();
    var state = renameState(callbacks) orelse return false;
    state.modal = false;
    var dialog = c.CreateDialogIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, renameProc, pointer(&state)) orelse return false;
    defer {
        if (c.IsWindow(dialog) != 0) _ = c.DestroyWindow(dialog);
    }
    if (c.IsWindowVisible(dialog) != 0 or c.GetDlgItem(dialog, edit_id) == null or c.GetDlgItem(dialog, c.IDOK) == null or c.GetDlgItem(dialog, c.IDCANCEL) == null) return false;
    // The native edit accepts UTF-16; byte-bound validation must reject 129 bytes.
    var overlong: [44]u16 = [_]u16{0x4e2d} ** 44;
    overlong[43] = 0;
    _ = c.SetDlgItemTextW(dialog, edit_id, &overlong);
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDOK, 0);
    if (c.IsWindow(dialog) == 0 or state.result != 0) return false;
    var oversized: [name_capacity + 2]u16 = [_]u16{'X'} ** (name_capacity + 2);
    oversized[oversized.len - 1] = 0;
    _ = c.SetDlgItemTextW(dialog, edit_id, &oversized);
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDOK, 0);
    if (c.IsWindow(dialog) == 0 or state.result != 0) return false;
    _ = c.SetDlgItemTextW(dialog, edit_id, wide("Native & 中"));
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDOK, 0);
    if (c.IsWindow(dialog) != 0 or state.result <= 0 or !titleMatches(callbacks, state.index, "Native & 中")) return false;
    state = renameState(callbacks) orelse return false;
    state.modal = false;
    dialog = c.CreateDialogIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, renameProc, pointer(&state)) orelse return false;
    _ = c.SetDlgItemTextW(dialog, edit_id, wide("Cancelled"));
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDCANCEL, 0);
    return c.IsWindow(dialog) == 0 and state.result == 0 and titleMatches(callbacks, state.index, "Native & 中");
}

pub fn titleMatches(callbacks: *const Abi.Callbacks, index: c_int, expected: []const u8) bool {
    var bytes: [Protocol.max_title_bytes]u8 = undefined;
    const len = callbacks.tab_title(callbacks.userdata, index, &bytes, bytes.len);
    return len >= 0 and len == expected.len and std.mem.eql(u8, bytes[0..@intCast(len)], expected);
}

pub fn pointer(value: anytype) c.LPARAM {
    return @bitCast(@intFromPtr(value));
}
fn wide(comptime text: []const u8) [*:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}
