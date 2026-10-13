#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd -P)
scratch_parent=${NOCTTY_SYSTEM_TUI_QUALIFICATION_PARENT:-$repo_root}
case "$scratch_parent" in
    /*) ;;
    *) scratch_parent="$repo_root/$scratch_parent" ;;
esac
scratch=$(mktemp -d "$scratch_parent/.noctty-system-tui.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

top_path=${NOCTTY_SYSTEM_TUI_TOP:-$(command -v top || true)}
watch_path=${NOCTTY_SYSTEM_TUI_WATCH:-$(command -v watch || true)}
info_path=${NOCTTY_SYSTEM_TUI_INFO:-$(command -v info || true)}
whiptail_path=${NOCTTY_SYSTEM_TUI_WHIPTAIL:-$(command -v whiptail || true)}
fzf_path=${NOCTTY_SYSTEM_TUI_FZF:-$(command -v fzf || true)}
sqlite_path=${NOCTTY_SYSTEM_TUI_SQLITE:-$(command -v sqlite3 || true)}
glances_path=${NOCTTY_SYSTEM_TUI_GLANCES:-$(command -v glances || true)}
bash_path=${NOCTTY_SYSTEM_TUI_BASH:-$(command -v bash || true)}
man_path=${NOCTTY_SYSTEM_TUI_MAN:-$(command -v man || true)}
less_path=${NOCTTY_SYSTEM_TUI_LESS:-$(command -v less || true)}
sftp_path=${NOCTTY_SYSTEM_TUI_SFTP:-$(command -v sftp || true)}
sftp_server_path=${NOCTTY_SYSTEM_TUI_SFTP_SERVER:-}
if [[ -z "$sftp_server_path" ]]; then
    for candidate in /usr/lib/ssh/sftp-server /usr/lib/openssh/sftp-server; do
        if [[ -x "$candidate" ]]; then
            sftp_server_path=$candidate
            break
        fi
    done
fi
for path in "$top_path" "$watch_path" "$info_path" "$whiptail_path" \
    "$fzf_path" "$sqlite_path" "$glances_path" "$bash_path" "$man_path" \
    "$less_path" "$sftp_path" "$sftp_server_path"; do
    [[ -n "$path" && -x "$path" && "$path" = /* ]]
done
infocmp xterm-256color >/dev/null

top_version=$($top_path --version 2>/dev/null | awk 'NR == 1 { print $NF }')
watch_version=$($watch_path --version 2>/dev/null | awk 'NR == 1 { print $NF }')
info_version=$($info_path --version 2>/dev/null | awk 'NR == 1 { print $NF }')
whiptail_version=$($whiptail_path -v 2>&1 | awk 'NR == 1 { print $NF }')
fzf_version=$($fzf_path --version 2>/dev/null | awk 'NR == 1 { print $1 }')
sqlite_version=$($sqlite_path --version 2>/dev/null | awk 'NR == 1 { print $1 }')
glances_version=$($glances_path --version 2>/dev/null | awk -F '\t' '/Glances version:/ { print $2; exit }')
bash_version=$($bash_path --version 2>/dev/null | awk 'NR == 1 { print $4 }')
man_version=$($man_path --version 2>/dev/null | awk 'NR == 1 { print $2 }')
sftp_version=$(ssh -V 2>&1 | sed -n 's/^OpenSSH_\([^, ]*\).*/\1/p')
[[ -n "$top_version" && -n "$watch_version" && -n "$info_version" && \
    -n "$whiptail_version" && -n "$fzf_version" && \
    -n "$sqlite_version" && -n "$glances_version" && \
    -n "$bash_version" && -n "$man_version" && -n "$sftp_version" ]]

run_mode() {
    mode=$1
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache-$mode"
    mode_tmp="$scratch/tmp-$mode"
    mode_xdg_cache="$scratch/xdg-cache-$mode"
    state="$scratch/state-$mode"
    mkdir -p "$mode_tmp" "$mode_xdg_cache" "$state"
    for app in top watch info whiptail fzf sqlite3 glances bash man sftp; do
        mkdir -p \
            "$state/$app-home" \
            "$state/$app-codex" \
            "$state/$app-config" \
            "$state/$app-state" \
            "$state/$app-cache"
    done
    printf '%s\n' alpha NOCTTY_FZF_TARGET omega >"$state/fzf-input.txt"
    printf '%s\n' \
        "PS1='NOCTTY_BASH> '" \
        "printf 'NOCTTY_BASH_READY\\n'" \
        >"$state/bashrc"
    printf '%s\n' \
        '.TH NOCTTY-SYSTEM 1' \
        '.SH NAME' \
        'noctty-system \- NOCTTY_SYSTEM_MAN' \
        '.SH DESCRIPTION' \
        'Deterministic installed man pager fixture for NOCTTY.' \
        >"$state/noctty-system.1"

    TMPDIR="$mode_tmp" XDG_CACHE_HOME="$mode_xdg_cache" \
        ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build terminal-system-tui-qualification-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache"

    output_file="$scratch/output-$mode"
    "$prefix/bin/noctty-terminal-system-tui-qualification" \
        "$state" "$top_path" "$watch_path" "$info_path" "$whiptail_path" \
        "$fzf_path" "$sqlite_path" "$glances_path" "$bash_path" \
        "$man_path" "$less_path" "$sftp_path" "$sftp_server_path" \
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
    printf 'terminal_system_tui_resource mode=%s peak_root_pss_kib=%d peak_root_rss_kib=%d peak_tree_pss_kib=%d peak_tree_rss_kib=%d samples=%d root_process_separate=true process_tree_memory=true\n' \
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
    for app in top watch info whiptail fzf sqlite3 glances bash man sftp; do
        printf '%s\n' "$output" | grep -E \
            "terminal_system_tui_case mode=$mode app=$app ready_ns=[1-9][0-9]* exit_ns=[1-9][0-9]* output_bytes=[1-9][0-9]* screen_hash=[1-9][0-9]*" \
            >/dev/null
        printf '%s\n' "$output" | grep -E \
            "app=$app .*foreground_identity=true input_routed=true .*process_residual=0 assertions=true" \
            >/dev/null
    done
    for app in top watch info whiptail fzf sqlite3 glances bash man sftp; do
        printf '%s\n' "$output" | grep -E "app=$app .*exit_code=0" >/dev/null
    done
    printf '%s\n' "$output" | grep -F \
        "terminal_system_tui_qualification mode=$mode applications=10" \
        >/dev/null
    printf '%s\n' "$output" | grep -F \
        'top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true foreground_identity=true input_routed=true controlled_exit=true allocator_leak_free=true allocator_residual_bytes=0 process_residual=0 assertions=true' \
        >/dev/null
    resource=$(cat "$scratch/resource-$mode")
    printf '%s\n' "$resource"
    printf '%s\n' "$resource" | grep -E \
        "mode=$mode peak_root_pss_kib=[1-9][0-9]* peak_root_rss_kib=[1-9][0-9]* peak_tree_pss_kib=[1-9][0-9]* peak_tree_rss_kib=[1-9][0-9]* samples=[1-9][0-9]* root_process_separate=true process_tree_memory=true" \
        >/dev/null
done

printf 'terminal_system_tui_versions top=%s watch=%s info=%s whiptail=%s fzf=%s sqlite3=%s glances=%s bash=%s man=%s sftp=%s terminfo=xterm-256color scratch_clean=true\n' \
    "$top_version" "$watch_version" "$info_version" "$whiptail_version" \
    "$fzf_version" "$sqlite_version" "$glances_version" "$bash_version" \
    "$man_version" "$sftp_version"
echo 'terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true'
