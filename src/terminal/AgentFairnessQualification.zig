const std = @import("std");
const builtin = @import("builtin");
const Pty = @import("Pty.zig");
const TerminalSession = @import("Session.zig").TerminalSession;

const pane_count: usize = 30;
const marker_count: usize = pane_count - 1;
const flood_warm_bytes: usize = 256 * 1024;
const paste_bytes: usize = 8 * 1024 * 1024;
const deadline_us: i64 = 60 * std.time.us_per_s;
const g_io_in: c_uint = 1;
const g_io_err: c_uint = 8;
const g_io_hup: c_uint = 16;
const source_remove: c_int = 0;
const source_continue: c_int = 1;

extern fn g_unix_fd_add_full(
    priority: c_int,
    file_descriptor: c_int,
    condition: c_uint,
    callback: *const fn (c_int, c_uint, ?*anyopaque) callconv(.c) c_int,
    user_data: ?*anyopaque,
    notify: ?*const fn (?*anyopaque) callconv(.c) void,
) c_uint;
extern fn g_main_context_iteration(context: ?*anyopaque, may_block: c_int) c_int;
extern fn g_source_remove(source_id: c_uint) c_int;
extern fn g_get_monotonic_time() i64;
extern fn kill(process_id: c_int, signal: c_int) c_int;

const AccountedAllocator = std.heap.DebugAllocator(.{
    .enable_memory_limit = true,
});

const SlotKind = enum {
    flood,
    marker,
};

const Slot = struct {
    session: TerminalSession = undefined,
    kind: SlotKind = .marker,
    source_id: c_uint = 0,
    marker: [32]u8 = undefined,
    marker_len: usize = 0,
    started_us: i64 = 0,
    seen_us: i64 = 0,
    output_bytes: usize = 0,
    initialized: bool = false,
    failed: bool = false,
};

const FairnessResult = struct {
    flood_bytes: usize,
    marker_p50_ns: u64,
    marker_p95_ns: u64,
    marker_p99_ns: u64,
    marker_max_ns: u64,
};

const PasteResult = struct {
    enqueue_ns: u64,
    drain_ns: u64,
    teardown_ns: u64,
};

pub fn main(init: std.process.Init) !void {
    var debug_allocator: AccountedAllocator = .init;
    const fairness = runFairness(debug_allocator.allocator()) catch |err| {
        _ = debug_allocator.deinit();
        return err;
    };
    const paste = runLargePaste(debug_allocator.allocator()) catch |err| {
        _ = debug_allocator.deinit();
        return err;
    };
    const residual_bytes = debug_allocator.total_requested_bytes;
    const leak_check = debug_allocator.deinit();
    if (residual_bytes != 0 or leak_check != .ok) {
        return error.AllocatorAccountingFailed;
    }

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(
        .stdout(),
        init.io,
        &stdout_buffer,
    );
    const stdout = &stdout_file_writer.interface;
    try stdout.print(
        "terminal_agent_fairness_qualification mode={s} panes={d} " ++
            "flood_panes=1 marker_panes={d} flood_bytes={d} " ++
            "marker_p50_ns={d} marker_p95_ns={d} marker_p99_ns={d} " ++
            "marker_max_ns={d} all_markers=true shared_pump_scratch=true " ++
            "glib_fd_sources=true large_paste_bytes={d} paste_enqueue_ns={d} " ++
            "paste_drain_ns={d} paste_queue_exercised=true " ++
            "paste_pending_teardown=true paste_teardown_ns={d} " ++
            "allocator_leak_free=true allocator_residual_bytes={d} " ++
            "process_residual=0 assertions=true\n",
        .{
            @tagName(builtin.mode),
            pane_count,
            marker_count,
            fairness.flood_bytes,
            fairness.marker_p50_ns,
            fairness.marker_p95_ns,
            fairness.marker_p99_ns,
            fairness.marker_max_ns,
            paste_bytes,
            paste.enqueue_ns,
            paste.drain_ns,
            paste.teardown_ns,
            residual_bytes,
        },
    );
    try stdout.flush();
}

fn runFairness(allocator: std.mem.Allocator) !FairnessResult {
    const slots = try allocator.alloc(Slot, pane_count);
    defer allocator.free(slots);
    @memset(slots, .{});

    var pump_scratch = TerminalSession.PumpScratch{};
    var initialized: usize = 0;
    defer cleanupSlots(slots, initialized);

    for (slots, 0..) |*slot, index| {
        slot.session = try TerminalSession.spawnWithHistoryLimitAndScratch(
            allocator,
            "/tmp",
            "/bin/sh",
            80,
            24,
            128,
            &pump_scratch,
        );
        slot.initialized = true;
        initialized += 1;
        slot.kind = if (index == 0) .flood else .marker;
        if (slot.kind == .marker) {
            const marker = try std.fmt.bufPrint(
                &slot.marker,
                "deetty-marker-{d:0>2}",
                .{index},
            );
            slot.marker_len = marker.len;
        }
        slot.source_id = g_unix_fd_add_full(
            0,
            slot.session.fileDescriptor(),
            g_io_in | g_io_err | g_io_hup,
            onPtyReady,
            slot,
            null,
        );
        if (slot.source_id == 0) return error.GLibPtySourceFailed;
    }

    const settle_until_us = g_get_monotonic_time() + 100 * std.time.us_per_ms;
    while (g_get_monotonic_time() < settle_until_us) {
        iterateMainContext();
    }

    try slots[0].session.write("yes 'DEETTY_FAIRNESS_FLOOD_0123456789'\n");
    const warm_deadline_us = g_get_monotonic_time() + deadline_us;
    while (slots[0].output_bytes < flood_warm_bytes) {
        iterateMainContext();
        if (slots[0].failed) return error.FloodPanePumpFailed;
        if (g_get_monotonic_time() >= warm_deadline_us) {
            return error.FloodPaneWarmupTimedOut;
        }
    }

    const flood_bytes_at_marker_start = slots[0].output_bytes;
    for (slots[1..], 1..) |*slot, index| {
        var command_buffer: [96]u8 = undefined;
        const command = try std.fmt.bufPrint(
            &command_buffer,
            "printf '\\033]2;deetty-marker-{d:0>2}\\007'; exit 0\n",
            .{index},
        );
        slot.started_us = g_get_monotonic_time();
        try slot.session.write(command);
    }

    const marker_deadline_us = g_get_monotonic_time() + deadline_us;
    while (countSeenMarkers(slots) < marker_count) {
        iterateMainContext();
        for (slots) |slot| {
            if (slot.failed) return error.FairnessPanePumpFailed;
        }
        if (g_get_monotonic_time() >= marker_deadline_us) {
            return error.MarkerPaneFairnessTimedOut;
        }
    }
    if (slots[0].output_bytes <= flood_bytes_at_marker_start) {
        return error.FloodPaneStoppedDuringMarkers;
    }

    var latencies_ns: [marker_count]u64 = undefined;
    for (slots[1..], 0..) |slot, index| {
        if (slot.seen_us < slot.started_us) return error.InvalidMarkerTiming;
        latencies_ns[index] = @intCast(
            (slot.seen_us - slot.started_us) * std.time.ns_per_us,
        );
    }
    std.mem.sort(u64, &latencies_ns, {}, std.sort.asc(u64));
    const result = FairnessResult{
        .flood_bytes = slots[0].output_bytes,
        .marker_p50_ns = percentile(&latencies_ns, 50),
        .marker_p95_ns = percentile(&latencies_ns, 95),
        .marker_p99_ns = percentile(&latencies_ns, 99),
        .marker_max_ns = latencies_ns[latencies_ns.len - 1],
    };
    if (result.marker_max_ns >= 10 * std.time.ns_per_s) {
        return error.MarkerPaneStarvation;
    }

    var process_ids: [pane_count]i32 = undefined;
    for (slots, 0..) |slot, index| process_ids[index] = slot.session.processId();
    cleanupSlots(slots, initialized);
    initialized = 0;
    for (process_ids) |process_id| {
        if (!waitForProcessGone(process_id)) return error.FairnessProcessResidual;
    }
    return result;
}

fn runLargePaste(allocator: std.mem.Allocator) !PasteResult {
    const input = try allocator.alloc(u8, paste_bytes);
    defer allocator.free(input);
    @memset(input, 'x');

    var session = try TerminalSession.spawn(
        allocator,
        "/tmp",
        "/bin/sh",
        80,
        24,
    );
    var session_open = true;
    defer if (session_open) session.deinit();
    const process_id = session.processId();
    try session.write(
        "stty raw -echo; " ++
            "printf '\\033]2;deetty-paste-ready\\007'; " ++
            "head -c 8388608 >/dev/null; " ++
            "printf '\\033]2;deetty-paste-drained\\007'; exit 0\n",
    );
    try waitForTitle(&session, "deetty-paste-ready");

    const enqueue_started_us = g_get_monotonic_time();
    try session.write(input);
    const enqueue_us = g_get_monotonic_time() - enqueue_started_us;
    if (!session.hasPendingWrites()) return error.PasteQueueNotExercised;
    try waitForTitle(&session, "deetty-paste-drained");
    const drain_us = g_get_monotonic_time() - enqueue_started_us;
    if (session.hasPendingWrites()) return error.PasteQueueDidNotDrain;
    try waitForExit(&session);
    session.deinit();
    session.deinit();
    session_open = false;
    if (session.fileDescriptor() != -1) return error.PasteSessionStayedOpen;
    if (!waitForProcessGone(process_id)) return error.PasteProcessResidual;

    var pending = try TerminalSession.spawn(
        allocator,
        "/tmp",
        "/bin/sh",
        80,
        24,
    );
    var pending_open = true;
    defer if (pending_open) pending.deinit();
    const pending_process_id = pending.processId();
    try pending.write("stty -echo; sleep 60\n");
    try waitForForegroundProcess(&pending);
    try pending.write(input);
    if (!pending.hasPendingWrites()) return error.PendingPasteQueueNotExercised;
    const teardown_started_us = g_get_monotonic_time();
    pending.deinit();
    const teardown_us = g_get_monotonic_time() - teardown_started_us;
    pending_open = false;
    if (pending.fileDescriptor() != -1) return error.PendingPasteSessionStayedOpen;
    if (!waitForProcessGone(pending_process_id)) {
        return error.PendingPasteProcessResidual;
    }
    if (enqueue_us >= std.time.us_per_s) return error.PasteEnqueueLatencyRegression;
    if (drain_us >= deadline_us) return error.PasteDrainTimedOut;
    if (teardown_us >= 2 * std.time.us_per_s) {
        return error.PendingPasteTeardownTimedOut;
    }

    return .{
        .enqueue_ns = @intCast(enqueue_us * std.time.ns_per_us),
        .drain_ns = @intCast(drain_us * std.time.ns_per_us),
        .teardown_ns = @intCast(teardown_us * std.time.ns_per_us),
    };
}

fn onPtyReady(
    _: c_int,
    _: c_uint,
    raw: ?*anyopaque,
) callconv(.c) c_int {
    const slot: *Slot = @ptrCast(@alignCast(raw orelse return source_remove));
    const pumped = slot.session.pump() catch {
        slot.failed = true;
        slot.source_id = 0;
        return source_remove;
    };
    switch (pumped) {
        .bytes => |count| slot.output_bytes += count,
        .would_block => {},
        .eof => {
            slot.source_id = 0;
            return source_remove;
        },
    }
    if (slot.kind == .marker and slot.seen_us == 0 and
        std.mem.eql(
            u8,
            slot.session.grid.titleSlice(),
            slot.marker[0..slot.marker_len],
        ))
    {
        slot.seen_us = g_get_monotonic_time();
        slot.source_id = 0;
        return source_remove;
    }
    return source_continue;
}

fn cleanupSlots(slots: []Slot, initialized: usize) void {
    for (slots[0..initialized]) |*slot| {
        if (slot.source_id != 0) {
            _ = g_source_remove(slot.source_id);
            slot.source_id = 0;
        }
    }
    for (slots[0..initialized]) |*slot| {
        if (slot.initialized) {
            slot.session.deinit();
            slot.initialized = false;
        }
    }
}

fn iterateMainContext() void {
    if (g_main_context_iteration(null, 0) == 0) Pty.sleepBrief(1);
}

fn countSeenMarkers(slots: []const Slot) usize {
    var count: usize = 0;
    for (slots[1..]) |slot| {
        if (slot.seen_us != 0) count += 1;
    }
    return count;
}

fn waitForTitle(session: *TerminalSession, title: []const u8) !void {
    const end_us = g_get_monotonic_time() + deadline_us;
    while (g_get_monotonic_time() < end_us) {
        switch (try session.pump()) {
            .bytes => {},
            .would_block, .eof => Pty.sleepBrief(1),
        }
        if (std.mem.eql(u8, session.grid.titleSlice(), title)) return;
    }
    return error.TerminalTitleTimedOut;
}

fn waitForExit(session: *TerminalSession) !void {
    const end_us = g_get_monotonic_time() + deadline_us;
    while (g_get_monotonic_time() < end_us) {
        _ = try session.pump();
        if (try session.pollExit()) |exit_code| {
            if (exit_code != 0) return error.PasteChildExitFailed;
            return;
        }
        Pty.sleepBrief(1);
    }
    return error.PasteChildExitTimedOut;
}

fn waitForForegroundProcess(session: *TerminalSession) !void {
    const end_us = g_get_monotonic_time() + deadline_us;
    while (g_get_monotonic_time() < end_us) {
        _ = try session.pump();
        if (session.hasForegroundProcess()) return;
        Pty.sleepBrief(1);
    }
    return error.PendingPasteForegroundTimedOut;
}

fn waitForProcessGone(process_id: i32) bool {
    if (process_id <= 1) return false;
    for (0..1000) |_| {
        if (kill(@intCast(process_id), 0) != 0) return true;
        Pty.sleepBrief(1);
    }
    return kill(@intCast(process_id), 0) != 0;
}

fn percentile(values: []const u64, percent: usize) u64 {
    const rank = (values.len * percent + 99) / 100;
    return values[@max(rank, 1) - 1];
}
