# NoctEd Native Endurance Evidence: 2026-08-04

This directory retains the live Plasma Wayland/X11 Debug/`ReleaseSafe` endurance matrix documented in `docs/NOCTED_NATIVE_ENDURANCE_QUALIFICATION.md`.

```text
nocted_native_endurance_matrix wayland=true x11=true debug=true release_safe=true rounds_per_lane=32 cycles_per_phase_per_lane=256 total_cycles_per_phase=1024 total_phase_cycles=4096 ranking_evaluations=3072 search_load=true deterministic_ranking=true gtk_batch_bounded=true project_lifecycle=true monitor_bursts=true overflow_recovery=true worker_drained=true process_tree_memory=true screenshots=true warning_fatal=true duration_recorded=true scratch_clean=true
```

Each of the four lanes ran 32 complete mapped workflows. Every workflow repeated eight resource, search/load, monitor, and real-project lifecycle cycles, then drained workers and exercised post-widget callback safety. The complete matrix lasted 630 seconds.

| Backend | Mode | Duration | Peak tree PSS / RSS |
|---|---|---:|---:|
| Wayland | Debug | 175.260 s | 87,502 / 156,640 KiB |
| Wayland | `ReleaseSafe` | 159.702 s | 75,201 / 147,020 KiB |
| X11 | Debug | 154.096 s | 54,574 / 124,876 KiB |
| X11 | `ReleaseSafe` | 140.998 s | 44,366 / 113,860 KiB |

The `*.log` files retain every workflow receipt. `summary.csv` and `metadata.txt` retain aggregate duration and memory observations. The first and final `*.png` in each lane were rendered from the mapped GTK widget tree through Cairo, required positive sampled RGB content, and were manually inspected. `SHA256SUMS` covers every retained file.

This is bounded one-host sustained native-GUI evidence, not multi-day stability, a varied-project corpus, authenticated-agent proof, physical-input proof, or final compositor acceptance.
