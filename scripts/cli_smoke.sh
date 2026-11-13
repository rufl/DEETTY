#!/usr/bin/env sh
set -eu

# No display or session bus is reachable, including when a help regression
# accidentally falls through to GTK initialization or existing-instance IPC.
deetty=$(realpath "${1:-zig-out/bin/deetty}")
nocted=$(realpath "${2:-zig-out/bin/nocted}")
scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-cli.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
unset DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
export HOME="$scratch/home" XDG_CONFIG_HOME="$scratch/config"
export XDG_STATE_HOME="$scratch/state" XDG_RUNTIME_DIR="$scratch/runtime"
export XDG_CACHE_HOME="$scratch/cache" XDG_DATA_HOME="$scratch/data"
export DEETTY_RENDERER=grid NOCTED_DISABLE_SINGLE_INSTANCE=1
package_output=$(timeout --kill-after=1 5 "$deetty" --package-smoke)
printf '%s\n' "$package_output" | grep -q 'package_smoke deetty=true headless=true'

for binary in "$deetty" "$nocted"; do
  for option in --help -h --version; do
    output=$(timeout --kill-after=1 5 "$binary" "$option")
    test -n "$output"
  done
  status=0
  timeout --kill-after=1 5 "$binary" --not-a-deetty-option >"$scratch/error" 2>&1 || status=$?
  case "$status" in
    0|124|137) echo "cli_smoke invalid_option_not_rejected=$binary status=$status" >&2; exit 1 ;;
  esac
  grep -q 'UnknownArgument' "$scratch/error"
done
for state in "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"; do
  test ! -e "$state" || { echo "cli_smoke unexpected_state=$state" >&2; exit 1; }
done
printf '%s\n' 'cli_smoke help=true version=true package_smoke=true invalid_options_rejected=true no_display=true state_untouched=true'
