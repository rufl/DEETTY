# NOCTTY Backlog

Last refreshed: 2026-08-29.

## Source Of Truth Policy

Only incomplete accepted work lives here. `[status:yellow]` is locally evidenced but not closed; `[truth:*]` names that evidence. Archive completed or retired work.

## Completion Index

| ID | Open boundary |
|---|---|
| NCT-112 | Multi-day terminal stability |
| NCT-123 | Experimental Windows host parity and physical qualification |
| NCT-125 | Current-build dogfood defect recapture |
| NCT-126 | First-party native-adapter migration to Zig |
| Release operations | Signed artifacts, publication, independent redistribution review, compositor and HID acceptance |

## Active

### NCT-112 Terminal stability and agent-resource qualification — partial

- [ ] [status:yellow] Complete the retained 48-hour `ReleaseSafe` Wayland/X11 hidden/visible matrix. The mode-40 runner, exact phase/resource receipts, 64 MiB root-growth guard, compositor capture, and four-lane Debug/`ReleaseSafe` shakedown pass; elapsed authenticated execution remains open. `[truth:test,measurement]`

Focused receipts and proof boundaries live in `docs/TECHNICAL_STATUS.md`,
`docs/RELEASE_CHECKLIST.md`, and the linked qualification records.

### NCT-125 Current-build dogfood defect recapture — partial

- [ ] [status:yellow] Retain a clean two-hour Plasma Wayland session on the
  current installed dogfood build that uses Codex scrollbar wheel/drag
  navigation, opens and closes native menus/dialogs, exercises Project / NoctEd
  once, and exits both NOCTTY and NoctEd normally. The source
  slice fixes the Codex mouse-mode scrollbar priority, bounds project refresh
  to its visible GUI, owns sharing refresh timers, rejects retired menu
  contexts, anchors popups to the top-level surface, makes NoctEd teardown
  idempotent, and separates recoverable persistence failures from hard model
  synchronization failures. A follow-on source/behavior audit bounded theme
  imports, made workspace and theme failures visible and retryable, refreshed
  live theme controls, restored two-axis narrow Settings access, gave every
  tab/file close control a contextual accessible name, removed duplicate split
  resize work, and isolated the legacy X11 fallback's runtime sockets. The
  final contained pass makes `Open NoctEd Here` use the selected pane as its
  process cwd, closes bounded-theme-read races, propagates durable
  profile and active-theme save failures, prevents failed Quick Note reads from
  overwriting state, announces dynamic failures to assistive technology, and
  bounds compact transient surfaces to the active monitor. The
  subsequent low-effort audit labels workspace-restore, encrypted-history,
  agent-resume, and sharing form controls for assistive technology; announces
  sharing plus NoctEd find/project-search/Quick Open/main-status changes as
  native status or alert events; labels tab-rename, workspace-tag,
  Noctalia-import, and NoctEd language-service controls; safely copies tag text
  before trimming; suppresses unchanged timed announcements; and prevents the
  sharing preview from forcing a 480x260 minimum beyond a compact work area.
  The focused sharing follow-through also makes stopped/failed roles clearable,
  disables impossible actions, confirms and hides revoked peers, exposes
  retryable paired-device persistence failures, reclaims revoked capacity only
  when the bounded store is full, stops every network role when the only
  sharing surface closes, bounds listener cancellation polling, and retains
  explicit remote input/paste failure feedback with a 64 KiB paste ceiling.
  Both smoke binaries and the
  native source contract compile/pass. The focused mapped sharing proof failed
  closed first at a read-only shared-runner lock and then at sandbox-denied
  private D-Bus socket creation, so it adds no mapped visual evidence. The
  initial aggregate check passed 418/418; the
  final current-source run passed 411 tests, skipped one, and failed only six
  loopback-sharing tests because this sandbox denies socket creation. Fresh
  production NOCTTY plus both smoke binaries compile. The focused graphical
  scrollbar proof correctly failed closed because this sandbox could not create
  the private display namespace. The current visual-flow audit likewise stopped
  at sandbox-denied private D-Bus socket creation and did not touch the active
  desktop; a later 520x420 compact run deferred fail-closed at the isolated
  runner's I/O pressure gate. A 2026-09-02 installed-log follow-through closes
  the recurring Wayland non-topmost popup-parent warning by clearing stale
  process-local popups before opening terminal/tab menus and makes that exact
  warning fail clean-log qualification. Repeat installation now also reuses a
  previously staged GTK Layer Shell runtime only when it matches the prior
  private build receipt; the current `ReleaseFast` dogfood install completed
  through that fail-closed path. The launcher smoke and isolated Wayland
  tab/profile menu lanes pass without the popup-parent warning. The retained
  2026-07-19 alpha screenshots now have an explicit stale
  boundary; recapture them inside the installed-session qualification. A real
  installed-session recapture remains
  required before closing the historical
  descriptor, GTK-critical, and exit-139 observations. `[truth:build,logs,docs]`

### NCT-123 Experimental Windows host — partial

- [ ] [status:yellow] Physically qualify the x86_64 Win32/GDI + ConPTY host on
  Windows 10/11. The source tranche now cross-compiles without GTK, owns bounded
  tabs/splits and per-pane ConPTY/VT state, supports native selection and DEC
  mouse reporting, ships the separate native NoctEd editor, and produces a
  reproducible per-user NSIS installer with reversible shortcuts/Open-With
  registration and an operator-owned signing hook. A checksum-bound dogfood ZIP
  is discoverable through PI WEB QOL's existing token-scoped artifact service;
  its PowerShell installer verifies the payload, runs both installed self-tests,
  and retains a local receipt. Wine-hosted self-tests and installer lifecycle
  smoke pass, but Wine does not prove physical ConPTY/GDI, input, installer, or
  editor behavior on supported Windows releases.
  `[truth:build,test,docs]`

### NCT-126 First-party native-adapter migration to Zig — partial

- [ ] [status:yellow] Move first-party platform behavior into Zig without
  replacing stable, focused native qualifications with percentage-driven
  rewrites. Session-sharing sockets, Windows DPAPI/state persistence, the
  pinned offline Unicode generator, and the complete Windows NoctEd model plus
  Win32 controls/message-loop host are now Zig-owned. They retain Linux
  loopback/discovery plus generator tests and Windows `ReleaseSafe`
  cross-compilation. A dedicated isolated Wine controls/message-loop smoke is
  present; it exposed and closed a pseudo-HMENU alignment panic, then passed
  post-fix mapped control/message-loop runs in isolated Wine for Debug and
  `ReleaseSafe`. Remaining C translation units are the GTK
  native-grid adapter and the experimental Win32 terminal host. The latter now
  delegates geometry, pointer cells, selection, color conversion, grid sizing,
  special keys, and UTF-16 assembly to tested Zig exports. Zig also owns ConPTY
  pipes/process/thread teardown, the bounded output ring, Unicode clipboard
  memory, sibling-process launch, native-menu construction/state, DPI-aware GDI
  fonts/metrics, preference normalization, bounded window titles, the complete
  double-buffered GDI terminal renderer, local logs, and minidumps. C still
  owns timer objects, input/workspace-session orchestration,
  command/window-message dispatch, and the main HWND. The GTK adapter now
  delegates scrollbar geometry, wheel accumulation, keyboard scroll targets,
  grid sizing/auto-fit, window-resize deltas/bounds, pointer-to-cell mapping,
  linear selection hit testing, and pixel-snapped spans to tested Zig policy.
  Migrate those incrementally behind their existing ABI contracts; keep
  generated vendored Tree-sitter parsers, system headers, and display-isolation
  shell orchestration outside the source-percentage target. Physical Windows
  behavior, a current-source mapped Wine rerun, and isolated mapped GTK proof
  remain required before retiring each
  adapter. `[truth:build,test,docs]`

## Release Operations

- [ ] [status:yellow] Retain both architecture artifacts/signatures, publication, independent dependency-bundle redistribution review and receipts, final compositor acceptance, and consented Wayland HID capture. The NCT-077 follow-through is locally closed; external evidence remains operator-owned. `[truth:build,docs,external]`
