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
## Renderer A/B

The NOCTTY benchmark fixture accepts `NOCTTY_BENCH_RENDERER=cairo|opengl`;
`cairo` is the default. Both modes use the same authoritative Cairo rasterizer.
`opengl` measures the optional GPU presentation path: the Cairo image is
uploaded as a texture and presented through `GtkGLArea`; it is not GPU glyph
rasterization.

Use a disposable real X11/XWayland display when qualifying GPU presentation:

```sh
NOCTTY_DEDICATED_DISPLAY=1 \
NOCTTY_BENCH_RENDERER=cairo \
NOCTTY_BENCH_TERMINALS=noctty \
NOCTTY_BENCH_PANES='1' \
NOCTTY_BENCH_OUTPUT_PANES='1' \
./scripts/terminal_benchmark.sh
```

For a native Wayland run, set `NOCTTY_BENCH_DISPLAY_BACKEND=wayland`,
preserve `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR`, and use the same command.
The Wayland lane intentionally leaves `visual_ms` and `visual_tail_ms`
unavailable because the retained pixel observer is X11-only.

Repeat with `NOCTTY_BENCH_RENDERER=opengl` and a different
`NOCTTY_BENCH_STAMP`. The app log must contain
`native_grid_gpu_context`, and the renderer receipt must report
`renderer_requested=opengl renderer_effective=opengl`,
`gpu_render_frames>0`, and `gpu_fallbacks=0`. A receipt with
`renderer_effective=cairo` is a fallback and is not a GPU result.

The harness retains renderer lines in the metadata receipt and fails a NOCTTY
trial when the requested renderer is not observed. An offscreen Xvfb run may
use llvmpipe; it validates the benchmark pipeline but is not a hardware-GPU
result.

Compare startup, PSS/RSS/USS, idle CPU, writer completion, and final-pixel
timings only between runs with identical workload, geometry, font, pane count,
trial count, and display conditions.

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

The retained 2026-10-14 offscreen X11 receipt compares NOCTTY and Kitty v0.49.2
under the same 1200×800, 5000-line, three-trial workload. Its median process
tree PSS is 45.421–46.994 MiB for NOCTTY versus 172.170–176.704 MiB for Kitty;
startup favors NOCTTY, while Kitty has lower visual completion in the retained
matrix. The full table and source-pinned architecture comparison are in
[`PERFORMANCE_ALGORITHM_RESEARCH.md`](PERFORMANCE_ALGORITHM_RESEARCH.md).

The accepted 32-session memory experiment and rejected buffer/history/renderer
variants are recorded in
[TERMINAL_AGENT_SCALE_RESEARCH.md](TERMINAL_AGENT_SCALE_RESEARCH.md).

## Historical receipts

Development chronology and superseded tables are retained in
[TERMINAL_BENCHMARK_HISTORY.md](TERMINAL_BENCHMARK_HISTORY.md). They are
receipts, not current font-parity or cross-version claims.
