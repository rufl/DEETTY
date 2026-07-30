# NOCTTY 0.1 Public Source Alpha Draft Notes

NOCTTY 0.1 alpha is a source-first Linux preview for people who want to try a
native terminal workspace with a compact companion editor, NoctEd.

## What this alpha is

- native Zig/GTK/Cairo terminal workspace for Linux
- focused on KDE Plasma, Wayland, and X11
- dropdown, windowed, and fullscreen/zen terminal modes
- tabs, recursive splits, native settings, themes, profiles, hot-session restore
- standalone NoctEd for quick project edits, search, Save As, quick open, folding,
  minimap, recent projects, private atomic dirty-tab hot exit, and bounded
  filesystem workers
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
316/316 tests passed
```

A fresh 2026-07-30 source copy without `.git`, `.zig-cache`, `zig-out`, or
`.noctty-*` state passed the same 19/19 steps and 316/316 tests in Debug and
`ReleaseSafe`; focused state-recovery and X11/Wayland native checks also cover
dirty untitled restoration and hot exit.

Bounded public-source-alpha gate:

```sh
./scripts/public_alpha_verify.sh
```

Current result:

```text
public_alpha_verify passed=true build_check=true no_surprise_network=true docs_truth=true native_grid_smoke=true nocted_native_smoke=true full_verify=false
```

Additional public-alpha guards currently pass individually:

```sh
./scripts/check_no_surprise_network.sh
./scripts/check_docs_truth.sh
```

The full maintainer gate remains:

```sh
./scripts/verify.sh
```

A fresh 2026-07-30 single-job run completed successfully through terminal
compatibility/session/continuity/TUI, renderer and PTY/VT pipeline, Zig
build/test, NoctEd core/worker/index, package/release contracts, and truth
checks. It ended with
`verify_cleanup scratch=true cache=true install=true artifacts=true`.

## Known open alpha items

Current dogfood status:

```text
dogfood_status counted_sessions=0 not_counted_sessions=2 five_sessions=false four_pane=false agent_cli=false nocted_real_edit=false foreground_close_confirmation=false
```

- counted real dogfood sessions are still needed
- signing/publication/artifact signatures are not complete
- longer native GUI soaks and authenticated agent workflows remain future proof

## Suggested tag wording

```text
NOCTTY 0.1 public source alpha: native Linux terminal workspace + compact NoctEd
editor. Source builds locally, fast gate is green, limitations are explicit, and
release/signing/daily-driver proof remains alpha work.
```
