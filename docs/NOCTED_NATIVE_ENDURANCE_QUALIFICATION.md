# NoctEd Native Endurance Qualification

Retained on 2026-08-04 with Zig 0.16.0 on Linux x86_64. This is the sustained native-GUI companion to the bounded NoctEd smoke, search/load, project-lifecycle, and resource receipts.

Stable receipt:

```text
nocted_native_endurance_matrix wayland=true x11=true debug=true release_safe=true rounds_per_lane=32 cycles_per_phase_per_lane=256 total_cycles_per_phase=1024 total_phase_cycles=4096 ranking_evaluations=3072 search_load=true deterministic_ranking=true gtk_batch_bounded=true project_lifecycle=true monitor_bursts=true overflow_recovery=true worker_drained=true process_tree_memory=true screenshots=true warning_fatal=true duration_recorded=true scratch_clean=true
```

## Method

`./scripts/nocted_native_endurance_qualification.sh` builds isolated Debug and `ReleaseSafe` smoke binaries, then runs 32 complete mapped workflows on live Plasma Wayland and X11 for each mode/backend lane. Every workflow repeats:

- eight resource cycles through project replacement, superseded searches, duplicate document opens, untitled Save As, close, and final worker/project drain;
- eight Find in Files first-result/completion/draw samples, eight cancellation samples, eight opens under search, eight saves under refresh, and 24 Quick Open ranking samples;
- eight actual twelve-file GIO monitor bursts, bounded GTK publication, one deterministic overflow fallback, and exact final-index checks;
- eight current-checkout open-to-model/open-to-tree-draw cycles;
- hot-exit preparation, widget teardown, and one ignored post-widget monitor callback.

The matrix therefore retains 256 cycles per phase in each lane, 1,024 cycles for each repeated phase across the four lanes, 4,096 combined phase cycles, and 3,072 full-order Quick Open ranking evaluations. Every process runs with `G_DEBUG=fatal-warnings`. The wrapper samples its complete process tree, retains the first and final rendered image from every lane, records elapsed time, and removes all build and fixture scratch through one trap.

## Retained Results

| Backend | Mode | Lane duration | Peak tree PSS / RSS | Memory samples |
|---|---|---:|---:|---:|
| Wayland | Debug | 175.260 s | 87,502 / 156,640 KiB | 781 |
| Wayland | `ReleaseSafe` | 159.702 s | 75,201 / 147,020 KiB | 685 |
| X11 | Debug | 154.096 s | 54,574 / 124,876 KiB | 657 |
| X11 | `ReleaseSafe` | 140.998 s | 44,366 / 113,860 KiB | 575 |

The complete matrix elapsed 630 seconds. Every one of the 128 independent workflows passed deterministic ranking, the exact two-batch GTK cap, foreground/scan lane separation, worker/project drain, monitor publication, overflow recovery, lifecycle teardown, warning-fatal execution, rendered capture, and scratch cleanup.

Maximum observed per-workflow p95 values are host-local observations, not release thresholds:

| Backend | Mode | First result | Completion | GTK draw | Quick Open | Project model | Project draw | Monitor publish | Overflow |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Wayland | Debug | 26.365 ms | 109.887 ms | 37.567 ms | 47.861 ms | 34.936 ms | 66.539 ms | 124.940 ms | 132.618 ms |
| Wayland | `ReleaseSafe` | 24.723 ms | 95.841 ms | 30.612 ms | 50.038 ms | 24.072 ms | 41.276 ms | 127.165 ms | 119.308 ms |
| X11 | Debug | 11.823 ms | 87.666 ms | 29.560 ms | 42.740 ms | 66.585 ms | 72.125 ms | 114.748 ms | 101.665 ms |
| X11 | `ReleaseSafe` | 9.466 ms | 71.487 ms | 22.945 ms | 52.594 ms | 31.010 ms | 37.578 ms | 111.399 ms | 101.667 ms |

## Rendered UI and Capture Integrity

The endurance tranche also hardened the native UI path:

- NoctEd now uses its product-cased window title, explicit window accessibility name, descriptive search placeholders, 28-logical-pixel width and 26-logical-pixel height file-tab close targets, and visible focus rings for the project tree, file tabs, close controls, project results, and Quick Open results.
- The prior `gdk_pixbuf_get_from_window` smoke capture could return a nonempty all-black image on Wayland. Smoke capture now draws the mapped widget tree into a Cairo image surface, samples RGB content before accepting it, and requires `render=widget` with a positive `nonblack_samples` receipt.
- All eight retained first/final images are 1220×760, contain visible project, editor, Quick Open, selection, focus, minimap, and status content, and were manually inspected after checksum verification.

## Proof Boundary

This closes NCT-106's sustained native GUI/lifecycle tranche, NCT-121's sustained cross-backend project-lifecycle tranche, and NCT-122's sustained cross-backend search/load and deterministic-ranking tranche for the current one-host alpha boundary. It does not claim multi-hour or multi-day stability, a varied-repository corpus, authenticated agent behavior, physical input, universal latency thresholds, or final compositor acceptance. Multi-day terminal/agent stability remains NCT-112; broader editor parity remains outside the alpha target.

Retained artifacts, raw per-workflow receipts, screenshots, memory summary, metadata, and checksums live in `benchmarks/nocted-native-endurance-2026-08-04/`.
