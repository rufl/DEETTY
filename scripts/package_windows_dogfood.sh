#!/usr/bin/env sh
set -eu

export LC_ALL=C
export TZ=UTC

out=${1:-dist/dintty-windows-x86_64-dogfood.zip}
case "$out" in
  *.zip) ;;
  *) echo 'package_windows_dogfood error=output_must_end_in_zip' >&2; exit 1 ;;
esac
case "$out" in
  /*) out_path=$out ;;
  *) out_path="$(pwd -P)/$out" ;;
esac
out_dir=$(dirname "$out_path")
out_name=$(basename "$out_path")
mkdir -p "$out_dir"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/dintty-windows-dogfood.XXXXXX")
archive_tmp=$(mktemp "$out_dir/.${out_name}.tmp.XXXXXX")
checksum_tmp=$(mktemp "$out_dir/.${out_name}.sha256.tmp.XXXXXX")
manifest_tmp=$(mktemp "$out_dir/.${out_name}.manifest.tmp.XXXXXX")
cleanup() {
  rm -rf "$scratch"
  rm -f "$archive_tmp" "$checksum_tmp" "$manifest_tmp"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

portable="$scratch/dintty-windows-x86_64-alpha.zip"
installer_name=dintty-windows-x86_64-dogfood-setup.exe
installer="$scratch/$installer_name"
bundle="$scratch/dintty-windows-x86_64-dogfood"
mkdir -p "$bundle"

./scripts/package_windows.sh "$portable"
./scripts/package_windows_installer.sh "$installer" "$portable"
cp "$installer" "$installer.sha256" "$installer.manifest" "$bundle/"
cp scripts/install_windows_dogfood.ps1 "$bundle/Install-DINTTY-Dogfood.ps1"
cat >"$bundle/INSTALL.txt" <<'EOF'
DINTTY Windows dogfood installation

1. Review this bundle on the Windows machine. It is an unsigned dogfood build.
2. Fully close DINTTY and NoctEd.
3. Open PowerShell in this directory.
4. Verify and run the per-user installer:

   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-DINTTY-Dogfood.ps1

   Add -Silent for an unattended current-user install.

The script verifies the adjacent SHA-256 sidecar, runs both installed self-tests,
and writes %LOCALAPPDATA%\DINTTY\dogfood-install.receipt. It never uploads logs,
crash dumps, or receipts. A successful self-test is not physical UI qualification.
EOF

find "$bundle" -exec touch -h -d '1980-01-01 00:00:00 UTC' {} +
inventory="$scratch/payload.inventory"
find "$bundle" -type f -printf '%P\n' |
  LC_ALL=C sort |
  while IFS= read -r path; do
    printf '%s  %s/%s\n' \
      "$(sha256sum "$bundle/$path" | awk '{print $1}')" \
      "$(basename "$bundle")" \
      "$path"
  done >"$inventory"

rm -f "$archive_tmp"
(
  cd "$scratch"
  find "$(basename "$bundle")" -print |
    LC_ALL=C sort |
    zip -X -q "$archive_tmp" -@
)
test -s "$archive_tmp"
digest=$(sha256sum "$archive_tmp" | awk '{print $1}')
bytes=$(wc -c <"$archive_tmp" | tr -d ' ')
installer_digest=$(sha256sum "$installer" | awk '{print $1}')
source_revision=$(sed -n 's/^source_revision=//p' "$portable.manifest")
version=$(sed -n 's/^version=//p' "$portable.manifest")
package_revision=$(sed -n 's/^package_revision=//p' "$portable.manifest")
working_tree_dirty=$(sed -n 's/^working_tree_dirty=//p' "$portable.manifest")
printf '%s  %s\n' "$digest" "$out_name" >"$checksum_tmp"
{
  printf 'windows_dogfood_bundle_manifest_version=1\n'
  printf 'package=dintty\n'
  printf 'version=%s\n' "$version"
  printf 'package_revision=%s\n' "$package_revision"
  printf 'source_revision=%s\n' "$source_revision"
  printf 'working_tree_dirty=%s\n' "$working_tree_dirty"
  printf 'architecture=x86_64\n'
  printf 'minimum_runtime=Windows 10 version 1809\n'
  printf 'archive=%s\n' "$out_name"
  printf 'archive_sha256=%s\n' "$digest"
  printf 'archive_bytes=%s\n' "$bytes"
  printf 'installer=%s\n' "$installer_name"
  printf 'installer_sha256=%s\n' "$installer_digest"
  printf 'installer_signed=false\n'
  printf 'install_scope=per-user\n'
  printf 'install_receipt=true\n'
  printf 'installed_self_tests=true\n'
  printf 'piwebqol_artifact_compatible=true\n'
  printf 'telemetry=false\n'
  printf 'network_uploads=false\n'
  printf 'physical_windows_validation=false\n'
  printf 'payload_inventory_begin\n'
  cat "$inventory"
  printf 'payload_inventory_end\n'
} >"$manifest_tmp"
chmod 0644 "$archive_tmp" "$checksum_tmp" "$manifest_tmp"
mv -f "$archive_tmp" "$out_path"
archive_tmp=
mv -f "$checksum_tmp" "$out_path.sha256"
checksum_tmp=
mv -f "$manifest_tmp" "$out_path.manifest"
manifest_tmp=
(cd "$out_dir" && sha256sum -c "$(basename "$out_path").sha256" >/dev/null)

printf 'package_windows_dogfood path=%s version=%s package_revision=%s sha256=%s bytes=%s installer_sha256=%s signed=false install_scope=per-user receipt=true self_tests=true piwebqol_artifact_compatible=true physical_windows_validation=false\n' \
  "$out" "$version" "$package_revision" "$digest" "$bytes" "$installer_digest"
