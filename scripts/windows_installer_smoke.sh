#!/usr/bin/env sh
set -eu

export LC_ALL=C
export TZ=UTC

installer=${1:-dist/noctty-windows-x86_64-setup-unsigned.exe}
case "$installer" in
  /*) installer_path=$installer ;;
  *) installer_path="$(pwd -P)/$installer" ;;
esac
test -s "$installer_path"
test -s "$installer_path.sha256"
test -s "$installer_path.manifest"
(
  cd "$(dirname "$installer_path")"
  sha256sum -c "$(basename "$installer_path").sha256" >/dev/null
)
grep -Fx 'windows_installer_manifest_version=2' "$installer_path.manifest" >/dev/null
grep -Fx 'signed=false' "$installer_path.manifest" >/dev/null
grep -Fx 'scope=per-user' "$installer_path.manifest" >/dev/null
grep -Fx 'open_with_only=true' "$installer_path.manifest" >/dev/null
grep -Fx 'user_data_preserved_on_uninstall=true' "$installer_path.manifest" >/dev/null

wine=${NOCTTY_WINE:-wine}
wineboot=${NOCTTY_WINEBOOT:-wineboot}
winepath=${NOCTTY_WINEPATH:-winepath}
wineserver=${NOCTTY_WINESERVER:-wineserver}
command -v "$wine" >/dev/null
command -v "$wineboot" >/dev/null
command -v "$winepath" >/dev/null
command -v "$wineserver" >/dev/null
command -v timeout >/dev/null

wine_prefix=$(mktemp -d "${TMPDIR:-/tmp}/noctty-installer-wine.XXXXXX")
cleanup() {
  timeout --kill-after=5 "${NOCTTY_WINE_CLEANUP_TIMEOUT_SECONDS:-15}" \
    env WINEPREFIX="$wine_prefix" "$wineboot" -e >/dev/null 2>&1 || true
  rm -rf "$wine_prefix"
}
trap cleanup EXIT HUP INT TERM
export WINEPREFIX=$wine_prefix
export WINEDEBUG=${WINEDEBUG:--all}
step_timeout=${NOCTTY_WINE_STEP_TIMEOUT_SECONDS:-90}
case "$step_timeout" in
  ''|*[!0-9]*|0)
    echo 'windows_installer_smoke error=invalid_step_timeout' >&2
    exit 2
    ;;
esac
run_step() {
  stage=$1
  shift
  if timeout --kill-after=5 "$step_timeout" "$@"; then
    return 0
  else
    status=$?
  fi
  echo "windows_installer_smoke error=step_failed stage=$stage status=$status" >&2
  exit "$status"
}
run_step wineboot "$wineboot" -u >/dev/null
run_step install "$wine" "$installer_path" /S

local_appdata_win=$(run_step local_appdata "$wine" cmd /d /c 'echo %LOCALAPPDATA%' | tr -d '\r' | sed -n '$p')
appdata_win=$(run_step appdata "$wine" cmd /d /c 'echo %APPDATA%' | tr -d '\r' | sed -n '$p')
userprofile_win=$(run_step userprofile "$wine" cmd /d /c 'echo %USERPROFILE%' | tr -d '\r' | sed -n '$p')
install_dir=$("$winepath" -u "$local_appdata_win\\Programs\\NOCTTY")
user_data_dir=$("$winepath" -u "$local_appdata_win\\NOCTTY")
start_menu_dir=$("$winepath" -u "$appdata_win\\Microsoft\\Windows\\Start Menu\\Programs\\NOCTTY")

test -s "$install_dir/noctty.exe"
test -s "$install_dir/nocted.exe"
test -s "$install_dir/Uninstall.exe"
test -s "$start_menu_dir/NOCTTY.lnk"
test -s "$start_menu_dir/NoctEd.lnk"
test -s "$start_menu_dir/Uninstall NOCTTY.lnk"
test ! -e "$("$winepath" -u "$userprofile_win\\Desktop\\NOCTTY.lnk")"
test ! -e "$("$winepath" -u "$userprofile_win\\Desktop\\NoctEd.lnk")"

uninstall_key='HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\NOCTTY'
application_key='HKCU\Software\Classes\Applications\nocted.exe\shell\open\command'
progid_key='HKCU\Software\Classes\NoctEd.Text\shell\open\command'
run_step uninstall_registry "$wine" reg query "$uninstall_key" /v QuietUninstallString >/dev/null
run_step application_registry "$wine" reg query "$application_key" /ve >/dev/null
run_step progid_registry "$wine" reg query "$progid_key" /ve >/dev/null
for extension in .txt .c .h .cc .cpp .cxx .hh .hpp .py .json; do
  run_step "extension_registry_$extension" "$wine" reg query \
    "HKCU\\Software\\Classes\\${extension}\\OpenWithProgids" \
    /v NoctEd.Text >/dev/null
done

mkdir -p "$user_data_dir"
printf 'preserve user state\n' > "$user_data_dir/installer-smoke-user-state"
printf 'preserve non-installer file\n' > "$install_dir/operator-owned-file"
run_step noctty_self_test "$wine" "$install_dir/noctty.exe" --self-test
run_step nocted_self_test "$wine" "$install_dir/nocted.exe" --self-test
run_step uninstall "$wine" "$install_dir/Uninstall.exe" /S
run_step wineserver_wait "$wineserver" -w

test ! -e "$install_dir/noctty.exe"
test ! -e "$install_dir/nocted.exe"
test ! -e "$install_dir/Uninstall.exe"
test -s "$install_dir/operator-owned-file"
test -s "$user_data_dir/installer-smoke-user-state"
test ! -e "$start_menu_dir/NOCTTY.lnk"
test ! -e "$start_menu_dir/NoctEd.lnk"
test ! -e "$start_menu_dir/Uninstall NOCTTY.lnk"
if "$wine" reg query "$uninstall_key" >/dev/null 2>&1; then
  echo 'windows_installer_smoke error=uninstall_key_survived' >&2
  exit 1
fi
if "$wine" reg query 'HKCU\Software\Classes\Applications\nocted.exe' >/dev/null 2>&1; then
  echo 'windows_installer_smoke error=application_registration_survived' >&2
  exit 1
fi
if "$wine" reg query 'HKCU\Software\Classes\NoctEd.Text' >/dev/null 2>&1; then
  echo 'windows_installer_smoke error=progid_survived' >&2
  exit 1
fi
for extension in .txt .c .h .cc .cpp .cxx .hh .hpp .py .json; do
  if "$wine" reg query "HKCU\\Software\\Classes\\${extension}\\OpenWithProgids" /v NoctEd.Text >/dev/null 2>&1; then
    echo "windows_installer_smoke error=open_with_survived extension=$extension" >&2
    exit 1
  fi
done

echo 'windows_installer_smoke silent_install=true silent_uninstall=true shortcuts_reversible=true open_with_reversible=true user_data_preserved=true unrelated_install_file_preserved=true'
