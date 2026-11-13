# Native Grid Full-Stack Qualification

Status: passed on 2026-08-04 for Debug and `ReleaseSafe` on live Plasma Wayland
and X11.

Run:

```sh
DINTTY_FULL_STACK_ARTIFACT_DIR=benchmarks/native-grid-full-stack-$(date +%F) \
  ./scripts/native_grid_full_stack_qualification.sh
```

The lane builds the smoke host in isolated temporary caches, launches the
production PTY/VT/GTK/Cairo path, and retains two mapped phases per backend:

1. **Idle window:** stable terminal content, external root/process-tree memory,
   scheduler counters, and a compositor screenshot.
2. **Fullscreen:** a real GTK fullscreen transition, PTY-fed color rows,
   external memory/scheduler counters, and a second compositor screenshot.

The host fails if the mapped surface or fullscreen state is absent, if the
fallback PTY timer wakes, if idle cursor/maintenance callbacks exceed their
small fixed bounds, or if fullscreen output does not reach a rendered frame.
The runner also rejects a screenshot unless OCR finds `DINTTY mapped`; this
prevents another active window from being archived as evidence.

Retained evidence is under
[`benchmarks/native-grid-full-stack-2026-08-04/`](../benchmarks/native-grid-full-stack-2026-08-04/README.md).
The matrix passed with zero idle/fullscreen fallback PTY ticks, five idle draws,
zero idle output frames, and bounded cursor/maintenance wakeups. The smallest
retained root PSS was 33,028 KiB (`ReleaseSafe` X11 idle); the largest point
sample was 75,043 KiB (`ReleaseSafe` Wayland fullscreen).

## Proof boundary

This lane proves short mapped production-path rendering, real fullscreen
allocation, bounded idle callbacks, external `/proc` memory snapshots, and
archived compositor pixels on the exercised host. It does not prove physical
HID, GDK event-queue timing, long-idle behavior, multi-monitor behavior, or multi-day stability. Authenticated Codex and installed tmux/Zellij now have separate mapped qualification records.
