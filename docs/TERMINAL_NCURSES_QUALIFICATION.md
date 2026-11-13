# Ncurses Application Qualification

Status: bounded NCT-110/NCT-112 installed nano/less/dialog PTY/VT tranche passed on 2026-07-18. Authenticated mapped Codex acceptance is covered by the 2026-08-04 companion matrix.

## Qualified Boundary

`scripts/terminal_ncurses_qualification.sh` discovers installed nano, less, and dialog executables and builds the native Zig `deetty-terminal-ncurses-qualification` runner in Debug and `ReleaseSafe`. Each application starts at 120x40 through the production `LaunchProfile`, Zig PTY, `TerminalSession`, and `Vt.Grid`. The runner waits for application-owned screen markers, checks foreground identity through the production `/proc` seam, records terminal modes and cell state, routes a controlled exit, observes exit code zero, releases the session, and requires allocator requested bytes to return to the pre-case baseline and zero at process exit.

The isolated cases are:

- nano 9.1 opens a disposable two-line read-only fixture with mouse support enabled. The retained state includes the fixture marker, nano control surface, alternate screen, bracketed paste, mouse plus SGR-mouse reporting, styled cells, `Ctrl+X` routing, and clean exit.
- less 704 pages a disposable 201-line fixture. The retained state includes its first-page marker, styled cells, alternate screen, `q` routing, and clean exit.
- dialog 1.3-20260107 opens a titled message box. The retained state includes the title and body, styled border cells, mouse plus SGR-mouse reporting, Enter routing, and clean exit. This build clears and uses the primary screen rather than entering the alternate screen; the qualification records and asserts that behavior instead of claiming otherwise.

The external tools do not enter DEETTY. The qualification binary and PTY/session path remain native Zig, and the lane adds no product dependency, browser runtime, network request, credential, telemetry, or persisted user state.

## Retained Result

The 2026-07-18 host-local run retained:

| Mode | nano / less / dialog ready | Exit after input | Total output | Peak root PSS / RSS | Peak tree PSS / RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Debug | 1,209 / 1,206 / 1,201 ms | 1 / 436 / 1 ms | 4,167 bytes | 7,111 / 9,464 KiB | 8,624 / 15,764 KiB |
| ReleaseSafe | 1,187 / 1,180 / 1,189 ms | 1 / 205 / 2 ms | 4,173 bytes | 1,478 / 3,312 KiB | 3,026 / 9,700 KiB |

Readiness includes the qualification-only 1,000-poll observation dwell after screen markers appear; it is not application startup latency. Root and tree peaks are sampled independently and need not come from the same instant. The values are one-host engineering observations, not acceptance thresholds or a terminal ranking.

```text
terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true
```

## Proof Boundary

This is real installed-application, headless production PTY/VT model evidence. It proves that these exact installed versions generated and consumed compatible terminal streams through DEETTY's production session model. It does not initialize GTK, map a native surface, exercise Cairo or a compositor, compare pixels, or measure key-to-frame latency.

Three applications are not universal ncurses compatibility. This lane does not prove Claude Code, Antigravity, other terminal applications, compositor-backed pixels, Plasma interaction, or multi-day stability. The separate authenticated Codex and installed tmux/Zellij mapped matrices close NCT-110/NCT-111 at their accepted one-host boundaries. NCT-112's hidden/visible harness shakedown passes; the retained 48-hour run remains open.

The complementary [system TUI qualification](TERMINAL_SYSTEM_TUI_QUALIFICATION.md) broadens the headless installed-tool evidence to top, watch, info, whiptail, fzf, SQLite, Glances, Bash, man, and SFTP without expanding that proof boundary: `terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true`.

## Reproduce

The lane is opt-in because it intentionally requires the installed external tools rather than making them product dependencies:

```sh
./scripts/terminal_ncurses_qualification.sh
```

`DEETTY_NCURSES_NANO`, `DEETTY_NCURSES_LESS`, and `DEETTY_NCURSES_DIALOG` can select explicit absolute executable paths. The script uses only scoped disposable homes, XDG roots, Zig caches, output files, and fixtures under one trap-cleaned workspace directory.
