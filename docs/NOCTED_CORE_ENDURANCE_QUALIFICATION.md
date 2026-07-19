# NoctEd Core Endurance Qualification

Retained on 2026-07-18 with Zig 0.16.0 on Linux x86_64. This is the opt-in bounded endurance companion to the maintained 128-cycle core stability gate.

## Method

`./scripts/nocted_core_endurance_qualification.sh` configures the production `nocted-core-stability` runner for its fixed maximum of 512 cycles, then runs the same 128-file fixture independently in Debug and `ReleaseSafe`. Each cycle performs permission-preserving atomic save, identity-stable load, multi-selection replacement, fold analysis, immutable project scan, bounded project search, top-K Quick Open, three full-order ranking queries, and non-executing TextMate conversion.

Every operation uses the production NoctEd core modules. Zig `DebugAllocator` requested-byte accounting must return to the pre-cycle baseline after every cycle and to zero at process exit. The wrapper samples root-process PSS/RSS, validates the exact ranking fingerprint and positive samples in both modes, records elapsed wall time, and removes its project-local scratch tree.

```text
nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true
```

## Retained Results

The complete two-mode run took 459 seconds. Operation values are monotonic-clock nanoseconds and are host-local observations, not thresholds.

| Mode | Operation | p50 ns | p95 ns | p99 ns |
|---|---|---:|---:|---:|
| Debug | atomic save | 390,359,790 | 1,580,301,421 | 2,597,666,794 |
| Debug | load | 186,836 | 300,877 | 512,848 |
| Debug | edit/fold | 121,404 | 191,971 | 290,343 |
| Debug | project scan | 760,402 | 959,016 | 1,895,598 |
| Debug | project search | 2,241,018 | 2,642,003 | 4,952,211 |
| Debug | Quick Open | 4,956,257 | 6,267,059 | 19,118,625 |
| Debug | grammar conversion | 247,222 | 304,121 | 506,381 |
| ReleaseSafe | atomic save | 173,230,753 | 1,166,785,074 | 1,975,770,798 |
| ReleaseSafe | load | 60,388 | 158,365 | 325,551 |
| ReleaseSafe | edit/fold | 31,310 | 77,854 | 98,309 |
| ReleaseSafe | project scan | 203,618 | 269,677 | 456,801 |
| ReleaseSafe | project search | 629,238 | 875,011 | 1,429,382 |
| ReleaseSafe | Quick Open | 1,043,697 | 4,828,871 | 8,073,035 |
| ReleaseSafe | grammar conversion | 55,314 | 84,108 | 122,307 |

Both modes indexed 137 entries and returned 131 search results in every cycle. All 3,072 ranking evaluations retained fingerprint `12892608525683143802`. The largest allocator-accounted checkpoint was 30,689 bytes and final requested-byte residue was zero.

| Mode | Peak root PSS KiB | Peak root RSS KiB | Samples |
|---|---:|---:|---:|
| Debug | 7,092 | 7,084 | 18,144 |
| ReleaseSafe | 1,688 | 1,700 | 8,993 |

Atomic-save percentiles include the managed filesystem's replacement and durability latency. They are not a storage benchmark or release limit.

## Proof Boundary

This retains 1,024 bounded headless core cycles and substantially extends deterministic ranking, allocator, and operation-distribution evidence for NCT-106/NCT-122. It does not initialize GTK, exercise the two GLib worker lanes, publish result batches to a widget, draw through a compositor, cover varied real projects, or constitute a multi-hour/multi-day native GUI soak. Native X11/Wayland search cancellation, first-result/UI-draw/open-save-under-load distributions, peak full-process-tree memory, and long-duration lifecycle evidence remain open.

The later [GLib worker qualification](NOCTED_WORKER_QUALIFICATION.md) separately closes the shared production admission plus real headless two-pool worker/backpressure/foreground-save seam. It does not change this endurance receipt's core-only boundary or supply the still-open GTK/compositor/long-duration evidence.

## Reproduce

```sh
./scripts/nocted_core_endurance_qualification.sh
```

The maintained `./scripts/verify.sh` continues to run the faster 128-cycle baseline. The 512-cycle endurance lane is opt-in because it deliberately spends several minutes on repeated atomic filesystem and core-model work.
