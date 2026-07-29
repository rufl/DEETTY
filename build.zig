const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    if (builtin.zig_version.major != 0 or builtin.zig_version.minor < 16) {
        std.debug.panic(
            "NOCTTY requires Zig 0.16.x or newer (found {d}.{d}.{d}).",
            .{ builtin.zig_version.major, builtin.zig_version.minor, builtin.zig_version.patch },
        );
    }

    var target = b.standardTargetOptions(.{});
    if (target.query.isNative() and builtin.target.os.tag == .linux) {
        // Zig 0.16's linker cannot read newer distro CRT .sframe relocations.
        // Keep the host OS/libc native while avoiding host-specific CPU instructions.
        target = b.resolveTargetQuery(.{ .cpu_model = .baseline });
        b.addSearchPrefix("/usr");
    }
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Strip debug and symbol sections from packaged binaries") orelse false;

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    const runtime_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    const legacy_root_options = b.addOptions();
    legacy_root_options.addOption(bool, "enable_legacy_editor", true);
    root_mod.addOptions("noctty_build_options", legacy_root_options);
    const runtime_root_options = b.addOptions();
    runtime_root_options.addOption(bool, "enable_legacy_editor", false);
    runtime_mod.addOptions("noctty_build_options", runtime_root_options);

    const nocted_core_mod = b.createModule(.{
        .root_source_file = b.path("src/nocted/root.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    const release_mod = b.createModule(.{
        .root_source_file = b.path("src/release.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tree_sitter_mod = b.createModule(.{
        .root_source_file = b.path("src/TreeSitter.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    addTreeSitterSources(b, tree_sitter_mod);
    const ghostty_vt_public_mod = b.createModule(.{
        .root_source_file = b.path("src/ghostty/VtPublic.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    const vte_host_test_mod = b.createModule(.{
        .root_source_file = b.path("src/gui/VteHost.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });

    root_mod.addImport("tree_sitter", tree_sitter_mod);
    root_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    runtime_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    const runtime_options = b.addOptions();
    runtime_options.addOption(bool, "enable_smoke", false);
    runtime_options.addOption(bool, "enable_vte", false);
    runtime_options.addOption(bool, "enable_legacy_editor", false);
    exe_mod.addOptions("build_options", runtime_options);
    exe_mod.addImport("noctty", runtime_mod);
    addNativeGridSources(b, exe_mod, false);
    exe_mod.linkSystemLibrary("gtk+-3.0", .{ .use_pkg_config = .force });
    exe_mod.linkSystemLibrary("dl", .{});

    const exe = b.addExecutable(.{
        .name = "noctty",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const nocted_mod = b.createModule(.{
        .root_source_file = b.path("src/nocted/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    const nocted_runtime_options = b.addOptions();
    nocted_runtime_options.addOption(bool, "enable_smoke", false);
    nocted_mod.addOptions("build_options", nocted_runtime_options);
    nocted_mod.addImport("nocted_core", nocted_core_mod);
    nocted_mod.addImport("noctty_release", release_mod);
    nocted_mod.addImport("tree_sitter", tree_sitter_mod);
    nocted_mod.linkSystemLibrary("gtk+-3.0", .{ .use_pkg_config = .force });
    nocted_mod.linkSystemLibrary("gtksourceview-4", .{ .use_pkg_config = .force });
    const nocted_exe = b.addExecutable(.{
        .name = "nocted",
        .root_module = nocted_mod,
    });
    b.installArtifact(nocted_exe);

    const vte_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    const vte_options = b.addOptions();
    vte_options.addOption(bool, "enable_smoke", false);
    vte_options.addOption(bool, "enable_vte", true);
    vte_options.addOption(bool, "enable_legacy_editor", false);
    vte_mod.addOptions("build_options", vte_options);
    vte_mod.addImport("noctty", runtime_mod);
    addNativeGridSources(b, vte_mod, false);
    vte_mod.linkSystemLibrary("gtk+-3.0", .{ .use_pkg_config = .force });
    vte_mod.linkSystemLibrary("vte-2.91", .{ .use_pkg_config = .force });
    vte_mod.linkSystemLibrary("dl", .{});
    const vte_exe = b.addExecutable(.{
        .name = "noctty-vte",
        .root_module = vte_mod,
    });
    const install_vte = b.addInstallArtifact(vte_exe, .{});
    const vte_step = b.step("vte-fallback", "Build the optional VTE fallback binary");
    vte_step.dependOn(&install_vte.step);
    if (b.option(bool, "with-vte", "Install the optional noctty-vte fallback") orelse false)
        b.getInstallStep().dependOn(&install_vte.step);

    const smoke_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    const smoke_options = b.addOptions();
    smoke_options.addOption(bool, "enable_smoke", true);
    smoke_options.addOption(bool, "enable_vte", true);
    smoke_options.addOption(bool, "enable_legacy_editor", true);
    smoke_mod.addOptions("build_options", smoke_options);
    smoke_mod.addImport("noctty", root_mod);
    addNativeGridSources(b, smoke_mod, true);
    smoke_mod.linkSystemLibrary("gtk+-3.0", .{ .use_pkg_config = .force });
    smoke_mod.linkSystemLibrary("vte-2.91", .{ .use_pkg_config = .force });
    smoke_mod.linkSystemLibrary("dl", .{});
    const smoke_exe = b.addExecutable(.{
        .name = "noctty-smoke",
        .root_module = smoke_mod,
    });

    const nocted_smoke_mod = b.createModule(.{
        .root_source_file = b.path("src/nocted/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    const nocted_smoke_options = b.addOptions();
    nocted_smoke_options.addOption(bool, "enable_smoke", true);
    nocted_smoke_mod.addOptions("build_options", nocted_smoke_options);
    nocted_smoke_mod.addImport("nocted_core", nocted_core_mod);
    nocted_smoke_mod.addImport("noctty_release", release_mod);
    nocted_smoke_mod.addImport("tree_sitter", tree_sitter_mod);
    nocted_smoke_mod.linkSystemLibrary("gtk+-3.0", .{ .use_pkg_config = .force });
    nocted_smoke_mod.linkSystemLibrary("gtksourceview-4", .{ .use_pkg_config = .force });
    const nocted_smoke_exe = b.addExecutable(.{
        .name = "nocted-smoke",
        .root_module = nocted_smoke_mod,
    });

    const install_smoke = b.addInstallArtifact(smoke_exe, .{});
    const install_nocted_smoke = b.addInstallArtifact(nocted_smoke_exe, .{});
    const smoke_step = b.step("smoke-binaries", "Build native smoke-only binaries");
    smoke_step.dependOn(&install_smoke.step);
    smoke_step.dependOn(&install_nocted_smoke.step);
    const noctty_smoke_step = b.step(
        "noctty-smoke-binary",
        "Build only the NOCTTY smoke binary",
    );
    noctty_smoke_step.dependOn(&install_smoke.step);
    const nocted_smoke_step = b.step(
        "nocted-smoke-binary",
        "Build only the standalone NoctEd smoke binary",
    );
    nocted_smoke_step.dependOn(&install_nocted_smoke.step);

    const nocted_stability_mod = b.createModule(.{
        .root_source_file = b.path("src/nocted/StabilityQualification.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    nocted_stability_mod.addImport("nocted_core", nocted_core_mod);
    const nocted_stability_exe = b.addExecutable(.{
        .name = "nocted-core-stability",
        .root_module = nocted_stability_mod,
    });
    const install_nocted_stability = b.addInstallArtifact(nocted_stability_exe, .{});
    const nocted_stability_binary_step = b.step(
        "nocted-stability-binary",
        "Build the allocator-accounted NoctEd core stability runner",
    );
    nocted_stability_binary_step.dependOn(&install_nocted_stability.step);

    const nocted_worker_qualification_mod = b.createModule(.{
        .root_source_file = b.path("src/nocted/WorkerQualification.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    nocted_worker_qualification_mod.addImport("nocted_core", nocted_core_mod);
    nocted_worker_qualification_mod.linkSystemLibrary("glib-2.0", .{
        .use_pkg_config = .force,
    });
    const nocted_worker_qualification_exe = b.addExecutable(.{
        .name = "nocted-worker-qualification",
        .root_module = nocted_worker_qualification_mod,
    });
    const install_nocted_worker_qualification = b.addInstallArtifact(
        nocted_worker_qualification_exe,
        .{},
    );
    const nocted_worker_qualification_step = b.step(
        "nocted-worker-qualification-binary",
        "Build the headless production NoctEd GLib worker qualification runner",
    );
    nocted_worker_qualification_step.dependOn(
        &install_nocted_worker_qualification.step,
    );

    const nocted_project_index_mod = b.createModule(.{
        .root_source_file = b.path("src/nocted/ProjectIndexQualification.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    nocted_project_index_mod.addImport("nocted_core", nocted_core_mod);
    const nocted_project_index_exe = b.addExecutable(.{
        .name = "nocted-project-index-qualification",
        .root_module = nocted_project_index_mod,
    });
    const install_nocted_project_index = b.addInstallArtifact(
        nocted_project_index_exe,
        .{},
    );
    const nocted_project_index_step = b.step(
        "nocted-project-index-binary",
        "Build the NoctEd project-index scale and delta qualification runner",
    );
    nocted_project_index_step.dependOn(&install_nocted_project_index.step);

    const terminal_compatibility_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/CompatibilityQualification.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    terminal_compatibility_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    const terminal_compatibility_exe = b.addExecutable(.{
        .name = "noctty-terminal-compatibility",
        .root_module = terminal_compatibility_mod,
    });
    const install_terminal_compatibility = b.addInstallArtifact(
        terminal_compatibility_exe,
        .{},
    );
    const terminal_compatibility_binary_step = b.step(
        "terminal-compatibility-binary",
        "Build the deterministic terminal compatibility qualification runner",
    );
    terminal_compatibility_binary_step.dependOn(&install_terminal_compatibility.step);

    const terminal_session_qualification_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/SessionQualification.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    terminal_session_qualification_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    const terminal_session_qualification_exe = b.addExecutable(.{
        .name = "noctty-terminal-session-qualification",
        .root_module = terminal_session_qualification_mod,
    });
    const install_terminal_session_qualification = b.addInstallArtifact(
        terminal_session_qualification_exe,
        .{},
    );
    const terminal_session_qualification_binary_step = b.step(
        "terminal-session-qualification-binary",
        "Build the allocator-accounted PTY lifecycle qualification runner",
    );
    terminal_session_qualification_binary_step.dependOn(
        &install_terminal_session_qualification.step,
    );

    const launch_continuity_qualification_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/ContinuityQualification.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    launch_continuity_qualification_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    const launch_continuity_qualification_exe = b.addExecutable(.{
        .name = "noctty-launch-continuity-qualification",
        .root_module = launch_continuity_qualification_mod,
    });
    const install_launch_continuity_qualification = b.addInstallArtifact(
        launch_continuity_qualification_exe,
        .{},
    );
    const launch_continuity_qualification_binary_step = b.step(
        "launch-continuity-qualification-binary",
        "Build the tmux/Zellij launch-profile PTY qualification runner",
    );
    launch_continuity_qualification_binary_step.dependOn(
        &install_launch_continuity_qualification.step,
    );

    const terminal_real_tui_qualification_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/RealTuiQualification.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    terminal_real_tui_qualification_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    const terminal_real_tui_qualification_exe = b.addExecutable(.{
        .name = "noctty-terminal-real-tui-qualification",
        .root_module = terminal_real_tui_qualification_mod,
    });
    const install_terminal_real_tui_qualification = b.addInstallArtifact(
        terminal_real_tui_qualification_exe,
        .{},
    );
    const terminal_real_tui_qualification_binary_step = b.step(
        "terminal-real-tui-qualification-binary",
        "Build the installed Codex/Vim/btop PTY/VT qualification runner",
    );
    terminal_real_tui_qualification_binary_step.dependOn(
        &install_terminal_real_tui_qualification.step,
    );

    const terminal_ncurses_qualification_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/NcursesQualification.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    terminal_ncurses_qualification_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    const terminal_ncurses_qualification_exe = b.addExecutable(.{
        .name = "noctty-terminal-ncurses-qualification",
        .root_module = terminal_ncurses_qualification_mod,
    });
    const install_terminal_ncurses_qualification = b.addInstallArtifact(
        terminal_ncurses_qualification_exe,
        .{},
    );
    const terminal_ncurses_qualification_binary_step = b.step(
        "terminal-ncurses-qualification-binary",
        "Build the installed nano/less/dialog PTY/VT qualification runner",
    );
    terminal_ncurses_qualification_binary_step.dependOn(
        &install_terminal_ncurses_qualification.step,
    );

    const terminal_system_tui_qualification_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/SystemTuiQualification.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    terminal_system_tui_qualification_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    const terminal_system_tui_qualification_exe = b.addExecutable(.{
        .name = "noctty-terminal-system-tui-qualification",
        .root_module = terminal_system_tui_qualification_mod,
    });
    const install_terminal_system_tui_qualification = b.addInstallArtifact(
        terminal_system_tui_qualification_exe,
        .{},
    );
    const terminal_system_tui_qualification_binary_step = b.step(
        "terminal-system-tui-qualification-binary",
        "Build the installed top/watch/info/whiptail/fzf/sqlite3/glances/bash/man/sftp PTY/VT qualification runner",
    );
    terminal_system_tui_qualification_binary_step.dependOn(
        &install_terminal_system_tui_qualification.step,
    );
    b.installFile("resources/com.noctty.NOCTTY.desktop", "share/applications/com.noctty.NOCTTY.desktop");
    b.installFile("resources/com.noctty.NOCTTY.metainfo.xml", "share/metainfo/com.noctty.NOCTTY.metainfo.xml");
    b.installFile("resources/com.noctty.NOCTTY.svg", "share/icons/hicolor/scalable/apps/com.noctty.NOCTTY.svg");
    b.installFile("resources/com.noctty.NoctEd.desktop", "share/applications/com.noctty.NoctEd.desktop");
    b.installFile("resources/com.noctty.NoctEd.metainfo.xml", "share/metainfo/com.noctty.NoctEd.metainfo.xml");
    b.installFile("resources/com.noctty.NoctEd.svg", "share/icons/hicolor/scalable/apps/com.noctty.NoctEd.svg");
    b.installFile("resources/nocted/language-specs/zig.lang", "share/nocted/language-specs/zig.lang");
    b.installFile("resources/nocted/language-specs/svelte.lang", "share/nocted/language-specs/svelte.lang");
    b.installFile("resources/nocted/styles/nocted-dark.xml", "share/nocted/styles/nocted-dark.xml");
    b.installFile("resources/icons/48x48/com.noctty.NOCTTY.png", "share/icons/hicolor/48x48/apps/com.noctty.NOCTTY.png");
    b.installFile("resources/icons/128x128/com.noctty.NOCTTY.png", "share/icons/hicolor/128x128/apps/com.noctty.NOCTTY.png");
    b.installFile("resources/noctalia/niri.kdl", "share/noctty/noctalia/niri.kdl");
    b.installFile("resources/noctalia/hyprland.lua", "share/noctty/noctalia/hyprland.lua");
    b.installFile("resources/noctalia/hyprland.conf", "share/noctty/noctalia/hyprland.conf");
    b.installFile("resources/noctalia/sway.conf", "share/noctty/noctalia/sway.conf");
    b.installFile("resources/noctalia/scroll.conf", "share/noctty/noctalia/scroll.conf");
    b.installFile("resources/noctalia/labwc-rc.xml", "share/noctty/noctalia/labwc-rc.xml");
    b.installFile("resources/noctalia/labwc-autostart", "share/noctty/noctalia/labwc-autostart");
    b.installFile("resources/noctalia/mango.conf", "share/noctty/noctalia/mango.conf");
    b.installFile("resources/noctalia/noctalia-v5-widget.toml", "share/noctty/noctalia/noctalia-v5-widget.toml");
    b.installFile("LICENSE", "share/licenses/noctty/LICENSE");
    b.installFile(
        "THIRD_PARTY_NOTICES.md",
        "share/licenses/noctty/THIRD_PARTY_NOTICES.md",
    );

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the NOCTTY development launcher");
    run_step.dependOn(&run_cmd.step);

    const run_smoke_cmd = b.addRunArtifact(smoke_exe);
    if (b.args) |args| run_smoke_cmd.addArgs(args);
    const run_smoke_step = b.step("smoke-run", "Run the smoke-only NOCTTY binary");
    run_smoke_step.dependOn(&run_smoke_cmd.step);

    const run_nocted_cmd = b.addRunArtifact(nocted_exe);
    run_nocted_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_nocted_cmd.addArgs(args);
    const run_nocted_step = b.step("run-nocted", "Run the NoctEd development editor");
    run_nocted_step.dependOn(&run_nocted_cmd.step);

    const run_nocted_smoke_cmd = b.addRunArtifact(nocted_smoke_exe);
    if (b.args) |args| run_nocted_smoke_cmd.addArgs(args);
    const run_nocted_smoke_step = b.step("run-nocted-smoke", "Run the smoke-only NoctEd binary");
    run_nocted_smoke_step.dependOn(&run_nocted_smoke_cmd.step);

    const tests = b.addTest(.{
        .root_module = root_mod,
    });
    const run_tests = b.addRunArtifact(tests);
    const nocted_tests = b.addTest(.{
        .root_module = nocted_core_mod,
    });
    const run_nocted_tests = b.addRunArtifact(nocted_tests);
    const ghostty_vt_public_tests = b.addTest(.{
        .root_module = ghostty_vt_public_mod,
    });
    const run_ghostty_vt_public_tests = b.addRunArtifact(ghostty_vt_public_tests);
    const vte_host_tests = b.addTest(.{
        .root_module = vte_host_test_mod,
    });
    const run_vte_host_tests = b.addRunArtifact(vte_host_tests);

    const test_step = b.step("test", "Run NOCTTY unit tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_nocted_tests.step);
    test_step.dependOn(&run_ghostty_vt_public_tests.step);
    test_step.dependOn(&run_vte_host_tests.step);

    const check_step = b.step("check", "Build and test NOCTTY");
    check_step.dependOn(&exe.step);
    check_step.dependOn(&nocted_exe.step);
    check_step.dependOn(&vte_exe.step);
    check_step.dependOn(&smoke_exe.step);
    check_step.dependOn(&nocted_smoke_exe.step);
    check_step.dependOn(&run_tests.step);
    check_step.dependOn(&run_nocted_tests.step);
    check_step.dependOn(&run_ghostty_vt_public_tests.step);
    check_step.dependOn(&run_vte_host_tests.step);
}

fn addTreeSitterSources(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    module.addIncludePath(b.path("vendor/tree-sitter/lib/src"));
    module.addIncludePath(b.path("vendor/tree-sitter-zig/src"));
    module.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter/lib/src/lib.c"),
        .flags = &.{ "-std=c11", "-D_GNU_SOURCE" },
    });
    for ([_][]const u8{
        "vendor/tree-sitter-json/src/parser.c",
        "vendor/tree-sitter-c/src/parser.c",
        "vendor/tree-sitter-bash/src/parser.c",
        "vendor/tree-sitter-bash/src/scanner.c",
        "vendor/tree-sitter-markdown/tree-sitter-markdown/src/parser.c",
        "vendor/tree-sitter-markdown/tree-sitter-markdown/src/scanner.c",
        "vendor/tree-sitter-markdown/tree-sitter-markdown-inline/src/parser.c",
        "vendor/tree-sitter-markdown/tree-sitter-markdown-inline/src/scanner.c",
        "vendor/tree-sitter-zig/src/parser.c",
    }) |file| module.addCSourceFile(.{ .file = b.path(file), .flags = &.{"-std=c11"} });
}

fn addNativeGridSources(
    b: *std.Build,
    module: *std.Build.Module,
    enable_smoke: bool,
) void {
    const flags: []const []const u8 = if (enable_smoke)
        &.{
            "-std=c11",
            "-DNOCTTY_ENABLE_SMOKE=1",
            "-Wall",
            "-Wextra",
            "-Wconversion",
            "-Wsign-conversion",
            "-Wshadow",
            "-Wformat=2",
            "-Werror",
        }
    else
        &.{
            "-std=c11",
            "-DNOCTTY_ENABLE_SMOKE=0",
            "-Wall",
            "-Wextra",
            "-Wconversion",
            "-Wsign-conversion",
            "-Wshadow",
            "-Wformat=2",
            // Smoke helpers remain compiled but unreachable in production.
            "-Wno-unused-function",
            "-Werror",
        };
    module.addCSourceFile(.{
        .file = b.path("src/gui/native_grid_host.c"),
        .flags = flags,
    });
}
