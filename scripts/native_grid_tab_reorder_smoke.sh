#!/usr/bin/env sh
set -eu

./scripts/require_isolated_display.sh --dedicated
if [ -z "${DISPLAY:-}" ]; then
  echo 'native_grid_tab_reorder_smoke error=dedicated_xwayland_required' >&2
  exit 2
fi

export LC_ALL=C
command -v xdotool >/dev/null 2>&1 || {
  printf 'native_grid_tab_reorder_smoke error=xdotool_not_found\n' >&2
  exit 1
}
test -n "${DISPLAY:-}" || {
  printf 'native_grid_tab_reorder_smoke error=x11_display_not_found\n' >&2
  exit 1
}

ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-binaries

log=$(mktemp /tmp/dintty-tab-reorder.XXXXXX)
pid=
cleanup() {
  xdotool mouseup 1 >/dev/null 2>&1 || true
  if test -n "$pid" && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -f "$log"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

NO_AT_BRIDGE=1 GTK_MODULES= G_DEBUG=fatal-warnings GDK_BACKEND=x11 \
  ./zig-out/bin/dintty-smoke --native-grid-tab-reorder-smoke \
  >"$log" 2>&1 &
pid=$!

ready=
attempt=0
while test "$attempt" -lt 80; do
  ready=$(grep '^native_grid_tab_reorder_ready ' "$log" 2>/dev/null | tail -1 || true)
  test -n "$ready" && break
  kill -0 "$pid" 2>/dev/null || break
  attempt=$((attempt + 1))
  sleep 0.05
done

if test -z "$ready"; then
  cat "$log" >&2
  printf 'native_grid_tab_reorder_smoke error=drag_target_not_ready\n' >&2
  exit 1
fi

field() {
  printf '%s\n' "$ready" | awk -v key="$1" '{
    for (field_index = 1; field_index <= NF; field_index++) {
      split($field_index, pair, "=")
      if (pair[1] == key) { print pair[2]; exit }
    }
  }'
}

source_x=$(field source_x)
source_y=$(field source_y)
target_x=$(field target_x)
target_y=$(field target_y)
mid_x=$(((source_x + target_x) / 2))
mid_y=$(((source_y + target_y) / 2))

window=
attempt=0
while test "$attempt" -lt 40; do
  candidate=$(xdotool search --onlyvisible --pid "$pid" \
    --name '^DINTTY native grid$' 2>/dev/null | head -1 || true)
  if test -n "$candidate" && \
      test "$(xdotool getwindowpid "$candidate" 2>/dev/null || true)" = "$pid"; then
    window=$candidate
    break
  fi
  attempt=$((attempt + 1))
  sleep 0.05
done
if test -z "$window" || test "$(xdotool getwindowpid "$window" 2>/dev/null || true)" != "$pid"; then
  cat "$log" >&2
  printf 'native_grid_tab_reorder_smoke error=window_not_owned\n' >&2
  exit 1
fi

activate_attempt=0
while test "$activate_attempt" -lt 20; do
  xdotool windowraise "$window" 2>/dev/null || true
  xdotool windowactivate --sync "$window" 2>/dev/null || true
  test "$(xdotool getactivewindow 2>/dev/null || true)" = "$window" && break
  activate_attempt=$((activate_attempt + 1))
  sleep 0.05
done
if test "$(xdotool getactivewindow 2>/dev/null || true)" != "$window"; then
  cat "$log" >&2
  printf 'native_grid_tab_reorder_smoke error=window_not_active\n' >&2
  exit 1
fi

if ! kill -0 "$pid" 2>/dev/null || \
    test "$(xdotool getwindowpid "$window" 2>/dev/null || true)" != "$pid"; then
  cat "$log" >&2
  printf 'native_grid_tab_reorder_smoke error=window_lost_before_drag\n' >&2
  exit 1
fi
if ! xdotool mousemove --sync "$source_x" "$source_y" 2>/dev/null || \
    ! xdotool mousedown 1 2>/dev/null; then
  cat "$log" >&2
  printf 'native_grid_tab_reorder_smoke error=pointer_press_failed\n' >&2
  exit 1
fi
sleep 0.10
if ! xdotool mousemove --sync "$mid_x" "$mid_y" 2>/dev/null; then
  cat "$log" >&2
  printf 'native_grid_tab_reorder_smoke error=pointer_midpoint_failed\n' >&2
  exit 1
fi
sleep 0.12
if ! xdotool mousemove --sync "$target_x" "$target_y" 2>/dev/null; then
  cat "$log" >&2
  printf 'native_grid_tab_reorder_smoke error=pointer_target_failed\n' >&2
  exit 1
fi
sleep 0.20
if ! xdotool mouseup 1 2>/dev/null; then
  cat "$log" >&2
  printf 'native_grid_tab_reorder_smoke error=pointer_release_failed\n' >&2
  exit 1
fi

if wait "$pid"; then
  status=0
else
  status=$?
fi
pid=
output=$(cat "$log")
printf '%s\n' "$output"
test "$status" -eq 0 || exit "$status"
printf '%s\n' "$output" | grep -q '^native_grid_tab_reorder_smoke pointer_drag=true pointer_press=true pointer_drop=true forward=true tabs=3 active_identity=true model_order=true snapshot_order=true persistence_coalesced=true exited=true$'
