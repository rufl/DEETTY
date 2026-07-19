status=passed
command=./scripts/dogfood_status.sh && zig build check -j1 --summary all && ./scripts/check_no_surprise_network.sh && ./scripts/check_docs_truth.sh
reason=dogfood status reports counted_sessions=0 and excludes not-counted preflight entries; working-tree build/check passed with 17/17 steps and 320/320 tests; no-surprise network guard passed; docs truth passed on 2026-07-19 after dogfood status slice
source=local maintainer run
