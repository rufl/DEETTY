#!/usr/bin/env bash
set -euo pipefail

./scripts/require_isolated_display.sh --dedicated
export LC_ALL=C

repo_root=$(cd "$(dirname "$0")/.." && pwd)
artifact_dir=${DEETTY_AUTH_AGENT_ARTIFACT_DIR:-"$repo_root/benchmarks/authenticated-agent-$(date +%F)"}
case "$artifact_dir" in
    /*) ;;
    *) artifact_dir="$repo_root/$artifact_dir" ;;
esac
scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-auth-agent.XXXXXX")
runner_pid=
cleanup() {
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
        "deettyAuthAgentActivate$$" >/dev/null 2>&1 || true
    if [[ -n "$runner_pid" ]] && kill -0 "$runner_pid" 2>/dev/null; then
        kill "$runner_pid" 2>/dev/null || true
        wait "$runner_pid" 2>/dev/null || true
    fi
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

launcher=${DEETTY_AGENT_QUALIFICATION_LAUNCHER:-pi}
case "$launcher" in
    pi|omp|zipi) ;;
    *) printf 'unsupported agent launcher: %s\n' "$launcher" >&2; exit 2 ;;
esac
command -v "$launcher" >/dev/null
command -v spectacle >/dev/null
command -v identify >/dev/null
command -v tesseract >/dev/null
command -v xdotool >/dev/null
command -v qdbus6 >/dev/null
mkdir -p "$artifact_dir"
find "$artifact_dir" -maxdepth 1 -type f \
    \( -name '*.png' -o -name '*.log' -o -name '*-response.txt' -o \
       -name 'summary.csv' -o -name 'SHA256SUMS' \) -delete
printf 'mode,backend,root_pss_kib,root_rss_kib,tree_pss_kib,tree_rss_kib,response_bytes,image_width,image_height\n' \
    >"$artifact_dir/summary.csv"

wait_for_response() {
    local response=$1
    local log=$2
    local pid=$3
    local attempt=0
    while ((attempt < 900)); do
        if [[ -s "$response" ]]; then
            grep -Fx 'DEETTY_AGENT_QUALIFICATION_OK' "$response" >/dev/null
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            cat "$log" >&2
            return 1
        fi
        sleep 0.2
        attempt=$((attempt + 1))
    done
    printf 'timed out waiting for agent qualification response launcher=%s pid=%s\n' \
        "$launcher" "$pid" >&2
    cat "$log" >&2
    return 1
}

activate_wayland_window() {
    local pid=$1
    local script="$scratch/activate-window.js"
    local plugin="deettyAuthAgentActivate$$"
    cat >"$script" <<EOF
for (const window of workspace.windowList()) {
    if (window.caption === 'DEETTY agent qualification') {
        break;
    }
}
EOF
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
        "$plugin" >/dev/null 2>&1 || true
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
        "$script" "$plugin" >/dev/null
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
    sleep 0.3
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
        "$plugin" >/dev/null
}

capture_window() {
    local backend=$1
    local pid=$2
    local image=$3
    if [[ "$backend" == x11 ]]; then
        local window=
        local attempt=0
        while ((attempt < 100)); do
            window=$(xdotool search --onlyvisible \
                --name '^DEETTY agent qualification$' \
                2>/dev/null | awk 'END { print }' || true)
            [[ -z "$window" ]] || break
            sleep 0.1
            attempt=$((attempt + 1))
        done
        [[ -n "$window" ]]
        timeout 5 xdotool windowactivate --sync "$window"
        sleep 0.1
    else
        activate_wayland_window "$pid"
    fi
    spectacle --background --nonotify --activewindow --output "$image"
    test -s "$image"
    local ocr
    ocr=$(tesseract "$image" stdout -l afr --psm 6 2>/dev/null)
    grep -F 'AGENT' <<<"$ocr" >/dev/null
    grep -F 'QUALIFICATION' <<<"$ocr" >/dev/null
}

for mode in Debug ReleaseSafe; do
    prefix="$scratch/$mode"
    ZIG_GLOBAL_CACHE_DIR="$scratch/global-cache" zig build deetty-smoke-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$scratch/cache-$mode"
    mode_name=$(tr '[:upper:]' '[:lower:]' <<<"$mode")
    for backend in wayland x11; do
        lane="$mode_name-$backend"
        response="$artifact_dir/$lane-response.txt"
        captured="$scratch/$lane-captured"
        log="$artifact_dir/$lane.log"
        image="$artifact_dir/$lane.png"
        rm -f "$captured"
        env GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
            GDK_BACKEND="$backend" \
            DEETTY_AGENT_QUALIFICATION_LAUNCHER="$launcher" \
            DEETTY_AUTH_AGENT_RESPONSE_PATH="$response" \
            DEETTY_AUTH_AGENT_CAPTURED_PATH="$captured" \
            "$prefix/bin/deetty-smoke" \
            --native-grid-authenticated-agent-qualification >"$log" 2>&1 &
        runner_pid=$!
        wait_for_response "$response" "$log" "$runner_pid"

        root_pss_kib=$(awk '/^Pss:/ { print $2; exit }' "/proc/$runner_pid/smaps_rollup")
        root_rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$runner_pid/status")
        tree_receipt=$("$repo_root/scripts/process_tree_memory.sh" "$runner_pid")
        tree_pss_kib=$(sed -n 's/.* pss_kib=\([0-9][0-9]*\).*/\1/p' <<<"$tree_receipt")
        tree_rss_kib=$(sed -n 's/.* rss_kib=\([0-9][0-9]*\).*/\1/p' <<<"$tree_receipt")
        capture_window "$backend" "$runner_pid" "$image"
        read -r image_width image_height < <(identify -format '%w %h\n' "$image")
        ((image_width >= 900))
        ((image_height >= 500))
        response_bytes=$(wc -c <"$response")
        printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$mode" "$backend" "$root_pss_kib" "$root_rss_kib" \
            "$tree_pss_kib" "$tree_rss_kib" "$response_bytes" \
            "$image_width" "$image_height" >>"$artifact_dir/summary.csv"
        touch "$captured"

        wait "$runner_pid"
        runner_pid=
        grep -F "native_grid_agent_qualification launcher=$launcher model_request=true ephemeral=true sandbox=read-only production_pty=true production_vt=true production_gtk=true production_cairo=true response_exact=true controlled_exit=true" "$log" >/dev/null
        cat "$log"
    done
done

(
    cd "$artifact_dir"
    checksum_files=(./*.log ./*.png ./*-response.txt summary.csv)
    [[ ! -f README.md ]] || checksum_files=(README.md "${checksum_files[@]}")
    sha256sum "${checksum_files[@]}" >SHA256SUMS
    sha256sum -c SHA256SUMS >/dev/null
)

echo "native_grid_agent_matrix launcher=$launcher model_requests=4 debug=true release_safe=true wayland=true x11=true production_pty=true production_vt=true production_gtk=true production_cairo=true response_exact=true compositor_pixels=true root_memory=true process_tree_memory=true controlled_exit=true ephemeral=true sandbox=read-only hid=false checksums=true artifact_dir=$artifact_dir scratch_clean=true"
