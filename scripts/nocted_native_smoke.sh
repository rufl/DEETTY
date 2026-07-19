#!/usr/bin/env sh
set -eu

lifecycle_root=$(pwd -P)
lifecycle_mode=1
if [ "${NOCTED_SKIP_PROJECT_LIFECYCLE:-0}" = 1 ]; then
  lifecycle_root=
  lifecycle_mode=0
fi
if [ "${1:-}" = --project-lifecycle ]; then
  lifecycle_mode=1
  shift
fi
if [ "$#" -eq 0 ]; then
  zig build nocted-smoke-binary --global-cache-dir .zig-cache/global
  binary=./zig-out/bin/nocted-smoke
else
  binary=$1
fi
backend=${NOCTED_GDK_BACKEND:-x11}
resource_mode=${NOCTED_QUALIFICATION_SMOKE:-0}
if [ "${2:-}" = --qualification ]; then
  resource_mode=1
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-native-smoke.XXXXXX")

cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
}
trap cleanup EXIT HUP INT TERM

if [ "$lifecycle_mode" = 1 ] && [ -z "$lifecycle_root" ]; then
  lifecycle_root=$(pwd -P)
fi

mkdir -p \
  "$scratch/config/nocted/imported-language-specs" \
  "$scratch/project/src" \
  "$scratch/search-project/src"
printf '%s\n' \
  'version=1' \
  'syntax_prompt_done=true' \
  'sidebar_visible=true' \
  'minimap_visible=true' \
  'code_folding_enabled=true' \
  >"$scratch/config/nocted/settings.conf"
printf '%s\n' \
  'const std = @import("std");' \
  '' \
  'pub fn helper() void {' \
  '    const message = "other file";' \
  '    std.debug.print("{s}\\n", .{message});' \
  '}' \
  >"$scratch/project/src/other.zig"
printf '%s\n' \
  'const std = @import("std");' \
  '' \
  'pub fn build() void {' \
  '    const enabled = true;' \
  '    if (enabled) {' \
  '        std.debug.print("fold one\\n", .{});' \
  '    }' \
  '}' \
  '' \
  'pub fn second() void {' \
  '    const count = 2;' \
  '    if (count > 1) {' \
  '        std.debug.print("fold two λ\\n", .{});' \
  '    }' \
  '}' \
  >"$scratch/project/src/sample.zig"
many_index=0
while [ "$many_index" -lt 72 ]; do
  printf 'const smoke_match_%02d = true;\n' "$many_index"
  many_index=$((many_index + 1))
done >"$scratch/project/src/many.zig"
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<language id="task-note" name="Stale Task Notes" version="2.0" _section="Source">' \
  '  <metadata><property name="globs">*.note</property></metadata>' \
  '  <definitions><context id="task-note"/></definitions>' \
  '</language>' \
  >"$scratch/config/nocted/imported-language-specs/task-note.lang"
printf '%s\n' \
  '{' \
  '  "name": "Task Notes",' \
  '  "scopeName": "source.task-note",' \
  '  "fileTypes": ["note"],' \
  '  "patterns": [' \
  '    {"match": "\\\\b(TODO|DONE)\\\\b", "name": "keyword.control.task"},' \
  '    {"begin": "#", "end": "$", "name": "comment.line.number-sign"}' \
  '  ]' \
  '}' \
  >"$scratch/task-notes.tmLanguage.json"
printf '%s\n' \
  'TODO prove imported highlighting' \
  '# native rendered grammar receipt' \
  >"$scratch/project/src/imported.note"

printf '%s\n' \
  'const qualification_search_marker = "rank target";' \
  'pub fn rankTarget() []const u8 { return qualification_search_marker; }' \
  >"$scratch/search-project/src/rank-target.zig"
group_index=0
qualification_index=0
while [ "$group_index" -lt 8 ]; do
  group_path=$(printf '%s/group_%02d' "$scratch/search-project/src" "$group_index")
  mkdir -p "$group_path"
  group_file=0
  while [ "$group_file" -lt 32 ]; do
    fixture_path=$(printf '%s/qual-file-%03d.zig' "$group_path" "$qualification_index")
    {
      printf 'const qualification_search_marker = %s;\n' "$qualification_index"
      filler_line=0
      while [ "$filler_line" -lt 96 ]; do
        printf 'const qualification_filler_%03d_%03d = "bounded native search load";\n' \
          "$qualification_index" "$filler_line"
        filler_line=$((filler_line + 1))
      done
    } >"$fixture_path"
    qualification_index=$((qualification_index + 1))
    group_file=$((group_file + 1))
  done
  group_index=$((group_index + 1))
done

if output=$(env \
  XDG_CONFIG_HOME="$scratch/config" \
  GDK_BACKEND="$backend" \
  NO_AT_BRIDGE=1 \
  G_DEBUG=fatal-warnings \
  NOCTED_QUALIFICATION_SMOKE="$resource_mode" \
  NOCTED_PROJECT_LIFECYCLE_ROOT="$lifecycle_root" \
  NOCTED_SEARCH_LOAD_ROOT="$scratch/search-project" \
  NOCTED_SMOKE_SAVE_AS="$scratch/project/src/created.zig" \
  NOCTED_SMOKE_TEXTMATE_GRAMMAR="$scratch/task-notes.tmLanguage.json" \
  NOCTED_SMOKE_TEXTMATE_DOCUMENT="$scratch/project/src/imported.note" \
  NOCTED_SMOKE_PREVIEW=quick-open \
  NOCTED_SMOKE_SCREENSHOT="$scratch/quick-open.png" \
  "$binary" \
  --smoke \
  --project "$scratch/project" \
  --open "$scratch/project/src/sample.zig" 2>&1); then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'nocted_native_smoke_diagnostic pass=1' >/dev/null
printf '%s\n' "$output" | grep -F \
  'nocted_search_load_qualification pass=1 cycles=8' >/dev/null
printf '%s\n' "$output" | grep -F \
  'ranking_queries=3 ranking_cycles=8 ranking_deterministic=true' >/dev/null
printf '%s\n' "$output" | grep -F \
  'foreground_lane=true scan_lane=true worker_drained=1' >/dev/null
for field in \
  'project_activation=1' \
  'project_tree_lazy=1' \
  'project_delta_fallbacks=0' \
  'external_clean_reload=1' \
  'external_dirty_keep=1' \
  'multi_selection=1' \
  'multi_selection_undo=1' \
  'multi_selection_rendered=1' \
  'fold=1' \
  'unfold=1' \
  'folded_save=1' \
  'folded_edit_restore=1' \
  'fold_undo_preserved=1' \
  'folding_configurable=1' \
  'find_in_files=1' \
  'search_snapshot_first=1' \
  'search_batch_peak=2' \
  'search_batch_cap=2' \
  'worker_lanes=2' \
  'project_search_activation=1' \
  'multi_file_tabs=1' \
  'tab_navigation=1' \
  'close_other=1' \
  'close_all=1' \
  'document_reopen=1' \
  'untitled=1' \
  'untitled_dirty=1' \
  'save_as=1' \
  'save_as_collision=1' \
  'save_as_atomic=1' \
  'save_as_language=1' \
  'tree_sitter=1' \
  'quick_open=1' \
  'quick_open_bounded=1' \
  'quick_open_activation=1' \
  'session_persist=1' \
  'session_restore=1' \
  'recent_project=1' \
  'textmate_import=1' \
  'textmate_language=1' \
  'textmate_rendered=1' \
  'textmate_precedence=1' \
  'textmate_malformed_rejected=1'; do
  printf '%s\n' "$output" | grep -F "$field" >/dev/null
done
printf '%s\n' "$output" | grep -E 'project_delta_updates=[1-9][0-9]*' >/dev/null
printf '%s\n' "$output" | grep -E 'project_delta_added=[1-9][0-9]*' >/dev/null
printf '%s\n' "$output" | grep -F 'minimap_overlay_translucent=true' >/dev/null
printf '%s\n' "$output" | grep -F 'rendered=true' >/dev/null
if [ "$resource_mode" = 1 ]; then
  printf '%s\n' "$output" | grep -F 'nocted_resource_smoke pass=1 cycles=8 queue_cap=64' >/dev/null
  printf '%s\n' "$output" | grep -F 'worker_drained=1 project_drained=1' >/dev/null
fi
test "$(cat "$scratch/project/src/created.zig")" = 'const smoke_created = true;'
if [ "$lifecycle_mode" = 0 ]; then
  grep -F "project=$scratch/project" "$scratch/config/nocted/session.conf" >/dev/null
  grep -F "recent=$scratch/project" "$scratch/config/nocted/session.conf" >/dev/null
else
  printf '%s\n' "$output" | grep -F \
    'nocted_project_monitor_qualification pass=1 burst_cycles=8 files_per_burst=12' >/dev/null
  printf '%s\n' "$output" | grep -F 'bounded_fallbacks=1' >/dev/null
  printf '%s\n' "$output" | grep -F \
    'exact_index=true actual_gio_burst=true overflow_admission_injected=true overflow_full_scan=true worker_drained=1 project_drained=1' >/dev/null
  printf '%s\n' "$output" | grep -F \
    'nocted_project_real_project_qualification pass=1 cycles=8' >/dev/null
  printf '%s\n' "$output" | grep -F \
    'retained_real_project=true gtk_tree_draw=true worker_drained=1 project_drained=1' >/dev/null
  printf '%s\n' "$output" | grep -F \
    'nocted_project_lifecycle_teardown pass=1 callback_after_widget=true late_callback_ignored=1 source_scheduled=0 worker_drained=1' >/dev/null
fi
grep -F "open=$scratch/project/src/sample.zig" "$scratch/config/nocted/session.conf" >/dev/null
grep -F 'name="Task Notes"' \
  "$scratch/config/nocted/imported-language-specs/task-note.lang" >/dev/null
! grep -F 'Stale Task Notes' \
  "$scratch/config/nocted/imported-language-specs/task-note.lang" >/dev/null
test -s "$scratch/quick-open.png"
if [ -n "${NOCTED_CAPTURE_OUTPUT:-}" ]; then
  cp "$scratch/quick-open.png" "$NOCTED_CAPTURE_OUTPUT"
fi

scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"
echo "nocted_native_gate rendered=true tree_sitter=true folding=true minimap_overlay_translucent=true find_in_files=true project_search_activation=true multi_file_tabs=true tab_navigation=true close_other=true close_all=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true warning_fatal=true backend=$backend scratch_clean=true"
echo "nocted_search_load_native_gate search_load=true cycles=8 first_result_latency=true completion_latency=true cancellation_latency=true ui_draw_latency=true open_under_search=true save_under_refresh=true deterministic_ranking=true warning_fatal=true backend=$backend scratch_clean=true"
if [ "$lifecycle_mode" = 1 ]; then
  echo "nocted_project_lifecycle_gate backend=$backend real_project=true cycles=8 gtk_tree_draw=true model_latency=true draw_latency=true monitor_burst=true burst_cycles=8 files_per_burst=12 publication_latency=true overflow_recovery=true late_callback_guard=true worker_drained=true scratch_clean=true"
fi
