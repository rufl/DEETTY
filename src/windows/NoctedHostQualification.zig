//! Mapped Wine/Win32 qualification for the Zig NoctEd controls adapter.

const std = @import("std");
const windows = std.os.windows;
const Host = @import("NoctedHost.zig");

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

fn replaceSuccess(_: ?*anyopaque, _: [*]const u8, _: usize) callconv(.c) c_int {
    return 1;
}

fn tabCount(_: ?*anyopaque) callconv(.c) usize {
    return 1;
}

fn activeTab(_: ?*anyopaque) callconv(.c) usize {
    return 0;
}

fn tabTitle(
    _: ?*anyopaque,
    _: usize,
    output: [*]u8,
    capacity: usize,
    dirty: *c_int,
    read_only: *c_int,
) callconv(.c) usize {
    const title = "Untitled 1";
    dirty.* = 0;
    read_only.* = 0;
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
    const callbacks = Host.Callbacks{
        .userdata = null,
        .new_document = success,
        .open_document = pathSuccess,
        .open_project = pathSuccess,
        .open_project_entry = projectEntrySuccess,
        .save_document = saveSuccess,
        .close_document = closeSuccess,
        .discard_document = indexedSuccess,
        .activate_document = indexedSuccess,
        .replace_contents = replaceSuccess,
        .tab_count = tabCount,
        .active_tab = activeTab,
        .tab_title = tabTitle,
        .active_content_length = emptyBytesCount,
        .active_content = emptyBytes,
        .active_path = emptyBytes,
        .project_name = emptyBytes,
        .project_entry_count = tabCount,
        .project_entry = projectEntry,
        .last_error = emptyBytes,
        .persist_session = success,
        .editor_font_size = fontSize,
        .set_editor_font_size = setFontSize,
    };
    return Host.run(instance, show_command, &callbacks, true);
}

fn emptyBytesCount(_: ?*anyopaque) callconv(.c) usize {
    return 0;
}
