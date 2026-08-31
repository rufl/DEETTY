//! Native Windows terminal menu construction and checked-state updates.
//!
//! Once attached, the HWND owns the HMENU tree. This adapter retains only a
//! bounded descriptor for updating submenu state and frees that descriptor.

const Logic = @import("WindowsHostLogic.zig");

const c = @cImport({
    @cDefine("UNICODE", "1");
    @cDefine("_UNICODE", "1");
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("windows.h");
});

const id_theme_dark = Logic.menu_theme_dark;
const id_theme_high_contrast = Logic.menu_theme_high_contrast;
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

const Menu = struct {
    window: c.HWND,
    root: c.HMENU,
    settings: c.HMENU,
    theme: c.HMENU,
    font: c.HMENU,
    profile: c.HMENU,
    workspace: c.HMENU,
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

    if (!append(theme, c.MF_STRING, id_theme_dark, "&Dark") or
        !append(theme, c.MF_STRING, id_theme_high_contrast, "&High contrast") or
        !append(font, c.MF_STRING, id_font_11, "11 pt") or
        !append(font, c.MF_STRING, id_font_13, "13 pt") or
        !append(font, c.MF_STRING, id_font_16, "16 pt") or
        !append(font, c.MF_STRING, id_font_18, "18 pt") or
        !append(profile, c.MF_STRING, id_profile_powershell, "&PowerShell") or
        !append(profile, c.MF_STRING, id_profile_command, "&Command Prompt") or
        !append(settings, c.MF_STRING, id_restore_startup, "&Restore saved workspace on startup") or
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
    if (c.AppendMenuW(settings, c.MF_SEPARATOR, 0, null) == 0) return null;
    if (c.AppendMenuW(root, c.MF_POPUP, @intFromPtr(settings), wide("&Settings")) == 0) return null;
    settings_owned = false;
    if (c.AppendMenuW(root, c.MF_POPUP, @intFromPtr(workspace), wide("&Workspace")) == 0) {
        return null;
    }
    workspace_owned = false;
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
    _ = c.CheckMenuRadioItem(
        menu.theme,
        id_theme_dark,
        id_theme_high_contrast,
        if (theme_value == 1) id_theme_high_contrast else id_theme_dark,
        c.MF_BYCOMMAND,
    );
    const font_command: c.UINT = switch (font_size_pt) {
        11 => id_font_11,
        16 => id_font_16,
        18 => id_font_18,
        else => id_font_13,
    };
    _ = c.CheckMenuRadioItem(menu.font, id_font_11, id_font_18, font_command, c.MF_BYCOMMAND);
    _ = c.CheckMenuRadioItem(
        menu.profile,
        id_profile_powershell,
        id_profile_command,
        if (launch_profile == 1) id_profile_command else id_profile_powershell,
        c.MF_BYCOMMAND,
    );
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
    _ = c.EnableMenuItem(menu.profile, id_profile_powershell, command_state);
    _ = c.EnableMenuItem(menu.profile, id_profile_command, command_state);
    _ = c.EnableMenuItem(menu.settings, id_restore_startup, command_state);
    _ = c.EnableMenuItem(menu.workspace, id_workspace_save, command_state);
    _ = c.EnableMenuItem(menu.workspace, id_workspace_restore, command_state);
    _ = c.DrawMenuBar(menu.window);
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
