#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-release-signature-intake.XXXXXX")

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
  output=$(./scripts/release_operations_signature_intake.sh "$arch" "$target" "$signature" "$evidence")
  printf '%s\n' "$output" | grep -F "release_operations_signature_intake version=0.1.0 arch=$arch target=$target signature=true retained=true path=$evidence" >/dev/null
}

make_artifact x86_64
make_artifact aarch64
./scripts/release_operations_artifact_intake.sh x86_64 "$src/input-x86_64.tar.gz" "$evidence" >/dev/null
./scripts/release_operations_artifact_intake.sh aarch64 "$src/input-aarch64.tar.gz" "$evidence" >/dev/null

initial_status=$(DEETTY_RELEASE_EVIDENCE_DIR="$evidence" ./scripts/release_operations_status.sh)
printf '%s\n' "$initial_status" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=true signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=5' >/dev/null

make_signature x86_64 archive
make_signature x86_64 checksum
make_signature x86_64 manifest
make_signature aarch64 archive
make_signature aarch64 checksum
make_signature aarch64 manifest

status_output=$(DEETTY_RELEASE_EVIDENCE_DIR="$evidence" ./scripts/release_operations_status.sh --list-missing)
printf '%s\n' "$status_output" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=true signatures=true publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=4' >/dev/null
printf '%s\n' "$status_output" | grep -F 'release_operations_issue category=publication path=publication-receipt.txt reason=missing' >/dev/null

placeholder_sig="$src/placeholder.sig"
printf 'TODO signature retained evidence\n' >"$placeholder_sig" # craft-ignore: intentional rejected fixture
if ./scripts/release_operations_signature_intake.sh x86_64 archive "$placeholder_sig" "$evidence" >/dev/null 2>&1; then
  echo "release_operations_signature_intake_smoke expected placeholder signature to fail" >&2
  exit 1
fi

target_required_sig="$src/target-required.sig"
printf 'signed-by-release-key arch=x86_64 target=archive\n' >"$target_required_sig"
if ./scripts/release_operations_signature_intake.sh x86_64 archive "$target_required_sig" "$scratch/missing-target-evidence" >/dev/null 2>&1; then
  echo "release_operations_signature_intake_smoke expected missing retained target to fail" >&2
  exit 1
fi

victim="$scratch/signature-victim"
printf 'victim-safe\n' >"$victim"
retained_signature="$evidence/deetty-linux-x86_64.tar.gz.sig"
rm -f "$retained_signature"
ln -s "$victim" "$retained_signature"
./scripts/release_operations_signature_intake.sh x86_64 archive \
  "$src/x86_64-archive.sig" "$evidence" >/dev/null
test "$(cat "$victim")" = victim-safe
test ! -L "$retained_signature"
cmp -s "$src/x86_64-archive.sig" "$retained_signature"

scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"

echo "release_operations_signature_intake_smoke archive=true checksum=true manifest=true x86_64=true aarch64=true placeholder_blocked=true target_required=true retained_status=true scratch_clean=true"
