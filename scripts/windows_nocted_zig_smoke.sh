#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

isolation=${NOCTTY_ISOLATED_DISPLAY:-overzeer-isolated-display}
command -v "$isolation" >/dev/null
command -v wine >/dev/null
command -v wineboot >/dev/null
command -v wineserver >/dev/null

optimize=${NOCTTY_WINDOWS_OPTIMIZE:-ReleaseSafe}
scratch=$(mktemp -d "$repo_root/.noctty-windows-nocted-zig.XXXXXX")
cleanup() {
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$scratch/stage" "$scratch/local-cache" "$scratch/global-cache"

zig build windows-nocted-host-qualification \
  -Dtarget=x86_64-windows-gnu \
  -Doptimize="$optimize" \
  -j1 \
  --prefix "$scratch/stage" \
  --cache-dir "$scratch/local-cache" \
  --global-cache-dir "$scratch/global-cache" >/dev/null

test -s "$scratch/stage/bin/nocted-host-qualification.exe"
cat >"$scratch/run.sh" <<'RUNNER'
#!/usr/bin/env sh
set -eu
export WINEPREFIX=$1
export WINEDEBUG=-all
wineboot -u
wineserver -w
wine "$2"
wineserver -w
RUNNER
chmod +x "$scratch/run.sh"

if ! "$isolation" --timeout 120 -- \
  "$scratch/run.sh" "$scratch/wine" "$scratch/stage/bin/nocted-host-qualification.exe" \
  >"$scratch/host.log" 2>&1; then
  cat "$scratch/host.log" >&2
  exit 1
fi

printf '%s\n' \
  'windows_nocted_zig_smoke cross_compile=true wine=true mapped=true controls=true project_tree=true find=true settings=true controlled_close=true isolated=true'
