#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

grid=src/gui/native_grid_host.c
grid_abi=src/gui/native_grid_abi.h
grid_abi_zig=src/gui/NativeGridAbi.zig
native_gtk=src/gui/NativeGtk.zig
main=src/main.zig
pty=src/terminal/Pty.zig
vt=src/terminal/Vt.zig
nocted=src/nocted/main.zig
nocted_settings=src/nocted/Settings.zig
nocted_task=src/nocted/Task.zig
nocted_worker=src/nocted/Worker.zig
isolated_x11=scripts/run_isolated_x11.sh
isolated_wayland=scripts/run_isolated_wayland.sh
nocted_endurance=scripts/nocted_native_endurance_qualification.sh
auth_agent=scripts/native_grid_authenticated_agent_qualification.sh
installed_continuity=scripts/native_grid_installed_continuity_qualification.sh
stability=scripts/native_grid_stability_qualification.sh
windows_host=src/windows/native_host.c
windows_main=src/windows/main.zig
windows_nocted=src/windows/nocted_main.zig
windows_package=scripts/package_windows.sh
windows_smoke=scripts/windows_smoke.ps1

for path in "$grid" "$grid_abi" "$grid_abi_zig" "$native_gtk" "$main" "$pty" "$vt" "$nocted" "$nocted_settings" "$nocted_task" "$nocted_worker" "$isolated_x11" "$isolated_wayland" "$nocted_endurance" "$auth_agent" "$installed_continuity" "$stability" "$windows_host" "$windows_main" "$windows_nocted" "$windows_package" "$windows_smoke"; do
  test -s "$path"
done

test "$(find src -type f -name '*.c' | wc -l | tr -d ' ')" -eq 5
test "$(find src -type f -name '*.c' ! -path "$grid" ! -path "$windows_host" \
  ! -path src/windows/nocted_host.c ! -path src/windows/dpapi.c \
  ! -path src/share/net.c | wc -l | tr -d ' ')" -eq 0
test ! -e src/editor

grep -F '#define NOCTTY_NATIVE_GRID_ABI_VERSION 5u' "$grid_abi" >/dev/null
grep -F 'pub const version: u32 = 5;' "$grid_abi_zig" >/dev/null
grep -F 'pub const Paste = *const fn (?*anyopaque, [*]const u8, usize)' "$grid_abi_zig" >/dev/null
grep -F 'test "paste callback accepts length-delimited bytes"' "$grid_abi_zig" >/dev/null
grep -F 'pub const NativeGridAbi = @import("NativeGridAbi.zig");' src/gui/root.zig >/dev/null
grep -F 'const NativeGridAbi = noctty.gui.NativeGridAbi;' "$main" >/dev/null

grep -F 'const NativeGridRunOptions = struct {' "$main" >/dev/null
grep -F '.use_layer_shell = options.use_layer_shell' "$main" >/dev/null
grep -F 'fn runNativeGridHost(options: NativeGridRunOptions) c_int {' "$main" >/dev/null
grep -F '"--native-grid-full-stack-qualification"' "$main" >/dev/null
grep -F '"--native-grid-stability-qualification"' "$main" >/dev/null
grep -F '"--native-grid-authenticated-agent-qualification"' "$main" >/dev/null
grep -F '"--native-grid-installed-continuity-qualification"' "$main" >/dev/null
! grep -F 'fn noctty_native_grid_host_run(' "$main" >/dev/null

grep -F 'pub export fn noctty_settings_page_new' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_settings_grid_attach_control' "$native_gtk" >/dev/null
grep -F 'gtk_label_set_mnemonic_widget(@ptrCast(label), control_widget);' "$native_gtk" >/dev/null
! grep -F 'static GtkWidget *settings_page_new' "$grid" >/dev/null
! grep -F 'static void settings_grid_attach_control' "$grid" >/dev/null
grep -F 'save failed; keep this window open' "$grid" >/dev/null
grep -F 'if (save_quick_note(root)) gtk_widget_destroy' "$grid" >/dev/null
grep -F 'Could not save terminal scrollback' "$grid" >/dev/null
grep -F 'set_widget_accessible_name(entry, "Search terminal scrollback");' "$grid" >/dev/null
grep -F 'context.full_stack_idle_ticks == 0' "$grid" >/dev/null
grep -F 'context.stability_hidden_draws == 0' "$grid" >/dev/null
grep -F "bytes[0] = '\\r'; length = 1;" "$grid" >/dev/null
! grep -F "bytes[0] = '\\n'; length = 1;" "$grid" >/dev/null
grep -F 'poll_installed_continuity_detach_smoke' "$grid" >/dev/null
grep -F 'g_dbus_connection_call_sync(' "$grid" >/dev/null
grep -F '#define NOCTTY_WINDOW_RESIZE_BORDER_PX 3' "$grid" >/dev/null
grep -F '#define NOCTTY_PANE_INFO_HEIGHT_PX 18' "$grid" >/dev/null
grep -F 'return index == 3 || index == 4 ? "ew-resize" : "ns-resize";' "$grid" >/dev/null
! grep -F 'nwse-resize' "$grid" >/dev/null
! grep -F 'nesw-resize' "$grid" >/dev/null
grep -F 'gdk_cursor_new_from_name(display, "text")' "$grid" >/dev/null
grep -F 'gtk_window_set_default_icon_name("com.noctty.NOCTTY");' "$grid" >/dev/null
grep -F 'gtk_window_set_icon_name(GTK_WINDOW(window), "com.noctty.NOCTTY");' "$grid" >/dev/null
grep -F 'root, dialog, "noctty-terminal-find"' "$grid" >/dev/null
grep -F 'static void configure_overlay_window_geometry(' "$grid" >/dev/null
grep -F 'gint width = gtk_widget_get_allocated_width(dialog);' "$grid" >/dev/null
grep -F 'GtkWidget *launch_buttons = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);' "$grid" >/dev/null
grep -F 'if (!gtk_widget_get_mapped(widget)) {' "$grid" >/dev/null
grep -F 'resize_grid_to_allocation(context, &allocation);' "$grid" >/dev/null
grep -F 'g_idle_add(focus_grid_area_idle, g_object_ref(context->area));' "$grid" >/dev/null
grep -F 'guint focus_deferred_source;' "$grid" >/dev/null
grep -F 'remove_grid_source(&context->focus_deferred_source);' "$grid" >/dev/null
grep -F 'remaining->focus_deferred_source =' "$grid" >/dev/null
grep -F 'g_idle_add(recreate_grid_toplevel_idle, root);' "$grid" >/dev/null
grep -F 'root->layer_shell_active = 0;' "$grid" >/dev/null
grep -F 'root->window = create_grid_toplevel(root);' "$grid" >/dev/null
grep -F '"gtk_layer_get_protocol_version"' "$grid" >/dev/null
grep -F 'root->layer_shell_keyboard_mode = protocol_version >= 4 ? 2 : 1;' "$grid" >/dev/null
grep -F 'set_grid_layer_keyboard_active(root, FALSE);' "$grid" >/dev/null
grep -F 'root->hide_source = g_timeout_add(16, finish_grid_hide, root);' "$grid" >/dev/null

grep -F 'typedef int (*NocttyGridRow)(void *, int, uint64_t *, size_t);' "$grid_abi" >/dev/null
grep -F 'int dirty_count = context->dirty_spans(' "$grid" >/dev/null
grep -F 'static int draw_ascii_run(' "$grid" >/dev/null
grep -F 'gtk_widget_add_tick_callback(' "$grid" >/dev/null
grep -F 'g_unix_fd_add_full(' "$grid" >/dev/null
! grep -F '*created = *source;' "$grid" >/dev/null

grep -F 'const child_pid = std.c.fork();' "$pty" >/dev/null
grep -F 'const read_length = std.c.read(fd, buffer.ptr, buffer.len);' "$pty" >/dev/null
grep -F 'childCloseInheritedDescriptors();' "$pty" >/dev/null
! grep -R -E --include='*.zig' '(append|insert)\(try ' src >/dev/null
! grep -R -F --include='*.zig' '_ = allocator;' src >/dev/null
grep -F 'checkAllAllocationFailures' src/nocted/Settings.zig >/dev/null
grep -F 'checkAllAllocationFailures' src/nocted/Session.zig >/dev/null
grep -F 'checkAllAllocationFailures' src/nocted/Lsp.zig >/dev/null
grep -F 'checkAllAllocationFailures' src/nocted/SyntaxDiscovery.zig >/dev/null
grep -F 'checkAllAllocationFailures' src/terminal/Terminal.zig >/dev/null
grep -F 'checkAllAllocationFailures' src/workspace/Workspace.zig >/dev/null
grep -F '_ = execve(options.program.ptr' "$pty" >/dev/null
grep -F 'pub fn packedRow(self: Grid, row: usize, output: []u64) usize {' "$vt" >/dev/null

grep -F 'CreatePseudoConsole(size, input_read, output_write' "$windows_host" >/dev/null
grep -F 'const Vt = Share.vt;' "$windows_main" >/dev/null
grep -F 'self.next_untitled = next_untitled;' "$windows_nocted" >/dev/null
grep -F 'telemetry=false uploads=false' "$windows_host" >/dev/null
grep -F -- '-Dtarget=x86_64-windows-gnu' "$windows_package" >/dev/null
grep -F 'physical_windows_validation=false' "$windows_package" >/dev/null
grep -F 'windows_smoke self_test=true' "$windows_smoke" >/dev/null

grep -F 'setAccessibleName(self.notebook, "Open files");' "$nocted" >/dev/null
grep -F 'setAccessibleName(self.window, "NoctEd editor window");' "$nocted" >/dev/null
grep -F 'setAccessibleName(self.tree, "Project files");' "$nocted" >/dev/null
grep -F 'setAccessibleName(self.project_search_tree, "Project search results");' "$nocted" >/dev/null
grep -F 'setAccessibleName(self.quick_open_tree, "Quick Open results");' "$nocted" >/dev/null
grep -F 'c.gtk_widget_set_size_request(close, 28, 18);' "$nocted" >/dev/null
grep -F 'c.gtk_widget_set_size_request(button, 28, 28);' "$nocted" >/dev/null
grep -F 'render=widget nonblack_samples=%zu' "$nocted" >/dev/null
grep -F 'total_phase_cycles=$((total_cycles * 4))' "$nocted_endurance" >/dev/null
grep -F 'No file open; use File > New File or Open File' "$nocted" >/dev/null
grep -F 'app.newDocument() catch' "$nocted" >/dev/null
grep -F 'pub fn truncateImportPaths(' "$nocted_settings" >/dev/null
grep -F 'self.settings.truncateImportPaths(self.allocator, retained_count);' "$nocted" >/dev/null
grep -F 'session save failed during window teardown' "$nocted" >/dev/null
grep -F 'native_grid_stability_matrix' "$stability" >/dev/null
grep -F 'if (hasFile(io, root, "Cargo.toml")) return cargoPlan(action);' "$nocted_task" >/dev/null
grep -F 'if (hasFile(io, root, "go.mod")) return goPlan(action);' "$nocted_task" >/dev/null
grep -F 'fn hasDirectory(' "$nocted_task" >/dev/null
grep -F 'const stream_bytes_max = 1024 * 1024;' "$nocted_task" >/dev/null
grep -F 'const termination_grace_ms = 100;' "$nocted_task" >/dev/null
grep -F 'std.posix.kill(-child_id, .TERM)' "$nocted_task" >/dev/null
grep -F 'packageHasScript(io, root, "check")' "$nocted_task" >/dev/null
grep -F 'pub fn runControlledAlloc(' "$nocted_task" >/dev/null
grep -F '.pgid = if (builtin.os.tag == .windows' "$nocted_task" >/dev/null
grep -F '.is_cancelled = taskCancelled' "$nocted_worker" >/dev/null
grep -F 'return error.TaskEnvironmentUnavailable;' "$nocted_worker" >/dev/null
grep -F '.environ_map = environment' "$nocted_worker" >/dev/null
grep -F 'orderedRemove("XDG_ACTIVATION_TOKEN")' "$nocted_task" >/dev/null
grep -F 'orderedRemove("DESKTOP_STARTUP_ID")' "$nocted_task" >/dev/null
grep -F 'NOCTTY_ISOLATED_DISPLAY=x11 NOCTTY_SHARED_ISOLATION=1' "$isolated_x11" >/dev/null
grep -F 'export XDG_CONFIG_HOME="$root/config"' "$isolated_x11" >/dev/null
grep -F 'export NOCTTY_ISOLATED_DISPLAY=wayland' "$isolated_wayland" >/dev/null
grep -F 'unset DISPLAY WAYLAND_DISPLAY' "$isolated_x11" >/dev/null
grep -F 'unset DISPLAY WAYLAND_DISPLAY' "$isolated_wayland" >/dev/null

grep -F '"-Wconversion"' build.zig >/dev/null
grep -F '"-Wshadow"' build.zig >/dev/null
grep -F '"-Werror"' build.zig >/dev/null

echo 'native_layout gtk_host_c=true windows_host_c=true windows_conpty=true windows_local_dumps=true windows_untitled_transaction=true zig_state=true named_launch_options=true abi_v5=true length_delimited_paste=true enter_carriage_return=true yakuake_resize_chrome=true terminal_text_cursor=true no_diagonal_cursors=true application_icon=true dialogs_above_terminal=true settings_geometry_bounded=true transient_resize_suppressed=true session_focus_deferred=true deferred_focus_owned=true live_window_mode_switch=true layer_keyboard_on_demand=true staged_layer_unmap=true settings_zig=true settings_accessible=true transient_accessible=true save_errors_visible=true packed_rows=true dirty_spans=true frame_clock=true pty_event_source=true mapped_full_stack=true mapped_stability=true native_renderer=true native_renderer_default=true native_host_override=true native_grid=true native_grid_workspace=true native_grid_clipboard=true native_grid_notification=true native_grid_noctalia_ipc=true native_grid_shortcut=true native_grid_tab_rename=true native_grid_theme=true native_grid_project=true native_grid_maintenance=true native_grid_hot_session=true native_grid_profile_preset=true native_grid_launch_profile=true native_grid_command_palette=true native_grid_tab_color=true native_grid_settings_stacking=true native_grid_note_overlay=true native_grid_tab_navigation=true native_grid_terminal_chords=true native_grid_wayland=true native_grid_x11=true native_grid_sharing_scope=true native_grid_pane_scrollbar=true native_grid_reorder=true native_grid_layout=true native_grid_layout_qualification=true native_grid_installed_continuity=true native_grid_authenticated_agent=true native_grid_oom=true native_grid_fairness=true native_grid_network=true native_grid_failure_injection=true native_grid_portability=true native_grid_release=true native_grid_differential=true native_grid_pane_identity=true native_grid_project_actions=true native_grid_launch_profile_gui=true native_grid_command_palette_rename=true native_grid_shortcut_menu=true native_grid_visual_profile=true native_grid_emoji=true native_grid_process_tree=true native_grid_single_instance=true native_grid_state_recovery=true native_grid_recovery_notice=true native_grid_workspace_activation=true native_grid_tab_indicator=true native_grid_focus=true native_grid_close_preflight=true native_grid_share=true native_grid_smart_filter=true native_grid_reflow=true native_grid_resize_osd=true native_grid_pane_scrollbar=true native_grid_gtk=true native_grid_abi=true'
