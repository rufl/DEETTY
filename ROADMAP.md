# NOCTTY Roadmap

This roadmap is the public-readable plan. The detailed engineering backlog and
proof boundaries remain in `BACKLOG.md`.

## North star

Make NOCTTY a dependable native Linux terminal workspace, with NoctEd as a small
companion editor, so terminal-heavy developers can work with fewer heavy editor
windows.

## Public alpha target

Public alpha means:

- source is publishable under Lichforge on GitHub
- README/build/run instructions are understandable
- known limitations are honest
- NOCTTY can be dogfooded for real work on the author's Linux desktop
- NoctEd can safely handle quick project edits
- no telemetry or surprise network behavior exists

Public alpha does **not** mean mature IDE, VS Code parity, Windows/macOS support,
or universal terminal compatibility.

## Phase 0 — Public-readiness docs

Status: in progress.

Required:

- [x] Human-readable README
- [x] Preserve detailed technical status separately
- [x] Known limitations document
- [x] Public alpha plan
- [x] Project memory
- [x] Roadmap
- [x] Contributing guide
- [x] Security policy
- [x] Dogfood log template
- [x] Screenshots referenced from README

## Phase 1 — Dogfood NOCTTY as daily terminal

Goal: use NOCTTY for real Lichforge work instead of merely testing fixtures.

Acceptance:

- [ ] Five sessions of at least two hours each
- [ ] One session with four or more panes/tabs
- [ ] One Pi or coding-agent session inside NOCTTY
- [ ] Hide/show and restore tested during real work
- [ ] close confirmation tested with a foreground job
- [ ] copy/paste/search/scrollback used during real work
- [ ] blocker notes recorded in `docs/DOGFOOD_LOG.md`

Only fix P0/P1 dogfood blockers during this phase.

## Phase 2 — NoctEd useful-enough alpha

Goal: NoctEd is safe and useful for quick edits while working from NOCTTY.

Acceptance:

- [ ] open current project from NOCTTY
- [ ] project tree navigation feels understandable
- [ ] edit/save/Save As used on real files
- [ ] dirty close protection checked
- [ ] find in file used on real edits
- [ ] find in project used on a real repo
- [ ] quick open used on a real repo
- [ ] resource behavior remains acceptable on current Lichforge repos

Deferred until after alpha:

- LSP
- DAP
- plugin system
- batch replace
- broad language/editor parity

## Phase 3 — Release hygiene

Goal: make the first public GitHub release low-drama.

Required before tagging alpha:

- [x] fast source build/check path confirmed with `zig build check -j1 --summary all`
- [x] fast build/check path confirmed from a clean source copy
- [ ] full `./scripts/verify.sh` status recorded
- [x] README screenshots current
- [x] limitations current
- [x] changelog has alpha note
- [x] license present
- [x] contributing/security docs present
- [x] public bug/dogfood issue templates and PR template present
- [x] package/signing status is clearly marked incomplete if not done
- [x] no telemetry/network surprise check
- [x] local Git boundary and first public source baseline commit

## Phase 4 — Packaging and broader proof

Post-alpha work:

- signed release artifacts
- retained architecture artifacts/signatures
- independent dependency-bundle redistribution review
- installed desktop activation receipts on accessible Plasma Wayland/X11
- longer native GUI soaks
- authenticated coding-agent receipts
- tmux/Zellij installed live reattach proof

## WIZP relationship

WIZP remains a separate experimental rich-editor/WebView project. Do not import
its WebView/Bun/VS Code-parity stack into NOCTTY. Transfer only small ideas that
fit NOCTTY's native terminal workspace goal.
