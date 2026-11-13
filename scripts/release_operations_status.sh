#!/usr/bin/env sh
set -eu

export LC_ALL=C

release_value() {
  sed -n "s/^pub const $1 = \"\([^\"]*\)\";$/\1/p" src/release.zig
}

has_file() {
  test -s "$1"
}

version=$(release_value version)
evidence_dir="${DEETTY_RELEASE_EVIDENCE_DIR:-release/evidence/$version}"
require_complete=false
list_missing=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --require-complete)
      require_complete=true
      ;;
    --list-missing)
      list_missing=true
      ;;
    *)
      echo "usage: $0 [--require-complete] [--list-missing]" >&2
      exit 2
      ;;
  esac
  shift
done

issues_report=
if [ "$list_missing" = true ]; then
  issues_report=$(mktemp "${TMPDIR:-/tmp}/deetty-release-issues.XXXXXX")
fi

cleanup() {
  if [ -n "${issues_report:-}" ]; then rm -f "$issues_report"; fi
}
trap cleanup EXIT HUP INT TERM

issue_count=0
record_issue() {
  category=$1
  path=$2
  reason=$3
  issue_count=$((issue_count + 1))
  if [ "$list_missing" = true ]; then
    printf 'release_operations_issue category=%s path=%s reason=%s\n' "$category" "$path" "$reason" >>"$issues_report"
  fi
}

check_file() {
  category=$1
  rel_path=$2
  if has_file "$evidence_dir/$rel_path"; then
    return 0
  fi
  record_issue "$category" "$rel_path" "missing"
  return 1
}

check_no_placeholder() {
  category=$1
  rel_path=$2
  if grep -Ei 'TODO|TBD|unresolved|missing|placeholder|dummy|retained evidence' "$evidence_dir/$rel_path" >/dev/null; then # craft-ignore: intentional placeholder rejection
    record_issue "$category" "$rel_path" "placeholder_text"
    return 1
  fi
  return 0
}

check_contains() {
  category=$1
  rel_path=$2
  expected=$3
  reason=$4
  if grep -F "$expected" "$evidence_dir/$rel_path" >/dev/null; then
    return 0
  fi
  record_issue "$category" "$rel_path" "$reason"
  return 1
}

checksum_digest() {
  sed -n '1s/[[:space:]].*$//p' "$1"
}

validate_manifest() {
  arch=$1
  checksum_file="deetty-linux-$arch.tar.gz.sha256"
  manifest_file="deetty-linux-$arch.tar.gz.manifest"
  digest=$(checksum_digest "$evidence_dir/$checksum_file")
  ok=true
  if ! check_contains tagged_artifacts "$manifest_file" "architecture=$arch" "manifest_architecture_mismatch"; then
    ok=false
  fi
  if ! check_contains tagged_artifacts "$manifest_file" "archive_sha256=$digest" "manifest_digest_mismatch"; then
    ok=false
  fi
  if ! check_contains tagged_artifacts "$manifest_file" "bundle_manifest_version=1" "manifest_version_missing"; then
    ok=false
  fi
  if ! check_contains tagged_artifacts "$manifest_file" "installed_files_begin" "manifest_installed_files_missing"; then
    ok=false
  fi
  if ! check_contains tagged_artifacts "$manifest_file" "library_inventory_begin" "manifest_library_inventory_missing"; then
    ok=false
  fi
  if [ "$ok" = true ]; then
    return 0
  fi
  return 1
}

tagged_artifacts=false
tagged_artifacts_ready=true
for file in \
  deetty-linux-x86_64.tar.gz \
  deetty-linux-x86_64.tar.gz.sha256 \
  deetty-linux-x86_64.tar.gz.manifest \
  deetty-linux-aarch64.tar.gz \
  deetty-linux-aarch64.tar.gz.sha256 \
  deetty-linux-aarch64.tar.gz.manifest; do
  if ! check_file tagged_artifacts "$file"; then
    tagged_artifacts_ready=false
  fi
done
if [ "$tagged_artifacts_ready" = true ]; then
  (
    cd "$evidence_dir"
    sha256sum -c deetty-linux-x86_64.tar.gz.sha256 >/dev/null
    sha256sum -c deetty-linux-aarch64.tar.gz.sha256 >/dev/null
  )
  if ! validate_manifest x86_64; then
    tagged_artifacts_ready=false
  fi
  if ! validate_manifest aarch64; then
    tagged_artifacts_ready=false
  fi
  if [ "$tagged_artifacts_ready" = true ]; then
    tagged_artifacts=true
  fi
fi

signatures=false
signatures_ready=true
for file in \
  deetty-linux-x86_64.tar.gz.sig \
  deetty-linux-aarch64.tar.gz.sig \
  deetty-linux-x86_64.tar.gz.sha256.sig \
  deetty-linux-aarch64.tar.gz.sha256.sig \
  deetty-linux-x86_64.tar.gz.manifest.sig \
  deetty-linux-aarch64.tar.gz.manifest.sig; do
  if ! check_file signatures "$file"; then
    signatures_ready=false
  fi
done
if [ "$signatures_ready" = true ]; then
  for file in \
    deetty-linux-x86_64.tar.gz.sig \
    deetty-linux-aarch64.tar.gz.sig \
    deetty-linux-x86_64.tar.gz.sha256.sig \
    deetty-linux-aarch64.tar.gz.sha256.sig \
    deetty-linux-x86_64.tar.gz.manifest.sig \
    deetty-linux-aarch64.tar.gz.manifest.sig; do
    if ! check_no_placeholder signatures "$file"; then
      signatures_ready=false
    fi
  done
  if [ "$signatures_ready" = true ]; then
    signatures=true
  fi
fi

publication=false
if check_file publication publication-receipt.txt; then
  publication_ready=true
  for expected in \
    "version=$version" \
    "tag=v$version" \
    "artifacts_published=true" \
    "checksums_published=true" \
    "signatures_published=true" \
    "release_notes_published=true"; do
    if ! check_contains publication publication-receipt.txt "$expected" receipt_field_missing; then
      publication_ready=false
    fi
  done
  if ! check_no_placeholder publication publication-receipt.txt; then
    publication_ready=false
  fi
  if [ "$tagged_artifacts" != true ] || [ "$signatures" != true ]; then
    record_issue publication publication-receipt.txt publication_prerequisites_missing
    publication_ready=false
  fi
  if [ "$publication_ready" = true ]; then
    publication=true
  fi
fi

dependency_bundle_redistribution=false
if check_file dependency_bundle_redistribution dependency-bundle-redistribution-notices.md; then
  if check_no_placeholder dependency_bundle_redistribution dependency-bundle-redistribution-notices.md &&
    check_contains dependency_bundle_redistribution dependency-bundle-redistribution-notices.md "all_copied_host_libraries_accounted=true" receipt_field_missing &&
    check_contains dependency_bundle_redistribution dependency-bundle-redistribution-notices.md "redistribution_notices_complete=true" receipt_field_missing &&
    check_contains dependency_bundle_redistribution dependency-bundle-redistribution-notices.md "bundle_manifest_redistribution_ready=true" receipt_field_missing &&
    check_contains dependency_bundle_redistribution dependency-bundle-redistribution-notices.md "bundle_license_payload_complete=true" receipt_field_missing; then
    dependency_bundle_redistribution=true
  fi
fi

compositor_acceptance=false
compositor_acceptance_ready=true
for file in \
  compositors/niri.txt \
  compositors/hyprland.txt \
  compositors/sway.txt \
  compositors/scroll.txt \
  compositors/labwc.txt \
  compositors/mango.txt; do
  if ! check_file compositor_acceptance "$file"; then
    compositor_acceptance_ready=false
  fi
done
if [ "$compositor_acceptance_ready" = true ]; then
  for compositor in niri hyprland sway scroll labwc mango; do
    file="compositors/$compositor.txt"
    if ! check_contains compositor_acceptance "$file" "version=$version" receipt_field_missing; then
      compositor_acceptance_ready=false
    fi
    if ! check_contains compositor_acceptance "$file" "compositor=$compositor" receipt_field_missing; then
      compositor_acceptance_ready=false
    fi
    if ! check_contains compositor_acceptance "$file" "native_release_smoke=true" receipt_field_missing; then
      compositor_acceptance_ready=false
    fi
    if ! check_contains compositor_acceptance "$file" "operator_acceptance=true" receipt_field_missing; then
      compositor_acceptance_ready=false
    fi
    if ! check_no_placeholder compositor_acceptance "$file"; then
      compositor_acceptance_ready=false
    fi
  done
  if [ "$compositor_acceptance_ready" = true ]; then
    compositor_acceptance=true
  fi
fi

wayland_hid_consent=false
if check_file wayland_hid_consent wayland-hid-consent-receipt.txt; then
  if check_contains wayland_hid_consent wayland-hid-consent-receipt.txt "version=$version" receipt_field_missing &&
    check_contains wayland_hid_consent wayland-hid-consent-receipt.txt "portal=RemoteDesktop/EIS" receipt_field_missing &&
    check_contains wayland_hid_consent wayland-hid-consent-receipt.txt "explicit_user_consent=true" receipt_field_missing &&
    check_contains wayland_hid_consent wayland-hid-consent-receipt.txt "physical_input_receipt=true" receipt_field_missing &&
    check_no_placeholder wayland_hid_consent wayland-hid-consent-receipt.txt; then
    wayland_hid_consent=true
  fi
fi

external_blockers=0
for status in "$tagged_artifacts" "$signatures" "$publication" \
  "$dependency_bundle_redistribution" "$compositor_acceptance" "$wayland_hid_consent"; do
  if [ "$status" != true ]; then
    external_blockers=$((external_blockers + 1))
  fi
done

complete=false
if [ "$external_blockers" -eq 0 ]; then
  complete=true
fi

echo "release_operations_status version=$version tagged_artifacts=$tagged_artifacts signatures=$signatures publication=$publication dependency_bundle_redistribution=$dependency_bundle_redistribution compositor_acceptance=$compositor_acceptance wayland_hid_consent=$wayland_hid_consent complete=$complete external_blockers=$external_blockers"

if [ "$list_missing" = true ]; then
  cat "$issues_report"
  echo "release_operations_issues total=$issue_count"
fi

if [ "$require_complete" = true ] && [ "$complete" != true ]; then
  exit 1
fi
