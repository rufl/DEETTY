#!/usr/bin/env sh
set -eu

if [ "${DEETTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DEETTY_ISOLATED_DISPLAY:-}" != wayland ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh
backend=${DEETTY_ISOLATED_DISPLAY:-x11}
case "$backend" in
  x11|wayland) ;;
  *) echo "native_grid_single_instance_smoke error=unsupported_backend backend=$backend" >&2; exit 2 ;;
esac

binary=${1:-./zig-out/bin/deetty}
case "$binary" in
  /*) ;;
  *) binary="$PWD/${binary#./}" ;;
esac
test -x "$binary"
command -v gdbus >/dev/null

scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-single-instance.XXXXXX")
cleanup() {
  if [ -s "$scratch/pids" ]; then
    while read -r pid; do
      kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    done < "$scratch/pids"
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM
: > "$scratch/pids"

DEETTY_SINGLE_INSTANCE_BACKEND=$backend \
DEETTY_SINGLE_INSTANCE_BINARY=$binary \
DEETTY_SINGLE_INSTANCE_SCRATCH=$scratch \
sh -eu -c '
  binary=$DEETTY_SINGLE_INSTANCE_BINARY
  scratch=$DEETTY_SINGLE_INSTANCE_SCRATCH
  backend=$DEETTY_SINGLE_INSTANCE_BACKEND
  export HOME="$scratch/home"
  export XDG_CONFIG_HOME="$scratch/config"
  export XDG_STATE_HOME="$scratch/state"
  export XDG_CACHE_HOME="$scratch/cache"
  export XDG_DATA_HOME="$scratch/data"
  export GDK_BACKEND="$backend"
  export NO_AT_BRIDGE=1
  mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME" "$XDG_DATA_HOME"

  process_live() {
    pid=$1
    test -r "/proc/$pid/stat" || return 1
    proc_state=$(cut -d " " -f 3 "/proc/$pid/stat" 2>/dev/null) || return 1
    test "$proc_state" != Z
  }

  launch_race() {
    mode=$1
    : > "$scratch/round-pids"
    index=0
    while [ "$index" -lt 12 ]; do
      setsid "$binary" "$mode" >"$scratch/$mode-$index.log" 2>&1 &
      pid=$!
      printf "%s\n" "$pid" >> "$scratch/pids"
      printf "%s\n" "$pid" >> "$scratch/round-pids"
      index=$((index + 1))
    done

    attempt=0
    state=
    while [ "$attempt" -lt 100 ]; do
      state=$("$binary" --status 2>/dev/null || true)
      printf "%s\n" "$state" | grep -F "running=true" >/dev/null && break
      attempt=$((attempt + 1))
      sleep 0.05
    done
    if ! printf "%s\n" "$state" | grep -F "running=true" >/dev/null; then
      printf "single-instance cold race produced no owner: %s\n" "$state" >&2
      cat "$scratch"/*.log >&2 || true
      exit 1
    fi
    attempt=0
    alive=0
    winner=
    while [ "$attempt" -lt 100 ]; do
      alive=0
      winner=
      while read -r pid; do
        if process_live "$pid"; then
          alive=$((alive + 1))
          winner=$pid
        else
          wait "$pid" 2>/dev/null || true
        fi
      done < "$scratch/round-pids"
      [ "$alive" -le 1 ] && break
      attempt=$((attempt + 1))
      sleep 0.05
    done
    if [ "$alive" -ne 1 ]; then
      printf "single-instance cold race left %s live owners\n" "$alive" >&2
      while read -r pid; do ps -o pid,ppid,stat,args -p "$pid" >&2 || true; done < "$scratch/round-pids"
      cat "$scratch"/*.log >&2 || true
      exit 1
    fi
    printf "%s\n" "$state" | grep -F "visible=true" >/dev/null

    kill -TERM "-$winner" 2>/dev/null || kill -TERM "$winner" 2>/dev/null || true
    attempt=0
    while process_live "$winner" && [ "$attempt" -lt 100 ]; do
      attempt=$((attempt + 1))
      sleep 0.05
    done
    ! process_live "$winner"
    wait "$winner" 2>/dev/null || true
  }

  launch_race --show

  # Force the filesystem lock open to fail and prove the D-Bus
  # DO_NOT_QUEUE ownership fallback still converges without persistence.
  rm -f "$HOME/.local/state/deetty/instance.lock"
  mkdir -p "$HOME/.local/state/deetty/instance.lock"
  launch_race --show
  rm -rf "$HOME/.local/state/deetty/instance.lock"

  setsid "$binary" --hidden >"$scratch/hidden.log" 2>&1 &
  hidden_pid=$!
  printf "%s\n" "$hidden_pid" >> "$scratch/pids"
  setsid "$binary" --show >"$scratch/show-race.log" 2>&1 &
  show_pid=$!
  printf "%s\n" "$show_pid" >> "$scratch/pids"

  attempt=0
  final_state=
  while [ "$attempt" -lt 100 ]; do
    final_state=$("$binary" --status 2>/dev/null || true)
    printf "%s\n" "$final_state" | grep -F "running=true" >/dev/null &&
      printf "%s\n" "$final_state" | grep -F "visible=true" >/dev/null && break
    attempt=$((attempt + 1))
    sleep 0.05
  done
  if ! printf "%s\n" "$final_state" | grep -F "running=true" >/dev/null; then
    printf "hidden/show race produced no owner: %s\n" "$final_state" >&2
    cat "$scratch/hidden.log" "$scratch/show-race.log" >&2 || true
    exit 1
  fi
  printf "%s\n" "$final_state" | grep -F "visible=true" >/dev/null
  attempt=0
  alive=0
  winner=
  while [ "$attempt" -lt 100 ]; do
    alive=0
    winner=
    for pid in "$hidden_pid" "$show_pid"; do
      if process_live "$pid"; then
        alive=$((alive + 1))
        winner=$pid
      else
        wait "$pid" 2>/dev/null || true
      fi
    done
    [ "$alive" -le 1 ] && break
    attempt=$((attempt + 1))
    sleep 0.05
  done
  if [ "$alive" -ne 1 ]; then
    printf "hidden/show race left %s live owners\n" "$alive" >&2
    ps -o pid,ppid,stat,args -p "$hidden_pid" -p "$show_pid" >&2 || true
    cat "$scratch/hidden.log" "$scratch/show-race.log" >&2 || true
    exit 1
  fi
  kill -TERM "-$winner" 2>/dev/null || kill -TERM "$winner" 2>/dev/null || true
  attempt=0
  while process_live "$winner" && [ "$attempt" -lt 100 ]; do
    attempt=$((attempt + 1))
    sleep 0.05
  done
  ! process_live "$winner"
  wait "$winner" 2>/dev/null || true

  DEETTY_DEBUG_ACTIVATION=1 setsid "$binary" --hidden >"$scratch/primary-hidden.log" 2>&1 &
  primary_pid=$!
  printf "%s\n" "$primary_pid" >> "$scratch/pids"
  attempt=0
  while [ "$attempt" -lt 100 ]; do
    primary_state=$("$binary" --status 2>/dev/null || true)
    printf "%s\n" "$primary_state" | grep -F "running=true" >/dev/null && break
    attempt=$((attempt + 1))
    sleep 0.05
  done
  printf "%s\n" "$primary_state" | grep -F "running=true" >/dev/null
  XDG_ACTIVATION_TOKEN=deetty-smoke-token "$binary" --show >/dev/null
  attempt=0
  while [ "$attempt" -lt 40 ]; do
    grep -F "deetty_xdg_activation applied=true backend=$backend" \
      "$scratch/primary-hidden.log" >/dev/null 2>&1 && break
    attempt=$((attempt + 1))
    sleep 0.05
  done
  grep -F "deetty_xdg_activation applied=true backend=$backend" \
    "$scratch/primary-hidden.log" >/dev/null

  "$binary" --hide >/dev/null
  attempt=0
  while [ "$attempt" -lt 40 ]; do
    if gdbus call --session --dest com.deetty.DEETTY \
      --object-path /StatusNotifierItem \
      --method org.kde.StatusNotifierItem.ProvideXdgActivationToken \
      deetty-tray-smoke-token >/dev/null 2>&1; then
      break
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done
  [ "$attempt" -lt 40 ]
  gdbus call --session --dest com.deetty.DEETTY \
    --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.Activate 0 0 >/dev/null
  attempt=0
  while [ "$attempt" -lt 40 ]; do
    applied_count=$(grep -c \
      "deetty_xdg_activation applied=true backend=$backend" \
      "$scratch/primary-hidden.log" || true)
    [ "$applied_count" -ge 2 ] && break
    attempt=$((attempt + 1))
    sleep 0.05
  done
  [ "$applied_count" -eq 2 ]

  # A token supplied while visible must not survive a hide and become attached
  # to a later unrelated Show.
  gdbus call --session --dest com.deetty.DEETTY \
    --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.ProvideXdgActivationToken \
    deetty-stale-tray-token >/dev/null
  "$binary" --hide >/dev/null
  XDG_ACTIVATION_TOKEN= "$binary" --show >/dev/null
  sleep 0.1
  applied_count=$(grep -c \
    "deetty_xdg_activation applied=true backend=$backend" \
    "$scratch/primary-hidden.log" || true)
  [ "$applied_count" -eq 2 ]

  project="$scratch/Open Here Project"
  mkdir -p "$project"
  setsid "$binary" --new-window --working-directory "$project" \
    >"$scratch/new-window.log" 2>&1 &
  window_pid=$!
  printf "%s\n" "$window_pid" >> "$scratch/pids"
  attempt=0
  child_pid=
  while [ "$attempt" -lt 100 ]; do
    child_pid=$(pgrep -P "$window_pid" | head -n 1 || true)
    [ -n "$child_pid" ] && [ -e "/proc/$child_pid/cwd" ] && break
    process_live "$window_pid" || { cat "$scratch/new-window.log" >&2; exit 1; }
    attempt=$((attempt + 1))
    sleep 0.05
  done
  process_live "$primary_pid"
  process_live "$window_pid"
  test -n "$child_pid"
  test "$(readlink "/proc/$child_pid/cwd")" = "$project"
  owner_state=$("$binary" --status)
  printf "%s\n" "$owner_state" | grep -F "running=true" >/dev/null

  for pid in "$window_pid" "$primary_pid"; do
    kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    attempt=0
    while process_live "$pid" && [ "$attempt" -lt 100 ]; do
      attempt=$((attempt + 1))
      sleep 0.05
    done
    ! process_live "$pid"
    wait "$pid" 2>/dev/null || true
  done
'

rm -rf "$scratch"
scratch=
trap - EXIT HUP INT TERM
printf '%s\n' 'native_grid_single_instance_smoke cold_callers=12 owner=1 convergence_wait_bounded=true duplicate_window=false lock_fallback=true hidden_show_race=true visible=true activation_token=true tray_activation_token=true stale_token_cleared=true separate_window=true open_here_cwd=true process_group_cleanup=true'
