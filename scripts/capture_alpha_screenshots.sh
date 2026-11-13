#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
if [[ -z "${DEETTY_ISOLATED_DISPLAY:-}" &&
      "${DEETTY_DEDICATED_DISPLAY:-0}" != 1 ]]; then
  exec "$script_dir/isolated_display_runner.sh" \
    --timeout "${DEETTY_SCREENSHOT_TIMEOUT_SECONDS:-180}" \
    --screen "${DEETTY_ISOLATED_DISPLAY_SCREEN:-1280x900x24}" \
    --wm "${DEETTY_ISOLATED_X11_WM:-auto}" -- \
    env DEETTY_DEDICATED_DISPLAY=1 DEETTY_ISOLATED_DISPLAY=x11 "$0"
fi
"$script_dir/require_isolated_display.sh" --dedicated
cd "$repo_root"
command -v xdotool >/dev/null 2>&1 || {
  echo 'xdotool is required for focused, private publication captures.' >&2
  exit 1
}

out_dir=${DEETTY_SCREENSHOT_DIR:-docs/assets}
mkdir -p "$out_dir"

deetty_out="$out_dir/deetty-alpha.png"
nocted_out="$out_dir/nocted-alpha.png"
deetty_workspace_out="$out_dir/deetty-alpha-tabs-splits.png"
deetty_settings_out="$out_dir/deetty-alpha-settings.png"
nocted_search_out="$out_dir/nocted-alpha-project-search.png"
wait_ms=${DEETTY_SCREENSHOT_DELAY_MS:-3500}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-alpha-screenshots.XXXXXX")
active_pid=

stop_active() {
  if [[ -n "$active_pid" ]]; then
    kill -TERM -- "-$active_pid" >/dev/null 2>&1 ||
      kill -TERM "$active_pid" >/dev/null 2>&1 || true
    sleep 1
    kill -KILL -- "-$active_pid" >/dev/null 2>&1 ||
      kill -KILL "$active_pid" >/dev/null 2>&1 || true
    wait "$active_pid" 2>/dev/null || true
    active_pid=
  fi
}

cleanup() {
  stop_active
  rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

capture() {
  local output=$1
  if command -v spectacle >/dev/null 2>&1; then
    spectacle --background --nonotify --activewindow --output "$output" --delay "$wait_ms"
  elif command -v grim >/dev/null 2>&1; then
    sleep "$(awk "BEGIN { print $wait_ms / 1000 }")"
    grim "$output"
  elif command -v gnome-screenshot >/dev/null 2>&1; then
    sleep "$(awk "BEGIN { print $wait_ms / 1000 }")"
    gnome-screenshot --window -f "$output"
  elif command -v import >/dev/null 2>&1 && command -v xdotool >/dev/null 2>&1 &&
    [[ -n "${DISPLAY:-}" ]]; then
    sleep "$(awk "BEGIN { print $wait_ms / 1000 }")"
    import -window "$(xdotool getactivewindow)" "$output"
  else
    echo "No supported active-window screenshot tool found: install spectacle, gnome-screenshot, or ImageMagick plus xdotool." >&2
    return 1
  fi
}

focus_window() {
  local title=$1
  local window_id=
  window_id=$(timeout 12s xdotool search --sync --maxdepth 1 --limit 1 --name "$title" 2>/dev/null || true)
  [[ -n "$window_id" ]] || {
    echo "Could not find the expected window: $title" >&2
    return 1
  }
  xdotool windowactivate --sync "$window_id" >/dev/null 2>&1 ||
    xdotool windowfocus --sync "$window_id" >/dev/null 2>&1 ||
    return 1
  local active_window active_title
  active_window=$(xdotool getactivewindow 2>/dev/null || true)
  active_title=$(xdotool getwindowname "$active_window" 2>/dev/null || true)
  if [[ ! "$active_title" =~ $title ]]; then
    xdotool windowfocus --sync "$window_id" >/dev/null 2>&1 || true
    active_window=$(xdotool getactivewindow 2>/dev/null || true)
    active_title=$(xdotool getwindowname "$active_window" 2>/dev/null || true)
  fi
  [[ "$active_title" =~ $title ]] || {
    echo "Expected window did not become active: $title active=${active_title:-none}" >&2
    return 1
  }
  xdotool mousemove 10 10 >/dev/null 2>&1 || true
}

interact_window() {
  case "$1" in
    none) ;;
    workspace)
      xdotool key --clearmodifiers ctrl+shift+t
      sleep 0.5
      xdotool key --clearmodifiers ctrl+shift+s
      sleep 0.5
      xdotool key --clearmodifiers ctrl+shift+l
      sleep 1
      ;;
    settings)
      xdotool key --clearmodifiers ctrl+shift+p
      sleep 0.5
      xdotool type --clearmodifiers --delay 35 'Open settings'
      sleep 0.5
      xdotool key --clearmodifiers Return
      sleep 1
      ;;
    nocted-search)
      sleep 3
      xdotool key --clearmodifiers ctrl+shift+f
      sleep 0.5
      xdotool type --clearmodifiers --delay 35 workspace
      xdotool key --clearmodifiers Return
      sleep 2
      ;;
    *)
      echo "Unknown screenshot interaction: $1" >&2
      return 1
      ;;
  esac
  xdotool mousemove 10 10 >/dev/null 2>&1 || true
}

launch_and_capture() {
  local label=$1
  local output=$2
  local title=$3
  local interaction=$4
  shift 4

  mkdir -p "$scratch/home-$label" "$scratch/config-$label" "$scratch/cache-$label" "$scratch/data-$label"
  if command -v xdotool >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    xdotool mousemove 10 10 >/dev/null 2>&1 || true
  fi
  echo "Launching $label..."
  setsid env \
    GTK_MODULES= \
    GTK_THEME=Adwaita:dark \
    NO_AT_BRIDGE=1 \
    HOME="$scratch/home-$label" \
    XDG_CONFIG_HOME="$scratch/config-$label" \
    XDG_CACHE_HOME="$scratch/cache-$label" \
    XDG_DATA_HOME="$scratch/data-$label" \
    "$@" >"$scratch/$label.log" 2>&1 &
  active_pid=$!

  sleep 1
  if ! focus_window "$title"; then
    cat "$scratch/$label.log" >&2 || true
    return 1
  fi
  interact_window "$interaction"
  echo "Capturing $output..."
  set +e
  capture "$output"
  local capture_status=$?
  set -e
  stop_active
  ((capture_status == 0)) || return "$capture_status"
  test -s "$output"
}

demo_shell="$scratch/deetty-demo-shell"
cat >"$demo_shell" <<'EOF'
#!/bin/sh
printf '\033]2;DEETTY showcase\007\033[2J\033[H'
printf '\033[1;38;2;103;232;249mDEETTY\033[0m  native Zig terminal workspace\n'
printf 'PTY · VT grid · tabs · recursive splits · local-first\n\n'
printf '\033[38;2;148;163;184m$ printf '\''Unicode: Á 你好 👩‍🚀 │ ANSI 24-bit\\n'\''\033[0m\n'
printf 'Unicode: Á 你好 👩‍🚀 │ ANSI 24-bit\n'
printf '\033[38;2;148;163;184m$ zig version\033[0m\n'
zig version
printf '\033[38;2;148;163;184m$ printf '\''\\033[38;2;96;165;250mANSI 24-bit color\\033[0m\\n'\''\033[0m\n'
printf '\033[38;2;96;165;250mANSI 24-bit color\033[0m\n\n$ '
IFS= read -r _
EOF
chmod 700 "$demo_shell"
compact_demo_shell="$scratch/deetty-compact-demo-shell"
cat >"$compact_demo_shell" <<'EOF'
#!/bin/sh
printf '\033]2;DEETTY workspace\007\033[2J\033[H'
printf '\033[1;38;2;103;232;249mDEETTY pane\033[0m\n'
printf 'independent PTY · ready\n\n$ '
IFS= read -r _
EOF
chmod 700 "$compact_demo_shell"

showcase_root="$scratch/deetty-showcase"
mkdir -p "$showcase_root/src"
cat >"$showcase_root/src/main.zig" <<'EOF'
const std = @import("std");
const workspace = @import("workspace.zig");

pub fn main() !void {
    var terminal = try workspace.Terminal.init();
    defer terminal.deinit();
    try terminal.run();
}
EOF
cat >"$showcase_root/src/workspace.zig" <<'EOF'
const std = @import("std");

pub const Terminal = struct {
    pub fn init() !Terminal {
        return .{};
    }

    pub fn deinit(_: *Terminal) void {}

    pub fn run(_: *Terminal) !void {
        std.debug.print("DEETTY workspace ready\n", .{});
    }
};
EOF
cat >"$showcase_root/README.md" <<'EOF'
# DEETTY workspace

Native terminal and editor workspace.
EOF
project_file="$scratch/deetty-project.npr"
printf 'version=1\nroot=%s\n' "$showcase_root" >"$project_file"
for label in nocted nocted-search; do
  mkdir -p "$scratch/config-$label/nocted"
  printf '%s\n' \
    'version=1' \
    'syntax_prompt_done=true' \
    'sidebar_visible=true' \
    'minimap_visible=true' \
    'code_folding_enabled=true' \
    'word_wrap_enabled=false' \
    >"$scratch/config-$label/nocted/settings.conf"
done


zig build -j1 -Doptimize=ReleaseSafe >"$scratch/build.log" 2>&1

launch_and_capture deetty "$scratch/deetty-alpha.png" "DEETTY" none \
  env SHELL="$demo_shell" "$repo_root/zig-out/bin/deetty" --native-grid-windowed

launch_and_capture deetty-workspace "$scratch/deetty-alpha-tabs-splits.png" "DEETTY" workspace \
  env SHELL="$compact_demo_shell" "$repo_root/zig-out/bin/deetty" --native-grid-windowed

launch_and_capture deetty-settings "$scratch/deetty-alpha-settings.png" "DEETTY" settings \
  env SHELL="$demo_shell" "$repo_root/zig-out/bin/deetty" --native-grid-windowed

launch_and_capture nocted "$scratch/nocted-alpha.png" '[Nn][Oo][Cc][Tt][Ee][Dd]' none \
  "$repo_root/zig-out/bin/nocted" --project "$project_file" --open "$showcase_root/src/main.zig"

launch_and_capture nocted-search "$scratch/nocted-alpha-project-search.png" '[Nn][Oo][Cc][Tt][Ee][Dd]' nocted-search \
  "$repo_root/zig-out/bin/nocted" --project "$project_file" --open "$showcase_root/src/main.zig"

install -m 0644 "$scratch/deetty-alpha.png" "$deetty_out"
install -m 0644 "$scratch/deetty-alpha-tabs-splits.png" "$deetty_workspace_out"
install -m 0644 "$scratch/deetty-alpha-settings.png" "$deetty_settings_out"
install -m 0644 "$scratch/nocted-alpha.png" "$nocted_out"
install -m 0644 "$scratch/nocted-alpha-project-search.png" "$nocted_search_out"

printf 'alpha_screenshots release_safe=true installed_tree=true active_window=true terminal=true tabs_splits=true settings=true nocted=true project_search=true captured=true\n'
