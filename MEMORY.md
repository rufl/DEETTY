# NOCTTY Memory

This is the short project memory. Detailed evidence lives in `docs/TECHNICAL_STATUS.md`; active unfinished work lives in `BACKLOG.md`.

## Identity

NOCTTY is a native Linux-first terminal workspace with a small companion
editor, NoctEd, for terminal-heavy development on KDE Plasma, Wayland, and X11.
An experimental Win32/ConPTY terminal workspace reuses the Zig VT and now owns
bounded tabs and recursive splits, but it is not Windows feature parity. NOCTTY
is not a VS Code, Zed, Sublime, Ghostty, or Yakuake replacement.

## Non-negotiables

- Keep Zig/C native; no Electron, browser runtime, telemetry, update pings, crash uploaders, or remote flags.
- Keep Plasma, Wayland, and X11 first-class.
- Prefer GUI-owned state and atomic persistence; manual config editing must not be required.
- Keep Ghostty/libghostty behind the isolated adapter boundary.
- Keep claims bounded to retained evidence; do not promote headless or synthetic proof to compositor, authenticated-agent, or universal compatibility claims.

## Current state

- Public-readiness docs, source baseline, package contracts, no-surprise-network checks, and dogfood installation are present.
- Installed dogfood launchers now retain private atomic running/finished duration receipts with host/boot identity, monotonic elapsed seconds, exit status, backend, and log linkage. `dogfood_status.sh` accepts only unique two-hour NOCTTY receipts attached to real-work entries. Retained legacy logs on this host currently prove 8.777 NOCTTY process-hours and 3.056 NoctEd process-hours, but zero quota-counted sessions; one 4.466-hour NOCTTY runtime remains uncounted without work context.
- The experimental x86_64 Windows host now cross-compiles without GTK, uses Win32/GDI plus independent ConPTY/Zig-VT sessions behind bounded native tabs and recursive splits, retains local logs/minidumps without upload, passes a Wine-hosted no-window VT/workspace self-test, and emits a checksummed `ReleaseFast` ZIP. Physical Windows behavior and broader feature parity remain open.
- Native Linux terminal VT, PTY, grid, renderer, history, session lifecycle, continuity, settings, tab/chrome, NoctEd, and package gates are implemented for the current 0.1.0 slice.
- NoctEd project-task detection now matches its documented surface: Zig, Cargo, Go, Flutter, Dart, validated npm scripts, .NET, Python, and Make use bounded regular-manifest/root scans and fixed argv without shell evaluation; unavailable generic actions are not guessed. The focused nine-ecosystem worker smoke passes with local shims. Running tasks own a process group, retain 120-second and independently enforced 1 MiB stream caps, remove desktop activation variables from child environments, and poll cancellation within 50 ms while idle, give the process group a bounded 100 ms TERM grace, then kill remaining descendants and free the foreground worker.
- Native pane retirement now owns and removes its deferred-focus source before releasing a heap context. The focused pane-close smoke passes inside a private D-Bus + Xvfb session. The default X11 helper delegates to the shared pressure-gated mount/PID/IPC/network namespace runner while adding private HOME/XDG/TMP paths; the virtual-KWin Wayland helper likewise clears inherited display state, serializes runs, enforces timeouts, and fails closed. The maintained guard inventories 38 self-isolating focused wrappers and 20 broad compositor, screenshot, physical-shortcut, endurance, installed-activation, and post-upgrade lanes that require `NOCTTY_DEDICATED_DISPLAY=1` in a disposable session. Single-instance and damaged-state smokes no longer create a nested second X server, and the split-terminal benchmark now requires shared offscreen isolation or explicit disposable-session acknowledgement.
- Plasma toggle-jank triage found dogfood control-launch overhead with 1.4–2.2 s spikes and a cold exclusive-keyboard layer-surface transition. Existing-owner controls bypass logging setup and Show/Toggle use the already-held native lock instead of a second D-Bus status call; install receipts cache Plasma/KWin versions; GTK debug chatter is opt-in; protocol-v4+ dropdowns use on-demand keyboard focus and commit `NONE` one frame before unmap.
- The Konsole-resilience tranche now retains validated last-known-good settings/theme backups, preserves replaced malformed bytes, opens a usable terminal with a native recovery notice after settings/theme/workspace damage, takes the primary lock before mutable state or PTYs, resolves 12-caller cold-start and hidden/show races to one owner, applies one-use GTK activation tokens on cold, forwarded, and StatusNotifier presentation without PTY inheritance or cross-hide stale reuse, and provides separate New Workspace/Open NOCTTY Here paths without clobbering the primary hot session.
- Settings navigation now has ATK names, 48-logical-pixel focusable category rows, destination-specific tooltips, theme-aware selected/focus contrast, a Window keyboard entry point, and narrow-work-area scrolling. Native settings, HiDPI/theme, compact UX, and X11 stacking receipts include `category_navigation=true`.
- NoctEd file-tab close controls retain 28-logical-pixel targets; transient icon controls retain 28-logical-pixel targets; project, tab, close, and result navigation has visible focus; and search surfaces expose descriptive placeholders. The sustained native endurance matrix repeats 32 complete workflows in Debug/`ReleaseSafe` on live Wayland/X11, retaining 4,096 combined search/resource/monitor/lifecycle phase cycles, 3,072 deterministic ranking evaluations, rendered widget captures, process-tree memory, and clean teardown.
- Live installed desktop/MIME activation and Recent Workspaces child launch pass on Wayland and X11. The smoke now fails closed on actual child exit while allowing the hidden restored tab to remain unpainted. The Project Workspace dialog uses a bounded scrollable summary, adaptive work-area sizing, and assistive names.
- Pi 0.83.0 duplication was fixed at the shared VT layer with delayed autowrap and related standards corrections. The direct PTY/grid probe retains typed editing, resize, cursor row 9, zero history, and no duplicate rows; 32 curated and 50 deterministic no-tab VTE streams have zero material mismatches.
- Debug and `ReleaseSafe` `zig build check -j1 --summary all` pass 19/19 steps and 393/393 tests. PTY shutdown now enforces its intended 500 ms grace with a monotonic deadline instead of 50 scheduler-stretched sleeps; under load the focused pending-paste teardown improved from Debug 1.992 s / `ReleaseSafe` 1.591 s to 0.988 s / 0.386 s. The aggregate passes end to end with complete scratch cleanup, private X11/Wayland display proof, the owned deferred-focus pane-close regression, nine project-task ecosystems, one-use activation, package reproducibility, and retained external release-operation boundaries.
- ReleaseFast guards retain 111.649 MiB/s at eight output panes and 134.808 MiB/s at 32 panes.
- The direct GLib fairness lane retains one continuously flooding PTY plus 29 marker PTYs in Debug/`ReleaseSafe`; the production-relevant lane delivered all markers below 2.5 ms. An 8 MiB paste drains through the queue, while pending-paste teardown releases the session and process group. A separate mapped Plasma lane now retains 64 synthetic production key-handler-to-draw/after-paint samples per mode/backend and actual Wayland GDK presentation feedback; X11 exposes no completed presentation timestamp on this host.
- NCT-119 is complete: Debug and `ReleaseSafe` now also retain live Wayland/X11 idle and fullscreen compositor pixels, external root/process-tree memory, zero fallback PTY timer ticks, and bounded cursor/maintenance wakeups. Command palette, terminal search, and Quick Note controls expose explicit assistive names covered by the compact UX smoke.
- NCT-110 is complete at the accepted one-host boundary: authenticated Codex 0.144.6 returned one exact ephemeral read-only model response in each Debug/`ReleaseSafe` Wayland/X11 lane through the production command profile, PTY, VT, GTK, and Cairo path. No credential was retained.
- NCT-111 is complete at the accepted one-host boundary: locally installed tmux 3.7b and Zellij 0.44.3 passed first attach, native detach, NOCTTY process exit/relaunch, reattach, preserved rendered content, and controlled cleanup in every Debug/`ReleaseSafe` Wayland/X11 lane.
- Compact NOCTTY and NoctEd tab/action controls now share 28-logical-pixel targets with explicit hover, active, and keyboard-focus states.
- NCT-112 now has a fail-closed hidden/visible stability runner. Its Debug/`ReleaseSafe` Wayland/X11 harness shakedown and a separate short authenticated `ReleaseSafe` matrix passed with exact Codex responses, zero hidden draws, zero fallback PTY ticks, phase-specific output/wakeup counts, compositor captures, external root/tree memory, and clean exit. Both remain `multi_day=false`; the default acceptance run is still 24 hours per backend, 48 hours total.
- A fresh NoctEd launch with no restored/open document now opens one clean Untitled buffer and names the immediate save action in the status line instead of leaving an empty editor surface.

## Open boundaries

The backlog remains partial for:

- NCT-112: the elapsed 48-hour authenticated mapped agent/resource run;
- NCT-123: physical Windows qualification and Windows workspace/NoctEd parity;
- release operations: retained architecture artifacts/signatures, publication, independent redistribution review, compositor acceptance, and consented Wayland HID.

These are evidence/operator boundaries, not reasons to invent local claims.

## Immediate priorities

1. Complete one current-version four-session OMP preflight, then record counted
   daily-driver dogfood sessions in `docs/DOGFOOD_LOG.md`;
   `dogfood_status.sh` qualifies only one automatically correlated, complete
   workspace trace and never accepts manual step claims.
2. Run the checksummed Windows alpha on physical Windows 10/11 and retain launch, input, resize, shell-exit, log, and crash-dump receipts before expanding claims.
3. Fix only P0/P1 dogfood blockers.
4. Run `./scripts/native_grid_stability_qualification.sh --run` when 48 hours of uninterrupted compositor access are available.
5. Keep `./scripts/check_docs_truth.sh`, `./scripts/check_no_surprise_network.sh`, and the full verifier green.
6. Keep release wording below signing/publication evidence.

## Verification

Main gate:

```sh
NOCTTY_VERIFY_PARENT=/dev/shm NOCTTY_ZIG_SINGLE_JOB=1 ./scripts/verify.sh
```

The gate is local proof only. It does not close the external release-operation rows above.

## Public claim rule

Source exists means implemented. Focused local proof means bounded local proof.
Display-backed proof is compositor/session-specific. Dogfood proof is workflow evidence, not universal support. Release proof requires retained artifact, signature, and publication evidence.
