# NoctEd Project Lifecycle Qualification

Last refreshed: 2026-08-04.

This receipt retains the bounded native-GUI NCT-121 tranche exercised by `./scripts/nocted_native_matrix.sh`. The maintained smoke runs the normal standalone editor workflow first, then exercises the same production GIO admission, background scan worker, immutable-index replacement, bounded GTK population, and project-tree draw path on X11 and Wayland.

Stable receipt:

```text
nocted_native_matrix x11=true wayland=true folding=true editor_zoom=true find_in_files=true multi_file=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true session_dirty_restore=true hot_exit=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true real_project=true lifecycle_cycles=8 gtk_tree_draw=true model_latency=true draw_latency=true monitor_burst=true burst_cycles=8 files_per_burst=12 publication_latency=true overflow_recovery=true late_callback_guard=true worker_drained=true warning_fatal=true scratch_clean=true
```

## Method

- Real-project lane: open the current DEETTY checkout eight times per backend. Each sample starts before worker admission, records the immutable-model GTK commit, and finishes at the first subsequent `GtkTreeView` draw callback. Entry count, monitor ownership, and worker/project drain state must remain stable.
- Monitor lane: create twelve files per burst for eight cycles through real filesystem writes while the production `GFileMonitor` objects are live. Each sample runs from the first write through the coalescing delay, delta worker, immutable-index publication, GTK model commit, and first subsequent tree draw. The final path must exist in the committed index.
- Overflow lane: after an actual GIO burst series, write a sentinel file and inject 257 paths through the production capped admission method. The 257th event must select exactly one conservative full-scan fallback; the sentinel must appear after worker and GTK publication. Injection makes the cap boundary deterministic because compositor/GLib event coalescing cannot guarantee 257 distinct callbacks.
- Teardown lane: destroy the window, invoke the exact production monitor callback as a late callback, and require it to return at the shutdown guard without queuing a path, source, or worker job.
- `G_DEBUG=fatal-warnings`, a nonempty native screenshot, worker drain, and scratch removal remain required by the surrounding NoctEd smoke.

## Retained Host-Local Results

Platform: Zig 0.16.0, Linux 7.1.3 x86_64, native GTK 3/GtkSourceView 4, 16 logical CPUs.

| Backend | Real entries | Model p50 / p95 / p99 | Tree draw p50 / p95 / p99 | GIO burst-to-draw p50 / p95 / p99 | Overflow recovery |
|---|---:|---:|---:|---:|---:|
| X11 | 251 | 5,161,246 / 12,102,690 / 12,102,690 ns | 15,084,137 / 19,531,636 / 19,531,636 ns | 99,570,307 / 101,585,855 / 101,585,855 ns | 100,810,595 ns |
| Wayland | 251 | 5,189,141 / 7,217,281 / 7,217,281 ns | 9,711,038 / 15,963,217 / 15,963,217 ns | 86,760,310 / 91,523,831 / 91,523,831 ns | 87,936,165 ns |

Both backends retained eight real-project cycles, eight twelve-file actual GIO bursts, eight delta publications, one deterministic overflow fallback, 36 project monitors on the retained checkout, a clean worker/project drain, one ignored post-widget callback, fatal-warning enforcement, and clean scratch teardown.

## 2026-07-18 Wayland Debug Refresh

The two native search/load runs retained on 2026-07-18 also repeated the full
project-lifecycle lane against the then-current checkout. They do not replace
the earlier cross-backend matrix, but confirm the Wayland path after subsequent
search/load instrumentation and worker changes.

| Run | Real entries | Model p50 / p95 / p99 | Tree draw p50 / p95 / p99 | GIO burst-to-draw p50 / p95 / p99 | Overflow recovery |
|---|---:|---:|---:|---:|---:|
| A | 279 | 5,087,082 / 220,858,749 / 220,858,749 ns | 10,869,728 / 224,922,130 / 224,922,130 ns | 91,208,043 / 95,401,370 / 95,401,370 ns | 85,687,516 ns |
| B | 279 | 9,393,428 / 11,522,461 / 11,522,461 ns | 16,856,293 / 19,480,474 / 19,480,474 ns | 87,393,634 / 91,734,910 / 91,734,910 ns | 86,074,940 ns |

Both refresh runs retained 289 monitor events, eight delta updates, one bounded
overflow fallback, 36 monitors, exact final indexes, real GIO bursts, worker and
project drain, fatal-warning enforcement, rendered GTK tree draws, and clean
scratch.

## 2026-08-02 Live Wayland Resource Run

The matching live Plasma Wayland resource run retained both modes, process-tree memory, the current 571-entry DEETTY checkout, 41 monitors, eight model/tree-draw cycles, eight actual 12-file GIO bursts, and one overflow recovery.

| Mode | Model p50 / p95 | Tree draw p50 / p95 | GIO burst-to-draw p50 / p95 | Overflow recovery | Peak tree PSS / RSS |
|---|---:|---:|---:|---:|---:|
| Debug | 34,732,754 / 36,308,933 ns | 39,767,082 / 47,203,587 ns | 97,898,508 / 106,499,112 ns | 96,123,161 ns | 85,947 / 138,220 KiB |
| ReleaseSafe | 6,362,136 / 6,461,687 ns | 12,834,771 / 21,683,892 ns | 91,983,927 / 94,429,120 ns | 91,677,029 ns | 75,844 / 127,936 KiB |

Stable backend receipt:

```text
nocted_resource_backend backend=wayland debug=true release_safe=true native_search_load=true native_project_lifecycle=true process_tree_memory=true scratch_clean=true
```

## Proof Boundary

This closes the bounded real-project open-to-model/open-to-tree-draw distribution, actual monitor-burst publication-latency, deterministic overflow recovery, post-widget-teardown callback, and matching live Wayland Debug/`ReleaseSafe` resource tranche on the current host. The later [native endurance qualification](NOCTED_NATIVE_ENDURANCE_QUALIFICATION.md) repeats this path 32 times per mode/backend and closes NCT-121's sustained one-host cross-backend lifecycle boundary. Neither receipt establishes universal thresholds, a varied multi-repository corpus, or multi-hour/multi-day native-GUI stability.
