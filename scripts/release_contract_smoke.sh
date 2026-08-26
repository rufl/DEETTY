#!/usr/bin/env sh
set -eu

export LC_ALL=C

release_value() {
  sed -n "s/^pub const $1 = \"\([^\"]*\)\";$/\1/p" src/release.zig
}

version=$(release_value version)
release_date=$(release_value release_date)
revision=$(release_value package_revision)
verified_date=2026-07-18
binary="${1:-zig-out/bin/noctty}"
nocted_binary="$(dirname "$binary")/nocted"

test "$version" = "0.1.0"
test "$release_date" = "2026-07-14"
test "$revision" = "1"
test -x "$binary"
test -x "$nocted_binary"
test "$("$binary" --version)" = "noctty $version"
test "$("$nocted_binary" --version)" = "nocted $version"

if ldd "$binary" | grep -Eq 'libvte|tree-sitter'; then
  echo 'release_contract error=production_optional_dependency' >&2
  exit 1
fi
optional_symbol=$(strings "$binary" | grep -Em 1 'tree_sitter_|vte_terminal_' || true)
if [ -n "$optional_symbol" ]; then
  printf 'release_contract error=production_optional_symbol match=%s\n' \
    "$optional_symbol" >&2
  exit 1
fi
smoke_symbol=$(strings "$binary" | grep -Em 1 \
  'native_grid_presentation_qualification|NOCTTY stability qualification|A deliberately long shell title' || true)
if [ -n "$smoke_symbol" ]; then
  printf 'release_contract error=production_smoke_symbol match=%s\n' \
    "$smoke_symbol" >&2
  exit 1
fi
nocted_runtime_contract=$("$nocted_binary" --runtime-contract)
printf '%s\n' "$nocted_runtime_contract" | grep -E \
  '^nocted_runtime_contract tree_sitter=true captures=[1-9][0-9]* capture_limit=4096 direct_limit_bytes=32768$' >/dev/null
if smoke_output=$("$binary" --native-grid-smoke 2>&1); then
  echo 'release_contract error=production_smoke_surface' >&2
  exit 1
fi
printf '%s\n' "$smoke_output" | grep -F 'SmokeModeUnavailable' >/dev/null
if editor_output=$("$binary" --editor-plan 2>&1); then
  echo 'release_contract error=production_legacy_editor_surface' >&2
  exit 1
fi
printf '%s\n' "$editor_output" | grep -F 'LegacyEditorRemoved' >/dev/null

grep -F ".version = \"$version\"," build.zig.zon >/dev/null
grep -F 'noctty.release.version' src/main.zig >/dev/null
grep -F "<release version=\"$version\" date=\"$release_date\">" resources/com.noctty.NOCTTY.metainfo.xml >/dev/null
grep -F '<id>com.noctty.NoctEd</id>' resources/com.noctty.NoctEd.metainfo.xml >/dev/null
grep -F "noctty ($version-$revision)" packaging/debian/changelog >/dev/null
grep -F "Version:        $version" packaging/rpm/noctty.spec >/dev/null
grep -F "Release:        $revision" packaging/rpm/noctty.spec >/dev/null
grep -F "pkgver=$version" packaging/arch/PKGBUILD >/dev/null
grep -F "pkgrel=$revision" packaging/arch/PKGBUILD >/dev/null

debian_date=$(date -u -d "$release_date" '+%a, %d %b %Y')
rpm_date=$(date -u -d "$release_date" '+%a %b %d %Y')
grep -F "$debian_date" packaging/debian/changelog >/dev/null
grep -F "* $rpm_date" packaging/rpm/noctty.spec >/dev/null

grep -F 'NOCTTY is a native terminal workspace focused first on Linux desktops' README.md >/dev/null
grep -F "## $version — $release_date product behavior complete; release hardening and publication pending" CHANGELOG.md >/dev/null
grep -F "Product-behavior and local release-source baseline: $version, $verified_date." docs/RELEASE_CHECKLIST.md >/dev/null
grep -F "Canonical release contract: version $version, source baseline $release_date, package revision $revision." docs/INSTALL.md >/dev/null

echo "release_contract version=$version release_date=$release_date revision=$revision build_zon=true noctty_runtime=true nocted_runtime=true production_vte=false production_noctty_tree_sitter=false production_nocted_tree_sitter=true production_smoke_surface=false production_smoke_symbols=false production_legacy_editor=false appstream=true debian=true rpm=true arch=true docs=true"
