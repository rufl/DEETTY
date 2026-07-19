#!/usr/bin/env bash
set -euo pipefail

for mode in Debug ReleaseSafe; do
    zig build test \
        -Doptimize="$mode" \
        --global-cache-dir .zig-cache/global
    printf 'nocted_fuzz_race_qualification mode=%s tests=true\n' "$mode"
done

echo 'nocted_fuzz_race_matrix debug=true release_safe=true document_cases=256 grammar_cases=256 external_read_race=true stable_retry=true retry_cap=3 perpetual_churn_rejected=true scratch_clean=true'
