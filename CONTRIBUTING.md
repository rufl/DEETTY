# Contributing to NOCTTY

Thank you for considering a contribution. NOCTTY is an early source alpha, so
small, focused improvements are much more valuable than broad feature pushes.
Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md); support
expectations are documented in [SUPPORT.md](SUPPORT.md).

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

First build and launch using [Install](docs/INSTALL.md#run-from-the-checkout).
For a code change, the non-graphical contributor gate is:

```sh
zig fmt --check build.zig src
zig build check -j1 --summary all
```

This gate additionally requires VTE 2.91 development files (`libvte-2.91-dev`
on Debian/Ubuntu). It builds the fallback and smoke binaries and runs unit
tests, but does not launch graphical qualification or require an agent account.
For documentation-only changes, use `./scripts/check_docs_truth.sh`.

Optional bounded source-alpha gate, from a Git checkout:

```sh
./scripts/public_alpha_verify.sh
```

This includes isolated X11 and Wayland graphical checks. The repository-owned
X11 runner requires `bubblewrap`, `dbus-run-session`, `flock`, `setsid`,
`timeout`, Xvfb, Xauthority tooling, and a private window manager such as
Openbox or `kwin_x11`; `OVERZEER_DISPLAY_RUNNER` may select an equivalent
reviewed runner. The Wayland wrapper additionally needs `kwin_wayland` with
virtual-backend support. Release CI provisions these tools. They remain optional
for building, launching, or running `zig build check`.
Do not bypass a missing isolation runner by using your active desktop.
The bounded gate is not physical desktop, authenticated-agent, or release
qualification.

The maintainer gate is `./scripts/verify.sh`. It includes isolated graphical and
broader qualification lanes, can be environment-heavy, and is not required for
every focused pull request. Never run display tests against an active desktop;
use the repository's fail-closed isolated-display wrappers. If a gate cannot run
because of toolchain/compositor constraints, include the exact command and
failure in the pull request.

## Coding guidelines

- Follow `.editorconfig`; run `zig fmt` for Zig sources.
- Add comments for ownership, invariants, and surprising lifetime rules, not for
  code that is already self-explanatory.
- Keep runtime dependencies native and minimal.
- Prefer small functions and explicit ownership over clever abstractions.
- Do not add telemetry, analytics, update checks, crash uploaders, or feature
  flags.
- Do not require users to hand-edit config files for normal behavior.
- Keep Ghostty/libghostty behind the adapter boundary.
- Keep WIZP's WebView/Bun/VS Code-parity stack out of NOCTTY.

## Contribution license

By submitting a contribution, you agree that it is licensed under this
repository's [MIT License](LICENSE) and confirm that you have the right to
submit it. Do not contribute copied code, generated parser updates, fonts,
icons, screenshots, or other assets without compatible provenance and notices.
Update [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) when a contribution adds
redistributed third-party material.

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
