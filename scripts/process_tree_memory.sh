#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'usage: %s PID [--details]\n' "$0" >&2
    exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage
root_pid=$1
details=${2:-}
[[ "$root_pid" =~ ^[1-9][0-9]*$ ]] || usage
[[ -r "/proc/$root_pid/status" ]] || {
    printf 'process_tree_memory error=pid_not_readable pid=%s\n' "$root_pid" >&2
    exit 1
}
[[ -z "$details" || "$details" == "--details" ]] || usage

tree_pids() {
    ps -e -o pid=,ppid= | awk -v root="$root_pid" '
        { pid[++count] = $1; parent[count] = $2 }
        END {
            keep[root] = 1
            for (pass = 0; pass < count; pass++) {
                for (item = 1; item <= count; item++) {
                    if (keep[parent[item]]) keep[pid[item]] = 1
                }
            }
            for (item = 1; item <= count; item++) {
                if (keep[pid[item]]) print pid[item]
            }
        }
    '
}

pids=$(tree_pids)
total_pss_kib=0
total_rss_kib=0
process_count=0
readable_pss_count=0

if [[ "$details" == "--details" ]]; then
    printf '%-8s %-8s %12s %12s %s\n' PID PPID PSS_KiB RSS_KiB COMMAND
fi

while IFS= read -r pid; do
    [[ -n "$pid" && -r "/proc/$pid/status" ]] || continue
    pss_kib=0
    if [[ -r "/proc/$pid/smaps_rollup" ]]; then
        pss_kib=$(awk '/^Pss:/ { print $2; exit }' "/proc/$pid/smaps_rollup")
        readable_pss_count=$((readable_pss_count + 1))
    fi
    rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$pid/status")
    ppid=$(awk '/^PPid:/ { print $2; exit }' "/proc/$pid/status")
    command=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)
    if [[ -z "$command" ]]; then
        command=$(awk '/^Name:/ { print $2; exit }' "/proc/$pid/status")
    fi
    total_pss_kib=$((total_pss_kib + ${pss_kib:-0}))
    total_rss_kib=$((total_rss_kib + ${rss_kib:-0}))
    process_count=$((process_count + 1))
    if [[ "$details" == "--details" ]]; then
        printf '%-8s %-8s %12s %12s %s\n' \
            "$pid" "${ppid:-0}" "${pss_kib:-0}" "${rss_kib:-0}" "$command"
    fi
done <<<"$pids"

pss_mib=$(awk -v kib="$total_pss_kib" 'BEGIN { printf "%.3f", kib / 1024 }')
rss_mib=$(awk -v kib="$total_rss_kib" 'BEGIN { printf "%.3f", kib / 1024 }')
printf 'process_tree_memory root_pid=%s processes=%d pss_kib=%d pss_mib=%s rss_kib=%d rss_mib=%s pss_readable=%d\n' \
    "$root_pid" "$process_count" "$total_pss_kib" "$pss_mib" \
    "$total_rss_kib" "$rss_mib" "$readable_pss_count"
