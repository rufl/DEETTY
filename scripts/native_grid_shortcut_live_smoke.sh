#!/usr/bin/env sh
set -eu

./scripts/require_isolated_display.sh --dedicated
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

ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-binaries
output=/tmp/noctty-native-grid-shortcut-live.txt
ready=/tmp/noctty-native-grid-shortcut-ready
activated=/tmp/noctty-native-grid-shortcut-activated
recorder_ready=/tmp/noctty-native-grid-shortcut-recorder-ready
recorder_captured=/tmp/noctty-native-grid-shortcut-recorder-captured
rm -f "$output"
rm -f "$ready"
rm -f "$activated"
rm -f "$recorder_ready"
rm -f "$recorder_captured"
GDK_BACKEND=x11 ./zig-out/bin/noctty-smoke --native-grid-shortcut-live-smoke >"$output" 2>&1 &
pid=$!
cleanup() {
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$ready"
    rm -f "$activated"
    rm -f "$recorder_ready"
    rm -f "$recorder_captured"
    rm -f "$output"
    unregister_shortcut
}
trap cleanup EXIT

attempt=0
while [ "$attempt" -lt 100 ]; do
    if [ -s "$ready" ] && qdbus6 --literal org.kde.kglobalaccel /component/noctty_smoke org.kde.kglobalaccel.Component.allShortcutInfos 2>/dev/null | grep -q '16777273'; then
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
attempt=0
while [ "$attempt" -lt 100 ] && [ ! -s "$recorder_ready" ]; do
    attempt=$((attempt + 1))
    sleep 0.05
done
if [ ! -s "$recorder_ready" ]; then
    cat "$output" >&2
    exit 1
fi
xdotool key --clearmodifiers F10
attempt=0
while [ "$attempt" -lt 100 ] && [ ! -s "$recorder_captured" ]; do
    attempt=$((attempt + 1))
    sleep 0.05
done
if [ ! -s "$recorder_captured" ]; then
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
grep -q '^native_grid_shortcut_live_smoke registered=true hidden=true hidden_before_registration=true physical_key=true activated=true visible=true recorder=true recaptured=F10 exited=true$' "$output"
if qdbus6 --literal org.kde.kglobalaccel /component/noctty_smoke \
    org.kde.kglobalaccel.Component.allShortcutInfos 2>/dev/null |
    grep -q '"toggle-window-smoke"'; then
    echo 'NOCTTY shortcut registration survived process exit' >&2
    exit 1
fi
rm -f "$ready" "$activated" "$recorder_ready" "$recorder_captured" "$output"
trap - EXIT
