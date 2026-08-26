#!/usr/bin/env sh
set -eu

./scripts/require_isolated_display.sh --dedicated

for backend in wayland x11; do
    echo "native-host smoke backend=$backend"
    if [ "$backend" = x11 ]; then
        output_file="/tmp/noctty-native-host-$backend.txt"
        GDK_BACKEND="$backend" zig build smoke-run -- --native-host-smoke | tee "$output_file"
        grep -q 'secondary_started=true secondary_output=true secondary_exited=true' "$output_file"
    else
        GDK_BACKEND="$backend" zig build smoke-run -- --native-host-smoke
    fi
done

echo "native-host smoke mode=windowed backend=x11"
windowed_output="/tmp/noctty-native-host-windowed.txt"
GDK_BACKEND=x11 zig build smoke-run -- --native-host-windowed-smoke | tee "$windowed_output"
grep -q 'mode=windowed .*placement=windowed' "$windowed_output"

echo "native-host smoke mode=zen_fullscreen backend=x11"
zen_output="/tmp/noctty-native-host-zen.txt"
GDK_BACKEND=x11 zig build smoke-run -- --native-host-zen-smoke | tee "$zen_output"
grep -q 'mode=zen_fullscreen .*placement=fullscreen' "$zen_output"

echo "native-host smoke shortcut-conflict backend=wayland"
GDK_BACKEND=wayland zig build smoke-run -- --native-host-shortcut-conflict-smoke

echo "native-host smoke shortcut-recorder backend=wayland"
GDK_BACKEND=wayland zig build smoke-run -- --native-host-shortcut-recorder-smoke

echo "native-host smoke shortcut-hid backend=x11"
hid_output="/tmp/noctty-shortcut-hid-output.txt"
hid_image="/tmp/noctty-shortcut-recorder.png"
hid_crop="/tmp/noctty-shortcut-recorder-crop.png"
rm -f "$hid_output" "$hid_image" "$hid_crop"
GDK_BACKEND=x11 zig build smoke-run -- --native-host-shortcut-hid-smoke >"$hid_output" 2>&1 &
hid_pid=$!
window=""
attempt=0
while [ "$attempt" -lt 100 ]; do
    window=$(xdotool search --name '^NOCTTY Dropdown Shortcut$' 2>/dev/null | head -1 || true)
    [ -n "$window" ] && break
    attempt=$((attempt + 1))
    sleep 0.05
done
[ -n "$window" ]
spectacle -b -n -o "$hid_image"
geometry=$(xdotool getwindowgeometry --shell "$window")
x=$(printf '%s\n' "$geometry" | awk -F= '/^X=/{print $2}')
y=$(printf '%s\n' "$geometry" | awk -F= '/^Y=/{print $2}')
width=$(printf '%s\n' "$geometry" | awk -F= '/^WIDTH=/{print $2}')
height=$(printf '%s\n' "$geometry" | awk -F= '/^HEIGHT=/{print $2}')
convert "$hid_image" -crop "${width}x${height}+${x}+${y}" +repage "$hid_crop"
set -- $(identify -format '%w %h %[colors]' "$hid_crop")
[ "$1" -ge 200 ]
[ "$2" -ge 80 ]
[ "$3" -gt 4 ]
xdotool windowactivate --sync "$window" key --clearmodifiers ctrl+Home
wait "$hid_pid"
cat "$hid_output"
grep -q 'mode=shortcut_hid' "$hid_output"
grep -q 'config_persisted=true config_reloaded=true configured_key=Home configured_ctrl=true' "$hid_output"

echo "native-host wayland-input capability"
./scripts/wayland_input_probe.sh
