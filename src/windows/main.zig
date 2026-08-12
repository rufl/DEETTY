const std = @import("std");
const windows = std.os.windows;
const Vt = @import("noctty_vt");
const Release = @import("noctty_release");

const host_abi_version: u32 = 1;
const columns_initial: usize = 120;
const rows_initial: usize = 36;

const State = struct {
    grid: Vt.Grid,
};

const Feed = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const TakeReply = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const Cell = *const fn (?*anyopaque, c_int, c_int) callconv(.c) u64;
const CellText = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    [*]u8,
    usize,
) callconv(.c) c_int;
const ColorRgb = *const fn (?*anyopaque, u32) callconv(.c) u32;
const Cursor = *const fn (?*anyopaque) callconv(.c) u32;
const Title = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const Resize = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;
const Scroll = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const CursorMode = *const fn (?*anyopaque) callconv(.c) c_int;
const SmokeReady = *const fn (?*anyopaque) callconv(.c) c_int;

const Callbacks = extern struct {
    abi_version: u32 = host_abi_version,
    struct_size: u32 = @sizeOf(Callbacks),
    userdata: ?*anyopaque,
    feed: Feed,
    take_reply: TakeReply,
    cell: Cell,
    cell_text: CellText,
    color_rgb: ColorRgb,
    cursor: Cursor,
    title: Title,
    resize: Resize,
    scroll: Scroll,
    cursor_mode: CursorMode,
    smoke_ready: SmokeReady,
};

extern fn noctty_windows_host_run(
    instance: windows.HINSTANCE,
    show_command: c_int,
    callbacks: *const Callbacks,
) c_int;
extern fn noctty_windows_show_version(
    instance: windows.HINSTANCE,
    version: [*:0]const u16,
) void;

pub export fn wWinMain(
    instance: windows.HINSTANCE,
    previous_instance: ?windows.HINSTANCE,
    command_line: [*:0]u16,
    show_command: c_int,
) callconv(.c) c_int {
    _ = previous_instance;

    const command = std.mem.span(command_line);
    if (wideContainsAscii(command, "--version")) {
        const version_text = std.unicode.utf8ToUtf16LeStringLiteral(
            "NOCTTY " ++ Release.version ++ " Windows alpha",
        );
        noctty_windows_show_version(instance, version_text);
        return 0;
    }

    var state = State{
        .grid = Vt.Grid.init(
            std.heap.page_allocator,
            columns_initial,
            rows_initial,
        ) catch return 1,
    };
    defer state.grid.deinit();

    if (wideContainsAscii(command, "--self-test")) {
        return if (selfTest(&state)) 0 else 1;
    }

    const callbacks = Callbacks{
        .userdata = &state,
        .feed = feed,
        .take_reply = takeReply,
        .cell = cell,
        .cell_text = cellText,
        .color_rgb = colorRgb,
        .cursor = cursor,
        .title = title,
        .resize = resize,
        .scroll = scroll,
        .cursor_mode = cursorMode,
        .smoke_ready = smokeReady,
    };
    return noctty_windows_host_run(instance, show_command, &callbacks);
}

fn stateFromRaw(raw: ?*anyopaque) ?*State {
    return @ptrCast(@alignCast(raw orelse return null));
}

fn feed(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (length > 2 * 1024 * 1024) return -1;
    state.grid.feed(bytes[0..length]) catch return -1;
    return std.math.cast(c_int, length) orelse -1;
}

fn takeReply(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (capacity == 0) return 0;
    const pending = state.grid.pendingReplies();
    const count = @min(pending.len, capacity);
    @memcpy(output[0..count], pending[0..count]);
    state.grid.consumeReplies(count);
    return std.math.cast(c_int, count) orelse -1;
}

fn cell(raw: ?*anyopaque, column: c_int, row: c_int) callconv(.c) u64 {
    const state = stateFromRaw(raw) orelse return ' ';
    if (column < 0 or row < 0) return ' ';
    return state.grid.packedCell(@intCast(column), @intCast(row));
}

fn cellText(
    raw: ?*anyopaque,
    column: c_int,
    row: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (column < 0 or row < 0 or capacity == 0) return 0;
    const count = state.grid.cellText(
        @intCast(column),
        @intCast(row),
        output[0..capacity],
    );
    return std.math.cast(c_int, count) orelse -1;
}

fn colorRgb(raw: ?*anyopaque, color_id: u32) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (color_id > std.math.maxInt(u16)) return 0xffffffff;
    return state.grid.colorRgb(@intCast(color_id));
}

fn cursor(raw: ?*anyopaque) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (!state.grid.cursor_visible) return 0xffffffff;
    if (state.grid.cursor_row > std.math.maxInt(u16)) return 0xffffffff;
    if (state.grid.cursor_column > std.math.maxInt(u16)) return 0xffffffff;
    return (@as(u32, @intCast(state.grid.cursor_row)) << 16) |
        @as(u32, @intCast(state.grid.cursor_column));
}

fn title(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const value = state.grid.titleSlice();
    const count = @min(value.len, capacity);
    @memcpy(output[0..count], value[0..count]);
    return std.math.cast(c_int, count) orelse -1;
}

fn resize(raw: ?*anyopaque, columns: c_int, rows: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (columns < 1 or rows < 1) return -1;
    if (columns > 1000 or rows > 500) return -1;
    state.grid.resize(@intCast(columns), @intCast(rows)) catch return -1;
    return 0;
}

fn scroll(raw: ?*anyopaque, lines: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    state.grid.scrollViewport(lines);
    return 0;
}

fn cursorMode(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return 0;
    return @intFromBool(state.grid.application_cursor_keys);
}

fn smokeReady(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return 0;
    const marker = state.grid.findText(
        "NOCTTY_WINDOWS_HOST_OK",
        false,
        0,
    );
    return @intFromBool(marker != null);
}

fn wideContainsAscii(haystack: []const u16, needle: []const u8) bool {
    if (needle.len == 0 or haystack.len < needle.len) return false;
    for (0..haystack.len - needle.len + 1) |start| {
        var matches = true;
        for (needle, 0..) |byte, index| {
            if (haystack[start + index] != byte) {
                matches = false;
                break;
            }
        }
        if (matches) return true;
    }
    return false;
}

fn selfTest(state: *State) bool {
    state.grid.feed("\x1b[2J\x1b[3;4H\x1b[1;38;2;143;184;255mWIN_OK") catch
        return false;
    const first = state.grid.cell(3, 2);
    const last = state.grid.cell(8, 2);
    if (first.codepoint != 'W') return false;
    if (last.codepoint != 'K') return false;
    if (!first.flags.bold) return false;
    if (state.grid.colorRgb(first.foreground) != 0x8fb8ff) return false;
    state.grid.feed("\r\nNOCTTY_WINDOWS_HOST_OK\r\n") catch return false;
    return smokeReady(state) == 1;
}
