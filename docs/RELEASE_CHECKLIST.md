# Release Checklist

Product-behavior and local release-source baseline: 0.1.0, 2026-07-18.

The local 0.1.0 behavior and source-evidence baseline is implemented. NCT-106, NCT-110, NCT-111, NCT-119, NCT-120, NCT-121, and NCT-122 are complete at their bounded one-host source/native boundaries. NCT-112's hidden/visible runner and four-lane shakedown pass, but acceptance remains partial until the retained 48-hour authenticated matrix elapses. This checklist keeps local source/native evidence separate from mature-editor parity, release artifacts/signatures/publication, final compositor acceptance, and consent-gated physical input.

NCT-100 reproducible split-terminal benchmarking, NCT-101 throughput hardening, NCT-102 event-driven PTY scheduling, NCT-118 short resource qualification, and NCT-120 history qualification are complete machine-local engineering lanes; they do not satisfy any retained release-operation row. Focused warning-fatal X11/Wayland renderer and NoctEd workflows prove the implemented slices, not universal latency, agent compatibility, Sublime Text 2, or Zed parity.

The opt-in NCT-106/NCT-122 core endurance extension retains 512 cycles per mode, 1,024 total operation cycles, 3,072 ranking evaluations, the exact cross-mode fingerprint, zero allocator residue, operation percentiles, positive root memory, duration, and scratch cleanup: `nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true`. It remains headless and bounded; the separate native endurance matrix supplies the sustained GTK/Wayland/X11 boundary.

The maintained NCT-106/NCT-122 GLib worker lane retains the shared admission and queue transaction called by production `App` (generation supersession, 64 shared/32 per-lane caps, cancelled-lane exclusion, kind cancellation, pending lookup, lazy pool creation, failure-safe append, push rollback, and ordered retirement) plus production scan/search/save payloads through two real single-thread pools, snapshot-first streaming, cooperative cancellation, exact two-batch backpressure, atomic foreground save while scan is blocked, drain, root PSS/RSS, and zero allocator residue. It remains headless; the separate native endurance matrix crosses GTK publication/draw and sustained teardown.

## Source Gate

- [x] `./scripts/verify.sh`
- [x] Zig unit tests and executable check
- [x] Debug/`ReleaseSafe` NoctEd settings/session recovery corpus plus exact legacy Bash scanner callback prototype (`legacy_shell_parser=true`, `malformed_state_corpus=13`, `interrupted_replace=true`)
- [x] Debug/`ReleaseSafe` NoctEd document/grammar mutation corpus plus identity-stable external-read retry and bounded churn rejection (`document_cases=256`, `grammar_cases=256`, `retry_cap=3`)
- [x] SHA-256-pinned Debug/`ReleaseSafe` terminal protocol/state diffs, malformed-input resize/chunk equivalence, Unicode mutation, complete Unicode 17 grapheme conformance, fixed parser bounds, and allocator accounting (`terminal_compatibility_matrix debug=true release_safe=true protocol_cases=23 schedules=6 malformed_cases=128 unicode_mutations=256 grapheme_cases=766 allocator_leak_free=true scratch_clean=true`)
- [x] Installed nano 9.1, less 704, and dialog 1.3-20260107 through production profiles, PTYs, sessions, and VT grids in Debug/`ReleaseSafe`, with application state, screen-mode, foreground identity, routed exit, allocator/process teardown, root/tree memory, update checks disabled, and clean scratch (`terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`)
- [x] Installed top 4.0.6-dirty, watch 4.0.6-dirty, info 7.3, whiptail 0.52.25, fzf 0.74.0, SQLite 3.53.3, Glances 4.5.5, Bash 5.3.15, man-db 2.13.1, and OpenSSH SFTP 10.4p1 through production profiles, PTYs, sessions, and VT grids in Debug/`ReleaseSafe`, with primary/alternate screen state, fuzzy-filter input modes, plaintext REPL behavior, styled monitor behavior, isolated Readline shell state, nested man/less foreground transfer, direct local SFTP client/server interaction without a network bind, foreground identity, routed zero exits, allocator/process teardown, root/tree memory, update checks disabled, and clean scratch (`terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`)
- [x] PTY, VT grid, and TerminalSession smokes
- [x] Debug/`ReleaseSafe` direct GLib fairness with one flooding pane, 29 marker panes, shared guarded pump scratch, 8 MiB paste drain and pending-paste teardown, allocator/process cleanup, and scoped scratch (`terminal_agent_fairness_matrix debug=true release_safe=true panes=30 flood_panes=1 marker_panes=29 all_markers=true shared_pump_scratch=true glib_fd_sources=true large_paste_bytes=8388608 paste_queue_exercised=true paste_drained=true paste_pending_teardown=true allocator_leak_free=true process_residual=0 scratch_clean=true`)
- [x] Install-tree desktop/AppStream/icon/license validation
- [x] Debian/RPM/Arch manifest structure checks with truthful RPM and Arch parser availability status
- [x] Two isolated byte-identical tarball builds, coherent version/date surfaces, SHA-256 sidecar verification, and self-cleaning verification scratch space (NCT-075)
- [x] Pinned x86_64/aarch64 release workflow contract with Zig 0.16.0, runner-architecture assertions, archive/sidecar validation before upload, and a bounded Linux source-alpha gate using CI-provisioned private display/session namespaces, Xvfb, Openbox, and virtual KWin (NCT-076, NCT-127)
- [x] Dependency-bundle manifest with archive digest, installed files, bundled-library/package/license inventories, fail-closed ownership/text validation, and redistribution-source readiness (NCT-077 follow-through)
- [x] Release-operations evidence status guard that reports retained artifacts, signatures, publication, dependency-bundle redistribution notices, compositor acceptance, and consented Wayland HID receipts without promoting missing external evidence to source success (NCT-078)
- [x] Release-operations missing-evidence diagnostics and complete-fixture smoke for `--require-complete` (NCT-079)
- [x] Semantic retained-evidence validation that rejects placeholder receipts and requires manifest, publication, redistribution, compositor, and consent fields before `--require-complete` can pass (NCT-080)
- [x] TODO-bearing release-evidence scaffold templates that do not create fake artifacts and remain blocked until replaced by real retained evidence (NCT-081)
- [x] Architecture artifact intake guard that verifies archive checksums and manifest architecture/digest fields before retaining tagged artifacts (NCT-082)
- [x] Signature intake guard that retains archive/checksum/manifest signatures only after the matching canonical retained target exists (NCT-083)
- [x] Publication and dependency-bundle redistribution receipt intake guard with semantic validation and publication prerequisite diagnostics (NCT-084)
- [x] Compositor acceptance and Wayland HID consent intake guard with semantic validation and complete retained-evidence fixture proof (NCT-085)
- [x] Native VT scrollback ring retention with bounded 1000-line storage, no repeated front shifting after the cap, and allocator cleanup on grid init/resize setup failures (NCT-086, `scrollback_ring=true`)
- [x] Quick-note overlay draw-label cache with hidden-state cleanup proof for both overlay-owned strings (NCT-087, `note_overlay_cached=true`)
- [x] Native tick path skips unchanged GTK top-level title writes and unchanged running-tooltip rebuilds (NCT-088, `tick_noop_dedup=true`)
- [x] Native tick path suppresses idle would-block terminal redraws while preserving redraws for PTY bytes, status transitions, exit, and cursor blink (NCT-089, `idle_redraw_suppressed=true`)
- [x] Quick-note overlay Pango font-description cache with draw-local layouts and shutdown cleanup (NCT-090, `note_overlay_font_cached=true`)
- [x] Quick-note overlay bounded 4 KiB preview read with strict full-note editor reads preserved (NCT-091, `note_overlay_preview_bounded=true`)
- [x] Compact-tab markup and tooltip setter dedupe with object-owned cache cleanup (NCT-092, `tab_setter_dedup=true`)
- [x] Pane status tooltip stack formatting and setter dedupe with object-owned cache cleanup (NCT-093, `pane_tooltip_dedup=true`)
- [x] Tab-color CSS provider rebuild dedupe keyed by RGB and active styling state (NCT-094, `tab_color_style_dedup=true`)
- [x] Compact-tab suffix stack/literal formatting for pane, selection, broadcast, color-tooltip, and ellipsis text (NCT-095, `tab_suffix_stack=true`)
- [x] Native draw/tick/source-cleanup and project-scan memory-pressure polish (NCT-096, `native_perf_memory_polish=true`)
- [x] Native retired-context freeing, VT scrollback slab storage, and terminal-find result caching (NCT-097, `native_memory_leak_hardening=true`)
- [x] Native allocation polish for git cap-before-clone parsing and stack-formatted Smart Tab/filter status labels (NCT-098, `native_allocation_polish=true`, `git_parse_cap_before_alloc=true`, `smart_filter_label_stack=true`, `terminal_find_status_stack=true`)
- [x] Native deep performance/memory hardening for lazy VT history and alternate-screen resize safety, packed/blank-skipping draw work, idle metadata/exit-poll suppression, native-host callback cleanup, and one-buffer session-owned paste (NCT-099, `native_deep_memory_hardening=true`, `scrollback_lazy_growth=true`, `alternate_resize_safe=true`, `packed_cell_render=true`, `blank_cell_draw_skipped=true`, `idle_metadata_probe_suppressed=true`, `idle_exit_poll_throttled=true`, `native_host_callback_cleanup=true`, `literal_paste_single_pass=true`, `paste_session_allocator=true`)
- [x] Reproducible split-terminal benchmark with exclusive Yakuake lifecycle, process-tree PSS/RSS/CPU accounting, retained three-run artifacts, and a bounded drain-to-`EAGAIN` PTY pump whose current measured ceiling is 2 MiB (NCT-100, `split_terminal_benchmark=true`, `yakuake_exclusive=true`, `process_tree_pss=true`, `pty_pump_bounded_drain=true`)
- [x] Benchmark-driven native output throughput hardening with constant-time full-screen visible-row rotation, equivalent printable runs, and initial reusable read-buffer/GTK-continuation work later superseded by the shared 128 KiB scratch and descriptor-driven presentation path (NCT-101, `native_output_throughput=true`, `visible_grid_ring=true`, `vt_ascii_run=true`, `pty_active_continuation=true`, `continuation_cleanup=true`)
- [x] Event-driven PTY descriptor readiness, one-shot presentation coalescing, complete descriptor/presentation source teardown, runtime multi-pane source assertions, warning-fatal pane-menu popdown teardown, deterministic terminal-order isolation, and per-pane WezTerm readiness (NCT-102, `pty_event_source=true`, `timer_read_polling=false`, `output_present_coalesced=true`, `event_source_cleanup=true`, `pane_close_menu_popdown=true`, `benchmark_order_isolated=true`, `wezterm_split_ready=true`, `writer_median_ms=66`)
- [x] Agent-scale native session memory pass: read arrays, pump ceilings, synchronous/idle cold history, history allocators, Pango/Cairo reuse, shared scratch, and cell alignment were benchmarked in detached worktrees. One guarded 128 KiB scratch serves the GTK-serialized pool, standalone sessions retain private ownership, `TerminalSession` is 10,352 bytes, and hot cells are 14 bytes. Idle history now cold-packs in bounded 30/300-second maintenance slices and libc completion-wave trimming returns pages; thirty 120×40 grids release 40.72 MiB logically and a delayed narrow 32-pane sample releases 7,084 KiB USS while active seven-pair throughput stays intact. The benchmark accepts 16/32 panes, exact binaries, USS accounting, post-output settle, and an idle-compaction expectation (`shared_pump_scratch=true`, `terminal_cell_bytes=14`, `idle_history_compaction=true`, `agent_scale_panes=32`)
- [x] Pinned fourteen-repository terminal/agent-workspace review: blank-tail primary reflow preserves visible content, bounded OSC 9/99/777 requests drive pending-input attention without retaining payload text, and a 64 MiB-capped ordered PTY write queue replaces GTK-thread sleeping with a temporary 4 ms drain source. A focused 8 MiB sleeping-child probe changed caller blocking from 921.618 to 1.450 ms, the queue retains at most 256 KiB after drain, and no dependency, custom epoll loop, browser runtime, or agent auto-hibernation path was added. Herdr-inspired continuity badges, bounded Claude Code/Codex resume references, GUI restore modes, explicit safe notification actions, and encrypted mode-0600 screen-history export are now implemented (`terminal_peer_research=true`, `reflow_blank_tail_fixed=true`, `terminal_notification_attention=true`, `pty_write_queue=true`, `continuity_badges=true`, `agent_resume_references=true`, `restore_modes=true`, `safe_notification_actions=true`, `encrypted_history_export=true`)
- [x] Foreground-process close confirmation, bounded process-group teardown, immediate retired grid/session release, pre-teardown rejection of late GTK/IM/input/draw/PTY/drag/clipboard callbacks, ordered menu/popup teardown before parent hide, root-coalesced blink and maintenance, one-second descriptor-backed exit fallback, hidden presentation throttling, mapped-only redraw, explicit-PID agent process-tree memory accounting, and conservative daily-driver guidance (NCT-109, `foreground_guard=true`, `session_storage_released=true`, `late_callback_guard=true`, `popup_teardown=true`, `root_timer_coalesced=true`, `hidden_present_throttled=true`, `mapped_redraw_only=true`)
- [x] Root-coalesced descriptor-backed exit fallback with zero pane exit timers, 16 ms registration-failure fallback only, centralized idempotent source shutdown across every context lifecycle, descriptor-aware layout-preset readiness, and an eight-pane static schedule of 3 callbacks per second (NCT-116, `descriptor_fallback=root_coalesced`, `pane_exit_timers=0`, `source_cleanup=centralized`)
- [x] PID-owned real-pointer tab drag across three live tabs, pre-drag active-page preservation, stable-ID Zig ordering, rejected-dispatch GTK rollback, coalesced hot-session persistence, restored-layout writeback suppression, snapshot/reload order, and native-release-matrix promotion (NCT-113, `tab_reorder_pointer_drag=true`, `tab_reorder_active_identity=true`, `tab_reorder_rollback=true`, `tab_reorder_persistence_coalesced=true`)
- [x] Standalone NoctEd binary/process, NOCTTY cwd handoff, compact project-tree/tab/minimap surface, GtkSourceView syntax reuse/import, bounded UTF-8 loading, permission-preserving atomic save, native render proof, and package/bundle integration (NCT-103, `nocted_standalone=true`, `process_separate=true`, `project_activation=true`, `permissions_preserved=true`)
- [x] NCT-104 bounded Unicode select-all-occurrences transactions with native primary clipboard/IME ownership, rendered secondary marks, one-step undo, bounded recent projects, and atomic ordered active-tab session restoration (`multi_selection=true`, `multi_selection_undo=true`, `multi_selection_rendered=true`, `session_persist=true`, `session_restore=true`, `recent_project=true`)
- [x] NCT-105 bounded TextMate JSON conversion, atomic duplicate replacement, generated-definition precedence, safe runtime language-manager replacement, open-buffer re-detection, malformed rejection, and warning-fatal X11/Wayland activation (`textmate_import=true`, `textmate_language=true`, `textmate_precedence=true`, `malformed_rejected=true`)
- [x] Reversible zero-copy NoctEd indentation folding with native undo preservation, exact folded save, translucent minimap scrubber, and warning-fatal teardown (NCT-107, `folding=true`, `minimap_overlay_translucent=true`)
- [x] Bounded NoctEd Find in Files, search-result activation, multi-file tab navigation, and guarded close-other/close-all actions (NCT-108, `find_in_files=true`, `project_search_activation=true`, `multi_file_tabs=true`)
- [x] Clean NoctEd untitled buffers, duplicate-safe native Save As, exact atomic first-save with syntax re-detection, and capped fuzzy project quick-open with captured X11/Wayland proof (NCT-114, `untitled=true`, `save_as_collision=true`, `quick_open_bounded=true`, `quick_open_capture=true`)
- [x] Yakuake-shaped local active-pane information with bounded PTY foreground `/proc` metadata, allocation-free Zig formatting, one root-owned GTK strip below the notebook, immediate focus/tab refresh, root-coalesced maintenance refresh, unchanged-setter dedupe, persisted GUI toggle, layout/preset/restore regression coverage, shared idempotent pointer/signal activation, bounded click-focus sequencing, deterministic origin-bound native gate lifecycle, and stripped dependency-bundle binaries (NCT-115, `pane_info=true`, `pane_source=pty_proc`, `pane_refresh=coalesced`, `pane_info_dedup=true`)
- [x] Initial transactional visit-budgeted NoctEd project refresh/search, coalesced Quick Open, explicit root/borrowed pane-context initialization, packed-row rendering, and isolated production/optional/smoke build surfaces with VTE absent from production runtime manifests (NCT-117, `render_abi=packed_rows`, `production_vte=false`, `production_noctty_tree_sitter=false production_nocted_tree_sitter=true`, `production_smoke_surface=false production_smoke_symbols=false`, `production_legacy_editor=false`)
- [x] GUI-configurable 0-to-100000-line terminal history with live bounded shrink and resize preservation; versioned native-grid ABI v1; terminal-owned dirty-row damage; coalesced background and eligible ASCII glyph batches; one 64-job exclusive NoctEd filesystem worker; constant-time document/page identity; compact tree IDs; lazy search/minimap state; malformed-stream resize/history churn; eight-cycle NoctEd and 32-session terminal Debug/`ReleaseSafe` resource qualification (NCT-118, `render_abi_version=1`, `damage_tracking=dirty_rows`, `glyph_batching=true`, `nocted_worker=bounded`)
- [x] Completed NCT-119 through exact production-Cairo fixtures, real PTY/VT-to-Cairo distributions, direct GLib fairness and large-paste teardown, live mapped key-handler-to-draw/after-paint distributions with Wayland GDK feedback, and live Debug/`ReleaseSafe` Wayland/X11 idle/fullscreen compositor pixels plus external memory and bounded wakeups. Authenticated Codex acceptance now has a separate mapped receipt; physical HID and final compositor acceptance remain release operations.
- [x] Implemented the bounded NCT-112 production-session and real-PTY-to-Cairo tranches plus the long-run hidden/visible harness. Debug/`ReleaseSafe` each repeat 64 ordinary plus eight forced production-session lifecycles, one installed Codex/Vim/btop sequence, two 64-sample real-shell PTY/VT/exact-Cairo sequences, and a short Wayland/X11 mode-40 shakedown with zero hidden draws, zero fallback PTY ticks, phase wakeups/output, external memory, compositor pixels, and controlled exit. Acceptance remains partial only for the default authenticated 24-hour Wayland plus 24-hour X11 execution.
- [x] Implemented the bounded NCT-111 named-profile, credentialed-SSH, continuity-adapter, local workspace-activation, and installed-acceptance-harness tranches: one GUI-owned atomic active shell/command/SSH/Persistent-tmux/Persistent-Zellij profile plus up to eight named entries; settings-version-9 launch state and recent-workspace persistence with versions 1–8 migration; disposable Ed25519 public-key authentication through the real OpenSSH client/server and product PTY with a pinned host key; fixed direct tmux/Zellij create-or-attach argv; bounded local `noctty:`/`file:` decoding; pre-PTY snapshot restore; native Recent Workspaces selection; separate-process activation that leaves current PTYs untouched; and a passing disposable production desktop/MIME contract (`launch_runtime=true`, `launch_library=true`, `credentialed_ssh=true`, `workspace_activation=true`, `recent_workspaces=true`, `native_grid_installed_activation_contract installed_desktop=true mime_registered=true exec_open_uri=true fixture_tabs=2 production_binary=true smoke_isolated=true scratch_scoped=true`; `launch_continuity_matrix debug=true release_safe=true kinds=tmux,zellij direct_argv=true create_or_attach=true production_pty=true cwd=true environment=true controlled_exit=true allocator_leak_free=true tool_shims=true installed_tools=false live_reattach=false scratch_clean=true`). The harness now isolates its prefix, TMPDIR, XDG cache, and Zig local/global caches below one trap-cleaned root. Live Plasma Wayland and X11 retain desktop/MIME dispatch plus Recent Workspaces child activation with mapped, rendered two-tab children and controlled zero exit (`native_grid_installed_activation_matrix backends=wayland,x11 installed_desktop=true desktop_dispatch=true recent_child=true rendered=true controlled_exit=true scratch_clean=true`). The later installed matrix closes NCT-111 with tmux 3.7b and Zellij 0.44.3 detach, NOCTTY relaunch, live reattach, preserved content, and 16 compositor screenshots across Debug/`ReleaseSafe` Wayland/X11.
- [x] Completed NCT-120 stable logical-line identity, grapheme anchors, primary-screen reflow, compact memory-only cold history, forced shrink compaction, and 100000-line Debug/`ReleaseSafe` grow/shrink qualification (`terminal_history_matrix debug=true release_safe=true lines=100000 compact=true reflow=true grow_shrink=true scratch_clean=true`).
- [x] Implemented NCT-121/NCT-122's immutable 100000-entry-cap worktree index, bounded structural deltas/fallback, external-change decisions, two lazy worker lanes, snapshot-first streaming search, two-batch backpressure, smart-case top-K Quick Open, scale qualification, and bounded native GTK lifecycle/search/resource matrices.
- [x] Implemented NCT-106 deterministic recovery, malformed/mutation/race coverage, identity-stable reads, allocator-accounted core repetition, production worker admission/transaction proof, and bounded native GTK resource/search/lifecycle matrices.
- [x] Extended the production NoctEd core to 512 cycles per mode with 1,024 total cycles, 3,072 deterministic ranking evaluations, zero allocator residue, root-memory samples, duration, and scoped cleanup (`nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true`).
- [x] Closed the sustained NCT-106/NCT-121/NCT-122 native boundary with 32 complete Debug/`ReleaseSafe` Wayland/X11 workflows per lane: 256 cycles per phase per lane, 4,096 combined phase cycles, 3,072 deterministic ranking evaluations, process-tree memory, warning-fatal GTK, worker/project drain, Cairo widget captures with sampled nonblack RGB, hot-exit teardown, post-widget callback safety, and clean scratch (`nocted_native_endurance_matrix wayland=true x11=true debug=true release_safe=true rounds_per_lane=32 cycles_per_phase_per_lane=256 total_cycles_per_phase=1024 total_phase_cycles=4096 ranking_evaluations=3072 search_load=true deterministic_ranking=true gtk_batch_bounded=true project_lifecycle=true monitor_bursts=true overflow_recovery=true worker_drained=true process_tree_memory=true screenshots=true warning_fatal=true duration_recorded=true scratch_clean=true`).
- [x] Ghostty public-ABI/upstream-surface guard
- [x] Documentation and native-layout truth checks
- [x] Low-risk native UI/error audit: selected-cwd NoctEd handoff, post-read
  theme bounds, checked durable profile/theme writes, non-destructive Quick
  Note load failure, accessible dynamic status/errors, and monitor-bounded
  compact transients. The smoke binary and native-layout contract pass; mapped
  narrow-layout recapture remains in NCT-125 after the isolated I/O pressure
  gate deferred the focused run.
- [x] Noctalia v4/v5 capability model and Niri/Hyprland/Sway/Scroll/Labwc/Mango binding serializers

## Native Product Gate

- [x] Dropdown, borderless windowed, and zen fullscreen
- [x] Pre-state primary-instance lock plus D-Bus fallback, 12-caller cold-start and hidden/show race convergence, one-use GTK activation-token forwarding, and explicit isolated New Workspace/Open NOCTTY Here launch paths (NCT-124)
- [x] Damaged settings/theme/workspace startup fallback with validated last-known-good backups, exact rejected-byte retention, and one native recovery notice (NCT-124)
- [x] Undecorated Wayland dogfood dropdown through a launcher-owned pinned GTK Layer Shell runtime, with symmetric recentering after percentage/pixel width changes
- [x] Legacy 32 px dropdown recovery to the percentage setting above a 480×240 usable floor, plus bounded 80%×75% windowed startup sizing
- [x] Wayland layer-shell and X11 top-edge placement
- [x] Dynamic independent tabs and recursively splittable sessions
- [x] Leading accessible `+` New Tab action from the default row and after original-tab closure, with fresh-session routing and persistent one-tab availability
- [x] Trailing system-theme Settings then Close controls in Yakuake order, with native Settings activation and clean all-session PTY shutdown independent of NoctEd
- [x] Native action buttons use the standard arrow pointer, expose nonempty tooltips, and restore terminal/text/resize cursor semantics on leave
- [x] Yakuake-density tab chrome keeps compact titles and `×N` pane counts while New Tab, Settings, application Close, and per-tab Close use native symbolic icons with 28-logical-pixel width and 18-logical-pixel height targets plus explicit hover, active, and keyboard-focus states
- [x] Configurable 18-pixel page-level active-pane information below top tabs with `short cwd : foreground process` text and a full pane/PID/process/directory tooltip; no per-split title bars
- [x] Double-click no-popup inline tab rename with outside-click cancellation, Enter commit, focus restoration, Zig state, dirty marking, and workspace snapshot persistence
- [x] Exact-tab native `Tab Color` presets with contrast-aware rendering, reversible active-tab lighten/darken shortcuts, dirty marking, and backward-compatible snapshot persistence
- [x] `Ctrl+Tab` visible-pane focus cycling and `Ctrl+Shift+Tab` Smart Tab-preserving notebook cycling through the real GTK key path
- [x] Alt+wheel next/previous pane cycling stays on the current tab, excludes hidden panes, and renders transient `Pane n / total` target feedback on Wayland/X11
- [x] Ctrl+Alt+wheel next/previous tab cycling wraps through ordinary and Smart Tab-filtered views and renders transient `Tab n / total` feedback on Wayland/X11
- [x] Multi-pane selection tags, selective tag removal, and replaceable/clearable Smart Tab filtering
- [x] Native workspace smoke receipt for tag matching and Smart Tab filter clearing
- [x] Pane tooltips expose current tags and refresh after tag mutations
- [x] Compact tab label and tooltip expose the active Smart Tab filter
- [x] Smart Tab filter is available from the command palette and `Ctrl+Shift+G`
- [x] Tag and remove-tag actions are available from the command palette; tagging also has `Ctrl+Shift+Y`
- [x] Compact selection-count and broadcast markers with explicit tab-tooltip state
- [x] Smart Tab filtering hands focus to a visible matching pane
- [x] Smart Tab no-match state is explicit and clears when results return
- [x] Right-click exact-tab close with last-tab protection, PTY teardown, root-host survival, and remaining-tab focus
- [x] Pane-context `Close Terminal` with model-first exact removal, topology-preserving split collapse, PTY teardown, root-host survival, remaining-pane focus, and final-terminal protection
- [x] Broadcast-safe plain `Ctrl+C` interruption of the focused pane only, plus no-EOT exact-pane `Ctrl+D` teardown, surviving focus, and final-pane protection on Wayland/X11
- [x] Context-menu 1×1/2×2 churn across eight rounds plus balanced 3×3/4×4 layouts; mapped Wayland/X11 Vim and mixed btop/Vim grids render and accept input at the 80×24 auto-fit target; cancel preserves all 16 sessions, acceptance moves 15 surplus sessions to an overflow tab, and restores source-pane focus
- [x] Four-session proof with vertical Split Down and horizontal Split Left
- [x] Balanced eight-session proof with midpoint divider placement
- [x] Click-to-focus switching with distinct commands delivered to both pane PTYs
- [x] Clean click/release/hover selection behavior without motion trails
- [x] Selection-free double-click pane zoom/restore with ordinary drag selection preserved
- [x] Context-menu/drag pane reparenting and last-pane source-tab closure
- [x] Immediate and startup-restored bottom tab placement
- [x] Transient command palette, scrollback find/save, quick note, pane zoom, directional focus, bell attention, and IM composition
- [x] Hold-Alt multiline UTF-8 workspace-note overlays on every visible pane, with compact bounds and release/focus-loss hiding on Wayland and X11
- [x] Quick-note overlays reuse one cached formatted label per Alt-preview lifetime and release it with the raw note text on hide
- [x] Atomic hot-session write-through and startup reconstruction of customized tabs, panes, recursive ratios, active identity, titles/colors, tags/Smart Tab, profiles, notes/broadcast state, settings, and cwd on Wayland/X11, with corrupt-file fallback
- [x] Persisted drop-down width/height/reveal/focus controls, three-pixel side resize borders, and a full-height pane-information dragger with cardinal-only resize cursors
- [x] Centered live `columns × rows` feedback for divider, dropdown-grip, and window resizing with initial suppression and 750 ms timeout
- [x] Pane-local Ctrl+wheel font increase/decrease with isolated dynamic cell geometry, ordinary wheel preservation, and workspace-persisted reload
- [x] Exact-pane `Profile` submenu with five Zig-owned presets (Global default, Compact, Readable, High contrast, and Mono no ligatures), live isolated family/size/high-contrast/ligature state, Settings `Active pane profile`, and workspace persistence/restoration; the current Cairo lane proves preference delivery rather than visible ligature shaping
- [x] Keyboard, mouse, focus, resize, selection, copy, and safe paste
- [x] ABI v4 packed-row fetches, terminal-owned dirty-span damage with full fallback, coalesced equal-background fills, guarded Cairo glyph caching, rich-style/grapheme fallback, selective cursor redraw, mapped frame-clock presentation, hidden 100 ms coalescing, synchronized-output deadman release, and final-geometry resize coalescing
- [x] GUI-configurable bounded VT scrollback from 0 through 100000 lines applies live, releases excess storage, and preserves logical oldest-to-newest history across resize
- [x] Wayland and X11 clipboard round trips
- [x] Plasma shortcut registration, conflict fallback, recorder persistence, and cleanup
- [x] Noctalia-compatible recorder persistence and generated compositor plans
- [x] Physical X11 F10 delivery through Plasma GlobalAccel
- [x] Live Wayland `noctty-dropdown` layer-shell and D-Bus hidden/status/show/hide/toggle/single-instance gate
- [x] Status border/tooltip and desktop notification receipt
- [x] Settings controls plus persistence/reload, including live bounded scrollback selection and an atomic eight-entry launch-profile library whose selected command/cwd/environment/history are consumed by a real fresh PTY
- [x] Settings stays above its owning NOCTTY window on Wayland and X11, with transient ownership, parent-layer restoration on close, and accessible/focusable Window/Behavior/Appearance category navigation
- [x] Command palette, terminal search, and Quick Note expose explicit assistive names for input/result/status controls; compact UX smoke requires them
- [x] Theme import/select plus persistence/reload
- [x] Work-area-bounded Project Workspace dialog with a two-axis summary scroller, assistive summary/recent-workspace names, and persisted eight-entry MRU
- [x] Live Plasma Wayland/X11 installed desktop/MIME dispatch and Recent Workspaces child activation with mapped/rendered two-tab children and controlled zero exit
- [x] Focus-safe `Open NoctEd Here` handoff with `editor_binary=nocted editor_handoff=true directory_resolved=true editor_process_separate=true`
- [x] Standalone NoctEd transactionally refreshed project tree, reorderable/restorable tabs, lazy translucent minimap, streaming search-result activation, document/project find, reversible folding, bounded multi-selection edits, recent projects, multi-file navigation, clean untitled buffers, native Save As, permission-preserving replacement, atomic first-save, smart-case top-K Quick Open, immutable arena-backed worktree snapshots, coalesced capped structural deltas with conservative fallback, clean-reload/dirty-keep external decisions, two joined/drained filesystem lanes, bounded GTK search backpressure, constant-time document identity, compact model payloads, and Save/Discard/Cancel guards for file/other/all/window close
- [x] NoctEd discrete/smooth `Ctrl+wheel` editor zoom from 60% through 240%, shared across open documents with ordinary scrolling and minimap scaling preserved
- [x] Obsolete embedded editor, duplicate document model, legacy CLI surface, and shutdown-only compatibility lane removed; standalone NoctEd remains the sole editor owner
- [x] Timer-driven autosave and recovery cleanup plus demand-driven bounded
  project refresh when Project / NoctEd opens
- [ ] Current-build two-hour dogfood recapture after the 2026-08-29 scrollbar,
  descriptor-churn, popup/timer, persistence-classification, and NoctEd
  lifecycle fixes; retained historical failures are not current-version proof
- [x] Workspace layout, selection, focus, pane transfer, and guarded broadcast input: context menu, command palette, and `Ctrl+Shift+B` share explicit enable confirmation with `Keep Off` default and immediate disable
- [x] Direct paired session-sharing core and native Linux recovery UX:
  Noise/SAS trust, bounded peer store, pane/tab/session scopes, view-only default,
  per-pane control, checkpoint/resync/reconnect, 64-row remote history,
  state-sensitive actions, clearable terminal roles, confirmed revocation,
  retryable persistence, fail-closed dialog teardown, bounded listener cancel,
  and 64 KiB explicit remote paste
- [ ] Retain mapped Linux interaction/accessibility evidence plus physical
  cross-machine Linux/Windows and routed-VPN qualification; source, loopback,
  cross-build, or isolated-runner admission failures do not close this boundary
- [x] Scale-2 font and high-contrast rendering
- [x] Borderless eight-direction window resizing, native StatusNotifier activation, and right-click `Close NOCTTY` with PTY/menu teardown
- [x] Consolidated `NOCTTY_DEDICATED_DISPLAY=1 ./scripts/native_release_smoke.sh` for disposable compositor sessions

Expected consolidated result:

```text
native_release_smoke renderer=true modes=true tabs=true tab_add=true tab_reorder=true tab_reorder_pointer_drag=true late_callback_guard=true popup_teardown=true window_controls=true tab_rename=true tab_color=true profile_presets=true navigation=true alt_scroll=true ctrl_alt_scroll=true tab_close=true pane_close=true terminal_chords=true layout_presets=true layout_tui=true resize_overlay=true window_resize=true tray=true splits=true recursive_splits=true eight_panes=true click_focus=true clean_selection=true pane_move=true live_tab_position=true compact_ux=true note_overlay=true hot_session=true clipboard=true notifications=true settings=true settings_stacking=true themes=true project=true workspace_activation=true recent_workspaces=true nocted_handoff=true nocted=true maintenance=true workspace=true shortcut=true noctalia_ipc=true hidpi=true
```

Focused profile evidence: `native_grid_profile_preset_smoke context_menu=true submenu=true menu_survived=true presets=5 exact_target=true current=true readable=true font_size=14 isolated=true high_contrast=true rendered=true mono_no_ligatures=true workspace_dirty=true snapshot=true restored=true exited=true`. Repeated backend evidence: `native_grid_profile_preset_matrix wayland=true x11=true exact_target=true isolated=true persisted=true restored=true`.

Focused NoctEd evidence: `nocted_native_gate rendered=true folding=true minimap_overlay_translucent=true editor_zoom=true find_in_files=true project_search_activation=true multi_file_tabs=true tab_navigation=true close_other=true close_all=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true session_dirty_restore=true hot_exit=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true warning_fatal=true backend=x11 scratch_clean=true`.

NCT-104/NCT-105 expanded evidence: `nocted_native_gate rendered=true folding=true minimap_overlay_translucent=true editor_zoom=true find_in_files=true project_search_activation=true multi_file_tabs=true tab_navigation=true close_other=true close_all=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true session_dirty_restore=true hot_exit=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true warning_fatal=true backend=x11 scratch_clean=true`; the same gate passes with `backend=wayland`, and the combined matrix reports both backends true.

Repeated NoctEd backend evidence: `nocted_native_matrix x11=true wayland=true folding=true editor_zoom=true find_in_files=true multi_file=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true session_dirty_restore=true hot_exit=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true real_project=true lifecycle_cycles=8 gtk_tree_draw=true model_latency=true draw_latency=true monitor_burst=true burst_cycles=8 files_per_burst=12 publication_latency=true overflow_recovery=true late_callback_guard=true worker_drained=true warning_fatal=true scratch_clean=true`.

Bounded resource evidence includes the NoctEd core/worker/index/native matrices, the sustained native endurance matrix, installed TUI PTY/VT lanes, exact Cairo and real PTY/VT-to-Cairo qualifications, terminal churn, and `./scripts/native_grid_full_stack_qualification.sh` for live Wayland/X11 idle/fullscreen compositor pixels, root/tree memory, and bounded wakeups. Printed timing and PSS/RSS values are host-local observations, not release thresholds, final compositor acceptance, multi-day proof, or cross-terminal rankings. Authenticated Codex proof is separately bounded to four exact ephemeral read-only requests.

`./scripts/nocted_core_endurance_qualification.sh` is the longer opt-in companion to the maintained 128-cycle verifier lane. It selects the fixed 512-cycle maximum in each mode and retains the exact endurance matrix above without changing the native acceptance boundary.

`./scripts/nocted_native_endurance_qualification.sh` is the mapped companion. It repeats 32 complete workflows in every Debug/`ReleaseSafe` Wayland/X11 lane, retaining 4,096 combined phase cycles, rendered first/final UI, process-tree memory, duration, checksums, warning-fatal execution, and clean scratch.

Production build evidence includes `release_contract version=0.1.0 release_date=2026-07-14 revision=1 build_zon=true noctty_runtime=true nocted_runtime=true production_vte=false production_noctty_tree_sitter=false production_nocted_tree_sitter=true production_smoke_surface=false production_smoke_symbols=false production_legacy_editor=false appstream=true debian=true rpm=true arch=true docs=true` and `package_manifests ... mandatory_vte_dependency=false ...`.

NOCTTY close preflight now covers foreground terminal processes only. NoctEd owns its own graceful Save/Discard/Cancel behavior; forced SIGTERM, SIGKILL, or desktop-session termination remains outside that interactive contract.

Aggregate proof orchestration is state-driven for the prerequisite tab lanes: background-tab close waits for the popup to map and chains close validation into fresh-tab reopen and cleanup, while inline rename uses bounded mapped-tab readiness retries and PTYs held open by explicit read handshakes. This hardens evidence repeatability without changing the `tab_add=true`, `tab_close=true`, or `tab_rename=true` product claims.

## Packaging Gate

- [x] Local `ReleaseSafe` install tree
- [x] Reproducible two-build install tarball
- [x] Same-architecture dependency bundle and launcher/version check
- [x] Both `noctty` and `nocted` binaries, launchers, desktop/AppStream entries, icons, GtkSourceView dependency, and NoctEd syntax/style resources
- [x] Production `noctty` links neither VTE nor Tree-sitter, rejects smoke/legacy-editor commands, and default archives exclude optional `noctty-vte` plus smoke binaries; distribution runtime manifests do not require VTE
- [x] Bundle manifest sidecar with version, architecture, compiler, source revision when available, archive digest, sorted installed files, and sorted bundled-library inventory
- [x] Locally emitted and self-verified SHA-256 sidecars
- [x] Debian source manifest
- [x] RPM source manifest
- [x] Arch x86_64/aarch64 source manifest
- [x] Architecture-local x86_64/aarch64 release workflow definition
- [x] Pinned Zig and self-sufficient x86_64/aarch64 workflow dependency/architecture contract (NCT-076)
- [x] Native `gtk-layer-shell` package dependency/bundle copy and installed Noctalia integration fragments
- [x] Scoped package parser/architecture receipts plus fail-closed bundled-library provenance and embedded license inventory; the prebuilt `gtk-layer-shell` fallback was removed from source publication, and packaging now requires an attributable system library (NCT-077 follow-through)

The dependency-bundle manifest now reports `redistribution_ready=true` only after every copied host library resolves to one package or pinned vendored payload and package notices/canonical SPDX texts are embedded with digests. Missing ownership or text fails the build. This closes the source/tooling payload gap; it is not legal advice, independent review, a retained redistribution receipt, signing, or publication.

## Publication Operations

These actions need external authority or interactive consent and are not source-code blockers:

Current local status receipt:

```text
release_operations_status version=0.1.0 tagged_artifacts=false signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=6
```

The retained evidence layout is defined in [RELEASE_OPERATIONS.md](RELEASE_OPERATIONS.md). Use `./scripts/release_operations_status.sh --require-complete` only after the required files exist.
Use `./scripts/release_operations_status.sh --list-missing` for deterministic issue rows; an empty evidence directory currently reports `release_operations_issues total=21`. The focused smoke reports `semantic_receipts=true`, so arbitrary nonempty receipt files are not enough.
Use `./scripts/release_operations_scaffold.sh /path/to/evidence` to create templates; the scaffold smoke reports `release_operations_scaffold_smoke templates=true fake_artifacts=false placeholder_blocked=true require_complete_blocks=true scratch_clean=true`.
Use `./scripts/release_operations_artifact_intake.sh <arch> <archive.tar.gz> /path/to/evidence` to retain architecture artifacts; its smoke reports `release_operations_artifact_intake_smoke x86_64=true aarch64=true sidecars_verified=true retained_status=true mismatch_blocked=true scratch_clean=true`.
Use `./scripts/release_operations_signature_intake.sh <arch> <archive|checksum|manifest> <signature-file> /path/to/evidence` to retain signatures after their canonical targets exist; its smoke reports `release_operations_signature_intake_smoke archive=true checksum=true manifest=true x86_64=true aarch64=true placeholder_blocked=true target_required=true retained_status=true scratch_clean=true`.
Use `./scripts/release_operations_receipt_intake.sh <publication|dependency-bundle-redistribution> <receipt-file> /path/to/evidence` to retain semantic publication and redistribution receipts; its smoke reports `release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true`.
Use `./scripts/release_operations_acceptance_intake.sh compositor <name> <receipt-file> /path/to/evidence` and `./scripts/release_operations_acceptance_intake.sh wayland-hid <receipt-file> /path/to/evidence` to retain compositor and consent receipts; its smoke reports `release_operations_acceptance_intake_smoke compositors=6 wayland_hid=true semantic=true placeholder_blocked=true compositor_mismatch_blocked=true consent_required=true complete_status=true scratch_clean=true`.

- [ ] Run the tagged x86_64 and aarch64 workflow and retain both artifacts/checksums.
- [ ] Sign release artifacts with the project release key and retain all six artifact/checksum/manifest signatures.
- [ ] Publish the tag, packages, checksums, signatures, and release notes.
- [ ] If publishing a dependency bundle, independently review the generated package/license inventories and retain the redistribution receipt with the exact ready-manifest attestations.
- [ ] Retain final acceptance receipts from available Niri, Hyprland, Sway, Scroll, Labwc, and MangoWC release sessions; the current host has none of those compositors installed.
- [ ] Optionally capture physical Wayland recorder/activation evidence through an explicitly consented RemoteDesktop/EIS portal session.

Normal Plasma Wayland GlobalAccel and the shared Noctalia layer-shell/D-Bus/freedesktop contracts are already verified programmatically. The compositor-session row is acceptance evidence rather than missing application code. The final optional row concerns synthetic physical-input evidence only; NOCTTY must never bypass compositor consent.
