#!/usr/bin/env bash
set -euo pipefail

./scripts/require_isolated_display.sh --dedicated
export LC_ALL=C

repo_root=$(cd "$(dirname "$0")/.." && pwd)
artifact_dir=${DINTTY_FULL_STACK_ARTIFACT_DIR:-"$repo_root/benchmarks/native-grid-full-stack-$(date +%F)"}
case "$artifact_dir" in
    /*) ;;
    *) artifact_dir="$repo_root/$artifact_dir" ;;
esac
scratch=$(mktemp -d "${TMPDIR:-/tmp}/dintty-full-stack-qualification.XXXXXX")
runner_pid=
cleanup() {
    if [[ -n "$runner_pid" ]] && kill -0 "$runner_pid" 2>/dev/null; then
        kill "$runner_pid" 2>/dev/null || true
        wait "$runner_pid" 2>/dev/null || true
    fi
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

command -v spectacle >/dev/null
command -v identify >/dev/null
command -v tesseract >/dev/null
command -v xdotool >/dev/null
mkdir -p "$artifact_dir"
find "$artifact_dir" -maxdepth 1 -type f \
    \( -name '*.png' -o -name '*.log' -o -name 'summary.csv' -o -name 'SHA256SUMS' \) \
    -delete
printf 'mode,backend,phase,root_pss_kib,root_rss_kib,tree_pss_kib,tree_rss_kib,cpu_ticks,voluntary_switches,nonvoluntary_switches,image_width,image_height\n' \
    >"$artifact_dir/summary.csv"

wait_for_phase() {
    local log=$1
    local phase=$2
    local pid=$3
    local attempt=0
    while ((attempt < 120)); do
        if grep -F "native_grid_full_stack_phase phase=$phase " "$log" >/dev/null 2>&1; then
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            cat "$log" >&2
            return 1
        fi
        sleep 0.05
        attempt=$((attempt + 1))
    done
    printf 'timed out waiting for phase=%s pid=%s\n' "$phase" "$pid" >&2
    cat "$log" >&2
    return 1
}

capture_dintty_window() {
    local backend=$1
    local image=$2
    if [[ "$backend" == x11 ]]; then
        local window
        window=$(xdotool search --sync --onlyvisible \
            --name '^DINTTY full-stack qualification$' | tail -n 1)
        xdotool windowactivate --sync "$window"
        sleep 0.1
    fi
    spectacle --background --nonotify --activewindow --output "$image"
    test -s "$image"
    tesseract "$image" stdout -l afr --psm 6 2>/dev/null |
        grep -F 'DINTTY mapped' >/dev/null
}

sample_phase() {
    local mode=$1
    local backend=$2
    local phase=$3
    local pid=$4
    local image=$5
    local root_pss_kib root_rss_kib tree_receipt tree_pss_kib tree_rss_kib
    local cpu_ticks voluntary_switches nonvoluntary_switches image_width image_height
    root_pss_kib=$(awk '/^Pss:/ { print $2; exit }' "/proc/$pid/smaps_rollup")
    root_rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$pid/status")
    tree_receipt=$("$repo_root/scripts/process_tree_memory.sh" "$pid")
    tree_pss_kib=$(sed -n 's/.* pss_kib=\([0-9][0-9]*\).*/\1/p' <<<"$tree_receipt")
    tree_rss_kib=$(sed -n 's/.* rss_kib=\([0-9][0-9]*\).*/\1/p' <<<"$tree_receipt")
    cpu_ticks=$(awk '{ print $14 + $15 }' "/proc/$pid/stat")
    read -r voluntary_switches nonvoluntary_switches < <(
        awk '
            /^voluntary_ctxt_switches:/ { voluntary = $2 }
            /^nonvoluntary_ctxt_switches:/ { nonvoluntary = $2 }
            END { print voluntary + 0, nonvoluntary + 0 }
        ' "/proc/$pid/status"
    )
    capture_dintty_window "$backend" "$image"
    read -r image_width image_height < <(identify -format '%w %h\n' "$image")
    ((image_width >= 900))
    ((image_height >= 500))
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$mode" "$backend" "$phase" "$root_pss_kib" "$root_rss_kib" \
        "$tree_pss_kib" "$tree_rss_kib" "$cpu_ticks" \
        "$voluntary_switches" "$nonvoluntary_switches" \
        "$image_width" "$image_height" >>"$artifact_dir/summary.csv"
}

for mode in Debug ReleaseSafe; do
    prefix="$scratch/$mode"
    ZIG_GLOBAL_CACHE_DIR="$scratch/global-cache" zig build dintty-smoke-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$scratch/cache-$mode"
    mode_name=$(tr '[:upper:]' '[:lower:]' <<<"$mode")
    for backend in wayland x11; do
        log="$artifact_dir/$mode_name-$backend.log"
        env GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
            GDK_BACKEND="$backend" "$prefix/bin/dintty-smoke" \
            --native-grid-full-stack-qualification >"$log" 2>&1 &
        runner_pid=$!
        wait_for_phase "$log" idle_ready "$runner_pid"
        sample_phase "$mode" "$backend" idle "$runner_pid" \
            "$artifact_dir/$mode_name-$backend-idle.png"
        wait_for_phase "$log" fullscreen_ready "$runner_pid"
        sample_phase "$mode" "$backend" fullscreen "$runner_pid" \
            "$artifact_dir/$mode_name-$backend-fullscreen.png"
        wait "$runner_pid"
        runner_pid=
        grep -E "^native_grid_full_stack_qualification backend=$backend idle_draws=[1-9][0-9]* idle_output_frames=[0-9]+ idle_ticks=0 idle_cursor_blinks=[1-8] idle_maintenance=[1-4] fullscreen_draws=[1-9][0-9]* fullscreen_output_frames=[1-9][0-9]* fullscreen_ticks=0 fullscreen_cursor_blinks=[1-8] fullscreen_maintenance=[1-4] mapped_surface=true fullscreen=true production_pty=true production_vt=true production_gtk=true production_cairo=true external_memory=true external_compositor_pixels=true hid=false passed=true$" "$log" >/dev/null
        idle_width=$(awk -F, -v mode="$mode" -v backend="$backend" '$1 == mode && $2 == backend && $3 == "idle" { print $11 }' "$artifact_dir/summary.csv")
        idle_height=$(awk -F, -v mode="$mode" -v backend="$backend" '$1 == mode && $2 == backend && $3 == "idle" { print $12 }' "$artifact_dir/summary.csv")
        full_width=$(awk -F, -v mode="$mode" -v backend="$backend" '$1 == mode && $2 == backend && $3 == "fullscreen" { print $11 }' "$artifact_dir/summary.csv")
        full_height=$(awk -F, -v mode="$mode" -v backend="$backend" '$1 == mode && $2 == backend && $3 == "fullscreen" { print $12 }' "$artifact_dir/summary.csv")
        ((full_width >= idle_width))
        ((full_height >= idle_height))
        cat "$log"
    done
done

(
    cd "$artifact_dir"
    checksum_files=(./*.log ./*.png summary.csv)
    if [[ -f README.md ]]; then
        checksum_files=(README.md "${checksum_files[@]}")
    fi
    sha256sum "${checksum_files[@]}" >SHA256SUMS
    sha256sum -c SHA256SUMS >/dev/null
)

echo "native_grid_full_stack_matrix debug=true release_safe=true wayland=true x11=true idle=true fullscreen=true production_pty=true production_vt=true production_gtk=true production_cairo=true mapped_memory=true process_tree_memory=true scheduler_receipts=true compositor_pixels=true active_window_capture=true hid=false checksums=true artifact_dir=$artifact_dir scratch_clean=true"
