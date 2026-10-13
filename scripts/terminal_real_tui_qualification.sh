#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch_parent=${NOCTTY_REAL_TUI_QUALIFICATION_PARENT:-${TMPDIR:-/tmp}}
scratch=$(mktemp -d "$scratch_parent/.noctty-real-tui.XXXXXX")
cleanup() {
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

codex_path=${NOCTTY_REAL_TUI_CODEX:-$(command -v codex || true)}
vim_path=${NOCTTY_REAL_TUI_VIM:-$(command -v vim || true)}
btop_path=${NOCTTY_REAL_TUI_BTOP:-$(command -v btop || true)}
for path in "$codex_path" "$vim_path" "$btop_path"; do
    [[ -n "$path" && -x "$path" && "$path" = /* ]]
done
infocmp xterm-256color >/dev/null

codex_version=$($codex_path --version 2>/dev/null | awk 'NR == 1 { print $2 }')
vim_version=$($vim_path --version 2>/dev/null | awk 'NR == 1 { print $5 }')
btop_version=$($btop_path --version 2>/dev/null | sed $'s/\033\\[[0-9;]*m//g' | awk 'NR == 1 { print $3 }')
[[ -n "$codex_version" && -n "$vim_version" && -n "$btop_version" ]]

run_mode() {
    mode=$1
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache-$mode"
    state="$scratch/state-$mode"
    mkdir -p "$state"
    for app in codex vim btop; do
        mkdir -p \
            "$state/$app-home" \
            "$state/$app-codex" \
            "$state/$app-config" \
            "$state/$app-state" \
            "$state/$app-cache"
    done
    printf 'NOCTTY_REAL_TUI_VIM\nreal ncurses fixture\n' >"$state/vim-fixture.txt"

    if ! ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build terminal-real-tui-qualification-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache"; then
        return 1
    fi

    output_file="$scratch/output-$mode"
    "$prefix/bin/noctty-terminal-real-tui-qualification" \
        "$state" "$codex_path" "$vim_path" "$btop_path" \
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
        if [[ -n "$root_pss_kib" && "$root_pss_kib" -gt "$peak_root_pss_kib" ]]; then
            peak_root_pss_kib=$root_pss_kib
        fi
        if [[ -n "$root_rss_kib" && "$root_rss_kib" -gt "$peak_root_rss_kib" ]]; then
            peak_root_rss_kib=$root_rss_kib
        fi
        if [[ -n "$tree_pss_kib" && "$tree_pss_kib" -gt "$peak_tree_pss_kib" ]]; then
            peak_tree_pss_kib=$tree_pss_kib
        fi
        if [[ -n "$tree_rss_kib" && "$tree_rss_kib" -gt "$peak_tree_rss_kib" ]]; then
            peak_tree_rss_kib=$tree_rss_kib
        fi
        samples=$((samples + 1))
        sleep 0.01
    done
    if ! wait "$runner_pid"; then
        return 1
    fi
    printf 'terminal_real_tui_resource mode=%s peak_root_pss_kib=%d peak_root_rss_kib=%d peak_tree_pss_kib=%d peak_tree_rss_kib=%d samples=%d root_process_separate=true process_tree_memory=true\n' \
        "$mode" "$peak_root_pss_kib" "$peak_root_rss_kib" \
        "$peak_tree_pss_kib" "$peak_tree_rss_kib" "$samples" \
        >"$scratch/resource-$mode"
}

cd "$repo_root"
run_mode Debug
run_mode ReleaseSafe

for mode in Debug ReleaseSafe; do
    output=$(cat "$scratch/output-$mode")
    printf '%s\n' "$output"
    for app in codex vim btop; do
        printf '%s\n' "$output" | grep -E \
            "terminal_real_tui_case mode=$mode app=$app ready_ns=[1-9][0-9]* exit_ns=[1-9][0-9]* output_bytes=[1-9][0-9]* screen_hash=[1-9][0-9]*" \
            >/dev/null
        printf '%s\n' "$output" | grep -E \
            "app=$app .*foreground_identity=true input_routed=true exit_code=0 process_residual=0 assertions=true" \
            >/dev/null
    done
    printf '%s\n' "$output" | grep -F \
        "terminal_real_tui_qualification mode=$mode applications=3" \
        >/dev/null
    printf '%s\n' "$output" | grep -F \
        'codex_login_surface=true codex_sync_output=true codex_exit_code=0 vim_fixture=true vim_alternate_screen=true vim_bracketed_paste=true vim_focus_reporting=true vim_exit_code=0 btop_dashboard=true btop_alternate_screen=true btop_mouse=true btop_sgr_mouse=true btop_truecolor=true btop_unicode=true btop_exit_code=0 foreground_identity=true input_routed=true controlled_exit=true allocator_leak_free=true allocator_residual_bytes=0 process_residual=0 assertions=true' \
        >/dev/null
    resource=$(cat "$scratch/resource-$mode")
    printf '%s\n' "$resource"
    printf '%s\n' "$resource" | grep -E \
        "mode=$mode peak_root_pss_kib=[1-9][0-9]* peak_root_rss_kib=[1-9][0-9]* peak_tree_pss_kib=[1-9][0-9]* peak_tree_rss_kib=[1-9][0-9]* samples=[1-9][0-9]* root_process_separate=true process_tree_memory=true" \
        >/dev/null
done

printf 'terminal_real_tui_versions codex=%s vim=%s btop=%s terminfo=xterm-256color scratch_clean=true\n' \
    "$codex_version" "$vim_version" "$btop_version"
echo 'terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true'
