# NOCTTY

NOCTTY is a native terminal workspace focused first on Linux desktops: KDE
Plasma, Noctalia-compatible Wayland compositors, Wayland, and X11. An
experimental native Windows host now provides a first Win32/ConPTY terminal
tranche using the same Zig VT core. NOCTTY is built for the workflow that
usually turns into many heavy VS Code/MrCode/Electron windows: agent sessions,
shells, logs, quick edits, and project navigation.

NoctEd is the companion standalone editor. It is intentionally smaller than a
full IDE: open a project, edit files, search, save safely, and get back to the
terminal.

NOCTTY and NoctEd are written in Zig with thin native C ABI boundaries. The
supported runtime path does **not** use Electron, Node.js, Bun, React, a browser
UI runtime, telemetry, update pings, crash uploaders, or remote feature flags.

## Status

Current public-readiness status: **pre-public Linux alpha**.

A separate experimental Windows terminal alpha is now available for testing;
it is not yet Windows feature parity or physically qualified.

The local 0.1.0 behavior scope has substantial proof coverage on the author's
Linux/KDE-style environment, but the project is not yet a broad public release.
The next goal is to make NOCTTY/NoctEd reliable enough for daily use while
keeping the public claims small and honest.

The NCT-112 hidden/visible stability harness passes its short Debug/`ReleaseSafe`
Wayland/X11 shakedown. The default authenticated 24-hour Wayland plus 24-hour
X11 run still needs elapsed time and is not claimed complete.

Supported first:

- Linux desktop
- KDE Plasma Wayland/X11
- Noctalia-compatible Wayland sessions
- native terminal workspace use
- standalone NoctEd quick editing

Experimental:

- x86_64 Windows 10 1809+/Windows 11 Win32/ConPTY terminal workspace with bounded native tabs and recursive splits

Not claimed yet:

- Windows feature parity, Windows NoctEd, or physically qualified Windows
  daily-driver support
- macOS support
- VS Code/Zed/Sublime parity
- universal terminal compatibility
- multi-day production stability
- authenticated agent compatibility across every coding CLI
- signed/public packages

See [Known limitations](docs/KNOWN_LIMITATIONS.md), the [no-surprise network check](docs/NO_SURPRISE_NETWORK.md), the [code map](docs/CODE_MAP.md), the [Konsole resilience review](docs/KONSOLE_RESILIENCE_REVIEW.md),
the [terminal peer research](docs/TERMINAL_PEER_RESEARCH.md), the [agent fairness qualification](docs/TERMINAL_AGENT_FAIRNESS_QUALIFICATION.md), the [mapped presentation qualification](docs/NATIVE_GRID_PRESENTATION_QUALIFICATION.md), the [full-stack mapped qualification](docs/NATIVE_GRID_FULL_STACK_QUALIFICATION.md), the [hidden/visible stability qualification](docs/NATIVE_GRID_STABILITY_QUALIFICATION.md), the [authenticated Codex qualification](docs/AUTHENTICATED_AGENT_QUALIFICATION.md), the [installed tmux/Zellij continuity qualification](docs/INSTALLED_CONTINUITY_QUALIFICATION.md), the [NoctEd native endurance qualification](docs/NOCTED_NATIVE_ENDURANCE_QUALIFICATION.md), and the detailed historical status in [Technical status](docs/TECHNICAL_STATUS.md).

## Screenshots

Current alpha screenshots from the author's Plasma Wayland desktop. Recapture
with `./scripts/capture_alpha_screenshots.sh` when the UI changes materially.

![NOCTTY alpha terminal workspace](docs/assets/noctty-alpha.png)

![NoctEd alpha editor](docs/assets/nocted-alpha.png)

## What works today

The qualified Linux NOCTTY host provides:

- undecorated, horizontally centered dropdown mode with live percentage sizing,
  native decorated windowed mode, and zen/fullscreen mode
- native terminal tabs and recursive splits
- guarded broadcast input across selected panes or the active tab, with explicit enable confirmation and immediate disable
- compact tab chrome inspired by Yakuake/Konsole workflows
- bottom active-pane bar with NOCTTY-wide and selected-terminal-tree CPU/memory usage
- per-pane scrollbars with wheel, track-click, thumb-drag, and Shift+Page/Home/End keyboard navigation, plus scrollback search, copy/paste, mouse, resize, and Unicode/ANSI handling
- terminal content exposed through native ATK text semantics for Linux screen readers
- configurable launch profiles for shells, commands, SSH, tmux, and Zellij paths
- retained installed tmux 3.7b/Zellij 0.44.3 detach, NOCTTY relaunch, reattach, and preserved-content proof on Plasma Wayland/X11
- retained authenticated Codex 0.144.6 exact-response proof through the production PTY/VT/GTK/Cairo path on Plasma Wayland/X11
- hot-session workspace recovery plus mapped Wayland/X11 desktop-link and Recent Workspaces activation, with explicit shell-restart, tmux/Zellij-attach, or registered-agent-resume choices
- validated last-known-good settings/theme fallback, exact damaged-state retention, and a native startup recovery notice instead of a blocked terminal
- deterministic pre-state single-instance ownership for the dropdown, cold-start and Show/Toggle activation-token handoff without PTY inheritance, plus explicit separate New Workspace and Dolphin **Open NOCTTY Here** launches
- continuity badges distinguishing restartable shells, live sessions, and agent resumes
- opt-in password-protected encrypted screen-history export
- native settings, command palette, terminal search, Quick Note, and Project Workspace surfaces with keyboard-accessible controls, assistive names, and narrow-window scrolling
- optional tray/status notifier integration
- native themes and import paths for simple terminal color formats
- opt-in end-to-end encrypted sharing of the active terminal to one paired
  NOCTTY device, with a native remote preview and separately approved,
  connection-scoped input control

The experimental Windows host provides a native Win32/GDI window, ConPTY,
the shared Zig VT/parser, Unicode and control-key input, live resize, ANSI/true
color, scrollback, clipboard paste, text selection, DEC mouse reporting,
bounded tabs and recursive splits, native settings, saved-layout restore,
launch profiles, local logs/minidumps, and paired session sharing/receiving.
The Windows package also contains a separate native NoctEd editor with
persistent 8–32 point font controls, menu/keyboard zoom, and `Ctrl+wheel`
document zoom. Its reproducible per-user NSIS installer provides reversible
shortcuts/Open-With registration and an operator-owned signing hook. Physical
Windows 10/11 qualification and full Linux workspace parity remain open. See
[Windows alpha](docs/WINDOWS.md).

NoctEd provides on Linux:

- standalone `nocted` binary/process
- project tree with persistent show/hide controls and one-click parent-directory navigation
- a clean Untitled buffer on first launch, plus file tabs with 28-logical-pixel close targets and explicit interaction states
- UTF-8 editing through GtkSourceView with direct vendored Tree-sitter highlighting and GtkSourceView fallback
- document find and project Find in Files
- quick open
- reversible folding
- minimap
- persistent 8–32 point GUI font controls under **Settings > Interface Font Size...**, independent from View-menu, keyboard, and `Ctrl+wheel` code-text zoom
- recent projects
- atomic save/Save As behavior
- atomic hot-exit recovery for dirty saved and untitled tabs
- Save/Discard/Cancel protection when closing individual dirty tabs
- visible keyboard focus, descriptive search placeholders, and bounded 28-logical-pixel transient controls
- sustained Debug/`ReleaseSafe` Wayland/X11 search, ranking, monitor, project-lifecycle, render, memory, and teardown qualification

## Paired session sharing

Session sharing mirrors presentation state, not a PTY or process. The machine
running the shell remains authoritative; closing it ends the remote view.
Open **Session Sharing…** from the Linux workspace menu. On one device choose
**Pair: Listen**. On the other, choose **Discover on LAN** to fill the announced
endpoint, review it, and choose **Pair: Connect**. If LAN discovery is
unavailable, enter the listener's reachable hostname or IP directly. Compare
and explicitly confirm the six-digit code on both devices. The endpoint may be
a LAN address, IPv4/IPv6 address, DNS name, or a
Tailscale/WireGuard/ZeroTier-style VPN name or address.

Select the saved peer and choose **Share current pane**, **Share current tab**,
or **Share entire session** on the host, then **Receive selected device** on the
viewer. A pane share stays pinned to that pane and ends when it closes. A tab
share follows every pane in the tab that was active when sharing started. An
entire-session share follows every tab and pane in workspace order, including
tabs and panes opened, closed, reordered, renamed, or moved while connected.
The receiver's **Shared tab** selector chooses the reconstructed remote tab;
the preview renders all of that tab's panes from the host split tree and ratio
state. **Shared pane** changes keyboard focus within the layout, and clicking a
pane does the same. Selected and host-active panes remain visibly distinct.
Each pane keeps an independent bounded sequence and checkpoint. Receivers also
retain the latest 64 host scrollback rows per pane; the preview's mouse wheel
navigates that bounded history while new rows preserve the scrolled view.
`Ctrl+Shift+V` and `Shift+Insert` paste only after an explicit user action,
including bracketed-paste framing when the remote application requests it.
Keep the same TCP port used during pairing reachable on the host. Viewing is
the default. A control request and host grant apply only to the selected pane
and current connection; changing panes requires a separate grant. Grants end
on revoke, disconnect, pane closure, resynchronization, or reconnect. After a
link closes or fails, **Reconnect securely** performs a new authenticated
handshake with the saved paired key and starts view-only.
**Revoke paired device** persists locally and closes a matching active share.

There is no relay, account service, NAT traversal, port forwarding, or subnet
scan. Pairing listeners send bounded, opt-in LAN multicast/broadcast
announcements containing only a temporary instance identifier, alias, port,
protocol version, and capability bits. Announcements are unauthenticated hints;
trust begins only after both devices confirm the same pairing code. Discovery
runs only while the user asks for it in the Session Sharing dialog; closing the
dialog stops discovery. Direct endpoints remain the reliable path across
routed VPNs.

After the encrypted transport starts, both sides require matching workspace,
dynamic-pane, tab-hierarchy, split-layout, share-scope, resynchronization,
keepalive, and per-pane-control capabilities. Sequence gaps discard an affected
pane's partial snapshot and request a fresh bounded checkpoint; they are not
repaired by replaying an unbounded PTY byte stream.
The host also probes an otherwise idle viewer and closes a link that does not
answer.

## What NOCTTY is not

NOCTTY is not trying to be a full IDE or a VS Code clone. It is a small native
workspace for terminal-heavy development.

NoctEd is not trying to be VS Code, Zed, or Sublime Text. It should become a
trustworthy companion editor for quick project edits, not a plugin platform.

WIZP is the separate experimental rich-editor/WebView line. Ideas may transfer
from WIZP, but NOCTTY should stay native and avoid inheriting WIZP's webview,
Bun, or VS Code-parity stack.

## Build and run

Linux requirements:

- Zig 0.16.x or newer
- GTK 3 development files discoverable through `pkg-config`
- GtkSourceView 4 development files discoverable through `pkg-config`
- `gtk-layer-shell` at runtime for Wayland dropdown placement; distribution
  packages provide it, while dependency bundles and dogfood installs stage the
  pinned private runtime
- VTE 2.91 development files only for the optional legacy/fallback binary or the
  complete verification matrix

From the repository root on Linux:

```sh
./scripts/verify.sh
zig build run
```

Useful launch variants:

```sh
zig build run -- --native-grid-windowed
zig build run -- --native-grid-zen
zig build run -- --native-grid-two-pane
zig build run-nocted -- --open src/nocted/main.zig
```

Optional legacy/fallback build:

```sh
zig build vte-fallback
./zig-out/bin/noctty-vte --native-host
```

Native x86_64 Windows cross-build (no GTK dependency):

```sh
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseFast
./scripts/package_windows.sh dist/noctty-windows-x86_64-alpha.zip
```

See [Windows alpha](docs/WINDOWS.md) for the current feature and proof boundary.

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
Configured global shortcut (F10 default) show / hide
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
Shift+PageUp/PageDown terminal history page up / down
Shift+Home/End        oldest / live terminal output
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
Ctrl+wheel             zoom editor text in / out
Ctrl+W                 close file
Ctrl+Shift+[/]         fold / unfold region
```

More interaction detail: [Compact UX](docs/COMPACT_UX.md).

## Verification

Fast Linux contributor gate:

```sh
zig build check
```

Windows compile gate:

```sh
zig build check -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseSafe
```

The current working tree passes `zig build check -j1 --summary all` with
`19/19` steps and `384/384` tests in Debug and `ReleaseSafe`. The required
`./scripts/verify.sh` aggregate also passes with scoped scratch cleanup; it
still deliberately rejects pending-paste teardown beyond its two-second
wall-clock budget.

Bounded public-source-alpha gate:

```sh
./scripts/public_alpha_verify.sh
```

Dogfood `ReleaseFast` install with private crash/debug logs, atomic duration
receipts, and the private GTK Layer Shell runtime needed for an undecorated
Wayland dropdown:

```sh
./scripts/install_dogfood.sh
./scripts/dogfood_status.sh
./scripts/dogfood_runtime_status.sh --list-candidates
./scripts/plasma_wayland_post_upgrade.sh --full
```

The post-upgrade lane is local and operator-initiated; it performs no package
refresh, telemetry, or upload. See [Dogfood install and logging](docs/DOGFOOD_LOGGING.md).

Main maintainer gate:

```sh
./scripts/verify.sh
```

A fresh current-source single-job maintainer run completed successfully on
2026-08-03, including the Debug/`ReleaseSafe` terminal, renderer, PTY, NoctEd
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
