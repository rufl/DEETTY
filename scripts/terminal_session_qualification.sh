#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-terminal-session.XXXXXX")
cleanup() {
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

run_mode() {
    mode=$1
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache-$mode"
    if ! zig build terminal-session-qualification-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache" \
        --global-cache-dir "$global_cache"; then
        return 1
    fi

    output_file="$scratch/output-$mode"
    "$prefix/bin/noctty-terminal-session-qualification" 64 8 >"$output_file" &
    runner_pid=$!
    peak_root_pss_kib=0
    peak_root_rss_kib=0
    peak_tree_pss_kib=0
    peak_tree_rss_kib=0
    samples=0
    while kill -0 "$runner_pid" 2>/dev/null; do
        root_pss_kib=$(awk '/^Pss:/ { print $2; exit }' "/proc/$runner_pid/smaps_rollup" 2>/dev/null || true)
        root_rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$runner_pid/status" 2>/dev/null || true)
        tree_sample=$("$repo_root/scripts/process_tree_memory.sh" "$runner_pid" 2>/dev/null || true)
        tree_pss_kib=$(printf '%s\n' "$tree_sample" | sed -n 's/.* pss_kib=\([0-9][0-9]*\).*/\1/p')
        tree_rss_kib=$(printf '%s\n' "$tree_sample" | sed -n 's/.* rss_kib=\([0-9][0-9]*\).*/\1/p')
        if [[ -n "$root_pss_kib" && "$root_pss_kib" -gt "$peak_root_pss_kib" ]]; then
            peak_root_pss_kib=$root_pss_kib
        fi
        if [[ -n "$root_rss_kib" && "$root_rss_kib" -gt "$peak_root_rss_kib" ]]; then
            peak_root_rss_kib=$root_rss_kib
        fi
        if [[ -n "$tree_pss_kib" && "$tree_pss_kib" -gt "$peak_tree_pss_kib" ]]; then
            peak_tree_pss_kib=$tree_pss_kib
        fi
        if [[ -n "$tree_rss_kib" && "$tree_rss_kib" -gt "$peak_tree_rss_kib" ]]; then
            peak_tree_rss_kib=$tree_rss_kib
        fi
        samples=$((samples + 1))
        sleep 0.01
    done
    if ! wait "$runner_pid"; then
        return 1
    fi
    printf 'terminal_session_resource mode=%s peak_root_pss_kib=%d peak_root_rss_kib=%d peak_tree_pss_kib=%d peak_tree_rss_kib=%d samples=%d root_process_separate=true process_tree_memory=true\n' \
        "$mode" "$peak_root_pss_kib" "$peak_root_rss_kib" \
        "$peak_tree_pss_kib" "$peak_tree_rss_kib" "$samples" \
        >"$scratch/resource-$mode"
}

cd "$repo_root"
run_mode Debug
run_mode ReleaseSafe

for mode in Debug ReleaseSafe; do
    output=$(cat "$scratch/output-$mode")
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -F \
        "mode=$mode normal_cycles=64 forced_cycles=8 sessions=72 resizes=128" \
        >/dev/null
    printf '%s\n' "$output" | grep -E \
        'output_bytes=[1-9][0-9]* allocator_leak_free=true allocator_residual_bytes=0 checkpoint_peak_active_bytes=[1-9][0-9]*' \
        >/dev/null
    printf '%s\n' "$output" | grep -E \
        'normal_p50_ns=[0-9]+ normal_p95_ns=[0-9]+ normal_p99_ns=[0-9]+ forced_p50_ns=[0-9]+ forced_p95_ns=[0-9]+ forced_p99_ns=[0-9]+' \
        >/dev/null
    printf '%s\n' "$output" | grep -F \
        'forced_grace_exhausted=8 shell_reaped=8 foreground_groups_reaped=8 process_residual=0 assertions=true' \
        >/dev/null
    resource=$(cat "$scratch/resource-$mode")
    printf '%s\n' "$resource"
    printf '%s\n' "$resource" | grep -E \
        "mode=$mode peak_root_pss_kib=[1-9][0-9]* peak_root_rss_kib=[1-9][0-9]* peak_tree_pss_kib=[1-9][0-9]* peak_tree_rss_kib=[1-9][0-9]* samples=[1-9][0-9]* root_process_separate=true process_tree_memory=true" \
        >/dev/null
done

echo 'terminal_session_qualification_matrix debug=true release_safe=true normal_cycles=64 forced_cycles=8 sessions_per_mode=72 total_sessions=144 allocator_leak_free=true forced_group_shutdown=true latency_percentiles=true root_memory_separate=true process_tree_memory=true scratch_clean=true'
