status=passed
command=zig build check -j1 --summary all && clean source-copy zig build check -j1 --summary all && ./scripts/native_grid_compact_ux_smoke.sh && ./scripts/check_no_surprise_network.sh && ./scripts/check_docs_truth.sh && ./scripts/install_dogfood.sh ~/.local
reason=active-pane App and Pane process-tree CPU/RSS added; 200 five-process sampler calls averaged host-local 39.8 us; working and clean source-copy gates passed with 17/17 steps and 322/322 tests; compact UI resource label/tooltip/dedupe smoke passed; no-surprise network and docs truth passed; unstripped dogfood binary installed atomically while prior NOCTTY remained running; restart required to load new inode
source=local maintainer run
