#!/usr/bin/env sh
set -eu
export LC_ALL=C

if pgrep -x noctty >/dev/null 2>&1 ||
   pgrep -x noctty-smoke >/dev/null 2>&1 ||
   pgrep -f '/noctty-dogfood/noctty-bin' >/dev/null 2>&1; then
    echo 'close the running NOCTTY process before shortcut qualification' >&2
    exit 1
fi

unregister_shortcut() {
    qdbus6 org.kde.kglobalaccel /kglobalaccel \
        org.kde.KGlobalAccel.unregister noctty-smoke toggle-window-smoke \
        >/dev/null 2>&1 || true
}

unregister_shortcut

zig build --global-cache-dir .zig-cache/global smoke-binaries
output=/tmp/noctty-native-grid-shortcut-live.txt
ready=/tmp/noctty-native-grid-shortcut-ready
activated=/tmp/noctty-native-grid-shortcut-activated
rm -f "$output"
rm -f "$ready"
rm -f "$activated"
GDK_BACKEND=x11 ./zig-out/bin/noctty-smoke --native-grid-shortcut-live-smoke >"$output" 2>&1 &
pid=$!
cleanup() {
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$ready"
    rm -f "$activated"
    rm -f "$output"
    unregister_shortcut
}
trap cleanup EXIT

attempt=0
while [ "$attempt" -lt 100 ]; do
    if [ -s "$ready" ] && qdbus6 --literal org.kde.kglobalaccel /component/noctty-smoke org.kde.kglobalaccel.Component.allShortcutInfos 2>/dev/null | grep -q '16777273'; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.05
done
if [ "$attempt" -ge 100 ]; then
    cat "$output" >&2
    exit 1
fi
sleep 0.25
key_attempt=0
while [ "$key_attempt" -lt 3 ]; do
    xdotool key --clearmodifiers F10
    settle=0
    while [ "$settle" -lt 10 ]; do
        [ -s "$activated" ] && break
        settle=$((settle + 1))
        sleep 0.05
    done
    [ -s "$activated" ] && break
    key_attempt=$((key_attempt + 1))
done
if [ ! -s "$activated" ]; then
    cat "$output" >&2
    exit 1
fi
if wait "$pid"; then
    :
else
    status=$?
    cat "$output" >&2
    exit "$status"
fi
cat "$output"
grep -q '^native_grid_shortcut_live_smoke registered=true hidden=true hidden_before_registration=true physical_key=true activated=true visible=true exited=true$' "$output"
if qdbus6 --literal org.kde.kglobalaccel /component/noctty-smoke \
    org.kde.kglobalaccel.Component.allShortcutInfos 2>/dev/null |
    grep -q '"toggle-window-smoke"'; then
    echo 'NOCTTY shortcut registration survived process exit' >&2
    exit 1
fi
rm -f "$ready" "$activated" "$output"
trap - EXIT
