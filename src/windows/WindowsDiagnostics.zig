//! Local-only Windows launch logging and minidump ownership.
//!
//! Files remain under `%LOCALAPPDATA%\NOCTTY\logs` (or `%TEMP%` fallback).
//! No diagnostic data leaves the workstation.

const std = @import("std");

const c = @import("c");

const path_capacity: usize = c.MAX_PATH * 2;
var log_file: c.HANDLE = c.INVALID_HANDLE_VALUE;
var dump_path: [path_capacity:0]u16 = @splat(0);

pub export fn noctty_windows_diagnostics_init() callconv(.c) c_int {
    var base: [c.MAX_PATH:0]u16 = undefined;
    const local_app_data = std.unicode.utf8ToUtf16LeStringLiteral("LOCALAPPDATA");
    var length: usize = c.GetEnvironmentVariableW(local_app_data, &base, base.len);
    if (length == 0 or length >= base.len) {
        length = c.GetTempPathW(base.len, &base);
        if (length == 0 or length >= base.len) return 0;
        while (length != 0 and (base[length - 1] == '\\' or base[length - 1] == '/'))
            length -= 1;
    }

    var directory: [path_capacity:0]u16 = @splat(0);
    @memcpy(directory[0..length], base[0..length]);
    appendWide(&directory, &length, std.unicode.utf8ToUtf16LeStringLiteral("\\NOCTTY")) catch
        return 0;
    _ = c.CreateDirectoryW(&directory, null);
    appendWide(&directory, &length, std.unicode.utf8ToUtf16LeStringLiteral("\\logs")) catch
        return 0;
    _ = c.CreateDirectoryW(&directory, null);

    var time: c.SYSTEMTIME = undefined;
    c.GetLocalTime(&time);
    var suffix_utf8: [128]u8 = undefined;
    const suffix = std.fmt.bufPrint(
        &suffix_utf8,
        "\\noctty-{d:0>4}{d:0>2}{d:0>2}-{d:0>2}{d:0>2}{d:0>2}-{d}",
        .{
            time.wYear,
            time.wMonth,
            time.wDay,
            time.wHour,
            time.wMinute,
            time.wSecond,
            c.GetCurrentProcessId(),
        },
    ) catch return 0;
    var suffix_wide: [128]u16 = undefined;
    const suffix_length = std.unicode.utf8ToUtf16Le(&suffix_wide, suffix) catch return 0;

    var log_path = directory;
    var log_length = length;
    appendWide(&log_path, &log_length, suffix_wide[0..suffix_length]) catch return 0;
    appendWide(&log_path, &log_length, std.unicode.utf8ToUtf16LeStringLiteral(".log")) catch
        return 0;
    log_file = c.CreateFileW(
        &log_path,
        c.FILE_APPEND_DATA,
        c.FILE_SHARE_READ,
        null,
        c.CREATE_ALWAYS,
        c.FILE_ATTRIBUTE_NORMAL,
        null,
    );

    dump_path = directory;
    var dump_length = length;
    appendWide(&dump_path, &dump_length, suffix_wide[0..suffix_length]) catch return 0;
    appendWide(&dump_path, &dump_length, std.unicode.utf8ToUtf16LeStringLiteral(".dmp")) catch
        return 0;
    _ = c.SetUnhandledExceptionFilter(unhandledException);
    return @intFromBool(log_file != c.INVALID_HANDLE_VALUE);
}

fn appendWide(
    path: *[path_capacity:0]u16,
    length: *usize,
    suffix: []const u16,
) !void {
    if (length.* + suffix.len + 1 >= path.len) return error.PathTooLong;
    @memcpy(path[length.*..][0..suffix.len], suffix);
    length.* += suffix.len;
    path[length.*] = 0;
}

fn unhandledException(exception: [*c]c.EXCEPTION_POINTERS) callconv(.winapi) c.LONG {
    var line: [256]u8 = undefined;
    const record = exception.*.ExceptionRecord.*;
    const rendered = std.fmt.bufPrint(
        &line,
        "crash exception_code=0x{x:0>8} address=0x{x}\r\n",
        .{ record.ExceptionCode, @intFromPtr(record.ExceptionAddress) },
    ) catch "crash exception=unknown\r\n";
    noctty_windows_diagnostics_write(rendered.ptr, rendered.len);

    const dump = c.CreateFileW(
        &dump_path,
        c.GENERIC_WRITE,
        0,
        null,
        c.CREATE_ALWAYS,
        c.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (dump != c.INVALID_HANDLE_VALUE) {
        var information = c.MINIDUMP_EXCEPTION_INFORMATION{
            .ThreadId = c.GetCurrentThreadId(),
            .ExceptionPointers = exception,
            .ClientPointers = 0,
        };
        _ = c.MiniDumpWriteDump(
            c.GetCurrentProcess(),
            c.GetCurrentProcessId(),
            dump,
            c.MiniDumpNormal,
            &information,
            null,
            null,
        );
        _ = c.CloseHandle(dump);
    }
    return c.EXCEPTION_EXECUTE_HANDLER;
}

pub export fn noctty_windows_diagnostics_write(
    bytes: [*]const u8,
    length: usize,
) callconv(.c) void {
    if (log_file == c.INVALID_HANDLE_VALUE or length == 0) return;
    var offset: usize = 0;
    while (offset < length) {
        const request: c.DWORD = @intCast(@min(length - offset, std.math.maxInt(c.DWORD)));
        var written: c.DWORD = 0;
        if (c.WriteFile(log_file, bytes + offset, request, &written, null) == 0 or
            written == 0) return;
        offset += written;
    }
}

pub export fn noctty_windows_diagnostics_deinit() callconv(.c) void {
    if (log_file != c.INVALID_HANDLE_VALUE) {
        _ = c.CloseHandle(log_file);
        log_file = c.INVALID_HANDLE_VALUE;
    }
}
