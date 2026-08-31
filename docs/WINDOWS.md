# Windows Alpha

NOCTTY now has an experimental native Windows terminal host. It is a real
Windows build rather than a Linux executable renamed for Windows, but it is the
first portability tranche and does not yet have Linux feature parity.

## Current Windows boundary

Included:

- x86_64 Windows GUI executable with no GTK runtime
- Win32 window and GDI terminal rendering
- Windows ConPTY shell transport
- the same renderer-neutral Zig VT/parser used by Linux NOCTTY
- ANSI color, true color, Unicode text, cursor, title, scrollback, and live resize
- selectable PowerShell or Command Prompt launch profile for new shells
- arrow, navigation, function, control, and Unicode keyboard input
- `Ctrl+Shift+V`/`Shift+Insert` clipboard paste
- Unicode-aware drag selection with `Ctrl+Shift+C` copying the selected range
- DEC 1000/1002/1003 mouse reporting with legacy and SGR encodings; `Shift`+
  left drag always selects locally when an application has mouse capture
- local lifecycle/error logs and local crash minidumps
- bounded local tabs and recursive split-down/split-left layouts, with one
  independent ConPTY process, Zig VT grid, output ring, reply path, resize
  state, and lifecycle per pane
- a native Win32 menu for dark/system-high-contrast themes, 11/13/16/18-point
  terminal fonts, launch profile, and startup workspace restoration
- explicit, checksummed save/restore of the bounded tab and split layout;
  restoring launches replacement shells rather than serializing shell contents
- explicit command-line LAN discovery, pairing, and encrypted terminal
  sharing/receiving with a native GDI remote view and host-approved,
  connection-scoped input; while receiving a Linux workspace, `Ctrl+Tab`
  cycles shared tabs and `Ctrl+Shift+Tab` cycles panes in the selected tab as
  its hierarchy changes
- a separate native `nocted.exe` editor with tabs, project tree, UTF-8 editing,
  find, clipboard commands, atomic save, and bounded session restore
- a reproducible per-user NSIS installer with Start Menu shortcuts, optional
  desktop shortcuts, reversible NoctEd Open-With registration, silent lifecycle
  support, and a fail-closed operator-provided signing hook
- no telemetry, analytics, update checks, crash uploads, or remote flags

Not included or claimed yet:

- Smart Tabs, broadcast input, mouse/tab-strip workspace controls, adjustable
  split ratios, or a reusable launch-profile library
- dropdown/global-hotkey behavior
- shell-content recovery or Linux workspace continuity parity
- real release Authenticode signatures, MSIX packaging, ARM64, or automatic
  updates
- graphical paired-device/session-sharing controls
- physical Windows dogfood or compatibility qualification

This should be treated as a testable Windows terminal alpha, not as Windows
parity with the current Linux workspace.

ConPTY pipes, the shell process, reader thread, synchronized 1 MiB output ring,
resize/exit polling, Unicode clipboard global memory, native-menu state,
DPI-aware font creation/metrics, preference normalization, bounded window
titles, the double-buffered GDI renderer, local diagnostics, and sibling NoctEd
launch are Zig-owned platform adapters. The remaining C host is limited to
HWND/timer ownership, input/workspace-session orchestration, and
window-message/command dispatch behind the existing ABI.

## Requirements

- Windows 10 version 1809 or newer, or Windows 11
- x86_64 processor
- PowerShell or `cmd.exe`

ConPTY is part of Windows and no GTK/MSYS/Cygwin runtime is required.
Session sharing additionally requires direct TCP reachability between devices;
the Windows firewall may prompt when listening. LAN, tailnet, and other routed
VPN addresses work without protocol-specific integration. NOCTTY does not
provide a relay or NAT traversal.

## Local tabs and splits

The local Windows workspace admits up to 16 tabs and 32 panes. Every pane owns
an independent ConPTY process and Zig VT grid; resize, output, terminal replies,
input, process exit, and teardown remain indexed to that pane. Split trees are
recursive and divide each branch evenly. The window title reports the current
tab and pane counts, and clicking a rendered pane focuses its exact session.

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+T` | Open and focus a new tab |
| `Ctrl+Shift+S` | Split the focused pane down |
| `Ctrl+Shift+L` | Split the focused pane left |
| `Ctrl+Tab` | Cycle panes in the current tab |
| `Ctrl+Shift+Tab` | Cycle tabs |
| `Ctrl+D` | Close the focused pane; the final session is protected |
| `Ctrl+Shift+W` | Close the current tab; the final tab is protected |

These controls are intentionally smaller than the Linux workspace surface.
There is no Windows tab strip, drag reordering, reusable profile library,
Smart Tab, or broadcast-input claim yet.

## Selection and terminal mouse input

Left-drag selects terminal cells in the focused pane. `Ctrl+Shift+C` copies the
selected range with trailing row padding removed; with no selection it copies
the visible grid. Selection extraction preserves UTF-8 grapheme text and does
not emit duplicate bytes for wide-cell continuations. A resize, pane change, or
new selection clears the prior highlight.

When a terminal enables DEC 1000, 1002, or 1003 mouse tracking, unmodified
button, drag/motion, and wheel events go to the application. Both legacy and
SGR 1006 encodings are supported. Hold `Shift` while left-dragging to bypass
application capture and make a local selection. Losing focus or capture sends
bounded release reports before NOCTTY clears pressed-button state.

## Native settings and saved layouts

The window's **Settings** menu applies user-owned, local preferences:

- **Theme** selects the built-in dark palette or Windows' current
  high-contrast window colors.
- **Font size** selects 11, 13, 16, or 18 points.
- **Launch profile** selects PowerShell or Command Prompt for newly created
  ConPTY sessions. `NOCTTY_WINDOWS_SHELL` remains the explicit test/operator
  override and takes precedence.
- **Restore saved workspace on startup** controls whether a saved layout is
  reconstructed before the native host opens.

The **Workspace** menu saves the current bounded tab/split model or restores the
last saved model. Restore is intentionally destructive: NOCTTY confirms first,
closes the current shells, reconstructs the validated layout, and starts
replacement shells. Scrollback, process state, working directories, and shell
contents are not serialized.

Preferences and the saved layout use an atomic, versioned, checksummed local
file at `%LOCALAPPDATA%\NOCTTY\windows-state-v1.bin`. Invalid or truncated state
is ignored; startup falls back to the default single-pane workspace.

## Native Windows NoctEd

`nocted.exe` is a separate native Win32 editor process; it does not run inside
the terminal host and does not require GTK, Node.js, Electron, or a browser
runtime. It provides bounded document tabs, a project tree, UTF-8 Rich Edit
editing, undo/redo, cut/copy/paste, find, New/Open/Open Folder, Save/Save As,
dirty-close prompts, and DPI-aware native controls.

Start it directly, open one file, or index a project folder:

```powershell
.\nocted.exe
.\nocted.exe --open C:\work\project\main.zig
.\nocted.exe --project C:\work\project
```

NoctEd atomically saves files and rejects a save when the loaded file identity
changed on disk. Restored dirty file buffers remain deliberately conflicted
because the prior identity is not persisted; save them to a different path
after reviewing the on-disk file. Its bounded session state restores ordered
tabs, dirty recovery buffers, the active tab, and the project root under
`%LOCALAPPDATA%\NOCTTY`. Choosing **No** in a dirty-exit prompt removes that
buffer from recovery instead of reopening the file; failure to persist the
remaining recovery state blocks shutdown.

Use **View → Zoom In/Out/Reset Zoom** or `Ctrl++`, `Ctrl+-`, and `Ctrl+0`
to change the active editor font. Holding `Ctrl` while scrolling over the
document provides the same point-by-point zoom. **Settings → Editor Font
Size…** accepts an exact size from 8 to 32 points. The status bar reports the
current size, which is restored from
`%LOCALAPPDATA%\NOCTTY\NoctEd\settings.conf` on the next launch.

The Win32 controls adapter is Zig-owned. Its focused isolated Wine
qualification cross-compiles a mock-callback host and is designed to map the
real RichEdit/tree/tab controls, enter the message loop, and perform a
controlled close in Debug and `ReleaseSafe`. Its first mapped run exposed and
closed a pseudo-HMENU alignment panic; post-fix mapped runs pass under isolated
Wine in both modes. Physical Windows input, rendering, file dialogs, and
persistence remain unproved.

## Pair and share a terminal

Pairing is explicit on both devices. The first command listens on `PORT` and
records the other device under `ALIAS` and its reachable `HOST`; the second
connects to that listener:

```powershell
# Device A
.\noctty.exe --pair-listen 49331 "Device B" "device-b.tailnet.example"

# Device B
.\noctty.exe --pair-connect "device-a.tailnet.example" 49331 "Device A"
```

For devices on the same LAN, the listener advertises only while the explicit
`--pair-listen` command is active. The other device can discover one listener
before connecting:

```powershell
.\noctty.exe --discover
```

The result shows the direct `--pair-connect` command parameters. Tailnets and
routed VPNs commonly do not carry LAN multicast or broadcast; use the direct
hostname/IP form above there.

Compare the six-digit code shown on both devices and accept only if it matches.
The private identity is saved as
`%LOCALAPPDATA%\NOCTTY\sharing-identity.dpapi`; the paired-device list is saved
beside it as `sharing-peers.dpapi`. Both use current-user DPAPI protection.
Inspect saved indexes or revoke a device without editing the protected files:

```powershell
.\noctty.exe --list-pairs
.\noctty.exe --revoke 0
```


To share Device A's current ConPTY terminal on the same reachable port and
receive it on Device B:

```powershell
# Device A
.\noctty.exe --share 0 49331

# Device B
.\noctty.exe --receive 0
```

The receiver starts view-only. Typing requests control; Device A shows a native
approval prompt before any input is delivered. Approval applies only to the
selected shared pane and that connection, and ends on pane closure,
resynchronization, revoke, or disconnect. A Linux host can publish one pane,
one dynamic tab, or its entire workspace. The Windows receiver reconstructs
every pane in the selected tab from the host's split tree and ratios; its title
identifies the received scope, shared tab, and focused terminal. `Ctrl+Tab`
cycles shared tabs; `Ctrl+Shift+Tab` cycles focus between panes in the selected
layout, and clicking a pane focuses it directly. Tabs and panes join, leave,
reorder, rename, split, zoom, or move without reconnecting. The mouse wheel
navigates the latest 64 mirrored host scrollback rows per pane, and explicit
`Ctrl+Shift+V` or `Shift+Insert` clipboard paste uses the existing bounded
input path. A Windows host publishes the ConPTY pane selected when sharing
starts; later local tab/pane focus changes cannot migrate that stream or an
existing remote-control grant to another shell. The shell, process, and full
scrollback remain owned by Device A; this is presentation mirroring with
bounded receiver history, not PTY migration.
Capability negotiation rejects incompatible peers, sequence gaps request a
fresh bounded pane checkpoint, and idle host links require authenticated
keepalive replies. Reconnecting performs a new paired-key handshake and never
restores a prior control grant.

## Build from Linux or Windows

With Zig 0.16.x:

```sh
zig build \
  -Dtarget=x86_64-windows-gnu \
  -Doptimize=ReleaseFast \
  -Dstrip=false
```

The executable is written to `zig-out/bin/noctty.exe`.

Create the dogfood ZIP and SHA-256/manifest sidecars:

```sh
./scripts/package_windows.sh dist/noctty-windows-x86_64-alpha.zip
```

The package intentionally keeps symbols in the optimized executable so early
crash reports remain useful.

Build the reproducible per-user NSIS installer from that portable ZIP:

```sh
./scripts/package_windows_installer.sh \
  dist/noctty-windows-x86_64-setup-unsigned.exe \
  dist/noctty-windows-x86_64-alpha.zip
```

The installer builder verifies the portable ZIP checksum, manifest schema,
version, revision, unsigned status, and NoctEd payload before consuming it. A
missing or stale generated portable artifact is rebuilt from the current tree
and validated again; an invalid regenerated contract fails with an explicit
error instead of a silent `grep` exit.

The installer targets `%LOCALAPPDATA%\Programs\NOCTTY`, requires no
administrator elevation, creates Start Menu shortcuts, offers optional desktop
shortcuts, and registers NoctEd only as an **Open with** option for supported
text/code extensions. `/S` provides silent install and uninstall. Uninstall
removes only installer-owned files and registrations; it preserves
`%LOCALAPPDATA%\NOCTTY` user state and unrelated files in the install directory.

Release signing is deliberately operator-owned. Set
`NOCTTY_WINDOWS_SIGN_HOOK` to an absolute executable path. The hook receives
`sign KIND INPUT OUTPUT` for `noctty-exe`, `nocted-exe`, and `installer`, then
`verify KIND ARTIFACT`; verification must report signer identity, certificate
thumbprint, timestamp presence, and signing tool. Packaging fails closed if the
hook does not change and verify every artifact, preserves the canonical unsigned
installer, and emits a separate signed installer plus a verification receipt.
NOCTTY contains no credentials and makes no signed-release claim without that
operator receipt.

## Run and choose a shell

Double-click `noctty.exe` or start it from PowerShell. NOCTTY attempts
Windows PowerShell first and falls back to `cmd.exe`.

Set an explicit command line before launch when testing PowerShell 7 or another
ConPTY-compatible shell:

```powershell
$env:NOCTTY_WINDOWS_SHELL = 'pwsh.exe -NoLogo'
.\noctty.exe
```

The value is local, user-owned process configuration. NOCTTY does not download
or discover shells over the network.

## Logs and crash dumps

Each launch writes local metadata and error logs under:

```text
%LOCALAPPDATA%\NOCTTY\logs\
```

Unhandled crashes write a local `.dmp` file beside the log. Terminal command
output is not copied into the debug log. Nothing is uploaded automatically.
Please retain the matching ZIP checksum and `BUILD-INFO.txt` when reporting a
problem.

Useful report details:

- Windows version and GPU/remote-desktop context
- shell selected and whether fallback occurred
- steps immediately before the problem
- the matching `.log`
- the matching `.dmp` for a crash, if sharing it is acceptable

Review logs and dumps before sharing because local paths and process metadata
may be sensitive.

## Self-test and physical smoke

`noctty.exe` contains a no-window VT/parser, selection/mouse, and
bounded-workspace contract test:

```powershell
.\noctty.exe --self-test
$LASTEXITCODE
```

The separate editor has a document bridge, atomic-save, and external-change
rejection self-test:

```powershell
.\nocted.exe --self-test
$LASTEXITCODE
```

The package also includes a PowerShell wrapper:

```powershell
.\WINDOWS-SMOKE.ps1
.\WINDOWS-SMOKE.ps1 -AutomatedHost
.\WINDOWS-SMOKE.ps1 -Interactive
```

The default wrapper checks the embedded fixture. `-AutomatedHost` starts a real
`cmd.exe` through ConPTY, requires the marker to reach the shared Zig VT and a
Win32/GDI paint, verifies that the native settings menu/preferences bridge was
created, and requires clean process/host exit. `-Interactive` launches the
normal host and prints the prompt, settings persistence, launch-profile,
workspace restore, input, resize, clipboard, and scroll checklist. It does not
infer whether the visual checklist passed; record those operator observations
separately.

An exit code of `0` from `noctty.exe --self-test` proves the embedded Zig VT
processed the pinned color/cursor fixture; selection preserved Unicode
graphemes; DEC mouse mode and SGR encoding matched their bounded contracts;
nested split layout, tab/pane cycling, collapse, and final-session protection
matched the workspace model; and a multi-tab layout survived the
versioned/checksummed persistence codec. `nocted.exe --self-test` proves its
UTF-8 load/save bridge and external-change guard. Neither proves ConPTY, GDI
presentation, installer behavior, input, or physical Windows compatibility;
those require a supported Windows session.
