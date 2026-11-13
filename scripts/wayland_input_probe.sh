#!/usr/bin/env sh
set -eu

if ! pkg-config --exists libei-1.0; then
    echo "wayland_input=unavailable reason=libei_missing"
    exit 0
fi

if ! busctl --user introspect org.freedesktop.portal.Desktop \
    /org/freedesktop/portal/desktop \
    org.freedesktop.portal.RemoteDesktop >/tmp/dintty-remote-desktop-introspection.txt 2>/dev/null; then
    echo "wayland_input=unavailable reason=remote_desktop_portal_missing"
    exit 0
fi

if rg -q 'ConnectToEIS|NotifyKeyboardKeysym' /tmp/dintty-remote-desktop-introspection.txt; then
    echo "wayland_input=available requires_user_consent=true transport=xdg_remote_desktop_eis"
else
    echo "wayland_input=unavailable reason=portal_lacks_keyboard_transport"
fi
