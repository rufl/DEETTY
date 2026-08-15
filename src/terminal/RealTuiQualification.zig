const std = @import("std");
const builtin = @import("builtin");
const LaunchProfile = @import("LaunchProfile.zig");
const Pty = @import("Pty.zig");
const TerminalSession = @import("Session.zig").TerminalSession;
const Vt = @import("Vt.zig");

pub const AccountedAllocator = std.heap.DebugAllocator(.{
    .enable_memory_limit = true,
});

extern fn kill(process_id: c_int, signal: c_int) c_int;

pub const App = enum {
    codex,
    vim,
    btop,
    nano,
    less,
    dialog,
    top,
    watch,
    info,
    whiptail,
    fzf,
    sqlite3,
    glances,
    bash,
    man,
    sftp,
};

pub const Case = struct {
    app: App,
    command: []const u8,
    environment: []const u8,
    input: []const u8,
    expected_exit: u8,
    process_names: []const []const u8,
    markers: []const []const u8,
    settle_polls: usize = 20,
};

pub const Outcome = struct {
    ready_ns: u64,
    exit_ns: u64,
    output_bytes: usize,
    screen_hash: u64,
    nonblank_cells: usize,
    styled_cells: usize,
    truecolor_cells: usize,
    unicode_cells: usize,
    synchronized_output_begins: u64,
    alternate_screen: bool,
    bracketed_paste: bool,
    focus_reporting: bool,
    mouse_reporting: bool,
    sgr_mouse: bool,
    foreground_identity: bool,
    exit_code: u8,
    checkpoint_peak_active_bytes: usize,
};

const ScreenSummary = struct {
    hash: u64 = 14695981039346656037,
    nonblank: usize = 0,
    styled: usize = 0,
    truecolor: usize = 0,
    unicode: usize = 0,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 5) return error.InvalidArguments;
    const scratch = args[1];
    const codex_path = args[2];
    const vim_path = args[3];
    const btop_path = args[4];
    try validatePath(scratch);
    try validatePath(codex_path);
    try validatePath(vim_path);
    try validatePath(btop_path);

    var codex_command_buffer: [1024]u8 = undefined;
    const codex_command = try std.fmt.bufPrint(
        &codex_command_buffer,
        "exec \"{s}\" --no-alt-screen",
        .{codex_path},
    );
    var vim_command_buffer: [1024]u8 = undefined;
    const vim_command = try std.fmt.bufPrint(
        &vim_command_buffer,
        "exec \"{s}\" -Nu NONE -n -i NONE -c 'set noswapfile' \"{s}/vim-fixture.txt\"",
        .{ vim_path, scratch },
    );
    var btop_command_buffer: [1024]u8 = undefined;
    const btop_command = try std.fmt.bufPrint(
        &btop_command_buffer,
        "exec \"{s}\" --force-utf --update 100",
        .{btop_path},
    );

    var codex_environment_buffer: [2048]u8 = undefined;
    const codex_environment = try appEnvironment(
        &codex_environment_buffer,
        scratch,
        "codex",
    );
    var vim_environment_buffer: [2048]u8 = undefined;
    const vim_environment = try appEnvironment(
        &vim_environment_buffer,
        scratch,
        "vim",
    );
    var btop_environment_buffer: [2048]u8 = undefined;
    const btop_environment = try appEnvironment(
        &btop_environment_buffer,
        scratch,
        "btop",
    );

    const codex_markers = [_][]const u8{ "Welcome", "Codex", "Sign in with ChatGPT" };
    const vim_markers = [_][]const u8{"NOCTTY_REAL_TUI_VIM"};
    const btop_markers = [_][]const u8{ "cpu", "mem", "proc" };
    const codex_process_names = [_][]const u8{ "codex", "node-MainThread" };
    const vim_process_names = [_][]const u8{"vim"};
    const btop_process_names = [_][]const u8{"btop"};
    const cases = [_]Case{
        .{
            .app = .codex,
            .command = codex_command,
            .environment = codex_environment,
            .input = "\x03",
            .expected_exit = 0,
            .process_names = &codex_process_names,
            .markers = &codex_markers,
        },
        .{
            .app = .vim,
            .command = vim_command,
            .environment = vim_environment,
            .input = ":q!\r",
            .expected_exit = 0,
            .process_names = &vim_process_names,
            .markers = &vim_markers,
        },
        .{
            .app = .btop,
            .command = btop_command,
            .environment = btop_environment,
            .input = "q",
            .expected_exit = 0,
            .process_names = &btop_process_names,
            .markers = &btop_markers,
        },
    };

    var debug_allocator: AccountedAllocator = .init;
    var outcomes: [cases.len]Outcome = undefined;
    var total_output_bytes: usize = 0;
    var checkpoint_peak_active_bytes: usize = 0;
    for (cases, 0..) |case, index| {
        outcomes[index] = runCase(
            &debug_allocator,
            init.io,
            scratch,
            case,
        ) catch |err| {
            _ = debug_allocator.deinit();
            return err;
        };
        total_output_bytes += outcomes[index].output_bytes;
        checkpoint_peak_active_bytes = @max(
            checkpoint_peak_active_bytes,
            outcomes[index].checkpoint_peak_active_bytes,
        );
    }
    const residual_bytes = debug_allocator.total_requested_bytes;
    const leak_check = debug_allocator.deinit();
    if (residual_bytes != 0 or leak_check != .ok)
        return error.AllocatorAccountingFailed;

    const codex = outcomes[0];
    const vim = outcomes[1];
    const btop = outcomes[2];
    if (codex.synchronized_output_begins == 0 or
        codex.nonblank_cells < 40 or codex.styled_cells == 0 or
        codex.exit_code != 0)
        return error.CodexSurfaceAssertionsFailed;
    if (!vim.alternate_screen or !vim.bracketed_paste or
        !vim.focus_reporting or vim.nonblank_cells == 0 or vim.exit_code != 0)
        return error.VimSurfaceAssertionsFailed;
    if (!btop.alternate_screen or !btop.mouse_reporting or !btop.sgr_mouse or
        btop.truecolor_cells == 0 or btop.unicode_cells == 0 or
        btop.styled_cells == 0 or btop.exit_code != 0)
        return error.BtopSurfaceAssertionsFailed;
    if (!codex.foreground_identity or !vim.foreground_identity or
        !btop.foreground_identity)
        return error.ForegroundIdentityAssertionsFailed;

    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(
        .stdout(),
        init.io,
        &stdout_buffer,
    );
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};
    for (cases, outcomes) |case, outcome| {
        try stdout.print(
            "terminal_real_tui_case mode={s} app={s} ready_ns={d} exit_ns={d} " ++
                "output_bytes={d} screen_hash={d} nonblank_cells={d} " ++
                "styled_cells={d} truecolor_cells={d} unicode_cells={d} " ++
                "sync_begins={d} alternate_screen={} bracketed_paste={} " ++
                "focus_reporting={} mouse_reporting={} sgr_mouse={} " ++
                "foreground_identity={} input_routed=true exit_code={d} " ++
                "process_residual=0 assertions=true\n",
            .{
                @tagName(builtin.mode),
                @tagName(case.app),
                outcome.ready_ns,
                outcome.exit_ns,
                outcome.output_bytes,
                outcome.screen_hash,
                outcome.nonblank_cells,
                outcome.styled_cells,
                outcome.truecolor_cells,
                outcome.unicode_cells,
                outcome.synchronized_output_begins,
                outcome.alternate_screen,
                outcome.bracketed_paste,
                outcome.focus_reporting,
                outcome.mouse_reporting,
                outcome.sgr_mouse,
                outcome.foreground_identity,
                outcome.exit_code,
            },
        );
    }
    try stdout.print(
        "terminal_real_tui_qualification mode={s} applications=3 " ++
            "total_output_bytes={d} checkpoint_peak_active_bytes={d} " ++
            "codex_login_surface=true codex_sync_output=true codex_exit_code=0 " ++
            "vim_fixture=true vim_alternate_screen=true vim_bracketed_paste=true " ++
            "vim_focus_reporting=true vim_exit_code=0 btop_dashboard=true " ++
            "btop_alternate_screen=true btop_mouse=true btop_sgr_mouse=true " ++
            "btop_truecolor=true btop_unicode=true btop_exit_code=0 " ++
            "foreground_identity=true input_routed=true controlled_exit=true " ++
            "allocator_leak_free=true allocator_residual_bytes={d} " ++
            "process_residual=0 assertions=true\n",
        .{
            @tagName(builtin.mode),
            total_output_bytes,
            checkpoint_peak_active_bytes,
            residual_bytes,
        },
    );
}

pub fn runCase(
    accounting: *AccountedAllocator,
    io: std.Io,
    scratch: []const u8,
    case: Case,
) !Outcome {
    const baseline = accounting.total_requested_bytes;
    var profile = LaunchProfile.Profile{ .kind = .command };
    try profile.shell.set("/bin/sh");
    try profile.command.set(case.command);
    try profile.working_directory.set(scratch);
    try profile.environment.set(case.environment);
    profile.scrollback_lines = 2000;
    var session = try TerminalSession.spawnProfile(
        accounting.allocator(),
        &profile,
        scratch,
        "/bin/sh",
        120,
        40,
    );
    defer session.deinit();
    const process_id = session.processId();
    if (process_id <= 1) return error.InvalidTuiProcess;
    const checkpoint_peak_active_bytes = accounting.total_requested_bytes;
    const started = std.Io.Clock.awake.now(io);
    var output_bytes: usize = 0;
    var ready = false;
    for (0..20_000) |_| {
        switch (try session.pump()) {
            .bytes => |count| output_bytes += count,
            .would_block => Pty.sleepBrief(1),
            .eof => {
                std.debug.print("tui_exited_before_ready app={s}\n", .{
                    @tagName(case.app),
                });
                return error.TuiExitedBeforeReady;
            },
        }
        if (allMarkersPresent(session.grid, case.markers)) {
            ready = true;
            break;
        }
    }
    if (!ready) {
        std.debug.print("tui_ready_timeout app={s}\n", .{@tagName(case.app)});
        var row_bytes: [256]u8 = undefined;
        if (session.grid.columns <= row_bytes.len) {
            for (0..session.grid.rows) |row| {
                for (0..session.grid.columns) |column| {
                    const codepoint = session.grid.cell(column, row).codepoint;
                    row_bytes[column] = if (codepoint >= 0x20 and codepoint <= 0x7e)
                        @intCast(codepoint)
                    else
                        ' ';
                }
                std.debug.print("tui_screen app={s} row={d} text={s}\n", .{
                    @tagName(case.app),
                    row,
                    row_bytes[0..session.grid.columns],
                });
            }
        }
        return error.TuiReadyTimedOut;
    }
    for (0..case.settle_polls) |_| {
        switch (try session.pump()) {
            .bytes => |count| output_bytes += count,
            .would_block => Pty.sleepBrief(1),
            .eof => break,
        }
    }
    const ready_ns = elapsedNanoseconds(started, io);
    const screen = summarizeScreen(session.grid);
    var cwd_buffer: [4096]u8 = undefined;
    var name_buffer: [256]u8 = undefined;
    const foreground_identity = if (session.processInfo(
        &cwd_buffer,
        &name_buffer,
    )) |info| identity: {
        for (case.process_names) |process_name| {
            if (std.ascii.indexOfIgnoreCase(info.name, process_name) != null)
                break :identity true;
        }
        break :identity false;
    } else false;
    const synchronized_output_begins = session.grid.synchronized_output_begins;
    const alternate_screen = session.grid.alternate_cells != null;
    const bracketed_paste = session.grid.bracketed_paste;
    const focus_reporting = session.grid.focus_reporting;
    const mouse_reporting = session.grid.mouse_tracking != .none;
    const sgr_mouse = session.grid.mouse_encoding == .sgr;

    const exit_started = std.Io.Clock.awake.now(io);
    try session.write(case.input);
    var exit_code: ?u8 = null;
    for (0..10_000) |_| {
        switch (try session.pump()) {
            .bytes => |count| output_bytes += count,
            .would_block => Pty.sleepBrief(1),
            .eof => {},
        }
        if (try session.pollExit()) |code| {
            exit_code = code;
            break;
        }
    }
    const code = exit_code orelse return error.TuiExitTimedOut;
    if (code != case.expected_exit) {
        std.debug.print("tui_exit_mismatch app={s} expected={d} actual={d}\n", .{
            @tagName(case.app),
            case.expected_exit,
            code,
        });
        return error.UnexpectedTuiExitCode;
    }
    const exit_ns = elapsedNanoseconds(exit_started, io);
    session.deinit();
    if (!waitForProcessGone(process_id)) return error.TuiProcessResidual;
    if (accounting.total_requested_bytes != baseline)
        return error.TuiAllocatorResidual;
    return .{
        .ready_ns = ready_ns,
        .exit_ns = exit_ns,
        .output_bytes = output_bytes,
        .screen_hash = screen.hash,
        .nonblank_cells = screen.nonblank,
        .styled_cells = screen.styled,
        .truecolor_cells = screen.truecolor,
        .unicode_cells = screen.unicode,
        .synchronized_output_begins = synchronized_output_begins,
        .alternate_screen = alternate_screen,
        .bracketed_paste = bracketed_paste,
        .focus_reporting = focus_reporting,
        .mouse_reporting = mouse_reporting,
        .sgr_mouse = sgr_mouse,
        .foreground_identity = foreground_identity,
        .exit_code = code,
        .checkpoint_peak_active_bytes = checkpoint_peak_active_bytes,
    };
}

pub fn appEnvironment(
    buffer: []u8,
    scratch: []const u8,
    app: []const u8,
) ![]const u8 {
    return std.fmt.bufPrint(
        buffer,
        "HOME={s}/{s}-home;CODEX_HOME={s}/{s}-codex;" ++
            "XDG_CONFIG_HOME={s}/{s}-config;XDG_STATE_HOME={s}/{s}-state;" ++
            "XDG_CACHE_HOME={s}/{s}-cache;TMPDIR={s}/{s}-cache",
        .{
            scratch,
            app,
            scratch,
            app,
            scratch,
            app,
            scratch,
            app,
            scratch,
            app,
            scratch,
            app,
        },
    );
}

pub fn validatePath(path: []const u8) !void {
    if (!std.fs.path.isAbsolute(path) or path.len == 0)
        return error.InvalidQualificationPath;
    for (path) |byte| {
        if (!(std.ascii.isAlphanumeric(byte) or byte == '/' or byte == '.' or
            byte == '_' or byte == '-'))
            return error.InvalidQualificationPath;
    }
}

fn allMarkersPresent(grid: Vt.Grid, markers: []const []const u8) bool {
    for (markers) |marker| {
        if (!gridContainsIgnoreCase(grid, marker)) return false;
    }
    return true;
}

fn gridContainsIgnoreCase(grid: Vt.Grid, marker: []const u8) bool {
    var row_bytes: [256]u8 = undefined;
    if (grid.columns > row_bytes.len) return false;
    for (0..grid.rows) |row| {
        for (0..grid.columns) |column| {
            const codepoint = grid.cell(column, row).codepoint;
            row_bytes[column] = if (codepoint <= 0x7f)
                std.ascii.toLower(@intCast(codepoint))
            else
                '?';
        }
        var marker_lower: [128]u8 = undefined;
        if (marker.len > marker_lower.len) return false;
        for (marker, 0..) |byte, index|
            marker_lower[index] = std.ascii.toLower(byte);
        if (std.mem.indexOf(
            u8,
            row_bytes[0..grid.columns],
            marker_lower[0..marker.len],
        ) != null) return true;
    }
    return false;
}

fn summarizeScreen(grid: Vt.Grid) ScreenSummary {
    var summary = ScreenSummary{};
    for (0..grid.rows) |row| {
        for (0..grid.columns) |column| {
            const cell = grid.cell(column, row);
            summary.hash = (summary.hash ^ grid.packedCell(column, row)) *%
                1099511628211;
            if (cell.codepoint != ' ' and cell.codepoint != 0)
                summary.nonblank += 1;
            if (cell.flags.bold or cell.flags.inverse or cell.flags.italic or
                cell.flags.underline or cell.flags.strikethrough or cell.flags.dim or
                cell.foreground != Vt.default_color_id or
                cell.background != Vt.default_color_id)
                summary.styled += 1;
            if ((cell.foreground >= Vt.first_truecolor_id and
                cell.foreground < Vt.default_color_id) or
                (cell.background >= Vt.first_truecolor_id and
                    cell.background < Vt.default_color_id))
                summary.truecolor += 1;
            if (cell.codepoint > 0x7f) summary.unicode += 1;
        }
    }
    return summary;
}

fn waitForProcessGone(process_id: i32) bool {
    for (0..2000) |_| {
        if (kill(@intCast(process_id), 0) != 0) return true;
        Pty.sleepBrief(1);
    }
    return kill(@intCast(process_id), 0) != 0;
}

fn elapsedNanoseconds(started: std.Io.Timestamp, io: std.Io) u64 {
    const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return @intCast(@max(elapsed, 0));
}
