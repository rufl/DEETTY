//! Bounded sibling-process launch helpers for the Win32 host.

const std = @import("std");

const c = @import("c");

const path_capacity: usize = c.MAX_PATH * 2;

pub export fn noctty_windows_launch_nocted() c_int {
    var executable: [path_capacity]u16 = undefined;
    const length = c.GetModuleFileNameW(null, &executable, executable.len);
    if (length == 0 or length >= executable.len) return 0;

    var separator: ?usize = null;
    var index: usize = length;
    while (index > 0) {
        index -= 1;
        if (executable[index] == '\\') {
            separator = index;
            break;
        }
    }
    const directory_end = (separator orelse return 0) + 1;
    const editor_name = std.unicode.utf8ToUtf16LeStringLiteral("nocted.exe");
    const editor_length = editor_name.len;
    if (directory_end + editor_length + 1 > executable.len) return 0;
    @memcpy(executable[directory_end..][0..editor_length], editor_name[0..editor_length]);
    executable[directory_end + editor_length] = 0;
    const executable_length = directory_end + editor_length;

    var command: [path_capacity + 3]u16 = undefined;
    if (executable_length + 3 > command.len) return 0;
    command[0] = '"';
    @memcpy(command[1..][0..executable_length], executable[0..executable_length]);
    command[executable_length + 1] = '"';
    command[executable_length + 2] = 0;

    var startup: c.STARTUPINFOW = std.mem.zeroes(c.STARTUPINFOW);
    startup.cb = @sizeOf(c.STARTUPINFOW);
    var process: c.PROCESS_INFORMATION = std.mem.zeroes(c.PROCESS_INFORMATION);
    if (c.CreateProcessW(
        &executable,
        &command,
        null,
        null,
        c.FALSE,
        0,
        null,
        null,
        &startup,
        &process,
    ) == 0) return 0;
    if (process.hThread) |thread| _ = c.CloseHandle(thread);
    if (process.hProcess) |child| _ = c.CloseHandle(child);
    return 1;
}
