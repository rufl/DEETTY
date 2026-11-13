#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/dintty-release-acceptance-intake.XXXXXX")

cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
}
trap cleanup EXIT HUP INT TERM

src="$scratch/src"
evidence="$scratch/evidence"
mkdir -p "$src" "$evidence"

make_artifact() {
  arch=$1
  archive="$src/input-$arch.tar.gz"
  printf '%s retained artifact\n' "$arch" >"$archive"
  (
    cd "$src"
    sha256sum "$(basename "$archive")" >"$(basename "$archive").sha256"
  )
  digest=$(sed -n '1s/[[:space:]].*$//p' "$archive.sha256")
  {
    printf 'bundle_manifest_version=1\n'
    printf 'version=0.1.0\n'
    printf 'architecture=%s\n' "$arch"
    printf 'archive_sha256=%s\n' "$digest"
    printf 'installed_files_begin\n'
    printf 'bin/dintty\n'
    printf 'installed_files_end\n'
    printf 'library_inventory_begin\n'
    printf 'libexample.so|sha256=example\n'
    printf 'library_inventory_end\n'
  } >"$archive.manifest"
}

make_signature() {
  arch=$1
  target=$2
  signature="$src/$arch-$target.sig"
  printf 'signed-by-release-key arch=%s target=%s\n' "$arch" "$target" >"$signature"
  ./scripts/release_operations_signature_intake.sh "$arch" "$target" "$signature" "$evidence" >/dev/null
}

make_compositor_receipt() {
  compositor=$1
  receipt="$src/$compositor.txt"
  {
    printf 'version=0.1.0\n'
    printf 'compositor=%s\n' "$compositor"
    printf 'native_release_smoke=true\n'
    printf 'operator_acceptance=true\n'
    printf 'session=fixture-session\n'
    printf 'captured_at_utc=2026-07-14T00:00:00Z\n'
    printf 'operator=release-operator\n'
  } >"$receipt"
  output=$(./scripts/release_operations_acceptance_intake.sh compositor "$compositor" "$receipt" "$evidence")
  printf '%s\n' "$output" | grep -F "release_operations_acceptance_intake version=0.1.0 receipt=compositor compositor=$compositor semantic=true placeholder_blocking=true retained=true path=$evidence" >/dev/null
}

make_artifact x86_64
make_artifact aarch64
./scripts/release_operations_artifact_intake.sh x86_64 "$src/input-x86_64.tar.gz" "$evidence" >/dev/null
./scripts/release_operations_artifact_intake.sh aarch64 "$src/input-aarch64.tar.gz" "$evidence" >/dev/null
for arch in x86_64 aarch64; do
  make_signature "$arch" archive
  make_signature "$arch" checksum
  make_signature "$arch" manifest
done

publication_receipt="$src/publication-receipt.txt"
{
  printf 'version=0.1.0\n'
  printf 'tag=v0.1.0\n'
  printf 'artifacts_published=true\n'
  printf 'checksums_published=true\n'
  printf 'signatures_published=true\n'
  printf 'release_notes_published=true\n'
  printf 'publication_url=https://example.invalid/dintty/0.1.0\n'
  printf 'published_at_utc=2026-07-14T00:00:00Z\n'
  printf 'operator=release-operator\n'
} >"$publication_receipt"

redistribution_receipt="$src/dependency-bundle-redistribution-notices.md"
{
  printf '# Dependency Bundle Redistribution Notices\n'
  printf 'all_copied_host_libraries_accounted=true\n'
  printf 'redistribution_notices_complete=true\n'
  printf 'bundle_manifest_redistribution_ready=true\n'
  printf 'bundle_license_payload_complete=true\n'
  printf 'inventory=fixture-only\n'
} >"$redistribution_receipt"

./scripts/release_operations_receipt_intake.sh publication "$publication_receipt" "$evidence" >/dev/null
./scripts/release_operations_receipt_intake.sh dependency-bundle-redistribution "$redistribution_receipt" "$evidence" >/dev/null

pre_acceptance_status=$(DINTTY_RELEASE_EVIDENCE_DIR="$evidence" ./scripts/release_operations_status.sh)
printf '%s\n' "$pre_acceptance_status" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=true signatures=true publication=true dependency_bundle_redistribution=true compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=2' >/dev/null

for compositor in niri hyprland sway scroll labwc mango; do
  make_compositor_receipt "$compositor"
done

hid_receipt="$src/wayland-hid-consent-receipt.txt"
{
  printf 'version=0.1.0\n'
  printf 'portal=RemoteDesktop/EIS\n'
  printf 'explicit_user_consent=true\n'
  printf 'physical_input_receipt=true\n'
  printf 'captured_at_utc=2026-07-14T00:00:00Z\n'
  printf 'operator=release-operator\n'
} >"$hid_receipt"
hid_output=$(./scripts/release_operations_acceptance_intake.sh wayland-hid "$hid_receipt" "$evidence")
printf '%s\n' "$hid_output" | grep -F "release_operations_acceptance_intake version=0.1.0 receipt=wayland-hid semantic=true placeholder_blocking=true retained=true path=$evidence" >/dev/null

status_output=$(DINTTY_RELEASE_EVIDENCE_DIR="$evidence" ./scripts/release_operations_status.sh --require-complete --list-missing)
printf '%s\n' "$status_output" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=true signatures=true publication=true dependency_bundle_redistribution=true compositor_acceptance=true wayland_hid_consent=true complete=true external_blockers=0' >/dev/null
printf '%s\n' "$status_output" | grep -F 'release_operations_issues total=0' >/dev/null

victim="$scratch/acceptance-victim"
printf 'victim-safe\n' >"$victim"
retained_receipt="$evidence/compositors/niri.txt"
rm -f "$retained_receipt"
ln -s "$victim" "$retained_receipt"
./scripts/release_operations_acceptance_intake.sh compositor niri \
  "$src/niri.txt" "$evidence" >/dev/null
test "$(cat "$victim")" = victim-safe
test ! -L "$retained_receipt"
cmp -s "$src/niri.txt" "$retained_receipt"

placeholder_receipt="$src/placeholder-compositor.txt"
printf 'version=0.1.0\ncompositor=niri\nTODO acceptance\n' >"$placeholder_receipt" # craft-ignore: intentional rejected fixture
if ./scripts/release_operations_acceptance_intake.sh compositor niri "$placeholder_receipt" "$scratch/placeholder-evidence" >/dev/null 2>&1; then
  echo "release_operations_acceptance_intake_smoke expected placeholder receipt to fail" >&2
  exit 1
fi

mismatch_receipt="$src/mismatch-compositor.txt"
{
  printf 'version=0.1.0\n'
  printf 'compositor=sway\n'
  printf 'native_release_smoke=true\n'
  printf 'operator_acceptance=true\n'
} >"$mismatch_receipt"
if ./scripts/release_operations_acceptance_intake.sh compositor niri "$mismatch_receipt" "$scratch/mismatch-evidence" >/dev/null 2>&1; then
  echo "release_operations_acceptance_intake_smoke expected compositor mismatch to fail" >&2
  exit 1
fi

missing_consent_receipt="$src/missing-consent.txt"
{
  printf 'version=0.1.0\n'
  printf 'portal=RemoteDesktop/EIS\n'
  printf 'explicit_user_consent=false\n'
  printf 'physical_input_receipt=true\n'
} >"$missing_consent_receipt"
if ./scripts/release_operations_acceptance_intake.sh wayland-hid "$missing_consent_receipt" "$scratch/missing-consent-evidence" >/dev/null 2>&1; then
  echo "release_operations_acceptance_intake_smoke expected missing consent to fail" >&2
  exit 1
fi

scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"

echo "release_operations_acceptance_intake_smoke compositors=6 wayland_hid=true semantic=true placeholder_blocked=true compositor_mismatch_blocked=true consent_required=true complete_status=true scratch_clean=true"
