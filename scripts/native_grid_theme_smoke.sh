#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/noctty-theme-smoke.XXXXXX")
cleanup() {
  rm -rf "$fixture_root"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
fixture_config="$fixture_root/config"
scheme_dir="$fixture_config/noctalia/colorschemes/Smoke Scheme"
mkdir -p "$scheme_dir"
cat >"$scheme_dir/Smoke Scheme.json" <<'JSON'
{
  "dark": {
    "mPrimary": "#7a88cf",
    "mOnSurface": "#a9b1d6",
    "mSurface": "#1f2335",
    "terminal": { "foreground": "#a9b1d6", "background": "#1f2335" }
  },
  "light": {
    "mPrimary": "#4e70c2",
    "mOnSurface": "#303446",
    "mSurface": "#f0f2f7",
    "terminal": { "foreground": "#303446", "background": "#f0f2f7" }
  }
}
JSON

output=$(XDG_CONFIG_HOME="$fixture_config" zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-theme-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_theme_smoke rendered=true paseo_black_zinc=true imported=true format=ghostty noctalia=true noctalia_system=true noctalia_dark=true terminal_palette=true tui_palette=true per_tab=true material_chrome=true caret_color=true selected=true library_persisted=true config_persisted=true reloaded=true exited=true$'
