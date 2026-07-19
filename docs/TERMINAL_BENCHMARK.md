# Split Terminal Benchmark

Measured on 2026-07-15. This is a machine-local engineering comparison, not a
universal terminal ranking.

## Scope

| Terminal | Version |
| --- | --- |
| NOCTTY | 0.1.0 |
| Konsole | 26.04.3-1 |
| Kitty | 0.47.4-1 |
| WezTerm | 20240203.110809.5046fc22-2 |
| Terminator | 2.1.5-2 |
| Ghostty | 1.3.1-2 |

Yakuake was explicitly excluded because active Codex sessions were using it.
The harness records its PID set before and after the matrix and fails if that
set changes. The final run recorded PID `507138` both times and
`yakuake_untouched=true`.

## Method

- Host: Linux 7.1.3 x86_64, KDE desktop, Wayland session.
- Common automation backend: X11/XWayland for all six terminals.
- Window geometry: 1200x800 pixels; font size 11; 1000 scrollback lines.
- Layouts: balanced 1, 2, 4, and 8 pane trees with an identical shell
  workload in every pane.
- Repetitions: one unrecorded warmup, then three fresh-process trials. Terminal
  order follows a deterministic forward/reverse rotation, and every clean
  teardown is followed by a one-second settle interval.
- Startup: process launch until every requested pane has started its workload.
- Memory: terminal process-tree PSS and RSS after excluding every workload
  process subtree. PSS is the primary comparison because RSS double-counts
  shared pages.
- Idle CPU: one-second process-tree sample after workload readiness, with the
  workload subtrees excluded.
- Output: four panes each write the same 1,740,000-byte, 20,000-line ANSI
  payload. The reported time ends when all four writers finish. It measures PTY
  backpressure and ingestion capacity, not final-frame presentation latency.
- WezTerm split creation waits for each new pane's workload marker before the
  next split, preventing a successful control reply from outrunning pane setup.
- The retained matrix measured the NCT-102 implementation: each GTK-thread
  pump was bounded to 128 KiB through a reusable 16 KiB buffer, PTY descriptor
  readiness performed one bounded pump per GLib dispatch, presentation used a
  one-shot 16 ms source, and a 250 ms exit timer became a 16 ms read fallback
  only when descriptor registration failed.

NCT-109 and NCT-116 through NCT-120 landed after this matrix. Descriptor-driven draining remains
unchanged, hidden-pane presentation stays at 100 ms, and mapped-only redraw plus
immediate retired-session release remain in force. Descriptor-backed exit
fallback now runs through root maintenance with zero pane exit timers, while
complete context-source shutdown is centralized (`descriptor_fallback=root_coalesced`,
`pane_exit_timers=0`, `source_cleanup=centralized`). NCT-117 introduced packed-row
fetches; NCT-118 replaced its row-hash pass with terminal-owned dirty rows, and
NCT-119 now supersedes that transport with ABI v2 dirty column spans,
frame-clock presentation, resize coalescing, and guarded glyph caching
(`render_abi=packed_rows`, `render_abi_version=2`, `damage_tracking=dirty_spans`,
`glyph_batching=true`, `glyph_cache=true`, `frame_clock_present=true`). That presentation change is covered by native damage and
32-session churn receipts. A later headless production-session matrix separately
retains 64 ordinary and eight forced real-PTY lifecycles per mode with zero
allocator/process residue (`terminal_session_qualification_matrix debug=true release_safe=true normal_cycles=64 forced_cycles=8 sessions_per_mode=72 total_sessions=144 allocator_leak_free=true forced_group_shutdown=true latency_percentiles=true root_memory_separate=true process_tree_memory=true scratch_clean=true`). Neither receipt is folded
retroactively into the retained writer-completion numbers. A separate exact
production-Cairo lane now retains 128 idle, full-screen, and rich-style draws
per mode with repeat/cross-mode-identical pixels, process-CPU percentiles,
renderer-owned warm/resize allocation counts, and root memory
(`native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true`). That display-independent receipt is also not folded into
the comparison. Those changes pass focused
tests and rendered lifecycle gates, but the comparison was deliberately not
rerun while Yakuake hosts active sessions. The eight-pane 3-callback figure is
a static scheduling calculation, not a new benchmark delta; see
[DAILY_DRIVER.md](DAILY_DRIVER.md).

A later display-independent pipeline lane now feeds that exact Cairo path from
a real shell, production PTY/`TerminalSession`/VT, and ABI-v2 packed rows for
two 64-sample runs per mode. It retains input-write/PTY-read-start-to-draw
percentiles, repeat/cross-mode-identical pixels, zero warm-frame renderer
allocations, and separate root/tree memory
(`native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true`). It is likewise not folded into writer-completion numbers and does not replace mapped GTK/frame-clock/compositor acceptance.

The harness is [terminal_benchmark.sh](../scripts/terminal_benchmark.sh), its
controlled pane process is
[terminal_benchmark_workload.sh](../scripts/terminal_benchmark_workload.sh),
and the final artifacts are the [raw samples](../benchmarks/terminal-comparison-2026-07-15-raw.csv),
[summary](../benchmarks/terminal-comparison-2026-07-15-summary.csv), and
[environment metadata](../benchmarks/terminal-comparison-2026-07-15-metadata.txt).

## Results

Each startup cell is median milliseconds followed by median PSS in MiB.

| Terminal | 1 pane | 2 panes | 4 panes | 8 panes |
| --- | ---: | ---: | ---: | ---: |
| NOCTTY | 164 / 33.621 | 164 / 33.635 | 177 / 33.596 | 178 / 33.884 |
| Konsole | 276 / 34.094 | 317 / 34.984 | 429 / 38.081 | 634 / 43.776 |
| Kitty | 278 / 87.656 | 298 / 95.547 | 385 / 103.334 | 479 / 122.146 |
| WezTerm | 196 / 83.715 | 184 / 84.454 | 218 / 84.839 | 292 / 89.289 |
| Terminator | 374 / 60.666 | 397 / 61.851 | 437 / 63.534 | 554 / 65.960 |
| Ghostty | 680 / 116.896 | 838 / 126.094 | 1220 / 144.737 | 1946 / 183.536 |

The startup range is retained because desktop launch variance remains visible.
NOCTTY's ranges were 163-166, 150-168, 176-177, and 173-193 ms for 1/2/4/8
panes; Konsole's four-pane range was 422-616 ms. The raw CSV is the source for
every min/median/max value; output is measured in a separate scenario.

Four-pane output results:

| Terminal | Writer median | Throughput |
| --- | ---: | ---: |
| Kitty | 64 ms | 103.712 MiB/s |
| NOCTTY | 66 ms | 100.569 MiB/s |
| Ghostty | 66 ms | 100.569 MiB/s |
| Terminator | 113 ms | 58.740 MiB/s |
| WezTerm | 129 ms | 51.454 MiB/s |
| Konsole | 163 ms | 40.721 MiB/s |

NOCTTY used the least PSS and had the lowest median startup at every pane count.
Relative to the next-lowest PSS, Konsole, its advantage was 1.4 percent at one
pane and 22.6 percent at eight panes. Relative to the next-fastest startup
median, its advantage ranged from 10.9 percent at two panes to 39.0 percent at
eight panes. NOCTTY's median idle CPU sample was 0.0 percent at every pane
count; all idle results remain too close to one-jiffy resolution for a precise
CPU ranking.

The initial matrix exposed a one-read-per-tick NOCTTY bottleneck. Four-pane
writer completion was 7129 ms because each 16 ms GTK tick consumed only one
4 KiB PTY read. `TerminalSession.pump` first moved to drain-to-`EAGAIN` with a
128 KiB per-pane budget, reducing the median to 318 ms. NCT-101 then added a
16 KiB reusable read buffer, bounded active-output continuation,
constant-time full-screen visible-row rotation, and an equivalent printable-run
parser, reducing the median to 80 ms. NCT-102 replaced timer-driven reads with
PTY descriptor readiness, one-shot presentation coalescing, complete event
source ownership, terminal-order rotation, one-second teardown isolation, and
per-pane WezTerm readiness. The current 66 ms median is 17.5 percent faster than
the retained 80 ms result, 4.8x faster than the 318 ms intermediate, and 108.0x
faster than the original result (`native_output_throughput=true`,
`visible_grid_ring=true`, `vt_ascii_run=true`, `pty_event_source=true`,
`timer_read_polling=false`, `output_present_coalesced=true`,
`event_source_cleanup=true`, `benchmark_order_isolated=true`,
`wezterm_split_ready=true`).

The retained [pre-pump summary](../benchmarks/terminal-comparison-2026-07-15-pre-pump-fix-summary.csv),
[pre-active-output summary](../benchmarks/terminal-comparison-2026-07-15-pre-active-output-summary.csv),
and [pre-event-source summary](../benchmarks/terminal-comparison-2026-07-15-pre-event-source-summary.csv)
preserve all three baselines independently of the current matrix. NOCTTY trails
Kitty by 2 ms, ties Ghostty, and leads Konsole, WezTerm, and Terminator on writer
completion. This remains ingestion evidence, not final-frame proof.

## Boundaries

- Native Wayland performance was not compared because the window/control
  automation requires a common X11 path.
- PSS depends on other processes sharing the same libraries. The running
  Yakuake process may reduce Konsole's proportional Qt/KDE pages; GTK libraries
  can likewise be shared by NOCTTY, Terminator, and Ghostty.
- The harness does not measure keystroke latency, frame latency, GPU time,
  mapped visual correctness under load, shell startup customization, or
  long-duration soak behavior. The separate exact renderer fixture supplies
  bounded draw CPU/repeat-pixel/owned-allocation evidence, not those metrics.
- Split creation uses each terminal's supported interface: Konsole's PID-scoped
  D-Bus window API, [Kitty launch control](https://sw.kovidgoyal.net/kitty/launch/),
  [WezTerm split-pane control](https://wezterm.org/cli/cli/split-pane.html),
  generated [Terminator layouts](https://gnome-terminator.readthedocs.io/en/latest/layouts.html),
  and [Ghostty keybindings](https://ghostty.org/docs/config/keybind/reference).
- Konsole control is scoped to `org.kde.konsole-$launch_pid`; the harness never
  calls `org.kde.yakuake`.

## Reproduce

Install the five peer terminals plus `xdotool` and `qdbus`, then run from an
interactive KDE display session:

```sh
./scripts/terminal_benchmark.sh
```

Environment variables can narrow a diagnostic run, for example:

```sh
NOCTTY_BENCH_TERMINALS='noctty kitty' \
NOCTTY_BENCH_PANES='1 4 8' \
NOCTTY_BENCH_RUNS=3 \
./scripts/terminal_benchmark.sh
```

The harness owns only uniquely named windows, PID-scoped process trees, private
control sockets, and its exact temporary directory.

Acceptance receipt:
`split_terminal_benchmark=true yakuake_excluded=true process_tree_pss=true pty_pump_bounded_drain=true native_output_throughput=true visible_grid_ring=true vt_ascii_run=true pty_event_source=true timer_read_polling=false output_present_coalesced=true event_source_cleanup=true benchmark_order_isolated=true wezterm_split_ready=true writer_median_ms=66 output_metric=writer_completion`.
