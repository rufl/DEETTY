#!/usr/bin/env sh
set -eu

prefix="${DEETTY_GHOSTTY_PREFIX:-}"
if [ -z "$prefix" ] || [ ! -f "$prefix/include/ghostty.h" ] || [ ! -f "$prefix/lib/ghostty-internal.so" ]; then
  echo "ghostty_upstream_surface_probe skipped=true reason=DEETTY_GHOSTTY_PREFIX_missing"
  exit 0
fi

probe=$(mktemp "${TMPDIR:-/tmp}/deetty-ghostty-surface-probe.XXXXXX")
cleanup() { rm -f "$probe"; }
trap cleanup EXIT HUP INT TERM
cc scripts/ghostty_surface_probe.c \
  -I"$prefix/include" \
  -L"$prefix/lib" \
  -Wl,-rpath,"$prefix/lib" \
  -Wl,-l:ghostty-internal.so \
  -o "$probe"

if output="$(LD_PRELOAD="$prefix/lib/ghostty-internal.so" "$probe" 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'surface_created=false platform=invalid' >/dev/null
echo "ghostty_upstream_surface_probe supported_linux_surface=false safe_gui_abi=false"
