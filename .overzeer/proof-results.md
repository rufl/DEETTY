status=passed
command=zig build check -j1 --summary all && ./scripts/nocted_native_smoke.sh && ./scripts/release_contract_smoke.sh && ./scripts/check_no_surprise_network.sh && ./scripts/check_docs_truth.sh && ./scripts/install_dogfood.sh ~/.local
reason=NoctEd now owns direct vendored Tree-sitter parsing/highlight publication behind GtkSourceView with native Zig/UTF-8 smoke proof; build/check passed with 17/17 steps and 322/322 tests; release contract distinguishes parser-free NOCTTY from Tree-sitter-enabled NoctEd; no-surprise network and docs truth passed; updated unstripped dogfood binaries installed
source=local maintainer run
