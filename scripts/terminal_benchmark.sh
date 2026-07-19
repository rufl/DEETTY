#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workload="$repo_root/scripts/terminal_benchmark_workload.sh"
noctty_bin="$repo_root/zig-out/bin/noctty"
benchmark_dir="$repo_root/benchmarks"
runs=${NOCTTY_BENCH_RUNS:-3}
pane_counts=${NOCTTY_BENCH_PANES:-"1 2 4 8"}
output_panes=${NOCTTY_BENCH_OUTPUT_PANES:-4}
output_lines=${NOCTTY_BENCH_OUTPUT_LINES:-20000}
cpu_sample_ms=${NOCTTY_BENCH_CPU_SAMPLE_MS:-1000}
inter_trial_settle_ms=${NOCTTY_BENCH_INTER_TRIAL_SETTLE_MS:-1000}
warmup=${NOCTTY_BENCH_WARMUP:-1}
terminals=${NOCTTY_BENCH_TERMINALS:-"noctty konsole kitty wezterm terminator ghostty"}
read -r -a terminal_list <<<"$terminals"
terminal_count=${#terminal_list[@]}
inter_trial_settle_seconds=$(awk -v ms="$inter_trial_settle_ms" 'BEGIN { printf "%.3f", ms / 1000 }')
window_width=${NOCTTY_BENCH_WINDOW_WIDTH:-1200}
window_height=${NOCTTY_BENCH_WINDOW_HEIGHT:-800}
run_stamp=${NOCTTY_BENCH_STAMP:-$(date +%Y-%m-%d-%H%M%S)}
raw_csv=${NOCTTY_BENCH_RAW_CSV:-"$benchmark_dir/terminal-comparison-$run_stamp-raw.csv"}
summary_csv=${NOCTTY_BENCH_SUMMARY_CSV:-"$benchmark_dir/terminal-comparison-$run_stamp-summary.csv"}
metadata_file=${NOCTTY_BENCH_METADATA:-"$benchmark_dir/terminal-comparison-$run_stamp-metadata.txt"}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-terminal-benchmark.XXXXXX")
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

die() {
    printf 'terminal_benchmark error=%s\n' "$*" >&2
    exit 1
}

now_ms() {
    date +%s%3N
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
trap cleanup EXIT HUP INT TERM

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

wait_for_window() {
    local title=$1
    local timeout_ms=$2
    local pid=${3:-0}
    local deadline=$(( $(now_ms) + timeout_ms ))
    while (( $(now_ms) < deadline )); do
        window_id=$(xdotool search --onlyvisible --name "$title" 2>/dev/null | head -1 || true)
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

version_for() {
    local terminal=$1
    if [[ "$terminal" == noctty ]]; then
        "$noctty_bin" --version | awk '{print $2}'
    else
        pacman -Q "$terminal" | cut -d' ' -f2-
    fi
}

write_wezterm_config() {
    local path=$1
    cat >"$path" <<'EOF'
return {
  enable_wayland = false,
  font_size = 11.0,
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
    font = Monospace 11
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
font-size = 11
keybind = f8=new_split:auto
keybind = f9=goto_split:next
EOF
}

launch_terminal() {
    local terminal=$1
    local panes=$2
    local run_dir=$3
    local title=$4
    local config class
    launch_pid=0
    case "$terminal" in
        noctty)
            GDK_BACKEND=x11 "$noctty_bin" --native-grid-benchmark "$panes" \
                >"$run_dir/app.log" 2>&1 &
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
            KITTY_DISABLE_WAYLAND=1 NOCTTY_BENCH_SLOT=0 kitty --config NONE \
                --listen-on "unix:$kitty_socket" \
                -o allow_remote_control=socket-only \
                -o enabled_layouts=splits \
                -o linux_display_server=x11 \
                -o scrollback_lines=1000 \
                -o font_size=11.0 \
                -o remember_window_size=no \
                -o confirm_os_window_close=0 \
                --title "$title" "$workload" \
                >"$run_dir/app.log" 2>&1 &
            launch_pid=$!
            ;;
        wezterm)
            config="$run_dir/wezterm.lua"
            write_wezterm_config "$config"
            wezterm_class="NocttyBenchWezterm$trial_serial"
            wezterm_workspace="noctty-bench-$trial_serial"
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
            class="com.lichforge.NocttyBench$trial_serial"
            write_ghostty_config "$config" "$class" "$title"
            GDK_BACKEND=x11 ghostty --config-file="$config" \
                >"$run_dir/app.log" 2>&1 &
            launch_pid=$!
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
                --next-to "env:NOCTTY_BENCH_SLOT=$slot" \
                --title "$NOCTTY_BENCH_TITLE" \
                --env "NOCTTY_BENCH_SLOT=$next_slot" \
                --env "NOCTTY_BENCH_RUN_DIR=$NOCTTY_BENCH_RUN_DIR" \
                --env "NOCTTY_BENCH_TITLE=$NOCTTY_BENCH_TITLE" \
                --env "NOCTTY_BENCH_MODE=$NOCTTY_BENCH_MODE" \
                --env "NOCTTY_BENCH_PAYLOAD=$NOCTTY_BENCH_PAYLOAD" \
                "$workload" >/dev/null
            next_slot=$((next_slot + 1))
        done
        current=$((current * 2))
        level=$((level + 1))
    done
}

wezterm_initial_pane() {
    WEZTERM_UNIX_SOCKET="$wezterm_socket" wezterm cli --no-auto-start \
        list 2>>"$NOCTTY_BENCH_RUN_DIR/app.log" | \
        awk -v workspace="$wezterm_workspace" \
            'NR > 1 && index($0, workspace) { print $3; exit }'
}

create_wezterm_splits() {
    local panes=$1
    local initial=""
    local deadline=$(( $(now_ms) + 10000 ))
    local current level pane direction new_pane expected
    local -a pane_ids=()
    wait_for_socket "$wezterm_socket" || return 1
    while (( $(now_ms) < deadline )); do
        initial=$(wezterm_initial_pane)
        [[ -z "$initial" ]] || break
        sleep 0.02
    done
    if [[ -z "$initial" ]]; then
        WEZTERM_UNIX_SOCKET="$wezterm_socket" wezterm cli --no-auto-start list \
            >>"$NOCTTY_BENCH_RUN_DIR/app.log" 2>&1 || true
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
            wait_for_count "$NOCTTY_BENCH_RUN_DIR" spawned "$expected" 5000 ||
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
            wait_for_count "$NOCTTY_BENCH_RUN_DIR" spawned "$expected" 5000
            xdotool windowactivate --sync "$window_id"
            active_window=$(xdotool getactivewindow)
            [[ "$active_window" == "$window_id" ]] || return 1
            xdotool key --clearmodifiers F9
        done
        current=$((current * 2))
    done
}

create_splits() {
    local terminal=$1
    local panes=$2
    case "$terminal" in
        noctty|terminator) ;;
        konsole) create_konsole_splits "$panes" ;;
        kitty) create_kitty_splits "$panes" ;;
        wezterm) create_wezterm_splits "$panes" ;;
        ghostty) create_ghostty_splits "$panes" ;;
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

measure_memory() {
    local root=$1
    local pid pss rss
    local total_pss=0
    local total_rss=0
    local process_count=0
    while IFS= read -r pid; do
        [[ -z "${excluded_pids[$pid]+set}" ]] || continue
        [[ -r "/proc/$pid/status" ]] || continue
        pss=0
        if [[ -r "/proc/$pid/smaps_rollup" ]]; then
            pss=$(awk '/^Pss:/ { print $2; exit }' "/proc/$pid/smaps_rollup")
        fi
        rss=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$pid/status")
        total_pss=$((total_pss + ${pss:-0}))
        total_rss=$((total_rss + ${rss:-0}))
        process_count=$((process_count + 1))
    done < <(tree_pids "$root")
    printf '%d %d %d\n' "$total_pss" "$total_rss" "$process_count"
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
    local run_dir title start_ms ready_ms output_start output_end ingest_ms
    local pss_kib rss_kib process_count idle_cpu throughput version root_candidate runtime_dir

    trial_serial=$((trial_serial + 1))
    run_dir="$scratch/run-$trial_serial-$terminal-$panes-$scenario"
    title="NOCTTY-BENCH-$terminal-$trial_serial"
    mkdir -p "$run_dir"
    export NOCTTY_BENCH_RUN_DIR="$run_dir"
    export NOCTTY_BENCH_TITLE="$title"
    export NOCTTY_BENCH_MODE="$scenario"
    export NOCTTY_BENCH_PAYLOAD="$payload"
    export NOCTTY_BENCH_WORKLOAD="$workload"
    export NOCTTY_BENCH_SLOT=0

    start_ms=$(now_ms)
    launch_terminal "$terminal" "$panes" "$run_dir" "$title"
    wait_for_count "$run_dir" spawned 1 15000
    wait_for_window "$title" 15000 "$launch_pid" || {
        tail -80 "$run_dir/app.log" >&2 || true
        die "window_not_found:$terminal"
    }
    enforce_window_geometry || die "window_geometry:$terminal"
    create_splits "$terminal" "$panes" || {
        tail -80 "$run_dir/app.log" >&2 || true
        die "split_creation:$terminal"
    }
    wait_for_count "$run_dir" spawned "$panes" 20000
    ready_ms=$(now_ms)
    window_pid=$(xdotool getwindowpid "$window_id" 2>/dev/null || true)
    root_candidate=${window_pid:-$launch_pid}
    [[ "$root_candidate" =~ ^[0-9]+$ ]] || root_candidate=$launch_pid
    active_roots=("$launch_pid" "$root_candidate")

    output_start=$(now_ms)
    : >"$run_dir/go"
    wait_for_count "$run_dir" done "$panes" 60000
    output_end=$(now_ms)
    ingest_ms=$((output_end - output_start))
    sleep 0.25

    if (( record == 1 )); then
        build_excluded_pids "$run_dir"
        read -r pss_kib rss_kib process_count < <(measure_memory "$root_candidate")
        (( process_count > 0 && pss_kib > 0 && rss_kib > 0 )) ||
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
        printf '%s,%s,%s,%d,%d,%d,%d,%d,%s,%s,%s,%d\n' \
            "$terminal" "$version" "$scenario" "$panes" "$trial" \
            "$((ready_ms - start_ms))" "$pss_kib" "$rss_kib" \
            "$idle_cpu" "$ingest_ms" "$throughput" "$process_count" >>"$raw_csv"
        printf 'terminal_benchmark terminal=%s scenario=%s panes=%d trial=%d startup_ms=%d pss_kib=%d rss_kib=%d idle_cpu_pct=%s ingest_ms=%s throughput_mib_s=%s processes=%d\n' \
            "$terminal" "$scenario" "$panes" "$trial" \
            "$((ready_ms - start_ms))" "$pss_kib" "$rss_kib" \
            "$idle_cpu" "${ingest_ms:-na}" "${throughput:-na}" "$process_count"
    fi

    signal_workloads "$run_dir"
    wait_for_exit "$root_candidate"
    wait "$launch_pid" 2>/dev/null || true
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

    for ((offset = 0; offset < terminal_count; offset++)); do
        if (( trial % 2 == 0 )); then
            index=$(( (trial - 1 - offset + terminal_count * 2) % terminal_count ))
        else
            index=$(( (trial - 1 + offset) % terminal_count ))
        fi
        terminal=${terminal_list[$index]}
        run_trial "$terminal" "$panes" "$scenario" "$trial" "$record"
    done
}

median_values() {
    sort -n | awk '
        { values[NR] = $1 }
        END {
            if (NR == 0) { print ""; exit }
            if (NR % 2 == 1) print values[(NR + 1) / 2]
            else printf "%.3f\n", (values[NR / 2] + values[NR / 2 + 1]) / 2
        }
    '
}

summary_value() {
    local terminal=$1
    local scenario=$2
    local panes=$3
    local column=$4
    awk -F, -v terminal="$terminal" -v scenario="$scenario" \
        -v panes="$panes" -v column="$column" \
        '$1 == terminal && $3 == scenario && $4 == panes && $column != "" { print $column }' \
        "$raw_csv" | median_values
}

write_summary() {
    local terminal panes version startup_min startup_median startup_max pss rss cpu ingest throughput
    printf 'terminal,version,panes,startup_min_ms,startup_median_ms,startup_max_ms,pss_median_mib,rss_median_mib,idle_cpu_median_pct,ingest_median_ms,ingest_median_mib_s\n' >"$summary_csv"
    for terminal in $terminals; do
        version=$(version_for "$terminal")
        for panes in $pane_counts; do
            startup_min=$(awk -F, -v t="$terminal" -v p="$panes" \
                '$1 == t && $3 == "idle" && $4 == p { print $6 }' "$raw_csv" | sort -n | head -1)
            startup_median=$(summary_value "$terminal" idle "$panes" 6)
            startup_max=$(awk -F, -v t="$terminal" -v p="$panes" \
                '$1 == t && $3 == "idle" && $4 == p { print $6 }' "$raw_csv" | sort -n | tail -1)
            pss=$(summary_value "$terminal" idle "$panes" 7)
            rss=$(summary_value "$terminal" idle "$panes" 8)
            cpu=$(summary_value "$terminal" idle "$panes" 9)
            ingest=""
            throughput=""
            if (( panes == output_panes )); then
                ingest=$(summary_value "$terminal" output "$panes" 10)
                throughput=$(summary_value "$terminal" output "$panes" 11)
            fi
            pss=$(awk -v value="$pss" 'BEGIN { printf "%.3f", value / 1024 }')
            rss=$(awk -v value="$rss" 'BEGIN { printf "%.3f", value / 1024 }')
            printf '%s,%s,%d,%s,%s,%s,%s,%s,%s,%s,%s\n' \
                "$terminal" "$version" "$panes" "$startup_min" \
                "$startup_median" "$startup_max" "$pss" "$rss" \
                "$cpu" "$ingest" "$throughput" >>"$summary_csv"
        done
    done
}

for command in zig xdotool qdbus pacman ps awk find sort date getconf \
    konsole kitty wezterm terminator ghostty; do
    command -v "$command" >/dev/null || die "missing_command:$command"
done
[[ -x "$workload" ]] || die "workload_not_executable:$workload"
(( terminal_count > 0 )) || die "missing_terminal_list"
for pane_count in $pane_counts "$output_panes"; do
    case "$pane_count" in 1|2|4|8) ;; *) die "invalid_pane_count:$pane_count" ;; esac
done
[[ "$runs" =~ ^[1-9][0-9]*$ ]] || die "invalid_runs:$runs"
[[ "$inter_trial_settle_ms" =~ ^[0-9]+$ ]] || die "invalid_inter_trial_settle_ms:$inter_trial_settle_ms"

mkdir -p "$benchmark_dir"
zig build -Doptimize=ReleaseFast
[[ -x "$noctty_bin" ]] || die "missing_noctty_binary:$noctty_bin"

awk -v lines="$output_lines" 'BEGIN {
    for (line = 0; line < lines; line++) {
        color = 31 + (line % 7)
        printf "\033[%dmbench-%06d abcdefghijklmnopqrstuvwxyz 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ\033[0m\n", color, line
    }
}' >"$payload"
payload_bytes=$(wc -c <"$payload")

printf 'terminal,version,scenario,panes,trial,startup_ms,pss_kib,rss_kib,idle_cpu_pct,ingest_ms,ingest_mib_s,process_count\n' >"$raw_csv"
yakuake_before=$(pgrep -x yakuake 2>/dev/null | tr '\n' ' ' || true)

{
    printf 'terminal_benchmark date=%s\n' "$(date --iso-8601=seconds)"
    printf 'kernel=%s\n' "$(uname -srmo)"
    printf 'cpu=%s\n' "$(awk -F: '/model name/ { sub(/^[ \t]+/, "", $2); print $2; exit }' /proc/cpuinfo)"
    printf 'session=%s desktop=%s\n' "${XDG_SESSION_TYPE:-unknown}" "${XDG_CURRENT_DESKTOP:-unknown}"
    printf 'common_backend=x11_xwayland window=%sx%s runs=%s panes=%s output_panes=%s output_lines=%s payload_bytes=%s idle_cpu_sample_ms=%s inter_trial_settle_ms=%s terminal_order=rotated_snake\n' \
        "$window_width" "$window_height" "$runs" "$pane_counts" \
        "$output_panes" "$output_lines" "$payload_bytes" "$cpu_sample_ms" \
        "$inter_trial_settle_ms"
    printf 'yakuake_excluded=true yakuake_pids_before=%s\n' "${yakuake_before:-none}"
    for terminal in $terminals; do
        printf '%s_version=%s\n' "$terminal" "$(version_for "$terminal")"
    done
} >"$metadata_file"

if (( warmup == 1 )); then
    run_round 1 idle 1 0
fi

for panes in $pane_counts; do
    for ((trial = 1; trial <= runs; trial++)); do
        run_round "$panes" idle "$trial" 1
    done
done

for ((trial = 1; trial <= runs; trial++)); do
    run_round "$output_panes" output "$trial" 1
done

write_summary
yakuake_after=$(pgrep -x yakuake 2>/dev/null | tr '\n' ' ' || true)
printf 'yakuake_pids_after=%s yakuake_untouched=%s\n' \
    "${yakuake_after:-none}" "$([[ "$yakuake_before" == "$yakuake_after" ]] && printf true || printf false)" \
    >>"$metadata_file"
[[ "$yakuake_before" == "$yakuake_after" ]] || die "yakuake_process_set_changed"

printf 'terminal_benchmark complete=true raw=%s summary=%s metadata=%s yakuake_excluded=true\n' \
    "$raw_csv" "$summary_csv" "$metadata_file"
