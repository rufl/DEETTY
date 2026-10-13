#!/usr/bin/env bash
set -euo pipefail

./scripts/require_isolated_display.sh --dedicated

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

rounds=${NOCTED_ENDURANCE_ROUNDS:-8}
case "$rounds" in
    ''|*[!0-9]*) echo "NOCTED_ENDURANCE_ROUNDS must be an integer" >&2; exit 2 ;;
esac
if ((rounds < 2 || rounds > 32)); then
    echo "NOCTED_ENDURANCE_ROUNDS must be between 2 and 32" >&2
    exit 2
fi

output_dir=${NOCTED_ENDURANCE_OUTPUT_DIR:-"$repo_root/benchmarks/nocted-native-endurance-$(date +%F)"}
if [[ -d "$output_dir" && -n "$(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "output directory is not empty: $output_dir" >&2
    exit 2
fi
mkdir -p "$output_dir"

scratch_parent=${NOCTED_ENDURANCE_PARENT:-/dev/shm}
if [[ ! -d "$scratch_parent" || ! -w "$scratch_parent" ]]; then
    scratch_parent=$repo_root
fi
scratch=$(mktemp -d "$scratch_parent/.nocted-native-endurance.XXXXXX")
sampler_pid=
cleanup() {
    if [[ -n "$sampler_pid" ]]; then
        kill "$sampler_pid" 2>/dev/null || true
        wait "$sampler_pid" 2>/dev/null || true
    fi
    if [[ -n "${scratch:-}" && -d "$scratch" ]]; then
        find "$scratch" -depth -delete 2>/dev/null || true
    fi
}
trap cleanup EXIT HUP INT TERM

build_cache="$scratch/cache"
global_cache="$scratch/global"
build_tmp="$scratch/tmp"
xdg_cache="$scratch/xdg-cache"
mkdir -p "$build_cache" "$global_cache" "$build_tmp" "$xdg_cache"

for mode in Debug ReleaseSafe; do
    prefix="$scratch/$mode"
    mkdir -p "$prefix"
    XDG_CACHE_HOME="$xdg_cache" TMPDIR="$build_tmp" \
        ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build smoke-binaries \
            -Doptimize="$mode" \
            --prefix "$prefix" \
            --cache-dir "$build_cache-$mode"
done

printf '%s\n' \
    'backend,mode,rounds,cycles,ranking_evaluations,elapsed_ms,peak_tree_pss_kib,peak_tree_rss_kib,memory_samples,screenshots' \
    >"$output_dir/summary.csv"

matrix_started_ns=$(date +%s%N)
total_cycles=0
for backend in wayland x11; do
    if [[ "$backend" == wayland && -z "${WAYLAND_DISPLAY:-}" ]]; then
        echo 'WAYLAND_DISPLAY is required' >&2
        exit 2
    fi
    if [[ "$backend" == x11 && -z "${DISPLAY:-}" ]]; then
        echo 'DISPLAY is required' >&2
        exit 2
    fi
    for mode in Debug ReleaseSafe; do
        lane=$(printf '%s-%s' "${mode,,}" "$backend")
        lane_log="$output_dir/$lane.log"
        sample_file="$scratch/$lane.memory"
        sample_done="$scratch/$lane.done"
        : >"$lane_log"
        resource_pid=$$
        (
            peak_pss_kib=0
            peak_rss_kib=0
            samples=0
            while kill -0 "$resource_pid" 2>/dev/null && [[ ! -e "$sample_done" ]]; do
                receipt=$(./scripts/process_tree_memory.sh "$resource_pid" 2>/dev/null || true)
                pss_kib=$(sed -n 's/.*pss_kib=\([0-9][0-9]*\).*/\1/p' <<<"$receipt")
                rss_kib=$(sed -n 's/.*rss_kib=\([0-9][0-9]*\).*/\1/p' <<<"$receipt")
                if [[ -n "$pss_kib" && "$pss_kib" -gt "$peak_pss_kib" ]]; then
                    peak_pss_kib=$pss_kib
                fi
                if [[ -n "$rss_kib" && "$rss_kib" -gt "$peak_rss_kib" ]]; then
                    peak_rss_kib=$rss_kib
                fi
                samples=$((samples + 1))
                sleep 0.1
            done
            printf '%d %d %d\n' "$peak_pss_kib" "$peak_rss_kib" "$samples" >"$sample_file"
        ) &
        sampler_pid=$!
        lane_started_ns=$(date +%s%N)
        for ((round = 1; round <= rounds; round++)); do
            round_log="$scratch/$lane-round-$round.log"
            capture_args=()
            if ((round == 1 || round == rounds)); then
                capture_args=(NOCTED_CAPTURE_OUTPUT="$output_dir/$lane-round-$round.png")
            fi
            env \
                XDG_CACHE_HOME="$xdg_cache" \
                TMPDIR="$build_tmp" \
                NOCTED_GDK_BACKEND="$backend" \
                "${capture_args[@]}" \
                ./scripts/nocted_native_smoke.sh \
                    "$scratch/$mode/bin/nocted-smoke" --qualification \
                    >"$round_log"
            grep -F 'nocted_search_load_qualification pass=1 cycles=8' "$round_log" >/dev/null
            grep -F 'ranking_queries=3 ranking_cycles=8 ranking_deterministic=true' "$round_log" >/dev/null
            grep -F 'nocted_project_monitor_qualification pass=1 burst_cycles=8' "$round_log" >/dev/null
            grep -F 'nocted_project_real_project_qualification pass=1 cycles=8' "$round_log" >/dev/null
            grep -F 'worker_drained=1 project_drained=1' "$round_log" >/dev/null
            grep -F 'nocted_project_lifecycle_teardown pass=1' "$round_log" >/dev/null
            grep -F 'nocted_resource_smoke pass=1 cycles=8 queue_cap=64' "$round_log" >/dev/null
            printf 'round=%d\n' "$round" >>"$lane_log"
            cat "$round_log" >>"$lane_log"
        done
        : >"$sample_done"
        wait "$sampler_pid"
        sampler_pid=
        read -r peak_pss_kib peak_rss_kib samples <"$sample_file"
        lane_elapsed_ms=$((( $(date +%s%N) - lane_started_ns) / 1000000))
        lane_cycles=$((rounds * 8))
        ranking_evaluations=$((lane_cycles * 3))
        total_cycles=$((total_cycles + lane_cycles))
        screenshots=$(find "$output_dir" -maxdepth 1 -type f -name "$lane-round-*.png" | wc -l)
        [[ "$screenshots" -eq 2 ]]
        printf '%s,%s,%d,%d,%d,%d,%d,%d,%d,%d\n' \
            "$backend" "$mode" "$rounds" "$lane_cycles" "$ranking_evaluations" \
            "$lane_elapsed_ms" "$peak_pss_kib" "$peak_rss_kib" "$samples" "$screenshots" \
            >>"$output_dir/summary.csv"
        printf 'nocted_native_endurance_lane backend=%s mode=%s rounds=%d cycles=%d ranking_evaluations=%d elapsed_ms=%d peak_tree_pss_kib=%d peak_tree_rss_kib=%d samples=%d screenshots=%d passed=true\n' \
            "$backend" "$mode" "$rounds" "$lane_cycles" "$ranking_evaluations" \
            "$lane_elapsed_ms" "$peak_pss_kib" "$peak_rss_kib" "$samples" "$screenshots"
    done
done

matrix_elapsed_seconds=$((( $(date +%s%N) - matrix_started_ns) / 1000000000))
printf 'date=%s\nrevision=%s\ndirty=%s\nrounds_per_lane=%d\ntotal_cycles_per_phase=%d\ntotal_phase_cycles=%d\nelapsed_seconds=%d\nwayland_display=%s\ndisplay=%s\n' \
    "$(date +%F)" "$(git rev-parse --short HEAD)" \
    "$(if [[ -n "$(git status --short)" ]]; then echo true; else echo false; fi)" \
    "$rounds" "$total_cycles" "$((total_cycles * 4))" "$matrix_elapsed_seconds" \
    "${WAYLAND_DISPLAY:-}" "${DISPLAY:-}" >"$output_dir/metadata.txt"

(
    cd "$output_dir"
    : >SHA256SUMS
    while IFS= read -r path; do
        sha256sum "$path" >>SHA256SUMS
    done < <(find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%P\n' | sort)
)

scratch_path=$scratch
find "$scratch_path" -depth -delete
scratch=
[[ ! -e "$scratch_path" ]]
echo "nocted_native_endurance_matrix wayland=true x11=true debug=true release_safe=true rounds_per_lane=$rounds cycles_per_phase_per_lane=$((rounds * 8)) total_cycles_per_phase=$total_cycles total_phase_cycles=$((total_cycles * 4)) ranking_evaluations=$((total_cycles * 3)) search_load=true deterministic_ranking=true gtk_batch_bounded=true project_lifecycle=true monitor_bursts=true overflow_recovery=true worker_drained=true process_tree_memory=true screenshots=true warning_fatal=true duration_recorded=true scratch_clean=true"
