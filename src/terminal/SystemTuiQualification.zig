const std = @import("std");
const builtin = @import("builtin");
const Support = @import("RealTuiQualification.zig");

const resource_observation_polls: usize = 1000;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 14) return error.InvalidArguments;
    const scratch = args[1];
    const top_path = args[2];
    const watch_path = args[3];
    const info_path = args[4];
    const whiptail_path = args[5];
    const fzf_path = args[6];
    const sqlite_path = args[7];
    const glances_path = args[8];
    const bash_path = args[9];
    const man_path = args[10];
    const less_path = args[11];
    const sftp_path = args[12];
    const sftp_server_path = args[13];
    try Support.validatePath(scratch);
    try Support.validatePath(top_path);
    try Support.validatePath(watch_path);
    try Support.validatePath(info_path);
    try Support.validatePath(whiptail_path);
    try Support.validatePath(fzf_path);
    try Support.validatePath(sqlite_path);
    try Support.validatePath(glances_path);
    try Support.validatePath(bash_path);
    try Support.validatePath(man_path);
    try Support.validatePath(less_path);
    try Support.validatePath(sftp_path);
    try Support.validatePath(sftp_server_path);

    var top_command_buffer: [1024]u8 = undefined;
    const top_command = try std.fmt.bufPrint(
        &top_command_buffer,
        "exec \"{s}\" -d 60 -p \"$$\"",
        .{top_path},
    );
    var watch_command_buffer: [1024]u8 = undefined;
    const watch_command = try std.fmt.bufPrint(
        &watch_command_buffer,
        "exec \"{s}\" -n 60 -t \"printf 'NOCTTY_SYSTEM_WATCH\\nreal procps watch fixture\\n'\"",
        .{watch_path},
    );
    var info_command_buffer: [1024]u8 = undefined;
    const info_command = try std.fmt.bufPrint(
        &info_command_buffer,
        "exec \"{s}\" --file=dir",
        .{info_path},
    );
    var whiptail_command_buffer: [1024]u8 = undefined;
    const whiptail_command = try std.fmt.bufPrint(
        &whiptail_command_buffer,
        "exec \"{s}\" --title NOCTTY_SYSTEM_WHIPTAIL " ++
            "--msgbox 'real newt widget fixture' 8 50",
        .{whiptail_path},
    );
    var fzf_command_buffer: [1024]u8 = undefined;
    const fzf_command = try std.fmt.bufPrint(
        &fzf_command_buffer,
        "exec \"{s}\" --border --prompt='NOCTTY_FZF> ' " ++
            "< \"{s}/fzf-input.txt\"",
        .{ fzf_path, scratch },
    );
    var sqlite_command_buffer: [1024]u8 = undefined;
    const sqlite_command = try std.fmt.bufPrint(
        &sqlite_command_buffer,
        "exec \"{s}\" -interactive ':memory:' " ++
            "-cmd \"select 'NOCTTY_SQLITE_READY';\"",
        .{sqlite_path},
    );
    var glances_command_buffer: [1024]u8 = undefined;
    const glances_command = try std.fmt.bufPrint(
        &glances_command_buffer,
        "exec \"{s}\" --disable-check-update --disable-webui " ++
            "--disable-history --hide-public-info --disable-plugin ip -2 -t 60",
        .{glances_path},
    );
    var bash_command_buffer: [1024]u8 = undefined;
    const bash_command = try std.fmt.bufPrint(
        &bash_command_buffer,
        "exec \"{s}\" --noprofile --rcfile \"{s}/bashrc\" -i",
        .{ bash_path, scratch },
    );
    var man_command_buffer: [1024]u8 = undefined;
    const man_command = try std.fmt.bufPrint(
        &man_command_buffer,
        "exec \"{s}\" --pager=\"{s}\" --local-file " ++
            "\"{s}/noctty-system.1\"",
        .{ man_path, less_path, scratch },
    );
    var sftp_command_buffer: [1024]u8 = undefined;
    const sftp_command = try std.fmt.bufPrint(
        &sftp_command_buffer,
        "exec \"{s}\" -D \"{s}\"",
        .{ sftp_path, sftp_server_path },
    );

    var top_environment_buffer: [2048]u8 = undefined;
    const top_environment = try Support.appEnvironment(
        &top_environment_buffer,
        scratch,
        "top",
    );
    var watch_environment_buffer: [2048]u8 = undefined;
    const watch_environment = try Support.appEnvironment(
        &watch_environment_buffer,
        scratch,
        "watch",
    );
    var info_environment_buffer: [2048]u8 = undefined;
    const info_environment = try Support.appEnvironment(
        &info_environment_buffer,
        scratch,
        "info",
    );
    var whiptail_environment_buffer: [2048]u8 = undefined;
    const whiptail_environment = try Support.appEnvironment(
        &whiptail_environment_buffer,
        scratch,
        "whiptail",
    );
    var fzf_environment_buffer: [2048]u8 = undefined;
    const fzf_environment = try Support.appEnvironment(
        &fzf_environment_buffer,
        scratch,
        "fzf",
    );
    var sqlite_environment_buffer: [2048]u8 = undefined;
    const sqlite_environment = try Support.appEnvironment(
        &sqlite_environment_buffer,
        scratch,
        "sqlite3",
    );
    var glances_environment_buffer: [2048]u8 = undefined;
    const glances_environment = try Support.appEnvironment(
        &glances_environment_buffer,
        scratch,
        "glances",
    );
    var bash_environment_buffer: [2048]u8 = undefined;
    const bash_environment = try Support.appEnvironment(
        &bash_environment_buffer,
        scratch,
        "bash",
    );
    var man_environment_buffer: [2048]u8 = undefined;
    const man_environment = try Support.appEnvironment(
        &man_environment_buffer,
        scratch,
        "man",
    );
    var sftp_environment_buffer: [2048]u8 = undefined;
    const sftp_environment = try Support.appEnvironment(
        &sftp_environment_buffer,
        scratch,
        "sftp",
    );

    const top_markers = [_][]const u8{ "Tasks:", "MiB Mem" };
    const watch_markers = [_][]const u8{"NOCTTY_SYSTEM_WATCH"};
    const info_markers = [_][]const u8{ "File: dir", "Top" };
    const whiptail_markers = [_][]const u8{
        "NOCTTY_SYSTEM_WHIPTAIL",
        "real newt widget fixture",
    };
    const fzf_markers = [_][]const u8{ "NOCTTY_FZF", "NOCTTY_FZF_TARGET" };
    const sqlite_markers = [_][]const u8{ "NOCTTY_SQLITE_READY", "sqlite>" };
    const glances_markers = [_][]const u8{ "CPU", "MEM", "LOAD" };
    const bash_markers = [_][]const u8{ "NOCTTY_BASH_READY", "NOCTTY_BASH>" };
    const man_markers = [_][]const u8{ "NOCTTY-SYSTEM", "NOCTTY_SYSTEM_MAN" };
    const sftp_markers = [_][]const u8{ "Attached to", "sftp>" };
    const top_process_names = [_][]const u8{"top"};
    const watch_process_names = [_][]const u8{"watch"};
    const info_process_names = [_][]const u8{"info"};
    const whiptail_process_names = [_][]const u8{"whiptail"};
    const fzf_process_names = [_][]const u8{"fzf"};
    const sqlite_process_names = [_][]const u8{"sqlite3"};
    const glances_process_names = [_][]const u8{ "glances", "python" };
    const bash_process_names = [_][]const u8{"bash"};
    const man_process_names = [_][]const u8{ "man", "less" };
    const sftp_process_names = [_][]const u8{"sftp"};
    const cases = [_]Support.Case{
        .{
            .app = .top,
            .command = top_command,
            .environment = top_environment,
            .input = "q",
            .expected_exit = 0,
            .process_names = &top_process_names,
            .markers = &top_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .watch,
            .command = watch_command,
            .environment = watch_environment,
            .input = "\x03",
            .expected_exit = 0,
            .process_names = &watch_process_names,
            .markers = &watch_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .info,
            .command = info_command,
            .environment = info_environment,
            .input = "q",
            .expected_exit = 0,
            .process_names = &info_process_names,
            .markers = &info_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .whiptail,
            .command = whiptail_command,
            .environment = whiptail_environment,
            .input = "\r",
            .expected_exit = 0,
            .process_names = &whiptail_process_names,
            .markers = &whiptail_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .fzf,
            .command = fzf_command,
            .environment = fzf_environment,
            .input = "\r",
            .expected_exit = 0,
            .process_names = &fzf_process_names,
            .markers = &fzf_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .sqlite3,
            .command = sqlite_command,
            .environment = sqlite_environment,
            .input = ".quit\r",
            .expected_exit = 0,
            .process_names = &sqlite_process_names,
            .markers = &sqlite_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .glances,
            .command = glances_command,
            .environment = glances_environment,
            .input = "q",
            .expected_exit = 0,
            .process_names = &glances_process_names,
            .markers = &glances_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .bash,
            .command = bash_command,
            .environment = bash_environment,
            .input = "printf 'NOCTTY_BASH_COMMAND_OK\\n'\rexit\r",
            .expected_exit = 0,
            .process_names = &bash_process_names,
            .markers = &bash_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .man,
            .command = man_command,
            .environment = man_environment,
            .input = "q",
            .expected_exit = 0,
            .process_names = &man_process_names,
            .markers = &man_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .sftp,
            .command = sftp_command,
            .environment = sftp_environment,
            .input = "pwd\rquit\r",
            .expected_exit = 0,
            .process_names = &sftp_process_names,
            .markers = &sftp_markers,
            .settle_polls = resource_observation_polls,
        },
    };

    var debug_allocator: Support.AccountedAllocator = .init;
    var outcomes: [cases.len]Support.Outcome = undefined;
    var total_output_bytes: usize = 0;
    var checkpoint_peak_active_bytes: usize = 0;
    for (cases, 0..) |case, index| {
        outcomes[index] = Support.runCase(
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

    for (outcomes, 0..) |outcome, index| {
        if (!outcome.foreground_identity or outcome.nonblank_cells == 0) {
            std.debug.print(
                "system_tui_assertion app={s} foreground_identity={} nonblank_cells={d} styled_cells={d} exit_code={d}\n",
                .{
                    @tagName(cases[index].app),
                    outcome.foreground_identity,
                    outcome.nonblank_cells,
                    outcome.styled_cells,
                    outcome.exit_code,
                },
            );
            return error.SystemTuiSurfaceAssertionsFailed;
        }
    }
    const top = outcomes[0];
    const watch = outcomes[1];
    const info = outcomes[2];
    const whiptail = outcomes[3];
    const fzf = outcomes[4];
    const sqlite = outcomes[5];
    const glances = outcomes[6];
    const bash = outcomes[7];
    const man = outcomes[8];
    const sftp = outcomes[9];
    if (top.styled_cells == 0 or watch.styled_cells != 0 or
        info.styled_cells == 0 or whiptail.styled_cells == 0 or
        fzf.styled_cells == 0 or sqlite.styled_cells != 0 or
        glances.styled_cells == 0 or bash.styled_cells != 0 or
        man.styled_cells == 0 or sftp.styled_cells != 0)
        return error.SystemTuiStyleAssertionsFailed;
    if (!bash.bracketed_paste or bash.alternate_screen or
        !man.alternate_screen or sftp.alternate_screen)
        return error.SystemTuiModeAssertionsFailed;

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
            "terminal_system_tui_case mode={s} app={s} ready_ns={d} " ++
                "exit_ns={d} output_bytes={d} screen_hash={d} " ++
                "nonblank_cells={d} styled_cells={d} unicode_cells={d} " ++
                "alternate_screen={} bracketed_paste={} mouse_reporting={} " ++
                "sgr_mouse={} foreground_identity={} input_routed=true " ++
                "exit_code={d} process_residual=0 assertions=true\n",
            .{
                @tagName(builtin.mode),
                @tagName(case.app),
                outcome.ready_ns,
                outcome.exit_ns,
                outcome.output_bytes,
                outcome.screen_hash,
                outcome.nonblank_cells,
                outcome.styled_cells,
                outcome.unicode_cells,
                outcome.alternate_screen,
                outcome.bracketed_paste,
                outcome.mouse_reporting,
                outcome.sgr_mouse,
                outcome.foreground_identity,
                outcome.exit_code,
            },
        );
    }
    try stdout.print(
        "terminal_system_tui_qualification mode={s} applications=10 " ++
            "total_output_bytes={d} checkpoint_peak_active_bytes={d} " ++
            "top_monitor=true watch_refresh=true watch_plain_surface=true " ++
            "info_browser=true " ++
            "whiptail_widget=true fzf_filter=true sqlite_repl=true " ++
            "glances_monitor=true bash_shell=true bash_readline=true " ++
            "man_pager=true pager_chain=true sftp_client=true " ++
            "sftp_local_server=true network_bind=false rich_style=true " ++
            "plain_repl=true " ++
            "foreground_identity=true " ++
            "input_routed=true controlled_exit=true allocator_leak_free=true " ++
            "allocator_residual_bytes={d} process_residual=0 assertions=true\n",
        .{
            @tagName(builtin.mode),
            total_output_bytes,
            checkpoint_peak_active_bytes,
            residual_bytes,
        },
    );
}
