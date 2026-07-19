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
5. Capture a fresh full `./scripts/verify.sh` receipt outside the short agent
   timeout if the local Zig/toolchain path is stable.
5. Keep release/package claims below the retained signing/publication evidence.

## Verification notes

Main gate:

```sh
./scripts/verify.sh
```

On constrained hosts, use:

```sh
NOCTTY_ZIG_SINGLE_JOB=1 ./scripts/verify.sh
```

Recent public-readiness pass note: `zig build check -j1 --summary all` passes
with 320/320 tests both in the working tree and in a clean source copy. A 2026-07-19 single-job full-verification retry:

```sh
NOCTTY_ZIG_SINGLE_JOB=1 ./scripts/verify.sh
```

ran for the 20-minute agent limit and retained green output through terminal
compatibility, terminal session, launch continuity, ncurses/system TUI,
production-Cairo renderer, and real PTY/VT-to-Cairo pipeline matrices before the
harness timeout. No assertion failure was observed before timeout, but this is
still not a closed green receipt for the full maintainer gate.

## Public claim rule

A feature may be mentioned publicly only at the level its evidence supports:

- source exists = implementation exists, not release-ready
- local focused proof = bounded local proof
- display-backed proof = compositor/session-specific proof
- dogfood proof = useful in the author's workflow, not universal support
- release proof = retained artifact/signature/publication evidence exists

When unsure, claim less.
