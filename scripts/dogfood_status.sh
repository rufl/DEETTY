#!/usr/bin/env sh
set -eu

log=${1:-docs/DOGFOOD_LOG.md}
state_home=${2:-${XDG_STATE_HOME:-"$HOME/.local/state"}}

test -s "$log"

session_records=$(mktemp "${TMPDIR:-/tmp}/noctty-dogfood-sessions.XXXXXX")
candidates=$(mktemp "${TMPDIR:-/tmp}/noctty-dogfood-candidates.XXXXXX")
used=$(mktemp "${TMPDIR:-/tmp}/noctty-dogfood-used.XXXXXX")
omp_events=$(mktemp "${TMPDIR:-/tmp}/noctty-dogfood-omp-events.XXXXXX")
omp_records=$(mktemp "${TMPDIR:-/tmp}/noctty-dogfood-omp.XXXXXX")
trap 'rm -f "$session_records" "$candidates" "$used" "$omp_events" "$omp_records"' EXIT HUP INT TERM

awk '
  function flush() {
    if (active && counted)
      printf "%s|%d|%d|%d|%d|%d\n", receipt, work_context, four_pane, agent, nocted, close_confirm
  }
  /^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] / {
    flush()
    active = 1
    counted = ($0 !~ /not counted/)
    receipt = ""
    work_context = four_pane = agent = nocted = close_confirm = 0
    next
  }
  active && counted && /^- Dogfood receipt:/ {
    receipt = $0
    sub(/^- Dogfood receipt:[[:space:]]*/, "", receipt)
    gsub(/`/, "", receipt)
  }
  active && counted && /^- Work performed:/ {
    value = tolower($0)
    sub(/^- work performed:[[:space:]]*/, "", value)
    negative = (value == "" ||
      value ~ /^(no|none|not|unknown|unconfirmed|unrecorded|smoke|test)([[:space:][:punct:]]|$)/)
    if (!negative)
      work_context = 1
  }
  active && counted && /Panes\/tabs used:.*([4-9]|[1-9][0-9]+)/ { four_pane = 1 }
  active && counted && /Agent\/TUI apps used:/ {
    value = tolower($0)
    sub(/^.*agent\/tui apps used:[[:space:]]*/, "", value)
    negative = (value ~ /^(no|none|not|unknown|unconfirmed|unrecorded)([[:space:][:punct:]]|$)/)
    if (!negative && value ~ /(^|[^[:alnum:]_])(pi|omp|codex|claude|agent)([^[:alnum:]_]|$)/)
      agent = 1
  }
  active && counted && /NoctEd used:/ {
    value = tolower($0)
    sub(/^.*nocted used:[[:space:]]*/, "", value)
    negative = (value ~ /^(no|none|not|unknown|unconfirmed|unrecorded)([[:space:][:punct:]]|$)/)
    if (!negative && value ~ /(^|[^[:alnum:]_])(yes|edit|edited|editing|save|saved|search|searched|find|quick)([^[:alnum:]_]|$)/)
      nocted = 1
  }
  active && counted {
    value = tolower($0)
    close_subject = (value ~ /(close confirmation|foreground-job close|foreground job close)/)
    close_positive = (value ~ /(passed|worked|tested|confirmed|prompted|canceled|cancelled|accepted)/)
    close_negative = (value ~ /(^|[^[:alnum:]_])(no|not|never|unknown|unconfirmed|missing|without)([^[:alnum:]_]|$)/)
    if (close_subject && close_positive && !close_negative)
      close_confirm = 1
  }
  END { flush() }
' "$log" >"$session_records"

: >"$omp_events"
for omp_log in "$state_home"/noctty/logs/noctty-*.log; do
  [ -f "$omp_log" ] || continue
  awk '
    BEGIN { OFS = "\t"; session = version = "" }
    /^dogfood_launch / {
      session = version = ""
      for (i = 1; i <= NF; i++) {
        value = $i
        if (value ~ /^session_id=/) {
          sub(/^session_id=/, "", value)
          session = value
        } else if (value ~ /^omp_version=/) {
          sub(/^omp_version=/, "", value)
          version = value
        }
      }
      next
    }
    /^(dogfood_event|noctty_dogfood_event) / {
      event_session = event = pane = number = detail = ""
      for (i = 1; i <= NF; i++) {
        value = $i
        if (value ~ /^(session|session_id)=/) {
          sub(/^(session|session_id)=/, "", value)
          event_session = value
        } else if (value ~ /^event=/) {
          sub(/^event=/, "", value)
          event = value
        } else if (value ~ /^pane=/) {
          sub(/^pane=/, "", value)
          pane = value
        } else if (value ~ /^value=/) {
          sub(/^value=/, "", value)
          number = value
        } else if (value ~ /^detail=/) {
          sub(/^detail=/, "", value)
          detail = value
        }
      }
      if (session ~ /^[A-Za-z0-9._-]+$/ && event_session == session &&
          event ~ /^omp_[a-z_]+$/ && pane ~ /^[0-9]+$/ &&
          number ~ /^-?[0-9]+$/ &&
          detail ~ /^[A-Za-z0-9._\/-]+$/)
        print session, version, event, pane, number, detail
    }
  ' "$omp_log" >>"$omp_events"
done

awk -F '\t' '
  NR == FNR {
    if ($3 == "omp_version")
      session_version[$1] = $6
    if ($3 == "omp_workspace" && length($6) == 64 &&
        $6 ~ /^[0-9a-f][0-9a-f]+$/)
      workspace[$1] = $6
    next
  }
  {
    session = $1
    version_value = session_version[session]
    event = $3
    pane = $4
    number = $5 + 0
    detail = $6
    id = workspace[session]
    if (id == "") next
    observed[id] = 1
    session_key = id SUBSEP session
    sessions[session_key] = 1
    if (!(id in version)) version[id] = version_value
    else if (version[id] != version_value) version_mismatch[id] = 1
    if (event == "omp_concurrency" || event == "omp_workspace") {
      if (number > concurrent[id]) concurrent[id] = number
    } else if (event == "omp_detected" && length(detail) == 64 &&
               detail ~ /^[0-9a-f][0-9a-f]+$/) {
      worktree_key = id SUBSEP detail
      if (!(worktree_key in worktree_seen)) {
        worktree_seen[worktree_key] = 1
        worktree_count[id]++
      }
    } else if (event == "omp_concurrent_streaming" && number >= 4) {
      streaming[id] = 1
    } else if (event == "omp_independent_input") {
      input[id] = 1
    } else if (event == "omp_independent_paste") {
      paste[id] = 1
    } else if (event == "omp_resize_during_output") {
      resize[id] = 1
    } else if (event == "omp_focus") {
      focus_key = id SUBSEP pane
      if (!(focus_key in focus_seen)) {
        focus_seen[focus_key] = 1
        focus_count[id]++
      }
    } else if (event == "omp_hide" && number >= 4) {
      hide[id] = 1
    } else if (event == "omp_show_after_hide" && number >= 4) {
      show[id] = 1
    } else if (event == "omp_close_cancel") {
      close_cancel[id] = 1
    } else if (event == "omp_close_accept_isolated" && number >= 3) {
      close_accept[id] = 1
    } else if (event == "omp_normal_exit_cleanup") {
      normal_exit[id] = 1
    } else if (event == "omp_hot_restore" && number >= 4) {
      hot_restore[id] = 1
    } else if (event == "omp_output_integrity" && number > 0) {
      output[id] = 1
    } else if (event == "omp_log_review") {
      if (number == 1) log_clean[session_key] = 1
      else log_dirty[id] = 1
    }
  }
  END {
    for (key in sessions) {
      split(key, parts, SUBSEP)
      session_count[parts[1]]++
      if (log_clean[key]) clean_count[parts[1]]++
    }
    for (id in observed) {
      version_valid = (version[id] ~ /^omp\/[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.]+)?$/ &&
        !version_mismatch[id])
      worktrees = worktree_count[id] >= 4
      focus = focus_count[id] >= 4
      hide_show = hide[id] && show[id]
      logs = (session_count[id] > 0 &&
        clean_count[id] == session_count[id] && !log_dirty[id])
      complete = (version_valid && concurrent[id] >= 4 && worktrees &&
        streaming[id] && input[id] && paste[id] && resize[id] && focus &&
        hide_show && close_cancel[id] && close_accept[id] &&
        normal_exit[id] && hot_restore[id] && output[id] && logs)
      printf "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d\n",
        version[id], concurrent[id], worktrees, streaming[id], input[id],
        paste[id], resize[id], focus, hide_show, close_cancel[id],
        close_accept[id], normal_exit[id], hot_restore[id], output[id],
        logs, complete
    }
  }
' "$omp_events" "$omp_events" >"$omp_records"

documented_sessions=$(wc -l <"$session_records")
not_counted_sessions=$(awk '
  /^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] / && /not counted/ { count++ }
  END { print count + 0 }
' "$log")

runtime_status=$(./scripts/dogfood_runtime_status.sh --list-candidates "$state_home")
printf '%s\n' "$runtime_status" | awk '
  /^dogfood_runtime_candidate / {
    id = app = seconds = ""
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^session_id=/) {
        id = $i
        sub(/^session_id=/, "", id)
      } else if ($i ~ /^app=/) {
        app = $i
        sub(/^app=/, "", app)
      } else if ($i ~ /^duration_seconds=/) {
        seconds = $i
        sub(/^duration_seconds=/, "", seconds)
      }
    }
    if (app == "noctty" && id != "" && seconds ~ /^[0-9]+$/)
      print id "\t" seconds
  }
' >"$candidates"

counted_sessions=0
counted_seconds=0
unverified_sessions=0
four_pane=false
agent=false
nocted=false
close_confirm=false
while IFS='|' read -r receipt has_work has_four has_agent has_nocted has_close; do
  case "$receipt" in
    ''|*[!A-Za-z0-9._-]*)
      unverified_sessions=$((unverified_sessions + 1))
      continue
      ;;
  esac
  if [ "$has_work" != 1 ]; then
    unverified_sessions=$((unverified_sessions + 1))
    continue
  fi
  if grep -Fx "$receipt" "$used" >/dev/null 2>&1; then
    unverified_sessions=$((unverified_sessions + 1))
    continue
  fi
  seconds=$(awk -F '\t' -v id="$receipt" '$1 == id { print $2; exit }' "$candidates")
  if [ -z "$seconds" ]; then
    unverified_sessions=$((unverified_sessions + 1))
    continue
  fi
  printf '%s\n' "$receipt" >>"$used"
  counted_sessions=$((counted_sessions + 1))
  counted_seconds=$((counted_seconds + seconds))
  [ "$has_four" = 1 ] && four_pane=true
  [ "$has_agent" = 1 ] && agent=true
  [ "$has_nocted" = 1 ] && nocted=true
  [ "$has_close" = 1 ] && close_confirm=true
done <"$session_records"

if [ "$counted_sessions" -ge 5 ]; then five_sessions=true; else five_sessions=false; fi
counted_hours=$(awk -v seconds="$counted_seconds" 'BEGIN { printf "%.3f", seconds / 3600 }')

omp_observed_sessions=0
omp_qualified_sessions=0
omp_qualified_version=none
omp_max_concurrent=0
omp_worktrees=false
omp_streaming=false
omp_input=false
omp_paste=false
omp_resize=false
omp_focus=false
omp_hide=false
omp_close_cancel=false
omp_close_accept=false
omp_normal_exit=false
omp_hot_restore=false
omp_output=false
omp_logs=false
while IFS='|' read -r version concurrent has_worktrees has_streaming \
  has_input has_paste has_resize has_focus has_hide has_close_cancel \
  has_close_accept has_normal_exit has_hot_restore has_output has_logs \
  complete; do
  omp_observed_sessions=$((omp_observed_sessions + 1))
  case "$concurrent" in
    ''|*[!0-9]*) concurrent=0 ;;
  esac
  [ "$concurrent" -gt "$omp_max_concurrent" ] && omp_max_concurrent=$concurrent
  [ "$has_worktrees" = 1 ] && omp_worktrees=true
  [ "$has_streaming" = 1 ] && omp_streaming=true
  [ "$has_input" = 1 ] && omp_input=true
  [ "$has_paste" = 1 ] && omp_paste=true
  [ "$has_resize" = 1 ] && omp_resize=true
  [ "$has_focus" = 1 ] && omp_focus=true
  [ "$has_hide" = 1 ] && omp_hide=true
  [ "$has_close_cancel" = 1 ] && omp_close_cancel=true
  [ "$has_close_accept" = 1 ] && omp_close_accept=true
  [ "$has_normal_exit" = 1 ] && omp_normal_exit=true
  [ "$has_hot_restore" = 1 ] && omp_hot_restore=true
  [ "$has_output" = 1 ] && omp_output=true
  [ "$has_logs" = 1 ] && omp_logs=true
  if [ "$complete" = 1 ]; then
    omp_qualified_sessions=$((omp_qualified_sessions + 1))
    if [ "$omp_qualified_version" = none ]; then
      omp_qualified_version=$version
    fi
  fi
done <"$omp_records"
if [ "$omp_qualified_sessions" -gt 0 ]; then
  omp_compatible=true
else
  omp_compatible=false
fi

printf 'dogfood_status counted_sessions=%s documented_sessions=%s unverified_sessions=%s not_counted_sessions=%s counted_seconds=%s counted_hours=%s five_sessions=%s four_pane=%s agent_cli=%s nocted_real_edit=%s foreground_close_confirmation=%s\n' \
  "$counted_sessions" "$documented_sessions" "$unverified_sessions" \
  "$not_counted_sessions" "$counted_seconds" "$counted_hours" \
  "$five_sessions" "$four_pane" "$agent" "$nocted" "$close_confirm"
printf 'dogfood_omp_status observed_sessions=%s qualified_sessions=%s qualified_version=%s max_concurrent=%s separate_worktrees=%s concurrent_streaming=%s independent_input=%s independent_paste=%s resize_during_output=%s focus_isolation=%s hide_show=%s close_cancel=%s close_accept_isolated=%s normal_exit_cleanup=%s hot_restore=%s output_integrity=%s logs_clean=%s compatible=%s\n' \
  "$omp_observed_sessions" "$omp_qualified_sessions" "$omp_qualified_version" \
  "$omp_max_concurrent" "$omp_worktrees" "$omp_streaming" "$omp_input" \
  "$omp_paste" "$omp_resize" "$omp_focus" "$omp_hide" "$omp_close_cancel" \
  "$omp_close_accept" "$omp_normal_exit" "$omp_hot_restore" "$omp_output" \
  "$omp_logs" "$omp_compatible"
printf '%s\n' "$runtime_status" | awk '/^dogfood_runtime / { print; exit }'
