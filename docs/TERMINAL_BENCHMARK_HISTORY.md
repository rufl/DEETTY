# Archived Terminal Benchmark Receipts

This chronology predates the current protocol, includes non-font-parity runs,
and is retained only for development history. Do not use its tables for current
cross-terminal claims; run the protocol instead.

Most recently measured on 2026-07-21. This is a machine-local engineering
comparison, not a universal terminal ranking. The normative, bias-audited
method and runnable artifact contract are in
[TERMINAL_BENCHMARK_PROTOCOL.md](TERMINAL_BENCHMARK_PROTOCOL.md); historical
results below predate parts of that stricter protocol and must not be mixed
with a new run as if they were one controlled matrix.

> **Audit correction:** the historical harness configured peers at 11 pt but
> left DEETTY's benchmark-only path at its 13 pt default. That unequal visible
> grid can affect wrapping, scrolling, and rendering work. Historical tables
> remain useful development receipts, but they are not font-parity rankings.
> The current harness passes the same explicit font size into DEETTY and every
> peer; publishable cross-terminal claims require a fresh full matrix.

## Scope

| Terminal | Version |
| --- | --- |
| DEETTY | 0.1.0 |
| Konsole | 26.04.3-1 |
| Kitty | 0.48.0-1 |
| WezTerm | 20240203.110809.5046fc22-2 |
| Terminator | 2.1.5-2 |
| Ghostty | 1.3.1-2 |
| Alacritty | 0.17.0-1 |
| Yakuake | 26.04.3-1 |

The initial matrix excluded Yakuake while active sessions used it
(`yakuake_excluded=true`). The current harness instead requires Yakuake to be
absent, starts and stops its own isolated instance, creates the requested
balanced panel tree through D-Bus, and fails if its PID set differs after the
matrix.

## Method

- Host: Linux 7.1.3 x86_64, KDE desktop, Wayland session.
- Common automation backend: X11/XWayland for all terminals.
- Window geometry: 1200x800 pixels; font size 11; 1000 scrollback lines.
- Layouts: balanced 1, 2, 4, and 8 pane trees for split-capable terminals;
  Alacritty and Yakuake enter the one-pane lane only.
- Historical retained repetitions: one unrecorded warmup, then three
  fresh-process trials. The current harness defaults to seven samples and one
  warmup per pane/scenario cell. Terminal order follows a deterministic
  forward/reverse rotation, and every clean teardown is followed by a
  one-second settle interval.
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
a real shell, production PTY/`TerminalSession`/VT, and ABI-v7 packed frame
snapshots for two 64-sample runs per mode. It retains input-write/PTY-read-start-to-draw
percentiles, repeat/cross-mode-identical pixels, zero warm-frame renderer
allocations, and separate root/tree memory
(`native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true`). It is likewise not folded into writer-completion numbers. Separate live mapped receipts now cover synthetic production key-handler-to-draw/after-paint distributions, Wayland GDK presentation feedback, and Wayland/X11 idle/fullscreen compositor pixels plus memory/wakeups. Physical input remains separate.

The harness is [terminal_benchmark.sh](../scripts/terminal_benchmark.sh), its
bundle verifier is
[audit_terminal_benchmark.sh](../scripts/audit_terminal_benchmark.sh), its
controlled pane process is
[terminal_benchmark_workload.sh](../scripts/terminal_benchmark_workload.sh),
and the final artifacts are the [raw samples](../benchmarks/terminal-comparison-2026-07-15-raw.csv),
[summary](../benchmarks/terminal-comparison-2026-07-15-summary.csv), and
[environment metadata](../benchmarks/terminal-comparison-2026-07-15-metadata.txt).

## Results

Each startup cell is median milliseconds followed by median PSS in MiB.

| Terminal | 1 pane | 2 panes | 4 panes | 8 panes |
| --- | ---: | ---: | ---: | ---: |
| DEETTY | 164 / 33.621 | 164 / 33.635 | 177 / 33.596 | 178 / 33.884 |
| Konsole | 276 / 34.094 | 317 / 34.984 | 429 / 38.081 | 634 / 43.776 |
| Kitty | 278 / 87.656 | 298 / 95.547 | 385 / 103.334 | 479 / 122.146 |
| WezTerm | 196 / 83.715 | 184 / 84.454 | 218 / 84.839 | 292 / 89.289 |
| Terminator | 374 / 60.666 | 397 / 61.851 | 437 / 63.534 | 554 / 65.960 |
| Ghostty | 680 / 116.896 | 838 / 126.094 | 1220 / 144.737 | 1946 / 183.536 |

The startup range is retained because desktop launch variance remains visible.
DEETTY's ranges were 163-166, 150-168, 176-177, and 173-193 ms for 1/2/4/8
panes; Konsole's four-pane range was 422-616 ms. The raw CSV is the source for
every min/median/max value; output is measured in a separate scenario.

Four-pane output results:

| Terminal | Writer median | Throughput |
| --- | ---: | ---: |
| Kitty | 64 ms | 103.712 MiB/s |
| DEETTY | 66 ms | 100.569 MiB/s |
| Ghostty | 66 ms | 100.569 MiB/s |
| Terminator | 113 ms | 58.740 MiB/s |
| WezTerm | 129 ms | 51.454 MiB/s |
| Konsole | 163 ms | 40.721 MiB/s |

DEETTY used the least PSS and had the lowest median startup at every pane count.
Relative to the next-lowest PSS, Konsole, its advantage was 1.4 percent at one
pane and 22.6 percent at eight panes. Relative to the next-fastest startup
median, its advantage ranged from 10.9 percent at two panes to 39.0 percent at
eight panes. DEETTY's median idle CPU sample was 0.0 percent at every pane
count; all idle results remain too close to one-jiffy resolution for a precise
CPU ranking.

The initial matrix exposed a one-read-per-tick DEETTY bottleneck. Four-pane
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
preserve all three baselines independently of the current matrix. DEETTY trails
Kitty by 2 ms, ties Ghostty, and leads Konsole, WezTerm, and Terminator on writer
completion. This remains ingestion evidence, not final-frame proof.

## Post-lightness rerun (2026-07-20)

A fresh run after compact-history and startup-icon changes used the same six
terminals, X11/XWayland backend, pane counts, 20,000-line four-pane output
payload, warmup, three measured trials, rotated order, and one-second settle.
Alacritty was not installed and is therefore not represented. The retained
artifacts are the [raw samples](../benchmarks/terminal-comparison-2026-07-20-220831-post-lightness-raw.csv),
[summary](../benchmarks/terminal-comparison-2026-07-20-220831-post-lightness-summary.csv),
and [metadata](../benchmarks/terminal-comparison-2026-07-20-220831-post-lightness-metadata.txt).

| Terminal | 1-pane startup / PSS | 2-pane | 4-pane | 8-pane |
| --- | ---: | ---: | ---: | ---: |
| DEETTY | 121 ms / 15.048 MiB | 143 / 15.449 | 127 / 17.950 | 121 / 17.066 |
| Konsole | 223 / 28.509 | 272 / 29.612 | 373 / 32.477 | 581 / 38.081 |
| Kitty | 245 / 86.846 | 282 / 88.536 | 339 / 92.509 | 439 / 96.760 |
| WezTerm | 135 / 81.582 | 175 / 81.661 | 194 / 82.585 | 281 / 87.225 |
| Terminator | 320 / 61.798 | 341 / 63.297 | 397 / 65.217 | 524 / 67.342 |
| Ghostty | 617 / 110.454 | 758 / 122.142 | 1100 / 138.791 | 1903 / 177.063 |

DEETTY again has the lowest median startup and PSS at every pane count. Against
next-lowest-memory Konsole it uses 44.7–55.2% less PSS; against next-fastest
startup WezTerm it is 10.4–56.9% faster. One DEETTY eight-pane startup trial was
a 502 ms outlier; the other two were 117 and 121 ms.

Four-pane writer completion now ranks Kitty 64 ms, Ghostty 65 ms, Terminator
95 ms, WezTerm 135 ms, DEETTY 146 ms, and Konsole 167 ms. DEETTY is 12.6%
faster than Konsole but slower than the other four peers on this ingestion-only
metric. This is materially better than DEETTY's immediately preceding 237 ms
run, while slower than the older NCT-102 66 ms retained above. The compact
hot/cold history design traded ingestion throughput for much lower retained
memory; final-frame latency remains outside this harness.

### Output-ingestion optimization rerun

The subsequent parser/history pass packed terminal cell flags into a 16-byte
cell, made full-screen dirty state virtual until renderer consumption, borrowed
CSI/parameter storage instead of copying and clearing 544-byte parser values,
vectorized printable-run boundary scans, initialized known ASCII grapheme state
directly, retained the newest 1,024 physical history rows hot, replaced hot-slot
owner scans with pointer-derived indices, and raised the still-bounded per-pane
drain to 2 MiB through a 128 KiB reusable buffer.

A final same-session 15-trial leader matrix retained
[raw samples](../benchmarks/terminal-comparison-ingest-durable-final-raw.csv),
[summary](../benchmarks/terminal-comparison-ingest-durable-final-summary.csv),
and [metadata](../benchmarks/terminal-comparison-ingest-durable-final-metadata.txt).
DEETTY completed the four-pane writers in **66 ms / 100.569 MiB/s**, Kitty in
**67 ms / 99.068 MiB/s**, and Ghostty in **68 ms / 97.611 MiB/s**. The other
retained peers remain slower at 95 ms or more. On this machine-local,
writer-completion-only boundary, DEETTY is therefore the fastest measured
terminal, while the 1–2 ms lead is narrow enough that future comparisons must
retain multiple rotated trials. Final-frame presentation remains unmeasured.

## Current rerun (2026-07-21)

A fresh three-trial XWayland run retained [raw samples](../benchmarks/terminal-comparison-2026-07-21-font-cache-rerun-raw.csv), [summary](../benchmarks/terminal-comparison-2026-07-21-font-cache-rerun-summary.csv), and [metadata](../benchmarks/terminal-comparison-2026-07-21-font-cache-rerun-metadata.txt). It rebuilt DEETTY in `ReleaseFast`, used rotated order and one-second teardown intervals, and includes isolated one-pane Alacritty and Yakuake startup, memory, and writer samples.

| Terminal | 1-pane startup / PSS | 2-pane | 4-pane | 8-pane |
| --- | ---: | ---: | ---: | ---: |
| DEETTY | 135 ms / 16.573 MiB | 135 / 16.923 | 135 / 17.664 | 138 / 18.842 |
| Konsole | 220 ms / 29.773 MiB | 264 / 30.729 | 361 / 33.592 | 591 / 39.235 |
| Kitty | 229 ms / 92.043 MiB | 285 / 91.804 | 318 / 94.360 | 415 / 101.836 |
| WezTerm | 155 ms / 85.685 MiB | 157 / 86.266 | 188 / 87.526 | 259 / 91.812 |
| Terminator | 313 ms / 65.720 MiB | 332 / 66.836 | 391 / 68.967 | 496 / 71.262 |
| Ghostty | 578 ms / 117.475 MiB | 730 / 127.592 | 1062 / 146.545 | 1791 / 183.338 |
| Alacritty | 179 ms / 40.966 MiB | — | — | — |
| Yakuake | 292 ms / 34.580 MiB | — | — | — |

| Terminal | One-pane writer median | Throughput |
| --- | ---: | ---: |
| DEETTY | 20 ms | 82.970 MiB/s |
| Alacritty | 32 ms | 51.856 MiB/s |
| Kitty | 34 ms | 48.806 MiB/s |
| Terminator | 34 ms | 48.806 MiB/s |
| Konsole | 47 ms | 35.306 MiB/s |
| Yakuake | 50 ms | 33.188 MiB/s |
| Ghostty | 59 ms | 28.125 MiB/s |
| WezTerm | 61 ms | 27.203 MiB/s |

| Terminal | Four-pane writer median | Throughput |
| --- | ---: | ---: |
| Ghostty | 63 ms | 105.358 MiB/s |
| Kitty | 64 ms | 103.712 MiB/s |
| DEETTY | 65 ms | 102.117 MiB/s |
| Terminator | 90 ms | 73.751 MiB/s |
| WezTerm | 121 ms | 54.856 MiB/s |
| Konsole | 190 ms | 34.935 MiB/s |

DEETTY had the lowest median startup and idle PSS at every split-capable pane count, and at one pane against Alacritty and Yakuake. At one pane it started 12.9% faster than WezTerm and used 44.3% less PSS than Konsole, the next-lowest-memory peer. It led the one-pane writer lane and ranked third in the four-pane writer lane; both remain ingestion-only evidence.

That historical run kept Alacritty and Yakuake to one pane. The current harness still limits Alacritty, which has no native split-tree interface, but restores Yakuake's native D-Bus `splitTerminalTopBottom`/`splitTerminalLeftRight` path for balanced 2/4/8-panel trees. Yakuake starts only when no instance already exists, uses isolated configuration and Konsole profile directories, applies the common font and 1000-line history to every terminal, and exits through its own D-Bus API. Existing user sessions remain an enforced hard stop.

### Nanosecond completion refinement

The prior timer ended when the harness's 10 ms polling loop observed all done
markers, which was too coarse to rank terminals separated by 1–2 ms. The
refined harness uses the kernel timestamps of the writer-created marker files
and reports fractional milliseconds while retaining the same payload, launch
order, and writer-completion boundary.

A rotated 15-trial leader run retained
[raw samples](../benchmarks/terminal-comparison-2026-07-21-ns-final-raw.csv),
[summary](../benchmarks/terminal-comparison-2026-07-21-ns-final-summary.csv), and
[metadata](../benchmarks/terminal-comparison-2026-07-21-ns-final-metadata.txt).
Kitty completed the four-pane writers in **52.384 ms / 126.710 MiB/s**,
DEETTY in **56.378 ms / 117.733 MiB/s**, and Ghostty in
**59.187 ms / 112.146 MiB/s**. DEETTY remains the startup and memory leader,
but Kitty is the honest four-pane writer-completion leader by 3.994 ms in this
run. Tested 256 KiB and 1 MiB DEETTY read buffers regressed the focused median,
so the 128 KiB buffer remains.

## Boundaries

- Native Wayland performance was not compared because the window/control
  automation requires a common X11 path.
- PSS depends on other processes sharing the same libraries. GTK libraries can
  be shared by DEETTY, Terminator, and Ghostty; Qt/KDE pages can be shared by
  Konsole and Yakuake.
- The harness does not measure keystroke latency, frame latency, GPU time,
  mapped visual correctness under load, shell startup customization, or
  long-duration soak behavior. The separate exact renderer fixture supplies
  bounded draw CPU/repeat-pixel/owned-allocation evidence, not those metrics.
- Split creation uses each terminal's supported interface: Konsole's PID-scoped
  D-Bus window API, [Kitty launch control](https://sw.kovidgoyal.net/kitty/launch/),
  [WezTerm split-pane control](https://wezterm.org/cli/cli/split-pane.html),
  generated [Terminator layouts](https://gnome-terminator.readthedocs.io/en/latest/layouts.html),
  and [Ghostty keybindings](https://ghostty.org/docs/config/keybind/reference).
- Konsole control is scoped to `org.kde.konsole-$launch_pid`. Yakuake control
  is limited to the harness-owned singleton after a no-existing-instance check.

## Reproduce

Install the seven peer terminals plus `xdotool` and `qdbus`, then run from an
acknowledged disposable KDE display session:

```sh
DEETTY_DEDICATED_DISPLAY=1 ./scripts/terminal_benchmark.sh
```

Environment variables can narrow a diagnostic run, for example:

```sh
DEETTY_DEDICATED_DISPLAY=1 \
DEETTY_BENCH_TERMINALS='deetty kitty' \
DEETTY_BENCH_PANES='1 4 8' \
DEETTY_BENCH_RUNS=3 \
./scripts/terminal_benchmark.sh
```

The harness owns only uniquely named windows, PID-scoped process trees, private
control sockets, its exact temporary directory, and an otherwise absent Yakuake
singleton.

Acceptance receipt:
`split_terminal_benchmark=true single_pane_peers=alacritty,yakuake yakuake_isolated=true process_tree_pss=true pty_pump_bounded_drain=true native_output_throughput=true visible_grid_ring=true vt_ascii_run=true pty_event_source=true timer_read_polling=false output_present_coalesced=true event_source_cleanup=true benchmark_order_isolated=true wezterm_split_ready=true writer_median_ms=66 output_metric=writer_completion`.
