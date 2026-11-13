#!/usr/bin/env sh
set -eu

if [ "${DINTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DINTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=/tmp/dintty-native-grid-window-tray.txt
errors=/tmp/dintty-native-grid-window-tray.stderr
ready=/tmp/dintty-native-grid-window-tray-ready
ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-binaries
rm -f "$output" "$errors" "$ready"

./zig-out/bin/dintty-smoke --native-grid-window-tray-smoke >"$output" 2>"$errors" &
pid=$!
cleanup() {
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$errors" "$ready"
}
trap cleanup EXIT

attempt=0
while [ "$attempt" -lt 100 ] && [ ! -s "$ready" ]; do
    attempt=$((attempt + 1))
    sleep 0.05
done
if [ ! -s "$ready" ]; then
    cat "$output" >&2
    cat "$errors" >&2
    exit 1
fi

service=$(cat "$ready")
icon=$(gdbus call --session --dest "$service" \
    --object-path /StatusNotifierItem \
    --method org.freedesktop.DBus.Properties.Get \
    org.kde.StatusNotifierItem IconName)
menu=$(gdbus call --session --dest "$service" \
    --object-path /StatusNotifierItem \
    --method org.freedesktop.DBus.Properties.Get \
    org.kde.StatusNotifierItem Menu)
items=$(gdbus call --session --dest org.kde.StatusNotifierWatcher \
    --object-path /StatusNotifierWatcher \
    --method org.freedesktop.DBus.Properties.Get \
    org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems)
printf '%s\n' "$icon" | grep -F 'com.dintty.DINTTY' >/dev/null
printf '%s\n' "$menu" | grep -F '/MenuBar' >/dev/null
printf '%s\n' "$items" | grep -F "$service/StatusNotifierItem" >/dev/null

layout=$(gdbus call --session --dest "$service" --object-path /MenuBar \
    --method com.canonical.dbusmenu.GetLayout 0 1 '[]')
printf '%s\n' "$layout" | grep -F 'Hide DINTTY' >/dev/null
printf '%s\n' "$layout" | grep -F 'Settings' >/dev/null
printf '%s\n' "$layout" | grep -F 'Close DINTTY' >/dev/null

gdbus call --session --dest "$service" --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.Activate 0 0 >/dev/null
sleep 0.15
hidden_layout=$(gdbus call --session --dest "$service" --object-path /MenuBar \
    --method com.canonical.dbusmenu.GetLayout 0 1 '[]')
printf '%s\n' "$hidden_layout" | grep -F 'Show DINTTY' >/dev/null
gdbus call --session --dest "$service" --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.Activate 0 0 >/dev/null
gdbus call --session --dest "$service" --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.SecondaryActivate 0 0 >/dev/null
gdbus call --session --dest "$service" --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.ContextMenu 0 0 >/dev/null
gdbus call --session --dest "$service" --object-path /MenuBar \
    --method com.canonical.dbusmenu.Event 4 clicked '<0>' 0 >/dev/null

if wait "$pid"; then
    :
else
    status=$?
    cat "$output" >&2
    cat "$errors" >&2
    exit "$status"
fi
rm -f "$ready"
trap - EXIT
attempt=0
while [ "$attempt" -lt 40 ]; do
    items_after=$(gdbus call --session --dest org.kde.StatusNotifierWatcher \
        --object-path /StatusNotifierWatcher \
        --method org.freedesktop.DBus.Properties.Get \
        org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems)
    if ! printf '%s\n' "$items_after" | grep -F "$service/StatusNotifierItem" >/dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.05
done
if printf '%s\n' "$items_after" | grep -F "$service/StatusNotifierItem" >/dev/null; then
    echo "DINTTY tray item remained registered after exit" >&2
    exit 1
fi
cat "$output"
grep -F 'native_grid_window_tray_smoke resize_handles=4 cardinal_edges=true side_border=2 diagonal_cursors=false resized=true native_decorated=true native_resizable=true tray_registered=true menu_registered=true watcher=true icon=true activate=true secondary=true context=true menu_layout=true close=true session_stopped=true exited=true' "$output" >/dev/null
echo "native_grid_window_tray_teardown removed=true"
rm -f "$errors"
