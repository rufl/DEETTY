//! Win32 ConPTY ownership composed by the native Zig host.
//!
//! The host observes a session only through bounded reads, writes, resize, and
//! exit polling. This module alone owns every pipe, process, pseudo-console,
//! reader thread, lock, and output-ring lifetime.

const std = @import("std");
const Diagnostics = @import("WindowsDiagnostics.zig");
const OutputRing = @import("WindowsPtyLogic.zig").OutputRing;
const Share = @import("deetty_share");
const LaunchPlan = @import("WindowsLaunchPlan.zig");

const c = @import("c");

const output_ring_bytes: usize = 1024 * 1024;
const io_chunk_bytes: usize = 64 * 1024;
const command_capacity = LaunchPlan.command_capacity;
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

pub export fn deetty_windows_pty_create(
    index: c_int,
    columns: c_int,
    rows: c_int,
    launch_profile: c_int,
    custom_profile: ?*const Share.launch_profile.Profile,
    window: c.HWND,
    output_message: c.UINT,
) ?*Pty {
    return create(index, columns, rows, launch_profile, custom_profile, window, output_message) catch null;
}

fn create(
    index: c_int,
    columns: c_int,
    rows: c_int,
    launch_profile: c_int,
    custom_profile: ?*const Share.launch_profile.Profile,
    window: c.HWND,
    output_message: c.UINT,
) !*Pty {
    if (index < 0 or columns <= 0 or rows <= 0 or window == null) {
        return error.InvalidPtyConfiguration;
    }
    if (launch_profile < 0 or launch_profile > 2 or (launch_profile == 2) != (custom_profile != null))
        return error.InvalidPtyConfiguration;

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

    if (!createPseudoConsole(pty, launch_profile, custom_profile)) return error.PseudoConsoleUnavailable;
    errdefer closePlatformHandles(pty);

    pty.reader_thread = c.CreateThread(null, 0, readerThread, pty, 0, null);
    if (pty.reader_thread == null) {
        log("reader_thread_failed pane={d} error={d}\r\n", .{ index, c.GetLastError() });
        return error.ReaderThreadUnavailable;
    }
    return pty;
}

pub export fn deetty_windows_pty_destroy(optional_pty: ?*Pty) void {
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

pub export fn deetty_windows_pty_write(
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

pub export fn deetty_windows_pty_drain(
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

pub export fn deetty_windows_pty_resize(
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

pub export fn deetty_windows_pty_poll_exit(
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

pub export fn deetty_windows_pty_exited(optional_pty: ?*const Pty) c_int {
    const pty = optional_pty orelse return 0;
    return @intFromBool(pty.process_exited);
}

pub export fn deetty_windows_pty_exit_code(optional_pty: ?*const Pty) u32 {
    const pty = optional_pty orelse return 255;
    return pty.process_exit_code;
}

const qualification_arguments = "--launch-profile-child \"資料 with spaces\" \"C:\\ends\\\\\" & literal";

/// Called before normal application startup. No window or PTY is constructed.
pub fn qualificationChild(command_line: [*:0]const u16) ?c_int {
    const arguments = std.mem.span(command_line);
    const prefix = std.unicode.utf8ToUtf16LeStringLiteral("--launch-profile-child");
    if (!std.mem.startsWith(u16, arguments, prefix)) return null;
    if (!std.mem.eql(u16, arguments, std.unicode.utf8ToUtf16LeStringLiteral(qualification_arguments))) return 81;
    var module: [LaunchPlan.path_capacity]u16 = undefined;
    const module_len = c.GetModuleFileNameW(null, &module, module.len);
    if (module_len == 0 or module_len >= module.len) return 82;
    var directory: [LaunchPlan.path_capacity]u16 = undefined;
    const directory_len = c.GetCurrentDirectoryW(directory.len, &directory);
    if (directory_len == 0 or directory_len >= directory.len) return 83;
    if (!environmentEquals("DEETTY_QUAL_EXE", module[0..module_len]) or
        !environmentEquals("DEETTY_QUAL_CWD", directory[0..directory_len]) or
        !environmentEquals("DEETTY_QUAL_TEXT", std.unicode.utf8ToUtf16LeStringLiteral("資料=value")) or
        !environmentEquals("TERM", std.unicode.utf8ToUtf16LeStringLiteral("profile-term")) or
        !environmentEquals("COLORTERM", std.unicode.utf8ToUtf16LeStringLiteral("truecolor")))
        return 84;
    // An inherited Unicode value is supplied as a second expected value, not
    // recreated in the child, so this checks actual environment inheritance.
    var expected: [LaunchPlan.path_capacity]u16 = undefined;
    const expected_len = c.GetEnvironmentVariableW(std.unicode.utf8ToUtf16LeStringLiteral("DEETTY_QUAL_ROOT"), &expected, expected.len);
    if (expected_len == 0 or expected_len >= expected.len or !environmentEquals("SystemRoot", expected[0..expected_len])) return 85;
    return 0;
}

fn environmentEquals(comptime key: []const u8, expected: []const u16) bool {
    var actual: [LaunchPlan.path_capacity]u16 = undefined;
    const length = c.GetEnvironmentVariableW(std.unicode.utf8ToUtf16LeStringLiteral(key), &actual, actual.len);
    return length < actual.len and std.mem.eql(u16, expected, actual[0..length]);
}

/// Real native process qualification for runtimes without ConPTY support.
/// Copies the running executable into a unique directory, runs its early child
/// dispatcher with the production plan, waits at most 15 seconds, and removes
/// the executable/directory. No shell, mock session, or parent mutation is used.
pub fn qualifyLaunchProcess() bool {
    const before = c.GetEnvironmentStringsW() orelse return false;
    defer _ = c.FreeEnvironmentStringsW(before);
    const before_slice = environmentSlice(before) orelse return false;
    var temp: [c.MAX_PATH]u16 = undefined;
    const temp_len = c.GetTempPathW(temp.len, &temp);
    if (temp_len == 0 or temp_len >= temp.len) return false;
    var directory: [c.MAX_PATH]u16 = undefined;
    if (c.GetTempFileNameW(&temp, std.unicode.utf8ToUtf16LeStringLiteral("NLP"), 0, &directory) == 0) return false;
    if (c.DeleteFileW(&directory) == 0) return false;
    const directory_len = std.mem.sliceTo(&directory, 0).len;
    const suffix = std.unicode.utf8ToUtf16LeStringLiteral(" 資料 profiles");
    if (directory_len + suffix.len >= directory.len) return false;
    @memcpy(directory[directory_len..][0..suffix.len], suffix);
    directory[directory_len + suffix.len] = 0;
    if (c.CreateDirectoryW(&directory, null) == 0) return false;
    const result = qualifyInDirectory(std.mem.sliceTo(&directory, 0));
    const removed_directory = c.RemoveDirectoryW(&directory) != 0;
    const after = c.GetEnvironmentStringsW() orelse return false;
    defer _ = c.FreeEnvironmentStringsW(after);
    const after_slice = environmentSlice(after) orelse return false;
    return result and removed_directory and std.mem.eql(u16, before_slice, after_slice);
}

fn qualifyInDirectory(directory: []const u16) bool {
    var source: [LaunchPlan.path_capacity]u16 = undefined;
    const source_len = c.GetModuleFileNameW(null, &source, source.len);
    if (source_len == 0 or source_len >= source.len) return false;
    const filename = std.unicode.utf8ToUtf16LeStringLiteral("\\DEETTY 資料 with spaces.exe");
    var executable: [LaunchPlan.path_capacity]u16 = undefined;
    if (directory.len + filename.len >= executable.len) return false;
    @memcpy(executable[0..directory.len], directory);
    @memcpy(executable[directory.len..][0..filename.len], filename);
    const executable_len = directory.len + filename.len;
    executable[executable_len] = 0;
    if (c.CopyFileW(&source, &executable, c.TRUE) == 0) return false;
    const result = qualifyCopiedExecutable(executable[0..executable_len], directory);
    const removed_executable = c.DeleteFileW(&executable) != 0;
    return result and removed_executable;
}

fn qualifyCopiedExecutable(executable: []const u16, directory: []const u16) bool {
    var executable_utf8: [LaunchPlan.path_capacity * 3]u8 = undefined;
    const executable_len = std.unicode.utf16LeToUtf8(&executable_utf8, executable) catch return false;
    var directory_utf8: [LaunchPlan.path_capacity * 3]u8 = undefined;
    const directory_len = std.unicode.utf16LeToUtf8(&directory_utf8, directory) catch return false;
    var root: [LaunchPlan.path_capacity]u16 = undefined;
    const root_len = c.GetEnvironmentVariableW(std.unicode.utf8ToUtf16LeStringLiteral("SystemRoot"), &root, root.len);
    if (root_len == 0 or root_len >= root.len) return false;
    var root_utf8: [LaunchPlan.path_capacity * 3]u8 = undefined;
    const root_utf8_len = std.unicode.utf16LeToUtf8(&root_utf8, root[0..root_len]) catch return false;
    var environment: [Share.launch_profile.max_environment_bytes]u8 = undefined;
    const values = std.fmt.bufPrint(&environment, "DEETTY_QUAL_EXE={s};DEETTY_QUAL_CWD={s};DEETTY_QUAL_TEXT=資料=value;TERM=profile-term;DEETTY_QUAL_ROOT={s}", .{
        executable_utf8[0..executable_len],
        directory_utf8[0..directory_len],
        root_utf8[0..root_utf8_len],
    }) catch return false;
    var profile: Share.launch_profile.Profile = .{ .kind = .command };
    profile.shell.set(executable_utf8[0..executable_len]) catch return false;
    profile.command.set(qualification_arguments) catch return false;
    profile.working_directory.set(directory_utf8[0..directory_len]) catch return false;
    profile.environment.set(values) catch return false;
    var plan: LaunchPlan.Plan = .{};
    if (!initializePlan(&plan, &profile)) return false;
    var startup: c.STARTUPINFOW = std.mem.zeroes(c.STARTUPINFOW);
    startup.cb = @sizeOf(c.STARTUPINFOW);
    var process: c.PROCESS_INFORMATION = std.mem.zeroes(c.PROCESS_INFORMATION);
    if (!spawnPlan(&plan, &startup, c.CREATE_NO_WINDOW, &process)) return false;
    defer closeHandle(&process.hProcess);
    defer closeHandle(&process.hThread);
    if (c.WaitForSingleObject(process.hProcess, 10_000) != c.WAIT_OBJECT_0) {
        _ = c.TerminateProcess(process.hProcess, 86);
        _ = c.WaitForSingleObject(process.hProcess, 5_000);
        return false;
    }
    var exit_code: c.DWORD = 255;
    if (c.GetExitCodeProcess(process.hProcess, &exit_code) == 0 or exit_code != 0) return false;
    // Both configured resources are rejected before any override or spawn.
    profile.shell.set(directory_utf8[0..directory_len]) catch return false;
    if (initializePlan(&plan, &profile)) return false;
    profile.shell.set(executable_utf8[0..executable_len]) catch return false;
    profile.working_directory.set(executable_utf8[0..executable_len]) catch return false;
    return !initializePlan(&plan, &profile);
}

/// The environment allocation remains owned by Windows until copied into Plan.
fn environmentSlice(block: [*]const u16) ?[]const u16 {
    var index: usize = 0;
    while (index + 1 < LaunchPlan.environment_capacity) : (index += 1) {
        if (block[index] == 0 and block[index + 1] == 0) return block[0 .. index + 2];
    }
    return null;
}

fn initializePlan(plan: *LaunchPlan.Plan, custom: ?*const Share.launch_profile.Profile) bool {
    if (custom) |profile| {
        plan.custom(profile) catch return false;
        // Validate the configured target before trying an operator override.
        // A broken custom executable must not masquerade as a successful launch.
        if (!resolveApplication(plan)) return false;
    } else {
        const length = c.GetEnvironmentVariableW(
            std.unicode.utf8ToUtf16LeStringLiteral("USERPROFILE"),
            &plan.directory,
            plan.directory.len,
        );
        if (length >= plan.directory.len) return false;
        plan.directory_len = length;
    }
    if (plan.directory_len != 0) {
        const attributes = c.GetFileAttributesW(&plan.directory);
        if (attributes == c.INVALID_FILE_ATTRIBUTES or attributes & c.FILE_ATTRIBUTE_DIRECTORY == 0) return false;
    }
    const block = c.GetEnvironmentStringsW() orelse return false;
    defer _ = c.FreeEnvironmentStringsW(block);
    const inherited = environmentSlice(block) orelse return false;
    plan.setEnvironment(inherited, if (custom) |profile| profile.environment.slice() else "") catch return false;
    return true;
}

/// Resolve every executable before CreateProcessW, including builtin names.
/// The original, quoted argv0 stays intact; lpApplicationName is unambiguous.
fn resolveApplication(plan: *LaunchPlan.Plan) bool {
    var resolved: [LaunchPlan.path_capacity]u16 = undefined;
    const executable = plan.application[0..plan.application_len];
    const has_path = std.mem.indexOfScalar(u16, executable, '\\') != null or
        std.mem.indexOfScalar(u16, executable, '/') != null or
        std.mem.indexOfScalar(u16, executable, ':') != null;
    const length = if (has_path)
        c.GetFullPathNameW(&plan.application, resolved.len, &resolved, null)
    else
        c.SearchPathW(null, &plan.application, std.unicode.utf8ToUtf16LeStringLiteral(".exe"), resolved.len, &resolved, null);
    if (length == 0 or length >= resolved.len) return false;
    const attributes = c.GetFileAttributesW(&resolved);
    if (attributes == c.INVALID_FILE_ATTRIBUTES or attributes & c.FILE_ATTRIBUTE_DIRECTORY != 0) return false;
    var binary_type: c.DWORD = 0;
    if (c.GetBinaryTypeW(&resolved, &binary_type) == 0) return false;
    @memcpy(plan.application[0 .. length + 1], resolved[0 .. length + 1]);
    plan.application_len = length;
    return true;
}

fn spawnPlan(plan: *LaunchPlan.Plan, startup: *c.STARTUPINFOW, flags: c.DWORD, process: *c.PROCESS_INFORMATION) bool {
    return c.CreateProcessW(
        &plan.application,
        &plan.command,
        null,
        null,
        c.FALSE,
        flags | c.CREATE_UNICODE_ENVIRONMENT,
        &plan.environment,
        if (plan.directory_len == 0) null else &plan.directory,
        startup,
        process,
    ) != 0;
}

fn spawnSelected(
    selection: c_int,
    custom: ?*const Share.launch_profile.Profile,
    startup: *c.STARTUPINFOW,
    flags: c.DWORD,
    process: *c.PROCESS_INFORMATION,
) bool {
    var plan: LaunchPlan.Plan = .{};
    if (!initializePlan(&plan, custom)) return false;
    var operator_command: [command_capacity]u16 = undefined;
    const operator_length = c.GetEnvironmentVariableW(
        std.unicode.utf8ToUtf16LeStringLiteral("DEETTY_WINDOWS_SHELL"),
        &operator_command,
        operator_command.len,
    );
    if (operator_length >= operator_command.len) return false;
    if (operator_length != 0) {
        plan.operator(operator_command[0..operator_length]) catch return false;
        if (resolveApplication(&plan) and spawnPlan(&plan, startup, flags, process)) return true;
        log("shell_operator_failed error={d}\r\n", .{c.GetLastError()});
    }
    if (custom) |profile| {
        plan.custom(profile) catch return false;
        if (!resolveApplication(&plan)) return false;
        return spawnPlan(&plan, startup, flags, process);
    }
    for (@import("WindowsPtyLogic.zig").defaultShellCommands(selection)) |command| {
        plan.operator(command) catch return false;
        if (resolveApplication(&plan) and spawnPlan(&plan, startup, flags, process)) return true;
        log("shell_candidate_failed error={d}\r\n", .{c.GetLastError()});
    }
    return false;
}

fn createPseudoConsole(pty: *Pty, launch_profile: c_int, custom_profile: ?*const Share.launch_profile.Profile) bool {
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
    var process: c.PROCESS_INFORMATION = std.mem.zeroes(c.PROCESS_INFORMATION);
    if (!spawnSelected(launch_profile, custom_profile, &startup.StartupInfo, c.EXTENDED_STARTUPINFO_PRESENT, &process))
        return false;
    pty.process = process.hProcess;
    closeHandle(&process.hThread);
    log("shell_spawned pane={d} pid={d}\r\n", .{ pty.index, process.dwProcessId });
    success = true;
    return true;
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
    Diagnostics.deetty_windows_diagnostics_write(line.ptr, line.len);
}
