const std = @import("std");
const builtin = @import("builtin");
const LaunchProfile = @import("LaunchProfile.zig");
const Pty = @import("Pty.zig");
const TerminalSession = @import("Session.zig").TerminalSession;

const AccountedAllocator = std.heap.DebugAllocator(.{
    .enable_memory_limit = true,
});
const continuity_readiness_poll_limit: usize = 20_000;

const Case = struct {
    kind: LaunchProfile.Kind,
    session_name: []const u8,
    marker: []const u8,
};

const Outcome = struct {
    output_bytes: usize,
    exit_code: u8,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 1) return error.InvalidArguments;

    const cases = [_]Case{
        .{ .kind = .tmux, .session_name = "dintty-tmux", .marker = "DINTTY_CONTINUITY_OK:tmux" },
        .{ .kind = .zellij, .session_name = "dintty-zellij", .marker = "DINTTY_CONTINUITY_OK:zellij" },
    };

    var debug_allocator: AccountedAllocator = .init;
    var total_output_bytes: usize = 0;
    for (cases) |case| {
        const outcome = runCase(debug_allocator.allocator(), case) catch |err| {
            _ = debug_allocator.deinit();
            return err;
        };
        if (outcome.exit_code != 0 or outcome.output_bytes == 0)
            return error.ContinuityCaseFailed;
        total_output_bytes += outcome.output_bytes;
    }
    const residual_bytes = debug_allocator.total_requested_bytes;
    const leak_check = debug_allocator.deinit();
    if (residual_bytes != 0 or leak_check != .ok)
        return error.AllocatorAccountingFailed;

    var stdout_buffer: [2048]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(
        .stdout(),
        init.io,
        &stdout_buffer,
    );
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};
    try stdout.print(
        "launch_continuity_qualification mode={s} kinds=tmux,zellij " ++
            "tmux_argv=true zellij_argv=true create_or_attach=true " ++
            "production_pty=true cwd=true environment=true output_bytes={d} " ++
            "controlled_exit=true allocator_leak_free=true " ++
            "allocator_residual_bytes={d} assertions=true\n",
        .{ @tagName(builtin.mode), total_output_bytes, residual_bytes },
    );
}

fn runCase(allocator: std.mem.Allocator, case: Case) !Outcome {
    var profile = LaunchProfile.Profile{ .kind = case.kind };
    try profile.shell.set("/bin/false");
    try profile.working_directory.set("/tmp");
    try profile.environment.set("DINTTY_CONTINUITY=ready");
    try profile.ssh_target.set(case.session_name);
    profile.scrollback_lines = 64;
    try profile.validate();

    var session = try TerminalSession.spawnProfile(
        allocator,
        &profile,
        "/",
        "/bin/false",
        120,
        8,
    );
    defer session.deinit();
    if (session.grid.history_limit != 64) return error.HistoryLimitMismatch;

    var output_bytes: usize = 0;
    var saw_marker = false;
    var exit_code: ?u8 = null;
    for (0..continuity_readiness_poll_limit) |_| {
        switch (try session.pump()) {
            .bytes => |count| output_bytes += count,
            .would_block => Pty.sleepBrief(1),
            .eof => {},
        }
        saw_marker = saw_marker or gridContains(&session, case.marker);
        if (try session.pollExit()) |code| exit_code = code;
        if (saw_marker and exit_code != null) break;
    }
    if (!saw_marker or exit_code == null) return error.ContinuityMarkerMissing;
    return .{ .output_bytes = output_bytes, .exit_code = exit_code.? };
}

fn gridContains(session: *const TerminalSession, needle: []const u8) bool {
    var row_bytes: [120]u8 = undefined;
    for (0..session.grid.rows) |row| {
        for (0..session.grid.columns) |column| {
            const codepoint = session.grid.cell(column, row).codepoint;
            row_bytes[column] = if (codepoint <= 0x7f) @intCast(codepoint) else '?';
        }
        if (std.mem.indexOf(u8, row_bytes[0..session.grid.columns], needle) != null)
            return true;
    }
    return false;
}
