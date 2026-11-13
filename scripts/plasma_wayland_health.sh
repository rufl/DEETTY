#!/usr/bin/env sh
set -eu

# Read-only local health check for the supported EndeavourOS/Plasma/Wayland
# dogfood path. This command never refreshes package databases or uses a network.
session_type=${XDG_SESSION_TYPE:-unknown}
runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
wayland_display=${WAYLAND_DISPLAY:-none}
wayland_socket=false
if [ "$wayland_display" != none ] && [ -S "$runtime_dir/$wayland_display" ]; then
  wayland_socket=true
fi

receipt_field() {
  awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$2"
}

package_version() {
  if command -v pacman >/dev/null 2>&1; then
    pacman -Q "$1" 2>/dev/null | awk 'NR == 1 { print $2; exit }'
  else
    printf 'unknown'
  fi
}

plasma_version=$(package_version plasma-desktop)
kwin_version=$(package_version kwin)
portal_version=$(package_version xdg-desktop-portal)
portal_kde_version=$(package_version xdg-desktop-portal-kde)
at_spi_version=$(package_version at-spi2-core)
plasma_version=${plasma_version:-unknown}
kwin_version=${kwin_version:-unknown}
portal_version=${portal_version:-unknown}
portal_kde_version=${portal_kde_version:-unknown}
at_spi_version=${at_spi_version:-unknown}

kwin_active=false
plasmashell_active=false
portal_active=false
at_spi_active=false
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user is-active --quiet plasma-kwin_wayland.service && kwin_active=true
  systemctl --user is-active --quiet plasma-plasmashell.service && plasmashell_active=true
  systemctl --user is-active --quiet xdg-desktop-portal.service && portal_active=true
  systemctl --user is-active --quiet at-spi-dbus-bus.service && at_spi_active=true
fi

portal_kde_available=false
if [ -r /usr/share/xdg-desktop-portal/portals/kde.portal ] &&
   grep -Fx 'UseIn=KDE' /usr/share/xdg-desktop-portal/portals/kde.portal >/dev/null 2>&1; then
  portal_kde_available=true
fi

at_spi_socket=false
if command -v python3 >/dev/null 2>&1; then
  if python3 - "$runtime_dir/at-spi/bus_0" >/dev/null 2>&1 <<'PY'
import socket
import sys

connection = socket.socket(socket.AF_UNIX)
connection.settimeout(1.0)
connection.connect(sys.argv[1])
connection.close()
PY
  then
    at_spi_socket=true
  fi
elif [ -S "$runtime_dir/at-spi/bus_0" ]; then
  at_spi_socket=unverified
fi

private_layer_shell=false
layer_shell_path="$HOME/.local/libexec/dintty-dogfood/lib/libgtk-layer-shell.so.0"
if [ -r "$layer_shell_path" ]; then private_layer_shell=true; fi

dintty_binary=false
nocted_binary=false
dintty_path="$HOME/.local/libexec/dintty-dogfood/dintty-bin"
nocted_path="$HOME/.local/libexec/dintty-dogfood/nocted-bin"
[ -x "$dintty_path" ] && dintty_binary=true
[ -x "$nocted_path" ] && nocted_binary=true

build_receipt_valid=false
build_receipt="${XDG_STATE_HOME:-$HOME/.local/state}/dintty/dogfood-build.receipt"
if [ -r "$build_receipt" ] && [ "$dintty_binary" = true ] &&
   [ "$nocted_binary" = true ] && [ "$private_layer_shell" = true ]; then
  expected_dintty=$(receipt_field dintty_sha256 "$build_receipt")
  expected_nocted=$(receipt_field nocted_sha256 "$build_receipt")
  expected_layer_shell=$(receipt_field layer_shell_sha256 "$build_receipt")
  actual_dintty=$(sha256sum "$dintty_path" | awk '{ print $1 }')
  actual_nocted=$(sha256sum "$nocted_path" | awk '{ print $1 }')
  actual_layer_shell=$(sha256sum "$layer_shell_path" | awk '{ print $1 }')
  if [ "$expected_dintty" = "$actual_dintty" ] &&
     [ "$expected_nocted" = "$actual_nocted" ] &&
     [ "$expected_layer_shell" = "$actual_layer_shell" ]; then
    build_receipt_valid=true
  fi
fi

pending_desktop_upgrades=0
if command -v pacman >/dev/null 2>&1; then
  pending_desktop_upgrades=$(pacman -Qu 2>/dev/null |
    grep -E -c '^(plasma|kwin|xdg-desktop-portal|at-spi2-core|gtk3|mesa|linux)' || true)
fi
case "$pending_desktop_upgrades" in
  ''|*[!0-9]*) pending_desktop_upgrades=0 ;;
esac

healthy=false
if [ "$session_type" = wayland ] && [ "$wayland_socket" = true ] &&
   [ "$kwin_active" = true ] && [ "$plasmashell_active" = true ] &&
   [ "$portal_active" = true ] && [ "$portal_kde_available" = true ] &&
   [ "$at_spi_active" = true ] && [ "$at_spi_socket" = true ] &&
   [ "$private_layer_shell" = true ] && [ "$dintty_binary" = true ] &&
   [ "$nocted_binary" = true ] && [ "$build_receipt_valid" = true ]; then
  healthy=true
fi

printf 'plasma_wayland_health version=2 healthy=%s no_network=true session_type=%s wayland_socket=%s kwin_active=%s plasmashell_active=%s portal_active=%s portal_kde_available=%s at_spi_active=%s at_spi_socket=%s private_layer_shell=%s dintty_binary=%s nocted_binary=%s build_receipt_valid=%s pending_desktop_upgrades_local_db=%s\n' \
  "$healthy" "$session_type" "$wayland_socket" "$kwin_active" \
  "$plasmashell_active" "$portal_active" "$portal_kde_available" \
  "$at_spi_active" "$at_spi_socket" "$private_layer_shell" \
  "$dintty_binary" "$nocted_binary" "$build_receipt_valid" \
  "$pending_desktop_upgrades"
printf 'plasma_wayland_versions plasma=%s kwin=%s portal=%s portal_kde=%s at_spi=%s\n' \
  "$plasma_version" "$kwin_version" "$portal_version" \
  "$portal_kde_version" "$at_spi_version"

if [ "$at_spi_active" = true ] && [ "$at_spi_socket" = false ]; then
  printf '%s\n' 'plasma_wayland_issue component=at_spi reason=stale_socket repair=systemctl--user-restart-at-spi-dbus-bus.service'
fi
if [ "$healthy" != true ]; then exit 1; fi
