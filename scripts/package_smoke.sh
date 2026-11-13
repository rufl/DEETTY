#!/usr/bin/env sh
set -eu

scratch=
if [ -n "${DEETTY_ZIG_CACHE_DIR:-}" ] && [ -n "${DEETTY_ZIG_GLOBAL_CACHE_DIR:-}" ]; then
  cache_dir=$DEETTY_ZIG_CACHE_DIR
  global_cache_dir=$DEETTY_ZIG_GLOBAL_CACHE_DIR
  cache_scope=managed
else
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-package.XXXXXX")
  cache_dir="$scratch/local-cache"
  global_cache_dir="$scratch/global-cache"
  cache_scope=standalone
fi
prefix="${DEETTY_INSTALL_PREFIX:-zig-out}"

cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
}
trap cleanup EXIT HUP INT TERM

ZIG_GLOBAL_CACHE_DIR="$global_cache_dir" zig build --prefix "$prefix" --cache-dir "$cache_dir"

test -x "$prefix/bin/deetty"
test -x "$prefix/bin/nocted"
test -s "$prefix/share/applications/com.deetty.DEETTY.desktop"
test -s "$prefix/share/kio/servicemenus/deettyhere.desktop"
test -s "$prefix/share/applications/com.deetty.NoctEd.desktop"
test -s "$prefix/share/metainfo/com.deetty.DEETTY.metainfo.xml"
test -s "$prefix/share/metainfo/com.deetty.NoctEd.metainfo.xml"
test -s "$prefix/share/icons/hicolor/scalable/apps/com.deetty.DEETTY.svg"
test -s "$prefix/share/icons/hicolor/scalable/apps/com.deetty.NoctEd.svg"
test -s "$prefix/share/nocted/language-specs/zig.lang"
test -s "$prefix/share/nocted/language-specs/svelte.lang"
test -s "$prefix/share/nocted/styles/nocted-dark.xml"
test -s "$prefix/share/icons/hicolor/48x48/apps/com.deetty.DEETTY.png"
test -s "$prefix/share/icons/hicolor/128x128/apps/com.deetty.DEETTY.png"
test -s "$prefix/share/deetty/noctalia/niri.kdl"
test -s "$prefix/share/deetty/noctalia/hyprland.lua"
test -s "$prefix/share/deetty/noctalia/hyprland.conf"
test -s "$prefix/share/deetty/noctalia/sway.conf"
test -s "$prefix/share/deetty/noctalia/scroll.conf"
test -s "$prefix/share/deetty/noctalia/labwc-rc.xml"
test -s "$prefix/share/deetty/noctalia/labwc-autostart"
test -s "$prefix/share/deetty/noctalia/mango.conf"
test -s "$prefix/share/deetty/noctalia/noctalia-v5-widget.toml"
test -s "$prefix/share/licenses/deetty/LICENSE"

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$prefix/share/applications/com.deetty.DEETTY.desktop"
  desktop-file-validate "$prefix/share/applications/com.deetty.NoctEd.desktop"
fi
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$prefix/share/metainfo/com.deetty.DEETTY.metainfo.xml"
  xmllint --noout "$prefix/share/metainfo/com.deetty.NoctEd.metainfo.xml"
fi

if [ -n "$scratch" ]; then
  scratch_path=$scratch
  rm -rf "$scratch_path"
  scratch=
  test ! -e "$scratch_path"
fi

echo "package_smoke deetty=true nocted=true desktops=true dolphin_service_menu=true metainfo=true icons=true nocted_syntax=true noctalia=true license=true cache_scope=$cache_scope"
