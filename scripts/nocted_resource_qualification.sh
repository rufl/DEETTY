#!/usr/bin/env bash
set -euo pipefail

isolation_backend=${NOCTED_GDK_BACKEND:-x11}
if [[ ${DINTTY_DEDICATED_DISPLAY:-0} != 1 &&
      ${DINTTY_ISOLATED_DISPLAY:-} != "$isolation_backend" ]]; then
    case "$isolation_backend" in
        x11) exec ./scripts/run_isolated_x11.sh "$0" "$@" ;;
        wayland) exec ./scripts/run_isolated_wayland.sh "$0" "$@" ;;
        *) echo 'nocted_resource_qualification error=unsupported_backend' >&2; exit 2 ;;
    esac
fi
./scripts/require_isolated_display.sh

repo_root=$(cd "$(dirname "$0")/.." && pwd)
resource_parent=${NOCTED_RESOURCE_PARENT:-"$repo_root"}
case "$resource_parent" in
    /*) ;;
    *) resource_parent="$repo_root/$resource_parent" ;;
esac
scratch=$(mktemp -d "$resource_parent/.nocted-resource-qualification.XXXXXX")
cleanup() {
    if [[ -n "${scratch:-}" && -d "$scratch" ]]; then
        find "$scratch" -depth -delete 2>/dev/null || true
    fi
}
trap cleanup EXIT HUP INT TERM

backend=${NOCTED_GDK_BACKEND:-x11}
build_xdg_cache="$scratch/xdg-cache"
build_tmp="$scratch/tmp"
global_cache="$scratch/zig-global"
mkdir -p "$build_xdg_cache" "$build_tmp" "$global_cache"

for mode in Debug ReleaseSafe; do
    prefix="$scratch/$mode"
    cache="$scratch/cache-$mode"
    mkdir -p "$prefix" "$cache"
    XDG_CACHE_HOME="$build_xdg_cache" TMPDIR="$build_tmp" \
        ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build smoke-binaries \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$cache"
    output_file="$scratch/output-$mode"
    sample_file="$scratch/samples-$mode"
    sample_done="$scratch/samples-$mode.done"
    resource_pid=$$
    (
        peak_pss_kib=0
        peak_rss_kib=0
        samples=0
        while kill -0 "$resource_pid" 2>/dev/null && [[ ! -e "$sample_done" ]]; do
            receipt=$(./scripts/process_tree_memory.sh "$resource_pid" 2>/dev/null || true)
            pss_kib=$(printf '%s\n' "$receipt" | sed -n 's/.*pss_kib=\([0-9][0-9]*\).*/\1/p')
            rss_kib=$(printf '%s\n' "$receipt" | sed -n 's/.*rss_kib=\([0-9][0-9]*\).*/\1/p')
            if [[ -n "$pss_kib" && "$pss_kib" -gt "$peak_pss_kib" ]]; then
                peak_pss_kib=$pss_kib
            fi
            if [[ -n "$rss_kib" && "$rss_kib" -gt "$peak_rss_kib" ]]; then
                peak_rss_kib=$rss_kib
            fi
            samples=$((samples + 1))
            sleep 0.05
        done
        printf '%d %d %d\n' "$peak_pss_kib" "$peak_rss_kib" "$samples" >"$sample_file"
    ) &
    sampler_pid=$!
    start_ns=$(date +%s%N)
    if NOCTED_GDK_BACKEND="$backend" \
        ./scripts/nocted_native_smoke.sh "$prefix/bin/nocted-smoke" --qualification \
            >"$output_file"; then
        runner_status=0
    else
        runner_status=$?
    fi
    : >"$sample_done"
    wait "$sampler_pid"
    read -r peak_pss_kib peak_rss_kib samples <"$sample_file"
    if [[ "$runner_status" -ne 0 ]]; then
        exit "$runner_status"
    fi
    end_ns=$(date +%s%N)
    elapsed_ms=$(((end_ns - start_ns) / 1000000))
    grep -F 'nocted_resource_smoke pass=1 cycles=8 queue_cap=64' "$output_file" >/dev/null
    grep -F 'worker_drained=1 project_drained=1' "$output_file" >/dev/null
    grep -F 'nocted_search_load_qualification pass=1 cycles=8' "$output_file" >/dev/null
    search_receipt=$(grep -F 'nocted_search_load_qualification pass=1 cycles=8' "$output_file" | tail -n 1)
    monitor_receipt=$(grep -F 'nocted_project_monitor_qualification pass=1' "$output_file" | tail -n 1)
    lifecycle_receipt=$(grep -F 'nocted_project_real_project_qualification pass=1' "$output_file" | tail -n 1)
    printf 'nocted_search_load_resource mode=%s backend=%s %s\n' \
        "$mode" "$backend" "${search_receipt#nocted_search_load_qualification }"
    printf 'nocted_project_monitor_resource mode=%s backend=%s %s\n' \
        "$mode" "$backend" "${monitor_receipt#nocted_project_monitor_qualification }"
    printf 'nocted_project_lifecycle_resource mode=%s backend=%s %s\n' \
        "$mode" "$backend" "${lifecycle_receipt#nocted_project_real_project_qualification }"
    printf 'nocted_resource_qualification mode=%s backend=%s elapsed_ms=%d peak_pss_kib=%d peak_rss_kib=%d samples=%d\n' \
        "$mode" "$backend" "$elapsed_ms" "$peak_pss_kib" "$peak_rss_kib" "$samples"
done

echo 'nocted_resource_qualification debug=true release_safe=true cycles=8 cancellation=true duplicate_open=true atomic_save_close=true queue_bounded=true scratch_clean=true'
echo 'nocted_search_load_resource_matrix debug=true release_safe=true cycles=8 first_result_latency=true completion_latency=true cancellation_latency=true ui_draw_latency=true open_under_search=true save_under_refresh=true deterministic_ranking=true process_memory=true worker_drained=true scratch_clean=true'
echo "nocted_resource_backend backend=$backend debug=true release_safe=true native_search_load=true native_project_lifecycle=true process_tree_memory=true scratch_clean=true"
