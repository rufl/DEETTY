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
- PowerShell with `cmd.exe` fallback
- arrow, navigation, function, control, and Unicode keyboard input
- `Ctrl+Shift+V`/`Shift+Insert` clipboard paste
- `Ctrl+Shift+C` copy of the visible terminal surface
- local lifecycle/error logs and local crash minidumps
- no telemetry, analytics, update checks, crash uploads, or remote flags

Not included or claimed yet:

- tabs, recursive splits, Smart Tabs, broadcast input, or launch-profile UI
- dropdown/global-hotkey behavior
- workspace recovery and continuity UX
- native settings/theme dialogs
- mouse-reporting applications or text selection
- Windows NoctEd
- code signing, installer/MSIX packaging, ARM64, or automatic updates
- physical Windows dogfood or compatibility qualification

This should be treated as a testable Windows terminal alpha, not as Windows
parity with the current Linux workspace.

## Requirements

- Windows 10 version 1809 or newer, or Windows 11
- x86_64 processor
- PowerShell or `cmd.exe`

ConPTY is part of Windows and no GTK/MSYS/Cygwin runtime is required.

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

The executable contains a no-window VT/parser contract test:

```powershell
.\noctty.exe --self-test
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
Win32/GDI paint, and requires clean process/host exit. `-Interactive` launches
the normal host, prints the prompt/input/resize/clipboard/scroll checklist, and
then requires a ConPTY shell marker and clean shutdown marker in the new local
log. It does not infer whether the visual checklist passed; record those
operator observations separately.

An exit code of `0` from `--self-test` proves the embedded Zig VT initialized
and processed the pinned color/cursor fixture. It does not prove ConPTY, GDI
presentation, input, or physical Windows compatibility; those require a
Windows session.
