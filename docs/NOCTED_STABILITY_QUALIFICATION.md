# NoctEd Core Stability Qualification

Retained on 2026-07-18 with Zig 0.16.0 on Linux 7.1.3 x86_64, using a 16-vCPU host. The checkout did not expose repository revision metadata, so this receipt is tied to the documented source state and date rather than a commit identifier.

## Method

`./scripts/nocted_core_stability_qualification.sh` creates a disposable 128-file Zig project and runs 128 cycles in both Debug and `ReleaseSafe`. Every cycle performs a permission-preserving atomic save, identity-stable load, multi-selection replacement, fold analysis, immutable project scan, bounded project search, top-K Quick Open ranking, a three-query full-order ranking fingerprint, and non-executing TextMate conversion.

All core allocations use Zig's `DebugAllocator` with requested-byte accounting. The runner requires the active requested-byte count to return to its cycle baseline after every cycle, and requires both zero residual bytes and a clean allocator leak check before printing success. The shell samples only the qualification process's `/proc` PSS and RSS; it has no child workload.

Stable matrix receipt:

```text
nocted_core_stability_matrix debug=true release_safe=true cycles=128 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_cycles=128 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true scratch_clean=true
```

The opt-in [core endurance receipt](NOCTED_CORE_ENDURANCE_QUALIFICATION.md) reuses this exact runner and fixture at the fixed 512-cycle maximum in both modes. Its retained 459-second sequence totals 1,024 operation cycles and 3,072 ranking evaluations with zero allocator residue: `nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true`.

## Retained Results

All operation values are monotonic-clock nanoseconds. They are observations, not thresholds.

| Mode | Operation | p50 ns | p95 ns | p99 ns |
|---|---|---:|---:|---:|
| Debug | save | 22,346 | 36,809 | 47,574 |
| Debug | load | 46,669 | 54,952 | 74,734 |
| Debug | edit/fold | 68,785 | 80,481 | 118,291 |
| Debug | project scan | 528,835 | 632,273 | 789,293 |
| Debug | project search | 1,606,833 | 1,841,936 | 2,295,680 |
| Debug | Quick Open | 5,785,802 | 6,356,048 | 6,660,701 |
| Debug | grammar conversion | 155,905 | 188,307 | 231,948 |
| ReleaseSafe | save | 10,862 | 24,467 | 32,878 |
| ReleaseSafe | load | 19,957 | 28,617 | 42,082 |
| ReleaseSafe | edit/fold | 19,818 | 28,995 | 46,713 |
| ReleaseSafe | project scan | 138,909 | 168,301 | 410,762 |
| ReleaseSafe | project search | 542,856 | 650,253 | 857,435 |
| ReleaseSafe | Quick Open | 1,073,786 | 1,170,653 | 5,159,185 |
| ReleaseSafe | grammar conversion | 44,778 | 64,882 | 80,676 |

Both modes indexed 137 entries and returned 131 search results. All 128 cycles in both modes produced ranking fingerprint `12892608525683143802` for the three-query full-order corpus. The largest allocator-accounted active-byte checkpoint was 30,614 bytes, and final requested-byte residual was zero in both modes.

| Mode | Peak root PSS KiB | Peak root RSS KiB | Samples |
|---|---:|---:|---:|
| Debug | 6,800 | 6,800 | 113 |
| ReleaseSafe | 1,656 | 1,696 | 26 |

## Proof Boundary

This is repeatable allocator/leak, deterministic-ranking, and operation-distribution evidence for a bounded headless NoctEd core fixture. The 512-cycle-per-mode companion extends duration and repetition but does not change that proof boundary. The separate [GLib worker qualification](NOCTED_WORKER_QUALIFICATION.md) crosses the shared production admission policy and scan/search/save job runner through both real single-thread pools, including generation supersession, shared/per-lane caps, cancelled-job accounting, kind cancellation, lazy pools, transactional enqueue/rollback, ordered retirement, snapshot-first streaming, cooperative cancellation, two-batch backpressure, foreground save under blocked scan, drain, root memory, and zero allocator residue. It still does not initialize GTK or exercise widget publication, compositor presentation, or long-duration GUI behavior. The [project-index qualification](NOCTED_PROJECT_INDEX_QUALIFICATION.md) covers synthetic 4K/25K/100K full-scan/delta/model-memory plus rename/conflict/fallback behavior, while the [native project-lifecycle qualification](NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md) retains bounded current-project model/tree-draw distributions, actual GIO monitor bursts/UI publication delay, deterministic overflow recovery, and a post-widget late-callback guard on X11 and Wayland. The [search/load qualification](NOCTED_SEARCH_LOAD_QUALIFICATION.md) now additionally retains two eight-cycle native Wayland Debug runs for first result, completion, cancellation, GTK draw, open/save-under-load, Quick Open, bounded batches, and worker drain. Matching `ReleaseSafe`, X11, peak process-tree memory, and long-duration evidence remains open, so the NCT-106, NCT-121, and NCT-122 closure gates stay partial.
