//! Win32/RichEdit adapter for the experimental NoctEd Windows build.
//!
//! The document model remains in `nocted_main.zig`; this module owns HWND,
//! menu, font, dialog, accelerator, and common-control lifetimes.

const std = @import("std");
const windows = std.os.windows;
const allocator = std.heap.page_allocator;

const c = @import("c");

const abi_version: u32 = 3;
pub const close_ok: c_int = 1;
const close_dirty: c_int = 2;
const save_needs_path: c_int = 2;
const font_size_default: c_int = 11;
const font_size_min: c_int = 8;
const font_size_max: c_int = 32;
const invalid_index = std.math.maxInt(usize);
const tab_count_max: usize = 32;
const text_bytes_max: usize = 1024 * 1024;
// The model accepts complete read-only previews through this bound.
const preview_bytes_max: usize = 8 * 1024 * 1024;
const path_wide_capacity: usize = 32_768;

const id_file_new: u16 = 41001;
const id_file_open: u16 = 41002;
const id_file_open_folder: u16 = 41003;
const id_file_save: u16 = 41004;
const id_file_save_as: u16 = 41005;
const id_file_close: u16 = 41006;
const id_file_exit: u16 = 41007;
const id_edit_undo: u16 = 41101;
const id_edit_redo: u16 = 41102;
const id_edit_cut: u16 = 41103;
const id_edit_copy: u16 = 41104;
const id_edit_paste: u16 = 41105;
const id_edit_select_all: u16 = 41106;
const id_edit_find: u16 = 41107;
const id_view_zoom_in: u16 = 41201;
const id_view_zoom_out: u16 = 41202;
const id_view_zoom_reset: u16 = 41203;
const id_settings_font_size: u16 = 41301;
const id_control_tabs: u16 = 42001;
const id_control_tree: u16 = 42002;
const id_control_editor: u16 = 42003;
const id_control_status: u16 = 42004;
const id_control_find: u16 = 42005;
const id_control_find_next: u16 = 42006;
const id_settings_size_edit: u16 = 43001;
const id_settings_size_spin: u16 = 43002;

const editor_class = std.unicode.utf8ToUtf16LeStringLiteral("NoctEdWindowsEditor");
const settings_class = std.unicode.utf8ToUtf16LeStringLiteral("NoctEdWindowsSettings");
const title_nocted = std.unicode.utf8ToUtf16LeStringLiteral("NoctEd");

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

const tcm_first: c.UINT = 0x1300;
const tcm_delete_all_items: c.UINT = tcm_first + 9;
const tcm_get_current_selection: c.UINT = tcm_first + 11;
const tcm_set_current_selection: c.UINT = tcm_first + 12;
const tcm_insert_item_w: c.UINT = tcm_first + 62;
const tv_first: c.UINT = 0x1100;
const tvm_delete_item: c.UINT = tv_first + 1;
const tvm_expand: c.UINT = tv_first + 2;
const tvm_get_count: c.UINT = tv_first + 5;
const tvm_get_next_item: c.UINT = tv_first + 10;
const tvm_insert_item_w: c.UINT = tv_first + 50;
const tvm_get_item_w: c.UINT = tv_first + 62;
const tvgn_caret: c.WPARAM = 9;

extern "user32" fn LoadCursorW(
    c.HINSTANCE,
    ?*align(1) const anyopaque,
) callconv(.winapi) c.HCURSOR;
extern "user32" fn LoadIconW(
    c.HINSTANCE,
    ?*align(1) const anyopaque,
) callconv(.winapi) c.HICON;
extern "user32" fn GetSysColorBrush(c_int) callconv(.winapi) c.HBRUSH;

pub const NewDocument = *const fn (?*anyopaque) callconv(.c) c_int;
pub const PathCommand = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
pub const ProjectEntryCommand = *const fn (?*anyopaque, usize) callconv(.c) c_int;
pub const SaveDocument = *const fn (?*anyopaque, ?[*]const u8, usize) callconv(.c) c_int;
pub const CloseDocument = *const fn (?*anyopaque, usize, c_int) callconv(.c) c_int;
pub const DiscardDocument = *const fn (?*anyopaque, usize) callconv(.c) c_int;
pub const ActivateDocument = *const fn (?*anyopaque, usize) callconv(.c) c_int;
pub const ReplaceContents = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
pub const Count = *const fn (?*anyopaque) callconv(.c) usize;
pub const TabTitle = *const fn (
    ?*anyopaque,
    usize,
    [*]u8,
    usize,
    *c_int,
    *c_int,
) callconv(.c) usize;
pub const CopyBytes = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) usize;
pub const ProjectEntry = *const fn (
    ?*anyopaque,
    usize,
    [*]u8,
    usize,
    *usize,
    *c_int,
) callconv(.c) usize;
pub const Persist = *const fn (?*anyopaque) callconv(.c) c_int;
pub const GetInt = *const fn (?*anyopaque) callconv(.c) c_int;
pub const SetInt = *const fn (?*anyopaque, c_int) callconv(.c) c_int;

pub const Callbacks = extern struct {
    abi_version: u32 = abi_version,
    userdata: ?*anyopaque,
    new_document: NewDocument,
    open_document: PathCommand,
    open_project: PathCommand,
    open_project_entry: ProjectEntryCommand,
    save_document: SaveDocument,
    close_document: CloseDocument,
    discard_document: DiscardDocument,
    activate_document: ActivateDocument,
    replace_contents: ReplaceContents,
    tab_count: Count,
    active_tab: Count,
    tab_title: TabTitle,
    active_content_length: Count,
    active_content: CopyBytes,
    active_path: CopyBytes,
    project_name: CopyBytes,
    project_entry_count: Count,
    project_entry: ProjectEntry,
    last_error: CopyBytes,
    persist_session: Persist,
    editor_font_size: GetInt,
    set_editor_font_size: SetInt,
};

const Host = struct {
    instance: c.HINSTANCE,
    window: c.HWND = null,
    tabs: c.HWND = null,
    tree: c.HWND = null,
    editor: c.HWND = null,
    status: c.HWND = null,
    find_edit: c.HWND = null,
    find_button: c.HWND = null,
    settings_window: c.HWND = null,
    settings_size_edit: c.HWND = null,
    ui_font: c.HFONT = null,
    editor_font: c.HFONT = null,
    accelerators: c.HACCEL = null,
    rich_edit: c.HMODULE = null,
    callbacks: *const Callbacks,
    suppress_change: bool = false,
    editor_state: enum { unavailable, read_only, editable } = .unavailable,
    find_visible: bool = false,
    editor_font_size: c_int = font_size_default,
    zoom_wheel_delta: c_int = 0,
    dpi: c.UINT = 96,
};

fn handleWord(value: usize) u16 {
    return @truncate(value);
}

fn highWord(value: usize) u16 {
    return @truncate(value >> 16);
}

fn pointerFromLong(comptime T: type, value: c.LPARAM) *T {
    return @ptrFromInt(@as(usize, @bitCast(value)));
}

fn hostFromWindow(window: c.HWND) ?*Host {
    const value = c.GetWindowLongPtrW(window, c.GWLP_USERDATA);
    if (value == 0) return null;
    return @ptrFromInt(@as(usize, @bitCast(value)));
}

fn wordFromHandle(handle: anytype) c.WPARAM {
    return if (handle) |value| @intFromPtr(value) else 0;
}

fn longFromPointer(pointer: anytype) c.LPARAM {
    return @bitCast(@as(usize, @intFromPtr(pointer)));
}

fn menuFromId(id: u16) ?*align(1) anyopaque {
    return @ptrFromInt(id);
}

fn utf8ToWideAlloc(bytes: []const u8) ![:0]u16 {
    return std.unicode.utf8ToUtf16LeAllocZ(allocator, bytes);
}

fn wideToWtf8Alloc(wide: [*:0]const u16) ![]u8 {
    const source = std.mem.span(wide);
    const output = try allocator.alloc(u8, @max(source.len * 3, 1));
    const length = std.unicode.wtf16LeToWtf8(output, source);
    return allocator.realloc(output, length);
}

fn callbackText(host: *Host, callback: CopyBytes) ![:0]u16 {
    var ignored: u8 = 0;
    const length = callback(host.callbacks.userdata, @ptrCast(&ignored), 0);
    if (length > text_bytes_max) return error.CallbackTextTooLarge;
    const bytes = try allocator.alloc(u8, length);
    defer allocator.free(bytes);
    if (length != 0 and callback(host.callbacks.userdata, bytes.ptr, length) != length)
        return error.CallbackTextChanged;
    return utf8ToWideAlloc(bytes);
}

fn showMessage(owner: c.HWND, message: [*:0]const u16, flags: c_long) void {
    _ = c.MessageBoxW(owner, message, title_nocted, @intCast(c.MB_OK | flags));
}

fn showError(host: *Host, fallback: [*:0]const u16) void {
    const detail = callbackText(host, host.callbacks.last_error) catch {
        showMessage(host.window, fallback, c.MB_ICONERROR);
        return;
    };
    defer allocator.free(detail);
    showMessage(
        host.window,
        if (detail.len == 0) fallback else detail.ptr,
        c.MB_ICONERROR,
    );
}

fn windowDpi(window: c.HWND) c.UINT {
    const user = c.GetModuleHandleW(std.unicode.utf8ToUtf16LeStringLiteral("user32.dll"));
    if (user == null) return 96;
    const raw = c.GetProcAddress(user, "GetDpiForWindow") orelse return 96;
    const Function = *const fn (c.HWND) callconv(.winapi) c.UINT;
    const function: Function = @ptrCast(raw);
    return function(window);
}

fn deleteObject(object: anytype) void {
    if (object != null) _ = c.DeleteObject(object);
}

fn updateFont(host: *Host) void {
    var description: c.LOGFONTW = std.mem.zeroes(c.LOGFONTW);
    description.lfHeight = -c.MulDiv(11, @intCast(host.dpi), 72);
    const face = std.unicode.utf8ToUtf16LeStringLiteral("Consolas");
    @memcpy(description.lfFaceName[0..face.len], face);
    const next_ui = c.CreateFontIndirectW(&description);
    description.lfHeight = -c.MulDiv(host.editor_font_size, @intCast(host.dpi), 72);
    const next_editor = c.CreateFontIndirectW(&description);
    if (next_ui == null or next_editor == null) {
        deleteObject(next_ui);
        deleteObject(next_editor);
        return;
    }
    _ = c.SendMessageW(host.editor, c.WM_SETFONT, wordFromHandle(next_editor), 1);
    for ([_]c.HWND{ host.tabs, host.tree, host.status, host.find_edit, host.find_button }) |control| {
        _ = c.SendMessageW(control, c.WM_SETFONT, wordFromHandle(next_ui), 1);
    }
    if (host.settings_window != null) {
        var child = c.GetWindow(host.settings_window, c.GW_CHILD);
        while (child != null) : (child = c.GetWindow(child, c.GW_HWNDNEXT)) {
            _ = c.SendMessageW(child, c.WM_SETFONT, wordFromHandle(next_ui), 1);
        }
    }
    deleteObject(host.ui_font);
    deleteObject(host.editor_font);
    host.ui_font = next_ui;
    host.editor_font = next_editor;
}

fn applyEditorFontSize(host: *Host, value: c_int) bool {
    if (value < font_size_min or value > font_size_max) return false;
    if (value == host.editor_font_size) return true;
    if (host.callbacks.set_editor_font_size(host.callbacks.userdata, value) <= 0) {
        showError(
            host,
            std.unicode.utf8ToUtf16LeStringLiteral(
                "The editor font size could not be saved.",
            ),
        );
        return false;
    }
    host.editor_font_size = value;
    updateFont(host);
    updateChrome(host);
    return true;
}

fn openSettings(host: *Host) void {
    if (host.settings_window != null and c.IsWindow(host.settings_window) != 0) {
        _ = c.ShowWindow(host.settings_window, c.SW_SHOWNORMAL);
        _ = c.SetForegroundWindow(host.settings_window);
        _ = c.SetFocus(host.settings_size_edit);
        return;
    }
    const width = c.MulDiv(360, @intCast(host.dpi), 96);
    const height = c.MulDiv(180, @intCast(host.dpi), 96);
    host.settings_window = createWindowExW(
        c.WS_EX_DLGMODALFRAME | c.WS_EX_CONTROLPARENT,
        settings_class,
        std.unicode.utf8ToUtf16LeStringLiteral("NoctEd Settings"),
        c.WS_POPUP | c.WS_CAPTION | c.WS_SYSMENU,
        c.CW_USEDEFAULT,
        c.CW_USEDEFAULT,
        width,
        height,
        host.window,
        null,
        host.instance,
        host,
    );
    if (host.settings_window == null) {
        showMessage(
            host.window,
            std.unicode.utf8ToUtf16LeStringLiteral(
                "The Settings window could not be opened.",
            ),
            c.MB_ICONERROR,
        );
        return;
    }
    var owner: c.RECT = undefined;
    var settings: c.RECT = undefined;
    _ = c.GetWindowRect(host.window, &owner);
    _ = c.GetWindowRect(host.settings_window, &settings);
    const x = owner.left + @divTrunc(
        (owner.right - owner.left) - (settings.right - settings.left),
        2,
    );
    const y = owner.top + @divTrunc(
        (owner.bottom - owner.top) - (settings.bottom - settings.top),
        2,
    );
    _ = c.SetWindowPos(
        host.settings_window,
        c.HWND_TOP,
        x,
        y,
        0,
        0,
        c.SWP_NOSIZE | c.SWP_SHOWWINDOW,
    );
    _ = c.SetFocus(host.settings_size_edit);
    _ = c.SendMessageW(host.settings_size_edit, c.EM_SETSEL, 0, -1);
}

fn settingsWindowProc(
    window: c.HWND,
    message: c.UINT,
    word: c.WPARAM,
    long_value: c.LPARAM,
) callconv(.winapi) c.LRESULT {
    var host = hostFromWindow(window);
    if (message == c.WM_NCCREATE) {
        const create = pointerFromLong(c.CREATESTRUCTW, long_value);
        host = @ptrCast(@alignCast(create.lpCreateParams.?));
        _ = c.SetWindowLongPtrW(
            window,
            c.GWLP_USERDATA,
            @bitCast(@as(usize, @intFromPtr(host.?))),
        );
    }
    const state = host orelse return c.DefWindowProcW(window, message, word, long_value);
    switch (message) {
        c.WM_CREATE => {
            const left = c.MulDiv(20, @intCast(state.dpi), 96);
            const top = c.MulDiv(22, @intCast(state.dpi), 96);
            const row_height = c.MulDiv(26, @intCast(state.dpi), 96);
            const label = createWindowExW(
                0,
                std.unicode.utf8ToUtf16LeStringLiteral("STATIC"),
                std.unicode.utf8ToUtf16LeStringLiteral("Editor font size (8–32 pt):"),
                c.WS_CHILD | c.WS_VISIBLE | c.SS_LEFT,
                left,
                top,
                c.MulDiv(205, @intCast(state.dpi), 96),
                row_height,
                window,
                null,
                state.instance,
                null,
            );
            state.settings_size_edit = createWindowExW(
                c.WS_EX_CLIENTEDGE,
                std.unicode.utf8ToUtf16LeStringLiteral("EDIT"),
                std.unicode.utf8ToUtf16LeStringLiteral(""),
                c.WS_CHILD | c.WS_VISIBLE | c.WS_TABSTOP | c.ES_NUMBER | c.ES_AUTOHSCROLL,
                c.MulDiv(235, @intCast(state.dpi), 96),
                top,
                c.MulDiv(70, @intCast(state.dpi), 96),
                row_height,
                window,
                menuFromId(id_settings_size_edit),
                state.instance,
                null,
            );
            const spin = createWindowExW(
                0,
                std.unicode.utf8ToUtf16LeStringLiteral("msctls_updown32"),
                std.unicode.utf8ToUtf16LeStringLiteral(""),
                c.WS_CHILD | c.WS_VISIBLE | c.UDS_ALIGNRIGHT | c.UDS_SETBUDDYINT |
                    c.UDS_ARROWKEYS,
                0,
                0,
                0,
                0,
                window,
                menuFromId(id_settings_size_spin),
                state.instance,
                null,
            );
            const ok = createWindowExW(
                0,
                std.unicode.utf8ToUtf16LeStringLiteral("BUTTON"),
                std.unicode.utf8ToUtf16LeStringLiteral("OK"),
                c.WS_CHILD | c.WS_VISIBLE | c.WS_TABSTOP | c.BS_DEFPUSHBUTTON,
                c.MulDiv(170, @intCast(state.dpi), 96),
                c.MulDiv(82, @intCast(state.dpi), 96),
                c.MulDiv(76, @intCast(state.dpi), 96),
                c.MulDiv(28, @intCast(state.dpi), 96),
                window,
                menuFromId(c.IDOK),
                state.instance,
                null,
            );
            const cancel = createWindowExW(
                0,
                std.unicode.utf8ToUtf16LeStringLiteral("BUTTON"),
                std.unicode.utf8ToUtf16LeStringLiteral("Cancel"),
                c.WS_CHILD | c.WS_VISIBLE | c.WS_TABSTOP | c.BS_PUSHBUTTON,
                c.MulDiv(252, @intCast(state.dpi), 96),
                c.MulDiv(82, @intCast(state.dpi), 96),
                c.MulDiv(76, @intCast(state.dpi), 96),
                c.MulDiv(28, @intCast(state.dpi), 96),
                window,
                menuFromId(c.IDCANCEL),
                state.instance,
                null,
            );
            if (label == null or state.settings_size_edit == null or
                spin == null or ok == null or cancel == null) return -1;
            _ = c.SendMessageW(spin, c.UDM_SETBUDDY, wordFromHandle(state.settings_size_edit), 0);
            _ = c.SendMessageW(spin, c.UDM_SETRANGE32, font_size_min, font_size_max);
            _ = c.SendMessageW(spin, c.UDM_SETPOS32, 0, state.editor_font_size);
            for ([_]c.HWND{ label, state.settings_size_edit, ok, cancel }) |control| {
                _ = c.SendMessageW(control, c.WM_SETFONT, wordFromHandle(state.ui_font), 1);
            }
            return 0;
        },
        c.WM_COMMAND => {
            const command = handleWord(word);
            if (command == c.IDOK) {
                var translated: c.BOOL = 0;
                const unsigned_value = c.GetDlgItemInt(
                    window,
                    id_settings_size_edit,
                    &translated,
                    0,
                );
                if (translated == 0 or unsigned_value > std.math.maxInt(c_int) or
                    !applyEditorFontSize(state, @intCast(unsigned_value)))
                {
                    if (translated == 0 or unsigned_value > std.math.maxInt(c_int) or
                        unsigned_value < font_size_min or unsigned_value > font_size_max)
                    {
                        showMessage(
                            window,
                            std.unicode.utf8ToUtf16LeStringLiteral(
                                "Enter an editor font size from 8 to 32 points.",
                            ),
                            c.MB_ICONWARNING,
                        );
                    }
                    return 0;
                }
                _ = c.DestroyWindow(window);
                return 0;
            }
            if (command == c.IDCANCEL) {
                _ = c.DestroyWindow(window);
                return 0;
            }
        },
        c.WM_CLOSE => {
            _ = c.DestroyWindow(window);
            return 0;
        },
        c.WM_DESTROY => {
            state.settings_window = null;
            state.settings_size_edit = null;
            if (c.IsWindow(state.editor) != 0) _ = c.SetFocus(state.editor);
            return 0;
        },
        else => {},
    }
    return c.DefWindowProcW(window, message, word, long_value);
}

fn editorSubclassProc(
    window: c.HWND,
    message: c.UINT,
    word: c.WPARAM,
    long_value: c.LPARAM,
    subclass_id: c.UINT_PTR,
    reference: c.DWORD_PTR,
) callconv(.winapi) c.LRESULT {
    const host: *Host = @ptrFromInt(reference);
    if (message == c.WM_MOUSEWHEEL and handleWord(word) & c.MK_CONTROL != 0) {
        const wheel_delta: i16 = @bitCast(highWord(word));
        host.zoom_wheel_delta += wheel_delta;
        while (host.zoom_wheel_delta >= c.WHEEL_DELTA) {
            host.zoom_wheel_delta -= c.WHEEL_DELTA;
            if (!applyEditorFontSize(host, host.editor_font_size + 1)) break;
        }
        while (host.zoom_wheel_delta <= -c.WHEEL_DELTA) {
            host.zoom_wheel_delta += c.WHEEL_DELTA;
            if (!applyEditorFontSize(host, host.editor_font_size - 1)) break;
        }
        return 0;
    }
    if (message == c.WM_NCDESTROY) {
        _ = c.RemoveWindowSubclass(window, editorSubclassProc, subclass_id);
    }
    return c.DefSubclassProc(window, message, word, long_value);
}

fn layout(host: *Host) void {
    var client: c.RECT = undefined;
    _ = c.GetClientRect(host.window, &client);
    const width = client.right;
    const height = client.bottom;
    const tree_width = if (host.callbacks.project_entry_count(host.callbacks.userdata) != 0)
        c.MulDiv(260, @intCast(host.dpi), 96)
    else
        0;
    const status_height = c.MulDiv(24, @intCast(host.dpi), 96);
    const tab_height = c.MulDiv(30, @intCast(host.dpi), 96);
    const find_height = if (host.find_visible) c.MulDiv(30, @intCast(host.dpi), 96) else 0;
    const bottom = height - status_height;
    _ = c.MoveWindow(host.tabs, tree_width, 0, width - tree_width, tab_height, 1);
    _ = c.MoveWindow(host.tree, 0, 0, tree_width, bottom, 1);
    _ = c.ShowWindow(host.tree, if (tree_width != 0) c.SW_SHOW else c.SW_HIDE);
    _ = c.MoveWindow(
        host.editor,
        tree_width,
        tab_height,
        width - tree_width,
        bottom - tab_height - find_height,
        1,
    );
    _ = c.MoveWindow(
        host.find_edit,
        tree_width + 4,
        bottom - find_height + 3,
        width - tree_width - 104,
        find_height - 6,
        1,
    );
    _ = c.MoveWindow(
        host.find_button,
        width - 96,
        bottom - find_height + 3,
        92,
        find_height - 6,
        1,
    );
    _ = c.ShowWindow(host.find_edit, if (host.find_visible) c.SW_SHOW else c.SW_HIDE);
    _ = c.ShowWindow(host.find_button, if (host.find_visible) c.SW_SHOW else c.SW_HIDE);
    _ = c.MoveWindow(host.status, 0, bottom, width, status_height, 1);
}

fn syncTabs(host: *Host) void {
    const count = @min(host.callbacks.tab_count(host.callbacks.userdata), tab_count_max);
    const active = host.callbacks.active_tab(host.callbacks.userdata);
    _ = c.SendMessageW(host.tabs, tcm_delete_all_items, 0, 0);
    for (0..count) |index| {
        var bytes: [2048]u8 = undefined;
        var dirty: c_int = 0;
        var read_only: c_int = 0;
        var length = host.callbacks.tab_title(
            host.callbacks.userdata,
            index,
            &bytes,
            bytes.len - 4,
            &dirty,
            &read_only,
        );
        length = @min(length, bytes.len - 4);
        if (dirty != 0) {
            bytes[length] = '*';
            length += 1;
        }
        const title = utf8ToWideAlloc(bytes[0..length]) catch continue;
        defer allocator.free(title);
        var item: c.TCITEMW = std.mem.zeroes(c.TCITEMW);
        item.mask = c.TCIF_TEXT;
        item.pszText = title.ptr;
        _ = c.SendMessageW(host.tabs, tcm_insert_item_w, index, longFromPointer(&item));
    }
    if (active != invalid_index and active < count)
        _ = c.SendMessageW(host.tabs, tcm_set_current_selection, active, 0);
}

fn syncEditor(host: *Host) void {
    host.suppress_change = true;
    defer host.suppress_change = false;
    host.editor_state = .unavailable;
    _ = c.EnableWindow(host.editor, 0);
    _ = c.SendMessageW(host.editor, c.EM_SETREADONLY, 1, 0);
    _ = c.SendMessageW(host.editor, c.EM_EMPTYUNDOBUFFER, 0, 0);
    // Hide the previous document even if replacing its text subsequently fails.
    _ = c.ShowWindow(host.editor, c.SW_HIDE);
    var failure: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral(
        "This document could not be displayed. Editing and saving are disabled.",
    );
    defer if (host.editor_state == .unavailable) {
        if (c.SetWindowTextW(host.editor, failure) != 0)
            _ = c.ShowWindow(host.editor, c.SW_SHOW);
        _ = c.SendMessageW(host.editor, c.EM_SETMODIFY, 0, 0);
    };
    const active = host.callbacks.active_tab(host.callbacks.userdata);
    if (active == invalid_index) return;
    var dirty: c_int = 0;
    var read_only: c_int = 1;
    var ignored: u8 = 0;
    _ = host.callbacks.tab_title(
        host.callbacks.userdata,
        active,
        @ptrCast(&ignored),
        0,
        &dirty,
        &read_only,
    );
    const length = host.callbacks.active_content_length(host.callbacks.userdata);
    if (length > preview_bytes_max) {
        failure = std.unicode.utf8ToUtf16LeStringLiteral(
            "This document exceeds the supported 8 MiB preview limit. Editing and saving are disabled.",
        );
        return;
    }
    const bytes = allocator.alloc(u8, length) catch return;
    defer allocator.free(bytes);
    if (length != 0 and
        host.callbacks.active_content(host.callbacks.userdata, bytes.ptr, length) != length) return;
    if (std.mem.indexOfScalar(u8, bytes, 0) != null) return;
    const wide = utf8ToWideAlloc(bytes) catch return;
    defer allocator.free(wide);
    const editable = read_only == 0 and length <= text_bytes_max;
    _ = c.SendMessageW(host.editor, c.EM_EXLIMITTEXT, 0, preview_bytes_max);
    if (c.SetWindowTextW(host.editor, wide.ptr) == 0) return;
    _ = c.SendMessageW(host.editor, c.EM_EXLIMITTEXT, 0, if (editable) text_bytes_max else preview_bytes_max);
    if (c.SendMessageW(host.editor, c.EM_SETREADONLY, @intFromBool(!editable), 0) == 0) return;
    _ = c.SendMessageW(host.editor, c.EM_SETMODIFY, 0, 0);
    host.editor_state = if (editable) .editable else .read_only;
    _ = c.EnableWindow(host.editor, 1);
    _ = c.ShowWindow(host.editor, c.SW_SHOW);
}

fn syncProject(host: *Host) void {
    const count = host.callbacks.project_entry_count(host.callbacks.userdata);
    _ = c.SendMessageW(host.tree, tvm_delete_item, 0, longFromPointer(c.TVI_ROOT));
    if (count == 0 or count > text_bytes_max) return;
    const items = allocator.alloc(c.HTREEITEM, count) catch return;
    defer allocator.free(items);
    @memset(items, null);
    for (0..count) |index| {
        var bytes: [4096]u8 = undefined;
        var parent: usize = invalid_index;
        var directory: c_int = 0;
        const requested = host.callbacks.project_entry(
            host.callbacks.userdata,
            index,
            &bytes,
            bytes.len,
            &parent,
            &directory,
        );
        const name = utf8ToWideAlloc(bytes[0..@min(requested, bytes.len)]) catch continue;
        defer allocator.free(name);
        var insert: c.TVINSERTSTRUCTW = std.mem.zeroes(c.TVINSERTSTRUCTW);
        insert.hParent = if (parent != invalid_index and parent < index) items[parent] else c.TVI_ROOT;
        insert.hInsertAfter = c.TVI_LAST;
        insert.unnamed_0.item.mask = c.TVIF_TEXT | c.TVIF_PARAM | c.TVIF_CHILDREN;
        insert.unnamed_0.item.pszText = name.ptr;
        insert.unnamed_0.item.lParam = @intCast(index);
        insert.unnamed_0.item.cChildren = @intFromBool(directory != 0);
        items[index] = @ptrFromInt(@as(usize, @bitCast(c.SendMessageW(
            host.tree,
            tvm_insert_item_w,
            0,
            longFromPointer(&insert),
        ))));
    }
}

fn setWindowTextJoined(
    window: c.HWND,
    prefix: []const u16,
    middle: []const u16,
    suffix: []const u16,
) void {
    var text: [path_wide_capacity:0]u16 = @splat(0);
    var length: usize = 0;
    for ([_][]const u16{ prefix, middle, suffix }) |part| {
        const count = @min(part.len, text.len - length - 1);
        @memcpy(text[length..][0..count], part[0..count]);
        length += count;
    }
    text[length] = 0;
    _ = c.SetWindowTextW(window, &text);
}

fn updateChrome(host: *Host) void {
    const menu = c.GetMenu(host.window);
    const save_flags: c.UINT = @intCast(c.MF_BYCOMMAND |
        (if (host.editor_state == .editable) c.MF_ENABLED else c.MF_GRAYED));
    _ = c.EnableMenuItem(menu, id_file_save, save_flags);
    _ = c.EnableMenuItem(menu, id_file_save_as, save_flags);
    if (host.editor_state == .unavailable) {
        _ = c.SetWindowTextW(host.status, std.unicode.utf8ToUtf16LeStringLiteral(
            "Document display unavailable. Editing and saving are disabled.",
        ));
    }
    const path = callbackText(host, host.callbacks.active_path) catch null;
    defer if (path) |value| allocator.free(value);
    const project = callbackText(host, host.callbacks.project_name) catch null;
    defer if (project) |value| allocator.free(value);
    const shown: []const u16 = if (path) |value|
        if (value.len != 0) value else std.unicode.utf8ToUtf16LeStringLiteral("Untitled")
    else
        std.unicode.utf8ToUtf16LeStringLiteral("Untitled");
    const project_shown: []const u16 = if (project) |value|
        if (value.len != 0) value else std.unicode.utf8ToUtf16LeStringLiteral("No project folder open")
    else
        std.unicode.utf8ToUtf16LeStringLiteral("No project folder open");
    setWindowTextJoined(
        host.window,
        &.{},
        shown,
        std.unicode.utf8ToUtf16LeStringLiteral(" - NoctEd"),
    );
    var font_ascii: [32]u8 = undefined;
    const font = std.fmt.bufPrint(&font_ascii, "  |  Editor font: {d} pt", .{host.editor_font_size}) catch
        "  |  Editor font";
    var font_wide: [64]u16 = undefined;
    const font_length = std.unicode.utf8ToUtf16Le(&font_wide, font) catch 0;
    if (host.editor_state != .unavailable) {
        const prefix: []const u16 = if (host.editor_state == .read_only)
            std.unicode.utf8ToUtf16LeStringLiteral("Read-only preview  |  ")
        else
            std.unicode.utf8ToUtf16LeStringLiteral("");
        setWindowTextJoined(host.status, prefix, project_shown, font_wide[0..font_length]);
    }
}

fn sync(host: *Host) void {
    syncTabs(host);
    syncEditor(host);
    syncProject(host);
    updateChrome(host);
    layout(host);
    _ = c.SetFocus(host.editor);
}

fn editorChanged(host: *Host) void {
    if (host.suppress_change or host.editor_state != .editable) return;
    const wide_length = c.GetWindowTextLengthW(host.editor);
    if (wide_length < 0 or wide_length > text_bytes_max) return;
    const wide = allocator.allocSentinel(u16, @intCast(wide_length), 0) catch return;
    defer allocator.free(wide);
    if (c.GetWindowTextW(host.editor, wide.ptr, wide_length + 1) < 0) return;
    const utf8 = wideToWtf8Alloc(wide.ptr) catch return;
    defer allocator.free(utf8);
    if (host.callbacks.replace_contents(host.callbacks.userdata, utf8.ptr, utf8.len) < 0) {
        showError(
            host,
            std.unicode.utf8ToUtf16LeStringLiteral("The edit could not be applied."),
        );
        syncEditor(host);
    } else {
        syncTabs(host);
        updateChrome(host);
    }
}

fn openFileDialog(host: *Host, project: bool) bool {
    var path: [path_wide_capacity:0]u16 = @splat(0);
    var dialog: c.OPENFILENAMEW = std.mem.zeroes(c.OPENFILENAMEW);
    dialog.lStructSize = @sizeOf(c.OPENFILENAMEW);
    dialog.hwndOwner = host.window;
    dialog.lpstrFile = &path;
    dialog.nMaxFile = path.len;
    dialog.lpstrFilter = if (project)
        std.unicode.utf8ToUtf16LeStringLiteral("NoctEd projects\x00*.npr\x00\x00")
    else
        std.unicode.utf8ToUtf16LeStringLiteral(
            "Text files\x00*.txt;*.zig;*.c;*.h;*.md;*.json;*.toml;*.yaml;*.yml\x00All files\x00*.*\x00\x00",
        );
    dialog.Flags = c.OFN_FILEMUSTEXIST | c.OFN_PATHMUSTEXIST | c.OFN_HIDEREADONLY | c.OFN_EXPLORER;
    if (c.GetOpenFileNameW(&dialog) == 0) return false;
    const utf8 = wideToWtf8Alloc(&path) catch return false;
    defer allocator.free(utf8);
    const result = if (project)
        host.callbacks.open_project(host.callbacks.userdata, utf8.ptr, utf8.len)
    else
        host.callbacks.open_document(host.callbacks.userdata, utf8.ptr, utf8.len);
    if (result < 0) {
        showError(
            host,
            if (project)
                std.unicode.utf8ToUtf16LeStringLiteral("The project could not be opened.")
            else
                std.unicode.utf8ToUtf16LeStringLiteral("The file could not be opened."),
        );
        return false;
    }
    sync(host);
    return true;
}

fn saveAs(host: *Host) bool {
    var path: [path_wide_capacity:0]u16 = @splat(0);
    if (callbackText(host, host.callbacks.active_path)) |current| {
        defer allocator.free(current);
        const count = @min(current.len, path.len - 1);
        @memcpy(path[0..count], current[0..count]);
        path[count] = 0;
    } else |_| {}
    var dialog: c.OPENFILENAMEW = std.mem.zeroes(c.OPENFILENAMEW);
    dialog.lStructSize = @sizeOf(c.OPENFILENAMEW);
    dialog.hwndOwner = host.window;
    dialog.lpstrFile = &path;
    dialog.nMaxFile = path.len;
    dialog.lpstrFilter = std.unicode.utf8ToUtf16LeStringLiteral(
        "Text files\x00*.txt\x00All files\x00*.*\x00\x00",
    );
    dialog.Flags = c.OFN_PATHMUSTEXIST | c.OFN_OVERWRITEPROMPT | c.OFN_EXPLORER;
    if (c.GetSaveFileNameW(&dialog) == 0) return false;
    const utf8 = wideToWtf8Alloc(&path) catch return false;
    defer allocator.free(utf8);
    if (host.callbacks.save_document(host.callbacks.userdata, utf8.ptr, utf8.len) != close_ok) {
        showError(
            host,
            std.unicode.utf8ToUtf16LeStringLiteral("The file could not be saved."),
        );
        return false;
    }
    sync(host);
    return true;
}

fn save(host: *Host, force_path: bool) bool {
    if (host.editor_state != .editable) return false;
    if (force_path) return saveAs(host);
    const result = host.callbacks.save_document(host.callbacks.userdata, null, 0);
    if (result == save_needs_path) return saveAs(host);
    if (result != close_ok) {
        showError(
            host,
            std.unicode.utf8ToUtf16LeStringLiteral("The file could not be saved."),
        );
        return false;
    }
    sync(host);
    return true;
}

fn closeCurrent(host: *Host, exiting: bool) bool {
    const active = host.callbacks.active_tab(host.callbacks.userdata);
    if (active == invalid_index) return true;
    var result = host.callbacks.close_document(host.callbacks.userdata, active, 0);
    if (result == close_dirty) {
        const answer = c.MessageBoxW(
            host.window,
            std.unicode.utf8ToUtf16LeStringLiteral(
                "Save changes before closing this document?",
            ),
            std.unicode.utf8ToUtf16LeStringLiteral("Unsaved changes"),
            c.MB_YESNOCANCEL | c.MB_ICONWARNING,
        );
        if (answer == c.IDCANCEL) return false;
        if (answer == c.IDYES and !save(host, false)) return false;
        result = host.callbacks.close_document(host.callbacks.userdata, active, 1);
    }
    if (result != close_ok) {
        showError(
            host,
            std.unicode.utf8ToUtf16LeStringLiteral("The document could not be closed."),
        );
        return false;
    }
    if (!exiting and host.callbacks.tab_count(host.callbacks.userdata) == 0) {
        if (host.callbacks.new_document(host.callbacks.userdata) < 0) return false;
    }
    if (!exiting) sync(host);
    return true;
}

fn confirmExit(host: *Host) bool {
    const count = host.callbacks.tab_count(host.callbacks.userdata);
    const original = host.callbacks.active_tab(host.callbacks.userdata);
    if (count > tab_count_max) {
        showMessage(
            host.window,
            std.unicode.utf8ToUtf16LeStringLiteral("Too many editor tabs are open."),
            c.MB_ICONERROR,
        );
        return false;
    }
    var discard: [tab_count_max]bool = @splat(false);
    for (0..count) |index| {
        var ignored: u8 = 0;
        var dirty: c_int = 0;
        var read_only: c_int = 0;
        _ = host.callbacks.tab_title(
            host.callbacks.userdata,
            index,
            @ptrCast(&ignored),
            0,
            &dirty,
            &read_only,
        );
        if (dirty == 0) continue;
        if (host.callbacks.activate_document(host.callbacks.userdata, index) == 0) return false;
        syncEditor(host);
        const answer = c.MessageBoxW(
            host.window,
            std.unicode.utf8ToUtf16LeStringLiteral("Save changes before exiting NoctEd?"),
            std.unicode.utf8ToUtf16LeStringLiteral("Unsaved changes"),
            c.MB_YESNOCANCEL | c.MB_ICONWARNING,
        );
        if (answer == c.IDCANCEL or answer == c.IDYES and !save(host, false)) {
            if (original < count)
                _ = host.callbacks.activate_document(host.callbacks.userdata, original);
            sync(host);
            return false;
        }
        if (answer == c.IDNO) discard[index] = true;
    }
    var index = count;
    while (index > 0) {
        index -= 1;
        if (discard[index] and
            host.callbacks.discard_document(host.callbacks.userdata, index) != close_ok)
        {
            showError(
                host,
                std.unicode.utf8ToUtf16LeStringLiteral(
                    "The document changes could not be discarded.",
                ),
            );
            return false;
        }
    }
    if (original < count and !discard[original]) {
        var restored = original;
        for (discard[0..original]) |removed| {
            if (removed) restored -= 1;
        }
        _ = host.callbacks.activate_document(host.callbacks.userdata, restored);
    }
    sync(host);
    if (host.callbacks.persist_session(host.callbacks.userdata) <= 0) {
        showError(
            host,
            std.unicode.utf8ToUtf16LeStringLiteral("The editor session could not be saved."),
        );
        return false;
    }
    return true;
}

fn findNext(host: *Host) void {
    const length = c.GetWindowTextLengthW(host.find_edit);
    if (length <= 0 or length > text_bytes_max) return;
    const query = allocator.allocSentinel(u16, @intCast(length), 0) catch return;
    defer allocator.free(query);
    _ = c.GetWindowTextW(host.find_edit, query.ptr, length + 1);
    var selection: c.CHARRANGE = undefined;
    _ = c.SendMessageW(host.editor, c.EM_EXGETSEL, 0, longFromPointer(&selection));
    var find: c.FINDTEXTEXW = std.mem.zeroes(c.FINDTEXTEXW);
    find.chrg.cpMin = selection.cpMax;
    find.chrg.cpMax = -1;
    find.lpstrText = query.ptr;
    var result = c.SendMessageW(host.editor, c.EM_FINDTEXTEXW, c.FR_DOWN, longFromPointer(&find));
    if (result == -1) {
        find.chrg.cpMin = 0;
        find.chrg.cpMax = selection.cpMin;
        result = c.SendMessageW(host.editor, c.EM_FINDTEXTEXW, c.FR_DOWN, longFromPointer(&find));
    }
    if (result != -1) {
        _ = c.SendMessageW(host.editor, c.EM_EXSETSEL, 0, longFromPointer(&find.chrgText));
        _ = c.SendMessageW(host.editor, c.EM_SCROLLCARET, 0, 0);
        _ = c.SetFocus(host.editor);
    } else {
        _ = c.MessageBeep(@intCast(c.MB_ICONINFORMATION));
    }
}

fn showFind(host: *Host) void {
    host.find_visible = true;
    layout(host);
    _ = c.SetFocus(host.find_edit);
    _ = c.SendMessageW(host.find_edit, c.EM_SETSEL, 0, -1);
}

fn openTreeSelection(host: *Host) void {
    const selected: c.HTREEITEM = @ptrFromInt(@as(usize, @bitCast(c.SendMessageW(
        host.tree,
        tvm_get_next_item,
        tvgn_caret,
        0,
    ))));
    if (selected == null) return;
    var item: c.TVITEMW = std.mem.zeroes(c.TVITEMW);
    item.mask = c.TVIF_PARAM;
    item.hItem = selected;
    if (c.SendMessageW(host.tree, tvm_get_item_w, 0, longFromPointer(&item)) == 0) return;
    if (host.callbacks.open_project_entry(
        host.callbacks.userdata,
        @intCast(item.lParam),
    ) < 0) {
        _ = c.SendMessageW(
            host.tree,
            tvm_expand,
            c.TVE_TOGGLE,
            @bitCast(@intFromPtr(selected.?)),
        );
        return;
    }
    sync(host);
}

fn appendMenu(menu: c.HMENU, flags: c.UINT, id: usize, text: ?[*:0]const u16) bool {
    return c.AppendMenuW(menu, flags, id, text) != 0;
}

fn createMenu(host: *Host) bool {
    const menu = c.CreateMenu();
    const file = c.CreatePopupMenu();
    const edit = c.CreatePopupMenu();
    const view = c.CreatePopupMenu();
    const settings = c.CreatePopupMenu();
    if (menu == null or file == null or edit == null or view == null or settings == null)
        return false;
    const ok =
        appendMenu(file, c.MF_STRING, id_file_new, std.unicode.utf8ToUtf16LeStringLiteral("&New\tCtrl+N")) and
        appendMenu(file, c.MF_STRING, id_file_open, std.unicode.utf8ToUtf16LeStringLiteral("&Open...\tCtrl+O")) and
        appendMenu(file, c.MF_STRING, id_file_open_folder, std.unicode.utf8ToUtf16LeStringLiteral("Open &Project...")) and
        appendMenu(file, c.MF_SEPARATOR, 0, null) and
        appendMenu(file, c.MF_STRING, id_file_save, std.unicode.utf8ToUtf16LeStringLiteral("&Save\tCtrl+S")) and
        appendMenu(file, c.MF_STRING, id_file_save_as, std.unicode.utf8ToUtf16LeStringLiteral("Save &As...\tCtrl+Shift+S")) and
        appendMenu(file, c.MF_STRING, id_file_close, std.unicode.utf8ToUtf16LeStringLiteral("&Close\tCtrl+W")) and
        appendMenu(file, c.MF_SEPARATOR, 0, null) and
        appendMenu(file, c.MF_STRING, id_file_exit, std.unicode.utf8ToUtf16LeStringLiteral("E&xit")) and
        appendMenu(edit, c.MF_STRING, id_edit_undo, std.unicode.utf8ToUtf16LeStringLiteral("&Undo\tCtrl+Z")) and
        appendMenu(edit, c.MF_STRING, id_edit_redo, std.unicode.utf8ToUtf16LeStringLiteral("&Redo\tCtrl+Y")) and
        appendMenu(edit, c.MF_SEPARATOR, 0, null) and
        appendMenu(edit, c.MF_STRING, id_edit_cut, std.unicode.utf8ToUtf16LeStringLiteral("Cu&t\tCtrl+X")) and
        appendMenu(edit, c.MF_STRING, id_edit_copy, std.unicode.utf8ToUtf16LeStringLiteral("&Copy\tCtrl+C")) and
        appendMenu(edit, c.MF_STRING, id_edit_paste, std.unicode.utf8ToUtf16LeStringLiteral("&Paste\tCtrl+V")) and
        appendMenu(edit, c.MF_STRING, id_edit_select_all, std.unicode.utf8ToUtf16LeStringLiteral("Select &All\tCtrl+A")) and
        appendMenu(edit, c.MF_SEPARATOR, 0, null) and
        appendMenu(edit, c.MF_STRING, id_edit_find, std.unicode.utf8ToUtf16LeStringLiteral("&Find...\tCtrl+F")) and
        appendMenu(view, c.MF_STRING, id_view_zoom_in, std.unicode.utf8ToUtf16LeStringLiteral("Zoom &In\tCtrl++")) and
        appendMenu(view, c.MF_STRING, id_view_zoom_out, std.unicode.utf8ToUtf16LeStringLiteral("Zoom &Out\tCtrl+-")) and
        appendMenu(view, c.MF_STRING, id_view_zoom_reset, std.unicode.utf8ToUtf16LeStringLiteral("&Reset Zoom\tCtrl+0")) and
        appendMenu(settings, c.MF_STRING, id_settings_font_size, std.unicode.utf8ToUtf16LeStringLiteral("Editor &Font Size...")) and
        appendMenu(menu, c.MF_POPUP, @intFromPtr(file.?), std.unicode.utf8ToUtf16LeStringLiteral("&File")) and
        appendMenu(menu, c.MF_POPUP, @intFromPtr(edit.?), std.unicode.utf8ToUtf16LeStringLiteral("&Edit")) and
        appendMenu(menu, c.MF_POPUP, @intFromPtr(view.?), std.unicode.utf8ToUtf16LeStringLiteral("&View")) and
        appendMenu(menu, c.MF_POPUP, @intFromPtr(settings.?), std.unicode.utf8ToUtf16LeStringLiteral("&Settings")) and
        c.SetMenu(host.window, menu) != 0;
    if (!ok) _ = c.DestroyMenu(menu);
    return ok;
}

fn createAccelerators() c.HACCEL {
    var entries = [_]c.ACCEL{
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = 'N', .cmd = id_file_new },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = 'O', .cmd = id_file_open },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = 'S', .cmd = id_file_save },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL | c.FSHIFT, .key = 'S', .cmd = id_file_save_as },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = 'W', .cmd = id_file_close },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = 'F', .cmd = id_edit_find },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = c.VK_OEM_PLUS, .cmd = id_view_zoom_in },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = c.VK_ADD, .cmd = id_view_zoom_in },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = c.VK_OEM_MINUS, .cmd = id_view_zoom_out },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = c.VK_SUBTRACT, .cmd = id_view_zoom_out },
        .{ .fVirt = c.FVIRTKEY | c.FCONTROL, .key = '0', .cmd = id_view_zoom_reset },
    };
    return c.CreateAcceleratorTableW(&entries, entries.len);
}

fn createControls(host: *Host) bool {
    host.tabs = createWindowExW(
        0,
        std.unicode.utf8ToUtf16LeStringLiteral("SysTabControl32"),
        std.unicode.utf8ToUtf16LeStringLiteral(""),
        c.WS_CHILD | c.WS_VISIBLE | c.TCS_FOCUSNEVER,
        0,
        0,
        1,
        1,
        host.window,
        menuFromId(id_control_tabs),
        host.instance,
        null,
    );
    host.tree = createWindowExW(
        c.WS_EX_CLIENTEDGE,
        std.unicode.utf8ToUtf16LeStringLiteral("SysTreeView32"),
        std.unicode.utf8ToUtf16LeStringLiteral(""),
        c.WS_CHILD | c.WS_VISIBLE | c.TVS_HASBUTTONS | c.TVS_HASLINES |
            c.TVS_LINESATROOT | c.TVS_SHOWSELALWAYS,
        0,
        0,
        1,
        1,
        host.window,
        menuFromId(id_control_tree),
        host.instance,
        null,
    );
    host.editor = createWindowExW(
        c.WS_EX_CLIENTEDGE,
        std.unicode.utf8ToUtf16LeStringLiteral("RICHEDIT50W"),
        std.unicode.utf8ToUtf16LeStringLiteral(""),
        c.WS_CHILD | c.WS_VISIBLE | c.WS_TABSTOP | c.WS_VSCROLL | c.WS_HSCROLL |
            c.ES_MULTILINE | c.ES_WANTRETURN | c.ES_AUTOVSCROLL | c.ES_AUTOHSCROLL |
            c.ES_NOHIDESEL,
        0,
        0,
        1,
        1,
        host.window,
        menuFromId(id_control_editor),
        host.instance,
        null,
    );
    host.status = createWindowExW(
        0,
        std.unicode.utf8ToUtf16LeStringLiteral("STATIC"),
        std.unicode.utf8ToUtf16LeStringLiteral(""),
        c.WS_CHILD | c.WS_VISIBLE | c.SS_LEFTNOWORDWRAP,
        0,
        0,
        1,
        1,
        host.window,
        menuFromId(id_control_status),
        host.instance,
        null,
    );
    host.find_edit = createWindowExW(
        c.WS_EX_CLIENTEDGE,
        std.unicode.utf8ToUtf16LeStringLiteral("EDIT"),
        std.unicode.utf8ToUtf16LeStringLiteral(""),
        c.WS_CHILD | c.WS_TABSTOP | c.ES_AUTOHSCROLL,
        0,
        0,
        1,
        1,
        host.window,
        menuFromId(id_control_find),
        host.instance,
        null,
    );
    host.find_button = createWindowExW(
        0,
        std.unicode.utf8ToUtf16LeStringLiteral("BUTTON"),
        std.unicode.utf8ToUtf16LeStringLiteral("Find next"),
        c.WS_CHILD | c.WS_TABSTOP | c.BS_DEFPUSHBUTTON,
        0,
        0,
        1,
        1,
        host.window,
        menuFromId(id_control_find_next),
        host.instance,
        null,
    );
    if (host.tabs == null or host.tree == null or host.editor == null or
        host.status == null or host.find_edit == null or host.find_button == null) return false;
    _ = c.SendMessageW(host.editor, c.EM_EXLIMITTEXT, 0, text_bytes_max);
    const event_mask = c.SendMessageW(host.editor, c.EM_GETEVENTMASK, 0, 0);
    _ = c.SendMessageW(host.editor, c.EM_SETEVENTMASK, 0, event_mask | c.ENM_CHANGE);
    return c.SetWindowSubclass(
        host.editor,
        editorSubclassProc,
        1,
        @intFromPtr(host),
    ) != 0;
}

fn handleCommand(host: *Host, command: u16) bool {
    if (host.editor_state != .editable) switch (command) {
        id_edit_undo, id_edit_redo, id_edit_cut, id_edit_paste => return true,
        else => {},
    };
    switch (command) {
        id_file_new => {
            if (host.callbacks.new_document(host.callbacks.userdata) < 0) {
                showError(
                    host,
                    std.unicode.utf8ToUtf16LeStringLiteral("A document could not be created."),
                );
            } else sync(host);
        },
        id_file_open => _ = openFileDialog(host, false),
        id_file_open_folder => _ = openFileDialog(host, true),
        id_file_save => _ = save(host, false),
        id_file_save_as => _ = save(host, true),
        id_file_close => _ = closeCurrent(host, false),
        id_file_exit => _ = c.SendMessageW(host.window, c.WM_CLOSE, 0, 0),
        id_edit_undo => _ = c.SendMessageW(host.editor, c.EM_UNDO, 0, 0),
        id_edit_redo => _ = c.SendMessageW(host.editor, c.EM_REDO, 0, 0),
        id_edit_cut => _ = c.SendMessageW(host.editor, c.WM_CUT, 0, 0),
        id_edit_copy => _ = c.SendMessageW(host.editor, c.WM_COPY, 0, 0),
        id_edit_paste => _ = c.SendMessageW(host.editor, c.WM_PASTE, 0, 0),
        id_edit_select_all => _ = c.SendMessageW(host.editor, c.EM_SETSEL, 0, -1),
        id_edit_find => showFind(host),
        id_control_find_next => findNext(host),
        id_view_zoom_in => _ = applyEditorFontSize(host, host.editor_font_size + 1),
        id_view_zoom_out => _ = applyEditorFontSize(host, host.editor_font_size - 1),
        id_view_zoom_reset => _ = applyEditorFontSize(host, font_size_default),
        id_settings_font_size => openSettings(host),
        else => return false,
    }
    return true;
}

fn windowProc(
    window: c.HWND,
    message: c.UINT,
    word: c.WPARAM,
    long_value: c.LPARAM,
) callconv(.winapi) c.LRESULT {
    var host = hostFromWindow(window);
    if (message == c.WM_NCCREATE) {
        const create = pointerFromLong(c.CREATESTRUCTW, long_value);
        host = @ptrCast(@alignCast(create.lpCreateParams.?));
        host.?.window = window;
        _ = c.SetWindowLongPtrW(
            window,
            c.GWLP_USERDATA,
            @bitCast(@as(usize, @intFromPtr(host.?))),
        );
    }
    const state = host orelse return c.DefWindowProcW(window, message, word, long_value);
    switch (message) {
        c.WM_CREATE => {
            if (!createControls(state) or !createMenu(state)) return -1;
            state.dpi = windowDpi(window);
            state.editor_font_size = state.callbacks.editor_font_size(state.callbacks.userdata);
            if (state.editor_font_size < font_size_min or state.editor_font_size > font_size_max)
                state.editor_font_size = font_size_default;
            updateFont(state);
            return 0;
        },
        c.WM_SIZE => {
            layout(state);
            return 0;
        },
        c.WM_GETMINMAXINFO => {
            const limits = pointerFromLong(c.MINMAXINFO, long_value);
            limits.ptMinTrackSize.x = c.MulDiv(720, @intCast(state.dpi), 96);
            limits.ptMinTrackSize.y = c.MulDiv(480, @intCast(state.dpi), 96);
            return 0;
        },
        c.WM_DPICHANGED => {
            const suggested = pointerFromLong(c.RECT, long_value);
            state.dpi = highWord(word);
            _ = c.SetWindowPos(
                window,
                null,
                suggested.left,
                suggested.top,
                suggested.right - suggested.left,
                suggested.bottom - suggested.top,
                c.SWP_NOACTIVATE | c.SWP_NOZORDER,
            );
            updateFont(state);
            layout(state);
            return 0;
        },
        c.WM_COMMAND => {
            const command = handleWord(word);
            if (command == id_control_editor and highWord(word) == c.EN_CHANGE) {
                editorChanged(state);
                return 0;
            }
            if (handleCommand(state, command)) return 0;
        },
        c.WM_NOTIFY => {
            const note = pointerFromLong(c.NMHDR, long_value);
            if (note.idFrom == id_control_tabs and
                note.code == @as(c_uint, @bitCast(@as(c_int, -551))))
            {
                const index = c.SendMessageW(state.tabs, tcm_get_current_selection, 0, 0);
                if (index >= 0 and
                    state.callbacks.activate_document(
                        state.callbacks.userdata,
                        @intCast(index),
                    ) != 0)
                {
                    syncEditor(state);
                    updateChrome(state);
                    _ = c.SetFocus(state.editor);
                }
                return 0;
            }
            if (note.idFrom == id_control_tree and
                note.code == @as(c_uint, @bitCast(@as(c_int, -3))))
            {
                openTreeSelection(state);
                return 0;
            }
        },
        c.WM_CLOSE => {
            if (confirmExit(state)) _ = c.DestroyWindow(window);
            return 0;
        },
        c.WM_DESTROY => {
            if (state.settings_window != null) _ = c.DestroyWindow(state.settings_window);
            c.PostQuitMessage(0);
            return 0;
        },
        else => {},
    }
    return c.DefWindowProcW(window, message, word, long_value);
}

fn qualifyEditorTransitions(host: *Host) bool {
    const edited = std.unicode.utf8ToUtf16LeStringLiteral("editable document!");
    _ = c.SendMessageW(host.editor, c.EM_SETSEL, @intCast(c.GetWindowTextLengthW(host.editor)), -1);
    _ = c.SendMessageW(host.editor, c.WM_CHAR, '!', 0);
    var small: [128]u16 = undefined;
    var count = c.GetWindowTextW(host.editor, &small, small.len);
    if (count < 0 or !std.mem.eql(u16, small[0..@intCast(count)], edited)) return false;
    var selection = std.mem.zeroes(c.NMHDR);
    selection.hwndFrom = host.tabs;
    selection.idFrom = id_control_tabs;
    selection.code = @bitCast(@as(c_int, -551)); // TCN_SELCHANGE
    for (1..6) |index| {
        _ = c.SendMessageW(host.tabs, tcm_set_current_selection, index, 0);
        _ = c.SendMessageW(host.window, c.WM_NOTIFY, id_control_tabs, longFromPointer(&selection));
        if (host.callbacks.active_tab(host.callbacks.userdata) != index) return false;
        if ((c.GetWindowLongPtrW(host.editor, c.GWL_STYLE) & c.ES_READONLY) == 0) return false;
        if ((c.GetMenuState(c.GetMenu(host.window), id_file_save, c.MF_BYCOMMAND) & c.MF_GRAYED) == 0)
            return false;
        if (save(host, false) or save(host, true)) return false;
        _ = c.SendMessageW(host.editor, c.WM_CHAR, 'x', 0);
        _ = handleCommand(host, id_edit_undo);
        if (index <= 2) {
            const expected: usize = if (index == 1) 2 * 1024 * 1024 else preview_bytes_max;
            if (c.GetWindowTextLengthW(host.editor) != @as(c_int, @intCast(expected))) return false;
            const preview = allocator.alloc(u16, expected + 1) catch return false;
            defer allocator.free(preview);
            if (c.GetWindowTextW(host.editor, preview.ptr, @intCast(preview.len)) != @as(c_int, @intCast(expected)))
                return false;
            for (preview[0..expected]) |unit| if (unit != 'p') return false;
            if (c.IsWindowEnabled(host.editor) == 0) return false;
        } else {
            if (c.IsWindowEnabled(host.editor) != 0) return false;
            count = c.GetWindowTextW(host.editor, &small, small.len);
            if (count <= 0 or std.mem.eql(u16, small[0..@intCast(count)], edited)) return false;
        }
        _ = c.SendMessageW(host.tabs, tcm_set_current_selection, 0, 0);
        _ = c.SendMessageW(host.window, c.WM_NOTIFY, id_control_tabs, longFromPointer(&selection));
        if (host.callbacks.active_tab(host.callbacks.userdata) != 0) return false;
        count = c.GetWindowTextW(host.editor, &small, small.len);
        if (count < 0 or !std.mem.eql(u16, small[0..@intCast(count)], edited)) return false;
        if (c.IsWindowEnabled(host.editor) == 0 or
            (c.GetWindowLongPtrW(host.editor, c.GWL_STYLE) & c.ES_READONLY) != 0) return false;
        if ((c.GetMenuState(c.GetMenu(host.window), id_file_save, c.MF_BYCOMMAND) & c.MF_GRAYED) != 0)
            return false;
    }
    return true;
}

pub fn run(
    instance: windows.HINSTANCE,
    show_command: c_int,
    callbacks: *const Callbacks,
    qualification: bool,
) c_int {
    if (callbacks.abi_version != abi_version) return 1;
    const com_result = c.CoInitializeEx(
        null,
        c.COINIT_APARTMENTTHREADED | c.COINIT_DISABLE_OLE1DDE,
    );
    if (com_result < 0) return 1;
    defer c.CoUninitialize();

    const native_instance: c.HINSTANCE = @ptrCast(@alignCast(instance));
    var host = Host{ .instance = native_instance, .callbacks = callbacks };
    _ = c.SetProcessDPIAware();
    var controls = c.INITCOMMONCONTROLSEX{
        .dwSize = @sizeOf(c.INITCOMMONCONTROLSEX),
        .dwICC = c.ICC_TAB_CLASSES | c.ICC_TREEVIEW_CLASSES | c.ICC_STANDARD_CLASSES,
    };
    if (c.InitCommonControlsEx(&controls) == 0) return 1;
    host.rich_edit = c.LoadLibraryW(std.unicode.utf8ToUtf16LeStringLiteral("Msftedit.dll"));
    if (host.rich_edit == null) return 1;
    defer _ = c.FreeLibrary(host.rich_edit);

    var window_class: c.WNDCLASSEXW = std.mem.zeroes(c.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(c.WNDCLASSEXW);
    window_class.style = c.CS_HREDRAW | c.CS_VREDRAW;
    window_class.lpfnWndProc = windowProc;
    window_class.hInstance = native_instance;
    window_class.hCursor = LoadCursorW(null, @ptrFromInt(32513));
    window_class.hIcon = LoadIconW(null, @ptrFromInt(32512));
    window_class.hbrBackground = GetSysColorBrush(c.COLOR_WINDOW);
    window_class.lpszClassName = editor_class;
    if (c.RegisterClassExW(&window_class) == 0) return 1;
    defer _ = c.UnregisterClassW(editor_class, native_instance);

    window_class.style = 0;
    window_class.lpfnWndProc = settingsWindowProc;
    window_class.hCursor = LoadCursorW(null, @ptrFromInt(32512));
    window_class.hIcon = null;
    window_class.lpszClassName = settings_class;
    if (c.RegisterClassExW(&window_class) == 0) return 1;
    defer _ = c.UnregisterClassW(settings_class, native_instance);

    const window = createWindowExW(
        0,
        editor_class,
        title_nocted,
        c.WS_OVERLAPPEDWINDOW | c.WS_CLIPCHILDREN,
        c.CW_USEDEFAULT,
        c.CW_USEDEFAULT,
        1180,
        760,
        null,
        null,
        native_instance,
        &host,
    );
    if (window == null) return 1;
    host.accelerators = createAccelerators();
    sync(&host);
    _ = c.ShowWindow(window, if (show_command == 0) c.SW_SHOWNORMAL else show_command);
    _ = c.UpdateWindow(window);
    if (qualification) {
        if (host.tabs == null or host.tree == null or host.editor == null or
            host.find_edit == null or host.find_button == null) return 1;
        if (c.SendMessageW(host.tree, tvm_get_count, 0, 0) != 1) return 1;
        if (!qualifyEditorTransitions(&host)) return 1;
        showFind(&host);
        if (c.IsWindowVisible(host.find_edit) == 0 or
            c.IsWindowVisible(host.find_button) == 0) return 1;
        openSettings(&host);
        if (host.settings_window == null or
            c.IsWindowVisible(host.settings_window) == 0) return 1;
        _ = c.PostMessageW(window, c.WM_CLOSE, 0, 0);
    }

    var message: c.MSG = undefined;
    var result: c_int = 0;
    while (true) {
        result = c.GetMessageW(&message, null, 0, 0);
        if (result <= 0) break;
        if (host.settings_window != null and c.IsWindow(host.settings_window) != 0 and
            c.IsDialogMessageW(host.settings_window, &message) != 0) continue;
        if (host.accelerators == null or
            c.TranslateAcceleratorW(window, host.accelerators, &message) == 0)
        {
            _ = c.TranslateMessage(&message);
            _ = c.DispatchMessageW(&message);
        }
    }
    if (host.accelerators != null) _ = c.DestroyAcceleratorTable(host.accelerators);
    deleteObject(host.ui_font);
    deleteObject(host.editor_font);
    if (result < 0) return 1;
    return @intCast(message.wParam);
}
