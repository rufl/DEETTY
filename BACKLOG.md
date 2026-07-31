# NOCTTY Backlog

Last refreshed: 2026-07-31.

## Source Of Truth Policy

Only incomplete accepted work lives here. `[status:yellow]` is locally evidenced but not closed; `[truth:*]` names that evidence. Archive completed or retired work.

## Completion Index

| ID | Open boundary |
|---|---|
| NCT-106 | Native GUI/lifecycle soaks |
| NCT-110 | Authenticated/rendered agent coverage |
| NCT-111 | Installed activation and live reattach |
| NCT-112 | Multi-day terminal stability |
| NCT-119 | Compositor/key-to-frame evidence |
| NCT-121 | Long project lifecycle runs |
| NCT-122 | Cross-backend search/load runs |
| Release operations | Signed artifacts, publication, independent redistribution review, compositor and HID acceptance |

## Active

### NCT-106 NoctEd stability and resource qualification — partial

- [ ] [status:yellow] Add long cross-backend GUI/lifecycle soaks. `[truth:test,measurement]`

### NCT-110 Modern VT and agent-TUI compatibility — partial

- [ ] [status:yellow] Add authenticated agents and mapped Wayland/X11 receipts. `[truth:test,measurement]`

### NCT-111 Daily-driver session continuity and launch profiles — partial

- [ ] [status:yellow] Retain installed activation and live tmux/Zellij reattach. `[truth:test]`

### NCT-112 Terminal stability and agent-resource qualification — partial

- [ ] [status:yellow] Add multi-day mapped agent/resource runs. `[truth:test,measurement]`

### NCT-119 Terminal presentation latency and draw allocation — partial

- [ ] [status:yellow] Retain compositor and key-to-frame distributions. `[truth:measurement]`

### NCT-121 NoctEd shared worktree index and external-change engine — partial

- [ ] [status:yellow] Add long Wayland/X11 lifecycle evidence. `[truth:test,measurement]`

### NCT-122 NoctEd search latency and filesystem admission — partial

- [ ] [status:yellow] Add `ReleaseSafe`/X11 tree-memory and ranking runs. `[truth:test,measurement]`

## Retained Local Receipts

Exact strings below are the compact local evidence index; focused qualification docs own their limits.

### NoctEd

`nocted_state_recovery_matrix debug=true release_safe=true legacy_shell_parser=true malformed_state_corpus=13 oversized_fallback=true interrupted_replace=true settings_atomic=true session_atomic=true scratch_clean=true`

`nocted_fuzz_race_matrix debug=true release_safe=true document_cases=256 grammar_cases=256 external_read_race=true stable_retry=true retry_cap=3 perpetual_churn_rejected=true scratch_clean=true`

`nocted_core_stability_matrix debug=true release_safe=true cycles=128 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_cycles=128 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true scratch_clean=true`

`nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true`

`nocted_worker_matrix debug=true release_safe=true shared_admission_policy=true generation_supersession=true shared_queue_cap=64 lane_queue_cap=32 cancelled_lane_excluded=true kind_cancel=true pending_lookup=true lazy_pool_creation=true transactional_enqueue=true append_failure_safe=true push_failure_rollback=true ordered_retirement=true glib_thread_pools=true worker_lanes=2 project_scan=true search_streaming=true snapshot_first=true cooperative_cancellation=true search_batch_size=24 search_batch_cap=2 backpressure_exercised=true foreground_save_under_backpressure=true worker_drained=true allocator_leak_free=true process_memory=true scratch_clean=true`

`nocted_project_index_matrix debug=true release_safe=true scales=4000,25000,100000 immutable_delta=true quick_open_scale=true quick_open_release_safe_budget_ms=500 directory_rename=true replacement_conflict=true ignore_fallback=true overflow_fallback=true scan_time=true delta_time=true index_memory=true two_snapshot_peak=true process_memory=true allocator_leak_free=true scratch_clean=true`

### Terminal

`terminal_compatibility_matrix debug=true release_safe=true protocol_cases=23 schedules=6 malformed_cases=128 unicode_mutations=256 grapheme_cases=766 allocator_leak_free=true scratch_clean=true`

`terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true`

`terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`

`terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`

`terminal_session_qualification_matrix debug=true release_safe=true normal_cycles=64 forced_cycles=8 sessions_per_mode=72 total_sessions=144 allocator_leak_free=true forced_group_shutdown=true latency_percentiles=true root_memory_separate=true process_tree_memory=true scratch_clean=true`

### Launch and presentation

`launch_runtime=true launch_library=true credentialed_ssh=true`

`config_v9=true atomic=true separate_process_policy=true`

`native_grid_installed_activation_contract installed_desktop=true mime_registered=true exec_open_uri=true fixture_tabs=2 production_binary=true smoke_isolated=true scratch_scoped=true`

`launch_continuity_matrix debug=true release_safe=true kinds=tmux,zellij direct_argv=true create_or_attach=true production_pty=true cwd=true environment=true controlled_exit=true allocator_leak_free=true tool_shims=true installed_tools=false live_reattach=false scratch_clean=true`

`native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true`

`native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true`

## Release Operations

- [ ] [status:yellow] Retain both architecture artifacts/signatures, publication, independent dependency-bundle redistribution review and receipts, final compositor acceptance, and consented Wayland HID capture. The NCT-077 follow-through is locally closed; external evidence remains operator-owned. `[truth:build,docs,external]`
