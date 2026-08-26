const std = @import("std");

pub const version: u32 = 4;

pub const DirtySpan = extern struct {
    first: u32,
    end: u32,
};

pub const Pump = *const fn (?*anyopaque) callconv(.c) c_int;
pub const Write = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
pub const Cell = *const fn (?*anyopaque, c_int, c_int) callconv(.c) u64;
pub const Row = *const fn (?*anyopaque, c_int, [*]u64, usize) callconv(.c) c_int;
pub const DirtyRows = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
pub const DirtySpans = *const fn (?*anyopaque, [*]DirtySpan, usize) callconv(.c) c_int;
pub const PresentationReady = *const fn (?*anyopaque) callconv(.c) c_int;
pub const ColorRgb = *const fn (?*anyopaque, u32) callconv(.c) u32;
pub const CellText = *const fn (?*anyopaque, c_int, c_int, [*]u8, usize) callconv(.c) c_int;
pub const CellHyperlink = *const fn (?*anyopaque, c_int, c_int, [*]u8, usize) callconv(.c) c_int;
pub const PollExit = *const fn (?*anyopaque) callconv(.c) c_int;
pub const Resize = *const fn (?*anyopaque, c_int, c_int, c_int, c_int) callconv(.c) c_int;
pub const Mouse = *const fn (?*anyopaque, c_int, c_int, c_int, c_int) callconv(.c) c_int;
pub const Paste = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
pub const Copy = *const fn (?*anyopaque, [*]u8, usize, c_int, c_int, c_int, c_int) callconv(.c) c_int;
pub const Scroll = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
pub const Cursor = *const fn (?*anyopaque) callconv(.c) u32;
pub const Title = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
pub const CursorMode = *const fn (?*anyopaque) callconv(.c) c_int;
pub const MouseMode = *const fn (?*anyopaque) callconv(.c) c_int;
pub const Focus = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
pub const Event = *const fn (?*anyopaque, u64, c_int, c_int, u64) callconv(.c) void;
pub const TextAction = *const fn (?*anyopaque, c_int, [*]const u8, usize, [*]const u8, usize, c_int) callconv(.c) c_int;

pub const Callbacks = extern struct {
    abi_version: u32 = version,
    struct_size: u32 = @sizeOf(Callbacks),
    userdata: ?*anyopaque,
    pump: Pump,
    write: Write,
    cell: Cell,
    row: Row,
    dirty_rows: DirtyRows,
    dirty_spans: DirtySpans,
    presentation_ready: PresentationReady,
    color_rgb: ColorRgb,
    cell_text: CellText,
    cell_hyperlink: CellHyperlink,
    poll_exit: PollExit,
    resize: Resize,
    mouse: Mouse,
    paste: Paste,
    copy: Copy,
    scroll: Scroll,
    cursor: Cursor,
    title: Title,
    cursor_mode: CursorMode,
    mouse_mode: MouseMode,
    focus: Focus,
    event: Event,
    event_data: ?*anyopaque,
    text_action: ?TextAction,
    text_action_data: ?*anyopaque,
};

pub const LaunchOptions = extern struct {
    abi_version: u32 = version,
    struct_size: u32 = @sizeOf(LaunchOptions),
    pane_id: u64,
    columns: c_int,
    rows: c_int,
    mode: c_int,
    shortcut_key: c_int,
    enable_shortcut: c_int,
    workspace_smoke: c_int,
    secondary_userdata: ?*anyopaque,
    secondary_pane_id: u64,
    secondary_initially_active: c_int,
    enable_notifications: c_int,
    claim_control: c_int = 1,
    show_on_control_conflict: c_int = 0,
    recovery_notice_flags: u32 = 0,
    startup_activation_token: ?[*]const u8 = null,
    startup_activation_token_length: usize = 0,
};

extern fn noctty_native_grid_host_run_v2(
    callbacks: *const Callbacks,
    options: *const LaunchOptions,
) c_int;

pub fn run(callbacks: *const Callbacks, options: *const LaunchOptions) c_int {
    return noctty_native_grid_host_run_v2(callbacks, options);
}

fn countPasteBytes(_: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    _ = bytes;
    return @intCast(length);
}

test "native grid ABI layout is explicit and versioned" {
    try std.testing.expectEqual(@as(u32, 4), version);
    try std.testing.expect(@sizeOf(Callbacks) >= 2 * @sizeOf(u32));
    try std.testing.expect(@sizeOf(LaunchOptions) >= 2 * @sizeOf(u32));
}

test "paste callback accepts length-delimited bytes" {
    const bytes = [_]u8{ 'a', 'b', 'c' };
    const callback: Paste = countPasteBytes;
    try std.testing.expectEqual(@as(c_int, 3), callback(null, &bytes, bytes.len));
}
