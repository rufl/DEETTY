# NOCTTY 0.1 Public Source Alpha Draft Notes

NOCTTY 0.1 alpha is a source-first Linux preview for people who want to try a
native terminal workspace with a compact companion editor, NoctEd.

## What this alpha is

- native Zig/GTK/Cairo terminal workspace for Linux
- focused on KDE Plasma, Wayland, and X11
- dropdown, windowed, and fullscreen/zen terminal modes
- undecorated, horizontally centered Wayland dropdowns with a 480×240 usable
  floor and a dogfood-private GTK Layer Shell runtime
- tabs, recursive splits, native settings, themes, profiles, hot-session restore, live Plasma Wayland/X11 desktop-link plus Recent Workspaces activation, and guarded broadcast input that confirms enable while disabling immediately
- standalone NoctEd for quick project edits, search, Save As, quick open, folding,
  minimap, bounded `Ctrl+wheel` editor zoom, accessible scrollable project/workspace summaries, recent projects, private atomic
  dirty-tab hot exit, and bounded filesystem workers
- no Electron, browser UI runtime, telemetry, update pings, crash uploaders, or
  remote feature flags

## What this alpha is not

- not a mature IDE
- not a VS Code/Zed/Sublime replacement
- not universal terminal compatibility
- not a signed binary release
- not a claim of multi-day production stability
- not a completed package/signing/redistribution release

## Current retained local proof

Fast source gate:

```sh
zig build check -j1 --summary all
```

Current result:

```text
19/19 steps succeeded
421/421 tests passed
```

A fresh 2026-08-03 source copy without `.git`, `.zig-cache`, `zig-out`, or
`.noctty-*` state passed the same 19/19 steps and 343/343 tests in Debug and
`ReleaseSafe`; focused state-recovery and X11/Wayland native checks also cover
dirty untitled restoration and hot exit.

Bounded public-source-alpha gate:

```sh
./scripts/public_alpha_verify.sh
```

Current result:

```text
public_alpha_verify passed=true source_hygiene=true build_check=true no_surprise_network=true dogfood_logging_smoke=true docs_truth=true native_grid_smoke=true nocted_native_smoke=true full_verify=false
```

Additional public-alpha guards currently pass individually:

```sh
./scripts/check_no_surprise_network.sh
./scripts/check_docs_truth.sh
```

The opt-in live mapped presentation lane also passes Debug/`ReleaseSafe` on Plasma Wayland/X11 with 64 samples per run. It retains synthetic production key-handler-to-draw/after-paint distributions, frame intervals, and completed Wayland GDK presentation feedback while explicitly excluding physical HID and X11 completed-presentation claims.

The complementary full-stack lane closes NCT-119 with OCR-validated idle/fullscreen compositor captures, external root/process-tree memory, zero fallback PTY timer ticks, and bounded cursor/maintenance wakeups in Debug and `ReleaseSafe` on Wayland and X11. Final compositor acceptance and physical HID remain separate release operations.

The NCT-112 hidden/visible runner also passes its Debug/`ReleaseSafe` Wayland/X11 shakedown with zero hidden draws, zero fallback PTY ticks, phase-specific output/wakeup counts, compositor pixels, and external resource samples. This validates the harness only; the default authenticated 24-hour-per-backend run has not elapsed.

The full maintainer gate remains:

```sh
./scripts/verify.sh
```

A fresh 2026-08-05 tmpfs-scoped single-job run completed successfully through terminal compatibility/session/continuity/TUI, GLib agent fairness and large-paste teardown, renderer and PTY/VT pipeline, Zig build/test, NoctEd core/worker/index, package/release contracts, and truth checks. It ended with
`verify_cleanup scratch=true cache=true install=true artifacts=true`.

## Known open alpha items

Current dogfood status:

```text
dogfood_status counted_sessions=7 documented_sessions=7 unverified_sessions=0 not_counted_sessions=3 counted_seconds=601585 counted_hours=167.107 five_sessions=true four_pane=false agent_cli=true nocted_real_edit=true foreground_close_confirmation=false
dogfood_omp_status observed_sessions=1 qualified_sessions=0 qualified_version=none max_concurrent=5 separate_worktrees=true concurrent_streaming=true independent_input=true independent_paste=true resize_during_output=true focus_isolation=true hide_show=true close_cancel=false close_accept_isolated=false normal_exit_cleanup=false hot_restore=true output_integrity=false logs_clean=false compatible=false
```

Retained installed-launcher logs contain 188.293 total NOCTTY process-hours and
14.568 NoctEd process-hours on this host. The values can overlap. Seven unique
operator-confirmed NOCTTY receipts contribute 167.107 counted hours, satisfying
the minimum five-session baseline without inventing unrecorded interaction
coverage.

- NCT-125 still requires its clean current-build workflow recapture
- four-pane, close-protection, three-session NoctEd, and multi-OMP evidence remain incomplete
- signing/publication/artifact signatures are not complete
- authenticated Codex 0.144.6 and installed tmux/Zellij mapped receipts are retained; the stability harness shakedown passes, while the 48-hour run, varied-project GUI evidence, and broader agent products remain future proof

## Suggested tag wording

```text
NOCTTY 0.1 public source alpha: native Linux terminal workspace + compact NoctEd
editor. Source builds locally, fast gate is green, limitations are explicit, and
release/signing/daily-driver proof remains alpha work.
```
