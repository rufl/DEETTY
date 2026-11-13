#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

isolation=${DINTTY_ISOLATED_DISPLAY_RUNNER:-$repo_root/scripts/isolated_display_runner.sh}
test -x "$isolation"
command -v wine >/dev/null
command -v wineboot >/dev/null
command -v wineserver >/dev/null

optimize=${DINTTY_WINDOWS_OPTIMIZE:-ReleaseSafe}
scratch=$(mktemp -d "$repo_root/.dintty-windows-nocted-zig.XXXXXX")
cleanup() {
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$scratch/stage" "$scratch/local-cache" "$scratch/global-cache"

ZIG_GLOBAL_CACHE_DIR="$scratch/global-cache" zig build windows-nocted-host-qualification \
  -Dtarget=x86_64-windows-gnu \
  -Doptimize="$optimize" \
  -j1 \
  --prefix "$scratch/stage" \
  --cache-dir "$scratch/local-cache" >/dev/null

test -s "$scratch/stage/bin/nocted-host-qualification.exe"

# The private cross-build can briefly raise I/O PSI above the display wrapper's
# fail-closed threshold. Wait at most two minutes for that self-induced pressure
# to settle; the wrapper still performs the authoritative pressure/lock checks.
attempt=0
while :; do
  io_full=$(awk '/^full / { for (i = 1; i <= NF; i++) if ($i ~ /^avg10=/) { sub(/^avg10=/, "", $i); print $i; exit } }' /proc/pressure/io 2>/dev/null || printf '100\n')
  if awk -v value="$io_full" 'BEGIN { exit !(value < 8) }'; then
    break
  fi
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 24 ]; then
    echo "windows_nocted_zig_smoke deferred: I/O full PSI=${io_full}%" >&2
    exit 75
  fi
  sleep 5
done

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
