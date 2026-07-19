# Real TUI Qualification

Status: bounded NCT-110/NCT-112 installed-application PTY/VT tranche passed on 2026-07-18. Authenticated-agent and compositor-backed acceptance remain open.

## Qualified Boundary

`scripts/terminal_real_tui_qualification.sh` discovers installed Codex, Vim, and btop executables and builds the Zig/C-only `noctty-terminal-real-tui-qualification` runner in Debug and `ReleaseSafe`. Each application starts through the production `LaunchProfile`, PTY adapter, `TerminalSession`, and `Vt.Grid` at 120x40. The runner waits for application-owned screen markers, inspects foreground-process identity through the production `/proc` seam, records terminal modes and rendered cell state, routes application input, observes a controlled zero exit, releases the session, and requires Zig `DebugAllocator` requested bytes to return to the pre-case baseline and zero at process exit.

The isolated cases are:

- Codex CLI 0.144.5 with a disposable empty `CODEX_HOME`, proving only the unauthenticated welcome and `Sign in with ChatGPT` surface. The case retains DECSET 2026 synchronized-output begin observation, styled and Unicode cells, foreground runtime identity, `Ctrl+C` routing, and clean exit. The packaged command currently exposes `node-MainThread` as its Linux `comm`; that is accepted only as the observed foreground identity of the external installed Codex command.
- Vim 9.2 with `-Nu NONE`, no swap or viminfo, and a disposable two-line fixture, proving fixture text, alternate screen, bracketed paste, focus reporting, `:q!` routing, and clean exit.
- btop 1.4.7 with disposable XDG configuration/state/cache roots, proving its CPU/memory/process dashboard markers, alternate screen, mouse plus SGR-mouse reporting, truecolor, Unicode, `q` routing, and clean exit.

The external Codex package's implementation does not enter NOCTTY. The qualification binary and product remain native Zig plus the existing C PTY ABI, and the lane adds no product Node/browser dependency, network request, credential, telemetry, or persisted user state.

## Retained Result

The 2026-07-18 host-local run retained:

| Mode | Application | Ready | Exit after input | Output | Peak root PSS / RSS | Peak tree PSS / RSS |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Debug | Codex / Vim / btop sequence | 13,228 / 119 / 366 ms | 19 / 101 / 103 ms | 74,697 bytes | 7,056 / 9,392 KiB | 42,373 / 255,368 KiB |
| ReleaseSafe | Codex / Vim / btop sequence | 1,498 / 111 / 126 ms | 22 / 101 / 102 ms | 42,420 bytes | 1,464 / 3,296 KiB | 36,911 / 249,184 KiB |

Root and tree peaks are sampled independently and need not come from the same instant. Readiness timings include cold external-application startup and are one-host observations, not thresholds or a terminal ranking.

```text
terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true
```

## Proof Boundary

This is real installed-application, headless production PTY/VT model evidence. It proves more than the deterministic protocol corpus because actual applications generated and consumed the terminal stream, but it does not initialize GTK, map a native surface, exercise Cairo or a compositor, compare pixels, or measure input-to-frame latency.

This does not prove an authenticated Codex agent workflow, Claude Code or Antigravity, compositor-backed pixels, Plasma Wayland/X11 interaction, or multi-day stability. The Codex case never authenticates or submits a model request. Vim and btop cover two real full-screen terminal applications, not universal ncurses compatibility. NCT-110 remains partial for authenticated agent workflows, broader real-TUI coverage, and retained protocol/visual/interaction/exit receipts in mapped Plasma Wayland and X11 windows. NCT-112 remains partial for sustained real-agent output, hidden/visible multi-day soaks, and rendered latency/resource distributions.

The complementary [ncurses application qualification](TERMINAL_NCURSES_QUALIFICATION.md) broadens the headless installed-tool evidence to nano, less, and dialog without expanding that proof boundary: `terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`.

The [system TUI qualification](TERMINAL_SYSTEM_TUI_QUALIFICATION.md) separately broadens that evidence to top, watch, info, whiptail, fzf, SQLite, Glances, Bash, man, and SFTP: `terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`.

## Reproduce

The lane is opt-in because it intentionally requires installed Codex, Vim, and btop executables rather than making those external applications build dependencies:

```sh
./scripts/terminal_real_tui_qualification.sh
```

`NOCTTY_REAL_TUI_CODEX`, `NOCTTY_REAL_TUI_VIM`, and `NOCTTY_REAL_TUI_BTOP` can select explicit absolute executable paths. The script uses only scoped disposable homes, XDG roots, Zig caches, output files, and fixtures under one trap-cleaned workspace directory.
