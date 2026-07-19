# Native workspace activation

NOCTTY accepts local workspace deep links through `noctty --open-uri URI`. The installed desktop entry registers `x-scheme-handler/noctty`; `file:` input is also accepted for native callers. The only admitted forms are `noctty:///absolute/path.nocttyws` and `file:///absolute/path.nocttyws`.

The decoder is fixed-capacity native state. It rejects remote authorities, relative paths, query strings, fragments, malformed escapes, unescaped spaces, decoded control bytes, invalid UTF-8, paths over 4096 bytes, and names without the `.nocttyws` suffix. Admission does not perform network I/O. After decoding, the normal versioned workspace loader validates the complete snapshot before replacing startup state.

Activation happens before terminal sessions are created. The restored tab/pane/layout model therefore uses the same native reconstruction seam as crash-safe hot-session startup, with fresh PTYs in saved working directories. The internal `--open-workspace` path is used by the GTK adapter after a native file chooser or Recent Workspaces selection; it applies the same absolute-path validator.

## Recent workspaces and continuity boundary

Settings snapshot version 8 introduced a fixed library of at most eight absolute workspace paths; version 9 retains it while adding continuity launch kinds. Recording is most-recent-first, deduplicating, and drops only the oldest entry at capacity. Version 7 imports with an empty list. Save and successful activation update settings atomically; users select entries through Project Workspace rather than editing the native snapshot.

Open Workspace and Open Recent launch a separate native NOCTTY process. This deliberately leaves terminals and foreground jobs in the current process untouched. It is window/process isolation, not live-process persistence: closing or crashing the process that owns a PTY still ends that ownership boundary, and hot restore starts fresh shells.

## Verification boundary

Unit tests cover both URI schemes, percent decoding, every rejection class, MRU ordering/deduplication/capacity, settings-version-9 round trips, version-8 MRU retention, and version-7 migration. The focused state/startup receipt predates the version-9 continuity-kind extension and remains valid for the unchanged workspace path:

```text
native_grid_workspace_activation_smoke native_uri=true file_uri=true percent_decode=true authority_rejected=true validated_snapshot=true startup_restore_seam=true recent_mru=true fixed_capacity=8 config_v9=true atomic=true separate_process_policy=true exited=true
```

The project/editor lane is extended to require `recent_control=true recent_persisted=true`, and both local lanes are in `scripts/native_release_smoke.sh`. The focused state smoke owns an absolute project-local scratch tree for `TMPDIR`, XDG cache, and both Zig caches, then trap-cleans it.

`scripts/native_grid_installed_activation_smoke.sh` is the maintained installed-desktop acceptance lane. Its headless `--contract-only` mode builds the production install plus the isolated smoke binary in disposable locations, installs the real `com.noctty.NOCTTY.desktop`, registers `x-scheme-handler/noctty`, validates the exact `Exec=noctty --open-uri %u` route, and writes a two-tab native workspace fixture. The install prefix, `TMPDIR`, XDG cache, and Zig local/global caches all live below one exact trap-cleaned project-local scratch root, so the lane neither depends on nor mutates the repository's shared caches. That contract emits:

```text
native_grid_installed_activation_contract installed_desktop=true mime_registered=true exec_open_uri=true fixture_tabs=2 production_binary=true smoke_isolated=true scratch_scoped=true
```

The full mode must run inside an accessible Plasma session. For each requested Wayland/X11 GTK backend it first invokes the installed MIME handler with `gio open noctty:///…`, then opens Project Workspace, activates the real **Open Recent** button, and requires the separately spawned child to report a mapped, drawn two-tab native window before requesting controlled exit. Successful backends emit `native_grid_installed_activation backend=… desktop_dispatch=true parent_rendered=true recent_clicked=true child_rendered=true tabs=2 controlled_exit=true` and the final matrix emits `native_grid_installed_activation_matrix backends=wayland,x11 installed_desktop=true desktop_dispatch=true recent_child=true rendered=true controlled_exit=true scratch_clean=true`.

The smoke-only child receipt and temporary executable shim never enter the production binary or installed user state; they only make mapped/drawn state observable while exercising the production desktop resource and existing `--open-uri`/`--open-workspace` entry points. The contract passes in the managed workspace. After cache isolation removed the earlier read-only build failure, both full attempts reached the native host; Wayland and X11 each emitted `native_grid_gtk_init_failed` and no child receipt despite visible socket paths. The full compositor receipts therefore remain open in NCT-111. The script fails rather than skipping or relabeling that missing compositor proof.
