#!/usr/bin/env sh
set -eu

binary=${1:-./zig-out/bin/noctty}
case "$binary" in
  /*) ;;
  *) binary="$PWD/${binary#./}" ;;
esac
test -x "$binary"
command -v dbus-run-session >/dev/null
command -v xvfb-run >/dev/null

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-single-instance.XXXXXX")
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

NOCTTY_SINGLE_INSTANCE_BINARY=$binary \
NOCTTY_SINGLE_INSTANCE_SCRATCH=$scratch \
dbus-run-session -- xvfb-run -a -s '-screen 0 1280x800x24' sh -eu -c '
  binary=$NOCTTY_SINGLE_INSTANCE_BINARY
  scratch=$NOCTTY_SINGLE_INSTANCE_SCRATCH
  export HOME="$scratch/home"
  export XDG_CONFIG_HOME="$scratch/config"
  export XDG_STATE_HOME="$scratch/state"
  export XDG_DATA_HOME="$scratch/data"
  export GDK_BACKEND=x11
  export NO_AT_BRIDGE=1
  mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME"

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
    sleep 0.4

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
  rm -f "$HOME/.local/state/noctty/instance.lock"
  mkdir -p "$HOME/.local/state/noctty/instance.lock"
  launch_race --show
  rm -rf "$HOME/.local/state/noctty/instance.lock"

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
  sleep 0.4

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

  NOCTTY_DEBUG_ACTIVATION=1 setsid "$binary" --hidden >"$scratch/primary-hidden.log" 2>&1 &
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
  XDG_ACTIVATION_TOKEN=noctty-smoke-token "$binary" --show >/dev/null
  attempt=0
  while [ "$attempt" -lt 40 ]; do
    grep -F "noctty_xdg_activation applied=true backend=x11" \
      "$scratch/primary-hidden.log" >/dev/null 2>&1 && break
    attempt=$((attempt + 1))
    sleep 0.05
  done
  grep -F "noctty_xdg_activation applied=true backend=x11" \
    "$scratch/primary-hidden.log" >/dev/null

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
printf '%s\n' 'native_grid_single_instance_smoke cold_callers=12 owner=1 duplicate_window=false lock_fallback=true hidden_show_race=true visible=true activation_token=true separate_window=true open_here_cwd=true process_group_cleanup=true'
