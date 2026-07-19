#!/usr/bin/env sh
set -eu

zig build --global-cache-dir .zig-cache/global install smoke-binaries
if output="$(GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
  ./zig-out/bin/noctty-smoke --native-grid-project-editor-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_project_editor_smoke rendered_project=true workspace_saved=true workspace_loaded=true recent_control=true recent_persisted=true context_menu=true menu_survived=true editor_here=true editor_binary=nocted editor_handoff=true editor_process_separate=true directory_listed=true directory_navigated=true compatibility_editor=true rendered_editor=true syntax_highlighting=true syntax_theme=high-contrast reloaded=true file_opened=true edited=true dirty_state=true save_state=true ctrl_s=true file_switch_cancel=true file_switch_save=true file_switch_discard=true close_cancel=true close_discard=true parent_mapped=true saved=true exited=true$'
