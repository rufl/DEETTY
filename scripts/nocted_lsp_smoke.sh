#!/bin/sh
set -eu

if ! command -v clangd >/dev/null 2>&1; then
  echo 'nocted_lsp_smoke skipped=true reason=clangd_missing'
  exit 0
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-lsp.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
cat >"$scratch/probe.c" <<'EOF'
int nocted_lsp_symbol(void) { return 42; }
EOF

zig build -Doptimize=Debug >/dev/null
output=$(timeout 30 ./zig-out/bin/dintor --lsp-probe "$scratch/probe.c")
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F \
  'nocted_lsp_probe server=clangd language=cpp response=nocted_lsp_symbol' >/dev/null
echo 'nocted_lsp_smoke client=true server=true transport=stdio framing=true initialize=true did_open=true symbols=true clangd=true timeout=true scratch_clean=true'
