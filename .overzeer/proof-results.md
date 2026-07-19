status=passed
command=./scripts/dogfood_status.sh && zig build check -j1 --summary all && ./scripts/check_no_surprise_network.sh && ./scripts/check_docs_truth.sh
reason=go/no-go sheet added with explicit no-go while counted dogfood remains zero; dogfood status still counted_sessions=0; working-tree build/check passed with 17/17 steps and 320/320 tests; no-surprise network guard passed; docs truth passed on 2026-07-19
source=local maintainer run
