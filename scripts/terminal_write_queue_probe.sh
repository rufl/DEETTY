#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
probe="$repo_root/.terminal_write_queue_probe.$$.zig"
trap 'rm -f "$probe"' EXIT HUP INT TERM

cat >"$probe" <<'ZIG'
const std = @import("std");
const Pty = @import("src/terminal/Pty.zig");
const TerminalSession = @import("src/terminal/Session.zig").TerminalSession;

const input_bytes = 8 * 1024 * 1024;

fn nowNs() !i128 {
    var value: std.c.timespec = undefined;
    if (std.c.clock_gettime(.MONOTONIC, &value) != 0) return error.ClockFailed;
    return @as(i128, value.sec) * std.time.ns_per_s + value.nsec;
}

fn elapsedMs(start_ns: i128) !f64 {
    return @as(f64, @floatFromInt(try nowNs() - start_ns)) / std.time.ns_per_ms;
}

pub fn main() !void {
    const input = try std.heap.page_allocator.alloc(u8, input_bytes);
    defer std.heap.page_allocator.free(input);
    @memset(input, 'x');

    var blocking = try Pty.Session.spawn("/tmp", "/bin/sh");
    try blocking.writeAll("sleep 2\n");
    Pty.sleepBrief(50);
    const blocking_start_ns = try nowNs();
    try blocking.writeAll(input);
    const blocking_ms = try elapsedMs(blocking_start_ns);
    blocking.deinit();

    var queued = try TerminalSession.spawn(
        std.heap.page_allocator,
        "/tmp",
        "/bin/sh",
        40,
        4,
    );
    defer queued.deinit();
    try queued.write("sleep 2\n");
    Pty.sleepBrief(50);
    const queued_start_ns = try nowNs();
    try queued.write(input);
    const queued_ms = try elapsedMs(queued_start_ns);
    if (!queued.hasPendingWrites()) return error.WriteQueueNotExercised;
    if (blocking_ms < 50 or queued_ms * 10 >= blocking_ms)
        return error.WriteQueueLatencyRegression;

    std.debug.print(
        "terminal_write_queue_probe bytes={d} blocking_ms={d:.3} " ++
            "queued_ms={d:.3} speedup={d:.1}x pending=true passed=true\n",
        .{ input.len, blocking_ms, queued_ms, blocking_ms / queued_ms },
    );
}
ZIG

cd "$repo_root"
zig run "$probe" -lc
