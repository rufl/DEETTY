#!/usr/bin/env sh
set -eu

if [ "${DEETTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DEETTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DEETTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

receipt='native_grid_workspace_activation_smoke native_uri=true file_uri=true percent_decode=true authority_rejected=true validated_snapshot=true startup_restore_seam=true recent_mru=true fixed_capacity=8 config_v9=true atomic=true separate_process_policy=true exited=true'
repo_root=$(cd "$(dirname "$0")/.." && pwd -P)
scratch=$(mktemp -d "$repo_root/.deetty-workspace-activation.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$scratch/tmp" "$scratch/xdg-cache" "$scratch/local-cache" "$scratch/global-cache"

output=$(TMPDIR="$scratch/tmp" XDG_CACHE_HOME="$scratch/xdg-cache" \
  ZIG_GLOBAL_CACHE_DIR="$scratch/global-cache" zig build -j1 smoke-run \
    --cache-dir "$scratch/local-cache" \
    -- --native-grid-workspace-activation-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q "^${receipt}$"

grep -F 'Exec=deetty --open-uri %u' resources/com.deetty.DEETTY.desktop >/dev/null
grep -F 'MimeType=x-scheme-handler/deetty;' resources/com.deetty.DEETTY.desktop >/dev/null
grep -F 'StartupNotify=true' resources/com.deetty.DEETTY.desktop >/dev/null
grep -F 'X-KDE-StartupNotify=true' resources/com.deetty.DEETTY.desktop >/dev/null
grep -F 'Actions=Show;NewWorkspace;Toggle;' resources/com.deetty.DEETTY.desktop >/dev/null
grep -F 'Exec=deetty --new-window' resources/com.deetty.DEETTY.desktop >/dev/null
grep -F 'TryExec=deetty' resources/deettyhere.desktop >/dev/null
grep -F 'MimeType=inode/directory;' resources/deettyhere.desktop >/dev/null
grep -F 'X-KDE-ServiceTypes=KonqPopupMenu/Plugin' resources/deettyhere.desktop >/dev/null
grep -F 'X-KDE-MaxNumberOfUrls=1' resources/deettyhere.desktop >/dev/null
grep -F 'Exec=deetty --new-window --working-directory %f' resources/deettyhere.desktop >/dev/null

printf '%s\n' 'native_grid_workspace_activation_contract uri=true desktop=true startup_notify=true recent=true native_window=true new_workspace=true open_here=true config_v9=true'
