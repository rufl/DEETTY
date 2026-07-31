#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-project-index.XXXXXX")
cleanup() {
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

cd "$repo_root"
for mode in Debug ReleaseSafe; do
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache"
    zig build nocted-project-index-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache" \
        --global-cache-dir "$global_cache"

    for scale in 4000 25000 100000; do
        project="$scratch/project-$mode-$scale"
        mkdir -p "$project"
        output_file="$scratch/output-$mode-$scale"
        "$prefix/bin/nocted-project-index-qualification" \
            "$project" "$scale" >"$output_file" &
        runner_pid=$!
        peak_pss_kib=0
        peak_rss_kib=0
        samples=0
        while kill -0 "$runner_pid" 2>/dev/null; do
            pss_kib=$(awk '/^Pss:/ { print $2; exit }' \
                "/proc/$runner_pid/smaps_rollup" 2>/dev/null || true)
            rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' \
                "/proc/$runner_pid/status" 2>/dev/null || true)
            if [ -n "$pss_kib" ] && [ "$pss_kib" -gt "$peak_pss_kib" ]; then
                peak_pss_kib=$pss_kib
            fi
            if [ -n "$rss_kib" ] && [ "$rss_kib" -gt "$peak_rss_kib" ]; then
                peak_rss_kib=$rss_kib
            fi
            samples=$((samples + 1))
            sleep 0.01
        done
        wait "$runner_pid"
        output=$(cat "$output_file")
        printf '%s\n' "$output"
        printf '%s\n' "$output" | grep -F \
            "mode=$mode scale=$scale entries=$scale" >/dev/null
        for field in \
            'directory_rename=true' \
            'replacement_conflict=true' \
            'ignore_fallback=true' \
            'overflow_fallback=true' \
            'snapshot_teardown=true' \
            'allocator_leak_free=true' \
            'allocator_residual_bytes=0'; do
            printf '%s\n' "$output" | grep -F "$field" >/dev/null
        done
        printf '%s\n' "$output" | grep -E \
            'scan_ns=[1-9][0-9]* quick_open_ns=[1-9][0-9]* quick_open_matches=[1-9][0-9]* delta_ns=[1-9][0-9]* index_bytes=[1-9][0-9]* two_snapshot_bytes=[1-9][0-9]*' \
            >/dev/null
        printf '%s\n' "$output" | grep -E \
            'delta_events=5 delta_added=[1-9][0-9]* delta_removed=[1-9][0-9]*' \
            >/dev/null
        printf 'nocted_project_index_resource mode=%s scale=%d peak_pss_kib=%d peak_rss_kib=%d samples=%d root_process_only=true\n' \
            "$mode" "$scale" "$peak_pss_kib" "$peak_rss_kib" "$samples"
        rm -rf "$project"
    done
done

echo 'nocted_project_index_matrix debug=true release_safe=true scales=4000,25000,100000 immutable_delta=true quick_open_scale=true quick_open_release_safe_budget_ms=500 directory_rename=true replacement_conflict=true ignore_fallback=true overflow_fallback=true scan_time=true delta_time=true index_memory=true two_snapshot_peak=true process_memory=true allocator_leak_free=true scratch_clean=true'
