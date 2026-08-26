#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

binary=${1:-./zig-out/bin/noctty}
case "$binary" in
  /*) ;;
  *) binary="$PWD/${binary#./}" ;;
esac
test -x "$binary"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-state-recovery.XXXXXX")
cleanup() {
  if [ -s "$scratch/pid" ]; then
    pid=$(cat "$scratch/pid")
    kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

NOCTTY_RECOVERY_BINARY=$binary \
NOCTTY_RECOVERY_SCRATCH=$scratch \
sh -eu -c '
  binary=$NOCTTY_RECOVERY_BINARY
  scratch=$NOCTTY_RECOVERY_SCRATCH
  export HOME="$scratch/home"
  export XDG_CONFIG_HOME="$scratch/config"
  export XDG_STATE_HOME="$scratch/state"
  export XDG_CACHE_HOME="$scratch/cache"
  export XDG_DATA_HOME="$scratch/data"
  export GDK_BACKEND=x11
  export NO_AT_BRIDGE=1
  config="$HOME/.config/noctty/settings.nocttycfg"
  themes="$HOME/.config/noctty/themes.nocttythemes"
  workspace="$HOME/.local/state/noctty/autosave/default.nocttyws"
  mkdir -p "$(dirname "$config")" "$(dirname "$workspace")" \
    "$XDG_CACHE_HOME" "$XDG_DATA_HOME"

  process_live() {
    process_id=$1
    test -r "/proc/$process_id/stat" || return 1
    process_state=$(cut -d " " -f 3 "/proc/$process_id/stat" 2>/dev/null) || return 1
    test "$process_state" != Z
  }

  printf "%s" "damaged settings" > "$config"
  printf "%s" "damaged themes" > "$themes"
  printf "%s" "damaged workspace" > "$workspace"

  setsid "$binary" --show >"$scratch/output.log" 2>&1 &
  pid=$!
  printf "%s\n" "$pid" > "$scratch/pid"

  attempt=0
  while [ "$attempt" -lt 120 ]; do
    grep -F "noctty_startup_recovery_notice flags=26" "$scratch/output.log" >/dev/null 2>&1 && break
    kill -0 "$pid" 2>/dev/null || { cat "$scratch/output.log" >&2; exit 1; }
    attempt=$((attempt + 1))
    sleep 0.05
  done
  grep -F "config_defaults=1" "$scratch/output.log" >/dev/null
  grep -F "theme_defaults=1" "$scratch/output.log" >/dev/null
  grep -F "workspace_defaults=1" "$scratch/output.log" >/dev/null
  state=$("$binary" --status)
  printf "%s\n" "$state" | grep -F "running=true" >/dev/null
  printf "%s\n" "$state" | grep -F "visible=true" >/dev/null

  test "$(cat "$config")" = "damaged settings"
  test "$(cat "$themes")" = "damaged themes"
  test "$(cat "$workspace.rejected")" = "damaged workspace"
  test "$(wc -c < "$workspace")" -gt 17

  kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  attempt=0
  while process_live "$pid" && [ "$attempt" -lt 100 ]; do
    attempt=$((attempt + 1))
    sleep 0.05
  done
  ! process_live "$pid"
  wait "$pid" 2>/dev/null || true

  # If the rejected destination itself is unusable, startup must remain
  # available without overwriting the only malformed workspace evidence.
  rm -rf "$workspace.rejected"
  mkdir -p "$workspace.rejected"
  printf "%s" "retain blocker" > "$workspace.rejected/keep"
  printf "%s" "damaged workspace without retention" > "$workspace"
  setsid "$binary" --show >"$scratch/retention-failure.log" 2>&1 &
  pid=$!
  printf "%s\n" "$pid" > "$scratch/pid"

  attempt=0
  while [ "$attempt" -lt 120 ]; do
    grep -F "workspace retention failed" \
      "$scratch/retention-failure.log" >/dev/null 2>&1 && break
    kill -0 "$pid" 2>/dev/null || {
      cat "$scratch/retention-failure.log" >&2
      exit 1
    }
    attempt=$((attempt + 1))
    sleep 0.05
  done
  grep -F "autosave disabled" "$scratch/retention-failure.log" >/dev/null
  attempt=0
  state=
  while [ "$attempt" -lt 120 ]; do
    state=$("$binary" --status 2>/dev/null || true)
    printf "%s\n" "$state" | grep -F "running=true" >/dev/null && break
    kill -0 "$pid" 2>/dev/null || {
      cat "$scratch/retention-failure.log" >&2
      exit 1
    }
    attempt=$((attempt + 1))
    sleep 0.05
  done
  printf "%s\n" "$state" | grep -F "running=true" >/dev/null
  test "$(cat "$workspace")" = "damaged workspace without retention"
  test "$(cat "$workspace.rejected/keep")" = "retain blocker"

  kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  attempt=0
  while process_live "$pid" && [ "$attempt" -lt 100 ]; do
    attempt=$((attempt + 1))
    sleep 0.05
  done
  ! process_live "$pid"
  wait "$pid" 2>/dev/null || true
'

rm -rf "$scratch"
scratch=
trap - EXIT HUP INT TERM
printf '%s\n' 'native_grid_state_recovery_smoke config_defaults=true theme_defaults=true workspace_defaults=true notice=true malformed_retained=true retention_failure_preserves_original=true usable_terminal=true process_group_cleanup=true'
