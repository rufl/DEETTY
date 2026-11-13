#!/usr/bin/env sh
set -eu
export LC_ALL=C

if [ "${DINTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

binary=${1:-./zig-out/bin/nocted}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-single-instance.XXXXXX")
scratch=$(cd "$scratch" && pwd -P)
cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$scratch/config/nocted" "$scratch/project"
printf '%s\n' 'version=1' >"$scratch/config/nocted/settings.conf"
printf '%s\n' \
  'version=2' \
  "project=$scratch/project" \
  'active=0' \
  "$(printf 'tab=1\t\tVW50aXRsZWQ=\tdW5zYXZlZA==')" \
  >"$scratch/config/nocted/session.conf"
printf '%s\n' 'const routed = true;' >"$scratch/project/sample.zig"
printf 'version=1\nroot=%s\n' "$scratch/project" >"$scratch/project.npr"

sh -eu -c '
  binary=$1
  scratch=$2
  export DISPLAY
  export HOME="$scratch/home"
  export XDG_CONFIG_HOME="$scratch/config"
  export XDG_STATE_HOME="$scratch/state"
  export XDG_CACHE_HOME="$scratch/cache"
  export XDG_DATA_HOME="$scratch/data"
  mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
  export NO_AT_BRIDGE=1
  export G_DEBUG=fatal-warnings
  primary=
  cleanup_primary() {
    if test -n "$primary"; then
      kill -TERM "-$primary" 2>/dev/null || kill -TERM "$primary" 2>/dev/null || true
      sleep 0.1
      kill -KILL "-$primary" 2>/dev/null || kill -KILL "$primary" 2>/dev/null || true
      wait "$primary" 2>/dev/null || true
    fi
  }
  trap cleanup_primary EXIT
  trap "exit 129" HUP
  trap "exit 130" INT
  trap "exit 143" TERM
  setsid "$binary" --project "$scratch/project.npr" \
    >"$scratch/primary.log" 2>&1 &
  primary=$!
  for _ in $(seq 1 60); do
    if test -e "$scratch/config/nocted/instance.lock"; then
      break
    fi
    sleep 0.1
  done
  test -e "$scratch/config/nocted/instance.lock"
  kill -0 "$primary"
  sleep 1
  if ! "$binary" --open "$scratch/project/sample.zig" \
    >"$scratch/route.log" 2>&1; then
    cat "$scratch/primary.log" "$scratch/route.log" >&2
    exit 1
  fi
  kill -0 "$primary"
  test -f "$scratch/config/nocted/session.conf"
  encoded=$(printf "%s" "$scratch/project/sample.zig" | base64 -w0)
  routed=0
  dirty=0
  for _ in $(seq 1 40); do
    routed=0
    dirty=0
    while IFS= read -r line; do
      case "$line" in
        *"$encoded"*) routed=1 ;;
        *"dW5zYXZlZA=="*|*"CnVuc2F2ZWQ="*) dirty=1 ;;
      esac
    done <"$scratch/config/nocted/session.conf"
    if test "$routed" -eq 1; then break; fi
    sleep 0.1
  done
  test "$routed" -eq 1
  test "$dirty" -eq 1

  kill -TERM "-$primary" 2>/dev/null || kill -TERM "$primary" 2>/dev/null || true
  terminated=0
  for _ in $(seq 1 100); do
    if ! test -r "/proc/$primary/stat"; then
      terminated=1
      break
    fi
    state=$(cut -d " " -f 3 "/proc/$primary/stat" 2>/dev/null || true)
    if test "$state" = Z; then
      terminated=1
      break
    fi
    sleep 0.05
  done
  test "$terminated" -eq 1
  wait "$primary" 2>/dev/null || true
  primary=
  trap - EXIT HUP INT TERM
  printf "%s\n" "nocted_single_instance_smoke routed=true session_preserved=true duplicate_process=false process_group_cleanup=true"
' sh "$binary" "$scratch"
