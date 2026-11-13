const std = @import("std");
const builtin = @import("builtin");
const Support = @import("RealTuiQualification.zig");
const resource_observation_polls: usize = 1000;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 5) return error.InvalidArguments;
    const scratch = args[1];
    const nano_path = args[2];
    const less_path = args[3];
    const dialog_path = args[4];
    try Support.validatePath(scratch);
    try Support.validatePath(nano_path);
    try Support.validatePath(less_path);
    try Support.validatePath(dialog_path);

    var nano_command_buffer: [1024]u8 = undefined;
    const nano_command = try std.fmt.bufPrint(
        &nano_command_buffer,
        "exec \"{s}\" -I -m -v \"{s}/nano-fixture.txt\"",
        .{ nano_path, scratch },
    );
    var less_command_buffer: [1024]u8 = undefined;
    const less_command = try std.fmt.bufPrint(
        &less_command_buffer,
        "LESS=R; export LESS; exec \"{s}\" -R \"{s}/less-fixture.txt\"",
        .{ less_path, scratch },
    );
    var dialog_command_buffer: [1024]u8 = undefined;
    const dialog_command = try std.fmt.bufPrint(
        &dialog_command_buffer,
        "exec \"{s}\" --clear --title DINTTY_NCURSES_DIALOG " ++
            "--msgbox 'real ncurses dialog fixture' 8 50",
        .{dialog_path},
    );

    var nano_environment_buffer: [2048]u8 = undefined;
    const nano_environment = try Support.appEnvironment(
        &nano_environment_buffer,
        scratch,
        "nano",
    );
    var less_environment_buffer: [2048]u8 = undefined;
    const less_environment = try Support.appEnvironment(
        &less_environment_buffer,
        scratch,
        "less",
    );
    var dialog_environment_buffer: [2048]u8 = undefined;
    const dialog_environment = try Support.appEnvironment(
        &dialog_environment_buffer,
        scratch,
        "dialog",
    );

    const nano_markers = [_][]const u8{ "DINTTY_NCURSES_NANO", "Write Out" };
    const less_markers = [_][]const u8{"DINTTY_NCURSES_LESS"};
    const dialog_markers = [_][]const u8{
        "DINTTY_NCURSES_DIALOG",
        "real ncurses dialog fixture",
    };
    const nano_process_names = [_][]const u8{"nano"};
    const less_process_names = [_][]const u8{"less"};
    const dialog_process_names = [_][]const u8{"dialog"};
    const cases = [_]Support.Case{
        .{
            .app = .nano,
            .command = nano_command,
            .environment = nano_environment,
            .input = "\x18",
            .expected_exit = 0,
            .process_names = &nano_process_names,
            .markers = &nano_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .less,
            .command = less_command,
            .environment = less_environment,
            .input = "q",
            .expected_exit = 0,
            .process_names = &less_process_names,
            .markers = &less_markers,
            .settle_polls = resource_observation_polls,
        },
        .{
            .app = .dialog,
            .command = dialog_command,
            .environment = dialog_environment,
            .input = "\r",
            .expected_exit = 0,
            .process_names = &dialog_process_names,
            .markers = &dialog_markers,
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

    const nano = outcomes[0];
    const less = outcomes[1];
    const dialog = outcomes[2];
    for (outcomes, 0..) |outcome, index| {
        if (!outcome.foreground_identity or outcome.nonblank_cells == 0 or
            outcome.styled_cells == 0 or
            outcome.exit_code != 0)
        {
            std.debug.print(
                "ncurses_assertion app={s} foreground_identity={} alternate_screen={} nonblank_cells={d} styled_cells={d} exit_code={d}\n",
                .{
                    @tagName(cases[index].app),
                    outcome.foreground_identity,
                    outcome.alternate_screen,
                    outcome.nonblank_cells,
                    outcome.styled_cells,
                    outcome.exit_code,
                },
            );
            return error.NcursesSurfaceAssertionsFailed;
        }
    }
    if (!nano.alternate_screen or !less.alternate_screen or
        dialog.alternate_screen)
        return error.NcursesScreenModeAssertionsFailed;

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
            "terminal_ncurses_case mode={s} app={s} ready_ns={d} exit_ns={d} " ++
                "output_bytes={d} screen_hash={d} nonblank_cells={d} " ++
                "styled_cells={d} unicode_cells={d} alternate_screen={} " ++
                "bracketed_paste={} mouse_reporting={} sgr_mouse={} " ++
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
        "terminal_ncurses_qualification mode={s} applications=3 " ++
            "total_output_bytes={d} checkpoint_peak_active_bytes={d} " ++
            "nano_editor=true nano_alternate_screen={} nano_mouse={} " ++
            "less_pager=true less_alternate_screen={} " ++
            "dialog_widget=true dialog_alternate_screen={} " ++
            "rich_style=true foreground_identity=true input_routed=true " ++
            "controlled_exit=true allocator_leak_free=true " ++
            "allocator_residual_bytes={d} process_residual=0 assertions=true\n",
        .{
            @tagName(builtin.mode),
            total_output_bytes,
            checkpoint_peak_active_bytes,
            nano.alternate_screen,
            nano.mouse_reporting,
            less.alternate_screen,
            dialog.alternate_screen,
            residual_bytes,
        },
    );
}
