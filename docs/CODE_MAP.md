# NOCTTY Code Map

This map is for contributors and reviewers who want to understand the public
alpha source tree without reading the backlog first.

## Product entry points

- `src/main.zig` — NOCTTY executable entry point, command-line dispatch,
  development/smoke command routing, native-grid launch paths, and many receipt
  writers used by qualification scripts.
- `src/nocted/main.zig` — standalone NoctEd GTK editor executable, including
  application wiring, project loading, tabs, search, save flows, callbacks, and
  NoctEd smoke/qualification flows.
- `build.zig` — build graph for production binaries, optional VTE fallback,
  smoke binaries, qualification runners, and `zig build check`.

Start here when trying the app:

```sh
zig build run -- --native-grid-windowed
zig build run-nocted -- --project . --open README.md
```

## Main NOCTTY runtime areas

- `src/app/App.zig` — product-level application model. Owns config loading,
  theme/workspace persistence, editor-document integration, host launch plans,
  and high-level command results.
- `src/gui/Host.zig` — native GUI host-facing planning types for presentation,
  windows, dropdown behavior, shortcuts, notifications, status UI, project panel
  presentation, clipboard/paste flow, and related status structs.
- `src/gui/native_grid_host.c` — GTK native-grid implementation. This is the
  large C boundary that owns the current production grid window/dropdown UI,
  pane drawing, GTK callbacks, tab chrome, compact controls, settings surfaces,
  and bridge calls into Zig.
- `src/gui/native_host.c` — older/optional VTE-backed native host path used for
  fallback and compatibility experiments, not the main public product surface.
- `src/workspace/Workspace.zig` — workspace state, tabs/splits/layouts, project
  panels, activation plans, project actions, and persistence-facing workspace
  structures.
- `src/config/Config.zig` — user-facing configuration model and defaults.
- `src/theme/*` — theme library/import/export/application logic.

## Terminal core

- `src/terminal/Terminal.zig` — terminal/session-facing types and orchestration.
- `src/terminal/Vt.zig` — VT/grid model: cells, scrollback, anchors, search,
  graphemes, hyperlinks, style storage, parser application, dirty regions, and
  screen state.
- `src/terminal/VtParser.zig` — terminal escape/control parser.
- `src/terminal/Unicode.zig` — Unicode width/encoding helpers used by the grid.
- `src/terminal/pty.c` — native PTY/process boundary.
- `src/terminal/vt_public.c` — small C ABI helper surface used by smoke/public
  VT checks.

## NoctEd editor core

- `src/nocted/main.zig` — standalone GTK app wiring. It is intentionally large
  today: GUI construction, callbacks, file/project actions, smoke flows, and
  app lifecycle live together for alpha.
- `src/nocted/root.zig` — import root for reusable NoctEd core modules.
- `src/nocted/FilesystemWorker.zig` — GLib worker-job model for project scans,
  searches, document load/save, cancellation, lane admission, queue limits, and
  completion handoff.
- `src/nocted/project_index*` / `src/nocted/project_search*` — project indexing
  and Find in Files support.
- `src/nocted/document*` — document load/save/edit support used by the editor.
- `src/nocted/TextMateGrammar.zig` and syntax modules — syntax-definition
  import/highlight support.

## Smoke and qualification code

The repo contains a lot of proof code by design. Public alpha reviewers should
read this as engineering evidence, not as extra product surface.

- `scripts/verify.sh` — full maintainer gate. It is intentionally broad and may
  take a long time on contributor machines.
- `scripts/native_release_smoke.sh` — display-backed native smoke gate.
- `scripts/nocted_native_smoke.sh` — NoctEd GUI/editor smoke path.
- `scripts/terminal_*_qualification.sh` — terminal compatibility and PTY/TUI
  qualification lanes.
- `src/*Qualification*.zig` — focused qualification runners built by `build.zig`.

A practical contributor sequence is:

```sh
zig build check
zig build run -- --native-grid-windowed
zig build run-nocted -- --project . --open README.md
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
8. `src/nocted/FilesystemWorker.zig`
9. `src/nocted/main.zig` app lifecycle and save/search/open paths
