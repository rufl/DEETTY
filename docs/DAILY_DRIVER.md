# Daily-driver terminal audit

Audit refreshed: 2026-08-29.

## Verdict

NOCTTY already covers the core multi-tab, multi-pane drop-down workflow and its
measured terminal-only footprint is small. It is suitable for ordinary shell
work and supervised agent sessions, but it is not yet an unconditional Yakuake
replacement for all-day Codex, Claude Code, and Antigravity CLI use.

The minimum counted baseline now exists: seven operator-confirmed installed
sessions total 167.107 hours. Remaining daily-driver acceptance categories are
the specific four-pane, lifecycle, close-protection, editor, and multi-OMP
workflows, one clean current-build two-hour defect recapture, and the elapsed
48-hour hidden/visible stability run. Authenticated Codex 0.144.6 and installed
tmux/Zellij mapped acceptance are retained at one-host boundaries, and the
stability harness passes its short Debug/`ReleaseSafe` Wayland/X11 shakedown
without claiming multi-day completion. Hot-session recovery still restores
tabs, split geometry, profile state, and working directories by starting new
shells; arbitrary agent processes are not resurrected unless the user
deliberately runs them inside a persistent tmux/Zellij session.

The 2026-07-16 hardening slice closes the immediate lifecycle and idle-cost
defects. Current dogfood startup additionally rejects legacy relative pane cwd
state before PTY creation, recovers collapsed 32 px geometry to a usable
percentage size, keeps dropdown width horizontally centered, and stages GTK
Layer Shell so Plasma Wayland uses an undecorated overlay instead of a titled
fallback:

- pane, tab, toolbar, tray, and window close detect foreground process groups
  and require `Close Anyway` confirmation;
- PTY shutdown sends a hangup to the foreground and shell groups, tracks both
  independently through a bounded 500 ms grace period even when the shell
  exits first, then forces every surviving group instead of blocking the GTK
  thread or orphaning a stubborn job;
- retired sessions immediately deinitialize their Zig VT grid and remove
  dynamic session storage from the owning pool;
- affected contexts enter a callback-retired state before IM or GTK teardown;
  late draw, focus, input, resize, PTY, drag, and clipboard callbacks cannot
  reach released session userdata, and a pending clipboard read retains only
  its small C context until delivery;
- cursor blink and app maintenance use one root-owned timer each instead of one
  pair per pane;
- descriptor-backed exit fallback runs through the existing root maintenance
  pass, so live descriptor panes own no exit timer; a 16 ms pane timer exists
  only if descriptor registration fails;
- hidden panes still drain and parse PTY output, but presentation is coalesced
  to 100 ms and unmapped drawing areas do not queue redraws;
- native-grid ABI v6 consumes terminal-owned dirty column spans, coalesces
  equal-background fills, and caches eligible Cairo glyph conversion without
  weakening grapheme, rich-style, fallback-font, or full-redraw paths;
- mapped output uses one owned GTK frame-clock callback, hidden output retains
  its 100 ms path, and resize commits only the latest bounded geometry;
- split creation initializes pane ownership explicitly from one root controller
  instead of shallow-copying contexts that contain owned pointers or GLib
  source IDs;
- owned menus and process-local GTK popup windows are dismissed before parent
  hide or destruction; the hot-session Wayland/X11 gate treats GLib/GDK
  warnings as fatal (`popup_teardown=true`).
- the active tab exposes the focused pane's short cwd and foreground process,
  plus NOCTTY-wide and selected-terminal-tree CPU/RSS; hover adds full pane/PID/
  path/process-count detail. It reuses root maintenance and suppresses unchanged
  GTK updates instead of adding one timer per pane.
- the launch-profile flow adds one GUI-owned active profile plus up to eight
  bounded names for shell, command, SSH, Persistent tmux, Persistent Zellij,
  cwd, environment, target, and per-profile history. Rendered save/select/delete launches
  a real local command PTY with the selected cwd, environment, and history
  (`launch_profile=true`, `launch_library=true`, `launch_runtime=true`); version 9
  persists the two continuity kinds.
- local `noctty:` and `file:` workspace activation validates a bounded absolute
  snapshot path before PTY creation. Settings version 9 retains the version-8
  eight-entry recent-path library, and Project Workspace exposes it without manual config editing.
  Activation uses a separate native process. The maintained installed lane validates the real desktop/MIME contract in a disposable tree, dispatches `gio`, and clicks the real Recent Workspaces control. Live Plasma Wayland/X11 mapped two-tab child receipts now pass with controlled zero exit. Project Workspace keeps its summary scroll-accessible within the monitor work area and exposes assistive names.
- installed Codex 0.144.5's unauthenticated welcome/login surface, Vim 9.2,
  and btop 1.4.7 now pass through the production PTY, terminal session, and VT
  model in Debug and `ReleaseSafe`, including synchronized output,
  alternate-screen/focus/mouse modes, truecolor/Unicode, routed exit input,
  foreground identity, allocator/process teardown, and separate root/tree
  memory. This headless case does not authenticate Codex or submit a model request; the separate mapped companion does so with an exact ephemeral read-only response in every Debug/`ReleaseSafe` Wayland/X11 lane.
- installed tmux 3.7b and Zellij 0.44.3 now pass first attach, native detach, NOCTTY process exit/relaunch, reattach, preserved rendered content, and controlled cleanup across both modes and desktop backends.

Production `noctty` also excludes VTE, Tree-sitter, and smoke commands. The
optional fallback and smoke hosts are separate non-default binaries, reducing
production code and dependency surface without weakening the verification matrix.

The source-backed [performance and algorithm research](PERFORMANCE_ALGORITHM_RESEARCH.md) keeps GTK/Cairo and event-driven descriptor reads. Its frame-clock, glyph-cache, resize-coalescing, ABI-v2 dirty-span, bounded parser, synchronized-output, and grapheme-aware logical-line designs are implemented. NCT-120's compact-history/reflow qualification is complete. NCT-110 now combines pinned protocol/state, malformed-input, Unicode, installed Codex/Vim/btop, ncurses/system-TUI, and authenticated mapped Codex 0.144.6 evidence at the accepted one-host boundary.

NCT-119 is complete through four complementary boundaries: exact display-independent Cairo fixtures, real-shell PTY/VT-to-Cairo distributions, a live mapped Plasma presentation matrix, and live Wayland/X11 idle/fullscreen compositor-pixel plus memory/wakeup receipts. The presentation lane records 64 synthetic production key-handler-to-draw/after-paint samples per mode, frame intervals, predictions, and completed Wayland GDK presentation feedback; the full-stack lane records zero fallback PTY timer ticks and bounded idle callbacks. Neither claims physical input, X11 completed presentation timing, or multi-day evidence. GPU rendering and dedicated thread sets per pane remain deferred (`performance_algorithm_research=true`).

NoctEd's opt-in [core endurance qualification](NOCTED_CORE_ENDURANCE_QUALIFICATION.md) retains 512 cycles per mode through atomic save/load, edit/fold, project scan/search, Quick Open ranking, grammar conversion, allocator baselines, and root memory: `nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true`. This is bounded headless core repetition, not a daily-driver GTK worker/compositor or multi-day project soak.

The maintained [GLib worker qualification](NOCTED_WORKER_QUALIFICATION.md) adds real headless admission/concurrency: production `App` calls the qualified generation-supersession, 64 shared/32 per-lane cap, cancelled-lane exclusion, kind-cancellation, pending-lookup, lazy-pool, transactional-enqueue, rollback, and ordered-retirement functions before the runner drives both real pools: `nocted_worker_matrix debug=true release_safe=true shared_admission_policy=true generation_supersession=true shared_queue_cap=64 lane_queue_cap=32 cancelled_lane_excluded=true kind_cancel=true pending_lookup=true lazy_pool_creation=true transactional_enqueue=true append_failure_safe=true push_failure_rollback=true ordered_retirement=true glib_thread_pools=true worker_lanes=2 project_scan=true search_streaming=true snapshot_first=true cooperative_cancellation=true search_batch_size=24 search_batch_cap=2 backpressure_exercised=true foreground_save_under_backpressure=true worker_drained=true allocator_leak_free=true process_memory=true scratch_clean=true`. It proves foreground save remains usable while scan is blocked at its exact batch cap and cancellation/replacement/drain return allocator ownership to zero. It is not a mapped daily-driver UI or long-duration acceptance receipt.

The [native endurance qualification](NOCTED_NATIVE_ENDURANCE_QUALIFICATION.md) crosses that boundary with 32 complete Debug/`ReleaseSafe` workflows in every live Wayland/X11 lane. It retains 4,096 combined resource/search/monitor/lifecycle phase cycles, 3,072 deterministic ranking evaluations, rendered first/final UI, process-tree memory, warning-fatal GTK, and clean teardown over 630 seconds. This closes the sustained one-host NoctEd alpha boundary, not multi-day or varied-project daily-driver proof.

For eight idle descriptor-backed panes, the static periodic timer schedule falls
from the original 56 callbacks per second (eight 250 ms exit timers, eight
500 ms blink timers, and eight one-second maintenance timers) to
3 callbacks per second: root maintenance at 1 Hz plus root cursor blink at 2 Hz. Descriptor
readiness remains event-driven and presentation sources are one-shot. This is a
scheduling calculation, not a new CPU benchmark
(`descriptor_fallback=root_coalesced`, `pane_exit_timers=0`,
`source_cleanup=centralized`).

The bounded native-grid qualification repeats real 1x1/2x2/1x1 churn eight
times, grows through balanced 3x3 and 4x4 layouts, then proves cancel-first
shrink protection and preservation of 15 surplus sessions in an overflow tab
in both Debug and `ReleaseSafe`. A production-path matrix additionally opens
separate all-Vim and all-btop 4×4 tabs on both native Wayland and X11. Each case
starts from one source terminal and requires exactly 16 new sessions with mapped,
drawn, nonblank panes, routed input, source-tab preservation, and persisted-model
restoration
(`native_grid_layout_tui_matrix wayland=true x11=true applications=vim,btop panes=16 production_4x4=true mapped=true all_panes_drawn=true all_panes_nonblank=true rendered=true input_routed=true source_tab_preserved=true`). A complementary headless production-session lane
now repeats 64 ordinary plus eight forced real-PTY lifecycles per mode. The
forced job ignores `SIGHUP` and `SIGTERM`; all 16 cases exhaust the 500 ms grace,
lose both shell and foreground group, and leave zero process or allocator
residue. Both lanes sample the terminal root separately from the complete child
process tree and report
`native_grid_resource_qualification debug=true release_safe=true churn_cycles=8 max_live_sessions=16 overflow_preserved=true root_memory_separate=true process_tree_memory=true scratch_clean=true`
and
`terminal_session_qualification_matrix debug=true release_safe=true normal_cycles=64 forced_cycles=8 sessions_per_mode=72 total_sessions=144 allocator_leak_free=true forced_group_shutdown=true latency_percentiles=true root_memory_separate=true process_tree_memory=true scratch_clean=true`.
The controlled installed-application lane adds
`terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true`.
The display-independent renderer lane additionally reports
`native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true`.
These are short one-host engineering probes, not the multi-day agent-TUI soak, physical-input latency, final compositor acceptance, or universal cross-terminal ranking.

## Compatibility gaps

| Capability | Current boundary | Daily-driver requirement |
| --- | --- | --- |
| Tabs, pointer drag/reorder, recursive panes, focus, close, layouts, active-pane identity | Implemented and rendered; local pane identity uses PTY `/proc` metadata; the SSH profile has a retained real-OpenSSH public-key authentication case through the product PTY (`credentialed_ssh=true`) | Local stdio-transport authentication is not remote-network, agent/hardware-key, or live compositor proof |
| Drop-down, Plasma shortcut, tray, Wayland/X11 | Implemented and rendered | Retain |
| Bracketed paste, basic mouse/focus modes, alternate screen | Implemented; pinned DECRQM state cases run under six feed schedules, installed Vim retains alternate-screen/bracketed-paste/focus state, and installed btop retains alternate-screen/mouse/SGR-mouse state | Retain mapped cross-backend real-TUI interaction receipts |
| ANSI colors | 16/256/truecolor state and deterministic combined-SGR assertion retained; installed btop produces truecolor cells through the production grid | Retain mapped rendered state diffs and fallback corpus |
| Text attributes | Bold, inverse, underline, italic, dim, strike implemented; combined state retained | Retain real-TUI combination/fallback rendering corpus |
| Unicode layout | Grapheme-aware cells and width handling plus all 766 Unicode 17 grapheme-break cases retained; installed Codex and btop produce Unicode cell state | Retain real-TUI selection/search and mapped rendered diffs |
| OSC | Bounded OSC 8 hyperlinks and explicit blocked OSC 52 policy are state-diffed; fixed string overflow is retained | Retain native interaction receipts and fuzz duration |
| Terminal queries | Bounded DA/DSR/DECRQM/XTGETTCAP replies run in the pinned 23-case/six-schedule corpus | Retain real-agent query traces against the advertised `TERM=xterm-256color` surface |
| Link handling | OSC 8 state reaches native rich cells; Ctrl-click opens allowed links even while a TUI owns mouse reporting, and pixel-aligned underlines remain below the baseline | Retain hover/copy interaction evidence |
| Scrollback | GUI-configurable 0-to-100000-line ring, 1000 default, live global application plus independent per-profile choices in an eight-entry named library | Retain |
| Shell profiles | One atomic active profile plus up to eight GUI names cover interactive shell, one-line command, SSH, Persistent tmux, Persistent Zellij, absolute/inherited cwd, 16 bounded environment overrides, validated targets, persistence, save/select/delete, real selected local command launch, and disposable Ed25519 OpenSSH authentication (`credentialed_ssh=true`) | Retain remote-network and any password/agent/hardware-key expansion only if those claims are needed; the current bounded credential case is complete |
| Workspace activation | Bounded local `noctty:`/`file:` admission, pre-PTY snapshot restore, settings-version-9 retention of the version-8 eight-entry MRU, adaptive accessible Project Workspace dialog, and live installed `gio` plus rendered Recent Workspaces child activation on Plasma Wayland/X11 (`native_grid_installed_activation_matrix backends=wayland,x11 installed_desktop=true desktop_dispatch=true recent_child=true rendered=true controlled_exit=true scratch_clean=true`) | Retain |
| Process continuity | Layout/cwd hot restore plus first-class tmux/Zellij create-or-attach profile dispatch and installed tmux 3.7b/Zellij 0.44.3 mapped detach/relaunch/reattach with preserved content | Multi-day and remote/cross-host continuity remain outside the current receipt |
| Paired session sharing | Native direct encrypted pairing, pane/tab/session presentation, view-only default, per-pane grants, bounded history/paste, reconnect, revocation, explicit terminal-state recovery, and fail-closed dialog teardown compile on Linux and experimental Windows; focused peer-store tests pass | Retain current mapped interaction/accessibility evidence and physical Linux/Windows plus routed-VPN qualification before daily-driver sharing claims |
| Qualification | Debug/`ReleaseSafe` 32-session native-grid churn, repeated production PTY lifecycles, installed TUI tranches, authenticated Codex, installed tmux/Zellij relaunch/reattach, 100000-line reflow/grow-shrink, exact-Cairo frames, mapped key-to-frame runs, and archived Wayland/X11 pixels plus memory/wakeups | Multi-day pane churn, broader agent-product parity, final compositor acceptance, and physical-input latency |

The implementation selects `TERM=xterm-256color`, and the bounded Codex
login/Vim/btop lane now proves several advertised capabilities under real TUIs.
Completion still requires the remaining specific real-work workflows and
multi-day evidence; the minimum elapsed-session baseline is complete. Broader
application traces are needed only before making broader product-compatibility
claims.

For process continuity, select the matching persistent tmux or Zellij launch type with a session name. Installed server survival and later reattachment are retained on this host; NOCTTY still does not own a persistent terminal daemon or claim arbitrary-process resurrection.

## Memory accounting

The maintained split benchmark excludes shell/workload subtrees so it measures
the emulator rather than the application running inside it. Its eight-pane
NOCTTY median is 33.884 MiB PSS. Codex, Claude Code, Antigravity, their MCP
servers, subagents, language servers, and commands belong to child process
trees and can be much larger than the host terminal.

Measure a specific agent root without selecting or controlling any other
terminal:

```sh
./scripts/process_tree_memory.sh AGENT_PID
./scripts/process_tree_memory.sh AGENT_PID --details
```

Use PSS for comparisons. Summed RSS double-counts shared libraries. Take a
baseline after startup, after a representative long task, after compaction, and
after returning idle. Growth that remains after task completion is more useful
than a one-off peak when hunting a leak.

NOCTTY cannot safely impose an internal allocation policy on an unrelated CLI.
On systemd Linux, an optional per-session pressure boundary can be applied at
launch:

```sh
systemd-run --user --scope -p MemoryHigh=2G -- codex --profile lean
```

`MemoryHigh` asks the kernel to reclaim/throttle under pressure. Add
`MemoryMax` only when forced termination and loss of an in-progress turn are
acceptable.

## Codex CLI

The audit shell exposes Codex CLI 0.151.0. The high-value controls are:

- set `tui.alternate_screen = "never"` or launch with
  `codex --no-alt-screen` so interactive output enters terminal history;
  alternate-screen framebuffers cannot provide semantic terminal scrollback;
- use a lean profile and disable unused stdio MCP servers with
  `mcp_servers.NAME.enabled=false`; every enabled stdio server can add a local
  child process;
- keep `tool_output_token_limit` bounded so one command result does not remain
  as a very large transcript object;
- use `/compact` or start a new task between unrelated work; this directly
  reduces model context, while resident-memory improvement must still be
  measured rather than assumed;
- avoid unnecessary concurrent subagents and stop finished background
  terminals with `/ps` and `/stop`;
- use `/mcp` to audit active integrations.

Example `~/.codex/lean.config.toml`:

```toml
model_auto_compact_token_limit = 64000
tool_output_token_limit = 8000

[tui]
alternate_screen = "never"

[mcp_servers.rarely_used]
enabled = false
```

Launch it with `codex --profile lean`. See the official
[Codex configuration sample](https://learn.chatgpt.com/docs/config-file/config-sample),
[advanced profiles](https://learn.chatgpt.com/docs/config-file/config-advanced),
and [CLI slash commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli).

## Claude Code

Claude Code was not resolvable on this audit shell's `PATH`, so no local
resident-memory number is claimed. Anthropic's current guidance is to use
`/compact`, restart between major tasks, ignore large generated directories,
and use `--safe-mode` to isolate plugins, hooks, or MCP servers. `/heapdump`
produces a heap snapshot when growth persists.

For a low-concurrency terminal profile:

```sh
CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 \
ENABLE_CLAUDEAI_MCP_SERVERS=false \
CLAUDE_CODE_AUTO_CONNECT_IDE=false \
claude
```

Keep automatic compaction enabled. Disable unused MCP servers in `/mcp`; tool
search reduces schema context but does not make an unnecessary local server
process free. Disabling auto memory can reduce context/disk activity but is not
expected to be the main RSS lever. See Anthropic's official
[performance troubleshooting](https://code.claude.com/docs/en/troubleshooting),
[MCP controls](https://code.claude.com/docs/en/mcp), and
[environment variables](https://code.claude.com/docs/en/env-vars).

## Antigravity CLI

The current launcher is `agy`; it was not resolvable on this audit shell's
`PATH`, so no local memory result is claimed. To keep its local process set
bounded:

- disable unused MCP entries with `"disabled": true` and withhold unused tools
  through `disabledTools`;
- disable whole plugin bundles with `agy plugin disable NAME` when their hooks,
  MCP servers, or subagent definitions are not needed;
- inspect and terminate completed or runaway work in `/agents` and `/tasks`;
- avoid forks and parallel subagents for tasks that do not benefit from them;
- use `/clear` between unrelated work and workspace-scoped `/resume` rather
  than carrying one unbounded conversation;
- set `AGY_CLI_DISABLE_AUTO_UPDATE=true` when background update checks are not
  wanted.

Antigravity's inline rendering mode (`altScreenMode: "never"`) shifts visible
history to NOCTTY's bounded scrollback instead of its integrated alternate
screen. Measure both modes before calling either one lower-memory. See the
official [CLI settings](https://antigravity.google/docs/cli-settings),
[MCP configuration](https://antigravity.google/docs/mcp),
[plugins](https://antigravity.google/docs/cli-plugins), and
[background-agent controls](https://antigravity.google/docs/cli-subagents).

## Proof boundary

No Yakuake process, window, D-Bus endpoint, or session was controlled or
benchmarked during this audit. The existing benchmark remains the source for
terminal-only numbers. The new lifecycle claims are covered by Zig tests,
native source guards, the rendered pane-close smoke, and a deliberate
post-close callback in the two-tab smoke; long-duration agent soaks and full
modern-VT compatibility remain open backlog work.

Current lifecycle receipt: `foreground_guard=true session_storage_released=true
late_callback_guard=true popup_teardown=true root_timer_coalesced=true
hidden_present_throttled=true mapped_redraw_only=true`.
