#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-worker-qualification.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

cd "$repo_root"
for mode in Debug ReleaseSafe; do
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache"
    project="$scratch/project-$mode"
    output_file="$scratch/output-$mode"
    mkdir -p "$project"
    ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build nocted-worker-qualification-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache"

    "$prefix/bin/nocted-worker-qualification" "$project" >"$output_file" &
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
        "mode=$mode fixture_files=193" >/dev/null
    for field in \
        'shared_admission_policy=true' \
        'generation_supersession=true' \
        'shared_queue_cap=64' \
        'lane_queue_cap=32' \
        'cancelled_lane_excluded=true' \
        'kind_cancel=true' \
        'pending_lookup=true' \
        'lazy_pool_creation=true' \
        'transactional_enqueue=true' \
        'append_failure_safe=true' \
        'push_failure_rollback=true' \
        'ordered_retirement=true' \
        'glib_thread_pools=true' \
        'worker_lanes=2' \
        'project_scan=true' \
        'search_streaming=true' \
        'snapshot_first=true' \
        'cooperative_cancellation=true' \
        'search_batch_size=24' \
        'search_batch_cap=2' \
        'backpressure_exercised=true' \
        'foreground_save_under_backpressure=true' \
        'worker_drained=true' \
        'allocator_leak_free=true' \
        'allocator_residual_bytes=0'; do
        printf '%s\n' "$output" | grep -F "$field" >/dev/null
    done
    printf '%s\n' "$output" | grep -E \
        'scan_entries=[1-9][0-9]* search_results=193 old_batch_peak=2 new_batch_peak=[12] new_batches=[2-9][0-9]* cancel_retired_ns=[1-9][0-9]*.*checkpoint_active_bytes=[1-9][0-9]*' \
        >/dev/null
    test "$peak_pss_kib" -gt 0
    test "$peak_rss_kib" -gt 0
    printf 'nocted_worker_resource mode=%s peak_pss_kib=%d peak_rss_kib=%d samples=%d root_process_only=true\n' \
        "$mode" "$peak_pss_kib" "$peak_rss_kib" "$samples"
done

echo 'nocted_worker_matrix debug=true release_safe=true shared_admission_policy=true generation_supersession=true shared_queue_cap=64 lane_queue_cap=32 cancelled_lane_excluded=true kind_cancel=true pending_lookup=true lazy_pool_creation=true transactional_enqueue=true append_failure_safe=true push_failure_rollback=true ordered_retirement=true glib_thread_pools=true worker_lanes=2 project_scan=true search_streaming=true snapshot_first=true cooperative_cancellation=true search_batch_size=24 search_batch_cap=2 backpressure_exercised=true foreground_save_under_backpressure=true worker_drained=true allocator_leak_free=true process_memory=true scratch_clean=true'
