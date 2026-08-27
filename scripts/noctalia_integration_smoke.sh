#!/usr/bin/env sh
set -eu

cache_dir="${NOCTTY_ZIG_CACHE_DIR:-.zig-cache}"
global_cache_dir="${NOCTTY_ZIG_GLOBAL_CACHE_DIR:-.zig-cache/global}"
prefix="${NOCTTY_INSTALL_PREFIX:-zig-out}"
binary="$prefix/bin/noctty"

zig build --prefix "$prefix" --cache-dir "$cache_dir" --global-cache-dir "$global_cache_dir"

for compositor in niri hyprland sway scroll labwc mango; do
    output="$(
        WAYLAND_DISPLAY=wayland-test \
        XDG_CURRENT_DESKTOP=Noctalia \
        NOCTTY_DESKTOP_SHELL=noctalia \
        NOCTALIA_VERSION=5 \
        "$binary" --noctalia-plan "$compositor"
    )"
    printf '%s\n' "$output" | grep -F "noctalia active=true supported=true version=v5 compositor=$compositor" >/dev/null
    printf '%s\n' "$output" | grep -F 'activation=dbus command=noctty --toggle service=com.noctty.NOCTTY' >/dev/null
    printf '%s\n' "$output" | grep -F 'surface=toplevel app_id=com.noctty.NOCTTY title_prefix=NOCTTY_Dropdown notifications=org.freedesktop.Notifications' >/dev/null
    printf '%s\n' "$output" | grep -F 'binding=' | grep -v 'unavailable' >/dev/null
    printf '%s\n' "$output" | grep -F 'autostart=' | grep -F 'noctty --hidden' >/dev/null ||
        printf '%s\n' "$output" | grep -F 'autostart=' | grep -F '"noctty" "--hidden"' >/dev/null
done

host_plan="$(
    WAYLAND_DISPLAY=wayland-test \
    XDG_SESSION_TYPE=wayland \
    XDG_CURRENT_DESKTOP=niri \
    XDG_SESSION_DESKTOP=niri \
    KDE_FULL_SESSION=0 \
    NIRI_SOCKET=/tmp/niri-test.sock \
    "$binary" --host-plan
)"
printf '%s\n' "$host_plan" | grep -F 'backend=noctalia_wayland shell=noctalia compositor=niri' >/dev/null
printf '%s\n' "$host_plan" | grep -F 'global_shortcut=false external_activation=true layer_shell=false desktop_notifications=true' >/dev/null

printf '%s\n' "$host_plan" | grep -F 'transport=compositor_binding' >/dev/null

for path in \
    resources/noctalia/niri.kdl \
    resources/noctalia/hyprland.lua \
    resources/noctalia/hyprland.conf \
    resources/noctalia/sway.conf \
    resources/noctalia/scroll.conf \
    resources/noctalia/labwc-rc.xml \
    resources/noctalia/labwc-autostart \
    resources/noctalia/mango.conf \
    resources/noctalia/noctalia-v5-widget.toml; do
    test -s "$path"
done

grep -F 'F10 { spawn "noctty" "--toggle"; }' resources/noctalia/niri.kdl >/dev/null
grep -F 'match app-id=r#"^com\.noctty\.NOCTTY$"# title=r#"^NOCTTY Dropdown(?: —|$)"#' resources/noctalia/niri.kdl >/dev/null
grep -F 'open-floating true' resources/noctalia/niri.kdl >/dev/null
grep -F 'default-floating-position x=0 y=0 relative-to="top"' resources/noctalia/niri.kdl >/dev/null
grep -F 'hl.bind("F10", hl.dsp.exec_cmd("noctty --toggle"))' resources/noctalia/hyprland.lua >/dev/null
grep -F 'bind = , F10, exec, noctty --toggle' resources/noctalia/hyprland.conf >/dev/null
grep -F 'bindsym F10 exec noctty --toggle' resources/noctalia/sway.conf >/dev/null
grep -F '<keybind key="F10">' resources/noctalia/labwc-rc.xml >/dev/null
grep -F 'bind=NONE,F10,spawn,noctty --toggle' resources/noctalia/mango.conf >/dev/null
grep -F '[widget.noctty.actions]' resources/noctalia/noctalia-v5-widget.toml >/dev/null
grep -F 'left = "exec noctty --toggle"' resources/noctalia/noctalia-v5-widget.toml >/dev/null
grep -F 'right = "exec noctty --show"' resources/noctalia/noctalia-v5-widget.toml >/dev/null
sh -n resources/noctalia/labwc-autostart

v4_hyprland="$(
    WAYLAND_DISPLAY=wayland-test \
    XDG_CURRENT_DESKTOP=Noctalia \
    NOCTTY_DESKTOP_SHELL=noctalia \
    NOCTALIA_VERSION=4 \
    "$binary" --noctalia-plan hyprland
)"
printf '%s\n' "$v4_hyprland" | grep -F 'version=v4 compositor=hyprland' >/dev/null
printf '%s\n' "$v4_hyprland" | grep -F 'binding=bind = , F10, exec, noctty --toggle' >/dev/null
printf '%s\n' "$v4_hyprland" | grep -F 'autostart=exec-once = noctty --hidden' >/dev/null

echo "noctalia_integration model=true v4_compatible=true v5=true niri=true hyprland=true sway=true scroll=true labwc=true mango=true dbus_activation=true layer_shell=false notifications=true artifacts=true"
