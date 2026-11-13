#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
history_parent=${DINTTY_HISTORY_PARENT:-"$repo_root"}
case "$history_parent" in
    /*) ;;
    *) history_parent="$repo_root/$history_parent" ;;
esac
scratch=$(mktemp -d "$history_parent/.dintty-history-qualification.XXXXXX")
cleanup() {
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

local_cache=${DINTTY_ZIG_CACHE_DIR:-"$scratch/zig-local"}
global_cache=${DINTTY_ZIG_GLOBAL_CACHE_DIR:-"$scratch/zig-global"}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$scratch/xdg-cache"}
export TMPDIR="$scratch/tmp"
mkdir -p "$local_cache" "$global_cache" "$XDG_CACHE_HOME" "$TMPDIR"

for mode in Debug ReleaseSafe; do
    prefix="$scratch/$mode"
    mkdir -p "$prefix"
    ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build smoke-binaries \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache"
    output=$(
        "$prefix/bin/dintty-smoke" --terminal-history-qualification
    )
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -E \
        'terminal_history_qualification lines=100000 direct_bytes=[1-9][0-9]* compact_bytes=[1-9][0-9]* compact_ratio_bp=[1-9][0-9]* reflow_bytes=[1-9][0-9]* reflow_narrow=true reflow_wide=true shrink_bytes=[1-9][0-9]* grow_shrink_cycles=4 cold_memory_only=true passed=true' \
        >/dev/null
    printf '%s\n' "$output" | grep -E \
        'terminal_idle_history_qualification columns=120 rows=40 history=1000 before_bytes=[1-9][0-9]* after_bytes=[1-9][0-9]* saved_bytes=[1-9][0-9]* steps=[1-9][0-9]* rows_per_step=64 content_preserved=true resumed_output_regrows=true passed=true' \
        >/dev/null
done

echo 'terminal_history_matrix debug=true release_safe=true lines=100000 compact=true reflow=true grow_shrink=true idle_compaction=true idle_regrow=true scratch_clean=true'
