//! Win32 ConPTY ownership composed by the native Zig host.
//!
//! The host observes a session only through bounded reads, writes, resize, and
//! exit polling. This module alone owns every pipe, process, pseudo-console,
//! reader thread, lock, and output-ring lifetime.

const std = @import("std");
const Diagnostics = @import("WindowsDiagnostics.zig");
const OutputRing = @import("WindowsPtyLogic.zig").OutputRing;

const c = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "");
    @cDefine("NOMINMAX", "");
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("windows.h");
});

const output_ring_bytes: usize = 1024 * 1024;
const io_chunk_bytes: usize = 64 * 1024;
const command_capacity: usize = 2048;
const write_chunk_bytes: usize = 64 * 1024;

pub const Pty = struct {
    index: c_int,
    window: c.HWND,
    output_message: c.UINT,
    columns: c_int,
    rows: c_int,
    pseudo_console: c.HPCON = null,
    input_write: c.HANDLE = null,
    output_read: c.HANDLE = null,
    process: c.HANDLE = null,
    reader_thread: c.HANDLE = null,
    output_lock: c.CRITICAL_SECTION = undefined,
    output_ring: OutputRing,
    stopping: std.atomic.Value(bool) = .init(false),
    process_exited: bool = false,
    process_exit_code: c.DWORD = 255,
};

pub export fn noctty_windows_pty_create(
    index: c_int,
    columns: c_int,
    rows: c_int,
    launch_profile: c_int,
    window: c.HWND,
    output_message: c.UINT,
) ?*Pty {
    return create(index, columns, rows, launch_profile, window, output_message) catch null;
}

fn create(
    index: c_int,
    columns: c_int,
    rows: c_int,
    launch_profile: c_int,
    window: c.HWND,
    output_message: c.UINT,
) !*Pty {
    if (index < 0 or columns <= 0 or rows <= 0 or window == null) {
        return error.InvalidPtyConfiguration;
    }

    const heap = c.GetProcessHeap() orelse return error.ProcessHeapUnavailable;
    const raw_ring = c.HeapAlloc(heap, 0, output_ring_bytes) orelse return error.OutOfMemory;
    errdefer _ = c.HeapFree(heap, 0, raw_ring);
    const raw_pty = c.HeapAlloc(heap, c.HEAP_ZERO_MEMORY, @sizeOf(Pty)) orelse {
        return error.OutOfMemory;
    };
    errdefer _ = c.HeapFree(heap, 0, raw_pty);

    const pty: *Pty = @ptrCast(@alignCast(raw_pty));
    pty.* = .{
        .index = index,
        .window = window,
        .output_message = output_message,
        .columns = columns,
        .rows = rows,
        .output_ring = OutputRing.init(@as([*]u8, @ptrCast(raw_ring))[0..output_ring_bytes]),
    };
    c.InitializeCriticalSection(&pty.output_lock);
    errdefer c.DeleteCriticalSection(&pty.output_lock);

    if (!createPseudoConsole(pty, launch_profile)) return error.PseudoConsoleUnavailable;
    errdefer closePlatformHandles(pty);

    pty.reader_thread = c.CreateThread(null, 0, readerThread, pty, 0, null);
    if (pty.reader_thread == null) {
        log("reader_thread_failed pane={d} error={d}\r\n", .{ index, c.GetLastError() });
        return error.ReaderThreadUnavailable;
    }
    return pty;
}

pub export fn noctty_windows_pty_destroy(optional_pty: ?*Pty) void {
    const pty = optional_pty orelse return;
    pty.stopping.store(true, .release);
    if (pty.reader_thread) |thread| _ = c.CancelSynchronousIo(thread);
    closeHandle(&pty.input_write);
    closeHandle(&pty.output_read);
    if (pty.pseudo_console) |pseudo_console| {
        c.ClosePseudoConsole(pseudo_console);
        pty.pseudo_console = null;
    }
    if (pty.reader_thread) |thread| {
        _ = c.WaitForSingleObject(thread, c.INFINITE);
        closeHandle(&pty.reader_thread);
    }
    if (pty.process) |process| {
        if (c.WaitForSingleObject(process, 500) == c.WAIT_TIMEOUT) {
            _ = c.TerminateProcess(process, 1);
            _ = c.WaitForSingleObject(process, 500);
        }
        closeHandle(&pty.process);
    }

    c.DeleteCriticalSection(&pty.output_lock);
    const heap = c.GetProcessHeap() orelse return;
    _ = c.HeapFree(heap, 0, pty.output_ring.storage.ptr);
    _ = c.HeapFree(heap, 0, pty);
}

pub export fn noctty_windows_pty_write(
    optional_pty: ?*Pty,
    bytes: ?[*]const u8,
    length: usize,
) c_int {
    const pty = optional_pty orelse return 0;
    if (length == 0) return 1;
    const input = bytes orelse return 0;
    if (pty.process_exited or pty.input_write == null) return 0;

    var offset: usize = 0;
    while (offset < length) {
        const request: c.DWORD = @intCast(@min(length - offset, write_chunk_bytes));
        var written: c.DWORD = 0;
        if (c.WriteFile(pty.input_write, input + offset, request, &written, null) == 0) {
            log("input_write_failed pane={d} error={d}\r\n", .{ pty.index, c.GetLastError() });
            return 0;
        }
        if (written == 0) return 0;
        offset += written;
    }
    return 1;
}

pub export fn noctty_windows_pty_drain(
    optional_pty: ?*Pty,
    output: ?[*]u8,
    capacity: usize,
) usize {
    const pty = optional_pty orelse return 0;
    if (capacity == 0) return 0;
    const target = output orelse return 0;

    c.EnterCriticalSection(&pty.output_lock);
    defer c.LeaveCriticalSection(&pty.output_lock);
    return pty.output_ring.read(target[0..capacity]);
}

pub export fn noctty_windows_pty_resize(
    optional_pty: ?*Pty,
    columns: c_int,
    rows: c_int,
) c_int {
    const pty = optional_pty orelse return 0;
    if (columns <= 0 or rows <= 0) return 0;
    if (columns > std.math.maxInt(c.SHORT) or rows > std.math.maxInt(c.SHORT)) return 0;
    const size = c.COORD{ .X = @intCast(columns), .Y = @intCast(rows) };
    const pseudo_console = pty.pseudo_console orelse return 0;
    if (c.ResizePseudoConsole(pseudo_console, size) < 0) {
        log("conpty_resize_failed pane={d} columns={d} rows={d}\r\n", .{
            pty.index,
            columns,
            rows,
        });
        return 0;
    }
    pty.columns = columns;
    pty.rows = rows;
    return 1;
}

pub export fn noctty_windows_pty_poll_exit(
    optional_pty: ?*Pty,
    exit_code: ?*u32,
) c_int {
    const pty = optional_pty orelse return 0;
    if (pty.process_exited) {
        if (exit_code) |output| output.* = pty.process_exit_code;
        return 0;
    }
    const process = pty.process orelse return 0;
    if (c.WaitForSingleObject(process, 0) != c.WAIT_OBJECT_0) return 0;
    var code: c.DWORD = 255;
    _ = c.GetExitCodeProcess(process, &code);
    pty.process_exited = true;
    pty.process_exit_code = code;
    log("shell_exit pane={d} code={d}\r\n", .{ pty.index, code });
    if (exit_code) |output| output.* = pty.process_exit_code;
    return 1;
}

pub export fn noctty_windows_pty_exited(optional_pty: ?*const Pty) c_int {
    const pty = optional_pty orelse return 0;
    return @intFromBool(pty.process_exited);
}

pub export fn noctty_windows_pty_exit_code(optional_pty: ?*const Pty) u32 {
    const pty = optional_pty orelse return 255;
    return pty.process_exit_code;
}

fn createPseudoConsole(pty: *Pty, launch_profile: c_int) bool {
    var success = false;
    defer if (!success) closePlatformHandles(pty);
    var input_read: c.HANDLE = null;
    defer closeHandle(&input_read);
    var output_write: c.HANDLE = null;
    defer closeHandle(&output_write);
    if (c.CreatePipe(&input_read, &pty.input_write, null, 0) == 0) return false;
    if (c.CreatePipe(&pty.output_read, &output_write, null, 0) == 0) return false;

    const size = c.COORD{ .X = @intCast(pty.columns), .Y = @intCast(pty.rows) };
    const result = c.CreatePseudoConsole(size, input_read, output_write, 0, &pty.pseudo_console);
    if (result < 0) {
        log("conpty_create_failed pane={d} hresult=0x{x}\r\n", .{
            pty.index,
            @as(u32, @bitCast(result)),
        });
        return false;
    }
    closeHandle(&input_read);
    closeHandle(&output_write);

    var attribute_bytes: c.SIZE_T = 0;
    _ = c.InitializeProcThreadAttributeList(null, 1, 0, &attribute_bytes);
    const heap = c.GetProcessHeap() orelse return false;
    const raw_attributes = c.HeapAlloc(heap, 0, attribute_bytes) orelse return false;
    defer _ = c.HeapFree(heap, 0, raw_attributes);
    const attributes: c.PPROC_THREAD_ATTRIBUTE_LIST = @ptrCast(@alignCast(raw_attributes));
    if (c.InitializeProcThreadAttributeList(attributes, 1, 0, &attribute_bytes) == 0) {
        return false;
    }
    defer c.DeleteProcThreadAttributeList(attributes);
    if (c.UpdateProcThreadAttribute(
        attributes,
        0,
        c.PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
        pty.pseudo_console,
        @sizeOf(c.HPCON),
        null,
        null,
    ) == 0) return false;

    var startup: c.STARTUPINFOEXW = std.mem.zeroes(c.STARTUPINFOEXW);
    startup.StartupInfo.cb = @sizeOf(c.STARTUPINFOEXW);
    startup.lpAttributeList = attributes;
    _ = c.SetEnvironmentVariableW(
        std.unicode.utf8ToUtf16LeStringLiteral("TERM"),
        std.unicode.utf8ToUtf16LeStringLiteral("xterm-256color"),
    );
    _ = c.SetEnvironmentVariableW(
        std.unicode.utf8ToUtf16LeStringLiteral("COLORTERM"),
        std.unicode.utf8ToUtf16LeStringLiteral("truecolor"),
    );

    var custom_command: [command_capacity]u16 = undefined;
    const custom_length = c.GetEnvironmentVariableW(
        std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY_WINDOWS_SHELL"),
        &custom_command,
        custom_command.len,
    );
    const powershell = std.unicode.utf8ToUtf16LeStringLiteral("powershell.exe -NoLogo");
    const command_prompt = std.unicode.utf8ToUtf16LeStringLiteral("cmd.exe");
    var commands: [3][]const u16 = undefined;
    var command_count: usize = 0;
    if (custom_length > 0 and custom_length < custom_command.len) {
        commands[command_count] = custom_command[0..custom_length];
        command_count += 1;
    }
    if (launch_profile == 1) {
        commands[command_count] = command_prompt[0 .. command_prompt.len - 1];
        command_count += 1;
        commands[command_count] = powershell[0 .. powershell.len - 1];
        command_count += 1;
    } else {
        commands[command_count] = powershell[0 .. powershell.len - 1];
        command_count += 1;
        commands[command_count] = command_prompt[0 .. command_prompt.len - 1];
        command_count += 1;
    }

    var current_directory: [c.MAX_PATH]u16 = undefined;
    const directory_length = c.GetEnvironmentVariableW(
        std.unicode.utf8ToUtf16LeStringLiteral("USERPROFILE"),
        &current_directory,
        current_directory.len,
    );
    const directory: c.LPCWSTR = if (directory_length > 0 and directory_length < current_directory.len) &current_directory else null;

    for (commands[0..command_count], 0..) |command, candidate_index| {
        var command_line: [command_capacity]u16 = undefined;
        if (command.len + 1 > command_line.len) continue;
        @memcpy(command_line[0..command.len], command);
        command_line[command.len] = 0;
        var process: c.PROCESS_INFORMATION = std.mem.zeroes(c.PROCESS_INFORMATION);
        const flags = c.EXTENDED_STARTUPINFO_PRESENT | c.CREATE_UNICODE_ENVIRONMENT;
        if (c.CreateProcessW(
            null,
            &command_line,
            null,
            null,
            c.FALSE,
            flags,
            null,
            directory,
            &startup.StartupInfo,
            &process,
        ) != 0) {
            pty.process = process.hProcess;
            closeHandle(&process.hThread);
            log("shell_spawned pane={d} candidate={d} pid={d}\r\n", .{
                pty.index,
                candidate_index,
                process.dwProcessId,
            });
            success = true;
            return true;
        }
        log("shell_spawn_failed pane={d} candidate={d} error={d}\r\n", .{
            pty.index,
            candidate_index,
            c.GetLastError(),
        });
    }
    return false;
}

fn readerThread(raw: ?*anyopaque) callconv(.winapi) c.DWORD {
    const pty: *Pty = @ptrCast(@alignCast(raw orelse return 1));
    var input: [io_chunk_bytes]u8 = undefined;
    while (!pty.stopping.load(.acquire)) {
        var count: c.DWORD = 0;
        if (c.ReadFile(pty.output_read, &input, input.len, &count, null) == 0) {
            const failure = c.GetLastError();
            if (failure != c.ERROR_BROKEN_PIPE and failure != c.ERROR_OPERATION_ABORTED) {
                log("output_read_failed pane={d} error={d}\r\n", .{ pty.index, failure });
            }
            break;
        }
        if (count == 0) break;
        var offset: usize = 0;
        while (offset < count and !pty.stopping.load(.acquire)) {
            c.EnterCriticalSection(&pty.output_lock);
            const chunk = pty.output_ring.write(input[offset..@intCast(count)]);
            c.LeaveCriticalSection(&pty.output_lock);
            if (chunk == 0) {
                c.Sleep(1);
            } else {
                offset += chunk;
            }
        }
        _ = c.PostMessageW(pty.window, pty.output_message, @intCast(pty.index), 0);
    }
    _ = c.PostMessageW(pty.window, pty.output_message, @intCast(pty.index), 0);
    return 0;
}

fn closePlatformHandles(pty: *Pty) void {
    closeHandle(&pty.input_write);
    closeHandle(&pty.output_read);
    if (pty.pseudo_console) |pseudo_console| {
        c.ClosePseudoConsole(pseudo_console);
        pty.pseudo_console = null;
    }
    closeHandle(&pty.process);
}

fn closeHandle(handle: *c.HANDLE) void {
    const value = handle.* orelse return;
    if (value != c.INVALID_HANDLE_VALUE) _ = c.CloseHandle(value);
    handle.* = null;
}

fn log(comptime format: []const u8, arguments: anytype) void {
    var buffer: [512]u8 = undefined;
    const line = std.fmt.bufPrint(&buffer, format, arguments) catch return;
    Diagnostics.noctty_windows_diagnostics_write(line.ptr, line.len);
}
