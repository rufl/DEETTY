#!/usr/bin/env bash
set -euo pipefail

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-resource-qualification.XXXXXX")
cleanup() {
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

for mode in Debug ReleaseSafe; do
    prefix="$scratch/$mode"
    cache="$scratch/cache-$mode"
    zig build smoke-binaries \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$cache" \
        --global-cache-dir .zig-cache/global
    output_file="$scratch/output-$mode"
    start_ns=$(date +%s%N)
    env GDK_BACKEND=x11 NO_AT_BRIDGE=1 \
        "$prefix/bin/noctty-smoke" --native-grid-layout-preset-smoke \
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
        receipt=$(./scripts/process_tree_memory.sh "$runner_pid" 2>/dev/null || true)
        tree_pss_kib=$(printf '%s\n' "$receipt" | sed -n 's/.*pss_kib=\([0-9][0-9]*\).*/\1/p')
        tree_rss_kib=$(printf '%s\n' "$receipt" | sed -n 's/.*rss_kib=\([0-9][0-9]*\).*/\1/p')
        if [ -n "$root_pss_kib" ] && [ "$root_pss_kib" -gt "$peak_root_pss_kib" ]; then
            peak_root_pss_kib=$root_pss_kib
        fi
        if [ -n "$root_rss_kib" ] && [ "$root_rss_kib" -gt "$peak_root_rss_kib" ]; then
            peak_root_rss_kib=$root_rss_kib
        fi
        if [ -n "$tree_pss_kib" ] && [ "$tree_pss_kib" -gt "$peak_tree_pss_kib" ]; then
            peak_tree_pss_kib=$tree_pss_kib
        fi
        if [ -n "$tree_rss_kib" ] && [ "$tree_rss_kib" -gt "$peak_tree_rss_kib" ]; then
            peak_tree_rss_kib=$tree_rss_kib
        fi
        samples=$((samples + 1))
        sleep 0.05
    done
    wait "$runner_pid"
    end_ns=$(date +%s%N)
    elapsed_ms=$(((end_ns - start_ns) / 1000000))
    grep -F 'churn_cycles=8 sessions_created=32 sessions_closed=32' "$output_file" >/dev/null
    grep -F 'session_storage_released=true remaining_focused=true exited=true' "$output_file" >/dev/null
    printf 'native_grid_resource_qualification mode=%s elapsed_ms=%d root_peak_pss_kib=%d root_peak_rss_kib=%d tree_peak_pss_kib=%d tree_peak_rss_kib=%d samples=%d\n' \
        "$mode" "$elapsed_ms" "$peak_root_pss_kib" "$peak_root_rss_kib" \
        "$peak_tree_pss_kib" "$peak_tree_rss_kib" "$samples"
done

echo 'native_grid_resource_qualification debug=true release_safe=true churn_cycles=8 sessions_created=32 sessions_closed=32 root_memory_separate=true process_tree_memory=true scratch_clean=true'
