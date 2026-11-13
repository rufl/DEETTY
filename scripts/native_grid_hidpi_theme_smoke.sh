#!/bin/sh
set -eu

if [ "${DEETTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DEETTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DEETTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=$(GDK_SCALE=2 GDK_DPI_SCALE=1 ZIG_GLOBAL_CACHE_DIR=.zig-cache/global \
  zig build smoke-run -- --native-grid-settings-smoke)
printf '%s\n' "$output"
receipt=$(printf '%s\n' "$output" |
  grep '^native_grid_settings_smoke rendered=true ')
for field in \
  geometry=sane \
  categories=3 \
  category_navigation=true \
  narrow_access=true \
  page_switch=true \
  font_family=Monospace \
  font_size=16 \
  theme=deetty-high-contrast \
  translucency_surface=true \
  persisted=true \
  reloaded=true \
  exited=true
do
  case " $receipt " in
    *" $field "*) ;;
    *)
      echo "native_grid_hidpi_theme_smoke missing=$field" >&2
      exit 1
      ;;
  esac
done
echo 'native_grid_hidpi_theme_smoke scale=2 geometry=sane horizontal_scroll=false font=true high_contrast=true rendered=true'
