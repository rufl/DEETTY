# NOCTTY Memory

This file is the short, human-maintained project memory for public-readiness
work. Detailed historical evidence lives in `docs/TECHNICAL_STATUS.md` and the
active engineering finish list lives in `BACKLOG.md`.

## Project identity

NOCTTY is a native Linux terminal workspace with a small companion editor,
NoctEd. It exists to reduce the need for many heavy Electron/editor windows when
working with shells, coding agents, logs, and quick project edits.

Primary public positioning:

> A native terminal workspace with a compact companion editor for terminal-heavy
> Linux development on KDE Plasma, Wayland, and X11.

Do not position NOCTTY as a VS Code, Zed, Sublime, Ghostty, or Yakuake clone.
Those projects can inspire specific ergonomics, but NOCTTY should keep smaller,
proof-bounded claims.

## Non-negotiables

- Keep the runtime native: Zig plus C ABI bindings are acceptable.
- Do not add Electron, Node.js, Bun, React, or browser-runtime UI to NOCTTY.
- Do not add telemetry, analytics, update pings, crash uploaders, or remote
  feature flags.
- Keep KDE Plasma, Wayland, and X11 compatibility first-class.
- Prefer GUI-configurable state over required manual config editing.
- Keep Ghostty/libghostty experiments isolated behind an adapter boundary.
- Use WIZP only as idea/reference material; do not import its WebView/Bun/VS
  Code parity stack.

## Current public-readiness state

- README has been rewritten for humans and public alpha expectations.
- The former receipt-heavy README is preserved as `docs/TECHNICAL_STATUS.md`.
- `docs/KNOWN_LIMITATIONS.md` records the honest non-claims.
- `docs/PUBLIC_ALPHA_PLAN.md` records the small path to alpha.
- `docs/NO_SURPRISE_NETWORK.md` records the retained static source scan for no telemetry/update/crash-upload/remote-flag surprises.
- `.github/ISSUE_TEMPLATE/` and `.github/pull_request_template.md` now provide public-alpha bug, dogfood, and review prompts.
- The formerly empty `.git` marker has been replaced with a real local Git boundary and first public source baseline commit.
- `docs/PUBLIC_ALPHA_RELEASE_NOTES.md` is the current bounded draft for first public source-alpha wording.
- Dogfood preflight found and fixed a flaky native-grid synchronized-output smoke window; X11 and Wayland native-grid smoke pass again.
- `./scripts/public_alpha_verify.sh` is the bounded public-source-alpha gate; it intentionally does not replace the full maintainer `./scripts/verify.sh` matrix.
- `docs/PUBLIC_ALPHA_CODE_REVIEW.md` and `docs/PUBLIC_ALPHA_GO_NO_GO.md` agree on the current state: source-alpha prep is ready except counted dogfood, and public announcement remains no-go while counted dogfood is zero.
- `docs/DOGFOOD_RUNBOOK.md` defines what may count as real dogfood; smoke/script-only sessions do not count.
- `./scripts/dogfood_status.sh` reports counted dogfood progress from `docs/DOGFOOD_LOG.md` without counting preflight/smoke entries.
- `./scripts/install_dogfood.sh` installs unstripped `ReleaseFast` binaries behind bounded local logging launchers by default, stages the pinned GTK Layer Shell runtime in the launcher-owned tree, and can select another Zig optimization mode through `NOCTTY_DOGFOOD_OPTIMIZE`. Logs stay under `~/.local/state/noctty/logs/` and are never uploaded.
- The latest dogfood blockers are closed locally: legacy relative pane cwd snapshots fall back before PTY startup; collapsed 32 px geometry recovers to a 480×240-minimum percentage size; windowed startup uses a bounded 80%×75% work-area size; and Wayland dogfood dropdowns enter the undecorated, horizontally centered `noctty-dropdown` layer surface even without a system GTK Layer Shell install.
- NoctEd handles discrete and smooth `Ctrl+wheel` as bounded 60%–240% shared editor zoom while leaving ordinary scrolling and the minimap scale unchanged.
- A pinned review of Jeremy Huang's `1jehuang` projects found applicable bounded-work fixes rather than justifying a new architecture. Quick Open now swaps active slice headers and normalizes the query once, improving broad-match ReleaseFast p50 by at least 56x with identical ranking. The follow-up applies `jofi`/`jtop`-style early rejection and retained fallback: direct Tree-sitter work is 100 ms-coalesced, limited to 32 KiB and 4,096 complete captures on GTK's main thread, and falls back visibly instead of partially highlighting or accepting the former measured 43.5 ms p50 256 KiB path.
- A detached-worktree 20/30-agent scale pass tested 16/32/64/96/128 KiB reads, early history compression, Pango/Cairo object reuse, shared pump storage, terminal-cell alignment, pump ceilings, and history allocators. The accepted native design shares one guarded 128 KiB PTY scratch across GTK-serialized sessions, reducing `TerminalSession` from 141,344 to 10,352 bytes and structurally saving about 3.88 MiB at 32 sessions without the eight-pane regression of a universally smaller read buffer. Lowering the natural alignment of the unchanged-width codepoint field also reduces each hot terminal cell from 16 to 14 bytes. Unfocused panes now cold-pack history after 30 idle seconds, the focused pane after five minutes, in sixteen process-wide 64-row batches per second; libc-backed slabs and bounded trimming reduced a 30-grid 120×40 history probe by 40.72 MiB and delayed native 32-pane USS by 7,084 KiB while active throughput stayed intact. `docs/TERMINAL_AGENT_SCALE_RESEARCH.md` records the bounded results and GPU decision.
- A pinned fourteen-repository terminal/agent-workspace review retained three smaller transfers: blank rows below the cursor no longer become fake scrollback during width-changing shrink; OSC 9/99/777 can mark a pane pending without retaining notification text; and PTY writes use a per-session ordered 64 MiB-capped queue rather than sleeping on GTK's thread. Queue storage above 256 KiB is released after drain. The focused 8 MiB sleeping-child probe changed caller blocking from 921.618 to 1.450 ms; `docs/TERMINAL_PEER_RESEARCH.md` owns the evidence and deferred architecture decisions.
- Herdr-inspired continuity is now explicit rather than inferred: pane badges distinguish restartable shells/live tmux/Zellij/agent resume; bounded Claude Code/Codex references persist in workspace snapshot version 7; the GUI restore chooser selects restart/attach/resume; OSC 99/777 focus-project actions remain user-confirmed; and command-palette screen-history export uses password-derived XChaCha20-Poly1305, atomic mode-0600 `.nocttyhs` files, and no stored password.
- Pi 0.83.0 redraw corruption was standard VT behavior, not a Pi workaround. The follow-up Pi/Codex audit added delayed autowrap, private-CSI collision isolation, origin/scroll-margin semantics, immediate-only repeat, DEC G0/G1 box drawing and save/restore, independent alternate-screen cursor/wrap/margin state, ED 3, and physical clearing of vacated rows. A direct Pi production PTY/grid probe changed cursor row 18 to clean row 9 with zero history; 32 curated VTE streams produced 31 exact and one equivalent pending-wrap result, while 50 deterministic no-tab streams produced 48 exact and two equivalent results with zero material mismatches.
- Qualification-only process waits now sleep on PTY EOF, use bounded 60-second loaded-host ceilings, and run Debug/`ReleaseSafe` session and installed-agent matrices sequentially; this avoids false waitpid/Codex SQLite failures without changing production timeout or teardown behavior.
- Compact New Tab, per-tab Close, Settings, and application Close controls use native GTK symbolic icons with 24-logical-pixel minimum targets while preserving the single-row Yakuake-style chrome.
- The active-pane bar is bottom-anchored below the terminal layout and shows cached one-second CPU/RSS for the full NOCTTY process tree and selected terminal tree; this is local `/proc` observation, not telemetry.
- `BACKLOG.md` remains the detailed active technical finish list.
- `CHANGELOG.md` remains detailed and evidence-heavy.

## Alpha strategy

Ship NOCTTY/NoctEd first as a Linux-native alpha. Keep WIZP separate and
experimental.

Public alpha should prove:

1. A stranger can understand the repo in a few minutes.
2. The source build/run path is documented and realistic.
3. NOCTTY can be dogfooded for real Lichforge work.
4. NoctEd is useful enough for quick project edits.
5. Known limitations are explicit and not hidden behind marketing.

## Immediate priorities

1. Run daily-driver dogfood sessions and record blockers.
2. Fix only P0/P1 blockers found by dogfooding.
3. Replace/refresh screenshots when UI presentation changes materially.
4. Keep `./scripts/check_no_surprise_network.sh` green when touching launch/network-adjacent code.
5. Keep the fresh full `./scripts/verify.sh` receipt green when changing shared
   runtime, package, or proof surfaces.
6. Keep release/package claims below the retained signing/publication evidence.

## Verification notes

Main gate:

```sh
./scripts/verify.sh
```

On constrained hosts, use:

```sh
NOCTTY_ZIG_SINGLE_JOB=1 ./scripts/verify.sh
```

Current local pass note: Debug and `ReleaseSafe` `zig build check -j1 --summary all`
pass 19/19 steps and 343/343 tests. A current-source single-job full verifier
completed terminal compatibility/session/continuity/TUI, production-Cairo
renderer and PTY/VT pipeline, NoctEd core/worker/index, package/release, source
truth, and final cleanup with
`verify_cleanup scratch=true cache=true install=true artifacts=true`. A direct
Pi 0.83.0 PTY/grid run also covered typed editing and width-changing resize; no
broad compositor or HID claim was added.

## Public claim rule

A feature may be mentioned publicly only at the level its evidence supports:

- source exists = implementation exists, not release-ready
- local focused proof = bounded local proof
- display-backed proof = compositor/session-specific proof
- dogfood proof = useful in the author's workflow, not universal support
- release proof = retained artifact/signature/publication evidence exists

When unsure, claim less.
