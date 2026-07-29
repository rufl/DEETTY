# System TUI Qualification

Status: bounded NCT-110/NCT-112 installed top/watch/info/whiptail/fzf/sqlite3/glances/bash/man/sftp PTY/VT tranche passed on 2026-07-18. Authenticated-agent and compositor-backed acceptance remain open.

## Qualified Boundary

`scripts/terminal_system_tui_qualification.sh` discovers installed procps top, procps watch, GNU info, newt whiptail, fzf, SQLite, Glances, Bash, man-db, less, OpenSSH SFTP client, and OpenSSH SFTP server executables and builds the native Zig `noctty-terminal-system-tui-qualification` runner in Debug and `ReleaseSafe`. Each of the ten application cases starts at 120x40 through the production `LaunchProfile`, Zig PTY, `TerminalSession`, and `Vt.Grid`. The runner waits for application-owned screen markers, checks foreground identity through the production `/proc` seam, records terminal modes and cell state, routes a controlled exit, observes exit code zero, releases the session, and requires allocator requested bytes to return to the pre-case baseline and zero at process exit.

The isolated cases are:

- procps top 4.0.6-dirty renders its live process/CPU/memory monitor on the primary screen while filtering the table to its own retained PID for deterministic viewport coverage, accepts `q`, and exits cleanly.
- procps watch 4.0.6-dirty repeatedly renders a deterministic command marker on the alternate screen, accepts a real ETX (`Ctrl+C`), handles it internally, and exits with code zero. The watched command is intentionally plain text, so zero styled cells are asserted rather than promoted to a rich-style claim.
- GNU info 7.3 opens the installed directory browser, renders menu/help state on the alternate screen, accepts `q`, and exits cleanly.
- newt whiptail 0.52.25 renders a titled Unicode-border message widget on the alternate screen, accepts Enter, and exits cleanly.
- fzf 0.74.0 loads a deterministic three-entry fixture, renders a bordered fuzzy filter with Unicode, style, bracketed-paste, and mouse modes on the alternate screen, accepts Enter, and exits cleanly.
- SQLite 3.53.3 starts an isolated in-memory interactive database, renders a deterministic query result plus its plaintext prompt, accepts `.quit`, and exits cleanly. Zero styled cells are asserted deliberately.
- Glances 4.5.5 renders its CPU, memory, load, and process monitor on the alternate screen, accepts `q`, and exits cleanly. Update checks are disabled, public information is hidden, and the IP plugin is disabled because network-interface inspection is forbidden by the managed sandbox.
- Bash 5.3.15 starts a disposable interactive Readline shell, renders deterministic startup and prompt markers on the primary screen, enables bracketed paste, accepts a real command followed by `exit`, and exits cleanly without reading user startup or history files.
- man-db 2.13.1 formats a deterministic local manual page and hands it to the explicitly selected installed less pager. The nested pager owns the foreground terminal, renders styled text on the alternate screen, accepts `q`, returns control to man, and both processes exit cleanly.
- OpenSSH SFTP 10.4p1 attaches directly to the installed local `sftp-server` with `-D`, renders its plaintext interactive prompt on the primary screen, accepts `pwd` and `quit`, and exits cleanly without SSH transport, credential use, or a network bind.

The external tools do not enter NOCTTY. The qualification binary and PTY/session path remain native Zig, and the lane adds no product dependency, browser runtime, network request or bind, credential, telemetry, or persisted user state.

## Retained Result

The 2026-07-18 host-local canonical full-verifier run retained:

| Mode | top / watch / info / whiptail ready | fzf / SQLite / Glances ready | Bash / man / SFTP ready | Exit after input, all ten | Total output | Peak root PSS / RSS | Peak tree PSS / RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Debug | 1,575 / 1,280 / 1,241 / 1,323 ms | 2,009 / 1,252 / 2,086 ms | 1,275 / 1,313 / 1,312 ms | 1 / 1 / 1 / 1 / 1 / 74 / 550 / 234 / 1 / 1 ms | 25,114 bytes | 6,277 / 8,672 KiB | 62,478 / 78,320 KiB |
| ReleaseSafe | 1,486 / 1,201 / 1,168 / 1,184 ms | 1,175 / 1,188 / 2,164 ms | 1,189 / 1,255 / 1,211 ms | 1 / 1 / 1 / 1 / 1 / 1,739 / 1,266 / 1 / 225 / 1 ms | 24,428 bytes | 1,509 / 3,340 KiB | 57,909 / 73,204 KiB |

Readiness includes the qualification-only 1,000-poll observation dwell after screen markers appear; it is not application startup latency. Root and tree peaks are sampled independently and need not come from the same instant. The values are one-host engineering observations, not acceptance thresholds or a terminal ranking.

```text
terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true
```

## Proof Boundary

This is real installed-application, headless production PTY/VT model evidence. It proves that these exact installed versions generated and consumed compatible terminal streams through NOCTTY's production session model. It does not initialize GTK, map a native surface, exercise Cairo or a compositor, compare pixels, or measure key-to-frame latency.

Ten applications are not universal TUI compatibility. The SFTP case is direct local client/server protocol evidence, not remote-network or credentialed SSH acceptance. The lane does not prove authenticated Codex, Claude Code, Antigravity, tmux, Zellij, other terminal applications, compositor-backed pixels, Plasma Wayland/X11 interaction, or multi-day stability. NCT-110 therefore remains partial for authenticated/broader agent and mapped cross-backend protocol, visual, interaction, and exit receipts. NCT-112 remains partial for sustained output, hidden/visible multi-day soaks, and rendered latency/resource distributions.

## Reproduce

The lane is opt-in because it intentionally requires the installed external tools rather than making them product dependencies:

```sh
./scripts/terminal_system_tui_qualification.sh
```

`NOCTTY_SYSTEM_TUI_TOP`, `NOCTTY_SYSTEM_TUI_WATCH`, `NOCTTY_SYSTEM_TUI_INFO`, `NOCTTY_SYSTEM_TUI_WHIPTAIL`, `NOCTTY_SYSTEM_TUI_FZF`, `NOCTTY_SYSTEM_TUI_SQLITE`, `NOCTTY_SYSTEM_TUI_GLANCES`, `NOCTTY_SYSTEM_TUI_BASH`, `NOCTTY_SYSTEM_TUI_MAN`, `NOCTTY_SYSTEM_TUI_LESS`, `NOCTTY_SYSTEM_TUI_SFTP`, and `NOCTTY_SYSTEM_TUI_SFTP_SERVER` can select explicit absolute executable paths. The script uses only scoped disposable homes, XDG roots, temporary directories, Zig caches, output files, and fixtures under one trap-cleaned workspace directory.
