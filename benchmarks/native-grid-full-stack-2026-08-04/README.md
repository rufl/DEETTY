# Native Grid Full-Stack Qualification: 2026-08-04

This retained matrix exercises the production PTY, VT, GTK, and Cairo path in
mapped NOCTTY windows on the live Plasma session. Debug and `ReleaseSafe` were
run through native Wayland and X11 backends at an idle window and after a real
fullscreen transition.

## Result

| Mode | Backend | Phase | Root PSS KiB | Root RSS KiB | Tree PSS KiB | Tree RSS KiB | Image |
|---|---|---:|---:|---:|---:|---:|---|
| Debug | Wayland | idle | 47,019 | 85,704 | 55,277 | 111,456 | 1545×849 |
| Debug | Wayland | fullscreen | 62,170 | 95,756 | 70,427 | 121,508 | 1920×1080 |
| Debug | X11 | idle | 39,006 | 71,668 | 47,153 | 97,100 | 1536×780 |
| Debug | X11 | fullscreen | 39,986 | 72,832 | 48,133 | 98,264 | 1920×1080 |
| ReleaseSafe | Wayland | idle | 39,841 | 78,568 | 48,140 | 104,320 | 1545×849 |
| ReleaseSafe | Wayland | fullscreen | 75,043 | 109,304 | 53,990 | 114,320 | 1920×1080 |
| ReleaseSafe | X11 | idle | 33,028 | 65,784 | 41,287 | 91,440 | 1536×780 |
| ReleaseSafe | X11 | fullscreen | 33,962 | 66,888 | 42,220 | 92,544 | 1920×1080 |

All four runs recorded zero fallback PTY timer ticks while idle and fullscreen.
Each 2.5-second idle window recorded five cursor-blink callbacks, two or three
maintenance callbacks, five idle draws, and zero output-frame callbacks. The
fullscreen phase recorded one output frame and ten or eleven bounded draws.

## Retained files

- `summary.csv`: root/process-tree memory, scheduler counters, and image sizes.
- `debug-*.log`, `releasesafe-*.log`: production-host receipts.
- `*-idle.png`, `*-fullscreen.png`: active-window compositor captures.
- `SHA256SUMS`: checksums for every retained receipt and image.

The runner rejects screenshots unless OCR finds `NOCTTY mapped`, preventing an
unrelated active window from satisfying the pixel lane. X11 activation is used
only to select the mapped qualification window before Spectacle captures it.

## Boundary

This is a short, synthetic qualification. It proves mapped native rendering,
fullscreen allocation, bounded idle callbacks, external `/proc` memory
snapshots, and archived compositor pixels on this host. It is not physical HID,
GDK event-queue, authenticated-agent, long-idle, multi-monitor, or multi-day
proof. Memory columns are successive point snapshots, not simultaneous samples.
