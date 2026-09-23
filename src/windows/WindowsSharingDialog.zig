//! Native paired-device manager backed by the existing encrypted sharing store.
const std = @import("std");
const Abi = @import("WindowsHostAbi.zig");
const Share = @import("noctty_share");
const c = Abi.c;
const pointer = @import("WindowsTabStrip.zig").pointer;

const list_id: u16 = 40900;
const host_id: u16 = 40901;
const port_id: u16 = 40902;
const alias_id: u16 = 40903;
const pair_id: u16 = 40904;
const discover_id: u16 = 40905;
const revoke_id: u16 = 40906;
const status_id: u16 = 40907;
const role_status_id: u16 = 40908;
const share_id: u16 = 40909;
const receive_id: u16 = 40910;
const stop_id: u16 = 40911;

const State = struct {
    callbacks: *const Abi.Callbacks,
    modal: bool = true,
    failed: bool = false,
};

pub fn show(parent: c.HWND, callbacks: *const Abi.Callbacks) bool {
    var state = State{ .callbacks = callbacks };
    var template = dialogTemplate();
    const result = c.DialogBoxIndirectParamW(
        c.GetModuleHandleW(null),
        @ptrCast(&template.words),
        parent,
        dialogProc,
        pointer(&state),
    );
    return result != -1 and !state.failed;
}

fn finish(window: c.HWND, state: *State) void {
    if (state.modal) _ = c.EndDialog(window, c.IDCANCEL) else _ = c.DestroyWindow(window);
}

fn wide(comptime text: []const u8) [*:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}

fn failure(window: c.HWND, comptime text: []const u8) void {
    _ = c.SetDlgItemTextW(window, status_id, wide(text));
}

fn setText(window: c.HWND, id: u16, text: []const u8, capacity: usize) bool {
    if (text.len > capacity) return false;
    var encoded: [Share.identity.max_endpoint_bytes + Share.protocol.max_alias_bytes + 2]u16 = undefined;
    const units = if (text.len == 0)
        0
    else
        c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, text.ptr, @intCast(text.len), &encoded, encoded.len - 1);
    if (text.len != 0 and units <= 0) return false;
    encoded[@intCast(units)] = 0;
    return c.SetDlgItemTextW(window, id, &encoded) != 0;
}

fn readField(window: c.HWND, id: u16, output: []u8) !usize {
    const edit = c.GetDlgItem(window, id);
    const length = c.GetWindowTextLengthW(edit);
    if (length < 0 or @as(usize, @intCast(length)) > output.len) return error.FieldTooLong;
    var encoded: [Share.identity.max_endpoint_bytes + Share.protocol.max_alias_bytes + 2]u16 = undefined;
    if (length == 0) return 0;
    const copied = c.GetWindowTextW(edit, &encoded, @intCast(@min(encoded.len, @as(usize, @intCast(length)) + 1)));
    if (copied != length) return error.FieldReadFailed;
    const bytes = c.WideCharToMultiByte(
        c.CP_UTF8,
        c.WC_ERR_INVALID_CHARS,
        &encoded,
        length,
        output.ptr,
        @intCast(output.len),
        null,
        null,
    );

    if (bytes <= 0) return error.InvalidUnicode;
    return @intCast(bytes);
}
fn updateRole(window: c.HWND, state: *State) void {
    const role = state.callbacks.share_role_status(state.callbacks.userdata);
    const text = switch (role) {
        0 => "Session: idle",
        1 => "Session: sharing selected device",
        2 => "Session: receiving selected device",
        else => "Session: failed; stop the session before retrying",
    };
    _ = setText(window, role_status_id, text, 64);
    const selected = c.SendDlgItemMessageW(window, list_id, c.LB_GETCURSEL, 0, 0) >= 0;
    _ = c.EnableWindow(c.GetDlgItem(window, share_id), @intFromBool(selected and role == 0));
    _ = c.EnableWindow(c.GetDlgItem(window, receive_id), @intFromBool(selected and role == 0));
    _ = c.EnableWindow(c.GetDlgItem(window, stop_id), @intFromBool(role != 0));
}

fn refresh(window: c.HWND, state: *State) bool {
    const cb = state.callbacks;
    const count = cb.share_peer_count(cb.userdata);
    if (count < 0 or count > Share.identity.max_peers) return false;
    _ = c.SendDlgItemMessageW(window, list_id, c.LB_RESETCONTENT, 0, 0);
    var index: c_int = 0;
    while (index < count) : (index += 1) {
        var alias: [Share.protocol.max_alias_bytes]u8 = undefined;
        var endpoint: [Share.identity.max_endpoint_bytes]u8 = undefined;
        var alias_length: usize = 0;
        var endpoint_length: usize = 0;
        var port: u16 = 0;
        if (cb.share_peer_info(
            cb.userdata,
            index,
            &alias,
            alias.len,
            &alias_length,
            &endpoint,
            endpoint.len,
            &endpoint_length,
            &port,
        ) != 0 or alias_length == 0 or endpoint_length == 0 or port == 0) return false;
        var line: [Share.identity.max_endpoint_bytes + Share.protocol.max_alias_bytes + 16]u8 = undefined;
        const text = std.fmt.bufPrint(
            &line,
            "{s} - {s}:{d}",
            .{ alias[0..alias_length], endpoint[0..endpoint_length], port },
        ) catch return false;
        var encoded: [Share.identity.max_endpoint_bytes + Share.protocol.max_alias_bytes + 32]u16 = undefined;
        const units = c.MultiByteToWideChar(
            c.CP_UTF8,
            c.MB_ERR_INVALID_CHARS,
            text.ptr,
            @intCast(text.len),
            &encoded,
            encoded.len - 1,
        );
        if (units <= 0) return false;
        encoded[@intCast(units)] = 0;
        if (c.SendDlgItemMessageW(window, list_id, c.LB_ADDSTRING, 0, pointer(&encoded)) < 0) return false;
    }
    _ = c.EnableWindow(c.GetDlgItem(window, revoke_id), @intFromBool(count > 0));
    updateRole(window, state);
    return true;
}

fn pair(window: c.HWND, state: *State) void {
    var endpoint: [Share.identity.max_endpoint_bytes]u8 = undefined;
    var alias: [Share.protocol.max_alias_bytes]u8 = undefined;
    const endpoint_length = readField(window, host_id, &endpoint) catch {
        failure(window, "Enter a valid endpoint using UTF-8 text within 253 bytes.");
        return;
    };
    const alias_length = readField(window, alias_id, &alias) catch {
        failure(window, "Enter a valid device alias using UTF-8 text within 64 bytes.");
        return;
    };
    var port_text: [6]u8 = undefined;
    const port_length = readField(window, port_id, &port_text) catch {
        failure(window, "Enter a TCP port from 1 to 65535.");
        return;
    };
    const port = std.fmt.parseInt(u16, port_text[0..port_length], 10) catch {
        failure(window, "Enter a TCP port from 1 to 65535.");
        return;
    };
    if (endpoint_length == 0 or alias_length == 0 or port == 0) {
        failure(window, "Endpoint, port, and alias are required.");
        return;
    }
    if (state.callbacks.share_pair(
        state.callbacks.userdata,
        &endpoint,
        endpoint_length,
        &alias,
        alias_length,
        port,
    ) != 0) {
        failure(window, "Pairing failed or could not be persisted. The existing device list is unchanged.");
        return;
    }
    if (!refresh(window, state)) {
        failure(window, "Pairing succeeded, but the paired-device list could not refresh.");
        return;
    }
    failure(window, "Pairing succeeded and the device was saved.");
}

fn discover(window: c.HWND, state: *State) void {
    if (state.callbacks.share_discover(state.callbacks.userdata) != 0) {
        failure(window, "LAN discovery failed or found no pairing listener.");
        return;
    }
    failure(window, "Discovery completed. Use the reported endpoint to pair.");
}

fn startRole(window: c.HWND, state: *State, role: c_int) void {
    const selected = c.SendDlgItemMessageW(window, list_id, c.LB_GETCURSEL, 0, 0);
    if (selected < 0) {
        failure(window, "Select a paired device first.");
        return;
    }
    var port_text: [6]u8 = undefined;
    const port_length = readField(window, port_id, &port_text) catch {
        failure(window, "Enter a TCP port from 1 to 65535.");
        return;
    };
    const port = std.fmt.parseInt(u16, port_text[0..port_length], 10) catch {
        failure(window, "Enter a TCP port from 1 to 65535.");
        return;
    };
    if (port == 0) {
        failure(window, "Enter a TCP port from 1 to 65535.");
        return;
    }
    if (state.callbacks.share_role_start(state.callbacks.userdata, @intCast(selected), port, role) != 0) {
        failure(window, "Could not start the requested sharing session.");
        updateRole(window, state);
        return;
    }
    updateRole(window, state);
    if (role == 1) {
        failure(window, "Sharing session started.");
    } else {
        failure(window, "Receiving session started.");
    }
}

fn stopRole(window: c.HWND, state: *State) void {
    if (state.callbacks.share_role_stop(state.callbacks.userdata) != 0) {
        failure(window, "Could not stop the sharing session.");
        return;
    }
    updateRole(window, state);
    failure(window, "Sharing session stopped.");
}

fn revoke(window: c.HWND, state: *State) void {
    const selected = c.SendDlgItemMessageW(window, list_id, c.LB_GETCURSEL, 0, 0);
    if (selected < 0) return;
    if (c.MessageBoxW(
        window,
        wide("Revoke this paired device? Existing sessions using it will stop accepting new trust checks."),
        wide("Revoke paired device"),
        c.MB_YESNO | c.MB_ICONWARNING | c.MB_DEFBUTTON2,
    ) != c.IDYES) return;
    if (state.callbacks.share_peer_revoke(state.callbacks.userdata, @intCast(selected)) != 0) {
        failure(window, "Could not persist revocation. The device remains paired.");
        return;
    }
    if (!refresh(window, state)) {
        failure(window, "Device revoked, but the paired-device list could not refresh.");
        return;
    }
    failure(window, "Device revoked and hidden from the active paired-device list.");
}

fn dialogProc(window: c.HWND, message: c.UINT, word: c.WPARAM, long_value: c.LPARAM) callconv(.winapi) c.INT_PTR {
    if (message == c.WM_INITDIALOG) {
        const state: *State = @ptrFromInt(@as(usize, @bitCast(long_value)));
        _ = c.SetWindowLongPtrW(window, c.GWLP_USERDATA, long_value);
        _ = c.SendDlgItemMessageW(window, host_id, c.EM_SETLIMITTEXT, Share.identity.max_endpoint_bytes, 0);
        _ = c.SendDlgItemMessageW(window, alias_id, c.EM_SETLIMITTEXT, Share.protocol.max_alias_bytes, 0);
        _ = c.SendDlgItemMessageW(window, port_id, c.EM_SETLIMITTEXT, 5, 0);
        if (!setText(window, alias_id, "NOCTTY Windows", Share.protocol.max_alias_bytes) or
            !setText(window, port_id, "49152", 5) or !refresh(window, state))
        {
            state.failed = true;
            finish(window, state);
        }
        return 1;
    }
    const raw = c.GetWindowLongPtrW(window, c.GWLP_USERDATA);
    if (raw == 0) return 0;
    const state: *State = @ptrFromInt(@as(usize, @bitCast(raw)));
    const id: u16 = @truncate(word);
    if (message == c.WM_CLOSE or (message == c.WM_COMMAND and id == c.IDCANCEL)) {
        finish(window, state);
        return 1;
    }
    if (message != c.WM_COMMAND) return 0;
    const notification: u16 = @truncate(word >> 16);
    switch (id) {
        pair_id => pair(window, state),
        discover_id => discover(window, state),
        share_id => startRole(window, state, 1),
        receive_id => startRole(window, state, 2),
        stop_id => stopRole(window, state),
        revoke_id => revoke(window, state),
        list_id => {
            if (notification == c.LBN_SELCHANGE) {
                _ = c.EnableWindow(c.GetDlgItem(window, revoke_id), @intFromBool(
                    c.SendDlgItemMessageW(window, list_id, c.LB_GETCURSEL, 0, 0) >= 0,
                ));
                updateRole(window, state);
            }
        },
        else => return 0,
    }
    return 1;
}

const Template = struct {
    words: [2048]u16 align(4) = [_]u16{0} ** 2048,
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
    result.word(17);
    result.word(0);
    result.word(0);
    result.word(500);
    result.word(290);
    result.word(0);
    result.word(0);
    result.text("Session sharing");
    result.word(9);
    result.text("Segoe UI");
    result.control(0, 10, 8, 300, 22, 0xffff, 0x82, "Paired devices");
    result.control(c.WS_TABSTOP | c.WS_BORDER | c.WS_VSCROLL | c.LBS_NOTIFY | c.LBS_NOINTEGRALHEIGHT, 10, 34, 300, 160, list_id, 0x83, "");
    result.control(0, 322, 36, 70, 12, 0xffff, 0x82, "&Endpoint:");
    result.control(c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL, 322, 50, 168, 17, host_id, 0x81, "");
    result.control(0, 322, 76, 70, 12, 0xffff, 0x82, "&Port:");
    result.control(c.WS_TABSTOP | c.WS_BORDER | c.ES_NUMBER | c.ES_AUTOHSCROLL, 322, 90, 168, 17, port_id, 0x81, "");
    result.control(0, 322, 116, 70, 12, 0xffff, 0x82, "&Alias:");
    result.control(c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL, 322, 130, 168, 17, alias_id, 0x81, "");
    result.control(0, 10, 200, 480, 18, role_status_id, 0x82, "");
    result.control(0, 10, 220, 480, 18, status_id, 0x82, "");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 10, 244, 112, 16, share_id, 0x80, "&Share selected");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 128, 244, 128, 16, receive_id, 0x80, "&Receive selected");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 262, 244, 76, 16, stop_id, 0x80, "S&top");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 10, 266, 72, 16, pair_id, 0x80, "&Pair");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 88, 266, 82, 16, discover_id, 0x80, "&Discover");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 178, 266, 82, 16, revoke_id, 0x80, "&Revoke...");
    result.control(c.WS_TABSTOP | c.BS_DEFPUSHBUTTON, 422, 266, 68, 16, c.IDCANCEL, 0x80, "&Close");
    return result;
}

pub fn qualify(parent: c.HWND, callbacks: *const Abi.Callbacks) bool {
    var state = State{ .callbacks = callbacks, .modal = false };
    var template = dialogTemplate();
    const dialog = c.CreateDialogIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, dialogProc, pointer(&state)) orelse return false;
    defer {
        if (c.IsWindow(dialog) != 0) _ = c.DestroyWindow(dialog);
    }
    return !state.failed and callbacks.share_peer_count(callbacks.userdata) >= 0;
}
