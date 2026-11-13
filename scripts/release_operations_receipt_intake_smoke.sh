#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-release-receipt-intake.XXXXXX")

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
    printf 'bin/deetty\n'
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

make_artifact x86_64
make_artifact aarch64
./scripts/release_operations_artifact_intake.sh x86_64 "$src/input-x86_64.tar.gz" "$evidence" >/dev/null
./scripts/release_operations_artifact_intake.sh aarch64 "$src/input-aarch64.tar.gz" "$evidence" >/dev/null
for arch in x86_64 aarch64; do
  make_signature "$arch" archive
  make_signature "$arch" checksum
  make_signature "$arch" manifest
done

pre_receipt_status=$(DEETTY_RELEASE_EVIDENCE_DIR="$evidence" ./scripts/release_operations_status.sh)
printf '%s\n' "$pre_receipt_status" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=true signatures=true publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=4' >/dev/null

publication_receipt="$src/publication-receipt.txt"
{
  printf 'version=0.1.0\n'
  printf 'tag=v0.1.0\n'
  printf 'artifacts_published=true\n'
  printf 'checksums_published=true\n'
  printf 'signatures_published=true\n'
  printf 'release_notes_published=true\n'
  printf 'publication_url=https://example.invalid/deetty/0.1.0\n'
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

publication_output=$(./scripts/release_operations_receipt_intake.sh publication "$publication_receipt" "$evidence")
redistribution_output=$(./scripts/release_operations_receipt_intake.sh dependency-bundle-redistribution "$redistribution_receipt" "$evidence")
printf '%s\n' "$publication_output" | grep -F "release_operations_receipt_intake version=0.1.0 receipt=publication semantic=true placeholder_blocking=true retained=true path=$evidence" >/dev/null
printf '%s\n' "$redistribution_output" | grep -F "release_operations_receipt_intake version=0.1.0 receipt=dependency-bundle-redistribution semantic=true placeholder_blocking=true retained=true path=$evidence" >/dev/null

status_output=$(DEETTY_RELEASE_EVIDENCE_DIR="$evidence" ./scripts/release_operations_status.sh --list-missing)
printf '%s\n' "$status_output" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=true signatures=true publication=true dependency_bundle_redistribution=true compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=2' >/dev/null
printf '%s\n' "$status_output" | grep -F 'release_operations_issue category=compositor_acceptance path=compositors/niri.txt reason=missing' >/dev/null

placeholder_receipt="$src/placeholder-publication.txt"
printf 'version=0.1.0\nTODO publication\n' >"$placeholder_receipt" # craft-ignore: intentional rejected fixture
if ./scripts/release_operations_receipt_intake.sh publication "$placeholder_receipt" "$scratch/placeholder-evidence" >/dev/null 2>&1; then
  echo "release_operations_receipt_intake_smoke expected placeholder receipt to fail" >&2
  exit 1
fi

incomplete_receipt="$src/incomplete-publication.txt"
{
  printf 'version=0.1.0\n'
  printf 'tag=v0.1.0\n'
  printf 'artifacts_published=true\n'
} >"$incomplete_receipt"
if ./scripts/release_operations_receipt_intake.sh publication "$incomplete_receipt" "$scratch/incomplete-evidence" >/dev/null 2>&1; then
  echo "release_operations_receipt_intake_smoke expected incomplete receipt to fail" >&2
  exit 1
fi

legacy_redistribution_receipt="$src/legacy-redistribution-receipt.txt"
{
  printf 'all_copied_host_libraries_accounted=true\n'
  printf 'redistribution_notices_complete=true\n'
} >"$legacy_redistribution_receipt"
if ./scripts/release_operations_receipt_intake.sh dependency-bundle-redistribution \
  "$legacy_redistribution_receipt" "$scratch/legacy-redistribution-evidence" \
  >/dev/null 2>&1; then
  echo "release_operations_receipt_intake_smoke expected manifest-free redistribution receipt to fail" >&2
  exit 1
fi

publication_without_prereqs="$scratch/publication-without-prereqs"
mkdir -p "$publication_without_prereqs"
cp "$publication_receipt" "$publication_without_prereqs/publication-receipt.txt"
without_prereqs_status=$(DEETTY_RELEASE_EVIDENCE_DIR="$publication_without_prereqs" ./scripts/release_operations_status.sh --list-missing)
printf '%s\n' "$without_prereqs_status" | grep -F 'release_operations_issue category=publication path=publication-receipt.txt reason=publication_prerequisites_missing' >/dev/null

victim="$scratch/receipt-victim"
printf 'victim-safe\n' >"$victim"
retained_receipt="$evidence/publication-receipt.txt"
rm -f "$retained_receipt"
ln -s "$victim" "$retained_receipt"
./scripts/release_operations_receipt_intake.sh publication \
  "$publication_receipt" "$evidence" >/dev/null
test "$(cat "$victim")" = victim-safe
test ! -L "$retained_receipt"
cmp -s "$publication_receipt" "$retained_receipt"

scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"

echo "release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true"
