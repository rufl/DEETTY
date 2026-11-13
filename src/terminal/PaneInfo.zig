const std = @import("std");
const Pty = @import("Pty.zig");

pub const Usage = struct {
    app_cpu_tenths: u32 = 0,
    app_rss_kib: u64 = 0,
    app_processes: u32 = 0,
    pane_cpu_tenths: u32 = 0,
    pane_rss_kib: u64 = 0,
    pane_processes: u32 = 0,
};

pub const UsageSampler = struct {
    previous_machine_ticks: u64 = 0,
    previous_app_ticks: u64 = 0,
    previous_pane_ticks: u64 = 0,
    previous_pane_root: i32 = 0,
    last: Usage = .{},

    pub fn sample(self: *UsageSampler, app: Pty.ResourceSample, pane: Pty.ResourceSample, pane_root: i32) Usage {
        const machine_delta = app.machine_ticks -| self.previous_machine_ticks;
        if (self.previous_machine_ticks != 0 and
            pane_root == self.previous_pane_root and
            machine_delta < @as(u64, app.cpu_count) * 20) return self.last;
        const app_cpu = if (self.previous_machine_ticks == 0)
            0
        else
            cpuTenths(
                app.ticks -| self.previous_app_ticks,
                machine_delta,
                app.cpu_count,
            );
        const pane_cpu = if (pane_root == self.previous_pane_root)
            cpuTenths(
                pane.ticks -| self.previous_pane_ticks,
                machine_delta,
                pane.cpu_count,
            )
        else
            0;
        self.previous_machine_ticks = app.machine_ticks;
        self.previous_app_ticks = app.ticks;
        self.previous_pane_ticks = pane.ticks;
        self.previous_pane_root = pane_root;
        self.last = .{
            .app_cpu_tenths = app_cpu,
            .app_rss_kib = app.rss_kib,
            .app_processes = app.processes,
            .pane_cpu_tenths = pane_cpu,
            .pane_rss_kib = pane.rss_kib,
            .pane_processes = pane.processes,
        };
        return self.last;
    }
};

pub const Input = struct {
    pane_id: u64,
    process_id: i32,
    cwd: []const u8,
    process_name: []const u8,
    continuity: []const u8 = "restartable shell",
    usage: Usage = .{},
};

pub const Output = struct {
    display_length: usize,
    tooltip_length: usize,
};

pub fn format(input: Input, display: []u8, tooltip: []u8) !Output {
    const cwd = safeText(input.cwd, "?");
    const process_name = safeText(input.process_name, "shell");
    const short_cwd = shortDirectory(cwd);
    const app_mib_tenths = memoryMiBTenths(input.usage.app_rss_kib);
    const pane_mib_tenths = memoryMiBTenths(input.usage.pane_rss_kib);
    const display_text = try std.fmt.bufPrint(
        display,
        "{s} : {s}  | {s} | App {d}.{d}% {d}.{d}M | Pane {d}.{d}% {d}.{d}M",
        .{
            short_cwd,
            process_name,
            safeText(input.continuity, "restartable shell"),
            input.usage.app_cpu_tenths / 10,
            input.usage.app_cpu_tenths % 10,
            app_mib_tenths / 10,
            app_mib_tenths % 10,
            input.usage.pane_cpu_tenths / 10,
            input.usage.pane_cpu_tenths % 10,
            pane_mib_tenths / 10,
            pane_mib_tenths % 10,
        },
    );
    const tooltip_text = try std.fmt.bufPrint(
        tooltip,
        "Pane {d}\nProcess: {s} (PID {d})\nDirectory: {s}\nContinuity: {s}\nDEETTY tree: {d}.{d}% CPU, {d}.{d} MiB, {d} processes\nSelected terminal tree: {d}.{d}% CPU, {d}.{d} MiB, {d} processes",
        .{
            input.pane_id,
            process_name,
            input.process_id,
            cwd,
            safeText(input.continuity, "restartable shell"),
            input.usage.app_cpu_tenths / 10,
            input.usage.app_cpu_tenths % 10,
            app_mib_tenths / 10,
            app_mib_tenths % 10,
            input.usage.app_processes,
            input.usage.pane_cpu_tenths / 10,
            input.usage.pane_cpu_tenths % 10,
            pane_mib_tenths / 10,
            pane_mib_tenths % 10,
            input.usage.pane_processes,
        },
    );
    return .{
        .display_length = display_text.len,
        .tooltip_length = tooltip_text.len,
    };
}

fn cpuTenths(process_delta: u64, machine_delta: u64, cpu_count: u32) u32 {
    if (machine_delta == 0 or process_delta == 0) return 0;
    const value = @as(u128, process_delta) * @as(u128, cpu_count) * 1000 / machine_delta;
    return @intCast(@min(value, std.math.maxInt(u32)));
}

fn memoryMiBTenths(kib: u64) u64 {
    return (kib *| 10 + 512) / 1024;
}

fn safeText(text: []const u8, fallback: []const u8) []const u8 {
    if (text.len == 0 or !std.unicode.utf8ValidateSlice(text)) return fallback;
    for (text) |byte| {
        if (byte < 0x20 or byte == 0x7f) return fallback;
    }
    return text;
}

fn shortDirectory(cwd: []const u8) []const u8 {
    if (std.mem.eql(u8, cwd, "/")) return cwd;
    const trimmed = std.mem.trimEnd(u8, cwd, "/");
    if (trimmed.len == 0) return "/";
    return std.fs.path.basename(trimmed);
}

test "pane info matches the local Yakuake title shape" {
    var display: [128]u8 = undefined;
    var tooltip: [256]u8 = undefined;
    const output = try format(.{
        .pane_id = 7,
        .process_id = 420,
        .cwd = "/home/alice/project",
        .process_name = "zig",
    }, &display, &tooltip);

    try std.testing.expectEqualStrings(
        "project : zig  | restartable shell | App 0.0% 0.0M | Pane 0.0% 0.0M",
        display[0..output.display_length],
    );
    try std.testing.expectEqualStrings(
        "Pane 7\nProcess: zig (PID 420)\nDirectory: /home/alice/project\nContinuity: restartable shell\nDEETTY tree: 0.0% CPU, 0.0 MiB, 0 processes\nSelected terminal tree: 0.0% CPU, 0.0 MiB, 0 processes",
        tooltip[0..output.tooltip_length],
    );
}

test "pane info handles root and rejects unsafe process metadata" {
    var display: [128]u8 = undefined;
    var tooltip: [256]u8 = undefined;
    const output = try format(.{
        .pane_id = 1,
        .process_id = 9,
        .cwd = "/",
        .process_name = "bad\nname",
    }, &display, &tooltip);

    try std.testing.expectEqualStrings("/ : shell  | restartable shell | App 0.0% 0.0M | Pane 0.0% 0.0M", display[0..output.display_length]);
    try std.testing.expect(std.mem.indexOf(
        u8,
        tooltip[0..output.tooltip_length],
        "Process: shell (PID 9)",
    ) != null);
}

test "pane info calculates process-tree CPU deltas and memory" {
    var sampler = UsageSampler{};
    _ = sampler.sample(
        .{ .ticks = 100, .rss_kib = 10240, .processes = 3, .machine_ticks = 1000, .cpu_count = 4 },
        .{ .ticks = 40, .rss_kib = 2048, .processes = 2, .machine_ticks = 1000, .cpu_count = 4 },
        22,
    );
    const usage = sampler.sample(
        .{ .ticks = 110, .rss_kib = 11264, .processes = 3, .machine_ticks = 1100, .cpu_count = 4 },
        .{ .ticks = 45, .rss_kib = 3072, .processes = 2, .machine_ticks = 1100, .cpu_count = 4 },
        22,
    );
    try std.testing.expectEqual(@as(u32, 400), usage.app_cpu_tenths);
    try std.testing.expectEqual(@as(u32, 200), usage.pane_cpu_tenths);
    try std.testing.expectEqual(@as(u64, 11264), usage.app_rss_kib);
    try std.testing.expectEqual(@as(u64, 3072), usage.pane_rss_kib);
}

test "pane info stays within caller-owned buffers" {
    var display: [4]u8 = undefined;
    var tooltip: [8]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, format(.{
        .pane_id = 1,
        .process_id = 2,
        .cwd = "/tmp",
        .process_name = "sh",
    }, &display, &tooltip));
}
