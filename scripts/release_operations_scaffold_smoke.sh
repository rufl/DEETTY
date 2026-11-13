#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/dintty-release-scaffold-smoke.XXXXXX")

cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
}
trap cleanup EXIT HUP INT TERM

evidence="$scratch/evidence"
scaffold_output=$(./scripts/release_operations_scaffold.sh "$evidence")
printf '%s\n' "$scaffold_output" | grep -F "release_operations_scaffold version=0.1.0 path=$evidence receipt_templates=true compositor_templates=6 placeholder_blocking=true artifact_files=false" >/dev/null

test -s "$evidence/README.md"
test -s "$evidence/publication-receipt.txt"
test -s "$evidence/dependency-bundle-redistribution-notices.md"
test -s "$evidence/wayland-hid-consent-receipt.txt"
for compositor in niri hyprland sway scroll labwc mango; do
  test -s "$evidence/compositors/$compositor.txt"
done

if [ -e "$evidence/dintty-linux-x86_64.tar.gz" ] ||
  [ -e "$evidence/dintty-linux-aarch64.tar.gz" ] ||
  [ -e "$evidence/dintty-linux-x86_64.tar.gz.sig" ] ||
  [ -e "$evidence/dintty-linux-aarch64.tar.gz.sig" ]; then
  echo "release_operations_scaffold_smoke scaffold created fake artifact/signature files" >&2
  exit 1
fi

status_output=$(DINTTY_RELEASE_EVIDENCE_DIR="$evidence" ./scripts/release_operations_status.sh --list-missing)
printf '%s\n' "$status_output" | grep -F 'release_operations_status version=0.1.0 tagged_artifacts=false signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=6' >/dev/null
printf '%s\n' "$status_output" | grep -F 'release_operations_issue category=publication path=publication-receipt.txt reason=receipt_field_missing' >/dev/null
printf '%s\n' "$status_output" | grep -F 'release_operations_issue category=publication path=publication-receipt.txt reason=placeholder_text' >/dev/null
printf '%s\n' "$status_output" | grep -F 'release_operations_issue category=compositor_acceptance path=compositors/niri.txt reason=placeholder_text' >/dev/null
printf '%s\n' "$status_output" | grep -F 'release_operations_issue category=wayland_hid_consent path=wayland-hid-consent-receipt.txt reason=receipt_field_missing' >/dev/null

if DINTTY_RELEASE_EVIDENCE_DIR="$evidence" ./scripts/release_operations_status.sh --require-complete >/dev/null; then
  echo "release_operations_scaffold_smoke expected scaffold to fail --require-complete" >&2
  exit 1
fi

scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"

echo "release_operations_scaffold_smoke templates=true fake_artifacts=false placeholder_blocked=true require_complete_blocks=true scratch_clean=true"
