#!/usr/bin/env sh
set -eu

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
grep -F 'StartupNotify=false' resources/com.noctty.NOCTTY.desktop >/dev/null
grep -F 'X-KDE-StartupNotify=false' resources/com.noctty.NOCTTY.desktop >/dev/null

printf '%s\n' 'native_grid_workspace_activation_contract uri=true desktop=true startup_notify=false recent=true native_window=true config_v9=true'
