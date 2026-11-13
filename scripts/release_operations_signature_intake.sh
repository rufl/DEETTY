#!/usr/bin/env sh
set -eu

release_value() {
  sed -n "s/^pub const $1 = \"\([^\"]*\)\";$/\1/p" src/release.zig
}

. ./scripts/release_operations_common.sh

usage() {
  echo "usage: $0 <x86_64|aarch64> <archive|checksum|manifest> <signature-file> [evidence-dir]" >&2
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

case "${2:-}" in
  archive)
    target_kind=archive
    target_name="dintty-linux-$arch.tar.gz"
    ;;
  checksum)
    target_kind=checksum
    target_name="dintty-linux-$arch.tar.gz.sha256"
    ;;
  manifest)
    target_kind=manifest
    target_name="dintty-linux-$arch.tar.gz.manifest"
    ;;
  *)
    usage
    ;;
esac

signature=${3:-}
if [ -z "$signature" ]; then
  usage
fi

version=$(release_value version)
evidence_dir="${4:-release/evidence/$version}"
target_path="$evidence_dir/$target_name"
retained_signature="$target_path.sig"

test -s "$target_path"
test -s "$signature"

if grep -Ei 'TODO|TBD|unresolved|missing|placeholder|dummy|retained evidence' "$signature" >/dev/null; then # craft-ignore: intentional placeholder rejection
  echo "release_operations_signature_intake refused placeholder signature: $signature" >&2
  exit 1
fi

retain_file "$signature" "$retained_signature"
test -s "$retained_signature"

echo "release_operations_signature_intake version=$version arch=$arch target=$target_kind signature=true retained=true path=$evidence_dir"
