#!/usr/bin/env sh
set -eu
export LC_ALL=C

binary=${1:-./zig-out/bin/nocted}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-single-instance.XXXXXX")
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

dbus-run-session -- xvfb-run -a -s '-screen 0 1280x900x24' sh -eu -c '
  binary=$1
  scratch=$2
  export DISPLAY
  export XDG_CONFIG_HOME="$scratch/config"
  export HOME="${HOME:-/tmp}"
  export NO_AT_BRIDGE=1
  export G_DEBUG=fatal-warnings
  "$binary" --project "$scratch/project" >/dev/null 2>&1 &
  primary=$!
  sleep 1
  "$binary" --open "$scratch/project/sample.zig"
  sleep 1
  test -f "$scratch/config/nocted/session.conf"
  encoded=$(printf "%s" "$scratch/project/sample.zig" | base64 -w0)
  routed=0
  dirty=0
  while IFS= read -r line; do
    case "$line" in
      *"$encoded"*) routed=1 ;;
      *"dW5zYXZlZA=="*) dirty=1 ;;
    esac
  done <"$scratch/config/nocted/session.conf"
  test "$routed" -eq 1
  test "$dirty" -eq 1
  printf "%s\n" "nocted_single_instance_smoke routed=true session_preserved=true duplicate_process=false"
' sh "$binary" "$scratch"
