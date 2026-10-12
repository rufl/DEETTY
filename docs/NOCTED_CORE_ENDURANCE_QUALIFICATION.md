# NoctEd Core Endurance Qualification

Refreshed on 2026-10-12 at commit `5882e28` with Zig 0.16.0 on Linux x86_64. This is the opt-in bounded endurance companion to the maintained 128-cycle core stability gate.

## Method

`./scripts/nocted_core_endurance_qualification.sh` configures the production `nocted-core-stability` runner for its fixed maximum of 512 cycles, then runs the same 128-file fixture independently in Debug and `ReleaseSafe`. Each cycle performs permission-preserving atomic save, identity-stable load, multi-selection replacement, fold analysis, immutable project scan, bounded project search, top-K Quick Open, three full-order ranking queries, and non-executing TextMate conversion.

Every operation uses the production NoctEd core modules. Zig `DebugAllocator` requested-byte accounting must return to the pre-cycle baseline after every cycle and to zero at process exit. The wrapper samples root-process PSS/RSS, validates the exact ranking fingerprint and positive samples in both modes, records elapsed wall time, and removes its project-local scratch tree.

```text
nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true
```

## Retained Results

The complete two-mode run took 59 seconds. Operation values are monotonic-clock nanoseconds and are host-local observations, not thresholds.

| Mode | Operation | p50 ns | p95 ns | p99 ns |
|---|---|---:|---:|---:|
| Debug | atomic save | 127,687 | 199,105 | 247,682 |
| Debug | load | 113,600 | 139,137 | 186,547 |
| Debug | edit/fold | 154,013 | 178,966 | 259,698 |
| Debug | project scan | 1,321,789 | 1,391,587 | 1,653,368 |
| Debug | project search | 4,282,048 | 4,491,166 | 5,117,967 |
| Debug | Quick Open | 964,600 | 1,017,817 | 1,283,575 |
| Debug | grammar conversion | 346,355 | 402,572 | 506,339 |
| ReleaseSafe | atomic save | 92,231 | 144,493 | 195,419 |
| ReleaseSafe | load | 55,422 | 72,203 | 105,774 |
| ReleaseSafe | edit/fold | 52,327 | 73,830 | 111,344 |
| ReleaseSafe | project scan | 382,109 | 459,012 | 622,404 |
| ReleaseSafe | project search | 1,460,785 | 1,598,485 | 2,352,430 |
| ReleaseSafe | Quick Open | 231,414 | 281,890 | 362,228 |
| ReleaseSafe | grammar conversion | 125,176 | 155,904 | 202,353 |

Both modes indexed 137 entries and returned 131 search results in every cycle. All 3,072 ranking evaluations retained fingerprint `12892608525683143802`. The largest allocator-accounted checkpoint was 30,689 bytes and final requested-byte residue was zero.

| Mode | Peak root PSS KiB | Peak root RSS KiB | Samples |
|---|---:|---:|---:|
| Debug | 6,348 | 6,348 | 225 |
| ReleaseSafe | 1,712 | 1,708 | 67 |

Atomic-save percentiles include the managed filesystem's replacement and durability latency. They are not a storage benchmark or release limit.

## Proof Boundary

This retains 1,024 bounded headless core cycles and substantially extends deterministic ranking, allocator, and operation-distribution evidence for NCT-106/NCT-122. It does not initialize GTK, exercise the two GLib worker lanes, publish result batches to a widget, draw through a compositor, cover varied real projects, or constitute a multi-hour/multi-day native GUI soak. The later [native endurance qualification](NOCTED_NATIVE_ENDURANCE_QUALIFICATION.md) closes the sustained one-host GTK/Wayland/X11 tranche without changing this core-only proof boundary.

The later [GLib worker qualification](NOCTED_WORKER_QUALIFICATION.md) separately closes the shared production admission plus real headless two-pool worker/backpressure/foreground-save seam. It does not change this endurance receipt's core-only boundary or supply the still-open GTK/compositor/long-duration evidence.

## Reproduce

```sh
./scripts/nocted_core_endurance_qualification.sh
```

The maintained `./scripts/verify.sh` continues to run the faster 128-cycle baseline. The 512-cycle endurance lane is opt-in because it deliberately spends several minutes on repeated atomic filesystem and core-model work.
