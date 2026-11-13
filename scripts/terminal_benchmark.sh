#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workload="$repo_root/scripts/terminal_benchmark_workload.sh"
dintty_bin=${DINTTY_BENCH_DINTTY_BIN:-"$repo_root/zig-out/bin/dintty"}
benchmark_dir="$repo_root/benchmarks"
runs=${DINTTY_BENCH_RUNS:-7}
pane_counts=${DINTTY_BENCH_PANES:-"1 2 4 8"}
output_pane_counts=${DINTTY_BENCH_OUTPUT_PANES:-"1 2 4 8"}
output_lines=${DINTTY_BENCH_OUTPUT_LINES:-20000}
cpu_sample_ms=${DINTTY_BENCH_CPU_SAMPLE_MS:-1000}
visual_timeout_ms=${DINTTY_BENCH_VISUAL_TIMEOUT_MS:-30000}
inter_trial_settle_ms=${DINTTY_BENCH_INTER_TRIAL_SETTLE_MS:-1000}
post_output_settle_ms=${DINTTY_BENCH_POST_OUTPUT_SETTLE_MS:-250}
expect_idle_compaction=${DINTTY_BENCH_EXPECT_IDLE_COMPACTION:-0}
warmup=${DINTTY_BENCH_WARMUP:-1}
skip_build=${DINTTY_BENCH_SKIP_BUILD:-0}
terminals=${DINTTY_BENCH_TERMINALS:-"dintty dintty-production konsole kitty wezterm terminator ghostty alacritty yakuake"}
read -r -a terminal_list <<<"$terminals"
terminal_count=${#terminal_list[@]}
inter_trial_settle_seconds=$(awk -v ms="$inter_trial_settle_ms" 'BEGIN { printf "%.3f", ms / 1000 }')
post_output_settle_seconds=$(awk -v ms="$post_output_settle_ms" 'BEGIN { printf "%.3f", ms / 1000 }')
window_width=${DINTTY_BENCH_WINDOW_WIDTH:-1200}
window_height=${DINTTY_BENCH_WINDOW_HEIGHT:-800}
font_size=${DINTTY_BENCH_FONT_SIZE:-11}
offscreen=${DINTTY_BENCH_OFFSCREEN:-0}
display_backend=${DINTTY_BENCH_DISPLAY_BACKEND:-x11}
renderer=${DINTTY_BENCH_RENDERER:-cairo}
export DINTTY_BENCH_RENDERER="$renderer"
if [[ "$display_backend" == wayland ]]; then
    backend_label=native_wayland
    visual_metric=unavailable_native_wayland
    visual_tail_metric=unavailable_native_wayland
else
    backend_label=x11_xwayland
    visual_metric=release_to_external_pixel_marker
    visual_tail_metric=writer_completion_to_external_pixel_marker
fi
run_stamp=${DINTTY_BENCH_STAMP:-$(date +%Y-%m-%d-%H%M%S)}
raw_csv="$benchmark_dir/terminal-comparison-$run_stamp-raw.csv"
summary_csv="$benchmark_dir/terminal-comparison-$run_stamp-summary.csv"
metadata_file="$benchmark_dir/terminal-comparison-$run_stamp-metadata.txt"
process_tsv="$benchmark_dir/terminal-comparison-$run_stamp-processes.tsv"
checksums_file="$benchmark_dir/terminal-comparison-$run_stamp-SHA256SUMS"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/dintty-terminal-benchmark.XXXXXX")
payload="$scratch/payload.ansi"
declare -a active_roots=()
launch_pid=0
window_pid=0
window_id=""
kitty_socket=""
konsole_service=""
wezterm_class=""
wezterm_workspace=""
wezterm_socket=""
wezterm_log=""
trial_serial=0
progress_done=0
progress_total=0
progress_label="starting"

progress_render() {
    local width=30 filled percent prefix="" suffix=$'\n'
    (( progress_total > 0 )) || return 0
    percent=$((progress_done * 100 / progress_total))
    filled=$((progress_done * width / progress_total))
    if [[ -t 2 ]]; then prefix=$'\r\033[2K'; suffix=""; fi
    printf '%s[%.*s%*s] %d/%d %3d%% %s%s' \
        "$prefix" "$filled" '##############################' "$((width - filled))" '' \
        "$progress_done" "$progress_total" "$percent" "$progress_label" "$suffix" >&2
}

progress_clear() {
    [[ ! -t 2 ]] || printf '\r\033[2K' >&2
}

die() {
    progress_clear
    printf 'terminal_benchmark error=%s\n' "$*" >&2
    exit 1
}

now_ms() {
    date +%s%3N
}

now_ns() {
    date +%s%N
}

tree_pids() {
    local root=$1
    ps -e -o pid=,ppid= | awk -v root="$root" '
        { pid[++count] = $1; parent[count] = $2 }
        END {
            keep[root] = 1
            for (pass = 0; pass < count; pass++) {
                for (item = 1; item <= count; item++) {
                    if (keep[parent[item]]) keep[pid[item]] = 1
                }
            }
            for (item = 1; item <= count; item++) {
                if (keep[pid[item]]) print pid[item]
            }
        }
    '
}

kill_tree() {
    local root=$1
    local -a pids=()
    kill -0 "$root" 2>/dev/null || return 0
    mapfile -t pids < <(tree_pids "$root" | sort -rn)
    ((${#pids[@]} == 0)) || kill "${pids[@]}" 2>/dev/null || true
}

cleanup() {
    local marker pid root runtime_dir
    shopt -s nullglob globstar
    for marker in "$scratch"/**/spawned.*; do
        pid=${marker##*.}
        [[ "$pid" =~ ^[1-9][0-9]*$ ]] || continue
        [[ -r "/proc/$pid/cmdline" ]] || continue
        if tr '\0' ' ' 2>/dev/null <"/proc/$pid/cmdline" | grep -Fq "$workload"; then
            kill_tree "$pid"
        fi
    done
    shopt -u globstar nullglob
    for root in "${active_roots[@]}"; do
        kill_tree "$root"
    done

    if [[ -n "$wezterm_socket" ]]; then
        runtime_dir=${wezterm_socket%/*}
        rm -f -- "$wezterm_socket" "$wezterm_log"
        rmdir "$runtime_dir" 2>/dev/null || true
    fi
    rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

marker_count() {
    local directory=$1
    local prefix=$2
    find "$directory" -maxdepth 1 -type f -name "$prefix.*" -printf . | wc -c
}

wait_for_count() {
    local directory=$1
    local prefix=$2
    local expected=$3
    local timeout_ms=$4
    local deadline=$(( $(now_ms) + timeout_ms ))
    local count
    while (( $(now_ms) < deadline )); do
        count=$(marker_count "$directory" "$prefix")
        (( count >= expected )) && return 0
        sleep 0.01
    done
    count=$(marker_count "$directory" "$prefix")
    printf 'terminal_benchmark timeout marker=%s expected=%d actual=%d run_dir=%s\n' \
        "$prefix" "$expected" "$count" "$directory" >&2
    [[ ! -f "$directory/app.log" ]] || tail -80 "$directory/app.log" >&2
    return 1
}

wait_for_log() {
    local file=$1
    local pattern=$2
    local timeout_ms=$3
    local deadline=$(( $(now_ms) + timeout_ms ))
    while (( $(now_ms) < deadline )); do
        [[ -f "$file" ]] && grep -Eq "$pattern" "$file" && return 0
        sleep 0.01
    done
    printf 'terminal_benchmark timeout log_pattern=%s file=%s\n' \
        "$pattern" "$file" >&2
    [[ ! -f "$file" ]] || tail -80 "$file" >&2
    return 1
}

geometry_stats() {
    awk 'NR == 1 { min_r=max_r=$1; min_c=max_c=$2 }
        { if ($1<min_r) min_r=$1; if ($1>max_r) max_r=$1;
          if ($2<min_c) min_c=$2; if ($2>max_c) max_c=$2 }
        END { print min_r, max_r, min_c, max_c }' "$1"/geometry.*
}

wait_for_visual_marker() {
    local deadline=$(( $(now_ms) + visual_timeout_ms ))
    local image="$scratch/visual.rgb"
    while (( $(now_ms) < deadline )); do
        import -window "$window_id" -depth 8 "rgb:$image" 2>/dev/null || continue
        visual_end_ns=$(now_ns)
        LC_ALL=C grep -aFqm1 $'\x12\x34\x56' "$image" && return 0
        sleep 0.02
    done
    return 1
}

wait_for_window() {
    local selector=$1
    local query=$2
    local timeout_ms=$3
    local pid=${4:-0}
    local deadline=$(( $(now_ms) + timeout_ms ))
    while (( $(now_ms) < deadline )); do
        window_id=$(xdotool search --onlyvisible "--$selector" "$query" 2>/dev/null | head -1 || true)
        if [[ -z "$window_id" && "$pid" =~ ^[1-9][0-9]*$ ]]; then
            window_id=$(xdotool search --onlyvisible --pid "$pid" 2>/dev/null | head -1 || true)
        fi
        [[ -z "$window_id" ]] || return 0
        sleep 0.02
    done
    return 1
}

enforce_window_geometry() {
    local geometry actual_width actual_height
    local deadline=$(( $(now_ms) + 3000 ))
    xdotool windowstate --remove FULLSCREEN "$window_id" >/dev/null 2>&1 || true
    xdotool windowstate --remove MAXIMIZED_VERT "$window_id" >/dev/null 2>&1 || true
    xdotool windowstate --remove MAXIMIZED_HORZ "$window_id" >/dev/null 2>&1 || true
    while (( $(now_ms) < deadline )); do
        xdotool windowsize "$window_id" "$window_width" "$window_height" \
            >/dev/null 2>&1 || true
        geometry=$(xdotool getwindowgeometry --shell "$window_id" 2>/dev/null || true)
        actual_width=$(awk -F= '$1 == "WIDTH" { print $2 }' <<<"$geometry")
        actual_height=$(awk -F= '$1 == "HEIGHT" { print $2 }' <<<"$geometry")
        if [[ "$actual_width" == "$window_width" && "$actual_height" == "$window_height" ]]; then
            return 0
        fi
        sleep 0.02
    done
    printf 'terminal_benchmark geometry expected=%sx%s actual=%sx%s window=%s\n' \
        "$window_width" "$window_height" "${actual_width:-unknown}" \
        "${actual_height:-unknown}" "$window_id" >&2
    return 1
}

wait_for_socket() {
    local path=$1
    local deadline=$(( $(now_ms) + 10000 ))
    while (( $(now_ms) < deadline )); do
        [[ -S "$path" ]] && return 0
        sleep 0.02
    done
    return 1
}

wait_for_konsole_service() {
    local deadline=$(( $(now_ms) + 10000 ))
    while (( $(now_ms) < deadline )); do
        if qdbus "$konsole_service" /Windows/1 \
            org.kde.konsole.Window.sessionCount >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.02
    done
    return 1
}

wait_for_yakuake_service() {
    local deadline=$(( $(now_ms) + 10000 ))
    while (( $(now_ms) < deadline )); do
        qdbus org.kde.yakuake /yakuake/sessions \
            org.kde.yakuake.activeTerminalId >/dev/null 2>&1 && return 0
        sleep 0.02
    done
    return 1
}

supports_panes() {
    local terminal=$1
    local panes=$2
    [[ "$panes" == 1 || ( "$terminal" != alacritty && "$terminal" != dintty-production ) ]]
}

version_for() {
    local terminal=$1 executable=$1 output
    [[ "$terminal" != dintty && "$terminal" != dintty-production ]] || executable=$dintty_bin
    if [[ "$terminal" == terminator ]]; then
        output=$("$executable" --version 2>&1 | grep -m1 '^terminator ' || true)
    else
        output=$("$executable" --version 2>&1 | head -1 || true)
    fi
    printf '%s' "${output:-unknown}" | tr ',\t\r\n' '    '
}

write_wezterm_config() {
    local path=$1
    cat >"$path" <<EOF
return {
  enable_wayland = false,
  font_size = $font_size,
  scrollback_lines = 1000,
  audible_bell = "Disabled",
  window_close_confirmation = "NeverPrompt",
  check_for_updates = false,
  initial_cols = 120,
  initial_rows = 40,
}
EOF
}

terminator_node_id=0
terminator_terminal_id=0
terminator_config=""

emit_terminator_tree() {
    local parent=$1
    local order=$2
    local leaves=$3
    local depth=$4
    local name type half
    if (( leaves == 1 )); then
        name="terminal$terminator_terminal_id"
        terminator_terminal_id=$((terminator_terminal_id + 1))
        cat >>"$terminator_config" <<EOF
    [[[$name]]]
      type = Terminal
      parent = $parent
      order = $order
      profile = benchmark
EOF
        return
    fi

    name="split$terminator_node_id"
    terminator_node_id=$((terminator_node_id + 1))
    if (( depth % 2 == 0 )); then
        type=HPaned
    else
        type=VPaned
    fi
    cat >>"$terminator_config" <<EOF
    [[[$name]]]
      type = $type
      parent = $parent
      order = $order
      ratio = 0.5
EOF
    half=$((leaves / 2))
    emit_terminator_tree "$name" 0 "$half" $((depth + 1))
    emit_terminator_tree "$name" 1 "$half" $((depth + 1))
}

write_terminator_config() {
    local path=$1
    local pane_count=$2
    terminator_config=$path
    terminator_node_id=0
    terminator_terminal_id=0
    cat >"$path" <<EOF
[global_config]
  ask_before_closing = never
  geometry_hinting = False
[keybindings]
[profiles]
  [[benchmark]]
    use_custom_command = True
    custom_command = $workload
    exit_action = close
    use_system_font = False
    font = Monospace $font_size
    scrollback_lines = 1000
    show_titlebar = False
[layouts]
  [[benchmark]]
    [[[window0]]]
      type = Window
      parent =
      size = $window_width, $window_height
EOF
    emit_terminator_tree window0 0 "$pane_count" 0
    printf '[plugins]\n' >>"$path"
}

write_ghostty_config() {
    local path=$1
    local class=$2
    local title=$3
    cat >"$path" <<EOF
command = $workload
title = $title
class = $class
gtk-single-instance = false
quit-after-last-window-closed = true
confirm-close-surface = false
shell-integration = none
font-family = monospace
font-size = $font_size
scrollback-limit = 87000
keybind = f8=new_split:auto
keybind = f9=goto_split:next
EOF
}

write_alacritty_config() {
    local path=$1
    cat >"$path" <<EOF
[window]
dynamic_title = false
dimensions = { columns = 120, lines = 40 }

[font]
size = $font_size

[scrolling]
history = 1000
EOF
}

write_yakuake_profile() {
    local path=$1
    mkdir -p "$(dirname "$path")"
    cat >"$path" <<EOF
[Appearance]
ColorScheme=Breeze
Font=Monospace,$font_size,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0

[General]
Name=DINTTY Benchmark
Parent=FALLBACK/
TerminalColumns=120
TerminalRows=40
EOF
}

write_yakuake_command() {
    local path=$1
    cat >"$path" <<EOF
#!/usr/bin/env bash
export DINTTY_BENCH_RUN_DIR=$(printf '%q' "$DINTTY_BENCH_RUN_DIR")
export DINTTY_BENCH_TITLE=$(printf '%q' "$DINTTY_BENCH_TITLE")
export DINTTY_BENCH_MODE=$(printf '%q' "$DINTTY_BENCH_MODE")
export DINTTY_BENCH_PAYLOAD=$(printf '%q' "$DINTTY_BENCH_PAYLOAD")
exec $(printf '%q' "$workload")
EOF
    chmod +x "$path"
}

launch_terminal() {
    local terminal=$1
    local panes=$2
    local run_dir=$3
    local title=$4
    local config class
    launch_pid=0
    case "$terminal" in
        dintty)
            if [[ "$display_backend" == wayland ]]; then
                NO_AT_BRIDGE=1 GDK_BACKEND=wayland DISPLAY= "$dintty_bin" --native-grid-benchmark "$panes" \
                    >"$run_dir/app.log" 2>&1 &
            else
                NO_AT_BRIDGE=1 GDK_BACKEND=x11 "$dintty_bin" --native-grid-benchmark "$panes" \
                    >"$run_dir/app.log" 2>&1 &
            fi
            launch_pid=$!
            ;;
        dintty-production)
            mkdir -p "$run_dir/home" "$run_dir/config" "$run_dir/state"
            if [[ "$display_backend" == wayland ]]; then
                HOME="$run_dir/home" XDG_CONFIG_HOME="$run_dir/config" \
                    XDG_STATE_HOME="$run_dir/state" SHELL="$workload" \
                    NO_AT_BRIDGE=1 GDK_BACKEND=wayland DISPLAY= \
                    "$dintty_bin" --native-grid-windowed \
                    >"$run_dir/app.log" 2>&1 &
            else
                HOME="$run_dir/home" XDG_CONFIG_HOME="$run_dir/config" \
                    XDG_STATE_HOME="$run_dir/state" SHELL="$workload" \
                    NO_AT_BRIDGE=1 GDK_BACKEND=x11 "$dintty_bin" --native-grid-windowed \
                    >"$run_dir/app.log" 2>&1 &
            fi
            launch_pid=$!
            ;;
        konsole)
            QT_QPA_PLATFORM=xcb konsole --separate --builtin-profile \
                --notransparency --hide-menubar --hide-tabbar \
                -e "$workload" >"$run_dir/app.log" 2>&1 &
            launch_pid=$!
            konsole_service="org.kde.konsole-$launch_pid"
            ;;
        kitty)
            kitty_socket="$run_dir/kitty.sock"
            KITTY_DISABLE_WAYLAND=1 DINTTY_BENCH_SLOT=0 kitty --config NONE \
                --listen-on "unix:$kitty_socket" \
                -o allow_remote_control=socket-only \
                -o enabled_layouts=splits \
                -o linux_display_server=x11 \
                -o scrollback_lines=1000 \
                -o font_size="$font_size" \
                -o remember_window_size=no \
                -o confirm_os_window_close=0 \
                --title "$title" "$workload" \
                >"$run_dir/app.log" 2>&1 &
            launch_pid=$!
            ;;
        wezterm)
            config="$run_dir/wezterm.lua"
            write_wezterm_config "$config"
            wezterm_class="DinttyBenchWezterm$trial_serial"
            wezterm_workspace="dintty-bench-$trial_serial"
            wezterm --config-file "$config" start --always-new-process \
                --class "$wezterm_class" --workspace "$wezterm_workspace" \
                -- "$workload" >"$run_dir/app.log" 2>&1 &
            launch_pid=$!
            wezterm_socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wezterm/gui-sock-$launch_pid"
            wezterm_log="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wezterm/wezterm-gui-log-$launch_pid.txt"
            ;;
        terminator)
            config="$run_dir/terminator.conf"
            write_terminator_config "$config" "$panes"
            GDK_BACKEND=x11 terminator --no-dbus --config "$config" \
                --layout benchmark --title "$title" \
                --geometry "${window_width}x${window_height}" \
                >"$run_dir/app.log" 2>&1 &
            launch_pid=$!
            ;;
        ghostty)
            config="$run_dir/ghostty.conf"
            class="com.lichforge.DinttyBench$trial_serial"
            write_ghostty_config "$config" "$class" "$title"
            GDK_BACKEND=x11 ghostty --config-file="$config" \
                >"$run_dir/app.log" 2>&1 &
            launch_pid=$!
            ;;
        alacritty)
            config="$run_dir/alacritty.toml"
            write_alacritty_config "$config"
            env -u WAYLAND_DISPLAY alacritty --config-file "$config" \
                --title "$title" --class "DinttyBenchAlacritty$trial_serial" \
                -e "$workload" >"$run_dir/app.log" 2>&1 &
            launch_pid=$!
            ;;
        yakuake)
            write_yakuake_profile \
                "$run_dir/yakuake-data/konsole/DINTTY Benchmark.profile"
            mkdir -p "$run_dir/yakuake-config"
            printf '[Desktop Entry]\nDefaultProfile=DINTTY Benchmark.profile\n[Dialogs]\nFirstRun=false\n[Window]\nHeight=100\nWidth=100\n' \
                >"$run_dir/yakuake-config/yakuakerc"
            QT_QPA_PLATFORM=xcb XDG_CONFIG_HOME="$run_dir/yakuake-config" \
                XDG_DATA_HOME="$run_dir/yakuake-data" yakuake \
                >"$run_dir/app.log" 2>&1 &
            launch_pid=$!
            wait_for_yakuake_service || return 1
            launch_pid=$(pgrep -n -x yakuake || true)
            [[ "$launch_pid" =~ ^[1-9][0-9]*$ ]] || return 1
            write_yakuake_command "$run_dir/yakuake-workload.sh"
            local terminal_id
            terminal_id=$(qdbus org.kde.yakuake /yakuake/sessions \
                org.kde.yakuake.activeTerminalId)
            qdbus org.kde.yakuake "/Sessions/$((terminal_id + 1))" \
                org.kde.konsole.Session.setHistorySize 1000 >/dev/null || return 1
            qdbus org.kde.yakuake /yakuake/sessions \
                org.kde.yakuake.runCommandInTerminal "$terminal_id" \
                "$run_dir/yakuake-workload.sh" || return 1
            qdbus org.kde.yakuake /yakuake/window \
                org.kde.yakuake.toggleWindowState || return 1
            ;;
        *) die "unsupported_terminal:$terminal" ;;
    esac
    active_roots=("$launch_pid")
}

create_konsole_splits() {
    local panes=$1
    local current=1
    local horizontal=true
    local view result session_count index
    wait_for_konsole_service || return 1
    while (( current < panes )); do
        for ((view = 0; view < current; view++)); do
            result=$(qdbus "$konsole_service" /Windows/1 \
                org.kde.konsole.Window.createSplit "$view" "$horizontal")
            [[ "$result" == true ]] || return 1
        done
        current=$((current * 2))
        if [[ "$horizontal" == true ]]; then horizontal=false; else horizontal=true; fi
    done
    session_count=$(qdbus "$konsole_service" /Windows/1 \
        org.kde.konsole.Window.sessionCount)
    (( session_count == panes )) || return 1
    for ((index = 1; index <= panes; index++)); do
        qdbus "$konsole_service" "/Sessions/$index" \
            org.kde.konsole.Session.setHistorySize 1000 >/dev/null
    done
}

create_kitty_splits() {
    local panes=$1
    local current=1
    local next_slot=1
    local level=0
    local slot location
    wait_for_socket "$kitty_socket" || return 1
    while (( current < panes )); do
        if (( level % 2 == 0 )); then location=vsplit; else location=hsplit; fi
        for ((slot = 0; slot < current; slot++)); do
            kitty @ --to "unix:$kitty_socket" launch \
                --type=window --keep-focus --location="$location" \
                --next-to "env:DINTTY_BENCH_SLOT=$slot" \
                --title "$DINTTY_BENCH_TITLE" \
                --env "DINTTY_BENCH_SLOT=$next_slot" \
                --env "DINTTY_BENCH_RUN_DIR=$DINTTY_BENCH_RUN_DIR" \
                --env "DINTTY_BENCH_TITLE=$DINTTY_BENCH_TITLE" \
                --env "DINTTY_BENCH_MODE=$DINTTY_BENCH_MODE" \
                --env "DINTTY_BENCH_PAYLOAD=$DINTTY_BENCH_PAYLOAD" \
                "$workload" >/dev/null
            next_slot=$((next_slot + 1))
        done
        current=$((current * 2))
        level=$((level + 1))
    done
}

create_wezterm_splits() {
    local panes=$1
    local initial=""
    local deadline=$(( $(now_ms) + 10000 ))
    local current level pane direction new_pane expected
    local -a pane_ids=()
    wait_for_socket "$wezterm_socket" || return 1
    while (( $(now_ms) < deadline )); do
        initial=$(WEZTERM_UNIX_SOCKET="$wezterm_socket" wezterm cli --no-auto-start \
            list 2>>"$DINTTY_BENCH_RUN_DIR/app.log" | \
            awk -v workspace="$wezterm_workspace" \
                'NR > 1 && index($0, workspace) { print $3; exit }')
        [[ -z "$initial" ]] || break
        sleep 0.02
    done
    if [[ -z "$initial" ]]; then
        WEZTERM_UNIX_SOCKET="$wezterm_socket" wezterm cli --no-auto-start list \
            >>"$DINTTY_BENCH_RUN_DIR/app.log" 2>&1 || true
        return 1
    fi
    pane_ids=("$initial")
    current=1
    level=0
    while (( current < panes )); do
        if (( level % 2 == 0 )); then direction=--right; else direction=--bottom; fi
        for pane in "${pane_ids[@]:0:current}"; do
            new_pane=$(WEZTERM_UNIX_SOCKET="$wezterm_socket" \
                wezterm cli --no-auto-start split-pane --pane-id "$pane" \
                "$direction" -- "$workload")
            [[ "$new_pane" =~ ^[0-9]+$ ]] || return 1
            pane_ids+=("$new_pane")
            expected=${#pane_ids[@]}
            wait_for_count "$DINTTY_BENCH_RUN_DIR" spawned "$expected" 5000 ||
                return 1
        done
        current=$((current * 2))
        level=$((level + 1))
    done
}

create_ghostty_splits() {
    local panes=$1
    local current=1
    local index expected active_window
    while (( current < panes )); do
        for ((index = 0; index < current; index++)); do
            xdotool windowactivate --sync "$window_id"
            active_window=$(xdotool getactivewindow)
            [[ "$active_window" == "$window_id" ]] || return 1
            xdotool key --clearmodifiers F8
            expected=$((current + index + 1))
            wait_for_count "$DINTTY_BENCH_RUN_DIR" spawned "$expected" 5000
            xdotool windowactivate --sync "$window_id"
            active_window=$(xdotool getactivewindow)
            [[ "$active_window" == "$window_id" ]] || return 1
            xdotool key --clearmodifiers F9
        done
        current=$((current * 2))
    done
}

create_yakuake_splits() {
    local panes=$1
    local current=1
    local level=0
    local terminal new_terminal expected method terminal_count
    local -a terminal_ids=()
    terminal_ids=("$(qdbus org.kde.yakuake /yakuake/sessions \
        org.kde.yakuake.activeTerminalId)")
    while (( current < panes )); do
        if (( level % 2 == 0 )); then
            method=org.kde.yakuake.splitTerminalTopBottom
        else
            method=org.kde.yakuake.splitTerminalLeftRight
        fi
        for terminal in "${terminal_ids[@]:0:current}"; do
            new_terminal=$(qdbus org.kde.yakuake /yakuake/sessions \
                "$method" "$terminal")
            [[ "$new_terminal" =~ ^[0-9]+$ ]] || return 1
            terminal_ids+=("$new_terminal")
            qdbus org.kde.yakuake "/Sessions/$((new_terminal + 1))" \
                org.kde.konsole.Session.setHistorySize 1000 >/dev/null || return 1
            qdbus org.kde.yakuake /yakuake/sessions \
                org.kde.yakuake.runCommandInTerminal "$new_terminal" \
                "$DINTTY_BENCH_RUN_DIR/yakuake-workload.sh" || return 1
            expected=${#terminal_ids[@]}
            wait_for_count "$DINTTY_BENCH_RUN_DIR" spawned "$expected" 5000 ||
                return 1
        done
        current=$((current * 2))
        level=$((level + 1))
    done
    terminal_count=$(qdbus org.kde.yakuake /yakuake/sessions \
        org.kde.yakuake.terminalIdList | grep -oE '[0-9]+' | wc -l)
    (( terminal_count == panes ))
}

create_splits() {
    local terminal=$1
    local panes=$2
    case "$terminal" in
        dintty|dintty-production|terminator|alacritty) ;;
        konsole) create_konsole_splits "$panes" ;;
        kitty) create_kitty_splits "$panes" ;;
        wezterm) create_wezterm_splits "$panes" ;;
        ghostty) create_ghostty_splits "$panes" ;;
        yakuake) create_yakuake_splits "$panes" ;;
    esac
}

declare -A excluded_pids=()

build_excluded_pids() {
    local run_dir=$1
    local marker pid child
    excluded_pids=()
    shopt -s nullglob
    for marker in "$run_dir"/spawned.*; do
        pid=${marker##*.}
        while IFS= read -r child; do
            excluded_pids[$child]=1
        done < <(tree_pids "$pid")
    done
    shopt -u nullglob
}

snapshot_processes() {
    local root=$1 terminal=$2 scenario=$3 panes=$4 trial=$5 serial=$6
    local pid ppid pss rss uss excluded command
    local total_pss=0 total_rss=0 total_uss=0 process_count=0
    while IFS= read -r pid; do
        [[ -r "/proc/$pid/status" ]] || continue
        ppid=$(awk '/^PPid:/ { print $2; exit }' "/proc/$pid/status")
        pss=0
        [[ ! -r "/proc/$pid/smaps_rollup" ]] ||
            pss=$(awk '/^Pss:/ { print $2; exit }' "/proc/$pid/smaps_rollup")
        rss=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$pid/status")
        uss=0
        [[ ! -r "/proc/$pid/smaps_rollup" ]] ||
            uss=$(awk '/^Private_(Clean|Dirty|Hugetlb):/ { total += $2 } END { print total + 0 }' "/proc/$pid/smaps_rollup")
        excluded=$([[ -n "${excluded_pids[$pid]+set}" ]] && printf true || printf false)
        command=$(tr '\0\t\r\n' '    ' <"/proc/$pid/cmdline" 2>/dev/null || true)
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$serial" "$terminal" "$scenario" "$panes" "$trial" "$pid" \
            "${ppid:-0}" "$excluded" "${pss:-0}" "${rss:-0}" "${uss:-0}" "$command" \
            >>"$process_tsv"
        [[ "$excluded" == true ]] && continue
        total_pss=$((total_pss + ${pss:-0}))
        total_rss=$((total_rss + ${rss:-0}))
        total_uss=$((total_uss + ${uss:-0}))
        process_count=$((process_count + 1))
    done < <(tree_pids "$root")
    printf '%d %d %d %d\n' "$total_pss" "$total_rss" "$total_uss" "$process_count"
}

sum_jiffies() {
    local root=$1
    local pid stat rest ticks
    local total=0
    while IFS= read -r pid; do
        [[ -z "${excluded_pids[$pid]+set}" ]] || continue
        [[ -r "/proc/$pid/stat" ]] || continue
        stat=$(<"/proc/$pid/stat")
        rest=${stat##*) }
        ticks=$(awk '{ print $12 + $13 }' <<<"$rest")
        total=$((total + ticks))
    done < <(tree_pids "$root")
    printf '%d\n' "$total"
}

measure_idle_cpu() {
    local root=$1
    local hz start_ticks end_ticks start_ns end_ns
    hz=$(getconf CLK_TCK)
    start_ticks=$(sum_jiffies "$root")
    start_ns=$(date +%s%N)
    sleep "$(awk -v ms="$cpu_sample_ms" 'BEGIN { printf "%.3f", ms / 1000 }')"
    end_ticks=$(sum_jiffies "$root")
    end_ns=$(date +%s%N)
    awk -v delta="$((end_ticks - start_ticks))" -v hz="$hz" \
        -v elapsed="$((end_ns - start_ns))" \
        'BEGIN { if (elapsed <= 0) print "0.000"; else printf "%.3f", (delta / hz) / (elapsed / 1000000000) * 100 }'
}

signal_workloads() {
    local run_dir=$1
    local fifo
    local -a writers=()
    shopt -s nullglob
    for fifo in "$run_dir"/control.*; do
        (printf 'stop\n' >"$fifo") &
        writers+=("$!")
    done
    shopt -u nullglob
    ((${#writers[@]} == 0)) || wait "${writers[@]}" 2>/dev/null || true
}

wait_for_exit() {
    local pid=$1
    local deadline=$(( $(now_ms) + 5000 ))
    while (( $(now_ms) < deadline )); do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.02
    done
    kill_tree "$pid"
}

run_trial() {
    local terminal=$1
    local panes=$2
    local scenario=$3
    local trial=$4
    local record=$5
    local order_index=${6:-0}
    local run_dir title start_ms ready_ms start_ns ready_ns output_start_ns output_end_ns ingest_ms
    local rows_min rows_max columns_min columns_max visual_ms="" visual_tail_ms="" visual_end_ns=""
    local pss_kib rss_kib uss_kib process_count idle_cpu throughput version root_candidate runtime_dir

    trial_serial=$((trial_serial + 1))
    run_dir="$scratch/run-$trial_serial-$terminal-$panes-$scenario"
    title="DINTTY-BENCH-$terminal-$trial_serial"
    mkdir -p "$run_dir"
    export DINTTY_BENCH_RUN_DIR="$run_dir"
    export DINTTY_BENCH_TITLE="$title"
    export DINTTY_BENCH_MODE="$scenario"
    export DINTTY_BENCH_PAYLOAD="$payload"
    export DINTTY_BENCH_WORKLOAD="$workload"
    export DINTTY_BENCH_FONT_SIZE="$font_size"
    export DINTTY_BENCH_SLOT=0

    start_ms=$(now_ms)
    start_ns=$(now_ns)
    window_id=""
    launch_terminal "$terminal" "$panes" "$run_dir" "$title"
    wait_for_count "$run_dir" spawned 1 15000
    if [[ "$display_backend" != wayland ]]; then
        if [[ "$terminal" == yakuake ]]; then
            wait_for_window class yakuake 15000
        else
            wait_for_window name "$title" 15000 "$launch_pid"
        fi
        [[ -n "$window_id" ]] || {
            tail -80 "$run_dir/app.log" >&2 || true
            die "window_not_found:$terminal"
        }
        enforce_window_geometry || die "window_geometry:$terminal"
    fi
    create_splits "$terminal" "$panes" || {
        tail -80 "$run_dir/app.log" >&2 || true
        die "split_creation:$terminal"
    }
    wait_for_count "$run_dir" spawned "$panes" 20000
    if [[ "$terminal" == dintty ]]; then
        if [[ "$renderer" == opengl ]]; then
            wait_for_log "$run_dir/app.log" \
                'native_grid_(renderer_receipt|renderer_fallback)' 15000 ||
                die "renderer_startup_timeout:$renderer"
        else
            wait_for_log "$run_dir/app.log" 'native_grid_renderer_receipt' 15000 ||
                die "renderer_startup_timeout:$renderer"
        fi
    fi
    ready_ms=$(now_ms)
    ready_ns=$(now_ns)
    if [[ "$display_backend" != wayland ]]; then
        window_pid=$(xdotool getwindowpid "$window_id" 2>/dev/null || true)
    else
        window_pid=""
    fi
    root_candidate=${window_pid:-$launch_pid}
    [[ "$root_candidate" =~ ^[0-9]+$ ]] || root_candidate=$launch_pid
    active_roots=("$launch_pid" "$root_candidate")
    sleep 0.25
    output_start_ns=$(now_ns)
    : >"$run_dir/go"
    wait_for_count "$run_dir" done "$panes" 60000
    output_end_ns=$(find "$run_dir" -maxdepth 1 -type f -name 'done.*' -printf '%T@\n' |
        sort -n | tail -1 | awk '{ printf "%.0f", $1 * 1000000000 }')
    ingest_ms=$(awk -v start="$output_start_ns" -v finish="$output_end_ns" \
        'BEGIN { printf "%.3f", (finish - start) / 1000000 }')
    read -r rows_min rows_max columns_min columns_max < <(geometry_stats "$run_dir")
    if [[ "$scenario" == output && "$display_backend" != wayland ]]; then
        wait_for_visual_marker || die "visual_marker_timeout:$terminal:$panes"
        visual_ms=$(awk -v start="$output_start_ns" -v finish="$visual_end_ns" \
            'BEGIN { printf "%.3f", (finish - start) / 1000000 }')
        visual_tail_ms=$(awk -v done="$output_end_ns" -v finish="$visual_end_ns" \
            'BEGIN { printf "%.3f", (finish - done) / 1000000 }')
    fi
    if [[ "$scenario" == output ]]; then
        sleep "$post_output_settle_seconds"
    else
        sleep 0.25
    fi

    if (( record == 1 )); then
        build_excluded_pids "$run_dir"
        read -r pss_kib rss_kib uss_kib process_count < <(
            snapshot_processes "$root_candidate" "$terminal" "$scenario" "$panes" "$trial" "$trial_serial"
        )
        (( process_count > 0 && pss_kib > 0 && rss_kib > 0 && uss_kib > 0 )) ||
            die "invalid_process_metrics:$terminal:$root_candidate"
        idle_cpu=$(measure_idle_cpu "$root_candidate")
        if [[ "$scenario" == output ]]; then
            throughput=$(awk -v bytes="$((payload_bytes * panes))" -v ms="$ingest_ms" \
                'BEGIN { if (ms <= 0) print "0.000"; else printf "%.3f", bytes / 1048576 / (ms / 1000) }')
        else
            ingest_ms=""
            throughput=""
        fi
        version=$(version_for "$terminal")
        printf '%s,%s,%s,%d,%d,%d,%d,%d,%d,%s,%s,%s,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$terminal" "$version" "$scenario" "$panes" "$trial" \
            "$((ready_ms - start_ms))" "$pss_kib" "$rss_kib" "$uss_kib" \
            "$idle_cpu" "$ingest_ms" "$throughput" "$process_count" \
            "$trial_serial" "$order_index" "$launch_pid" "$root_candidate" \
            "$start_ns" "$ready_ns" "$output_start_ns" "$output_end_ns" \
            "$rows_min" "$rows_max" "$columns_min" "$columns_max" \
            "$visual_ms" "$visual_end_ns" "$visual_tail_ms" >>"$raw_csv"
        progress_clear
        printf 'terminal_benchmark terminal=%s scenario=%s panes=%d trial=%d startup_ms=%d pss_kib=%d rss_kib=%d uss_kib=%d idle_cpu_pct=%s ingest_ms=%s visual_ms=%s visual_tail_ms=%s grid=%s-%sx%s-%s throughput_mib_s=%s processes=%d\n' \
            "$terminal" "$scenario" "$panes" "$trial" \
            "$((ready_ms - start_ms))" "$pss_kib" "$rss_kib" "$uss_kib" \
            "$idle_cpu" "${ingest_ms:-na}" "${visual_ms:-na}" "${visual_tail_ms:-na}" \
            "$rows_min" "$rows_max" "$columns_min" "$columns_max" \
            "${throughput:-na}" "$process_count"
    fi
    signal_workloads "$run_dir"
    if [[ "$terminal" == yakuake ]]; then
        qdbus org.kde.yakuake /MainApplication \
            org.qtproject.Qt.QCoreApplication.quit >/dev/null 2>&1 || true
    fi
    wait_for_exit "$root_candidate"
    wait "$launch_pid" 2>/dev/null || true
    if [[ "$record" == 1 && "$terminal" == dintty ]]; then
        renderer_receipt=$(grep -E '^native_grid_(benchmark renderer|gpu_context|renderer_receipt|renderer_smoke|renderer_fallback)' \
            "$run_dir/app.log" | tr '\n' ';' || true)
        printf 'renderer_receipt run_serial=%d terminal=%s scenario=%s panes=%d trial=%d lines=%s\n' \
            "$trial_serial" "$terminal" "$scenario" "$panes" "$trial" "${renderer_receipt:-missing}" \
            >>"$metadata_file"
        if [[ -z "$renderer_receipt" ]]; then
            tail -80 "$run_dir/app.log" >&2 || true
            die "renderer_receipt_missing:$renderer"
        fi
        if ! grep -Eq "native_grid_(renderer_receipt|renderer_smoke) .*renderer_requested=${renderer} renderer_effective=${renderer} " \
            "$run_dir/app.log"; then
            tail -80 "$run_dir/app.log" >&2 || true
            die "renderer_receipt_mismatch:$renderer"
        fi
        if grep -Eq '^native_grid_renderer_fallback ' "$run_dir/app.log"; then
            die "renderer_fallback:$renderer"
        fi
        if [[ "$renderer" == opengl ]]; then
            if ! grep -Eq 'native_grid_(renderer_receipt|renderer_smoke) .*gpu_render_frames=[1-9][0-9]* .*gpu_fallbacks=0([[:space:]]|$)' \
                "$run_dir/app.log"; then
                tail -80 "$run_dir/app.log" >&2 || true
                die "gpu_presentation_missing"
            fi
        fi
    fi
    if [[ "$expect_idle_compaction" == 1 && "$scenario" == output &&
          "$terminal" == dintty* ]]; then
        grep -E 'native_grid_benchmark idle_history_compactions=[1-9][0-9]*' \
            "$run_dir/app.log" >/dev/null || {
            tail -80 "$run_dir/app.log" >&2 || true
            die "idle_history_compaction_missing:$terminal:$panes"
        }
    fi
    if [[ "$terminal" == wezterm && -n "$wezterm_socket" ]]; then
        runtime_dir=${wezterm_socket%/*}
        rm -f -- "$wezterm_socket" "$wezterm_log"
        rmdir "$runtime_dir" 2>/dev/null || true
        wezterm_socket=""
        wezterm_log=""
    fi
    active_roots=()
    if (( inter_trial_settle_ms > 0 )); then
        sleep "$inter_trial_settle_seconds"
    fi
}

run_round() {
    local panes=$1
    local scenario=$2
    local trial=$3
    local record=$4
    local offset index terminal
    local rotation_trial=$((trial > 0 ? trial : 1))

    for ((offset = 0; offset < terminal_count; offset++)); do
        if (( rotation_trial % 2 == 0 )); then
            index=$(( (rotation_trial - 1 - offset + terminal_count * 2) % terminal_count ))
        else
            index=$(( (rotation_trial - 1 + offset) % terminal_count ))
        fi
        terminal=${terminal_list[$index]}
        supports_panes "$terminal" "$panes" || continue
        progress_label="$terminal $scenario ${panes}p trial=$trial"
        progress_render
        run_trial "$terminal" "$panes" "$scenario" "$trial" "$record" "$offset"
        progress_done=$((progress_done + 1))
        progress_render
    done
}

write_summary() {
    awk -F, -v terminals="$terminals" -v panes="$pane_counts" '
        function sort(a, n,    i,j,t) { for (i=2;i<=n;i++) { t=a[i]; for(j=i-1;j&&a[j]>t;j--) a[j+1]=a[j]; a[j+1]=t } }
        function median(v, n,    a,i) { if (!n) return ""; split(v,a," "); sort(a,n); return n%2 ? a[(n+1)/2] : sprintf("%.3f", (a[n/2]+a[n/2+1])/2) }
        function mad(v, n,    a,b,i,m) { if (!n) return ""; m=median(v,n); split(v,a," "); for(i=1;i<=n;i++) b[i]=(a[i]>m?a[i]-m:m-a[i]); sort(b,n); return n%2 ? b[(n+1)/2] : sprintf("%.3f", (b[n/2]+b[n/2+1])/2) }
        function add(k, metric, value) { values[k SUBSEP metric]=values[k SUBSEP metric] " " value; count[k SUBSEP metric]++ }
        NR == 1 { next }
        {
            k=$1 SUBSEP $4
            if ($3 == "idle") {
                version[k]=$2; add(k,"startup",$6); add(k,"pss",$7); add(k,"rss",$8); add(k,"uss",$9); add(k,"cpu",$10)
                add(k,"rows_min",$22); add(k,"rows_max",$23); add(k,"columns_min",$24); add(k,"columns_max",$25)
            } else {
                add(k,"ingest",$11); add(k,"throughput",$12); if ($26 != "") add(k,"visual",$26); if ($28 != "") add(k,"visual_tail",$28)
            }
        }
        END {
            print "terminal,version,panes,startup_min_ms,startup_median_ms,startup_max_ms,pss_median_mib,rss_median_mib,uss_median_mib,idle_cpu_median_pct,ingest_median_ms,ingest_median_mib_s,startup_n,startup_mad_ms,pss_mad_mib,uss_mad_mib,ingest_n,ingest_mad_ms,rows_min,rows_max,columns_min,columns_max,visual_median_ms,visual_n,visual_mad_ms,visual_tail_median_ms,visual_tail_mad_ms"
            nt=split(terminals,ts," "); np=split(panes,ps," ")
            for (ti=1;ti<=nt;ti++) for (pi=1;pi<=np;pi++) {
                k=ts[ti] SUBSEP ps[pi]; n=count[k SUBSEP "startup"]; if (!n) continue
                split(values[k SUBSEP "startup"], startup, " "); sort(startup,n)
                pss=median(values[k SUBSEP "pss"],n)/1024; rss=median(values[k SUBSEP "rss"],n)/1024; uss=median(values[k SUBSEP "uss"],n)/1024; pss_mad=mad(values[k SUBSEP "pss"],n)/1024; uss_mad=mad(values[k SUBSEP "uss"],n)/1024
                ni=count[k SUBSEP "ingest"]; nv=count[k SUBSEP "visual"]
                printf "%s,%s,%s,%s,%s,%s,%.3f,%.3f,%.3f,%s,%s,%s,%d,%s,%.3f,%.3f,%d,%s,%s,%s,%s,%s,%s,%d,%s,%s,%s\n", ts[ti],version[k],ps[pi],startup[1],median(values[k SUBSEP "startup"],n),startup[n],pss,rss,uss,median(values[k SUBSEP "cpu"],n),median(values[k SUBSEP "ingest"],ni),median(values[k SUBSEP "throughput"],ni),n,mad(values[k SUBSEP "startup"],n),pss_mad,uss_mad,ni,mad(values[k SUBSEP "ingest"],ni),median(values[k SUBSEP "rows_min"],n),median(values[k SUBSEP "rows_max"],n),median(values[k SUBSEP "columns_min"],n),median(values[k SUBSEP "columns_max"],n),median(values[k SUBSEP "visual"],nv),nv,mad(values[k SUBSEP "visual"],nv),median(values[k SUBSEP "visual_tail"],nv),mad(values[k SUBSEP "visual_tail"],nv)
            }
        }
    ' "$raw_csv" >"$summary_csv"
}

for command in zig xdotool ps awk find sort date getconf sha256sum flock; do
    command -v "$command" >/dev/null || die "missing_command:$command"
done

for terminal in "${terminal_list[@]}"; do
    [[ "$terminal" == dintty || "$terminal" == dintty-production ]] || command -v "$terminal" >/dev/null ||
        die "missing_command:$terminal"
    [[ "$terminal" != konsole && "$terminal" != yakuake ]] ||
        command -v qdbus >/dev/null || die "missing_command:qdbus"
done
[[ -x "$workload" ]] || die "workload_not_executable:$workload"
(( terminal_count > 0 )) || die "missing_terminal_list"
for pane_count in $pane_counts $output_pane_counts; do
    case "$pane_count" in 1|2|4|8|16|32) ;; *) die "invalid_pane_count:$pane_count" ;; esac
done
[[ "$runs" =~ ^[1-9][0-9]*$ ]] || die "invalid_runs:$runs"
[[ "$output_lines" =~ ^[1-9][0-9]*$ ]] || die "invalid_output_lines:$output_lines"
[[ "$cpu_sample_ms" =~ ^[1-9][0-9]*$ ]] || die "invalid_cpu_sample_ms:$cpu_sample_ms"
[[ "$warmup" == 0 || "$warmup" == 1 ]] || die "invalid_warmup:$warmup"
[[ "$window_width" =~ ^[1-9][0-9]*$ ]] || die "invalid_window_width:$window_width"
[[ "$window_height" =~ ^[1-9][0-9]*$ ]] || die "invalid_window_height:$window_height"
[[ "$font_size" =~ ^[1-9][0-9]*([.][0-9]+)?$ ]] || die "invalid_font_size:$font_size"
[[ "$run_stamp" =~ ^[A-Za-z0-9._-]+$ && ${#run_stamp} -le 64 ]] ||
    die "invalid_stamp:$run_stamp"
[[ "$visual_timeout_ms" =~ ^[1-9][0-9]*$ ]] || die "invalid_visual_timeout_ms:$visual_timeout_ms"
[[ "$inter_trial_settle_ms" =~ ^[0-9]+$ ]] || die "invalid_inter_trial_settle_ms:$inter_trial_settle_ms"
[[ "$post_output_settle_ms" =~ ^[0-9]+$ ]] || die "invalid_post_output_settle_ms:$post_output_settle_ms"
[[ "$expect_idle_compaction" == 0 || "$expect_idle_compaction" == 1 ]] ||
    die "invalid_idle_compaction_expectation:$expect_idle_compaction"
[[ "$skip_build" == 0 || "$skip_build" == 1 ]] || die "invalid_skip_build:$skip_build"
[[ "$renderer" == cairo || "$renderer" == opengl ]] || die "invalid_renderer:$renderer"
case "$display_backend" in
    x11) ;;
    wayland)
        (( offscreen == 0 )) || die "wayland_offscreen_unsupported"
        [[ -n "${WAYLAND_DISPLAY:-}" ]] || die "wayland_display_missing"
        [[ -n "${XDG_RUNTIME_DIR:-}" &&
            -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]] ||
            die "wayland_socket_missing"
        ;;
    *) die "invalid_display_backend:$display_backend" ;;
esac
if [[ "$display_backend" == x11 ]]; then
    command -v import >/dev/null || die "visual_completion_requires_imagemagick"
fi

if (( offscreen == 1 )); then
    if [[ "${DINTTY_BENCH_XVFB:-}" != 1 ]]; then
        exec env DINTTY_BENCH_XVFB=1 \
            DINTTY_ISOLATED_DISPLAY_SCREEN="${window_width}x${window_height}x24" \
            DINTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=1800 \
            "$repo_root/scripts/run_isolated_x11.sh" "$0" "$@"
    fi
    "$repo_root/scripts/require_isolated_display.sh"
else
    "$repo_root/scripts/require_isolated_display.sh" --dedicated
fi

benchmark_lock="${XDG_RUNTIME_DIR:-/tmp}/dintty-terminal-benchmark-$(id -u).lock"
exec 9>"$benchmark_lock"
flock -n 9 || die "benchmark_busy:$benchmark_lock"
for artifact in "$raw_csv" "$summary_csv" "$metadata_file" "$process_tsv" "$checksums_file"; do
    [[ ! -e "$artifact" ]] || die "artifact_exists:$artifact"
done

mkdir -p "$benchmark_dir"
if (( skip_build == 0 )); then
    zig build -Doptimize=ReleaseFast
fi
[[ -x "$dintty_bin" ]] || die "missing_dintty_binary:$dintty_bin"

awk -v lines="$output_lines" 'BEGIN {
    for (line = 0; line < lines; line++) {
        color = 31 + (line % 7)
        printf "\033[%dmbench-%06d abcdefghijklmnopqrstuvwxyz 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ\033[0m\n", color, line
    }
}' >"$payload"
payload_bytes=$(wc -c <"$payload")

printf 'terminal,version,scenario,panes,trial,startup_ms,pss_kib,rss_kib,uss_kib,idle_cpu_pct,ingest_ms,ingest_mib_s,process_count,run_serial,order_index,launch_pid,root_pid,start_ns,ready_ns,go_ns,done_ns,rows_min,rows_max,columns_min,columns_max,visual_ms,visual_end_ns,visual_tail_ms\n' >"$raw_csv"
printf 'run_serial\tterminal\tscenario\tpanes\ttrial\tpid\tppid\texcluded\tpss_kib\trss_kib\tuss_kib\tcmdline\n' >"$process_tsv"
yakuake_before=$(pgrep -x yakuake 2>/dev/null | tr '\n' ' ' || true)
if [[ -n "$yakuake_before" ]]; then
    qdbus org.kde.yakuake /MainApplication \
        org.qtproject.Qt.QCoreApplication.quit >/dev/null 2>&1 ||
        kill $yakuake_before 2>/dev/null || true
    for _ in {1..250}; do
        pgrep -x yakuake >/dev/null 2>&1 || break
        sleep 0.02
    done
    pgrep -x yakuake >/dev/null 2>&1 && die "yakuake_stop_failed"
fi
{
    printf 'terminal_benchmark date=%s\n' "$(date --iso-8601=seconds)"
    printf 'kernel=%s\n' "$(uname -srmo)"
    printf 'cpu=%s\n' "$(awk -F: '/model name/ { sub(/^[ \t]+/, "", $2); print $2; exit }' /proc/cpuinfo)"
    printf 'session=%s desktop=%s offscreen=%s display=%s\n' "${XDG_SESSION_TYPE:-unknown}" "${XDG_CURRENT_DESKTOP:-unknown}" "$offscreen" "${DISPLAY:-unknown}"
    printf 'common_backend=%s renderer=%s window=%sx%s font_size=%s runs=%s panes=%s output_panes=%s output_lines=%s payload_bytes=%s idle_cpu_sample_ms=%s visual_timeout_ms=%s inter_trial_settle_ms=%s post_output_settle_ms=%s expect_idle_compaction=%s skip_build=%s terminal_order=rotated_snake\n' \
        "$backend_label" "$renderer" "$window_width" "$window_height" "$font_size" "$runs" "$pane_counts" \
        "$output_pane_counts" "$output_lines" "$payload_bytes" "$cpu_sample_ms" \
        "$visual_timeout_ms" "$inter_trial_settle_ms" "$post_output_settle_ms" \
        "$expect_idle_compaction" "$skip_build"
    printf 'yakuake_exclusive=true yakuake_pids_stopped_before=%s\n' "${yakuake_before:-none}"
    printf 'payload_sha256=%s workload_sha256=%s harness_sha256=%s dintty_binary_sha256=%s\n' \
        "$(sha256sum "$payload" | awk '{print $1}')" \
        "$(sha256sum "$workload" | awk '{print $1}')" \
        "$(sha256sum "${BASH_SOURCE[0]}" | awk '{print $1}')" \
        "$(sha256sum "$dintty_bin" | awk '{print $1}')"
    printf 'git_commit=%s git_dirty=%s git_diff_sha256=%s\n' \
        "$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)" \
        "$([[ -n "$(git -C "$repo_root" status --porcelain 2>/dev/null)" ]] && printf true || printf false)" \
        "$(git -C "$repo_root" diff --binary 2>/dev/null | sha256sum | awk '{print $1}')"
    printf 'cpu_count=%s cpu_governors=%s memory_kib=%s locale=%s compositor=%s\n' \
        "$(getconf _NPROCESSORS_ONLN)" \
        "$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort -u | tr '\n' ',' || printf unknown)" \
        "$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)" \
        "${LC_ALL:-${LANG:-unknown}}" "${XDG_CURRENT_DESKTOP:-unknown}"
    printf 'metric_startup=launch_to_all_workloads_spawned metric_output=writer_completion metric_visual=%s metric_visual_tail=%s metric_memory=process_tree_pss_excluding_workloads metric_cpu=process_tree_jiffies_excluding_workloads\n' \
        "$visual_metric" "$visual_tail_metric"
    printf 'parity_font=monospace:%s parity_geometry=%sx%s parity_scrollback_lines=1000 ghostty_scrollback_bytes=87000 yakuake_profile=isolated\n' \
        "$font_size" "$window_width" "$window_height"
    printf 'adapter_dintty=benchmark_mode_prebuilt_balanced_tree adapter_dintty_production=normal_windowed_single_pane adapter_terminator=prebuilt_config_tree adapter_konsole=dbus_splits adapter_kitty=remote_control_splits adapter_wezterm=cli_splits adapter_ghostty=keyboard_splits adapter_alacritty=single_pane adapter_yakuake=dbus_balanced_splits\n'
    { env | grep '^DINTTY_BENCH_' || true; } | sort | sed 's/^/environment_/'
    for terminal in $terminals; do
        printf '%s_version=%s\n' "$terminal" "$(version_for "$terminal")"
        if [[ "$terminal" == dintty || "$terminal" == dintty-production ]]; then
            printf '%s_executable=%s\n' "$terminal" "$dintty_bin"
        else
            printf '%s_executable=%s\n' "$terminal" "$(command -v "$terminal")"
        fi
    done
} >"$metadata_file"

for panes in $pane_counts; do
    for terminal in "${terminal_list[@]}"; do
        supports_panes "$terminal" "$panes" && progress_total=$((progress_total + runs + warmup))
    done
done
for panes in $output_pane_counts; do
    for terminal in "${terminal_list[@]}"; do
        supports_panes "$terminal" "$panes" && progress_total=$((progress_total + runs + warmup))
    done
done
progress_render

for panes in $pane_counts; do
    (( warmup == 0 )) || run_round "$panes" idle 0 0
    for ((trial = 1; trial <= runs; trial++)); do
        run_round "$panes" idle "$trial" 1
    done
done

for output_pane_count in $output_pane_counts; do
    (( warmup == 0 )) || run_round "$output_pane_count" output 0 0
    for ((trial = 1; trial <= runs; trial++)); do
        run_round "$output_pane_count" output "$trial" 1
    done
done

write_summary
yakuake_after=$(pgrep -x yakuake 2>/dev/null | tr '\n' ' ' || true)
printf 'yakuake_pids_after=%s yakuake_clean=%s\n' \
    "${yakuake_after:-none}" "$([[ -z "$yakuake_after" ]] && printf true || printf false)" \
    >>"$metadata_file"
[[ -z "$yakuake_after" ]] || die "yakuake_process_survived"
(cd "$benchmark_dir" && sha256sum \
    "$(basename "$raw_csv")" "$(basename "$summary_csv")" \
    "$(basename "$metadata_file")" "$(basename "$process_tsv")") >"$checksums_file"

progress_clear
printf 'terminal_benchmark complete=true raw=%s summary=%s metadata=%s processes=%s checksums=%s yakuake_exclusive=true\n' \
    "$raw_csv" "$summary_csv" "$metadata_file" "$process_tsv" "$checksums_file"
progress_label="complete"
progress_render
[[ ! -t 2 ]] || printf '\n' >&2
