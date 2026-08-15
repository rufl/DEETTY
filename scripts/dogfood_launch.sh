#!/bin/sh
set -u

app=$(basename "$0")
case "$app" in
  noctty|nocted) ;;
  *) echo "unknown NOCTTY dogfood launcher: $app" >&2; exit 64 ;;
esac

umask 077
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
backend=${GDK_BACKEND:-auto}
omp_version=deferred

write_receipt() {
  receipt_state=$1
  end_timestamp=$2
  end_epoch=$3
  end_uptime=$4
  duration_seconds=$5
  exit_status=$6
  receipt_new="$receipt.new.$$"
  {
    printf 'receipt_version=1\n'
    printf 'session_id=%s\n' "$session_id"
    printf 'app=%s\n' "$app"
    printf 'host=%s\n' "$host_name"
    printf 'boot_id=%s\n' "$boot_id"
    printf 'state=%s\n' "$receipt_state"
    printf 'start_timestamp=%s\n' "$start_timestamp"
    printf 'start_epoch=%s\n' "$start_epoch"
    printf 'start_uptime_seconds=%s\n' "$start_uptime"
    printf 'end_timestamp=%s\n' "$end_timestamp"
    printf 'end_epoch=%s\n' "$end_epoch"
    printf 'end_uptime_seconds=%s\n' "$end_uptime"
    printf 'duration_seconds=%s\n' "$duration_seconds"
    printf 'exit_status=%s\n' "$exit_status"
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

export G_MESSAGES_DEBUG=all
ulimit -c unlimited 2>/dev/null || true
{
  printf 'dogfood_launch app=%s session_id=%s timestamp=%s epoch=%s uptime_seconds=%s pid=%s host=%s boot_id=%s session=%s backend=%s receipt=%s omp_version=%s args=' \
    "$app" "$session_id" "$start_timestamp" "$start_epoch" "$start_uptime" \
    "$$" "$host_name" "$boot_id" "$desktop_session" "$backend" "$receipt" \
    "$omp_version"
  printf ' %s' "$@"
  printf '\n'
} >>"$log"

launcher=$(readlink -f "$0")
runtime_dir=$(dirname "$launcher")
export LD_LIBRARY_PATH="$runtime_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
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
    if grep -E '(\*\* .*(ERROR|CRITICAL) \*\*|native_grid_[A-Za-z0-9_]*failed|dogfood_event_error)' \
        "$log" >/dev/null 2>&1; then
      omp_log_clean=0
      omp_log_detail=error_detected
    fi
  fi
  printf 'dogfood_event session=%s event=omp_log_review pane=0 value=%s detail=%s\n' \
    "$session_id" "$omp_log_clean" "$omp_log_detail" >>"$log"
fi

printf 'dogfood_exit app=%s session_id=%s timestamp=%s epoch=%s uptime_seconds=%s duration_seconds=%s status=%s receipt=%s log=%s\n' \
  "$app" "$session_id" "$end_timestamp" "$end_epoch" "$end_uptime" \
  "$duration_seconds" "$status" "$receipt" "$log" >>"$log"
write_receipt finished "$end_timestamp" "$end_epoch" "$end_uptime" \
  "$duration_seconds" "$status"
exit "$status"
