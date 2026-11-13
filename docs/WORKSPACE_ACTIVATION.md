# Native workspace activation

DINTTY accepts local workspace deep links through `dintty --open-uri URI`. The installed desktop entry registers `x-scheme-handler/dintty`; `file:` input is also accepted for native callers. The only admitted forms are `dintty:///absolute/path.dinttyws` and `file:///absolute/path.dinttyws`.

The decoder is fixed-capacity native state. It rejects remote authorities, relative paths, query strings, fragments, malformed escapes, unescaped spaces, decoded control bytes, invalid UTF-8, paths over 4096 bytes, and names without the `.dinttyws` suffix. Admission does not perform network I/O. After decoding, the normal versioned workspace loader validates the complete snapshot before replacing startup state.

Activation happens before terminal sessions are created. The restored tab/pane/layout model therefore uses the same native reconstruction seam as crash-safe hot-session startup, with fresh PTYs in saved working directories. The internal `--open-workspace` path is used by the GTK adapter after a native file chooser or Recent Workspaces selection; it applies the same absolute-path validator. Activated and explicit `--new-window` processes do not claim the primary dropdown lock/D-Bus name or write its default hot-session file.

## Recent workspaces and continuity boundary

Settings snapshot version 8 introduced a fixed library of at most eight absolute workspace paths; version 9 retains it while adding continuity launch kinds. Recording is most-recent-first, deduplicating, and drops only the oldest entry at capacity. Version 7 imports with an empty list. Save and successful activation update settings atomically; users select entries through Project Workspace rather than editing the native snapshot. The dialog sizes itself to the current work area, keeps the workspace summary in a two-axis scroller instead of forcing a fixed width, and names the summary and recent-workspace control for assistive technology.

Open Workspace and Open Recent launch a separate native DINTTY process. This deliberately leaves terminals and foreground jobs in the current process untouched. It is window/process isolation, not live-process persistence: closing or crashing the process that owns a PTY still ends that ownership boundary, and hot restore starts fresh shells.

## Verification boundary

Unit tests cover both URI schemes, percent decoding, every rejection class, MRU ordering/deduplication/capacity, settings-version-9 round trips, version-8 MRU retention, and version-7 migration. The focused state/startup receipt predates the version-9 continuity-kind extension and remains valid for the unchanged workspace path:

```text
native_grid_workspace_activation_smoke native_uri=true file_uri=true percent_decode=true authority_rejected=true validated_snapshot=true startup_restore_seam=true recent_mru=true fixed_capacity=8 config_v9=true atomic=true separate_process_policy=true exited=true
```

The project/editor lane is extended to require `recent_control=true recent_persisted=true`, and both local lanes are in `scripts/native_release_smoke.sh`. The focused state smoke owns an absolute project-local scratch tree for `TMPDIR`, XDG cache, and both Zig caches, then trap-cleans it.

The application desktop entry also exposes **Open New Workspace Window** through `dintty --new-window`. The installed KIO service menu exposes **Open DINTTY Here** for local directories through `--new-window --working-directory %f`; the path is bounded, absolute, local, valid UTF-8, control-free, and opened as a directory before a PTY is created. That explicit
Open Here directory overrides any configured launch-profile cwd for the first
terminal without mutating the saved profile; later tabs continue to use the
profile normally.

`scripts/native_grid_installed_activation_smoke.sh` is the maintained installed-desktop acceptance lane. Its headless `--contract-only` mode builds the production install plus the isolated smoke binary in disposable locations, installs the real `com.dintty.DINTTY.desktop`, registers `x-scheme-handler/dintty`, validates the exact `Exec=dintty --open-uri %u` route, and writes a two-tab native workspace fixture. The install prefix, `TMPDIR`, XDG cache, and Zig local/global caches all live below one exact trap-cleaned project-local scratch root, so the lane neither depends on nor mutates the repository's shared caches. That contract emits:

```text
native_grid_installed_activation_contract installed_desktop=true mime_registered=true exec_open_uri=true startup_notify=true fixture_tabs=2 production_binary=true smoke_isolated=true scratch_scoped=true
```

The full mode must run inside an accessible Plasma session. For each requested Wayland/X11 GTK backend it first invokes the installed MIME handler with `gio open dintty:///…`, then opens Project Workspace, activates the real **Open Recent** button, and requires the separately spawned child to report a mapped, drawn two-tab native window before requesting controlled exit. Successful backends emit `native_grid_installed_activation backend=… desktop_dispatch=true parent_rendered=true recent_clicked=true child_rendered=true tabs=2 controlled_exit=true` and the final matrix emits `native_grid_installed_activation_matrix backends=wayland,x11 installed_desktop=true desktop_dispatch=true recent_child=true rendered=true controlled_exit=true scratch_clean=true`.

The smoke-only child receipt and temporary executable shim never enter the production binary or installed user state; they only make mapped/drawn state observable while exercising the production desktop resource and existing `--open-uri`/`--open-workspace` entry points. The live Plasma run retains both backends and both activation routes. The harness forces the guaranteed `C` locale before enabling fatal GTK warnings, requires mapped/rendered active content and a two-tab restored model, allows the hidden restored tab to remain unpainted, and waits for controlled zero exit. The script still fails rather than skipping or relabeling inaccessible backends.
