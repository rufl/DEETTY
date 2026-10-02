# Linux / Windows Native Parity Matrix

Last refreshed: 2026-10-02.

This is the locked source-tree inventory required by the fixed NCT-127
Definition of Done in [BACKLOG.md](../BACKLOG.md#nct-127-fixed-definition-of-done).
It records implementation and supporting evidence without converting cross-build,
Wine, loopback, or isolated-runner results into physical Windows acceptance.

Status vocabulary:

- **implemented** — the capability exists in the native source path.
- **supporting** — focused policy, native smoke, cross-build, or Wine evidence
  exercises part of the capability.
- **physical-open** — supported Windows 10/11 ConPTY, Win32/GDI, DPI,
  high-contrast, IME, accessibility, lifecycle, and clean-exit proof remains.
- **external-open** — real Linux↔Windows hosts, routed-VPN connectivity,
  identity transitions, and receipt integrity remain.

| ID | Capability | Linux implementation / proof | Windows implementation / proof | Current status | Remaining gate |
|---|---|---|---|---|---|
| `terminal-io` | Terminal input/output, VT, resize, scrollback | Zig VT + POSIX PTY; native host and focused runtime smoke | Zig VT + ConPTY + GDI; cross-build and host harness | implemented / supporting | physical-open |
| `tabs` | Tab creation, selection, rename, order, close | GTK notebook, durable identity, native smoke | Win32 tab control, bounded Unicode rename, drag/order model, Wine controls | implemented / supporting | physical-open |
| `recursive-splits` | Recursive split tree and pane lifecycle | GTK split tree, ratio policy, native smoke | Bounded workspace tree, ratio policy, ConPTY per pane, Wine controls | implemented / supporting | physical-open |
| `focus` | Keyboard, pointer, active pane/tab transitions | GTK focus bridge and shortcut lanes | Win32 message routing, tab focus, pane selection policy | implemented / supporting | physical-open |
| `selection-scrolling` | Selection, clipboard, mouse reporting, scrolling | GTK selection and clipboard runtime smoke | Win32 Unicode selection, clipboard, mouse policy and policy tests | implemented / supporting | physical-open |
| `profiles` | Built-in/custom launch profiles and environment | Zig profile model and PTY launch | Native profile dialog, NWS5 persistence, launch-plan and Wine evidence | implemented / supporting | physical-open |
| `themes` | Theme selection, import/export, persistence | GTK theme library and source import smoke | Native picker, transactional source imports, file-backed and Wine evidence | implemented / supporting | physical-open |
| `persistence` | Workspace save/restore and identity recovery | Autosave/workspace snapshots and runtime smoke | Versioned NWS5 tab/split/profile envelope and policy tests | implemented / supporting | physical-open |
| `smart-tabs` | Tags, filters, empty-state recovery | GTK tag/filter bridge and maintained smoke | Win32 tag filters and Ctrl+Alt+Space entry point | implemented / supporting | physical-open |
| `dropdown-hotkey` | Dropdown presentation and global-hotkey behavior | Plasma/Noctalia presentation and shortcut proof | Win32 visibility toggle and menu state | implemented / supporting | physical-open |
| `nocted` | Native editor handoff, tabs, search, persistence | Zig NoctEd host and project smoke | Separate `nocted.exe`, Win32 host and qualification harness | implemented / supporting | physical-open |
| `sharing` | Pairing, discovery, remote view, permissions | Native sharing and Linux runtime lanes | Native pairing dialog, GDI remote view, host-approved input | implemented / supporting | external-open + physical-open |
| `status-strip` | Compact context footer for mode/tab/pane/profile | Existing native workspace information strip | New DPI-aware GDI footer reserves terminal height and reports mode, tab, pane, profile | implemented | physical-open |

## Receipt contract

The source-tree check is deliberately narrow. Run:

```sh
./scripts/check_windows_linux_parity.sh
```

It emits the locked commit, row count, and open physical/external gates. A
future physical receipt must additionally identify the same commit, exact
package/archive digests, supported-host versions, exercised capabilities, and
explicit skips/failures. The local ztash package path is build-only and reports
`remote_deployment=not_performed`; it is not a Windows host or cross-machine
receipt.

The matrix does not close NCT-127 by itself. The remaining acceptance work is
real supported-Windows 10/11 execution with ConPTY and physical input, then
real Linux↔Windows sharing over the intended network boundary. Release signing,
publication, redistribution review, compositor acceptance, and consented HID
remain separate Release Operations gates.
