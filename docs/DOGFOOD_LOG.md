# NOCTTY Dogfood Log

Use this file to record real daily-driver sessions before public alpha. Keep it
honest: failures and annoyances are useful. Session rules live in
[`DOGFOOD_RUNBOOK.md`](DOGFOOD_RUNBOOK.md).

## Session template

```markdown
## YYYY-MM-DD — session title

- Duration:
- Dogfood receipt: `noctty-YYYYMMDD-HHMMSS-PID`
- Desktop/session: Plasma Wayland / Plasma X11 / other
- NOCTTY command:
- Work performed:
- Panes/tabs used:
- Agent/TUI apps used:
- NoctEd used: yes/no; for what files?


### What worked

-

### Problems

- [ ] P0/P1/P2: description, reproduction, expected behavior

### Resource notes

- CPU/memory observation if measured:
- Any visible jank/hangs:

### Follow-up

-
```

Multi-OMP evidence is not entered as manual `pass`/`fail` fields. The installed
launcher and native host write local `dogfood_event` records while the actions
occur; `./scripts/dogfood_status.sh` extracts and fail-closes the qualification
from those process logs. See `docs/DOGFOOD_LOGGING.md` for the event contract
and `docs/DOGFOOD_RUNBOOK.md` for the exact preflight.

## Alpha dogfood checklist

- [x] Five sessions of at least two hours each
- [ ] One session with four or more panes/tabs
- [x] One Pi/Codex/Claude/agent CLI session inside NOCTTY
- [ ] Hide/show tested during real work
- [ ] close confirmation tested with foreground job
- [ ] hot-session restore tested after normal exit
- [ ] copy/paste/search/scrollback used during real work
- [ ] NoctEd used for real project edits in at least three sessions
- [ ] One complete current-version four-session OMP compatibility preflight

## Host runtime evidence snapshot — 2026-08-14

`./scripts/dogfood_runtime_status.sh --list-candidates` inspected retained
installed-launcher receipts and legacy logs on host `chopper`:

- NOCTTY: 21 finished launches, one incomplete launch, 31,598 observed seconds
  (8.777 hours), including one 16,077-second (4.466-hour) two-hour candidate
- NoctEd: 22 finished launches, 11,003 observed seconds (3.056 hours), with no
  two-hour candidate
- NOCTTY and NoctEd hours may overlap and are not summed
- these totals prove retained process runtime only; they do not prove primary
  terminal use, pane count, agent use, editor actions, or other dogfood quota
  criteria

## Reliability remediation snapshot — 2026-08-29

The current audit inspected all retained launcher receipts and failure logs on
host `chopper`:

- NOCTTY: 106 observed launches, 98 finished, eight incomplete, seven failed,
  75,401 seconds / 20.945 runtime-only hours
- NoctEd: 80 observed launches, 75 finished, five incomplete, two failed,
  29,094 seconds / 8.082 runtime-only hours
- one clean 2.699-hour NOCTTY runtime candidate and one clean 3.203-hour NoctEd
  runtime candidate exist, but neither is counted without the required work
  context in this log.
- The 2026-09-06 operator reconciliation under **Sessions** supersedes this
  historical NOCTTY count classification, not the retained defect facts.
- five retained NOCTTY failures ended in descriptor exhaustion/display flush
  failure; separate retained logs exposed popup-parent warnings, stale-widget
  draw criticals, one exit 139, and one `NativeGridStateSyncFailed`
- retained NoctEd failures exposed `gtk_main_quit` outside a live main loop and
  later notebook work after teardown
- live Codex dogfood exposed a visible scrollbar whose wheel path was shadowed
  by terminal mouse reporting

The 2026-08-29 source slice fixes the reproducible event-order and lifecycle
defects: the native scrollbar owns its rail before TUI mouse reporting;
terminal-only sessions stop launching periodic git subprocesses; project data
refreshes on demand; popup/menu contexts and sharing timers are ownership
guarded; recoverable persistence errors no longer poison normal exit as a hard
model-sync failure; and NoctEd destruction is idempotent and main-loop guarded.
An initial aggregate check passed all 418 tests. After the final patch, the
current-source rerun passed 411 tests, skipped one, and failed only the six
loopback-sharing cases for sandbox-denied socket creation; fresh production
NOCTTY and both smoke binaries compile. The focused graphical proof was not
executed because the managed sandbox could not create the fail-closed private
display namespace. These are local source/build facts, not a clean multi-hour
runtime receipt. NCT-125 remains open until a newly installed build completes
the two-hour recapture without descriptor, GTK-critical, or nonzero-exit
markers.

A follow-on low-risk source/behavior audit on the same date closed additional
error and compact-UI gaps. Recoverable user actions no longer set the hard
model-sync failure bit; immediate hot-session persistence returns its true
status; workspace save/open failures display a retryable dialog; and theme
imports require bounded regular nonempty files, publish status, refresh open
selectors, and queue a live redraw. Narrow Settings content can scroll on both
axes, terminal and NoctEd tab close controls expose the exact target to
assistive technology, and split creation avoids a duplicate resize request.
The reviewed legacy X11 runner now owns a private `XDG_RUNTIME_DIR`. Focused
source contracts, formatting, static C analysis, seven theme tests, and fresh
NOCTTY/NoctEd compilation pass. A current screenshot/interaction audit remains
unavailable here because the managed sandbox denies the private D-Bus socket;
the runner failed closed and did not contact the active desktop. This is still
not counted runtime evidence.

The final contained pass fixes the discovered `Open NoctEd Here` mismatch by
using the selected pane directory as the child process cwd while retaining
NoctEd's explicit-project/no-scan policy. Theme reads now recheck their bound
after loading, profile/theme actions distinguish config-write failure, Quick
Note cannot overwrite a note after a failed read, dynamic note/theme failures
publish ATK alerts, and failed agent-reference clearing is visible. Find,
Quick Note, shortcut help, and the command palette now derive bounded geometry
from the active monitor; narrow find and command content stacks vertically.
The smoke binary and source contract pass. A focused 520x420 compact run used
only the reviewed isolated-display wrapper and deferred fail-closed at its I/O
pressure gate (`I/O full PSI=31.28%`); it did not contact the active desktop and
does not add mapped or runtime evidence.

A final low-effort UI/accessibility sweep labels the workspace restore mode,
encrypted-history password, agent-resume fields, and session-sharing form for
assistive technology. Sharing and NoctEd's main/find/project-search/Quick Open
status changes now emit native ATK status or alert notifications, and the
sharing preview request follows the bounded dialog work area instead of forcing
480x260 logical pixels. Inline tab rename, workspace-tag, Noctalia-import, and
NoctEd language-service inputs are explicitly named as well; tag trimming no
longer modifies GTK's borrowed text, and unchanged timed sharing state does not
repeat announcements. Fresh NOCTTY and NoctEd smoke binaries plus the native
source contract pass. The focused sharing-scope run failed closed before GTK
mapping because the shared runner lock was read-only in this sandbox and its
private legacy fallback could not bind a D-Bus socket. No active display was
contacted, and this is source/build evidence rather than a counted dogfood
session or current screenshot.

The next source/state-machine sharing pass found and fixed recovery defects that
the blocked visual lane could not expose: stopped/failed host and viewer objects
had no enabled clear action, revoked records stayed selectable, persistence
errors vanished on the next 200 ms refresh, closing the dialog left network
roles alive, and a listening pairing worker depended on cross-thread close of a
blocking accept. Terminal states are now clearable, action availability follows
the actual role, revocation is confirmed and removed from actionable choices,
paired-device saves can be retried, dialog close stops all sharing roles, and
listener cancellation polls in bounded intervals. Input/paste failure feedback
is retained for three seconds; remote paste is capped at 64 KiB and attempts a
bracket terminator after partial failure. Three identity-store tests, both
native platform compiles used by this slice, Zig formatting, and the source
contract pass. The focused cancel regression is retained in the repository test
graph, but its ad hoc test executable could not link against this host's
`.sframe` CRT and was not executed; the earlier isolated mapped-flow
blocker remains. This entry therefore
adds no screenshot, compositor, physical network, or screen-reader receipt.

## Reliability follow-through — 2026-09-02

The latest retained installed Wayland logs exposed one source defect not closed
by the 2026-08-29 pass: terminal and tab menus repeatedly attempted to map
against the main toplevel while an older process-local popup remained at the
head of GTK's Wayland popup stack. Those logs also contain selection-transfer
broken-pipe warnings when an external clipboard consumer closes its request;
the GTK-owned cancellation does not alter NOCTTY state and remains outside the
hard-failure marker set.

The current source dismisses stale process-local popup windows before opening a
terminal or tab menu. The logging launcher now counts the exact
`Tried to map a popup with a non-top most parent` warning and rejects it from a
clean multi-OMP receipt. The focused logging smoke passes, and isolated Wayland
tab-color plus profile-submenu lanes complete without that warning.

The same install attempt found that a dogfood refresh failed after the system
GTK Layer Shell package had been removed even though the previous installer
retained the provenance-checked runtime and its SHA-256. Refresh now preflights
and accepts only that private library when it still matches the previous `0600`
build receipt; a missing or changed file fails before installed files are
replaced. The launcher also bypasses receipt creation for NoctEd `--version`,
matching its existing NOCTTY version behavior and documentation. The current
`ReleaseFast` dogfood install completed through this retained-runtime path. A
fresh two-hour
installed session is still required; source, smoke, and installation results do
not close NCT-125 by themselves.

## Sessions

The operator reconfirmed on 2026-09-06 that the seven retained two-hour NOCTTY
candidates below were real installed daily-terminal dogfood, not smoke or
screenshot runs. The receipts contribute 601,585 seconds / 167.107 hours across
seven unique launcher sessions. Shell commands and terminal contents were
intentionally not logged. Six sessions exited zero; the nonzero exit and
warning-bearing sessions remain documented rather than being silently excluded.
Separate NoctEd runtime may overlap and is not added to the NOCTTY total.

## 2026-09-03 — 60.152-hour installed NOCTTY dogfood session

- Duration: 216,547 seconds / 60.152 hours
- Dogfood receipt: `noctty-20260903-162027-752716`
- Desktop/session: Niri / Wayland
- NOCTTY command: installed launcher with `--toggle`
- Work performed: operator-confirmed real daily terminal work; terminal content was intentionally not retained
- Panes/tabs used: at least one instrumented pane; exact peak was not retained
- Agent/TUI apps used: OMP 18.1.11, with native detection and independent-input evidence
- NoctEd used: yes; the overlapping finished NoctEd receipt retained 6.478 hours on a configuration file

### What worked

- The installed host remained available across 60.152 hours and exited zero.
- Retained timestamps show repeated popup, selection-transfer, and final OMP interaction rather than an untouched launch.

### Problems

- [x] P2 historical popup-parent and external clipboard-consumer warnings were
  retained. Current source dismisses stale popups; clipboard broken-pipe
  cancellation is nondestructive. The warning-bearing OMP log review correctly
  remains ineligible for the separate multi-OMP qualification.

## 2026-09-03 — 3.322-hour installed NOCTTY dogfood session

- Duration: 11,961 seconds / 3.322 hours
- Dogfood receipt: `noctty-20260903-125659-3575`
- Desktop/session: Niri / Wayland
- NOCTTY command: installed launcher with `--hidden`
- Work performed: operator-confirmed real daily terminal work; terminal content was intentionally not retained
- Panes/tabs used: not instrumented
- Agent/TUI apps used: not instrumented
- NoctEd used: no linked editor receipt

### What worked

- The installed host completed more than three hours of use and exited zero.

### Problems

- [x] P1 historical tab-label ownership failure emitted three GTK criticals.
  The source correction is retained, while NCT-125 still requires a clean
  current-build workflow recapture rather than reclassifying this old run.

## 2026-09-02 — 10.856-hour installed NOCTTY dogfood session

- Duration: 39,081 seconds / 10.856 hours
- Dogfood receipt: `noctty-20260902-135507-18289`
- Desktop/session: Niri / Wayland
- NOCTTY command: installed launcher with `--hidden`
- Work performed: operator-confirmed real daily terminal work; terminal content was intentionally not retained
- Panes/tabs used: not instrumented
- Agent/TUI apps used: not instrumented
- NoctEd used: no linked editor receipt

### What worked

- The installed host exited zero after 10.856 hours.
- The retained log contains no categorized warning, critical, native-grid failure, or panic marker.

### Problems

- None recorded in the retained launcher log.

## 2026-08-31 — 47.626-hour installed NOCTTY dogfood session

- Duration: 171,454 seconds / 47.626 hours
- Dogfood receipt: `noctty-20260831-111441-1690`
- Desktop/session: Niri / Wayland
- NOCTTY command: installed launcher with `--hidden`
- Work performed: operator-confirmed real daily terminal work; terminal content was intentionally not retained
- Panes/tabs used: not instrumented
- Agent/TUI apps used: not instrumented
- NoctEd used: no linked two-hour editor receipt

### What worked

- The installed host remained alive across two calendar days and exited zero.
- Retained popup and selection-transfer timestamps show interaction throughout the launcher span.

### Problems

- [x] P2 historical popup-parent and external clipboard-consumer warnings were
  retained and fed the later popup ownership hardening.

## 2026-08-30 — 2.222-hour installed NOCTTY dogfood session

- Duration: 7,998 seconds / 2.222 hours
- Dogfood receipt: `noctty-20260830-125425-2624493`
- Desktop/session: Niri / Wayland
- NOCTTY command: installed launcher with `--open-uri`
- Work performed: operator-confirmed real daily terminal work; terminal content was intentionally not retained
- Panes/tabs used: not instrumented
- Agent/TUI apps used: not instrumented
- NoctEd used: no linked editor receipt

### What worked

- The installed host exited zero after more than two hours.
- Retained popup and selection-transfer timestamps show active UI use.

### Problems

- [x] P2 historical popup-parent and external clipboard-consumer warnings were
  retained and fed the later popup ownership hardening.

## 2026-08-28 — 40.230-hour installed NOCTTY dogfood session

- Duration: 144,828 seconds / 40.230 hours
- Dogfood receipt: `noctty-20260828-204031-39059`
- Desktop/session: Niri / Wayland
- NOCTTY command: installed launcher with `--open-uri`
- Work performed: operator-confirmed real daily terminal work; terminal content was intentionally not retained
- Panes/tabs used: not instrumented
- Agent/TUI apps used: not instrumented
- NoctEd used: no linked two-hour editor receipt

### What worked

- The launcher retained a complete monotonic duration across two calendar days.
- Popup and selection-transfer timestamps show repeated interaction throughout the span.

### Problems

- [x] P1 historical process exit 139 after 40.230 hours. The associated
  lifecycle/descriptor fixes are retained; NCT-125 still requires a clean
  current-build workflow recapture.

## 2026-08-28 — 2.699-hour installed NOCTTY dogfood session

- Duration: 9,716 seconds / 2.699 hours
- Dogfood receipt: `noctty-20260828-115932-221925`
- Desktop/session: Niri / Wayland
- NOCTTY command: installed launcher with `--open-uri`
- Work performed: operator-confirmed real daily terminal work; terminal content was intentionally not retained
- Panes/tabs used: not instrumented
- Agent/TUI apps used: not instrumented
- NoctEd used: no linked editor receipt

### What worked

- The installed host exited zero after more than two hours.
- Popup and selection-transfer timestamps show active UI use.

### Problems

- [x] P2 historical popup-parent and external clipboard-consumer warnings were
  retained and fed the later popup ownership hardening.

## 2026-08-05 — retained 4.466-hour runtime candidate (not counted pending work-context confirmation)

- Duration: 16,077 seconds / 4.466 hours from launcher timestamps
- Dogfood receipt: `noctty-20260805-124514-2056382` (legacy log import)
- Desktop/session: Plasma Wayland
- NOCTTY command: installed launcher with `--open-uri`
- Work performed: not recoverable from process logging; primary-terminal use is unconfirmed
- Panes/tabs used: not recorded
- Agent/TUI apps used: not recorded
- NoctEd used: not linked to this runtime

### What worked

- The installed native host remained alive for more than the two-hour duration boundary.
- The launcher retained start/end timestamps, exit status, backend, and the terminal failure.

### Problems

- [ ] P1 candidate: after 4.466 hours the process logged `Too many open files`,
  failed a Wayland shared-memory pool request, and exited with status 1. Recheck
  on the current build before promoting this historical observation to an
  active blocker.

### Resource notes

- CPU/memory observation if measured: not measured.
- Any visible jank/hangs: not recorded before the final display failure.

### Follow-up

- Do not count this session unless the operator can confirm real work and the
  missing pane/agent/workflow fields.
- Use version-1 duration receipts for future sessions.

## 2026-07-19 — public-alpha repository prep (not counted toward dogfood quota)

- Duration: Pi-assisted prep session
- Desktop/session: not verified as a NOCTTY-hosted GUI dogfood session
- NOCTTY command: not launched for this entry
- Work performed: public-alpha documentation pass, source code map, screenshot capture automation, README screenshots, verification-status note
- Panes/tabs used: not measured
- Agent/TUI apps used: Pi coding-agent harness
- NoctEd used: no

### What worked

- The repository now has a public-readable alpha path and a contributor code map.
- The current verification uncertainty is recorded instead of being hidden.
- Automated screenshot capture produced real Plasma Wayland NOCTTY and NoctEd PNGs.

### Problems

- [ ] P1: Real NOCTTY/NoctEd dogfood sessions still need to be captured before counting alpha readiness as green.
- [x] P1: `zig build run-nocted -- --project . --open README.md` aborted in a worker because the project index path expected an absolute path. Fixed on 2026-07-19: NoctEd now resolves relative project/document CLI paths to absolute real paths before worker admission, and the relative launch was re-tested without panic/assertion.

### Resource notes

- CPU/memory observation if measured: not measured
- Any visible jank/hangs: not applicable

### Follow-up

- Run a real NOCTTY session and a real NoctEd edit/search/save session, then add the first counted dogfood entry below this one.
- Continue with a real counted NOCTTY + NoctEd dogfood session; the relative-path CLI assertion is fixed.

## 2026-07-19 — dogfood preflight smoke hardening (not counted toward dogfood quota)

- Duration: focused preflight slice
- Desktop/session: managed X11 and Wayland smoke backends
- NOCTTY command: `./scripts/native_grid_smoke.sh`
- Work performed: pre-dogfood native-grid smoke rerun before starting counted sessions
- Panes/tabs used: smoke fixture only
- Agent/TUI apps used: Pi coding-agent harness
- NoctEd used: smoke fixture only; `./scripts/nocted_native_smoke.sh` passed

### What worked

- NoctEd native smoke passed with project tree, search/load, quick open, Save As, session restore, recent project, and worker/lifecycle receipts.
- After fixture timing hardening, native-grid smoke passed on both X11 and Wayland with synchronized-output normal release and deadman release evidence.

### Problems

- [x] P1: `./scripts/native_grid_smoke.sh` initially failed because the synchronized-output smoke command's timing could miss either the normal DECSET 2026 release or the deadman release under current backend scheduling. Fixed by lengthening only the smoke fixture's synchronized-output windows; production behavior unchanged.

### Resource notes

- CPU/memory observation if measured: not measured beyond smoke receipts.
- Any visible jank/hangs: none observed by the smoke after the timing fix.

### Follow-up

- Start the first counted two-hour NOCTTY/NoctEd dogfood session.

_Add new counted entries here._
