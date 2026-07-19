status=passed
command=zig build check -j1 --summary all && ./scripts/check_no_surprise_network.sh && ./scripts/check_docs_truth.sh
reason=working-tree build/check passed with 17/17 steps and 320/320 tests; no-surprise network guard passed; docs truth passed on 2026-07-19 after draft public source-alpha release notes
source=local maintainer run
