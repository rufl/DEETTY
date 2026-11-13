#!/usr/bin/env sh
set -eu

out="${1:-/tmp/dintty-linux-bundle.tar.gz}"
case "$out" in
  /*) out_path="$out" ;;
  *) out_path="$(pwd)/$out" ;;
esac
out_dir=$(dirname "$out_path")
out_name=$(basename "$out_path")
test -d "$out_dir"

release_version=$(sed -n 's/^pub const version = "\([^\"]*\)";$/\1/p' src/release.zig)
release_date=$(sed -n 's/^pub const release_date = "\([^\"]*\)";$/\1/p' src/release.zig)
test -n "$release_version"
test -n "$release_date"

scratch_parent=${DINTTY_BUNDLE_PARENT:-.}
case "$scratch_parent" in
  /*) ;;
  *) scratch_parent="$(pwd -P)/$scratch_parent" ;;
esac
scratch=
archive_tmp=
checksum_tmp=
manifest_tmp=
cleanup() {
  if [ -n "${scratch:-}" ] && [ -d "$scratch" ]; then
    find "$scratch" -depth -delete 2>/dev/null || true
  fi
  if [ -n "${archive_tmp:-}" ]; then rm -f "$archive_tmp"; fi
  if [ -n "${checksum_tmp:-}" ]; then rm -f "$checksum_tmp"; fi
  if [ -n "${manifest_tmp:-}" ]; then rm -f "$manifest_tmp"; fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

scratch=$(mktemp -d "$scratch_parent/.dintty-bundle.XXXXXX")
stage="$scratch/stage"
local_cache="$scratch/zig-local"
global_cache="$scratch/zig-global"
export TMPDIR="$scratch/tmp"
export XDG_CACHE_HOME="$scratch/xdg-cache"
archive_tmp=$(mktemp "$out_dir/.$out_name.tmp.XXXXXX")
checksum_tmp=$(mktemp "$out_dir/.$out_name.sha256.tmp.XXXXXX")
manifest_tmp=$(mktemp "$out_dir/.$out_name.manifest.tmp.XXXXXX")
manifest_path="$out_path.manifest"

mkdir -p "$stage" "$local_cache" "$global_cache" "$TMPDIR" "$XDG_CACHE_HOME"
ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build --cache-dir "$local_cache" test >/dev/null
ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build --cache-dir "$local_cache" check >/dev/null
ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build -Doptimize=ReleaseSafe -Dstrip=true --prefix "$stage" \
  --cache-dir "$local_cache"
mkdir -p "$stage/libexec/dintty/lib"
mv "$stage/bin/dintty" "$stage/libexec/dintty/dintty"
mv "$stage/bin/nocted" "$stage/libexec/dintty/nocted"
cp packaging/dintty-launcher "$stage/bin/dintty"
cp packaging/nocted-launcher "$stage/bin/nocted"
chmod +x "$stage/bin/dintty" "$stage/bin/nocted" \
  "$stage/libexec/dintty/dintty" "$stage/libexec/dintty/nocted"

library_sources="$scratch/library-sources.txt"
{
  ldd "$stage/libexec/dintty/dintty"
  ldd "$stage/libexec/dintty/nocted"
} | awk '/=> \/|^\// { for (i=1; i<=NF; i++) if ($i ~ /^\//) print $i }' |
  while IFS= read -r library; do readlink -f "$library"; done |
  sort -u > "$library_sources"
while IFS= read -r library; do
  cp -L "$library" "$stage/libexec/dintty/lib/"
done < "$library_sources"
layer_shell="$(ldconfig -p 2>/dev/null | awk '/libgtk-layer-shell\.so\.0 / { print $NF; exit }')"
layer_shell_source=system
if [ -z "$layer_shell" ] || [ ! -f "$layer_shell" ]; then
  retained_layer_shell="$HOME/.local/libexec/dintty-dogfood/lib/libgtk-layer-shell.so.0"
  retained_receipt="${XDG_STATE_HOME:-"$HOME/.local/state"}/dintty/dogfood-build.receipt"
  retained_expected=$(awk -F= '$1 == "layer_shell_sha256" { print $2; exit }' \
    "$retained_receipt" 2>/dev/null || true)
  retained_actual=$(sha256sum "$retained_layer_shell" 2>/dev/null |
    awk 'NR == 1 { print $1; exit }' || true)
  case "$retained_expected" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*)
      if [ "${#retained_expected}" -eq 64 ] &&
         [ "$retained_actual" = "$retained_expected" ]; then
        layer_shell="$retained_layer_shell"
        layer_shell_source=retained-private-runtime
      fi
      ;;
  esac
fi
if [ -z "$layer_shell" ] || [ ! -f "$layer_shell" ]; then
  echo "package_bundle missing system libgtk-layer-shell.so.0 or checksum-matching retained runtime" >&2
  exit 1
fi
if [ "$layer_shell_source" = retained-private-runtime ]; then
  export DINTTY_BUNDLE_RETAINED_LAYER_SHELL="$layer_shell"
else
  unset DINTTY_BUNDLE_RETAINED_LAYER_SHELL
fi
printf '%s\n' "$layer_shell" >> "$library_sources"
sort -u "$library_sources" -o "$library_sources"

cp packaging/runtime-dependencies.txt "$stage/libexec/dintty/"
test "$("$stage/bin/dintty" --version)" = "dintty $release_version"
test "$("$stage/bin/nocted" --version)" = "nocted $release_version"

library_inventory="$scratch/library-inventory.txt"
package_inventory="$scratch/package-inventory.txt"
license_files="$scratch/license-files.txt"
license_receipt=$(./scripts/package_bundle_licenses.sh "$library_sources" "$stage" \
  "$library_inventory" "$package_inventory" "$license_files")

installed_files="$scratch/installed-files.txt"
bundled_libraries="$scratch/bundled-libraries.txt"
(cd "$stage" && find . -type f | sed 's#^\./##' | sort) > "$installed_files"
find "$stage/libexec/dintty/lib" -type f -exec basename {} \; | sort > "$bundled_libraries"

tar -C "$stage" --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner -cf - . | gzip -n > "$archive_tmp"
test -s "$archive_tmp"
archive_digest=$(sha256sum "$archive_tmp" | awk '{print $1}')
printf '%s  %s\n' "$archive_digest" "$out_name" > "$checksum_tmp"
compiler=$(zig version)
architecture=$(uname -m)
source_revision=$(git rev-parse --short=12 HEAD 2>/dev/null || printf 'unavailable')
bytes=$(wc -c < "$archive_tmp")
library_count=$(wc -l < "$bundled_libraries" | tr -d ' ')
package_count=$(wc -l < "$package_inventory" | tr -d ' ')
license_file_count=$(wc -l < "$license_files" | tr -d ' ')

{
  printf 'bundle_manifest_version=1\n'
  printf 'package=dintty\n'
  printf 'version=%s\n' "$release_version"
  printf 'release_date=%s\n' "$release_date"
  printf 'architecture=%s\n' "$architecture"
  printf 'compiler=zig %s\n' "$compiler"
  printf 'source_revision=%s\n' "$source_revision"
  printf 'archive=%s\n' "$out_name"
  printf 'archive_sha256=%s\n' "$archive_digest"
  printf 'archive_bytes=%s\n' "$bytes"
  printf 'checksum=%s.sha256\n' "$out_name"
  printf 'redistribution_ready=true\n'
  printf 'redistribution_blocker=none\n'
  printf 'license_inventory_version=1\n'
  printf 'license_inventory_source=installed_package_ownership_metadata_notices_and_spdx_texts\n'
  printf 'all_copied_host_libraries_accounted=true\n'
  printf 'bundle_license_payload_complete=true\n'
  printf 'dependency_package_count=%s\n' "$package_count"
  printf 'dependency_license_file_count=%s\n' "$license_file_count"
  printf 'gtk_layer_shell_source=%s\n' "$layer_shell_source"
  printf 'gtk_layer_shell_license=LGPL-3.0-or-later\n'
  printf 'gtk_layer_shell_license_source=host_package_inventory_and_retained_notice_payload\n'
  printf 'installed_files_begin\n'
  cat "$installed_files"
  printf 'installed_files_end\n'
  printf 'bundled_libraries_begin\n'
  cat "$bundled_libraries"
  printf 'bundled_libraries_end\n'
  printf 'library_inventory_begin\n'
  cat "$library_inventory"
  printf 'library_inventory_end\n'
  printf 'package_inventory_begin\n'
  cat "$package_inventory"
  printf 'package_inventory_end\n'
  printf 'license_files_begin\n'
  cat "$license_files"
  printf 'license_files_end\n'
} > "$manifest_tmp"

chmod 0644 "$archive_tmp" "$checksum_tmp" "$manifest_tmp"

mv -f "$archive_tmp" "$out_path"
archive_tmp=
mv -f "$checksum_tmp" "$out_path.sha256"
checksum_tmp=
mv -f "$manifest_tmp" "$manifest_path"
manifest_tmp=
(cd "$out_dir" && sha256sum -c "$out_name.sha256" >/dev/null)

scratch_path=$scratch
find "$scratch_path" -depth -delete
scratch=
test ! -e "$scratch_path"
printf '%s\n' "$license_receipt"
echo "package_bundle path=$out architecture=$architecture version=$release_version manifest=true installed_files=true library_inventory=true package_inventory=true license_payload=true bundled_libraries=$library_count dependency_packages=$package_count dependency_license_files=$license_file_count checksum=true archive_sha256=$archive_digest redistribution_ready=true provenance=complete"
