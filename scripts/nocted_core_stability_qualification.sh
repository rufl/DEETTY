#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-core-stability.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

cycles=${NOCTED_CORE_STABILITY_CYCLES:-128}
case "$cycles" in
    ''|*[!0-9]*)
        printf 'NOCTED_CORE_STABILITY_CYCLES must be an integer from 1 through 512\n' >&2
        exit 2
        ;;
esac
if ((cycles < 1 || cycles > 512)); then
    printf 'NOCTED_CORE_STABILITY_CYCLES must be an integer from 1 through 512\n' >&2
    exit 2
fi

project="$scratch/project"
mkdir -p "$project"
directory=0
while [ "$directory" -lt 8 ]; do
    directory_path=$(printf '%s/module_%02d' "$project" "$directory")
    mkdir -p "$directory_path"
    file=0
    while [ "$file" -lt 16 ]; do
        fixture_path=$(printf '%s/file_%03d.zig' "$directory_path" "$file")
        printf 'pub fn fixture_%02d_%03d() []const u8 {\n    return "stability_needle module_%02d file_%03d";\n}\n' \
            "$directory" "$file" "$directory" "$file" >"$fixture_path"
        file=$((file + 1))
    done
    directory=$((directory + 1))
done
printf 'fn initial() void {\n    const stability_needle = true;\n    _ = stability_needle;\n}\n' \
    >"$project/focus.zig"

for mode in Debug ReleaseSafe; do
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache"
    ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build nocted-stability-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache"

    output_file="$scratch/output-$mode"
    "$prefix/bin/nocted-core-stability" "$project" "$cycles" >"$output_file" &
    runner_pid=$!
    peak_pss_kib=0
    peak_rss_kib=0
    samples=0
    while kill -0 "$runner_pid" 2>/dev/null; do
        pss_kib=$(awk '/^Pss:/ { print $2; exit }' "/proc/$runner_pid/smaps_rollup" 2>/dev/null || true)
        rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$runner_pid/status" 2>/dev/null || true)
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
    printf '%s\n' "$output" | grep -F "mode=$mode cycles=$cycles" >/dev/null
    printf '%s\n' "$output" | grep -E \
        'project_entries=[1-9][0-9]* search_results=[1-9][0-9]* allocator_leak_free=true allocator_residual_bytes=0 checkpoint_peak_active_bytes=[1-9][0-9]*' \
        >/dev/null
    printf '%s\n' "$output" | grep -E \
        "ranking_queries=3 ranking_cycles=$cycles ranking_fingerprint=[1-9][0-9]* ranking_deterministic=true" \
        >/dev/null
    for metric in save load edit scan search quick_open grammar; do
        printf '%s\n' "$output" | grep -E \
            "${metric}_p50_ns=[0-9]+ ${metric}_p95_ns=[0-9]+ ${metric}_p99_ns=[0-9]+" \
            >/dev/null
    done
    printf 'nocted_core_stability_resource mode=%s peak_pss_kib=%d peak_rss_kib=%d samples=%d root_process_only=true\n' \
        "$mode" "$peak_pss_kib" "$peak_rss_kib" "$samples"
done

if ((cycles == 128)); then
    echo 'nocted_core_stability_matrix debug=true release_safe=true cycles=128 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_cycles=128 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true scratch_clean=true'
else
    printf 'nocted_core_stability_matrix debug=true release_safe=true cycles=%d fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_cycles=%d grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true scratch_clean=true\n' \
        "$cycles" "$cycles"
fi
