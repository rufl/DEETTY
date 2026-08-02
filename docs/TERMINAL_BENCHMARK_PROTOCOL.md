# Terminal Benchmark Protocol

This suite is a machine-local comparison, not a universal terminal ranking.
Its purpose is to produce evidence that another person can rerun, inspect, and
reject without trusting NOCTTY.

## Rules

1. **Same work:** every pane executes the same external workload script and
   reads the same hashed payload.
2. **Same visible envelope:** 1200×800 X11/XWayland window, monospace 11 pt,
   balanced split trees, and 1000 lines of scrollback where the terminal exposes
   a line-based setting. Every workload records its settled `stty size`; raw and
   summary artifacts retain the minimum and maximum rows and columns per trial.
3. **Native control paths:** each terminal uses its supported CLI, D-Bus,
   remote-control, config-layout, or keyboard split interface. The adapter used
   is recorded; adapter time is included in startup.
4. **Fresh ownership:** every trial starts a separately attributable terminal
   process tree and tears it down before the next trial. Workload subtrees are
   excluded from terminal memory and CPU totals.
5. **Balanced order:** terminal order rotates forward and backward. Every
   terminal receives one unrecorded warmup for every pane/scenario cell.
6. **No selective samples:** default runs are seven. Raw samples (including
   execution order), process attribution, environment, source/binary hashes,
   and median absolute deviations are retained.
7. **Metric names are boundaries:** writer completion remains PTY-ingestion
   evidence. A separate external screenshot observer records when a fixed RGB
   marker reaches the captured X11 window; it is not compositor presentation or
   key-to-photon latency. Process readiness is not called first-frame presentation.
8. **No composite winner:** startup, PSS/RSS/USS, idle CPU, ingestion, and correctness
   remain separate. A terminal may lead one and lose another.

## Current lanes

| Lane | Pane counts | Boundary | Status |
| --- | --- | --- | --- |
| Startup | 1, 2, 4, 8 | launch request → every workload spawned | Cross-terminal; Alacritty is one-pane only |
| Idle memory | 1, 2, 4, 8 | process-tree PSS/RSS/USS after readiness | Cross-terminal |
| Idle CPU | 1, 2, 4, 8 | process-tree jiffies over fixed interval | Cross-terminal; coarse near zero |
| Output ingestion | 1, 2, 4, 8 | release writers → last writer marker timestamp | Cross-terminal PTY ingestion |
| External pixel completion | 1, 2, 4, 8 | release writers → fixed RGB marker observed in captured X11 window | Cross-terminal; includes screenshot-observer cost, not compositor presentation |
| Production startup | 1 | normal `noctty --native-grid-windowed` path with isolated state and external workload shell | NOCTTY parity/control row, reported separately as `noctty-production` |
| Renderer/pipeline | internal | real PTY/VT → exact Cairo draw | NOCTTY qualification only; never used for peer ranking |
| Compatibility/TUI | internal | deterministic VT and installed TUI qualifications | NOCTTY qualification only |

The suite deliberately does **not** call the screenshot lane compositor
presentation or key-to-photon latency. It also does not rank GPU energy, native
Wayland presentation, accessibility, or correctness under every workload. The
pixel metric is useful only with its retained X11/XWayland and observer boundary.

## Known asymmetries

- The multi-pane `noctty` row uses NOCTTY's benchmark fixture to construct a
  balanced tree from startup data. The separate one-pane `noctty-production`
  row enters through the normal windowed product path with isolated XDG state;
  it prevents benchmark-fixture startup from being presented as product startup.
  Terminator can construct a balanced tree from startup data; Konsole, Kitty,
  WezTerm, and Ghostty create splits after their first window.
- Ghostty limits scrollback in bytes, so the harness uses 87,000 bytes—the exact
  average size of 1,000 lines of the default payload. Yakuake's temporary
  profile scrollback is not externally verified; its row is marked accordingly.
- Alacritty has no native split tree and therefore participates only in
  one-pane cells. Yakuake uses its native D-Bus terminal split API for balanced
  2/4/8-panel trees, with an isolated Konsole profile and verified 1000-line
  history on every terminal.
- PSS depends on host library sharing; USS exposes private clean/dirty/huge
  pages and is better for allocator-release checks. Executable versions, process lists, and
  the desktop/session environment are retained with every run.
- The common automation path is X11/XWayland. Results do not establish native
  Wayland ordering.

## Run

Full matrix (long-running, visible X11/XWayland):

```sh
./scripts/terminal_benchmark.sh
```

Offscreen matrix (requires `Xvfb`; the live status bar remains visible on
standard error):

```sh
NOCTTY_BENCH_OFFSCREEN=1 ./scripts/terminal_benchmark.sh
```

The offscreen mode uses `xvfb-run -a` for a private display, unsets
`WAYLAND_DISPLAY`, and records display and host provenance.
It does not make compositor-presentation claims; those require a real display
lane.

Focused, still auditable example:

```sh
NOCTTY_BENCH_TERMINALS='noctty kitty ghostty' \
NOCTTY_BENCH_PANES='1 4' \
NOCTTY_BENCH_OUTPUT_PANES='1 4' \
NOCTTY_BENCH_RUNS=15 \
./scripts/terminal_benchmark.sh
```

Slow renderers get 30 seconds to expose the visual marker. Override that only
when needed with `NOCTTY_BENCH_VISUAL_TIMEOUT_MS`.

Verify the retained bundle:

```sh
./scripts/audit_terminal_benchmark.sh \
  benchmarks/terminal-comparison-<stamp>-SHA256SUMS
```

A valid bundle contains raw samples including settled grid, execution order,
and pixel timestamps; a statistical summary; per-process attribution;
environment/provenance metadata; and checksums.
The raw files are the source of truth; prose tables are derived views.
