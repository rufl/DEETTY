#!/bin/sh
set -u

app=$(basename "$0")
case "$app" in
  noctty|nocted) ;;
  *) echo "unknown NOCTTY dogfood launcher: $app" >&2; exit 64 ;;
esac

launcher=$(readlink -f "$0")
runtime_dir=$(dirname "$launcher")
export LD_LIBRARY_PATH="$runtime_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
umask 077
if [ "$#" -ge 1 ]; then
  case "$1" in
    --version|--help|-h) exec "$runtime_dir/$app-bin" "$@" ;;
  esac
fi


# Existing-instance controls are latency-sensitive and do not represent a new
# dogfood session. Bypass receipt/log setup, but retain it when Show or Toggle
# must cold-start the GUI.
if [ "$app" = noctty ] && [ "$#" -eq 1 ]; then
  case "$1" in
    --status|--hide)
      exec "$runtime_dir/noctty-bin" "$@"
      ;;
    --show|--toggle)
      instance_lock="$HOME/.local/state/noctty/instance.lock"
      lock_held=0
      if command -v flock >/dev/null 2>&1 && [ -f "$instance_lock" ]; then
        flock -n -E 75 "$instance_lock" true 2>/dev/null
        lock_status=$?
        if [ "$lock_status" -eq 75 ]; then lock_held=1; fi
      fi
      if [ "$lock_held" -eq 1 ] ||
         "$runtime_dir/noctty-bin" --status 2>/dev/null |
           grep -F 'running=true' >/dev/null; then
        exec "$runtime_dir/noctty-bin" "$@"
      fi
      ;;
  esac
fi

state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
log_dir="$state_home/noctty/logs"
receipt_dir="$state_home/noctty/dogfood-sessions"
mkdir -p "$log_dir" "$receipt_dir"

start_timestamp=$(date --iso-8601=seconds)
start_epoch=$(date +%s)
start_uptime=$(awk '{ print int($1) }' /proc/uptime 2>/dev/null || printf '0')
host_name=$(hostname 2>/dev/null || printf 'unknown')
boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || printf 'unknown')
session_id="$app-$(date +%Y%m%d-%H%M%S)-$$"
log="$log_dir/$session_id.log"
receipt="$receipt_dir/$session_id.receipt"
desktop_session=${XDG_SESSION_TYPE:-unknown}
desktop_name=${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-unknown}}
wayland_display=${WAYLAND_DISPLAY:-none}
display=${DISPLAY:-none}
backend=${GDK_BACKEND:-auto}
kernel_release=$(uname -r 2>/dev/null || printf 'unknown')
os_id=$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release 2>/dev/null || printf 'unknown')
os_build=$(awk -F= '$1 == "BUILD_ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release 2>/dev/null || printf 'unknown')
build_receipt="$state_home/noctty/dogfood-build.receipt"
plasma_version=$(awk -F= '$1 == "plasma_version" { print $2; exit }' \
  "$build_receipt" 2>/dev/null || true)
kwin_version=$(awk -F= '$1 == "kwin_version" { print $2; exit }' \
  "$build_receipt" 2>/dev/null || true)
if [ -z "$plasma_version" ]; then
  plasma_version=$(plasmashell --version 2>/dev/null |
    awk 'NR == 1 { print $NF; exit }' || true)
fi
if [ -z "$kwin_version" ]; then
  kwin_version=$(kwin_wayland --version 2>/dev/null |
    awk 'NR == 1 { print $NF; exit }' || true)
fi
[ -n "$plasma_version" ] || plasma_version=unknown
[ -n "$kwin_version" ] || kwin_version=unknown
binary_path="$runtime_dir/$app-bin"
binary_sha256=$(sha256sum "$binary_path" 2>/dev/null | awk 'NR == 1 { print $1; exit }' || printf 'unknown')
omp_version=deferred

safe_token() {
  value=$(printf '%s' "$1" | tr -cd 'A-Za-z0-9._:+/-' | cut -c1-128)
  if [ -n "$value" ]; then printf '%s' "$value"; else printf 'unknown'; fi
}

safe_log_argument() {
  printf '%s' "$1" | LC_ALL=C tr '\000-\037\177' '?' | LC_ALL=C cut -c1-512
}

host_name=$(safe_token "$host_name")
boot_id=$(safe_token "$boot_id")
desktop_session=$(safe_token "$desktop_session")
desktop_name=$(safe_token "$desktop_name")
wayland_display=$(safe_token "$wayland_display")
display=$(safe_token "$display")
backend=$(safe_token "$backend")
kernel_release=$(safe_token "$kernel_release")
os_id=$(safe_token "$os_id")
os_build=$(safe_token "$os_build")
plasma_version=$(safe_token "$plasma_version")
kwin_version=$(safe_token "$kwin_version")
binary_sha256=$(safe_token "$binary_sha256")
runtime_warning_markers=0
gtk_critical_markers=0
gdk_critical_markers=0
glib_critical_markers=0
gobject_critical_markers=0
native_grid_failure_markers=0
panic_markers=0

write_receipt() {
  receipt_state=$1
  end_timestamp=$2
  end_epoch=$3
  end_uptime=$4
  duration_seconds=$5
  exit_status=$6
  receipt_new="$receipt.new.$$"
  {
    printf 'receipt_version=3\n'
    printf 'session_id=%s\n' "$session_id"
    printf 'app=%s\n' "$app"
    printf 'host=%s\n' "$host_name"
    printf 'boot_id=%s\n' "$boot_id"
    printf 'os_id=%s\n' "$os_id"
    printf 'os_build=%s\n' "$os_build"
    printf 'kernel_release=%s\n' "$kernel_release"
    printf 'desktop_name=%s\n' "$desktop_name"
    printf 'plasma_version=%s\n' "$plasma_version"
    printf 'kwin_version=%s\n' "$kwin_version"
    printf 'wayland_display=%s\n' "$wayland_display"
    printf 'display=%s\n' "$display"
    printf 'binary_sha256=%s\n' "$binary_sha256"
    printf 'state=%s\n' "$receipt_state"
    printf 'start_timestamp=%s\n' "$start_timestamp"
    printf 'start_epoch=%s\n' "$start_epoch"
    printf 'start_uptime_seconds=%s\n' "$start_uptime"
    printf 'end_timestamp=%s\n' "$end_timestamp"
    printf 'end_epoch=%s\n' "$end_epoch"
    printf 'end_uptime_seconds=%s\n' "$end_uptime"
    printf 'duration_seconds=%s\n' "$duration_seconds"
    printf 'exit_status=%s\n' "$exit_status"
    printf 'runtime_warning_markers=%s\n' "$runtime_warning_markers"
    printf 'gtk_critical_markers=%s\n' "$gtk_critical_markers"
    printf 'gdk_critical_markers=%s\n' "$gdk_critical_markers"
    printf 'glib_critical_markers=%s\n' "$glib_critical_markers"
    printf 'gobject_critical_markers=%s\n' "$gobject_critical_markers"
    printf 'native_grid_failure_markers=%s\n' "$native_grid_failure_markers"
    printf 'panic_markers=%s\n' "$panic_markers"
    printf 'desktop_session=%s\n' "$desktop_session"
    printf 'backend=%s\n' "$backend"
    printf 'log=%s\n' "$log"
  } >"$receipt_new"
  chmod 0600 "$receipt_new"
  mv -f "$receipt_new" "$receipt"
}

# Preserve a durable incomplete receipt even if the launcher or host is killed.
write_receipt running '' 0 0 0 -1

# Verbose process logs are bounded; compact duration receipts survive more
# frequent launch/test churn so five-session evidence is not rotated away.
ls -1t "$log_dir/$app"-*.log 2>/dev/null | awk 'NR > 100' | xargs -r rm -f
ls -1t "$receipt_dir/$app"-*.receipt 2>/dev/null |
  awk 'NR > 500' | xargs -r rm -f

if [ "${NOCTTY_DOGFOOD_VERBOSE:-0}" = 1 ]; then
  export G_MESSAGES_DEBUG=all
fi
ulimit -c unlimited 2>/dev/null || true
{
  printf 'dogfood_launch app=%s session_id=%s timestamp=%s epoch=%s uptime_seconds=%s pid=%s host=%s boot_id=%s session=%s backend=%s receipt=%s omp_version=%s args=' \
    "$app" "$session_id" "$start_timestamp" "$start_epoch" "$start_uptime" \
    "$$" "$host_name" "$boot_id" "$desktop_session" "$backend" "$receipt" \
    "$omp_version"
  for argument in "$@"; do
    printf ' %s' "$(safe_log_argument "$argument")"
  done
  printf '\n'
} >>"$log"

export NOCTTY_DOGFOOD_SESSION_ID="$session_id"
export NOCTTY_DOGFOOD_LOG="$log"
set +e
"$runtime_dir/$app-bin" "$@" >>"$log" 2>&1
status=$?
set -e

end_timestamp=$(date --iso-8601=seconds)
end_epoch=$(date +%s)
end_boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || printf 'unknown')
end_uptime=$(awk '{ print int($1) }' /proc/uptime 2>/dev/null || printf '0')
if [ "$boot_id" = "$end_boot_id" ] && [ "$start_uptime" -gt 0 ] &&
   [ "$end_uptime" -ge "$start_uptime" ]; then
  duration_seconds=$((end_uptime - start_uptime))
else
  duration_seconds=$((end_epoch - start_epoch))
  [ "$duration_seconds" -ge 0 ] || duration_seconds=0
fi

if grep -F ' event=omp_detected ' "$log" >/dev/null 2>&1; then
  omp_version=unknown
  if command -v omp >/dev/null 2>&1; then
    candidate_omp_version=$(omp --version 2>/dev/null | sed -n '1p' || true)
    case "$candidate_omp_version" in
      omp/*[!A-Za-z0-9._/-]*|'') ;;
      omp/*) omp_version=$candidate_omp_version ;;
    esac
  fi
  printf 'dogfood_event session=%s event=omp_version pane=0 value=1 detail=%s\n' \
    "$session_id" "$omp_version" >>"$log"
  omp_log_clean=0
  omp_log_detail=nonzero_exit
  if [ "$status" -eq 0 ]; then
    omp_log_clean=1
    omp_log_detail=clean
    if grep -E '(\*\* .*(ERROR|CRITICAL) \*\*|Tried to map a popup with a non-top most parent|native_grid_[A-Za-z0-9_]*failed|dogfood_event_error)' \
        "$log" >/dev/null 2>&1; then
      omp_log_clean=0
      omp_log_detail=error_detected
    fi
  fi
  printf 'dogfood_event session=%s event=omp_log_review pane=0 value=%s detail=%s\n' \
    "$session_id" "$omp_log_clean" "$omp_log_detail" >>"$log"
fi

bounded_marker_count() {
  marker_count=$(grep -E -c "$1" "$log" 2>/dev/null || true)
  case "$marker_count" in ''|*[!0-9]*) marker_count=0 ;; esac
  if [ "$marker_count" -gt 9999 ]; then marker_count=9999; fi
  printf '%s' "$marker_count"
}
runtime_warning_markers=$(bounded_marker_count \
  '(Gtk|Gdk|GLib|GObject)-CRITICAL|Tried to map a popup with a non-top most parent|native_grid_[A-Za-z0-9_]*failed|thread [0-9]+ panic')
gtk_critical_markers=$(bounded_marker_count 'Gtk-CRITICAL')
gdk_critical_markers=$(bounded_marker_count 'Gdk-CRITICAL')
glib_critical_markers=$(bounded_marker_count 'GLib-CRITICAL')
gobject_critical_markers=$(bounded_marker_count 'GObject-CRITICAL')
native_grid_failure_markers=$(bounded_marker_count 'native_grid_[A-Za-z0-9_]*failed')
panic_markers=$(bounded_marker_count 'thread [0-9]+ panic')
printf 'dogfood_exit app=%s session_id=%s timestamp=%s epoch=%s uptime_seconds=%s duration_seconds=%s status=%s runtime_warning_markers=%s gtk_critical=%s gdk_critical=%s glib_critical=%s gobject_critical=%s native_grid_failed=%s panic=%s receipt=%s log=%s\n' \
  "$app" "$session_id" "$end_timestamp" "$end_epoch" "$end_uptime" \
  "$duration_seconds" "$status" "$runtime_warning_markers" \
  "$gtk_critical_markers" "$gdk_critical_markers" \
  "$glib_critical_markers" "$gobject_critical_markers" \
  "$native_grid_failure_markers" "$panic_markers" "$receipt" "$log" >>"$log"
write_receipt finished "$end_timestamp" "$end_epoch" "$end_uptime" \
  "$duration_seconds" "$status"
exit "$status"
