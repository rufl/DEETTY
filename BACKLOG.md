# DEETTY Backlog

Last refreshed: 2026-10-12.

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
| P2 | NCT-128 NoctEd KOF4J tooling compatibility | Prove 100% project language, linter, and required LSP compatibility on the canonical KOF4J fixture. |
| P3 | Release Operations | Operator/external evidence owns signing, publication, redistribution review, compositor, and consented HID acceptance. |

Every open bundle is listed once above. Source-ready work is locally executable;
elapsed, physical, and operator evidence is not implied by source completion.

## Active

### P1 — Public-alpha/dogfood

#### NCT-125 Current-build dogfood defect recapture — partial

- [ ] [status:yellow] Retain a clean two-hour Plasma Wayland session on the
  current installed dogfood build that uses Codex scrollbar wheel/drag
  navigation, opens and closes native menus/dialogs, exercises Project / NoctEd
  once, and exits both DEETTY and NoctEd normally. The source
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
  production DEETTY plus both smoke binaries compile. The focused graphical
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
  Smart Tab text, cycle-feedback labels, tab-title fallback precedence,
  notification body composition, and pane-zoom feedback now cross the Zig ABI;
  C retains model/cwd acquisition and native presentation effects. Zoom
  enter/unzoom selection is also a Zig state plan; C retains visibility,
  notebook, focus, and resize effects.
  Settings shortcut button label and transport-specific tooltip composition now
  also cross the Zig ABI; C retains shortcut-key acquisition and GTK widget
  application.
  Note-overlay labels, window-title prefixes, close-confirmation title/detail/action
  copy, layout-preset title/detail/action copy, find-status text,
  keyboard-shortcuts text, and sharing peer/tab/pane labels now also cross the Zig
  ABI; C retains GTK allocation, dialog, combo-box, and terminal-model effects.
  Layout-preset event validation and rows/columns/target-count selection are
  also a tested Zig state plan; C retains pane enumeration, confirmations,
  session movement, and GTK layout effects.
  Settings-panel/background field normalization and layout-effect
  classification now cross a tested Zig state plan; C retains per-context
  state application, widget invalidation, and event emission.
  Launch-profile payload serialization, name validation, save-status messages,
  and Noctalia theme persistence-status composition now cross the Zig ABI; C
  retains GTK entry acquisition, text-action dispatch, and native status
  effects.
  The current source run passes all 141 Zig grid-logic tests and both Debug and
  `ReleaseSafe` builds. Settings, session-sharing, command-palette, terminal
  find, quick-note, theme-library, and project-workspace surfaces now share
  theme-aware groups, focus rings, action affordances, readable utility
  spacing, and accessible status/search roles. The counted Zig ownership
  inventory is 82.18%; the fixed 90.00% gate and isolated graphical proof
  remain open.
  The current batches move compact-setting target mapping, persisted settings
  field/schema selection, default normalization, panel-metric clamps,
  font-rendering combo bounds, terminal context-menu action/selection geometry,
  theme display labels, profile-preset validity, windowed-dimension
  percentage/floor selection, and launch-profile kind/sensitivity policy into
  tested Zig plans; C retains native state and GTK effects.
  Workspace event-routing classification, tray-menu item kinds/actions, native
  lifecycle timing constants, D-Bus ownership-result classification, shortcut
  conflict/failure event identities, D-Bus call/notification/drain/poll timing,
  native host geometry/scrollbar/copy bounds, UI color role ordinals, status
  event IDs, persistence result codes, remaining GTK scheduling intervals,
  settings-control event IDs, and native host-event protocol identities now
  cross tested Zig plans; C retains GTK/GVariant/GLib source and effect
  handling. `[truth:build,test,docs]`
  Numeric restore-mode text, sharing selection IDs, pane drag identifiers, and
  terminal accessibility names now also use bounded Zig text helpers; C retains
  spawn, combo-box, drag-and-drop, and ATK effects.
  Command-palette dispatch effects, split orientation/rendered-event selection,
  tab-rename boundary trimming/validation, and restored-session dimension minimums
  now cross tested Zig plans; C retains GTK activation, inline editor, layout, and
  session-allocation effects.
  Keyboard accessibility granularity, keyboard-scroll action mapping, chord
  side-effect flags, and terminal renderer fallback RGB defaults now cross
  tested Zig policy plans; C retains ATK pointer conversion, GTK key delivery,
  Cairo/Pango rendering, and native widget effects.

  Continue migrating that adapter incrementally behind its existing ABI
  contracts; keep generated vendored Tree-sitter parsers, system headers, and
  display-isolation shell orchestration outside the source-percentage target.
  The isolated mapped GTK proof remains open: the private X11 runner deferred
  under host I/O pressure (`exit=75`), and the current private Wayland wrapper
  exits before producing a smoke receipt (`exit=1`); physical Windows behavior
  remains a separate required acceptance boundary. `[truth:build,test,external]`

##### NCT-126 fixed definition of done

NCT-126 closes only when every gate below is evidenced against one locked
source tree. Once closed, no further percentage-driven GTK rewrites are part
of this item.

1. **Scope lock:** record the final source-tree commit and the counted
   ownership inventory. Count only first-party `src/` and `include/deetty/`
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

Current locked-tree evidence reports `100.00%` Zig ownership under the fixed
policy-only denominator (`zig_lines=91721`, `adapter_lines=0`,
`target=90.00`). `scripts/check_native_c_classification.py` covers all 630
top-level definitions in `src/gui/native_grid_host.c`: 204 native-effect
functions, 22 query functions, 51 lifetime functions, 243 functions consuming
Zig policy plans, and 110 display-backed orchestration functions. The manifest
has no `remaining_policy` or unclassified function. ABI headers, native
effects, and display orchestration are excluded exactly by the locked scope;
new or stale C definitions fail the inventory checker.

Focused Debug and `ReleaseSafe` builds plus the 141-test Zig policy suite pass.
The complete focused renderer matrix
(`DEETTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=300 ./scripts/native_grid_smoke.sh`)
now passes in serialized private X11 and private Wayland namespaces:
`native_grid_renderer_matrix x11=true wayland=true abi=7 dirty_spans=true
frame_clock=true glyph_cache=true resize_coalesced=true
synchronized_output=true deadman=true warning_fatal=true`. The individual
receipts report `resize_commits=1`, `sync_deferrals=4`,
`sync_releases=1`, `sync_deadman_releases=1`, and `passed=true` on both
backends. The Settings and compact-UX Wayland lanes also exit 0 with their
complete receipts. X11 qualification is no longer blocked by the earlier
pressure-gated `exit=75` attempt; no pressure threshold was bypassed.
NCT-126 remains open only for the broader registered-smoke qualification
matrix and external compositor/release gates.

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
- [x] [status:green] Implement native source-format theme imports for Ghostty,
  Xresources, Alacritty, and Noctalia. Windows now accepts those source
  extensions through its native picker and converts each source transactionally
  into one custom theme; focused parser coverage and the native Windows theme
  smoke cover all four source families. Physical Windows qualification remains
  in the supported-Windows custom-theme acceptance item below.
- [ ] [status:yellow] Qualify custom theme selection/import/export, replacement
  confirmation, persistence errors, and tab dragging on supported Windows with
  real sessions, DPI changes, and assistive technology. The focused policy
  group, file-backed interoperability smoke, GTK theme flow, and isolated
  Wine control/bitmap qualification pass. `[truth:build,test,docs,external]`
- [ ] [status:yellow] Qualify remaining native Windows workspace parity:
  Smart Tabs, dropdown presentation, global-hotkey behavior, and workspace
  continuity against supported Windows ConPTY sessions. Smart Tabs, guarded
  global hotkey visibility toggling, broadcast input, and persisted workspace
  recovery are implemented; source tests and cross-build/Wine evidence do not
  establish physical Windows acceptance.
- [ ] Continue replacing GTK C ownership with cohesive Zig components toward
  90% without counting file moves, duplicate implementations, or unrelated new
  code as architectural progress. Retain focused Linux runtime proof and
  supported-Windows acceptance for each migrated behavior.
##### NCT-127 fixed definition of done

NCT-127 closes only when Linux and Windows have feature/behavior parity for
the supported terminal workspace, while retaining native platform boundaries
(GTK/Cairo plus POSIX PTY on Linux; Win32/GDI plus ConPTY on Windows). A
different native widget or transport implementation is not a parity failure;
an undocumented user-visible capability gap is.

1. **Parity inventory:** one locked source-tree matrix maps every Linux
   workspace capability to a Windows implementation or an explicit,
   user-approved platform exception. The matrix covers terminal input/output,
   tabs, recursive splits, focus, selection, scrolling, profiles, themes,
   persistence/recovery, Smart Tabs, dropdown/global-hotkey behavior, NoctEd,
   and session sharing.
2. **Windows runtime proof:** the Windows implementation passes the matrix on
   supported Windows 10/11 hosts with real ConPTY sessions, Win32/GDI drawing,
   DPI, high-contrast, IME/keyboard, clipboard, accessibility, process
   lifecycle, and clean exit. Cross-builds, Wine, and policy tests are
   supporting evidence only.
3. **Cross-platform proof:** Linux↔Windows session sharing, remote input
   permissions, routed-VPN connectivity, persistence compatibility, and
   workspace/tab/pane identity transitions pass with real hosts on both sides.
4. **Receipt integrity:** Linux and Windows receipts identify the same locked
   commit, exact package/archive digests, supported-host versions, exercised
   capabilities, and explicit skips/failures. No source-only, loopback-only,
   isolated-runner-only, or Wine-only result closes this gate.
5. **Boundary accounting:** signing, publication, redistribution review,
   final compositor acceptance, and consented physical HID remain separate
   Release Operations gates; they cannot be silently counted as parity.

Current status: the locked bilingual source-tree inventory is now maintained in
`docs/WINDOWS_LINUX_PARITY.md` and
`docs/WINDOWS_LINUX_PARITY.zh-CN.md`, and the Windows host adds a
DPI-aware status footer without changing the native boundary. Physical Windows
qualification, cross-machine Linux↔Windows proof, and the remaining workspace
parity receipts are still open.

#### NCT-128 NoctEd KOF4J tooling compatibility — open

- [ ] [status:yellow] Qualify NoctEd against the canonical KOF4J project fixture
  with 100% language coverage, 100% linter compatibility, and 100% required
  LSP compatibility. The fixture must pin its repository revision, file/language
  inventory, linter configuration/version, LSP configuration/server versions,
  tool paths, and approved unsupported cases; no compatibility claim exists
  until every manifest row has an observable result.
  `[truth:test,docs,external]`

##### NCT-128 fixed definition of done

NCT-128 closes only when every supported NoctEd target claimed by the release
passes the canonical KOF4J project:

1. **100% language coverage:** every inventoried source, opened generated file,
   config, template, and documentation type has the correct language identity
   and complete declared syntax/highlighting behavior; unsupported or
   misidentified rows are zero.
2. **100% linter compatibility:** NoctEd discovers and invokes the exact KOF4J
   linter/configuration from the project root, preserves cwd/arguments, and
   presents every fixture diagnostic with correct file, range, severity, message,
   and version. Clean output, warnings, errors, malformed output, non-zero exit,
   cancellation, timeout, and missing executable paths have explicit results.
3. **100% required LSP compatibility:** NoctEd passes every KOF4J-required,
   server-advertised initialization, workspace-root, document-version,
   diagnostics, completion, hover, definition, references, rename, symbols,
   formatting, cancellation, restart, and shutdown case over bounded local
   stdio JSON-RPC. Unsupported capabilities are reported, not counted as pass.
4. **Lifecycle compatibility:** project open/reload/rename, nested modules,
   generated/vendor ignores, unsaved buffers, multi-file state, linter failure,
   server restart, and clean exit preserve project/tool state without stale
   diagnostics or cross-project leakage.
5. **Receipt integrity:** the receipt names the KOF4J revision, exact tool/server
   versions, configuration hashes, NoctEd commit/package digest, language/linter/
   LSP cases, approved skips, failures, host/backend, and Debug/`ReleaseSafe`
   native-smoke results. Source inspection, one opened file, or a mock server
   cannot close the gate.

The required receipt is
`nocted_kof4j_compatibility languages=100% linter=100% lsp=100% lifecycle=true`.
The implementation baseline now bundles the official Kof grammar, maps `.kf` and
`.kof` to `kof lsp`, and detects KOF4J `check`/`build`/`test` tooling projects.
`scripts/nocted_kof4j_qualification.sh` produces a real-distribution
`status=partial` receipt. The gate remains open because no pinned fixture
manifest, complete LSP/lifecycle matrix, or isolated native Debug/`ReleaseSafe`
receipt is retained. The detailed bilingual contract is in
`docs/NOCTED_KOF4J_DOD.md` and `docs/NOCTED_KOF4J_DOD.zh-CN.md`.


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
