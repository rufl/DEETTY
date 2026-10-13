const std = @import("std");
const Compat = @import("compat");
const LaunchProfile = @import("LaunchProfile.zig");

extern fn tcgetpgrp(fd: c_int) c_int;
extern fn getpgrp() c_int;
extern fn posix_openpt(flags: c_int) c_int;
extern fn grantpt(fd: c_int) c_int;
extern fn unlockpt(fd: c_int) c_int;
extern fn ptsname(fd: c_int) ?[*:0]u8;
extern fn execve(
    path: [*:0]const u8,
    argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
) c_int;
extern var environ: [*:null]?[*:0]u8;

const test_poll_limit = 30_000;

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

pub const ResourceSample = struct {
    ticks: u64 = 0,
    rss_kib: u64 = 0,
    processes: u32 = 0,
    machine_ticks: u64 = 0,
    cpu_count: u32 = 1,
};

pub const ResourceSamplePair = struct {
    app: ResourceSample,
    pane: ResourceSample,
};

const ProcessTotals = struct {
    ticks: u64 = 0,
    rss_kib: u64 = 0,
    processes: u32 = 0,
};

const ProcessWalk = struct {
    root: ProcessTotals = .{},
    pane: ProcessTotals = .{},
    pane_found: bool = false,
};

const MachineSample = struct {
    ticks: u64,
    cpu_count: u32,
};

fn readFile(path: [*:0]const u8, buffer: []u8) ?[]u8 {
    const flags: std.posix.O = .{ .ACCMODE = .RDONLY, .CLOEXEC = true };
    const fd = std.posix.openatZ(std.posix.AT.FDCWD, path, flags, 0) catch return null;
    defer _ = std.c.close(fd);
    const read_length = std.c.read(fd, buffer.ptr, buffer.len);
    if (read_length < 0) return null;
    var length: usize = @intCast(read_length);
    while (length > 0 and (buffer[length - 1] == '\n' or buffer[length - 1] == '\r')) length -= 1;
    return buffer[0..length];
}

fn readProcFile(pid: i32, leaf: []const u8, buffer: []u8) ?[]u8 {
    if (pid <= 0 or buffer.len == 0) return null;
    var path_buffer: [96]u8 = undefined;
    const path = Compat.bufPrintZ(&path_buffer, "/proc/{d}/{s}", .{ pid, leaf }) catch return null;
    return readFile(path.ptr, buffer);
}

fn readProcLink(pid: i32, leaf: []const u8, buffer: []u8) ?[]u8 {
    if (pid <= 0 or buffer.len == 0) return null;
    var path_buffer: [96]u8 = undefined;
    const path = Compat.bufPrintZ(&path_buffer, "/proc/{d}/{s}", .{ pid, leaf }) catch return null;
    const length = std.c.readlink(path.ptr, buffer.ptr, buffer.len);
    if (length <= 0) return null;
    return buffer[0..@intCast(length)];
}

fn processStat(pid: i32, page_size: u64) ?ProcessTotals {
    var stat_buffer: [4096]u8 = undefined;
    const stat = readProcFile(pid, "stat", stat_buffer[0 .. stat_buffer.len - 1]) orelse return null;
    const fields_start = (std.mem.lastIndexOf(u8, stat, ") ") orelse return null) + 2;
    var fields = std.mem.tokenizeScalar(u8, stat[fields_start..], ' ');
    var number: u8 = 3;
    var user_ticks: u64 = 0;
    var system_ticks: u64 = 0;
    while (fields.next()) |field| : (number += 1) {
        if (number == 14) user_ticks = std.fmt.parseInt(u64, field, 10) catch 0;
        if (number == 15) {
            system_ticks = std.fmt.parseInt(u64, field, 10) catch 0;
            break;
        }
    }

    var statm_buffer: [256]u8 = undefined;
    const statm = readProcFile(pid, "statm", statm_buffer[0 .. statm_buffer.len - 1]) orelse return null;
    var pages = std.mem.tokenizeScalar(u8, statm, ' ');
    _ = pages.next() orelse return null;
    const resident_pages = std.fmt.parseInt(u64, pages.next() orelse return null, 10) catch return null;
    return .{
        .ticks = user_ticks + system_ticks,
        .rss_kib = resident_pages * page_size / 1024,
        .processes = 1,
    };
}

fn addTotals(target: *ProcessTotals, process: ProcessTotals) void {
    target.ticks += process.ticks;
    target.rss_kib += process.rss_kib;
    target.processes += process.processes;
}

fn walkProcessTree(root_pid: i32, pane_root_pid: i32) ?ProcessWalk {
    if (root_pid <= 0) return null;
    const page_size_raw = std.c.sysconf(@backingInt(std.c._SC.PAGESIZE));
    if (page_size_raw <= 0) return null;
    const page_size: u64 = @intCast(page_size_raw);
    var queue: [4096]i32 = undefined; // ponytail: bounded /proc walk; raise if 4096 descendants becomes real.
    var pane_descendant: [4096]bool = undefined;
    var head: usize = 0;
    var tail: usize = 1;
    queue[0] = root_pid;
    pane_descendant[0] = root_pid == pane_root_pid;
    var result = ProcessWalk{};

    while (head < tail) : (head += 1) {
        const pid = queue[head];
        const in_pane = pane_descendant[head];
        const process = processStat(pid, page_size) orelse continue;
        addTotals(&result.root, process);
        if (in_pane) {
            result.pane_found = true;
            addTotals(&result.pane, process);
        }

        var children_buffer: [8192]u8 = undefined;
        var path_buffer: [96]u8 = undefined;
        const path = Compat.bufPrintZ(
            &path_buffer,
            "/proc/{d}/task/{d}/children",
            .{ pid, pid },
        ) catch continue;
        const children = readFile(path.ptr, children_buffer[0 .. children_buffer.len - 1]) orelse continue;
        var ids = std.mem.tokenizeAny(u8, children, " \n");
        while (tail < queue.len) {
            const raw = ids.next() orelse break;
            const child = std.fmt.parseInt(i32, raw, 10) catch break;
            if (child <= 0) continue;
            queue[tail] = child;
            pane_descendant[tail] = in_pane or child == pane_root_pid;
            tail += 1;
        }
    }
    return result;
}

fn machineSample() ?MachineSample {
    var buffer: [4096]u8 = undefined;
    const contents = readFile("/proc/stat", buffer[0 .. buffer.len - 1]) orelse return null;
    var fields = std.mem.tokenizeAny(u8, contents, " \n");
    if (!std.mem.eql(u8, fields.next() orelse return null, "cpu")) return null;
    var ticks: u64 = 0;
    var count: u8 = 0;
    while (count < 10) : (count += 1) {
        const field = fields.next() orelse break;
        ticks += std.fmt.parseInt(u64, field, 10) catch return null;
    }
    if (count < 4) return null;
    return .{
        .ticks = ticks,
        .cpu_count = @intCast(std.Thread.getCpuCount() catch 1),
    };
}

fn completeSample(totals: ProcessTotals, machine: MachineSample) ResourceSample {
    return .{
        .ticks = totals.ticks,
        .rss_kib = totals.rss_kib,
        .processes = totals.processes,
        .machine_ticks = machine.ticks,
        .cpu_count = machine.cpu_count,
    };
}

pub fn resourceSample(root_pid: i32) ?ResourceSample {
    const root = if (root_pid > 0) root_pid else std.c.getpid();
    const walked = walkProcessTree(root, 0) orelse return null;
    if (walked.root.processes == 0) return null;
    return completeSample(walked.root, machineSample() orelse return null);
}

pub fn resourceSamplePair(pane_root_pid: i32) ?ResourceSamplePair {
    const app_root = std.c.getpid();
    var walked = walkProcessTree(app_root, pane_root_pid) orelse return null;
    if (walked.root.processes == 0) return null;
    if (pane_root_pid > 0 and !walked.pane_found) {
        const pane_walk = walkProcessTree(pane_root_pid, pane_root_pid);
        if (pane_walk) |separate| walked.pane = separate.root;
    }
    const machine = machineSample() orelse return null;
    return .{
        .app = completeSample(walked.root, machine),
        .pane = completeSample(walked.pane, machine),
    };
}

pub const SpawnOptions = struct {
    cwd: [:0]const u8,
    program: [:0]const u8,
    kind: LaunchProfile.Kind,
    argument: [:0]const u8,
    environment: [:0]const u8,
};

const child_environment_inherited_max: usize = 4096;
const child_environment_override_max: usize = LaunchProfile.max_environment_entries + 2;

const ChildEnvironment = struct {
    entries: [child_environment_inherited_max + child_environment_override_max + 1]?[*:0]const u8,
    overrides: [child_environment_override_max][*:0]const u8,
    override_keys: [child_environment_override_max][]const u8,
    storage: [LaunchProfile.max_environment_bytes + 1]u8,
    entry_count: usize,
    override_count: usize,

    fn init(self: *ChildEnvironment, raw: [:0]const u8) !void {
        self.entry_count = 0;
        self.override_count = 0;

        if (raw.len > 0) {
            @memcpy(self.storage[0..raw.len], raw);
            self.storage[raw.len] = 0;
            var start: usize = 0;
            while (start < raw.len) {
                const end = std.mem.indexOfScalarPos(
                    u8,
                    self.storage[0..raw.len],
                    start,
                    ';',
                ) orelse raw.len;
                self.storage[end] = 0;
                const equals = start + (std.mem.indexOfScalar(
                    u8,
                    self.storage[start..end],
                    '=',
                ) orelse return error.PtySpawnFailed);
                const key = self.storage[start..equals];
                if (!std.mem.eql(u8, key, "TERM") and
                    !std.mem.eql(u8, key, "COLORTERM") and
                    !isStartupActivationKey(key))
                {
                    self.overrides[self.override_count] = @ptrCast(self.storage[start..].ptr);
                    self.override_keys[self.override_count] = key;
                    self.override_count += 1;
                }
                start = end + 1;
            }
        }

        self.addFixedOverride("TERM", "TERM=xterm-256color");
        self.addFixedOverride("COLORTERM", "COLORTERM=truecolor");

        var inherited_index: usize = 0;
        while (environ[inherited_index]) |entry| : (inherited_index += 1) {
            const text = std.mem.span(entry);
            const equals = std.mem.indexOfScalar(u8, text, '=') orelse text.len;
            const key = text[0..equals];
            if (self.overridesKey(key) or isStartupActivationKey(key)) continue;
            // ponytail: Fail closed if a process really carries more than 4096 variables.
            if (self.entry_count == child_environment_inherited_max)
                return error.PtySpawnFailed;
            self.entries[self.entry_count] = entry;
            self.entry_count += 1;
        }
        for (self.overrides[0..self.override_count]) |entry| {
            self.entries[self.entry_count] = entry;
            self.entry_count += 1;
        }
        self.entries[self.entry_count] = null;
    }

    fn addFixedOverride(
        self: *ChildEnvironment,
        key: []const u8,
        entry: [*:0]const u8,
    ) void {
        self.overrides[self.override_count] = entry;
        self.override_keys[self.override_count] = key;
        self.override_count += 1;
    }

    fn overridesKey(self: *const ChildEnvironment, key: []const u8) bool {
        for (self.override_keys[0..self.override_count]) |override_key| {
            if (std.mem.eql(u8, override_key, key)) return true;
        }
        return false;
    }

    fn pointer(self: *const ChildEnvironment) [*:null]const ?[*:0]const u8 {
        return self.entries[0..self.entry_count :null].ptr;
    }
};

fn isStartupActivationKey(key: []const u8) bool {
    return std.mem.eql(u8, key, "XDG_ACTIVATION_TOKEN") or
        std.mem.eql(u8, key, "DESKTOP_STARTUP_ID");
}

fn childCloseInheritedDescriptors() void {
    const linux = std.os.linux;
    const result = linux.close_range(3, std.math.maxInt(linux.fd_t), .{
        .UNSHARE = false,
        .CLOEXEC = false,
    });
    if (linux.errno(result) == .SUCCESS) return;

    // ponytail: Old-kernel fallback is bounded; raise only for verified >4096-fd launches.
    for (3..4096) |fd| _ = linux.close(@intCast(fd));
}

fn childExec(
    options: SpawnOptions,
    environment: *const ChildEnvironment,
    master: c_int,
    slave: c_int,
) noreturn {
    if (std.c.setsid() < 0) std.c._exit(127);
    if (std.c.ioctl(slave, std.c.T.IOCSCTTY, @as(c_int, 0)) < 0) std.c._exit(127);
    if (std.c.dup2(slave, 0) < 0 or std.c.dup2(slave, 1) < 0 or std.c.dup2(slave, 2) < 0)
        std.c._exit(127);
    if (slave > 2) _ = std.c.close(slave);
    _ = std.c.close(master);
    childCloseInheritedDescriptors();
    if (options.cwd.len > 0 and std.c.chdir(options.cwd.ptr) != 0) std.c._exit(127);

    switch (options.kind) {
        .shell => {
            const argv = [_:null]?[*:0]const u8{ options.program.ptr, "-i" };
            _ = execve(options.program.ptr, &argv, environment.pointer());
        },
        .command => {
            const argv = [_:null]?[*:0]const u8{ options.program.ptr, "-lc", options.argument.ptr };
            _ = execve(options.program.ptr, &argv, environment.pointer());
        },
        .ssh => {
            const argv = [_:null]?[*:0]const u8{ "ssh", options.argument.ptr };
            _ = execve(options.program.ptr, &argv, environment.pointer());
        },
        .tmux => {
            const argv = [_:null]?[*:0]const u8{ "tmux", "new-session", "-A", "-s", options.argument.ptr };
            _ = execve(options.program.ptr, &argv, environment.pointer());
        },
        .zellij => {
            const argv = [_:null]?[*:0]const u8{ "zellij", "attach", "--create", options.argument.ptr };
            _ = execve(options.program.ptr, &argv, environment.pointer());
        },
    }
    std.c._exit(127);
}

fn resolveExecutableInPath(name: []const u8, path: []const u8, buffer: []u8) ?[:0]const u8 {
    var directories = std.mem.splitScalar(u8, path, ':');
    while (directories.next()) |directory| {
        if (!std.fs.path.isAbsolute(directory)) continue;
        const candidate = Compat.bufPrintZ(
            buffer,
            "{s}/{s}",
            .{ directory, name },
        ) catch continue;
        if (std.c.access(candidate.ptr, std.c.X_OK) == 0) return candidate;
    }
    return null;
}

fn resolveExecutable(name: []const u8, buffer: []u8) ?[:0]const u8 {
    const path = if (std.c.getenv("PATH")) |value|
        std.mem.span(value)
    else
        "/usr/local/bin:/usr/bin:/bin";
    return resolveExecutableInPath(name, path, buffer);
}

fn spawnPty(options: SpawnOptions) !Session {
    const program_must_be_absolute = options.kind == .shell or options.kind == .command;
    if ((program_must_be_absolute and
        (options.program.len == 0 or !std.fs.path.isAbsolute(options.program))) or
        (options.cwd.len > 0 and !std.fs.path.isAbsolute(options.cwd)) or
        std.mem.indexOfScalar(u8, options.program, 0) != null or
        std.mem.indexOfScalar(u8, options.cwd, 0) != null or
        std.mem.indexOfScalar(u8, options.argument, 0) != null or
        options.environment.len > LaunchProfile.max_environment_bytes or
        std.mem.indexOfScalar(u8, options.environment, 0) != null or
        (options.kind != .shell and options.argument.len == 0))
        return error.PtySpawnFailed;
    LaunchProfile.validateEnvironment(options.environment) catch return error.PtySpawnFailed;

    var child_environment: ChildEnvironment = undefined;
    try child_environment.init(options.environment);

    var executable_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var child_options = options;
    child_options.program = switch (options.kind) {
        .shell, .command => options.program,
        .ssh => resolveExecutable("ssh", &executable_buffer) orelse return error.PtySpawnFailed,
        .tmux => resolveExecutable("tmux", &executable_buffer) orelse return error.PtySpawnFailed,
        .zellij => resolveExecutable("zellij", &executable_buffer) orelse return error.PtySpawnFailed,
    };

    const master_flags = std.c.O{
        .ACCMODE = .RDWR,
        .NOCTTY = true,
        .NONBLOCK = true,
        .CLOEXEC = true,
    };
    const master = posix_openpt(@bitCast(master_flags));
    if (master < 0) return error.PtySpawnFailed;
    errdefer _ = std.c.close(master);
    if (grantpt(master) != 0 or unlockpt(master) != 0) return error.PtySpawnFailed;
    const slave_name = ptsname(master) orelse return error.PtySpawnFailed;
    const slave = std.c.open(slave_name, std.c.O{ .ACCMODE = .RDWR, .NOCTTY = true, .CLOEXEC = true });
    if (slave < 0) return error.PtySpawnFailed;
    errdefer _ = std.c.close(slave);

    const child_pid = std.c.fork();
    if (child_pid < 0) return error.PtySpawnFailed;
    if (child_pid == 0)
        childExec(child_options, &child_environment, master, slave);
    _ = std.c.close(slave);
    return .{ .master_fd = master, .child_pid = child_pid };
}

pub fn sleepBrief(milliseconds: u32) void {
    const duration = std.c.timespec{
        .sec = @intCast(milliseconds / 1000),
        .nsec = @intCast((milliseconds % 1000) * 1_000_000),
    };
    _ = std.c.nanosleep(&duration, null);
}

fn processGroupAlive(process_group: c_int, own_group: c_int) bool {
    if (process_group <= 1 or process_group == own_group) return false;
    const result = std.c.kill(-process_group, @fromBackingInt(@intCast(0)));
    return result == 0 or std.posix.errno(result) == .PERM;
}

fn signalProcess(pid: c_int, signal: std.c.SIG) void {
    _ = std.c.kill(pid, signal);
}

fn monotonicMilliseconds() ?u64 {
    var now: std.c.timespec = undefined;
    if (std.c.clock_gettime(.MONOTONIC, &now) != 0) return null;
    if (now.sec < 0 or now.nsec < 0) return null;
    return @as(u64, @intCast(now.sec)) * std.time.ms_per_s +
        @as(u64, @intCast(now.nsec)) / std.time.ns_per_ms;
}

fn closePty(fd: c_int, child_pid: c_int, child_reaped: bool) void {
    const foreground = if (fd >= 0) tcgetpgrp(fd) else -1;
    const own_group = getpgrp();
    var foreground_alive = processGroupAlive(foreground, own_group);
    if (foreground_alive) signalProcess(-foreground, .HUP);
    if (fd >= 0) _ = std.c.close(fd);
    if (child_pid <= 0) return;

    var status: c_int = 0;
    var child_running = false;
    if (!child_reaped)
        child_running = std.c.waitpid(child_pid, &status, std.c.W.NOHANG) == 0;
    var shell_group_alive = !child_reaped and processGroupAlive(child_pid, own_group);
    if (child_running or shell_group_alive) signalProcess(-child_pid, .HUP);
    if (child_running) signalProcess(child_pid, .HUP);

    const graceful_shutdown_ms: u64 = 500;
    const shutdown_deadline_ms = if (monotonicMilliseconds()) |started_ms|
        started_ms +| graceful_shutdown_ms
    else
        null;
    for (0..50) |_| {
        foreground_alive = processGroupAlive(foreground, own_group);
        shell_group_alive = !child_reaped and processGroupAlive(child_pid, own_group);
        if (!child_running and !foreground_alive and !shell_group_alive) break;
        if (shutdown_deadline_ms) |deadline_ms| {
            const current_ms = monotonicMilliseconds() orelse deadline_ms;
            if (current_ms >= deadline_ms) break;
        }
        sleepBrief(10);
        if (child_running)
            child_running = std.c.waitpid(child_pid, &status, std.c.W.NOHANG) == 0;
    }

    foreground_alive = processGroupAlive(foreground, own_group);
    shell_group_alive = !child_reaped and processGroupAlive(child_pid, own_group);
    if (child_running or foreground_alive or shell_group_alive) {
        if (foreground_alive) signalProcess(-foreground, .KILL);
        if (shell_group_alive) signalProcess(-child_pid, .KILL);
        if (child_running) signalProcess(child_pid, .KILL);
    }
    if (child_running) _ = std.c.waitpid(child_pid, &status, 0);
}

pub const Session = struct {
    master_fd: c_int,
    child_pid: c_int,
    closed: bool = false,
    exit_code: ?u8 = null,

    pub fn spawn(cwd: [:0]const u8, shell: [:0]const u8) !Session {
        return spawnPty(.{
            .cwd = cwd,
            .program = shell,
            .kind = .shell,
            .argument = "",
            .environment = "",
        });
    }

    pub fn spawnProfile(options: SpawnOptions) !Session {
        return spawnPty(options);
    }

    pub fn deinit(self: *Session) void {
        if (self.closed) return;
        closePty(self.master_fd, self.child_pid, self.exit_code != null);
        self.master_fd = -1;
        self.closed = true;
    }

    pub fn closeDescriptor(self: *Session) void {
        if (self.master_fd < 0) return;
        _ = std.c.close(self.master_fd);
        self.master_fd = -1;
    }

    pub fn fileDescriptor(self: *const Session) c_int {
        return if (self.closed or self.master_fd < 0) -1 else self.master_fd;
    }

    pub fn processId(self: *const Session) i32 {
        return if (self.closed) 0 else self.child_pid;
    }

    pub fn hasForegroundProcess(self: *const Session) bool {
        if (self.closed or self.child_pid <= 0 or self.master_fd < 0) return false;
        const foreground = tcgetpgrp(self.master_fd);
        return foreground > 0 and foreground != self.child_pid;
    }

    pub fn processInfo(self: *const Session, cwd: []u8, name: []u8) ?ProcessInfo {
        if (self.closed or cwd.len == 0 or name.len == 0) return null;
        const foreground = if (self.master_fd >= 0) tcgetpgrp(self.master_fd) else -1;
        const process_id = if (foreground > 0) foreground else self.child_pid;
        const process_cwd = readProcLink(process_id, "cwd", cwd) orelse
            if (process_id != self.child_pid) readProcLink(self.child_pid, "cwd", cwd) else null;
        const process_name = readProcFile(process_id, "comm", name) orelse
            if (process_id != self.child_pid) readProcFile(self.child_pid, "comm", name) else null;
        if (process_cwd == null and process_name == null) return null;
        return .{
            .process_id = process_id,
            .cwd = process_cwd orelse cwd[0..0],
            .name = process_name orelse name[0..0],
        };
    }

    pub fn read(self: *Session, buffer: []u8) !ReadResult {
        if (self.closed or self.master_fd < 0) return error.PtyClosed;
        const count = std.posix.read(self.master_fd, buffer) catch |err| switch (err) {
            error.WouldBlock => return .would_block,
            error.InputOutput => return .eof,
            else => return error.PtyReadFailed,
        };
        return if (count == 0) .eof else .{ .bytes = count };
    }

    pub fn write(self: *Session, bytes: []const u8) !usize {
        if (self.closed or self.master_fd < 0) return error.PtyClosed;
        const result = std.c.write(self.master_fd, bytes.ptr, bytes.len);
        if (result < 0) return switch (std.posix.errno(result)) {
            .AGAIN => error.PtyWouldBlock,
            else => error.PtyWriteFailed,
        };
        return @intCast(result);
    }

    pub fn writeAll(self: *Session, bytes: []const u8) !void {
        var offset: usize = 0;
        while (offset < bytes.len) {
            const written = self.write(bytes[offset..]) catch |err| switch (err) {
                error.PtyWouldBlock => {
                    sleepBrief(1);
                    continue;
                },
                else => return err,
            };
            offset += written;
        }
    }

    pub fn resize(self: *Session, rows: u16, columns: u16, width_px: u32, height_px: u32) !void {
        if (self.closed or self.master_fd < 0) return error.PtyClosed;
        var size = std.c.winsize{
            .row = rows,
            .col = columns,
            .xpixel = @truncate(width_px),
            .ypixel = @truncate(height_px),
        };
        if (std.c.ioctl(self.master_fd, std.c.T.IOCSWINSZ, &size) != 0) return error.PtyResizeFailed;
    }

    pub fn pollExit(self: *Session) !?u8 {
        if (self.exit_code) |code| return code;
        if (self.closed) return error.PtyClosed;
        var status: c_int = 0;
        const result = std.c.waitpid(self.child_pid, &status, std.c.W.NOHANG);
        if (result < 0) return error.PtyWaitFailed;
        if (result == 0) return null;
        const wait_status: u32 = @bitCast(status);
        self.exit_code = if (std.c.W.IFEXITED(wait_status))
            std.c.W.EXITSTATUS(wait_status)
        else if (std.c.W.IFSIGNALED(wait_status))
            @intCast(128 + @backingInt(std.c.W.TERMSIG(wait_status)))
        else
            255;
        return self.exit_code;
    }
};

test "zig-owned pty spawns shell, routes bytes, resizes, and observes exit" {
    var session = try Session.spawn("/tmp", "/bin/sh");
    defer session.deinit();

    try std.testing.expect(session.fileDescriptor() >= 0);
    const descriptor_flags = std.c.fcntl(session.fileDescriptor(), std.c.F.GETFD);
    try std.testing.expect(descriptor_flags >= 0);
    try std.testing.expect(descriptor_flags & std.c.FD_CLOEXEC != 0);

    try session.resize(24, 80, 800, 480);
    try session.writeAll("printf 'NOCTTY_ZIG_PTY_OK\n'; exit 0\n");

    var output: [4096]u8 = undefined;
    var used: usize = 0;
    var saw_marker = false;
    var saw_exit = false;
    var attempt: usize = 0;
    while (attempt < test_poll_limit and !(saw_exit and saw_marker)) : (attempt += 1) {
        switch (try session.read(output[used..])) {
            .bytes => |count| {
                used += count;
                if (std.mem.indexOf(u8, output[0..used], "NOCTTY_ZIG_PTY_OK") != null) saw_marker = true;
            },
            .would_block => sleepBrief(2),
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

test "zig-owned pty rejects relative executable and working-directory paths" {
    try std.testing.expectError(error.PtySpawnFailed, Session.spawn("relative", "/bin/sh"));
    try std.testing.expectError(error.PtySpawnFailed, Session.spawn("/tmp", "sh"));
}

test "zig-owned pty closes inherited descriptors before exec" {
    const source_fd = std.c.open("/dev/null", std.c.O{ .ACCMODE = .RDONLY });
    try std.testing.expect(source_fd >= 0);
    defer _ = std.c.close(source_fd);
    const inherited_fd = std.c.fcntl(source_fd, std.c.F.DUPFD, @as(c_int, 200));
    try std.testing.expect(inherited_fd >= 200);
    defer _ = std.c.close(inherited_fd);
    try std.testing.expectEqual(
        @as(c_int, 0),
        std.c.fcntl(inherited_fd, std.c.F.SETFD, @as(c_int, 0)),
    );

    var session = try Session.spawn("/tmp", "/bin/sh");
    defer session.deinit();
    var command_buffer: [160]u8 = undefined;
    const command = try std.fmt.bufPrint(
        &command_buffer,
        "if [ -e /proc/self/fd/{d} ]; then printf 'NOCTTY_FD_%s' LEAK; else printf 'NOCTTY_FD_%s' CLEAN; fi; exit 0\n",
        .{inherited_fd},
    );
    try session.writeAll(command);

    var output: [4096]u8 = undefined;
    var used: usize = 0;
    var saw_clean = false;
    var saw_exit = false;
    for (0..test_poll_limit) |_| {
        if (saw_clean and saw_exit) break;
        switch (try session.read(output[used..])) {
            .bytes => |count| {
                used += count;
                saw_clean = std.mem.indexOf(u8, output[0..used], "NOCTTY_FD_CLEAN") != null;
            },
            .would_block => sleepBrief(2),
            // EOF may arrive before waitpid reports the child under host contention.
            .eof => sleepBrief(2),
        }
        if (try session.pollExit()) |code| {
            try std.testing.expectEqual(@as(u8, 0), code);
            saw_exit = true;
        }
    }
    try std.testing.expect(saw_clean);
    try std.testing.expect(saw_exit);
    try std.testing.expect(std.mem.indexOf(u8, output[0..used], "NOCTTY_FD_LEAK") == null);
}

test "PTY child environment excludes one-use startup activation state" {
    var child_environment: ChildEnvironment = undefined;
    try child_environment.init(
        "XDG_ACTIVATION_TOKEN=profile-token;DESKTOP_STARTUP_ID=profile-id;NOCTTY_KEEP=ready",
    );

    var saw_keep = false;
    for (child_environment.entries[0..child_environment.entry_count]) |entry| {
        const text = std.mem.span(entry.?);
        try std.testing.expect(!std.mem.startsWith(u8, text, "XDG_ACTIVATION_TOKEN="));
        try std.testing.expect(!std.mem.startsWith(u8, text, "DESKTOP_STARTUP_ID="));
        if (std.mem.eql(u8, text, "NOCTTY_KEEP=ready")) saw_keep = true;
    }
    try std.testing.expect(saw_keep);
}

test "zig-owned pty advertises the tested terminal capability environment" {
    var session = try Session.spawnProfile(.{
        .cwd = "/tmp",
        .program = "/bin/sh",
        .kind = .shell,
        .argument = "",
        .environment = "NOCTTY_PROFILE_ENV=ready;TERM=wrong;COLORTERM=wrong",
    });
    defer session.deinit();
    try session.writeAll("printf 'NOCTTY_TERM=%s COLORTERM=%s PROFILE=%s\\n' \"$TERM\" \"$COLORTERM\" \"$NOCTTY_PROFILE_ENV\"; exit 0\n");

    var output: [4096]u8 = undefined;
    var used: usize = 0;
    var saw_environment = false;
    var saw_exit = false;
    for (0..test_poll_limit) |_| {
        if (saw_environment and saw_exit) break;
        switch (try session.read(output[used..])) {
            .bytes => |count| {
                used += count;
                saw_environment = std.mem.indexOf(
                    u8,
                    output[0..used],
                    "NOCTTY_TERM=xterm-256color COLORTERM=truecolor PROFILE=ready",
                ) != null;
            },
            .would_block => sleepBrief(2),
            .eof => saw_exit = true,
        }
        if (try session.pollExit()) |code| {
            try std.testing.expectEqual(@as(u8, 0), code);
            saw_exit = true;
        }
    }
    if (!saw_environment) std.debug.print("pty environment output: {s}\n", .{output[0..used]});
    try std.testing.expect(saw_environment);
    try std.testing.expect(saw_exit);
}

test "fixed tool resolution ignores empty and relative PATH entries" {
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    try std.testing.expect(resolveExecutableInPath("sh", ":relative", &buffer) == null);
    try std.testing.expect(resolveExecutableInPath("sh", "/bin:/usr/bin", &buffer) != null);
}

test "zig-owned pty distinguishes the shell from a foreground job" {
    var session = try Session.spawn("/tmp", "/bin/sh");
    defer session.deinit();

    var shell_ready = false;
    for (0..test_poll_limit) |_| {
        if (!session.hasForegroundProcess()) {
            shell_ready = true;
            break;
        }
        sleepBrief(1);
    }
    try std.testing.expect(shell_ready);

    try session.writeAll("sleep 5\n");
    var foreground_seen = false;
    for (0..test_poll_limit) |_| {
        if (session.hasForegroundProcess()) {
            foreground_seen = true;
            break;
        }
        sleepBrief(1);
    }
    try std.testing.expect(foreground_seen);
}

test "zig-owned pty exposes bounded foreground process metadata" {
    var session = try Session.spawn("/tmp", "/bin/sh");
    defer session.deinit();

    var cwd: [4096]u8 = undefined;
    var name: [256]u8 = undefined;
    var shell_ready = false;
    for (0..test_poll_limit) |_| {
        const shell = session.processInfo(&cwd, &name) orelse {
            sleepBrief(1);
            continue;
        };
        if (std.mem.eql(u8, shell.cwd, "/tmp") and shell.name.len > 0) {
            shell_ready = true;
            break;
        }
        sleepBrief(1);
    }
    try std.testing.expect(shell_ready);

    try session.writeAll("sleep 5\n");
    var saw_sleep = false;
    for (0..test_poll_limit) |_| {
        const foreground = session.processInfo(&cwd, &name) orelse {
            sleepBrief(1);
            continue;
        };
        if (std.mem.eql(u8, foreground.name, "sleep")) {
            try std.testing.expect(foreground.process_id > 0);
            try std.testing.expectEqualStrings("/tmp", foreground.cwd);
            saw_sleep = true;
            break;
        }
        sleepBrief(1);
    }
    try std.testing.expect(saw_sleep);
}

test "process resource sample reads the local Linux process tree" {
    const sample = resourceSample(0) orelse return error.ResourceSampleUnavailable;
    try std.testing.expect(sample.processes >= 1);
    try std.testing.expect(sample.rss_kib > 0);
    try std.testing.expect(sample.machine_ticks > 0);
    try std.testing.expect(sample.cpu_count >= 1);
}

test "paired resource sample shares one process walk and machine sample" {
    const pair = resourceSamplePair(std.c.getpid()) orelse
        return error.ResourceSampleUnavailable;
    try std.testing.expectEqual(pair.app.ticks, pair.pane.ticks);
    try std.testing.expectEqual(pair.app.rss_kib, pair.pane.rss_kib);
    try std.testing.expectEqual(pair.app.processes, pair.pane.processes);
    try std.testing.expectEqual(pair.app.machine_ticks, pair.pane.machine_ticks);
    try std.testing.expectEqual(pair.app.cpu_count, pair.pane.cpu_count);
}
