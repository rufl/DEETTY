#!/usr/bin/env sh
set -eu

log=${1:-docs/DOGFOOD_LOG.md}

test -s "$log"

counted_log=$(mktemp "${TMPDIR:-/tmp}/noctty-dogfood-counted.XXXXXX")
trap 'rm -f "$counted_log"' EXIT

awk '
  /^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] / {
    counted = ($0 !~ /not counted/)
    if (counted) count++
  }
  counted { print > counted_log }
  END { print count + 0 > count_path }
' counted_log="$counted_log" count_path="$counted_log.count" "$log"
counted_sessions=$(cat "$counted_log.count")
rm -f "$counted_log.count"

not_counted_sessions=$(awk '
  /^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] / {
    if ($0 ~ /not counted/) count++
  }
  END { print count + 0 }
' "$log")

four_pane=$(grep -E 'Panes/tabs used:.*([4-9]|[1-9][0-9]+)' "$counted_log" >/dev/null 2>&1 && printf true || printf false)
agent=$(grep -Ei 'Agent/TUI apps used:.*(pi|codex|claude|agent)' "$counted_log" >/dev/null 2>&1 && printf true || printf false)
nocted=$(grep -Ei 'NoctEd used: yes|NoctEd used:.*(edit|save|search|find|quick)' "$counted_log" >/dev/null 2>&1 && printf true || printf false)
close_confirm=$(grep -Ei 'close confirmation|foreground-job|foreground job|sleep 600' "$counted_log" >/dev/null 2>&1 && printf true || printf false)

if [ "$counted_sessions" -ge 5 ]; then five_sessions=true; else five_sessions=false; fi

printf 'dogfood_status counted_sessions=%s not_counted_sessions=%s five_sessions=%s four_pane=%s agent_cli=%s nocted_real_edit=%s foreground_close_confirmation=%s\n' \
  "$counted_sessions" "$not_counted_sessions" "$five_sessions" "$four_pane" "$agent" "$nocted" "$close_confirm"
