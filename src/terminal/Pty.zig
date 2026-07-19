const std = @import("std");
const LaunchProfile = @import("LaunchProfile.zig");

const c = @cImport({
    @cInclude("sys/types.h");
});

extern fn noctty_pty_spawn(cwd: [*:0]const u8, shell: [*:0]const u8, master_fd: *c_int, child_pid: *c_int) c_int;
extern fn noctty_pty_spawn_profile(cwd: [*:0]const u8, program: [*:0]const u8, kind: c_int, argument: [*:0]const u8, environment: [*:0]const u8, master_fd: *c_int, child_pid: *c_int) c_int;
extern fn noctty_pty_read(fd: c_int, buffer: [*]u8, length: usize) isize;
extern fn noctty_pty_write(fd: c_int, buffer: [*]const u8, length: usize) isize;
extern fn noctty_pty_resize(fd: c_int, rows: c_ushort, columns: c_ushort, width_px: c_uint, height_px: c_uint) c_int;
extern fn noctty_pty_poll_exit(child_pid: c_int, exit_code: *c_int) c_int;
extern fn noctty_pty_has_foreground_process(fd: c_int, child_pid: c_int) c_int;
extern fn noctty_pty_process_info(fd: c_int, child_pid: c_int, cwd: [*]u8, cwd_capacity: usize, cwd_length: *usize, name: [*]u8, name_capacity: usize, name_length: *usize, process_pid: *c_int) c_int;
extern fn noctty_pty_close(fd: c_int, child_pid: c_int) void;
extern fn noctty_pty_sleep_ms(milliseconds: c_uint) void;

pub const ReadResult = union(enum) {
    bytes: usize,
    would_block,
    eof,
};

pub const ProcessInfo = struct {
    process_id: i32,
    cwd: []u8,
    name: []u8,
};

pub const SpawnOptions = struct {
    cwd: [:0]const u8,
    program: [:0]const u8,
    kind: LaunchProfile.Kind,
    argument: [:0]const u8,
    environment: [:0]const u8,
};

pub fn sleepBrief(milliseconds: u32) void {
    noctty_pty_sleep_ms(milliseconds);
}

pub const Session = struct {
    master_fd: c_int,
    child_pid: c_int,
    closed: bool = false,
    exit_code: ?u8 = null,

    pub fn spawn(cwd: [:0]const u8, shell: [:0]const u8) !Session {
        var master_fd: c_int = -1;
        var child_pid: c_int = -1;
        if (noctty_pty_spawn(cwd.ptr, shell.ptr, &master_fd, &child_pid) != 0) return error.PtySpawnFailed;
        return .{ .master_fd = master_fd, .child_pid = child_pid };
    }

    pub fn spawnProfile(options: SpawnOptions) !Session {
        var master_fd: c_int = -1;
        var child_pid: c_int = -1;
        if (noctty_pty_spawn_profile(
            options.cwd.ptr,
            options.program.ptr,
            @intCast(@intFromEnum(options.kind)),
            options.argument.ptr,
            options.environment.ptr,
            &master_fd,
            &child_pid,
        ) != 0) return error.PtySpawnFailed;
        return .{ .master_fd = master_fd, .child_pid = child_pid };
    }

    pub fn deinit(self: *Session) void {
        if (self.closed) return;
        noctty_pty_close(self.master_fd, self.child_pid);
        self.closed = true;
    }

    pub fn fileDescriptor(self: *const Session) c_int {
        return if (self.closed) -1 else self.master_fd;
    }

    pub fn processId(self: *const Session) i32 {
        return if (self.closed) 0 else self.child_pid;
    }

    pub fn hasForegroundProcess(self: *const Session) bool {
        return !self.closed and
            noctty_pty_has_foreground_process(self.master_fd, self.child_pid) > 0;
    }

    pub fn processInfo(self: *const Session, cwd: []u8, name: []u8) ?ProcessInfo {
        if (self.closed or cwd.len == 0 or name.len == 0) return null;
        var cwd_length: usize = 0;
        var name_length: usize = 0;
        var process_id: c_int = self.child_pid;
        if (noctty_pty_process_info(
            self.master_fd,
            self.child_pid,
            cwd.ptr,
            cwd.len,
            &cwd_length,
            name.ptr,
            name.len,
            &name_length,
            &process_id,
        ) == 0) return null;
        return .{
            .process_id = process_id,
            .cwd = cwd[0..cwd_length],
            .name = name[0..name_length],
        };
    }

    pub fn read(self: *Session, buffer: []u8) !ReadResult {
        if (self.closed) return error.PtyClosed;
        const result = noctty_pty_read(self.master_fd, buffer.ptr, buffer.len);
        if (result == -2) return .would_block;
        if (result < 0) return error.PtyReadFailed;
        if (result == 0) return .eof;
        return .{ .bytes = @intCast(result) };
    }

    pub fn write(self: *Session, bytes: []const u8) !usize {
        if (self.closed) return error.PtyClosed;
        const result = noctty_pty_write(self.master_fd, bytes.ptr, bytes.len);
        if (result == -2) return error.PtyWouldBlock;
        if (result < 0) return error.PtyWriteFailed;
        return @intCast(result);
    }

    pub fn writeAll(self: *Session, bytes: []const u8) !void {
        var offset: usize = 0;
        while (offset < bytes.len) {
            const written = self.write(bytes[offset..]) catch |err| switch (err) {
                error.PtyWouldBlock => {
                    noctty_pty_sleep_ms(1);
                    continue;
                },
                else => return err,
            };
            offset += written;
        }
    }

    pub fn resize(self: *Session, rows: u16, columns: u16, width_px: u32, height_px: u32) !void {
        if (self.closed) return error.PtyClosed;
        if (noctty_pty_resize(self.master_fd, rows, columns, width_px, height_px) != 0) return error.PtyResizeFailed;
    }

    pub fn pollExit(self: *Session) !?u8 {
        if (self.exit_code) |code| return code;
        if (self.closed) return error.PtyClosed;
        var exit_code: c_int = 255;
        const result = noctty_pty_poll_exit(self.child_pid, &exit_code);
        if (result < 0) return error.PtyWaitFailed;
        if (result == 0) return null;
        self.exit_code = @intCast(@max(0, @min(exit_code, 255)));
        return self.exit_code;
    }
};

test "zig-owned pty spawns shell, routes bytes, resizes, and observes exit" {
    var session = try Session.spawn("/tmp", "/bin/sh");
    defer session.deinit();

    try std.testing.expect(session.fileDescriptor() >= 0);

    try session.resize(24, 80, 800, 480);
    try session.writeAll("printf 'NOCTTY_ZIG_PTY_OK\n'; exit 0\n");

    var output: [4096]u8 = undefined;
    var used: usize = 0;
    var saw_marker = false;
    var saw_exit = false;
    var attempt: usize = 0;
    while (attempt < 5000 and !(saw_exit and saw_marker)) : (attempt += 1) {
        switch (try session.read(output[used..])) {
            .bytes => |count| {
                used += count;
                if (std.mem.indexOf(u8, output[0..used], "NOCTTY_ZIG_PTY_OK") != null) saw_marker = true;
            },
            .would_block => noctty_pty_sleep_ms(2),
            .eof => saw_exit = true,
        }
        if (try session.pollExit()) |code| {
            try std.testing.expectEqual(@as(u8, 0), code);
            saw_exit = true;
        }
    }
    try std.testing.expect(saw_marker);
    try std.testing.expect(saw_exit);
}

test "zig-owned pty advertises the tested terminal capability environment" {
    var session = try Session.spawn("/tmp", "/bin/sh");
    defer session.deinit();
    try session.writeAll("printf 'NOCTTY_TERM=%s COLORTERM=%s\\n' \"$TERM\" \"$COLORTERM\"; exit 0\n");

    var output: [4096]u8 = undefined;
    var used: usize = 0;
    var saw_environment = false;
    var saw_exit = false;
    for (0..5000) |_| {
        if (saw_environment and saw_exit) break;
        switch (try session.read(output[used..])) {
            .bytes => |count| {
                used += count;
                saw_environment = std.mem.indexOf(
                    u8,
                    output[0..used],
                    "NOCTTY_TERM=xterm-256color COLORTERM=truecolor",
                ) != null;
            },
            .would_block => noctty_pty_sleep_ms(2),
            .eof => saw_exit = true,
        }
        if (try session.pollExit()) |code| {
            try std.testing.expectEqual(@as(u8, 0), code);
            saw_exit = true;
        }
    }
    try std.testing.expect(saw_environment);
    try std.testing.expect(saw_exit);
}

test "zig-owned pty distinguishes the shell from a foreground job" {
    var session = try Session.spawn("/tmp", "/bin/sh");
    defer session.deinit();

    var shell_ready = false;
    for (0..1000) |_| {
        if (!session.hasForegroundProcess()) {
            shell_ready = true;
            break;
        }
        noctty_pty_sleep_ms(1);
    }
    try std.testing.expect(shell_ready);

    try session.writeAll("sleep 5\n");
    var foreground_seen = false;
    for (0..1000) |_| {
        if (session.hasForegroundProcess()) {
            foreground_seen = true;
            break;
        }
        noctty_pty_sleep_ms(1);
    }
    try std.testing.expect(foreground_seen);
}

test "zig-owned pty exposes bounded foreground process metadata" {
    var session = try Session.spawn("/tmp", "/bin/sh");
    defer session.deinit();

    var cwd: [4096]u8 = undefined;
    var name: [256]u8 = undefined;
    var shell_ready = false;
    for (0..1000) |_| {
        const shell = session.processInfo(&cwd, &name) orelse {
            noctty_pty_sleep_ms(1);
            continue;
        };
        if (std.mem.eql(u8, shell.cwd, "/tmp") and shell.name.len > 0) {
            shell_ready = true;
            break;
        }
        noctty_pty_sleep_ms(1);
    }
    try std.testing.expect(shell_ready);

    try session.writeAll("sleep 5\n");
    var saw_sleep = false;
    for (0..1000) |_| {
        const foreground = session.processInfo(&cwd, &name) orelse {
            noctty_pty_sleep_ms(1);
            continue;
        };
        if (std.mem.eql(u8, foreground.name, "sleep")) {
            try std.testing.expect(foreground.process_id > 0);
            try std.testing.expectEqualStrings("/tmp", foreground.cwd);
            saw_sleep = true;
            break;
        }
        noctty_pty_sleep_ms(1);
    }
    try std.testing.expect(saw_sleep);
}
