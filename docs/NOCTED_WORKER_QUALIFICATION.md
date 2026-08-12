# NoctEd GLib Worker Qualification

Retained on 2026-07-18 with Zig 0.16.0, GLib 2.88.2, and Linux x86_64.
This display-independent receipt covers the production `Worker`
admission, queue transaction, and GLib scheduling seam without initializing
GTK.

## Method

`./scripts/nocted_worker_qualification.sh` builds a dedicated runner in Debug
and `ReleaseSafe`, links only the GLib system boundary, and creates two exclusive
single-thread `GThreadPool` lanes matching NoctEd's foreground and scan lanes.
Each mode creates a 193-file fixture and then:

- calls the same admission functions used by `App.submitWorkerJob` and proves
  newer same-kind generations cancel two older live jobs before admission, a
  generation-zero job cancels none, 64 attached jobs reject globally, and 32
  live jobs reject only their own lane;
- proves cancelled jobs stop consuming per-lane pressure while remaining part
  of the shared attached-job cap, foreground and scan accounting are
  independent, kind cancellation is idempotent, and pending-kind lookup retains
  cancelled jobs until main-thread retirement;
- injects an allocator failure before append and a queue-push failure after
  append, requiring an untouched list in the first case and exact prior pointer
  order in the second; successful commit and identity retirement are then
  required to be ordered and idempotent;
- starts with both production `Pools` slots empty, requires scan enqueue to
  create only the scan pool, requires foreground enqueue to create the other
  pool later, and uses the exact production enqueue path for every real job;
- scans it through the production `project_scan` worker payload;
- starts a snapshot-first search on the scan lane, allows the worker to fill
  both outstanding 24-result batch slots, and holds the GLib main context so
  the worker is genuinely stopped at its backpressure cap;
- starts an atomic document save on the independent foreground lane and
  requires the completed file to be readable before any queued main-context
  callback is drained;
- cancels generation 1 from its first delivered batch, requires bounded
  main-thread retirement, then drains generation 2 through all streamed
  batches;
- verifies the unsaved snapshot supplies the first result, each batch is at
  most 24 results, neither search exceeds two outstanding batches, both pools
  drain, every job retires through the shared identity helper, both pool slots
  return to null after shutdown, and `DebugAllocator` requested bytes return to
  zero.

Stable contract:

```text
nocted_worker_matrix debug=true release_safe=true shared_admission_policy=true generation_supersession=true shared_queue_cap=64 lane_queue_cap=32 cancelled_lane_excluded=true kind_cancel=true pending_lookup=true lazy_pool_creation=true transactional_enqueue=true append_failure_safe=true push_failure_rollback=true ordered_retirement=true glib_thread_pools=true worker_lanes=2 project_scan=true search_streaming=true snapshot_first=true cooperative_cancellation=true search_batch_size=24 search_batch_cap=2 backpressure_exercised=true foreground_save_under_backpressure=true worker_drained=true allocator_leak_free=true process_memory=true scratch_clean=true
```

## Retained Results

| Mode | Indexed entries | Final results | Old/new batch peak | New batches | Cancellation to retirement | Peak root PSS / RSS |
|---|---:|---:|---:|---:|---:|---:|
| Debug | 201 | 193 | 2 / 2 | 9 | 2,168,244 ns | 6,328 / 10,320 KiB |
| ReleaseSafe | 201 | 193 | 2 / 2 | 9 | 1,103,171 ns | 1,040 / 4,484 KiB |

Both modes observed positive root-process memory while the runner was live,
retired the cancelled job, completed the foreground save while the scan worker
was blocked at two outstanding batches, drained all queued callbacks and jobs,
and exited with `allocator_residual_bytes=0`. These values are host-local
observations, not release thresholds.

## Proof Boundary

This receipt executes the real lazy `GThreadPool` lifecycle, transactional list
append, `g_thread_pool_push`, identity retirement, `g_idle_add`, GLib
main-context callbacks, immutable index/search model, snapshot search, batch
ownership, cancellation checks, and atomic document-save path. Production
`App.submitWorkerJob`, `cancelWorkerJobs`, `hasWorkerJob`, shutdown, and job
retirement delegate to these exact qualified functions. Failure injection
qualifies append failure and post-append push rollback without claiming that
GLib itself was forced to fail on this host. The headless runner does not
initialize GTK or exercise widget publication, `GtkTreeStore` drawing,
compositor presentation, key-to-pixel latency, varied projects, or a sustained
GUI soak. The native Debug/`ReleaseSafe` resource lane and X11/Wayland search
matrix in [the search/load receipt](NOCTED_SEARCH_LOAD_QUALIFICATION.md) cross
that GTK boundary; the later [native endurance receipt](NOCTED_NATIVE_ENDURANCE_QUALIFICATION.md)
closes NCT-122's sustained one-host acceptance tranche.

## Reproduce

```sh
./scripts/nocted_worker_qualification.sh
```

The lane is part of `./scripts/verify.sh`; all build caches, fixture files, and
output are isolated below one trap-cleaned scratch directory.
