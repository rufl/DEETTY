//! Native Win32 window, message-pump, ConPTY-composition, and input adapter.

const std = @import("std");
const Abi = @import("WindowsHostAbi.zig");
const Logic = @import("WindowsHostLogic.zig");
const Diagnostics = @import("WindowsDiagnostics.zig");
const Pty = @import("WindowsPty.zig");
const Clipboard = @import("WindowsClipboard.zig");
const Process = @import("WindowsProcess.zig");
const Menu = @import("WindowsMenu.zig");
const Fonts = @import("WindowsFonts.zig");
const Title = @import("WindowsTitle.zig");
const Renderer = @import("WindowsRenderer.zig");
const Tabs = @import("WindowsTabStrip.zig");

const c = Abi.c;

extern "user32" fn LoadCursorW(
    instance: c.HINSTANCE,
    cursor_name: ?*const anyopaque,
) callconv(.winapi) c.HCURSOR;
extern "user32" fn LoadIconW(
    instance: c.HINSTANCE,
    icon_name: ?*const anyopaque,
) callconv(.winapi) c.HICON;

const timer_id: usize = 1;
const timer_interval_ms: c.UINT = 16;
const output_drain_bytes: usize = 128 * 1024;
const output_drain_limit: usize = 2 * 1024 * 1024;
const max_sessions: usize = @intCast(Logic.workspace_max_sessions);
const default_columns: c_int = 120;
const default_rows: c_int = 36;
const window_width: c_int = 1120;
const window_height: c_int = 720;
const window_min_width: c_int = 640;
const window_min_height: c_int = 360;
const output_message: c.UINT = c.WM_APP + 1;
const pref_theme: c_int = 1;
const pref_font_size: c_int = 2;
const pref_launch_profile: c_int = 3;
const pref_restore_workspace: c_int = 4;
const workspace_save: c_int = 1;
const workspace_restore: c_int = 2;
const menu_preference_theme: c_int = 1;
const menu_preference_font: c_int = 2;
const menu_preference_profile: c_int = 3;
const menu_preference_restore: c_int = 4;
const menu_workspace_save: c_int = 5;
const menu_workspace_restore: c_int = 6;
const menu_launch_nocted: c_int = 7;
const action_new_tab: c_int = 1;
const action_split_down: c_int = 2;
const action_split_left: c_int = 3;
const close_pane: c_int = 1;
const close_tab: c_int = 2;
const query_close_pane: c_int = 3;
const query_close_tab: c_int = 4;
const mouse_tracking_mask: u32 = 0x3;
const mouse_encoding_sgr: u32 = 0x100;
const mouse_wheel: c_int = 3;
const mouse_mod_shift: c_int = 1;
const mouse_mod_alt: c_int = 2;
const mouse_mod_control: c_int = 4;

pub const Callbacks = Abi.Callbacks;

const Session = struct {
    index: c_int = 0,
    columns: c_int = 0,
    rows: c_int = 0,
    pty: ?*Pty.Pty = null,
};

const PaneHit = struct {
    pane_index: c_int = 0,
    column: c_int = 0,
    selected: c_int = 0,
    host_active: c_int = 0,
    row: c_int = 0,
    inside_content: c_int = 0,
    pane: c.RECT = std.mem.zeroes(c.RECT),
    content: c.RECT = std.mem.zeroes(c.RECT),
    columns: c_int = 0,
    rows: c_int = 0,
};

const Host = struct {
    callbacks: *const Callbacks,
    window: c.HWND = null,
    font_normal: c.HFONT = null,
    font_bold: c.HFONT = null,
    cell_width: c_int = 0,
    cell_height: c_int = 0,
    columns: c_int = default_columns,
    menu: ?*Menu.Menu = null,
    tabs: Tabs.Strip = .{},
    content_top: c_int = 0,
    theme: c_int = 0,
    font_size_pt: c_int = 0,
    launch_profile: c_int = 0,
    restore_workspace: c_int = 0,
    foreground: u32 = 0,
    background: u32 = 0,
    settings_menu_ready: c_int = 0,
    preferences_ready: c_int = 0,
    rows: c_int = default_rows,
    sessions: [max_sessions]Session = [_]Session{.{}} ** max_sessions,
    workspace: Logic.WorkspaceState = .{ .live_sessions = 0, .pending_close = 0 },
    remote_mode: c_int = 0,
    suppress_character: c_int = 0,
    timer_active: bool = false,
    smoke_mode: c_int = 0,
    exit_code: c_int = 1,
    paint_count: u32 = 0,
    smoke_ticks: u32 = 0,
    smoke_marker_paint_count: u32 = 0,
    smoke_marker_seen: c_int = 0,
    pending_high_surrogate: u16 = 0,
    mouse: Logic.MouseState = std.mem.zeroes(Logic.MouseState),
    smoke_mouse_input: c_int = 0,
    smoke_coordinates: c_int = 0,
    smoke_selection: c_int = 0,
    smoke_clipboard: c_int = 0,
};

fn log(comptime format: []const u8, args: anytype) void {
    var buffer: [2048]u8 = undefined;
    const bytes = std.fmt.bufPrint(&buffer, format, args) catch return;
    Diagnostics.noctty_windows_diagnostics_write(bytes.ptr, bytes.len);
}

fn initializeLogging() void {
    _ = Diagnostics.noctty_windows_diagnostics_init();
    log("windows_launch pid={d} conpty=true renderer=win32_gdi telemetry=false uploads=false\r\n", .{c.GetCurrentProcessId()});
}

fn applyTheme(host: *Host) void {
    Renderer.noctty_windows_theme_colors(host.theme, &host.foreground, &host.background);
}

fn loadPreferences(host: *Host) c_int {
    var preferences: Logic.Preferences = undefined;
    const valid = Logic.noctty_windows_normalize_preferences(
        host.callbacks.preference_get(host.callbacks.userdata, pref_theme),
        host.callbacks.preference_get(host.callbacks.userdata, pref_font_size),
        host.callbacks.preference_get(host.callbacks.userdata, pref_launch_profile),
        host.callbacks.preference_get(host.callbacks.userdata, pref_restore_workspace),
        &preferences,
    );
    host.theme = preferences.theme;
    host.font_size_pt = preferences.font_size_pt;
    host.launch_profile = preferences.launch_profile;
    host.restore_workspace = preferences.restore_workspace;
    host.preferences_ready = valid;
    applyTheme(host);
    return valid;
}

fn updateMenu(host: *Host) void {
    Menu.noctty_windows_menu_update(host.menu, host.theme, host.font_size_pt, host.launch_profile, host.restore_workspace, host.remote_mode);
}

fn createMenu(host: *Host) bool {
    host.menu = Menu.noctty_windows_menu_create(@ptrCast(host.window));
    if (host.menu == null) return false;
    host.settings_menu_ready = 1;
    updateMenu(host);
    return true;
}

fn createFonts(host: *Host, dpi: c.UINT) bool {
    const updated = Fonts.noctty_windows_fonts_update(
        @ptrCast(host.window),
        host.font_size_pt,
        dpi,
        @ptrCast(&host.font_normal),
        @ptrCast(&host.font_bold),
        &host.cell_width,
        &host.cell_height,
    ) != 0;
    if (updated) host.tabs.setFont(host.font_normal, dpi, host.cell_height);
    return updated;
}

fn paneGeometry(host: *Host, pane_index: c_int, client: *const c.RECT, result: *PaneHit) bool {
    var x: u32 = 0;
    var y: u32 = 0;
    var width: u32 = 0;
    var height: u32 = 0;
    var selected: c_int = 0;
    var host_active: c_int = 0;
    var columns: u16 = 0;
    var rows: u16 = 0;
    if (host.callbacks.pane_layout(host.callbacks.userdata, pane_index, &x, &y, &width, &height, &selected, &host_active) <= 0 or
        host.callbacks.pane_dimensions(host.callbacks.userdata, pane_index, &columns, &rows) <= 0 or columns == 0 or rows == 0) return false;
    var geometry: Logic.PaneGeometry = undefined;
    if (Logic.noctty_windows_compute_pane_geometry(client.left, @min(host.content_top, client.bottom), client.right, client.bottom, x, y, width, height, 3, &geometry) == 0) return false;
    result.* = .{
        .pane_index = pane_index,
        .pane = .{ .left = geometry.pane_left, .top = geometry.pane_top, .right = geometry.pane_right, .bottom = geometry.pane_bottom },
        .content = .{ .left = geometry.content_left, .top = geometry.content_top, .right = geometry.content_right, .bottom = geometry.content_bottom },
        .columns = columns,
        .rows = rows,
        .selected = selected,
        .host_active = host_active,
    };
    return true;
}

fn cellForPane(host: *Host, pane_index: c_int, pointer_x: c_int, pointer_y: c_int, clamp: c_int, result: *PaneHit) bool {
    var client: c.RECT = undefined;
    _ = c.GetClientRect(host.window, &client);
    if (!paneGeometry(host, pane_index, &client, result)) return false;
    return Logic.noctty_windows_pointer_cell(
        result.content.left,
        result.content.top,
        result.content.right,
        result.content.bottom,
        result.columns,
        result.rows,
        pointer_x,
        pointer_y,
        clamp,
        &result.column,
        &result.row,
        &result.inside_content,
    ) != 0;
}

fn hitTestPaneCell(host: *Host, pointer_x: c_int, pointer_y: c_int, result: *PaneHit) bool {
    var client: c.RECT = undefined;
    _ = c.GetClientRect(host.window, &client);
    const count = host.callbacks.pane_count(host.callbacks.userdata);
    var index: c_int = 0;
    while (index < count) : (index += 1) {
        var candidate: PaneHit = .{};
        if (!paneGeometry(host, index, &client, &candidate)) continue;
        if (pointer_x < candidate.pane.left or pointer_x >= candidate.pane.right or pointer_y < candidate.pane.top or pointer_y >= candidate.pane.bottom) continue;
        _ = cellForPane(host, index, pointer_x, pointer_y, 0, &candidate);
        result.* = candidate;
        return true;
    }
    return false;
}

fn mousePolicy(host: *Host, input: *const Logic.MouseInput) void {
    var decision: Logic.MouseDecision = undefined;
    if (Logic.noctty_windows_mouse_transition(&host.mouse, input, &decision) != 0) applyMouseDecision(host, &decision);
}

fn clearSelection(host: *Host) void {
    var input: Logic.MouseInput = std.mem.zeroes(Logic.MouseInput);
    input.kind = Logic.mouse_event_clear_selection;
    mousePolicy(host, &input);
}

fn cellSelected(host: *const Host, pane_index: c_int, column: c_int, row: c_int) bool {
    return Logic.noctty_windows_cell_selected(
        host.mouse.selection_active,
        host.mouse.selection_pane,
        pane_index,
        host.mouse.selection_anchor_column,
        host.mouse.selection_anchor_row,
        host.mouse.selection_extent_column,
        host.mouse.selection_extent_row,
        column,
        row,
    ) != 0;
}

fn paint(host: *Host) void {
    var state: Renderer.State = std.mem.zeroes(Renderer.State);
    state.window = @ptrCast(host.window);
    state.callbacks = @ptrCast(host.callbacks);
    state.font_normal = @ptrCast(host.font_normal);
    state.font_bold = @ptrCast(host.font_bold);
    state.cell_width = host.cell_width;
    state.cell_height = host.cell_height;
    state.content_top = host.content_top;
    state.columns = host.columns;
    state.rows = host.rows;
    state.foreground = host.foreground;
    state.background = host.background;
    state.selection_active = host.mouse.selection_active;
    state.selection_pane = host.mouse.selection_pane;
    state.selection_anchor_column = host.mouse.selection_anchor_column;
    state.selection_anchor_row = host.mouse.selection_anchor_row;
    state.selection_extent_column = host.mouse.selection_extent_column;
    state.selection_extent_row = host.mouse.selection_extent_row;
    Renderer.noctty_windows_render(&state, &host.paint_count);
}

fn activeSession(host: *Host) ?*Session {
    const index = host.callbacks.active_pane(host.callbacks.userdata);
    if (Logic.noctty_windows_session_is_live(&host.workspace, index) == 0) return null;
    return &host.sessions[@intCast(index)];
}

fn writeSession(session: ?*Session, bytes: [*]const u8, length: usize) bool {
    const current = session orelse return false;
    return Pty.noctty_windows_pty_write(current.pty, bytes, length) != 0;
}

fn writeTerminal(host: *Host, bytes: [*]const u8, length: usize) bool {
    if (host.remote_mode != 0) return host.callbacks.write(host.callbacks.userdata, bytes, length) == @as(c_int, @intCast(length));
    return writeSession(activeSession(host), bytes, length);
}

fn flushReplies(host: *Host, session: *Session) void {
    var replies: [4096]u8 = undefined;
    for (0..16) |_| {
        const count = host.callbacks.pane_take_reply(host.callbacks.userdata, session.index, &replies, replies.len);
        if (count <= 0) break;
        if (!writeSession(session, &replies, @intCast(count))) break;
    }
}

fn drainOutput(host: *Host, session_index: c_int) void {
    if (Logic.noctty_windows_session_is_live(&host.workspace, session_index) == 0) return;
    var scratch: [output_drain_bytes]u8 = undefined;
    const session = &host.sessions[@intCast(session_index)];
    var total: usize = 0;
    while (total < output_drain_limit) {
        const count = Pty.noctty_windows_pty_drain(session.pty, &scratch, scratch.len);
        if (count == 0) break;
        if (host.callbacks.pane_feed(host.callbacks.userdata, session_index, &scratch, count) < 0) {
            log("vt_feed_failed pane={d} bytes={d}\r\n", .{ session_index, count });
            _ = c.DestroyWindow(host.window);
            return;
        }
        total += count;
    }
    if (total != 0) {
        flushReplies(host, session);
        updateTitle(host);
        _ = c.InvalidateRect(host.window, null, c.FALSE);
    }
}

fn cleanupSession(session: *Session) void {
    Pty.noctty_windows_pty_destroy(session.pty);
    session.* = .{};
}

fn cleanupSessions(host: *Host, mask: u32) void {
    for (&host.sessions, 0..) |*session, index| {
        if ((mask & (@as(u32, 1) << @intCast(index))) != 0) cleanupSession(session);
    }
}

fn startSession(host: *Host, session_index: c_int, dimensions_valid: c_int, columns: u16, rows: u16, startup: c_int) bool {
    var plan: Logic.SessionPlan = undefined;
    const decision = Logic.noctty_windows_session_start_plan(&host.workspace, session_index, dimensions_valid, columns, rows, &plan);
    if (decision == Logic.session_start_existing) return true;
    if (decision != Logic.session_start_create) return false;
    const session = &host.sessions[@intCast(plan.session_index)];
    session.* = .{ .index = plan.session_index, .columns = plan.columns, .rows = plan.rows };
    session.pty = Pty.noctty_windows_pty_create(plan.session_index, plan.columns, plan.rows, host.launch_profile, @ptrCast(host.window), output_message);
    if (session.pty == null) {
        var cleanup_mask: u32 = 0;
        session.* = .{};
        const failure = Logic.noctty_windows_session_start_failed(&host.workspace, plan.session_index, startup, &cleanup_mask);
        if (failure == Logic.session_failure_cleanup) cleanupSessions(host, cleanup_mask) else if (failure == Logic.session_failure_shutdown) _ = c.DestroyWindow(host.window);
        return false;
    }
    if (Logic.noctty_windows_session_started(&host.workspace, plan.session_index) == 0) {
        cleanupSession(session);
        _ = c.DestroyWindow(host.window);
        return false;
    }
    return true;
}

fn updateTitle(host: *Host) void {
    _ = host.tabs.sync(host.callbacks);
    var title_utf8: [512]u8 = undefined;
    const count = host.callbacks.title(host.callbacks.userdata, &title_utf8, title_utf8.len);
    const active = activeSession(host);
    const exited = if (active) |session| Pty.noctty_windows_pty_exited(session.pty) else 0;
    const valid_count: usize = if (count > 0 and count <= @as(c_int, @intCast(title_utf8.len))) @intCast(count) else 0;
    _ = Title.noctty_windows_update_title(@ptrCast(host.window), if (valid_count != 0) &title_utf8 else null, valid_count, exited);
}

fn resizeTerminal(host: *Host, width: c_int, height: c_int) void {
    _ = host.tabs.sync(host.callbacks);
    host.content_top = host.tabs.layout(width, height);
    const content_height = @max(0, height - host.content_top);
    if (Logic.noctty_windows_grid_dimensions(width, content_height, host.cell_width, host.cell_height, &host.columns, &host.rows) == 0) return;
    var pane_count: c_int = 0;
    if (Logic.noctty_windows_workspace_local_operation(host.remote_mode) != 0) pane_count = host.callbacks.pane_count(host.callbacks.userdata);
    pane_count = Logic.noctty_windows_workspace_resize_count(host.remote_mode, pane_count);
    var index: c_int = 0;
    while (index < pane_count) : (index += 1) {
        var x: u32 = 0;
        var y: u32 = 0;
        var pane_width: u32 = 0;
        var pane_height: u32 = 0;
        var selected: c_int = 0;
        var host_active: c_int = 0;
        if (host.callbacks.pane_layout(host.callbacks.userdata, index, &x, &y, &pane_width, &pane_height, &selected, &host_active) <= 0) continue;
        const pixel_width: c_int = @intCast(@divTrunc(@as(i64, width) * pane_width, 1_000_000) - 6);
        const pixel_height: c_int = @intCast(@divTrunc(@as(i64, content_height) * pane_height, 1_000_000) - 6);
        var columns: c_int = 0;
        var rows: c_int = 0;
        if (Logic.noctty_windows_grid_dimensions(pixel_width, pixel_height, host.cell_width, host.cell_height, &columns, &rows) == 0) continue;
        if (host.callbacks.pane_resize(host.callbacks.userdata, index, columns, rows) < 0) continue;
        var plan: Logic.SessionPlan = undefined;
        if (Logic.noctty_windows_session_resize_plan(&host.workspace, index, columns, rows, &plan) == 0) continue;
        const session = &host.sessions[@intCast(plan.session_index)];
        if (Pty.noctty_windows_pty_resize(session.pty, plan.columns, plan.rows) != 0) {
            session.columns = plan.columns;
            session.rows = plan.rows;
        }
    }
    _ = c.InvalidateRect(host.window, null, c.FALSE);
}

fn sendSpecialKey(host: *Host, key: c.WPARAM) void {
    var sequence: [16]u8 = undefined;
    const length = Logic.noctty_windows_special_key_sequence(
        @intCast(key),
        host.callbacks.cursor_mode(host.callbacks.userdata),
        &sequence,
        sequence.len,
    );
    if (length != 0) _ = writeTerminal(host, &sequence, length);
}

fn sendWideCharacter(host: *Host, character: u16) void {
    var utf8: [8]u8 = undefined;
    const count = Logic.noctty_windows_encode_utf16_input(
        character,
        &host.pending_high_surrogate,
        &utf8,
        utf8.len,
    );
    if (count != 0) _ = writeTerminal(host, &utf8, count);
}

fn clipboardWrite(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    const host: *Host = @ptrCast(@alignCast(raw orelse return -1));
    if (length > std.math.maxInt(c_int)) return -1;
    if (writeTerminal(host, bytes, length)) return @intCast(length);
    reportInputFailure(host);
    return -1;
}

fn pasteClipboard(host: *Host) void {
    _ = Clipboard.noctty_windows_clipboard_paste(
        @ptrCast(host.window),
        host,
        clipboardWrite,
    );
}

fn copyTerminal(host: *Host) void {
    const pane_index = host.callbacks.active_pane(host.callbacks.userdata);
    if (pane_index < 0) return;
    const selected = host.mouse.selection_active != 0 and host.mouse.selection_pane == pane_index;
    _ = Clipboard.noctty_windows_clipboard_copy(
        @ptrCast(host.window),
        host.callbacks.userdata,
        pane_index,
        host.callbacks.pane_copy,
        if (selected) host.mouse.selection_anchor_column else -1,
        if (selected) host.mouse.selection_anchor_row else -1,
        if (selected) host.mouse.selection_extent_column else -1,
        if (selected) host.mouse.selection_extent_row else -1,
    );
}

fn reportInputFailure(host: *Host) void {
    log("terminal_input_failed remote={d}\r\n", .{host.remote_mode});
    _ = c.MessageBoxW(
        host.window,
        wide("NOCTTY could not send input to the focused terminal. The session may have closed, or remote input may not be permitted."),
        wide("NOCTTY Windows alpha"),
        c.MB_OK | c.MB_ICONERROR,
    );
}

fn clearScreen(host: *Host) void {
    const form_feed = [_]u8{0x0c};
    if (!writeTerminal(host, &form_feed, form_feed.len)) reportInputFailure(host);
}

fn cycleWorkspace(host: *Host, next_tab: bool) void {
    const changed = if (next_tab)
        host.callbacks.next_tab(host.callbacks.userdata)
    else
        host.callbacks.next_stream(host.callbacks.userdata);
    if (changed <= 0) return;
    clearSelection(host);
    if (host.remote_mode == 0) {
        var client: c.RECT = undefined;
        _ = c.GetClientRect(host.window, &client);
        resizeTerminal(host, client.right, client.bottom);
    }
    updateTitle(host);
    _ = c.InvalidateRect(host.window, null, c.FALSE);
}

fn workspaceAction(host: *Host, action: c_int) bool {
    if (Logic.noctty_windows_workspace_local_operation(host.remote_mode) == 0) return false;
    const result = host.callbacks.workspace_action(host.callbacks.userdata, action, host.columns, host.rows);
    var session_index: c_int = -1;
    const decision = Logic.noctty_windows_workspace_action_result(host.remote_mode, result, &session_index);
    if (decision == Logic.workspace_action_none) return false;
    clearSelection(host);
    var client: c.RECT = undefined;
    _ = c.GetClientRect(host.window, &client);
    resizeTerminal(host, client.right, client.bottom);
    if (decision == Logic.workspace_action_start) {
        var columns: u16 = 0;
        var rows: u16 = 0;
        const dimensions_valid = host.callbacks.pane_dimensions(host.callbacks.userdata, session_index, &columns, &rows);
        if (startSession(host, session_index, dimensions_valid, columns, rows, 0)) {
            updateTitle(host);
            _ = c.InvalidateRect(host.window, null, c.FALSE);
            _ = c.SetFocus(host.window);
            return true;
        }
    }
    const rollback = host.callbacks.workspace_close(host.callbacks.userdata, close_pane);
    if (decision == Logic.workspace_action_start and
        Logic.noctty_windows_workspace_rollback_matches(session_index, rollback) == 0)
    {
        log("workspace_rollback_mismatch pane={d} actual=0x{x:0>8}\r\n", .{ session_index, rollback });
        _ = c.DestroyWindow(host.window);
        return false;
    }
    resizeTerminal(host, client.right, client.bottom);
    _ = c.MessageBoxW(
        host.window,
        wide("NOCTTY could not start another ConPTY."),
        wide("NOCTTY Windows alpha"),
        c.MB_OK | c.MB_ICONERROR,
    );
    return false;
}

fn workspaceClose(host: *Host, close_action: c_int, query_action: c_int) bool {
    if (Logic.noctty_windows_workspace_local_operation(host.remote_mode) == 0) return false;
    const pane_count = host.callbacks.pane_count(host.callbacks.userdata);
    const mask = host.callbacks.workspace_close(host.callbacks.userdata, query_action);
    var cleanup_mask: u32 = 0;
    const decision = Logic.noctty_windows_workspace_close_plan(
        &host.workspace,
        host.remote_mode,
        pane_count,
        mask,
        &cleanup_mask,
    );
    if (decision == Logic.workspace_close_none) return false;
    if (decision == Logic.workspace_close_shutdown) {
        log("workspace_close_invalid mask=0x{x:0>8} panes={d}\r\n", .{ mask, pane_count });
        _ = c.DestroyWindow(host.window);
        return false;
    }
    clearSelection(host);
    cleanupSessions(host, cleanup_mask);
    const committed = host.callbacks.workspace_close(host.callbacks.userdata, close_action);
    if (Logic.noctty_windows_workspace_close_commit(&host.workspace, committed) == 0) {
        log("workspace_close_mismatch expected=0x{x:0>8} actual=0x{x:0>8}\r\n", .{ mask, committed });
        _ = c.DestroyWindow(host.window);
        return false;
    }
    var client: c.RECT = undefined;
    _ = c.GetClientRect(host.window, &client);
    resizeTerminal(host, client.right, client.bottom);
    updateTitle(host);
    _ = c.InvalidateRect(host.window, null, c.FALSE);
    _ = c.SetFocus(host.window);
    return true;
}

fn cleanupAllSessions(host: *Host) void {
    var cleanup_mask: u32 = 0;
    _ = Logic.noctty_windows_workspace_reset(&host.workspace, &cleanup_mask);
    cleanupSessions(host, cleanup_mask);
}

fn startWorkspaceSessions(host: *Host) bool {
    var pane_count: c_int = 0;
    if (Logic.noctty_windows_workspace_local_operation(host.remote_mode) != 0) {
        pane_count = host.callbacks.pane_count(host.callbacks.userdata);
    }
    var session_count: c_int = 0;
    const startup = Logic.noctty_windows_workspace_startup_plan(
        &host.workspace,
        host.remote_mode,
        pane_count,
        &session_count,
    );
    if (startup == Logic.workspace_startup_remote) return true;
    if (startup != Logic.workspace_startup_local) return false;
    var index: c_int = 0;
    while (index < session_count) : (index += 1) {
        var columns: u16 = 0;
        var rows: u16 = 0;
        const dimensions_valid = host.callbacks.pane_dimensions(host.callbacks.userdata, index, &columns, &rows);
        if (dimensions_valid <= 0) continue;
        if (!startSession(host, index, dimensions_valid, columns, rows, 1)) return false;
    }
    return true;
}

fn setPreference(host: *Host, field: c_int, value: c_int) void {
    if (host.callbacks.preference_set(host.callbacks.userdata, field, value) != 0) {
        _ = c.MessageBoxW(
            host.window,
            wide("NOCTTY could not persist this Windows setting."),
            wide("NOCTTY Windows alpha"),
            c.MB_OK | c.MB_ICONERROR,
        );
        return;
    }
    _ = loadPreferences(host);
    if (field == pref_font_size) {
        var dpi = c.GetDpiForWindow(host.window);
        if (dpi == 0) dpi = 96;
        if (!createFonts(host, dpi)) {
            _ = c.MessageBoxW(
                host.window,
                wide("NOCTTY could not apply this font size."),
                wide("NOCTTY Windows alpha"),
                c.MB_OK | c.MB_ICONERROR,
            );
            return;
        }
        clearSelection(host);
        var client: c.RECT = undefined;
        _ = c.GetClientRect(host.window, &client);
        resizeTerminal(host, client.right, client.bottom);
    }
    updateMenu(host);
    _ = c.InvalidateRect(host.window, null, c.FALSE);
    _ = c.SetFocus(host.window);
}

fn workspacePersistence(host: *Host, action: c_int) void {
    if (Logic.noctty_windows_workspace_local_operation(host.remote_mode) == 0) return;
    if (action == workspace_restore and c.MessageBoxW(
        host.window,
        wide("Restore the saved layout? Current shells will be closed and replacement shells will start."),
        wide("Restore NOCTTY workspace"),
        c.MB_OKCANCEL | c.MB_ICONWARNING | c.MB_DEFBUTTON2,
    ) != c.IDOK) return;
    const result = host.callbacks.workspace_persistence(host.callbacks.userdata, action, host.columns, host.rows);
    if (result < 0) {
        _ = c.MessageBoxW(
            host.window,
            if (action == workspace_save)
                wide("NOCTTY could not save this workspace layout.")
            else
                wide("NOCTTY could not restore the saved workspace."),
            wide("NOCTTY Windows alpha"),
            c.MB_OK | c.MB_ICONERROR,
        );
        return;
    }
    if (result == 0) {
        _ = c.MessageBoxW(
            host.window,
            wide("No saved workspace layout is available."),
            wide("NOCTTY Windows alpha"),
            c.MB_OK | c.MB_ICONINFORMATION,
        );
        return;
    }
    if (action == workspace_save) {
        _ = c.MessageBoxW(
            host.window,
            wide("Workspace layout saved. Shell contents are not stored."),
            wide("NOCTTY Windows alpha"),
            c.MB_OK | c.MB_ICONINFORMATION,
        );
        _ = c.SetFocus(host.window);
        return;
    }
    clearSelection(host);
    cleanupAllSessions(host);
    if (!startWorkspaceSessions(host)) {
        _ = c.MessageBoxW(
            host.window,
            wide("The layout was restored, but NOCTTY could not start all replacement shells."),
            wide("NOCTTY Windows alpha"),
            c.MB_OK | c.MB_ICONERROR,
        );
    }
    var client: c.RECT = undefined;
    _ = c.GetClientRect(host.window, &client);
    resizeTerminal(host, client.right, client.bottom);
    updateTitle(host);
    _ = c.InvalidateRect(host.window, null, c.FALSE);
    _ = c.SetFocus(host.window);
}

fn writePane(host: *Host, pane_index: c_int, bytes: [*]const u8, length: usize) bool {
    if (host.remote_mode != 0) {
        return host.callbacks.write(host.callbacks.userdata, bytes, length) == @as(c_int, @intCast(length));
    }
    if (Logic.noctty_windows_session_is_live(&host.workspace, pane_index) == 0) return false;
    return writeSession(&host.sessions[@intCast(pane_index)], bytes, length);
}

fn mouseModifiers() c_int {
    var modifiers: c_int = 0;
    if ((c.GetKeyState(c.VK_SHIFT) & @as(c.SHORT, @bitCast(@as(u16, 0x8000)))) != 0) modifiers |= mouse_mod_shift;
    if ((c.GetKeyState(c.VK_MENU) & @as(c.SHORT, @bitCast(@as(u16, 0x8000)))) != 0) modifiers |= mouse_mod_alt;
    if ((c.GetKeyState(c.VK_CONTROL) & @as(c.SHORT, @bitCast(@as(u16, 0x8000)))) != 0) modifiers |= mouse_mod_control;
    return modifiers;
}

fn selectPane(host: *Host, pane_index: c_int) bool {
    const previous = host.callbacks.active_pane(host.callbacks.userdata);
    if (host.callbacks.pane_select(host.callbacks.userdata, pane_index) != 0) return false;
    if (previous != pane_index) clearSelection(host);
    _ = c.SetFocus(host.window);
    updateTitle(host);
    return true;
}

fn reportMouse(host: *Host, hit: *const PaneHit, button: c_int, kind: c_int, modifiers: c_int) bool {
    var encoded: [64]u8 = undefined;
    const count = host.callbacks.pane_mouse_encode(
        host.callbacks.userdata,
        hit.pane_index,
        hit.column,
        hit.row,
        button,
        kind,
        modifiers,
        &encoded,
        encoded.len,
    );
    if (count <= 0 or count > @as(c_int, @intCast(encoded.len))) return false;
    return writePane(host, hit.pane_index, &encoded, @intCast(count));
}

fn emitMouseReports(host: *Host, decision: *const Logic.MouseDecision) bool {
    if (decision.select_pane != 0 and !selectPane(host, decision.report_pane)) return false;
    const hit = PaneHit{
        .pane_index = decision.report_pane,
        .column = decision.report_column,
        .row = decision.report_row,
    };
    for (0..4) |button| {
        if ((decision.report_buttons & (@as(u32, 1) << @intCast(button))) == 0) continue;
        _ = reportMouse(host, &hit, @intCast(button), decision.report_kind, mouseModifiers());
    }
    return true;
}

fn applyMouseDecision(host: *Host, decision: *const Logic.MouseDecision) void {
    if (decision.capture == Logic.mouse_capture_set) _ = c.SetCapture(host.window);
    _ = emitMouseReports(host, decision);
    if (decision.capture == Logic.mouse_capture_release and c.GetCapture() == host.window) _ = c.ReleaseCapture();
    if (decision.invalidate != 0) _ = c.InvalidateRect(host.window, null, c.FALSE);
}

fn releaseMouseCapture(host: *Host) void {
    var input: Logic.MouseInput = std.mem.zeroes(Logic.MouseInput);
    input.kind = Logic.mouse_event_cancel;
    mousePolicy(host, &input);
}

fn launchNocted(host: *Host) void {
    if (Process.noctty_windows_launch_nocted() != 0) return;
    _ = c.MessageBoxW(
        host.window,
        wide("NOCTTY could not launch the sibling nocted.exe."),
        wide("NOCTTY Windows alpha"),
        c.MB_OK | c.MB_ICONERROR,
    );
}

fn tabSelectionChanged(host: *Host) void {
    const index = host.tabs.selected();
    const result = host.callbacks.tab_select(host.callbacks.userdata, index);
    if (result > 0) {
        releaseMouseCapture(host);
        clearSelection(host);
        var client: c.RECT = undefined;
        _ = c.GetClientRect(host.window, &client);
        resizeTerminal(host, client.right, client.bottom);
        updateTitle(host);
        _ = c.InvalidateRect(host.window, null, c.FALSE);
    } else {
        // Reconcile rejected/stale selections against authoritative model state.
        _ = host.tabs.sync(host.callbacks);
    }
    if (keyDown(c.VK_LBUTTON)) _ = c.SetFocus(host.window);
}

fn renameTab(host: *Host) void {
    if (host.remote_mode != 0) return;
    releaseMouseCapture(host);
    const result = Tabs.rename(host.window, host.callbacks, false);
    if (result < 0) {
        _ = c.MessageBoxW(host.window, wide("NOCTTY could not open the rename dialog."), wide("NOCTTY Windows alpha"), c.MB_OK | c.MB_ICONERROR);
    }
    updateTitle(host);
    _ = c.SetFocus(host.window);
}

fn moveTab(host: *Host, direction: c_int) void {
    if (host.remote_mode != 0) return;
    const from = host.callbacks.tab_active(host.callbacks.userdata);
    const to = from + direction;
    if (from < 0 or to < 0 or to >= host.callbacks.tab_count(host.callbacks.userdata)) return;
    if (host.callbacks.tab_move(host.callbacks.userdata, from, to) < 0) {
        _ = c.MessageBoxW(host.window, wide("NOCTTY could not move this tab."), wide("NOCTTY Windows alpha"), c.MB_OK | c.MB_ICONERROR);
        return;
    }
    updateTitle(host);
    _ = c.SetFocus(host.window);
}

fn handleMenuCommand(host: *Host, command: c.UINT) bool {
    switch (command) {
        Menu.id_focus_tabs => {
            _ = c.SetFocus(host.tabs.window);
            return true;
        },
        Menu.id_rename_tab => {
            renameTab(host);
            return true;
        },
        Menu.id_move_tab_left, Menu.id_move_tab_right => {
            moveTab(host, if (command == Menu.id_move_tab_left) -1 else 1);
            return true;
        },
        Menu.id_new_tab => {
            _ = workspaceAction(host, action_new_tab);
            return true;
        },
        Menu.id_split_down => {
            _ = workspaceAction(host, action_split_down);
            return true;
        },
        Menu.id_split_left => {
            _ = workspaceAction(host, action_split_left);
            return true;
        },
        Menu.id_next_pane => {
            cycleWorkspace(host, false);
            return true;
        },
        Menu.id_next_tab => {
            cycleWorkspace(host, true);
            return true;
        },
        Menu.id_close_pane => {
            _ = workspaceClose(host, close_pane, query_close_pane);
            return true;
        },
        Menu.id_close_tab => {
            _ = workspaceClose(host, close_tab, query_close_tab);
            return true;
        },
        Menu.id_copy => {
            copyTerminal(host);
            return true;
        },
        Menu.id_paste => {
            pasteClipboard(host);
            return true;
        },
        Menu.id_clear_screen => {
            clearScreen(host);
            return true;
        },
        else => {},
    }
    var action: Logic.MenuAction = undefined;
    if (Logic.noctty_windows_decode_menu_command(command, host.restore_workspace, &action) == 0) return false;
    switch (action.kind) {
        menu_preference_theme => setPreference(host, pref_theme, action.value),
        menu_preference_font => setPreference(host, pref_font_size, action.value),
        menu_preference_profile => setPreference(host, pref_launch_profile, action.value),
        menu_preference_restore => setPreference(host, pref_restore_workspace, action.value),
        menu_workspace_save => workspacePersistence(host, workspace_save),
        menu_workspace_restore => workspacePersistence(host, workspace_restore),
        menu_launch_nocted => launchNocted(host),
        else => return false,
    }
    return true;
}

fn tabSmoke(host: *Host) bool {
    const callbacks = host.callbacks;
    const original_count = callbacks.tab_count(callbacks.userdata);
    const original_tab = callbacks.tab_active(callbacks.userdata);
    const original_pane = callbacks.active_pane(callbacks.userdata);
    var class_name: [32]u16 = undefined;
    const class_length = c.GetClassNameW(host.tabs.window, &class_name, class_name.len);
    if (class_length != 15 or !std.mem.eql(u16, class_name[0..15], wide("SysTabControl32")[0..15])) return false;
    if (callbacks.workspace_action(callbacks.userdata, action_new_tab, default_columns, default_rows) <= 0) return false;
    const added_pane = callbacks.active_pane(callbacks.userdata);
    if (added_pane == original_pane or callbacks.tab_count(callbacks.userdata) != original_count + 1) return false;
    var client: c.RECT = undefined;
    _ = c.GetClientRect(host.window, &client);
    resizeTerminal(host, client.right, client.bottom);
    if (!host.tabs.matches(callbacks)) return false;

    // Drive the real common control, which emits TCN_SELCHANGE into windowProc.
    var tab_rect: c.RECT = undefined;
    if (c.SendMessageW(host.tabs.window, c.TCM_GETITEMRECT, @intCast(original_tab), Tabs.pointer(&tab_rect)) == 0) return false;
    const point: c.LPARAM = @intCast(@as(u32, @intCast(tab_rect.left + 4)) | (@as(u32, @intCast(tab_rect.top + 4)) << 16));
    _ = c.SendMessageW(host.tabs.window, c.WM_LBUTTONDOWN, c.MK_LBUTTON, point);
    _ = c.SendMessageW(host.tabs.window, c.WM_LBUTTONUP, 0, point);
    if (callbacks.active_pane(callbacks.userdata) != original_pane or !host.tabs.matches(callbacks)) return false;
    _ = c.SendMessageW(host.tabs.window, c.WM_KEYDOWN, c.VK_END, 0);
    // Arrow selection is native and must reach the production model as well.
    if (callbacks.tab_active(callbacks.userdata) != original_count) {
        _ = c.SendMessageW(host.tabs.window, c.WM_KEYDOWN, c.VK_RIGHT, 0);
    }
    if (callbacks.active_pane(callbacks.userdata) != added_pane or !host.tabs.matches(callbacks)) return false;
    if (!Tabs.qualifyRename(host.window, callbacks) or !host.tabs.sync(callbacks) or !host.tabs.matches(callbacks)) return false;
    if (!handleMenuCommand(host, Menu.id_move_tab_left) or
        callbacks.tab_active(callbacks.userdata) != original_count - 1 or
        callbacks.active_pane(callbacks.userdata) != added_pane or
        !Tabs.titleMatches(callbacks, original_count - 1, "Native & 中") or !host.tabs.matches(callbacks)) return false;
    if (!handleMenuCommand(host, Menu.id_move_tab_right) or
        callbacks.tab_active(callbacks.userdata) != original_count or
        callbacks.active_pane(callbacks.userdata) != added_pane or
        !Tabs.titleMatches(callbacks, original_count, "Native & 中") or !host.tabs.matches(callbacks)) return false;
    var hit: PaneHit = .{};
    var pane: PaneHit = .{};
    if (host.content_top <= 0 or !paneGeometry(host, added_pane, &client, &pane) or pane.pane.top < host.content_top or
        hitTestPaneCell(host, pane.content.left, host.content_top - 1, &hit) or
        !cellForPane(host, added_pane, pane.content.left, pane.content.top, 0, &hit) or
        hit.column != 0 or hit.row != 0 or hit.inside_content == 0) return false;
    // Qualification creates terminal models, never sessions or pseudo-consoles.
    if (host.workspace.live_sessions != 0 or callbacks.workspace_close(callbacks.userdata, close_tab) == 0) return false;
    _ = callbacks.tab_select(callbacks.userdata, original_tab);
    updateTitle(host);
    return callbacks.tab_count(callbacks.userdata) == original_count and
        callbacks.active_pane(callbacks.userdata) == original_pane and host.tabs.matches(callbacks);
}

fn menuSmoke(host: *Host) bool {
    const menu = host.menu orelse return false;
    if (!Menu.qualifyState(menu, false)) return false;
    if (!tabSmoke(host)) return false;
    const panes_before = host.callbacks.pane_count(host.callbacks.userdata);
    const active_before = host.callbacks.active_pane(host.callbacks.userdata);
    const sessions_before = host.workspace.live_sessions;
    host.remote_mode = 1;
    updateMenu(host);
    if (!Menu.qualifyState(menu, true)) return false;
    for ([_]u32{
        Menu.id_new_tab,       Menu.id_split_down,     Menu.id_split_left,
        Menu.id_close_pane,    Menu.id_close_tab,      Menu.id_rename_tab,
        Menu.id_move_tab_left, Menu.id_move_tab_right,
    }) |command| {
        if (!handleMenuCommand(host, command) or
            c.IsWindow(host.window) == 0 or
            host.callbacks.pane_count(host.callbacks.userdata) != panes_before or
            host.callbacks.active_pane(host.callbacks.userdata) != active_before or
            host.workspace.live_sessions != sessions_before or
            host.workspace.pending_close != 0) return false;
    }
    host.remote_mode = 0;
    updateMenu(host);
    if (!Menu.qualifyState(menu, false)) return false;
    const tab_window = host.tabs.window;
    // DestroyWindow owns the entire attached tree; descriptor cleanup must not
    // destroy any of these handles a second time.
    const handles = [_]c.HMENU{
        @ptrCast(menu.root),     @ptrCast(menu.settings), @ptrCast(menu.theme),
        @ptrCast(menu.font),     @ptrCast(menu.profile),  @ptrCast(menu.workspace),
        @ptrCast(menu.terminal),
    };
    if (c.DestroyWindow(host.window) == 0) return false;
    if (c.IsWindow(tab_window) != 0) return false;
    for (handles) |handle| {
        if (c.IsMenu(handle) != 0) return false;
    }
    return true;
}

fn signedLowWord(value: c.LPARAM) c_int {
    return @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(value))))));
}

fn signedHighWord(value: c.LPARAM) c_int {
    return @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(value)) >> 16))));
}

fn lowWord(value: usize) u16 {
    return @truncate(value);
}

fn highWord(value: usize) u16 {
    return @truncate(value >> 16);
}

fn keyDown(key: c_int) bool {
    return (c.GetKeyState(key) & @as(c.SHORT, @bitCast(@as(u16, 0x8000)))) != 0;
}

fn hostFromWindow(window: c.HWND) ?*Host {
    const raw = c.GetWindowLongPtrW(window, c.GWLP_USERDATA);
    if (raw == 0) return null;
    return @ptrFromInt(@as(usize, @bitCast(raw)));
}

fn windowProc(window: c.HWND, message: c.UINT, word: c.WPARAM, long_value: c.LPARAM) callconv(.winapi) c.LRESULT {
    var host = hostFromWindow(window);
    if (message == c.WM_NCCREATE) {
        const address: usize = @bitCast(long_value);
        const create: *const c.CREATESTRUCTW = @ptrFromInt(address);
        if (create.lpCreateParams) |raw| {
            const created_host: *Host = @ptrCast(@alignCast(raw));
            host = created_host;
            created_host.window = window;
            _ = c.SetWindowLongPtrW(window, c.GWLP_USERDATA, @bitCast(@intFromPtr(created_host)));
        }
    }
    const current = host orelse return c.DefWindowProcW(window, message, word, long_value);
    switch (message) {
        c.WM_PAINT => {
            paint(current);
            return 0;
        },
        c.WM_ERASEBKGND => return 1,
        c.WM_NOTIFY => {
            const notification: *const c.NMHDR = @ptrFromInt(@as(usize, @bitCast(long_value)));
            if (notification.hwndFrom == current.tabs.window and notification.code == @as(c.UINT, @bitCast(@as(c_int, -551)))) { // TCN_SELCHANGE
                tabSelectionChanged(current);
                return 0;
            }
            if (notification.hwndFrom == current.tabs.window and notification.code == @as(c.UINT, @bitCast(@as(c_int, -2)))) { // NM_CLICK
                // Clicking the already-selected tab emits no selection change.
                _ = c.SetFocus(window);
                return 0;
            }
            return c.DefWindowProcW(window, message, word, long_value);
        },
        c.WM_COMMAND => {
            if (highWord(word) == 0 and handleMenuCommand(current, lowWord(word))) return 0;
            return c.DefWindowProcW(window, message, word, long_value);
        },
        c.WM_SYSCOLORCHANGE => {
            if (current.tabs.window != null) _ = c.SendMessageW(current.tabs.window, message, word, long_value);
            if (current.theme == 1) {
                applyTheme(current);
                _ = c.InvalidateRect(window, null, c.FALSE);
            }
            return 0;
        },
        c.WM_SIZE => {
            if (word != c.SIZE_MINIMIZED) {
                clearSelection(current);
                resizeTerminal(current, lowWord(@bitCast(long_value)), highWord(@bitCast(long_value)));
            }
            return 0;
        },
        c.WM_GETMINMAXINFO => {
            const limits: *c.MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(long_value)));
            limits.ptMinTrackSize.x = window_min_width;
            limits.ptMinTrackSize.y = window_min_height;
            return 0;
        },
        c.WM_DPICHANGED => {
            const suggested: *const c.RECT = @ptrFromInt(@as(usize, @bitCast(long_value)));
            clearSelection(current);
            _ = createFonts(current, highWord(word));
            _ = c.SetWindowPos(
                window,
                null,
                suggested.left,
                suggested.top,
                suggested.right - suggested.left,
                suggested.bottom - suggested.top,
                c.SWP_NOACTIVATE | c.SWP_NOZORDER,
            );
            var client: c.RECT = undefined;
            _ = c.GetClientRect(window, &client);
            resizeTerminal(current, client.right, client.bottom);
            return 0;
        },
        c.WM_SETFOCUS => {
            _ = c.InvalidateRect(window, null, c.FALSE);
            return 0;
        },
        c.WM_KILLFOCUS => {
            if (current.mouse.selection_dragging != 0 or current.mouse.application_capture != 0) releaseMouseCapture(current);
            _ = c.InvalidateRect(window, null, c.FALSE);
            return 0;
        },
        c.WM_LBUTTONDOWN, c.WM_MBUTTONDOWN, c.WM_RBUTTONDOWN => {
            var hit: PaneHit = .{};
            if (!hitTestPaneCell(current, signedLowWord(long_value), signedHighWord(long_value), &hit)) return 0;
            if (!selectPane(current, hit.pane_index)) return 0;
            var input: Logic.MouseInput = std.mem.zeroes(Logic.MouseInput);
            input.kind = Logic.mouse_event_press;
            input.button = if (message == c.WM_LBUTTONDOWN) 0 else if (message == c.WM_MBUTTONDOWN) 1 else 2;
            input.shift = @intFromBool(keyDown(c.VK_SHIFT));
            input.cell_valid = 1;
            input.inside_content = hit.inside_content;
            input.pane = hit.pane_index;
            if (hit.inside_content != 0) {
                input.column = hit.column;
                input.row = hit.row;
                input.tracking_mode = current.callbacks.pane_mouse_mode(current.callbacks.userdata, hit.pane_index) & mouse_tracking_mask;
            }
            mousePolicy(current, &input);
            return 0;
        },
        c.WM_LBUTTONUP, c.WM_MBUTTONUP, c.WM_RBUTTONUP => {
            var hit: PaneHit = .{};
            var target_pane: c_int = -1;
            const button: c_int = if (message == c.WM_LBUTTONUP) 0 else if (message == c.WM_MBUTTONUP) 1 else 2;
            const route = Logic.noctty_windows_mouse_route(&current.mouse, Logic.mouse_event_release, button, &target_pane);
            var input: Logic.MouseInput = std.mem.zeroes(Logic.MouseInput);
            input.kind = Logic.mouse_event_release;
            input.button = button;
            input.pane = target_pane;
            if ((route == Logic.mouse_route_selection or route == Logic.mouse_route_application) and
                cellForPane(current, target_pane, signedLowWord(long_value), signedHighWord(long_value), 1, &hit))
            {
                input.cell_valid = 1;
                input.inside_content = hit.inside_content;
                input.pane = hit.pane_index;
                input.column = hit.column;
                input.row = hit.row;
            }
            mousePolicy(current, &input);
            return 0;
        },
        c.WM_MOUSEMOVE => {
            var hit: PaneHit = .{};
            var target_pane: c_int = -1;
            const route = Logic.noctty_windows_mouse_route(&current.mouse, Logic.mouse_event_move, 0, &target_pane);
            var input: Logic.MouseInput = std.mem.zeroes(Logic.MouseInput);
            input.kind = Logic.mouse_event_move;
            if (route == Logic.mouse_route_hit_test) {
                if (hitTestPaneCell(current, signedLowWord(long_value), signedHighWord(long_value), &hit)) {
                    input.cell_valid = 1;
                    input.inside_content = hit.inside_content;
                    input.pane = hit.pane_index;
                    if (hit.inside_content != 0) {
                        input.column = hit.column;
                        input.row = hit.row;
                        input.tracking_mode = current.callbacks.pane_mouse_mode(current.callbacks.userdata, hit.pane_index) & mouse_tracking_mask;
                    }
                }
            } else if ((route == Logic.mouse_route_selection or route == Logic.mouse_route_application) and
                cellForPane(current, target_pane, signedLowWord(long_value), signedHighWord(long_value), 1, &hit))
            {
                input.cell_valid = 1;
                input.inside_content = hit.inside_content;
                input.pane = hit.pane_index;
                input.column = hit.column;
                input.row = hit.row;
            }
            mousePolicy(current, &input);
            return 0;
        },
        c.WM_MOUSEWHEEL => {
            var pointer = c.POINT{ .x = signedLowWord(long_value), .y = signedHighWord(long_value) };
            const delta: i16 = @bitCast(highWord(word));
            const steps = @divTrunc(@as(c_int, delta), c.WHEEL_DELTA);
            if (steps == 0) return 0;
            _ = c.ScreenToClient(window, &pointer);
            var hit: PaneHit = .{};
            if (!hitTestPaneCell(current, pointer.x, pointer.y, &hit) or !selectPane(current, hit.pane_index)) return 0;
            if (hit.inside_content != 0 and
                (current.callbacks.pane_mouse_mode(current.callbacks.userdata, hit.pane_index) & mouse_tracking_mask) != 0)
            {
                const count: c_int = if (steps < 0) -steps else steps;
                const button: c_int = if (steps > 0) 64 else 65;
                var index: c_int = 0;
                while (index < count) : (index += 1) _ = reportMouse(current, &hit, button, mouse_wheel, mouseModifiers());
            } else {
                _ = current.callbacks.scroll(current.callbacks.userdata, steps * 3);
                _ = c.InvalidateRect(window, null, c.FALSE);
            }
            return 0;
        },
        c.WM_CAPTURECHANGED, c.WM_CANCELMODE => {
            releaseMouseCapture(current);
            _ = c.InvalidateRect(window, null, c.FALSE);
            return 0;
        },
        c.WM_KEYDOWN, c.WM_SYSKEYDOWN => {
            const control = @intFromBool(keyDown(c.VK_CONTROL));
            const shift = @intFromBool(keyDown(c.VK_SHIFT));
            const alt = @intFromBool(keyDown(c.VK_MENU));
            var suppress_character: c_int = 0;
            const action = Logic.noctty_windows_decode_key_action(@truncate(word), control, shift, alt, current.remote_mode, &suppress_character);
            if (suppress_character != 0) current.suppress_character = 1;
            switch (action) {
                Logic.key_action_copy => copyTerminal(current),
                Logic.key_action_paste => pasteClipboard(current),
                Logic.key_action_new_tab => _ = workspaceAction(current, action_new_tab),
                Logic.key_action_split_down => _ = workspaceAction(current, action_split_down),
                Logic.key_action_split_left => _ = workspaceAction(current, action_split_left),
                Logic.key_action_close_tab => _ = workspaceClose(current, close_tab, query_close_tab),
                Logic.key_action_close_pane => _ = workspaceClose(current, close_pane, query_close_pane),
                Logic.key_action_cycle => cycleWorkspace(current, if (current.remote_mode != 0) shift == 0 else shift != 0),
                Logic.key_action_special => sendSpecialKey(current, word),
                else => return c.DefWindowProcW(window, message, word, long_value),
            }
            return 0;
        },
        c.WM_CHAR => {
            if (current.suppress_character != 0) {
                current.suppress_character = 0;
                return 0;
            }
            if (word == c.VK_RETURN) {
                const carriage_return = [_]u8{'\r'};
                _ = writeTerminal(current, &carriage_return, carriage_return.len);
            } else if (word == c.VK_BACK) {
                const backspace = [_]u8{0x7f};
                _ = writeTerminal(current, &backspace, backspace.len);
            } else {
                sendWideCharacter(current, @truncate(word));
            }
            return 0;
        },
        c.WM_SYSCHAR => {
            if (word == c.VK_RETURN) return 0;
            if (!keyDown(c.VK_CONTROL) and Menu.isMnemonic(current.menu, @truncate(word)))
                return c.DefWindowProcW(window, message, word, long_value);
            const escape = [_]u8{0x1b};
            _ = writeTerminal(current, &escape, escape.len);
            sendWideCharacter(current, @truncate(word));
            return 0;
        },
        output_message => {
            if (word < max_sessions) drainOutput(current, @intCast(word));
            return 0;
        },
        c.WM_TIMER => {
            onTimer(current);
            return 0;
        },
        c.WM_CLOSE => {
            _ = c.DestroyWindow(window);
            return 0;
        },
        c.WM_DESTROY => {
            _ = c.KillTimer(window, timer_id);
            c.PostQuitMessage(current.exit_code);
            return 0;
        },
        else => return c.DefWindowProcW(window, message, word, long_value),
    }
}

fn drainRemoteInput(host: *Host) void {
    var input: [@import("noctty_share").protocol.max_input_bytes]u8 = undefined;
    const session_index = host.callbacks.remote_pane(host.callbacks.userdata);
    if (Logic.noctty_windows_session_is_live(&host.workspace, session_index) == 0) return;
    const session = &host.sessions[@intCast(session_index)];
    for (0..16) |_| {
        const count = host.callbacks.take_remote(host.callbacks.userdata, host.window, &input, input.len);
        if (count <= 0) break;
        if (c.IsWindow(host.window) == 0 or
            host.callbacks.remote_pane(host.callbacks.userdata) != session_index or
            Logic.noctty_windows_session_is_live(&host.workspace, session_index) == 0) break;
        if (!writeSession(session, &input, @intCast(count))) break;
    }
}

fn onTimer(host: *Host) void {
    if (host.timer_active) return;
    host.timer_active = true;
    defer host.timer_active = false;
    for (&host.sessions, 0..) |*session, index| {
        if (Logic.noctty_windows_session_is_live(&host.workspace, @intCast(index)) == 0) continue;
        drainOutput(host, @intCast(index));
        var process_exit_code: u32 = 255;
        if (Pty.noctty_windows_pty_poll_exit(session.pty, &process_exit_code) != 0) {
            updateTitle(host);
            _ = c.InvalidateRect(host.window, null, c.FALSE);
        }
    }
    drainRemoteInput(host);
    if (c.IsWindow(host.window) == 0) return;
    if (host.remote_mode != 0) {
        updateTitle(host);
        _ = c.InvalidateRect(host.window, null, c.FALSE);
    }
    host.smoke_ticks +%= 1;
    const smoke_session = activeSession(host);
    if (host.smoke_mode == 0 or smoke_session == null or Pty.noctty_windows_pty_exited(smoke_session.?.pty) == 0) return;
    const marker = host.callbacks.smoke_ready(host.callbacks.userdata);
    if (marker != 0 and host.smoke_marker_seen == 0) {
        host.smoke_marker_seen = 1;
        host.smoke_marker_paint_count = host.paint_count;
        _ = c.InvalidateRect(host.window, null, c.FALSE);
        _ = c.UpdateWindow(host.window);
    }
    if (marker != 0 and host.smoke_marker_seen != 0 and host.paint_count > host.smoke_marker_paint_count and
        Pty.noctty_windows_pty_exit_code(smoke_session.?.pty) == 0 and
        host.settings_menu_ready != 0 and host.preferences_ready != 0 and
        host.smoke_mouse_input != 0 and host.smoke_coordinates != 0 and
        host.smoke_selection != 0 and host.smoke_clipboard != 0)
    {
        log("windows_host_smoke conpty=true vt=true gdi=true settings_menu=true preferences=true mouse_input=true coordinates=true selection=true clipboard=true clean_exit=true\r\n", .{});
        host.exit_code = 0;
        _ = c.DestroyWindow(host.window);
    } else if (host.smoke_ticks > 625) {
        log(
            "windows_host_smoke conpty=true vt={s} gdi={s} mouse_input={s} coordinates={s} selection={s} clipboard={s} process_exit={d} clean_exit=false\r\n",
            .{
                boolText(marker != 0),
                boolText(host.paint_count > 0),
                boolText(host.smoke_mouse_input != 0),
                boolText(host.smoke_coordinates != 0),
                boolText(host.smoke_selection != 0),
                boolText(host.smoke_clipboard != 0),
                Pty.noctty_windows_pty_exit_code(smoke_session.?.pty),
            },
        );
        host.exit_code = 2;
        _ = c.DestroyWindow(host.window);
    }
}

fn inputSmokeObservables(host: *Host) void {
    const clipboard_probe = "NCT-中";
    var wide_probe: [16]u16 = undefined;
    const wide_count = c.MultiByteToWideChar(
        c.CP_UTF8,
        c.MB_ERR_INVALID_CHARS,
        @ptrCast(clipboard_probe.ptr),
        @intCast(clipboard_probe.len),
        @ptrCast(&wide_probe),
        @intCast(wide_probe.len),
    );
    host.smoke_clipboard = @intFromBool(wide_count == 5 and wide_probe[4] == 0x4e2d);
    host.smoke_mouse_input = 0;
    host.smoke_coordinates = 0;
    host.smoke_selection = 0;
    const pane_index = host.callbacks.active_pane(host.callbacks.userdata);
    if (pane_index < 0) return;
    const mode = host.callbacks.pane_mouse_mode(host.callbacks.userdata, pane_index);
    host.smoke_mouse_input = @intFromBool((mode & ~(mouse_tracking_mask | mouse_encoding_sgr)) == 0);
    if (host.smoke_mode != 0 and host.remote_mode == 0) {
        const enable_mouse = "\x1b[?1003h\x1b[?1006h";
        const disable_mouse = "\x1b[?1003l\x1b[?1006l";
        const expected = "\x1b[<48;3;4M";
        var encoded: [64]u8 = undefined;
        var encoded_length: c_int = -1;
        if (host.callbacks.pane_feed(host.callbacks.userdata, pane_index, enable_mouse.ptr, enable_mouse.len) >= 0 and
            host.callbacks.pane_mouse_mode(host.callbacks.userdata, pane_index) == (3 | mouse_encoding_sgr))
        {
            encoded_length = host.callbacks.pane_mouse_encode(
                host.callbacks.userdata,
                pane_index,
                2,
                3,
                0,
                Logic.mouse_motion,
                mouse_mod_control,
                &encoded,
                encoded.len,
            );
        }
        host.smoke_mouse_input = @intFromBool(
            encoded_length == @as(c_int, @intCast(expected.len)) and std.mem.eql(u8, encoded[0..@intCast(@max(encoded_length, 0))], expected),
        );
        _ = host.callbacks.pane_feed(host.callbacks.userdata, pane_index, disable_mouse.ptr, disable_mouse.len);
    }
    var client: c.RECT = undefined;
    _ = c.GetClientRect(host.window, &client);
    var geometry: PaneHit = .{};
    if (!paneGeometry(host, pane_index, &client, &geometry)) return;
    var first: PaneHit = .{};
    var last: PaneHit = .{};
    if (cellForPane(host, pane_index, geometry.content.left, geometry.content.top, 0, &first) and
        first.inside_content != 0 and first.column == 0 and first.row == 0 and
        cellForPane(host, pane_index, geometry.content.right - 1, geometry.content.bottom - 1, 0, &last) and
        last.inside_content != 0 and last.column == geometry.columns - 1 and last.row == geometry.rows - 1)
    {
        host.smoke_coordinates = 1;
    }
    host.mouse.selection_active = 1;
    host.mouse.selection_pane = pane_index;
    host.mouse.selection_anchor_column = 4;
    host.mouse.selection_anchor_row = 3;
    host.mouse.selection_extent_column = 1;
    host.mouse.selection_extent_row = 1;
    host.smoke_selection = @intFromBool(
        cellSelected(host, pane_index, 1, 1) and
            cellSelected(host, pane_index, 4, 3) and
            !cellSelected(host, pane_index, 0, 0),
    );
    host.mouse.selection_active = 0;
    host.mouse.selection_pane = -1;
}

fn cleanup(host: *Host) void {
    cleanupAllSessions(host);
    Fonts.noctty_windows_fonts_deinit(@ptrCast(&host.font_normal), @ptrCast(&host.font_bold));
    Menu.noctty_windows_menu_deinit(host.menu);
    host.menu = null;
    log("windows_exit clean=true\r\n", .{});
    Diagnostics.noctty_windows_diagnostics_deinit();
}

fn boolText(value: bool) []const u8 {
    return if (value) "true" else "false";
}

fn wide(comptime text: []const u8) [*:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}

pub fn run(instance: c.HINSTANCE, show_command: c_int, callbacks: *const Callbacks) c_int {
    const class_name = wide("NOCTTY.Windows.NativeHost");
    initializeLogging();
    const heap = c.GetProcessHeap() orelse return 1;
    const raw_host = c.HeapAlloc(heap, c.HEAP_ZERO_MEMORY, @sizeOf(Host)) orelse return 1;
    const host: *Host = @ptrCast(@alignCast(raw_host));
    host.* = .{ .callbacks = callbacks };
    if (Logic.noctty_windows_workspace_state_init(&host.workspace) == 0) {
        _ = c.HeapFree(heap, 0, raw_host);
        return 1;
    }
    _ = loadPreferences(host);
    var smoke_value: [8]u16 = undefined;
    const smoke_length = c.GetEnvironmentVariableW(
        wide("NOCTTY_WINDOWS_HOST_SMOKE"),
        &smoke_value,
        @intCast(smoke_value.len),
    );
    host.smoke_mode = @intFromBool(smoke_length > 0 and smoke_value[0] != '0');
    const menu_smoke_length = c.GetEnvironmentVariableW(
        wide("NOCTTY_WINDOWS_MENU_SMOKE"),
        &smoke_value,
        @intCast(smoke_value.len),
    );
    const menu_smoke = menu_smoke_length > 0 and smoke_value[0] != '0';
    host.mouse.selection_pane = -1;
    host.mouse.capture_pane = -1;

    var window_class: c.WNDCLASSEXW = std.mem.zeroes(c.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(c.WNDCLASSEXW);
    window_class.style = c.CS_HREDRAW | c.CS_VREDRAW | c.CS_DBLCLKS;
    window_class.lpfnWndProc = windowProc;
    window_class.hInstance = instance;
    window_class.hCursor = LoadCursorW(null, @ptrFromInt(32513));
    window_class.hIcon = LoadIconW(null, @ptrFromInt(32512));
    window_class.hbrBackground = c.GetSysColorBrush(c.COLOR_WINDOW);
    window_class.lpszClassName = class_name;

    var exit_code: c_int = 1;
    var session_started = false;
    defer {
        if (session_started) _ = callbacks.stop(callbacks.userdata);
        if (host.window != null and c.IsWindow(host.window) != 0) _ = c.DestroyWindow(host.window);
        cleanup(host);
        _ = c.HeapFree(heap, 0, raw_host);
    }
    if (c.RegisterClassExW(&window_class) == 0 and c.GetLastError() != c.ERROR_CLASS_ALREADY_EXISTS) {
        log("window_class_failed error={d}\r\n", .{c.GetLastError()});
        return exit_code;
    }
    host.window = c.CreateWindowExW(
        0,
        class_name,
        wide("NOCTTY Windows alpha"),
        c.WS_OVERLAPPEDWINDOW | c.WS_CLIPCHILDREN,
        c.CW_USEDEFAULT,
        c.CW_USEDEFAULT,
        window_width,
        window_height,
        null,
        null,
        instance,
        host,
    );
    if (host.window == null) {
        log("window_create_failed error={d}\r\n", .{c.GetLastError()});
        return exit_code;
    }
    if (!createMenu(host)) {
        if (menu_smoke) {
            log("windows_menu_smoke passed=false conpty=false\r\n", .{});
            return 2;
        }
        _ = c.MessageBoxW(host.window, wide("NOCTTY could not create its native menu."), wide("NOCTTY Windows alpha"), c.MB_OK | c.MB_ICONERROR);
        return exit_code;
    }
    if (!host.tabs.create(host.window)) {
        log("tab_strip_create_failed error={d}\r\n", .{c.GetLastError()});
        if (!menu_smoke) _ = c.MessageBoxW(host.window, wide("NOCTTY could not create its native tab strip."), wide("NOCTTY Windows alpha"), c.MB_OK | c.MB_ICONERROR);
        return exit_code;
    }
    var dpi = c.GetDpiForWindow(host.window);
    if (dpi == 0) dpi = 96;
    if (!createFonts(host, dpi) or !host.tabs.sync(callbacks)) {
        log("tab_strip_initialize_failed\r\n", .{});
        if (!menu_smoke) _ = c.MessageBoxW(host.window, wide("NOCTTY could not initialize its native tab strip."), wide("NOCTTY Windows alpha"), c.MB_OK | c.MB_ICONERROR);
        return exit_code;
    }
    if (menu_smoke) {
        if (!menuSmoke(host)) {
            log("windows_menu_smoke passed=false conpty=false\r\n", .{});
            return 2;
        }
        log("windows_menu_smoke menu_tree=true local_commands=true remote_disabled=true remote_dispatch_rejected=true cycle_hints=true terminal_commands=true ownership=true conpty=false tab_strip=true tab_selection=true tab_rename=true tab_reorder=true tab_inset=true\r\n", .{});
        return 0;
    }
    const start_mode = callbacks.start(callbacks.userdata);
    if (start_mode < 0) {
        _ = c.MessageBoxW(host.window, wide("NOCTTY could not start this session."), wide("NOCTTY Windows alpha"), c.MB_OK | c.MB_ICONERROR);
        return exit_code;
    }
    session_started = true;
    host.remote_mode = @intFromBool(start_mode > 0);
    updateMenu(host);
    var client: c.RECT = undefined;
    _ = c.GetClientRect(host.window, &client);
    resizeTerminal(host, client.right, client.bottom);
    if (!startWorkspaceSessions(host)) {
        _ = c.MessageBoxW(
            host.window,
            wide("NOCTTY could not start Windows ConPTY. Windows 10 version 1809 or newer is required."),
            wide("NOCTTY Windows alpha"),
            c.MB_OK | c.MB_ICONERROR,
        );
        return exit_code;
    }
    inputSmokeObservables(host);
    _ = c.SetTimer(host.window, timer_id, timer_interval_ms, null);
    _ = c.ShowWindow(host.window, if (show_command == 0) c.SW_SHOW else show_command);
    _ = c.UpdateWindow(host.window);
    _ = c.SetFocus(host.window);

    var message: c.MSG = undefined;
    while (c.GetMessageW(&message, null, 0, 0) > 0) {
        // Function keys remain terminal input unless the tab control owns focus.
        if (message.hwnd == host.tabs.window and message.message == c.WM_KEYDOWN) {
            if (message.wParam == c.VK_F2) {
                renameTab(host);
                continue;
            }
            if (message.wParam == c.VK_RETURN or message.wParam == c.VK_ESCAPE or message.wParam == c.VK_TAB) {
                _ = c.SetFocus(host.window);
                continue;
            }
        }
        _ = c.TranslateMessage(&message);
        _ = c.DispatchMessageW(&message);
    }
    exit_code = @intCast(message.wParam);
    return exit_code;
}
