#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

grid=src/gui/native_grid_host.c
grid_abi=include/noctty/native_grid_abi.h
grid_abi_zig=src/gui/NativeGridAbi.zig
grid_logic=src/gui/NativeGridLogic.zig
grid_logic_header=include/noctty/native_grid_logic.h
grid_render=src/gui/NativeGridRender.zig
grid_render_header=include/noctty/native_grid_render.h
grid_qualification=tests/native_grid_qualification.inc
native_gtk=src/gui/NativeGtk.zig
native_gtk_header=include/noctty/native_gtk.h
main=src/main.zig
pty=src/terminal/Pty.zig
vt=src/terminal/Vt.zig
nocted=src/nocted/main.zig
nocted_gtk=src/nocted/gtk.zig
nocted_settings=src/nocted/Settings.zig
nocted_task=src/nocted/Task.zig
nocted_worker=src/nocted/Worker.zig
isolated_x11=scripts/run_isolated_x11.sh
isolated_wayland=scripts/run_isolated_wayland.sh
nocted_endurance=scripts/nocted_native_endurance_qualification.sh
auth_agent=scripts/native_grid_authenticated_agent_qualification.sh
installed_continuity=scripts/native_grid_installed_continuity_qualification.sh
stability=scripts/native_grid_stability_qualification.sh
zig_ownership=scripts/check_zig_ownership.sh
windows_host=src/windows/WindowsHost.zig
windows_logic=src/windows/WindowsHostLogic.zig
windows_diagnostics=src/windows/WindowsDiagnostics.zig
windows_pty=src/windows/WindowsPty.zig
windows_pty_logic=src/windows/WindowsPtyLogic.zig
windows_clipboard=src/windows/WindowsClipboard.zig
windows_process=src/windows/WindowsProcess.zig
windows_menu=src/windows/WindowsMenu.zig
windows_fonts=src/windows/WindowsFonts.zig
windows_title=src/windows/WindowsTitle.zig
windows_renderer=src/windows/WindowsRenderer.zig
windows_main=src/windows/main.zig
windows_nocted=src/windows/nocted_main.zig
windows_nocted_host=src/windows/NoctedHost.zig
windows_nocted_qualification=src/windows/NoctedHostQualification.zig
windows_package=scripts/package_windows.sh
windows_smoke=scripts/windows_smoke.ps1
windows_nocted_zig_smoke=scripts/windows_nocted_zig_smoke.sh

for path in "$grid" "$grid_abi" "$grid_abi_zig" "$grid_logic" "$grid_logic_header" "$grid_render" "$grid_render_header" "$grid_qualification" "$native_gtk" "$native_gtk_header" "$main" "$pty" "$vt" "$nocted" "$nocted_settings" "$nocted_task" "$nocted_worker" "$isolated_x11" "$isolated_wayland" "$nocted_endurance" "$auth_agent" "$installed_continuity" "$stability" "$zig_ownership" "$windows_host" "$windows_logic" "$windows_diagnostics" "$windows_pty" "$windows_pty_logic" "$windows_clipboard" "$windows_process" "$windows_menu" "$windows_fonts" "$windows_title" "$windows_renderer" "$windows_main" "$windows_nocted" "$windows_nocted_host" "$windows_nocted_qualification" "$windows_package" "$windows_smoke" "$windows_nocted_zig_smoke"; do
  test -s "$path"
done
for path in tests/native_grid_smoke_*.inc; do
  test -s "$path"
done

test "$(find src -type f -name '*.c' | wc -l | tr -d ' ')" -eq 1
test "$(find src -type f -name '*.c' ! -path "$grid" ! -path "$windows_host" | wc -l | tr -d ' ')" -eq 0
test ! -e src/editor
test ! -e src/windows/nocted_host.c
test ! -e src/windows/nocted_host.h
grep -F 'pub const Callbacks = extern struct {' "$windows_nocted_host" >/dev/null
grep -F 'pub fn run(' "$windows_nocted_host" >/dev/null
grep -F 'instance: windows.HINSTANCE' "$windows_nocted_host" >/dev/null
grep -F 'return NoctedHost.run(instance, show_command, &callbacks, false);' "$windows_nocted" >/dev/null
grep -F 'return Host.run(instance, show_command, &callbacks, true);' "$windows_nocted_qualification" >/dev/null

grep -F '#define NOCTTY_NATIVE_GRID_ABI_VERSION 6u' "$grid_abi" >/dev/null
grep -F 'pub const version: u32 = 6;' "$grid_abi_zig" >/dev/null
grep -F 'pub const Paste = *const fn (?*anyopaque, [*]const u8, usize)' "$grid_abi_zig" >/dev/null
grep -F 'pub export fn noctty_grid_scrollbar_geometry(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_cell_selected(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_codepoint_utf8(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_render_viewport(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_render_chrome(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_render_cell(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_render_run_end(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_render_ascii_run(' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_cells(' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_apply_font_options(' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_terminal_text(' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_resize_overlay(' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_cycle_overlay(' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_quick_note(' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_status_feedback(' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_sharing_preview(' "$grid_render" >/dev/null
grep -F 'cursor_rgb: u32,' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_text_decoration(' "$grid_render" >/dev/null
grep -F 'pub export fn noctty_grid_render_scrollbar(' "$grid_render" >/dev/null
grep -F '#include "../../include/noctty/native_grid_render.h"' "$grid" >/dev/null
grep -F 'pub export fn noctty_grid_cell_span(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_scroll_steps(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_keyboard_scroll_target(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_scale_brightness(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_adapt_window_geometry(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_auto_fit(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_dimensions(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_resize_delta(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_clamp_resize(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_pointer_cell(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_input_route(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_terminal_key_sequence(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_shortcut_label(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_cycle_target(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_directional_focus_begin(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_directional_focus_consider(' "$grid_logic" >/dev/null
grep -F 'pub export fn noctty_grid_key_command_plan(' "$grid_logic" >/dev/null
grep -F 'noctty_grid_input_route(' "$grid" >/dev/null
grep -F 'noctty_grid_terminal_key_sequence(' "$grid" >/dev/null
grep -F 'noctty_grid_cycle_target(' "$grid" >/dev/null
grep -F 'noctty_grid_directional_focus_begin(' "$grid" >/dev/null
grep -F 'noctty_grid_directional_focus_consider(' "$grid" >/dev/null
grep -F 'noctty_grid_key_command_plan(' "$grid" >/dev/null
grep -F 'NocttyGridDirectionalFocusPlan;' "$grid_logic_header" >/dev/null
grep -F 'NocttyGridKeyCommandPlan;' "$grid_logic_header" >/dev/null
grep -F 'noctty_grid_key_command_plan(' "$grid_logic_header" >/dev/null
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

grep -F 'pub export fn noctty_grid_sync_split_visibility(' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_apply_pane_divider_style(' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_apply_even_pane_positions(' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_apply_pane_gap_style(' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_compact_tab_new(' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_new_tab_button_new(' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_window_toolbar_new(' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_window_toolbar_set_close_visible(' "$native_gtk" >/dev/null
grep -F 'noctty_compact_tab_new(' "$grid" >/dev/null
grep -F 'noctty_new_tab_button_new(' "$grid" >/dev/null
grep -F 'noctty_window_toolbar_new(' "$grid" >/dev/null
grep -F 'noctty_window_toolbar_set_close_visible(' "$grid" >/dev/null
grep -F 'NocttyCompactTabCallbacks;' "$native_gtk_header" >/dev/null
grep -F 'NocttyWindowToolbarContents;' "$native_gtk_header" >/dev/null
grep -F 'noctty_compact_tab_new(' "$native_gtk_header" >/dev/null
grep -F 'noctty_window_toolbar_new(' "$native_gtk_header" >/dev/null
grep -F 'const split_walk_max: usize = 31;' "$native_gtk" >/dev/null
! grep -F 'gtk_widget_is_ancestor' "$grid" >/dev/null
grep -F 'pub export fn noctty_settings_page_new' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_settings_grid_attach_control' "$native_gtk" >/dev/null
grep -F 'gtk_label_set_mnemonic_widget(@ptrCast(label), control_widget);' "$native_gtk" >/dev/null
grep -A4 -F 'gtk_scrolled_window_set_policy(' "$native_gtk" | \
  grep -F 'GTK_POLICY_AUTOMATIC,' >/dev/null
! grep -F 'static GtkWidget *settings_page_new' "$grid" >/dev/null
! grep -F 'static void settings_grid_attach_control' "$grid" >/dev/null
grep -F 'save failed; keep this window open' "$grid" >/dev/null
grep -F 'if (save_quick_note(root)) noctty_grid_widget_destroy' "$grid" >/dev/null
grep -F 'Could not save terminal scrollback' "$grid" >/dev/null
grep -F 'setAccessibleName(entry, "Search terminal scrollback");' "$native_gtk" >/dev/null
grep -F 'g_strdup_printf("Close tab: %s", title);' "$grid" >/dev/null
grep -F '"Close file: {s}"' "$nocted" >/dev/null
test "$(grep -c 'noctty_grid_widget_queue_resize(parent);' "$grid")" -eq 1
grep -F '"Theme imported, selected, and saved."' "$grid" >/dev/null
grep -F 'persistNativeGridConfigChecked(bridge)' "$main" >/dev/null
grep -F 'NOCTTY_TEXT_ACTION_PERSISTENCE_FAILED' "$grid" >/dev/null
grep -F 'context->nocted_directory_resolved ? directory : NULL,' "$grid" >/dev/null
grep -F 'static void set_status_label_feedback(' "$grid" >/dev/null
grep -F 'if (root->note_load_failed) return TRUE;' "$grid" >/dev/null
grep -F 'Workspace note could not be loaded; close this window and try again.' "$grid" >/dev/null
grep -F 'dialog, dialog_width, workarea.width < 600, &contents' "$grid" >/dev/null
grep -F 'if (vertical != 0) GTK_ORIENTATION_VERTICAL else GTK_ORIENTATION_HORIZONTAL' "$native_gtk" >/dev/null
grep -F 'gboolean vertical_rows = workarea.width < 640;' "$grid" >/dev/null
grep -F 'setAccessibleName(label, "NOCTTY keyboard shortcuts");' "$native_gtk" >/dev/null
grep -F 'setAccessibleName(combo, "Workspace restore mode");' "$native_gtk" >/dev/null
grep -F 'setAccessibleName(entry, "Screen history password");' "$native_gtk" >/dev/null
grep -F 'setAccessibleName(provider, "Agent provider");' "$native_gtk" >/dev/null
grep -F 'setAccessibleName(entry, "Workspace tag");' "$native_gtk" >/dev/null
grep -F 'setAccessibleName(variant, "Noctalia import variant");' "$native_gtk" >/dev/null
grep -F 'setAccessibleName(peers, "Paired device");' "$native_gtk" >/dev/null
grep -F 'atk_object_set_name(status_accessible, "Session sharing status");' "$native_gtk" >/dev/null
grep -F '@max(1, @min(480, width - 64))' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_grid_sharing_status_actions(' "$grid_logic" >/dev/null
grep -F 'NOCTTY_GRID_SHARING_CLEAR_HOST' tests/native_grid_sharing_scope_smoke.inc >/dev/null
grep -F 'NOCTTY_GRID_SHARING_CLEAR_VIEWER' tests/native_grid_sharing_scope_smoke.inc >/dev/null
! grep -F 'static gboolean sharing_status_can_clear_' "$grid" >/dev/null
grep -F '"Close sharing session"' "$grid" >/dev/null
grep -F '"Close remote session"' "$grid" >/dev/null
grep -F '.{ .label = "Retry saving devices", .action = 18 },' "$native_gtk" >/dev/null
grep -F 'if (revoked) continue;' "$grid" >/dev/null
grep -F 'noctty_grid_share_action(root->event_data, 6, -1' "$grid" >/dev/null
grep -F 'noctty_grid_share_action(root->event_data, 11, -1' "$grid" >/dev/null
grep -F 'state.paired_device_persistence = .save_failed;' "$main" >/dev/null
grep -F 'pairing.destroy();' "$main" >/dev/null
grep -F 'const readable = self.listener.?.readable(50)' src/share/PairController.zig >/dev/null
grep -F 'fn setStatusFeedback(' "$nocted" >/dev/null
grep -F 'if (text_changed or role_changed or description_changed)' "$nocted" >/dev/null
grep -F 'if (text_changed || role_changed || description_changed)' "$grid" >/dev/null
grep -F 'setAccessibleName(combo, "Language-service completions");' "$nocted" >/dev/null
grep -F 'setAccessibleName(entry, "New symbol name");' "$nocted" >/dev/null
! grep -F 'g_strstrip((gchar *)text)' "$grid" >/dev/null
grep -F 'pub const ATK_ROLE_STATUSBAR: c_int = 53;' "$nocted_gtk" >/dev/null
grep -F '"Could not save the workspace"' "$grid" >/dev/null
! sed -n '/export fn noctty_grid_text_action/,/^}/p' "$main" | \
  grep -F 'callback_failed = true' >/dev/null
grep -F 'context.full_stack_idle_ticks == 0' tests/native_grid_smoke_results.inc >/dev/null
grep -F 'context.stability_hidden_draws == 0' tests/native_grid_smoke_results.inc >/dev/null
grep -F 'noctty_grid_terminal_key_sequence(' "$grid" >/dev/null
grep -F 'noctty_grid_shortcut_label(' "$grid" >/dev/null
grep -F 'poll_installed_continuity_detach_smoke' "$grid_qualification" >/dev/null
grep -F 'g_dbus_connection_call_sync(' "$grid" >/dev/null
grep -F '#define NOCTTY_WINDOW_RESIZE_BORDER_PX 2' "$grid" >/dev/null
grep -F '#define NOCTTY_PANE_INFO_HEIGHT_PX 18' "$grid" >/dev/null
grep -F '"Open Link in Browser"' "$grid" >/dev/null
grep -F 'inactive_pane_brightness_percent' "$grid" >/dev/null
grep -F 'pane_gaps_transparent' "$grid" >/dev/null
grep -F 'on_window_resolution_configure' "$grid" >/dev/null
! grep -F 'nwse-resize' "$grid" >/dev/null
! grep -F 'nesw-resize' "$grid" >/dev/null
grep -F 'noctty_grid_gdk_set_cursor(' "$grid" >/dev/null
grep -F 'noctty_grid_combo_box_text_remove_all(' "$grid" >/dev/null
grep -F 'noctty_grid_color_chooser_set_rgb(' "$grid" >/dev/null
grep -F 'noctty_grid_widget_get_allocated_width(' "$grid" >/dev/null
grep -F 'noctty_grid_check_menu_item_get_active(' "$grid" >/dev/null
grep -F 'noctty_grid_widget_remove_tick_callback(' "$grid" >/dev/null
grep -F 'noctty_grid_spin_button_get_value(' "$grid" >/dev/null
grep -F 'noctty_grid_button_new_with_label(' "$grid" >/dev/null
grep -F 'noctty_grid_list_box_get_selected_row(' "$grid" >/dev/null
grep -F 'noctty_grid_dialog_get_widget_for_response(' "$grid" >/dev/null
grep -F 'noctty_grid_widget_get_sensitive(' "$grid" >/dev/null
grep -F 'noctty_grid_selection_data_get_text(' "$grid" >/dev/null
grep -F 'noctty_grid_im_context_set_client_window(' "$grid" >/dev/null
grep -F 'noctty_grid_gtk_init_check(' "$grid" >/dev/null
grep -F 'noctty_grid_gtk_main(' "$grid" >/dev/null
grep -F 'noctty_grid_window_set_default_icon_name(' "$grid" >/dev/null
grep -F 'noctty_grid_window_get_title(' "$grid" >/dev/null
grep -F 'noctty_grid_widget_class_set_accessible_type(' "$grid" >/dev/null
grep -F 'noctty_grid_container_forall(' "$grid" >/dev/null
grep -F 'noctty_grid_input_context_new(' "$grid" >/dev/null
grep -F 'noctty_grid_window_get_window_type(' "$grid" >/dev/null
grep -F 'noctty_grid_widget_is_type(' "$grid" >/dev/null
! grep -F 'GTK_IS_' "$grid" >/dev/null
! grep -F 'gtk_combo_box_text_remove_all(' "$grid" >/dev/null
! grep -F 'gtk_combo_box_text_append(' "$grid" >/dev/null
! grep -F 'gtk_combo_box_text_append_text(' "$grid" >/dev/null
! grep -F 'gtk_color_chooser_set_rgba(' "$grid" >/dev/null
! grep -F 'gtk_color_chooser_get_rgba(' "$grid" >/dev/null
! grep -F 'gtk_widget_get_allocated_width(' "$grid" >/dev/null
! grep -F 'gtk_widget_get_allocated_height(' "$grid" >/dev/null
! grep -F 'gtk_check_menu_item_get_active(' "$grid" >/dev/null
! grep -F 'gtk_widget_remove_tick_callback(' "$grid" >/dev/null
! grep -F 'gtk_spin_button_get_value(' "$grid" >/dev/null
! grep -F 'gtk_button_new_with_label(' "$grid" >/dev/null
! grep -F 'gtk_list_box_get_selected_row(' "$grid" >/dev/null
! grep -F 'gtk_dialog_get_widget_for_response(' "$grid" >/dev/null
! grep -F 'gtk_button_get_label(' "$grid" >/dev/null
! grep -F 'gtk_window_get_default_widget(' "$grid" >/dev/null
! grep -F 'gtk_label_get_label(' "$grid" >/dev/null
! grep -F 'gtk_widget_get_sensitive(' "$grid" >/dev/null
! grep -F 'gtk_selection_data_set_text(' "$grid" >/dev/null
! grep -F 'gtk_selection_data_get_text(' "$grid" >/dev/null
! grep -F 'gtk_im_context_set_client_window(' "$grid" >/dev/null
! grep -F 'gtk_init_check(' "$grid" >/dev/null
! grep -F 'gtk_main(' "$grid" >/dev/null
! grep -F 'gtk_window_set_default_icon_name(' "$grid" >/dev/null
! grep -F 'gtk_widget_class_set_accessible_type(' "$grid" >/dev/null
! grep -F 'gtk_im_multicontext_new(' "$grid" >/dev/null
! grep -F 'gtk_container_forall(' "$grid" >/dev/null
! grep -F 'gtk_window_get_window_type(' "$grid" >/dev/null
grep -F 'gtk_window_set_icon_name(@ptrCast(window), "com.noctty.NOCTTY");' "$native_gtk" >/dev/null
grep -F 'root, dialog, "noctty-terminal-find"' "$grid" >/dev/null
grep -F 'gint width = gtk_widget_get_allocated_width(dialog);' \
  tests/native_grid_compact_ux_smoke.inc >/dev/null
grep -F 'const buttons = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6)' "$native_gtk" >/dev/null
grep -F 'noctty_grid_widget_get_mapped(' "$grid" >/dev/null
grep -F 'g_idle_add(focus_grid_area_idle, g_object_ref(context->area));' "$grid" >/dev/null
grep -F 'guint focus_deferred_source;' "$grid" >/dev/null
grep -F 'remove_grid_source(&context->focus_deferred_source);' "$grid" >/dev/null
grep -F 'remaining->focus_deferred_source =' "$grid" >/dev/null
grep -F 'g_idle_add(recreate_grid_toplevel_idle, root);' "$grid" >/dev/null
grep -F 'root->layer_shell_active = 0;' "$grid" >/dev/null
grep -F 'root->window = create_grid_toplevel(root);' "$grid" >/dev/null
grep -F 'noctty_grid_widget_add_tick_callback(' "$grid" >/dev/null
grep -F 'root->layer_shell_keyboard_mode = protocol_version >= 4 ? 2 : 1;' "$grid" >/dev/null
grep -F 'set_grid_layer_keyboard_active(root, FALSE);' "$grid" >/dev/null
grep -F 'root->hide_source = g_timeout_add(16, finish_grid_hide, root);' "$grid" >/dev/null

grep -F 'typedef int (*NocttyGridRow)(void *, int, uint64_t *, size_t);' "$grid_abi" >/dev/null
grep -F 'int dirty_count = context->dirty_spans(' "$grid" >/dev/null
! grep -F 'static int draw_ascii_run(' "$grid" >/dev/null
grep -F 'noctty_grid_widget_add_tick_callback(' "$grid" >/dev/null
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

grep -F 'c.CreatePseudoConsole(size, input_read, output_write' "$windows_pty" >/dev/null
! grep -F 'CreatePseudoConsole(' "$windows_host" >/dev/null
! grep -F 'OpenClipboard(' "$windows_host" >/dev/null
! grep -F 'CreateProcessW(' "$windows_host" >/dev/null
! grep -F 'CreateMenu(' "$windows_host" >/dev/null
! grep -F 'CreateFontW(' "$windows_host" >/dev/null
! grep -F 'BeginPaint(' "$windows_host" >/dev/null
! grep -F 'ExtTextOutW(' "$windows_host" >/dev/null
! grep -F 'BitBlt(' "$windows_host" >/dev/null
grep -F 'const Vt = Share.vt;' "$windows_main" >/dev/null
grep -F 'self.next_untitled = next_untitled;' "$windows_nocted" >/dev/null
grep -F 'telemetry=false uploads=false' "$windows_host" >/dev/null
grep -F 'pub export fn noctty_windows_compute_pane_geometry(' "$windows_logic" >/dev/null
grep -F 'pub export fn noctty_windows_pointer_cell(' "$windows_logic" >/dev/null
grep -F 'pub export fn noctty_windows_special_key_sequence(' "$windows_logic" >/dev/null
grep -F 'pub export fn noctty_windows_mouse_route(' "$windows_logic" >/dev/null
grep -F 'pub export fn noctty_windows_mouse_transition(' "$windows_logic" >/dev/null
grep -F 'noctty_windows_mouse_transition(' "$windows_host" >/dev/null
grep -F 'noctty_windows_compute_pane_geometry(' "$windows_host" >/dev/null
grep -F 'pub export fn noctty_windows_diagnostics_init()' "$windows_diagnostics" >/dev/null
grep -F 'pub export fn noctty_windows_diagnostics_deinit()' "$windows_diagnostics" >/dev/null
grep -F 'noctty_windows_diagnostics_write(' "$windows_host" >/dev/null
grep -F 'pub export fn noctty_windows_pty_create(' "$windows_pty" >/dev/null
grep -F 'pub export fn noctty_windows_clipboard_paste(' "$windows_clipboard" >/dev/null
grep -F 'pub export fn noctty_windows_launch_nocted()' "$windows_process" >/dev/null
grep -F 'pub export fn noctty_windows_menu_create(' "$windows_menu" >/dev/null
grep -F 'pub export fn noctty_windows_fonts_update(' "$windows_fonts" >/dev/null
grep -F 'pub export fn noctty_windows_update_title(' "$windows_title" >/dev/null
grep -F 'pub export fn noctty_windows_render(' "$windows_renderer" >/dev/null
grep -F 'pub export fn noctty_windows_normalize_preferences(' "$windows_logic" >/dev/null
grep -F 'pub export fn noctty_windows_decode_menu_command(' "$windows_logic" >/dev/null
grep -F 'test "output ring preserves wrapped byte order"' "$windows_pty_logic" >/dev/null
grep -F -- '-Dtarget=x86_64-windows-gnu' "$windows_package" >/dev/null
grep -F 'physical_windows_validation=false' "$windows_package" >/dev/null
grep -F 'windows_smoke self_test=true' "$windows_smoke" >/dev/null
grep -F 'windows_nocted_zig_smoke cross_compile=true wine=true mapped=true' "$windows_nocted_zig_smoke" >/dev/null

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
grep -F 'export XDG_RUNTIME_DIR="$scratch/runtime"' "$isolated_x11" >/dev/null
grep -F 'unset DISPLAY WAYLAND_DISPLAY' "$isolated_wayland" >/dev/null

grep -F '"-Wconversion"' build.zig >/dev/null
grep -F '"-Wshadow"' build.zig >/dev/null
grep -F '"-Werror"' build.zig >/dev/null

"$zig_ownership" >/dev/null

echo 'native_layout gtk_host_c=true windows_host_zig=true windows_nocted_zig=true windows_conpty=true windows_conpty_zig=true windows_clipboard_zig=true windows_process_zig=true windows_menu_zig=true windows_fonts_zig=true windows_renderer_zig=true windows_title_zig=true windows_local_dumps=true windows_untitled_transaction=true zig_state=true named_launch_options=true abi_v6=true length_delimited_paste=true enter_carriage_return=true yakuake_resize_chrome=true terminal_text_cursor=true no_diagonal_cursors=true application_icon=true dialogs_above_terminal=true settings_geometry_bounded=true transient_resize_suppressed=true session_focus_deferred=true deferred_focus_owned=true live_window_mode_switch=true layer_keyboard_on_demand=true staged_layer_unmap=true settings_zig=true settings_accessible=true transient_accessible=true save_errors_visible=true packed_rows=true dirty_spans=true frame_clock=true pty_event_source=true mapped_full_stack=true mapped_stability=true native_renderer=true native_renderer_default=true native_host_override=true native_grid=true native_grid_workspace=true native_grid_clipboard=true native_grid_notification=true native_grid_noctalia_ipc=true native_grid_shortcut=true native_grid_tab_rename=true native_grid_theme=true native_grid_project=true native_grid_maintenance=true native_grid_hot_session=true native_grid_profile_preset=true native_grid_launch_profile=true native_grid_command_palette=true native_grid_tab_color=true native_grid_settings_stacking=true native_grid_note_overlay=true native_grid_tab_navigation=true native_grid_terminal_chords=true native_grid_wayland=true native_grid_x11=true native_grid_sharing_scope=true native_grid_sharing_recovery=true native_grid_pane_scrollbar=true native_grid_reorder=true native_grid_layout=true native_grid_layout_qualification=true native_grid_installed_continuity=true native_grid_authenticated_agent=true native_grid_oom=true native_grid_fairness=true native_grid_network=true native_grid_failure_injection=true native_grid_portability=true native_grid_release=true native_grid_differential=true native_grid_pane_identity=true native_grid_project_actions=true native_grid_launch_profile_gui=true native_grid_command_palette_rename=true native_grid_shortcut_menu=true native_grid_visual_profile=true native_grid_emoji=true native_grid_process_tree=true native_grid_single_instance=true native_grid_state_recovery=true native_grid_recovery_notice=true native_grid_workspace_activation=true native_grid_tab_indicator=true native_grid_focus=true native_grid_close_preflight=true native_grid_share=true native_grid_smart_filter=true native_grid_reflow=true native_grid_resize_osd=true native_grid_pane_scrollbar=true native_grid_gtk=true native_grid_logic_zig=true native_grid_abi=true'
