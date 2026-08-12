# NoctEd Search and Load Qualification

Last refreshed: 2026-08-04.

This receipt retains the completed deterministic-ranking and allocator tranche of
NCT-122 and defines the native GTK search/load lane now implemented by
`scripts/nocted_native_smoke.sh`. The core runner uses the production immutable
index, project search, Quick Open scorer, atomic document I/O, folding, and
allocator paths. The native lane uses the production two-lane filesystem worker,
streaming GTK batches, `GtkTreeView` draw callback, document foreground lane, and
project-refresh scan lane.

Stable retained core receipt:

```text
nocted_core_stability_matrix debug=true release_safe=true cycles=128 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_cycles=128 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true scratch_clean=true
```

Stable opt-in endurance extension:

```text
nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true
```

The dated [core endurance receipt](NOCTED_CORE_ENDURANCE_QUALIFICATION.md) retains the complete 459-second run, all operation distributions, root memory samples, and exact proof boundary. Its 1,024 total core cycles extend deterministic-ranking and allocator evidence but do not execute the GLib workers or GTK publication path.

## Retained Headless GLib Worker Results

The maintained [worker receipt](NOCTED_WORKER_QUALIFICATION.md) now qualifies
the shared admission policy called by production `App` and then executes the
production `Worker` through two real single-thread GLib pools without
initializing GTK:

```text
nocted_worker_matrix debug=true release_safe=true shared_admission_policy=true generation_supersession=true shared_queue_cap=64 lane_queue_cap=32 cancelled_lane_excluded=true kind_cancel=true pending_lookup=true lazy_pool_creation=true transactional_enqueue=true append_failure_safe=true push_failure_rollback=true ordered_retirement=true glib_thread_pools=true worker_lanes=2 project_scan=true search_streaming=true snapshot_first=true cooperative_cancellation=true search_batch_size=24 search_batch_cap=2 backpressure_exercised=true foreground_save_under_backpressure=true worker_drained=true allocator_leak_free=true process_memory=true scratch_clean=true
```

Debug and `ReleaseSafe` each indexed 201 entries, returned all 193 expected
results through nine streamed batches, and reached exactly two outstanding
batches. While generation 1 was blocked at that cap, the independent foreground
pool completed and exposed an atomic save before the GLib main context was
drained. Its first delivered batch cancelled that generation; retirement took
2,168,244 ns in Debug and 1,103,171 ns in `ReleaseSafe`. The replacement search
returned the unsaved snapshot first, both pools drained, allocator residue was
zero, and root PSS/RSS sampling was positive. These are host-local observations,
not thresholds.

## Retained Host-Local Core Results

Platform: Zig 0.16.0, Linux 7.1.3 x86_64, 16 logical CPUs.

| Mode | Search p50 / p95 / p99 | Quick Open p50 / p95 / p99 | Peak active allocator bytes | Peak root PSS / RSS |
|---|---:|---:|---:|---:|
| Debug | 1,606,833 / 1,841,936 / 2,295,680 ns | 5,785,802 / 6,356,048 / 6,660,701 ns | 30,614 | 6,800 / 6,800 KiB |
| ReleaseSafe | 542,856 / 650,253 / 857,435 ns | 1,073,786 / 1,170,653 / 5,159,185 ns | 30,614 | 1,656 / 1,696 KiB |

Both modes repeated three Quick Open queries for all 128 cycles and produced the
same full-order fingerprint, `12892608525683143802`. Every cycle returned active
requested bytes to its baseline; both processes exited with zero requested bytes
and a clean `DebugAllocator` leak check.

```text
ranking_fingerprint=12892608525683143802 ranking_queries=3 ranking_cycles=128 ranking_deterministic=true
```

## Native GTK Method

The native fixture contains 257 matching files and more than 200 indexed entries.
For eight cycles per run the maintained smoke now records:

- Find in Files start to first streamed GTK batch, worker completion, and first
  result-tree draw, summarized as p50/p95/p99;
- superseded-generation cancellation to main-thread job retirement;
- document open latency while a no-match search owns the scan lane;
- atomic save latency while a full project refresh owns the scan lane;
- actual 30 ms coalesced Quick Open key-to-results latency for three queries and
  a full result-order fingerprint across eight cycles;
- GTK search-batch high water against the two-batch cap and final worker drain.

`scripts/nocted_resource_qualification.sh` builds that same native lane in Debug
and `ReleaseSafe`, keeps its build caches and temporary tree below one
trap-cleaned project-local root, and samples process-tree PSS/RSS.
`scripts/nocted_native_matrix.sh` drives the lane on X11 and Wayland with fatal
GTK warnings.

Cross-backend matrix contract:

```text
nocted_search_load_native_matrix x11=true wayland=true cycles=8 first_result_latency=true completion_latency=true cancellation_latency=true ui_draw_latency=true open_under_search=true save_under_refresh=true deterministic_ranking=true gtk_batch_bounded=true worker_drained=true warning_fatal=true scratch_clean=true
```

## Current Native Evidence Boundary

Two consecutive direct Debug runs reached the live Wayland compositor on
2026-07-18 and completed all eight native cycles with fatal GTK warnings,
bounded two-batch publication, deterministic ranking, foreground/scan lane
separation, worker drain, rendered screenshot validation, and clean scratch.
On 2026-08-02, an Xvfb-backed X11 resource run and a later live Plasma Wayland run completed the same eight-cycle search/load, monitor, and real-project lifecycle paths in both Debug and `ReleaseSafe`, including process-tree memory sampling. These are host-local observations, not release thresholds.

| Run | Entries | First result p50 / p95 / p99 | Completion p50 / p95 / p99 | Cancellation p50 / p95 / p99 |
|---|---:|---:|---:|---:|
| A | 268 | 4,274,139 / 8,986,642 / 8,986,642 ns | 42,470,427 / 60,595,784 / 60,595,784 ns | 169,492 / 5,697,943 / 5,697,943 ns |
| B | 267 | 4,504,595 / 8,264,545 / 8,264,545 ns | 40,943,572 / 63,493,454 / 63,493,454 ns | 5,323,472 / 6,219,874 / 6,219,874 ns |

| Run | First GTK draw p50 / p95 / p99 | Open under search p95 | Save under refresh p95 | Quick Open p50 / p95 / p99 |
|---|---:|---:|---:|---:|
| A | 6,138,464 / 9,519,686 / 9,519,686 ns | 7,128,955 ns | 696,734 ns | 37,219,936 / 50,422,035 / 52,098,253 ns |
| B | 8,796,449 / 13,313,796 / 13,313,796 ns | 3,505,102 ns | 1,006,415 ns | 34,738,109 / 38,869,038 / 39,484,881 ns |

```text
nocted_search_load_wayland_evidence backend=wayland optimize=Debug runs=2 cycles_per_run=8 first_result_latency=true completion_latency=true cancellation_latency=true ui_draw_latency=true open_under_search=true save_under_refresh=true deterministic_ranking=true gtk_batch_peak=2 gtk_batch_cap=2 worker_drained=true warning_fatal=true rendered=true scratch_clean=true
```

The retained X11 resource run produced:

| Mode | First result p50 / p95 | Completion p50 / p95 | First draw p50 / p95 | Quick Open p50 / p95 / p99 | Peak tree PSS / RSS |
|---|---:|---:|---:|---:|---:|
| Debug | 7,028,545 / 9,265,213 ns | 73,085,734 / 80,709,392 ns | 11,547,255 / 17,955,840 ns | 33,657,424 / 37,043,811 / 188,475,639 ns | 91,779 / 234,360 KiB |
| ReleaseSafe | 4,220,732 / 7,134,150 ns | 24,751,136 / 31,453,702 ns | 11,464,369 / 18,775,491 ns | 32,895,975 / 35,759,468 / 38,017,126 ns | 84,714 / 224,696 KiB |

The retained live Wayland resource run produced:

| Mode | First result p50 / p95 | Completion p50 / p95 | First draw p50 / p95 | Quick Open p50 / p95 / p99 | Peak tree PSS / RSS |
|---|---:|---:|---:|---:|---:|
| Debug | 12,035,188 / 47,965,268 ns | 97,390,233 / 233,643,796 ns | 16,029,406 / 34,227,770 ns | 40,102,132 / 57,655,969 / 95,937,306 ns | 85,947 / 138,220 KiB |
| ReleaseSafe | 2,215,896 / 5,274,196 ns | 24,174,252 / 37,149,464 ns | 8,289,271 / 17,818,837 ns | 34,354,477 / 36,105,932 / 36,441,522 ns | 75,844 / 127,936 KiB |

Both backends and modes retained deterministic three-query ranking across eight cycles, the exact two-batch GTK cap, foreground/scan lane separation, worker drain, eight 12-file GIO monitor bursts, one bounded overflow recovery, and eight current NOCTTY project model/tree-draw cycles:

```text
nocted_search_load_resource_matrix debug=true release_safe=true cycles=8 first_result_latency=true completion_latency=true cancellation_latency=true ui_draw_latency=true open_under_search=true save_under_refresh=true deterministic_ranking=true process_memory=true worker_drained=true scratch_clean=true
nocted_resource_backend backend=x11 debug=true release_safe=true native_search_load=true native_project_lifecycle=true process_tree_memory=true scratch_clean=true
nocted_resource_backend backend=wayland debug=true release_safe=true native_search_load=true native_project_lifecycle=true process_tree_memory=true scratch_clean=true
```

NCT-122 retains X11 and live Wayland Debug/`ReleaseSafe` baseline evidence. The later [native endurance qualification](NOCTED_NATIVE_ENDURANCE_QUALIFICATION.md) repeats 32 complete workflows per lane, closes the sustained one-host cross-backend ranking/search boundary, and retains rendered first/final UI plus process-tree memory. The retained core/endurance/worker lanes
separately prove cross-mode deterministic ranking, bounded core latency, shared
generation/cap/cancellation admission, real headless worker/backpressure and
foreground independence, allocator cleanup, and root-process memory. None of
these receipts proves universal thresholds, multi-hour or multi-day stability, a varied-project corpus, or Sublime
Text 2/Zed parity.
