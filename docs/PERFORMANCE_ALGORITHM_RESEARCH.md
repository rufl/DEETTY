# Performance and Algorithm Research

Research date: 2026-07-16. Implementation status refreshed: 2026-07-31.

Status: architecture decision, implemented design record, and remaining
measurement contract. The accepted lower-complexity changes are present in the
source; focused smoke is not retained compatibility or performance-distribution
proof and does not supersede `TERMINAL_BENCHMARK.md` or `DAILY_DRIVER.md`.

## Executive Decision

NOCTTY should keep its current native Zig plus GTK/Cairo architecture. The
retained benchmark already shows competitive ingestion and low process memory;
the next gains are in presentation latency, draw-time allocation, terminal
correctness, resize behavior, and scrollback representation. A GPU rewrite or a
dedicated read/write/render thread set per pane would spend complexity and
memory before the current profile justifies it.

NoctEd should keep GtkSourceView 4 and `GtkTextBuffer` as its production text
surface. Its next gains are in the worktree index, filesystem change handling,
search result latency, worker admission, and quick-open ranking. Replacing the
GTK text model with a rope or piece tree would require either a custom editor
view or two synchronized text models, both of which conflict with the current
lean and stable product boundary.

### Jeremy Huang / `1jehuang` optimization review

A 2026-07-31 review of Jeremy Huang's current public projects used pinned source
revisions rather than copying architecture by reputation:

- [`jcode` slowness guide](https://github.com/1jehuang/jcode/blob/65aefb6714ae5f978ebb2d74943679e34b3ae1f8/docs/FINDING_SLOWNESS.md) and [memory budget](https://github.com/1jehuang/jcode/blob/65aefb6714ae5f978ebb2d74943679e34b3ae1f8/docs/MEMORY_BUDGET.md): enumerate heavy states, measure cold and warm work separately, gate deterministic work counters where possible, prove a gate by deliberately breaking it, cap caches, and fix duplicated ownership before raising a memory budget;
- [`handterm` optimization record](https://github.com/1jehuang/handterm/blob/6dbda57f6e62e2942165e855010ccbedca9f577d/OPTIMIZATION.md): benchmark each pipeline boundary, reuse hot buffers, coalesce PTY-driven presentation, share expensive process/runtime state, and delete an architecture when profiling shows a simpler host path wins;
- [`agentgrep` benchmarks](https://github.com/1jehuang/agentgrep/blob/66b1148bae243e74e4501bb84068d7d049fa4275/docs/BENCHMARKS.md): reject candidates before expensive structure work and normalize repeated text once rather than once per candidate;
- [`ffp`](https://github.com/1jehuang/ffp/blob/138e145fd8cc178c83461b3ec3b19bcaf2559a17/README.md): cap large pools, keep expensive discovery off the interaction path, cache genuinely expensive previews, and only fan work across cores when scale measurements justify it;
- [`jengine` targets](https://github.com/1jehuang/jengine/blob/005f09845b0a525ff7d33a46411606695913cd58/docs/PERFORMANCE_TARGETS.md): attribute host, setup, upload, compute, and download costs separately; record cache warmth; reduce dispatch and orchestration before chasing a faster inner kernel;
- [`mermaid-rs-renderer` benchmark design](https://github.com/1jehuang/mermaid-rs-renderer/blob/7ff1196ed297c32a65a6b3cdc28f3ca3787fb65e/docs/benchmark-suite-design.md): separate correctness, quality, stability, and performance; retain cold/warm, tail-latency, memory, and scaling evidence;
- [`niri-workspaces-rs`](https://github.com/1jehuang/niri-workspaces-rs/blob/43061415a7707d32757e02c76c9a662aee488c94/src/main.rs): subscribe once to incremental events and maintain local state instead of reopening IPC and recomputing full state for every update.

NOCTTY already follows most of those macro lessons: native/no-browser startup,
one process for many panes, frame-clock and resize coalescing, terminal dirty
spans, reusable renderer scratch, bounded caches, immutable project snapshots,
cheap fuzzy eligibility before scoring, lazy minimap/Tree-sitter work, and two
bounded filesystem lanes. The review therefore did not justify a GPU rewrite,
new allocator, new thread pool, daemon split, dependency, or runtime telemetry.

It did expose one concrete Quick Open regression. The two-row dynamic program
used `std.mem.swap` on whole 257-element arrays, copying a 2,056-byte score row
for every path byte. A focused one-off ReleaseFast in-memory harness with two
warmups and twelve samples per query measured about 939 ms p50 for `file` and
918 ms for `modulefilezig` on a synthetic 100,000-file index. Swapping active slices
instead, initializing only `query.len + 1` states, and normalizing the bounded
query/extension once reduced p50 to 6.8-7.3 ms and 15.8-16.2 ms respectively,
with identical ranking fingerprints: at least 128x and 56x faster on those
broad-match fixtures. The retained DebugAllocator-backed `ReleaseSafe`
100,000-entry qualification reports 69.5 ms and enforces a deliberately loose
500 ms regression budget.

### Local profiling gate

Use the existing exact renderer and real PTY pipeline directly:

```sh
./scripts/native_grid_renderer_qualification.sh
./scripts/native_grid_pipeline_qualification.sh
```

They retain Debug/ReleaseSafe timing, allocation, memory, and pixel evidence
without a separate profiling wrapper or runtime metrics.

The implementation order and current acceptance state are:

1. NCT-119: frame-clock presentation, allocation-bounded Cairo glyph delivery,
   and resize coalescing — implemented; exact synthetic renderer plus real-shell
   PTY/VT-to-Cairo tranches qualified, mapped compositor acceptance partial.
2. NCT-122: latency-prioritized NoctEd filesystem work, streaming Find in Files,
   and scalable top-K quick open — implemented, acceptance partial.
3. NCT-121: a compact shared worktree index, ignore semantics, and coalesced
   filesystem/file-change monitoring — implemented, acceptance partial.
4. NCT-110: a bounded table-driven VT parser, rich cell semantics, terminal
   replies, synchronized output, and a real installed Codex login/Vim/btop
   headless tranche — implemented, authenticated/cross-backend acceptance partial.
5. NCT-120: stable logical lines, true reflow, compact style storage, and a
   two-tier hot/cold scrollback representation — implemented and qualified.
6. NCT-112: allocator-accounted production-session repetition, stubborn
   foreground-group teardown, and a controlled installed-application sequence —
   bounded tranches qualified; native long-run acceptance partial.

Machine-readable decision receipt:

```text
performance_algorithm_research=true terminal_frame_clock=implemented terminal_glyph_cache=implemented terminal_resize_coalescing=implemented terminal_sync_output=implemented terminal_logical_lines=implemented terminal_gpu_rewrite=deferred terminal_per_pane_threads=deferred nocted_shared_index=implemented nocted_search_streaming=implemented nocted_worker_priority=implemented nocted_custom_rope=deferred nocted_tree_sitter_default=false
```

## Audit Baseline

The recommendations were checked against the current implementation rather than
derived from peer architecture alone.

### NOCTTY implementation baseline

- `src/terminal/Vt.zig` has a visible-grid ring, hot direct cells, compact cold
  logical lines, monotonic IDs, grapheme anchors, true primary-screen reflow,
  and a bounded table-driven parser with rich cell state and replies.
- `src/gui/native_grid_host.c` uses one owned frame-clock callback while mapped,
  retains the 100 ms hidden path, caches guarded glyph conversions, coalesces
  resize, and consumes ABI-v2 dirty column spans with full-redraw fallback. Its
  exact production draw function is shared with the display-independent
  Debug/`ReleaseSafe` renderer qualification.
- NCT-120's 100000-line Debug/`ReleaseSafe` reflow and grow/shrink qualification
  is complete. NCT-110's bounded protocol/state, malformed-input, Unicode
  mutation, complete Unicode 17 grapheme, and allocator-accounting matrix is
  also retained. The real installed-TUI lane adds Codex's unauthenticated
  welcome/login surface plus Vim and btop terminal-mode/input/exit proof through
  the production PTY/VT model in both modes:
  `terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true`.
  A second retained installed-tool lane covers nano, less, and dialog through the same production PTY/session/VT model: `terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`.
  A third retained installed-tool lane covers top, watch, info, whiptail, fzf, SQLite, Glances, Bash, man, and SFTP through that production model: `terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`.
  NCT-112 adds 64 ordinary and eight forced production real-PTY lifecycles per
  mode with zero allocator/process residue and separate root/tree memory
  sampling. NCT-119 additionally retains 128 idle, full-screen, and
  rich-style draws per mode with exact repeat/cross-mode pixels, renderer-owned
  warm/resize allocation counts, process-CPU percentiles, and root memory:
  `native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true`.
  The complementary real-shell pipeline retains two 64-sample runs per mode
  through production PTY/`TerminalSession`/VT/ABI-v2/Cairo with input-write and
  PTY-read-start-to-draw percentiles, repeat/cross-mode pixels, zero warm-frame
  renderer allocations, and separate root/tree memory:
  `native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true`.
  NCT-110/NCT-112/NCT-119 still require authenticated/broader real-agent
  cross-backend, multi-day hidden/visible, archived compositor pixels,
  full-stack allocation/idle-wakeup, and mapped end-to-end
  latency-distribution evidence.

### NoctEd implementation baseline

- `ProjectIndex.zig` admits up to 100000 entries into one immutable path arena,
  applies bounded directory-scoped ignore rules, and supports retained snapshots.
- Project search borrows the index, searches immutable unsaved-buffer snapshots
  first, reuses bounded chunks, and publishes at most 24 results or 25 ms with
  a two-batch GTK backpressure cap.
- `Worker.zig` and `main.zig` separate foreground document I/O from
  background scan/search/index-delta work through at most two lazy single-thread lanes.
- `QuickOpen.zig` uses smart-case gating, path-aware scoring, and fixed-size
  top-K selection. Coalesced GIO monitors drive external clean/dirty decisions
  and capped structural create/delete/move/rename batches; exact changed paths
  and subtrees refresh on the scan lane, while ambiguous/control/overflow events
  deliberately request the full scanner.
- Production editing is a GtkSourceView over a `GtkSourceBuffer`. The loaded
  Zig byte slice is copied into GTK and then released with the worker job.
- Two retained eight-cycle Debug runs now cross the live Wayland GTK result
  tree for first-result/completion/cancellation, first draw, open/save under
  load, coalesced Quick Open, the exact two-batch cap, deterministic ranking,
  and worker/project drain. Matching `ReleaseSafe`, X11, peak process-tree
  memory, and long-duration cross-backend distributions remain NCT-122 work.

## Terminal Algorithms

### 1. Align mapped presentation to the GTK frame clock

**Peer evidence.** GTK 3's
[`gtk_widget_add_tick_callback`](https://docs.gtk.org/gtk3/method.Widget.add_tick_callback.html)
runs before a display frame and its `GdkFrameClock` may be synchronized to the
monitor refresh rate. The
[`GdkFrameClock` documentation](https://docs.gtk.org/gdk3/class.FrameClock.html)
explains that this also lets GTK combine painting into fewer frames.

**Implemented in NOCTTY.** The mapped one-shot 16 ms timeout is replaced by a
one-shot tick callback that queues accumulated dirty spans and then returns
`G_SOURCE_REMOVE`. Keep the 100 ms hidden timeout because an unmapped widget may
not receive frame ticks. Retain one pending source/token per pane and cancel it
through the existing authoritative teardown path.

**Why this is better.** A fixed 16 ms timer is accidentally correct only near
60 Hz and can land just after a frame deadline. A one-shot frame callback stays
idle when there is no output and adapts to 60/90/120/144 Hz displays.

**Proof.** The display-independent qualification now retains input-write and
PTY-read-start through exact Cairo-draw p50/p95/p99 using local smoke-only
instrumentation. Still add GTK-key-event, frame-clock, compositor-presentation,
missed-frame, presentation-rate, and idle-wakeup distributions on Plasma
Wayland and X11. No telemetry or persistent event log is introduced.

### 2. Remove avoidable Cairo glyph-array churn

**Peer evidence.** Alacritty preloads printable ASCII glyphs for each font face
in its
[`GlyphCache`](https://github.com/alacritty/alacritty/blob/master/alacritty/src/renderer/text/glyph_cache.rs).
Cairo explicitly supports caller-provided stack arrays for small
[`cairo_scaled_font_text_to_glyphs`](https://www.cairographics.org/manual/cairo-cairo-scaled-font-t.html)
calls.

**Implemented in NOCTTY.** A pane-owned guarded glyph cache avoids repeated
normal-row Cairo conversions. On font family, size, scale, or face changes it
rebuilds the eligible printable glyph map while keeping
the existing per-codepoint fallback for shaping, fallback fonts, grapheme
clusters, and any mapping that is not one input codepoint to one glyph.

**Guardrail.** Cached glyph indices must not silently replace shaping for
Unicode or complex scripts. Visual corpus comparison and Cairo status/fallback
coverage remain required acceptance evidence.

**Bounded proof retained.** The display-independent production renderer lane
compares idle, full-screen ASCII/color, and grapheme/rich-style fixtures across
128 measured frames per build mode. Repeated surfaces have zero changed pixels,
Debug/`ReleaseSafe` PNGs are byte-identical, renderer-owned warm-frame
allocation is zero, grow/shrink scratch is bounded, and process-CPU p50/p95/p99
plus root memory are retained in
`docs/NATIVE_GRID_RENDERER_QUALIFICATION.md`. It counts row/glyph/cache storage,
not Cairo/Pango/library-internal allocations.

The real-shell pipeline lane additionally feeds this context through the
production PTY, bounded `TerminalSession` pump, VT grid, and ABI-v2 packed rows.
It retains input-write/PTY-read-start-to-Cairo percentiles, repeat/cross-mode
pixels, zero warm-frame renderer allocations, and separate root/tree memory.

**Proof still required.** Retain the fixed live-output corpus on mapped Plasma
Wayland and X11 surfaces with Cairo fallback conversion counts, full-stack
allocation evidence, archived pixel artifacts, frame-clock intervals, and
end-to-end timestamps. The display-independent fixture does not replace that
acceptance boundary.

### 3. Track dirty column spans, not only dirty rows

**Peer evidence.** Alacritty rows retain an upper bound for occupied/modified
cells and reset only that prefix in
[`Row`](https://github.com/alacritty/alacritty/blob/master/alacritty_terminal/src/grid/row.rs).
Its
[`DamageTracker`](https://github.com/alacritty/alacritty/blob/master/alacritty/src/display/damage.rs)
also keeps adjacent frame damage and previous cursor/selection state.

**Implemented in NOCTTY.** Each visible row retains a bounded dirty span with a
clean sentinel. Every VT mutation records its affected range. ABI v2 returns
row spans and retains a complete-row callback only as a compatibility fallback
inside the same size/version-checked struct. Full clear,
selection, font, theme, mapping, and resize operations still invalidate the
required full region.

**Proof.** Compare cells submitted and Cairo draw time for shell typing, a
single-cell progress spinner, ncurses partial updates, and full-screen agent
redraws. Do not accept extra branch cost if full-screen throughput regresses.

### 4. Coalesce interactive resize and defer expensive reflow

**Peer evidence.** foot performs a fast truncating resize while the user is
dragging and delays full reflow/client resize until a short idle period; its
documented default is 100 ms in
[`foot.ini(5)`](https://manpages.debian.org/testing/foot/foot.ini.5.en.html).

**Implemented in NOCTTY.** GTK size allocations are latest-value updates. The
PTY/grid resize commits once after a bounded quiet period and at final geometry.
The existing dimensions overlay shows the pending target. NCT-120 reflow now
runs only for the final coalesced geometry instead of every drag allocation.

**Guardrail.** The maximum delay is bounded, the final geometry must always be
committed, and mouse coordinates must continue to target the displayed grid.
Wayland and X11 require separate rendered drag tests.

### 5. Replace the ad hoc CSI state with a bounded parser contract

**Peer evidence.** Ghostty describes a SIMD-assisted parser and dedicated I/O
architecture in its
[`README`](https://github.com/ghostty-org/ghostty), but its own 1.3 stability
work emphasizes real recording corpora, AFL++ parser/stream fuzzing, and error
path injection in the
[`1.3 release notes`](https://ghostty.org/docs/install/release-notes/1-3-0).
Correctness and bounded failure behavior are the transferable lessons; SIMD is
not the first step.

Kitty 0.48.0 uses one child-monitor I/O thread to drain all PTYs into bounded
1 MiB parser buffers, coalesces main-loop wakeups with `input_delay`, and routes
contiguous text through `simd-string.h` before screen mutation. NOCTTY already
has contiguous ASCII runs and coalesced presentation; its current transferable
steps are larger bounded reads and direct hot-history ring reuse. Add a shared
I/O reader only if PTY-read-to-draw profiling proves GTK-thread parsing remains
the bottleneck; per-pane thread sets remain deferred.

**Implemented in NOCTTY.** NCT-110 introduces:

- a table-driven state machine for Ground, Escape, CSI entry/parameter/
  intermediate/ignore, OSC, DCS, and string termination;
- a fixed parameter array plus bounded subparameters, explicit missing/default
  values, and saturation without heap allocation;
- bounded OSC/DCS payload sinks with discard states after a cap;
- parser events separated from terminal state mutation and a bounded reply
  channel for DA/DSR/DECRQM/XTGETTCAP;
- a protocol policy layer for clipboard, hyperlinks, notifications, and future
  graphics rather than parser-owned GUI effects;
- byte-chunk ASCII/control classification only after corpus and fuzz parity.

`libghostty` remains a valid isolated adapter candidate. Ghostty currently
describes its behavior as stable but its API signatures as still in flux, so
its types must not enter workspace, config, theme, or editor state.

### 6. Implement synchronized output for agent TUIs

The synchronized-output protocol uses DEC private mode 2026 to let a TUI update
the grid while the terminal presents the previous completed frame. The
[`protocol description`](https://github.com/contour-terminal/vt-extensions/blob/1a9fde53d80c4a60b1be44c5a4492d86ec9f9cce/synchronized-output.md)
defines begin/end and feature detection. Ghostty specifically lists Claude Code
as software affected by unsynchronized large redraws in its
[`synchronized-output guidance`](https://ghostty.org/docs/help/synchronized-output).

NOCTTY continues parsing and mutating state while mode 2026 is set, but
suppress mapped presentation until reset. A bounded deadman timer must release
a stuck frame; the exact timeout should be selected from slow-stream tests
rather than copied blindly. Nested begin requests should not grow unbounded.

### 7. Introduce stable logical lines and true reflow

**Peer evidence.** WezTerm's
[`Screen`](https://github.com/wezterm/wezterm/blob/main/term/src/screen.rs)
uses a deque of lines, a stable-row offset, per-line change sequence numbers,
and joins/re-wraps wrapped rows when the primary screen changes width.
Alacritty's
[`Storage`](https://github.com/alacritty/alacritty/blob/master/alacritty_terminal/src/grid/storage.rs)
uses a logical ring origin and dynamically active scrollback length.

**Implemented in NOCTTY.** NCT-120 makes logical identity independent from
physical wrapping:

- each logical line has a monotonic ID, wrap metadata, and change generation;
- viewport, selection, and search anchors use `(line_id, grapheme_offset)`;
- physical rows are views/segments produced for the current column count;
- primary-screen width changes join prior wrapped segments and split them at
  grapheme boundaries; alternate-screen resize remains non-reflowing;
- resize can reuse unchanged logical lines and reflow only affected spans;
- dropped history advances a stable base generation so stale anchors fail
  deterministically.

This is a correctness prerequisite for compact cold scrollback. It should not
be hidden inside renderer code.

### 8. Keep hot cells direct; compress cold history

Adding truecolor, underline color, hyperlinks, grapheme clusters, and more style
flags directly to every retained cell could multiply the cost of 100,000-line
history. Kitty explicitly warns against huge interactive cell history and keeps
an optional separate UTF-8 pager history in its
[`scrollback options`](https://raw.githubusercontent.com/kovidgoyal/kitty/master/kitty/options/definition.py).
Its `HistoryBuf` is a preallocated circular row store: overwriting a full ring
advances `start_of_data` and copies directly into that slot rather than
releasing and searching for storage. NOCTTY now applies that bounded-ring
property to already-hot rows while retaining compact cold history for larger
configured limits. Ghostty 1.3 also reports that allocating alternate-screen memory on demand saves
multiple MiB per terminal.

Recommended representation:

- keep the visible screen and a small hot scrollback window as directly
  addressable cells;
- represent colors/styles through a bounded intern table or row-local style
  runs rather than duplicating two 24-bit colors plus hyperlink data per cell;
- encode cold logical lines as UTF-8 grapheme bytes plus run-length style spans
  and wrap metadata;
- decode only viewport/search rows into reusable scratch storage;
- allocate the alternate screen on first activation and release it according to
  a measured reuse policy.

The cold format stays memory-only by default. Disk-backed unlimited history is
not recommended without an explicit GUI privacy policy, secure permissions,
retention controls, and crash cleanup.

### 9. Adopt Unicode algorithms, not codepoint width guesses

The cell model must implement extended grapheme segmentation from
[`Unicode Standard Annex #29`](https://unicode.org/reports/tr29/) and a tested
terminal-width policy based on the current Unicode width data. Combining marks,
emoji ZWJ sequences, regional indicators, variation selectors, and wide
graphemes must remain atomic for cursor movement, selection, reflow, and damage.
Generated Unicode tables should be versioned source artifacts with provenance
and conformance fixtures, not runtime downloads.

### 10. Defer GPU and per-pane thread rewrites

Ghostty's dedicated read/write/render threads and GPU renderer are credible for
its architecture. foot also exposes render worker counts but warns they cannot
usefully exceed visible rows. Those designs do not imply that NOCTTY should
copy them now.

NOCTTY's current descriptor-driven GLib pump is idle when panes are idle, and
the retained benchmark is already competitive on ingestion and memory. A GPU
backend adds context/device loss, atlas lifetime, shader, driver, and packaging
work. Three dedicated threads per pane add stacks, scheduling, locks, and more
shutdown states. Reconsider only if frame-latency and CPU profiles remain out of
budget after NCT-119/NCT-110/NCT-120.

## Editor Algorithms

### 1. Store the project index as one shared immutable snapshot

Replace per-entry path allocations with a contiguous path arena and compact
entries containing offsets, lengths, parent/child ranges, kind, and flags.
Publish the completed snapshot atomically and retain it with a small thread-safe
reference count while search jobs run. A project search then borrows one shared
snapshot rather than cloning all paths.

The tree model should materialize root children initially and populate a
directory's direct child range on expansion. Search and Quick Open still see
the complete file index. This permits a measured increase beyond 4096 entries
without constructing a GTK row for every path at startup.

Acceptance metrics are index bytes/path, allocation count, scan time, first
tree paint, model rows created before interaction, and peak memory during a
project refresh while the prior snapshot remains live.

### 2. Add ignore semantics and coalesced filesystem deltas

ripgrep's default behavior combines recursive traversal with `.gitignore`,
`.ignore`, hidden-file, and binary filtering; its
[`README`](https://github.com/BurntSushi/ripgrep) is a useful behavioral target.
NoctEd should implement a bounded, non-executing ignore stack with directory
scope, negation, and deterministic precedence. It should not require `rg` or
spawn Git for correctness.

GIO already provides
[`GFileMonitor`](https://docs.gtk.org/gio/class.FileMonitor.html), move-aware
events, and a same-file
[`rate limit`](https://docs.gtk.org/gio/method.FileMonitor.set_rate_limit.html).
The implemented adapter uses that existing dependency behind the NoctEd boundary:

- coalesce event bursts for 75 ms into a transaction capped at 256 paths;
- map rename/move pairs when the backend supplies them;
- refresh exact files or directory subtrees on the existing scan lane, rebuild
  the compact immutable snapshot, and transactionally replace the GTK staging model;
- treat ignore-control changes, malformed paths, unknown events, overflow,
  unavailable recursive coverage, and ambiguous moves as bounded full-rescan requests;
- cancel every monitor and release pending owned paths before model/widget teardown.

Open documents need their own file identity `(device, inode, size, mtime_ns)`.
Clean documents may offer/reload a confirmed external change; dirty documents
must enter an explicit conflict decision. Hash contents only when metadata is
ambiguous, not on every maintenance pass.

### 3. Separate latency-sensitive and scanning filesystem work

The implemented admission policy uses two lazily created single-thread lanes
under the existing global job cap:

- foreground lane: load, save, Save As resolution, session/settings recovery;
- scan lane: project indexing/deltas, ignore discovery, Find in Files.

Cancel obsolete generations before admission, cap each kind separately, and
keep GTK publication on the main thread. This prevents a user-visible save from
waiting behind a long search while retaining a hard maximum of two filesystem
workers. A custom priority actor is only justified if two lanes fail the memory
budget.

### 4. Stream bounded search batches with backpressure

Zed's project-search work distinguishes total throughput from first-result
latency, prioritizes confirming known candidate matches, and notes that
unbounded result publication can flood the UI thread in
[`Nerd-sniped: Project Search`](https://zed.dev/blog/nerd-sniped-project-search).

NoctEd should:

- search unsaved open-buffer snapshots before corresponding disk files;
- reuse a 64 KiB read buffer and carry at most `query_len - 1` overlap plus a
  bounded preview accumulator across chunks;
- reject binary input early and validate UTF-8 incrementally;
- publish immutable batches of 16-32 lines or every 25 ms, whichever comes
  first;
- allow at most two unconsumed GTK batches and pause the scan lane when full;
- preserve one result row per matching source line while retaining all compact
  match ranges needed for highlighting and later replace preview;
- cancel and release old batches immediately on query generation changes;
- sort only within deterministic batches or at completion, without withholding
  the first visible result.

Literal search should continue using the Zig standard library until a corpus
proves a custom Two-Way/SIMD routine wins. ripgrep's larger lesson is adaptive
I/O, literal extraction, bounded parallel walking, and ignore handling, not
blindly copying a regex engine or adding a required executable dependency.

### 5. Use a hybrid fuzzy matcher and a top-K heap

fzy separates fast subsequence eligibility from a dynamic-programming score
with consecutive, path separator, word boundary, CamelCase, and extension
bonuses in its
[`algorithm description`](https://github.com/jhawthorn/fzy/blob/master/ALGORITHM.md).

For NoctEd:

1. Apply a cheap ASCII smart-case subsequence gate.
2. Score survivors with a bounded two-row DP; queries are already capped at 256
   bytes, but the scoring path should use a lower interactive cap.
3. Add bonuses for basename start, slash, separator, CamelCase, consecutive
   matches, and exact extension.
4. Retain 100 winners in a fixed-size max-heap, then sort only those winners.
5. Cache basename offsets and compact boundary metadata in the index, not a
   duplicate lowercased copy of every path.

At the current 100000-entry cap this bounded selection is required. Retain
key-to-results p95 and ranking fixtures, not only raw filter throughput.

### 6. Use GtkTextBuffer marks for multi-selection transactions

GTK's
[`TextBuffer`](https://docs.gtk.org/gtk3/class.TextBuffer.html) provides marks
with gravity and nested user-action grouping. Represent secondary carets and
selection endpoints as paired marks. Before an edit, normalize overlaps, sort
ranges by start, and apply replacements from the end of the buffer backward
inside one begin/end user action. Rebuild visual secondary selections after the
transaction and keep one primary GTK selection for native clipboard/IME
behavior.

NCT-104 now implements this design without a second text model: bounded Unicode
ranges are normalized in the core, paired marks render secondary selections,
edits run backward inside one user action, folding state is cleared before the
transaction, and the primary GTK selection remains authoritative for native
clipboard/IME ownership. Unit and warning-fatal native gates cover overlap,
reversed/empty normalization, Unicode text, exact one-action undo, rendered
secondary tags, and both X11 and Wayland. Arbitrary empty multi-caret placement
remains outside this select-all-occurrences slice.

### 7. Do not replace GtkTextBuffer with a rope now

Zed's persistent Rope/SumTree gives copy-on-write snapshots and logarithmic
aggregate lookup, described in
[`Rope & SumTree`](https://zed.dev/blog/zed-decoded-rope-sumtree). VS Code's
[`piece-tree account`](https://code.visualstudio.com/blogs/2018/03/23/text-buffer-reimplementation)
shows how append-only buffers, line-start references, and a red-black tree avoid
per-line object overhead. Both are sound editor-core designs.

They are not a drop-in optimization for NoctEd. GtkSourceView renders and edits
a `GtkTextBuffer`; mirroring a custom rope into it duplicates text and creates a
difficult consistency boundary. The current editable cap is 1 MiB, while GTK
already caches character and line counts and provides marks, undo grouping,
tags, and shared views. Profile realistic large files first. Revisit a custom
buffer only with a deliberate custom view/backend project and its own rendering,
accessibility, IME, bidi, selection, undo, and syntax plan.

### 8. Keep GtkSourceView highlighting; pilot Tree-sitter narrowly

Tree-sitter supports old-tree incremental reparsing and cheap copied trees for
background work in its
[`advanced parsing guide`](https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html).
Its query cursors are reusable and can restrict work to byte/point ranges per
the
[`query API`](https://tree-sitter.github.io/tree-sitter/using-parsers/queries/4-api.html).

NoctEd should retain GtkSourceView `.lang` highlighting as the zero-extra-runtime
default. Language definition v2 is compatible across GtkSourceView 2 through 5
according to the
[`language definition guide`](https://gnome.pages.gitlab.gnome.org/gtksourceview/gtksourceview5/lang-intro.html).
A Tree-sitter pilot may support structural folding, selection expansion, and
symbols for a few bundled, provenance-audited grammars. It must stay behind an
adapter and must not become a production dependency merely to duplicate syntax
coloring.

Imported TextMate/Sublime syntax should be parsed once under strict size/depth
caps, converted into the existing non-executing syntax model, and cached by
content digest. Grammar packages may not execute code or download dependencies.

### 9. Keep document loading simple until the size policy changes

The current 1 MiB editable and 8 MiB preview caps bound transient duplication
when GTK copies the loaded text. Chunked validation can reduce temporary memory
and improve cancellation, but mmap or a custom paging model does not remove
GtkTextBuffer's final copy. Prioritize the worktree/search allocations first.
If preview limits rise, add a separate read-only paged viewer rather than
pretending GtkSourceView is a zero-copy large-file surface.

## Dependency Decision

| Candidate | Decision | Reason |
| --- | --- | --- |
| GTK 3 frame clock | Use | Already linked; improves mapped scheduling without a renderer rewrite. |
| Cairo caller-owned glyph arrays | Use | Already linked; removes hot allocation while retaining fallback. |
| GFileMonitor | Use behind adapter | Already linked through GIO; supports native events and coalescing. |
| Generated Unicode tables | Use | Source-pinned, offline, auditable, and required for correctness. |
| `libghostty-vt` | Evaluate behind `src/ghostty` | Strong Zig implementation, but API signatures remain in flux. |
| Tree-sitter | Optional pilot only | Useful for structural features; unnecessary for baseline highlighting. |
| ripgrep executable/library | Do not require | Learn from its algorithms; keep standalone behavior and dependency budget. |
| GPU API/renderer library | Defer | No measured bottleneck justifies device/atlas/driver complexity yet. |
| Custom rope/piece tree | Defer | Incompatible with the current GtkSourceView ownership boundary. |

## Measurement Gates

The deterministic NCT-106 robustness baseline now covers 256 actual document
files, 256 TextMate JSON mutations, a one-time rewrite between read and identity
commit, and a perpetual-change retry cap in both Debug and `ReleaseSafe`:
`nocted_fuzz_race_matrix debug=true release_safe=true document_cases=256 grammar_cases=256 external_read_race=true stable_retry=true retry_cap=3 perpetual_churn_rejected=true scratch_clean=true`.
The bounded core stability lane adds 128 allocator-accounted cycles per mode for
atomic save/load, multi-selection/folding, scan/search, Quick Open, and grammar
conversion. Active requested bytes return to the cycle baseline and zero at
exit, while monotonic p50/p95/p99 and root-process PSS/RSS are retained in
`docs/NOCTED_STABILITY_QUALIFICATION.md`:
`nocted_core_stability_matrix debug=true release_safe=true cycles=128 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_cycles=128 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true scratch_clean=true`.
The opt-in endurance companion exercises the same lower-complexity algorithms for 512 cycles per mode and retains 1,024 total operation cycles plus 3,072 full-order ranking evaluations: `nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true`. This extends bounded core repetition; it does not convert headless algorithm evidence into GTK worker, compositor, varied-project, or multi-day stability proof.
The maintained worker companion now qualifies the shared admission and queue transaction called by production `App`—newer-generation cancellation, the 64 attached-job cap, 32-live-job lane caps, cancelled-lane exclusion, kind cancellation, pending lookup, lazy pool creation, failure-safe append, push rollback, and ordered retirement—then executes the search/index model through `Worker` and two real one-thread GLib pools: `nocted_worker_matrix debug=true release_safe=true shared_admission_policy=true generation_supersession=true shared_queue_cap=64 lane_queue_cap=32 cancelled_lane_excluded=true kind_cancel=true pending_lookup=true lazy_pool_creation=true transactional_enqueue=true append_failure_safe=true push_failure_rollback=true ordered_retirement=true glib_thread_pools=true worker_lanes=2 project_scan=true search_streaming=true snapshot_first=true cooperative_cancellation=true search_batch_size=24 search_batch_cap=2 backpressure_exercised=true foreground_save_under_backpressure=true worker_drained=true allocator_leak_free=true process_memory=true scratch_clean=true`. It deliberately holds scan at its two-batch cap, proves atomic foreground save completes independently, then retires one cancelled generation and drains the snapshot-first replacement. This supplies real headless admission/queue/scheduling/backpressure evidence, not GTK publication/draw, compositor, or sustained-load distributions.
Together these remove stale-byte/new-identity publication and supply bounded
core allocator/operation plus worker-concurrency evidence. The separate project-index matrix retains
real disposable 4K/25K/100K full-scan/delta timing, exact compact/two-snapshot
model bytes, directory rename, replacement conflict, ignore/257-event fallback,
root memory, and zero-residual allocator proof in
`docs/NOCTED_PROJECT_INDEX_QUALIFICATION.md`:
`nocted_project_index_matrix debug=true release_safe=true scales=4000,25000,100000 immutable_delta=true quick_open_scale=true quick_open_release_safe_budget_ms=500 directory_rename=true replacement_conflict=true ignore_fallback=true overflow_fallback=true scan_time=true delta_time=true index_memory=true two_snapshot_peak=true process_memory=true allocator_leak_free=true scratch_clean=true`.
The native matrix now complements those headless lanes with eight current-
repository open-to-model/open-to-tree-draw samples per backend, eight actual
twelve-file GIO burst-to-draw samples, deterministic 257-event overflow
recovery, worker drain, and the exact callback invoked after widget teardown.
The dated host-local values and injection boundary are retained in
`docs/NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md`. These bounded lanes do not
replace retained fuzz duration, sustained multi-hour/multi-day cross-backend
lifecycle evidence, or the remaining search/load distributions below.

The deterministic terminal baseline runs 23 SHA-256-pinned protocol cases over
six equivalent feed schedules, 128 malformed 4096-byte cases with resize churn,
256 Unicode mutations, and all 766 Unicode 17 grapheme-break cases in both
Debug and `ReleaseSafe`. Observable parser/grid/reply/title/mode/hyperlink state
is diffed, fixed parser bounds are asserted, and allocator requested bytes
return to baseline after every fixture and zero at exit:
`terminal_compatibility_matrix debug=true release_safe=true protocol_cases=23 schedules=6 malformed_cases=128 unicode_mutations=256 grapheme_cases=766 allocator_leak_free=true scratch_clean=true`.
This supplies bounded deterministic regression/conformance evidence, not a
retained fuzz-duration, parser-throughput, rendered, or real-agent result.

The bounded real-TUI baseline starts installed Codex 0.144.5 with a disposable
empty `CODEX_HOME`, Vim 9.2 with a disposable fixture, and btop 1.4.7 with
disposable XDG roots. Debug and `ReleaseSafe` route each through production
launch-profile, PTY, `TerminalSession`, and VT state; require application-owned
screen markers and terminal modes; route controlled exit input; assert
foreground identity and zero process/allocator residue; and sample root/tree
memory:
`terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true`.
The Codex case is explicitly unauthenticated and never submits a model request;
all three cases remain headless, short, and non-compositor evidence.

The bounded terminal-session baseline separately runs production spawn, resize,
VT output/title ingestion, exit polling, and teardown for 64 ordinary plus
eight forced real-PTY lifecycles in each safe build mode. The forced foreground
loop ignores `SIGHUP` and `SIGTERM`; teardown must exhaust the 500 ms grace,
reap the shell, remove the foreground group even when the shell exits first,
and return requested bytes to baseline after every cycle and zero at exit. It
retains lifecycle p50/p95/p99 plus independently sampled root and full-tree
PSS/RSS:
`terminal_session_qualification_matrix debug=true release_safe=true normal_cycles=64 forced_cycles=8 sessions_per_mode=72 total_sessions=144 allocator_leak_free=true forced_group_shutdown=true latency_percentiles=true root_memory_separate=true process_tree_memory=true scratch_clean=true`.
This is short headless one-host process evidence, not PTY-read-to-draw,
key-to-frame, multi-day, compositor, or real-agent evidence.

The bounded renderer baseline calls the exact production Cairo draw function
for 128 idle, full-screen, and rich-style frames per build mode after warm-up.
It requires exact repeated pixels, byte-identical cross-mode PNGs, zero
renderer-owned warm-frame allocations, bounded grow/no-allocation shrink
scratch, process-CPU percentiles, root memory samples, and scratch cleanup:
`native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true`.
This synthetic lane is display-independent one-host draw evidence. The
complementary real-shell pipeline is also retained:
`native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true`.
Neither lane is mapped GTK, compositor/frame-clock, library allocator, GPU,
authenticated-agent, or visible-presentation proof.

Every implementation slice needs a before/after artifact from identical inputs.
Median-only claims are insufficient.

### Terminal gate

- retained: 64 ordinary plus eight forced real-PTY lifecycles per mode with
  allocator baseline/zero-exit accounting, root/tree memory, lifecycle
  percentiles, shell reaping, and stubborn foreground-group removal;
- retained: one installed Codex login/Vim/btop production PTY/VT sequence per
  mode with synchronized output, alternate-screen/focus/mouse/truecolor/Unicode
  state, routed exit input, foreground identity, root/tree memory, and zero
  allocator/process residue;
- retained: 128 idle, full-screen, and rich-style exact production-Cairo draws
  per mode with repeat/cross-mode pixels, renderer-owned warm/resize allocation
  counts, process-CPU percentiles, root memory, and self-cleaning scratch;
- retained: two 64-sample real-shell PTY/VT-to-exact-Cairo runs per mode with
  input-write/PTY-read-start-to-draw p50/p95/p99, repeat/cross-mode pixels,
  zero warm-frame renderer allocations, separate root/tree memory, and clean scratch;
- startup and root-only/process-tree PSS at 1/2/4/8 panes;
- mapped GTK key-event-to-frame and compositor-presentation p50/p95/p99;
- frame intervals, missed deadlines, and presentations per output burst;
- idle wakeups and hidden-pane wakeups;
- mapped cells/rows submitted, Cairo fallback conversions, full-stack draw
  allocations, and draw CPU beyond the retained fixed-fixture renderer counts;
- mapped interactive resize allocations, peak memory, and final PTY geometry;
- parser corpus throughput, retained malformed-sequence fuzz duration, peak
  parser storage, and regression diffs when advertised capabilities change;
- authenticated Codex plus Claude Code, Antigravity, broader ncurses, tmux, and
  zellij visual/interaction/exit receipts on Plasma Wayland and X11.

The benchmark stops Yakuake before and after its isolated comparison run; it
no longer preserves active Yakuake sessions.

### Editor gate

- retained: synthetic 4K/25K/100K scan/delta time, compact index/two-snapshot
  model bytes, allocator cleanup, directory rename, replacement conflict, and
  ignore/overflow fallback;
- retained: eight current-NOCTTY project model/tree-draw distributions per
  backend, actual GIO monitor-burst publication delay, deterministic overflow
  recovery, and a post-widget late-callback guard;
- retained: 128 Debug and `ReleaseSafe` allocator-accounted core cycles with a
  three-query full-order Quick Open fingerprint stable across every cycle;
- still required: sustained long-duration Wayland/X11 project lifecycle and
  varied-real-project evidence;
- still required from a compositor-capable retained native run: Find in Files
  first-result p50/p95/p99, total time, peak memory, cancellation latency,
  queued GTK batches, UI frame delay, open/save p95 while search and refresh are
  active, and coalesced Quick Open key-to-results p50/p95/p99;
- still required: long native open/edit/fold/search/save/close and varied
  project-switch allocator/leak qualification beyond the bounded core cycles.

## Deferred or Rejected Shortcuts

- Do not infer rendering latency from writer completion.
- Do not advertise a richer `TERM` before replies and behavior pass a captured
  compatibility corpus.
- Do not add unbounded history, file indexing, search workers, result queues,
  syntax packages, or filesystem watches.
- Do not make an external `rg`, Git, Node, Electron, Bun, browser runtime, or
  network service a product requirement.
- Do not put libghostty, parser, toolkit, or monitor types into durable product
  state.
- Do not add telemetry, remote benchmarks, update pings, crash uploads, or
  runtime grammar downloads.
- Do not claim Sublime Text, Zed, Ghostty, Kitty, or Yakuake parity from these
  design decisions. Only retained runtime evidence can support such claims.

## Source Set

Primary or project-maintained sources accessed on 2026-07-16:

- Alacritty grid storage, row occupancy, damage tracking, and glyph cache:
  [storage](https://github.com/alacritty/alacritty/blob/master/alacritty_terminal/src/grid/storage.rs),
  [row](https://github.com/alacritty/alacritty/blob/master/alacritty_terminal/src/grid/row.rs),
  [damage](https://github.com/alacritty/alacritty/blob/master/alacritty/src/display/damage.rs),
  [glyph cache](https://github.com/alacritty/alacritty/blob/master/alacritty/src/renderer/text/glyph_cache.rs).
- Ghostty architecture, synchronized output, and 1.3 engineering notes:
  [repository](https://github.com/ghostty-org/ghostty),
  [synchronized output](https://ghostty.org/docs/help/synchronized-output),
  [release notes](https://ghostty.org/docs/install/release-notes/1-3-0).
- WezTerm screen/reflow model:
  [screen.rs](https://github.com/wezterm/wezterm/blob/main/term/src/screen.rs).
- Kitty scrollback policy:
  [option definitions](https://raw.githubusercontent.com/kovidgoyal/kitty/master/kitty/options/definition.py).
- foot render-worker and resize policy:
  [foot.ini(5)](https://manpages.debian.org/testing/foot/foot.ini.5.en.html).
- GTK/GIO/Cairo APIs:
  [frame callback](https://docs.gtk.org/gtk3/method.Widget.add_tick_callback.html),
  [frame clock](https://docs.gtk.org/gdk3/class.FrameClock.html),
  [file monitor](https://docs.gtk.org/gio/class.FileMonitor.html),
  [text buffer](https://docs.gtk.org/gtk3/class.TextBuffer.html),
  [Cairo scaled fonts](https://www.cairographics.org/manual/cairo-cairo-scaled-font-t.html).
- Zed editor structures and project search:
  [Rope and SumTree](https://zed.dev/blog/zed-decoded-rope-sumtree),
  [syntax-aware editing](https://zed.dev/blog/syntax-aware-editing),
  [project search](https://zed.dev/blog/nerd-sniped-project-search).
- VS Code piece-tree engineering:
  [Text Buffer Reimplementation](https://code.visualstudio.com/blogs/2018/03/23/text-buffer-reimplementation).
- Tree-sitter incremental parse/query APIs:
  [advanced parsing](https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html),
  [query API](https://tree-sitter.github.io/tree-sitter/using-parsers/queries/4-api.html).
- Search and fuzzy ranking:
  [ripgrep](https://github.com/BurntSushi/ripgrep),
  [fzy algorithm](https://github.com/jhawthorn/fzy/blob/master/ALGORITHM.md).
- Unicode grapheme rules:
  [UAX #29](https://unicode.org/reports/tr29/).
