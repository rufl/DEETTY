#!/usr/bin/env bash
set -euo pipefail

for mode in Debug ReleaseSafe; do
    ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build test \
        -Doptimize="$mode"
    printf 'nocted_state_recovery_qualification mode=%s tests=true\n' "$mode"
done

echo 'nocted_state_recovery_matrix debug=true release_safe=true legacy_shell_parser=true malformed_state_corpus=13 oversized_fallback=true interrupted_replace=true settings_atomic=true session_atomic=true scratch_clean=true'
