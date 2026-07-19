# Contributing to NOCTTY

Thank you for considering a contribution. NOCTTY is pre-public Linux alpha, so
small, focused improvements are much more valuable than broad feature pushes.

## Project shape

NOCTTY is a native Zig terminal workspace. NoctEd is its small standalone editor.
The project intentionally avoids Electron, browser-runtime UI, Node.js, Bun,
telemetry, update pings, and remote feature flags.

## Good first contributions

Good early contributions are bounded and easy to review:

- documentation fixes
- build/install notes for specific Linux distributions
- reproducible bug reports
- small terminal/editor correctness fixes
- tests for a specific behavior
- accessibility observations with exact desktop/session details
- screenshots/GIFs for current behavior

Please avoid large rewrites, plugin systems, new runtimes, or broad parity work
without discussion.

## Before opening a change

1. Read `README.md`, `docs/KNOWN_LIMITATIONS.md`, and `ROADMAP.md`.
2. Check whether the issue is already in `BACKLOG.md`.
3. Keep claims proof-bounded.
4. Run the smallest relevant local gate.

Main gate:

```sh
./scripts/verify.sh
```

On constrained hosts:

```sh
NOCTTY_ZIG_SINGLE_JOB=1 ./scripts/verify.sh
```

For docs-only changes, at minimum check links and formatting manually. If the
full gate fails due to local toolchain/compositor constraints, include the exact
command and failure in your report.

## Coding guidelines

- Keep runtime dependencies native and minimal.
- Prefer small functions and explicit ownership over clever abstractions.
- Do not add telemetry, analytics, update checks, crash uploaders, or feature
  flags.
- Do not require users to hand-edit config files for normal behavior.
- Keep Ghostty/libghostty behind the adapter boundary.
- Keep WIZP's WebView/Bun/VS Code-parity stack out of NOCTTY.

## Commit/PR style

Use concise descriptions:

```text
fix terminal resize redraw guard
add NoctEd dirty-close doc note
```

Include:

- what changed
- why it changed
- how it was tested
- what is still not claimed

## Bug reports

GitHub issue templates are provided for ordinary bugs and alpha dogfood reports.
Security-sensitive reports still belong in the private path from `SECURITY.md`,
not in public issues.

Please include:

- NOCTTY commit/version if known
- Linux distribution
- desktop session/compositor: Plasma Wayland, Plasma X11, Niri, etc.
- GPU/driver if rendering-related
- command used to launch NOCTTY/NoctEd
- terminal app involved if relevant
- exact reproduction steps
- logs/screenshots when possible

## Security issues

Do not open public issues for sensitive security reports. See `SECURITY.md`.
