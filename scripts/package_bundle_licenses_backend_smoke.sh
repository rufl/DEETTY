#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-bundle-license-backend.XXXXXX")
cleanup() {
  if [ -n "${scratch:-}" ] && [ -d "$scratch" ]; then
    find "$scratch" -depth -delete 2>/dev/null || true
  fi
}
trap cleanup EXIT HUP INT TERM

fakebin="$scratch/bin"
stage="$scratch/stage"
library="$scratch/libfixture.so.1"
copyright="$scratch/copyright"
sources="$scratch/library-sources.txt"
library_inventory="$scratch/library-inventory.txt"
package_inventory="$scratch/package-inventory.txt"
license_files="$scratch/license-files.txt"
mkdir -p "$fakebin" "$stage"
: >"$library"
printf 'Fixture license and copyright notice.\n' >"$copyright"
printf '%s\n' "$library" >"$sources"

printf '%s\n' \
  '#!/usr/bin/env sh' \
  'set -eu' \
  'case "$1" in' \
  '  -S)' \
  '    test "$2" = "$NOCTTY_FIXTURE_LIBRARY"' \
  '    printf "libfixture1:amd64: %s\\n" "$NOCTTY_FIXTURE_LIBRARY"' \
  '    ;;' \
  '  -W)' \
  '    printf "1.2.3-1\\n"' \
  '    ;;' \
  '  -L)' \
  '    printf "%s\\n" "$NOCTTY_FIXTURE_COPYRIGHT"' \
  '    ;;' \
  '  *) exit 2 ;;' \
  'esac' >"$fakebin/dpkg-query"
chmod +x "$fakebin/dpkg-query"

output=$(NOCTTY_PACKAGE_BACKEND=debian \
  NOCTTY_FIXTURE_LIBRARY="$library" \
  NOCTTY_FIXTURE_COPYRIGHT="$copyright" \
  PATH="$fakebin:$PATH" \
  ./scripts/package_bundle_licenses.sh "$sources" "$stage" \
    "$library_inventory" "$package_inventory" "$license_files")
printf '%s\n' "$output" | grep -F \
  'package_bundle_licenses backend=debian libraries=1 packages=1 license_files=1 all_copied_host_libraries_accounted=true redistribution_notices_complete=true fail_closed=true' \
  >/dev/null
grep -F 'package=libfixture1:amd64' "$library_inventory" >/dev/null
grep -F 'license="SEE-DEBIAN-COPYRIGHT"' "$library_inventory" >/dev/null
grep -F 'version=1.2.3-1' "$package_inventory" >/dev/null
grep -F 'license_source=debian_installed_copyright' "$package_inventory" >/dev/null
test "$(find "$stage/share/licenses/noctty/dependencies/packages" -type f | wc -l)" -eq 1

unowned="$scratch/unowned.so"
printf 'unowned\n' >"$unowned"
printf '%s\n' "$unowned" >"$sources"
mkdir -p "$scratch/unowned-stage"
if NOCTTY_PACKAGE_BACKEND=debian \
  NOCTTY_FIXTURE_LIBRARY="$library" \
  NOCTTY_FIXTURE_COPYRIGHT="$copyright" \
  PATH="$fakebin:$PATH" \
  ./scripts/package_bundle_licenses.sh "$sources" "$scratch/unowned-stage" \
    "$scratch/unowned-library-inventory.txt" \
    "$scratch/unowned-package-inventory.txt" \
    "$scratch/unowned-license-files.txt" >/dev/null 2>&1; then
  echo 'package_bundle_licenses_backend unowned library unexpectedly accepted' >&2
  exit 1
fi

scratch_path=$scratch
find "$scratch_path" -depth -delete
scratch=
test ! -e "$scratch_path"
echo 'package_bundle_licenses_backend_smoke debian=true version=true copyright=true library_inventory=true package_inventory=true fail_closed=true scratch_clean=true'
