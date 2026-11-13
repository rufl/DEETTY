# Known Limitations

DEETTY is in pre-public Linux alpha. This document keeps public expectations
small and clear.

## Platform support

Supported first:

- Linux desktop
- KDE Plasma Wayland/X11
- Noctalia-compatible Wayland sessions

Experimental, not parity or daily-driver qualified:

- x86_64 Windows 10 1809+/Windows 11 Win32/ConPTY terminal workspace. Native
  tabs/splits, settings, layout restore, mouse reporting/selection, NoctEd,
  and an NSIS installer are implemented. Dropdown/global-hotkey behavior,
  Linux workspace continuity parity, graphical sharing controls, ARM64,
  release signatures, and physical Windows qualification remain open.
  See [Windows alpha](WINDOWS.md) for the feature boundary.

Not supported or not claimed yet:

- macOS
- BSDs
- mobile
- remote desktop edge cases
- all Wayland compositors
- all accessibility stacks

## Packaging and release operations

Source builds and local packaging paths exist, but public release operations are
not complete yet.

Ordinary source builds and `zig build check` do not require maintainer release
receipts or graphical infrastructure. The optional
`scripts/public_alpha_verify.sh` uses the repository-owned bubblewrap/Xvfb plus
private-window-manager runner for X11 and a virtual-capable KWin for Wayland.
Those host packages are not bundled with the source; release CI provisions
them, while contributors may use the non-graphical gate when they are
unavailable. Never substitute an active desktop for an unavailable isolation
dependency.

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

DEETTY has substantial bounded terminal/PTY/VT evidence, including deterministic
protocol fixtures and several installed TUI applications. This does not mean
universal terminal compatibility.

Not complete yet:

- authenticated Claude Code/Antigravity receipts and broader real daily-agent workflows; the retained Codex matrix is one exact ephemeral read-only request per mode/backend
- broader real terminal application matrix on mapped Plasma Wayland/X11
- the retained hidden/visible harness shakedown passes, but its authenticated 24-hour Wayland plus 24-hour X11 acceptance run has not elapsed
- physical keyboard/HID-to-visible-presentation distributions; the retained mapped lane starts at a synthetic production key-handler invocation, and X11 exposed no completed presentation timestamp on this host
- universal ncurses/alternate-screen/mouse behavior claims

## Session continuity

DEETTY restores workspace layout and restarts fresh shells in saved directories.
It does **not** resurrect arbitrary in-memory shell processes after a crash or
forced exit.

Persistent tmux/Zellij launch kinds and installed live detach/relaunch/reattach now pass on this host. This does not make arbitrary shell processes restartable, prove remote multiplexer transports, or establish cross-host and multi-day survival.

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

Save refuses replacement when the original file changed or disappeared.
Dirty restored buffers lack a retained original-disk identity and require
Save As rather than assuming the current disk version is safe to overwrite.
The identity check narrows external-write races but is not a cross-process
filesystem lock; Save As remains the escape hatch for an unknown original.

Language-service edits use request-time snapshots of open buffers. Closing or
changing a target invalidates its response. A workspace rename that mentions an
unopened or changed file is rejected before any edit; open the affected files
and retry. Unopened disk files are not edited without a baseline.

Not claimed yet:

- VS Code parity
- Zed/Sublime parity
- plugin ecosystem
- persistent language-server sessions, inline diagnostics/code actions, and LSP/DAP parity; current LSP actions are explicit on-demand local requests
- every-language syntax correctness
- Tree-sitter-driven folding, structural selection, or symbol navigation
- incremental/background parsing; direct vendored Tree-sitter work is debounced for 100 ms, limited to 32 KiB and 4,096 captures on GTK's main thread, and falls back to GtkSourceView rather than partially highlighting or blocking larger/complex files
- multi-hour/multi-day GUI editor stability across a varied project corpus
- forced SIGKILL/session-logout unsaved-file protection

A forced process kill, desktop session termination, or power loss cannot wait
for a GUI prompt. The one-second debounced snapshot reduces loss but does not
guarantee the latest keystroke; users still need to save important files.

## Accessibility

Native action buttons, settings categories, editor trees, result lists, tabs, and status surfaces expose keyboard focus or assistive names where the toolkit supports them. DEETTY and NoctEd tab/action controls retain 28-logical-pixel width and 18-logical-pixel height targets with explicit hover, active, and keyboard-focus states.

Not complete or claimed yet:

- full screen-reader access to every custom-drawn terminal cell and scrollback transition
- qualified assistive-technology behavior across Plasma Wayland and X11
- universal high-contrast/theme behavior outside the retained native smoke cases

## Performance claims

DEETTY includes local benchmarks and resource receipts. Treat them as one-host
engineering evidence unless explicitly described otherwise.

Do not claim:

- universal fastest terminal
- universal lowest memory terminal
- production-grade performance on all GPUs/compositors
- multi-day resource stability; the short cross-backend shakedown is not the pending 48-hour receipt

Useful public language:

> DEETTY is designed and measured for low overhead on the author's Linux/KDE
> development host, with scripts available for others to reproduce locally.

## Ghostty/VTE boundaries

Production `deetty` uses DEETTY's own Zig PTY/VT/grid path and does not depend
on Ghostty's private GUI ABI. Ghostty-related experiments must stay isolated
behind the adapter boundary.

The older GTK/VTE path is optional/legacy and not the default product surface.

## Network and telemetry

DEETTY should not add telemetry, analytics, update pings, crash uploaders, or
remote feature flags. Any future network behavior must be explicit, user-owned,
and documented.

The maintained alpha guard is:

```sh
./scripts/check_no_surprise_network.sh
```

Current retained result: `no_surprise_network_check telemetry=false update_pings=false crash_uploaders=false remote_flags=false hidden_network_api=false proof_boundary=static_source_scan`.
