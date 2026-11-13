#!/usr/bin/env sh
set -eu

release_value() {
  sed -n "s/^pub const $1 = \"\([^\"]*\)\";$/\1/p" src/release.zig
}

. ./scripts/release_operations_common.sh

usage() {
  echo "usage: $0 <x86_64|aarch64> <archive.tar.gz> [evidence-dir]" >&2
  exit 2
}

case "${1:-}" in
  x86_64|aarch64)
    arch=$1
    ;;
  *)
    usage
    ;;
esac

archive=${2:-}
if [ -z "$archive" ]; then
  usage
fi

version=$(release_value version)
evidence_dir="${3:-release/evidence/$version}"
checksum="$archive.sha256"
manifest="$archive.manifest"

test -s "$archive"
test -s "$checksum"
test -s "$manifest"

archive_dir=$(dirname "$archive")
archive_name=$(basename "$archive")
(
  cd "$archive_dir"
  sha256sum -c "$archive_name.sha256" >/dev/null
)

digest=$(sed -n '1s/[[:space:]].*$//p' "$checksum")
grep -F 'bundle_manifest_version=1' "$manifest" >/dev/null
grep -F "architecture=$arch" "$manifest" >/dev/null
grep -F "archive_sha256=$digest" "$manifest" >/dev/null
grep -F 'installed_files_begin' "$manifest" >/dev/null
grep -F 'library_inventory_begin' "$manifest" >/dev/null

mkdir -p "$evidence_dir"
target_archive="$evidence_dir/dintty-linux-$arch.tar.gz"
target_checksum="$target_archive.sha256"
target_manifest="$target_archive.manifest"

retain_file "$archive" "$target_archive"
retain_file "$manifest" "$target_manifest"
printf '%s  %s\n' "$digest" "$(basename "$target_archive")" |
  retain_from_stdin "$target_checksum"
(
  cd "$evidence_dir"
  sha256sum -c "$(basename "$target_checksum")" >/dev/null
)

echo "release_operations_artifact_intake version=$version arch=$arch archive=true checksum=true manifest=true digest=$digest retained=true path=$evidence_dir"
