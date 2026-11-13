#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-release-artifact-intake.XXXXXX")

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

make_artifact x86_64
make_artifact aarch64

x86_64_output=$(./scripts/release_operations_artifact_intake.sh x86_64 "$src/input-x86_64.tar.gz" "$evidence")
aarch64_output=$(./scripts/release_operations_artifact_intake.sh aarch64 "$src/input-aarch64.tar.gz" "$evidence")
printf '%s\n' "$x86_64_output" | grep -F "release_operations_artifact_intake version=0.1.0 arch=x86_64 archive=true checksum=true manifest=true" >/dev/null
printf '%s\n' "$aarch64_output" | grep -F "release_operations_artifact_intake version=0.1.0 arch=aarch64 archive=true checksum=true manifest=true" >/dev/null

status_output=$(DEETTY_RELEASE_EVIDENCE_DIR="$evidence" ./scripts/release_operations_status.sh --list-missing)
printf '%s\n' "$status_output" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=true signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=5' >/dev/null
printf '%s\n' "$status_output" | grep -F 'release_operations_issue category=signatures path=deetty-linux-x86_64.tar.gz.sig reason=missing' >/dev/null

bad_archive="$src/bad-x86_64.tar.gz"
printf 'bad artifact\n' >"$bad_archive"
(
  cd "$src"
  sha256sum "$(basename "$bad_archive")" >"$(basename "$bad_archive").sha256"
)
bad_digest=$(sed -n '1s/[[:space:]].*$//p' "$bad_archive.sha256")
{
  printf 'bundle_manifest_version=1\n'
  printf 'architecture=aarch64\n'
  printf 'archive_sha256=%s\n' "$bad_digest"
  printf 'installed_files_begin\n'
  printf 'library_inventory_begin\n'
} >"$bad_archive.manifest"

if ./scripts/release_operations_artifact_intake.sh x86_64 "$bad_archive" "$scratch/bad-evidence" >/dev/null 2>&1; then
  echo "release_operations_artifact_intake_smoke expected architecture mismatch to fail" >&2
  exit 1
fi

symlink_evidence="$scratch/symlink-evidence"
mkdir -p "$symlink_evidence"
victim="$scratch/artifact-victim"
printf 'victim-safe\n' >"$victim"
ln -s "$victim" "$symlink_evidence/deetty-linux-x86_64.tar.gz"
./scripts/release_operations_artifact_intake.sh x86_64 \
  "$src/input-x86_64.tar.gz" "$symlink_evidence" >/dev/null
test "$(cat "$victim")" = victim-safe
test ! -L "$symlink_evidence/deetty-linux-x86_64.tar.gz"
cmp -s "$src/input-x86_64.tar.gz" "$symlink_evidence/deetty-linux-x86_64.tar.gz"

scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"

echo "release_operations_artifact_intake_smoke x86_64=true aarch64=true sidecars_verified=true retained_status=true mismatch_blocked=true scratch_clean=true"
