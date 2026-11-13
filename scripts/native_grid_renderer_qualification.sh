#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch_parent=${DEETTY_RENDERER_QUALIFICATION_PARENT:-$repo_root}
scratch=$(mktemp -d "$scratch_parent/.deetty-grid-renderer.XXXXXX")
cleanup() {
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

run_mode() {
    mode=$1
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache-$mode"
    artifact_dir="$scratch/artifacts-$mode"
    mode_tmp="$scratch/tmp-$mode"
    mode_xdg_cache="$scratch/xdg-cache-$mode"
    mkdir -p "$artifact_dir" "$mode_tmp" "$mode_xdg_cache"
    if ! TMPDIR="$mode_tmp" XDG_CACHE_HOME="$mode_xdg_cache" \
        ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build deetty-smoke-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache"; then
        return 1
    fi

    output_file="$scratch/output-$mode"
    "$prefix/bin/deetty-smoke" \
        --native-grid-renderer-qualification "$artifact_dir" "$mode" \
        >"$output_file" &
    runner_pid=$!
    peak_pss_kib=0
    peak_rss_kib=0
    samples=0
    while kill -0 "$runner_pid" 2>/dev/null; do
        pss_kib=$(awk '/^Pss:/ { print $2; exit }' "/proc/$runner_pid/smaps_rollup" 2>/dev/null || true)
        rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$runner_pid/status" 2>/dev/null || true)
        if [[ -n "$pss_kib" && "$pss_kib" -gt "$peak_pss_kib" ]]; then
            peak_pss_kib=$pss_kib
        fi
        if [[ -n "$rss_kib" && "$rss_kib" -gt "$peak_rss_kib" ]]; then
            peak_rss_kib=$rss_kib
        fi
        samples=$((samples + 1))
        sleep 0.01
    done
    if ! wait "$runner_pid"; then
        return 1
    fi
    printf 'native_grid_renderer_resource mode=%s peak_pss_kib=%d peak_rss_kib=%d samples=%d root_process_only=true\n' \
        "$mode" "$peak_pss_kib" "$peak_rss_kib" "$samples" \
        >"$scratch/resource-$mode"
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
        "mode=$mode frames=384 frames_per_scenario=128 scenarios=3 columns=160 rows=50" \
        >/dev/null
    for scenario in idle fullscreen rich; do
        printf '%s\n' "$output" | grep -E \
            "${scenario}_p50_cpu_ns=[1-9][0-9]* ${scenario}_p95_cpu_ns=[1-9][0-9]* ${scenario}_p99_cpu_ns=[1-9][0-9]*" \
            >/dev/null
    done
    printf '%s\n' "$output" | grep -E \
        'idle_hash=[1-9][0-9]* fullscreen_hash=[1-9][0-9]* rich_hash=[1-9][0-9]* pixel_diff=0' \
        >/dev/null
    printf '%s\n' "$output" | grep -E \
        'first_frame_owned_allocations=[1-9][0-9]* warm_frame_owned_allocations=0 resize_growth_allocations=[1-9][0-9]* resize_shrink_allocations=0 peak_owned_scratch_bytes=[1-9][0-9]* frame_buffer_allocations=[1-9][0-9]* glyph_scratch_allocations=[1-9][0-9]* glyph_cache_builds=[1-9][0-9]* artifacts=3 assertions=true' \
        >/dev/null
    resource=$(cat "$scratch/resource-$mode")
    printf '%s\n' "$resource"
    printf '%s\n' "$resource" | grep -E \
        "mode=$mode peak_pss_kib=[1-9][0-9]* peak_rss_kib=[1-9][0-9]* samples=[1-9][0-9]* root_process_only=true" \
        >/dev/null
    test "$(find "$scratch/artifacts-$mode" -maxdepth 1 -type f -name '*.png' | wc -l)" -eq 3
done

for artifact in idle fullscreen rich-style; do
    cmp -s \
        "$scratch/artifacts-Debug/$artifact.png" \
        "$scratch/artifacts-ReleaseSafe/$artifact.png"
done

debug_hashes=$(sed -n 's/.* idle_hash=\([0-9][0-9]*\) fullscreen_hash=\([0-9][0-9]*\) rich_hash=\([0-9][0-9]*\).*/\1 \2 \3/p' "$scratch/output-Debug")
release_hashes=$(sed -n 's/.* idle_hash=\([0-9][0-9]*\) fullscreen_hash=\([0-9][0-9]*\) rich_hash=\([0-9][0-9]*\).*/\1 \2 \3/p' "$scratch/output-ReleaseSafe")
test -n "$debug_hashes"
test "$debug_hashes" = "$release_hashes"

idle_sha256=$(sha256sum "$scratch/artifacts-Debug/idle.png" | awk '{print $1}')
fullscreen_sha256=$(sha256sum "$scratch/artifacts-Debug/fullscreen.png" | awk '{print $1}')
rich_sha256=$(sha256sum "$scratch/artifacts-Debug/rich-style.png" | awk '{print $1}')
printf 'native_grid_renderer_artifacts debug_release_identical=true idle_sha256=%s fullscreen_sha256=%s rich_sha256=%s scratch_clean=true\n' \
    "$idle_sha256" "$fullscreen_sha256" "$rich_sha256"
echo 'native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true'
