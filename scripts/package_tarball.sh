#!/usr/bin/env sh
set -eu

export LC_ALL=C
export TZ=UTC

out="${1:-/tmp/noctty-local.tar.gz}"
case "$out" in
  /*) out_path="$out" ;;
  *) out_path="$(pwd)/$out" ;;
esac
out_dir=$(dirname "$out_path")
out_name=$(basename "$out_path")
test -d "$out_dir"

release_value() {
  sed -n "s/^pub const $1 = \"\([^\"]*\)\";$/\1/p" src/release.zig
}

version=$(release_value version)
release_date=$(release_value release_date)
test -n "$version"
test -n "$release_date"

scratch=
publish_tmp=
sidecar_tmp=
cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
  if [ -n "${publish_tmp:-}" ]; then rm -f "$publish_tmp"; fi
  if [ -n "${sidecar_tmp:-}" ]; then rm -f "$sidecar_tmp"; fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-tarball.XXXXXX")
publish_tmp=$(mktemp "$out_dir/.${out_name}.tmp.XXXXXX")
sidecar_tmp=$(mktemp "$out_dir/.${out_name}.sha256.tmp.XXXXXX")

build_archive() {
  build_name=$1
  build_root="$scratch/$build_name"
  stage="$build_root/stage"
  archive="$build_root/noctty.tar.gz"
  mkdir -p "$stage" "$build_root/local-cache" "$build_root/global-cache"

  ZIG_GLOBAL_CACHE_DIR="$build_root/global-cache" zig build -Doptimize=ReleaseSafe -Dstrip=true \
    --prefix "$stage" \
    --cache-dir "$build_root/local-cache"

  test -x "$stage/bin/noctty"
  test -x "$stage/bin/nocted"
  test "$("$stage/bin/noctty" --version)" = "noctty $version"
  test "$("$stage/bin/nocted" --version)" = "nocted $version"

  tar -C "$stage" \
    --sort=name \
    --mtime='UTC 1970-01-01' \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -cf - . | gzip -n > "$archive"

  test -s "$archive"
  tar -tzf "$archive" | grep -F './bin/noctty' >/dev/null
  tar -tzf "$archive" | grep -F './bin/nocted' >/dev/null
  tar -tzf "$archive" | grep -F './share/applications/com.noctty.NOCTTY.desktop' >/dev/null
  tar -tzf "$archive" | grep -F './share/kio/servicemenus/nocttyhere.desktop' >/dev/null
  tar -tzf "$archive" | grep -F './share/applications/com.noctty.NoctEd.desktop' >/dev/null
  tar -tzf "$archive" | grep -F './share/metainfo/com.noctty.NOCTTY.metainfo.xml' >/dev/null
  tar -tzf "$archive" | grep -F './share/metainfo/com.noctty.NoctEd.metainfo.xml' >/dev/null
  tar -tzf "$archive" | grep -F './share/icons/hicolor/scalable/apps/com.noctty.NOCTTY.svg' >/dev/null
  tar -tzf "$archive" | grep -F './share/icons/hicolor/scalable/apps/com.noctty.NoctEd.svg' >/dev/null
  tar -tzf "$archive" | grep -F './share/nocted/language-specs/zig.lang' >/dev/null
  tar -tzf "$archive" | grep -F './share/nocted/language-specs/svelte.lang' >/dev/null
  tar -tzf "$archive" | grep -F './share/nocted/styles/nocted-dark.xml' >/dev/null
  tar -tzf "$archive" | grep -F './share/licenses/noctty/LICENSE' >/dev/null
  if tar -tzf "$archive" | grep -Eq '/(noctty-smoke|nocted-smoke|noctty-vte)$'; then
    echo 'package_tarball error=optional_binary_in_default_install' >&2
    return 1
  fi
}

build_archive build-a
build_archive build-b

archive_a="$scratch/build-a/noctty.tar.gz"
archive_b="$scratch/build-b/noctty.tar.gz"
cmp -s "$archive_a" "$archive_b"

digest_a=$(sha256sum "$archive_a" | awk '{print $1}')
digest_b=$(sha256sum "$archive_b" | awk '{print $1}')
test "$digest_a" = "$digest_b"

cp "$archive_a" "$publish_tmp"
printf '%s  %s\n' "$digest_a" "$out_name" > "$sidecar_tmp"
chmod 0644 "$publish_tmp" "$sidecar_tmp"
mv -f "$publish_tmp" "$out_path"
publish_tmp=
mv -f "$sidecar_tmp" "$out_path.sha256"
sidecar_tmp=
(cd "$out_dir" && sha256sum -c "$out_name.sha256" >/dev/null)

bytes=$(wc -c < "$out_path")
scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"

echo "package_tarball_reproducibility version=$version release_date=$release_date builds=2 isolated=true release_safe=true stripped=true byte_identical=true checksums_match=true archive_valid=true cli_version=true scratch_clean=true bytes=$bytes digest=$digest_a path=$out checksum=$out.sha256"
