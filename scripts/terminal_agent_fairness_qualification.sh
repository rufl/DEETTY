#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch_parent=${NOCTTY_FAIRNESS_PARENT:-$repo_root}
case "$scratch_parent" in
    /*) ;;
    *) scratch_parent="$repo_root/$scratch_parent" ;;
esac
scratch=$(mktemp -d "$scratch_parent/.noctty-terminal-fairness.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

run_mode() {
    mode=$1
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache-$mode"
    mode_tmp="$scratch/tmp-$mode"
    mode_xdg_cache="$scratch/xdg-cache-$mode"
    mkdir -p "$mode_tmp" "$mode_xdg_cache"
    TMPDIR="$mode_tmp" XDG_CACHE_HOME="$mode_xdg_cache" \
        ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build terminal-agent-fairness-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache"

    "$prefix/bin/noctty-terminal-agent-fairness" >"$scratch/output-$mode"
}

cd "$repo_root"
run_mode Debug
run_mode ReleaseSafe

for mode in Debug ReleaseSafe; do
    output=$(cat "$scratch/output-$mode")
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -E \
        "^terminal_agent_fairness_qualification mode=$mode panes=30 flood_panes=1 marker_panes=29 flood_bytes=[1-9][0-9]* marker_p50_ns=[1-9][0-9]* marker_p95_ns=[1-9][0-9]* marker_p99_ns=[1-9][0-9]* marker_max_ns=[1-9][0-9]* all_markers=true shared_pump_scratch=true glib_fd_sources=true large_paste_bytes=8388608 paste_enqueue_ns=[1-9][0-9]* paste_drain_ns=[1-9][0-9]* paste_queue_exercised=true paste_pending_teardown=true paste_teardown_ns=[1-9][0-9]* allocator_leak_free=true allocator_residual_bytes=0 process_residual=0 assertions=true$" \
        >/dev/null
done

echo 'terminal_agent_fairness_matrix debug=true release_safe=true panes=30 flood_panes=1 marker_panes=29 all_markers=true shared_pump_scratch=true glib_fd_sources=true large_paste_bytes=8388608 paste_queue_exercised=true paste_drained=true paste_pending_teardown=true allocator_leak_free=true process_residual=0 scratch_clean=true'
