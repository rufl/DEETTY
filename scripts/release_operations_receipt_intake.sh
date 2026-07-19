#!/usr/bin/env sh
set -eu

release_value() {
  sed -n "s/^pub const $1 = \"\([^\"]*\)\";$/\1/p" src/release.zig
}

usage() {
  echo "usage: $0 <publication|dependency-bundle-redistribution> <receipt-file> [evidence-dir]" >&2
  exit 2
}

version=$(release_value version)

case "${1:-}" in
  publication)
    receipt_kind=publication
    target_name=publication-receipt.txt
    ;;
  dependency-bundle-redistribution)
    receipt_kind=dependency-bundle-redistribution
    target_name=dependency-bundle-redistribution-notices.md
    ;;
  *)
    usage
    ;;
esac

receipt=${2:-}
if [ -z "$receipt" ]; then
  usage
fi

evidence_dir="${3:-release/evidence/$version}"
test -s "$receipt"

if grep -Ei 'TODO|TBD|unresolved|missing|placeholder|dummy|retained evidence' "$receipt" >/dev/null; then
  echo "release_operations_receipt_intake refused placeholder receipt: $receipt" >&2
  exit 1
fi

require_field() {
  expected=$1
  grep -F "$expected" "$receipt" >/dev/null
}

case "$receipt_kind" in
  publication)
    require_field "version=$version"
    require_field "tag=v$version"
    require_field "artifacts_published=true"
    require_field "checksums_published=true"
    require_field "signatures_published=true"
    require_field "release_notes_published=true"
    ;;
  dependency-bundle-redistribution)
    require_field "all_copied_host_libraries_accounted=true"
    require_field "redistribution_notices_complete=true"
    require_field "bundle_manifest_redistribution_ready=true"
    require_field "bundle_license_payload_complete=true"
    ;;
esac

mkdir -p "$evidence_dir"
cp "$receipt" "$evidence_dir/$target_name"
test -s "$evidence_dir/$target_name"

echo "release_operations_receipt_intake version=$version receipt=$receipt_kind semantic=true placeholder_blocking=true retained=true path=$evidence_dir"
