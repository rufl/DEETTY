status=passed
command=./scripts/install_dogfood.sh ~/.local && installed dogfood check && zig build check -j1 --summary all && ./scripts/check_no_surprise_network.sh && ./scripts/check_docs_truth.sh
reason=two unstripped Debug binaries installed with debug_info; logging wrappers, absolute desktop entries, per-app local logs, exit receipts, GTK/GLib debug, and core-dump enablement verified; build/check passed with 17/17 steps and 320/320 tests; no-surprise network and docs truth passed on 2026-07-19
source=local maintainer run
