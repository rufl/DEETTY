#!/usr/bin/env sh
set -eu

scratch=
if [ -n "${NOCTTY_ZIG_CACHE_DIR:-}" ] && [ -n "${NOCTTY_ZIG_GLOBAL_CACHE_DIR:-}" ]; then
  cache_dir=$NOCTTY_ZIG_CACHE_DIR
  global_cache_dir=$NOCTTY_ZIG_GLOBAL_CACHE_DIR
  cache_scope=managed
else
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-package.XXXXXX")
  cache_dir="$scratch/local-cache"
  global_cache_dir="$scratch/global-cache"
  cache_scope=standalone
fi
prefix="${NOCTTY_INSTALL_PREFIX:-zig-out}"

cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
}
trap cleanup EXIT HUP INT TERM

zig build --prefix "$prefix" --cache-dir "$cache_dir" --global-cache-dir "$global_cache_dir"

test -x "$prefix/bin/noctty"
test -x "$prefix/bin/nocted"
test -s "$prefix/share/applications/com.noctty.NOCTTY.desktop"
test -s "$prefix/share/applications/com.noctty.NoctEd.desktop"
test -s "$prefix/share/metainfo/com.noctty.NOCTTY.metainfo.xml"
test -s "$prefix/share/metainfo/com.noctty.NoctEd.metainfo.xml"
test -s "$prefix/share/icons/hicolor/scalable/apps/com.noctty.NOCTTY.svg"
test -s "$prefix/share/icons/hicolor/scalable/apps/com.noctty.NoctEd.svg"
test -s "$prefix/share/nocted/language-specs/zig.lang"
test -s "$prefix/share/nocted/language-specs/svelte.lang"
test -s "$prefix/share/nocted/styles/nocted-dark.xml"
test -s "$prefix/share/icons/hicolor/48x48/apps/com.noctty.NOCTTY.png"
test -s "$prefix/share/icons/hicolor/128x128/apps/com.noctty.NOCTTY.png"
test -s "$prefix/share/noctty/noctalia/niri.kdl"
test -s "$prefix/share/noctty/noctalia/hyprland.lua"
test -s "$prefix/share/noctty/noctalia/hyprland.conf"
test -s "$prefix/share/noctty/noctalia/sway.conf"
test -s "$prefix/share/noctty/noctalia/scroll.conf"
test -s "$prefix/share/noctty/noctalia/labwc-rc.xml"
test -s "$prefix/share/noctty/noctalia/labwc-autostart"
test -s "$prefix/share/noctty/noctalia/mango.conf"
test -s "$prefix/share/noctty/noctalia/noctalia-v5-widget.toml"
test -s "$prefix/share/licenses/noctty/LICENSE"

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$prefix/share/applications/com.noctty.NOCTTY.desktop"
  desktop-file-validate "$prefix/share/applications/com.noctty.NoctEd.desktop"
fi
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$prefix/share/metainfo/com.noctty.NOCTTY.metainfo.xml"
  xmllint --noout "$prefix/share/metainfo/com.noctty.NoctEd.metainfo.xml"
fi

if [ -n "$scratch" ]; then
  scratch_path=$scratch
  rm -rf "$scratch_path"
  scratch=
  test ! -e "$scratch_path"
fi

echo "package_smoke noctty=true nocted=true desktops=true metainfo=true icons=true nocted_syntax=true noctalia=true license=true cache_scope=$cache_scope"
