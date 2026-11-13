#!/usr/bin/env sh
set -eu

archive=${1:-dist/dintty-windows-x86_64-dogfood.zip}
case "$archive" in
  /*) archive_path=$archive ;;
  *) archive_path="$(pwd -P)/$archive" ;;
esac
test -s "$archive_path"
test -s "$archive_path.sha256"
test -s "$archive_path.manifest"
(
  cd "$(dirname "$archive_path")"
  sha256sum -c "$(basename "$archive_path").sha256" >/dev/null
)
grep -Fx 'windows_dogfood_bundle_manifest_version=1' "$archive_path.manifest" >/dev/null
grep -Fx 'installer_signed=false' "$archive_path.manifest" >/dev/null
grep -Fx 'install_scope=per-user' "$archive_path.manifest" >/dev/null
grep -Fx 'install_receipt=true' "$archive_path.manifest" >/dev/null
grep -Fx 'installed_self_tests=true' "$archive_path.manifest" >/dev/null
grep -Fx 'piwebqol_artifact_compatible=true' "$archive_path.manifest" >/dev/null
grep -Fx 'telemetry=false' "$archive_path.manifest" >/dev/null
grep -Fx 'network_uploads=false' "$archive_path.manifest" >/dev/null
grep -Fx 'physical_windows_validation=false' "$archive_path.manifest" >/dev/null

command -v unzip >/dev/null
command -v pwsh >/dev/null
scratch=$(mktemp -d "${TMPDIR:-/tmp}/dintty-windows-dogfood-smoke.XXXXXX")
cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT HUP INT TERM
unzip -q "$archive_path" -d "$scratch"
bundle="$scratch/dintty-windows-x86_64-dogfood"
installer="$bundle/dintty-windows-x86_64-dogfood-setup.exe"
test -s "$installer"
test -s "$installer.sha256"
test -s "$installer.manifest"
test -s "$bundle/Install-DINTTY-Dogfood.ps1"
test -s "$bundle/INSTALL.txt"

verify_output=$(pwsh -NoProfile -File "$bundle/Install-DINTTY-Dogfood.ps1" \
  -InstallerPath "$installer" -VerifyOnly)
printf '%s\n' "$verify_output" |
  grep -F 'windows_dogfood_verify ' >/dev/null
printf '%s\n' "$verify_output" |
  grep -F ' valid=true signed=false' >/dev/null

tampered="$bundle/dintty-windows-x86_64-dogfood-setup-tampered.exe"
cp "$installer" "$tampered"
printf 'x' >>"$tampered"
cp "$installer.sha256" "$tampered.sha256"
sed -i "s/$(basename "$installer")/$(basename "$tampered")/" "$tampered.sha256"
if pwsh -NoProfile -File "$bundle/Install-DINTTY-Dogfood.ps1" \
    -InstallerPath "$tampered" -VerifyOnly >/dev/null 2>&1; then
  echo 'windows_dogfood_bundle_smoke error=tampered_installer_accepted' >&2
  exit 1
fi

echo 'windows_dogfood_bundle_smoke checksum=true tamper_rejected=true installer=true powershell_verify=true receipt_contract=true piwebqol_artifact_compatible=true unsigned_boundary=true physical_windows_validation=false'
