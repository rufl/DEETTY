# Windows Native Host / Parity Boundary

DINTTY has an experimental native Windows terminal host. It is a real
Windows build rather than a Linux executable renamed for Windows, but it is
the first portability tranche and does not yet have Linux feature parity.

Last refreshed: 2026-10-02. The locked [Linux/Windows parity matrix](WINDOWS_LINUX_PARITY.md)
and [Simplified Chinese companion](WINDOWS_LINUX_PARITY.zh-CN.md) distinguish
implemented code, supporting evidence, and physical-host gates.

## Current Windows boundary

Included:

- x86_64 Windows GUI executable with no GTK runtime
- Win32 window and GDI terminal rendering
- Windows ConPTY shell transport
- the same renderer-neutral Zig VT/parser used by Linux DINTTY
- ANSI color, true color, Unicode text, cursor, title, scrollback, and live resize
- built-in PowerShell/Command Prompt and eight reusable custom launch profiles
- arrow, navigation, function, control, and Unicode keyboard input
- `Ctrl+Shift+V`/`Shift+Insert` clipboard paste
- Unicode-aware drag selection with `Ctrl+Shift+C` copying the selected range
- DEC 1000/1002/1003 mouse reporting with legacy and SGR encodings; `Shift`+
  left drag always selects locally when an application has mouse capture
- local lifecycle/error logs and local crash minidumps
- bounded local tabs and recursive split-down/split-left layouts, with one
  independent ConPTY process, Zig VT grid, output ring, reply path, resize
  state, and lifecycle per pane
- native Win32 Settings, Workspace, and Terminal menus exposing themes,
  font sizes, per-pane launch profiles, workspace creation/navigation/guarded
  close, layout persistence, copy/paste, and focused-terminal Ctrl+L
- a native tab strip with direct tab selection, custom tab names, drag reordering,
  and left/right ordering commands; pane sessions retain their identities
- proportional split dividers with drag preview, menu-based pane resizing,
  reset/equalize, and saved ratios
- portable theme-library import/export, persistent custom selection, and native
  Unicode file dialogs using the shared Linux theme codec
- explicit, checksummed save/restore of the bounded tab and split layout;
  restoring launches replacement shells rather than serializing shell contents
- per-pane launch-profile identity, inherited by splits, selected by profile
  save/select actions, remapped on profile deletion, and persisted in the NWS5
  workspace envelope
- a DPI-aware compact status footer that reserves terminal height and reports
  local/remote mode, tab/pane position, and the active launch profile
- native Smart Tab tag filters and the Ctrl+Alt+Space dropdown/global-hotkey
  entry point; physical input and lifecycle qualification remains open
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
- an automated host-qualification harness covering ConPTY, VT parsing, GDI
  painting, settings, input coordinates, selection, clipboard, and clean exit;
  completed physical Windows 10/11 parity receipts remain open

Not included or claimed yet:

- shell-content recovery or Linux workspace continuity parity
- real release Authenticode signatures, MSIX packaging, ARM64, or automatic
  updates
- supported-Windows visual and physical-input acceptance for the implemented
  paired-device/session-sharing controls
- the physical Windows 10/11 capability matrix, including Smart Tabs,
  dropdown/global-hotkey behavior, DPI/high-contrast/IME/accessibility
  coverage, and cross-machine session-sharing receipts

This should be treated as a testable Windows terminal alpha, not as Windows
parity with the current Linux workspace.

ConPTY pipes, the shell process, reader thread, synchronized 1 MiB output ring,
resize/exit polling, Unicode clipboard global memory, native-menu state,
DPI-aware font creation/metrics, preference normalization, bounded window
titles, the double-buffered GDI renderer, local diagnostics, and sibling NoctEd
launch are Zig-owned platform adapters. `WindowsHost.zig` also owns
HWND/timer lifetime, input/workspace-session orchestration, and native
window-message/command dispatch. The Windows host has no first-party C
translation unit.

## Requirements

- Windows 10 version 1809 or newer, or Windows 11
- x86_64 processor
- PowerShell or `cmd.exe`

ConPTY is part of Windows and no GTK/MSYS/Cygwin runtime is required.
Session sharing additionally requires direct TCP reachability between devices;
the Windows firewall may prompt when listening. LAN, tailnet, and other routed
VPN addresses work without protocol-specific integration. DINTTY does not
provide a relay or NAT traversal.

## Local tabs and splits

The local Windows workspace admits up to 16 tabs and 32 panes. Every pane owns
an independent ConPTY process and Zig VT grid; resize, output, terminal replies,
input, process exit, and teardown remain indexed to that pane. Split trees are
recursive and begin with equal branches. Drag a divider to preview a new split;
release to apply it, or press Escape to discard it. Workspace resize commands
grow/shrink the focused pane along either axis, and reset restores equal splits.
Interactive ratios stay between 5% and 95%; resizing never changes pane/session
identity. Save the current layout to retain ratios. Remote layouts stay
host-owned. The window title reports tab/pane counts, and clicking a pane
focuses its exact session.

Click the native tab strip to select a tab. **Workspace → Focus Tab Strip**
provides keyboard access to the native control without stealing terminal
function keys. **Rename Tab**, **Move Tab Left**, and **Move Tab Right** operate
on the selected local tab. Renaming accepts up to 128 UTF-8 bytes without control
characters; an empty name returns to the automatic label. Reordering changes
the tab order, not pane slots, running processes, split trees, or each tab's
focused pane. Use **Save current layout** to persist names and ordering.

Drag a local tab past the native drag threshold to reorder it. The insertion
marker previews the destination; releasing commits one move. Escape, capture
loss, window resize, or workspace changes cancel the drag. The existing
left/right menu commands remain the keyboard alternative.

Remote tabs can be selected but not renamed or reordered locally. Their names
and ordering remain owned by the host.

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+T` | Open and focus a new tab |
| `Ctrl+Shift+S` | Split the focused pane down |
| `Ctrl+Shift+L` | Split the focused pane left |
| `Ctrl+Tab` | Cycle panes in the current tab |
| `Ctrl+Shift+Tab` | Cycle tabs |
| `Ctrl+D` | Close the focused pane; the final session is protected |
| `Ctrl+Shift+W` | Close the current tab; the final tab is protected |

The **Workspace** menu exposes these same actions and save/restore commands.
The **Terminal** menu provides Copy, Paste, and Clear Screen. Clear Screen sends
one Ctrl+L byte to the focused local or remote input path; the running shell or
application decides how to redraw. It does not directly erase the VT grid.
Paste and clear input-delivery failures show a native error dialog.

Remote viewers disable local workspace mutations and reject them at dispatch.
Next Pane and Next Tab remain available, with shortcut hints changed to match
the remote navigation order described above.

These controls remain smaller than the Linux workspace surface. Broadcast
input is available locally through the Workspace menu or
`Ctrl+Shift+B`; enabling it requires confirmation, sends input to every live
local pane, and is disabled for remote viewers. The setting is session-scoped
and starts disabled after restart. Smart Tabs, dropdown/global-hotkey behavior,
and sharing controls are implemented in the native source path; their physical
Windows and cross-machine qualification remains open. Linux workspace
continuity also remains open.

### Parity development boundary

Linux and Windows should share toolkit-neutral behavior, not widget handles or
transport lifetimes. Terminal key encoding is the first shared extraction;
GDK key values and Windows virtual keys stay in their respective adapters.
GTK/Cairo and Win32/GDI remain native surfaces, and POSIX PTY versus ConPTY
ownership remains platform-specific.

The next larger parity work is physical qualification of the implemented
Windows workspace surface and Linux workspace continuity. The source-level
Smart Tabs, dropdown/global-hotkey, broadcast, pairing, and sharing controls
are already represented in the parity matrix; physical host and cross-machine
receipts remain separate gates. Windows' bounded workspace tree and versioned
snapshot codec live in `src/windows/WindowsWorkspace.zig`. Its divider
conversions use `src/workspace/SplitRatio.zig`, also consumed by the GTK
divider adapter. Platform widgets and PTY lifetimes remain separate.

Cross-compilation proves build compatibility. Isolated Wine can exercise native
controls and command dispatch, but does not establish physical Windows
ConPTY/GDI, DPI, IME, or accessibility parity.
The full Linux × Windows acceptance definition is the fixed NCT-127 DoD in
`BACKLOG.md`: it requires a capability-by-capability matrix, supported-host
ConPTY/GDI/DPI/input/accessibility receipts, and real cross-machine
Linux↔Windows proof. Build compatibility and Wine control coverage do not
close that parity gate.

The [parity matrix](WINDOWS_LINUX_PARITY.md) is the source-tree inventory for
NCT-127; the [Chinese version](WINDOWS_LINUX_PARITY.zh-CN.md) is kept beside it.

### Focused native-control qualification

On Linux, `zig build windows-policy-test` exercises workspace identity,
proportional geometry, appearance/input policy, profile validation/persistence,
launch planning, and old/new snapshot compatibility without a display.
`windows-workspace-test` remains the narrower
workspace-only target.

After a Windows cross-build, run:

```sh
scripts/windows_terminal_menu_smoke.sh path/to/dintty.exe
```

This uses the reviewed isolated-display runner and a disposable Wine prefix.
It inspects real Win32 menus and tab controls, local/remote enabled-state
transitions, navigation shortcuts, tab selection, Unicode rename validation
and cancellation, reorder identity, terminal content inset, rejection of remote
workspace mutations, and HWND-owned child/menu destruction. It also exercises
divider drag/commit/cancellation, both-axis menu adjustment/reset, exact font
dialog validation and cancellation, theme selection, and font-size boundaries.
The theme/tab tranche adds production tab-drag qualification, Unicode file
paths, common-dialog cancellation, portable import/export, persisted custom
selection, rejected-import rollback, and bitmap sampling of terminal colors.
The profile tranche exercises native create/edit/rename/delete controls,
invalid and oversized fields, dirty/cancel decisions, selection, and durable
reload. A real child process checks executable and working-directory paths
containing spaces and Unicode, raw arguments, inherited environment, explicit
overrides, and unchanged parent environment through the production launch plan.
It does not start or mock ConPTY; its receipt explicitly reports `conpty=false`.

On supported Windows, run the packaged `windows_smoke.ps1 -Interactive`
checklist to exercise the new menus against real shells, clipboard, and remote
input permissions. Cross-compilation and the hidden-window Wine qualification
do not establish visual, physical-input, or ConPTY acceptance for these actions.

The integrated profile tranche passes focused policy/codec tests, Windows and
GTK `ReleaseSafe` builds, file-backed profile lifecycle/write-failure rollback,
and a POSIX named-profile configuration round-trip. Isolated GTK settings also
prove named-profile save/select/delete, reload, and real PTY launch. The isolated
Wine smoke covers the prior theme, tab, divider, menu, and font controls.
These receipts do not establish supported-Windows visual, input, or ConPTY
acceptance.

A separate private-X11/Wine visual run verified the mapped profile fields and
save feedback and opened a custom-command tab. That run showed no terminal
text, so it does not qualify ConPTY output; supported-Windows verification
remains required.

## Selection and terminal mouse input

Left-drag selects terminal cells in the focused pane. `Ctrl+Shift+C` copies the
selected range with trailing row padding removed; with no selection it copies
the visible grid. Selection extraction preserves UTF-8 grapheme text and does
not emit duplicate bytes for wide-cell continuations. A resize, pane change, or
new selection clears the prior highlight.

Right-clicking terminal content opens the native Terminal context menu with
Copy, Paste, and Clear Screen. This local action takes precedence over
application mouse tracking; the right-button event is not sent to the
application.

When a terminal enables DEC 1000, 1002, or 1003 mouse tracking, other
unmodified button, drag/motion, and wheel events go to the application. Both
SGR 1006 encodings are supported. Hold `Shift` while left-dragging to bypass
application capture and make a local selection. Losing focus or capture sends
bounded release reports before DINTTY clears pressed-button state.

## Native settings and saved layouts

The window's **Settings** menu applies user-owned, local preferences:

- **Theme** selects the shared DINTTY Dark or Paseo Black Zinc palette, Windows'
  current high-contrast window colors, or an imported custom theme. Terminal
  foreground/background, ANSI colors, and block-cursor colors use the selected
  shared palette; native window/menu chrome remains Windows-owned.
- **Font size** retains the 11/13/16/18-point presets and adds an exact native
  size dialog covering 8–32 points, plus increase/decrease/reset commands.
  These commands do not steal terminal keyboard shortcuts.
- **Launch profile** selects PowerShell, Command Prompt, or a named custom
  profile for newly created ConPTY sessions. **Manage Profiles…** creates,
  edits, renames, and deletes customs. Saving also selects that profile.
  `DINTTY_WINDOWS_SHELL` remains the explicit test/operator override and takes
  precedence over the chosen executable and arguments.
- **Restore saved workspace on startup** controls whether a saved layout is
  reconstructed before the native host opens.

The Workspace menu also exposes the first native Smart Tab controls:
`Ctrl+Shift+Y` toggles tag 1 on the focused pane, and `Ctrl+Shift+G` toggles
the volatile tag-1 filter. The filter hides unmatched pane geometry and hands
focus to the first matching pane; the filter resets after restart.

Broadcast input is session-scoped and is not serialized in `NWS3`; restarting
DINTTY always starts with broadcast disabled.

The **Workspace** menu saves the current bounded tab/split model or restores the
last saved model. Restore is intentionally destructive: DINTTY confirms first,
closes the current shells, reconstructs the validated layout, and starts
replacement shells. Scrollback, process state, working directories, and shell
contents are not serialized.

Preferences and the saved layout use an atomic, versioned, checksummed local
file at `%LOCALAPPDATA%\DINTTY\windows-state-v1.bin`. The pathname is retained
for compatibility: the reader accepts legacy `NWS1` and `NWS2` snapshots,
defaulting their split ratios to 50%. Subsequent saves write `NWS3` with tab
metadata and proportional split ratios. Older builds cannot read newly saved
`NWS3` files.
Invalid or truncated state is ignored; startup falls back to the default
single-pane workspace.

### Launch-profile library

The native manager accepts up to eight custom profiles with these limits:

| Field | Limit / interpretation |
| --- | --- |
| Name | 64 UTF-8 bytes; built-in names are reserved |
| Executable | 256 UTF-8 bytes; fully qualified Windows drive or UNC path |
| Arguments | 1,024 UTF-8 bytes; raw Windows arguments, without implicit `cmd /c` |
| Working directory | 4,096 UTF-8 bytes; empty or a fully qualified directory |
| Environment | 2,048 UTF-8 bytes, at most 16 `NAME=value;OTHER=value` entries |
| Scrollback | 1–100,000 lines for the new pane |

Inherited environment values are preserved unless overridden; Windows names
compare case-insensitively. Terminal defaults are applied before explicit
overrides. The parent process environment is never changed. Custom executable
or directory errors fail that launch rather than starting a different shell.
Choose `cmd.exe` or PowerShell explicitly when shell syntax is needed.

Selection and edits affect future sessions only. Deleting the selected custom
falls back to PowerShell; built-ins cannot be edited or deleted. Unsaved edits
and deletion require confirmation. Validation or write failures retain the
previous live library and selection.

The separate atomic, versioned file is
`%LOCALAPPDATA%\DINTTY\windows-launch-profiles-v1.bin`. Environment values are
stored locally **without encryption**; inherit secrets from the environment
instead of saving them in a profile. Missing or invalid profile state falls
back to the legacy built-in preference without overwriting the file until an
explicit successful change.
### Theme library

**Theme → Import library** opens a native file picker for portable
`.dinttythemes` libraries and single-source Ghostty `.conf`/`.ghostty`,
Xresources, Alacritty `.toml`, or Noctalia `.json` files. A source file becomes
one custom theme named from its validated ASCII filename stem; invalid stems
use `Imported theme`. Import replaces the custom library and selects its first
entry. Replacing existing custom themes requires confirmation.
Up to 64 custom themes and 4 MiB input are accepted;
malformed files or failed persistence leave the live and saved state unchanged.
Theme names follow the shared format's ASCII rules and 96-byte limit after
outer whitespace is trimmed; native labels use that trimmed name. File paths
support Unicode. Source parsers ignore unsupported keys but reject malformed
Noctalia JSON and preserve the previous library on validation or persistence
failure.

**Export library** writes the current custom library, or the three built-ins
when no customs exist, using the shared portable codec. The native save dialog
confirms overwrites. Import/export cancellation has no state effect.

Custom themes and active selection live together in the atomically replaced
`%LOCALAPPDATA%\DINTTY\windows-themes-v1.bin`. Legacy workspace preferences seed
the theme only when this separate state is absent or invalid. Corrupt theme
state is not overwritten automatically; an explicit successful theme selection
or import replaces it. Workspace snapshots remain `NWS3`.

## Native Windows NoctEd

`nocted.exe` is a separate native Win32 editor process; it does not run inside
the terminal host and does not require GTK, Node.js, Electron, or a browser
runtime. It provides bounded document tabs, a project tree, UTF-8 Rich Edit
editing, undo/redo, cut/copy/paste, find, New/Open/Open Project, Save/Save As,
dirty-close prompts, and DPI-aware native controls.

Start it directly, open one file, or open a saved `.npr` project:

```powershell
.\nocted.exe
.\nocted.exe --open C:\work\project\main.zig
.\nocted.exe --project C:\work\project\project.npr
```

**File → Open Project…** and `--project` require a `.npr` project file, not a
directory. NoctEd indexes the root recorded in that file; it does not currently
provide a Windows **Open Folder** command.

NoctEd atomically saves files and rejects a save when the loaded file identity
changed on disk. Restored dirty file buffers remain deliberately conflicted
because the prior identity is not persisted; save them to a different path
after reviewing the on-disk file. Its bounded session state restores ordered
tabs, dirty recovery buffers, and the active tab under `%LOCALAPPDATA%\DINTTY`.
The project is not restored automatically; reopen its `.npr` file explicitly.
Choosing **No** in a dirty-exit prompt removes that
buffer from recovery instead of reopening the file; failure to persist the
remaining recovery state blocks shutdown.

Use **View → Zoom In/Out/Reset Zoom** or `Ctrl++`, `Ctrl+-`, and `Ctrl+0`
to change the active editor font. Holding `Ctrl` while scrolling over the
document provides the same point-by-point zoom. **Settings → Editor Font
Size…** accepts an exact size from 8 to 32 points. The status bar reports the
current size, which is restored from
`%LOCALAPPDATA%\DINTTY\NoctEd\settings.conf` on the next launch.

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
.\dintty.exe --pair-listen 49331 "Device B" "device-b.tailnet.example"

# Device B
.\dintty.exe --pair-connect "device-a.tailnet.example" 49331 "Device A"
```

For devices on the same LAN, the listener advertises only while the explicit
`--pair-listen` command is active. The other device can discover one listener
before connecting:

```powershell
.\dintty.exe --discover
```

The result shows the direct `--pair-connect` command parameters. Tailnets and
routed VPNs commonly do not carry LAN multicast or broadcast; use the direct
hostname/IP form above there.

Compare the six-digit code shown on both devices and accept only if it matches.
The private identity is saved as
`%LOCALAPPDATA%\DINTTY\sharing-identity.dpapi`; the paired-device list is saved
beside it as `sharing-peers.dpapi`. Both use current-user DPAPI protection.
Inspect saved indexes or revoke a device without editing the protected files:

```powershell
.\dintty.exe --list-pairs
.\dintty.exe --revoke 0
```


To share Device A's current ConPTY terminal on the same reachable port and
receive it on Device B:

```powershell
# Device A
.\dintty.exe --share 0 49331

# Device B
.\dintty.exe --receive 0
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

The executable is written to `zig-out/bin/dintty.exe`.

Create the dogfood ZIP and SHA-256/manifest sidecars:

```sh
./scripts/package_windows.sh dist/dintty-windows-x86_64-alpha.zip
```

The package intentionally keeps symbols in the optimized executable so early
crash reports remain useful.

Build the reproducible per-user NSIS installer from that portable ZIP:

```sh
./scripts/package_windows_installer.sh \
  dist/dintty-windows-x86_64-setup-unsigned.exe \
  dist/dintty-windows-x86_64-alpha.zip
```

The installer builder verifies the portable ZIP checksum, manifest schema,
version, revision, unsigned status, and NoctEd payload before consuming it. A
missing or stale generated portable artifact is rebuilt from the current tree
and validated again; an invalid regenerated contract fails with an explicit
error instead of a silent `grep` exit.

The installer targets `%LOCALAPPDATA%\Programs\DINTTY`, requires no
administrator elevation, creates Start Menu shortcuts, offers optional desktop
shortcuts, and registers NoctEd only as an **Open with** option for supported
text/code extensions. `/S` provides silent install and uninstall. Uninstall
removes only installer-owned files and registrations; it preserves
`%LOCALAPPDATA%\DINTTY` user state and unrelated files in the install directory.

Release signing is deliberately operator-owned. Set
`DINTTY_WINDOWS_SIGN_HOOK` to an absolute executable path. The hook receives
`sign KIND INPUT OUTPUT` for `dintty-exe`, `nocted-exe`, and `installer`, then
`verify KIND ARTIFACT`; verification must report signer identity, certificate
thumbprint, timestamp presence, and signing tool. Packaging fails closed if the
hook does not change and verify every artifact, preserves the canonical unsigned
installer, and emits a separate signed installer plus a verification receipt.
DINTTY contains no credentials and makes no signed-release claim without that
operator receipt.

## Windows dogfood delivery

Build one checksum-bound dogfood bundle:

```sh
./scripts/package_windows_dogfood.sh
./scripts/windows_dogfood_bundle_smoke.sh
```

The default output is
`dist/dintty-windows-x86_64-dogfood.zip` with matching `.sha256` and
`.manifest` sidecars. The ZIP contains the per-user NSIS installer, its
checksum and manifest, and `Install-DINTTY-Dogfood.ps1`.

PI WEB QOL already discovers Windows artifacts under project `dist/`
directories. When its artifact service is bound to an explicit trusted LAN or
tailnet address, select DINTTY's **Builds** tab and download the dogfood ZIP on
the Windows machine. Do not bind the artifact service to a wildcard address.
ZWEB is the dashboard bundle rather than the transfer owner; ZNAP's embedded
service is loopback-only; OVERZEER deployment requires a separately managed
target service. The existing token-scoped PI WEB QOL download path is therefore
the smallest delivery boundary.
After copying or downloading the ZIP, verify its externally communicated
SHA-256, extract it, fully close DINTTY and NoctEd, and run from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\Install-DINTTY-Dogfood.ps1

# Current-user unattended install:
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\Install-DINTTY-Dogfood.ps1 -Silent
```

The script verifies the adjacent installer sidecar before execution, confirms
the installer registration and payload, runs both installed self-tests, and
atomically writes `%LOCALAPPDATA%\DINTTY\dogfood-install.receipt`. It does not
upload logs, dumps, or receipts. These dogfood artifacts remain unsigned;
checksum verification proves the received bytes match the operator's build but
does not establish publisher identity. Self-tests and Wine execution do not
replace physical Windows UI qualification.

## Run and choose a shell

Double-click `dintty.exe` or start it from PowerShell. DINTTY attempts
Windows PowerShell first and falls back to `cmd.exe`.

Set an explicit command line before launch when testing PowerShell 7 or another
ConPTY-compatible shell:

```powershell
$env:DINTTY_WINDOWS_SHELL = 'pwsh.exe -NoLogo'
.\dintty.exe
```

The value is local, user-owned process configuration. DINTTY does not download
or discover shells over the network.

## Logs and crash dumps

Each launch writes local metadata and error logs under:

```text
%LOCALAPPDATA%\DINTTY\logs\
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

`dintty.exe` contains a no-window VT/parser, selection/mouse, and
bounded-workspace contract test:

```powershell
.\dintty.exe --self-test
$LASTEXITCODE
```

The separate editor has a document bridge, atomic-save, and external-change
rejection self-test:

```powershell
.\nocted.exe --self-test
$LASTEXITCODE
```

The editor self-test uses `%LOCALAPPDATA%\DINTTY\NoctEd` for temporary files;
it does not require the package directory as its working directory. Success
exits zero. Failure exits one and reports the error name to stderr without
opening a dialog. Redirect stderr when running it from automation.

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

An exit code of `0` from `dintty.exe --self-test` proves the embedded Zig VT
processed the pinned color/cursor fixture; selection preserved Unicode
graphemes; DEC mouse mode and SGR encoding matched their bounded contracts;
nested split layout, tab/pane cycling, collapse, and final-session protection
matched the workspace model; and a multi-tab layout survived the
versioned/checksummed persistence codec. `nocted.exe --self-test` proves its
UTF-8 load/save bridge and external-change guard. Neither proves ConPTY, GDI
presentation, installer behavior, input, or physical Windows compatibility;
those require a supported Windows session.
