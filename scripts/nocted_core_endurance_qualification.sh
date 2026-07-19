#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd -P)
scratch=$(mktemp -d "$repo_root/.noctty-core-endurance.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

output_file="$scratch/output"
started_seconds=$(date +%s)
TMPDIR="$scratch" NOCTED_CORE_STABILITY_CYCLES=512 \
    "$repo_root/scripts/nocted_core_stability_qualification.sh" | tee "$output_file"
elapsed_seconds=$(($(date +%s) - started_seconds))

for mode in Debug ReleaseSafe; do
    grep -F "nocted_core_stability mode=$mode cycles=512" "$output_file" >/dev/null
    grep -E \
        "nocted_core_stability_resource mode=$mode peak_pss_kib=[1-9][0-9]* peak_rss_kib=[1-9][0-9]* samples=[1-9][0-9]* root_process_only=true" \
        "$output_file" >/dev/null
done
grep -F \
    'ranking_queries=3 ranking_cycles=512 ranking_fingerprint=12892608525683143802 ranking_deterministic=true' \
    "$output_file" >/dev/null
grep -F \
    'nocted_core_stability_matrix debug=true release_safe=true cycles=512 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_cycles=512 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true scratch_clean=true' \
    "$output_file" >/dev/null
if ((elapsed_seconds < 1)); then
    exit 1
fi

printf 'nocted_core_endurance_resource elapsed_seconds=%d duration_recorded=true\n' \
    "$elapsed_seconds"
echo 'nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true'
