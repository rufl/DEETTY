# Known Limitations

NOCTTY is in pre-public Linux alpha. This document keeps public expectations
small and clear.

## Platform support

Supported first:

- Linux desktop
- KDE Plasma Wayland/X11
- Noctalia-compatible Wayland sessions

Not supported or not claimed yet:

- Windows
- macOS
- BSDs
- mobile
- remote desktop edge cases
- all Wayland compositors
- all accessibility stacks

## Packaging and release operations

Source builds and local packaging paths exist, but public release operations are
not complete yet.

Open before a polished public binary release:

- signing
- publication process
- retained architecture artifacts/signatures
- independent dependency-bundle redistribution review/receipt
- final compositor acceptance receipts
- consented Wayland HID/input capture where needed

The dependency bundle should not be marketed as redistribution-ready until those
release-operation items are closed.

## Terminal compatibility

NOCTTY has substantial bounded terminal/PTY/VT evidence, including deterministic
protocol fixtures and several installed TUI applications. This does not mean
universal terminal compatibility.

Not complete yet:

- authenticated Codex/Claude Code/Antigravity daily-agent receipts
- broader real terminal application matrix on mapped Plasma Wayland/X11
- multi-day hidden/visible terminal soaks
- compositor-backed key-to-frame/presentation latency distributions
- universal ncurses/alternate-screen/mouse behavior claims

## Session continuity

NOCTTY restores workspace layout and restarts fresh shells in saved directories.
It does **not** resurrect arbitrary in-memory shell processes after a crash or
forced exit.

Persistent tmux/Zellij launch kinds exist, but installed live detach/relaunch/
reattach evidence is still open on the current host.

## NoctEd editor scope

NoctEd is a companion editor, not a mature IDE.

Works today in the intended scope:

- project tree
- file tabs
- edit/save/Save As
- find in file
- find in project
- quick open
- folding
- direct vendored Tree-sitter highlighting for Zig, JSON, C, shell, and Markdown, with GtkSourceView fallback
- minimap
- recent projects
- private atomic hot-exit restoration for dirty saved and untitled tabs
- Save/Discard/Cancel protection when closing an individual dirty tab

Not claimed yet:

- VS Code parity
- Zed/Sublime parity
- plugin ecosystem
- persistent language-server sessions, inline diagnostics/code actions, and LSP/DAP parity; current LSP actions are explicit on-demand local requests
- every-language syntax correctness
- Tree-sitter-driven folding, structural selection, or symbol navigation
- incremental/background parsing; the current alpha debounce performs a bounded full parse on GTK's main thread
- long-duration GUI editor stability across many projects
- forced SIGKILL/session-logout unsaved-file protection

A forced process kill, desktop session termination, or power loss cannot wait
for a GUI prompt. The one-second debounced snapshot reduces loss but does not
guarantee the latest keystroke; users still need to save important files.

## Performance claims

NOCTTY includes local benchmarks and resource receipts. Treat them as one-host
engineering evidence unless explicitly described otherwise.

Do not claim:

- universal fastest terminal
- universal lowest memory terminal
- production-grade performance on all GPUs/compositors
- multi-day resource stability

Useful public language:

> NOCTTY is designed and measured for low overhead on the author's Linux/KDE
> development host, with scripts available for others to reproduce locally.

## Ghostty/VTE boundaries

Production `noctty` uses NOCTTY's own Zig PTY/VT/grid path and does not depend
on Ghostty's private GUI ABI. Ghostty-related experiments must stay isolated
behind the adapter boundary.

The older GTK/VTE path is optional/legacy and not the default product surface.

## Network and telemetry

NOCTTY should not add telemetry, analytics, update pings, crash uploaders, or
remote feature flags. Any future network behavior must be explicit, user-owned,
and documented.

The maintained alpha guard is:

```sh
./scripts/check_no_surprise_network.sh
```

Current retained result: `no_surprise_network_check telemetry=false update_pings=false crash_uploaders=false remote_flags=false hidden_network_api=false proof_boundary=static_source_scan`.
