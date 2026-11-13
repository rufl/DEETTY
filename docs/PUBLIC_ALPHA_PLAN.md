# Public Alpha Plan

This is the small finish plan for publishing DEETTY/NoctEd as an honest
Lichforge open-source alpha.

## Positioning

Use this public positioning:

> DEETTY is a native Linux terminal workspace with a small companion editor for
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
- Screenshot recapture helper (self-isolating by default): `./scripts/capture_alpha_screenshots.sh`.
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

Current result on 2026-08-04: passed, `19/19` build steps succeeded and
`343/343` tests passed. The same pass includes the refreshed native GTK,
PTY, Ghostty VT, and standalone NoctEd boundaries plus the NoctEd relative
`--project . --open README.md` launch assertion.

The full maintainer gate is:

```sh
./scripts/verify.sh
```

The retained 2026-08-04 run with:

```sh
DEETTY_VERIFY_PARENT=/dev/shm DEETTY_ZIG_SINGLE_JOB=1 ./scripts/verify.sh
```

completed successfully through the terminal, renderer, PTY, NoctEd
core/worker/index, package/release, and source-truth lanes, ending with
`verify_cleanup scratch=true cache=true install=true artifacts=true`.

The opt-in live Plasma presentation lane retains 64 mapped synthetic production key-handler-to-draw/after-paint samples per mode on Wayland/X11 and completed Wayland GDK presentation feedback. The complementary full-stack lane closes NCT-119 with idle/fullscreen compositor pixels, external memory, and bounded wakeups on both backends. Neither is physical-input or final compositor-acceptance proof.

The same dogfood-prep slice reproduces and closes the relative-cwd startup and
collapsed-window blockers. The local Wayland install stages GTK Layer Shell,
logs `DEETTY dropdown layer-shell active`, removes ordinary window decorations,
and keeps percentage-driven dropdown widths horizontally centered.

## Phase 2 — Daily-driver dogfood

Goal: use DEETTY/NoctEd for real Lichforge work before public alpha.

Detailed runbook: `docs/DOGFOOD_RUNBOOK.md`. Current dogfood status command: `./scripts/dogfood_status.sh`.

Suggested dogfood protocol:

- [x] 5 separate sessions
- [x] at least 2 hours each
- [ ] use at least 4 terminal panes/tabs in one session
- [x] run Pi or another agent CLI inside DEETTY at least once
- [ ] use NoctEd for small real edits in at least 3 sessions
- [ ] test hide/show, close confirmation, restore, find, copy/paste, and settings
- [x] record bugs as backlog rows, not as vague notes

The retained baseline is seven operator-confirmed sessions and 167.107 counted
hours. Unchecked rows remain unchecked because elapsed time does not prove a
specific interaction.

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
- dirty saved and untitled tabs restore after hot exit
- `Ctrl+wheel` editor zoom works without disturbing ordinary scrolling
- find in file
- find in project
- quick open
- basic syntax highlighting
- recent projects
- bounded resource behavior on current Lichforge repos

Added after this plan was written:

- bounded on-demand local LSP client actions, without server or language-semantic implementation

Defer:

- persistent language-server sessions and IDE-parity LSP UX
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
- [x] Current `ReleaseSafe` installed-tree DEETTY and NoctEd screenshots
  recaptured in the repository's disposable private X11/KWin session, including
  terminal tabs/splits, settings, project editing, and project-wide search.
- [x] contribution licensing, conduct, support, and private security-reporting notes present
- [x] public bug/dogfood/feature issue templates and PR template present
- [x] pinned read-only source CI, tracked-source hygiene guard, and GitHub publication runbook present
- [x] local Git boundary and first public source baseline commit
- [x] draft public source-alpha release notes in `docs/PUBLIC_ALPHA_RELEASE_NOTES.md`
- [x] go/no-go sheet in `docs/PUBLIC_ALPHA_GO_NO_GO.md`
- [x] bounded public-source-alpha gate: `./scripts/public_alpha_verify.sh`

## Suggested first public alpha promise

```text
DEETTY 0.1 alpha is for Linux/KDE/Wayland/X11 users who want to try a native,
low-overhead terminal workspace with a small companion editor. It is not yet a
full IDE or a cross-platform terminal replacement. Expect rough edges, but the
project is proof-driven and avoids telemetry and Electron-style runtime bloat.
```

## WIZP relationship

WIZP should remain a separate experimental rich-editor/WebView project for now.
Do not import its Bun/WebView/VS Code-parity stack into DEETTY. Transfer only
small ideas that fit DEETTY's native terminal-workspace goal.
