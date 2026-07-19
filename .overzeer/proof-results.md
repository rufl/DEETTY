status=passed
command=./scripts/native_grid_smoke.sh && ./scripts/nocted_native_smoke.sh && zig build check -j1 --summary all && ./scripts/check_no_surprise_network.sh && ./scripts/check_docs_truth.sh
reason=native-grid X11/Wayland smoke passed after synchronized-output fixture hardening; NoctEd native smoke passed; build/check passed with 17/17 steps and 320/320 tests; no-surprise network guard passed; docs truth passed on 2026-07-19 during dogfood-preflight slice
source=local maintainer run
