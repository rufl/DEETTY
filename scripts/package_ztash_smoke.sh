#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
release_dir="${1:-$root/dist/ztash}"
release_dir="$(cd -- "$release_dir" && pwd -P)"

for command_name in python3 sha256sum tar unzip timeout; do
  command -v "$command_name" >/dev/null || {
    printf 'package_ztash_smoke: missing dependency: %s\n' "$command_name" >&2
    exit 2
  }
done

[ -f "$release_dir/ztash-release.json" ]
[ -f "$release_dir/SHA256SUMS" ]

mapfile -t artifacts < <(python3 - "$release_dir/ztash-release.json" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert manifest["schema"] == "ztash-release-v1"
assert manifest["application"] == "dintty"
assert manifest["qualification"] == "build-only"
assert manifest["remote_deployment"] == "not_performed"
assert {item["target"] for item in manifest["artifacts"]} == {"x86_64-linux", "x86_64-windows-gnu"}
for item in manifest["artifacts"]:
    assert item["name"].startswith("dintty-")
    assert item["sha256"] and len(item["sha256"]) == 64
    size_bytes = item["size_bytes"]
    assert isinstance(size_bytes, int) and not isinstance(size_bytes, bool) and size_bytes > 0
    archive = pathlib.Path(sys.argv[1]).parent / item["name"]
    assert archive.is_file()
    assert archive.stat().st_size == size_bytes
    print(item["target"], item["name"])
PY
)
[ "${#artifacts[@]}" -eq 2 ]
linux_archive="$(printf '%s\n' "${artifacts[@]}" | awk '$1 == "x86_64-linux" {print $2}')"
windows_archive="$(printf '%s\n' "${artifacts[@]}" | awk '$1 == "x86_64-windows-gnu" {print $2}')"
[ -n "$linux_archive" ]
[ -n "$windows_archive" ]

(
  cd "$release_dir"
  sha256sum -c SHA256SUMS >/dev/null
  test "$(wc -l < SHA256SUMS | tr -d ' ')" = 2
)

smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/dintty-ztash-smoke.XXXXXX")"
cleanup() { rm -rf -- "$smoke_root"; }
trap cleanup EXIT HUP INT TERM

tar -xzf "$release_dir/$linux_archive" -C "$smoke_root"
linux_root="$(tar -tzf "$release_dir/$linux_archive" | sed -n '1s#/.*##p')"
test -n "$linux_root"
test -x "$smoke_root/$linux_root/dintty"
test -x "$smoke_root/$linux_root/nocted"
tar -tzf "$release_dir/$linux_archive" | grep -Fx "$linux_root/README.md" >/dev/null
tar -tzf "$release_dir/$linux_archive" | grep -Fx "$linux_root/LICENSE" >/dev/null
tar -tzf "$release_dir/$linux_archive" | grep -Fx "$linux_root/resources/nocted/language-specs/zig.lang" >/dev/null

windows_root="$(unzip -Z1 "$release_dir/$windows_archive" | sed -n '1s#/.*##p')"
unzip -Z1 "$release_dir/$windows_archive" | grep -Fx "$windows_root/dintty.exe" >/dev/null
unzip -Z1 "$release_dir/$windows_archive" | grep -Fx "$windows_root/nocted.exe" >/dev/null
unzip -Z1 "$release_dir/$windows_archive" | grep -Fx "$windows_root/README.txt" >/dev/null
unzip -Z1 "$release_dir/$windows_archive" | grep -Fx "$windows_root/LICENSE" >/dev/null

HOME="$smoke_root/home" \
XDG_CONFIG_HOME="$smoke_root/config" \
XDG_STATE_HOME="$smoke_root/state" \
XDG_RUNTIME_DIR="$smoke_root/runtime" \
XDG_CACHE_HOME="$smoke_root/cache" \
XDG_DATA_HOME="$smoke_root/data" \
DINTTY_RENDERER=grid NOCTED_DISABLE_SINGLE_INSTANCE=1 \
timeout --kill-after=2 30 "$smoke_root/$linux_root/dintty" --package-smoke > "$smoke_root/linux-smoke-output"
grep -F 'package_smoke dintty=true headless=true' "$smoke_root/linux-smoke-output" >/dev/null

printf 'package_ztash_smoke manifest=true checksums=true sizes=true linux_archive=true windows_archive=true roots=true required_files=true linux_package_smoke=true scratch_clean=true\n'
