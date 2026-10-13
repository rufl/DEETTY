#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

export LC_ALL=C

ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build install smoke-binaries
if output="$(GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
  ./zig-out/bin/noctty-smoke --native-grid-project-editor-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_project_editor_smoke rendered_project=true workspace_saved=true workspace_loaded=true recent_control=true recent_persisted=true summary_scroll=true project_accessible=true context_menu=true menu_survived=true nocted_launch=true editor_binary=nocted editor_handoff=true directory_resolved=true editor_process_separate=true parent_mapped=true exited=true$'
