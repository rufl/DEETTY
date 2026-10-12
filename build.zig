const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    if (builtin.zig_version.major != 0 or builtin.zig_version.minor != 16) {
        std.debug.panic(
            "NOCTTY requires Zig 0.16.x (found {d}.{d}.{d}).",
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

    if (target.result.os.tag == .windows) {
        addWindowsBuild(b, target, optimize, strip);
        return;
    }
    if (target.result.os.tag != .linux) {
        std.debug.panic("NOCTTY currently supports Linux and experimental Windows targets.", .{});
    }

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });

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
    const unicode_generator_mod = b.createModule(.{
        .root_source_file = b.path("tools/generate_terminal_unicode.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    const terminal_key_encoding_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/KeyEncoding.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    const split_ratio_mod = b.createModule(.{
        .root_source_file = b.path("src/workspace/SplitRatio.zig"),
        .target = target,
        .optimize = optimize,
    });
    const native_grid_logic_mod = b.createModule(.{
        .root_source_file = b.path("src/gui/NativeGridLogic.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    const windows_host_logic_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/WindowsHostLogic.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    native_grid_logic_mod.addImport("terminal_key_encoding", terminal_key_encoding_mod);
    native_grid_logic_mod.addImport("split_ratio", split_ratio_mod);
    windows_host_logic_mod.addImport("terminal_key_encoding", terminal_key_encoding_mod);
    const windows_pty_logic_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/WindowsPtyLogic.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    const windows_workspace_share_mod = b.createModule(.{
        .root_source_file = b.path("src/share_module.zig"),
        .target = target,
        .optimize = optimize,
    });
    windows_workspace_share_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    const windows_workspace_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/WindowsWorkspace.zig"),
        .target = target,
        .optimize = optimize,
    });
    windows_workspace_mod.addImport("noctty_share", windows_workspace_share_mod);
    windows_host_logic_mod.addImport("noctty_share", windows_workspace_share_mod);
    const windows_appearance_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/WindowsAppearance.zig"),
        .target = target,
        .optimize = optimize,
    });
    windows_appearance_mod.addImport("noctty_share", windows_workspace_share_mod);
    const windows_theme_library_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/WindowsThemeLibrary.zig"),
        .target = target,
        .optimize = optimize,
    });
    windows_theme_library_mod.addImport("noctty_share", windows_workspace_share_mod);
    const windows_theme_source_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/WindowsThemeSource.zig"),
        .target = target,
        .optimize = optimize,
    });
    windows_theme_source_mod.addImport("noctty_share", windows_workspace_share_mod);
    const theme_storage_mod = b.createModule(.{
        .root_source_file = b.path("src/theme/Storage.zig"),
        .target = target,
        .optimize = optimize,
    });
    const windows_launch_profiles_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/WindowsLaunchProfiles.zig"),
        .target = target,
        .optimize = optimize,
    });
    windows_launch_profiles_mod.addImport("noctty_share", windows_workspace_share_mod);
    const windows_launch_plan_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/WindowsLaunchPlan.zig"),
        .target = target,
        .optimize = optimize,
    });
    windows_launch_plan_mod.addImport("noctty_share", windows_workspace_share_mod);
    const launch_profile_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/LaunchProfile.zig"),
        .target = target,
        .optimize = optimize,
    });

    root_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
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
    exe_mod.addOptions("build_options", runtime_options);
    exe_mod.addImport("noctty", root_mod);
    exe_mod.addImport("terminal_key_encoding", terminal_key_encoding_mod);
    exe_mod.addImport("split_ratio", split_ratio_mod);
    addNativeGridSources(b, exe_mod, false);
    exe_mod.linkSystemLibrary("gtk+-3.0", .{ .use_pkg_config = .force });
    exe_mod.linkSystemLibrary("dl", .{});

    const exe = b.addExecutable(.{
        .name = "noctty",
        .root_module = exe_mod,
        .use_llvm = true,
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
        .use_llvm = true,
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
    vte_mod.addOptions("build_options", vte_options);
    vte_mod.addImport("noctty", root_mod);
    vte_mod.addImport("terminal_key_encoding", terminal_key_encoding_mod);
    vte_mod.addImport("split_ratio", split_ratio_mod);
    addNativeGridSources(b, vte_mod, false);
    vte_mod.linkSystemLibrary("gtk+-3.0", .{ .use_pkg_config = .force });
    vte_mod.linkSystemLibrary("vte-2.91", .{ .use_pkg_config = .force });
    vte_mod.linkSystemLibrary("dl", .{});
    const vte_exe = b.addExecutable(.{
        .name = "noctty-vte",
        .root_module = vte_mod,
        .use_llvm = true,
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
    smoke_mod.addOptions("build_options", smoke_options);
    smoke_mod.addImport("noctty", root_mod);
    smoke_mod.addImport("terminal_key_encoding", terminal_key_encoding_mod);
    smoke_mod.addImport("split_ratio", split_ratio_mod);
    addNativeGridSources(b, smoke_mod, true);
    smoke_mod.linkSystemLibrary("gtk+-3.0", .{ .use_pkg_config = .force });
    smoke_mod.linkSystemLibrary("vte-2.91", .{ .use_pkg_config = .force });
    smoke_mod.linkSystemLibrary("dl", .{});
    const smoke_exe = b.addExecutable(.{
        .name = "noctty-smoke",
        .root_module = smoke_mod,
        .use_llvm = true,
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
        .use_llvm = true,
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
        .use_llvm = true,
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
        .use_llvm = true,
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
        .use_llvm = true,
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
        .use_llvm = true,
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
        .use_llvm = true,
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

    const terminal_agent_fairness_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/AgentFairnessQualification.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    terminal_agent_fairness_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    terminal_agent_fairness_mod.linkSystemLibrary("glib-2.0", .{
        .use_pkg_config = .force,
    });
    const terminal_agent_fairness_exe = b.addExecutable(.{
        .name = "noctty-terminal-agent-fairness",
        .root_module = terminal_agent_fairness_mod,
        .use_llvm = true,
    });
    const install_terminal_agent_fairness = b.addInstallArtifact(
        terminal_agent_fairness_exe,
        .{},
    );
    const terminal_agent_fairness_binary_step = b.step(
        "terminal-agent-fairness-binary",
        "Build the GLib PTY fairness and large-paste qualification runner",
    );
    terminal_agent_fairness_binary_step.dependOn(
        &install_terminal_agent_fairness.step,
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
        .use_llvm = true,
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
        .use_llvm = true,
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
        .use_llvm = true,
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
        .use_llvm = true,
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
    b.installFile("resources/nocttyhere.desktop", "share/kio/servicemenus/nocttyhere.desktop");
    b.installFile("resources/com.noctty.NOCTTY.metainfo.xml", "share/metainfo/com.noctty.NOCTTY.metainfo.xml");
    b.installFile("resources/com.noctty.NOCTTY.svg", "share/icons/hicolor/scalable/apps/com.noctty.NOCTTY.svg");
    b.installFile("resources/com.noctty.NoctEd.desktop", "share/applications/com.noctty.NoctEd.desktop");
    b.installFile("resources/com.noctty.NoctEd.metainfo.xml", "share/metainfo/com.noctty.NoctEd.metainfo.xml");
    b.installFile("resources/com.noctty.NoctEd.svg", "share/icons/hicolor/scalable/apps/com.noctty.NoctEd.svg");
    b.installFile("resources/nocted/language-specs/zig.lang", "share/nocted/language-specs/zig.lang");
    b.installFile("resources/nocted/language-specs/svelte.lang", "share/nocted/language-specs/svelte.lang");
    b.installFile("resources/nocted/language-specs/kof.lang", "share/nocted/language-specs/kof.lang");
    b.installFile("resources/nocted/language-specs/kof.tmLanguage.json", "share/nocted/language-specs/kof.tmLanguage.json");
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
    b.installFile("dependencies/UNICODE-LICENSE.txt", "share/licenses/noctty/UNICODE-LICENSE.txt");
    for ([_][]const u8{
        "tree-sitter",
        "tree-sitter-json",
        "tree-sitter-c",
        "tree-sitter-bash",
        "tree-sitter-markdown",
        "tree-sitter-zig",
    }) |component| {
        b.installFile(
            b.fmt("vendor/{s}/LICENSE", .{component}),
            b.fmt("share/licenses/noctty/vendor/{s}/LICENSE", .{component}),
        );
    }
    b.installFile(
        "vendor/tree-sitter/lib/src/unicode/LICENSE",
        "share/licenses/noctty/vendor/tree-sitter/lib/src/unicode/LICENSE",
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
        .use_llvm = true,
    });
    const run_tests = b.addRunArtifact(tests);
    const nocted_tests = b.addTest(.{
        .root_module = nocted_core_mod,
        .use_llvm = true,
    });
    const run_nocted_tests = b.addRunArtifact(nocted_tests);
    const ghostty_vt_public_tests = b.addTest(.{
        .root_module = ghostty_vt_public_mod,
        .use_llvm = true,
    });
    const run_ghostty_vt_public_tests = b.addRunArtifact(ghostty_vt_public_tests);
    const vte_host_tests = b.addTest(.{
        .root_module = vte_host_test_mod,
        .use_llvm = true,
    });
    const run_vte_host_tests = b.addRunArtifact(vte_host_tests);
    const unicode_generator_tests = b.addTest(.{
        .root_module = unicode_generator_mod,
        .use_llvm = true,
    });
    const run_unicode_generator_tests = b.addRunArtifact(unicode_generator_tests);
    const unicode_generator_exe = b.addExecutable(.{
        .name = "noctty-unicode-generator",
        .root_module = unicode_generator_mod,
        .use_llvm = true,
    });
    const terminal_key_encoding_tests = b.addTest(.{
        .root_module = terminal_key_encoding_mod,
        .use_llvm = true,
    });
    const run_terminal_key_encoding_tests = b.addRunArtifact(terminal_key_encoding_tests);
    const native_grid_logic_tests = b.addTest(.{
        .root_module = native_grid_logic_mod,
        .use_llvm = true,
    });
    const run_native_grid_logic_tests = b.addRunArtifact(native_grid_logic_tests);
    const windows_host_logic_tests = b.addTest(.{
        .root_module = windows_host_logic_mod,
        .use_llvm = true,
    });
    const run_windows_host_logic_tests = b.addRunArtifact(windows_host_logic_tests);
    const windows_pty_logic_tests = b.addTest(.{
        .root_module = windows_pty_logic_mod,
        .use_llvm = true,
    });
    const run_windows_pty_logic_tests = b.addRunArtifact(windows_pty_logic_tests);
    const windows_workspace_tests = b.addTest(.{
        .root_module = windows_workspace_mod,
        .filters = &.{"Windows workspace:"},
        .use_llvm = true,
    });
    const run_windows_workspace_tests = b.addRunArtifact(windows_workspace_tests);
    const windows_workspace_test_step = b.step(
        "windows-workspace-test",
        "Test Windows tab identity and snapshot compatibility without Win32",
    );
    windows_workspace_test_step.dependOn(&run_windows_workspace_tests.step);
    const split_ratio_tests = b.addTest(.{ .root_module = split_ratio_mod, .use_llvm = true });
    const run_split_ratio_tests = b.addRunArtifact(split_ratio_tests);
    const windows_appearance_tests = b.addTest(.{ .root_module = windows_appearance_mod, .use_llvm = true });
    const run_windows_appearance_tests = b.addRunArtifact(windows_appearance_tests);
    const windows_theme_library_tests = b.addTest(.{
        .root_module = windows_theme_library_mod,
        .filters = &.{"Windows theme library:"},
        .use_llvm = true,
    });
    const windows_theme_source_tests = b.addTest(.{
        .root_module = windows_theme_source_mod,
        .use_llvm = true,
    });
    const run_windows_theme_source_tests = b.addRunArtifact(windows_theme_source_tests);
    const run_windows_theme_library_tests = b.addRunArtifact(windows_theme_library_tests);
    const theme_storage_tests = b.addTest(.{
        .root_module = theme_storage_mod,
        .filters = &.{ "theme import", "theme libraries" },
        .use_llvm = true,
    });
    const run_theme_storage_tests = b.addRunArtifact(theme_storage_tests);
    const windows_launch_profiles_tests = b.addTest(.{
        .root_module = windows_launch_profiles_mod,
        .use_llvm = true,
    });
    const run_windows_launch_profiles_tests = b.addRunArtifact(windows_launch_profiles_tests);
    const windows_launch_plan_tests = b.addTest(.{
        .root_module = windows_launch_plan_mod,
        .use_llvm = true,
        .filters = &.{"Windows launch plan:"},
    });
    const run_windows_launch_plan_tests = b.addRunArtifact(windows_launch_plan_tests);
    const launch_profile_tests = b.addTest(.{
        .root_module = launch_profile_mod,
        .use_llvm = true,
    });
    const run_launch_profile_tests = b.addRunArtifact(launch_profile_tests);
    const windows_policy_step = b.step("windows-policy-test", "Test native workspace, divider, appearance, and input policy without a display");
    windows_policy_step.dependOn(&run_windows_workspace_tests.step);
    windows_policy_step.dependOn(&run_windows_theme_source_tests.step);
    windows_policy_step.dependOn(&run_windows_host_logic_tests.step);
    windows_policy_step.dependOn(&run_split_ratio_tests.step);
    windows_policy_step.dependOn(&run_windows_appearance_tests.step);
    windows_policy_step.dependOn(&run_windows_theme_library_tests.step);
    windows_policy_step.dependOn(&run_theme_storage_tests.step);
    windows_policy_step.dependOn(&run_windows_launch_profiles_tests.step);
    windows_policy_step.dependOn(&run_windows_launch_plan_tests.step);
    windows_policy_step.dependOn(&run_launch_profile_tests.step);

    const test_step = b.step("test", "Run NOCTTY unit tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_nocted_tests.step);
    test_step.dependOn(&run_ghostty_vt_public_tests.step);
    test_step.dependOn(&run_vte_host_tests.step);
    test_step.dependOn(&run_unicode_generator_tests.step);
    test_step.dependOn(&run_terminal_key_encoding_tests.step);
    test_step.dependOn(&run_native_grid_logic_tests.step);
    test_step.dependOn(&run_windows_host_logic_tests.step);
    test_step.dependOn(&run_windows_pty_logic_tests.step);
    test_step.dependOn(&run_windows_workspace_tests.step);
    test_step.dependOn(&run_split_ratio_tests.step);
    test_step.dependOn(&run_windows_appearance_tests.step);
    test_step.dependOn(&run_windows_theme_library_tests.step);
    test_step.dependOn(&run_windows_launch_profiles_tests.step);
    test_step.dependOn(&run_windows_launch_plan_tests.step);

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
    check_step.dependOn(&run_unicode_generator_tests.step);
    check_step.dependOn(&unicode_generator_exe.step);
    check_step.dependOn(&run_terminal_key_encoding_tests.step);
    check_step.dependOn(&run_native_grid_logic_tests.step);
    check_step.dependOn(&run_windows_host_logic_tests.step);
    check_step.dependOn(&run_windows_pty_logic_tests.step);
    check_step.dependOn(&run_windows_workspace_tests.step);
    check_step.dependOn(&run_split_ratio_tests.step);
    check_step.dependOn(&run_windows_appearance_tests.step);
    check_step.dependOn(&run_windows_theme_library_tests.step);
    check_step.dependOn(&run_windows_launch_profiles_tests.step);
    check_step.dependOn(&run_windows_launch_plan_tests.step);
}

fn addWindowsBuild(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    strip: bool,
) void {
    const ghostty_vt_public_mod = b.createModule(.{
        .root_source_file = b.path("src/ghostty/VtPublic.zig"),
        .target = target,
        .optimize = optimize,
    });

    const release_mod = b.createModule(.{
        .root_source_file = b.path("src/release.zig"),
        .target = target,
        .optimize = optimize,
    });
    const nocted_core_mod = b.createModule(.{
        .root_source_file = b.path("src/nocted/root.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    const nocted_windows_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/nocted_main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    nocted_windows_mod.addImport("nocted_core", nocted_core_mod);
    nocted_windows_mod.linkSystemLibrary("kernel32", .{});
    nocted_windows_mod.linkSystemLibrary("user32", .{});
    nocted_windows_mod.linkSystemLibrary("gdi32", .{});
    nocted_windows_mod.linkSystemLibrary("comctl32", .{});
    nocted_windows_mod.linkSystemLibrary("comdlg32", .{});
    nocted_windows_mod.linkSystemLibrary("shell32", .{});
    nocted_windows_mod.linkSystemLibrary("ole32", .{});
    const terminal_key_encoding_mod = b.createModule(.{
        .root_source_file = b.path("src/terminal/KeyEncoding.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    const windows_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    const share_mod = b.createModule(.{
        .root_source_file = b.path("src/share_module.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    share_mod.addImport("ghostty_vt_public", ghostty_vt_public_mod);
    windows_mod.addImport("noctty_share", share_mod);
    windows_mod.addImport("noctty_release", release_mod);
    windows_mod.addImport("terminal_key_encoding", terminal_key_encoding_mod);
    windows_mod.addIncludePath(b.path("src/windows"));
    const windows_theme_source_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/WindowsThemeSource.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    windows_theme_source_mod.addImport("noctty_share", share_mod);
    windows_mod.addImport("windows_theme_source", windows_theme_source_mod);
    windows_mod.linkSystemLibrary("kernel32", .{});
    windows_mod.linkSystemLibrary("user32", .{});
    windows_mod.linkSystemLibrary("gdi32", .{});
    windows_mod.linkSystemLibrary("comctl32", .{});
    windows_mod.linkSystemLibrary("comdlg32", .{});
    windows_mod.linkSystemLibrary("ws2_32", .{});
    windows_mod.linkSystemLibrary("dbghelp", .{});
    windows_mod.linkSystemLibrary("crypt32", .{});
    windows_mod.linkSystemLibrary("bcrypt", .{});

    const executable = b.addExecutable(.{
        .name = "noctty",
        .root_module = windows_mod,
    });
    executable.subsystem = .windows;
    executable.mingw_unicode_entry_point = true;
    b.installArtifact(executable);

    const nocted_executable = b.addExecutable(.{
        .name = "nocted",
        .root_module = nocted_windows_mod,
    });
    nocted_executable.subsystem = .windows;
    nocted_executable.mingw_unicode_entry_point = true;
    b.installArtifact(nocted_executable);

    const nocted_host_qualification_mod = b.createModule(.{
        .root_source_file = b.path("src/windows/NoctedHostQualification.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
    });
    nocted_host_qualification_mod.linkSystemLibrary("kernel32", .{});
    nocted_host_qualification_mod.linkSystemLibrary("user32", .{});
    nocted_host_qualification_mod.linkSystemLibrary("gdi32", .{});
    nocted_host_qualification_mod.linkSystemLibrary("comctl32", .{});
    nocted_host_qualification_mod.linkSystemLibrary("comdlg32", .{});
    nocted_host_qualification_mod.linkSystemLibrary("ole32", .{});
    const nocted_host_qualification_executable = b.addExecutable(.{
        .name = "nocted-host-qualification",
        .root_module = nocted_host_qualification_mod,
    });
    nocted_host_qualification_executable.subsystem = .windows;
    nocted_host_qualification_executable.mingw_unicode_entry_point = true;
    const install_nocted_host_qualification = b.addInstallArtifact(
        nocted_host_qualification_executable,
        .{},
    );
    b.installFile("LICENSE", "share/licenses/noctty/LICENSE");
    b.installFile(
        "THIRD_PARTY_NOTICES.md",
        "share/licenses/noctty/THIRD_PARTY_NOTICES.md",
    );
    b.installFile("dependencies/UNICODE-LICENSE.txt", "share/licenses/noctty/UNICODE-LICENSE.txt");

    const check_step = b.step(
        "check",
        "Compile the native Windows NOCTTY and NoctEd hosts",
    );
    check_step.dependOn(&executable.step);
    check_step.dependOn(&nocted_executable.step);
    check_step.dependOn(&nocted_host_qualification_executable.step);

    const windows_step = b.step(
        "windows",
        "Build the experimental native Windows NOCTTY host",
    );
    windows_step.dependOn(b.getInstallStep());

    const nocted_host_qualification_step = b.step(
        "windows-nocted-host-qualification",
        "Build the mapped Zig Win32 NoctEd host qualification",
    );
    nocted_host_qualification_step.dependOn(&install_nocted_host_qualification.step);
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
            "-Wno-macro-redefined",
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
            "-Wno-macro-redefined",
            // Smoke helpers remain compiled but unreachable in production.
            "-Wno-unused-function",
            "-Werror",
        };
    module.addCSourceFile(.{
        .file = b.path("src/gui/native_grid_host.c"),
        .flags = flags,
    });
}
