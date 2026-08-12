#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

repo_root=$(cd "$(dirname "$0")/.." && pwd)
mode=${1:---smoke}
case "$mode" in
    --smoke)
        cycles=${NOCTTY_STABILITY_CYCLES:-2}
        phase_seconds=${NOCTTY_STABILITY_PHASE_SECONDS:-2}
        authenticated=false
        modes=(Debug ReleaseSafe)
        artifact_dir=${NOCTTY_STABILITY_ARTIFACT_DIR:-"$repo_root/benchmarks/native-grid-stability-shakedown-$(date +%F)"}
        ;;
    --run)
        cycles=${NOCTTY_STABILITY_CYCLES:-24}
        phase_seconds=${NOCTTY_STABILITY_PHASE_SECONDS:-1800}
        authenticated=true
        modes=(ReleaseSafe)
        artifact_dir=${NOCTTY_STABILITY_ARTIFACT_DIR:-"$repo_root/benchmarks/native-grid-stability-$(date +%F)"}
        ;;
    *)
        echo "usage: $0 [--smoke|--run]" >&2
        exit 2
        ;;
esac
case "$artifact_dir" in
    /*) ;;
    *) artifact_dir="$repo_root/$artifact_dir" ;;
esac
[[ "$cycles" =~ ^[1-9][0-9]*$ ]] && ((cycles <= 96))
[[ "$phase_seconds" =~ ^[1-9][0-9]*$ ]] && ((phase_seconds <= 3600))

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-stability-qualification.XXXXXX")
runner_pid=
plugin="nocttyStabilityActivate$$"
cleanup() {
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
        "$plugin" >/dev/null 2>&1 || true
    if [[ -n "$runner_pid" ]] && kill -0 "$runner_pid" 2>/dev/null; then
        kill "$runner_pid" 2>/dev/null || true
        wait "$runner_pid" 2>/dev/null || true
    fi
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

for tool in identify qdbus6 spectacle tesseract xdotool; do
    command -v "$tool" >/dev/null
done
if [[ "$authenticated" == true ]]; then
    command -v codex >/dev/null
    codex login status 2>&1 | grep -F 'Logged in using ChatGPT' >/dev/null
fi

mkdir -p "$artifact_dir"
find "$artifact_dir" -maxdepth 1 -type f \
    \( -name '*.png' -o -name '*.log' -o -name '*-response.txt' -o \
       -name 'summary.csv' -o -name 'SHA256SUMS' \) -delete
printf 'mode,backend,cycle,phase,elapsed_seconds,root_pss_kib,root_rss_kib,tree_pss_kib,tree_rss_kib,cpu_ticks,voluntary_switches,nonvoluntary_switches\n' \
    >"$artifact_dir/summary.csv"

wait_for_phase() {
    local log=$1 phase=$2 cycle=$3 pid=$4 timeout_seconds=$5
    local deadline=$((SECONDS + timeout_seconds))
    while ((SECONDS < deadline)); do
        if grep -F "native_grid_stability_phase phase=$phase cycle=$cycle " \
            "$log" >/dev/null 2>&1; then
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            cat "$log" >&2
            return 1
        fi
        sleep 0.2
    done
    printf 'timed out waiting for phase=%s cycle=%s pid=%s\n' \
        "$phase" "$cycle" "$pid" >&2
    cat "$log" >&2
    return 1
}

wait_for_response() {
    local response=$1 log=$2 pid=$3
    local deadline=$((SECONDS + 600))
    while ((SECONDS < deadline)); do
        if [[ -s "$response" ]]; then
            grep -Fx 'NOCTTY_STABILITY_CODEX_OK' "$response" >/dev/null
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            cat "$log" >&2
            return 1
        fi
        sleep 0.2
    done
    printf 'timed out waiting for authenticated Codex response pid=%s\n' "$pid" >&2
    cat "$log" >&2
    return 1
}

activate_wayland_window() {
    local script="$scratch/activate-window.js"
    cat >"$script" <<'EOF'
for (const window of workspace.windowList()) {
    if (window.caption === 'NOCTTY stability qualification') {
        window.minimized = false;
        workspace.activeWindow = window;
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
    local backend=$1 image=$2
    if [[ "$backend" == x11 ]]; then
        local window= attempt=0
        while ((attempt < 100)); do
            window=$(xdotool search --onlyvisible \
                --name '^NOCTTY stability qualification$' 2>/dev/null |
                tail -n 1 || true)
            [[ -z "$window" ]] || break
            sleep 0.1
            attempt=$((attempt + 1))
        done
        [[ -n "$window" ]]
        timeout 5 xdotool windowactivate --sync "$window"
        sleep 0.1
    else
        activate_wayland_window
    fi
    spectacle --background --nonotify --activewindow --output "$image"
    test -s "$image"
    local width height ocr
    read -r width height < <(identify -format '%w %h\n' "$image")
    ((width >= 900))
    ((height >= 500))
    ocr=$(tesseract "$image" stdout -l afr --psm 6 2>/dev/null)
    grep -F 'NOCTTY' <<<"$ocr" >/dev/null
    grep -i -F 'stability' <<<"$ocr" >/dev/null
}

sample_phase() {
    local build_mode=$1 backend=$2 cycle=$3 phase=$4 pid=$5 started=$6
    local root_pss_kib root_rss_kib tree_receipt tree_pss_kib tree_rss_kib
    local cpu_ticks voluntary_switches nonvoluntary_switches elapsed_seconds
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
    elapsed_seconds=$(( $(date +%s) - started ))
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$build_mode" "$backend" "$cycle" "$phase" "$elapsed_seconds" \
        "$root_pss_kib" "$root_rss_kib" "$tree_pss_kib" "$tree_rss_kib" \
        "$cpu_ticks" "$voluntary_switches" "$nonvoluntary_switches" \
        >>"$artifact_dir/summary.csv"
}

backends=(wayland x11)
phase_timeout=$((phase_seconds + 180))
root_growth_kib_max=${NOCTTY_STABILITY_ROOT_GROWTH_KIB_MAX:-65536}
for build_mode in "${modes[@]}"; do
    prefix="$scratch/$build_mode"
    zig build noctty-smoke-binary \
        -Doptimize="$build_mode" \
        --prefix "$prefix" \
        --cache-dir "$scratch/cache-$build_mode" \
        --global-cache-dir "$scratch/global-cache"
    mode_name=$(tr '[:upper:]' '[:lower:]' <<<"$build_mode")
    for backend in "${backends[@]}"; do
        lane="$mode_name-$backend"
        log="$artifact_dir/$lane.log"
        response="$artifact_dir/$lane-response.txt"
        ready="$scratch/$lane-ready"
        rm -f "$ready"
        command="stty -echo; printf '\033]2;NOCTTY stability qualification\007'; printf '\033[2J\033[HNOCTTY stability qualification\r\nPTY · VT · GTK · Cairo · Plasma\r\n'; touch \"\$NOCTTY_STABILITY_READY_PATH\"; (i=0; while :; do i=\$((i + 1)); printf '\033[4;1HNOCTTY stability heartbeat %08d        ' \"\$i\"; sleep \"\${NOCTTY_STABILITY_HEARTBEAT_SECONDS:-1}\"; done) & worker=\$!; cat >/dev/null; kill \"\$worker\" 2>/dev/null || true; wait \"\$worker\" 2>/dev/null || true; exit 0"
        if [[ "$authenticated" == true ]]; then
            command="stty -echo; printf '\033]2;NOCTTY stability qualification\007'; printf '\033[2J\033[HNOCTTY stability qualification\r\nStarting authenticated Codex check...\r\n'; codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never -C /tmp -o \"\$NOCTTY_STABILITY_RESPONSE_PATH\" 'Do not run commands or inspect files. Reply with exactly NOCTTY_STABILITY_CODEX_OK.' </dev/null; status=\$?; [ \"\$status\" -eq 0 ] || exit \"\$status\"; printf '\033[2;1HAuthenticated Codex check passed.          '; touch \"\$NOCTTY_STABILITY_READY_PATH\"; (i=0; while :; do i=\$((i + 1)); printf '\033[4;1HNOCTTY stability heartbeat %08d        ' \"\$i\"; sleep \"\${NOCTTY_STABILITY_HEARTBEAT_SECONDS:-10}\"; done) & worker=\$!; cat >/dev/null; kill \"\$worker\" 2>/dev/null || true; wait \"\$worker\" 2>/dev/null || true; exit 0"
        fi
        ((${#command} <= 1024))
        started=$(date +%s)
        env GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
            GDK_BACKEND="$backend" \
            NOCTTY_STABILITY_CYCLES="$cycles" \
            NOCTTY_STABILITY_PHASE_SECONDS="$phase_seconds" \
            NOCTTY_STABILITY_RESPONSE_PATH="$response" \
            NOCTTY_STABILITY_READY_PATH="$ready" \
            NOCTTY_STABILITY_COMMAND="$command" \
            "$prefix/bin/noctty-smoke" \
            --native-grid-stability-qualification >"$log" 2>&1 &
        runner_pid=$!
        wait_for_phase "$log" visible_ready 0 "$runner_pid" 60
        if [[ "$authenticated" == true ]]; then
            wait_for_response "$response" "$log" "$runner_pid"
        fi
        sample_phase "$build_mode" "$backend" 0 visible "$runner_pid" "$started"
        capture_window "$backend" "$artifact_dir/$lane-initial.png"
        for ((cycle = 1; cycle <= cycles; cycle++)); do
            wait_for_phase "$log" hidden_ready "$cycle" "$runner_pid" "$phase_timeout"
            sample_phase "$build_mode" "$backend" "$cycle" hidden "$runner_pid" "$started"
            wait_for_phase "$log" visible_ready "$cycle" "$runner_pid" "$phase_timeout"
            sample_phase "$build_mode" "$backend" "$cycle" visible "$runner_pid" "$started"
        done
        capture_window "$backend" "$artifact_dir/$lane-final.png"
        wait "$runner_pid"
        runner_pid=
        grep -E "^native_grid_stability_qualification backend=$backend cycles=$cycles phase_seconds=$phase_seconds duration_seconds=[0-9]+ visible_draws=[1-9][0-9]* hidden_draws=0 visible_presents=[1-9][0-9]* hidden_presents=[1-9][0-9]* visible_ticks=0 hidden_ticks=0 visible_cursor_blinks=[1-9][0-9]* hidden_cursor_blinks=[1-9][0-9]* visible_maintenance=[1-9][0-9]* hidden_maintenance=[1-9][0-9]* mapped_visible=true unmapped_hidden=true production_pty=true production_vt=true production_gtk=true production_cairo=true workload_output=true hid=false passed=true$" "$log" >/dev/null
        first_pss=$(awk -F, -v mode="$build_mode" -v backend="$backend" '$1 == mode && $2 == backend && $3 == 0 && $4 == "visible" { print $6; exit }' "$artifact_dir/summary.csv")
        final_pss=$(awk -F, -v mode="$build_mode" -v backend="$backend" -v cycle="$cycles" '$1 == mode && $2 == backend && $3 == cycle && $4 == "visible" { print $6; exit }' "$artifact_dir/summary.csv")
        ((final_pss <= first_pss + root_growth_kib_max))
        cat "$log"
    done
done

(
    cd "$artifact_dir"
    checksum_files=(./*.log ./*.png summary.csv)
    if compgen -G './*-response.txt' >/dev/null; then
        checksum_files+=(./*-response.txt)
    fi
    [[ ! -f README.md ]] || checksum_files=(README.md "${checksum_files[@]}")
    sha256sum "${checksum_files[@]}" >SHA256SUMS
    sha256sum -c SHA256SUMS >/dev/null
)

expected_lane_seconds=$((cycles * phase_seconds * 2))
multi_day=false
if [[ "$authenticated" == true && "$expected_lane_seconds" -ge 86400 ]]; then
    multi_day=true
fi
echo "native_grid_stability_matrix smoke=$([[ "$mode" == --smoke ]] && echo true || echo false) release_safe=true debug=$([[ "$mode" == --smoke ]] && echo true || echo false) wayland=true x11=true cycles_per_lane=$cycles phase_seconds=$phase_seconds expected_lane_seconds=$expected_lane_seconds authenticated_codex=$authenticated hidden_visible=true production_pty=true production_vt=true production_gtk=true production_cairo=true mapped_memory=true process_tree_memory=true scheduler_receipts=true compositor_pixels=true root_growth_guard_kib=$root_growth_kib_max controlled_exit=true multi_day=$multi_day hid=false checksums=true artifact_dir=$artifact_dir scratch_clean=true"
