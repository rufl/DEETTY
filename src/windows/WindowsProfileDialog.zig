//! Native, bounded launch-profile editor. The dialog manager owns every child HWND.
const std = @import("std");
const Abi = @import("WindowsHostAbi.zig");
const Launch = @import("dintty_share").launch_profile;
const Profiles = @import("WindowsLaunchProfiles.zig");
const Dpapi = @import("Dpapi.zig");
const c = Abi.c;
const pointer = @import("WindowsTabStrip.zig").pointer;
const list_id = 40900;
const new_id = 40901;
const delete_id = 40902;
const error_id = 40903;
const field_ids = [_]u16{ 40910, 40911, 40912, 40913, 40914, 40915 };
fn repeatBytes(comptime pattern: []const u8, comptime count: usize) [pattern.len * count]u8 {
    var output: [pattern.len * count]u8 = undefined;
    for (0..count) |index|
        @memcpy(output[index * pattern.len ..][0..pattern.len], pattern);
    return output;
}
const State = struct {
    callbacks: *const Abi.Callbacks,
    index: c_int = -1,
    dirty: bool = false,
    loading: bool = false,
    modal: bool = true,
    failed: bool = false,
    // Hidden qualification supplies only the user's confirmation decision;
    // controls, validation, callbacks and durable writes remain production code.
    confirmation: ?bool = null,
};

pub fn show(parent: c.HWND, callbacks: *const Abi.Callbacks) bool {
    var state = State{ .callbacks = callbacks };
    var template = dialogTemplate();
    const result = c.DialogBoxIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, dialogProc, pointer(&state));
    return result != -1 and !state.failed;
}

fn finish(window: c.HWND, state: *State) void {
    if (state.modal) _ = c.EndDialog(window, c.IDCANCEL) else _ = c.DestroyWindow(window);
}

fn confirm(window: c.HWND, state: *const State, comptime text: []const u8) bool {
    if (state.confirmation) |answer| return answer;
    return c.MessageBoxW(window, wide(text), wide("Launch profiles"), c.MB_YESNO | c.MB_ICONWARNING | c.MB_DEFBUTTON2) == c.IDYES;
}

fn discard(window: c.HWND, state: *const State) bool {
    return !state.dirty or confirm(window, state, "Discard unsaved changes to this profile?");
}

fn setText(window: c.HWND, id: c_int, text: []const u8) bool {
    var encoded: [Launch.max_working_directory_bytes + 1]u16 = undefined;
    if (text.len > Launch.max_working_directory_bytes) return false;
    const units = if (text.len == 0) 0 else c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, text.ptr, @intCast(text.len), &encoded, encoded.len - 1);
    if (text.len != 0 and units <= 0) return false;
    encoded[@intCast(units)] = 0;
    return c.SetDlgItemTextW(window, id, &encoded) != 0;
}

fn failure(window: c.HWND, comptime text: []const u8) void {
    _ = c.SetDlgItemTextW(window, error_id, wide(text));
}

fn fill(window: c.HWND, state: *State, index: c_int) bool {
    const cb = state.callbacks;
    var entry: Launch.NamedProfile = .{};
    if (index >= 2 and cb.profile_get(cb.userdata, index, &entry) != 0) return false;
    if (index >= 2) entry.validateFor(.windows) catch return false;
    state.loading = true;
    defer state.loading = false;
    if (!setText(window, field_ids[0], entry.name.slice()) or
        !setText(window, field_ids[1], entry.profile.shell.slice()) or
        !setText(window, field_ids[2], entry.profile.command.slice()) or
        !setText(window, field_ids[3], entry.profile.working_directory.slice()) or
        !setText(window, field_ids[4], entry.profile.environment.slice())) return false;
    _ = c.SetDlgItemInt(window, field_ids[5], entry.profile.scrollback_lines, c.FALSE);
    _ = c.SendDlgItemMessageW(window, list_id, c.LB_SETCURSEL, if (index >= 2) @intCast(index - 2) else std.math.maxInt(usize), 0);
    _ = c.EnableWindow(c.GetDlgItem(window, delete_id), @intFromBool(index >= 2));
    state.index = index;
    state.dirty = false;
    failure(window, "");
    return true;
}

fn refresh(window: c.HWND, state: *State, index: c_int) bool {
    const cb = state.callbacks;
    const count = cb.profile_count(cb.userdata);
    if (count < 2 or count > 10) return false;
    _ = c.SendDlgItemMessageW(window, list_id, c.LB_RESETCONTENT, 0, 0);
    var current: c_int = 2;
    while (current < count) : (current += 1) {
        var bytes: [Launch.max_name_bytes]u8 = undefined;
        const length = cb.profile_name(cb.userdata, current, &bytes, bytes.len);
        if (length <= 0 or length > bytes.len) return false;
        var encoded: [Launch.max_name_bytes + 1]u16 = undefined;
        const units = c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, &bytes, length, &encoded, encoded.len - 1);
        if (units <= 0) return false;
        encoded[@intCast(units)] = 0;
        if (c.SendDlgItemMessageW(window, list_id, c.LB_ADDSTRING, 0, pointer(&encoded)) < 0) return false;
    }
    _ = c.EnableWindow(c.GetDlgItem(window, new_id), @intFromBool(count < 10));
    return fill(window, state, if (index >= 2 and index < count) index else -1);
}

fn readField(window: c.HWND, id: c_int, comptime capacity: usize) !Launch.BoundedText(capacity) {
    const edit = c.GetDlgItem(window, id);
    const length = c.GetWindowTextLengthW(edit);
    if (length < 0 or length > capacity) return error.LaunchProfileFieldTooLong;
    var encoded: [capacity + 1]u16 = undefined;
    const copied = c.GetWindowTextW(edit, &encoded, encoded.len);
    if (copied != length) return error.ProfileTextReadFailed;
    var result: Launch.BoundedText(capacity) = .{};
    if (length == 0) return result;
    const bytes = c.WideCharToMultiByte(c.CP_UTF8, c.WC_ERR_INVALID_CHARS, &encoded, length, &result.bytes, capacity, null, null);
    if (bytes <= 0) return error.InvalidOrOversizedUnicode;
    result.len = @intCast(bytes);
    return result;
}

fn readEntry(window: c.HWND) !Launch.NamedProfile {
    var entry: Launch.NamedProfile = .{};
    entry.name = try readField(window, field_ids[0], Launch.max_name_bytes);
    entry.profile.shell = try readField(window, field_ids[1], Launch.max_shell_bytes);
    entry.profile.command = try readField(window, field_ids[2], Launch.max_command_bytes);
    entry.profile.working_directory = try readField(window, field_ids[3], Launch.max_working_directory_bytes);
    entry.profile.environment = try readField(window, field_ids[4], Launch.max_environment_bytes);
    const scrollback = try readField(window, field_ids[5], 6);
    entry.profile.scrollback_lines = std.fmt.parseInt(u32, scrollback.slice(), 10) catch return error.InvalidLaunchScrollbackLines;
    entry.profile.kind = if (entry.profile.command.len == 0) .shell else .command;
    try entry.validateFor(.windows);
    try Profiles.validateProfile(&entry.profile);
    return entry;
}

fn save(window: c.HWND, state: *State) void {
    const entry = readEntry(window) catch |err| {
        switch (err) {
            error.InvalidLaunchShell => failure(window, "Executable must be a fully qualified drive or UNC path."),
            error.InvalidLaunchWorkingDirectory => failure(window, "Working directory must be empty or a fully qualified drive or UNC path."),
            error.InvalidLaunchScrollbackLines => failure(window, "Scrollback must be a whole number from 1 to 100000."),
            error.InvalidLaunchEnvironment, error.DuplicateLaunchEnvironmentKey => failure(window, "Use NAME=value;OTHER=value, at most 16 unique names (case-insensitive)."),
            error.InvalidLaunchProfileName => failure(window, "Enter a name of 1-64 UTF-8 bytes, without outer spaces or control characters."),
            else => failure(window, "Invalid or oversized text. Limits in UTF-8 bytes: name 64, executable 256, arguments 1024, directory 4096, environment 2048."),
        }
        return;
    };
    const cb = state.callbacks;
    const count = cb.profile_count(cb.userdata);
    var index: c_int = 2;
    while (index < count) : (index += 1) {
        if (index == state.index) continue;
        var other: Launch.NamedProfile = .{};
        if (cb.profile_get(cb.userdata, index, &other) != 0) {
            failure(window, "Could not read the profile library. Nothing was saved.");
            return;
        }
        if (other.name.len > other.name.bytes.len) return;
        if (std.ascii.eqlIgnoreCase(entry.name.slice(), other.name.slice())) {
            failure(window, "A different profile already uses this name. Choose a unique name.");
            return;
        }
    }
    if (cb.profile_save(cb.userdata, state.index, entry.name.bytes[0..].ptr, entry.name.len, &entry.profile) != 0) {
        failure(window, "Could not save the profile. Check the name, the 8-profile limit and storage permissions. The previous profile and selection are unchanged.");
        return;
    }
    if (!refresh(window, state, cb.profile_active(cb.userdata))) {
        failure(window, "Profile saved, but the list could not be refreshed. Close and reopen the manager.");
        return;
    }
    failure(window, "Saved and selected for future local sessions. Running sessions are unchanged.");
}

fn dialogProc(window: c.HWND, message: c.UINT, word: c.WPARAM, long_value: c.LPARAM) callconv(.winapi) c.INT_PTR {
    if (message == c.WM_INITDIALOG) {
        const state: *State = @ptrFromInt(@as(usize, @bitCast(long_value)));
        _ = c.SetWindowLongPtrW(window, c.GWLP_USERDATA, long_value);
        // Permit pastes beyond byte limits so Save rejects the complete input;
        // never truncate a Unicode field to a seemingly valid prefix.
        for (field_ids) |id| _ = c.SendDlgItemMessageW(window, id, c.EM_SETLIMITTEXT, 32767, 0);
        if (!refresh(window, state, state.callbacks.profile_active(state.callbacks.userdata))) {
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
        if (discard(window, state)) finish(window, state);
        return 1;
    }
    if (message != c.WM_COMMAND) return 0;
    const notification: u16 = @truncate(word >> 16);
    for (field_ids) |field| {
        if (id == field and notification == c.EN_CHANGE) {
            if (!state.loading) state.dirty = true;
            return 1;
        }
    }
    switch (id) {
        c.IDOK => save(window, state),
        new_id => {
            if (discard(window, state) and !fill(window, state, -1)) failure(window, "Could not clear the editor.");
        },
        delete_id => {
            if (state.index >= 2 and confirm(window, state, "Delete this saved profile and discard its editor changes? Running sessions will not be affected.")) {
                const cb = state.callbacks;
                if (cb.profile_remove(cb.userdata, state.index) != 0) {
                    failure(window, "Could not delete the profile. The library and selection are unchanged.");
                } else if (!refresh(window, state, cb.profile_active(cb.userdata))) {
                    failure(window, "Profile deleted, but the list could not be refreshed.");
                }
            }
        },
        list_id => {
            if (notification != c.LBN_SELCHANGE) return 0;
            const selected = c.SendDlgItemMessageW(window, list_id, c.LB_GETCURSEL, 0, 0);
            if (selected < 0) return 1;
            if (!discard(window, state)) {
                _ = c.SendDlgItemMessageW(window, list_id, c.LB_SETCURSEL, if (state.index >= 2) @intCast(state.index - 2) else std.math.maxInt(usize), 0);
            } else if (!fill(window, state, @intCast(selected + 2))) failure(window, "Could not load the selected profile.");
        },
        else => return 0,
    }
    return 1;
}

// DWORD-aligned standard dialog template, matching the native font/tab editors.
const Template = struct {
    words: [2048]u16 align(4) = @splat(0),
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
    result.word(20);
    result.word(0);
    result.word(0);
    result.word(470);
    result.word(292);
    result.word(0);
    result.word(0);
    result.text("Manage launch profiles");
    result.word(9);
    result.text("Segoe UI");
    result.control(0, 10, 8, 450, 22, 0xffff, 0x82, "Profiles apply only to future local sessions. PowerShell and Command Prompt remain available in the menu.");
    result.control(0, 10, 34, 124, 12, 0xffff, 0x82, "Saved custom &profiles:");
    result.control(c.WS_TABSTOP | c.WS_BORDER | c.WS_VSCROLL | c.LBS_NOTIFY | c.LBS_NOINTEGRALHEIGHT, 10, 48, 124, 170, list_id, 0x83, "");
    inline for (.{ "&Name:", "&Executable (absolute path):", "&Arguments (Windows command line):", "Working director&y (optional):", "En&vironment (NAME=value;OTHER=value):", "Sc&rollback (1-100000 lines):" }, 0..) |label, index| {
        const y: u16 = 34 + @as(u16, @intCast(index)) * 32;
        result.control(0, 146, y, 312, 12, 0xffff, 0x82, label);
        result.control(c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL, 146, y + 12, 312, 17, field_ids[index], 0x81, "");
    }
    result.control(0, 10, 228, 450, 34, error_id, 0x82, "");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 10, 268, 60, 16, new_id, 0x80, "Ne&w");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 78, 268, 60, 16, delete_id, 0x80, "&Delete...");
    result.control(c.WS_TABSTOP | c.BS_DEFPUSHBUTTON, 282, 268, 96, 16, c.IDOK, 0x80, "&Save and select");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 390, 268, 68, 16, c.IDCANCEL, 0x80, "&Close");
    return result;
}

/// Reloads the actual atomic profile envelope and compares consumer-visible state.
pub fn qualifyDurable(cb: *const Abi.Callbacks) bool {
    var bytes: [Profiles.max_state_bytes]u8 = undefined;
    const length = (Dpapi.profileStateLoad(&bytes) catch return false) orelse return false;
    const reopened = Profiles.decodeState(bytes[0..length]) catch return false;
    if (reopened.count() != cb.profile_count(cb.userdata) or reopened.selected != cb.profile_active(cb.userdata)) return false;
    var index: c_int = 2;
    while (index < cb.profile_count(cb.userdata)) : (index += 1) {
        var actual: Launch.NamedProfile = .{};
        if (cb.profile_get(cb.userdata, index, &actual) != 0) return false;
        const expected = reopened.get(@intCast(index)) orelse return false;
        if (!std.mem.eql(u8, expected.name.slice(), actual.name.slice()) or !expected.profile.eql(&actual.profile)) return false;
    }
    return true;
}

fn command(window: c.HWND, id: u16) void {
    _ = c.SendMessageW(window, c.WM_COMMAND, id, 0);
}

fn rejected(window: c.HWND, state: *State, expected_count: c_int, expected_active: c_int) bool {
    command(window, c.IDOK);
    return c.IsWindow(window) != 0 and
        c.GetWindowTextLengthW(c.GetDlgItem(window, error_id)) > 0 and
        state.callbacks.profile_count(state.callbacks.userdata) == expected_count and
        state.callbacks.profile_active(state.callbacks.userdata) == expected_active and
        qualifyDurable(state.callbacks);
}

/// Requires the isolated, initially empty native-smoke profile store.
/// No process is launched. All edits use production HWNDs and durable callbacks.
pub fn qualify(parent: c.HWND, cb: *const Abi.Callbacks) bool {
    if (cb.profile_count(cb.userdata) != 2) return false;
    var state = State{ .callbacks = cb, .modal = false, .confirmation = false };
    var template = dialogTemplate();
    const dialog = c.CreateDialogIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, dialogProc, pointer(&state)) orelse return false;
    defer {
        if (c.IsWindow(dialog) != 0) _ = c.DestroyWindow(dialog);
    }
    if (state.failed or c.IsWindowVisible(dialog) != 0) return false;
    if (!setText(dialog, field_ids[0], "Native & 中") or
        !setText(dialog, field_ids[1], "C:\\工具\\shell.exe") or
        !setText(dialog, field_ids[2], "--title \"native 中\"") or
        !setText(dialog, field_ids[3], "C:\\工作") or
        !setText(dialog, field_ids[4], "TERM=custom;VALUE=中") or
        !setText(dialog, field_ids[5], "4321")) return false;
    command(dialog, c.IDOK);
    if (cb.profile_count(cb.userdata) != 3 or cb.profile_active(cb.userdata) != 2 or state.dirty or !qualifyDurable(cb)) return false;
    var original: Launch.NamedProfile = .{};
    if (cb.profile_get(cb.userdata, 2, &original) != 0 or original.profile.scrollback_lines != 4321) return false;

    // Invalid text is rejected whole, including malformed UTF-16 from a native control.
    inline for (.{ .{ 1, "" }, .{ 1, "relative.exe" }, .{ 1, "C:relative.exe" }, .{ 3, "\\relative" }, .{ 4, "Path=a;PATH=b" }, .{ 5, "0" }, .{ 5, "100001" }, .{ 5, "abc" }, .{ 0, " leading" } }) |invalid| {
        if (!fill(dialog, &state, 2) or !setText(dialog, field_ids[invalid[0]], invalid[1]) or !rejected(dialog, &state, 3, 2)) return false;
        var entry: Launch.NamedProfile = .{};
        if (cb.profile_get(cb.userdata, 2, &entry) != 0 or !entry.profile.eql(&original.profile) or !std.mem.eql(u8, entry.name.slice(), original.name.slice())) return false;
    }
    inline for (.{ .{ 0, Launch.max_name_bytes }, .{ 1, Launch.max_shell_bytes }, .{ 2, Launch.max_command_bytes }, .{ 3, Launch.max_working_directory_bytes }, .{ 4, Launch.max_environment_bytes } }) |field| {
        if (!fill(dialog, &state, 2)) return false;
        var oversized: [field[1] + 2]u16 = @splat('a');
        oversized[oversized.len - 1] = 0;
        _ = c.SetDlgItemTextW(dialog, field_ids[field[0]], &oversized);
        if (!rejected(dialog, &state, 3, 2)) return false;
    }
    if (!fill(dialog, &state, 2)) return false;
    const malformed = [_:0]u16{0xd800};
    _ = c.SetDlgItemTextW(dialog, field_ids[1], &malformed);
    if (!rejected(dialog, &state, 3, 2)) return false;
    if (!fill(dialog, &state, 2)) return false;
    if (!setText(dialog, field_ids[0], &repeatBytes("中", 22)) or !rejected(dialog, &state, 3, 2)) return false;

    // Rename, duplicate rejection, and exact supported byte boundaries.
    if (!fill(dialog, &state, 2) or !setText(dialog, field_ids[0], "Renamed")) return false;
    command(dialog, c.IDOK);
    if (state.dirty or cb.profile_count(cb.userdata) != 3 or !qualifyDurable(cb)) return false;
    command(dialog, new_id);
    if (!setText(dialog, field_ids[0], "renamed") or !setText(dialog, field_ids[1], "C:\\shell.exe") or !rejected(dialog, &state, 3, 2)) return false;
    state.confirmation = true;
    command(dialog, new_id);
    if (!setText(dialog, field_ids[0], &repeatBytes("N", Launch.max_name_bytes)) or
        !setText(dialog, field_ids[1], "C:\\" ++ repeatBytes("x", Launch.max_shell_bytes - 3)) or
        !setText(dialog, field_ids[2], &repeatBytes("a", Launch.max_command_bytes)) or
        !setText(dialog, field_ids[3], "C:\\" ++ repeatBytes("x", Launch.max_working_directory_bytes - 3)) or
        !setText(dialog, field_ids[4], "X=" ++ repeatBytes("v", Launch.max_environment_bytes - 2)) or
        !setText(dialog, field_ids[5], "100000")) return false;
    command(dialog, c.IDOK);
    if (state.dirty or cb.profile_count(cb.userdata) != 4 or cb.profile_active(cb.userdata) != 3 or !qualifyDurable(cb)) return false;

    // Declining unsaved-change prompts preserves edits and selection on all exits.
    state.confirmation = false;
    if (!setText(dialog, field_ids[0], "Unsaved") or !state.dirty) return false;
    command(dialog, new_id);
    if (!state.dirty or state.index != 3) return false;
    _ = c.SendDlgItemMessageW(dialog, list_id, c.LB_SETCURSEL, 0, 0);
    _ = c.SendMessageW(dialog, c.WM_COMMAND, list_id | (@as(usize, c.LBN_SELCHANGE) << 16), 0);
    if (state.index != 3 or !state.dirty or c.SendDlgItemMessageW(dialog, list_id, c.LB_GETCURSEL, 0, 0) != 1) return false;
    command(dialog, c.IDCANCEL);
    command(dialog, delete_id);
    if (c.IsWindow(dialog) == 0 or cb.profile_count(cb.userdata) != 4 or !qualifyDurable(cb)) return false;
    state.confirmation = true;
    // Loading an entry changes only the editor, not the selected launch profile.
    _ = c.SendDlgItemMessageW(dialog, list_id, c.LB_SETCURSEL, 0, 0);
    _ = c.SendMessageW(dialog, c.WM_COMMAND, list_id | (@as(usize, c.LBN_SELCHANGE) << 16), 0);
    if (state.index != 2 or state.dirty or cb.profile_active(cb.userdata) != 3) return false;

    var next: c_int = 4;
    while (next < 10) : (next += 1) {
        command(dialog, new_id);
        var name: [32]u8 = undefined;
        const label = std.fmt.bufPrint(&name, "Profile {d}", .{next}) catch return false;
        if (!setText(dialog, field_ids[0], label) or !setText(dialog, field_ids[1], "C:\\shell.exe")) return false;
        command(dialog, c.IDOK);
        if (state.dirty or cb.profile_count(cb.userdata) != next + 1 or cb.profile_active(cb.userdata) != next or !qualifyDurable(cb)) return false;
    }
    if (c.IsWindowEnabled(c.GetDlgItem(dialog, new_id)) != 0) return false;
    if (cb.profile_save(cb.userdata, -1, "Overflow", 8, &original.profile) != -1 or
        cb.profile_select(cb.userdata, 10) != -1 or cb.profile_remove(cb.userdata, 0) != -1 or
        cb.profile_save(cb.userdata, 1, "Builtin", 7, &original.profile) != -1 or !qualifyDurable(cb)) return false;
    var invalid_profile = original.profile;
    invalid_profile.shell.len = Launch.max_shell_bytes + 1;
    if (cb.profile_save(cb.userdata, 2, "Bounds", 6, &invalid_profile) != -1) return false;
    invalid_profile = original.profile;
    invalid_profile.shell.bytes[3] = 0xff;
    if (cb.profile_save(cb.userdata, 2, "Utf8", 4, &invalid_profile) != -1 or !qualifyDurable(cb)) return false;

    // Delete the selected custom profile: production backend falls back to builtin.
    command(dialog, delete_id);
    if (cb.profile_count(cb.userdata) != 9 or cb.profile_active(cb.userdata) >= 2 or !qualifyDurable(cb)) return false;
    while (cb.profile_count(cb.userdata) > 3) {
        if (!fill(dialog, &state, cb.profile_count(cb.userdata) - 1)) return false;
        command(dialog, delete_id);
        if (!qualifyDurable(cb)) return false;
    }
    if (!fill(dialog, &state, 2) or !setText(dialog, field_ids[0], "Cancelled edit")) return false;
    command(dialog, c.IDCANCEL);
    if (c.IsWindow(dialog) != 0 or cb.profile_count(cb.userdata) != 3 or !qualifyDurable(cb)) return false;
    var saved: Launch.NamedProfile = .{};
    return cb.profile_get(cb.userdata, 2, &saved) == 0 and std.mem.eql(u8, saved.name.slice(), "Renamed");
}

fn wide(comptime text: []const u8) [*:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}
