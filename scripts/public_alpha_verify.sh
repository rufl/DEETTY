#!/usr/bin/env sh
set -eu
export LC_ALL=C

# Bounded public-source-alpha gate. This is intentionally smaller than
# ./scripts/verify.sh and does not replace the maintainer qualification matrix.

printf '%s\n' 'public_alpha_verify_begin proof_boundary=bounded_source_alpha full_verify=false'

zig build check -j1 --summary all
./scripts/check_no_surprise_network.sh
./scripts/check_docs_truth.sh
./scripts/native_grid_smoke.sh
./scripts/nocted_native_smoke.sh

printf '%s\n' 'public_alpha_verify passed=true build_check=true no_surprise_network=true docs_truth=true native_grid_smoke=true nocted_native_smoke=true full_verify=false'
