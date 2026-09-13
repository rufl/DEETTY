//! System-styled exact point-size editor. Dialog manager owns all child HWNDs.
const std = @import("std");
const Abi = @import("WindowsHostAbi.zig");
const Appearance = @import("WindowsAppearance.zig");
const c = Abi.c;
const edit_id = 40401;
const error_id = 40402;
const spin_id = 40403;
const pointer = @import("WindowsTabStrip.zig").pointer;
const CreateWindowExW = *const fn (c.DWORD, c.LPCWSTR, c.LPCWSTR, c.DWORD, c_int, c_int, c_int, c_int, c.HWND, ?*align(1) anyopaque, c.HINSTANCE, c.LPVOID) callconv(.winapi) c.HWND;
const createWindowExW: CreateWindowExW = @ptrCast(&c.CreateWindowExW);
const State = struct { initial: c_int, result: c_int = 0, modal: bool = true };

pub fn show(parent: c.HWND, initial: c_int) c_int {
    if (!initialize()) return -1;
    var state = State{ .initial = initial };
    var template = dialogTemplate();
    const result = c.DialogBoxIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, dialogProc, pointer(&state));
    return if (result == -1) -1 else state.result;
}

fn initialize() bool {
    var controls = c.INITCOMMONCONTROLSEX{ .dwSize = @sizeOf(c.INITCOMMONCONTROLSEX), .dwICC = c.ICC_UPDOWN_CLASS };
    return c.InitCommonControlsEx(&controls) != 0;
}

fn finish(window: c.HWND, state: *State) void {
    if (state.modal) _ = c.EndDialog(window, c.IDOK) else _ = c.DestroyWindow(window);
}

fn dialogProc(window: c.HWND, message: c.UINT, word: c.WPARAM, long_value: c.LPARAM) callconv(.winapi) c.INT_PTR {
    if (message == c.WM_INITDIALOG) {
        const state: *State = @ptrFromInt(@as(usize, @bitCast(long_value)));
        _ = c.SetWindowLongPtrW(window, c.GWLP_USERDATA, long_value);
        const edit = c.GetDlgItem(window, edit_id);
        _ = c.SendMessageW(edit, c.EM_SETLIMITTEXT, 3, 0);
        _ = c.SetDlgItemInt(window, edit_id, @intCast(state.initial), c.FALSE);
        const spin = createWindowExW(0, wide("msctls_updown32"), wide("Font size"), c.WS_CHILD | c.WS_VISIBLE | c.UDS_ALIGNRIGHT | c.UDS_ARROWKEYS | c.UDS_SETBUDDYINT, 0, 0, 0, 0, window, @ptrFromInt(spin_id), c.GetModuleHandleW(null), null);
        if (spin == null) {
            state.result = -1;
            finish(window, state);
            return 1;
        }
        _ = c.SendMessageW(spin, c.UDM_SETBUDDY, @intFromPtr(edit), 0);
        _ = c.SendMessageW(spin, c.UDM_SETRANGE32, Appearance.min_font_size, Appearance.max_font_size);
        _ = c.SendMessageW(spin, c.UDM_SETPOS32, 0, state.initial);
        _ = c.SendMessageW(edit, c.EM_SETSEL, 0, -1);
        _ = c.SetFocus(edit);
        return 0;
    }
    const raw = c.GetWindowLongPtrW(window, c.GWLP_USERDATA);
    if (raw == 0) return 0;
    const state: *State = @ptrFromInt(@as(usize, @bitCast(raw)));
    if (message == c.WM_CLOSE or (message == c.WM_COMMAND and word & 0xffff == c.IDCANCEL)) {
        state.result = 0;
        finish(window, state);
        return 1;
    }
    if (message == c.WM_COMMAND and word & 0xffff == c.IDOK) {
        var text: [8]u16 = undefined;
        const length = c.GetDlgItemTextW(window, edit_id, &text, text.len);
        var value: c_int = 0;
        var valid = length > 0 and length <= 2;
        if (valid) for (text[0..length]) |unit| {
            if (unit < '0' or unit > '9') {
                valid = false;
                break;
            }
            value = value * 10 + unit - '0';
        };
        if (!valid or !Appearance.validFontSize(value)) {
            _ = c.SetDlgItemTextW(window, error_id, wide("Enter a whole number from 8 to 32."));
            _ = c.SetFocus(c.GetDlgItem(window, edit_id));
            _ = c.SendDlgItemMessageW(window, edit_id, c.EM_SETSEL, 0, -1);
            return 1;
        }
        state.result = value;
        finish(window, state);
        return 1;
    }
    return 0;
}

// Same DWORD-aligned standard dialog template pattern as WindowsTabStrip.
const Template = struct {
    words: [384]u16 align(4) = [_]u16{0} ** 384,
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
    result.word(5);
    result.word(0);
    result.word(0);
    result.word(220);
    result.word(100);
    result.word(0);
    result.word(0);
    result.text("Font size");
    result.word(9);
    result.text("Segoe UI");
    result.control(0, 10, 12, 105, 12, 0xffff, 0x82, "Font &size (8-32 pt):");
    result.control(c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL | c.ES_NUMBER, 120, 10, 80, 16, edit_id, 0x81, "");
    result.control(0, 10, 36, 200, 25, error_id, 0x82, "");
    result.control(c.WS_TABSTOP | c.BS_DEFPUSHBUTTON, 96, 74, 52, 16, c.IDOK, 0x80, "OK");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 156, 74, 52, 16, c.IDCANCEL, 0x80, "Cancel");
    return result;
}

pub fn qualify(parent: c.HWND) bool {
    if (!initialize()) return false;
    var template = dialogTemplate();
    var state = State{ .initial = 13, .modal = false };
    var dialog = c.CreateDialogIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, dialogProc, pointer(&state)) orelse return false;
    defer {
        if (c.IsWindow(dialog) != 0) _ = c.DestroyWindow(dialog);
    }
    if (c.IsWindowVisible(dialog) != 0 or c.GetDlgItem(dialog, spin_id) == null) return false;
    inline for (.{ "", "7", "33", "12x", "1234567890123" }) |invalid| {
        _ = c.SetDlgItemTextW(dialog, edit_id, wide(invalid));
        _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDOK, 0);
        if (c.IsWindow(dialog) == 0 or state.result != 0 or c.GetWindowTextLengthW(c.GetDlgItem(dialog, error_id)) == 0) return false;
    }
    _ = c.SendDlgItemMessageW(dialog, spin_id, c.UDM_SETPOS32, 0, 23);
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDOK, 0);
    if (c.IsWindow(dialog) != 0 or state.result != 23) return false;
    state = .{ .initial = 23, .modal = false };
    dialog = c.CreateDialogIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, dialogProc, pointer(&state)) orelse return false;
    _ = c.SetDlgItemTextW(dialog, edit_id, wide("32"));
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDCANCEL, 0);
    return c.IsWindow(dialog) == 0 and state.result == 0;
}

fn wide(comptime text: []const u8) [*:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}
