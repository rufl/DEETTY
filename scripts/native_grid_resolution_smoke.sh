#!/usr/bin/env bash
set -euo pipefail

if [[ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ]]; then
    exec ./scripts/run_isolated_wayland.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

for command in identify kscreen-doctor qdbus6 spectacle; do
    command -v "$command" >/dev/null || {
        printf 'native_grid_resolution_smoke error=missing_tool tool=%s\n' "$command" >&2
        exit 2
    }
done

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/dintty-resolution-smoke.XXXXXX")
artifact_dir=${DINTTY_RESOLUTION_ARTIFACT_DIR:-}
runner_pid=
restore_output() {
    kscreen-doctor output.1.mode.1 >/dev/null 2>&1 || true
}
cleanup() {
    if [[ -n "$runner_pid" ]] && kill -0 "$runner_pid" 2>/dev/null; then
        kill "$runner_pid" 2>/dev/null || true
        wait "$runner_pid" 2>/dev/null || true
    fi
    restore_output
    if [[ -n "$artifact_dir" ]]; then
        for log in "$scratch"/*.log; do
            [[ -f "$log" ]] && cp "$log" "$artifact_dir/$(basename "$log")"
        done
    fi
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

if [[ -n "$artifact_dir" ]]; then
    case "$artifact_dir" in
        /*) ;;
        *) artifact_dir="$repo_root/$artifact_dir" ;;
    esac
    mkdir -p "$artifact_dir"
fi

wait_for_log() {
    local log=$1
    local text=$2
    local pid=$3
    local attempt=0
    while ((attempt < 200)); do
        if grep -F "$text" "$log" >/dev/null 2>&1; then
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            cat "$log" >&2
            return 1
        fi
        sleep 0.05
        attempt=$((attempt + 1))
    done
    printf 'native_grid_resolution_smoke error=window_timeout text=%s\n' "$text" >&2
    cat "$log" >&2
    return 1
}

wait_for_output_geometry() {
    local expected=$1
    local output=
    local geometry_line=
    local line=
    local attempt=0
    while ((attempt < 200)); do
        output=$(kscreen-doctor -o 2>/dev/null || true)
        geometry_line=
        while IFS= read -r line; do
            [[ "$line" == *Geometry:* ]] && geometry_line=$line
        done <<<"$output"
        if [[ "$geometry_line" == *"$expected"* ]]; then
            return 0
        fi
        sleep 0.05
        attempt=$((attempt + 1))
    done
    printf 'native_grid_resolution_smoke error=output_timeout expected=%s\n' "$expected" >&2
    printf '%s\n' "$output" >&2
    return 1
}

activate_window() {
    local title=$1
    local script="$scratch/activate-window.js"
    local plugin="dinttyResolutionActivate$$"
    cat >"$script" <<EOF
for (const window of workspace.windowList()) {
    if (window.caption === '$title') {
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
    sleep 0.15
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
        "$plugin" >/dev/null 2>&1 || true
}

dropdown_capture_extra_width=
dropdown_capture_extra_height=

capture_expected_geometry() {
    local mode=$1
    local phase=$2
    local title=$3
    local content_width=$4
    local content_height=$5
    local pid=$6
    local image="$scratch/${mode}-${phase}.png"
    local attempt=0
    local width=0
    local height=0
    local expected_width=$content_width
    local expected_height=$content_height
    while ((attempt < 80)); do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 1
        fi
        activate_window "$title"
        rm -f "$image"
        if spectacle --background --nonotify --activewindow \
            --output "$image" >/dev/null 2>&1 && [[ -s "$image" ]]; then
            read -r width height < <(identify -format '%w %h\n' "$image")
            if [[ "$mode" == dropdown && "$phase" == initial &&
                -z "$dropdown_capture_extra_width" ]]; then
                dropdown_capture_extra_width=$((width - content_width))
                dropdown_capture_extra_height=$((height - content_height))
                if ((dropdown_capture_extra_width < 0 ||
                    dropdown_capture_extra_width > 256 ||
                    dropdown_capture_extra_height < 0 ||
                    dropdown_capture_extra_height > 256)); then
                    dropdown_capture_extra_width=
                    dropdown_capture_extra_height=
                fi
            fi
            if [[ "$mode" == dropdown &&
                -n "$dropdown_capture_extra_width" ]]; then
                expected_width=$((content_width + dropdown_capture_extra_width))
                expected_height=$((content_height + dropdown_capture_extra_height))
            fi
            if [[ "$width" == "$expected_width" &&
                "$height" == "$expected_height" ]]; then
                if [[ -n "$artifact_dir" ]]; then
                    cp "$image" "$artifact_dir/${mode}-${phase}.png"
                fi
                printf 'native_grid_resolution_frame mode=%s phase=%s content_width=%s content_height=%s capture_width=%s capture_height=%s\n' \
                    "$mode" "$phase" "$content_width" "$content_height" \
                    "$width" "$height"
                return 0
            fi
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    printf 'native_grid_resolution_smoke error=window_geometry mode=%s phase=%s expected=%sx%s actual=%sx%s\n' \
        "$mode" "$phase" "$expected_width" "$expected_height" "$width" "$height" >&2
    return 1
}

run_case() {
    local mode=$1
    local flag=$2
    local title=$3
    local initial_width=$4
    local initial_height=$5
    local reduced_width=$6
    local reduced_height=$7
    local marker="$XDG_RUNTIME_DIR/dintty-resolution-${mode}-finished"
    local stdout_log="$scratch/${mode}.stdout.log"
    local stderr_log="$scratch/${mode}.stderr.log"
    rm -f "$marker"
    restore_output
    wait_for_output_geometry 1440x900

    env GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
        "$repo_root/zig-out/bin/dintty-smoke" "$flag" \
        >"$stdout_log" 2>"$stderr_log" &
    runner_pid=$!
    wait_for_log "$stderr_log" \
        "native_grid_resolution_window_ready mode=${mode}" "$runner_pid"
    capture_expected_geometry "$mode" initial "$title" \
        "$initial_width" "$initial_height" "$runner_pid"

    kscreen-doctor output.1.mode.1024x640@60 >/dev/null
    wait_for_output_geometry 1024x640
    capture_expected_geometry "$mode" reduced "$title" \
        "$reduced_width" "$reduced_height" "$runner_pid"

    restore_output
    wait_for_output_geometry 1440x900
    capture_expected_geometry "$mode" restored "$title" \
        "$initial_width" "$initial_height" "$runner_pid"

    touch "$marker"
    if ! wait "$runner_pid"; then
        runner_pid=
        cat "$stderr_log" "$stdout_log" >&2
        return 1
    fi
    runner_pid=
    if [[ -n "$artifact_dir" ]]; then
        cp "$stdout_log" "$artifact_dir/${mode}.stdout.log"
        cp "$stderr_log" "$artifact_dir/${mode}.stderr.log"
    fi
    cat "$stderr_log" "$stdout_log"
    if ! grep -F \
        "native_grid_resolution_smoke mode=${mode} live=true exited=true" \
        "$stdout_log" >/dev/null; then
        printf 'native_grid_resolution_smoke error=missing_receipt mode=%s\n' \
            "$mode" >&2
        return 1
    fi
}

cd "$repo_root"
ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build -j1 dintty-smoke-binary
kscreen-doctor output.1.addCustomMode.1024.640.60000.full >/dev/null
run_case dropdown --native-grid-resolution-dropdown-smoke \
    'DINTTY resolution dropdown qualification' 1382 495 983 352
run_case fullscreen --native-grid-resolution-fullscreen-smoke \
    'DINTTY resolution fullscreen qualification' 1440 900 1024 640
printf 'native_grid_resolution_smoke wayland=true live_switch=true dropdown_percent=true fullscreen_monitor=true restored=true isolated=true\n'
