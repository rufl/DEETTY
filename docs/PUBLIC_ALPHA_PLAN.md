# Public Alpha Plan

This is the small finish plan for publishing NOCTTY/NoctEd as an honest
Lichforge open-source alpha.

## Positioning

Use this public positioning:

> NOCTTY is a native Linux terminal workspace with a small companion editor for
> terminal-heavy development on KDE Plasma/Wayland/X11.

Avoid these claims:

- VS Code replacement
- Zed/Sublime replacement
- universal terminal compatibility
- universal benchmark winner
- production-ready package for all Linux distributions
- mature IDE

## Phase 1 — Public-readiness cleanup

Goal: make the repository understandable to a stranger in three minutes.

Required:

- Human-readable `README.md` focused on what it is, what works, how to build,
  and what is not claimed.
- `docs/KNOWN_LIMITATIONS.md` kept current.
- Screenshots or short GIFs for:
  - terminal tabs/splits
  - dropdown/windowed mode
  - settings
  - NoctEd project edit/search
- Screenshot recapture helper: `./scripts/capture_alpha_screenshots.sh`.
- README links to detailed evidence instead of embedding every receipt inline.
- `docs/CODE_MAP.md` explains the large native/runtime/editor source surfaces.
- One obvious verification command remains documented: `./scripts/verify.sh`.

Done when a new user can understand the project without reading the full backlog
first, and the current build/verification result is recorded honestly.

## Current verification note

Fast contributor gate captured during this prep pass:

```sh
zig build check -j1 --summary all
```

Result on 2026-07-19: passed, `17/17` build steps succeeded and `320/320` tests
passed. The same pass also refreshed README screenshots after the font/tab
presentation work and fixed the NoctEd relative `--project . --open README.md`
launch assertion.

The full maintainer gate is:

```sh
./scripts/verify.sh
```

During the public-alpha prep pass, one normal full-verification attempt reached
a Zig compiler `SEGV` while compiling a smoke binary. A 2026-07-19 retry with:

```sh
NOCTTY_ZIG_SINGLE_JOB=1 ./scripts/verify.sh
```

ran for the 20-minute agent limit and retained green output through terminal
compatibility, terminal session, launch continuity, ncurses/system TUI,
production-Cairo renderer, and real PTY/VT-to-Cairo pipeline matrices before the
harness timeout. Treat this as an alpha verification/toolchain/environment
follow-up until a fresh full green receipt is captured outside the short agent
limit.

## Phase 2 — Daily-driver dogfood

Goal: use NOCTTY/NoctEd for real Lichforge work before public alpha.

Suggested dogfood protocol:

- 5 separate sessions
- at least 2 hours each
- use at least 4 terminal panes/tabs in one session
- run Pi or another agent CLI inside NOCTTY at least once
- use NoctEd for small real edits in at least 3 sessions
- test hide/show, close confirmation, restore, find, copy/paste, and settings
- record bugs as backlog rows, not as vague notes

During this phase, only fix:

- crashes/data loss
- severe terminal/editor usability blockers
- memory/CPU regressions that block daily use
- README/build/install errors

Do not add broad features unless they unblock dogfooding.

## Phase 3 — NoctEd useful-enough line

NoctEd alpha is useful enough when the following are reliable in dogfood:

- open project
- project tree navigation
- open/edit/save/Save As
- dirty close protection
- find in file
- find in project
- quick open
- basic syntax highlighting
- recent projects
- bounded resource behavior on current Lichforge repos

Defer:

- LSP
- DAP
- plugin APIs
- batch replace
- broad language parity
- VS Code feature parity

## Phase 4 — Release hygiene

Before public alpha tag:

- [x] license present
- [x] changelog current
- [x] known limitations current
- [x] build/run instructions tested from a clean source copy
- [x] no telemetry/network surprises; retained source scan: `./scripts/check_no_surprise_network.sh`
- [x] package/signing status clear
- [x] screenshots current
- [x] contribution and security notes present
- [x] public bug/dogfood issue templates and PR template present
- [x] local Git boundary and first public source baseline commit
- [x] draft public source-alpha release notes in `docs/PUBLIC_ALPHA_RELEASE_NOTES.md`

## Suggested first public alpha promise

```text
NOCTTY 0.1 alpha is for Linux/KDE/Wayland/X11 users who want to try a native,
low-overhead terminal workspace with a small companion editor. It is not yet a
full IDE or a cross-platform terminal replacement. Expect rough edges, but the
project is proof-driven and avoids telemetry and Electron-style runtime bloat.
```

## WIZP relationship

WIZP should remain a separate experimental rich-editor/WebView project for now.
Do not import its Bun/WebView/VS Code-parity stack into NOCTTY. Transfer only
small ideas that fit NOCTTY's native terminal-workspace goal.
