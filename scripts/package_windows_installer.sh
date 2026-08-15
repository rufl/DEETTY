#!/usr/bin/env sh
set -eu

export LC_ALL=C
export TZ=UTC

out=${1:-dist/noctty-windows-x86_64-setup-unsigned.exe}
portable=${2:-${NOCTTY_WINDOWS_PORTABLE_ZIP:-dist/noctty-windows-x86_64-alpha.zip}}
case "$out" in
  /*) out_path=$out ;;
  *) out_path="$(pwd -P)/$out" ;;
esac
case "$portable" in
  /*) portable_path=$portable ;;
  *) portable_path="$(pwd -P)/$portable" ;;
esac
out_dir=$(dirname "$out_path")
out_name=$(basename "$out_path")
test -d "$out_dir"

case "$out_name" in
  *.exe) ;;
  *) echo 'package_windows_installer error=output_must_end_in_exe' >&2; exit 1 ;;
esac

if [ ! -s "$portable_path" ]; then
  ./scripts/package_windows.sh "$portable_path"
fi
test -s "$portable_path"
test -s "$portable_path.sha256"
test -s "$portable_path.manifest"
(
  cd "$(dirname "$portable_path")"
  sha256sum -c "$(basename "$portable_path").sha256" >/dev/null
)
grep -Fx 'windows_bundle_manifest_version=2' "$portable_path.manifest" >/dev/null
grep -Fx 'signed=false' "$portable_path.manifest" >/dev/null
grep -Fx 'nocted_included=true' "$portable_path.manifest" >/dev/null

version=$(sed -n 's/^pub const version = "\([^"]*\)";$/\1/p' src/release.zig)
package_revision=$(sed -n 's/^pub const package_revision = "\([^"]*\)";$/\1/p' src/release.zig)
release_date=$(sed -n 's/^pub const release_date = "\([^"]*\)";$/\1/p' src/release.zig)
test -n "$version"
test -n "$package_revision"
test -n "$release_date"
grep -Fx "version=$version" "$portable_path.manifest" >/dev/null
grep -Fx "package_revision=$package_revision" "$portable_path.manifest" >/dev/null

numeric_base=$(printf '%s\n' "$version" | sed 's/[^0-9.].*$//')
old_ifs=$IFS
IFS=.
set -- $numeric_base
IFS=$old_ifs
test "$#" -eq 3
case "$1$2$3$package_revision" in
  *[!0-9]*) echo 'package_windows_installer error=version_not_numeric' >&2; exit 1 ;;
esac
numeric_version=$1.$2.$3.$package_revision

makensis=${NOCTTY_MAKENSIS:-makensis}
case "$makensis" in
  */*) ;;
  *) makensis=$(command -v "$makensis") ;;
esac
test -x "$makensis"
nsis_version=$($makensis -VERSION 2>&1 | tr '\r\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/[[:space:]]$//')
test -n "$nsis_version"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-windows-installer.XXXXXX")
installer_tmp=$(mktemp "$out_dir/.${out_name}.tmp.XXXXXX")
checksum_tmp=$(mktemp "$out_dir/.${out_name}.sha256.tmp.XXXXXX")
manifest_tmp=$(mktemp "$out_dir/.${out_name}.manifest.tmp.XXXXXX")
signed_tmp=
signed_receipt_tmp=
cleanup() {
  rm -rf "$scratch"
  rm -f "$installer_tmp" "$checksum_tmp" "$manifest_tmp"
  if [ -n "$signed_tmp" ]; then rm -f "$signed_tmp"; fi
  if [ -n "$signed_receipt_tmp" ]; then rm -f "$signed_receipt_tmp"; fi
}
trap cleanup EXIT HUP INT TERM

unzip -q "$portable_path" -d "$scratch/unpacked"
payload="$scratch/unpacked/noctty-windows-x86_64"
test -d "$payload"
expected="$scratch/expected-files"
actual="$scratch/actual-files"
cat > "$expected" <<'EOF'
BUILD-INFO.txt
LICENSE
THIRD_PARTY_NOTICES.md
WINDOWS-SMOKE.ps1
WINDOWS.md
nocted.exe
noctty.exe
EOF
find "$payload" -type f -printf '%P\n' | LC_ALL=C sort > "$actual"
cmp "$expected" "$actual" >/dev/null
test -s "$payload/noctty.exe"
test -s "$payload/nocted.exe"

payload_inventory="$scratch/payload.inventory"
while IFS= read -r path; do
  printf '%s  %s\n' "$(sha256sum "$payload/$path" | awk '{print $1}')" "$path"
done < "$expected" > "$payload_inventory"

portable_inventory="$scratch/portable.inventory"
sed -n '/^payload_inventory_begin$/,/^payload_inventory_end$/p' "$portable_path.manifest" |
  sed '1d;$d;s#  noctty-windows-x86_64/#  #' > "$portable_inventory"
cmp "$payload_inventory" "$portable_inventory" >/dev/null
find "$payload" -exec touch -h -d '1980-01-01 00:00:00 UTC' {} +
estimated_size_kib=$(
  find "$payload" -type f -printf '%s\n' |
    awk '{ total += $1 } END { print int((total + 1023) / 1024) }'
)

source_epoch=$(date -u -d "$release_date 00:00:00 UTC" +%s)
export SOURCE_DATE_EPOCH=$source_epoch

build_installer() {
  source_payload=$1
  destination=$2
  rm -f "$destination"
  "$makensis" -V2 -NOCD \
    "-DNOCTTY_PAYLOAD=$source_payload" \
    "-DNOCTTY_OUTPUT=$destination" \
    "-DPRODUCT_VERSION=$version" \
    "-DPRODUCT_VERSION_NUMERIC=$numeric_version" \
    "-DPACKAGE_REVISION=$package_revision" \
    "-DESTIMATED_SIZE_KIB=$estimated_size_kib" \
    resources/windows/noctty-installer.nsi
  test -s "$destination"
}

build_installer "$payload" "$installer_tmp"
reproducibility_copy="$scratch/reproducibility/noctty-setup-unsigned.exe"
mkdir -p "$(dirname "$reproducibility_copy")"
build_installer "$payload" "$reproducibility_copy"
cmp "$installer_tmp" "$reproducibility_copy" >/dev/null
installer_digest=$(sha256sum "$installer_tmp" | awk '{print $1}')
installer_bytes=$(wc -c < "$installer_tmp" | tr -d ' ')
portable_digest=$(sha256sum "$portable_path" | awk '{print $1}')
portable_manifest_digest=$(sha256sum "$portable_path.manifest" | awk '{print $1}')
printf '%s  %s\n' "$installer_digest" "$out_name" > "$checksum_tmp"
{
  printf 'windows_installer_manifest_version=2\n'
  printf 'package=noctty\n'
  printf 'version=%s\n' "$version"
  printf 'package_revision=%s\n' "$package_revision"
  printf 'release_date=%s\n' "$release_date"
  printf 'architecture=x86_64\n'
  printf 'scope=per-user\n'
  printf 'default_install_dir=%%LOCALAPPDATA%%\\Programs\\NOCTTY\n'
  printf 'installer_format=NSIS\n'
  printf 'installer_compiler=%s\n' "$nsis_version"
  printf 'source_date_epoch=%s\n' "$source_epoch"
  printf 'source_archive=%s\n' "$(basename "$portable_path")"
  printf 'source_archive_sha256=%s\n' "$portable_digest"
  printf 'source_manifest_sha256=%s\n' "$portable_manifest_digest"
  printf 'installer=%s\n' "$out_name"
  printf 'installer_sha256=%s\n' "$installer_digest"
  printf 'installer_bytes=%s\n' "$installer_bytes"
  printf 'signed=false\n'
  printf 'silent_install=true\n'
  printf 'silent_uninstall=true\n'
  printf 'open_with_only=true\n'
  printf 'user_data_preserved_on_uninstall=true\n'
  printf 'reproducibility_verified=true\n'
  printf 'telemetry=false\n'
  printf 'network_uploads=false\n'
  printf 'payload_inventory_begin\n'
  cat "$payload_inventory"
  printf 'payload_inventory_end\n'
} > "$manifest_tmp"
chmod 0644 "$installer_tmp" "$checksum_tmp" "$manifest_tmp"
mv -f "$installer_tmp" "$out_path"
installer_tmp=
mv -f "$checksum_tmp" "$out_path.sha256"
checksum_tmp=
mv -f "$manifest_tmp" "$out_path.manifest"
manifest_tmp=

hook=${NOCTTY_WINDOWS_SIGN_HOOK:-}
if [ -n "$hook" ]; then
  case "$hook" in
    /*) ;;
    *) echo 'package_windows_installer error=sign_hook_must_be_absolute' >&2; exit 1 ;;
  esac
  test -x "$hook"

  unsigned_digest_before=$(sha256sum "$out_path" | awk '{print $1}')
  signed_payload="$scratch/signed-payload"
  cp -R "$payload" "$signed_payload"
  for kind in noctty-exe nocted-exe; do
    case "$kind" in
      noctty-exe) executable=noctty.exe ;;
      nocted-exe) executable=nocted.exe ;;
    esac
    unsigned_executable="$payload/$executable"
    signed_executable_tmp="$scratch/$executable.signed"
    verify_receipt="$scratch/$kind.verify"
    NOCTTY_WINDOWS_SIGN_HOOK=$hook \
      ./scripts/windows_sign_artifact.sh \
      "$kind" \
      "$unsigned_executable" \
      "$signed_executable_tmp" \
      "$verify_receipt" >/dev/null
    mv -f "$signed_executable_tmp" "$signed_payload/$executable"
  done

  find "$signed_payload" -exec touch -h -d '1980-01-01 00:00:00 UTC' {} +
  signed_container="$scratch/installer-with-signed-payload.exe"
  build_installer "$signed_payload" "$signed_container"
  case "$out_path" in
    *-unsigned.exe) signed_path=${out_path%-unsigned.exe}-signed.exe ;;
    *) signed_path=${out_path%.exe}-signed.exe ;;
  esac
  signed_name=$(basename "$signed_path")
  signed_tmp=$(mktemp "$out_dir/.${signed_name}.tmp.XXXXXX")
  rm -f "$signed_tmp"
  installer_verify_receipt="$scratch/installer.verify"
  NOCTTY_WINDOWS_SIGN_HOOK=$hook \
    ./scripts/windows_sign_artifact.sh \
    installer \
    "$signed_container" \
    "$signed_tmp" \
    "$installer_verify_receipt" >/dev/null
  signed_container_digest=$(sha256sum "$signed_container" | awk '{print $1}')
  signed_digest=$(sha256sum "$signed_tmp" | awk '{print $1}')

  unsigned_digest_after=$(sha256sum "$out_path" | awk '{print $1}')
  test "$unsigned_digest_before" = "$unsigned_digest_after"
  signed_receipt_tmp=$(mktemp "$out_dir/.${signed_name}.signing-receipt.tmp.XXXXXX")
  {
    printf 'windows_signing_receipt_version=1\n'
    printf 'signed=true\n'
    printf 'hook=%s\n' "$hook"
    printf 'source_manifest_sha256=%s\n' "$(sha256sum "$out_path.manifest" | awk '{print $1}')"
    printf 'canonical_unsigned_installer_sha256=%s\n' "$unsigned_digest_before"
    printf 'signed_payload_installer_sha256=%s\n' "$signed_container_digest"
    printf 'signed_installer=%s\n' "$signed_name"
    printf 'signed_installer_sha256=%s\n' "$signed_digest"
    for kind in noctty-exe nocted-exe; do
      case "$kind" in
        noctty-exe) executable=noctty.exe ;;
        nocted-exe) executable=nocted.exe ;;
      esac
      printf '%s_unsigned_sha256=%s\n' "$kind" "$(sha256sum "$payload/$executable" | awk '{print $1}')"
      printf '%s_signed_sha256=%s\n' "$kind" "$(sha256sum "$signed_payload/$executable" | awk '{print $1}')"
      printf '%s_verification_begin\n' "$kind"
      cat "$scratch/$kind.verify"
      printf '%s_verification_end\n' "$kind"
    done
    printf 'installer_verification_begin\n'
    cat "$installer_verify_receipt"
    printf 'installer_verification_end\n'
  } > "$signed_receipt_tmp"
  chmod 0644 "$signed_tmp" "$signed_receipt_tmp"
  mv -f "$signed_tmp" "$signed_path"
  signed_tmp=
  mv -f "$signed_receipt_tmp" "$signed_path.signing-receipt"
  signed_receipt_tmp=
fi

(
  cd "$out_dir"
  sha256sum -c "$(basename "$out_path").sha256" >/dev/null
)
echo "package_windows_installer path=$out version=$version package_revision=$package_revision architecture=x86_64 signed=false checksum=$installer_digest bytes=$installer_bytes"
