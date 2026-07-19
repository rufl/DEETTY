#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-release-ops-smoke.XXXXXX")

cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
}
trap cleanup EXIT HUP INT TERM

empty_evidence="$scratch/empty"
complete_evidence="$scratch/complete"
mkdir -p "$empty_evidence" "$complete_evidence/compositors"

empty_output=$(NOCTTY_RELEASE_EVIDENCE_DIR="$empty_evidence" ./scripts/release_operations_status.sh --list-missing)
printf '%s\n' "$empty_output" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=false signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=6' >/dev/null
printf '%s\n' "$empty_output" | grep -F 'release_operations_issue category=tagged_artifacts path=noctty-linux-x86_64.tar.gz reason=missing' >/dev/null
printf '%s\n' "$empty_output" | grep -F 'release_operations_issue category=compositor_acceptance path=compositors/niri.txt reason=missing' >/dev/null
printf '%s\n' "$empty_output" | grep -F 'release_operations_issues total=21' >/dev/null

if NOCTTY_RELEASE_EVIDENCE_DIR="$empty_evidence" ./scripts/release_operations_status.sh --require-complete >/dev/null; then
  echo "release_operations_status_smoke expected incomplete evidence to fail --require-complete" >&2
  exit 1
fi

printf 'x86_64 archive\n' >"$complete_evidence/noctty-linux-x86_64.tar.gz"
printf 'aarch64 archive\n' >"$complete_evidence/noctty-linux-aarch64.tar.gz"
(
  cd "$complete_evidence"
  sha256sum noctty-linux-x86_64.tar.gz >noctty-linux-x86_64.tar.gz.sha256
  sha256sum noctty-linux-aarch64.tar.gz >noctty-linux-aarch64.tar.gz.sha256
)
x86_64_digest=$(sed -n '1s/[[:space:]].*$//p' "$complete_evidence/noctty-linux-x86_64.tar.gz.sha256")
aarch64_digest=$(sed -n '1s/[[:space:]].*$//p' "$complete_evidence/noctty-linux-aarch64.tar.gz.sha256")

for arch_digest in "x86_64 $x86_64_digest" "aarch64 $aarch64_digest"; do
  set -- $arch_digest
  arch=$1
  digest=$2
  {
    printf 'bundle_manifest_version=1\n'
    printf 'version=0.1.0\n'
    printf 'architecture=%s\n' "$arch"
    printf 'archive_sha256=%s\n' "$digest"
    printf 'installed_files_begin\n'
    printf 'bin/noctty\n'
    printf 'installed_files_end\n'
    printf 'library_inventory_begin\n'
    printf 'libexample.so|sha256=example\n'
    printf 'library_inventory_end\n'
  } >"$complete_evidence/noctty-linux-$arch.tar.gz.manifest"
done

for file in \
  noctty-linux-x86_64.tar.gz.sig \
  noctty-linux-aarch64.tar.gz.sig \
  noctty-linux-x86_64.tar.gz.sha256.sig \
  noctty-linux-aarch64.tar.gz.sha256.sig \
  noctty-linux-x86_64.tar.gz.manifest.sig \
  noctty-linux-aarch64.tar.gz.manifest.sig; do
  printf 'SIGNATURE-FOR-%s\n' "$file" >"$complete_evidence/$file"
done

{
  printf 'version=0.1.0\n'
  printf 'tag=v0.1.0\n'
  printf 'artifacts_published=true\n'
  printf 'checksums_published=true\n'
  printf 'signatures_published=true\n'
  printf 'release_notes_published=true\n'
} >"$complete_evidence/publication-receipt.txt"

{
  printf 'all_copied_host_libraries_accounted=true\n'
  printf 'redistribution_notices_complete=true\n'
  printf 'bundle_manifest_redistribution_ready=true\n'
  printf 'bundle_license_payload_complete=true\n'
  printf 'notice_set=fixture\n'
} >"$complete_evidence/dependency-bundle-redistribution-notices.md"

for compositor in niri hyprland sway scroll labwc mango; do
  {
    printf 'version=0.1.0\n'
    printf 'compositor=%s\n' "$compositor"
    printf 'native_release_smoke=true\n'
    printf 'operator_acceptance=true\n'
  } >"$complete_evidence/compositors/$compositor.txt"
done

{
  printf 'version=0.1.0\n'
  printf 'portal=RemoteDesktop/EIS\n'
  printf 'explicit_user_consent=true\n'
  printf 'physical_input_receipt=true\n'
} >"$complete_evidence/wayland-hid-consent-receipt.txt"

complete_output=$(NOCTTY_RELEASE_EVIDENCE_DIR="$complete_evidence" ./scripts/release_operations_status.sh --require-complete --list-missing)
printf '%s\n' "$complete_output" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=true signatures=true publication=true dependency_bundle_redistribution=true compositor_acceptance=true wayland_hid_consent=true complete=true external_blockers=0' >/dev/null
printf '%s\n' "$complete_output" | grep -F 'release_operations_issues total=0' >/dev/null

scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"

echo "release_operations_status_smoke missing_diagnostics=true require_complete_blocks=true complete_fixture=true checksum_verified=true semantic_receipts=true bundle_manifest_attestation=true scratch_clean=true"
