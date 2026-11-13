# Native Grid Presentation Qualification

Status: bounded NCT-119 mapped GTK presentation tranche passed on live Plasma Wayland and X11 on 2026-08-03.

## Qualified Boundary

`scripts/native_grid_presentation_qualification.sh` builds the smoke-only native host in Debug and `ReleaseSafe`, then runs 64 independent updates on each live backend. Every update:

1. invokes the production `on_key_press` handler with a synthetic printable `GdkEventKey` after the drawing area is mapped;
2. writes through the production `TerminalSession` PTY to `cat`;
3. waits for the production PTY pump and VT grid to report a new output serial;
4. records the first mapped GTK/Cairo `draw` completion; and
5. records the matching `GdkFrameClock` `after-paint` completion and frame timing.

The runner also records GDK predicted-presentation timing. Plasma Wayland supplied completed `GdkFrameTimings` presentation timestamps for 64/64 Debug samples and 62/64 `ReleaseSafe` samples. This host's X11 backend returned no completed presentation timestamps, so the X11 receipt stops at mapped draw, frame-clock `after-paint`, and predicted presentation.

## Retained Result

All values are one-host observations in milliseconds, not release thresholds.

| Mode | Backend | Key handler→draw p50 / p95 / p99 | Key handler→after-paint p50 / p95 / p99 | Frame interval p50 / p95 / p99 |
| --- | --- | ---: | ---: | ---: |
| Debug | Wayland | 7.007 / 7.430 / 7.944 | 11.211 / 11.719 / 12.282 | 13.343 / 13.773 / 14.269 |
| Debug | X11 | 14.397 / 14.616 / 14.892 | 14.422 / 14.638 / 14.917 | 16.540 / 16.886 / 17.062 |
| ReleaseSafe | Wayland | 6.818 / 7.799 / 7.943 | 11.128 / 12.065 / 12.239 | 13.222 / 14.096 / 14.332 |
| ReleaseSafe | X11 | 14.480 / 14.789 / 14.862 | 14.513 / 14.827 / 14.901 | 16.646 / 16.907 / 17.079 |

| Mode | Backend | GDK predicted presentation p50 / p95 / p99 | Completed presentation samples | Key handler→presentation p50 / p95 / p99 |
| --- | --- | ---: | ---: | ---: |
| Debug | Wayland | 33.128 / 33.772 / 33.917 | 64 | 32.970 / 33.704 / 34.322 |
| Debug | X11 | 39.285 / 39.516 / 39.780 | 0 | unavailable |
| ReleaseSafe | Wayland | 22.945 / 24.335 / 25.085 | 62 | 22.898 / 24.538 / 25.868 |
| ReleaseSafe | X11 | 39.342 / 39.616 / 39.674 | 0 | unavailable |

All four runs retained 64 samples, 63 frame intervals, zero reported missed deadlines, a mapped surface, production PTY/VT/GTK paths, controlled zero process exit, and trap-cleaned build/cache/temp state. The stable contract is:

```text
native_grid_presentation_matrix debug=true release_safe=true wayland=true x11=true samples_per_run=64 production_pty=true production_vt=true production_gtk=true mapped_surface=true key_to_draw=true key_to_frame=true frame_intervals=true wayland_presentation_feedback=true x11_presentation_feedback_optional=true synthetic_gtk_keys=true gdk_event_queue=false hid=false scratch_clean=true
```

## Proof Boundary

This closes the previously absent mapped production GTK key-handler-to-draw and key-handler-to-frame-clock distribution. It also retains actual GDK presentation feedback where Plasma Wayland exposes it.

The start event is synthetic and calls the production handler directly. It does not enter through the GDK event queue, a keyboard device, KWin input dispatch, or consented HID capture. `after-paint` is GTK frame completion, not a photon measurement. X11 supplied predictions but no completed presentation timestamp. The lane does not archive compositor pixels, measure mapped idle/fullscreen wakeups, count Cairo/Pango/GLib allocator internals, or establish multi-day behavior. The complementary [full-stack qualification](NATIVE_GRID_FULL_STACK_QUALIFICATION.md) now retains the missing idle/fullscreen pixels, memory, and wakeup evidence and closes NCT-119. Physical input and final compositor acceptance remain separate release operations.

## Reproduce

Run from a live Plasma session with both Wayland and Xwayland access:

```sh
DEETTY_DEDICATED_DISPLAY=1 ./scripts/native_grid_presentation_qualification.sh
```

The script owns and removes its prefixes, Zig caches, and temporary outputs.
