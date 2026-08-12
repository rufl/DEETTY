# Native grid stability shakedown: 2026-08-05

This retained shakedown validates the NCT-112 long-run harness before elapsed multi-day qualification. It is not multi-day evidence and does not close NCT-112.

`./scripts/native_grid_stability_qualification.sh --smoke` ran two visible/hidden cycles in each Debug/`ReleaseSafe` Wayland/X11 lane through the production PTY, VT, GTK, and Cairo path. Every lane retained initial/final compositor screenshots, five external root/tree memory and scheduler samples, visible and hidden output presentation, zero fallback PTY ticks, zero hidden draws, and controlled zero exit.

Observed root PSS from first to final visible sample:

| Mode | Backend | First KiB | Final KiB | Change KiB |
| --- | --- | ---: | ---: | ---: |
| Debug | Wayland | 40,122 | 45,530 | +5,408 |
| Debug | X11 | 32,920 | 33,020 | +100 |
| `ReleaseSafe` | Wayland | 32,803 | 38,131 | +5,328 |
| `ReleaseSafe` | X11 | 25,824 | 25,836 | +12 |

The Wayland values include host/compositor allocation timing around repeated mapping and capture. The 64 MiB growth guard is deliberately broad and catches runaway growth; it is not a universal release budget.

Stable receipt:

```text
native_grid_stability_matrix smoke=true release_safe=true debug=true wayland=true x11=true cycles_per_lane=2 phase_seconds=2 expected_lane_seconds=8 authenticated_codex=false hidden_visible=true production_pty=true production_vt=true production_gtk=true production_cairo=true mapped_memory=true process_tree_memory=true scheduler_receipts=true compositor_pixels=true root_growth_guard_kib=65536 multi_day=false hid=false checksums=true scratch_clean=true
```
