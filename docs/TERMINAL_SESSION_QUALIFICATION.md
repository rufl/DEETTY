# Terminal Session Qualification

Status: bounded NCT-112 allocator-accounted PTY lifecycle and forced foreground-process shutdown tranche passed on 2026-07-18. Complementary installed and authenticated Codex lanes plus mapped latency/resource receipts pass; multi-day native-GUI evidence remains open.

## Qualified Boundary

`scripts/terminal_session_qualification.sh` builds the native Zig-only `deetty-terminal-session-qualification` runner in Debug and `ReleaseSafe`. Each mode uses the production `TerminalSession`, PTY adapter, VT grid, resize path, output pump, exit polling, and teardown path for 64 ordinary sessions plus eight forced-shutdown sessions.

The ordinary cycle starts a real interactive `/bin/sh` PTY, performs two resizes, drains 32 output lines and an OSC title marker into the production grid, observes exit zero, deinitializes twice to exercise the idempotent public boundary, and requires Zig `DebugAllocator` requested bytes to return to the pre-cycle baseline. The forced cycle starts a foreground shell loop that deliberately ignores `SIGHUP` and `SIGTERM`, waits until the PTY reports its distinct foreground process group, closes the session, requires the 500 ms grace path to expire, and then requires both the owned shell and stubborn foreground group to disappear. Requested bytes again return to baseline after every cycle and zero at process exit.

The production C adapter now tracks the foreground and shell process groups independently throughout the bounded grace period. If the interactive shell exits before a HUP-resistant foreground group, teardown still detects and force-kills that group instead of leaving it behind.

The shell wrapper samples root-process PSS/RSS separately from the full child process tree, retains p50/p95/p99 lifecycle timing, runs both build modes, and deletes its isolated prefixes, Zig caches, outputs, and scratch directory on exit.

## Retained Result

The 2026-07-18 host-local run retained:

| Mode | Ordinary p50 / p95 / p99 | Forced p50 / p95 / p99 | Peak root PSS / RSS | Peak tree PSS / RSS |
| --- | --- | --- | --- | --- |
| Debug | 4,192,297 / 4,647,070 / 5,501,166 ns | 504,084,560 / 505,271,799 / 505,271,799 ns | 6,960 / 9,236 KiB | 6,856 / 9,060 KiB |
| ReleaseSafe | 2,664,809 / 3,159,220 / 3,857,818 ns | 503,478,509 / 505,191,589 / 505,191,589 ns | 1,380 / 3,208 KiB | 1,380 / 3,208 KiB |

Debug drained 74,650 bytes and `ReleaseSafe` drained 74,936 bytes. Both performed 128 resizes, returned allocator requested bytes to zero, exhausted all eight forced grace periods, reaped all eight owned shells, and removed all eight stubborn foreground groups:

```text
terminal_session_qualification_matrix debug=true release_safe=true normal_cycles=64 forced_cycles=8 sessions_per_mode=72 total_sessions=144 allocator_leak_free=true forced_group_shutdown=true latency_percentiles=true root_memory_separate=true process_tree_memory=true scratch_clean=true
```

Timings and memory are one-host engineering observations, not release thresholds or a cross-terminal ranking. Tree and root peaks are sampled independently and need not come from the same instant.

## Proof Boundary

This closes NCT-112's bounded allocator-accounted TerminalSession repetition and stubborn foreground-process shutdown tranche. It is real PTY/process evidence, but it is headless and short. The complementary [real TUI qualification](TERMINAL_REAL_TUI_QUALIFICATION.md) starts installed Codex, Vim, and btop through the same production session path. The [terminal pipeline qualification](TERMINAL_PIPELINE_QUALIFICATION.md) additionally drives two 64-sample real-shell PTY/VT-to-exact-Cairo sequences per mode, retaining input-write/PTY-read-start-to-draw percentiles, repeated/cross-mode pixels, zero warm-frame renderer allocations, and separate root/tree memory: `native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true`. These lifecycle and display-independent lanes do not prove mapped GTK/compositor behavior. Separate mapped presentation and full-stack receipts retain Wayland/X11 key-handler-to-frame timing plus idle/fullscreen compositor pixels, memory, and wakeups. The [stability qualification](NATIVE_GRID_STABILITY_QUALIFICATION.md) now passes its short hidden/visible matrix with phase resources and zero hidden draws. Physical input remains open, and NCT-112 remains partial only for the elapsed 48-hour authenticated run.

The complementary ncurses application contract is `terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`. It starts installed nano, less, and dialog through the same production session path, but remains headless and short.

The complementary system TUI contract is `terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`. It starts installed top, watch, info, whiptail, fzf, SQLite, Glances, Bash, man, and SFTP through that production path, but remains headless and short.

The synthetic renderer contract remains `native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true`.

The installed application contract remains `terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true`.

## Reproduce

```sh
./scripts/terminal_session_qualification.sh
```
