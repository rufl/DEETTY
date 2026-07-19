const std = @import("std");
const builtin = @import("builtin");
const TerminalSession = @import("Session.zig").TerminalSession;
const Pty = @import("Pty.zig");

const max_normal_cycles: usize = 128;
const max_forced_cycles: usize = 32;
const default_normal_cycles: usize = 64;
const default_forced_cycles: usize = 8;
const normal_readiness_poll_limit: usize = 20_000;
const AccountedAllocator = std.heap.DebugAllocator(.{
    .enable_memory_limit = true,
});

extern fn kill(process_id: c_int, signal: c_int) c_int;

const Samples = struct {
    normal: [max_normal_cycles]u64 = undefined,
    forced: [max_forced_cycles]u64 = undefined,
};

const Summary = struct {
    p50_ns: u64,
    p95_ns: u64,
    p99_ns: u64,
};

const Outcome = struct {
    samples: Samples = .{},
    output_bytes: usize = 0,
    resizes: usize = 0,
    checkpoint_peak_active_bytes: usize = 0,
    grace_exhausted: usize = 0,
    shell_reaped: usize = 0,
    foreground_groups_reaped: usize = 0,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 3) return error.InvalidArguments;
    const normal_cycles = if (args.len >= 2)
        try std.fmt.parseInt(usize, args[1], 10)
    else
        default_normal_cycles;
    const forced_cycles = if (args.len >= 3)
        try std.fmt.parseInt(usize, args[2], 10)
    else
        default_forced_cycles;
    if (normal_cycles == 0 or normal_cycles > max_normal_cycles or
        forced_cycles == 0 or forced_cycles > max_forced_cycles)
        return error.InvalidCycleCount;

    var debug_allocator: AccountedAllocator = .init;
    var outcome = runQualification(
        &debug_allocator,
        init.io,
        normal_cycles,
        forced_cycles,
    ) catch |err| {
        _ = debug_allocator.deinit();
        return err;
    };
    const residual_bytes = debug_allocator.total_requested_bytes;
    const leak_check = debug_allocator.deinit();
    if (residual_bytes != 0 or leak_check != .ok)
        return error.AllocatorAccountingFailed;

    const normal = summarize(outcome.samples.normal[0..normal_cycles]);
    const forced = summarize(outcome.samples.forced[0..forced_cycles]);
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};
    try stdout.print(
        "terminal_session_qualification mode={s} normal_cycles={d} forced_cycles={d} " ++
            "sessions={d} resizes={d} output_bytes={d} allocator_leak_free=true " ++
            "allocator_residual_bytes={d} checkpoint_peak_active_bytes={d} " ++
            "normal_p50_ns={d} normal_p95_ns={d} normal_p99_ns={d} " ++
            "forced_p50_ns={d} forced_p95_ns={d} forced_p99_ns={d} " ++
            "forced_grace_exhausted={d} shell_reaped={d} foreground_groups_reaped={d} " ++
            "process_residual=0 assertions=true\n",
        .{
            @tagName(builtin.mode),
            normal_cycles,
            forced_cycles,
            normal_cycles + forced_cycles,
            outcome.resizes,
            outcome.output_bytes,
            residual_bytes,
            outcome.checkpoint_peak_active_bytes,
            normal.p50_ns,
            normal.p95_ns,
            normal.p99_ns,
            forced.p50_ns,
            forced.p95_ns,
            forced.p99_ns,
            outcome.grace_exhausted,
            outcome.shell_reaped,
            outcome.foreground_groups_reaped,
        },
    );
}

fn runQualification(
    accounting: *AccountedAllocator,
    io: std.Io,
    normal_cycles: usize,
    forced_cycles: usize,
) !Outcome {
    var outcome = Outcome{};
    const baseline = accounting.total_requested_bytes;
    for (0..normal_cycles) |cycle| {
        const started = std.Io.Clock.awake.now(io);
        var session = try TerminalSession.spawnWithHistoryLimit(
            accounting.allocator(),
            "/tmp",
            "/bin/sh",
            80,
            24,
            128,
        );
        defer session.deinit();
        const columns: u16 = @intCast(72 + (cycle % 5) * 8);
        const rows: u16 = @intCast(18 + (cycle % 4) * 2);
        try session.resize(columns + 4, rows + 2, 760, 420);
        try session.resize(columns, rows, 720, 400);
        outcome.resizes += 2;
        recordPeak(&outcome, accounting);
        try session.write(
            "i=0; while [ \"$i\" -lt 32 ]; do " ++
                "printf 'NOCTTY_NORMAL_LINE_%03d\\r\\n' \"$i\"; " ++
                "i=$((i + 1)); done; " ++
                "printf '\\033]2;noctty-normal-ready\\007'; exit 0\n",
        );

        var saw_marker = false;
        var saw_exit = false;
        for (0..normal_readiness_poll_limit) |_| {
            switch (try session.pump()) {
                .bytes => |count| outcome.output_bytes += count,
                .would_block => Pty.sleepBrief(1),
                .eof => {},
            }
            saw_marker = saw_marker or
                std.mem.eql(u8, session.grid.titleSlice(), "noctty-normal-ready");
            if (try session.pollExit()) |code| {
                if (code != 0) return error.NormalChildExitFailed;
                saw_exit = true;
            }
            if (saw_marker and saw_exit) break;
        }
        if (!saw_marker or !saw_exit) return error.NormalSessionTimedOut;
        session.deinit();
        session.deinit();
        if (session.fileDescriptor() != -1) return error.SessionBoundaryStayedOpen;
        outcome.samples.normal[cycle] = elapsedNanoseconds(started, io);
        if (accounting.total_requested_bytes != baseline)
            return error.NormalCycleAllocatorResidual;
    }

    for (0..forced_cycles) |cycle| {
        var session = try TerminalSession.spawnWithHistoryLimit(
            accounting.allocator(),
            "/tmp",
            "/bin/sh",
            80,
            24,
            128,
        );
        defer session.deinit();
        const shell_pid = session.processId();
        if (shell_pid <= 1) return error.InvalidShellProcess;
        recordPeak(&outcome, accounting);
        try session.write(
            "sh -c 'trap \"\" HUP TERM; " ++
                "printf \"\\033]2;noctty-forced-ready\\007\"; " ++
                "while :; do sleep 60; done'\n",
        );

        var foreground_pid: i32 = 0;
        var cwd_buffer: [4096]u8 = undefined;
        var name_buffer: [256]u8 = undefined;
        for (0..5000) |_| {
            switch (try session.pump()) {
                .bytes => |count| outcome.output_bytes += count,
                .would_block => Pty.sleepBrief(1),
                .eof => return error.ForcedChildExitedBeforeShutdown,
            }
            if (std.mem.eql(u8, session.grid.titleSlice(), "noctty-forced-ready") and
                session.hasForegroundProcess())
            {
                if (session.processInfo(&cwd_buffer, &name_buffer)) |info| {
                    if (info.process_id > 1 and info.process_id != shell_pid) {
                        foreground_pid = info.process_id;
                        break;
                    }
                }
            }
            Pty.sleepBrief(1);
        }
        if (foreground_pid <= 1) return error.ForcedForegroundNotReady;

        const shutdown_started = std.Io.Clock.awake.now(io);
        session.deinit();
        const shutdown_ns = elapsedNanoseconds(shutdown_started, io);
        outcome.samples.forced[cycle] = shutdown_ns;
        if (shutdown_ns < 300 * std.time.ns_per_ms)
            return error.ForcedGracePeriodNotExhausted;
        outcome.grace_exhausted += 1;
        if (!waitForProcessGone(shell_pid, false)) return error.ShellProcessResidual;
        outcome.shell_reaped += 1;
        if (!waitForProcessGone(foreground_pid, true))
            return error.ForegroundProcessGroupResidual;
        outcome.foreground_groups_reaped += 1;
        if (accounting.total_requested_bytes != baseline)
            return error.ForcedCycleAllocatorResidual;
    }
    return outcome;
}

fn waitForProcessGone(process_id: i32, group: bool) bool {
    const target = if (group) -process_id else process_id;
    for (0..2000) |_| {
        if (kill(@intCast(target), 0) != 0) return true;
        Pty.sleepBrief(1);
    }
    return kill(@intCast(target), 0) != 0;
}

fn recordPeak(outcome: *Outcome, accounting: *const AccountedAllocator) void {
    outcome.checkpoint_peak_active_bytes = @max(
        outcome.checkpoint_peak_active_bytes,
        accounting.total_requested_bytes,
    );
}

fn elapsedNanoseconds(started: std.Io.Timestamp, io: std.Io) u64 {
    const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return @intCast(@max(elapsed, 0));
}

fn summarize(values: []u64) Summary {
    std.mem.sort(u64, values, {}, std.sort.asc(u64));
    return .{
        .p50_ns = percentile(values, 50),
        .p95_ns = percentile(values, 95),
        .p99_ns = percentile(values, 99),
    };
}

fn percentile(values: []const u64, percent: usize) u64 {
    const rank = (values.len * percent + 99) / 100;
    return values[@max(rank, 1) - 1];
}
