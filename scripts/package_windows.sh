#!/usr/bin/env sh
set -eu

export LC_ALL=C
export TZ=UTC

out=${1:-dist/noctty-windows-x86_64-alpha.zip}
case "$out" in
  /*) out_path=$out ;;
  *) out_path="$(pwd -P)/$out" ;;
esac
out_dir=$(dirname "$out_path")
out_name=$(basename "$out_path")
test -d "$out_dir"

optimize=${NOCTTY_WINDOWS_OPTIMIZE:-ReleaseFast}
version=$(sed -n 's/^pub const version = "\([^"]*\)";$/\1/p' src/release.zig)
release_date=$(sed -n 's/^pub const release_date = "\([^"]*\)";$/\1/p' src/release.zig)
package_revision=$(sed -n 's/^pub const package_revision = "\([^"]*\)";$/\1/p' src/release.zig)
revision=$(git rev-parse --short=12 HEAD 2>/dev/null || printf unavailable)
compiler=$(zig version)
dirty=false
if [ -n "$(git status --short 2>/dev/null || true)" ]; then dirty=true; fi

test -n "$version"
test -n "$release_date"
test -n "$package_revision"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-windows.XXXXXX")
archive_tmp=$(mktemp "$out_dir/.${out_name}.tmp.XXXXXX")
checksum_tmp=$(mktemp "$out_dir/.${out_name}.sha256.tmp.XXXXXX")
manifest_tmp=$(mktemp "$out_dir/.${out_name}.manifest.tmp.XXXXXX")
cleanup() {
  rm -rf "$scratch"
  rm -f "$archive_tmp" "$checksum_tmp" "$manifest_tmp"
}
trap cleanup EXIT HUP INT TERM

stage="$scratch/stage"
package="$scratch/noctty-windows-x86_64"
mkdir -p "$stage" "$package" "$scratch/local-cache" "$scratch/global-cache"

zig build \
  -Dtarget=x86_64-windows-gnu \
  -Doptimize="$optimize" \
  -Dstrip=false \
  -j1 \
  --prefix "$stage" \
  --cache-dir "$scratch/local-cache" \
  --global-cache-dir "$scratch/global-cache"

test -s "$stage/bin/noctty.exe"
test -s "$stage/bin/nocted.exe"
for executable in noctty.exe nocted.exe; do
  file "$stage/bin/$executable" | grep -F 'PE32+ executable' >/dev/null
  if command -v llvm-objdump >/dev/null 2>&1; then
    imports=$(llvm-objdump -p "$stage/bin/$executable")
    printf '%s\n' "$imports" | grep -F 'Subsystem' >/dev/null
    if printf '%s\n' "$imports" | grep -Ei 'gtk|glib|gdk' >/dev/null; then
      echo "package_windows error=gtk_runtime_imported executable=$executable" >&2
      exit 1
    fi
  fi
done
if command -v llvm-objdump >/dev/null 2>&1; then
  printf '%s\n' "$(llvm-objdump -p "$stage/bin/noctty.exe")" |
    grep -F 'CreatePseudoConsole' >/dev/null
fi

cp "$stage/bin/noctty.exe" "$stage/bin/nocted.exe" "$package/"
cp LICENSE THIRD_PARTY_NOTICES.md docs/WINDOWS.md "$package/"
cp scripts/windows_smoke.ps1 "$package/WINDOWS-SMOKE.ps1"
cat > "$package/BUILD-INFO.txt" <<EOF
package=noctty
version=$version
package_revision=$package_revision
release_date=$release_date
source_revision=$revision
working_tree_dirty=$dirty
compiler=zig $compiler
target=x86_64-windows-gnu
optimization=$optimize
symbols=unstripped
host=Win32/GDI
terminal_transport=ConPTY
terminal_model=NOCTTY Zig VT
minimum_runtime=Windows 10 version 1809
telemetry=false
network_uploads=false
local_logging=true
local_crash_dumps=true
physical_windows_validation=false
nocted_included=true
EOF

if [ "${NOCTTY_WINDOWS_WINE_SMOKE:-0}" = 1 ]; then
  test -n "$(command -v wine)"
  wine "$package/noctty.exe" --self-test
fi

find "$package" -exec touch -h -d '1980-01-01 00:00:00 UTC' {} +
inventory="$scratch/payload.inventory"
find "$package" -type f -printf '%P\n' |
  LC_ALL=C sort |
  while IFS= read -r path; do
    printf '%s  %s/%s\n' \
      "$(sha256sum "$package/$path" | awk '{print $1}')" \
      "$(basename "$package")" \
      "$path"
  done > "$inventory"
rm -f "$archive_tmp"
(
  cd "$scratch"
  find noctty-windows-x86_64 -print |
    LC_ALL=C sort |
    zip -X -q "$archive_tmp" -@
)

test -s "$archive_tmp"
digest=$(sha256sum "$archive_tmp" | awk '{print $1}')
bytes=$(wc -c < "$archive_tmp" | tr -d ' ')
printf '%s  %s\n' "$digest" "$out_name" > "$checksum_tmp"
{
  printf 'windows_bundle_manifest_version=2\n'
  printf 'package=noctty\n'
  printf 'version=%s\n' "$version"
  printf 'package_revision=%s\n' "$package_revision"
  printf 'release_date=%s\n' "$release_date"
  printf 'source_revision=%s\n' "$revision"
  printf 'working_tree_dirty=%s\n' "$dirty"
  printf 'architecture=x86_64\n'
  printf 'target=x86_64-windows-gnu\n'
  printf 'compiler=zig %s\n' "$compiler"
  printf 'optimization=%s\n' "$optimize"
  printf 'archive=%s\n' "$out_name"
  printf 'archive_sha256=%s\n' "$digest"
  printf 'archive_bytes=%s\n' "$bytes"
  printf 'signed=false\n'
  printf 'win32_native=true\n'
  printf 'conpty=true\n'
  printf 'zig_vt=true\n'
  printf 'gtk_runtime=false\n'
  printf 'nocted_included=true\n'
  printf 'telemetry=false\n'
  printf 'network_uploads=false\n'
  printf 'local_logging=true\n'
  printf 'local_crash_dumps=true\n'
  printf 'physical_windows_validation=false\n'
  printf 'payload_inventory_begin\n'
  cat "$inventory"
  printf 'payload_inventory_end\n'
} > "$manifest_tmp"
chmod 0644 "$archive_tmp" "$checksum_tmp" "$manifest_tmp"
mv -f "$archive_tmp" "$out_path"
archive_tmp=
mv -f "$checksum_tmp" "$out_path.sha256"
checksum_tmp=
mv -f "$manifest_tmp" "$out_path.manifest"
manifest_tmp=
(cd "$out_dir" && sha256sum -c "$(basename "$out_path").sha256" >/dev/null)

echo "package_windows path=$out version=$version package_revision=$package_revision architecture=x86_64 optimize=$optimize win32_native=true conpty=true zig_vt=true gtk_runtime=false nocted=true signed=false local_logging=true local_crash_dumps=true telemetry=false physical_windows_validation=false checksum=$digest bytes=$bytes"
