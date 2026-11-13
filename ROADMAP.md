# DINTTY Roadmap

This roadmap is the public-readable plan. The detailed engineering backlog and
proof boundaries remain in `BACKLOG.md`.

## North star

Make DINTTY a dependable native Linux terminal workspace, with NoctEd as a small
companion editor, so terminal-heavy developers can work with fewer heavy editor
windows.

## Public alpha target

Public alpha means:

- source is publishable under Lichforge on GitHub
- README/build/run instructions are understandable
- known limitations are honest
- DINTTY can be dogfooded for real work on the author's Linux desktop
- NoctEd can safely handle quick project edits
- no telemetry or surprise network behavior exists

Public alpha does **not** mean mature IDE, VS Code parity, Windows feature
parity or physical qualification, macOS support, or universal terminal
compatibility.

## Priority tiers and execution bundles

- **P1 — public-alpha/dogfood:** current-build evidence and fixes for reproduced
  blockers only.
- **P2 — post-alpha:** architecture migration, physical-platform proof, and
  long-duration stability work.
- **P3 — release operations:** signing, publication, redistribution review, and
  final operator acceptance.

| Tier | Bundle | Executable boundary |
|---|---|---|
| P1 | NCT-125 current-build dogfood recapture | Blocked on operator evidence: source fixes are retained, but closure requires a clean installed-session recapture. |
| P2 | NCT-112 terminal stability | Blocked on elapsed evidence: run and retain the uninterrupted 48-hour qualification. |
| P2 | NCT-123 experimental Windows host | Blocked on physical/operator evidence: qualify the packaged host on supported Windows systems. |
| P2 | NCT-126 native-adapter migration | The strict 90% Zig ownership gate is met by the policy-only inventory; retain isolated X11/Wayland receipts before closure. |
| P3 | Release Operations | Retain operator/external signatures, publication, review, compositor, and consented HID acceptance. |

Source-ready work may be implemented locally; elapsed, physical, and operator
evidence cannot be claimed from source completion. The tier records execution
order, not completion.

## Phase 0 — Public-readiness docs

Status: complete.

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
- [x] Dogfood runbook
- [x] Installed `ReleaseFast` dogfood binaries with bounded local logging and a
  private copy of the provenance-checked system GTK Layer Shell runtime for undecorated Wayland dropdowns
- [x] Screenshots referenced from README

## Phase 1 — Dogfood DINTTY as daily terminal

Goal: use DINTTY for real Lichforge work instead of merely testing fixtures.

Acceptance:

- [x] Five sessions of at least two hours each
- [ ] One session with four or more panes/tabs
- [x] One Pi or coding-agent session inside DINTTY
- [ ] Hide/show and restore tested during real work
- [ ] close confirmation tested with a foreground job
- [ ] copy/paste/search/scrollback used during real work
- [x] blocker notes recorded in `docs/DOGFOOD_LOG.md`

Seven operator-confirmed installed sessions now contribute 167.107 counted
hours. The remaining unchecked rows require specific interaction evidence; raw
elapsed time does not imply that coverage.

Only fix P0/P1 dogfood blockers during this phase.

Closed dogfood blockers now include legacy relative-cwd startup failure,
collapsed 32 px window recovery, centered percentage-driven dropdown geometry,
bounded windowed startup sizing, decorated Wayland fallback caused by a
missing host GTK Layer Shell runtime, damaged local-state startup failure,
concurrent primary-owner races, activation-token handoff, and isolated New
Workspace/Open DINTTY Here launches.

## Phase 2 — NoctEd useful-enough alpha

Goal: NoctEd is safe and useful for quick edits while working from DINTTY.

Acceptance:

- [ ] open current project from DINTTY
- [ ] project tree navigation feels understandable
- [ ] edit/save/Save As used on real files
- [ ] dirty close protection checked
- [ ] find in file used on real edits
- [ ] find in project used on a real repo
- [ ] quick open used on a real repo
- [ ] resource behavior remains acceptable on current Lichforge repos

Added for dogfood beyond the original alpha boundary:

- [x] atomic hot-exit recovery for dirty saved and untitled tabs
- [x] Sublime-style bounded `Ctrl+wheel` editor zoom
- [x] bounded local stdio LSP client actions; NoctEd remains an editor, never an LSP server

Deferred until after alpha:

- persistent/always-on language-server sessions and VS Code-scale LSP UX
- DAP
- plugin system
- batch replace
- broad language/editor parity

## Phase 3 — Release hygiene

Goal: make the first public GitHub release low-drama.

Required before tagging alpha:

- [x] fast source build/check path confirmed with `zig build check -j1 --summary all`
- [x] fast build/check path confirmed from a clean source copy
- [x] full `./scripts/verify.sh` status recorded
- [x] README screenshots current
- [x] limitations current
- [x] changelog has alpha note
- [x] license present
- [x] contributing/security docs present
- [x] public bug/dogfood issue templates and PR template present
- [x] package/signing status is clearly marked incomplete if not done
- [x] no telemetry/network surprise check
- [x] local Git boundary and first public source baseline commit
- [x] draft public source-alpha release notes
- [x] public alpha go/no-go sheet
- [x] bounded public-source-alpha gate: `./scripts/public_alpha_verify.sh`

The checked items record source-release hygiene, not a completed public
release. Signing, publication, redistribution review, and final operator
acceptance remain P3 Release Operations.

## Phase 4 — Packaging and broader proof

Post-alpha work:

- [x] Retained Debug/`ReleaseSafe` Wayland/X11 mapped idle/fullscreen memory,
  bounded wakeup, and compositor-pixel qualification
- signed release artifacts
- retained architecture artifacts/signatures
- independent dependency-bundle redistribution review
- [x] installed tmux 3.7b/Zellij 0.44.3 detach, DINTTY relaunch, reattach, preserved-content, and mapped Wayland/X11 receipts
- [x] sustained native GUI and project-lifecycle qualification: 32 complete workflows per Debug/`ReleaseSafe` Wayland/X11 lane with rendered captures and process-tree memory
- [x] authenticated Codex 0.144.6 model-request receipts through production PTY/VT/GTK/Cairo on mapped Wayland/X11
- [x] fail-closed Debug/`ReleaseSafe` Wayland/X11 hidden/visible stability shakedown with phase resource receipts and compositor pixels
- 48-hour authenticated mapped agent/resource run (24 hours per backend)

## Phase 5 — Experimental Windows host

Goal: port the terminal deliberately through native platform boundaries without
pulling Linux GTK/POSIX details into product or VT state.

Current first tranche:

- [x] x86_64 Windows cross-build without GTK target libraries
- [x] Win32/GDI native window and ConPTY shell transport
- [x] reuse the existing renderer-neutral Zig VT/parser
- [x] keyboard, Unicode, resize, color, scrollback, and clipboard basics
- [x] bounded local logs and local crash minidumps with no upload path
- [x] checksummed ZIP/manifest packaging
- [x] paired-device identity, matching-code confirmation, direct TCP endpoints,
  and encrypted structured terminal presentation shared with Linux
- [x] native Windows share/receive rendering, dynamic Linux active-tab pane
  multiplexing, receiver pane selection, bounded resynchronization, negotiated
  liveness, and connection-scoped, per-pane host approval for remote input
- [x] bounded, user-initiated LAN pairing-listener announcements and discovery
  on Linux and Windows, with direct endpoints retained for routed VPNs
- [ ] physical Windows-to-Linux pairing, viewing, control, disconnect, and
  tailnet/VPN qualification
- [ ] physical Windows 10/11 launch, input, resize, shell-exit, and crash-log proof
- [x] bounded tabs and recursive splits with independent ConPTY sessions
- [x] native settings and themes, checksummed saved-layout restore, startup
  restore control, and launch-profile selection
- [x] native text selection and DEC mouse-reporting application support
- [x] separate native Windows NoctEd executable with tabs, project tree, editing,
  atomic save, and bounded session restore
- [x] reproducible per-user NSIS installer, reversible shortcuts/Open-With
  registration, and fail-closed operator signing hook

The Windows host remains an experimental native terminal workspace until the
remaining boundaries have receipts. Linux KDE/Wayland/X11 support remains first-class.

## WIZP relationship

WIZP remains a separate experimental rich-editor/WebView project. Do not import
its WebView/Bun/VS Code-parity stack into DINTTY. Transfer only small ideas that
fit DINTTY's native terminal workspace goal.
