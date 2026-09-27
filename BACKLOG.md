# NOCTTY Backlog

Last refreshed: 2026-09-26.

## Source Of Truth Policy

Only incomplete accepted work lives here. `[status:yellow]` is locally evidenced but not closed; `[truth:*]` names that evidence. Archive completed or retired work.

## Priority and Completion Index

- **P1 — public-alpha/dogfood:** current-build evidence and reproduced blockers
  only.
- **P2 — post-alpha:** architecture migration, physical-platform proof, and
  long-duration stability work.
- **P3 — release operations:** signing, publication, redistribution review, and
  final operator acceptance.

| Tier | Bundle | Executable boundary |
|---|---|---|
| P1 | NCT-125 current-build dogfood defect recapture | Blocked on operator evidence: retain the clean installed two-hour session; source work alone cannot close it. |
| P2 | NCT-112 terminal stability and agent-resource qualification | Blocked on elapsed evidence: retain the uninterrupted 48-hour run. |
| P2 | NCT-123 experimental Windows host | Blocked on physical/operator evidence: qualify the packaged host on supported Windows systems. |
| P2 | NCT-126 first-party native-adapter migration | Source-ready incremental migration plus mapped/physical retirement gates. |
| P2 | NCT-127 shared native behavior and Windows feature parity | Share toolkit-neutral libraries while adding native Windows workspace controls and preserving Linux behavior. |
| P3 | Release Operations | Operator/external evidence owns signing, publication, redistribution review, compositor, and consented HID acceptance. |

Every open bundle is listed once above. Source-ready work is locally executable;
elapsed, physical, and operator evidence is not implied by source completion.

## Active

### P1 — Public-alpha/dogfood

#### NCT-125 Current-build dogfood defect recapture — partial

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
  tab/profile menu lanes pass without the popup-parent warning. Current
  `ReleaseSafe` installed-tree alpha screenshots were recaptured inside the
  repository's private display/session boundary. Seven operator-confirmed
  installed sessions now contribute 167.107 counted hours, closing the minimum
  session-count baseline. NCT-125 remains open for the specified clean
  current-build workflow recapture after the historical descriptor,
  GTK-critical, and exit-139 observations.
  `[truth:build,logs,docs]`

### P2 — Post-alpha architecture, physical proof, and stability

#### NCT-112 Terminal stability and agent-resource qualification — partial

- [ ] [status:yellow] Complete the retained 48-hour `ReleaseSafe` Wayland/X11 hidden/visible matrix. The mode-40 runner, exact phase/resource receipts, 64 MiB root-growth guard, compositor capture, and four-lane Debug/`ReleaseSafe` shakedown pass; elapsed authenticated execution remains open. `[truth:test,measurement]`

Focused receipts and proof boundaries live in `docs/TECHNICAL_STATUS.md`,
`docs/RELEASE_CHECKLIST.md`, and the linked qualification records.

#### NCT-123 Experimental Windows host — partial

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

#### NCT-126 First-party native-adapter migration to Zig — partial

- [ ] [status:yellow] Move first-party platform behavior into Zig without
  replacing stable, focused native qualifications with percentage-driven
  rewrites. Session-sharing sockets, Windows DPAPI/state persistence, the
  pinned offline Unicode generator, and the complete Windows NoctEd model plus
  Win32 controls/message-loop host are now Zig-owned. They retain Linux
  loopback/discovery plus generator tests and Windows `ReleaseSafe`
  cross-compilation. A dedicated isolated Wine controls/message-loop smoke is
  present; it exposed and closed a pseudo-HMENU alignment panic, then passed
  post-fix mapped control/message-loop runs in isolated Wine for Debug and
  `ReleaseSafe`. The experimental Win32 terminal host is now fully Zig-owned:
  `WindowsHost.zig` owns the main HWND, timers, hit testing, focus/capture,
  input, workspace-session orchestration, and command/message dispatch alongside
  the existing Zig ConPTY, rendering, clipboard, menu, font, title, diagnostics,
  and persistence modules. Its former C translation unit and private header are
  retired. The only remaining first-party C translation unit is the GTK
  native-grid adapter. Core first-party ownership now exceeds the 80% Zig
  target. The adapter delegates bounded UI text validation, GTK modifier-mask
  translation and Alt/Meta key detection, input-routing precedence, keyboard
  navigation planning, tab/pane cycle targets, directional focus scoring,
  tray-menu ID, label, and icon policy, resize-cursor orientation, resize-edge
  ordinals, handle-index normalization, resize-handle grid layout,
  pane-divider snap points, active-pane render selection, status labels, profile
  preset labels, broadcast menu labels, shortcut identities, command-palette
  action IDs/labels/hints, workspace color-editor labels/roles, scrollbar
  geometry and press/drag planning, wheel accumulation, scroll targets,
  font/cell metric conversion, grid sizing/auto-fit, window-resize
  deltas/bounds, pointer-to-cell mapping, linear selection hit testing,
  pixel-snapped row/cell
  damage spans, Paseo Black Zinc theme colors, compact tab/new-tab/window-
  toolbar construction, bracketed-paste markers, sharing-preview control-key
  and editing/function-key sequences, text-prefix buffering, arrow-sequence
  formatting, paste-limit/chunk sizing, sharing-preview scroll mapping,
  selection-index parsing/formatting, normalized pane hit testing, theme-color
  channel extraction/clamping/rounding/hex formatting, and the Cairo/Pango
  cell, glyph, overlay, scrollbar, and sharing preview pipeline to Zig.
  The adapter also now delegates panel-layout spacing, bounded allocation
  resizing, notebook-chrome visibility, and terminal-status activation policy
  through the same Zig ABI.
  Shared terminal-status color-role, fallback, and idle-muted policy now also
  crosses that ABI.
  Compact-tab extent and close/action sizing arithmetic now follows the same
  split: Zig owns the calculation while GTK retains allocation queries and
  native eligibility checks.
  Dirty-row/span capacity normalization and selection-copy buffer growth
  bounds now follow the same Zig-policy/native-allocation split.
  Smart Tab visibility, focus-first, and empty-filter decisions now also cross
  the Zig ABI; GTK retains widget visibility, focus, and empty-state effects.
  GTK accessibility range clamping, character-offset validity, and ATK
  granularity expansion now cross the Zig ABI; C retains UTF-8 pointer
  conversion, returned-text allocation, and native ATK effects.
  Startup visibility, activation-application, native-smoke scheduling,
  accessible text-buffer normalization, session-sharing status text/error
  classification, compact-tab text/markup policy, pane-status tooltip
  composition, and recovery-notice message policy now also cross the Zig ABI;
  C retains GTK/GString effects, title/tag acquisition, discovery-field
  updates, InfoBar construction, smoke callback dispatch, and lifecycle
  ownership.
  Output-presentation tick-versus-timeout selection now also crosses the Zig
  ABI; C retains GTK source registration, callback dispatch, and terminal
  pump effects.
  Continue migrating that adapter incrementally behind its existing ABI
  contracts; keep generated vendored Tree-sitter parsers, system headers, and
  display-isolation shell orchestration outside the source-percentage target.
  The isolated mapped GTK proof now passes in Debug presentation mode and
  ReleaseSafe full-stack mode under both private X11 and private Wayland
  sessions; physical Windows behavior remains a separate required acceptance
  boundary. `[truth:build,test,docs,external]`

##### NCT-126 fixed definition of done

NCT-126 closes only when every gate below is evidenced against one locked
source tree. Once closed, no further percentage-driven GTK rewrites are part
of this item.

1. **Scope lock:** record the final source-tree commit and the counted
   ownership inventory. Count only first-party `src/` and `include/noctty/`
   policy code; keep generated/vendor code, system headers, and display
   orchestration excluded exactly as documented.
2. **Ownership target:** the locked inventory reports at least 90.00% Zig
   ownership using the repository checker, with the denominator and output
   retained in the qualification record.
3. **GTK query/effect boundary:** every remaining C function in the GTK
   adapter is classified as either (a) native object query/effect or
   lifetime glue, or (b) migrated policy. There are no unclassified policy
   branches, calculations, clamps, labels, schedules, or state transitions.
4. **Smoke/qualification boundary:** all native-grid smoke scenarios
   registered in the locked source tree, including the Zig-owned schedule plan
   and qualification callbacks, pass through the repository's isolated private
   X11 and private Wayland runners. No run may use the active display, session
   bus, or host input devices.
5. **Text/render boundary:** C retains only GTK/ATK/Cairo/Pango object access,
   allocation, signal, drawing, and lifetime effects; Zig owns the remaining
   text/render policy. Focused accessibility and renderer checks pass.
6. **Reproducible verification:** the current tree passes the focused native
   build/test command, the ownership checker, documentation truth checks, and
   whitespace checks. The qualification record includes exact commands,
   receipts, and failures; private build caches and temporary outputs are
   removed; the worktree is clean.
7. **Boundary accounting:** physical Windows qualification, the 48-hour
   stability run, the two-hour installed dogfood run, and release operations
   remain NCT-123/NCT-127, NCT-112, NCT-125, and Release Operations gates.
   They cannot expand NCT-126 after this scope lock.

The three remaining implementation items are therefore closed by gates 3–5;
gates 1, 2, and 6 close the bundle. Gate 7 prevents unrelated external work
from making this migration indefinite.

Current locked-tree evidence (2026-09-27) reports `82.28%` Zig ownership
(`zig_lines=88303`, `adapter_lines=19008`) against the strict `90.00%`
target. Direct Debug and `ReleaseSafe` renderer qualifications pass with
byte-identical fixtures and zero warm-frame allocations; the isolated mapped
GTK runner remains deferred by host I/O pressure (`exit=75`), so NCT-126 is
not closed.

#### NCT-127 Shared native behavior and Windows feature parity — partial

- [ ] [status:yellow] Qualify the new Windows Workspace/Terminal menus against
  real ConPTY shells and remote input permissions on supported Windows.
  Shared key encoding, native menu construction, guarded command dispatch,
  and the local Ctrl+Shift+Tab fix are implemented; cross-build and focused
  byte-level regressions do not establish physical Windows acceptance.
  `[truth:build,test,docs,external]`
- [ ] [status:yellow] Qualify the native Windows tab strip with supported-Windows
  input, DPI, high contrast, and live ConPTY sessions. Selection, bounded Unicode
  rename, and left/right ordering are implemented; focused model tests cover
  pane identity, close/reuse, and legacy/new saved-state compatibility.
  Captured drag reorder with insertion feedback and stale-identity guards is
  implemented; the isolated native controls qualification now passes.
  `[truth:build,test,docs,external]`
- [ ] [status:yellow] Qualify Windows divider capture/cancellation, menu resizing,
  and saved proportional layouts against live ConPTY sessions. Shared ratio
  math now serves GTK and Windows; native drag preview and keyboard/menu
  adjustment preserve the existing bounded tree and pane identities.
  `[truth:build,test,docs,external]`
- [ ] [status:yellow] Qualify the implemented Windows launch-profile library on
  supported Windows with live ConPTY sessions. Native create/edit/rename/delete,
  selection, atomic persistence, and executable/arguments/directory/environment/
  scrollback handling are implemented. Isolated Wine covers native controls and
  real child-process delivery without ConPTY; file-backed rollback and shared
  POSIX configuration compatibility pass. `[truth:build,test,docs,external]`
- [ ] [status:yellow] Add native source-format theme imports for Ghostty,
  Xresources, Alacritty, and Noctalia. Windows now accepts those source
  extensions through its native picker and converts each source transactionally
  into one custom theme; focused parser coverage and native-source qualification
  remain.
- [ ] [status:yellow] Qualify custom theme selection/import/export, replacement
  confirmation, persistence errors, and tab dragging on supported Windows with
  real sessions, DPI changes, and assistive technology. The focused policy
  group, file-backed interoperability smoke, GTK theme flow, and isolated
  Wine control/bitmap qualification pass. `[truth:build,test,docs,external]`
- [ ] [status:yellow] Complete remaining native Windows workspace parity:
  Smart Tabs, dropdown/global-hotkey behavior, and workspace continuity.
  Broadcast input now has guarded native menu/shortcut dispatch and live-pane
  fan-out; physical/operator qualification remains.
  Startup restoration failures for persisted Windows workspace, theme, and
  launch-profile state now surface an actionable recovery message instead of
  silently falling back.
- [ ] Continue replacing GTK C ownership with cohesive Zig components toward
  90% without counting file moves, duplicate implementations, or unrelated new
  code as architectural progress. Retain focused Linux runtime proof and
  supported-Windows acceptance for each migrated behavior.

### P3 — Release operations

#### Release Operations

- [ ] [status:yellow] Retain both architecture artifacts/signatures, publication, independent dependency-bundle redistribution review and receipts, final compositor acceptance, and consented Wayland HID capture. The NCT-077 follow-through is locally closed; external evidence remains operator-owned. `[truth:build,docs,external]`

<!-- OVERZEER:DOCS_BACKLOG_BEGIN -->
## OVERZEER project summary
- Git evidence in selected window: `77` commit(s).
- Documentation evidence: authored open tasks below; generated text is a proposal and does not mark work complete.
- [ ] [status:yellow] Retain a clean two-hour Plasma Wayland session on the
- [ ] [status:yellow] Complete the retained 48-hour `ReleaseSafe` Wayland/X11 hidden/visible matrix. The mode-40 runner, exact phase/resource receipts, 64 MiB root-growth guard, compositor capture, and four-lane Debug/`ReleaseSafe` shakedown pass; elapsed authenticated execution remains open. `[truth:test,measurement]`
- [ ] [status:yellow] Physically qualify the x86_64 Win32/GDI + ConPTY host on
- [ ] [status:yellow] Move first-party platform behavior into Zig without
- [ ] [status:yellow] Qualify the new Windows Workspace/Terminal menus against
- [ ] [status:yellow] Qualify the native Windows tab strip with supported-Windows
- [ ] [status:yellow] Qualify Windows divider capture/cancellation, menu resizing,
- [ ] [status:yellow] Qualify the implemented Windows launch-profile library on
- [ ] [status:yellow] Add native source-format theme imports for Ghostty,
- [ ] [status:yellow] Qualify custom theme selection/import/export, replacement
- [ ] [status:yellow] Complete remaining native Windows workspace parity:
- [ ] Add native graphical paired-device/session-sharing controls over the
- [ ] Continue replacing GTK C ownership with cohesive Zig components toward
- [ ] [status:yellow] Retain both architecture artifacts/signatures, publication, independent dependency-bundle redistribution review and receipts, final compositor acceptance, and consented Wayland HID capture. The NCT-077 follow-through is locally closed; external evidence remains operator-owned. `[truth:build,docs,external]`
<!-- OVERZEER:DOCS_BACKLOG_END -->
