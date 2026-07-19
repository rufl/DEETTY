# Terminal Compatibility Qualification

Status: deterministic NCT-110 protocol/state, malformed-input, and Unicode tranche passed on 2026-07-17. A bounded real installed Codex/Vim/btop headless tranche passed on 2026-07-18; authenticated-agent and rendered cross-backend acceptance remain open.

## Qualified Boundary

`scripts/terminal_compatibility_qualification.sh` builds the native Zig-only `noctty-terminal-compatibility` runner in both Debug and `ReleaseSafe`. The runner uses the production `Vt.Grid`, `VtParser`, and Unicode streaming implementation directly; it does not launch a browser runtime, substitute VTE, or cross the optional Ghostty adapter.

The retained matrix covers:

- 23 source-pinned protocol cases for DA, DSR, DECRQM mode state, XTGETTCAP, OSC title, blocked OSC 52, and both 7-bit and C1 forms;
- six equivalent feed schedules per case: whole input, bytewise input, and four deterministic chunk schedules, for 138 protocol executions per build mode;
- observable state diffs for dimensions, cursors, primary/alternate mode, scrollback bounds, parser state/string sink, replies, title, tab stops, colors, packed rows, grapheme cell text, and OSC 8 hyperlink targets;
- direct assertions for combined SGR state and truecolor, bounded OSC 8 storage, blocked OSC 52, and 4096-byte parser-string overflow recovery;
- 128 deterministic malformed cases of 4096 bytes each, with two resize points and all six feed schedules (`524288` unique malformed fixture bytes per mode);
- 256 deterministic valid/malformed Unicode/control mutations under all six feed schedules;
- all 766 cases in the official Unicode 17.0.0 `GraphemeBreakTest` fixture; and
- Zig `DebugAllocator` requested-byte accounting after every corpus case and at process exit.

The shell lane pins its inputs before execution:

| Fixture | SHA-256 |
| --- | --- |
| `src/terminal/fixtures/agent-compat-vt-corpus.tsv` | `65d5f28ec0f2e96bd4625a0d606a0b2a156f7a5f26cafc35edc1d015fc67068f` |
| `src/terminal/fixtures/GraphemeBreakTest-17.0.0.txt` | `e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec` |

## Retained Result

Both modes produced the same semantic receipt with their build mode substituted:

```text
terminal_compatibility mode=Debug protocol_cases=23 schedules=6 protocol_runs=138 malformed_cases=128 malformed_bytes=524288 unicode_mutations=256 grapheme_cases=766 unicode_version=17.0.0 state_diff=true replies=true modes=true sgr=true osc8=true osc52_blocked=true c1=true parser_bounds=true allocator_leak_free=true allocator_residual_bytes=0 assertions=true
terminal_compatibility mode=ReleaseSafe protocol_cases=23 schedules=6 protocol_runs=138 malformed_cases=128 malformed_bytes=524288 unicode_mutations=256 grapheme_cases=766 unicode_version=17.0.0 state_diff=true replies=true modes=true sgr=true osc8=true osc52_blocked=true c1=true parser_bounds=true allocator_leak_free=true allocator_residual_bytes=0 assertions=true
terminal_compatibility_matrix debug=true release_safe=true protocol_cases=23 schedules=6 malformed_cases=128 unicode_mutations=256 grapheme_cases=766 allocator_leak_free=true scratch_clean=true protocol_fixture_sha256=65d5f28ec0f2e96bd4625a0d606a0b2a156f7a5f26cafc35edc1d015fc67068f grapheme_fixture_sha256=e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec
```

The lane runs from `scripts/verify.sh` and deletes its build prefixes, Zig caches, binaries, and captured output through its scoped temporary-directory trap.

## Proof Boundary

This is bounded deterministic parser/state and Unicode conformance evidence. By itself it does not prove that Codex, Claude Code, Antigravity, ncurses applications, tmux, or zellij render and exit correctly in a live NOCTTY window. It is also not retained fuzz-duration, throughput, pixel-comparison, multi-day stability, or Plasma Wayland/X11 interaction evidence.

The complementary [real TUI qualification](TERMINAL_REAL_TUI_QUALIFICATION.md) now proves that installed Codex 0.144.5's unauthenticated welcome/login surface, Vim 9.2, and btop 1.4.7 generate compatible state and accept controlled exit input through the production PTY/VT model in both build modes: `terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true`. It remains headless and never authenticates Codex or submits a model request.

The [ncurses application qualification](TERMINAL_NCURSES_QUALIFICATION.md) separately proves installed nano 9.1, less 704, and dialog 1.3-20260107 through that same production PTY/VT path in both modes: `terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`. It remains headless and version-bounded rather than universal ncurses or compositor proof.

The [system TUI qualification](TERMINAL_SYSTEM_TUI_QUALIFICATION.md) separately proves installed top 4.0.6-dirty, watch 4.0.6-dirty, info 7.3, whiptail 0.52.25, fzf 0.74.0, SQLite 3.53.3, Glances 4.5.5, Bash 5.3.15, man-db 2.13.1, and OpenSSH SFTP 10.4p1 through the production PTY/VT path in both modes: `terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`. It remains headless and version-bounded rather than universal TUI or compositor proof.

NCT-110 remains partial until authenticated/broader real agent-TUI protocol, visual, interaction, and exit receipts are retained on Plasma Wayland and X11. NCT-112 now has a separate [bounded real-PTY lifecycle receipt](TERMINAL_SESSION_QUALIFICATION.md), `terminal_session_qualification_matrix debug=true release_safe=true normal_cycles=64 forced_cycles=8 sessions_per_mode=72 total_sessions=144 allocator_leak_free=true forced_group_shutdown=true latency_percentiles=true root_memory_separate=true process_tree_memory=true scratch_clean=true`, but multi-day native-GUI/sustained authenticated-agent-output evidence remains open. NCT-119 has a separate [display-independent exact production-Cairo receipt](NATIVE_GRID_RENDERER_QUALIFICATION.md), `native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true`; compositor/frame-clock, full-stack allocation, archived pixel, and end-to-end latency distributions remain open.

## Reproduce

```sh
./scripts/terminal_compatibility_qualification.sh
```
