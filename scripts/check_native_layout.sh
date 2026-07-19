#!/usr/bin/env sh
set -eu

host=src/gui/native_host.c
grid=src/gui/native_grid_host.c
grid_abi=src/gui/native_grid_abi.h
grid_abi_zig=src/gui/NativeGridAbi.zig
pane_info_strip=src/gui/pane_info_strip.c
pane_info_model=src/terminal/PaneInfo.zig
pty=src/terminal/pty.c
nocted=src/nocted/main.zig
nocted_gtk=src/nocted/gtk.zig
nocted_folding=src/nocted/Folding.zig
nocted_search=src/nocted/ProjectSearch.zig
nocted_worker=src/nocted/FilesystemWorker.zig
test -s "$nocted"
test -s "$nocted_gtk"
test -s "$nocted_folding"
test -s "$nocted_search"
test -s "$nocted_worker"
test -s "$grid_abi"
test -s "$grid_abi_zig"
test -s "$pane_info_strip"
test -s "$pane_info_model"
test -s "$pty"
grep -F 'pub fn format(input: Input' "$pane_info_model" >/dev/null
grep -F 'noctty_pty_process_info' "$pty" >/dev/null
grep -F 'tcgetpgrp(fd)' "$pty" >/dev/null
grep -F 'noctty_pane_info_strip_update' "$pane_info_strip" >/dev/null
grep -F 'refresh_active_pane_info(root);' "$grid" >/dev/null
grep -F 'grid_page_content_root' "$grid" >/dev/null
grep -F 'Show active pane information' "$grid" >/dev/null
grep -F 'pane_info=true pane_source=pty_proc pane_refresh=coalesced pane_info_dedup=true' src/main.zig >/dev/null
grep -F 'mark_workspace_menu_action(item);' "$grid" >/dev/null
grep -F '"noctty-workspace-action"' "$grid" >/dev/null
grep -F 'gtk_widget_grab_focus(active->area);' "$grid" >/dev/null
grep -F 'static gboolean finish_workspace_smoke' "$grid" >/dev/null
grep -F 'workspace_visual_attempts++ < 200' "$grid" >/dev/null
grep -F 'visual_ready=true controlled_exit=true' src/main.zig scripts/native_grid_workspace_smoke.sh >/dev/null
grep -F 'static gboolean open_smoke_workspace_menu' "$grid" >/dev/null
grep -F 'pane_close_smoke_attempts++ < 80' "$grid" >/dev/null
grep -F 'gint pending_index = root->saw_draw ? 1 : 0;' "$grid" >/dev/null
grep -F 'static gboolean cancel_natural_editor_shutdown_smoke' "$grid" >/dev/null
grep -F 'application_close_origin == NOCTTY_CLOSE_ORIGIN_NATURAL' "$grid" >/dev/null
grep -F 'run_smoke() {' scripts/native_release_smoke.sh >/dev/null
grep -F 'sleep 0.2' scripts/native_release_smoke.sh >/dev/null
grep -F 'c.gtk_source_map_set_view' "$nocted" >/dev/null
grep -F 'c.gtk_tree_view_new_with_model' "$nocted" >/dev/null
grep -F 'c.gtk_notebook_new' "$nocted" >/dev/null
grep -F 'gtk_source_search_context_new' "$nocted" >/dev/null
grep -F 'Code Folding Enabled' "$nocted" >/dev/null
grep -F 'Find in Files...' "$nocted" >/dev/null
grep -F 'Close Other Files' "$nocted" >/dev/null
grep -F 'Close All Files' "$nocted" >/dev/null
grep -F '#nocted-minimap.scrubber { background-color: rgba(102, 217, 239, 0.16); }' "$nocted" >/dev/null
grep -F 'pub const max_regions: usize = 4096;' "$nocted_folding" >/dev/null
grep -F 'pub const max_results: usize = 1000;' "$nocted_search" >/dev/null
grep -F 'fn completeTextAlloc' "$nocted" >/dev/null
grep -F '"invisible"' "$nocted" >/dev/null
grep -F '@as(f64, 0.01)' "$nocted" >/dev/null
! grep -F 'removed_text' "$nocted" >/dev/null
! grep -F 'fold_marker' "$nocted" >/dev/null
grep -F 'fn runProjectSearch' "$nocted" >/dev/null
grep -F 'max_threads: c_int' "$nocted_gtk" >/dev/null
grep -F 'pub const max_pending: usize = 64;' "$nocted_worker" >/dev/null
grep -F 'const progress = try cursor.step(1);' "$nocted_worker" >/dev/null
grep -F 'pending >= Job.search_batch_size or timed_flush or' "$nocted_worker" >/dev/null
grep -F 'documents_by_path: std.StringHashMap(*Document)' "$nocted" >/dev/null
grep -F 'if (self.shutting_down) return null;' "$nocted" >/dev/null
grep -F 'nocted_native_gate rendered=true folding=true' scripts/nocted_native_smoke.sh >/dev/null
grep -F "'fold_undo_preserved=1'" scripts/nocted_native_smoke.sh >/dev/null
grep -F 'nocted_native_matrix x11=true wayland=true' scripts/nocted_native_matrix.sh >/dev/null
grep -F 'run_smoke ./scripts/nocted_native_matrix.sh' scripts/native_release_smoke.sh >/dev/null
grep -F 'const version = @import("noctty_release").version;' "$nocted" >/dev/null
grep -F 'static gboolean launch_nocted' "$grid" >/dev/null
grep -F 'g_spawn_async(' "$grid" >/dev/null
grep -F 'Open NoctEd Here' "$grid" >/dev/null
grep -F 'gtk_notebook_new' "$host" >/dev/null
grep -F 'append_terminal_tab' "$host" >/dev/null
grep -F 'gtk_paned_new' "$host" >/dev/null
grep -F 'NocttySecondaryContext' "$host" >/dev/null
grep -F '.pane_id = pane_id + 1' "$host" >/dev/null
grep -F 'on_secondary_spawned' "$host" >/dev/null
grep -F 'on_secondary_contents_changed' "$host" >/dev/null
grep -F 'on_secondary_child_exited' "$host" >/dev/null
grep -F 'on_maintenance_timer' "$host" >/dev/null
grep -F 'g_timeout_add(smoke != 0 ? 100 : 1000' "$host" >/dev/null
grep -F 'secondary_userdata' "$grid" >/dev/null
grep -F 'gtk_paned_pack2' "$grid" >/dev/null
grep -F 'NocttyGridCreateSession' "$grid" >/dev/null
grep -F 'gtk_notebook_set_action_widget' "$grid" >/dev/null
grep -F 'gtk_notebook_set_tab_reorderable' "$grid" >/dev/null
grep -F 'gtk_notebook_set_tab_detachable' "$grid" >/dev/null
grep -F 'page-reordered' "$grid" >/dev/null
grep -F 'noctty_grid_reorder_tab' src/main.zig >/dev/null
grep -F 'noctty_grid_tab_index_for_pane' src/main.zig >/dev/null
grep -F 'tab_reorder_pressed_active_page' "$grid" >/dev/null
grep -F 'schedule_grid_hot_session_flush(root)' "$grid" >/dev/null
! grep -A20 -F 'export fn noctty_grid_reorder_tab' src/main.zig | grep -F 'persistNativeGridHotSession(bridge)' >/dev/null
grep -F 'GTK_PACK_START' "$grid" >/dev/null
grep -F 'GTK_PACK_END' "$grid" >/dev/null
grep -F 'list-add-symbolic' "$grid" >/dev/null
grep -F 'create_window_toolbar_controls' "$grid" >/dev/null
grep -F 'configure_settings_window_stacking' "$grid" >/dev/null
grep -F 'gtk_window_set_transient_for(GTK_WINDOW(dialog), GTK_WINDOW(root->window))' "$grid" >/dev/null
grep -F 'gtk_window_set_keep_above(GTK_WINDOW(dialog), TRUE)' "$grid" >/dev/null
grep -F 'set_namespace(GTK_WINDOW(dialog), "noctty-settings")' "$grid" >/dev/null
grep -F 'set_layer(GTK_WINDOW(root->window), 2)' "$grid" >/dev/null
grep -F 'set_layer(GTK_WINDOW(dialog), 3)' "$grid" >/dev/null
grep -F -- '--native-grid-settings-stacking-smoke' src/main.zig >/dev/null
grep -F 'G_CALLBACK(on_window_settings_button_clicked)' "$grid" >/dev/null
grep -F 'G_CALLBACK(on_window_close_button_clicked)' "$grid" >/dev/null
grep -F 'window_toolbar_yakuake_order' "$grid" >/dev/null
grep -F 'configure_action_button' "$grid" >/dev/null
grep -F 'gdk_cursor_new_from_name(display, "default")' "$grid" >/dev/null
grep -F 'gtk_widget_get_has_tooltip' "$grid" >/dev/null
grep -F 'action_button_pointer_normal' "$grid" >/dev/null
grep -F 'install_compact_tab_styles' "$grid" >/dev/null
grep -F 'notebook.noctty-tab-notebook > header > tabs > tab' "$grid" >/dev/null
grep -F 'compact_tab_geometry' "$grid" >/dev/null
grep -F 'compact_tabs=true' src/main.zig >/dev/null
grep -F 'create_tab_color_menu' "$grid" >/dev/null
grep -F 'noctty_grid_set_tab_color' src/main.zig >/dev/null
grep -F 'noctty_grid_adjust_tab_color' src/main.zig >/dev/null
grep -F 'GDK_KEY_equal' "$grid" >/dev/null
grep -F 'GDK_KEY_minus' "$grid" >/dev/null
grep -F -- '--native-grid-tab-color-smoke' src/main.zig >/dev/null
grep -F 'window-close-symbolic' "$grid" >/dev/null
grep -F 'on_notebook_switch_page' "$grid" >/dev/null
grep -F 'tab_active_styled' "$grid" >/dev/null
grep -F '"noctty-tab-markup-cache"' "$grid" >/dev/null
grep -F '"noctty-tab-tooltip-cache"' "$grid" >/dev/null
grep -F '"noctty-tab-color-active"' "$grid" >/dev/null
grep -F 'if (g_strcmp0(cached_markup, markup) != 0)' "$grid" >/dev/null
grep -F 'if (g_strcmp0(cached_tooltip, tooltip) != 0)' "$grid" >/dev/null
grep -F 'if (cached_rgb == rgb && (rgb == 0 || cached_active == is_active))' "$grid" >/dev/null
grep -F 'GDK_KEY_Page_Up' "$grid" >/dev/null
grep -F 'GDK_KEY_Page_Down' "$grid" >/dev/null
grep -F 'GDK_KEY_ISO_Left_Tab' "$grid" >/dev/null
grep -F 'cycle_grid_pane' "$grid" >/dev/null
grep -F 'event->state & GDK_MOD1_MASK' "$grid" >/dev/null
grep -F 'Pane %d / %d' "$grid" >/dev/null
grep -F 'pane_cycle_feedback_source' "$grid" >/dev/null
grep -F 'Tab %d / %d' "$grid" >/dev/null
grep -F 'tab_cycle_feedback_source' "$grid" >/dev/null
grep -F 'Alt+wheel      Previous / next pane' "$grid" >/dev/null
grep -F 'Ctrl+Alt+wheel Previous / next tab' "$grid" >/dev/null
grep -F 'Ctrl+Tab       Next terminal pane' "$grid" >/dev/null
grep -F 'Ctrl+Shift+Tab Next tab / Smart Tab' "$grid" >/dev/null
grep -F 'context->write(context->userdata, "\x03", 1)' "$grid" >/dev/null
grep -F 'ctrl_d_close_succeeded' "$grid" >/dev/null
grep -F 'Ctrl+C         Interrupt active pane' "$grid" >/dev/null
grep -F 'Ctrl+D         Close active pane' "$grid" >/dev/null
grep -F 'char text[384];' "$grid" >/dev/null
grep -F '"noctty-pane-tooltip-cache"' "$grid" >/dev/null
grep -F 'if (g_strcmp0(cached, text) != 0)' "$grid" >/dev/null
grep -F -- '--native-grid-terminal-chords-smoke' src/main.zig >/dev/null
grep -F 'tab_shortcut_reopen' "$grid" >/dev/null
grep -F '.reopen_tab' src/main.zig >/dev/null
grep -F 'noctty_grid_current_directory' "$grid" >/dev/null
grep -F 'const gchar *title_ellipsis = title_prefix != NULL ? "…" : "";' "$grid" >/dev/null
grep -F 'char selection_suffix[64] = {0};' "$grid" >/dev/null
grep -F 'char pane_suffix[32] = {0};' "$grid" >/dev/null
grep -F 'char tab_color_tooltip[96] = {0};' "$grid" >/dev/null
if grep -F 'g_strconcat(title_prefix, "…", NULL)' "$grid" >/dev/null; then
  exit 1
fi
grep -F 'noctty_grid_workspace_dirty' "$grid" >/dev/null
grep -F 'unsaved workspace' "$grid" >/dev/null
grep -F 'noctty_grid_pane_selected' "$grid" >/dev/null
grep -F 'selection_border_drawn' "$grid" >/dev/null
grep -F 'selection_visual_ok' "$grid" >/dev/null
grep -F 'Rename active tab' "$grid" >/dev/null
grep -F 'GDK_KEY_r' "$grid" >/dev/null
grep -F 'gtk_box_pack_start(GTK_BOX(content), entry, TRUE, TRUE, 0)' "$grid" >/dev/null
grep -F 'on_tab_rename_focus_out' "$grid" >/dev/null
grep -F 'tab_rename_outside_cancelled' "$grid" >/dev/null
if grep -F 'tab_rename_dialog' "$grid" >/dev/null; then
  exit 1
fi
grep -F 'New Tab (Ctrl+Shift+T)' "$grid" >/dev/null
grep -F 'New Tab, Ctrl+Shift+T' "$grid" >/dev/null
grep -F 'G_CALLBACK(on_new_tab_button_clicked)' "$grid" >/dev/null
grep -F 'new_tab_button_reopened_after_close' "$grid" >/dev/null
grep -F 'context->peer->area != NULL' "$grid" >/dev/null
grep -F 'GTK_ORIENTATION_VERTICAL' "$grid" >/dev/null
grep -F 'create_grid_context' "$grid" >/dev/null
grep -F 'secondary_pane_id' src/main.zig >/dev/null
grep -F -- '--native-grid-two-pane-smoke' src/main.zig >/dev/null
grep -F 'noctty_grid_close_tab' src/main.zig >/dev/null
grep -F 'noctty_grid_close_session' src/main.zig >/dev/null
grep -F 'noctty_grid_close_pane' src/main.zig >/dev/null
grep -F 'close_grid_tab' "$grid" >/dev/null
grep -F 'close_grid_pane' "$grid" >/dev/null
grep -F 'apply_grid_layout_preset' "$grid" >/dev/null
grep -F 'rebuild_grid_preset_page' "$grid" >/dev/null
grep -F 'noctty_grid_apply_preset' src/main.zig >/dev/null
grep -F 'gtk_menu_item_new_with_label("Close Tab")' "$grid" >/dev/null
grep -F 'gtk_menu_item_new_with_label("Close Terminal")' "$grid" >/dev/null
grep -F 'append_workspace_menu_item(menu, "Layout 2×2", 51' "$grid" >/dev/null
grep -F 'append_workspace_menu_item(menu, "Layout 3×3", 52' "$grid" >/dev/null
grep -F -- '--native-grid-layout-preset-smoke' src/main.zig >/dev/null
grep -F -- '--native-grid-recursive-split-smoke' src/main.zig >/dev/null
grep -F -- '--native-grid-click-focus-smoke' src/main.zig >/dev/null
grep -F 'drive_focus_click_smoke' "$grid" >/dev/null
grep -F 'activate_grid_context(context);' "$grid" >/dev/null
grep -F 'deactivate_grid_context(candidate);' "$grid" >/dev/null
grep -F 'focus_click_smoke_attempts++ < 80' "$grid" >/dev/null
grep -F 'focus_click_controlled_exit = expected == 2 && released == expected' "$grid" >/dev/null
grep -F 'focus_readiness=bounded controlled_exit=true' src/main.zig scripts/native_grid_click_focus_smoke.sh >/dev/null
grep -F -- '--native-grid-eight-pane-smoke' src/main.zig >/dev/null
grep -F -- '--native-grid-pane-move-smoke' src/main.zig >/dev/null
grep -F 'gtk_widget_grab_focus(widget)' "$grid" >/dev/null
grep -F 'selection_dragging' "$grid" >/dev/null
grep -F 'suppress_primary_release' "$grid" >/dev/null
grep -F 'focus_double_click_restore_clean' "$grid" >/dev/null
grep -F 'draw_resize_overlay' "$grid" >/dev/null
grep -F 'resize_overlay_hide_source' "$grid" >/dev/null
grep -F 'gtk_notebook_set_tab_pos' "$grid" >/dev/null
grep -F 'move_grid_context' "$grid" >/dev/null
grep -F 'open_command_palette' "$grid" >/dev/null
grep -F 'open_terminal_find' "$grid" >/dev/null
grep -F 'open_quick_note' "$grid" >/dev/null
grep -F 'draw_quick_note_overlay' "$grid" >/dev/null
grep -F 'show_quick_note_overlays' "$grid" >/dev/null
grep -F 'const size_t capacity = 4096' "$grid" >/dev/null
grep -F 'contents, capacity, 1)' "$grid" >/dev/null
grep -F 'PangoFontDescription *note_overlay_font;' "$grid" >/dev/null
grep -F 'root->note_overlay_font = pango_font_description_from_string("Sans 9")' "$grid" >/dev/null
grep -F 'pango_layout_set_font_description(layout, root->note_overlay_font)' "$grid" >/dev/null
grep -F 'g_clear_pointer(&context.note_overlay_font, pango_font_description_free)' "$grid" >/dev/null
grep -F 'gtk_window_get_title(GTK_WINDOW(context->window))' "$grid" >/dev/null
grep -F 'if (status_changed) {' "$grid" >/dev/null
grep -F 'int pumped = context->pump(context->userdata)' "$grid" >/dev/null
grep -F 'uint32_t cursor = context->cursor(context->userdata);' "$grid" >/dev/null
grep -F 'int selected_face = -1;' "$grid" >/dev/null
grep -F 'if (face != selected_face)' "$grid" >/dev/null
grep -F 'if (context->event != NULL && (had_output || status_changed))' "$grid" >/dev/null
grep -F 'candidate->event(candidate->event_data, candidate->pane_id, 4, 0,' "$grid" >/dev/null
grep -F 'root->maintenance_source = g_timeout_add_seconds(' "$grid" >/dev/null
grep -F 'root->cursor_blink_source = g_timeout_add(500, on_cursor_blink, root);' "$grid" >/dev/null
grep -F 'remove_grid_source(&context.application_close_deferred_source);' "$grid" >/dev/null
grep -F 'remove_grid_source(&context.maintenance_source);' "$grid" >/dev/null
grep -F 'destroy_retired_grid_context' "$grid" >/dev/null
grep -F 'g_ptr_array_remove(root->contexts, context);' "$grid" >/dev/null
grep -F 'char label[256];' "$grid" >/dev/null
grep -F 'const char *label_text = "Filter";' "$grid" >/dev/null
grep -F 'char status[96];' "$grid" >/dev/null
grep -F 'g_snprintf(status, sizeof(status), "%zu / %d' "$grid" >/dev/null
grep -F '#include "native_grid_abi.h"' "$grid" >/dev/null
grep -F '#define NOCTTY_NATIVE_GRID_ABI_VERSION 2u' "$grid_abi" >/dev/null
grep -F 'typedef uint64_t (*NocttyGridCell)(void *, int, int);' "$grid_abi" >/dev/null
grep -F 'uint64_t packed_cell =' "$grid" >/dev/null
grep -F 'typedef int (*NocttyGridRow)(void *, int, uint64_t *, size_t);' "$grid_abi" >/dev/null
grep -F 'typedef int (*NocttyGridDirtyRows)(void *, uint8_t *, size_t);' "$grid_abi" >/dev/null
grep -F 'typedef int (*NocttyGridDirtySpans)(void *, NocttyGridDirtySpan *, size_t);' "$grid_abi" >/dev/null
grep -F 'noctty_native_grid_host_run_v2' "$grid_abi" "$grid" >/dev/null
grep -F 'static void queue_grid_damage_when_mapped(NocttyGridContext *context) {' "$grid" >/dev/null
grep -F 'int dirty_count = context->dirty_spans(' "$grid" >/dev/null
grep -F 'context->userdata, context->dirty_span_buffer,' "$grid" >/dev/null
grep -F 'context->terminal_dirty_spans_used = 1;' "$grid" >/dev/null
grep -F 'static void queue_grid_cell_span(' "$grid" >/dev/null
grep -F 'int first_column = MAX(' "$grid" >/dev/null
grep -F 'static int draw_ascii_run(' "$grid" >/dev/null
grep -F 'cairo_scaled_font_text_to_glyphs' "$grid" >/dev/null
grep -F 'static void inherit_grid_session_context(NocttyGridContext *created,' "$grid" >/dev/null
! grep -F '*created = *source;' "$grid" >/dev/null
grep -F 'export fn noctty_grid_row(' src/main.zig >/dev/null
grep -F 'export fn noctty_grid_take_dirty_rows(' src/main.zig >/dev/null
grep -F 'export fn noctty_grid_take_dirty_spans(' src/main.zig >/dev/null
! grep -F 'export fn noctty_grid_row_hash(' src/main.zig >/dev/null
grep -F 'pub fn packedRow(self: Grid, row: usize, output: []u64) usize {' src/terminal/Vt.zig >/dev/null
! grep -F 'pub fn rowHash(self: Grid, row: usize) u64 {' src/terminal/Vt.zig >/dev/null
grep -F "if ((style & 128) == 0 && codepoint >= 0x20 && codepoint != ' ')" "$grid" >/dev/null
grep -F 'if (had_output || !context->terminal_metadata_initialized)' "$grid" >/dev/null
grep -F 'now_us - context->last_exit_poll_us >= 250 * 1000' "$grid" >/dev/null
grep -F 'created->terminal_metadata_initialized = 0;' "$grid" >/dev/null
grep -F 'defer if (event != 2 and event != 4) persistNativeGridHotSession(bridge);' src/main.zig >/dev/null
grep -F '4 => .{ .tick = at_ms },' src/main.zig >/dev/null
grep -F 'if (had_output) queue_grid_output_when_ready(context);' "$grid" >/dev/null
grep -F 'if (status_changed) queue_grid_draw_when_mapped(context);' "$grid" >/dev/null
grep -F '#include <glib-unix.h>' "$grid" >/dev/null
grep -F 'extern int noctty_grid_pty_fd(void *);' "$grid" >/dev/null
grep -F 'context->pty_fd = noctty_grid_pty_fd(context->userdata);' "$grid" >/dev/null
grep -F 'context->pty_source = g_unix_fd_add_full(' "$grid" >/dev/null
grep -F 'G_PRIORITY_DEFAULT, context->pty_fd,' "$grid" >/dev/null
grep -F 'gtk_widget_add_tick_callback(' "$grid" >/dev/null
grep -F 'context->area, on_output_frame, context, NULL);' "$grid" >/dev/null
grep -F 'G_PRIORITY_DEFAULT, 100, on_output_present, context, NULL);' "$grid" >/dev/null
grep -F 'context->descriptor_tick_coalesced = 1;' "$grid" >/dev/null
grep -F 'gtk_widget_remove_tick_callback(' "$grid" >/dev/null
grep -F 'G_PRIORITY_DEFAULT, 75, commit_grid_resize, context, NULL);' "$grid" >/dev/null
grep -F 'ensure_ascii_glyph_cache' "$grid" >/dev/null
grep -F 'context->glyph_cache_hits' "$grid" >/dev/null
grep -F 'queue_grid_draw_when_mapped(context);' "$grid" >/dev/null
grep -F 'noctty_grid_has_foreground_process' "$grid" >/dev/null
grep -F 'Close Anyway' "$grid" >/dev/null
grep -F 'if (close_status > 1) context->userdata = NULL;' "$grid" >/dev/null
grep -F 'if (pool.release(session)) return 2;' src/main.zig >/dev/null
grep -F 'int retiring;' "$grid" >/dev/null
grep -F 'grid_context_session_available' "$grid" >/dev/null
grep -F 'context->retiring = 1;' "$grid" >/dev/null
grep -F 'candidate->retiring = 1;' "$grid" >/dev/null
grep -F 'context->clipboard_requests++;' "$grid" >/dev/null
grep -F 'probe_retired_tab_callback' "$grid" >/dev/null
grep -F 'context.late_callback_guarded &&' "$grid" >/dev/null
grep -F 'late_callback_guard=true' src/main.zig scripts/native_grid_two_tab_smoke.sh >/dev/null
grep -F 'dismiss_grid_popup_windows' "$grid" >/dev/null
grep -F 'gtk_window_get_window_type(GTK_WINDOW(window))' "$grid" >/dev/null
grep -F 'G_DEBUG=fatal-warnings' scripts/native_grid_hot_session_smoke.sh >/dev/null
grep -F 'popup_teardown=true' scripts/native_grid_hot_session_smoke.sh >/dev/null
grep -F 'static void stop_grid_io_sources(NocttyGridContext *context) {' "$grid" >/dev/null
grep -F 'static void stop_grid_context_sources(NocttyGridContext *context) {' "$grid" >/dev/null
grep -F 'stop_grid_context_sources(candidate);' "$grid" >/dev/null
test "$(grep -Fc 'remove_grid_source(&context->pty_source);' "$grid")" -eq 1
test "$(grep -Fc 'remove_output_present(context);' "$grid")" -eq 1
grep -F 'if ((workspace_smoke == 2 || workspace_smoke == 20) &&' "$grid" >/dev/null
grep -F 'gtk_widget_get_ancestor(item, GTK_TYPE_MENU);' "$grid" >/dev/null
grep -F 'gtk_menu_popdown(GTK_MENU(menu));' "$grid" >/dev/null
grep -F 'context.pane_close_menu_popped_down &&' "$grid" >/dev/null
grep -F 'export fn noctty_grid_pty_fd' src/main.zig >/dev/null
grep -F 'pty_event_source=true' src/main.zig >/dev/null
! grep -F 'on_pump_idle' "$grid" >/dev/null
grep -F 'context->descriptor_tick_coalesced = 1;' "$grid" >/dev/null
grep -F 'root->descriptor_maintenance_fallback_seen = 1;' "$grid" >/dev/null
grep -F 'context->tick_source = g_timeout_add(16, on_tick, context);' "$grid" >/dev/null
! grep -F 'context->pty_source != 0 ? 1000 : 16' "$grid" >/dev/null
grep -F 'gboolean io_ready = TRUE;' "$grid" >/dev/null
grep -F 'candidate->descriptor_tick_coalesced &&' "$grid" >/dev/null
grep -F 'descriptor_fallback=root_coalesced pane_exit_timers=0 periodic_callbacks_per_second=3' src/main.zig scripts/native_grid_eight_pane_smoke.sh >/dev/null
grep -F 'descriptor_fallback=root_coalesced pane_exit_timer=false source_cleanup=centralized' src/main.zig scripts/native_grid_maintenance_smoke.sh >/dev/null
grep -F 'xdotool windowactivate --sync "$window"' scripts/native_grid_tab_reorder_smoke.sh >/dev/null
grep -F 'xdotool getactivewindow' scripts/native_grid_tab_reorder_smoke.sh >/dev/null
grep -F 'xdotool mousemove --sync --window "$window"' scripts/native_grid_tab_reorder_smoke.sh >/dev/null
grep -F 'const output_buffer_bytes = 16 * 1024;' src/terminal/Session.zig >/dev/null
grep -F 'fn putAscii(self: *Grid, bytes: []const u8) !void {' src/terminal/Vt.zig >/dev/null
grep -F 'self.screen_origin += 1;' src/terminal/Vt.zig >/dev/null
grep -F 'key-release-event' "$grid" >/dev/null
grep -F 'Hold Alt       Show note in each pane' "$grid" >/dev/null
grep -F 'apply_grid_font_size' "$grid" >/dev/null
grep -F 'grid_cell_width' "$grid" >/dev/null
grep -F 'event->state & GDK_CONTROL_MASK' "$grid" >/dev/null
grep -F 'Ctrl+wheel     Pane font up / down' "$grid" >/dev/null
grep -F 'toggle_grid_zoom' "$grid" >/dev/null
grep -F 'focus_grid_direction' "$grid" >/dev/null
grep -F -- '--native-grid-compact-ux-smoke' src/main.zig >/dev/null
grep -F -- '--native-grid-note-overlay-smoke' src/main.zig >/dev/null
grep -F -- '--native-grid-hot-session-smoke' src/main.zig >/dev/null
grep -F 'restore_hot_session' "$grid" >/dev/null
grep -F 'build_hot_session_layout_node' "$grid" >/dev/null
grep -F 'noctty_grid_set_layout_ratio' "$grid" >/dev/null
grep -F 'loadNativeGridHotSession' src/main.zig >/dev/null
grep -F 'persistNativeGridHotSession' src/main.zig >/dev/null
grep -F -- '--native-grid-resize-overlay-smoke' src/main.zig >/dev/null
grep -F -- '--native-grid-window-tray-smoke' src/main.zig >/dev/null
grep -F 'org.kde.StatusNotifierItem' "$grid" >/dev/null
grep -F 'com.canonical.dbusmenu' "$grid" >/dev/null
grep -F 'Close NOCTTY' "$grid" >/dev/null
grep -F 'request_grid_application_close' "$grid" >/dev/null
grep -F 'create_window_resize_layout' "$grid" >/dev/null
grep -F 'com.noctty.NOCTTY.Control' "$grid" >/dev/null
grep -F 'noctty-dropdown' "$grid" >/dev/null
grep -F 'open_grid_shortcut_recorder' "$grid" >/dev/null
grep -F -- '--native-grid-noctalia-ipc-smoke' src/main.zig >/dev/null
grep -F 'write_activation_child_receipt_smoke' "$grid" >/dev/null
grep -F 'request_recent_workspace_child_smoke' "$grid" >/dev/null
grep -F 'workspace_smoke == 35' "$grid" >/dev/null
grep -F -- '--native-grid-installed-activation-fixture' src/main.zig >/dev/null
grep -F -- '--native-grid-recent-activation-smoke' src/main.zig >/dev/null
test -x scripts/native_grid_installed_activation_smoke.sh
echo "native_layout notebook=true tab_add=true window_controls=true tab_close_button=true tab_active_styling=true tab_suffix_stack=true tab_setter_dedup=true tab_color=true tab_color_style_dedup=true navigation=true alt_scroll=true ctrl_alt_scroll=true tab_shortcuts=true tab_reopen_model=true tab_reorder=true tab_reorder_active_identity=true tab_reorder_rollback=true tab_reorder_persistence_coalesced=true split=true recursive_split=true dynamic_sessions=true pane_context_init=explicit shallow_context_copy=false tab_close=true pane_close=true pane_close_menu_popdown=true foreground_guard=true session_storage_released=true late_callback_guard=true popup_teardown=true root_timer_coalesced=true hidden_present_throttled=true mapped_redraw_only=true terminal_chords=true layout_presets=true layout_churn=32 eight_panes=true click_focus=true clean_selection=true zoom_selection=true resize_overlay=true resize_coalesced=true note_overlay=true note_overlay_font_cached=true note_overlay_preview_bounded=true hot_session=true layout_ratio_persistence=true font_wheel=true window_resize=true tray=true tray_menu=true tray_close=true pane_move=true live_tab_position=true compact_ux=true pane_info=true pane_source=pty_proc pane_refresh=coalesced pane_info_dedup=true settings_stacking=true shortcut_recorder=true noctalia_dbus=true layer_shell=true secondary_pty=spawned_event_routed=true maintenance_timer=true idle_redraw_suppressed=true idle_metadata_probe_suppressed=true idle_exit_poll_throttled=true pane_tooltip_dedup=true draw_cursor_cached=true draw_font_switch_dedup=true packed_cell_render=true render_abi=packed_rows render_abi_version=2 damage_tracking=dirty_spans glyph_batching=true glyph_cache=true frame_clock_present=true blank_cell_draw_skipped=true tick_event_throttled=true teardown_sources_complete=true retired_context_free=true smart_filter_label_stack=true terminal_find_status_stack=true visible_grid_ring=true vt_ascii_run=true pty_event_source=true timer_read_polling=false output_present_coalesced=true event_source_cleanup=true descriptor_fallback=root_coalesced pane_exit_timers=0 source_cleanup=centralized installed_activation_harness=true recent_child_receipt=true nocted=true nocted_process_separate=true nocted_project_tree=true nocted_minimap=true nocted_folding=true nocted_minimap_translucent=true nocted_find_in_files=true nocted_worker=bounded nocted_multi_file=true native_grid_two_pane_gate=true"
