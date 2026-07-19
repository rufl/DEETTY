status=passed
command=./scripts/public_alpha_verify.sh && zig build check -j1 --summary all && ./scripts/check_docs_truth.sh
reason=bounded public-source-alpha gate passed with build_check, no_surprise_network, docs_truth, native_grid_smoke, and nocted_native_smoke true while full_verify=false; working-tree build/check passed with 17/17 steps and 320/320 tests; docs truth passed on 2026-07-19
source=local maintainer run
