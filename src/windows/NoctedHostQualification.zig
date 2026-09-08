//! Mapped Wine/Win32 qualification for the Zig NoctEd controls adapter.

const std = @import("std");
const windows = std.os.windows;
const Host = @import("NoctedHost.zig");

// Tab 0 is editable; tabs 1/2 cover complete previews, and 3/4/5
// exercise oversized, short-copy, and invalid-UTF-8 display failures.
const Fixture = struct {
    active: usize = 0,
    small: [64]u8 = undefined,
    small_length: usize = 0,
};

fn fixture(raw: ?*anyopaque) *Fixture {
    return @ptrCast(@alignCast(raw.?));
}

fn activate(raw: ?*anyopaque, index: usize) callconv(.c) c_int {
    if (index >= 6) return 0;
    fixture(raw).active = index;
    return 1;
}

fn contentLength(raw: ?*anyopaque) callconv(.c) usize {
    const state = fixture(raw);
    return switch (state.active) {
        0 => state.small_length,
        1 => 2 * 1024 * 1024,
        2 => 8 * 1024 * 1024,
        3 => 8 * 1024 * 1024 + 1,
        4, 5 => 16,
        else => unreachable,
    };
}

fn content(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) usize {
    const state = fixture(raw);
    const length = contentLength(raw);
    const count = @min(capacity, length);
    if (state.active == 0) {
        @memcpy(output[0..count], state.small[0..count]);
    } else {
        @memset(output[0..count], if (state.active == 5) 0xff else 'p');
    }
    return if (state.active == 4) length - 1 else length;
}

fn success(_: ?*anyopaque) callconv(.c) c_int {
    return 1;
}

fn pathSuccess(_: ?*anyopaque, _: [*]const u8, _: usize) callconv(.c) c_int {
    return 1;
}

fn projectEntrySuccess(_: ?*anyopaque, _: usize) callconv(.c) c_int {
    return 1;
}

fn saveSuccess(_: ?*anyopaque, _: ?[*]const u8, _: usize) callconv(.c) c_int {
    return Host.close_ok;
}

fn closeSuccess(_: ?*anyopaque, _: usize, _: c_int) callconv(.c) c_int {
    return Host.close_ok;
}

fn indexedSuccess(_: ?*anyopaque, _: usize) callconv(.c) c_int {
    return 1;
}

fn replaceSuccess(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    const state = fixture(raw);
    if (state.active != 0 or length > state.small.len) return -1;
    @memcpy(state.small[0..length], bytes[0..length]);
    state.small_length = length;
    return 1;
}

fn tabCount(_: ?*anyopaque) callconv(.c) usize {
    return 6;
}

fn activeTab(raw: ?*anyopaque) callconv(.c) usize {
    return fixture(raw).active;
}

fn tabTitle(
    _: ?*anyopaque,
    index: usize,
    output: [*]u8,
    capacity: usize,
    dirty: *c_int,
    read_only: *c_int,
) callconv(.c) usize {
    const title: []const u8 = if (index == 0) "editable.txt" else "preview.txt";
    dirty.* = 0;
    read_only.* = @intFromBool(index != 0);
    const count = @min(capacity, title.len);
    if (count != 0) @memcpy(output[0..count], title[0..count]);
    return title.len;
}

fn emptyBytes(_: ?*anyopaque, _: [*]u8, _: usize) callconv(.c) usize {
    return 0;
}

fn projectEntry(
    _: ?*anyopaque,
    _: usize,
    output: [*]u8,
    capacity: usize,
    parent: *usize,
    directory: *c_int,
) callconv(.c) usize {
    const name = "main.zig";
    parent.* = std.math.maxInt(usize);
    directory.* = 0;
    const count = @min(capacity, name.len);
    if (count != 0) @memcpy(output[0..count], name[0..count]);
    return name.len;
}

fn fontSize(_: ?*anyopaque) callconv(.c) c_int {
    return 11;
}

fn setFontSize(_: ?*anyopaque, _: c_int) callconv(.c) c_int {
    return 1;
}

pub export fn wWinMain(
    instance: windows.HINSTANCE,
    previous_instance: ?windows.HINSTANCE,
    command_line: [*:0]u16,
    show_command: c_int,
) callconv(.c) c_int {
    _ = previous_instance;
    _ = command_line;
    var state = Fixture{};
    const initial = "editable document";
    @memcpy(state.small[0..initial.len], initial);
    state.small_length = initial.len;
    const callbacks = Host.Callbacks{
        .userdata = &state,
        .new_document = success,
        .open_document = pathSuccess,
        .open_project = pathSuccess,
        .open_project_entry = projectEntrySuccess,
        .save_document = saveSuccess,
        .close_document = closeSuccess,
        .discard_document = indexedSuccess,
        .activate_document = activate,
        .replace_contents = replaceSuccess,
        .tab_count = tabCount,
        .active_tab = activeTab,
        .tab_title = tabTitle,
        .active_content_length = contentLength,
        .active_content = content,
        .active_path = emptyBytes,
        .project_name = emptyBytes,
        .project_entry_count = projectEntryCount,
        .project_entry = projectEntry,
        .last_error = emptyBytes,
        .persist_session = success,
        .editor_font_size = fontSize,
        .set_editor_font_size = setFontSize,
    };
    return Host.run(instance, show_command, &callbacks, true);
}

fn projectEntryCount(_: ?*anyopaque) callconv(.c) usize {
    return 1;
}
