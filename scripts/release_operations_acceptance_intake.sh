#!/usr/bin/env sh
set -eu

release_value() {
  sed -n "s/^pub const $1 = \"\([^\"]*\)\";$/\1/p" src/release.zig
}

usage() {
  echo "usage: $0 compositor <niri|hyprland|sway|scroll|labwc|mango> <receipt-file> [evidence-dir]" >&2
  echo "       $0 wayland-hid <receipt-file> [evidence-dir]" >&2
  exit 2
}

version=$(release_value version)

require_field() {
  expected=$1
  grep -F "$expected" "$receipt" >/dev/null
}

reject_placeholder() {
  if grep -Ei 'TODO|TBD|unresolved|missing|placeholder|dummy|retained evidence' "$receipt" >/dev/null; then
    echo "release_operations_acceptance_intake refused placeholder receipt: $receipt" >&2
    exit 1
  fi
}

case "${1:-}" in
  compositor)
    case "${2:-}" in
      niri|hyprland|sway|scroll|labwc|mango)
        compositor=$2
        ;;
      *)
        usage
        ;;
    esac
    receipt=${3:-}
    if [ -z "$receipt" ]; then
      usage
    fi
    evidence_dir="${4:-release/evidence/$version}"
    test -s "$receipt"
    reject_placeholder
    require_field "version=$version"
    require_field "compositor=$compositor"
    require_field "native_release_smoke=true"
    require_field "operator_acceptance=true"
    mkdir -p "$evidence_dir/compositors"
    cp "$receipt" "$evidence_dir/compositors/$compositor.txt"
    test -s "$evidence_dir/compositors/$compositor.txt"
    echo "release_operations_acceptance_intake version=$version receipt=compositor compositor=$compositor semantic=true placeholder_blocking=true retained=true path=$evidence_dir"
    ;;
  wayland-hid)
    receipt=${2:-}
    if [ -z "$receipt" ]; then
      usage
    fi
    evidence_dir="${3:-release/evidence/$version}"
    test -s "$receipt"
    reject_placeholder
    require_field "version=$version"
    require_field "portal=RemoteDesktop/EIS"
    require_field "explicit_user_consent=true"
    require_field "physical_input_receipt=true"
    mkdir -p "$evidence_dir"
    cp "$receipt" "$evidence_dir/wayland-hid-consent-receipt.txt"
    test -s "$evidence_dir/wayland-hid-consent-receipt.txt"
    echo "release_operations_acceptance_intake version=$version receipt=wayland-hid semantic=true placeholder_blocking=true retained=true path=$evidence_dir"
    ;;
  *)
    usage
    ;;
esac
