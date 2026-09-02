# NOCTTY

NOCTTY is a native terminal workspace for KDE Plasma, Noctalia Shell, Wayland, and X11. Its standalone project editor is NoctEd. Both executables are written in Zig with thin native ABI boundaries—there is no Electron, browser runtime, JavaScript runtime, telemetry, update ping, or remote feature flag.

The experimental x86_64 Windows host now owns a bounded native workspace of up
to 16 tabs and 32 independent ConPTY/Zig-VT panes with recursive split-down and
split-left layouts, keyboard creation/cycling/close actions, click focus, and
per-pane resize/output/reply routing. Debug and `ReleaseSafe` cross-builds pass,
and the Wine-hosted no-window self-test covers VT state plus nested layout,
tab/pane cycling, close collapse, and final-session protection. The source
tranche also implements native settings, saved-layout restore, launch profiles,
selection/mouse reporting, a separate native Windows NoctEd, reproducible
per-user NSIS packaging, and a checksum-bound PI WEB QOL-discoverable dogfood
ZIP whose PowerShell installer verifies the payload, runs installed self-tests,
and retains a local receipt. Wine does not prove physical
ConPTY/GDI/input/editor or installer behavior; physical Windows qualification,
publisher signing, and physical dogfood remain open.

Product status: the 0.1.0 Plasma and Noctalia behavior scope plus local release-source evidence contracts are implemented and verified as of 2026-08-29. Native VT scrollback uses bounded ring retention (`scrollback_ring=true`) with a GUI-configurable 0-to-100000-line limit and compact memory-only cold logical lines. Monotonic line IDs, grapheme-relative anchors, wrap metadata, and style runs preserve logical identity through true primary-screen reflow; explicit shrink forces cold-arena compaction, while alternate-screen resize remains non-reflowing and safe (`scrollback_slab=true`, `scrollback_lazy_growth=true`, `alternate_resize_safe=true`). Full-screen visible rows rotate without moving the slab and printable ASCII is consumed in equivalent runs (`visible_grid_ring=true`, `vt_ascii_run=true`). Native draw crosses size/version-checked ABI v6, consumes terminal-owned dirty spans, fetches packed rows once, coalesces equal-background fills, caches eligible glyph conversions, redraws cursor cells selectively, and falls back for graphemes and rich styles (`packed_cell_render=true`, `render_abi=packed_rows`, `render_abi_version=6`, `damage_tracking=dirty_spans`, `glyph_batching=true`, `glyph_cache=true`, `blank_cell_draw_skipped=true`, `draw_cursor_cached=true`, `draw_font_switch_dedup=true`). Mapped output presents through one owned GTK frame-clock callback, hidden output remains coalesced at 100 ms, and interactive resize commits only the latest geometry; output-ready PTY descriptors still drive bounded reads through one guarded native-process pump scratch, with private scratch for standalone sessions and a pane-local fallback only when descriptor registration fails (`frame_clock_present=true`, `pty_event_source=true`, `timer_read_polling=false`, `output_present_coalesced=true`, `hidden_present_throttled=true`, `event_source_cleanup=true`, `descriptor_fallback=root_coalesced`, `pane_exit_timers=0`, `source_cleanup=centralized`). Cursor blink and maintenance are root-coalesced, unmapped areas do not queue redraws, foreground jobs receive close confirmation, and accepted pane/tab retirement releases the complete VT grid plus dynamic session object immediately. Pane creation initializes root and borrowed state explicitly, and a retirement barrier prevents late callbacks from dereferencing released session state (`root_timer_coalesced=true`, `mapped_redraw_only=true`, `foreground_guard=true`, `session_storage_released=true`, `late_callback_guard=true`). Production `noctty` links neither VTE nor Tree-sitter and contains no fallback, smoke, or legacy-editor command surface. The bounded table-driven VT supports rich SGR, grapheme cells, OSC 8, blocked OSC 52, bounded replies, and synchronized output. Bounded Debug/`ReleaseSafe` real-PTY repetition proves zero allocator/process residue and force-removal of HUP-resistant foreground groups; a real installed-application tranche now qualifies Codex's unauthenticated login surface, Vim, and btop through the production PTY/VT model; the exact production-Cairo renderer matrix additionally proves deterministic repeated fixtures, byte-identical cross-mode PNGs, host-local draw CPU, zero renderer-owned warm-frame allocations, and bounded resize scratch. A complementary real-shell pipeline retains display-independent input-write/PTY-read-start through VT and exact Cairo-draw percentiles, repeated/cross-mode pixels, zero warm-frame allocations, and separate root/tree memory. A live Plasma companion retains 64 mapped synthetic production key-handler-to-draw/after-paint samples per mode on Wayland/X11, frame intervals, predictions, and completed Wayland GDK presentation feedback. NCT-119 is now complete through an additional live Debug/`ReleaseSafe` Wayland/X11 idle/fullscreen matrix with OCR-validated compositor pixels, external root/tree memory, zero fallback PTY timer ticks, and bounded cursor/maintenance wakeups. Authenticated Codex 0.144.6 mapped acceptance is retained on Wayland/X11. The NCT-112 hidden/visible harness also passes its Debug/`ReleaseSafe` Wayland/X11 shakedown with zero hidden draws, zero fallback PTY ticks, external resource samples, and compositor pixels; broader agent products, physical input, and the elapsed 48-hour qualification remain outside those bounded receipts. A pinned fourteen-project peer review additionally fixed blank-tail resize reflow, added payload-free OSC 9/99/777 pending-input attention, and moved PTY input backpressure into a bounded nonblocking session queue; the focused 8 MiB sleeping-child caller probe changed from 921.618 to 1.450 ms. The retained direct GLib lane now runs one continuous flood against 29 exact marker PTYs and exercises 8 MiB paste drain plus pending-paste teardown with zero allocator/process residue; `ReleaseSafe` delivered every marker below 2.5 ms without changing the 2 MiB pump ceiling or source priority. Broadcast input now routes the pane menu, command palette, and `Ctrl+Shift+B` through one warning that defaults to `Keep Off`; disabling is immediate. Settings category navigation has explicit accessibility names, 48-logical-pixel focusable rows, destination-specific tooltips, selected/focus contrast, initial keyboard focus on Window, and narrow-work-area scrolling; command search/results, terminal search/status, and Quick Note/status now have explicit assistive names covered by the compact smoke (`native_settings_category_navigation=true`, `transient_accessible=true`). The dependency-bundle source lane now embeds package ownership, expressions, installed notices, canonical SPDX texts, and a fail-closed manifest attestation; independent redistribution review/receipt, credentialed signing/publication, retained architecture artifacts/signatures, unavailable-compositor acceptance, and consented Wayland HID capture remain separate operations in [the release checklist](RELEASE_CHECKLIST.md).

Dogfood reliability status was refreshed on 2026-08-29. Local source/build
proof now covers native-rail priority over Codex mouse mode, top-level popup
anchoring, retired-context and sharing-timer guards, demand-driven project scans,
recoverable persistence-error classification, and idempotent NoctEd main-loop
teardown. The initial aggregate check passed 418/418. The final current-source
rerun passed 411, skipped one, and failed only six loopback-sharing cases because
the sandbox denies socket creation; fresh production NOCTTY and both smoke
binaries compile. A follow-on source/behavior audit makes recoverable text
actions and hot-session persistence report their real status without poisoning
hard state synchronization, bounds and surfaces theme imports, keeps theme
selectors/redraws current, exposes workspace I/O failures, restores two-axis
narrow Settings access, gives terminal and NoctEd close controls contextual
accessible names, removes duplicate split resize work, and gives the reviewed
legacy X11 runner a private runtime directory. Focused source checks, seven
theme tests, static C analysis, and current binary compilation pass. The
current graphical-flow audit failed closed because this sandbox denied private
D-Bus socket creation, so no new mapped screenshot or compositor evidence is
claimed. A final low-risk native pass now uses the selected pane cwd as the
actual `Open NoctEd Here` child working directory, rechecks theme-file size
after reading, returns checked config-persistence results for profile and theme
actions, bounds find/note/shortcut/palette surfaces to the monitor work area,
stacks narrow find and command layouts, makes Quick Note load failure
non-destructive, announces dynamic note/theme failures through ATK alert roles,
and exposes failed agent-reference clearing. The smoke binary and native-layout
contract pass. A 520x420 compact mapped run was attempted only through the
reviewed isolated-display wrapper and deferred fail-closed by its I/O pressure
gate; it is not new visual proof. A 2026-09-02 installed-log follow-through
closes the recurring Wayland non-topmost popup-parent warning by dismissing
stale process-local popups before terminal/tab menus and adds that exact warning
to the clean-log failure contract. Repeat dogfood installation now accepts a
retained GTK Layer Shell library only when it matches the prior private build
receipt; the current `ReleaseFast` install passed that path after the system
package was removed. This does not supersede the retained descriptor/GTK
failure logs: a clean installed two-hour Wayland recapture is NCT-125, and the
48-hour NCT-112 matrix remains a separate release boundary.

The closing low-effort UI pass gives the restore-mode, encrypted-history,
agent-resume, and sharing form controls explicit assistive names. Session
sharing plus NoctEd's main, document-find, project-search, and Quick Open status
changes now publish de-duplicated native ATK status/alert events. Inline tab
rename, workspace-tag, Noctalia-import, and NoctEd language-service controls
are explicitly named, and tag validation trims an owned copy instead of GTK's
borrowed entry text. The sharing preview's size request is derived from the
already workarea-bounded dialog rather than forcing 480x260 logical pixels on
compact screens, and the focused sharing smoke checks the new names, status
role, and bounded request. Both smoke binaries compile and
the native-layout source contract passes. A focused mapped run failed closed at
the sandbox's read-only shared-runner lock and then its private D-Bus socket
restriction, so no new screenshot, compositor, or interaction evidence is
claimed.

The follow-up session-sharing audit closes the confirmed low-risk recovery
defects without expanding the relay or service boundary. Host and viewer
terminal states can be cleared, impossible concurrent actions are insensitive,
revoked peers are no longer actionable, revocation is confirmed, paired-device
write failures remain current-run-only and retryable, and a full 64-peer store
reclaims revoked slots only when a newly confirmed device needs capacity.
Closing the only sharing surface now stops discovery, pairing, hosting, and
receiving so no network role continues without a persistent indicator. Pairing
listener cancellation polls at 50 ms before accept; remote input failures retain
three seconds of native alert feedback; and clipboard forwarding is explicitly
bounded to 64 KiB with best-effort bracket closure after a failed chunk. The
three focused identity-store tests, strict smoke-binary compile, Windows Debug
cross-build, formatting check, and native-layout source contract pass. A direct
pair-controller test was not linked by the ad hoc command because the host Zig
linker rejects the distro CRT `.sframe` relocation; the regression is retained
in the repository test graph but was not executed here. No mapped screenshot or physical
cross-machine qualification is claimed.

NoctEd provides the standalone `nocted` process and binary with a compact transactionally refreshed project tree, reorderable/restorable tabs, translucent source minimap, bounded shared `Ctrl+wheel` editor zoom with independent minimap scale, document find, streaming Find in Files, reversible code folding, bounded Unicode select-all-occurrences transactions, recent projects, and direct vendored Tree-sitter highlighting for Zig/JSON/C/shell/Markdown with complete GtkSourceView fallback. Direct parsing is coalesced for 100 ms, limited to 32 KiB and 4,096 captures on GTK's main thread, and fails over visibly rather than publishing a partial capture set. NoctEd also retains bounded GUI-driven TextMate JSON grammar conversion, bounded UTF-8 editing, permission-preserving atomic save, clean untitled buffers, native Save As, and capped fuzzy project quick-open. At most two lazy GLib lanes separate foreground document I/O from background index/search work behind one 64-job cap; GTK publication stays on the main thread, cancellation is generation-owned, and shutdown joins and drains both lanes (`nocted_worker=bounded`, `nocted_worker_lanes=2`). The immutable worktree snapshot stores paths in one arena, applies bounded ignore rules, feeds search/Quick Open without deep path cloning, and is refreshed by capped coalesced GIO create/delete/move/rename deltas on the scan lane. Ignore-control, malformed, unknown, and overflow events fall back to the bounded full scanner. Native clean-reload and dirty-keep external-change decisions are live. Multi-selection rendering/one-action undo, atomic ordered session restoration, dirty saved/untitled hot exit, recent-project activation, grammar conversion, safe runtime-manager replacement, duplicate precedence, open-buffer re-detection, and generated definition activation pass warning-fatal X11 and Wayland proof (`multi_selection=true`, `session_restore=true`, `session_dirty_restore=true`, `hot_exit=true`, `recent_project=true`, `textmate_import=true`, `textmate_language=true`, `textmate_precedence=true`). Private `0600` session version 2 keeps bounded dirty UTF-8 snapshots while reading version-1 saved-tab state. Versioned settings/session parsing safely defaults after malformed or oversized state and preserves the last complete file across interrupted atomic replacement; Debug/`ReleaseSafe` also prove the legacy Bash scanner callback under optimization (`nocted_state_recovery_matrix debug=true release_safe=true legacy_shell_parser=true malformed_state_corpus=13 oversized_fallback=true interrupted_replace=true settings_atomic=true session_atomic=true scratch_clean=true`). Bounded real-project tree-draw, actual GIO burst-to-draw, overflow-recovery, and post-widget callback evidence passes on X11 and Wayland. Two eight-cycle Debug runs retain native Wayland first-result/completion/cancellation/GTK-draw, open/save-under-load, deterministic Quick Open, bounded-batch, and worker-drain values. Eight-cycle X11 and live Plasma Wayland Debug/`ReleaseSafe` resource runs establish the baseline. The later native endurance matrix repeats 32 complete workflows in every mode/backend lane, retaining 4,096 combined phase cycles, 3,072 deterministic ranking evaluations, process-tree memory, rendered first/final UI, and clean teardown over 630 seconds. This closes NCT-106/NCT-121/NCT-122's sustained one-host alpha boundary without implying Sublime Text 2/Zed parity, varied-project coverage, or multi-day stability.

NoctEd file loading is generation-consistent: device/inode/size/nanosecond-mtime identity must agree before and after a read, a one-time external rewrite retries to the current generation, and continuous churn fails after three bounded attempts instead of publishing stale bytes. A deterministic 512-case Debug/`ReleaseSafe` robustness lane covers 256 actual-file inputs and 256 TextMate JSON mutations (`nocted_fuzz_race_matrix debug=true release_safe=true document_cases=256 grammar_cases=256 external_read_race=true stable_retry=true retry_cap=3 perpetual_churn_rejected=true scratch_clean=true`). This is bounded fixture proof, not a long-duration fuzzer or stability-parity claim.

The repeatable NoctEd core stability lane adds 128 allocator-accounted cycles per mode across atomic save/load, selection/folding, project scan/search, Quick Open, and grammar conversion. It repeats a three-query full-order ranking corpus in every cycle, producing one stable fingerprint in Debug and `ReleaseSafe`. Every cycle returns active requested bytes to baseline and both modes exit with zero residual and a clean leak check; exact host-local p50/p95/p99 plus root PSS/RSS are retained in [the stability receipt](NOCTED_STABILITY_QUALIFICATION.md) and [NCT-122 search/load receipt](NOCTED_SEARCH_LOAD_QUALIFICATION.md). Its stable contract is `nocted_core_stability_matrix debug=true release_safe=true cycles=128 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_cycles=128 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true scratch_clean=true`. It is not GTK, worker-load, large-index, multi-day, or cross-backend stability proof.

The opt-in [NoctEd core endurance qualification](NOCTED_CORE_ENDURANCE_QUALIFICATION.md) raises that exact runner to 512 cycles per mode. The retained 459-second run covers 1,024 total atomic save/load, edit/fold, scan/search, Quick Open, grammar, and allocator cycles plus 3,072 full-order ranking evaluations: `nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true`. This is bounded headless endurance, not GTK worker, compositor, varied-project, or multi-day native-GUI proof.

The maintained [NoctEd GLib worker qualification](NOCTED_WORKER_QUALIFICATION.md) now crosses the exact shared admission and queue transaction used by production `App.submitWorkerJob`—generation supersession, the 64-job shared cap, 32-live-job lane caps, cancelled-lane exclusion, kind cancellation, pending lookup, lazy pool creation, failure-safe append, push rollback, and ordered retirement—then executes `Worker` through two real single-thread GLib pools with idle-callback delivery, snapshot-first streaming search, cooperative cancellation, two-batch backpressure, and atomic foreground save while scan is blocked. Debug and `ReleaseSafe` both drain with zero allocator residue and positive root-process memory: `nocted_worker_matrix debug=true release_safe=true shared_admission_policy=true generation_supersession=true shared_queue_cap=64 lane_queue_cap=32 cancelled_lane_excluded=true kind_cancel=true pending_lookup=true lazy_pool_creation=true transactional_enqueue=true append_failure_safe=true push_failure_rollback=true ordered_retirement=true glib_thread_pools=true worker_lanes=2 project_scan=true search_streaming=true snapshot_first=true cooperative_cancellation=true search_batch_size=24 search_batch_cap=2 backpressure_exercised=true foreground_save_under_backpressure=true worker_drained=true allocator_leak_free=true process_memory=true scratch_clean=true`. It is real headless admission/queue/GLib-worker evidence, not GTK widget publication, compositor, key-to-pixel, or long-duration GUI proof.

The [NoctEd project-index qualification](NOCTED_PROJECT_INDEX_QUALIFICATION.md) creates real disposable 4K, 25K, and 100K-entry projects in Debug and `ReleaseSafe`, retaining exact full-scan/delta timing, broad-match Quick Open latency with a 500 ms `ReleaseSafe` 100K-entry budget, compact index/two-snapshot bytes, root PSS/RSS, directory rename, replacement-conflict, ignore/overflow fallback, and zero-residual allocator proof. Its stable contract is `nocted_project_index_matrix debug=true release_safe=true scales=4000,25000,100000 immutable_delta=true quick_open_scale=true quick_open_release_safe_budget_ms=500 directory_rename=true replacement_conflict=true ignore_fallback=true overflow_fallback=true scan_time=true delta_time=true index_memory=true two_snapshot_peak=true process_memory=true allocator_leak_free=true scratch_clean=true`. The complementary [native project-lifecycle qualification](NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md) retains eight current-repository model/tree-draw cycles, eight actual twelve-file monitor bursts, bounded overflow recovery, publication latency, worker drain, and a post-widget late-callback guard on X11 and Wayland. These are bounded one-host receipts, not sustained multi-hour/multi-day or universal performance proof.

The deterministic [terminal compatibility qualification](TERMINAL_COMPATIBILITY_QUALIFICATION.md) runs the production Zig VT/Unicode state through 23 pinned protocol cases and six feed schedules, 128 malformed 4096-byte cases with resize churn, 256 Unicode mutations, and all 766 Unicode 17 grapheme-break cases in Debug and `ReleaseSafe`. Both corpora are SHA-256 guarded and every temporary grid returns requested-byte accounting to baseline; the stable contract is `terminal_compatibility_matrix debug=true release_safe=true protocol_cases=23 schedules=6 malformed_cases=128 unicode_mutations=256 grapheme_cases=766 allocator_leak_free=true scratch_clean=true`. This closes the deterministic protocol/state and broader malformed/Unicode tranche, not real Codex/Claude/Antigravity/ncurses, rendered-pixel, multi-day fuzz, or cross-backend acceptance.

The [real TUI qualification](TERMINAL_REAL_TUI_QUALIFICATION.md) starts installed Codex 0.144.5, Vim 9.2, and btop 1.4.7 through production launch profiles, PTYs, `TerminalSession`, and `Vt.Grid` in Debug and `ReleaseSafe`. It retains the unauthenticated Codex login surface and synchronized output, Vim alternate-screen/bracketed-paste/focus behavior, btop alternate-screen/mouse/truecolor/Unicode behavior, foreground identity, routed exit input, clean process/allocator teardown, separate root/tree memory, and scoped cleanup: `terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true`. It is headless terminal-model proof, not an authenticated model request or mapped compositor/pixel receipt. The complementary [authenticated-agent qualification](AUTHENTICATED_AGENT_QUALIFICATION.md) submits four ephemeral read-only Codex 0.144.6 requests through the production command profile and retains exact responses, mapped Wayland/X11 screenshots, root/tree memory, and controlled exits: `native_grid_authenticated_agent_matrix provider=codex version=0.144.6 authenticated=true model_requests=4 debug=true release_safe=true wayland=true x11=true production_pty=true production_vt=true production_gtk=true production_cairo=true response_exact=true compositor_pixels=true root_memory=true process_tree_memory=true controlled_exit=true ephemeral=true sandbox=read-only hid=false checksums=true scratch_clean=true`.

The [ncurses application qualification](TERMINAL_NCURSES_QUALIFICATION.md) adds installed nano 9.1, less 704, and dialog 1.3-20260107 through the same production path in both modes. It retains nano editing/mouse and alternate-screen state, less paging and alternate-screen state, dialog's styled primary-screen widget behavior, foreground identity, routed zero exits, allocator/process teardown, separate root/tree memory, and scoped cleanup: `terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`. This remains headless evidence for three exact installed versions, not universal ncurses or mapped compositor proof.

The [system TUI qualification](TERMINAL_SYSTEM_TUI_QUALIFICATION.md) adds installed top 4.0.6-dirty, watch 4.0.6-dirty, info 7.3, whiptail 0.52.25, fzf 0.74.0, SQLite 3.53.3, Glances 4.5.5, Bash 5.3.15, man-db 2.13.1, and OpenSSH SFTP 10.4p1 through the same production path. It retains primary/alternate screen behavior, watch's plain refresh surface and ETX handling, info browsing, whiptail's Unicode newt widget, fzf's styled Unicode filter and input modes, SQLite's plaintext in-memory REPL, Glances' styled monitor with update checks disabled, Bash's isolated Readline shell, man's styled nested less pager, SFTP's direct local client/server prompt without a network bind, foreground identity, routed zero exits, allocator/process teardown, separate root/tree memory, and scoped cleanup: `terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`. This remains headless evidence for ten exact installed versions, not universal TUI or mapped compositor proof.

The [terminal-session qualification](TERMINAL_SESSION_QUALIFICATION.md) runs 64 ordinary and eight deliberately stubborn real-PTY lifecycles per mode through production spawn, resize, VT ingestion, exit polling, and teardown. Every cycle returns `DebugAllocator` requested bytes to baseline; both modes exit at zero, and every HUP/TERM-resistant foreground group is forced down after the bounded grace period even when its interactive shell exits first. The stable contract is `terminal_session_qualification_matrix debug=true release_safe=true normal_cycles=64 forced_cycles=8 sessions_per_mode=72 total_sessions=144 allocator_leak_free=true forced_group_shutdown=true latency_percentiles=true root_memory_separate=true process_tree_memory=true scratch_clean=true`. It is bounded headless process evidence, not a multi-day native-GUI or rendered agent-latency claim.

The [agent-fairness qualification](TERMINAL_AGENT_FAIRNESS_QUALIFICATION.md) starts thirty real production PTY/session/VT instances behind equal-priority GLib Unix-FD sources and one shared guarded scratch. One pane floods continuously while 29 panes publish exact markers; both modes deliver every marker while flood bytes continue. The same runner proves an 8 MiB queued paste drains to an exact child marker and that teardown removes a separate session/process group while another 8 MiB paste remains pending. PTY shutdown retains its bounded 50-iteration fallback while a monotonic 500 ms deadline prevents scheduler-stretched sleeps from extending the graceful phase. The stable contract is `terminal_agent_fairness_matrix debug=true release_safe=true panes=30 flood_panes=1 marker_panes=29 all_markers=true shared_pump_scratch=true glib_fd_sources=true large_paste_bytes=8388608 paste_queue_exercised=true paste_drained=true paste_pending_teardown=true allocator_leak_free=true process_residual=0 scratch_clean=true`. It is not mapped GTK/frame-clock/compositor evidence.

The [session-continuity qualification](SESSION_CONTINUITY.md) adds GUI-managed **Persistent tmux** and **Persistent Zellij** launch kinds, version-9 persistence, conservative session-name validation, and fixed direct argv at the production PTY adapter. Debug and `ReleaseSafe` pass exact-argv executable shims through the real PTY/VT grid with cwd/environment/history and allocator checks: `launch_continuity_matrix debug=true release_safe=true kinds=tmux,zellij direct_argv=true create_or_attach=true production_pty=true cwd=true environment=true controlled_exit=true allocator_leak_free=true tool_shims=true installed_tools=false live_reattach=false scratch_clean=true`. The complementary installed matrix now proves tmux 3.7b and Zellij 0.44.3 first attach, detach, NOCTTY relaunch, reattach, preserved content, and compositor pixels in every Debug/`ReleaseSafe` Wayland/X11 lane.

The [native-grid renderer qualification](NATIVE_GRID_RENDERER_QUALIFICATION.md) calls the exact production Cairo draw function for idle, full-screen, and rich-style 160×50 fixtures without requiring a display. Debug and `ReleaseSafe` each measure 128 frames per scenario, require exact repeated pixels and byte-identical cross-mode PNGs, and count the renderer-owned packed-row/glyph/cache allocations through grow/shrink. The stable contract is `native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true`. It is bounded display-independent renderer evidence, not GTK/compositor, full-stack allocator, frame-clock, PTY/input-to-draw, or real-agent proof.

The [terminal pipeline qualification](TERMINAL_PIPELINE_QUALIFICATION.md) advances that synthetic boundary through 64 real shell/PTY/VT updates and exact production-Cairo draws per run, twice in each mode. It retains input-write-to-draw and PTY-read-start-to-draw p50/p95/p99, draw CPU, measured output bytes, zero warm-frame renderer allocations, separate root/tree memory, and repeat/cross-mode-identical final pixels: `native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true`. It is display-independent end-to-Cairo evidence, not GTK key-event, mapped frame-clock, compositor-presentation, or photon latency proof.

The [mapped presentation qualification](NATIVE_GRID_PRESENTATION_QUALIFICATION.md) adds 64 live production PTY/VT/GTK samples per mode/backend from synthetic production key-handler start through mapped Cairo draw and frame-clock `after-paint`. Plasma Wayland also returned completed GDK presentation timestamps; X11 returned predictions but no completed presentation timestamp. The [full-stack qualification](NATIVE_GRID_FULL_STACK_QUALIFICATION.md) complements it with live Wayland/X11 idle/fullscreen compositor pixels, external memory, and bounded wakeups. Together with the renderer, pipeline, and fairness lanes, this closes NCT-119. Physical HID and final compositor acceptance remain release operations.

The completed NCT-111 [native launch-profile](LAUNCH_PROFILES.md), [session continuity](SESSION_CONTINUITY.md), [installed continuity](INSTALLED_CONTINUITY_QUALIFICATION.md), and [workspace activation](WORKSPACE_ACTIVATION.md) tranches are retained. Settings owns an atomic active profile plus a bounded library of up to eight named shell/command/SSH/Persistent-tmux/Persistent-Zellij profiles with absolute/inherited cwd, bounded environment overrides, and independent new-session scrollback. Users can save/replace, select, and delete names without editing files; deleting a selected name deliberately leaves its launch values active as custom state. Fresh workspaces and new tabs/splits consume the active profile, while hot-restored panes retain saved cwd and fresh-shell recovery semantics. Local `noctty:`/`file:` activation validates and restores a `.nocttyws` snapshot before creating PTYs, and the native Project Workspace dialog exposes an eight-entry recent list plus an adaptively sized, horizontally and vertically scrollable summary with explicit assistive names. Each explicit activation opens a separate native process so current terminals remain intact. Credentialed SSH acceptance now uses the real OpenSSH client/server with disposable public-key credentials and a pinned host key through NOCTTY's PTY (`credentialed_ssh=true`). Exact tmux/Zellij create-or-attach dispatch passes through the production PTY with smoke-only executable shims, and the installed matrix adds live mapped reattach with preserved session content. The installed-desktop acceptance harness validates the real desktop/MIME contract, drives `gio`, and clicks the real Recent Workspaces button through disposable installed trees. Its prefix, local/global Zig caches, XDG cache, and temporary tree remain isolated under one trap-cleaned root. Live Plasma Wayland and X11 now retain mapped/rendered two-tab child receipts and controlled zero exits; the harness forces the guaranteed `C` locale under fatal-warning mode and exempts only the hidden restored tab from the visible-draw assertion. Installed tmux/Zellij detach/relaunch/reattach now passes with locally installed signature-verified binaries; the tools remain external to NOCTTY's runtime package.

The source-backed [terminal and editor algorithm audit](PERFORMANCE_ALGORITHM_RESEARCH.md) compares the hot paths with transferable designs from Alacritty, Ghostty, WezTerm, Kitty, foot, Zed, VS Code, ripgrep, fzy, GTK/GIO/Cairo, Tree-sitter, and Unicode specifications. Its accepted frame-clock, Cairo glyph-cache, bounded VT/synchronized-output, stable logical-line, compact worktree-index, GIO monitoring, two-lane admission, streaming-search, and top-K Quick Open designs are implemented. NCT-110/NCT-119/NCT-120/NCT-121/NCT-122 are complete at their bounded one-host boundaries. NCT-112 now has a passing four-lane hidden/visible harness shakedown but remains partial until the retained 48-hour authenticated run elapses. A detached-worktree 32-session pass additionally rejected smaller universal read arrays, early default-history compression, Pango-layout reuse, and Cairo font-option caching; the accepted shared pump scratch reduces `TerminalSession` from 141,344 to 10,352 bytes and removes about 3.88 MiB of structural recurring-read storage at 32 sessions. A second accepted alignment-only pass reduces hot terminal cells from 16 to 14 bytes and retained lower output RSS in every alternating pair without a median throughput regression. The follow-up idle-history pass leaves active output hot, then cold-packs unfocused/focused panes after 30/300 seconds in process-wide bounded steps; libc-backed eager virtual slabs plus completion-wave trimming saved 40.72 MiB across thirty 120×40 core grids and 7,084 KiB USS in a delayed narrow 32-pane native sample while seven active A/B pairs retained throughput. The benchmark now records USS and supports post-output settle windows. A subsequent fourteen-repository review retained blank-tail reflow pruning, explicit OSC notification attention, and nonblocking queued PTY writes while rejecting copied GPU/thread/browser/auto-hibernation architectures. Herdr-inspired continuity badges, bounded provider resume references, GUI restore modes, explicit safe notification actions, and password-protected encrypted history export are now implemented without changing the native runtime boundary. The bounded results are in [the agent-scale research receipt](TERMINAL_AGENT_SCALE_RESEARCH.md) and [the peer-research record](TERMINAL_PEER_RESEARCH.md). GPU rendering, per-pane thread sets, and a custom rope/piece tree remain deferred (`performance_algorithm_research=true`, `terminal_peer_research=true`).

Retained earlier hardening receipts remain part of the verified boundary: `note_overlay_cached=true`, `note_overlay_font_cached=true`, `note_overlay_preview_bounded=true`, `tab_setter_dedup=true`, `pane_tooltip_dedup=true`, `tab_color_style_dedup=true`, `tab_suffix_stack=true`, `native_perf_memory_polish=true`, `native_memory_leak_hardening=true`, `native_allocation_polish=true`, `native_deep_memory_hardening=true`, `git_parse_cap_before_alloc=true`, `smart_filter_label_stack=true`, `terminal_find_status_stack=true`, `scrollback_lazy_growth=true`, `alternate_resize_safe=true`, `packed_cell_render=true`, `blank_cell_draw_skipped=true`, `idle_metadata_probe_suppressed=true`, `idle_exit_poll_throttled=true`, `native_host_callback_cleanup=true`, `literal_paste_single_pass=true`, `paste_session_allocator=true`, `tick_noop_dedup=true`, and `idle_redraw_suppressed=true`.

Compact terminal tabs support native pointer drag/reorder with GTK's insertion indicator and overflow scrolling. Background-tab moves preserve the active tab, accepted stable-ID order is persisted through the coalesced hot-session path, rejected model changes roll GTK back, and tabs remain attached to the owning NOCTTY window (`tab_reorder_pointer_drag=true`, `tab_reorder_active_identity=true`, `tab_reorder_rollback=true`, `tab_reorder_persistence_coalesced=true`).

The workspace has one optional 18-pixel active-pane information strip below the notebook, leaving bottom-positioned tabs immediately above it. Modeled on Yakuake/Konsole's local session-title default, it renders `short cwd : foreground process`. NOCTTY resolves the PTY foreground process group on focus/tab changes and through the existing root-owned one-second maintenance pass, reads bounded `cwd` and `comm` data through the Zig PTY module, and falls back to the saved pane cwd plus `shell`. The full pane ID, PID, process, and directory remain in the tooltip; unchanged label/tooltip updates are skipped (`pane_info=true`, `pane_source=pty_proc`, `pane_refresh=coalesced`, `pane_info_dedup=true`). Appearance > Client chrome exposes the persisted toggle, so no settings-file editing is required. Yakuake's SSH-specific username/host title expansion is not claimed by this local metadata slice.

Window hide and shutdown pop down owned menus and process-local GTK popup windows before unmapping the parent. The Wayland/X11 hot-session matrix runs with GLib/GDK warnings fatal and proves this ordering (`popup_teardown=true`).

The maintained [split-terminal benchmark](TERMINAL_BENCHMARK.md) compares fresh 1/2/4/8-pane terminal process trees on one controlled X11/XWayland host. Offscreen runs use the reviewed shared private-display runner; compositor-backed runs require explicit disposable-session acknowledgement and otherwise fail closed. The harness stops Yakuake before and after its isolated run. Deterministic terminal-order rotation, one-second clean intervals, and per-pane WezTerm readiness keep peer carryover bounded (`benchmark_order_isolated=true`, `wezterm_split_ready=true`). Writer completion remains ingestion evidence; settled pane geometry and a separate externally captured X11 pixel marker now bound grid parity and draw completion without claiming compositor latency (`split_terminal_benchmark=true`, `yakuake_exclusive=true`, `process_tree_pss=true`, `pty_pump_bounded_drain=true`, `native_output_throughput=true`).

The current Yakuake-replacement and coding-agent boundary is recorded in [the daily-driver audit](DAILY_DRIVER.md). NOCTTY's own eight-pane benchmark median is 33.884 MiB PSS with workload subtrees excluded; Codex, Claude Code, Antigravity, MCP servers, and subagents must be measured as separate child process trees. The audit includes explicit-PID PSS/RSS tooling and conservative configuration guidance, and keeps modern VT, persistent live sessions, and long soaks open.

Unchanged title/BEL probes, idle exit checks, would-block redraws, and redundant status events remain suppressed (`idle_metadata_probe_suppressed=true`, `idle_exit_poll_throttled=true`, `idle_redraw_suppressed=true`, `tick_event_throttled=true`).

## Product

The default launch uses NOCTTY's own Zig PTY, terminal grid, and session lifecycle, rendered by a thin GTK/Cairo host. It provides:

- Dropdown, freely resizable borderless windowed, and zen-fullscreen modes on Plasma Wayland/X11 and Noctalia-compatible Wayland compositors.
- Thin client chrome, a persistent Yakuake-density tab row with compact `×N` pane counts, deduped tab markup/tooltip setter updates, bounded tab-color CSS provider rebuilds, native pointer drag/reorder, and 28-logical-pixel width and 18-logical-pixel height GTK symbolic New Tab, per-tab Close, Settings, and application Close targets with explicit hover, active, and keyboard-focus states. Settings then Close remain right-pinned in Yakuake order; action controls retain standard arrow pointer and native tooltip feedback. Durable native workspace state remains independent of presentation.
- A configurable page-level active-pane strip immediately below top tabs, showing bounded `short cwd : foreground process` text and exposing pane ID, PID, full cwd, and process in its tooltip without adding one header per split.
- A transient fuzzy command palette, scrollback-wide find and atomic save, reversible pane zoom, geometry-aware Alt+Arrow navigation, workspace quick notes with compact hold-Alt overlays in every visible pane plus bounded preview reads, cached overlay draw labels, and cached font descriptions, IME composition, optional focus-follows-pointer, compact bell/status dots rolled up to tabs, and multi-pane tags with native existing-tag suggestions plus a clearable Smart Tab filter whose active tag stays visible in compact tab chrome, hands focus to a matching pane when needed, names empty results, and offers button or Escape recovery.
- Yakuake-style drop-down polish with persisted width/height and reveal timing, a 480×240 usable floor with percentage fallback for legacy collapsed pixel state, explicit 80%×75% windowed startup sizing, optional focus-loss hiding, thin side/bottom/corner resize zones, inherited working directories, a compact one-tab row that keeps New Tab available, and a centered live `columns × rows` OSD while terminal surfaces resize. Pages with four or more panes derive a temporary font size targeting 80×24 without changing the persisted pane profile, show the current zoom, and report the bounded 3 pt floor when the target is physically impossible.
- Configurable F10 access with a native key recorder: Plasma uses live GlobalAccel registration, while Noctalia's supported compositors invoke NOCTTY's D-Bus-backed `noctty --toggle` command from their native keybind configuration.
- A native StatusNotifier system-tray icon remains available while the terminal is hidden. Primary activation toggles the window, secondary activation opens Settings, and right-click exposes `Show/Hide`, `Settings…`, and `Close NOCTTY`; Close stops live PTYs and removes the tray item. A separately launched NoctEd remains alive and owns its own dirty-document decisions.
- Rich ANSI/Unicode/grapheme rendering, cursor/title state, live GUI-configurable compact logical scrollback with a Konsole-style scrollbar independently rendered and navigated in every pane, ABI-v2 packed rows and dirty spans, selective cursor redraw, coalesced background fills, guarded glyph caching, synchronized output, and frame-clock presentation, per-pane click-to-focus keyboard routing, focused-pane-only `Ctrl+C` interrupt delivery even during broadcast, exact-pane `Ctrl+D` close with final-pane protection, persistent pane-local `Ctrl+wheel` font scaling, mouse, resize, intentional button-bound drag selection without hover trails or double-click zoom residue, clipboard copy, and bracketed-paste-safe delivery.
- Native status borders/tooltips, including current pane tags, selection-group state, and broadcast state, with deduped pane tooltip setter updates, plus configurable freedesktop desktop notifications compatible with Plasma and Noctalia.
- A Yakuake-style native Settings window with Window, Behavior, and Appearance categories, showing one compact grouped page at a time for mode, drop-down geometry, focus, the `Active pane profile`, active-pane information, tab placement, font, theme, status, spacing, notifications, and a bounded atomic launch-profile library. Up to eight named shell/command/SSH/Persistent-tmux/Persistent-Zellij profiles model absolute or inherited cwd, bounded environment overrides, and new-session scrollback; save/replace/select/delete is GUI-owned and running sessions remain unchanged. The five visual presets—Global default, Compact, Readable, High contrast, and Mono no ligatures—resolve Zig-owned per-pane family, size, contrast, and ligature preference. Settings remains compositor-stacked above its owning NOCTTY dropdown on Wayland and X11; no manual config-file editing is required.
- Built-in themes plus GUI import of Ghostty, Xresources, and simple Alacritty color files.

NOCTTY continuously writes customized tabs, panes, recursive split ratios, active focus, titles, colors, tags and Smart Tabs, pane profiles, quick notes, broadcast state, and working directories to an atomic hot-session snapshot. A fresh launch rebuilds that native workspace before presenting the window, while settings—including the active launch profile, named library, selected identity, and recent workspace MRU—are independently persisted after valid atomic GUI mutations. New workspaces/tabs/splits use the active launch profile; crash-restored or explicitly activated panes instead restart fresh shells in their saved directories. NOCTTY does not pretend it can resurrect in-memory shell processes.

NoctEd's interactive unsaved-document guarantee applies to its graceful window close. A forced SIGTERM, SIGKILL, or desktop-session termination cannot wait for a native prompt and remains outside that boundary; NOCTTY's atomic hot-session snapshot is terminal-workspace recovery support, not a substitute for saving editor files. NOCTTY owns only the cwd-based process handoff and does not retain editor buffers or editor-close prompts.

The supported release renderer does not depend on a private Ghostty GUI ABI. The installed public package and pinned upstream commit `53bd14f` expose no supported Linux GUI surface contract, so NOCTTY uses its Zig PTY/VT implementation and keeps the Ghostty adapter isolated for a future public ABI. The published `libghostty-vt` paste utility may be used through that boundary. No fork and no Ghostty-rendering claim are maintained. See [the native-host decision](NATIVE_HOST.md).

The prior GTK/VTE host is isolated in the optional `noctty-vte` binary. Production `noctty` does not link VTE or Tree-sitter and rejects fallback, smoke, and legacy-editor command surfaces.

## Build and Run

Requirements:

- Zig 0.16.x or newer.
- GTK 3 and GtkSourceView 4 development packages discoverable through `pkg-config`.
- VTE 2.91 development files only when compiling the optional fallback or the complete verification matrix.
- system `gtk-layer-shell` at runtime for Wayland dropdown placement (bundles and dogfood installs privately stage the provenance-checked host-package library).
- A Plasma Wayland/X11 or Noctalia-compatible Wayland session for display-backed product gates.

```sh
./scripts/verify.sh
zig build run
```

Useful launch variants:

```sh
zig build run -- --native-grid-windowed
zig build run -- --native-grid-zen
zig build run -- --native-grid-two-pane
zig build run-nocted -- --project . --open src/nocted/main.zig
zig build vte-fallback
./zig-out/bin/noctty-vte --native-host
zig build run -- --noctalia-plan niri
```

Compact controls:

```text
Ctrl+Shift+P  command palette       Ctrl+Shift+F  find in scrollback
Ctrl+Shift+N  quick note            Ctrl+Shift+Z  zoom / restore pane
Ctrl+Shift+G  Smart Tab filter      Ctrl+Shift+Y  tag selected panes
Ctrl+Shift+K  shortcut card
Ctrl+Tab      next visible pane     Ctrl+Shift+Tab next tab / Smart Tab
Ctrl+Alt+=    lighten tab color     Ctrl+Alt+-    darken tab color
Hold Alt      show note per pane    Alt+Arrow     directional focus
Alt+wheel     previous / next pane  Ctrl+wheel    pane font up / down
Ctrl+Alt+wheel previous / next tab
Ctrl+C        interrupt active pane
Ctrl+D        close active pane
Ctrl+S        save in NoctEd
Ctrl+F        find in NoctEd file   Ctrl+Shift+F Find in NoctEd project
Ctrl+PageUp/Down previous / next NoctEd file
Ctrl+W        close NoctEd file     Ctrl+Shift+[/] fold / unfold region
F10           show / hide
Double-click  pane: zoom / restore  Tab title ×2  rename that tab
Right-click   Open NoctEd Here      launch editor at the pane cwd
Tab-row +     New Tab               open and focus a native tab
Tab-row Settings / Close            configure or guard and stop NOCTTY
Tab right-click  Tab Color          Default plus eight presets
Tab right-click  Close Tab          stop that tab's sessions
Pane right-click Close Terminal     stop and remove that terminal
Pane right-click Profile            five exact-pane profile presets
Pane right-click **New Split Tab** 2×2/4×2/3×3/4×4 materializes live PTY grids; the redundant 1×1 entry is removed, while internal shrink qualification cancels by default or moves surplus sessions to an overflow tab
```

The interaction and chrome budget is documented in [docs/COMPACT_UX.md](COMPACT_UX.md).

## Verification

The maintained local repository gate is:

```sh
./scripts/verify.sh
```

It runs the SHA-256-pinned Debug/`ReleaseSafe` terminal protocol/state and malformed/Unicode qualification, Zig tests/checks, install-tree validation, truthful package-manifest structure checks with available/unavailable RPM and Arch parser status, two isolated normalized install-tarball builds with byte-for-byte comparison and SHA-256 sidecar verification, the guarded 0.1.0 version/date contract, a pinned x86_64/aarch64 release-workflow contract check, fail-closed dependency-bundle ownership/license-payload/manifest checks, the release-operations evidence status guard plus missing-evidence, semantic-receipt, scaffold-template, artifact-intake, signature-intake, receipt-intake, and acceptance-intake smokes, self-cleaning verification scratch space, Ghostty ABI guards, PTY/VT/session smokes, documentation checks, and native-layout guards. The gate redirects its temporary directory, XDG cache, Zig local/global caches, install prefix, and generated artifacts into that scoped root. Set `NOCTTY_ZIG_SINGLE_JOB=1` for an opt-in serialized Zig build on constrained or sandboxed hosts; normal runs keep Zig's default job count.

The complete display-backed release gate fails closed unless it is running in a disposable dedicated VM/container compositor session:

```sh
NOCTTY_DEDICATED_DISPLAY=1 ./scripts/native_release_smoke.sh
```

Its expected successful receipt is:

```text
native_release_smoke renderer=true modes=true tabs=true tab_add=true tab_reorder=true tab_reorder_pointer_drag=true late_callback_guard=true popup_teardown=true window_controls=true tab_rename=true tab_color=true profile_presets=true navigation=true alt_scroll=true ctrl_alt_scroll=true tab_close=true pane_close=true terminal_chords=true layout_presets=true layout_tui=true resize_overlay=true window_resize=true tray=true splits=true recursive_splits=true eight_panes=true click_focus=true clean_selection=true pane_move=true live_tab_position=true compact_ux=true note_overlay=true hot_session=true clipboard=true notifications=true settings=true credentialed_ssh=true settings_stacking=true themes=true project=true workspace_activation=true recent_workspaces=true nocted_handoff=true nocted=true maintenance=true workspace=true shortcut=true noctalia_ipc=true hidpi=true
```

The profile lane emits `native_grid_profile_preset_smoke context_menu=true submenu=true menu_survived=true presets=5 exact_target=true current=true readable=true font_size=14 isolated=true high_contrast=true rendered=true mono_no_ligatures=true workspace_dirty=true snapshot=true restored=true exited=true` and `native_grid_profile_preset_matrix wayland=true x11=true exact_target=true isolated=true persisted=true restored=true`.

The Settings lane additionally emits `launch_profile=true launch_kind=command launch_shell=/bin/sh launch_cwd=/tmp launch_env=2 launch_scrollback=2048 launch_atomic=true launch_persisted=true launch_runtime=true launch_library=true launch_profiles=1 launch_named=true launch_saved=true launch_selected=true launch_deleted=true launch_continuity_controls=true launch_tmux=true launch_zellij=true`. It proves rendered GUI ownership of bounded save/select/delete, both continuity controls reaching validated state, and a real local command PTY with the selected profile's cwd/environment/history. Settings version 9 retains versions 1–8 migration and adds the tmux/Zellij launch-kind semantics. The separate headless credential lane emits `native_grid_credentialed_ssh_smoke profile=true system_client=true system_server=true credential=publickey identity_isolated=true host_key=pinned transport=stdio_proxy network_bind=false remote_marker=true exited=true`; it proves local OpenSSH public-key authentication through the product PTY, not remote-network reachability or live-process continuity (`credentialed_ssh=true`).

The installed activation lane is deliberately opt-in because it needs access to the current Plasma compositor and desktop application registry:

```sh
./scripts/native_grid_installed_activation_smoke.sh --contract-only
NOCTTY_DEDICATED_DISPLAY=1 ./scripts/native_grid_installed_activation_smoke.sh
```

The first command validates the disposable production install, desktop MIME registration, exact `%u` command, isolated smoke surface, and two-tab fixture. Both commands keep the install prefix, temporary tree, XDG cache, and Zig local/global caches below one trap-cleaned project-local scratch root. The full command dispatches the installed `noctty:` handler through `gio`, then clicks the actual Recent Workspaces control and requires mapped/drawn child-window receipts on Wayland and X11. It fails if either display is inaccessible. The retained live run reports `native_grid_installed_activation_matrix backends=wayland,x11 installed_desktop=true desktop_dispatch=true recent_child=true rendered=true controlled_exit=true scratch_clean=true`; this is mapped activation proof on the current Plasma session, not universal compositor acceptance.

This matrix covers Wayland/X11 modes and clipboard, eight-direction borderless window resizing, live Plasma StatusNotifier registration and activation, the standard right-click tray-menu layout plus clean `Close NOCTTY` PTY teardown, the leading `+` New Tab button and trailing Yakuake-order Settings/Close buttons on the native tab row, bounded Yakuake-density tab geometry, standard button-pointer and native-tooltip feedback, dynamic tabs, rendered no-popup inline tab rename, tab colors, exact-pane profiles, visible-pane and tab navigation, exact tab/pane close, balanced layout presets, resize overlays, recursive splits, compact palette/find/notes/zoom/attention/IME behavior, hold-Alt notes, pane-local font scaling, clean selection/zoom behavior, click-to-focus routing, and focus-safe `Open NoctEd Here` handoff from a live pane cwd. The handoff receipt requires `editor_binary=nocted editor_handoff=true directory_resolved=true editor_process_separate=true`; `scripts/nocted_native_smoke.sh` separately proves project-tree and search-result activation, translucent minimap, document/project find, reversible folding and folded save, multi-file controls, clean/dirty untitled transitions, duplicate-safe atomic Save As, syntax re-detection, bounded quick-open activation, rendered multi-selection with one-step undo, recent-project activation, exact tab-session restoration, a captured quick-open panel, warning-fatal teardown, and scratch cleanup. The obsolete embedded editor and two-editor shutdown lane have been removed, so NOCTTY close preflight concerns terminal foreground processes only. The matrix also covers settings, persistence, above-parent stacking, themes, maintenance, workspace commands, scale-2/high-contrast rendering, physical X11 F10 through Plasma GlobalAccel, and live Wayland layer-shell plus D-Bus activation. Forced process/session termination and physical Wayland injection are outside their respective interactive proof boundaries.

Opt-in resource and deterministic robustness lanes cover both Debug and `ReleaseSafe`:

```sh
./scripts/nocted_resource_qualification.sh
./scripts/nocted_state_recovery_qualification.sh
./scripts/nocted_fuzz_race_qualification.sh
./scripts/nocted_core_stability_qualification.sh
./scripts/nocted_worker_qualification.sh
./scripts/nocted_core_endurance_qualification.sh
NOCTTY_DEDICATED_DISPLAY=1 ./scripts/nocted_native_endurance_qualification.sh
./scripts/nocted_project_index_qualification.sh
./scripts/terminal_compatibility_qualification.sh
./scripts/terminal_real_tui_qualification.sh
./scripts/terminal_ncurses_qualification.sh
./scripts/terminal_system_tui_qualification.sh
./scripts/terminal_session_qualification.sh
./scripts/launch_continuity_qualification.sh
./scripts/native_grid_renderer_qualification.sh
./scripts/native_grid_pipeline_qualification.sh
./scripts/native_grid_resource_qualification.sh
```

The first runs eight worker cancellation, duplicate-open, and atomic-save-close cycles per mode and requires all worker/project ownership to drain. The state-recovery lane repeats the complete unit boundary, including 13 malformed settings/session cases, oversized safe fallback, interrupted replacement, and the legacy shell parser. The fuzz/race lane adds 256 actual document files, 256 deterministic TextMate mutations, stable-generation retry, and bounded continuous-churn rejection. The core-stability lane repeats 128 allocator-accounted operation cycles per mode, repeats a three-query deterministic ranking corpus, and prints percentile plus root-process memory observations. The terminal-compatibility lane runs pinned protocol/state, malformed-byte, Unicode mutation, and complete grapheme-break fixtures across equivalent feed schedules with allocator accounting. The installed real-TUI lane starts Codex, Vim, and btop through the production session, validates their terminal-model surfaces and input/exit behavior, and remains opt-in because those external applications are not build dependencies. The terminal-session lane repeats 72 production real-PTY lifecycles per mode, including eight bounded forced foreground-group shutdowns, while accounting allocator, root, and child-tree resources. The renderer lane measures 384 exact production-Cairo frames per mode, repeated pixels, renderer-owned allocations, resize scratch, draw CPU, and root memory without a compositor. The terminal-pipeline lane adds two 64-sample real shell/PTY/VT-to-Cairo runs per mode, input/read-to-draw percentiles, repeat/cross-mode pixels, and separate root/tree memory. The mapped companion adds 64 synthetic production key-handler-to-draw/after-paint samples per mode/backend plus completed Wayland GDK presentation feedback; the full-stack companion adds live idle/fullscreen compositor pixels, external memory, and bounded wakeups. The final native-grid lane creates and closes 32 dynamic terminal sessions while sampling the terminal root separately from its child process tree. Printed timing/PSS/RSS values are host-local engineering observations, and deterministic fixture counts or short real-TUI cases are not retained fuzz duration, authenticated-agent acceptance, release thresholds, physical-input proof, final compositor acceptance, large-index/GUI distributions, long-soak proof, or cross-terminal rankings.

The project-index lane creates real disposable 4K, 25K, and 100K-entry trees in both modes, exercises broad-match Quick Open under a 500 ms `ReleaseSafe` 100K-entry budget, and retains `nocted_project_index_matrix debug=true release_safe=true scales=4000,25000,100000 immutable_delta=true quick_open_scale=true quick_open_release_safe_budget_ms=500 directory_rename=true replacement_conflict=true ignore_fallback=true overflow_fallback=true scan_time=true delta_time=true index_memory=true two_snapshot_peak=true process_memory=true allocator_leak_free=true scratch_clean=true`. The bounded native matrix closes current-project tree-draw, monitor publication, overflow recovery, and post-widget callback safety; the sustained native endurance matrix closes the one-host NCT-121/NCT-122 repetition boundary.

## Install and Package

Local install:

```sh
zig build --prefix "$HOME/.local"
```

Reproducible install-tree tarball:

```sh
./scripts/package_tarball.sh /tmp/noctty-local.tar.gz
```

Same-architecture dependency bundle:

```sh
./scripts/package_bundle.sh /tmp/noctty-linux-bundle.tar.gz
```

Both package routes build `ReleaseSafe` binaries with `-Dstrip=true`; dependency-bundle redistribution remains blocked until copied host-library notices are complete.

Debian, RPM, and Arch source manifests are under `packaging/`. Install trees, normalized tarballs, and dependency bundles contain both `noctty` and `nocted`, both desktop/AppStream entries, the NoctEd icon, and its syntax/style resources. Dependency bundles additionally contain per-library package provenance plus package-installed notices and canonical SPDX texts under `share/licenses/noctty/dependencies`; the manifest reports `redistribution_ready=true` only after every copied library is accounted for. The release workflow is configured for architecture-local x86_64 and aarch64 bundles, pinned Zig setup, layer-shell provisioning, runner-architecture assertions, and archive/SHA-256/manifest validation before upload; retained tagged artifacts and independent redistribution review remain external release operations. Installation details and the current artifact boundary are in [docs/INSTALL.md](INSTALL.md).

External release evidence is tracked by `./scripts/release_operations_status.sh`; the current local receipt is `release_operations_status version=0.1.0 tagged_artifacts=false signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=6`. Use `--list-missing` for deterministic `release_operations_issue` rows such as `release_operations_issue category=tagged_artifacts path=noctty-linux-x86_64.tar.gz reason=missing`. The focused smoke proves `semantic_receipts=true`, so retained files must carry expected fields rather than arbitrary placeholder text. The evidence layout is documented in [docs/RELEASE_OPERATIONS.md](RELEASE_OPERATIONS.md).

`./scripts/release_operations_scaffold.sh /path/to/evidence` creates TODO-bearing receipt templates and reports `artifact_files=false`; its smoke receipt is `release_operations_scaffold_smoke templates=true fake_artifacts=false placeholder_blocked=true require_complete_blocks=true scratch_clean=true`.

`./scripts/release_operations_artifact_intake.sh x86_64 /path/to/noctty-linux-x86_64.tar.gz /path/to/evidence` verifies the archive `.sha256` and `.manifest` before retaining it. The smoke receipt is `release_operations_artifact_intake_smoke x86_64=true aarch64=true sidecars_verified=true retained_status=true mismatch_blocked=true scratch_clean=true`.

`./scripts/release_operations_signature_intake.sh x86_64 archive /path/to/noctty-linux-x86_64.tar.gz.sig /path/to/evidence` retains archive, checksum, or manifest signatures only after the matching retained target exists. The smoke receipt is `release_operations_signature_intake_smoke archive=true checksum=true manifest=true x86_64=true aarch64=true placeholder_blocked=true target_required=true retained_status=true scratch_clean=true`.

`./scripts/release_operations_receipt_intake.sh publication /path/to/publication-receipt.txt /path/to/evidence` retains publication or dependency-bundle redistribution receipts only after semantic fields validate. The smoke receipt is `release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true`.

`./scripts/release_operations_acceptance_intake.sh compositor niri /path/to/niri.txt /path/to/evidence` and `./scripts/release_operations_acceptance_intake.sh wayland-hid /path/to/wayland-hid-consent-receipt.txt /path/to/evidence` retain final compositor and consent receipts only after their semantic fields validate. The smoke receipt is `release_operations_acceptance_intake_smoke compositors=6 wayland_hid=true semantic=true placeholder_blocked=true compositor_mismatch_blocked=true consent_required=true complete_status=true scratch_clean=true`.

## Architecture and Truth

- [BACKLOG.md](BACKLOG.md) is the active implementation ledger.
- [BACKLOG_ARCHIVE.md](BACKLOG_ARCHIVE.md) preserves completed epics and point-in-time slices.
- [CHANGELOG.md](CHANGELOG.md) records the product-complete 0.1.0 boundary, open release hardening, and development history.
- [docs/PITCH_AUDIT.md](PITCH_AUDIT.md) maps product promises to end-to-end evidence.
- [docs/ARCHITECTURE.md](ARCHITECTURE.md) defines the stable Zig product state and thin native adapters.
- [docs/SESSION_CONTINUITY.md](SESSION_CONTINUITY.md) and [docs/INSTALLED_CONTINUITY_QUALIFICATION.md](INSTALLED_CONTINUITY_QUALIFICATION.md) record tmux/Zellij profile semantics, direct PTY dispatch, and installed mapped reattach proof.
- [docs/NATIVE_HOST.md](NATIVE_HOST.md) records the Plasma host and Ghostty replacement decision.
- [docs/NOCTED.md](NOCTED.md) records the standalone editor architecture, syntax compatibility, safety limits, verification, and maturity boundary.
- [docs/NOCTED_PROJECT_INDEX_QUALIFICATION.md](NOCTED_PROJECT_INDEX_QUALIFICATION.md) records the 4K/25K/100K immutable-index/delta timing, memory, rename/conflict, fallback, and proof boundary.
- [docs/COMPACT_UX.md](COMPACT_UX.md) records the Wave/PrettyMux/Yakuake-inspired low-chrome interaction budget.
- [docs/NOCTALIA.md](NOCTALIA.md) records Noctalia v4/v5, compositor bindings, D-Bus activation, layer-shell, and proof boundaries.
- [docs/TERMINAL_BENCHMARK.md](TERMINAL_BENCHMARK.md) records the reproducible split-terminal comparison, result artifacts, and measurement boundaries.
- [docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md](TERMINAL_COMPATIBILITY_QUALIFICATION.md) and [docs/AUTHENTICATED_AGENT_QUALIFICATION.md](AUTHENTICATED_AGENT_QUALIFICATION.md) record the pinned NCT-110 protocol/state, malformed-input, Unicode, allocator, and authenticated mapped Codex boundary.
- [docs/TERMINAL_NCURSES_QUALIFICATION.md](TERMINAL_NCURSES_QUALIFICATION.md) records the installed nano/less/dialog production PTY/VT matrix and its headless, version-bounded proof boundary.
- [docs/TERMINAL_SYSTEM_TUI_QUALIFICATION.md](TERMINAL_SYSTEM_TUI_QUALIFICATION.md) records the installed top/watch/info/whiptail/fzf/sqlite3/glances/bash/man/sftp production PTY/VT matrix and its headless, version-bounded proof boundary.
- [docs/TERMINAL_REAL_TUI_QUALIFICATION.md](TERMINAL_REAL_TUI_QUALIFICATION.md) records the bounded installed Codex/Vim/btop headless matrix; the authenticated mapped companion is documented separately.
- [docs/TERMINAL_PIPELINE_QUALIFICATION.md](TERMINAL_PIPELINE_QUALIFICATION.md) records the real-shell PTY/VT-to-production-Cairo latency, repeat-pixel, allocation, and mapped-compositor boundary.
- [docs/NATIVE_GRID_FULL_STACK_QUALIFICATION.md](NATIVE_GRID_FULL_STACK_QUALIFICATION.md) records live Wayland/X11 idle/fullscreen compositor pixels, external memory, and bounded wakeups.
- [docs/DAILY_DRIVER.md](DAILY_DRIVER.md) records the Yakuake-replacement gap audit, foreground-session lifecycle, and Codex/Claude/Antigravity resource controls.
- [docs/LAUNCH_PROFILES.md](LAUNCH_PROFILES.md) records the GUI launch model, validation/persistence rules, PTY semantics, and completed NCT-111 proof boundary.
- [docs/WORKSPACE_ACTIVATION.md](WORKSPACE_ACTIVATION.md) records local URI admission, recent-workspace state, separate-window behavior, and its conservative proof boundary.
- [docs/PERFORMANCE_ALGORITHM_RESEARCH.md](PERFORMANCE_ALGORITHM_RESEARCH.md) records the peer-algorithm audit, accepted optimization roadmap, dependency decisions, and measurement gates.
- [docs/RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) separates green source gates from external release operations.
- [docs/RELEASE_OPERATIONS.md](RELEASE_OPERATIONS.md) defines retained evidence files for tagged artifacts, signatures, publication, compositor acceptance, dependency-bundle notices, and consented Wayland HID capture.

Core ownership:

- `src/terminal`: Zig PTY, VT grid, terminal sessions, status, and paste policy.
- `src/workspace`: tabs, panes, layouts, snapshots, project views, and recovery state.
- `src/config` and `src/theme`: GUI-facing state plus native persistence/import.
- `src/nocted`: standalone editor core, native GTK/GtkSourceView surface, project indexing, settings, and syntax discovery.
- `src/app/App.zig`: product command dispatch and coordination.
- `src/gui`: GTK/Cairo, Plasma GlobalAccel, Noctalia compositor plans, Wayland/X11, D-Bus activation, dialogs, and transport adapters.
- `src/ghostty`: isolated optional public-ABI probe/lifecycle boundary.

NOCTTY remains native-first: no TUI-only product surface, no thick per-terminal title bars, no analytics, and no required hand-editing of persistence files.
