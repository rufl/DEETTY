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
pass with 316/316 tests after adding private atomic dirty-buffer hot exit and
rejecting legacy relative pane cwd state before PTY startup. A fresh clean-source
copy passed the same 19/19 steps and 316/316 tests in Debug and `ReleaseSafe`;
both native backends also pass dirty untitled restoration and hot exit. The
reported stale cwd and collapsed-window dogfood states were reproduced, and a
local Plasma Wayland hidden launch logged `NOCTTY dropdown layer-shell active`
through the installed private runtime. A
current-source single-job full verifier
also completed terminal compatibility/session/continuity/TUI, production-Cairo
renderer and PTY/VT pipeline, NoctEd core/worker/index, package/release, source
truth, and final cleanup with
`verify_cleanup scratch=true cache=true install=true artifacts=true`. The Xvfb
X11 lane and available local Wayland socket were exercised; no broad compositor
or HID claim was added.

## Public claim rule

A feature may be mentioned publicly only at the level its evidence supports:

- source exists = implementation exists, not release-ready
- local focused proof = bounded local proof
- display-backed proof = compositor/session-specific proof
- dogfood proof = useful in the author's workflow, not universal support
- release proof = retained artifact/signature/publication evidence exists

When unsure, claim less.
