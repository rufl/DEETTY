#!/usr/bin/env sh
set -eu

release_value() {
  sed -n "s/^pub const $1 = \"\([^\"]*\)\";$/\1/p" src/release.zig
}

version=$(release_value version)
release_date=$(release_value release_date)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-reproducibility.XXXXXX")

cleanup() {
  if [ -n "${scratch:-}" ]; then rm -rf "$scratch"; fi
}
trap cleanup EXIT HUP INT TERM

archive="$scratch/deetty-$version.tar.gz"
tarball_output=$(./scripts/package_tarball.sh "$archive")
printf '%s\n' "$tarball_output"
printf '%s\n' "$tarball_output" | grep -F "package_tarball_reproducibility version=$version release_date=$release_date builds=2 isolated=true release_safe=true stripped=true byte_identical=true checksums_match=true archive_valid=true cli_version=true scratch_clean=true" >/dev/null

test -s "$archive"
test -s "$archive.sha256"
test "$(stat -c %a "$archive")" = 644
test "$(stat -c %a "$archive.sha256")" = 644
(cd "$scratch" && sha256sum -c "$(basename "$archive").sha256" >/dev/null)
mkdir -p "$scratch/extracted"
tar -xzf "$archive" -C "$scratch/extracted"
contract_output=$(./scripts/release_contract_smoke.sh "$scratch/extracted/bin/deetty")
printf '%s\n' "$contract_output"

scratch_path=$scratch
rm -rf "$scratch_path"
scratch=
test ! -e "$scratch_path"

echo "package_reproducibility version=$version release_date=$release_date builds=2 isolated=true byte_identical=true checksums_match=true archive_valid=true cli_version=true scratch_clean=true"
