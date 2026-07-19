#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-terminal-compatibility.XXXXXX")
cleanup() {
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

protocol_fixture="$repo_root/src/terminal/fixtures/agent-compat-vt-corpus.tsv"
grapheme_fixture="$repo_root/src/terminal/fixtures/GraphemeBreakTest-17.0.0.txt"
expected_protocol_sha256=65d5f28ec0f2e96bd4625a0d606a0b2a156f7a5f26cafc35edc1d015fc67068f
expected_grapheme_sha256=e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec
protocol_sha256=$(sha256sum "$protocol_fixture" | awk '{print $1}')
grapheme_sha256=$(sha256sum "$grapheme_fixture" | awk '{print $1}')
test "$protocol_sha256" = "$expected_protocol_sha256"
test "$grapheme_sha256" = "$expected_grapheme_sha256"

cd "$repo_root"
run_mode() {
    mode=$1
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache-$mode"
    zig build terminal-compatibility-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache" \
        --global-cache-dir "$global_cache"
    "$prefix/bin/noctty-terminal-compatibility" >"$scratch/output-$mode"
}

run_mode Debug &
debug_pid=$!
run_mode ReleaseSafe &
release_safe_pid=$!
wait "$debug_pid"
wait "$release_safe_pid"

for mode in Debug ReleaseSafe; do
    output=$(cat "$scratch/output-$mode")
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -F \
        "mode=$mode protocol_cases=23 schedules=6 protocol_runs=138 malformed_cases=128 malformed_bytes=524288 unicode_mutations=256 grapheme_cases=766 unicode_version=17.0.0" \
        >/dev/null
    printf '%s\n' "$output" | grep -F \
        'state_diff=true replies=true modes=true sgr=true osc8=true osc52_blocked=true c1=true parser_bounds=true allocator_leak_free=true allocator_residual_bytes=0 assertions=true' \
        >/dev/null
done

echo "terminal_compatibility_matrix debug=true release_safe=true protocol_cases=23 schedules=6 malformed_cases=128 unicode_mutations=256 grapheme_cases=766 allocator_leak_free=true scratch_clean=true protocol_fixture_sha256=$protocol_sha256 grapheme_fixture_sha256=$grapheme_sha256"
