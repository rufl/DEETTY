# NOCTTY Backlog Archive

Last refreshed: 2026-08-22.

This archive records completed implementation slices that changed the verified project boundary. The 0.1.0 product-behavior epics, follow-through safety slices, release-source/evidence work through NCT-085 plus the NCT-077 dependency-license payload follow-through, native performance and memory work through NCT-102 plus NCT-109 and NCT-116 through NCT-120, tab-drag hardening through NCT-113, NoctEd work through NCT-118 including NCT-104 daily-editing workflows and NCT-105 syntax compatibility, and active-pane information through NCT-115 are closed. Granular “still open” clauses below are preserved as point-in-time history and are superseded by the current product boundary.

NCT-100 reproducible split-terminal benchmarking and bounded PTY drain hardening, NCT-101 native output throughput hardening, and NCT-102 event-driven PTY scheduling plus benchmark isolation are also closed.

## 2026-08-22 <!-- craft-ignore: chronological archive navigation -->

### NCT-124 Konsole-class Plasma launch resilience: done

- Added parse-validated, atomically rotated settings/theme last-known-good backups; malformed primaries fall back without blocking a terminal and are retained as `.rejected` before a later GUI save replaces them. Invalid hot-workspace bytes receive the same exact retention.
- Added one native keyboard-accessible startup recovery notice with Open Settings and Dismiss actions.
- Added a per-user primary lock before mutable state, sharing identity, PTYs, or GTK; D-Bus name conflict remains the fallback. Twelve simultaneous cold callers and a hidden/show race resolve to one visible owner without duplicate hot-session writes.
- Added one-use bounded XDG activation-token handling for cold launches plus control and StatusNotifier paths, applied with GTK immediately before presentation and excluded from PTY child environments. Retained live X11 and Plasma Wayland presentation receipts.
- Added explicit separate `--new-window`, bounded `--working-directory`, desktop New Workspace, and Dolphin Open NOCTTY Here paths without claiming the primary control service or hot-session file.
- Removed first-toggle jank from the dogfood route: existing-owner controls bypass logging/fingerprint setup, install receipts cache Plasma/KWin versions, GTK debug chatter is opt-in, and protocol-v4+ layer surfaces use on-demand keyboard focus plus a keyboard-`NONE` commit before unmap.
- Acceptance met: `native_grid_single_instance_smoke cold_callers=12 owner=1 duplicate_window=false lock_fallback=true hidden_show_race=true visible=true activation_token=true tray_activation_token=true stale_token_cleared=true separate_window=true open_here_cwd=true process_group_cleanup=true`; `native_grid_state_recovery_smoke config_defaults=true theme_defaults=true workspace_defaults=true notice=true malformed_retained=true retention_failure_preserves_original=true usable_terminal=true process_group_cleanup=true`; `native_grid_wayland_activation_smoke gtk_startup_id=true xdg_activation_token=true cold_start=true forwarded_show=true token_not_in_pty=true backend=wayland visible=true process_group_cleanup=true`.
- Honest boundary: this closes local launch/state/activation plumbing, not NCT-112 multi-day stability, physical HID-to-photon focus proof, arbitrary process resurrection, or broad compositor acceptance.

## 2026-08-04 <!-- craft-ignore: chronological archive navigation -->

### NCT-110 authenticated mapped Codex compatibility: done

- Added `scripts/native_grid_authenticated_agent_qualification.sh` and a smoke-only production command-profile path for one exact authenticated Codex request in Debug/`ReleaseSafe` on live Plasma Wayland/X11.
- Every request was ephemeral, read-only, rooted at `/tmp`, and prohibited from running commands or inspecting files. Codex returned the exact 29-byte `NOCTTY_AUTHENTICATED_CODEX_OK` response in all four lanes.
- Retained response files, mapped compositor screenshots, root/process-tree memory, controlled zero exits, and checksums under `benchmarks/authenticated-agent-2026-08-04/`.
- Acceptance met: `native_grid_authenticated_agent_matrix provider=codex version=0.144.6 authenticated=true model_requests=4 debug=true release_safe=true wayland=true x11=true production_pty=true production_vt=true production_gtk=true production_cairo=true response_exact=true compositor_pixels=true root_memory=true process_tree_memory=true controlled_exit=true ephemeral=true sandbox=read-only hid=false checksums=true scratch_clean=true`.
- Honest boundary: this closes the accepted one-host authenticated Codex boundary, not Claude Code, Antigravity, universal agent compatibility, HID, or multi-day stability.

### NCT-111 installed tmux/Zellij detach and reattach: done

- Installed tmux 3.7b and Zellij 0.44.3 into the user prefix from signature-verified Arch packages; neither tool became a NOCTTY runtime dependency.
- Added `scripts/native_grid_installed_continuity_qualification.sh`, which runs the product's Persistent tmux and Persistent Zellij profiles in Debug/`ReleaseSafe` on live Plasma Wayland/X11.
- Each lane retained first-attach and reattach screenshots, routed the native detach chord through NOCTTY's PTY write path, exited the first NOCTTY process while preserving the session, launched a second process, and required the prior marker to remain visible.
- Retained 16 compositor screenshots, 16 controlled process logs, summary data, and checksums under `benchmarks/installed-continuity-2026-08-04/`.
- Acceptance met: `native_grid_installed_continuity_matrix tmux_version=3.7b zellij_version=0.44.3 debug=true release_safe=true wayland=true x11=true first_attach=true detached=true noctty_relaunch=true reattach=true content_preserved=true production_pty=true production_vt=true production_gtk=true production_cairo=true compositor_pixels=true controlled_exit=true hid=false checksums=true scratch_clean=true`.
- Honest boundary: this closes installed one-host continuity, not remote multiplexer transport, HID, cross-host portability, or multi-day survival.

### NCT-106/NCT-121/NCT-122 sustained native NoctEd endurance: done

- Added `scripts/nocted_native_endurance_qualification.sh`, which builds isolated Debug and `ReleaseSafe` smoke binaries and repeats 32 complete mapped workflows on live Plasma Wayland and X11 for every mode/backend lane.
- Retained 256 cycles per phase per lane, 1,024 cycles for each resource/search/lifecycle/monitor phase across the matrix, 4,096 combined phase cycles, and 3,072 deterministic full-order Quick Open ranking evaluations over 630 seconds.
- Every one of the 128 independent workflows passed warning-fatal GTK execution, bounded two-batch publication, cancellation, foreground open/save under scan load, actual GIO monitor bursts, overflow recovery, current-project model/tree draw, worker/project drain, hot-exit teardown, and post-widget callback safety.
- Replaced Wayland's potentially black `gdk_pixbuf_get_from_window` smoke output with bounded Cairo widget rendering plus sampled nonblack RGB validation. The first and final 1220×760 render from each lane were manually inspected and retained with raw receipts, process-tree memory, metadata, summary, and checksums under `benchmarks/nocted-native-endurance-2026-08-04/`.
- Polished the same native path with a product-cased NoctEd title, explicit window accessibility name, descriptive search placeholders, 28-logical-pixel transient icon controls, and visible focus rings across project, tab, close, search-result, and Quick Open navigation.
- Acceptance met: `nocted_native_endurance_matrix wayland=true x11=true debug=true release_safe=true rounds_per_lane=32 cycles_per_phase_per_lane=256 total_cycles_per_phase=1024 total_phase_cycles=4096 ranking_evaluations=3072 search_load=true deterministic_ranking=true gtk_batch_bounded=true project_lifecycle=true monitor_bursts=true overflow_recovery=true worker_drained=true process_tree_memory=true screenshots=true warning_fatal=true duration_recorded=true scratch_clean=true`.
- Honest boundary: this closes the sustained one-host native-GUI, project-lifecycle, and search/load acceptance tranches. It is not multi-hour/multi-day stability, a varied-project corpus, authenticated-agent proof, physical-input proof, universal latency ranking, or final compositor acceptance.

## 2026-07-18

### Fail-closed dependency-bundle redistribution payload — done

- Added `scripts/package_bundle_licenses.sh` to map every copied shared library to exactly one installed Arch/pacman or Debian/dpkg package, or the pinned vendored GTK Layer Shell payload. Missing ownership, empty expressions, absent texts, conflicting targets, and basename collisions fail the bundle.
- Embedded package-specific installed notices plus canonical SPDX license/exception texts under `share/licenses/noctty/dependencies`, with a SHA-256 inventory and package/version/expression/source records in the manifest sidecar.
- Normalized loader aliases before copying, isolated bundle Zig/XDG/tmp state below one self-cleaning scratch root, and promoted `redistribution_ready=true` only after all copied host libraries are accounted for and the license payload is complete.
- Routed the terminal-history qualification through the verifier-owned Zig caches, or through scratch-local caches when run alone, so the maintained full verifier no longer recreates a 321 MiB workspace `.zig-cache` after reporting cleanup.
- Tightened release receipt intake and status so `dependency_bundle_redistribution=true` additionally requires `bundle_manifest_redistribution_ready=true` and `bundle_license_payload_complete=true`; old two-field receipts are rejected.
- Added a synthetic Debian/dpkg ownership/version/copyright lane and Ubuntu workflow assertions for the ready manifest fields and embedded package payload. Acceptance met: `package_bundle_licenses_backend_smoke debian=true version=true copyright=true library_inventory=true package_inventory=true fail_closed=true scratch_clean=true`, `package_bundle_manifest manifest=true archive=true checksum=true installed_files=true library_inventory=true package_inventory=true license_payload=true all_libraries_accounted=true gtk_layer_shell_license=LGPL-3.0-or-later redistribution_ready=true fail_closed=true scratch_clean=true`, `release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true`, and `release_operations_status_smoke missing_diagnostics=true require_complete_blocks=true complete_fixture=true checksum_verified=true semantic_receipts=true bundle_manifest_attestation=true scratch_clean=true`.
- Honest boundary: the generated payload is a source/tooling redistribution-readiness gate for the exact host libraries, not legal advice, independent review, a signed architecture artifact, publication, or a retained release receipt.

## 2026-07-17

### NCT-104 NoctEd daily-editing workflow parity — done

- Added `Edit > Select All Occurrences` and `Ctrl+Shift+L`. NoctEd keeps GTK's primary selection authoritative for native clipboard and IME behavior while rendering up to 255 paired-mark secondary ranges with a dedicated text tag.
- Added a bounded Unicode core that finds at most 256 occurrences, caps selected text at 4096 bytes, normalizes reversed, duplicate, empty, and overlapping ranges, and applies replacements from the end backward. Native edits run inside one `GtkTextBuffer` user action, so typing, Backspace, or Delete across all ranges is one undo step; ordinary edits, folding changes, and Escape clear secondary state safely.
- Added an atomic versioned `session.conf` under NoctEd's configuration directory. It caps state at 64 KiB, recent projects at eight, open files at 32, rejects unsafe/oversized paths, and falls back to an empty state after corrupt input.
- Added `File > Open Recent`, bounded most-recent-first deduplication, Clear Recent Projects, persistence after project/tab/path/order changes and clean shutdown, and no-argument startup restoration of the project, exact saved tab order, and active saved tab. Untitled or dirty in-memory contents are deliberately not claimed as crash recovery.
- Added focused unit coverage for Unicode occurrence ranges, normalization, bounded/invalid input, one-model replacement, recent-project ordering, atomic round trips, and corrupt-state fallback. The warning-fatal native driver renders secondary selections, proves a single undo restores exact text, tears down and restores the live tab session, activates a recent project, validates the persisted receipt, captures the native window, and cleans its scratch tree.
- Acceptance met on both native backends: `nocted_native_matrix x11=true wayland=true folding=true find_in_files=true multi_file=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true warning_fatal=true scratch_clean=true`.
- Honest boundary: batch replace still needs a preview/confirmation contract; additional grammar formats, unsaved-buffer crash recovery, mature-editor parity, and sustained stability/latency evidence are not implied.

### NCT-105 NoctEd syntax ecosystem compatibility — done

- Added `Tools > Import TextMate JSON Grammar...`, a GUI-owned path that accepts JSON TextMate grammars used by VS Code extensions, converts supported match/range/repository rules to application-owned GtkSourceView XML, and requires no settings-file editing or runtime/plugin execution.
- Bounded input to 1 MiB, 512 supported patterns, 4096 bytes per expression, 32 file types, and 16 repository-include levels. Unit coverage rejects malformed, oversized, cyclic, missing-pattern, unsafe-extension, and unsupported-only grammars and verifies deterministic duplicate scope IDs.
- Stored converted definitions atomically under NoctEd's configuration directory. Normalized scope identity makes later imports replace earlier generated definitions deliberately, and generated definitions precede bundled, GUI-imported, and system search paths.
- Fixed both runtime syntax-import paths to replace an already-enumerated GtkSource language manager, re-detect every open buffer while the old manager remains alive, and release the old manager only after buffers drop its language objects. This closes the immutable-search-path assertion and language-finalization ownership errors exposed by warning-fatal smoke.
- Expanded the disposable native driver with a stale duplicate definition, a replacement grammar, a matching open document, language ID/name checks, generated-file replacement, precedence, malformed rejection, and scratch cleanup. Acceptance met on X11 and Wayland with 171 available definitions: `nocted_native_matrix x11=true wayland=true folding=true find_in_files=true multi_file=true untitled=true save_as=true quick_open=true quick_open_capture=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true warning_fatal=true scratch_clean=true`.
- Honest boundary: plist `.tmLanguage`, YAML Sublime `.sublime-syntax`, VS Code extension manifests, injections, embedded-language maps, and arbitrary Oniguruma-only semantics are outside this bounded converter and are not claimed.

### NCT-120 Stable terminal lines and compact scrollback — done

- Added monotonic logical-line IDs, grapheme-relative anchors, wrap metadata, and line generations so primary-screen resize reflows wrapped content without changing retained logical identity; stale anchors fail deterministically when history eviction drops their line.
- Kept visible rows and a bounded hot window as direct cells while encoding cold logical lines as UTF-8 graphemes plus compact style runs. Decoding reuses bounded scratch storage, alternate-screen resize remains non-reflowing, and cold history stays memory-only.
- Fixed explicit history-limit shrink to force cold-arena compaction even below the routine one-mebibyte dead-storage threshold, so repeated grow/shrink cycles release dead backing bytes immediately.
- Added deterministic Debug and `ReleaseSafe` qualification for 100000 logical lines, narrow/wide primary-screen reflow, compact-memory bounds, four grow/shrink cycles, and scratch cleanup. Acceptance receipt: `terminal_history_matrix debug=true release_safe=true lines=100000 compact=true reflow=true grow_shrink=true scratch_clean=true`.
- Current superseding presentation boundary: NCT-119 is complete through complementary exact Cairo, real PTY/VT-to-Cairo, mapped key-to-frame, and live Wayland/X11 idle/fullscreen compositor-pixel plus memory/wakeup qualifications. Physical HID and final compositor acceptance remain release operations.
- Current superseding terminal compatibility boundary: NCT-110 now retains deterministic protocol/Unicode plus installed Codex login/Vim/btop headless production-PTY/VT proof, while authenticated/broader mapped cross-backend agent acceptance remains partial (`terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true`). NCT-119 is complete; NCT-112 retains its bounded allocator/forced-group plus real installed-TUI tranches and remains partial for multi-day native-GUI/authenticated-agent qualification.

## 2026-07-16

### NCT-118 Bounded resource ownership and dirty-row rendering — done

- Added GUI-configurable terminal history from 0 through 100000 lines with a 1000-line default. New and live sessions receive the selected limit, shrinking immediately releases excess slabs, growth remains lazy from at most 32 rows, and column resize preserves retained logical history instead of discarding it.
- Moved display damage ownership into the Zig VT grid. Mutations mark terminal rows dirty, the host consumes and clears those bits once per presentation, and the obsolete full-row FNV hash pass plus callback were removed (`render_abi=packed_rows`, `render_abi_version=1`, `damage_tracking=dirty_rows`).
- Replaced the positional native-grid call surface with a size/version-checked `NocttyGridCallbacks` plus `NocttyGridLaunchOptions` ABI boundary. The Cairo host coalesces adjacent equal-background fills and batches eligible fixed-position ASCII runs through `cairo_scaled_font_text_to_glyphs`, while unsupported glyphs and style changes retain the bounded fallback (`glyph_batching=true`).
- Added one exclusive GLib filesystem worker for NoctEd project scan/search, document load/save, and Save As path resolution. The application caps outstanding jobs at 64, checks generation cancellation between bounded core steps, transfers only completed state to GTK's main thread, joins the worker before widget teardown, and drains completion ownership before releasing documents (`nocted_worker=bounded`).
- Removed linear document identity scans and repeated tree strings. Canonical paths map directly to documents, notebook pages carry their document pointer, project/search/quick-open models store compact entry IDs, project-search results borrow indexed paths, and per-document search contexts plus minimaps are created lazily.
- Strengthened terminal qualification with eight 1x1-to-2x2-to-1x1 rounds plus final 3x3 teardown, proving 32 dynamic session creates and closes. A deterministic malformed control/UTF-8 corpus is fed one byte at a time through resize and history-limit churn with grid/dirty-row invariants checked.
- Added isolated Debug and `ReleaseSafe` resource lanes. NoctEd runs eight cancellation/duplicate-open/atomic-save cycles and proves the worker/project queues drain; terminal churn samples root memory separately from the complete child tree. Current one-host receipts were NoctEd Debug 57537 KiB peak PSS and `ReleaseSafe` 51441 KiB, and terminal root Debug 38742 KiB and `ReleaseSafe` 30865 KiB; elapsed and memory values are bounded engineering observations, not release thresholds or cross-terminal rankings.
- Acceptance met: unit tests, executable/native-layout guards, warning-fatal standalone NoctEd smoke, packed-row renderer smoke, layout churn through 16 live sessions, and both resource qualification scripts pass. Canonical receipts include `nocted_resource_qualification debug=true release_safe=true cycles=8 cancellation=true duplicate_open=true atomic_save_close=true queue_bounded=true scratch_clean=true` and `native_grid_resource_qualification debug=true release_safe=true churn_cycles=8 max_live_sessions=16 overflow_preserved=true root_memory_separate=true process_tree_memory=true scratch_clean=true`.
- Honest boundary: NCT-106 remains partial for long editor/project soaks, allocator/leak tools, fuzzing, external-change races, and retained latency distributions. NCT-110 still owns modern VT/agent-TUI behavior. NCT-112 remains partial for multi-day terminal runs, sustained real-agent workloads, allocator accounting, frame/input latency, and forced-child cases across Plasma Wayland and X11.

### NCT-117 Runtime boundary, incremental editor work, and damage rendering — done

- Replaced NoctEd's blocking project walk with a cancellation-owned incremental scanner and transactional staging `GtkTreeStore`. Filesystem visits and model population each yield in bounded 128-item slices; the old project/index remains live until the new model commits.
- Replaced blocking Find in Files with an incremental cursor over the retained project index. One indexed entry is processed per idle callback, results publish incrementally, and every replacement/hide/shutdown path removes its GLib source before releasing cursor-owned root/query/result memory. Quick Open now coalesces search changes behind one 30 ms source.
- Removed the native grid's shallow `NocttyGridContext` copies. Dynamic and initial panes receive only explicit borrowed callbacks/configuration plus an explicit root pointer; split attachment now owns assignment of the borrowed page/tab relationship, while every context retains independent GTK widgets, buffers, hashes, sources, and teardown state (`pane_context_init=explicit`, `shallow_context_copy=false`).
- Added packed-row and row-hash callbacks at the existing host ABI boundary. Cairo fetches each visible row once, output presentation queues contiguous changed-row ranges, cursor movement/blink invalidates only cursor cells, and newly mapped panes force one full initial damage pass (`render_abi=packed_rows`, `damage_tracking=row_hash`).
- Split build products by responsibility. Default installs contain `noctty` and `nocted`; production `noctty` has no VTE, Tree-sitter, smoke scheduler, or legacy-editor command surface. `noctty-vte` is optional, while `noctty-smoke` and `nocted-smoke` are explicit non-default test artifacts. Debian/RPM/Arch runtime manifests no longer require VTE (`production_vte=false`, `production_noctty_tree_sitter=false production_nocted_tree_sitter=true`, `production_smoke_surface=false`).
- Hardened native proof while integrating the split: smoke scripts use dedicated run targets, failed NoctEd diagnostics survive `set -e`, mapped split panes receive initial damage, pointer tab drag uses PID-owned screen coordinates with bounded KDE activation, and compatibility-editor completion is event-driven rather than tied to a fixed shell sleep.
- Acceptance met: `zig build check`, the production release contract, package-manifest parsers, warning-fatal NoctEd X11/Wayland matrix, packed-row/damage native smoke, and one continuous `native_release_smoke` pass all succeed. The renderer receipt reported nonzero row batches and damage rows.
- Honest boundary: NCT-106 still owns long editor soaks/leak qualification; NCT-110 still owns modern VT/agent-TUI protocol coverage; NCT-112 still owns allocator-accounted churn, multi-day runs, and latency/resource qualification.

### NCT-116 Root-coalesced descriptor fallback and source ownership — done

- Removed the one-second timer previously owned by every descriptor-backed pane. PTY data remains descriptor-driven, while the existing root maintenance pass performs one bounded exit-safety poll per live descriptor context; a pane-local 16 ms read/exit timer exists only when GLib descriptor registration fails (`descriptor_fallback=root_coalesced`, `pane_exit_timers=0`).
- Centralized I/O-source and complete context-source shutdown in `stop_grid_io_sources` and `stop_grid_context_sources`. Natural exit, pane close, tab close, retirement, application close, and final shutdown now share the same idempotent ownership path (`source_cleanup=centralized`).
- Decoupled layout-preset visual mapping proof from I/O readiness. Descriptor-backed panes must be mapped with a registered descriptor source and no pane timer; registration-fallback panes must carry the 16 ms timer.
- The eight-pane static periodic schedule falls from the NCT-109 intermediate 11 callbacks per second to 3: root maintenance at 1 Hz plus root cursor blink at 2 Hz. This is a scheduling calculation, not a CPU benchmark.
- Acceptance met: maintenance, balanced eight-pane, 1×1/2×2/3×3 preset churn, pane close, and two-tab late-callback gates pass. Receipts include `descriptor_fallback=root_coalesced pane_exit_timers=0 periodic_callbacks_per_second=3` and `source_cleanup=centralized`.
- Full-matrix validation exposed that PID/visibility checks alone did not guarantee a real pointer drag reached the tab strip under concurrent desktop load. The tab-reorder harness now raises and synchronously activates only its spawned, PID-verified NOCTTY window, verifies active-window identity, and synchronizes each pointer move before pressing.
- Honest boundary: NCT-112 remains partial for repeated allocator-accounted churn, long hidden/visible soaks, sustained agent-TUI output, and cross-backend latency/resource qualification.

### NCT-115 Yakuake-style active-pane information and metadata boundary — done

- Added one optional 18-pixel information strip per notebook page. It follows Yakuake/Konsole's local `%d : %n` shape as `short cwd : foreground process`, ellipsizes in the row, and exposes pane ID, PID, process, and full directory in its tooltip without adding a title bar to every split.
- Added one bounded POSIX metadata seam: `tcgetpgrp` resolves the PTY foreground process group, `/proc/<pid>/cwd` and `/proc/<pid>/comm` provide local metadata, shell-child retry handles foreground-exit races, and workspace cwd plus `shell` remain deterministic fallbacks. A pure Zig formatter validates UTF-8/control safety and writes label/tooltip text into caller-owned buffers without heap allocation.
- Isolated GTK ownership and setter dedupe in `NativeGtk.zig` behind the retained C header. Focus and notebook changes refresh immediately; foreground command transitions reuse the existing one-second root maintenance timer and query only the active page. Identical metadata retains the same widget revision (`pane_refresh=coalesced`, `pane_info_dedup=true`).
- Added the Appearance > Client chrome checkbox, config snapshot v4 migration/default coverage, typed app command, live toggle, immediate atomic persistence, and fresh-App reload proof.
- Replaced implicit first-page-child assumptions with explicit terminal-content lookup across layout binding, hot-session rebuild, presets, and cross-tab moves. The preset menu smoke now uses bounded mapped-menu retries and fail-fast shell release, preventing a compositor-delay failure from hanging the gate.
- Aligned `package_bundle.sh` with the reproducible tarball by requesting `ReleaseSafe -Dstrip=true` and guarded that release-source contract.
- Workspace-menu actions now cancel the menu's stale focus-loss timer and return focus to the active pane. This keeps dropdown mode stable while heavier layout rebuilds complete; dismissal without an action still follows the configured focus-loss behavior. The workspace smoke also waits on bounded native visual readiness and explicitly releases its shell fixtures instead of racing compositor draws against fixed process sleeps (`visual_ready=true`, `controlled_exit=true`).
- Hardened the native qualification lifecycle without retrying failed assertions: synthetic workspace-menu activation now uses one shared focus-preserving mapped-menu helper, click-focus proof uses one bounded readiness state machine plus controlled PTY release, pane-close fixtures keep a controllable foreground process group alive through the close guard, tab-rename proof explicitly visits hidden pages before requiring a draw, editor-shutdown cancellation is origin-bound to the natural close dialog, and release stages receive 200 ms of GTK teardown quiescence before the next process starts. Pointer presses and GTK focus signals share one idempotent pane-activation path, so PTY focus, workspace selection, compact tabs, redraw, and pane information cannot drift while compositor focus delivery catches up.
- Acceptance met: 244 unit tests, executable check, compact/settings receipts, hot-session Wayland/X11 matrix, pane move, recursive split, pane close, and 1×1/2×2/3×3 preset gates pass. Compact receipt: `pane_info=true pane_source=pty_proc pane_refresh=coalesced pane_info_dedup=true`.
- Honest boundary: Yakuake/Konsole remote username/host title expansion is not inferred from local process metadata; it remains NCT-111 launch-profile work.

### NCT-114 NoctEd new-file, Save As, and quick-open workflows — done

- Added clean `Ctrl+N` untitled buffers with stable `Untitled`, `Untitled 2`, ... identities and ordinary dirty markers/prompts. Untouched buffers close without a prompt; saving a dirty untitled buffer routes through the native Save chooser.
- Added `Ctrl+Shift+S` and `File > Save As...` with local-only native overwrite confirmation, canonical existing/new target identity, atomic first-file creation, existing-permission preservation, duplicate-open target rejection, tab/path adoption only after write success, and GtkSourceView syntax re-detection after the filename changes.
- Added `Ctrl+P` bounded fuzzy project quick-open. It reuses the pruned 4096-entry/depth-12 project index, accepts one UTF-8 query up to 256 bytes, excludes directories, retains at most 100 ranked deterministic matches, labels truncation, preselects the first result, supports keyboard or row activation, and allocates no second filesystem index.
- Added focused tests for new-target resolution/atomic creation, query validation, fuzzy ordering, directory exclusion, and visible-result caps. The warning-fatal native smoke also proves untitled clean/dirty transitions, open-buffer collision rejection, exact first-save contents, syntax reclassification, bounded quick-open activation, and a captured quick-open surface.
- Acceptance met on X11: `nocted_native_gate rendered=true folding=true minimap_overlay_translucent=true find_in_files=true project_search_activation=true multi_file_tabs=true tab_navigation=true close_other=true close_all=true untitled=true save_as=true quick_open=true quick_open_capture=true warning_fatal=true backend=x11 scratch_clean=true`.
- Backend repeat: `nocted_native_matrix x11=true wayland=true folding=true find_in_files=true multi_file=true untitled=true save_as=true quick_open=true quick_open_capture=true warning_fatal=true scratch_clean=true`.
- At NCT-114 closure, NCT-104 still lacked multi-selection, recent-project, and restoration workflows; the completed NCT-104 entry above supersedes that point-in-time boundary.

### NCT-113 Native pointer-driven tab reorder hardening — done

- Kept GTK's native insertion indicator, scrollable overflow behavior, and reorderable-but-nondetachable pages for initial, dynamic, and hot-restored tabs. A drag changes order within the current NOCTTY notebook and cannot detach a terminal into an unmanaged window.
- Captured the active page before a background-tab pointer drag. Every accepted `page-reordered` event restores that stable page identity after Zig reorders by tab ID, while forward, backward, clamped, and no-op model moves are unit-covered.
- Added model-index lookup and GTK rollback when Zig rejects a reorder, preventing native/model divergence. Startup reconstruction suppresses reorder writeback, and successful drag motion shares the existing 120 ms hot-session flush coalescer instead of writing a snapshot at every intermediate position.
- Replaced the old direct `gtk_notebook_reorder_child` smoke with a PID-verified `xdotool` press/move/drop across three real live tabs. The lane proves UI/model order `2,3,1`, background active-tab preservation, snapshot/reload order plus active identity, owned-process cleanup, and is now part of `native_release_smoke.sh`.
- Acceptance met: `native_grid_tab_reorder_smoke pointer_drag=true pointer_press=true pointer_drop=true forward=true tabs=3 active_identity=true model_order=true snapshot_order=true persistence_coalesced=true exited=true`; canonical product receipt: `tab_reorder_pointer_drag=true tab_reorder_active_identity=true tab_reorder_rollback=true tab_reorder_persistence_coalesced=true`.

### NCT-109 Agent-session lifecycle and idle-scheduling hardening — done

- Added a native foreground-process-group query at the PTY/session boundary, now fully Zig-owned. Pane, tab, toolbar, tray, and window close require explicit `Close Anyway` confirmation before stopping active Codex/Claude/Antigravity-style foreground jobs; final-terminal protection remains unchanged.
- Made PTY shutdown bounded: foreground and shell process groups receive SIGHUP, the shell receives up to 500 ms to exit, and a stuck group is forced instead of blocking the GTK thread indefinitely.
- Made `TerminalSession.deinit` idempotent and changed accepted pane/tab close to deinitialize the complete PTY plus VT grid. Dynamic sessions are removed and destroyed from `NativeGridSessionPool` immediately, closing the retained scrollback/grid and embedded-buffer lifetime left by prior context-only retirement.
- Raised a callback-retirement barrier before IM and GTK tree teardown. Generic draw, focus, key, mouse, scroll, resize, PTY, drag, and clipboard paths reject retired session userdata; an outstanding asynchronous clipboard read retains only the small C context until its callback drains. The two-tab native lane schedules a deliberate post-close focus callback and fails unless it is ignored without touching the released Zig session.
- Centralized workspace-menu dismissal and process-local popup teardown before parent-window hide/destroy. The hot-session matrix now treats GLib/GDK warnings as fatal on Wayland and X11, covering the previously intermittent parent-unmap warning (`popup_teardown=true`).
- Coalesced cursor blink and maintenance onto one root-owned timer each, retained per-pane status ticks through one shared maintenance dispatch, slowed descriptor-backed exit fallback from 250 ms to one second, and coalesced hidden-pane presentation to 100 ms while skipping redraw requests for unmapped areas. That intermediate eight-pane schedule fell from 56 to 11 callbacks per second; NCT-116 later removed the eight pane-owned exit timers and reduced it to 3.
- Added `scripts/process_tree_memory.sh` for explicit-PID descendant PSS/RSS accounting and documented the daily-driver/agent-memory boundary without inspecting or controlling Yakuake. Modern VT, live-process continuity, and long-duration agent qualification remain NCT-110 through NCT-112.
- Acceptance met: PTY/session tests, `zig build check`, native source guards, the rendered pane-close path, and the post-close two-tab callback probe report `foreground_guard=true close_confirmed=true primary_pty_closed=true session_storage_released=true late_callback_guard=true pty_event_source=true split_collapsed=true root_timer_coalesced=true hidden_present_throttled=true mapped_redraw_only=true`.

## 2026-07-15

### NCT-108 NoctEd project search and multi-file controls — done

- Added `Ctrl+Shift+F` and `Find > Find in Files...` with an explicit Enter/search-button trigger, path/line/column previews, matching-line counts, and result activation that opens the canonical document, restores folds, selects the target line, scrolls it into view, and focuses the editor.
- Kept search resource use deterministic: queries are one UTF-8 line capped at 256 bytes; scans reuse the pruned project index, inspect at most 1024 files and 32 MiB total, skip files over 1 MiB plus binary/invalid UTF-8 data, retain at most 1000 matching lines, and bound each preview to 240 UTF-8 bytes.
- Tightened the shared text boundary so standalone document load/save and project search reject NUL-bearing data instead of allowing a C-string truncation hazard.
- Added `Ctrl+PageUp`/`Ctrl+PageDown` previous/next file navigation, `Ctrl+W` close-file, and File-menu Close Other Files/Close All Files actions. All close routes reuse NoctEd's Save/Discard/Cancel decision path.
- Added core search tests plus a warning-fatal standalone rendered gate with a disposable two-file project. Acceptance met: `nocted_native_gate rendered=true folding=true minimap_overlay_translucent=true find_in_files=true project_search_activation=true multi_file_tabs=true tab_navigation=true close_other=true close_all=true warning_fatal=true backend=x11 scratch_clean=true`.
- Repeated the complete standalone workflow on native X11 and Wayland backends: `nocted_native_matrix x11=true wayland=true folding=true find_in_files=true multi_file=true warning_fatal=true scratch_clean=true`.

### NCT-107 NoctEd configurable folding and minimap legibility — done

- Added a persisted GUI code-folding toggle plus Fold Current Region, Unfold Current Region, Fold All, and Unfold All actions. `Ctrl+Shift+[` and `Ctrl+Shift+]` operate on the current indentation region.
- Added a single-pass indentation analyzer bounded to 4096 regions and nesting depth 256. Blank lines, tabs, siblings, and nested regions are unit-covered.
- Folded bodies use scaled invisible GtkTextTags plus live marks. Every byte remains in the source buffer, no document body is duplicated, modified state stays unchanged, and native undo history survives fold/unfold. Search, edits, undo/redo, and disabling folding clear tags first; folded save reads the complete unchanged buffer.
- Made the GtkSourceMap scrubber translucent instead of obscuring rendered minimap glyphs. GDK self-capture verified compact folded layout without blank line gaps and visible minimap text beneath the viewport.
- Hardened GTK shutdown ordering so late buffer/notebook signals cannot inspect destroyed widgets. Warning-fatal smoke covers fold, unfold, folded save, edit-triggered unfold, undo preservation, settings toggle, and teardown.

### NCT-103 Standalone NoctEd foundation — done

- Replaced the normal product-facing embedded editor route with a sibling `nocted --project <pane-cwd>` launch. GLib starts and automatically reaps the separate child; NOCTTY does not own NoctEd's window, documents, or lifetime. The old embedded editor was temporarily retained for compatibility smokes and was later removed with that duplicate state surface.
- Added a fully Zig NoctEd executable with a declaration-only GTK 3/GtkSourceView 4 ABI boundary, compact Sublime Text 2-style menu/tabs/status chrome, left project tree, line-numbered source view, right minimap, native find, undo/redo, dirty tabs, and Save/Discard/Cancel close protection.
- Added bounded UTF-8 loading, 1 MiB editable and 8 MiB preview limits, canonical path identity for symlink-safe saves, permission-preserving atomic writeback, a 4096-entry/depth-12 pruned project index, explicit GTK model/document cleanup, XDG settings, and per-document bounded undo.
- Reused installed GtkSourceView 4 `.lang` definitions, bundled Zig syntax, detected additional GtkSourceView 3 definitions, prompted before importing them, and added a GUI directory importer. The rendered host exposed 170 syntax definitions.
- Packaged `nocted`, its desktop/AppStream/icon resources, syntax/style assets, GtkSourceView dependencies, and both dependency-bundle launchers/libraries. Added normal-bin and `libexec` resource discovery.
- Native visual QA fixed a released GTK tree-value path and an inherited font rule that had expanded the minimap. The final render shows the compact project tree, full-width editor, 112-pixel minimap, and non-overlapping status surface.
- Acceptance met: `nocted_standalone=true process_separate=true project_tree=true project_activation=true minimap=true gtksourceview_lang=true syntax_import_prompt=true atomic_save=true permissions_preserved=true rendered=true`.

### NCT-102 Event-driven PTY scheduling and benchmark isolation — done

- Added a narrow PTY descriptor adapter and one GLib Unix-FD source per live pane. Readable PTYs drain immediately through the existing reusable 16 KiB buffer and 128 KiB dispatch cap; timer reads remain only as a 16 ms registration fallback.
- Replaced the continuous 16 ms read tick with a 250 ms exit fallback and one-shot 16 ms output presentation. Metadata, events, and drawing remain coalesced while idle panes perform no timer-driven PTY reads.
- Made descriptor, presentation, tick, blink, maintenance, note, hide, resize, and navigation sources teardown-owned across pane close, tab close, retirement, natural exit, application close, and final shutdown. The two-pane and pane-close native smokes now fail unless every exercised pane registered the event source.
- Pane-context `Close Terminal` now pops down its owning menu before destroying the pane hierarchy; the native close smoke records that transition and runs with GLib/GDK warnings fatal (`pane_close_menu_popdown=true`).
- Hardened the six-terminal harness with one-second post-teardown isolation, deterministic snake-order rotation, and per-pane WezTerm workload readiness. The final guarded matrix left Yakuake PID `507138` unchanged.
- NOCTTY's final four-pane writer median moved from the retained 80 ms pre-event-source result to 66 ms (100.569 MiB/s). It had the fastest startup median and lowest PSS at every pane count, tied Ghostty on writer completion, and trailed Kitty by 2 ms. The writer metric is still not final-frame latency.
- Acceptance met: `pty_event_source=true timer_read_polling=false output_present_coalesced=true event_source_cleanup=true pane_close_menu_popdown=true benchmark_order_isolated=true wezterm_split_ready=true writer_median_ms=66`.

### NCT-101 Native output throughput hardening — done

- Replaced full-screen visible-cell slab movement with a logical row ring. Full-screen forward/reverse scroll rotates one index and clears one row, while partial margins, editing operations, renderer reads, search/export, alternate-screen restoration, and resize retain logical ordering.
- Corrected mixed scrollback/current viewport reads and kept alternate-screen scrolling out of primary history; regressions cover physical wrap, partial margins across the wrap point, line insert/delete, viewport blending, and rotated primary restoration through alternate resize.
- Added a printable-ASCII run path that is regression-checked against byte feeding under mixed SGR, wrapping, CRLF, UTF-8, title, and scrollback input. A temporary release probe measured 200,000 ANSI lines at 0.03 seconds versus 0.06 seconds through the byte path.
- Reused a 16 KiB per-session read buffer while retaining the 128 KiB pump slice. Productive ticks arm one high-idle continuation per pane; every dispatch yields after one bounded pump, coalesces presentation onto the normal tick, tolerates only three transient empty polls, and is removed on every pane/tab/application/natural-exit teardown path.
- Re-ran the six-terminal matrix without touching Yakuake. NOCTTY's four-pane writer median moved from 318 ms to 80 ms (82.970 MiB/s), while idle PSS remained the lowest at every pane count in the current matrix.
- Acceptance met: `native_output_throughput=true visible_grid_ring=true vt_ascii_run=true pty_active_continuation=true continuation_cleanup=true read_buffer=16384 writer_median_ms=80`.

### NCT-100 Reproducible split-terminal benchmark and bounded PTY drain — done

- Added an isolated native benchmark entrypoint that materializes balanced 1/2/4/8-pane NOCTTY layouts with one controlled workload per independent PTY.
- Added fresh-process adapters for Konsole, Kitty, WezTerm, Terminator, and Ghostty; fixed 1200x800 XWayland geometry; three-run startup, process-tree PSS/RSS, idle CPU, and four-pane ANSI writer metrics; and raw/summary/environment artifacts.
- Excluded Yakuake from launch, focus, control, and cleanup. The final matrix retained the same PID before and after, and Konsole D-Bus calls were scoped to `org.kde.konsole-$launch_pid`.
- Fixed the benchmark-exposed one-4-KiB-read-per-16-ms-tick bottleneck by draining PTY bytes until `EAGAIN`, EOF, or a 128 KiB per-pane budget. A deterministic fake-reader test guards the bound.
- The final machine-local matrix reduced NOCTTY's four-pane writer median from 7129 ms to 318 ms, kept median PSS between 30.679 and 31.337 MiB across 1-8 panes, and preserved the remaining writer-throughput gap as an explicit report boundary.
- Acceptance met: `split_terminal_benchmark=true yakuake_excluded=true process_tree_pss=true pty_pump_bounded_drain=true output_metric=writer_completion`.

## 2026-07-14

### NCT-099 Native deep performance and memory hardening — done

- Replaced eager 1000-line per-pane VT history allocation with a 32-line slab that doubles only as output requires, keeps row-only resize history in place, and safely resizes both primary and alternate screen buffers.
- Packed codepoint and style into one C/Zig draw callback, skipped blank-glyph Cairo calls, bounded the terminal-find location stack, suppressed idle title/BEL probes, and throttled idle exit polling while retaining immediate byte/EOF checks.
- Fixed owned GTK preset text, spawn-error, recorder-context, dialog-state, and pending smoke-source cleanup in the legacy native host.
- Moved Tree-sitter capture scratch storage to the stack, delayed editor find reservation until the first match, and reduced native literal paste to one exact owned buffer using the session allocator.
- Acceptance met: `native_deep_memory_hardening=true scrollback_lazy_growth=true alternate_resize_safe=true packed_cell_render=true blank_cell_draw_skipped=true idle_metadata_probe_suppressed=true idle_exit_poll_throttled=true native_host_callback_cleanup=true tree_sitter_capture_stack=true editor_find_lazy_reserve=true literal_paste_single_pass=true paste_session_allocator=true`.

### NCT-098 Native allocation polish — done

- Moved VS Code syntax-theme JSON parsing onto an allocator-aware path and retained parser deinit, so theme import memory is released through the caller/test allocator instead of being hidden behind the page allocator.
- Checked git status and graph caps before cloning overflow records, avoiding one extra owned path/commit/summary allocation at the truncation boundary.
- Pre-reserved bounded native-editor find match storage for ordinary searches and replaced Smart Tab filter and terminal-find status label heap formatting with stack buffers.
- Acceptance met: `native_allocation_polish=true syntax_theme_parse_deinit=true git_parse_cap_before_alloc=true smart_filter_label_stack=true terminal_find_status_stack=true editor_find_prereserved=true`.

### NCT-097 Native leak and allocator-pressure hardening — done

- Retired heap-created native grid contexts are now removed from the root context array and freed when panes/tabs close, so repeated split/close cycles do not retain dead contexts until process shutdown.
- Replaced per-scrolled-line VT history allocation with a fixed per-grid scrollback slab while preserving the logical 1000-line ring and existing oldest-to-newest readers.
- Added common single-edit fast paths for the native editor buffer so ordinary inserts, deletes, same-length replacements, and suffix replacements avoid rebuilding the whole text buffer.
- Reduced terminal find to one pass for normal bounded result sets and retained the overflow fallback for very large match counts.
- Reused Tree-sitter parser documents for open editor documents by path/revision instead of constructing a one-shot parser document for every matching highlight request.
- Acceptance met: `native_memory_leak_hardening=true retired_context_free=true scrollback_slab=true editor_single_edit_fastpath=true terminal_find_cached=true tree_sitter_document_reuse=true`.

### NCT-096 Native performance and memory polish — done

- Cached the terminal cursor once per Cairo frame and skipped repeated font-face selection while drawing same-weight cells.
- Throttled running/output status events to actual PTY pump work or status transitions, added a one-second status tick for long-running transitions, and skipped hot-session persistence on high-frequency output/tick events.
- Completed native source cleanup for close/deferred-close paths so retired panes/tabs do not leave maintenance, focus-hide, feedback, or close-dwell callbacks behind.
- Bounded native-editor undo/redo history by transaction count and byte budget, optimized editor search line/column accounting to advance in one pass, and skipped generated/vendor trees plus pre-cap path allocation in project scans.
- Acceptance met: `native_perf_memory_polish=true draw_cursor_cached=true draw_font_switch_dedup=true tick_event_throttled=true teardown_sources_complete=true editor_undo_bounded=true editor_search_linear=true project_scan_pruned=true`.

### NCT-095 Compact-tab suffix allocation polish — done

- Removed heap allocation for the common compact-tab empty suffix cases by using literal empty strings and bounded stack buffers for pane-count, selection-count, broadcast, and tab-color tooltip suffixes.
- Avoided building a separate heap-allocated shortened-title string; long titles now escape the truncated prefix and append the ellipsis in the final markup.
- Preserved the same compact tab markup and tooltip text while reducing temporary allocations during title/status/tab refreshes.
- Acceptance met: `tab_suffix_stack=true empty_suffix_no_alloc=true ellipsis_no_concat=true tooltip_suffix_stack=true native_layout=true`.

### NCT-094 Tab-color CSS provider dedupe polish — done

- Cached the last applied tab color RGB and active-state style key on each GTK tab widget.
- Skipped removing and rebuilding the tab-color CSS provider when the requested color and active styling are unchanged.
- Preserved provider rebuilds for real color changes, reset-to-default, and active/inactive transitions where the tab-color shadow styling differs.
- Acceptance met: `tab_color_style_dedup=true provider_rebuild_bounded=true active_state_key=true native_layout=true`.

### NCT-093 Pane status tooltip dedupe polish — done

- Replaced the pane status tooltip's per-refresh `g_strdup_printf` allocation with bounded stack formatting.
- Cached the last applied pane tooltip on the drawing-area object and skipped repeated GTK tooltip setter calls when status/tag text is unchanged.
- Kept cache ownership on the GTK object through `g_object_set_data_full`, so replacement strings are freed by GTK when superseded or when the drawing area is destroyed.
- Acceptance met: `pane_tooltip_dedup=true stack_format=true tooltip_cache=true object_owned_cleanup=true native_layout=true`.

### NCT-092 Compact-tab setter dedupe polish — done

- Cached the last applied compact-tab markup and tooltip strings on the GTK tab label object.
- Skipped repeated `gtk_label_set_markup` and tab tooltip setter calls when the computed strings are unchanged, reducing GTK-side string churn on status/title refreshes without changing tab text or tooltip contents.
- Kept the cache object-owned through `g_object_set_data_full`, so replacement strings are freed by GTK when superseded or when the tab label is destroyed.
- Acceptance met: `tab_setter_dedup=true markup_cache=true tooltip_cache=true object_owned_cleanup=true native_layout=true`.

### NCT-091 Quick-note overlay bounded-preview polish — done

- Reduced the hold-Alt quick-note overlay read buffer from 1 MiB to a bounded 4 KiB preview buffer, matching the overlay's 512-character display boundary instead of the full editor note boundary.
- Added an explicit Zig text-action preview mode for quick-note reads, so oversized notes return a bounded prefix for overlays while the full Quick Note editor still uses the strict full-note read path.
- Kept UTF-8 validation and 512-character display truncation in the native overlay path, so a byte-truncated preview cannot leak invalid text into Pango.
- Acceptance met: `note_overlay_preview_bounded=true preview_buffer=4096 full_editor_read_unchanged=true utf8_validated=true native_layout=true`.

### NCT-090 Quick-note overlay font-cache polish — done

- Cached the quick-note overlay's Pango font description on the root grid context instead of rebuilding the same `Sans 9` description on every visible-pane overlay paint.
- Kept the Pango layout itself draw-local so Cairo context state remains correct while bounding repeated font-description allocation.
- Added cleanup for root, cloned, and shutdown contexts so the cached font description is released with other overlay-owned state.
- Acceptance met: `note_overlay_font_cached=true pango_font_reused=true draw_context_safe=true cleanup=true native_layout=true`.

### NCT-089 Native idle-redraw suppression polish — done

- Used the Zig pump result on each 16 ms native tick to distinguish actual PTY bytes from idle would-block ticks.
- Idle would-block ticks no longer queue a full terminal redraw after the no-op title/status work has been skipped.
- Redraw still happens on PTY bytes, status transitions, session exit, and cursor blink through the existing dedicated timer.
- Acceptance met: `idle_redraw_suppressed=true pump_driven_draw=true status_transition_draw=true native_layout=true`.

### NCT-088 Native tick-path no-op update polish — done

- Avoided setting the GTK window title on every 16 ms terminal tick when the focused/primary pane title is already the current top-level title.
- Avoided rebuilding and setting the running status tooltip on every tick after the pane has already entered the running state; exit/done/error and tag-refresh paths still update their tooltips.
- Guarded both hot-path no-op reductions through the native layout and docs truth checks.
- Acceptance met: `tick_noop_dedup=true title_dedup=true status_tooltip_dedup=true native_layout=true`.

### NCT-087 Quick-note overlay allocation polish — done

- Cached the quick-note overlay's formatted `Note · ...` label when Alt preview is shown, so every mapped pane draw reuses overlay-owned text instead of allocating and freeing the same label on each paint.
- Extended overlay cleanup to clear both the raw note text and cached label on hide/release, session clone setup, and shutdown cleanup.
- Tightened the native note-overlay smoke predicate so the hidden state is only accepted after both overlay-owned strings are released.
- Acceptance met: `note_overlay_cached=true draw_allocations=bounded hidden_cleanup=true native_layout=true`.

### NCT-086 Native VT scrollback ring-retention polish — done

- Replaced the Zig VT grid's capped scrollback front-removal path with a bounded ring-retention model, preserving logical oldest-to-newest reads without shifting retained history on every line after the cap.
- Pre-reserved the scrollback pointer storage at grid initialization and added allocator cleanup on grid init/resize failure paths so partial setup cannot leak already-owned buffers.
- Added a regression that feeds beyond the 1000-line cap, verifies the ring has advanced, and proves viewport/logical line reads still expose the expected retained oldest and newest entries.
- Acceptance met: `scrollback_ring=true bounded=1000 no_front_shift=true init_cleanup=true resize_cleanup=true order_preserved=true`.

### NCT-085 Compositor and Wayland HID acceptance intake guard — done

- Added `scripts/release_operations_acceptance_intake.sh` to retain compositor acceptance receipts and Wayland HID consent receipts only after semantic fields validate and placeholder text is absent.
- Compositor intake requires the requested compositor name to match the receipt, `native_release_smoke=true`, and `operator_acceptance=true`; Wayland HID intake requires the RemoteDesktop/EIS portal plus explicit consent and physical-input receipt fields.
- Added `scripts/release_operations_acceptance_intake_smoke.sh` and promoted it into `./scripts/verify.sh`. The smoke builds a complete retained-evidence fixture through the artifact, signature, publication, redistribution, compositor, and HID intake paths, proves `--require-complete` can pass with zero issues, and rejects placeholder, compositor-mismatched, and no-consent receipts.
- Acceptance met: `release_operations_acceptance_intake_smoke compositors=6 wayland_hid=true semantic=true placeholder_blocked=true compositor_mismatch_blocked=true consent_required=true complete_status=true scratch_clean=true`.

### NCT-084 Publication and redistribution receipt intake guard — done

- Added `scripts/release_operations_receipt_intake.sh` to retain publication receipts and dependency-bundle redistribution notices only after their semantic fields validate and placeholder text is absent.
- Tightened `scripts/release_operations_status.sh` so `publication=true` also requires retained tagged artifacts and retained signatures; a standalone publication receipt now reports `publication_prerequisites_missing` instead of pretending publication evidence is coherent.
- Added `scripts/release_operations_receipt_intake_smoke.sh` and promoted it into `./scripts/verify.sh`. The smoke proves publication and redistribution receipts can move the retained-evidence status to two remaining external blockers, while placeholder, incomplete, and prerequisite-missing publication evidence are rejected or diagnosed.
- Acceptance met: `release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true`.

### NCT-083 Signature intake guard — done

- Added `scripts/release_operations_signature_intake.sh` to retain archive, checksum, or manifest signatures only after the matching canonical retained evidence target already exists.
- The intake guard rejects missing targets, empty signature files, and placeholder signature content before copying into the canonical `release/evidence/0.1.0` signature filename.
- Added `scripts/release_operations_signature_intake_smoke.sh` and promoted it into `./scripts/verify.sh`. The smoke proves all six signature lanes can be retained after artifact intake, status then reports `signatures=true` while publication, redistribution, compositor acceptance, and Wayland HID remain blocked, and placeholder or targetless signatures are rejected.
- Acceptance met: `release_operations_signature_intake_smoke archive=true checksum=true manifest=true x86_64=true aarch64=true placeholder_blocked=true target_required=true retained_status=true scratch_clean=true`.

### NCT-082 Architecture artifact intake guard — done

- Added `scripts/release_operations_artifact_intake.sh` to retain a real architecture archive only after its `.sha256` and `.manifest` sidecars verify.
- The intake guard requires the manifest architecture to match the requested `x86_64` or `aarch64` lane and requires the manifest `archive_sha256` to match the retained checksum digest before copying into `release/evidence/0.1.0`.
- Added `scripts/release_operations_artifact_intake_smoke.sh` and promoted it into `./scripts/verify.sh`. The smoke proves both architectures can be retained from sidecar-verified fixture artifacts, the status gate then reports `tagged_artifacts=true` while the other external rows remain blocked, and an architecture mismatch is rejected.
- Acceptance met: `release_operations_artifact_intake_smoke x86_64=true aarch64=true sidecars_verified=true retained_status=true mismatch_blocked=true scratch_clean=true`.

### NCT-081 Release-evidence scaffold templates — done

- Added `scripts/release_operations_scaffold.sh` to create release-operation receipt templates for publication, dependency-bundle redistribution, compositor acceptance, and consented Wayland HID evidence.
- The scaffold intentionally does not create release artifacts, checksum sidecars, manifests, or signatures. It writes TODO-bearing templates so `scripts/release_operations_status.sh --require-complete` continues to fail until real retained evidence replaces them.
- Added `scripts/release_operations_scaffold_smoke.sh` and promoted it into `./scripts/verify.sh`.
- Acceptance met: `release_operations_scaffold_smoke templates=true fake_artifacts=false placeholder_blocked=true require_complete_blocks=true scratch_clean=true`.

### NCT-080 Semantic release-evidence validation — done

- Tightened `scripts/release_operations_status.sh` so retained evidence must carry semantic fields, not just nonempty files. Artifact manifests must match the retained architecture and checksum digest, publication receipts must name the tag and published artifact/checksum/signature/notes state, redistribution notices must declare copied-library accounting complete, compositor receipts must name version/compositor/runtime/operator acceptance, and Wayland HID receipts must name the consented RemoteDesktop/EIS proof.
- Placeholder text such as `TODO`, `TBD`, `unresolved`, `missing`, `placeholder`, `dummy`, or `retained evidence` now keeps the corresponding operation blocked.
- Updated `scripts/release_operations_status_smoke.sh` to prove the stricter complete fixture with manifest digests and semantic receipt fields.
- Acceptance met: `release_operations_status_smoke missing_diagnostics=true require_complete_blocks=true complete_fixture=true checksum_verified=true semantic_receipts=true bundle_manifest_attestation=true scratch_clean=true`.

### NCT-079 Release-operations missing-evidence diagnostics — done

- Extended `scripts/release_operations_status.sh` with `--list-missing`, producing deterministic `release_operations_issue` rows for absent or placeholder release evidence while preserving the normal status receipt used by `./scripts/verify.sh`.
- Added `scripts/release_operations_status_smoke.sh`, which proves an empty retained-evidence directory reports 21 specific issues and fails `--require-complete`. NCT-080 supersedes the original complete-fixture receipt with semantic retained-evidence validation.
- Promoted the focused smoke into `./scripts/verify.sh` and guarded the receipt through `scripts/check_docs_truth.sh`.
- Acceptance met for diagnostics; the complete-fixture contract is now guarded by NCT-080's `semantic_receipts=true` receipt.

### NCT-078 Release-operations evidence guard — done

- Added `scripts/release_operations_status.sh` as a local receipt for the remaining release operations. It checks retained tagged x86_64/aarch64 artifacts and checksums, artifact signatures, publication receipt, dependency-bundle redistribution notices, six compositor acceptance receipts, and explicitly consented Wayland HID evidence.
- Added `docs/RELEASE_OPERATIONS.md` with the expected evidence directory layout and the `NOCTTY_RELEASE_EVIDENCE_DIR` override for validating retained receipts outside the checkout.
- Promoted the status receipt into `./scripts/verify.sh` without requiring external completion, so local source verification stays green while reporting `complete=false` until credentials, runners, unavailable compositor sessions, or consented input evidence exist.
- Acceptance met with the current conservative receipt `release_operations_status version=0.1.0 tagged_artifacts=false signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=6`.

### NCT-077 Honest package receipts and dependency provenance — done

- Replaced the package manifest smoke's unconditional `debian=true rpm=true arch=true x86_64=true aarch64=true noctalia=true bundle=true` receipt with fields tied to checks that actually ran. RPM and Arch parser lanes now report `passed` or `unavailable`.
- Extended `scripts/package_bundle.sh` to emit a `.manifest` sidecar with version, release date, architecture, Zig compiler version, source revision when available, archive digest, byte count, sorted installed files, sorted bundled libraries, and a library inventory.
- Reconciled the vendored `gtk-layer-shell` fallback license boundary: Arch package metadata and upstream documentation identify the project/package as `LGPL-3.0-or-later`; the retained `LICENSE_MIT.txt` applies to many individual source files and is not treated as the whole package license.
- Acceptance at the time used a conservative `redistribution_ready=false` boundary because copied system runtime notices were not yet complete. The current NCT-077 follow-through supersedes that historical boundary with a fail-closed embedded license payload; no signing, review, receipt, or publication claim is inferred.

### NCT-076 Architecture-self-sufficient pinned release workflow — done

- Pinned the release workflow to Zig `0.16.0` instead of the moving `master` channel.
- Made both x86_64 and aarch64 matrix jobs install `libgtk-layer-shell0`, assert the runner `uname -m` matches the artifact architecture label, and validate each generated bundle plus SHA-256 sidecar before upload.
- Added `scripts/release_workflow_contract_smoke.sh` and promoted it into `./scripts/verify.sh` so the local gate guards the workflow contract.
- Acceptance met at the source-contract boundary: `release_workflow_contract zig=0.16.0 x86_64=true aarch64=true layer_shell=true gtksourceview=true nocted=true arch_assert=true verify=true bundle=true archive_validation=true sidecar_validation=true manifest_validation=true upload=true retained_artifacts_external=true`. Tagged architecture artifact retention remains an external release operation until the workflow actually runs on a tag.

### NCT-075 Dual-build reproducibility, version/date coherence, and scratch cleanup — done

- Replaced the tarball lane with two isolated `ReleaseSafe` install-tree builds using separate stages plus local/global Zig caches, normalized both archives, required byte-identical output, and required matching SHA-256 values before publishing the requested archive and sidecar.
- Added the guarded 0.1.0 release contract across `build.zig.zon`, `noctty --version`, AppStream, Debian, RPM, Arch, and release-facing documentation.
- Verification scratch roots, build caches, temporary archives, and sidecar staging paths are self-cleaning; explicitly requested output artifacts are preserved.
- Acceptance met: `scripts/package_reproducibility_smoke.sh` emits `package_reproducibility version=0.1.0 release_date=2026-07-14 builds=2 isolated=true byte_identical=true checksums_match=true archive_valid=true cli_version=true scratch_clean=true`, `release_contract_smoke.sh` emits `release_contract version=0.1.0 release_date=2026-07-14 revision=1 build_zon=true runtime=true appstream=true debian=true rpm=true arch=true docs=true`, and the post-run local cleanup removed NOCTTY cache/temp residue.

### NCT-072 Exact-pane native profile selection — done

- Added a native `Profile` submenu to every terminal context menu with five Zig-owned radio choices: Global default, Compact, Readable, High contrast, and Mono no ligatures.
- Current-item resolution and activation retain the pane ID captured by the original right click, so keyboard focus on another pane cannot redirect the mutation.
- Acceptance met: the rendered two-pane gate opens the real submenu, observes the current item, drives three presets on pane 2, and keeps pane 1 unchanged.

### NCT-073 Live resolved-profile application and isolation — done

- Added the narrow per-pane query for resolved family, point size, high-contrast state, ligature preference, and current preset. GTK synchronizes only the matching renderer; Readable recalculates the target at 14 pt, High contrast redraws its theme, and Settings exposes the same Zig path as `Active pane profile`.
- Profile changes dirty the workspace and persist through snapshot/autosave restoration without moving durable ownership out of Zig.
- The Cairo boundary remains conservative: Mono no ligatures proves live persisted preference delivery and pane isolation, not font-feature shaping or visible ligature suppression in the fixed-cell codepoint renderer.

### NCT-074 Rendered profile preset and persistence matrix — done

- Added `scripts/native_grid_profile_preset_smoke.sh`, promoted it into `scripts/native_release_smoke.sh`, and guarded the aggregate `profile_presets=true` contract.
- Focused receipt: `native_grid_profile_preset_smoke context_menu=true submenu=true menu_survived=true presets=5 exact_target=true current=true readable=true font_size=14 isolated=true high_contrast=true rendered=true mono_no_ligatures=true workspace_dirty=true snapshot=true restored=true exited=true`.
- Acceptance met on two consecutive hardened reruns across both display backends: `native_grid_profile_preset_matrix wayland=true x11=true exact_target=true isolated=true persisted=true restored=true`. `zig build check` also passes.

### NCT-069 Whole-application unsaved-editor close guard — done

- Added one root-owned graceful-shutdown transaction that scans every native grid context for an open dirty former embedded-editor buffer before any PTY, timer, tray, control, or GTK-loop teardown begins.
- Each dirty editor receives the existing native Save/Discard/Cancel decision. Save must complete through the Zig atomic-write boundary, Discard authorizes only the pending application close, and Cancel or save failure leaves the editor and application alive and rearms a later close request.
- Application-close requests arriving while an editor-owned confirmation is already modal are deferred and resumed afterward, preventing nested prompts or replacement of the direct editor decision.
- Acceptance met: the rendered runtime lane opens two dirty editors and proves single-depth prompt ownership, window-manager Cancel survival, deterministic toolbar save-failure survival, and retryable state before a later accepted close.

### NCT-070 Graceful editor-aware shutdown routing — done

- Routed the tab-row `Close NOCTTY` button, the StatusNotifier tray close item, the main-window manager delete event, and natural last-PTY exit through the shared editor-aware transaction.
- Clean, read-only, and editor-free closes retain their direct clean-shutdown behavior. Accepted dirty-editor closes enter the existing idempotent all-session cleanup only after the editor decision succeeds.
- Natural last-PTY close waits a bounded 80 ms before preflight so already-delivered terminal exits settle without bypassing dirty editor confirmation; Cancel preserves both exited contexts, their distinct nonzero exit codes 7 and 9, active validation state, the mapped editors/window, and retryability.
- Acceptance met at the bounded route boundary: the dirty-editor lane drives window-manager Cancel, toolbar save-failure retry, natural last-PTY Cancel/retry, and final toolbar Save/Discard teardown. The existing live clean tray-close receipt confirms tray convergence on the transaction; dirty Cancel is not separately driven from the tray entry.

### NCT-071 Rendered editor-shutdown route matrix — done

- Added the historical `scripts/native_grid_editor_shutdown_smoke.sh` rendered/runtime matrix for two dirty editors: direct editor-modal ownership and window-manager deferral, window-manager Cancel, deterministic toolbar save failure, natural last-PTY Cancel after an 80 ms dwell, and final toolbar acceptance with one Save and one Discard.
- Promoted that lane into the aggregate release contract while the compatibility editor existed. The lane and compatibility editor were later removed after standalone NoctEd became the sole editor owner.
- Aggregate reruns also hardened two prerequisite tab proofs against compositor and PTY scheduling variance. The two-tab harness now waits for the background-tab popup to be mapped, then chains close validation into fresh-tab reopen and cleanup. The tab-rename harness uses bounded two-tab/mapped-label readiness retries, while both fixture PTYs wait for an explicit read handshake before exiting.
- This hardening changes proof orchestration only; it does not broaden the native tab-close, new-tab, inline-rename, or PTY behavior contract.
- Acceptance met: the exact compositor-backed receipt requires one direct editor prompt plus five application-close prompts, `modal_depth=1`, deferred/resumed prompt ownership, window-manager and natural-exit Cancel/retry, deterministic save-failure survival, `already_exited=2`, `exit_codes=7,9`, preserved active validation, accepted toolbar origin, saved/discarded file correctness, two-session completion, editor destruction, and tray/menu unregistration. Dirty Cancel is not separately driven from the tray entry. Forced `SIGTERM`, `SIGKILL`, and desktop-session termination cannot display an interactive save prompt and remain outside this graceful-shutdown guarantee.

### NCT-066 Embedded-editor clean/dirty Save state — done

- Connected the native `GtkTextBuffer` modified state to an explicit `Unsaved changes` status and the Save control: clean and read-only documents keep Save disabled, while a real edit enables it immediately.
- Programmatic file loads and syntax-tag application are suppressed from dirty tracking, then explicitly establish a clean buffer without duplicating durable document state in GTK.
- Acceptance met: Zig checks/tests and the rendered project/editor gate prove clean-load, dirty-state, Save-sensitivity, parent-window mapping, and clean PTY exit.

### NCT-067 Embedded-editor Ctrl+S atomic writeback — done

- Added exact `Ctrl+S` handling while the former embedded-editor dialog owns focus. Only a dirty editable document invokes the existing Zig edit plus atomic-save action; unrelated keys and terminal input remain unchanged.
- Successful writeback clears the native modified flag, disables Save, and reports `Saved`; a failed write keeps the buffer dirty, the action enabled, and the editor open.
- Acceptance met: the rendered gate edits the first fixture, drives the real key event, verifies clean-state reset, and confirms the saved bytes through the Zig file boundary.

### NCT-068 Unsaved editor transition guards — done

- Opening another file or directly closing the editor now presents a native Save/Discard/Cancel decision. Same-file activation is a no-op, Cancel preserves the exact path/text/dirty state, Save must succeed before the transition, and Discard authorizes only that transition rather than prematurely marking the old buffer clean.
- Both the dialog Close response and the GTK window-manager delete event share the guarded lifecycle. Owned prompts and the editor stay above a mapped NOCTTY parent without weakening explicit whole-application shutdown.
- Extended `scripts/native_grid_project_editor_smoke.sh` with five rendered prompts covering file-switch Cancel/Save/Discard and close Cancel/Discard, including atomic bytes, unchanged discarded-file bytes, parent survival, and final editor destruction. The receipt now reports `dirty_state=true save_state=true ctrl_s=true file_switch_cancel=true file_switch_save=true file_switch_discard=true close_cancel=true close_discard=true parent_mapped=true`.
- Acceptance met: focused Zig checks/tests and the compositor-backed project/editor smoke pass.

### NCT-035 Multi-pane tags and smart tabs — done

- Added de-duplicated, trimmed pane tags with workspace persistence through the existing pane snapshot format.
- Added native `Tag Selected Panes…` and `Smart Tab Filter…` actions to the terminal context menu.
- The smart tab filter is a live active-tab view over the existing PTY-backed split, preserving pane identity and geometry while hiding untagged panes.
- Added model coverage for multi-pane tagging, filter matching, clearing, and selection integration.
- Acceptance met: Zig checks/tests pass; the native workspace smoke remains the runtime gate for selection and broadcast routing.

### NCT-036 Tag management and smart-filter polish — done

- Added `Remove Tag from Selected Panes…` with the same native dialog and workspace-dirty boundary as tagging.
- Smart Tab Filter now supports replacing the active tag and clearing it with a blank value; cancel leaves the current filter unchanged.
- Added model coverage for selective tag removal while preserving tags on unselected panes.
- Acceptance met: Zig checks/tests and docs truth pass; native runtime verification remains bounded by compositor availability.

### NCT-037 Native tag/filter runtime receipt — done

- Extended the compositor-backed workspace smoke to tag the selected pane, apply a Smart Tab filter, verify tagged/untagged matching, clear the filter, and confirm the model state after the live GTK run.
- Updated the maintained workspace smoke wrapper and release matrix expectation with `tag=true filter=true filter_cleared=true`.
- Acceptance met: source, packaging, docs, and native-layout gates pass; live GTK execution remains display-session dependent on this host.

### NCT-038 Tag discoverability polish — done

- Pane tooltips now include the pane's current tags.
- Tag and remove-tag actions refresh all live pane tooltips immediately.
- The narrow C ABI export reads Zig-owned workspace tags without duplicating tag state in GTK.
- Acceptance met: full repository verification and documentation truth checks pass.

### NCT-039 Smart Tab compact indicator — done

- Compact tab labels now show the active Smart Tab tag and expose the filter state in the tab tooltip.
- The indicator refreshes across notebook pages whenever the filter changes or a page is selected, while the underlying live sessions remain untouched.
- Extended the native workspace receipt to verify the rendered compact indicator before clearing the filter.
- Acceptance met: source, packaging, documentation, and native-layout gates pass; compositor-backed rendering remains display-session dependent.

### NCT-040 Smart Tab command-palette access — done

- Added `Set Smart Tab filter` to the native command palette.
- Added `Ctrl+Shift+G` and the same shortcut-card entry; both use the existing native dialog and Zig filter state.
- Blank filter input clears the Smart Tab, while cancel preserves the current filter.
- Acceptance met: source, packaging, documentation, and native-layout gates pass.

### NCT-041 Palette tag management — done

- Added `Tag selected panes` and `Remove tag from selected panes` to the native command palette.
- Added `Ctrl+Shift+Y` for tagging selected panes; removal remains available through palette/context actions to avoid destructive shortcut surprises.
- Reused the existing tag dialog, tooltip refresh, and Zig workspace command paths.
- Acceptance met: source, packaging, documentation, and native-layout gates pass.

### NCT-042 Selection and broadcast state indicators — done

- Compact tab labels now show a selection-count marker and a broadcast marker when active.
- Tab tooltips explicitly state when a selection group is active and when broadcast input is enabled.
- Extended the native workspace receipt to verify these indicators alongside existing selection and broadcast routing.
- Acceptance met: source, packaging, documentation, and native-layout gates pass.

### NCT-043 Smart Tab focus handoff — done

- Applying a Smart Tab filter now moves keyboard focus to the first matching live pane when the previously focused pane is hidden.
- Clearing the filter restores visibility without disturbing selection, broadcast, or PTY state.
- Extended the native workspace receipt to verify the filtered focus handoff.
- Acceptance met: source, packaging, documentation, and native-layout gates pass.

### NCT-044 Smart Tab empty-state feedback — done

- Smart Tab filters with no matching panes now show a native “No panes match this Smart Tab filter” message instead of an unexplained blank split.
- The empty state disappears when a matching filter is selected or the filter is cleared.
- Extended the native workspace receipt to verify empty-state display and recovery.
- Acceptance met: source, packaging, documentation, and native-layout gates pass.

### NCT-045 Smart Tab empty-state recovery — done

- Added a visible native `Clear filter` action to the no-match Smart Tab state.
- Clicking it clears the Zig filter, removes the transient empty state, restores all panes, and returns focus to the terminal surface.
- Extended the compositor-backed workspace receipt with the actual button activation and post-clear visibility/state check.
- Acceptance met: source, packaging, documentation, and native-layout gates pass; live GTK execution remains display-session dependent on this host.

### NCT-046 Smart Tab empty-state context — done

- Empty Smart Tab feedback now names the active tag instead of showing only a generic no-results message.
- The native label has an explanatory tooltip, while the existing `Clear filter` action remains the direct recovery path.
- Extended the workspace receipt to verify the active tag is present in the rendered empty-state text.
- Acceptance met: source, packaging, documentation, and native-layout gates pass; live GTK execution remains display-session dependent on this host.

### NCT-047 Smart Tab keyboard recovery — done

- Pressing `Escape` now clears a Smart Tab only when its active tag has no matching panes, so ordinary terminal Escape input remains unchanged.
- Keyboard recovery uses the same Zig-owned clear path as the native `Clear filter` button and restores terminal focus.
- Extended the native workspace receipt with the zero-match Escape recovery path.
- Acceptance met: source, packaging, documentation, and native-layout gates pass; live GTK execution remains display-session dependent on this host.

### NCT-048 Native tag suggestions — done

- Tag, remove-tag, and Smart Tab dialogs now expose a native editable list of unique tags already present in the workspace.
- Users can select an existing tag or continue typing a new one; no manual config-file editing or duplicated GTK tag state is required.
- Added workspace-model coverage for deterministic de-duplication and extended the native workspace receipt to verify the populated suggestion model.
- Acceptance met: source, packaging, documentation, and native-layout gates pass; live GTK execution remains display-session dependent on this host.

### NCT-049 Pane-local Ctrl+wheel font scaling — done

- `Ctrl+wheel` now changes only the terminal pane under the pointer instead of propagating the size to every live pane.
- The targeted pane alone recalculates its Cairo cell geometry and PTY dimensions; ordinary unmodified wheel routing and global Settings font changes remain intact.
- Pane font sizes are validated in Zig-owned profile state, persisted through workspace snapshots, and restored independently.
- Extended model and native compact-UX coverage for pane isolation, global-default preservation, ordinary scrolling, and workspace reload.
- Acceptance met: source, packaging, documentation, and native-layout gates pass; live GTK execution remains display-session dependent on this host.

### NCT-050 System-tray context menu and clean close — done

- The Plasma StatusNotifier item now exports a standard native D-Bus menu with dynamic `Show NOCTTY`/`Hide NOCTTY`, `Settings…`, and `Close NOCTTY` actions.
- `Close NOCTTY` stops every active pane timer and PTY through the existing session lifecycle before leaving the GTK loop; tray and menu objects are then unregistered without stale watcher entries.
- Extended the live window/tray gate to inspect the menu layout, verify visibility-label updates, activate the real close item, require PTY shutdown, and confirm watcher cleanup.
- Acceptance met: Zig checks and the compositor-backed Plasma tray smoke pass.

### NCT-051 Yakuake-style main-window controls — done

- Added flat system-theme Settings and Close buttons to the notebook's trailing action slot, on the same compact row as the tabs.
- Preserved Yakuake's right-edge order: Settings immediately precedes Close; the control group follows horizontal or vertical tab placement without adding a title bar.
- Settings opens the existing native configuration surface. Close shares the clean all-session shutdown lifecycle with the tray action while retaining independent activation proof.
- Extended the rendered Settings lane to inspect placement, order, icons, accessibility names, real button activation, PTY shutdown, and clean exit; the tray-close regression remains covered separately.
- Hardened the adjacent workspace receipt so full-matrix proof checks selection chrome on the selected pane's real tab and gives dynamic PTYs sufficient render/exit dwell.
- Acceptance met: Zig checks/tests, documentation/layout guards, rendered Settings and Plasma tray smokes, workspace smoke, deterministic verification, and the consolidated native release matrix pass.

### NCT-052 Frictionless inline tab rename — done

- Replaced the transient rename dialog with a borderless `GtkEntry` embedded directly where the compact tab label is rendered; double-clicking the title selects the current name for immediate typing without opening another window.
- Enter validates and commits through the existing Zig workspace transaction. Escape or focus moving to any other control, tab, or terminal surface destroys the editor and restores the unchanged model title.
- Kept invalid names in the inline editor with local warning feedback, and routed the command-palette action plus `Ctrl+Shift+R` through the same no-popup lifecycle.
- Strengthened the compositor-backed tab-rename gate to prove embedded placement, popup absence, outside-click cancellation, Enter commit, rendered/model/snapshot persistence, focus restoration, and independent PTY cleanup.
- Acceptance met: Zig checks and both rendered tab-rename entry routes pass on the compositor-capable host.

### NCT-053 Native button hover affordances — done

- Added one shared GTK affordance path for persistent and transient native action buttons, including tab, window, Smart Tab, Settings, theme, editor, project, and dialog controls.
- Hovering an action requests the portable named `default` cursor, with an X11 arrow fallback, and restores the inherited cursor on leave so terminal, text-entry, and resize cursors retain their own semantics.
- Existing tooltip copy is preserved; labeled native buttons receive a concise fallback when needed, while compact or ambiguous actions keep explicit descriptive tooltips.
- Extended the rendered Settings gate to prove the standard pointer and nonempty tooltip contracts on New Tab, Settings, Close NOCTTY, and per-tab Close without regressing inline rename or exact-tab close.
- Acceptance met: Zig checks plus rendered Settings, tab-rename, and two-tab interaction gates pass on the compositor-capable host.

### NCT-054 Yakuake-density compact tabs — done

- Matched the installed Yakuake Breeze skin's 22-pixel tab geometry with a theme-safe NOCTTY target of 22–24 logical pixels instead of allowing Plasma GTK defaults to inflate the strip to roughly 39 pixels.
- Added a scoped native GTK notebook style for zero-margin tab/header layout, compact horizontal padding, 22-pixel row actions, and an 18-pixel per-tab close control without changing terminal, dialog, or Settings sizing.
- Reduced title overflow from 24 to 18 characters, replaced the longer `· multi` suffix with an exact compact `×N` pane count, and retained the complete title and pane state in tooltips.
- Fixed dynamically created tabs showing only their label while leaving the close child unmapped, then extended the real two-tab gate with a `compact_tabs=true` contract that bounds strip height, tab width, a visible 18-pixel close control, and row-action size; inline rename and scale-2/high-contrast regressions remain green.
- Acceptance met: Zig checks, rendered two-tab, inline-rename, Settings, and HiDPI/theme gates pass on the compositor-capable host.

### NCT-055 Peacock-style per-tab color accents — done

- Added a native `Tab Color` submenu to each exact tab's right-click menu with Default plus Red, Orange, Yellow, Green, Cyan, Blue, Purple, and Pink presets.
- Colored tabs keep contrast-aware title/close treatment, preserve the compact 22–24-pixel geometry, and identify their hue and shade in the full tab tooltip.
- Added reversible `Ctrl+Alt+=` lighten and `Ctrl+Alt+-` darken actions for the active tab, mirrored in the command palette and shortcut card; an uncolored tab starts from Blue when either shade action is used.
- Kept preset and bounded shade state in the Zig workspace model, marked color changes dirty, and added version-5 snapshot export/import with backward compatibility for earlier workspaces.
- Added the compositor-backed `native_grid_tab_color_smoke` for real menu activation, rendered RGB/contrast, both keyboard paths, exact shade reversal, model state, and snapshot persistence.
- Acceptance met: Zig checks/tests and the rendered native tab-color smoke pass on the compositor-capable host.

### NCT-056 Direct pane and Smart Tab keyboard cycling — done

- Added `Ctrl+Tab` to advance through the visible live terminal panes on the current tab with wraparound and real GTK focus/model synchronization.
- Smart Tab-filtered and zoom-hidden panes are skipped, so the shortcut never hands input to a pane the user cannot see.
- Added `Ctrl+Shift+Tab` to advance through ordinary tabs and their active Smart Tab-filtered views while preserving the selected tag; `Ctrl+PageUp` and `Ctrl+PageDown` remain available for explicit previous/next tab movement.
- Extended the compositor-backed `native_grid_tab_navigation_smoke` to drive both new key paths through the real GTK handler before rechecking legacy tab cycling, close/reopen, and terminal focus restoration.
- Acceptance met: Zig checks/tests and the rendered navigation receipt pass on the compositor-capable host.

### NCT-057 Settings window stacking — done

- Settings now has an explicit transient parent, destroy-with-parent lifecycle, dialog type hint, and always-above request relative to the owning NOCTTY window.
- Plasma Wayland dropdown mode gives Settings its own `noctty-settings` overlay-layer surface and temporarily lowers the main dropdown to the top layer, guaranteeing the dialog remains visible above it; closing Settings restores the dropdown's overlay layer.
- X11 and ordinary Wayland window modes retain native window-manager stacking through the transient and keep-above relationship.
- Added `native_grid_settings_stacking_smoke`, which renders the real dialog on Wayland and X11 and requires both windows visible, parent ownership, compositor stacking, and parent-layer restoration.
- Acceptance met: Zig checks/tests and the rendered cross-backend Settings stacking matrix pass.

### NCT-058 Hold-Alt workspace-note overlays — done

- Holding either Alt key now reveals the saved workspace quick note as a compact tooltip overlay in every visible pane on the current tab; releasing Alt hides all copies immediately.
- The overlay is drawn directly on each native terminal surface, supports UTF-8 and multiline notes, wraps to at most three lines, stays within a 320×92-logical-pixel budget, and reserves no layout space.
- Smart Tab- and zoom-hidden panes remain excluded because only mapped terminal surfaces are redrawn; losing window focus or hiding the dropdown also clears the overlay so it cannot become stuck.
- Existing `Alt+Arrow` directional focus remains intact and shows the note while Alt is held, while the persisted note continues to use the single Zig workspace model edited through `Ctrl+Shift+N`.
- Added `native_grid_note_overlay_smoke`, which renders a multiline UTF-8 note over two panes on Wayland and X11 and proves Alt press, every-visible-pane drawing, compact bounds, release-to-hide, and clean PTY exit.
- Acceptance met: Zig checks and the rendered cross-backend Alt-note overlay matrix pass.

### NCT-059 Crash-safe hot-session recovery — done

- Every user-visible workspace mutation now marks recovery state and writes through to the atomic XDG-state hot-session snapshot; settings continue to persist immediately through their separate versioned config file.
- Normal startup loads the hot session before creating terminal surfaces, then reconstructs every saved native tab, pane, recursive split, divider ratio, active tab/pane, manual title, tab color, tag/selection, Smart Tab filter, pane profile, quick note, broadcast state, and working directory.
- Divider movement now updates the Zig-owned split ratio and coalesces atomic writes, so custom matrix widths and heights survive a crash instead of reverting to preset proportions.
- Snapshot version 6 adds the Smart Tab tag while retaining imports from versions 1–5. Structural validation rejects duplicate IDs, cycles, orphan nodes, invalid leaves, and malformed roots before any live UI is replaced.
- A missing or corrupt hot session falls back to a clean one-tab workspace without preventing NOCTTY from opening. Shell processes are restarted in their saved directories; impossible process-memory resurrection is not claimed.
- Added `native_grid_hot_session_smoke`, which restores two customized tabs and five live panes through the real recursive GTK host on Wayland and X11, checks ratios/titles/colors/tags/filter/profile/settings/cwd, and proves corrupt-snapshot fallback.
- Acceptance met: Zig checks/tests and the rendered cross-backend hot-session matrix pass.

### NCT-060 Alt-wheel pane cycling feedback — done

- Holding Alt while scrolling down advances to the next visible terminal pane on the current tab; Alt+scroll up moves to the previous pane, with wraparound.
- Traversal reuses the live GTK focus path and therefore updates the Zig active-pane identity without disturbing the user's multi-pane tag selection. Smart Tab- and zoom-hidden panes are excluded.
- Smooth wheel deltas accumulate into whole navigation steps instead of racing through panes.
- Every accepted step paints an 800 ms native blue focus frame and `Pane n / total` chip over the target terminal without reserving layout space; a one-visible-pane view still confirms its target.
- Extended `native_grid_tab_navigation_smoke` across Wayland and X11 to prove both directions, current-tab confinement while another tab exists, hidden-pane exclusion, rendered feedback, model synchronization, and clean session exit.
- Acceptance met: the cross-backend navigation matrix passes.

### NCT-061 Ctrl+Alt-wheel tab cycling feedback — done

- Holding Ctrl+Alt while scrolling down selects the next tab; Ctrl+Alt+scroll up selects the previous tab, with wraparound through ordinary and Smart Tab-filtered views.
- The interaction reuses the notebook's established page-switch and focus handoff path, preserving the active Smart Tab tag while keeping GTK and Zig tab/pane identity synchronized.
- Smooth wheel deltas accumulate into bounded whole navigation steps rather than racing across tabs.
- Every accepted step paints a distinct 800 ms native purple frame and `Tab n / total` chip over the focused terminal without reserving layout space.
- Extended the Wayland/X11 `native_grid_tab_navigation_smoke` to prove both directions, last-to-first wraparound, rendered tab feedback, Smart Tab preservation, model synchronization, and clean session exit.
- Acceptance met: the cross-backend navigation matrix passes.

### NCT-062 Pane-local terminal control chords — done

- Plain `Ctrl+C` now writes one ETX directly to the focused terminal session, bypassing broadcast fan-out even when broadcast mode is enabled; `Ctrl+Shift+C` remains copy.
- Plain `Ctrl+D` now invokes the existing model-first exact-pane close lifecycle instead of forwarding EOT to the shell. GTK split collapse, PTY/timer teardown, hot-session dirty state, and surviving-pane focus are shared with `Close Terminal`.
- The final terminal remains protected: `Ctrl+D` is consumed without leaking EOT when no valid pane removal exists.
- Added `native_grid_terminal_chords_smoke`, which runs two live panes with broadcast enabled on Wayland and X11, proves exactly one ETX reaches the active pane, proves zero ETX reaches its neighbor, proves no EOT reaches either PTY, closes the exact active pane, and verifies focus plus final-pane protection.
- Acceptance met: Zig checks/tests and the rendered cross-backend terminal-chord matrix pass.

### NCT-027 Keyboard tab navigation and reopen — done

- Added `Ctrl+PageUp`, `Ctrl+PageDown`, `Ctrl+Shift+W`, and `Ctrl+Shift+T` handling, plus a single-entry workspace closed-tab snapshot for genuine reopen behavior.
- `Ctrl+Shift+T` falls back to a fresh tab when no closed tab is available.
- Added the compositor-backed `native_grid_tab_navigation_smoke`, which drives the real GTK key handler for next/previous cycling, shortcut close, shortcut reopen, and focus restoration.
- Acceptance met: repeated native smoke runs pass on the compositor-capable host, with focus restored after reopening.

### NCT-028 Tab title fallback and overflow polish — done

- Added shell-title, working-directory basename, and numbered fallback precedence; long compact titles now use a visible ellipsis while tooltips retain the full title.
- Explicit user-renamed titles remain durable and authoritative.
- Added the compositor-backed `native_grid_tab_title_smoke`, covering empty shell-title fallback, long-title ellipsis, full-title tooltip text, manual rename precedence, and clean PTY exit.
- Acceptance met: the native title smoke passes on the compositor-capable host.

### NCT-029 Tab attention and dirty indicators — done

- Added an independent unsaved-workspace marker beside the status/attention dot without replacing tab names.
- Attention clears on focus and session exit; the dirty marker follows the app recovery dirty state and clears through the existing save path.
- Added the compositor-backed `native_grid_tab_dirty_smoke`, covering attention and dirty marker appearance, attention/session-exit clearing, saved dirty-state clearing, and title preservation.
- Acceptance met: the native indicator smoke passes on the compositor-capable host.

### NCT-030 Tab reorder interaction — done

- Added GTK notebook drag reordering, stable tab-ID model dispatch, active-tab identity preservation, and snapshot-backed ordering.
- GTK supplies the native insertion indicator during drag.
- Preserved the pre-drag active page when a background tab is moved instead of activating the moved tab unconditionally.
- Added the compositor-backed `native_grid_tab_reorder_smoke`, covering real notebook reorder, active identity, model order, snapshot save/load order, and clean PTY exit.
- Acceptance met: the native reorder smoke passes on the compositor-capable host.

### NCT-031 Rename-tab command palette action — done

- Added a `Rename active tab` command-palette action and `Ctrl+Shift+R` keyboard path.
- Reuses the inline tab-label editor, local validation, model dispatch, cancel, and focus-restoration boundary without opening a dialog.
- Added the compositor-backed `native_grid_palette_rename_smoke`, covering palette invocation, fuzzy action selection, empty-name validation, commit, cancel, focus restoration, title preservation, and clean PTY exit.
- Acceptance met: the native palette rename smoke passes on the compositor-capable host.

### NCT-032 Broadcast input delivery — done

- Native keyboard, IME, and clipboard input now route through the live pane-context set when broadcast is enabled.
- Tagged panes receive input exclusively when a selection group exists; with no tagged panes, every live pane in the active tab receives it. Broadcast-off input remains focused-pane-only.
- Verified by build and the compositor-backed native workspace smoke; the workspace model regression continues to cover selected-pane and all-pane target calculation.

### NCT-033 Incremental syntax highlighting and portable editor themes — done

- Added the canonical TextMate/Sublime scope vocabulary to the existing bounded editor spans and a compact native syntax-theme resolver.
- Added VS Code/TextMate `tokenColors` import support for editor foreground/background, scope rules, and bold/italic/underline styles, with owned bounded rule storage.
- Tree-sitter parser-first dispatch now sits behind the Zig editor boundary; the bounded highlighter remains the fallback for plain text, unsupported languages, parser failures, and large-file policy paths.
- Start with bundled Zig, JSON, Markdown, C, and Shell grammars. Audit each grammar license independently; only MIT, CC0, or otherwise explicitly approved permissive assets may ship.
- Convert Tree-sitter highlight captures into the established hierarchical TextMate/Sublime scope vocabulary (`keyword`, `string`, `comment`, `constant.numeric`, `entity.name.function`, `entity.name.type`, `variable`, `invalid`, and related scopes).
- Add a compact native NOCTTY theme model for editor globals and scope rules, with VS Code/TextMate `tokenColors` import compatibility first and optional Sublime `.sublime-color-scheme` import later.
- Preserve the native Zig plus C ABI architecture: no Node.js, Electron, browser runtime, Rust runtime, or proprietary Sublime syntax engine dependency.
- Acceptance met: incremental edits update spans, themes apply across the initial language set, unsupported files remain readable/editable, and native/editor smoke covers highlighting, theme reload, fallback behavior, and the license manifest.

### NCT-034 Tree-sitter grammar and native editor rendering — done

- Vendored and recorded MIT revisions for the Tree-sitter C runtime plus JSON, C, Bash, Markdown, and Zig grammar sources.
- Compiled the runtime and JSON/C/Bash generated parsers directly into the native Zig build; the former C adapter is now owned by `src/TreeSitter.zig`.
- Added an incremental document API, Tree-sitter query captures, canonical scope-to-span conversion, and App-level parser-first dispatch with fallback to the bounded highlighter.
- Compiled the generated MIT Zig parser source and routed Zig through the same parser-first path; the existing editor highlight receipt remains stable.
- The editor load flow proves editable, large read-only preview, and metadata-only hard-limit fallback behavior.
- Persisted syntax-theme selection in config version 3 with backward-compatible defaults and fresh-App reload proof.
- Acceptance met: native/editor smoke proves incremental highlighting, syntax-theme reload, fallback behavior, large-file fallback, capture coverage, and grammar license-manifest completeness without Node.js, Electron, browser, or Rust runtime dependencies.

## 2026-07-12

### NCT-063 Live Grid Layout Presets — done

- Fixed `Layout 2×2` and `Layout 3×3` in the terminal context menu updating only Zig pane records while leaving the native window unchanged. The clicked tab now grows to four/nine real `TerminalSession` and drawing contexts, receives a bounded canonical pane-order receipt, and rebuilds only that GTK page.
- Added balanced row-major `GtkPaned` reconstruction and matching proportional Zig split ratios. Three-way rows/columns use one-third then one-half division instead of the prior recursive 50/25/25 geometry. Existing sessions survive preset changes; `Layout 1×1` closes eight surplus PTYs/timers through the exact pane teardown path and focuses the survivor.
- Added `scripts/native_grid_layout_preset_smoke.sh`. The live context-menu gate keeps each popup usable across focus loss, activates 2×2, 3×3, and 1×1 in sequence, requires 4/9/1 model-render-session agreement, checks two/three balanced coordinate bands, proves eight surplus PTYs close, and finishes through the remaining terminal lifecycle.

### NCT-026 Pane-context Terminal Close — done

- Added `Close Terminal` to the native terminal-surface context menu. The exact clicked pane dispatches through a typed `App.close_pane`/`Workspace.closePane` boundary before GTK changes, while the application's final terminal is disabled in the menu and rejected by the model.
- Added topology-preserving `SplitLayout.removePane`: it copies only reachable survivors, promotes the removed leaf's sibling, retains split axes and ratios, clears zoom, chooses a stable active pane, and closes an emptied tab only when another tab can survive. The native host stops the exact pane's sources and PTY, collapses its `GtkPaned`, and keeps root window/tray/maintenance ownership alive when pane 1 closes.
- Added `scripts/native_grid_pane_close_smoke.sh`. The live GTK gate right-clicks primary pane 1, keeps the popup and window mapped across focus loss, activates the exact action, requires Zig/GTK/PTY removal and split collapse, focuses pane 2 through its lifecycle, and proves the remaining terminal cannot be closed. Workspace/App tests cover exact removal, topology, inactive focus preservation, sole-pane tab closure, missing panes, and final-terminal rejection.

### NCT-025 Persistent New-tab Button — done

- Added a compact themed `list-add-symbolic` button in GTK's notebook start-action slot, placing an accessible `New Tab` control before the default tab. It routes through the current notebook page and existing Zig new-tab/session boundary.
- Kept the one-tab row visible so `+` remains available at startup and after tab closure; pane zoom still hides the whole row temporarily. Closing a tab now severs retired peer links, and reuse is restricted to live pristine peers so a later click cannot revive a stopped PTY.
- Strengthened `scripts/native_grid_two_tab_smoke.sh` to inspect the real icon, accessible name, start placement, and mapped one-tab row; click it to create tab 2; close original background tab 1; click it again to require a fresh context/session; and clean up to one focused surviving tab. The compact-UX gate separately proves zoom hides and restores the row/action.

### NCT-024 Right-click Tab Close — done

- Added a native `Close Tab` menu on compact tab labels. The clicked tab page resolves to a stable Zig tab ID, and the GTK page is removed only after `Workspace.closeTab` accepts the request; closing the final tab is disabled in GTK and rejected by the model.
- Closing a tab stops every pane's tick/blink/resize timers on that page and idempotently closes each PTY while retaining session/grid storage for normal teardown. Closing the original root tab keeps host control, focus-loss, tray, shortcut, and maintenance ownership alive and routes later focus/settings actions to the surviving context.
- Extended `scripts/native_grid_two_tab_smoke.sh` to right-click background tab 1 while tab 2 is active, keep the popup usable, close the exact model/page/session, restore the persistent one-tab row, focus tab 2, and finish its independent lifecycle. Workspace tests separately prove multi-pane model removal and last-tab rejection.

### NCT-023 Context-menu Embedded Editor And Focus-loss Safety — done

- Added the historical `Open Editor Here` route to the terminal context menu and compact command palette. It resolved the right-clicked pane's live PTY working directory with a workspace-cwd fallback, opened the former embedded editor's native file list there, supported folder navigation, and activated UTF-8 files through the existing Zig load/edit/read-only/atomic-save boundary. NCT-103 superseded this product route with standalone `Open NoctEd Here`.
- Fixed drop-down focus-loss hiding racing GTK popup ownership. The host defers hiding while its tracked context menu or GTK grab is active, preserves the main window while owned transient dialogs are visible, and rechecks after menu dismissal without weakening explicit F10/D-Bus menu cleanup.
- The historical project/editor smoke used a nested `src/open_here.zig` fixture to exercise the embedded route. The maintained gate now proves the same focus-safe menu path, exact pane-cwd resolution, and separate NoctEd process handoff; NoctEd's own native matrix owns rendered edit/save proof.

### NCT-022 Ctrl+Wheel Font Scaling — done

- Added native `Ctrl+mouse-wheel up/down` font scaling on every terminal surface. Discrete wheels change one point per notch; smooth-scroll input accumulates before applying bounded steps, and the gesture is consumed before terminal scrollback or application mouse reporting.
- Font changes apply to every live pane, clamp to the Zig-configured 7–28 pt range, recompute Cairo cell metrics and PTY columns/rows, and persist through the same atomic GUI configuration path used by Settings. New panes inherit the current size.
- Extended the rendered compact-UX gate to prove increase, decrease, all-pane propagation, ordinary unmodified wheel scrolling, and fresh-App configuration reload.
- Superseded by NCT-049: Ctrl+wheel is now pane-local and workspace-persisted; Settings retains the global font-default path.

### NCT-021 Free Window Resize And Native Tray — done

- Preserved NOCTTY's borderless chrome while adding eight six-pixel compositor resize zones around normal windows. Dropdowns expose the compatible side, bottom, and bottom-corner zones; their manual layer-shell drag path updates the existing persisted width/height settings and live terminal grid dimensions.
- Added a dependency-free native `org.kde.StatusNotifierItem` implementation. Plasma's watcher receives the stable icon name plus a real PNG-derived ARGB fallback, the item remains Active while hidden, primary activation toggles NOCTTY, secondary activation opens Settings, tooltip state follows visibility, and watcher restarts trigger re-registration. The current item also exports a standard `com.canonical.dbusmenu` right-click surface with Show/Hide, Settings, and clean Close actions.
- Added `--native-grid-window-tray-smoke` and `scripts/native_grid_window_tray_smoke.sh`. The live Plasma/Wayland gate requires all eight resize routes, an accepted outer geometry change, watcher enumeration, icon delivery, hide/show and Settings activation, exact menu layout, Close-driven PTY shutdown, and clean tray/menu teardown.

### NCT-020 Yakuake-style Settings Window — done

- Replaced the single long GTK settings form with a compact list-style dialog modeled on Yakuake's current Window, Behavior, and Appearance page structure. A narrow system-icon sidebar keeps all three categories visible while the content stack shows only the selected grouped page.
- Reorganized every existing live control without changing its Zig event or persistence boundary: mode, shortcut, drop-down geometry, focus, pane profile, notifications, theme, font, tabs, status, padding, and spacing remain GUI-configurable.
- Strengthened `--native-grid-settings-smoke` and both settings wrappers to require exactly three categories and a real sidebar-to-stack switch before the existing action, persistence, reload, and clean-exit receipts can pass. The rendered lane passes on the current Wayland session and through XWayland.

### NCT-019 Live Terminal Resize Dimensions — done

- Added a native Cairo resize OSD to every Zig-grid terminal surface. After initial layout settles, any grid-size change from a split divider, dropdown bottom grip, or ordinary window edge shows the current unit-free `columns × rows` value centered over the affected terminal without reserving space.
- The OSD updates on every accepted PTY/grid resize, restarts one 750 ms settle timer while movement continues, and then disappears. A compact rounded translucent treatment remains readable in normal and high-contrast themes.
- Added `--native-grid-resize-overlay-smoke` and `scripts/native_grid_resize_overlay_smoke.sh`; the rendered two-pane gate moves a real GTK divider twice and requires initial suppression, both pane overlays, current grid values, repeated live updates, Cairo draw evidence, 750 ms timeout, clean hiding, and independent PTY exit.

### NCT-018 Selection-safe Double-click Pane Zoom — done

- Fixed the GTK button sequence where the first click initialized selection, the double-click changed pane geometry, and the trailing release was then interpreted at the resized coordinates as a drag endpoint.
- Double-click zoom/restore now clears transient and completed selection state before toggling, consumes exactly the trailing primary-button release, and resets a stale suppression token on focus loss or the next ordinary press. Terminal mouse-reporting mode is unchanged.
- Strengthened `scripts/native_grid_click_focus_smoke.sh` to drive real press/release/double-click/release sequences through both zoom and restore, require no selection after either gesture, and separately prove ordinary Button-1 drag selection still works.

## 2026-07-11

### NCT-017 Double-click Tab Rename — done

- Wrapped each compact notebook label in a native event target so a left-button double-click replaces the label itself with a borderless native entry, matching Yakuake's direct tab-title interaction without a popup. Enter commits; Esc or clicking any other element cancels without changing the title; invalid blank/control/oversized names stay in the inline editor; and terminal focus returns after keyboard commit/cancel.
- Routed rename through `App.dispatch` into Zig-owned workspace state. Manual names override live shell titles only after the user renames a tab, mark recovery/autosave state dirty, and persist through workspace snapshot format version 4 while version 1–3 imports remain supported.
- Added `--native-grid-tab-rename-smoke` and `scripts/native_grid_tab_rename_smoke.sh`; the rendered gate creates a second independent tab, drives the double-click handler, proves the editor is embedded with no popup, cancels a draft through an outside terminal click, commits `Build logs` with Enter, and checks the visible compact label, Zig model, dirty state, exported/imported snapshot, focus restoration, and both PTY lifecycles.

### NCT-016 Noctalia Shell Support — done

- Added a first-class `noctalia_wayland` backend with exact Niri, Hyprland, Sway, Scroll, Labwc, and MangoWC detection while keeping Plasma, generic Wayland, X11, and headless capability boundaries distinct.
- Added the native `com.noctty.NOCTTY` D-Bus control endpoint and `noctty --status`, `--show`, `--hide`, `--toggle`, and `--hidden` commands. Compositor autostart hides only after activation is ready; ordinary launch stays visible and duplicate launcher activation targets the running instance.
- Promoted the default Zig-grid dropdown to GTK layer-shell with the `noctty-dropdown` namespace, overlay placement, configured symmetric width margins, no exclusive zone, and keyboard focus while mapped. Desktop notification modeling now names the shared freedesktop transport rather than a KDE-only service.
- Extended the rendered Settings dialog with the same supported key recorder. Plasma re-registers before persistence; Noctalia-compatible sessions persist the key and `--noctalia-plan` serializes its current value into compositor-owned bindings.
- Installed documented F10/autostart fragments for all six Noctalia compositors plus an optional v5 compact `custom_button`; Debian/RPM/Arch manifests and dependency bundles now require or copy `gtk-layer-shell` explicitly.
- Deterministic proof: `scripts/noctalia_integration_smoke.sh` covers v4-compatible/v5 plans, all six serializers, backend/transport selection, and installed artifacts. Live Wayland proof: `scripts/native_grid_noctalia_ipc_smoke.sh` covers layer-shell, hidden readiness, status/show/hide/toggle, single-instance routing, and clean exit. The rendered Settings smoke captures/persists/reloads F11.
- Proof boundary: the current host runs Plasma Wayland and has none of Noctalia's six compositors installed. Shared protocols are live-proven and each compositor contract is source-checked; final per-compositor release acceptance remains an external-session checklist row rather than a false six-session claim.

### NCT-015 Compact Power UX — done

- Adapted low-chrome interactions from Wave Terminal, PrettyMux, and Yakuake as independent native GTK/Zig behavior: fuzzy command palette, scrollback-wide find and atomic save, workspace quick notes, reversible pane zoom, geometry-aware Alt+Arrow focus, shortcut card, theme/tab cycling, BEL attention dots, and GTK IM composition.
- Hid the tab strip for a one-tab or zoomed workspace; NCT-025 later superseded the one-tab rule with a persistent compact row and leading New Tab action, while zoom still hides the row and panes still have no title bars.
- Wired persisted drop-down width/height, reveal timing, focus-loss hiding, optional pointer focus, animated reveal, same-directory tab/split creation, and a four-pixel bottom resize grip.
- Added version-1 settings migration, version-3 workspace quick-note persistence, model/unit coverage, `--native-grid-compact-ux-smoke`, and release-matrix integration.
- Proof: `zig build test`, `zig build check`, `scripts/native_grid_compact_ux_smoke.sh`, `scripts/native_grid_settings_smoke.sh`, `scripts/verify.sh`, and `scripts/native_release_smoke.sh`.

### NCT-010 Verification And Packaging — done

- Completed headless tests/checks, Wayland/X11 mode and clipboard matrices, dynamic tab/split lifecycle gates, physical X11 GlobalAccel activation, rendered settings/theme/project/editor/maintenance/workspace lanes, and scale-2 font/high-contrast proof.
- Added normalized single-build install tarballs, SHA-256 sidecars, desktop/AppStream/icons/license install wiring, a same-architecture dependency bundle with copied runtime libraries, and structural/available-parser Debian/RPM/Arch checks. NCT-075–077 supersede the former broad reproducibility and package-proof wording.
- Added an x86_64/aarch64 release workflow and consolidated `scripts/native_release_smoke.sh`; the refreshed local x86_64 bundle reports 85 bundled libraries and passes its launcher/version check.
- External release operations remain explicit: artifact signing/publication requires release credentials, and Wayland physical HID injection requires interactive compositor consent. Neither is represented as automated local proof.

### NCT-002 libghostty Integration — closed by supported native replacement

- Confirmed from the installed public package and pinned upstream `53bd14f` build that Ghostty exposes VT utilities but no supported Linux GUI platform-surface ABI; upstream surface creation remains `platform=invalid` on Linux.
- Rejected the private package-owned `libghostty.so` as an unsafe ABI dependency and retained the isolated probe/adapter for future upstream availability.
- Completed the intended user-visible lifecycle through NOCTTY's Zig PTY/VT grid and native GTK surface instead. No Ghostty-rendering claim is made and no fork is maintained.

### NCT-011 Zig-Native PTY — done

- Zig owns PTY creation, fixed-argv child setup, interactive shell lifecycle, nonblocking I/O, resize, exit status, foreground metadata, resource sampling, and teardown directly through libc/POSIX declarations.
- `TerminalSession` feeds the PTY into the default native grid; dynamic tab/split activation runs independent sessions and the VTE host is only an explicit fallback.
- PTY, session, dynamic tab, and dynamic split gates all pass.

### NCT-012 Zig Terminal Grid and Public VT Boundary — done

- Completed the renderer-neutral Zig screen model for the supported release matrix: UTF-8, cursor/addressing/save/restore, scroll regions/history, alternate screen, line/character editing, erase, insert/autowrap/tab modes, ANSI colors/styles, OSC title, bracketed paste, mouse/focus/application-cursor modes, and resize.
- Only the published `libghostty-vt` paste utility crosses the Ghostty boundary; no private GUI ABI is used.
- Unit tests, VT smoke, terminal-session smoke, and live native rendering gates cover the boundary. Additional emulator compatibility sequences are future compatibility work rather than an embedding blocker.

### NCT-014 Native Grid Drawing Surface — done

- Replaced VTE as the default with the GTK/Cairo surface backed by Zig `TerminalSession` cells.
- Completed Unicode/ANSI rendering, cursor/status/title/scrollback, keyboard/mouse/focus/resize, drag selection/copy, safe clipboard paste, dynamic notebook/split sessions, settings/themes, project/editor dialogs, and pane lifecycle routing.
- Made C-ABI cell/style reads bounds-safe so a stale GTK draw immediately after pane reparent/resize renders blank default cells rather than panicking on obsolete dimensions.
- Physical X11 F10 proof now covers hidden startup, Plasma GlobalAccel delivery, visible activation, and cleanup; dropdown/windowed/zen, two-pane, and two-tab display gates pass.

### NCT-003 Terminal Workspace UX — done

- Completed native notebook-tab and split presentation with independent Zig PTY/VT sessions and stable pane lifecycle routing.
- Added keyboard and context-menu actions for new tab, split left/down, 1x1/2x2/3x3 layouts, pane focus, replace/add/toggle selection, and confirmed broadcast toggle.
- Added ownership-preserving Zig pane movement between tabs, exposed by context menu and GTK middle-button drag/drop targets. The live GTK drawing area/session now reparents with the model, source/destination split trees rebuild, and moving a last pane closes the empty source tab.
- Replaced the fixed primary/secondary host pair with on-demand session contexts and recursively nested GTK panes. Midpoint divider placement and maintained four-pane plus balanced eight-pane gates prove repeated splitting, vertical Split Down, horizontal Split Left, dynamic tabs, pane movement, hover-safe drag selection, broadcast, and click-to-focus command routing without a hardcoded two- or four-terminal ceiling.

### NCT-008 Project Workspaces — done

- Completed binary workspace snapshots and atomic save/load for tabs, panes, layouts, cwd/worktrees/tags, selections/status, profiles, project rows, recovery state, and IDs.
- The default host scans files and available Git status/graph data into a rendered native Project Workspace panel; GTK save/open file choosers route snapshot work back through Zig.
- The native GLib timer now executes due autosave, project refresh, and recovery-cleanup receipts rather than stopping at planning.
- Proof: `--native-grid-project-editor-smoke`, `--native-grid-maintenance-smoke`, existing parser/storage tests, and `./scripts/verify.sh`. Git runners activate when launched from a checkout with usable Git metadata.

### NCT-009 Lightweight Code Previewer/Editor — done

- Completed the Zig text-buffer/editor core with multiple selections/edits, undo/redo, search, syntax spans, common-language detection, worktree metadata, large-file policy, dirty/revision tracking, and read-only enforcement.
- Added a rendered native monospace editor opened from the Project Workspace panel, with native file selection, editable text buffer, Save control, Zig document loading/editing, and atomic writeback.
- The project/editor smoke proves rendered open, supplied-file load, full-buffer edit, Zig dirty/revision path, and saved file contents; focused CLI/tests retain find, syntax, multi-edit, and large-file coverage.

### NCT-006 Theme Compatibility — done

- Completed built-in themes plus Ghostty, Xresources, and simple Alacritty import parsing, preview summaries, install/replace/select state, and binary theme-library persistence.
- Added a native Theme Library dialog with built-in selection, preview affordance, and a GTK file chooser that routes imported contents back to Zig for parsing and installation.
- Imported libraries and the selected default theme persist separately and reload on default startup.
- `--native-grid-theme-smoke` proves rendered library presentation, Ghostty import, selection, both persistence files, and fresh-App reload; parser tests cover Xresources and Alacritty.

### NCT-005 GUI Configuration — done

- Added a native-grid Settings dialog reachable from the terminal context menu with window mode, tab position, font family/size, theme, status indicator, panel padding/spacing, KDE notifications, and pane profile preset controls.
- Tab position now updates the live GTK notebook immediately and is applied from loaded configuration during host startup.
- Every control dispatches through the Zig `App` command model and atomically persists the native binary settings snapshot; default startup reloads it without manual file editing.
- The established GUI shortcut recorder remains the key-recording surface and persists only after successful Plasma registration.
- `--native-grid-settings-smoke` proves rendered controls, pane preset application, atomic persistence, and fresh-App reload.

### NCT-004 Agent Status Signals — done

- Completed idle/running/pending/done/error/long-running state modeling, stable pane routing, compact tab counts, detailed tooltip summaries, and configurable background/border color plans.
- The default native grid now renders a one-pixel running/done/error border and live pane-status tooltip text.
- Terminal exit uses `org.freedesktop.Notifications.Notify` when the existing GUI setting is enabled; the display-backed smoke requires a returned notification ID.
- Proof: `--native-grid-notification-smoke`, `scripts/native_grid_notification_smoke.sh`, `zig build test`, and `./scripts/verify.sh`.

### NCT-007 Clipboard Safety — done

- Completed unsafe-control stripping, shell one-line repair, heredoc literal preservation, existing bracket-marker normalization, bracketed-paste wrapping, selected-grid copy, and native GTK clipboard copy/paste.
- Ctrl+Shift+V remains asynchronous in the product path; the live gate verifies that bracketed paste does not execute until a separate Enter keystroke.
- `scripts/native_grid_clipboard_smoke.sh` passes on both Wayland and X11 and proves clipboard readback, Zig paste safety, PTY delivery, rendered output, and clean exit.
- Proof: `zig build test`, `zig build check`, `./scripts/verify.sh`, and the display-backed clipboard matrix.

### NCT-013 PTY-to-VT Terminal Session — done

- `src/terminal/Session.zig` now owns PTY spawn, resize, output pumping, VT-grid updates, title capture, and child exit.
- `--terminal-session-smoke` proves `pty=true vt=true grid=true title=true exited=true`.
- The session contract is consumed by the default native grid surface and by independent dynamic tab/split sessions.
- Proof: `zig build test`, `zig build check`, `zig build run -- --terminal-session-smoke`, and `./scripts/verify.sh`.

### NCT-001 Native Plasma Host — done

- Built and verified the native GTK host boundary for KDE Plasma Wayland and X11.
- Completed dropdown, centered borderless windowed, and zen fullscreen modes while keeping terminal client chrome thin.
- Completed configured global shortcut registration with default F10, availability/accepted-key validation, conflict/failure handling, and GUI recorder-driven live re-registration with persistence only after successful registration.
- End-to-end proof passed for Wayland layer-shell dropdown, X11 top-edge dropdown, X11 windowed, X11 zen fullscreen, shortcut conflict, recorder persistence, terminal lifecycle, resize/input/output, and maintenance-tick delivery.
- Tabs/splits and distribution packaging are closed by NCT-003 and NCT-010 above.

### NCT-001 native window mode and live shortcut re-registration slice

- Added live borderless windowed and native zen-fullscreen mode selection to the GTK host alongside dropdown/layer-shell mode.
- Removed the local F10 hardcode from native key handling; the configured encoded shortcut now controls local activation consistently with Plasma GlobalAccel registration.
- Added windowed and zen-fullscreen native smoke commands and kept conflict/failure recorder feedback visible while successful captures re-register and persist.
- Proof: `zig fmt src/main.zig`, isolated-cache `zig build test`, isolated-cache `zig build check`, `./scripts/check_native_layout.sh`, and elevated `NOCTTY_RUN_NATIVE_SMOKE=1 ./scripts/ci_verify.sh`.
- Live evidence: Wayland dropdown `placement=wayland_layer_shell`, X11 dropdown `placement=x11_top`, X11 windowed `placement=windowed`, and X11 zen `placement=fullscreen`; all report terminal input/output/resize/exit, shortcut registration, and maintenance-tick success.

### NCT-008 native maintenance timer delivery slice

- Connected the native GTK/GLib event loop to the existing Zig maintenance tick dispatch through a periodic timer callback.
- Added display-bound smoke evidence requiring at least one delivered maintenance tick while preserving receipt-driven autosave, project-refresh, and recovery-cleanup execution.
- Updated the structural native-layout guard and current-facing docs to record timer delivery without overstating scheduled work execution.
- Proof: `zig fmt src/main.zig`, `./scripts/verify.sh`, `./scripts/ci_verify.sh`, `zig build run -- --maintenance-plan`, and `zig build run -- --self-check`.
- At that slice's point-in-time, compositor smoke was environment-dependent; the final 0.1.0 live maintenance and release-matrix proof is recorded in the parent closures above.

## 2026-07-10

### NCT-005 physical recorder input slice

- Added an X11/XWayland smoke lane using `xdotool` to inject `Ctrl+Home` into the rendered recorder dialog.
- Required the live capture to persist and reload as `configured_key=Home configured_ctrl=true`.
- Replaced the hanging per-window ImageMagick capture with a bounded `spectacle` desktop screenshot cropped to the recorder window geometry from `xdotool`; current proof is 462×107 with 1,246 colors.
- Proof: direct X11 HID run and the maintained `shortcut-hid` lane, with `mode=shortcut_hid ... configured_key=Home configured_ctrl=true ... status=done`.
- Still open: Wayland physical input tooling and equivalent cropped proof, HIDPI/theme rendering, broader settings UI, and full packaging.

### NCT-005 Wayland input capability-boundary slice

- Added `scripts/wayland_input_probe.sh`, a read-only probe for `libei` and the XDG RemoteDesktop portal keyboard transport.
- Current environment exposes `ConnectToEIS` and keyboard notification methods, but using them requires explicit compositor/user consent. NOCTTY does not silently request that permission or claim unattended Wayland HID proof.
- Proof: the probe reports `wayland_input=available requires_user_consent=true transport=xdg_remote_desktop_eis` when run in the current Plasma session.
- An explicit `CreateSession` request returned a portal request path but produced no response signal or consent UI before the request disappeared; `SelectDevices`, `Start`, and `ConnectToEIS` remain unproven.
- A monitored retry confirmed no `org.freedesktop.portal.Request.Response` signal at all; the environment blocks before the consent/device-selection stages.

### NCT-005 shortcut persistence and expanded capture slice

- Expanded the native recorder to Insert/Delete/Home/End/Page/arrow keys in addition to letters, digits, F1–F12, and modifiers.
- Persisted recorder changes atomically to the native XDG-style settings file only after confirmed GlobalAccel registration; conflict/failure remains unsaved.
- Expanded the recorder smoke to capture F11, re-register it live, save under an isolated `/tmp` home, create a fresh `App`, reload the snapshot, and require the reloaded shortcut to remain F11.
- Proof: `./scripts/verify.sh` and `GDK_BACKEND=wayland zig build run -- --native-host-shortcut-recorder-smoke`, reporting `config_persisted=true config_reloaded=true configured_key=F11`.
- Still open: physical key injection, pixel-level recorder assertions, broader settings UI, tabs/splits, multi-architecture packaging, full application packaging, and supported Ghostty rendering.

### NCT-005 rendered shortcut recorder slice

- Added a native modal shortcut-recorder dialog opened by right-clicking the live terminal.
- Captures letters, digits, F1–F12, and modifiers; Esc cancels without mutation.
- Decodes capture into the Zig `Config.KeyEvent` path, unregisters the prior action, performs safe live GlobalAccel registration, closes on success, and retains the dialog with guidance on conflict/failure.
- Added `--native-host-shortcut-recorder-smoke` to the maintained graphical gate; it requires the rendered dialog show event alongside healthy placement, terminal, shortcut registration, cleanup, and lifecycle assertions.
- Proof: `./scripts/verify.sh` and `./scripts/native_host_smoke.sh`.
- Still open: persisted save from the live recorder, navigation/editing-key capture, physical key injection/pixel assertions, broader settings UI, tabs/splits, packaging, and supported Ghostty rendering.

### NCT-001/NCT-005 configurable GlobalAccel safety slice

- Replaced the native adapter's hardcoded F10 value with Qt encoding derived from the validated Zig shortcut, including supported alphanumeric, navigation/editing, function-key, and modifier combinations.
- Added Plasma availability checking before assignment and accepted-key verification after `setShortcut`.
- Mapped registered, conflict, and failed native outcomes into existing Zig shortcut receipts; hidden startup remains restricted to confirmed registration.
- Added `--native-host-shortcut-conflict-smoke` and included it in `scripts/native_host_smoke.sh`. The lane uses F12, already owned by Yakuake here, and proves conflict receipt, visible fallback, no activation, cleanup, and no reassignment.
- Proof: `./scripts/verify.sh` and `./scripts/native_host_smoke.sh`; Wayland/X11 success lanes stayed green and the conflict lane reported `shortcut_registered=false shortcut_conflict=true shortcut_failed=false global_shortcut=false shortcut_unregistered=true`.
- Still open: rendered key-recorder re-registration and feedback UI, a deterministic denied/transport-failure fixture, physical shortcut injection, multi-architecture dependency packaging, tabs/splits, packaging, and supported Ghostty rendering.

### NCT-001 repo-local GTK3 layer-shell proof slice

- Added a pinned x86_64 GTK3 layer-shell 0.10.1 runtime fallback under `vendor/gtk-layer-shell`, including package/runtime SHA-256 values, public header, GIR metadata, package metadata, and provenance. The extracted `.PKGINFO` license field conflicts with the included `LICENSE_MIT.txt` and earlier vendor note; NCT-077 supersedes the historical resolved-license wording pending authoritative reconciliation.
- Kept system-library preference and loaded the local runtime only when `libgtk-layer-shell.so.0` is absent.
- Proved live left/right/top anchoring on Plasma Wayland with on-demand keyboard focus; the graphical lane now reports `placement=wayland_layer_shell` while retaining GlobalAccel, input, marker, resize, visibility, focus, cleanup, and lifecycle assertions.
- Stabilized smoke correlation with a per-process command marker and synchronous Plasma component invocation; X11 regression remains `placement=x11_top` with all assertions green.
- Proof: `./scripts/verify.sh` and `./scripts/native_host_smoke.sh`.
- Still open: multi-architecture dependency packaging, configurable shortcut conflict/denial flows, tabs/splits, full application packaging, and supported Ghostty rendering.

### NCT-001 protocol-specific dropdown placement slice

- Added runtime GDK backend detection and monitor work-area sizing for the dropdown.
- X11/XWayland requests full work-area width, 45% height, and the top-left work-area origin; smoke acceptance requires GTK position/size readback to match, producing `placement=x11_top`.
- Added a pre-realization dynamic probe for the GTK3 layer-shell ABI, with left/right/top anchoring, top layer, and on-demand keyboard mode when available.
- The current machine only provides GTK4 layer shell, which is not safe to mix with the GTK3/VTE host. The Wayland smoke therefore reports `placement=wayland_constrained` and does not claim exact positioning.
- Proof: `./scripts/verify.sh` and `./scripts/native_host_smoke.sh`; both lanes retained every prior assertion, X11 proved exact readback, and Wayland preserved the dependency boundary.
- Still open: provide and prove a compatible GTK3 layer-shell runtime, configurable shortcut conflict/denial flows, tabs/splits, packaging, and supported Ghostty rendering.

### NCT-001 Plasma GlobalAccel F10 slice

- Registered `noctty/toggle-window` with Plasma GlobalAccel using F10, subscribed to the component activation signal, and toggled the live GTK window from that signal while hidden.
- Normal startup now hides only after successful registration and remains visible on failure; showing restores terminal focus.
- Synchronized successful registration into the existing Zig shortcut request/receipt model, then unsubscribed, unregistered, and reset model state on shutdown.
- Expanded the graphical smoke to hide the window, invoke the registered action through Plasma, require activation signal receipt and restored focus, and require cleanup. Wayland and X11 lanes both reported `shortcut_registered=true global_shortcut=true shortcut_unregistered=true` with all previous assertions green; read-only before/after checks showed no stale NOCTTY actions.
- Still open: physical F10 injection, conflict/denial UI, configurable shortcut re-registration, protocol-specific top-edge placement, tabs/splits, packaging, and supported Ghostty rendering.

### NCT-001 live dropdown visibility and focus slice

- Added live borderless always-above window show/hide behavior without restarting the terminal PTY.
- Restored terminal focus after show, handled F10 while the window owns focus, and mirrored GTK map/unmap transitions into the Zig host model.
- Expanded the dual-backend graphical smoke to require observed show, hide, remap, and focus events alongside the existing input, marker, resize, and lifecycle proof.
- Proof: `./scripts/verify.sh` and `./scripts/native_host_smoke.sh`; Wayland and X11 lanes reported `shown=true hidden=true focused=true` with all prior assertions green.
- Still open: Plasma GlobalAccel registration/activation while hidden, Wayland layer-shell and X11 top-edge placement, physical shortcut injection, tabs/splits, packaging, and supported Ghostty rendering.

### NCT-001 native input and resize smoke slice

- Expanded the display-bound native-host smoke to spawn a shell and inject its marker command through the live terminal input path.
- Correlated input with rendered terminal contents before accepting clean child exit, avoiding a weaker output-signal-only claim.
- Forced the live window from its initial allocation to 1200 by 720 pixels and required the terminal widget to report a changed allocation with a non-zero column count.
- Proof: `./scripts/verify.sh` and `./scripts/native_host_smoke.sh`; explicit Wayland and X11 lanes both reported `pane=1 started=true input=true marker=true output=true resized=true exited=true exit_code=0 status=done`.
- Still open: physical keyboard/mouse automation, clipboard and HiDPI assertions, dropdown/show-hide behavior, Plasma shortcut registration, tabs/splits, CI compositor provisioning, packaging, and supported Ghostty rendering.

### NCT-001 stable-pane native lifecycle and dual-backend smoke slice

- Connected native terminal spawn, output, and exit callbacks to `App.dispatch(.terminal_status)` using the workspace's stable active pane ID.
- Added `--native-host-smoke`, which runs a marker command and fails unless pane `1` observes start, output, clean exit, and final `done` state.
- Added `scripts/native_host_smoke.sh` as a display-bound gate for explicit Wayland and X11 GDK backends, separate from the headless verification baseline.
- Proof: `./scripts/verify.sh`, `zig build run -- --native-host-smoke`, `GDK_BACKEND=wayland zig build run -- --native-host-smoke`, and `GDK_BACKEND=x11 zig build run -- --native-host-smoke`; both explicit backend lanes reported `pane=1 started=true output=true exited=true exit_code=0 status=done`.
- Still open: deterministic input/resize assertions, dropdown and shortcut behavior, tabs/splits, CI compositor provisioning, packaging, and supported Ghostty-backed rendering.

### NCT-001 native terminal vertical slice

- Replaced the default planning-only launcher behavior with a real native GTK/VTE terminal window.
- Added live shell PTY spawn, terminal rendering, keyboard/focus/resize behavior, scrollback, child-exit handling, and a borderless-window request through a thin C ABI adapter.
- Kept VTE explicitly provisional: the installed public Ghostty development surface does not provide a supported Linux GUI embedding header, and the locally present private embedded library was not treated as a safe ABI dependency.
- Added `docs/NATIVE_HOST.md` with the architecture decision, proof boundary, Ghostty replacement criteria, and ordered follow-up slices.
- Proof: `zig fmt build.zig src/main.zig`, `zig build check` with all 152 Zig model tests passing, and live `zig build run` launch under KDE Plasma Wayland with a rendered shell prompt captured in a desktop screenshot.
- Still open in the parent epics: Zig model binding, dropdown/show-hide behavior, global shortcut registration, tabs/splits, explicit X11 and automated GUI smoke, packaging, and supported Ghostty-backed rendering.

## 2026-07-09

### NCT-009 editor save/writeback model slice

- Added native app-level editor edit and file-save/writeback plumbing for stored editable documents.
- `edit_editor_document` applies transactional native text edits to the active or selected stored document, updates dirty/revision state, and refreshes document byte/line metrics while rejecting large read-only documents.
- `saveEditorDocumentFile` writes editable document buffers back through a native `std.Io.Dir` with atomic replacement, clears dirty state after a successful write, and rejects read-only documents.
- Added `zig build run -- --editor-save-flow` to exercise editable file loading, edit application, save/writeback verification, and read-only edit/save rejection from `/tmp` fixtures without rendered editor tabs.
- Proof: `zig fmt src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build --global-cache-dir .zig-cache/global run -- --editor-save-flow`.
- Current local editor-save-flow result: the editable fixture stores index 0, one edit changes the buffer from 35 to 47 bytes with `dirty=true` and `revision=1`, save writes the file with `dirty=false` and `saved_contains_replacement=true`, and the large read-only fixture blocks both edit and save with `EditorDocumentReadOnly`.
- Still open in the parent epic: rendered editor UI/tabs, rendered save controls and dirty prompts, rendered syntax theme/style mapping, rendered find controls, GUI project-panel/portal wiring into editor file loading/saving, and live GUI editor workflows.

### NCT-009 editor file-backed load slice

- Added native filesystem-backed editor document loading for project-panel file rows.
- `loadEditorDocumentFile` stats the selected project-panel file through a native `std.Io.Dir`, reads only files within the editor preview limit, stores editable and large read-only documents through the existing document store, and leaves hard-limit files metadata-only without reading their contents.
- Added `zig build run -- --editor-file-load-flow` to exercise editable file loading, soft-limit large read-only file loading, hard-limit metadata-only file handling with no read, and same-path reload replacement from `/tmp` fixtures without rendered editor tabs.
- Proof: `zig fmt src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build --global-cache-dir .zig-cache/global run -- --editor-file-load-flow`.
- Current local editor-file-load-flow result: the editable fixture stores index 0, the soft-limit log stores large read-only index 1 after reading 1,048,577 bytes, the hard-limit JSON reports `read_bytes=0` and `lines=unknown`, and reloading the editable fixture replaces index 0 while keeping two stored documents.
- Still open in the parent epic: rendered editor UI/tabs, rendered save controls and dirty prompts, rendered syntax theme/style mapping, rendered find controls, GUI project-panel/portal wiring into editor file loading/saving, and live GUI editor workflows.

### NCT-009 editor document load-store slice

- Added a native app-level editor document store for project-panel file rows.
- `load_editor_document` plans the selected project-panel file through the existing editor open policy, stores owned `EditorDocument` buffers for editable and large read-only loads, replaces an already-open path on reload, and reports metadata-only files without storing a buffer.
- Added `zig build run -- --editor-load-flow` to exercise editable loading, large read-only loading from line limits, metadata-only hard-limit handling, and same-path reload replacement without rendered UI.
- Proof: `zig fmt src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build --global-cache-dir .zig-cache/global run -- --editor-load-flow`.
- Current local editor-load-flow result: `/repo/src/main.zig` stores editable index 0, `/repo/notes.txt` stores large read-only index 1 with search enabled and edits/syntax disabled, `/repo/dumps/huge.json` remains metadata-only with no stored buffer, and reloading `/repo/src/main.zig` replaces index 0 while keeping two stored documents.
- Still open in the parent epic: rendered editor UI/tabs, rendered save controls and dirty prompts, rendered syntax theme/style mapping, rendered find controls, GUI project-panel/portal wiring into editor file loading/saving, and live GUI editor workflows.

### NCT-009 editor workspace open integration slice

- Added an app-level bridge from project-panel file action specs to editor open planning.
- Project-panel file rows now can be planned as `open_editor_document` editor loads while preserving the native action operation/executor metadata and applying the editor large-file policy before any file read or rendered UI work.
- Added an app-level `plan_editor_document_open` command and `zig build run -- --editor-open-flow` to exercise editable, large read-only, and metadata-only project-file opens from seeded project-panel file rows.
- Proof: `zig fmt src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build --global-cache-dir .zig-cache/global run -- --editor-open-flow`.
- Current local editor-open-flow result: `/repo/src/main.zig` plans as editable with syntax/search/undo enabled, `/repo/logs/large.log` plans as large read-only with search enabled and syntax/undo disabled, and `/repo/dumps/huge.json` plans as metadata-only with confirmation required and no buffer load.
- Still open in the parent epic: rendered editor UI/tabs, rendered save controls and dirty prompts, rendered syntax theme/style mapping, rendered find controls, GUI project-panel/portal wiring into editor file loading/saving, and live GUI editor workflows.

### NCT-009 editor find navigation model slice

- Added native editor find summaries for future rendered find controls.
- Find summaries support case sensitivity, whole-word filtering, forward/backward navigation, wrap/no-wrap behavior, selected current match indexes, bounded stored matches, and truncation reporting.
- Added an app-level `find_editor_matches` command and `zig build run -- --editor-find` to exercise forward truncated matches, backward wrap navigation, and no-wrap no-current behavior.
- Proof: `zig fmt src/editor/TextBuffer.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build --global-cache-dir .zig-cache/global run -- --editor-find`.
- Current local editor-find result: the forward case reports 4 total matches with 2 stored and current index 1, the backward case wraps to current index 3, and the no-wrap case reports no current match.
- Still open in the parent epic: rendered editor UI, rendered syntax theme/style mapping, rendered find controls, terminal/workspace integration, and live GUI editor workflows.

### NCT-009 editor syntax highlight span slice

- Added native bounded syntax highlight spans for future editor rendering.
- Syntax summaries classify Zig/C-like/script-like comments, strings, numbers, literals, and keywords, plus Markdown headings and code fences, without painting a rendered editor UI.
- Added an app-level `highlight_editor_syntax` command and `zig build run -- --editor-highlight` to exercise Zig, JSON, and Markdown samples.
- Proof: `zig fmt src/editor/TextBuffer.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build --global-cache-dir .zig-cache/global run -- --editor-highlight`.
- Current local editor-highlight result: Zig reports 6 spans, JSON reports 4 spans, and Markdown reports 3 spans, all untruncated with `max=128`.
- Still open in the parent epic: rendered editor UI, theme/style mapping for syntax spans, rendered find controls, terminal/workspace integration, and live GUI editor workflows.

### NCT-009 editor large-file open planning slice

- Added native editor open planning for large files before buffer allocation.
- Editor open plans classify files as `editable`, `large_read_only`, or `metadata_only` from byte counts, optional line counts, and policy thresholds.
- Plans expose language, worktree-relative path, soft/hard/line-limit reasons, editability, buffer loading, undo tracking, search, syntax, confirmation, and warning flags for future GUI editor flows.
- Added an app-level `plan_editor_open` command and `zig build run -- --editor-plan` to exercise editable, large read-only, and metadata-only cases without reading files or opening rendered UI.
- Proof: `zig fmt src/editor/TextBuffer.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build --global-cache-dir .zig-cache/global run -- --editor-plan`.
- Current local editor-plan result: `src/main.zig` is editable with undo/search/syntax enabled, `logs/large.log` is large read-only with search enabled and syntax/undo disabled, and `dumps/huge.json` is metadata-only with confirmation required and no buffer load.
- Still open in the parent epic: rendered editor UI, rendered syntax theme/style mapping, rendered find controls, terminal/workspace integration, and live GUI editor workflows.

### NCT-008 project panel action result-view slice

- Added native render-ready project-panel action result views for accepted action execution results.
- Result views map operation/status into stable title/detail strings, success/warning/error tones, process-output flags, editor/directory target flags, output presence, and attention state without storing borrowed project-panel row strings.
- Added an app-level `project_panel_action_result_view` command that exposes the last accepted action execution result view and fails before a matching execution receipt exists.
- Expanded `zig build run -- --project-panel-action` to print `project_panel_action_result_view` after each seeded action result receipt.
- Proof: `zig fmt src/workspace/Workspace.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build --global-cache-dir .zig-cache/global run -- --project-panel-action`.
- Current local project-panel-action result: seeded rows print result views for `run_git_diff`, `open_directory_view`, `open_editor_document`, and `run_git_commit_show` with `tone=success`, static titles for Git diff/directory/editor/commit views, and the expected process/editor/directory display flags.
- Still open in the parent epic: actual rendered project panels, live GUI controls, live file/diff/commit opening, Git-backed runtime proof in a checkout with valid Git metadata, real native host event-loop wiring, and rendered KDE/portal workspace file dialogs.

### NCT-008 project panel action result receipt slice

- Added native project-panel action execution receipts/results for process, editor-document, and directory-view action specs.
- App state now tracks a compact pending action execution key and rejects mismatched or stale execution receipts without storing borrowed project-panel row strings.
- Expanded `zig build run -- --project-panel-action` to print seeded action execution results after the existing native action handoff receipts.
- Proof: `zig fmt src/workspace/Workspace.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build run -- --project-panel-action`.
- Current local project-panel-action result: seeded rows print completed result receipts for `run_git_diff`, `open_directory_view`, `open_editor_document`, and `run_git_commit_show`; process results show `exit_code=0` with zero stdout/stderr bytes because no live Git command is run.
- Still open in the parent epic: actual rendered project panels, live GUI controls, live file/diff/commit opening, Git-backed runtime proof in a checkout with valid Git metadata, real native host event-loop wiring, and rendered KDE/portal workspace file dialogs.

### NCT-008 project panel action execution-spec slice

- Added native project-panel action execution specs that lower action plans into non-executed Git argv, editor-document, and directory-view targets.
- Git diff specs now expose `git diff -- <path>` argv, and commit specs expose `git show --stat --patch <commit>` argv without running Git.
- File and directory specs target the future native editor document and directory view without opening rendered UI.
- Added app-level `prepare_project_panel_action` command dispatch.
- Expanded `zig build run -- --project-panel-action` to print each execution spec before the existing native action request and completed receipt.
- Proof: `zig fmt src/workspace/Workspace.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build run -- --project-panel-action`.
- Current local project-panel-action result: seeded rows print non-mutating specs for `run_git_diff`, `open_directory_view`, `open_editor_document`, and `run_git_commit_show`, then complete the existing `native_workspace_action` receipts.
- Still open in the parent epic: actual rendered project panels, live GUI controls, live file/diff/commit opening, Git-backed runtime proof in a checkout with valid Git metadata, real native host event-loop wiring, and rendered KDE/portal workspace file dialogs.

### NCT-008 project panel action execution-plan slice

- Added native project-panel action execution plans that classify activation intents into future executors for git diff, git commit, file open, and directory open.
- Captured execution requirements for path, commit, and Git-backed actions while rejecting malformed or non-executable action targets before host handoff.
- Added app-level `plan_project_panel_action` command dispatch.
- Expanded `zig build run -- --project-panel-action` to print each execution plan before the existing native action request and completed receipt.
- Proof: `zig fmt src/workspace/Workspace.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, and `zig build run -- --project-panel-action`.
- Current local project-panel-action result: seeded rows produce `native_git_diff`, `native_directory_open`, `native_file_open`, and `native_git_commit` plans with the expected path/commit/Git requirements, then complete the existing `native_workspace_action` receipts.
- Still open in the parent epic: actual rendered project panels, live GUI controls, live file/diff/commit opening, Git-backed runtime proof in a checkout with valid Git metadata, real native host event-loop wiring, and rendered KDE/portal workspace file dialogs.

### NCT-008 project panel action handoff contract slice

- Added native host project-panel action requests and completed/denied/failed/unavailable receipts around existing row activation intents.
- Kept host state durable by storing only the action kind, source row, transport, and status while the request payload carries borrowed activation details for immediate handoff.
- Added app-level `request_project_panel_action` and `project_panel_action_receipt` commands.
- Expanded `zig build run -- --project-panel-action` to exercise pending `native_workspace_action` requests and completed receipts for git diff, directory, file, and commit targets.
- Proof: `zig fmt src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --project-panel-action`, `zig build run -- --project-panel-view`, `zig build run -- --project-panel-plan`, and `zig build run -- --host-plan`.
- Current local project-panel-action result: each seeded action reports `transport=native_workspace_action`, `request_status=pending`, `current_status=pending`, then a completed receipt for `show_git_diff`, `open_directory`, `open_file`, and `show_git_commit`.
- Still open in the parent epic: actual rendered project panels, live GUI controls, live file/diff/commit opening, Git-backed runtime proof in a checkout with valid Git metadata, real native host event-loop wiring, and rendered KDE/portal workspace file dialogs.

### NCT-008 project panel row activation contract slice

- Added native project-panel row activation intents without executing file, diff, directory, or commit actions.
- Git-status rows now map to `show_git_diff`, git-graph rows map to `show_git_commit`, file rows map to `open_file`, and directory rows map to `open_directory`.
- Added an app-level `activate_project_panel_row` command and `zig build run -- --project-panel-action` to exercise seeded activation intents.
- Proof: `zig fmt src/workspace/Workspace.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --project-panel-action`, `zig build run -- --project-panel-view`, `zig build run -- --project-panel-plan`, and `zig build run -- --host-plan`.
- Current local project-panel-action result: `src/main.zig` status maps to `show_git_diff`; `src` maps to `open_directory`; `src/main.zig` file row maps to `open_file`; commit `abc1234` maps to `show_git_commit`.
- Still open in the parent epic: actual rendered project panels, live GUI controls, live file/diff/commit opening, Git-backed runtime proof in a checkout with valid Git metadata, real native host event-loop wiring, and rendered KDE/portal workspace file dialogs.

### NCT-008 project panel render-view contract slice

- Added bounded render-ready project-panel views for git-status, git-graph, and file-list panels without storing borrowed row data in native host state.
- Added changed-only, conflicts-only, and dirty-only filtering plus source-index selection tracking and truncation reporting for future GUI panel rendering.
- Added an app-level `project_panel_view` command and `zig build run -- --project-panel-view` to exercise seeded changed-status, conflicts-only, dirty-file, and git-graph views.
- Proof: `zig fmt src/workspace/Workspace.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --project-panel-view`, `zig build run -- --project-panel-plan`, and `zig build run -- --host-plan`.
- Current local project-panel-view result: changed git-status view reports `total=3`, `visible=2`, `rows=1`, `truncated=true`, and selected source index 1; conflicts-only view reports the selected conflicted `docs/ARCHITECTURE.md` row; dirty-file view reports selected `src/main.zig`; git-graph view reports two rows with `abc1234` selected.
- Still open in the parent epic: actual rendered project panels, live GUI controls, Git-backed runtime proof in a checkout with valid Git metadata, real native host event-loop wiring, and rendered KDE/portal workspace file dialogs.

### NCT-008 project panel presentation contract slice

- Added typed project-panel presentation requests that carry the current git-status, git-graph, and file-list summary counts to a future renderer.
- Added shown/dismissed/failed receipts plus hide handling for project-panel presentation state without claiming rendered panel output.
- Added app commands for showing project-panel presentation, applying presentation receipts, and hiding the presentation request.
- Exposed the default project-panel presentation request through `zig build run -- --host-plan` and added `zig build run -- --project-panel-plan` to exercise a seeded request/receipt/hide flow.
- Proof: `zig fmt src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --project-panel-plan`, `zig build run -- --maintenance-plan`, `zig build run -- --workspace-file-flow`, `zig build run -- --project-scan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Current local host-plan result: project-panel presentation is `show_requested` against an empty fresh-app summary, current status is `hidden`, and `has_data=false`.
- Current local project-panel-plan result: seeded project-panel presentation moves from `show_requested` to `shown` to `hidden`, reports `has_data=true`, and carries 2 git-status entries, 1 git-graph entry, 2 file entries, 2 changed entries, 1 conflict, 1 directory, and 1 dirty file.
- Still open in the parent epic: actual rendered project panels, live GUI controls, Git-backed runtime proof in a checkout with valid Git metadata, real native host event-loop wiring, and rendered KDE/portal workspace file dialogs.

### NCT-008 selected workspace file-flow slice

- Added an app-level selected-path bridge that validates workspace file-dialog receipts through host state, then runs the existing native manual save/load helpers.
- Preserved canceled dialog receipts as no-op file actions and rejected non-manual workspace roles for GUI dialog-driven saves/loads.
- Added `zig build run -- --workspace-file-flow` to exercise save dialog selection, workspace save, workspace mutation, open dialog selection, workspace load, and temporary-file cleanup through the native model.
- Proof: `zig fmt src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --workspace-file-flow`, `zig build run -- --host-plan`, `zig build run -- --maintenance-plan`, and `zig build run -- --project-scan`.
- Current local workspace-file-flow result: save and open both report `selected`, saved and loaded byte counts match at 372 bytes, and the restored workspace has 2 panes.
- Still open in the parent epic: actual rendered KDE/portal file dialogs, rendered save/load controls, rendered project panels, real native host timer/event-loop wiring, and Git-backed runtime proof in a checkout with valid Git metadata.

### NCT-008 workspace file-dialog flow slice

- Added typed workspace save/open file-dialog requests and shown/selected/canceled/failed/unavailable receipts.
- Selected KDE-native file dialog transport for Plasma Wayland/X11-capable backends while preserving explicit unavailable state for headless/portable backends.
- Added app commands for showing workspace file dialogs and applying dialog receipts without performing hidden file writes or loads.
- Exposed workspace file-dialog planning through `zig build run -- --host-plan`.
- Proof: `zig fmt src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --maintenance-plan`, `zig build run -- --project-scan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Current local host-plan result: workspace save dialogs select `kde_file_dialog`, request status is `pending`, and current status is `not_requested`.
- Still open in the parent epic: actual rendered KDE/portal file dialogs, rendered save/load controls, rendered project panels, real native host timer/event-loop wiring, and Git-backed runtime proof in a checkout with valid Git metadata.

### NCT-008 maintenance tick planning slice

- Added native maintenance policy/state for autosave, project-panel refresh, and recovery cleanup intervals.
- Added maintenance tick planning that marks due work pending without performing hidden file writes, scans, or deletions.
- Added project-refresh and recovery-cleanup receipts so future backend timers can clear pending work only after real scan/cleanup results are available.
- Connected autosave saves to the maintenance state so successful workspace saves clear pending autosave work and dirty timestamps.
- Added `zig build run -- --maintenance-plan` to expose the timer-planning boundary from the development launcher.
- Proof: `zig fmt src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --maintenance-plan`, `zig build run -- --project-scan`, `zig build run -- --self-check`, `zig build run -- --host-plan`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Current local maintenance-plan result: autosave, project refresh, and recovery cleanup are all due after the simulated dirty-workspace interval, and all three are marked pending.
- Still open in the parent epic: wiring the tick contract to a real native host timer/event loop, rendered project panels, GUI save/load flows, and Git-backed runtime proof in a checkout with valid Git metadata.

### NCT-008 project panel scan feed slice

- Added `src/workspace/ProjectScan.zig` with parsers for `git status --porcelain=v1 -z` output and decorated `git log` records.
- Added optional native Git status/log runners behind the workspace scan boundary, plus bounded file-list walking that skips hidden/generated directories by default.
- Added app-level scan application so parser/scan results flow through the same owned project-panel update path as future GUI refreshes.
- Added `zig build run -- --project-scan` to expose the current project-panel scan boundary from the development launcher.
- Proof: `zig fmt src/workspace/ProjectScan.zig src/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --project-scan`, `zig build run -- --self-check`, `zig build run -- --host-plan`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Current local scan result: file scanning reports 39 file-panel entries and 11 directories; Git status/log are unavailable in this checkout because usable Git metadata is not present.
- Still open in the parent epic: rendered project panels, real native host timer/event-loop wiring, GUI save/load flows, and Git-backed runtime proof in a checkout with valid Git metadata.

### NCT-007 clipboard transfer and paste delivery contract slice

- Added typed clipboard read/write transfer requests and completed/denied/failed/unavailable receipts.
- Selected Wayland data-control or X11 selection transports from backend capabilities without claiming live OS clipboard access.
- Added typed prepared-paste delivery requests and delivered/failed/unavailable receipts for future terminal injection.
- Added app commands for clipboard read/write transfer requests, transfer receipts, pane paste-delivery requests, and paste-delivery receipts.
- Exposed clipboard transfer and paste delivery planning through `zig build run -- --host-plan`.
- Proof: `zig fmt src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: real Wayland/X11 clipboard transport, clipboard read/write payload handoff, and live terminal delivery through the rendering backend.

### NCT-006 durable theme library persistence slice

- Added versioned native binary installed-theme library snapshots using the `NOCTTYTHM` format.
- Added file-backed theme-library save/load helpers and the default XDG-style theme path `~/.config/noctty/themes.nocttythemes`.
- Preserved full foreground/background/cursor colors plus all 16 palette colors for installed themes.
- Added app wrappers for saving and loading installed themes; loading replaces the app theme library and falls back to the first loaded theme when the current default theme is absent.
- Covered export/import, malformed snapshot rejection, duplicate theme-name rejection, default path generation, atomic file save/load, and app-level durable library restore behavior.
- Proof: `zig fmt src/theme/Storage.zig src/app/App.zig src/root.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: rendered GUI theme browser and additional import formats.

### NCT-005 per-terminal profile preset menu slice

- Added typed right-click profile preset menu requests with five preset items: global default, compact, readable, high contrast, and mono no ligatures.
- Added shown/selected/dismissed/failed/unavailable receipts and stale receipt rejection for active pane menu requests.
- Added app commands for showing, hiding, receiving, and selecting from the active profile preset menu; selection validates the active host request before applying the pane profile.
- Exposed profile preset menu planning through `zig build run -- --host-plan`.
- Proof: `zig fmt src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: actual rendered right-click menu invocation/display and pointer/context-menu runtime proof.

### NCT-005 GUI settings persistence slice

- Added versioned native binary GUI settings snapshots using the `NOCTTYCFG` format.
- Added file-backed settings save/load helpers and the default XDG-style config path `~/.config/noctty/settings.nocttycfg`.
- Loaded font-family and default-theme strings into owned app memory and synchronized `app.config` with `host.config`.
- Covered roundtrip export/import, invalid snapshot rejection, default path generation, atomic file save/load, and app-level save/load restore behavior.
- Proof: `zig fmt src/config/Storage.zig src/root.zig src/app/App.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: rendered settings UI and rendered per-terminal profile preset menu display/invocation.

### NCT-004 status-tooltip request lifecycle slice

- Added typed status-tooltip show requests and shown/dismissed/failed/disabled receipts around existing tab status summaries.
- Added tab targeting for tooltip requests, including active-tab fallback and stale tab receipt rejection.
- Reused existing compact status summary and tooltip formatter data instead of duplicating status text.
- Exposed status-tooltip requests through app commands and `zig build run -- --host-plan`.
- Proof: `zig fmt src/workspace/Workspace.zig src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: rendered GUI tooltip display and hover/focus runtime proof.

### NCT-004 notification delivery transport slice

- Added typed notification delivery requests and receipts around existing terminal status notification requests.
- Modeled not-requested, unavailable, pending, delivered, denied, and failed states without claiming KDE DBus delivery has occurred.
- Selected KDE DBus notification transport from backend capabilities and rejected stale/mismatched delivery receipts.
- Exposed notification delivery through app commands and `zig build run -- --host-plan`.
- Proof: `zig fmt src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: actual KDE DBus notification delivery and rendered GUI tooltip proof.

### NCT-001 native window lifecycle transport slice

- Added typed native window lifecycle requests and receipts for startup and shortcut activation.
- Modeled not-requested, unavailable, create-requested, created, shown, hidden, destroyed, and failed states without claiming a real OS window exists.
- Updated host state from validated lifecycle receipts, including shown/hidden dropdown state and an opaque future transport window id.
- Rejected stale trigger/protocol/target receipts and exposed lifecycle requests through app commands plus `zig build run -- --host-plan`.
- Proof: `zig fmt src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: actual Wayland/X11 window creation, live show/hide transport, and runtime GUI smoke proof.

### NCT-001 global-shortcut registration transport slice

- Added typed global-shortcut registration requests and receipts for the native host.
- Modeled pending, registered, denied, conflict, failed, unavailable, and not-requested states without claiming OS registration has occurred.
- Selected KDE GlobalAccel or X11 grab-key transports from backend capabilities and rejected stale/mismatched receipts.
- Exposed registration through app commands and `zig build run -- --host-plan`.
- Proof: `zig fmt src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: actual KDE/X11 global shortcut registration transport and runtime activation smoke proof.

### NCT-001 presentation-action planning slice

- Added protocol-specific presentation plans for startup and shortcut activation.
- Modeled Wayland layer-shell dropdown presentation, Wayland toplevel fallback, X11 EWMH fallback, degraded non-Plasma behavior, and headless unavailability.
- Added fixed action lists for create/configure/position/register/notify/DnD/show/hide/fullscreen transport work so a future native backend can bind real calls without changing product state.
- Exposed presentation plans through the app model and `zig build run -- --host-plan`.
- Proof: `zig fmt src/gui/Host.zig src/gui/root.zig src/app/App.zig src/main.zig`, `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: actual window creation, real global shortcut registration, and Wayland/X11 runtime GUI smoke proof.

### NCT-001 host launch/readiness plan slice

- Added a typed native host launch plan that describes startup readiness, initial surface intent, first dropdown shortcut activation, chrome constraints, backend feature usage, and degraded/headless behavior.
- Exposed the launch plan through the app model and `zig build run -- --host-plan`.
- Added focused tests for the default hidden-dropdown startup path, first visible dropdown activation, non-Plasma degradation, and headless unavailability.
- Proof: `./scripts/verify.sh`, `zig build run -- --host-plan`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --ghostty-probe`.
- Still open in the parent epic: real rendered window creation, registered global shortcut transport, and runtime Wayland/X11 GUI smoke proof.

### NCT-009 editor undo/redo and literal search model slice

- Added owned edit transactions for editor undo and redo.
- Added redo-stack clearing when a new edit follows undo.
- Added literal search with optional ASCII case-insensitive matching, result limits, and line/column match positions.
- Added focused editor tests for search, undo/redo, and redo invalidation.
- Proof: `./scripts/verify.sh`, `zig build run -- --self-check`, `zig build run -- --dump-default-config`, and `zig build run -- --host-plan`.
- Still open in the parent epic: rendered editor UI, rendered syntax theme/style mapping, rendered find controls, terminal/workspace integration, and live GUI editor workflows.

### NCT-009 editor document foundation slice

- Added a native editor document wrapper around text buffers.
- Added common language detection from file paths.
- Added worktree-aware document metadata, dirty tracking, and revision tracking.
- Added multiple-selection replacement and transactional non-overlapping multi-edit application.
- Still open in the parent epic: rendered editor UI and user-facing editor workflows.

### NCT-008 workspace storage and recovery slice

- Added file-backed workspace save/load helpers using the binary workspace snapshot format.
- Added atomic workspace writes and bounded workspace-file reads.
- Added default XDG-style workspace, autosave, and recovery paths.
- Added recovery dirty/autosave policy state plus retention-based cleanup planning and pruning for old autosave/recovery files.
- Still open in the parent epic: rendered GUI save/load flows, real native host timer/event-loop wiring for cleanup, Git-backed runtime proof, and rendered project panels.

### NCT-008 project panel model slice

- Added native project-panel state for git status entries, git graph nodes, and file-list entries.
- Included project-panel state in workspace snapshots, export bytes, import bytes, and restore flows.
- Added typed app commands for project-panel updates.
- Still open in the parent epic: real git/file scanning and rendered panel UI.

### Native state foundation slices

- Added the native-only app/config/workspace model foundation.
- Added Plasma/Wayland/X11 backend capability descriptors and host placement state.
- Added compact split/grid workspace state, pane selection, broadcast target selection, and context-menu command dispatch.
- Added per-terminal status state, tab status summaries, tooltip text data, status-tooltip request lifecycle modeling, and KDE-capable notification request creation.
- Added GUI-facing configuration commands and native settings persistence for window mode, dropdown shortcut capture, tabs, status indicators, notifications, font settings, theme choice, panel metrics, and per-terminal profile presets.
- Added theme import primitives for Ghostty, Xresources, and simple Alacritty color lines.
- Added clipboard paste preparation with unsafe-control stripping, heredoc literal preservation, shell one-line repair, bracketed-paste wrapping, and bracket-marker normalization.
- Added the isolated dynamic `libghostty` adapter boundary plus fake-symbol lifecycle tests.
- Still open across the parent epics: real rendered Plasma GUI, terminal rendering loop, global shortcuts, KDE DBus notification delivery, platform clipboard transport, rendered settings UI, theme browser UI, and Linux Ghostty surface contract validation.
## Supplemental verification and packaging slices — 2026-07-10

- Added native desktop-entry, AppStream, scalable SVG, 48px, and 128px icon
  resources and wired them into the Zig install tree.
- Added syntax-validated install metadata, isolated-prefix install proof,
  normalized tarball generation, SHA-256 sidecars, and packaging smoke checks.
- Promoted packaging and Ghostty ABI guards into `scripts/verify.sh`.
- Proof: `./scripts/verify.sh` passes with install-tree, tarball, checksum, and
  ABI-boundary assertions. Native package-manager manifests, signing,
  dependency bundling, and multi-architecture artifacts remain open.
## Supplemental native workspace UI slices — 2026-07-10

- Added reorderable GTK notebook tab bookkeeping and a horizontal split
  container around the live terminal.
- Added a dedicated secondary VTE context with pane ID `2`, independent shell
  spawn, output/resize/exit callbacks, and native smoke reporting fields.
- Added structural layout and two-pane preflight checks. The current display
  environment fails before native launch (`NativeHostUnavailable`), so no live
  pane-2 runtime proof is claimed.
- X11 later provided complete pane-2 runtime proof; maintained smoke now asserts
  `secondary_started=true secondary_output=true secondary_exited=true`. Wayland
  remains blocked before launch by `NativeHostUnavailable`.

## Supplemental tab chrome polish slices — 2026-07-13

### NCT-064 Tab chrome contrast and close affordances — done

- Added active-tab contrast and an explicit per-tab close button while preserving right-click close and last-tab protection.
- Focused native two-tab smoke proved active styling, close targeting, surviving-tab focus, and PTY teardown.

### NCT-065 New-tab shortcut and accessible labeling — done

- Added `Ctrl+Shift+T` to the persistent New Tab button tooltip and accessibility name.
- Focused native two-tab smoke proved button activation and accessibility metadata.
