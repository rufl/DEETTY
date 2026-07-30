#!/usr/bin/env sh
set -eu

NOCTED_GDK_BACKEND=x11 ./scripts/nocted_native_smoke.sh "$@"
NOCTED_GDK_BACKEND=wayland ./scripts/nocted_native_smoke.sh "$@"
echo "nocted_native_matrix x11=true wayland=true folding=true editor_zoom=true find_in_files=true multi_file=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true session_dirty_restore=true hot_exit=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true real_project=true lifecycle_cycles=8 gtk_tree_draw=true model_latency=true draw_latency=true monitor_burst=true burst_cycles=8 files_per_burst=12 publication_latency=true overflow_recovery=true late_callback_guard=true worker_drained=true warning_fatal=true scratch_clean=true"
echo "nocted_search_load_native_matrix x11=true wayland=true cycles=8 first_result_latency=true completion_latency=true cancellation_latency=true ui_draw_latency=true open_under_search=true save_under_refresh=true deterministic_ranking=true gtk_batch_bounded=true worker_drained=true warning_fatal=true scratch_clean=true"
