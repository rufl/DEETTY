#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch_parent=${NOCTTY_PIPELINE_QUALIFICATION_PARENT:-$repo_root}
case "$scratch_parent" in
    /*) ;;
    *) scratch_parent="$repo_root/$scratch_parent" ;;
esac
scratch=$(mktemp -d "$scratch_parent/.noctty-grid-pipeline.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

process_tree_pids() {
    root_pid=$1
    pending=$root_pid
    seen=" $root_pid "
    while [[ -n "$pending" ]]; do
        current=${pending%% *}
        if [[ "$pending" == *" "* ]]; then
            pending=${pending#* }
        else
            pending=
        fi
        children=$(cat "/proc/$current/task/$current/children" 2>/dev/null || true)
        for child in $children; do
            case "$seen" in
                *" $child "*) ;;
                *)
                    seen="$seen$child "
                    pending=${pending:+"$pending "}$child
                    ;;
            esac
        done
    done
    printf '%s\n' "$seen"
}

run_mode() {
    mode=$1
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache-$mode"
    mode_tmp="$scratch/tmp-$mode"
    mode_xdg_cache="$scratch/xdg-cache-$mode"
    mkdir -p "$mode_tmp" "$mode_xdg_cache"
    TMPDIR="$mode_tmp" XDG_CACHE_HOME="$mode_xdg_cache" \
        zig build noctty-smoke-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache" \
        --global-cache-dir "$global_cache"

    output_file="$scratch/output-$mode"
    artifact="$scratch/pipeline-$mode.png"
    "$prefix/bin/noctty-smoke" \
        --native-grid-pipeline-qualification "$artifact" "$mode" \
        >"$output_file" &
    runner_pid=$!
    peak_root_pss_kib=0
    peak_root_rss_kib=0
    peak_tree_pss_kib=0
    peak_tree_rss_kib=0
    samples=0
    while kill -0 "$runner_pid" 2>/dev/null; do
        root_pss_kib=$(awk '/^Pss:/ { print $2; exit }' "/proc/$runner_pid/smaps_rollup" 2>/dev/null || true)
        root_rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$runner_pid/status" 2>/dev/null || true)
        tree_pss_kib=0
        tree_rss_kib=0
        for pid in $(process_tree_pids "$runner_pid"); do
            pss_kib=$(awk '/^Pss:/ { print $2; exit }' "/proc/$pid/smaps_rollup" 2>/dev/null || true)
            rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$pid/status" 2>/dev/null || true)
            tree_pss_kib=$((tree_pss_kib + ${pss_kib:-0}))
            tree_rss_kib=$((tree_rss_kib + ${rss_kib:-0}))
        done
        peak_root_pss_kib=$((root_pss_kib > peak_root_pss_kib ? root_pss_kib : peak_root_pss_kib))
        peak_root_rss_kib=$((root_rss_kib > peak_root_rss_kib ? root_rss_kib : peak_root_rss_kib))
        peak_tree_pss_kib=$((tree_pss_kib > peak_tree_pss_kib ? tree_pss_kib : peak_tree_pss_kib))
        peak_tree_rss_kib=$((tree_rss_kib > peak_tree_rss_kib ? tree_rss_kib : peak_tree_rss_kib))
        samples=$((samples + 1))
        sleep 0.005
    done
    wait "$runner_pid"
    printf 'native_grid_pipeline_resource mode=%s peak_root_pss_kib=%d peak_root_rss_kib=%d peak_tree_pss_kib=%d peak_tree_rss_kib=%d samples=%d root_memory_separate=true process_tree_memory=true\n' \
        "$mode" "$peak_root_pss_kib" "$peak_root_rss_kib" \
        "$peak_tree_pss_kib" "$peak_tree_rss_kib" "$samples" \
        >"$scratch/resource-$mode"

    "$prefix/bin/noctty-smoke" \
        --native-grid-pipeline-qualification \
        "$scratch/pipeline-$mode-repeat.png" "$mode" \
        >"$scratch/output-$mode-repeat"
}

cd "$repo_root"
run_mode Debug &
debug_pid=$!
run_mode ReleaseSafe &
release_safe_pid=$!
debug_status=0
release_safe_status=0
wait "$debug_pid" || debug_status=$?
wait "$release_safe_pid" || release_safe_status=$?
if [[ "$debug_status" -ne 0 || "$release_safe_status" -ne 0 ]]; then
    exit 1
fi

for mode in Debug ReleaseSafe; do
    output=$(cat "$scratch/output-$mode")
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -F \
        "mode=$mode samples=64 columns=120 rows=40" >/dev/null
    printf '%s\n' "$output" | grep -E \
        'output_bytes=[1-9][0-9]* input_write_to_draw_p50_ns=[1-9][0-9]* input_write_to_draw_p95_ns=[1-9][0-9]* input_write_to_draw_p99_ns=[1-9][0-9]*' \
        >/dev/null
    printf '%s\n' "$output" | grep -E \
        'pty_read_to_draw_p50_ns=[1-9][0-9]* pty_read_to_draw_p95_ns=[1-9][0-9]* pty_read_to_draw_p99_ns=[1-9][0-9]*' \
        >/dev/null
    printf '%s\n' "$output" | grep -E \
        'draw_p50_cpu_ns=[1-9][0-9]* draw_p95_cpu_ns=[1-9][0-9]* draw_p99_cpu_ns=[1-9][0-9]* pixel_hash=[1-9][0-9]* first_frame_owned_allocations=[1-9][0-9]* warm_frame_owned_allocations=0 peak_owned_scratch_bytes=[1-9][0-9]*' \
        >/dev/null
    printf '%s\n' "$output" | grep -F \
        'production_pty=true production_vt=true production_cairo=true display_independent=true compositor_presented=false artifact=true assertions=true' \
        >/dev/null
    resource=$(cat "$scratch/resource-$mode")
    printf '%s\n' "$resource"
    printf '%s\n' "$resource" | grep -E \
        "mode=$mode peak_root_pss_kib=[1-9][0-9]* peak_root_rss_kib=[1-9][0-9]* peak_tree_pss_kib=[1-9][0-9]* peak_tree_rss_kib=[1-9][0-9]* samples=[1-9][0-9]* root_memory_separate=true process_tree_memory=true" \
        >/dev/null
    cmp -s "$scratch/pipeline-$mode.png" "$scratch/pipeline-$mode-repeat.png"
done

cmp -s "$scratch/pipeline-Debug.png" "$scratch/pipeline-ReleaseSafe.png"
artifact_sha256=$(sha256sum "$scratch/pipeline-Debug.png" | awk '{print $1}')
printf 'native_grid_pipeline_artifact repeated_exact=true debug_release_identical=true sha256=%s scratch_clean=true\n' \
    "$artifact_sha256"
echo 'native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true'
