# Split Terminal Benchmark

This is a machine-local engineering comparison, not a universal terminal
ranking. The runnable [protocol](TERMINAL_BENCHMARK_PROTOCOL.md) is the source
of truth for methodology and artifact requirements.

## Run

The compositor-backed matrix must run in an acknowledged disposable session:

```sh
NOCTTY_DEDICATED_DISPLAY=1 ./scripts/terminal_benchmark.sh
```

For an automatically isolated, display-independent X11 lane:

```sh
NOCTTY_BENCH_OFFSCREEN=1 ./scripts/terminal_benchmark.sh
```

Offscreen mode uses the repository's `isolated_display_runner.sh` boundary by
default: a private mount/PID/IPC/network namespace, runtime directory, D-Bus
session, and X server with serialized, pressure-gated, bounded process-tree
cleanup. `OVERZEER_DISPLAY_RUNNER` may select an equivalent reviewed runner.
Both modes fail closed rather than use an unacknowledged active desktop.

The harness writes raw samples (including execution order), summary, metadata,
process attribution, and checksums to `benchmarks/`. Run stamps are bounded to
portable filename characters, and an existing artifact set is never
overwritten. Verify a run with:

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
order and seven recorded trials by default. Power-of-two 16/32-pane runs are
available through `NOCTTY_BENCH_PANES` and `NOCTTY_BENCH_OUTPUT_PANES` for
agent-scale work; they are not part of the default peer matrix.
`NOCTTY_BENCH_SKIP_BUILD=1` plus `NOCTTY_BENCH_NOCTTY_BIN=/path/to/noctty`
selects an exact detached-worktree binary for A/B evidence.
`NOCTTY_BENCH_POST_OUTPUT_SETTLE_MS` delays the resource sample after the final
pixel for idle-release measurements; the default is 250 ms.
`NOCTTY_BENCH_EXPECT_IDLE_COMPACTION=1` makes NOCTTY benchmark mode fail unless
a native session reports completed idle-history compaction. Alacritty is
one-pane only; Yakuake uses a harness-owned isolated instance and is stopped
before and after the run. Startup, PSS, RSS, USS, idle CPU, writer completion,
and final-pixel timing remain separate metrics. USS sums private clean, dirty,
and private huge pages from `/proc/<pid>/smaps_rollup`.

Receipt: `split_terminal_benchmark=true yakuake_exclusive=true
process_tree_pss=true process_tree_uss=true pty_pump_bounded_drain=true`.

The accepted 32-session memory experiment and rejected buffer/history/renderer
variants are recorded in
[TERMINAL_AGENT_SCALE_RESEARCH.md](TERMINAL_AGENT_SCALE_RESEARCH.md).

## Historical receipts

Development chronology and superseded tables are retained in
[TERMINAL_BENCHMARK_HISTORY.md](TERMINAL_BENCHMARK_HISTORY.md). They are
receipts, not current font-parity or cross-version claims.
