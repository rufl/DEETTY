status=passed
command=zig build check -j1 --summary all && ./scripts/native_grid_compact_ux_smoke.sh && ./scripts/check_no_surprise_network.sh && ./scripts/check_docs_truth.sh && ./scripts/install_dogfood.sh ~/.local
reason=active-pane App/Pane CPU/RSS information strip moved below terminal layout and compact smoke verifies final page-child placement; build/check passed with 17/17 steps and 322/322 tests; no-surprise network and docs truth passed; updated unstripped dogfood binaries installed on 2026-07-19
source=local maintainer run
