#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-bundle-smoke.XXXXXX")
cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
}
trap cleanup EXIT HUP INT TERM

archive="$scratch/noctty-linux-bundle.tar.gz"
output=$(./scripts/package_bundle.sh "$archive")
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'manifest=true' >/dev/null
printf '%s\n' "$output" | grep -F 'library_inventory=true' >/dev/null
printf '%s\n' "$output" | grep -F 'package_inventory=true' >/dev/null
printf '%s\n' "$output" | grep -F 'license_payload=true' >/dev/null
printf '%s\n' "$output" | grep -F 'redistribution_ready=true' >/dev/null
printf '%s\n' "$output" | grep -F 'provenance=complete' >/dev/null
printf '%s\n' "$output" | grep -E \
  'package_bundle_licenses backend=(arch|debian) libraries=[1-9][0-9]* packages=[1-9][0-9]* license_files=[1-9][0-9]* all_copied_host_libraries_accounted=true redistribution_notices_complete=true fail_closed=true' \
  >/dev/null

test -s "$archive"
test -s "$archive.sha256"
test -s "$archive.manifest"
test "$(stat -c %a "$archive")" = 644
test "$(stat -c %a "$archive.sha256")" = 644
test "$(stat -c %a "$archive.manifest")" = 644
(cd "$scratch" && sha256sum -c "$(basename "$archive").sha256" >/dev/null)
tar -tzf "$archive" | grep -F './bin/noctty' >/dev/null
tar -tzf "$archive" | grep -F './bin/nocted' >/dev/null
tar -tzf "$archive" | grep -F './libexec/noctty/noctty' >/dev/null
tar -tzf "$archive" | grep -F './libexec/noctty/nocted' >/dev/null
tar -tzf "$archive" | grep -F './libexec/noctty/runtime-dependencies.txt' >/dev/null
tar -tzf "$archive" | grep -F './share/licenses/noctty/dependencies/packages/' >/dev/null

grep -F 'bundle_manifest_version=1' "$archive.manifest" >/dev/null
grep -F 'archive_sha256=' "$archive.manifest" >/dev/null
grep -F 'installed_files_begin' "$archive.manifest" >/dev/null
grep -F 'installed_files_end' "$archive.manifest" >/dev/null
grep -F 'bundled_libraries_begin' "$archive.manifest" >/dev/null
grep -F 'bundled_libraries_end' "$archive.manifest" >/dev/null
grep -F 'library_inventory_begin' "$archive.manifest" >/dev/null
grep -F 'library_inventory_end' "$archive.manifest" >/dev/null
grep -F 'package_inventory_begin' "$archive.manifest" >/dev/null
grep -F 'package_inventory_end' "$archive.manifest" >/dev/null
grep -F 'license_files_begin' "$archive.manifest" >/dev/null
grep -F 'license_files_end' "$archive.manifest" >/dev/null
grep -F 'gtk_layer_shell_license=LGPL-3.0-or-later' "$archive.manifest" >/dev/null
grep -F 'redistribution_ready=true' "$archive.manifest" >/dev/null
grep -F 'redistribution_blocker=none' "$archive.manifest" >/dev/null
grep -F 'license_inventory_version=1' "$archive.manifest" >/dev/null
grep -F 'all_copied_host_libraries_accounted=true' "$archive.manifest" >/dev/null
grep -F 'bundle_license_payload_complete=true' "$archive.manifest" >/dev/null
if command -v pacman >/dev/null 2>&1; then
  grep -F 'gtksourceview_4_8_upstream_and_binary_notice_override' "$archive.manifest" >/dev/null
else
  grep -F 'license_source=debian_installed_copyright' "$archive.manifest" >/dev/null
fi
! grep -E 'system-runtime-unresolved|not_inventoried|LicenseRef-None' "$archive.manifest" >/dev/null

unowned="$scratch/unowned-library.so"
unowned_sources="$scratch/unowned-sources.txt"
unowned_stage="$scratch/unowned-stage"
mkdir -p "$unowned_stage"
: >"$unowned"
printf '%s\n' "$unowned" >"$unowned_sources"
if ./scripts/package_bundle_licenses.sh "$unowned_sources" "$unowned_stage" \
  "$scratch/unowned-library-inventory.txt" \
  "$scratch/unowned-package-inventory.txt" \
  "$scratch/unowned-license-files.txt" >/dev/null 2>&1; then
  echo 'package_bundle_manifest unowned library unexpectedly accepted' >&2
  exit 1
fi

scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"
echo "package_bundle_manifest manifest=true archive=true checksum=true installed_files=true library_inventory=true package_inventory=true license_payload=true all_libraries_accounted=true gtk_layer_shell_license=LGPL-3.0-or-later redistribution_ready=true fail_closed=true scratch_clean=true"
