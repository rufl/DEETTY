#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"
binary=${1:-$repo_root/zig-out/bin/noctty.exe}
test -s "$binary"
binary=$(realpath "$binary")
for tool in wine wineboot wineserver; do
  command -v "$tool" >/dev/null
done

scratch=$(mktemp -d "$repo_root/.noctty-windows-menu.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
cat >"$scratch/run.sh" <<'RUNNER'
#!/usr/bin/env sh
set -eu
export WINEPREFIX=$1
export WINEDEBUG=-all
export WINEDLLOVERRIDES='mscoree,mshtml='
unset NOCTTY_WINDOWS_HOST_SMOKE NOCTTY_WINDOWS_SHELL
wineboot -u
wineserver -w
NOCTTY_WINDOWS_MENU_SMOKE=1 wine "$2"
wineserver -w
RUNNER

status=0
"$repo_root/scripts/isolated_display_runner.sh" --wm auto --timeout 120 -- \
  sh "$scratch/run.sh" "$scratch/wine" "$binary" >"$scratch/runner.log" 2>&1 || status=$?
if [ "$status" -ne 0 ]; then
  cat "$scratch/runner.log" >&2
  if [ -d "$scratch/wine/drive_c/users" ]; then
    find "$scratch/wine/drive_c/users" -type f -name 'noctty-*.log' -exec sed -n '1,240p' {} \; >&2
  fi
  exit "$status"
fi
receipt='windows_menu_smoke menu_tree=true local_commands=true remote_disabled=true remote_dispatch_rejected=true cycle_hints=true terminal_commands=true ownership=true conpty=false tab_strip=true tab_selection=true tab_rename=true tab_reorder=true tab_inset=true divider_drag=true divider_cancel=true divider_menu=true appearance_dialog=true tab_drag=true theme_library=true theme_selection=true theme_persistence=true theme_rollback=true theme_export=true theme_paint=true theme_dialog_cancel=true theme_unicode=true profiles=true profile_dialog=true profile_persistence=true profile_process=true theme_sources=true'
logs="$scratch/wine/drive_c/users"
if ! find "$logs" -type f -name 'noctty-*.log' -exec grep -F "$receipt" {} + | grep -F "$receipt"; then
  cat "$scratch/runner.log" >&2
  echo 'windows_terminal_menu_smoke error=missing_menu_receipt' >&2
  exit 1
fi
printf '%s\n' 'windows_terminal_menu_smoke isolated=true wine=true menu_state=true remote_dispatch_guard=true tab_strip=true tab_selection=true tab_rename=true tab_reorder=true tab_inset=true divider_drag=true divider_cancel=true divider_menu=true appearance_dialog=true tab_drag=true theme_library=true theme_selection=true theme_persistence=true theme_rollback=true theme_export=true theme_paint=true theme_dialog_cancel=true theme_unicode=true profiles=true profile_dialog=true profile_persistence=true profile_process=true theme_sources=true physical_windows=false conpty=false'
