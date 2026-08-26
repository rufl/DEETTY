#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

receipt='native_grid_workspace_activation_smoke native_uri=true file_uri=true percent_decode=true authority_rejected=true validated_snapshot=true startup_restore_seam=true recent_mru=true fixed_capacity=8 config_v9=true atomic=true separate_process_policy=true exited=true'
repo_root=$(cd "$(dirname "$0")/.." && pwd -P)
scratch=$(mktemp -d "$repo_root/.noctty-workspace-activation.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$scratch/tmp" "$scratch/xdg-cache" "$scratch/local-cache" "$scratch/global-cache"

output=$(TMPDIR="$scratch/tmp" XDG_CACHE_HOME="$scratch/xdg-cache" \
  zig build -j1 smoke-run \
    --cache-dir "$scratch/local-cache" \
    --global-cache-dir "$scratch/global-cache" \
    -- --native-grid-workspace-activation-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q "^${receipt}$"

grep -F 'Exec=noctty --open-uri %u' resources/com.noctty.NOCTTY.desktop >/dev/null
grep -F 'MimeType=x-scheme-handler/noctty;' resources/com.noctty.NOCTTY.desktop >/dev/null
grep -F 'StartupNotify=true' resources/com.noctty.NOCTTY.desktop >/dev/null
grep -F 'X-KDE-StartupNotify=true' resources/com.noctty.NOCTTY.desktop >/dev/null
grep -F 'Actions=Show;NewWorkspace;Toggle;' resources/com.noctty.NOCTTY.desktop >/dev/null
grep -F 'Exec=noctty --new-window' resources/com.noctty.NOCTTY.desktop >/dev/null
grep -F 'TryExec=noctty' resources/nocttyhere.desktop >/dev/null
grep -F 'MimeType=inode/directory;' resources/nocttyhere.desktop >/dev/null
grep -F 'X-KDE-ServiceTypes=KonqPopupMenu/Plugin' resources/nocttyhere.desktop >/dev/null
grep -F 'X-KDE-MaxNumberOfUrls=1' resources/nocttyhere.desktop >/dev/null
grep -F 'Exec=noctty --new-window --working-directory %f' resources/nocttyhere.desktop >/dev/null

printf '%s\n' 'native_grid_workspace_activation_contract uri=true desktop=true startup_notify=true recent=true native_window=true new_workspace=true open_here=true config_v9=true'
