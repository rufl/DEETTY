# Split Terminal Benchmark

This is a machine-local engineering comparison, not a universal terminal
ranking. The runnable [protocol](TERMINAL_BENCHMARK_PROTOCOL.md) is the source
of truth for methodology and artifact requirements.

## Run

```sh
./scripts/terminal_benchmark.sh
```

For a disposable X11 lane:

```sh
NOCTTY_BENCH_OFFSCREEN=1 ./scripts/terminal_benchmark.sh
```

The harness writes raw samples (including execution order), summary, metadata,
process attribution, and checksums to `benchmarks/`. Verify a run with:

```sh
./scripts/audit_terminal_benchmark.sh \
  benchmarks/terminal-comparison-<stamp>-SHA256SUMS
```

Writer completion measures PTY backpressure and ingestion. A separate captured
X11 pixel marker measures externally observed draw completion, including
observer cost; it is not compositor or key-to-photon latency. Results from
different hosts, versions, or protocol revisions are not a single ranking.

## Current status

The harness compares fresh 1/2/4/8-pane terminal process trees with rotated
order and seven recorded trials by default. Alacritty is one-pane only;
Yakuake uses a harness-owned isolated instance and is stopped before and after
the run. Startup, PSS, idle CPU, and writer completion remain separate metrics.

Receipt: `split_terminal_benchmark=true yakuake_exclusive=true
process_tree_pss=true pty_pump_bounded_drain=true`.

## Historical receipts

Development chronology and superseded tables are retained in
[TERMINAL_BENCHMARK_HISTORY.md](TERMINAL_BENCHMARK_HISTORY.md). They are
receipts, not current font-parity or cross-version claims.
