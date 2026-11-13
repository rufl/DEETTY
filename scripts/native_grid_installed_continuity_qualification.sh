#!/usr/bin/env bash
set -euo pipefail

./scripts/require_isolated_display.sh --dedicated
export LC_ALL=C
export PATH="$PATH:$HOME/.local/bin"

repo_root=$(cd "$(dirname "$0")/.." && pwd)
artifact_dir=${DEETTY_CONTINUITY_ARTIFACT_DIR:-"$repo_root/benchmarks/installed-continuity-$(date +%F)"}
case "$artifact_dir" in
    /*) ;;
    *) artifact_dir="$repo_root/$artifact_dir" ;;
esac
scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-installed-continuity.XXXXXX")
runner_pid=
current_kind=
current_session=
cleanup_session() {
    [[ -z "$current_session" ]] && return 0
    if [[ "$current_kind" == tmux ]]; then
        tmux kill-session -t "$current_session" >/dev/null 2>&1 || true
    elif [[ "$current_kind" == zellij ]]; then
        zellij delete-session --force "$current_session" >/dev/null 2>&1 || true
    fi
}
cleanup() {
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
        "deettyContinuityActivate$$" >/dev/null 2>&1 || true
    if [[ -n "$runner_pid" ]] && kill -0 "$runner_pid" 2>/dev/null; then
        kill "$runner_pid" 2>/dev/null || true
        wait "$runner_pid" 2>/dev/null || true
    fi
    cleanup_session
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

command -v tmux >/dev/null
command -v zellij >/dev/null
command -v spectacle >/dev/null
command -v identify >/dev/null
command -v tesseract >/dev/null
command -v xdotool >/dev/null
command -v qdbus6 >/dev/null
mkdir -p "$scratch/tmux-runtime" "$scratch/config" "$scratch/cache" "$scratch/data"
chmod 0700 "$scratch/tmux-runtime"
export TMUX_TMPDIR="$scratch/tmux-runtime"
export ZELLIJ_CONFIG_DIR="$scratch/config/zellij"
export XDG_CACHE_HOME="$scratch/cache"
export XDG_CONFIG_HOME="$scratch/config"
export XDG_DATA_HOME="$scratch/data"
export SHELL=/bin/sh
mkdir -p "$ZELLIJ_CONFIG_DIR"
zellij setup --dump-config >"$ZELLIJ_CONFIG_DIR/config.kdl"
printf '\nshow_release_notes false\nshow_startup_tips false\n' \
    >>"$ZELLIJ_CONFIG_DIR/config.kdl"
printf 'default_shell "/bin/sh"\nsimplified_ui true\n' \
    >>"$ZELLIJ_CONFIG_DIR/config.kdl"
mkdir -p "$artifact_dir"
find "$artifact_dir" -maxdepth 1 -type f \
    \( -name '*.png' -o -name '*.log' -o -name 'summary.csv' -o \
       -name 'SHA256SUMS' \) -delete
printf 'kind,mode,backend,phase,image_width,image_height\n' >"$artifact_dir/summary.csv"

session_exists() {
    local kind=$1
    local name=$2
    if [[ "$kind" == tmux ]]; then
        tmux has-session -t "$name" 2>/dev/null
    else
        zellij list-sessions --short 2>/dev/null | grep -Fx "$name" >/dev/null
    fi
}

wait_for_session() {
    local kind=$1
    local name=$2
    local log=$3
    local pid=$4
    local attempt=0
    while ((attempt < 200)); do
        if session_exists "$kind" "$name"; then return 0; fi
        if ! kill -0 "$pid" 2>/dev/null; then
            cat "$log" >&2
            return 1
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    printf 'timed out waiting for %s session %s\n' "$kind" "$name" >&2
    cat "$log" >&2
    return 1
}

send_marker() {
    local kind=$1
    local name=$2
    local marker=$3
    local attempt=0
    while ((attempt < 100)); do
        if [[ "$kind" == tmux ]]; then
            if tmux send-keys -t "$name" "printf '$marker\\n'" Enter 2>/dev/null; then
                return 0
            fi
        else
            if zellij --session "$name" action write-chars \
                "printf '$marker\\n'" >/dev/null 2>&1 &&
               zellij --session "$name" action send-keys Enter >/dev/null 2>&1; then
                return 0
            fi
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    return 1
}

screen_contains_marker() {
    local kind=$1
    local name=$2
    local marker=$3
    if [[ "$kind" == tmux ]]; then
        tmux capture-pane -p -t "$name" | grep -F "$marker" >/dev/null
    else
        zellij --session "$name" action dump-screen 2>/dev/null |
            grep -F "$marker" >/dev/null
    fi
}

wait_for_marker() {
    local kind=$1
    local name=$2
    local marker=$3
    local attempt=0
    while ((attempt < 200)); do
        if screen_contains_marker "$kind" "$name" "$marker"; then return 0; fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    return 1
}

wait_for_exit() {
    local pid=$1
    local log=$2
    local attempt=0
    while ((attempt < 200)); do
        if ! kill -0 "$pid" 2>/dev/null; then
            wait "$pid"
            return 0
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    printf 'timed out waiting for detached DEETTY pid=%s\n' "$pid" >&2
    cat "$log" >&2
    return 1
}

activate_wayland_window() {
    local pid=$1
    local script="$scratch/activate-window.js"
    local plugin="deettyContinuityActivate$$"
    cat >"$script" <<EOF
for (const window of workspace.windowList()) {
    if (window.caption === 'DEETTY installed continuity qualification') {
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
    local backend=$1
    local pid=$2
    local image=$3
    local marker=$4
    if [[ "$backend" == x11 ]]; then
        local window=
        local attempt=0
        while ((attempt < 100)); do
            window=$(xdotool search --onlyvisible \
                --name '^DEETTY installed continuity qualification$' \
                2>/dev/null | tail -n 1 || true)
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
    grep -F 'DEETTY' <<<"$ocr" >/dev/null
    grep -F 'PERSISTENT' <<<"$ocr" >/dev/null
    local tool
    tool=$(awk '{ print $3 }' <<<"$marker")
    grep -F "$tool" <<<"$ocr" >/dev/null
}

launch_lane() {
    local binary=$1
    local kind=$2
    local name=$3
    local backend=$4
    local detach_path=$5
    local log=$6
    env GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
        GDK_BACKEND="$backend" \
        DEETTY_CONTINUITY_KIND="$kind" \
        DEETTY_CONTINUITY_DETACH_PATH="$detach_path" \
        "$binary" \
        --native-grid-installed-continuity-qualification \
        "$kind" "$name" >"$log" 2>&1 &
    runner_pid=$!
}

for mode in Debug ReleaseSafe; do
    prefix="$scratch/$mode"
    ZIG_GLOBAL_CACHE_DIR="$scratch/global-cache" zig build deetty-smoke-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$scratch/cache-$mode"
    mode_name=$(tr '[:upper:]' '[:lower:]' <<<"$mode")
    for backend in wayland x11; do
        for kind in tmux zellij; do
            current_kind=$kind
            current_session="deetty-${kind}-${mode_name}-${backend}-$$"
            marker="DEETTY PERSISTENT $(tr '[:lower:]' '[:upper:]' <<<"$kind") SESSION OK"
            first_log="$artifact_dir/$kind-$mode_name-$backend-first.log"
            first_image="$artifact_dir/$kind-$mode_name-$backend-first.png"
            detach_path="$scratch/$kind-$mode_name-$backend-first-detach"
            rm -f "$detach_path"
            launch_lane "$prefix/bin/deetty-smoke" "$kind" "$current_session" \
                "$backend" "$detach_path" "$first_log"
            wait_for_session "$kind" "$current_session" "$first_log" "$runner_pid"
            send_marker "$kind" "$current_session" "$marker"
            wait_for_marker "$kind" "$current_session" "$marker"
            capture_window "$backend" "$runner_pid" "$first_image" "$marker"
            read -r width height < <(identify -format '%w %h\n' "$first_image")
            ((width >= 900))
            ((height >= 500))
            printf '%s,%s,%s,first,%s,%s\n' \
                "$kind" "$mode" "$backend" "$width" "$height" \
                >>"$artifact_dir/summary.csv"
            touch "$detach_path"
            wait_for_exit "$runner_pid" "$first_log"
            runner_pid=
            session_exists "$kind" "$current_session"
            grep -F "native_grid_installed_continuity_qualification kind=$kind installed_tool=true create_or_attach=true production_pty=true production_vt=true production_gtk=true production_cairo=true controlled_detach=true exited=true" "$first_log" >/dev/null

            reattach_log="$artifact_dir/$kind-$mode_name-$backend-reattach.log"
            reattach_image="$artifact_dir/$kind-$mode_name-$backend-reattach.png"
            detach_path="$scratch/$kind-$mode_name-$backend-reattach-detach"
            rm -f "$detach_path"
            launch_lane "$prefix/bin/deetty-smoke" "$kind" "$current_session" \
                "$backend" "$detach_path" "$reattach_log"
            wait_for_session "$kind" "$current_session" "$reattach_log" "$runner_pid"
            wait_for_marker "$kind" "$current_session" "$marker"
            capture_window "$backend" "$runner_pid" "$reattach_image" "$marker"
            read -r width height < <(identify -format '%w %h\n' "$reattach_image")
            ((width >= 900))
            ((height >= 500))
            printf '%s,%s,%s,reattach,%s,%s\n' \
                "$kind" "$mode" "$backend" "$width" "$height" \
                >>"$artifact_dir/summary.csv"
            touch "$detach_path"
            wait_for_exit "$runner_pid" "$reattach_log"
            runner_pid=
            session_exists "$kind" "$current_session"
            grep -F "native_grid_installed_continuity_qualification kind=$kind installed_tool=true create_or_attach=true production_pty=true production_vt=true production_gtk=true production_cairo=true controlled_detach=true exited=true" "$reattach_log" >/dev/null
            cleanup_session
            ! session_exists "$kind" "$current_session"
            current_kind=
            current_session=
            cat "$first_log"
            cat "$reattach_log"
        done
    done
done

(
    cd "$artifact_dir"
    checksum_files=(./*.log ./*.png summary.csv)
    [[ ! -f README.md ]] || checksum_files=(README.md "${checksum_files[@]}")
    sha256sum "${checksum_files[@]}" >SHA256SUMS
    sha256sum -c SHA256SUMS >/dev/null
)

echo "native_grid_installed_continuity_matrix tmux_version=$(tmux -V | awk '{print $2}') zellij_version=$(zellij --version | awk '{print $2}') debug=true release_safe=true wayland=true x11=true first_attach=true detached=true deetty_relaunch=true reattach=true content_preserved=true production_pty=true production_vt=true production_gtk=true production_cairo=true compositor_pixels=true controlled_exit=true hid=false checksums=true artifact_dir=$artifact_dir scratch_clean=true"
