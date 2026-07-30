# NOCTTY

NOCTTY is a native terminal workspace for Linux desktops, focused on KDE Plasma,
Noctalia-compatible Wayland compositors, Wayland, and X11. It is built for the
workflow that usually turns into many heavy VS Code/MrCode/Electron windows:
agent sessions, shells, logs, quick edits, and project navigation.

NoctEd is the companion standalone editor. It is intentionally smaller than a
full IDE: open a project, edit files, search, save safely, and get back to the
terminal.

NOCTTY and NoctEd are written in Zig with thin native C ABI boundaries. The
supported runtime path does **not** use Electron, Node.js, Bun, React, a browser
UI runtime, telemetry, update pings, crash uploaders, or remote feature flags.

## Status

Current public-readiness status: **pre-public Linux alpha**.

The local 0.1.0 behavior scope has substantial proof coverage on the author's
Linux/KDE-style environment, but the project is not yet a broad public release.
The next goal is to make NOCTTY/NoctEd reliable enough for daily use while
keeping the public claims small and honest.

Supported first:

- Linux desktop
- KDE Plasma Wayland/X11
- Noctalia-compatible Wayland sessions
- native terminal workspace use
- standalone NoctEd quick editing

Not claimed yet:

- Windows or macOS support
- VS Code/Zed/Sublime parity
- universal terminal compatibility
- multi-day production stability
- authenticated agent compatibility across every coding CLI
- signed/public packages

See [Known limitations](docs/KNOWN_LIMITATIONS.md), the [no-surprise network check](docs/NO_SURPRISE_NETWORK.md), the [code map](docs/CODE_MAP.md),
and the detailed historical status in [Technical status](docs/TECHNICAL_STATUS.md).

## Screenshots

Current alpha screenshots from the author's Plasma Wayland desktop. Recapture
with `./scripts/capture_alpha_screenshots.sh` when the UI changes materially.

![NOCTTY alpha terminal workspace](docs/assets/noctty-alpha.png)

![NoctEd alpha editor](docs/assets/nocted-alpha.png)

## What works today

NOCTTY provides:

- dropdown, windowed, and zen/fullscreen terminal modes
- native terminal tabs and recursive splits
- compact tab chrome inspired by Yakuake/Konsole workflows
- bottom active-pane bar with NOCTTY-wide and selected-terminal-tree CPU/memory usage
- scrollback, search, copy/paste, mouse, resize, and Unicode/ANSI handling
- configurable launch profiles for shells, commands, SSH, tmux, and Zellij paths
- hot-session workspace recovery with fresh shell restart semantics
- native settings UI for common behavior and appearance choices
- optional tray/status notifier integration
- native themes and import paths for simple terminal color formats

NoctEd provides:

- standalone `nocted` binary/process
- project tree
- file tabs
- UTF-8 editing through GtkSourceView with direct vendored Tree-sitter highlighting and GtkSourceView fallback
- document find and project Find in Files
- quick open
- reversible folding
- minimap
- recent projects
- atomic save/Save As behavior
- atomic hot-exit recovery for dirty saved and untitled tabs
- Save/Discard/Cancel protection when closing individual dirty tabs

## What NOCTTY is not

NOCTTY is not trying to be a full IDE or a VS Code clone. It is a small native
workspace for terminal-heavy development.

NoctEd is not trying to be VS Code, Zed, or Sublime Text. It should become a
trustworthy companion editor for quick project edits, not a plugin platform.

WIZP is the separate experimental rich-editor/WebView line. Ideas may transfer
from WIZP, but NOCTTY should stay native and avoid inheriting WIZP's webview,
Bun, or VS Code-parity stack.

## Build and run

Requirements:

- Zig 0.16.x or newer
- GTK 3 development files discoverable through `pkg-config`
- GtkSourceView 4 development files discoverable through `pkg-config`
- `gtk-layer-shell` at runtime for Wayland dropdown placement
- VTE 2.91 development files only for the optional legacy/fallback binary or the
  complete verification matrix

From the repository root:

```sh
./scripts/verify.sh
zig build run
```

Useful launch variants:

```sh
zig build run -- --native-grid-windowed
zig build run -- --native-grid-zen
zig build run -- --native-grid-two-pane
zig build run-nocted -- --project . --open src/nocted/main.zig
```

Optional legacy/fallback build:

```sh
zig build vte-fallback
./zig-out/bin/noctty-vte --native-host
```

## Install/package locally

Local install:

```sh
zig build --prefix "$HOME/.local"
```

Reproducible install-tree tarball:

```sh
./scripts/package_tarball.sh /tmp/noctty-local.tar.gz
```

Same-architecture dependency bundle:

```sh
./scripts/package_bundle.sh /tmp/noctty-linux-bundle.tar.gz
```

The dependency bundle is not a public redistribution promise until independent
license/redistribution review and release receipts are complete.

## Common controls

```text
F10                    show / hide
Ctrl+Shift+P           command palette
Ctrl+Shift+F           find in scrollback
Ctrl+Shift+N           quick note
Ctrl+Shift+Z           zoom / restore pane
Ctrl+Shift+G           Smart Tab filter
Ctrl+Shift+Y           tag selected panes
Ctrl+Shift+K           shortcut card
Ctrl+Tab               next visible pane
Ctrl+Shift+Tab         next tab / Smart Tab
Alt+Arrow              directional pane focus
Alt+wheel              previous / next pane
Ctrl+Alt+wheel         previous / next tab
Ctrl+wheel             pane font up / down
Ctrl+C                 interrupt active pane
Ctrl+D                 close active pane
Right-click pane       terminal actions / Open NoctEd Here
```

NoctEd:

```text
Ctrl+S                 save
Ctrl+F                 find in file
Ctrl+Shift+F           find in project
Ctrl+PageUp/PageDown   previous / next file
Ctrl+W                 close file
Ctrl+Shift+[/]         fold / unfold region
```

More interaction detail: [Compact UX](docs/COMPACT_UX.md).

## Verification

Fast contributor gate:

```sh
zig build check
```

The current working tree and a fresh clean source copy pass
`zig build check -j1 --summary all` with `19/19` steps and `316/316` tests.

Bounded public-source-alpha gate:

```sh
./scripts/public_alpha_verify.sh
```

Dogfood Debug install with local crash/debug logs:

```sh
./scripts/install_dogfood.sh
```

See [Dogfood install and logging](docs/DOGFOOD_LOGGING.md).

Main maintainer gate:

```sh
./scripts/verify.sh
```

A fresh current-source single-job maintainer run completed successfully on
2026-07-29, including the Debug/`ReleaseSafe` terminal, renderer, PTY, NoctEd
core/worker, project-index, package, release-contract, and truth-check lanes,
followed by `verify_cleanup scratch=true cache=true install=true artifacts=true`.

Display-backed smoke gate:

```sh
./scripts/native_release_smoke.sh
```

Opt-in focused qualification lanes exist for terminal compatibility, renderer
behavior, PTY lifecycle, NoctEd worker/index/search behavior, and native UI
lifecycle. These are engineering evidence, not blanket public guarantees. The
full detailed receipt history lives in [Technical status](docs/TECHNICAL_STATUS.md)
and the active finish list lives in [BACKLOG.md](BACKLOG.md).

## Public alpha finish line

Before publishing as a Lichforge public alpha, the project should have:

- a clean human-readable README (this file)
- current screenshots or short GIFs
- a contributor code map for navigating the large native code paths
- a minimal install/build path tested from a clean checkout
- daily-driver dogfood notes from real NOCTTY/NoctEd sessions
- known limitations documented without marketing overclaim
- package/signing/redistribution status clearly separated from source release
- a retained no-surprise network/telemetry source scan

See [Public alpha plan](docs/PUBLIC_ALPHA_PLAN.md), [go/no-go sheet](docs/PUBLIC_ALPHA_GO_NO_GO.md), [draft alpha release notes](docs/PUBLIC_ALPHA_RELEASE_NOTES.md), [Roadmap](ROADMAP.md),
[project memory](MEMORY.md), the [dogfood runbook](docs/DOGFOOD_RUNBOOK.md), the [dogfood log](docs/DOGFOOD_LOG.md), and the
historical [pitch audit](docs/PITCH_AUDIT.md). Dogfood progress can be checked with
`./scripts/dogfood_status.sh`.

## Philosophy

- Native runtime first.
- GUI-configurable behavior over required manual config editing.
- No telemetry or surprise network behavior.
- Small, proof-bounded claims.
- Prefer a dependable terminal workspace over a half-finished IDE.

## License

MIT. See [LICENSE](LICENSE).
