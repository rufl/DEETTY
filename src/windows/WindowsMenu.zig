//! Native Windows terminal menu construction and checked-state updates.
//!
//! Once attached, the HWND owns the HMENU tree. This adapter retains only a
//! bounded descriptor for updating submenu state and frees that descriptor.

const Logic = @import("WindowsHostLogic.zig");
const Appearance = @import("WindowsAppearance.zig");
const Abi = @import("WindowsHostAbi.zig");

const c = @cImport({
    @cDefine("UNICODE", "1");
    @cDefine("_UNICODE", "1");
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("windows.h");
});

const id_theme_dark = Logic.menu_theme_dark;
const id_theme_high_contrast = Logic.menu_theme_high_contrast;
const id_theme_zinc = Logic.menu_theme_zinc;
pub const id_font_custom = Logic.menu_font_custom;
pub const id_font_increase = Logic.menu_font_increase;
pub const id_font_decrease = Logic.menu_font_decrease;
pub const id_font_reset = Logic.menu_font_reset;
const id_font_11 = Logic.menu_font_11;
const id_font_13 = Logic.menu_font_13;
const id_font_16 = Logic.menu_font_16;
const id_font_18 = Logic.menu_font_18;
const id_profile_powershell = Logic.menu_profile_powershell;
const id_profile_command = Logic.menu_profile_command;
const id_restore_startup = Logic.menu_restore_startup;
const id_workspace_save = Logic.menu_workspace_save;
const id_workspace_restore = Logic.menu_workspace_restore;
const id_open_nocted = Logic.menu_open_nocted;

pub const id_new_tab: u32 = 40101;
pub const id_split_down: u32 = 40102;
pub const id_split_left: u32 = 40103;
pub const id_next_pane: u32 = 40104;
pub const id_next_tab: u32 = 40105;
pub const id_close_pane: u32 = 40106;
pub const id_close_tab: u32 = 40107;
pub const id_rename_tab: u32 = 40108;
pub const id_move_tab_left: u32 = 40109;
pub const id_move_tab_right: u32 = 40110;
pub const id_focus_tabs: u32 = 40111;
pub const id_divider_reset: u32 = 40112;
pub const id_divider_wider: u32 = 40113;
pub const id_divider_narrower: u32 = 40114;
pub const id_divider_taller: u32 = 40115;
pub const id_divider_shorter: u32 = 40116;
pub const id_copy: u32 = 40201;
pub const id_paste: u32 = 40202;
pub const id_clear_screen: u32 = 40203;
pub const id_theme_import: u32 = 40500;
pub const id_theme_export: u32 = 40501;
pub const id_theme_custom: u32 = 40600;
pub const id_broadcast: u32 = 40117;
pub const id_tag_focused: u32 = 40118;
pub const id_smart_filter: u32 = 40119;
pub const max_custom_themes: u32 = 64;
pub const id_profile_manage: u32 = 40700;
pub const id_profile_custom: u32 = 40800;
pub const max_custom_profiles: u32 = 8;

const local_commands = [_]u32{
    id_new_tab,        id_split_down,        id_split_left,       id_close_pane,     id_close_tab,
    id_workspace_save, id_workspace_restore, id_rename_tab,       id_move_tab_left,  id_move_tab_right,
    id_divider_reset,  id_divider_wider,     id_divider_narrower, id_divider_taller, id_divider_shorter,
    id_broadcast,      id_tag_focused,       id_smart_filter,
};

pub const Menu = struct {
    window: c.HWND,
    root: c.HMENU,
    settings: c.HMENU,
    theme: c.HMENU,
    font: c.HMENU,
    profile: c.HMENU,
    workspace: c.HMENU,
    terminal: c.HMENU,
};

pub export fn noctty_windows_menu_create(window: c.HWND) ?*Menu {
    if (window == null) return null;
    const root = c.CreateMenu() orelse return null;
    var root_owned = true;
    defer {
        if (root_owned) _ = c.DestroyMenu(root);
    }
    const settings = c.CreatePopupMenu() orelse return null;
    var settings_owned = true;
    defer {
        if (settings_owned) _ = c.DestroyMenu(settings);
    }
    const theme = c.CreatePopupMenu() orelse return null;
    var theme_owned = true;
    defer {
        if (theme_owned) _ = c.DestroyMenu(theme);
    }
    const font = c.CreatePopupMenu() orelse return null;
    var font_owned = true;
    defer {
        if (font_owned) _ = c.DestroyMenu(font);
    }
    const profile = c.CreatePopupMenu() orelse return null;
    var profile_owned = true;
    defer {
        if (profile_owned) _ = c.DestroyMenu(profile);
    }
    const workspace = c.CreatePopupMenu() orelse return null;
    var workspace_owned = true;
    defer {
        if (workspace_owned) _ = c.DestroyMenu(workspace);
    }
    const terminal = c.CreatePopupMenu() orelse return null;
    var terminal_owned = true;
    defer {
        if (terminal_owned) _ = c.DestroyMenu(terminal);
    }

    if (!append(theme, c.MF_STRING, id_theme_dark, "&Dark") or
        !append(theme, c.MF_STRING, id_theme_high_contrast, "&High contrast") or
        !append(theme, c.MF_STRING, id_theme_zinc, "&Paseo Black Zinc") or
        c.AppendMenuW(theme, c.MF_SEPARATOR, 0, null) == 0 or
        !append(theme, c.MF_STRING, id_theme_import, "&Import library...") or
        !append(theme, c.MF_STRING, id_theme_export, "&Export library...") or
        !append(font, c.MF_STRING, id_font_11, "11 pt") or
        !append(font, c.MF_STRING, id_font_13, "13 pt") or
        !append(font, c.MF_STRING, id_font_16, "16 pt") or
        !append(font, c.MF_STRING, id_font_18, "18 pt") or
        c.AppendMenuW(font, c.MF_SEPARATOR, 0, null) == 0 or
        !append(font, c.MF_STRING, id_font_custom, "&Custom size... (8-32 pt)") or
        !append(font, c.MF_STRING, id_font_increase, "&Increase by 1 pt") or
        !append(font, c.MF_STRING, id_font_decrease, "&Decrease by 1 pt") or
        !append(font, c.MF_STRING, id_font_reset, "&Reset to 13 pt") or
        !append(profile, c.MF_STRING, id_profile_powershell, "&PowerShell") or
        !append(profile, c.MF_STRING, id_profile_command, "&Command Prompt") or
        c.AppendMenuW(profile, c.MF_SEPARATOR, 0, null) == 0 or
        !append(profile, c.MF_STRING, id_profile_manage, "&Manage profiles...") or
        !append(settings, c.MF_STRING, id_restore_startup, "&Restore saved workspace on startup") or
        !append(workspace, c.MF_STRING, id_new_tab, "&New Tab\tCtrl+Shift+T") or
        !append(workspace, c.MF_STRING, id_split_down, "Split &Down\tCtrl+Shift+S") or
        !append(workspace, c.MF_STRING, id_split_left, "Split &Left\tCtrl+Shift+L") or
        c.AppendMenuW(workspace, c.MF_SEPARATOR, 0, null) == 0 or
        !append(workspace, c.MF_STRING, id_next_pane, "Next &Pane\tCtrl+Tab") or
        !append(workspace, c.MF_STRING, id_next_tab, "Next &Tab\tCtrl+Shift+Tab") or
        !append(workspace, c.MF_STRING, id_focus_tabs, "&Focus Tab Strip (arrow keys; Enter returns)") or
        !append(workspace, c.MF_STRING, id_rename_tab, "&Rename Tab... (F2 in tab strip)") or
        !append(workspace, c.MF_STRING, id_move_tab_left, "Move Tab L&eft") or
        !append(workspace, c.MF_STRING, id_move_tab_right, "Move Tab R&ight") or
        !append(workspace, c.MF_STRING, id_close_pane, "&Close Pane\tCtrl+D") or
        !append(workspace, c.MF_STRING, id_close_tab, "Close Ta&b\tCtrl+Shift+W") or
        !append(workspace, c.MF_STRING, id_broadcast, "&Broadcast input\tCtrl+Shift+B") or
        !append(workspace, c.MF_STRING, id_tag_focused, "Tag focused pane\tCtrl+Shift+Y") or
        !append(workspace, c.MF_STRING, id_smart_filter, "Smart Tab filter\tCtrl+Shift+G") or
        !append(workspace, c.MF_STRING, id_divider_wider, "Make focused pane &Wider") or
        !append(workspace, c.MF_STRING, id_divider_narrower, "Make focused pane N&arrower") or
        !append(workspace, c.MF_STRING, id_divider_taller, "Make focused pane Ta&ller") or
        !append(workspace, c.MF_STRING, id_divider_shorter, "Make focused pane S&horter") or
        !append(workspace, c.MF_STRING, id_divider_reset, "E&qualize all splits in tab") or
        c.AppendMenuW(workspace, c.MF_SEPARATOR, 0, null) == 0 or
        !append(terminal, c.MF_STRING, id_copy, "&Copy\tCtrl+Shift+C") or
        !append(terminal, c.MF_STRING, id_paste, "&Paste\tCtrl+Shift+V") or
        !append(terminal, c.MF_STRING, id_clear_screen, "C&lear Screen\tCtrl+L") or
        !append(workspace, c.MF_STRING, id_workspace_save, "&Save current layout") or
        !append(workspace, c.MF_STRING, id_workspace_restore, "&Restore saved layout..."))
    {
        return null;
    }
    if (c.AppendMenuW(settings, c.MF_POPUP, @intFromPtr(theme), wide("&Theme")) == 0) return null;
    theme_owned = false;
    if (c.AppendMenuW(
        settings,
        c.MF_POPUP,
        @intFromPtr(font),
        wide("&Font size"),
    ) == 0) return null;
    font_owned = false;
    if (c.AppendMenuW(settings, c.MF_POPUP, @intFromPtr(profile), wide("&Launch profile")) == 0) {
        return null;
    }
    profile_owned = false;
    if (c.AppendMenuW(root, c.MF_POPUP, @intFromPtr(settings), wide("&Settings")) == 0) return null;
    settings_owned = false;
    if (c.AppendMenuW(root, c.MF_POPUP, @intFromPtr(workspace), wide("&Workspace")) == 0) {
        return null;
    }
    workspace_owned = false;
    if (c.AppendMenuW(root, c.MF_POPUP, @intFromPtr(terminal), wide("&Terminal")) == 0) return null;
    terminal_owned = false;
    if (!append(root, c.MF_STRING, id_open_nocted, "Open &NoctEd")) return null;

    const heap = c.GetProcessHeap() orelse return null;
    const raw_menu = c.HeapAlloc(heap, 0, @sizeOf(Menu)) orelse return null;
    const menu: *Menu = @ptrCast(@alignCast(raw_menu));
    menu.* = .{
        .window = window,
        .root = root,
        .settings = settings,
        .theme = theme,
        .font = font,
        .profile = profile,
        .workspace = workspace,
        .terminal = terminal,
    };
    if (c.SetMenu(window, root) == 0) {
        _ = c.HeapFree(heap, 0, menu);
        return null;
    }
    root_owned = false;
    return menu;
}

pub export fn noctty_windows_menu_update(
    optional_menu: ?*Menu,
    theme_value: c_int,
    font_size_pt: c_int,
    launch_profile: c_int,
    restore_workspace: c_int,
    remote_mode: c_int,
) void {
    const menu = optional_menu orelse return;
    for ([_]u32{ id_theme_dark, id_theme_high_contrast, id_theme_zinc }, 0..) |command, index| {
        _ = c.CheckMenuItem(menu.theme, command, @intCast(c.MF_BYCOMMAND | (if (theme_value == @as(c_int, @intCast(index))) c.MF_CHECKED else c.MF_UNCHECKED)));
    }
    for (0..max_custom_themes) |index| {
        _ = c.CheckMenuItem(menu.theme, id_theme_custom + @as(u32, @intCast(index)), @intCast(c.MF_BYCOMMAND | (if (theme_value == @as(c_int, @intCast(index)) + 3) c.MF_CHECKED else c.MF_UNCHECKED)));
    }
    const font_command: c.UINT = switch (font_size_pt) {
        11 => id_font_11,
        16 => id_font_16,
        18 => id_font_18,
        13 => id_font_13,
        else => 0,
    };
    _ = c.CheckMenuRadioItem(menu.font, id_font_11, id_font_18, font_command, c.MF_BYCOMMAND);
    _ = c.CheckMenuItem(menu.font, id_font_custom, @intCast(c.MF_BYCOMMAND | (if (font_command == 0) c.MF_CHECKED else c.MF_UNCHECKED)));
    _ = c.EnableMenuItem(menu.font, id_font_increase, @intCast(c.MF_BYCOMMAND | (if (font_size_pt >= Appearance.max_font_size) c.MF_GRAYED else c.MF_ENABLED)));
    _ = c.EnableMenuItem(menu.font, id_font_decrease, @intCast(c.MF_BYCOMMAND | (if (font_size_pt <= Appearance.min_font_size) c.MF_GRAYED else c.MF_ENABLED)));
    _ = c.EnableMenuItem(menu.font, id_font_reset, @intCast(c.MF_BYCOMMAND | (if (font_size_pt == Appearance.default_font_size) c.MF_GRAYED else c.MF_ENABLED)));
    _ = c.CheckMenuRadioItem(
        menu.profile,
        id_profile_powershell,
        id_profile_command,
        if (launch_profile == 0) id_profile_powershell else if (launch_profile == 1) id_profile_command else 0,
        c.MF_BYCOMMAND,
    );
    for (0..max_custom_profiles) |index| {
        _ = c.CheckMenuItem(menu.profile, id_profile_custom + @as(u32, @intCast(index)), @intCast(c.MF_BYCOMMAND | (if (launch_profile == @as(c_int, @intCast(index)) + 2) c.MF_CHECKED else c.MF_UNCHECKED)));
    }
    _ = c.CheckMenuItem(
        menu.settings,
        id_restore_startup,
        @as(c.UINT, @intCast(c.MF_BYCOMMAND)) |
            @as(c.UINT, @intCast(if (restore_workspace != 0) c.MF_CHECKED else c.MF_UNCHECKED)),
    );
    const workspace_state: c.UINT = @intCast(
        if (remote_mode != 0) c.MF_GRAYED else c.MF_ENABLED,
    );
    const command_state = @as(c.UINT, @intCast(c.MF_BYCOMMAND)) | workspace_state;
    _ = c.EnableMenuItem(menu.settings, id_restore_startup, command_state);
    for (local_commands) |command| _ = c.EnableMenuItem(menu.workspace, command, command_state);
    _ = c.ModifyMenuW(menu.workspace, id_next_pane, c.MF_BYCOMMAND | c.MF_STRING, id_next_pane, if (remote_mode != 0)
        wide("Next &Pane\tCtrl+Shift+Tab")
    else
        wide("Next &Pane\tCtrl+Tab"));
    _ = c.ModifyMenuW(menu.workspace, id_next_tab, c.MF_BYCOMMAND | c.MF_STRING, id_next_tab, if (remote_mode != 0)
        wide("Next &Tab\tCtrl+Tab")
    else
        wide("Next &Tab\tCtrl+Shift+Tab"));
    _ = c.DrawMenuBar(menu.window);
}

/// Rebuild only the custom tail after the library changes. The attached menu
/// remains owned by the HWND; AppendMenuW copies each temporary UTF-16 label.
pub fn refreshThemes(menu: *Menu, callbacks: *const Abi.Callbacks) bool {
    while (c.GetMenuItemCount(menu.theme) > 6) {
        if (c.DeleteMenu(menu.theme, 6, c.MF_BYPOSITION) == 0) return false;
    }
    const count = callbacks.theme_count(callbacks.userdata);
    if (count < 3 or count > 3 + max_custom_themes) return false;
    var index: c_int = 3;
    while (index < count) : (index += 1) {
        var name: [96]u8 = undefined;
        const length = callbacks.theme_name(callbacks.userdata, index, &name, name.len);
        if (length <= 0 or length > name.len) return false;
        var decoded: [96]u16 = undefined;
        const units = c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, &name, length, &decoded, decoded.len);
        if (units <= 0) return false;
        var label: [193]u16 = undefined;
        var used: usize = 0;
        for (decoded[0..@intCast(units)]) |unit| {
            label[used] = unit;
            used += 1;
            if (unit == '&') {
                label[used] = '&';
                used += 1;
            }
        }
        label[used] = 0;
        if (c.AppendMenuW(menu.theme, c.MF_STRING, id_theme_custom + @as(u32, @intCast(index - 3)), @ptrCast(&label)) == 0) return false;
    }
    return true;
}

pub fn qualifyThemes(menu: *const Menu, count: c_int, active: c_int) bool {
    if (count < 3 or c.GetMenuItemCount(menu.theme) != count + 3 or
        !commandStateMatches(menu.theme, id_theme_import, false) or
        !commandStateMatches(menu.theme, id_theme_export, false)) return false;
    var index: c_int = 0;
    while (index < count) : (index += 1) {
        const command = if (index < 3) @as(u32, @intCast(index)) + id_theme_dark else id_theme_custom + @as(u32, @intCast(index - 3));
        const state = c.GetMenuState(menu.theme, command, c.MF_BYCOMMAND);
        if (state == @import("std").math.maxInt(c.UINT) or ((state & c.MF_CHECKED) != 0) != (index == active)) return false;
    }
    return true;
}

pub fn refreshProfiles(menu: *Menu, callbacks: *const Abi.Callbacks) bool {
    while (c.GetMenuItemCount(menu.profile) > 4) {
        if (c.DeleteMenu(menu.profile, 4, c.MF_BYPOSITION) == 0) return false;
    }
    const count = callbacks.profile_count(callbacks.userdata);
    if (count < 2 or count > 2 + max_custom_profiles) return false;
    var index: c_int = 2;
    while (index < count) : (index += 1) {
        var name: [64]u8 = undefined;
        const length = callbacks.profile_name(callbacks.userdata, index, &name, name.len);
        if (length <= 0 or length > name.len) return false;
        var decoded: [64]u16 = undefined;
        const units = c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, &name, length, &decoded, decoded.len);
        if (units <= 0) return false;
        var label: [129]u16 = undefined;
        var used: usize = 0;
        for (decoded[0..@intCast(units)]) |unit| {
            label[used] = unit;
            used += 1;
            if (unit == '&') {
                label[used] = '&';
                used += 1;
            }
        }
        label[used] = 0;
        if (c.AppendMenuW(menu.profile, c.MF_STRING, id_profile_custom + @as(u32, @intCast(index - 2)), @ptrCast(&label)) == 0) return false;
    }
    return true;
}

pub fn qualifyProfiles(menu: *const Menu, count: c_int, active: c_int) bool {
    if (count < 2 or c.GetMenuItemCount(menu.profile) != count + 2 or
        !commandStateMatches(menu.profile, id_profile_manage, false)) return false;
    var index: c_int = 0;
    while (index < count) : (index += 1) {
        const command = if (index == 0) id_profile_powershell else if (index == 1) id_profile_command else id_profile_custom + @as(u32, @intCast(index - 2));
        const state = c.GetMenuState(menu.profile, command, c.MF_BYCOMMAND);
        if (state == @import("std").math.maxInt(c.UINT) or
            (state & (c.MF_DISABLED | c.MF_GRAYED)) != 0 or
            ((state & c.MF_CHECKED) != 0) != (index == active)) return false;
    }
    return true;
}

/// Inspect the real Win32 menu, including disabled commands and displayed hints.
/// Used only by the bounded, hidden-window host qualification mode.
pub fn qualifyStateCode(menu: *const Menu, remote_mode: bool) u32 {
    var code: u32 = 0;
    if (c.GetMenu(menu.window) != menu.root or
        c.GetMenuItemCount(menu.root) != 4 or
        c.GetSubMenu(menu.root, 0) != menu.settings or
        c.GetSubMenu(menu.root, 1) != menu.workspace or
        c.GetSubMenu(menu.root, 2) != menu.terminal or
        c.GetMenuItemCount(menu.workspace) != 23 or
        c.GetMenuItemCount(menu.terminal) != 3) code |= 1;
    for (local_commands) |command| {
        if (!commandStateMatches(menu.workspace, command, remote_mode)) {
            code |= 2;
            break;
        }
    }
    for ([_]u32{ id_next_pane, id_next_tab }) |command| {
        if (!commandStateMatches(menu.workspace, command, false)) code |= 4;
    }
    for ([_]u32{ id_copy, id_paste, id_clear_screen }) |command| {
        if (!commandStateMatches(menu.terminal, command, false)) code |= 8;
    }
    if (!commandStateMatches(menu.root, id_open_nocted, false) or
        !commandStateMatches(menu.settings, id_restore_startup, remote_mode) or
        !commandStateMatches(menu.profile, id_profile_powershell, false) or
        !commandStateMatches(menu.profile, id_profile_command, false) or
        !commandStateMatches(menu.profile, id_profile_manage, false)) code |= 16;
    const hints_ok = if (remote_mode)
        commandTextMatches(menu.workspace, id_next_pane, "Next &Pane\tCtrl+Shift+Tab") and
            commandTextMatches(menu.workspace, id_next_tab, "Next &Tab\tCtrl+Tab")
    else
        commandTextMatches(menu.workspace, id_next_pane, "Next &Pane\tCtrl+Tab") and
            commandTextMatches(menu.workspace, id_next_tab, "Next &Tab\tCtrl+Shift+Tab");
    if (!hints_ok) code |= 32;
    return code;
}

pub fn qualifyHintLengths(menu: *const Menu) u32 {
    var text: [64]u16 = undefined;
    const pane_by_command = c.GetMenuStringW(menu.workspace, id_next_pane, &text, text.len, c.MF_BYCOMMAND);
    const tab_by_command = c.GetMenuStringW(menu.workspace, id_next_tab, &text, text.len, c.MF_BYCOMMAND);
    const pane_by_position = c.GetMenuStringW(menu.workspace, 4, &text, text.len, c.MF_BYPOSITION);
    const tab_by_position = c.GetMenuStringW(menu.workspace, 5, &text, text.len, c.MF_BYPOSITION);
    return (@as(u32, @intCast(@max(pane_by_command, 0))) << 24) |
        (@as(u32, @intCast(@max(tab_by_command, 0))) << 16) |
        (@as(u32, @intCast(@max(pane_by_position, 0))) << 8) |
        @as(u32, @intCast(@max(tab_by_position, 0)));
}

fn commandStateMatches(menu: c.HMENU, command: u32, disabled: bool) bool {
    const state = c.GetMenuState(menu, command, c.MF_BYCOMMAND);
    if (state == @import("std").math.maxInt(c.UINT)) return false;
    return ((state & (c.MF_DISABLED | c.MF_GRAYED)) != 0) == disabled;
}

fn commandTextMatches(menu: c.HMENU, command: u32, comptime expected: []const u8) bool {
    var text: [64]u16 = undefined;
    var info: c.MENUITEMINFOW = @import("std").mem.zeroes(c.MENUITEMINFOW);
    info.cbSize = @sizeOf(c.MENUITEMINFOW);
    info.fMask = c.MIIM_STRING;
    info.dwTypeData = &text;
    info.cch = text.len;
    if (c.GetMenuItemInfoW(menu, command, c.FALSE, &info) == 0) return false;
    const expected_wide = @import("std").unicode.utf8ToUtf16LeStringLiteral(expected);
    return info.cch == expected_wide.len and
        @import("std").mem.eql(u16, text[0..expected_wide.len], expected_wide);
}
pub fn qualifyState(menu: *const Menu, remote_mode: bool) bool {
    return qualifyStateCode(menu, remote_mode) == 0;
}

/// Reserve only actual menu mnemonics; unmatched Alt chords remain terminal input.
pub fn isMnemonic(optional_menu: ?*Menu, character: u16) bool {
    const menu = optional_menu orelse return false;
    var index: c_int = 0;
    while (index < c.GetMenuItemCount(menu.root)) : (index += 1) {
        var text: [128]u16 = undefined;
        const length = c.GetMenuStringW(menu.root, @intCast(index), &text, text.len, c.MF_BYPOSITION);
        var position: usize = 0;
        while (position + 1 < @as(usize, @intCast(@max(length, 0)))) : (position += 1) {
            if (text[position] != '&') continue;
            position += 1;
            if (text[position] != '&' and
                @import("std").ascii.toLower(@as(u8, @truncate(text[position]))) ==
                    @import("std").ascii.toLower(@as(u8, @truncate(character))) and character < 128) return true;
        }
    }
    return false;
}

pub export fn noctty_windows_menu_deinit(optional_menu: ?*Menu) void {
    const menu = optional_menu orelse return;
    const heap = c.GetProcessHeap() orelse return;
    _ = c.HeapFree(heap, 0, menu);
}

fn append(menu: c.HMENU, flags: c.UINT, item: c.UINT_PTR, comptime text: []const u8) bool {
    return c.AppendMenuW(menu, flags, item, wide(text)) != 0;
}

fn wide(comptime text: []const u8) [*:0]const u16 {
    return @ptrCast(@import("std").unicode.utf8ToUtf16LeStringLiteral(text));
}
