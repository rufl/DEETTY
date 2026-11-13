# DINTTY Code Map

This map is for contributors and reviewers who want to understand the public
alpha source tree without reading the backlog first. The largest runtime files
also carry module-level ownership comments; comments explain boundaries and
non-obvious lifetime rules rather than restating each function.

## Product entry points

- `src/main.zig` — DINTTY executable entry point, command-line dispatch,
  development/smoke command routing, native-grid launch paths, and many receipt
  writers used by qualification scripts.
- `src/nocted/main.zig` — standalone NoctEd GTK editor executable, including
  application wiring, project loading, tabs, search, save flows, callbacks, and
  NoctEd smoke/qualification flows.
- `build.zig` — build graph for production binaries, the experimental Windows
  host, optional VTE fallback, smoke binaries, qualification runners, and
  `zig build check`.

Start here when trying the app:

```sh
zig build run -- --native-grid-windowed
zig build run-nocted -- --open README.md
```

## Main DINTTY runtime areas

- `src/app/App.zig` — product-level application model. Owns config loading,
  theme/workspace persistence, host launch plans, and high-level command results.
  Editor documents belong exclusively to the standalone NoctEd process.
- `src/gui/Host.zig` — native GUI host-facing planning types for presentation,
  windows, dropdown behavior, shortcuts, notifications, status UI, project panel
  presentation, clipboard/paste flow, and related status structs.
- `src/gui/native_grid_host.c` — GTK native-grid implementation. This is the
  shrinking C boundary that owns the production grid window/dropdown GTK
  lifetimes, callback dispatch, Pango glyph caches, and bridge calls into Zig.
- `src/gui/NativeGridLogic.zig` — tested platform-neutral input-routing
  precedence, keyboard command planning, tab/pane cycle targets, directional
  pane focus scoring, scrollbar geometry and press/drag planning, wheel
  accumulation and fallback keys, GTK modifier-mask and Alt/Meta key policy,
  tray-menu ID, label, and icon policy, resize-cursor orientation,
  resize-edge ordinals, handle-index normalization, resize-handle grid layout,
  pane-divider snap points, active-pane render selection, status-label and
  profile-preset label selection, broadcast-menu label selection, global
  shortcut identity strings, terminal key encoding and shortcut labels,
  keyboard scroll targets, bounded UI text and hyperlink validation,
  command-palette action IDs, labels, and hints, workspace color-editor labels
  and roles, fuzzy matching, responsive dropdown dimension/percentage
  conversion, sharing-status actions, bracketed-paste markers, sharing-preview
  control-key sequences, text-prefix buffering, arrow-sequence formatting,
  paste-limit/chunk sizing, sharing-preview scroll-direction mapping, decimal
  selection-index parsing/formatting, normalized pane hit testing, theme-color
  RGB-channel extraction and hex formatting, terminal font/cell metric
  conversion, grid sizing/auto-fit, window-resize deltas/bounds,
  pointer-to-cell mapping, linear selection hit testing, pixel-snapped render
  and dirty row/cell damage spans, packed-cell/run decoding, UTF-8 encoding,
  clipping, pane chrome, and caret policy consumed through
  `include/dintty/native_grid_logic.h`.
- `src/gui/NativeGridRender.zig` — Cairo/Pango-owned grid cell pipeline,
  row buffering, glyph-cache and ASCII-run batching, terminal font setup and
  text, text decorations, resize/cycle/note/status overlays, and terminal
  scrollbar rendering behind the narrow
  `include/dintty/native_grid_render.h` ABI.
- `tests/native_grid_qualification.inc` and `tests/native_grid_*_smoke.inc` —
  test-only renderer, compact UX, presentation, full-stack, and stability
  qualification included only in smoke builds; production host source contains
  no qualification implementation.
- `src/gui/NativeGtk.zig`: migrated native GTK pane/resource strip,
  bounded nested split-branch visibility traversal, divider/gap styling,
  balanced split positioning, action-button affordances, compact-tab styling
  and construction, new-tab and window-toolbar controls, tab-child lookup,
  color styling, settings surfaces, context menus, compact dialogs, theme
  library, project tools, and sharing controls behind the narrow
  `include/dintty/native_gtk.h` ABI.
- `include/dintty/` — published narrow C ABI declarations; these remain counted
  by the Zig ownership gate.
- `src/gui/VteHost.zig`: older/optional VTE-backed native host path used for
  fallback and compatibility experiments, not the main public product surface.
- `src/windows/main.zig`, `src/windows/WindowsHost.zig`,
  `src/windows/Dpapi.zig`, `src/windows/WindowsHostLogic.zig`,
  `src/windows/WindowsPty.zig`, `src/windows/WindowsClipboard.zig`,
  `src/windows/WindowsProcess.zig`, `src/windows/WindowsMenu.zig`,
  `src/windows/WindowsFonts.zig`, `src/windows/WindowsTitle.zig`, and
  `src/windows/WindowsRenderer.zig` — experimental Windows boundary. Zig owns
  the main HWND/message loop, timers, hit testing, focus/capture, input,
  workspace-session orchestration, shared VT callbacks, persistence, ConPTY,
  the bounded output ring, clipboard, sibling launch, menus, fonts, titles,
  GDI rendering, local logs, and minidumps. No GTK, POSIX host state, or
  first-party C translation unit enters the Windows executable.
- `src/windows/WindowsWorkspace.zig` — the bounded Windows workspace model
  and versioned snapshot codec, separated from Win32 for focused native tests.
  Tab selection/naming/reordering preserve pane slots and split-tree identity.
- `src/windows/WindowsTabStrip.zig` — native tab control, rename dialog, and
  captured drag reordering; `WindowsHost.zig` owns viewport/lifecycle integration.
- `src/windows/WindowsAppearance.zig` — shared built-in theme lookup, ANSI
  palette overrides, and native exact-font-size bounds; no duplicate palette.
- `src/windows/WindowsThemeLibrary.zig` — bounded custom themes, transactional
  selection/import, shared portable codec, and Windows selection envelope.
- `src/windows/WindowsFileDialog.zig` — native Unicode theme file pickers.
- `src/terminal/LaunchProfile.zig` — bounded shared profile fields and named
  libraries, with explicit POSIX/Windows path and environment validation.
- `src/windows/WindowsLaunchProfiles.zig` — immutable built-ins, bounded custom
  entries, transactional selection/edit/delete, and the Windows profile codec.
- `src/windows/WindowsProfileDialog.zig` — native profile manager and guarded
  Unicode field editing; existing sessions are not reconfigured.
- `src/windows/WindowsLaunchPlan.zig` — explicit executable/argument planning
  and bounded Unicode child-environment merging, consumed by `WindowsPty.zig`.
- `src/workspace/SplitRatio.zig` — allocation-free, overflow-safe divider
  conversion used by the GTK adapter and Windows proportional workspace.
- `src/workspace/Workspace.zig` — workspace state, tabs/splits/layouts, project
  panels, activation plans, project actions, and persistence-facing workspace
  structures.
- `src/config/Config.zig` — user-facing configuration model and defaults.
- `src/theme/*` — theme library/import/export/application logic, including the
  built-in DINTTY Dark, High Contrast, and Paseo Black Zinc palettes.
- `src/share/Net.zig` — bounded cross-platform TCP, multicast-discovery, and
  socket-lifetime boundary for explicitly enabled LAN session sharing.

## Terminal core

- `src/terminal/Terminal.zig` — terminal/session-facing types and orchestration.
- `src/terminal/Vt.zig` — VT/grid model: cells, scrollback, anchors, search,
  graphemes, hyperlinks, style storage, parser application, dirty regions, and
  screen state.
- `src/terminal/VtParser.zig` — terminal escape/control parser.
- `src/terminal/KeyEncoding.zig` — toolkit-neutral navigation, editing, and
  function-key encoding shared by the GTK and Win32 adapters. Platform key
  identifiers stay in the adapters; terminal byte sequences live here.
- `src/terminal/Unicode.zig` — Unicode width/encoding helpers used by the grid.
- `tools/generate_terminal_unicode.zig` — offline bounded Unicode 17 table
  generator with pinned input/output SHA-256 verification.
- `src/terminal/Pty.zig`: PTY/session wrapper plus foreground `/proc` metadata
  and shared app/pane process-tree resource sampling; fixed-argv fork/exec,
  descriptor I/O, resize, wait, and process-group teardown are Zig-owned.
- `src/ghostty/VtPublic.zig`: isolated dynamic `libghostty-vt` probe used by
  smoke/public VT checks; its symbol is resolved once and stays outside product state.

## NoctEd editor core

- `src/nocted/main.zig` — standalone GTK app wiring. It is intentionally large
  today: GUI construction, callbacks, file/project actions, smoke flows, and
  app lifecycle live together for alpha.
- Window modes: `Settings.WindowMode` (settings v4 `window_mode`) drives the
  View menu `Windowed` / `Zen Fullscreen (F11)` items, F11 toggle, Escape exit,
  and `window-state-event` reconciliation. Zen hides the top bar, status bar,
  tab strip, and sidebar; fullscreen uses xdg-shell on Wayland (Aqueous/Pearl
  server-side decorations) and EWMH on X11.
- `src/windows/nocted_main.zig` and `src/windows/NoctedHost.zig` — fully Zig
  experimental Windows NoctEd model/bootstrap and Win32 controls adapter. The
  adapter owns RichEdit/tree/tab HWNDs, GDI fonts, menus, accelerators, dialogs,
  DPI layout, UTF conversion, and the message loop behind bounded callbacks.
  `src/windows/NoctedHostQualification.zig` supplies the isolated mapped
  mock-callback lifecycle harness; current proof status remains in the backlog.
- `src/nocted/root.zig` — import root for reusable NoctEd core modules.
- `src/nocted/Worker.zig` — GLib worker-job model for project scans,
  searches, document load/save, cancellation, lane admission, queue limits, and
  completion handoff.
- `src/nocted/project_index*` / `src/nocted/project_search*` — project indexing
  and Find in Files support.
- `src/nocted/document*` — document load/save/edit support used by the editor.
- `src/nocted/Session.zig` — private atomic ordered-tab state, version-1 import,
  and bounded version-2 dirty saved/untitled hot-exit snapshots.
- `src/TreeSitter.zig` and `src/nocted/TreeSitter.zig`: Zig-owned parser/query boundary and bounded highlight captures; only the vendored generated parsers remain C, and GtkSourceView remains the only text buffer/widget.
- `src/nocted/TextMateGrammar.zig` and syntax modules — fallback syntax-definition import/highlight support.

## Smoke and qualification code

The repo contains a lot of proof code by design. Public alpha reviewers should
read this as engineering evidence, not as extra product surface.

- `scripts/check_public_source_hygiene.sh` — bounded tracked-source publication
  guard for required policy files, generated artifacts, sensitive filenames,
  workstation paths, merge markers, and immutable GitHub Action pins.
- `scripts/verify.sh` — full maintainer gate. It is intentionally broad and may
  take a long time on contributor machines.
- `scripts/native_release_smoke.sh` — display-backed native smoke gate; requires an explicitly acknowledged disposable compositor session.
- `scripts/run_isolated_x11.sh`, `scripts/run_isolated_wayland.sh`, and `scripts/require_isolated_display.sh` — serialized focused-display boundaries and the fail-closed guard for broader disposable-session lanes; `scripts/check_display_isolation.sh` keeps the wrapper inventory explicit.
- `scripts/native_grid_presentation_qualification.sh`: opt-in dedicated Plasma Wayland/X11 synthetic key-handler-to-draw/frame-clock and presentation-timing lane.
- `scripts/native_grid_full_stack_qualification.sh`: opt-in live Wayland/X11 idle/fullscreen compositor-pixel, memory, and wakeup lane.
- `scripts/native_grid_resolution_smoke.sh`: focused private-KWin live output-mode
  switch proof for proportional dropdown reflow and current-monitor fullscreen.
- `scripts/native_grid_stability_qualification.sh`: NCT-112 hidden/visible phase runner. `--smoke` checks Debug/`ReleaseSafe` Wayland/X11 quickly; `--run` retains the default 48-hour authenticated `ReleaseSafe` matrix.
- `scripts/native_grid_authenticated_agent_qualification.sh`: opt-in launcher-selected Pi/OMP/ZIPI exact-response matrix through production PTY/VT/GTK/Cairo in dedicated Wayland/X11 sessions; Pi and OMP own external-provider access, while ZIPI is local-only.
- `scripts/native_grid_installed_continuity_qualification.sh`: opt-in installed tmux/Zellij detach, DINTTY relaunch, reattach, preserved-content, and compositor-pixel matrix.
- `scripts/nocted_native_smoke.sh` — NoctEd GUI/editor smoke path, including
  `--window-mode-smoke` zen/windowed chrome and persistence assertions.
- `scripts/nocted_native_endurance_qualification.sh`: opt-in 32-workflow-per-lane Debug/`ReleaseSafe` Wayland/X11 search/resource/monitor/lifecycle endurance matrix with rendered-content, memory, duration, and checksum evidence.
- `scripts/install_dogfood.sh` — atomic local `ReleaseFast` install, bounded
  logging launchers, desktop-entry rewrite, and private staging of the
  provenance-checked system GTK Layer Shell runtime; refreshes can reuse only
  the checksum-matching copy from the previous install receipt.
- `scripts/install_dogfood_smoke.sh` — isolated fake-prefix proof for retained
  runtime checksum admission and failure-before-install mutation.
- `scripts/windows_installer_timeout_smoke.sh` — fake-Wine proof for
  per-step failure attribution and bounded cleanup.
- `scripts/package_windows.sh` — experimental Windows `ReleaseFast` ZIP,
  checksum, and manifest packaging with PE/ConPTY/no-GTK contract checks.
- `scripts/package_windows_dogfood.sh` and
  `scripts/install_windows_dogfood.ps1` — PI WEB QOL-discoverable Windows
  dogfood bundle, checksum-gated per-user install, installed self-tests, and
  local install receipt.
- `scripts/terminal_*_qualification.sh` — terminal compatibility and PTY/TUI
  qualification lanes.
- `src/*Qualification*.zig` — focused qualification runners built by `build.zig`.

A practical contributor sequence is:

```sh
zig build check
zig build run -- --native-grid-windowed
zig build run-nocted -- --open README.md
```

Maintainers should still run the full verification matrix before tags or public
release artifacts.

## Large-file note

Some files are large in the current alpha tree. Do not treat size alone as a bug
or start broad refactors before dogfood. Preferred order:

1. fix crashes, save/data-loss bugs, launch/build failures, and README lies;
2. add small comments/tests around changed behavior;
3. extract obvious seams only when a real change makes the extraction useful.

## Current public-alpha reading path

For a fast review, read in this order:

1. `README.md`
2. `docs/KNOWN_LIMITATIONS.md`
3. `docs/PUBLIC_ALPHA_PLAN.md`
4. `docs/PUBLIC_ALPHA_CODE_REVIEW.md`
5. `src/app/App.zig` top-level types and `init/deinit/launchPlan`
6. `src/gui/Host.zig` launch/presentation structs
7. `src/terminal/Vt.zig` top-level data model
8. `src/nocted/Worker.zig`
9. `src/nocted/main.zig` app lifecycle and save/search/open paths
