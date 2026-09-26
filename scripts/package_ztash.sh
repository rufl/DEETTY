#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
release_dir="${NOCTTY_ZTASH_RELEASE_DIR:-$root/dist/ztash}"

for command_name in git zig tar zip unzip sha256sum timeout python3 mktemp; do
  command -v "$command_name" >/dev/null || {
    printf 'package_ztash: missing dependency: %s\n' "$command_name" >&2
    exit 2
  }
done

version="$(sed -n 's/^pub const version = "\([^\"]*\)";$/\1/p' "$root/src/release.zig")"
release_date="$(sed -n 's/^pub const release_date = "\([^\"]*\)";$/\1/p' "$root/src/release.zig")"
package_revision="$(sed -n 's/^pub const package_revision = "\([^\"]*\)";$/\1/p' "$root/src/release.zig")"
case "$version" in
  ''|*[!0-9.]*|.*|*.|*..*)
    printf 'package_ztash: invalid release version: %s\n' "$version" >&2
    exit 2
    ;;
esac
[ -n "$release_date" ] || { echo 'package_ztash: release date is missing' >&2; exit 2; }
[ -n "$package_revision" ] || { echo 'package_ztash: package revision is missing' >&2; exit 2; }

build_id="$(git -C "$root" rev-parse HEAD)"
if [ -n "$(git -C "$root" status --short)" ]; then
  echo 'package_ztash: refusing to package a dirty worktree' >&2
  exit 2
fi

mkdir -p -- "$(dirname -- "$release_dir")"
release_dir="$(cd -- "$(dirname -- "$release_dir")" && pwd -P)/$(basename -- "$release_dir")"
if [ -L "$release_dir" ] || [ "$release_dir" = "$root" ] || [ "$release_dir" = / ]; then
  echo "package_ztash: unsafe release directory: $release_dir" >&2
  exit 2
fi

stage_root="$(mktemp -d "$root/.ztash-package.XXXXXX")"
cache_dir="$stage_root/zig-cache"
global_cache_dir="$stage_root/zig-global-cache"
linux_install="$stage_root/linux-install"
windows_install="$stage_root/windows-install"
linux_root="$stage_root/noctty-$version-linux-x86_64"
windows_root="$stage_root/noctty-$version-windows-x86_64"
linux_archive="noctty-$version-linux-x86_64.tar.gz"
windows_archive="noctty-$version-windows-x86_64.zip"

cleanup() {
  rm -rf -- "$root/.zig-cache" "$root/zig-out" "$stage_root"
}
trap cleanup EXIT HUP INT TERM

build_target() {
  local prefix="$1"
  shift
  (cd "$root" && zig build "$@" -Doptimize=ReleaseFast -Dstrip=true \
    --prefix "$prefix" --cache-dir "$cache_dir" --global-cache-dir "$global_cache_dir")
}

mkdir -p -- "$linux_root" "$windows_root"
build_target "$linux_install"
build_target "$windows_install" -Dtarget=x86_64-windows-gnu

copy_linux_payload() {
  cp -p "$linux_install/bin/noctty" "$linux_root/noctty"
  cp -p "$linux_install/bin/nocted" "$linux_root/nocted"
  cp -p "$root/README.md" "$linux_root/README.md"
  cp -p "$root/LICENSE" "$linux_root/LICENSE"
  cp -p "$root/THIRD_PARTY_NOTICES.md" "$linux_root/THIRD_PARTY_NOTICES.md"
  cp -p "$root/dependencies/UNICODE-LICENSE.txt" "$linux_root/UNICODE-LICENSE.txt"
  cp -p "$root/packaging/runtime-dependencies.txt" "$linux_root/runtime-dependencies.txt"
  cp -a "$linux_install/share" "$linux_root/share"
  mkdir -p "$linux_root/resources"
  cp -a "$linux_install/share/nocted" "$linux_root/resources/nocted"
  chmod 0755 "$linux_root/noctty" "$linux_root/nocted"
  cat > "$linux_root/BUILD-INFO.txt" <<EOF
package=noctty
application=noctty
version=$version
package_revision=$package_revision
target=linux-x86_64
build_id=$build_id
release_date=$release_date
qualification=build-only
smoke=noctty --package-smoke
EOF
}

copy_windows_payload() {
  cp -p "$windows_install/bin/noctty.exe" "$windows_root/noctty.exe"
  cp -p "$windows_install/bin/nocted.exe" "$windows_root/nocted.exe"
  cp -p "$root/README.md" "$windows_root/README.txt"
  cp -p "$root/LICENSE" "$windows_root/LICENSE"
  cp -p "$root/THIRD_PARTY_NOTICES.md" "$windows_root/THIRD_PARTY_NOTICES.md"
  cp -p "$root/dependencies/UNICODE-LICENSE.txt" "$windows_root/UNICODE-LICENSE.txt"
  cp -p "$root/docs/WINDOWS.md" "$windows_root/WINDOWS.md"
  cp -p "$root/scripts/windows_smoke.ps1" "$windows_root/WINDOWS-SMOKE.ps1"
  cat > "$windows_root/BUILD-INFO.txt" <<EOF
package=noctty
application=noctty
version=$version
package_revision=$package_revision
target=windows-x86_64
build_id=$build_id
release_date=$release_date
qualification=build-only
smoke=noctty.exe --package-smoke
EOF
}

copy_linux_payload
copy_windows_payload

linux_smoke_home="$stage_root/linux-smoke-home"
mkdir -p -- "$linux_smoke_home"
linux_smoke_output="$stage_root/linux-package-smoke.txt"
HOME="$linux_smoke_home" \
XDG_CONFIG_HOME="$linux_smoke_home/config" \
XDG_STATE_HOME="$linux_smoke_home/state" \
XDG_RUNTIME_DIR="$linux_smoke_home/runtime" \
XDG_CACHE_HOME="$linux_smoke_home/cache" \
XDG_DATA_HOME="$linux_smoke_home/data" \
NOCTTY_RENDERER=grid NOCTED_DISABLE_SINGLE_INSTANCE=1 \
timeout --kill-after=2 30 "$linux_root/noctty" --package-smoke > "$linux_smoke_output"
grep -F 'package_smoke noctty=true headless=true' "$linux_smoke_output" >/dev/null

if [ "${NOCTTY_ZTASH_WINE_SMOKE:-0}" = 1 ] && command -v wine >/dev/null; then
  wine_prefix="$stage_root/wine-prefix"
  WINEPREFIX="$wine_prefix" timeout --kill-after=2 60 wine "$windows_root/noctty.exe" --package-smoke >/dev/null
  windows_smoke=passed
else
  windows_smoke=deferred_to_receiver
fi

find "$linux_root" "$windows_root" -type f -exec touch -h -d '1980-01-01 00:00:00 UTC' {} +

( 
  cd "$stage_root"
  tar --sort=name --mtime='UTC 1980-01-01' --owner=0 --group=0 --numeric-owner \
    -cf - "$(basename -- "$linux_root")" | gzip -n > "$linux_archive"
  find "$(basename -- "$windows_root")" -type f -printf '%P\n' |
    LC_ALL=C sort | sed "s#^#$(basename -- "$windows_root")/#" |
    zip -X -q "$windows_archive" -@
  sha256sum "$linux_archive" "$windows_archive" > SHA256SUMS
  tar -tzf "$linux_archive" >/dev/null
  unzip -tq "$windows_archive" >/dev/null
  sha256sum -c SHA256SUMS >/dev/null
)

linux_sha="$(sha256sum "$stage_root/$linux_archive" | awk '{print $1}')"
windows_sha="$(sha256sum "$stage_root/$windows_archive" | awk '{print $1}')"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$stage_root/ztash-release.json" <<EOF
{
  "schema": "ztash-release-v1",
  "application": "noctty",
  "version": "$version",
  "build_id": "$build_id",
  "commit": "$build_id",
  "created_at_utc": "$created_at",
  "qualification": "build-only",
  "remote_deployment": "not_performed",
  "linux_smoke": "passed",
  "windows_smoke": "$windows_smoke",
  "artifacts": [
    {
      "name": "$linux_archive",
      "target": "x86_64-linux",
      "sha256": "$linux_sha"
    },
    {
      "name": "$windows_archive",
      "target": "x86_64-windows-gnu",
      "sha256": "$windows_sha"
    }
  ]
}
EOF

rm -rf -- "$release_dir"
mkdir -p -- "$release_dir"
cp -p "$stage_root/$linux_archive" "$stage_root/$windows_archive" \
  "$stage_root/SHA256SUMS" "$stage_root/ztash-release.json" "$release_dir/"
chmod 0644 "$release_dir"/*

printf 'package_ztash release=%s application=noctty version=%s build_id=%s linux=%s windows=%s linux_smoke=passed windows_smoke=%s stale_release_clean=true caches_cleaned=true\n' \
  "$release_dir" "$version" "$build_id" "$linux_archive" "$windows_archive" "$windows_smoke"
