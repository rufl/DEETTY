# Authenticated native-grid stability shakedown: 2026-08-05

This retained `ReleaseSafe` Plasma Wayland/X11 shakedown validates the authenticated `--run` path without claiming elapsed stability. It used one visible/hidden cycle with two-second phases per backend, so `multi_day=false` and NCT-112 remains open.

Each lane submitted one exact Codex ephemeral read-only request after the native window and production PTY/VT path started. The response file contained exactly `NOCTTY_STABILITY_CODEX_OK`. The stability clock began only after that response completed, then retained mapped-visible and unmapped-hidden output, zero hidden draws, zero fallback PTY ticks, phase wakeups, external root/tree memory, initial/final compositor screenshots, and controlled zero exit.

Root PSS changed from 39,439 to 39,467 KiB on Wayland and from 25,885 to 25,913 KiB on X11, +28 KiB in each lane. These short values validate accounting and the broad 64 MiB runaway-growth guard; they are not long-run thresholds.

Stable receipt:

```text
native_grid_stability_matrix smoke=false release_safe=true debug=false wayland=true x11=true cycles_per_lane=1 phase_seconds=2 expected_lane_seconds=4 authenticated_codex=true hidden_visible=true production_pty=true production_vt=true production_gtk=true production_cairo=true mapped_memory=true process_tree_memory=true scheduler_receipts=true compositor_pixels=true root_growth_guard_kib=65536 multi_day=false hid=false checksums=true scratch_clean=true
```
