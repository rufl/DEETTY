# Terminal Agent-Scale Performance Research

Date: 2026-08-01.

Status: shared pump storage, 14-byte cells, and bounded idle-history release
are implemented; alternating A/B evidence is retained under
`benchmarks/terminal-agent-scale-2026-08-01/` as engineering evidence, not
universal terminal rankings or authenticated-agent proof.

## Question

How should DINTTY minimize terminal-root memory and preserve output throughput
when one process owns roughly 20 to 30 concurrent agent shells?

## Method

The existing `scripts/terminal_benchmark.sh` production path was extended from
1/2/4/8 panes to 1/2/4/8/16/32 panes. The stress case used:

- one ReleaseFast DINTTY process;
- 32 real PTYs and terminal grids;
- a 1200x800 X11/Xvfb window at 11 pt;
- 1000 lines of scrollback per pane;
- 20,000 ANSI lines, about 1.66 MiB per pane and 53 MiB total;
- terminal-root PSS/RSS/USS excluding workload process trees;
- writer completion and externally observed final-pixel timing.

Separate detached worktrees tested inline read buffers of 128, 96, 64, 32, and
16 KiB; one shared 128 KiB read scratch; 128/64-line hot-history limits; reused
Pango layouts; cached Cairo font options; 14-byte terminal cells; 128 KiB–2 MiB
pump budgets; idle-history compaction; page-backed history; and libc-backed
history with bounded trimming. Runs were serial because parallel
builds and display workloads distort the exact resource being measured.

## Accepted Result: Shared Pump Scratch and 14-Byte Cells

`TerminalSession` previously embedded a 128 KiB PTY read array. Every pane paid
for that array even though GTK invokes all pane pumps serially on one main
thread. The maintained design now keeps recurring read storage behind a pointer
and gives every session in a `NativeGridSessionPool` the same guarded 128 KiB
scratch.

The scratch has an explicit `in_use` guard. Reentrant pumping fails rather than
allowing two sessions to overwrite the same bytes. Standalone/headless sessions
still allocate and own one private scratch, so the terminal core does not depend
on GTK or global state.

Deterministic layout effect:

| Item | Before | After |
| --- | ---: | ---: |
| `@sizeOf(TerminalSession)` | 141,344 bytes | 10,280 bytes |
| Recurring read storage for 32 native sessions | 4.00 MiB | 0.125 MiB |
| Structural saving at 32 sessions | — | about 3.88 MiB |

The later nonblocking PTY write queue adds 72 bytes of bounded queue metadata, so the current `TerminalSession` value is 10,352 bytes while the shared 128 KiB structural saving remains about 3.88 MiB at 32 sessions.

The final comparison used nine A/B pairs, alternating which binary ran first.
The baseline was commit `56cbcd7` with only the benchmark's 16/32-pane ceiling
backported; the final binary added shared scratch. Each measured trial followed
one warmup. Unrelated local builds entered during the run, so paired order and
medians reduce but do not erase host noise.

| Metric | Inline 128 KiB per pane | Shared 128 KiB | Change |
| --- | ---: | ---: | ---: |
| Idle terminal-root PSS | 114,109 KiB | 108,705 KiB | -4.7% |
| Idle terminal-root RSS | 208,108 KiB | 202,900 KiB | -2.5% |
| Output terminal-root PSS | 128,569 KiB | 123,358 KiB | -4.1% |
| Output terminal-root RSS | 222,716 KiB | 217,372 KiB | -2.4% |
| Writer completion | 483.847 ms | 482.463 ms | -0.3% |
| Aggregate throughput | 109.747 MiB/s | 110.061 MiB/s | +0.3% |
| External final pixel | 524.828 ms | 518.296 ms | -1.2% |

The paired median reduction was 4,278 KiB idle PSS and 5,246 KiB output PSS.
RSS was lower in every pair; output PSS was lower in eight of nine. Throughput
remained effectively unchanged.

A second detached worktree lowered only the natural alignment of `Cell.codepoint`
from four bytes to two. This preserves the direct-field representation and all
value widths while reducing `@sizeOf(Cell)` from 16 to 14 bytes. A seven-pair
alternating comparison against shared-scratch/16-byte cells found output RSS
lower in all seven pairs, with paired medians of -1,616 KiB RSS and -2,086 KiB
PSS. Median aggregate throughput changed from 110.489 to 111.816 MiB/s. Seven
simultaneous, CPU-assignment-alternated exact-renderer pairs kept identical
pixels; full-screen p50/p95 changed by -0.2%/+0.3% and rich p50/p95 by
-5.7%/-0.1%. The exact benchmark geometry structurally removes about 1.59 MiB;
30 terminals at 120x40 with 1000 hot history lines remove about 7.14 MiB. A
separate seven-pair direct baseline/final check at the established eight-pane
size retained lower output PSS/RSS and changed median aggregate throughput from
97.936 to 101.789 MiB/s; the accepted changes do not reproduce the smaller-read
buffer's eight-pane regression.

### Idle History Release

Synchronous 128-line hot history had regressed output, so the accepted path does
no cold conversion while a pane is active. Unfocused panes become eligible
30 seconds after their last PTY bytes; the focused pane waits five minutes.
The root maintenance source cold-packs at most 16 batches per second, each batch
at most 64 rows. History slabs use libc allocation and one bounded
`malloc_trim(0)` after a completion wave so released pages reach the OS. Output
resets the idle state and the slab regrows directly to its bounded capacity.

The maintained core qualification for one 120x40 grid reports 1,759,008 bytes
before and 335,580 after compaction, saving 1,423,428 bytes while preserving the
oldest content and regrowing on resumed output. A 30-grid ReleaseFast probe
reported:

| Metric | Result |
| --- | ---: |
| History bytes before | 52,770,240 |
| History bytes after | 10,067,400 |
| Saving | 42,702,840 bytes / 40.72 MiB |
| Total compaction time | 9.266 ms |
| Maximum 64-row step | 0.191 ms |
| Resume 6,000 lines | 14.701 ms |

Seven alternating active-output pairs guarded the hot path. Median throughput
changed from 112.093 to 118.842 MiB/s at eight panes and from 122.884 to
124.965 MiB/s at 32 panes. In the 32-pane path, paired active USS was effectively
flat (+88 KiB). A delayed 32-pane native sample with the benchmark's narrow
geometry moved USS from 62,772 to 55,688 KiB after compaction, a 7,084 KiB or
11.3% reduction. Normal 120-column agent panes have the larger core saving
shown above.

Raw measured trials, process accounting, medians, metadata, and checksums for
all accepted stages are retained in the artifact directory above. Structural
scratch, cell-size, and core idle-history savings are independent of host load.

## Rejected or Deferred Variants

### Smaller Per-Pane Read Arrays

At 32 panes, 32 and 64 KiB arrays often improved fairness and reduced memory.
The 32 KiB worktree reached a three-run median of 117.349 MiB/s and 55,423 KiB
output PSS versus the initial 128 KiB baseline's 99.760 MiB/s and 59,976 KiB.
At eight panes, however, the same 32 KiB choice was about 4% slower in the
alternating median. A universal smaller array therefore traded the established
small-pane benchmark for the scale benchmark.

The shared 128 KiB design captures the memory reduction without lowering the
per-read ceiling. No user-facing buffer setting was added.

### Fully Packing Cells to 12 Bytes

A direct `packed struct(u96)` experiment still occupied 16 bytes under Zig's
backing-integer layout. Splitting identity/style into separately packed 64- and
32-bit words can reach 12 bytes, but it replaces direct fields with manual
bitfield access throughout VT mutation, search, cold-history conversion, and
render packing. The accepted two-byte alignment reaches 14 bytes with unchanged
field widths and a two-line production diff. The final 2-byte theoretical gain
does not justify that broader hot-path rewrite without stronger memory pressure.

### Compacting Default Scrollback During Output

Reducing the always-hot window from 1024 lines to 128 lowered eight-pane output
PSS from roughly 44.7 MiB to 42.0 MiB, but writer completion rose from about
120 ms to 173 ms. A 64-line window was slower again. That synchronous approach
remains rejected; the accepted idle-only path above moves the same work outside
active output and bounds each maintenance step.

### Smaller Pump Budgets

128 KiB, 256 KiB, 512 KiB, and 1 MiB per-callback pump ceilings were compared
with the retained 2 MiB ceiling. Some short runs favored smaller budgets, but a
seven-pair 2 MiB versus 1 MiB confirmation favored 2 MiB at both scales:
112.231 versus 103.427 MiB/s at eight panes and 128.074 versus 120.125 MiB/s at
32 panes. The established 2 MiB bounded drain remains. A later direct GLib qualification kept one production PTY continuously flooding while 29 peer PTYs emitted exact markers. `ReleaseSafe` retained 2.377 ms marker p95 and 2.409 ms max with all markers delivered, so the measured fairness lane does not justify reopening the ceiling or source-priority decision. See [`TERMINAL_AGENT_FAIRNESS_QUALIFICATION.md`](TERMINAL_AGENT_FAIRNESS_QUALIFICATION.md).

### Page-Backed History Slabs

Direct page allocation made idle release visible without trimming, but active
output medians regressed, especially at eight panes. Eager virtual capacity and
`realloc` reduced growth copies but did not remove the tradeoff. Libc-backed
slabs plus bounded trimming retained active throughput and produced the same
native USS release, so the page-backed worktree was rejected.

### Pango and Cairo Object Reuse

Five alternating exact-renderer runs produced these ReleaseSafe p50 medians:

| Variant | Idle | Full screen | Rich style |
| --- | ---: | ---: | ---: |
| Baseline | 0.241 ms | 3.640 ms | 5.183 ms |
| Cached Cairo font options | 0.241 ms | 3.620 ms | 5.351 ms |
| Reused Pango layouts | 0.252 ms | 3.704 ms | 5.165 ms |

Neither change produced a broad win. Pango layout update cost replaced its
allocation saving, while Cairo font-option caching was noise-level for ASCII
and regressed the rich median. Both worktrees were rejected.

### GPU Renderer

The production binary performs terminal rasterization through Cairo, Pango,
FreeType, and Pixman; it creates no OpenGL/EGL/Vulkan context. KWin already uses
the GPU to composite the resulting window. A 160x50, roughly 1920x1200,
ReleaseSafe draw remains about 3.3-3.6 ms for full-screen ASCII and 5.0-5.4 ms
for rich content in isolated runs.

Splitting one fixed-size window into 32 panes does not multiply its total pixel
area by 32. The scale test was dominated by PTY/VT ingestion and per-session
state, not by repeatedly drawing 32 full-size surfaces. A GPU backend would add
glyph-atlas, shader, device-loss, driver, packaging, and fallback ownership
without addressing the measured scale bottleneck.

A smoke-only `GtkGLArea` prototype remains justified only if mapped 4K/HiDPI or
120/144 Hz evidence shows terminal drawing consumes over half the frame budget
or misses more than 1% of frames after the CPU path is measured.

## Reproduce

Run the maintained 32-pane production benchmark on an otherwise quiet mapped
X11/XWayland session:

```sh
LC_ALL=C LANG=C \
DINTTY_DEDICATED_DISPLAY=1 \
DINTTY_BENCH_TERMINALS=dintty \
DINTTY_BENCH_PANES=32 \
DINTTY_BENCH_OUTPUT_PANES=32 \
DINTTY_BENCH_RUNS=5 \
./scripts/terminal_benchmark.sh
```

Do not compare timings collected while unrelated compilers, games, VMs, or
rendering tests are active. Retain raw, summary, process, metadata, and checksum
artifacts before making a market-ranking claim. For exact detached-worktree
A/B runs, set `DINTTY_BENCH_SKIP_BUILD=1` and point
`DINTTY_BENCH_DINTTY_BIN` at the binary under test.
