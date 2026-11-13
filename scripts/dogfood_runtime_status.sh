#!/usr/bin/env sh
set -eu

list_candidates=false
if [ "${1:-}" = "--list-candidates" ]; then
  list_candidates=true
  shift
fi

state_home=${1:-${XDG_STATE_HOME:-"$HOME/.local/state"}}
log_dir="$state_home/deetty/logs"
receipt_dir="$state_home/deetty/dogfood-sessions"
records=$(mktemp "${TMPDIR:-/tmp}/deetty-dogfood-runtime.XXXXXX")
trap 'rm -f "$records"' EXIT HUP INT TERM
: >"$records"

receipt_field() {
  awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$2"
}

if [ -d "$receipt_dir" ]; then
  for receipt in "$receipt_dir"/*.receipt; do
    [ -f "$receipt" ] || continue
    session_id=$(receipt_field session_id "$receipt")
    app=$(receipt_field app "$receipt")
    state=$(receipt_field state "$receipt")
    duration=$(receipt_field duration_seconds "$receipt")
    status=$(receipt_field exit_status "$receipt")
    case "$session_id" in
      ''|*[!A-Za-z0-9._-]*) continue ;;
    esac
    case "$app" in deetty|nocted) ;; *) continue ;; esac
    case "$duration" in ''|*[!0-9]*) duration=0 ;; esac
    case "$status" in -1) ;; ''|*[!0-9]*) status=-1 ;; esac
    if [ "$state" = finished ]; then finished=true; else finished=false; fi
    printf '%s\t%s\t%s\t%s\t%s\treceipt\n' \
      "$session_id" "$app" "$finished" "$duration" "$status" >>"$records"
  done
fi

if [ -d "$log_dir" ]; then
  for log in "$log_dir"/deetty-*.log "$log_dir"/nocted-*.log; do
    [ -f "$log" ] || continue
    session_id=$(basename "$log" .log)
    [ -f "$receipt_dir/$session_id.receipt" ] && continue
    launch=$(awk '/^dogfood_launch / { print; exit }' "$log")
    [ -n "$launch" ] || continue
    app=$(printf '%s\n' "$launch" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^app=/) { sub(/^app=/, "", $i); print $i; exit } }')
    case "$app" in deetty|nocted) ;; *) continue ;; esac
    start_epoch=$(printf '%s\n' "$launch" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^epoch=/) { sub(/^epoch=/, "", $i); print $i; exit } }')
    if [ -z "$start_epoch" ]; then
      start_timestamp=$(printf '%s\n' "$launch" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^timestamp=/) { sub(/^timestamp=/, "", $i); print $i; exit } }')
      start_epoch=$(date --date="$start_timestamp" +%s 2>/dev/null || printf '0')
    fi
    exit_line=$(awk '/^dogfood_exit / { value = $0 } END { print value }' "$log")
    if [ -z "$exit_line" ]; then
      printf '%s\t%s\tfalse\t0\t-1\tlegacy\n' "$session_id" "$app" >>"$records"
      continue
    fi
    duration=$(printf '%s\n' "$exit_line" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^duration_seconds=/) { sub(/^duration_seconds=/, "", $i); print $i; exit } }')
    if [ -z "$duration" ]; then
      end_timestamp=$(printf '%s\n' "$exit_line" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^timestamp=/) { sub(/^timestamp=/, "", $i); print $i; exit } }')
      end_epoch=$(date --date="$end_timestamp" +%s 2>/dev/null || printf '0')
      duration=$((end_epoch - start_epoch))
      [ "$duration" -ge 0 ] || duration=0
    fi
    status=$(printf '%s\n' "$exit_line" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^status=/) { sub(/^status=/, "", $i); print $i; exit } }')
    case "$duration" in ''|*[!0-9]*) duration=0 ;; esac
    case "$status" in ''|*[!0-9]*) status=-1 ;; esac
    printf '%s\t%s\ttrue\t%s\t%s\tlegacy\n' \
      "$session_id" "$app" "$duration" "$status" >>"$records"
  done
fi

host_name=$(hostname 2>/dev/null || printf 'unknown')
awk -F '\t' -v host="$host_name" '
  {
    app = $2
    sessions[app]++
    sources[$6]++
    if ($3 == "true") {
      finished[app]++
      seconds[app] += $4
      if ($5 != 0) failed[app]++
      if ($4 >= 7200) {
        candidates[app]++
        candidate_seconds[app] += $4
      }
    } else {
      incomplete[app]++
    }
  }
  END {
    printf "dogfood_runtime host=%s receipt_sessions=%d legacy_sessions=%d", host, sources["receipt"] + 0, sources["legacy"] + 0
    printf " deetty_sessions=%d deetty_finished=%d deetty_incomplete=%d deetty_failed=%d deetty_seconds=%d deetty_hours=%.3f deetty_two_hour_candidates=%d deetty_candidate_hours=%.3f", sessions["deetty"] + 0, finished["deetty"] + 0, incomplete["deetty"] + 0, failed["deetty"] + 0, seconds["deetty"] + 0, (seconds["deetty"] + 0) / 3600, candidates["deetty"] + 0, (candidate_seconds["deetty"] + 0) / 3600
    printf " nocted_sessions=%d nocted_finished=%d nocted_incomplete=%d nocted_failed=%d nocted_seconds=%d nocted_hours=%.3f nocted_two_hour_candidates=%d nocted_candidate_hours=%.3f evidence_boundary=runtime_only\n", sessions["nocted"] + 0, finished["nocted"] + 0, incomplete["nocted"] + 0, failed["nocted"] + 0, seconds["nocted"] + 0, (seconds["nocted"] + 0) / 3600, candidates["nocted"] + 0, (candidate_seconds["nocted"] + 0) / 3600
  }
' "$records"

if [ "$list_candidates" = true ]; then
  awk -F '\t' '$3 == "true" && $4 >= 7200 {
    printf "dogfood_runtime_candidate session_id=%s app=%s duration_seconds=%s hours=%.3f exit_status=%s source=%s\n", $1, $2, $4, $4 / 3600, $5, $6
  }' "$records"
fi
