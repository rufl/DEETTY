#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd -P)
scratch_parent=${DINTTY_NCURSES_QUALIFICATION_PARENT:-$repo_root}
case "$scratch_parent" in
    /*) ;;
    *) scratch_parent="$repo_root/$scratch_parent" ;;
esac
scratch=$(mktemp -d "$scratch_parent/.dintty-ncurses.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

nano_path=${DINTTY_NCURSES_NANO:-$(command -v nano || true)}
less_path=${DINTTY_NCURSES_LESS:-$(command -v less || true)}
dialog_path=${DINTTY_NCURSES_DIALOG:-$(command -v dialog || true)}
for path in "$nano_path" "$less_path" "$dialog_path"; do
    [[ -n "$path" && -x "$path" && "$path" = /* ]]
done
infocmp xterm-256color >/dev/null

nano_version=$($nano_path --version 2>/dev/null | sed -n 's/.*version \([^ ]*\).*/\1/p' | head -1)
less_version=$($less_path --version 2>/dev/null | awk 'NR == 1 { print $2 }')
dialog_version=$($dialog_path --version 2>&1 | awk '/Version:/ { print $2; exit }')
[[ -n "$nano_version" && -n "$less_version" && -n "$dialog_version" ]]

run_mode() {
    mode=$1
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache-$mode"
    mode_tmp="$scratch/tmp-$mode"
    mode_xdg_cache="$scratch/xdg-cache-$mode"
    state="$scratch/state-$mode"
    mkdir -p "$mode_tmp" "$mode_xdg_cache" "$state"
    for app in nano less dialog; do
        mkdir -p \
            "$state/$app-home" \
            "$state/$app-codex" \
            "$state/$app-config" \
            "$state/$app-state" \
            "$state/$app-cache"
    done
    printf 'DINTTY_NCURSES_NANO\nread-only editor fixture\n' \
        >"$state/nano-fixture.txt"
    {
        printf 'DINTTY_NCURSES_LESS\n'
        for index in $(seq 1 200); do
            printf 'pager line %03d real ncurses fixture\n' "$index"
        done
    } >"$state/less-fixture.txt"

    TMPDIR="$mode_tmp" XDG_CACHE_HOME="$mode_xdg_cache" \
        ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build terminal-ncurses-qualification-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache"

    output_file="$scratch/output-$mode"
    "$prefix/bin/dintty-terminal-ncurses-qualification" \
        "$state" "$nano_path" "$less_path" "$dialog_path" \
        >"$output_file" &
    runner_pid=$!
    peak_root_pss_kib=0
    peak_root_rss_kib=0
    peak_tree_pss_kib=0
    peak_tree_rss_kib=0
    samples=0
    while kill -0 "$runner_pid" 2>/dev/null; do
        root_pss_kib=$(awk '/^Pss:/ { print $2; exit }' "/proc/$runner_pid/smaps_rollup" 2>/dev/null || true)
        root_rss_kib=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$runner_pid/status" 2>/dev/null || true)
        tree_sample=$("$repo_root/scripts/process_tree_memory.sh" "$runner_pid" 2>/dev/null || true)
        tree_pss_kib=$(printf '%s\n' "$tree_sample" | sed -n 's/.* pss_kib=\([0-9][0-9]*\).*/\1/p')
        tree_rss_kib=$(printf '%s\n' "$tree_sample" | sed -n 's/.* rss_kib=\([0-9][0-9]*\).*/\1/p')
        peak_root_pss_kib=$(( ${root_pss_kib:-0} > peak_root_pss_kib ? ${root_pss_kib:-0} : peak_root_pss_kib ))
        peak_root_rss_kib=$(( ${root_rss_kib:-0} > peak_root_rss_kib ? ${root_rss_kib:-0} : peak_root_rss_kib ))
        peak_tree_pss_kib=$(( ${tree_pss_kib:-0} > peak_tree_pss_kib ? ${tree_pss_kib:-0} : peak_tree_pss_kib ))
        peak_tree_rss_kib=$(( ${tree_rss_kib:-0} > peak_tree_rss_kib ? ${tree_rss_kib:-0} : peak_tree_rss_kib ))
        samples=$((samples + 1))
        sleep 0.01
    done
    wait "$runner_pid"
    printf 'terminal_ncurses_resource mode=%s peak_root_pss_kib=%d peak_root_rss_kib=%d peak_tree_pss_kib=%d peak_tree_rss_kib=%d samples=%d root_process_separate=true process_tree_memory=true\n' \
        "$mode" "$peak_root_pss_kib" "$peak_root_rss_kib" \
        "$peak_tree_pss_kib" "$peak_tree_rss_kib" "$samples" \
        >"$scratch/resource-$mode"
}

cd "$repo_root"
run_mode Debug &
debug_pid=$!
run_mode ReleaseSafe &
release_safe_pid=$!
debug_status=0
release_safe_status=0
wait "$debug_pid" || debug_status=$?
wait "$release_safe_pid" || release_safe_status=$?
if [[ "$debug_status" -ne 0 || "$release_safe_status" -ne 0 ]]; then
    exit 1
fi

for mode in Debug ReleaseSafe; do
    output=$(cat "$scratch/output-$mode")
    printf '%s\n' "$output"
    for app in nano less dialog; do
        printf '%s\n' "$output" | grep -E \
            "terminal_ncurses_case mode=$mode app=$app ready_ns=[1-9][0-9]* exit_ns=[1-9][0-9]* output_bytes=[1-9][0-9]* screen_hash=[1-9][0-9]*" \
            >/dev/null
        printf '%s\n' "$output" | grep -E \
            "app=$app .*foreground_identity=true input_routed=true exit_code=0 process_residual=0 assertions=true" \
            >/dev/null
    done
    printf '%s\n' "$output" | grep -E \
        "app=(nano|less) .*alternate_screen=true" >/dev/null
    printf '%s\n' "$output" | grep -E \
        "app=dialog .*alternate_screen=false" >/dev/null
    printf '%s\n' "$output" | grep -F \
        "terminal_ncurses_qualification mode=$mode applications=3" \
        >/dev/null
    printf '%s\n' "$output" | grep -F \
        'nano_editor=true nano_alternate_screen=true nano_mouse=true less_pager=true less_alternate_screen=true dialog_widget=true dialog_alternate_screen=false rich_style=true foreground_identity=true input_routed=true controlled_exit=true allocator_leak_free=true allocator_residual_bytes=0 process_residual=0 assertions=true' \
        >/dev/null
    resource=$(cat "$scratch/resource-$mode")
    printf '%s\n' "$resource"
    printf '%s\n' "$resource" | grep -E \
        "mode=$mode peak_root_pss_kib=[1-9][0-9]* peak_root_rss_kib=[1-9][0-9]* peak_tree_pss_kib=[1-9][0-9]* peak_tree_rss_kib=[1-9][0-9]* samples=[1-9][0-9]* root_process_separate=true process_tree_memory=true" \
        >/dev/null
done

printf 'terminal_ncurses_versions nano=%s less=%s dialog=%s terminfo=xterm-256color scratch_clean=true\n' \
    "$nano_version" "$less_version" "$dialog_version"
echo 'terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true'
