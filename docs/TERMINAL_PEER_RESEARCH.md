# Terminal Peer Research: High-Performance and Agent Workspaces

Date: 2026-08-01.

Status: source-pinned architecture review with three accepted NOCTTY changes.
The review is based on the exact public revisions retained in
`benchmarks/terminal-peer-research-2026-08-01/sources.tsv`. Peer claims and
benchmarks are treated as design evidence, not as proof that one terminal is
universally faster than another.

## Question

What do current high-performance terminals, multiplexers, and agent-oriented
terminal workspaces do that transfers cleanly to NOCTTY's native Zig/GTK design?

The useful answer is not “copy their stack.” It is to identify where several
independent projects converge, compare that with NOCTTY's measured bottlenecks,
and retain only the smallest changes that improve correctness, latency, memory,
or parallel-agent usability.

## Repositories Reviewed

| Project | Pinned revision | Relevant surface |
| --- | --- | --- |
| Ghostty | `46edeee407ff` | Page-local terminal storage, incremental idle compression, separate I/O and renderer loops |
| WezTerm | `d69264df66fd` | Stable rows, width reflow, blank-tail pruning, render snapshots |
| Alacritty | `852e971cddfa` | Occupied-cell bounds, adjacent-frame damage, timer ownership, glyph cache |
| Kitty | `999cde66dbd5` | Shared child monitor, bounded delayed parsing, segmented mmap history, write backpressure |
| foot | `8db88cceb758` | Direct descriptor loop, lazy rows, Pixman damage, Wayland presentation feedback |
| Rio | `497f97151bea` | Damage-driven snapshots, render scheduling, fair terminal/render locking |
| cmux | `2f4059bd3211` | OSC 9/99/777 agent notifications, unread attention, explicit hooks, bounded notification ingress |
| Herdr | `9a4ce5e13c1d` | Agent-aware detach/restore, explicit session references, safe OSC notifications, privacy boundaries |
| Agent Deck | `69bba27fbfcd` | Confirmed activity evidence, bounded attention list, suggest-only stale cleanup |
| Claude Squad | `2dd388e98572` | Simple tmux plus Git-worktree isolation |
| WaveTerm | `a4447c1563b2` | Durable remote sessions and workspace command primitives |
| Zellij | `0e6e4404027a` | Async PTY readiness, partial-write requeue, OSC 99 routing in nested panes |
| tmux | `31dccb6bc952` | Libevent PTY ownership, parse/read backpressure, durable server-side panes |
| Better Agent Terminal | `72dc4baa10c8` | Session rest/wake, activity indicators, agent/worktree UX |

The exact full revisions and repository URLs are retained in the artifact
folder. Star counts and marketing claims were deliberately excluded from the
decision process.

## High-Performance Terminal Findings

### Ghostty: make cold work resumable and benchmark restoration separately

Pinned sources:

- [`src/terminal/page.zig`](https://github.com/ghostty-org/ghostty/blob/46edeee407ff8fe153450098953ffc67e608c5f1/src/terminal/page.zig)
- [`src/terminal/PageList.zig`](https://github.com/ghostty-org/ghostty/blob/46edeee407ff8fe153450098953ffc67e608c5f1/src/terminal/PageList.zig)
- [`src/renderer/Thread.zig`](https://github.com/ghostty-org/ghostty/blob/46edeee407ff8fe153450098953ffc67e608c5f1/src/renderer/Thread.zig)
- [`src/benchmark/ScrollbackCompression.zig`](https://github.com/ghostty-org/ghostty/blob/46edeee407ff8fe153450098953ffc67e608c5f1/src/benchmark/ScrollbackCompression.zig)

Ghostty's terminal pages are self-contained contiguous mappings with row, cell,
style, grapheme, string, and hyperlink storage. Cold pages can retain their
virtual mapping while physical pages are discarded and a compressed encoding
is kept separately. Restoration is transparent at the page-access boundary.
Its renderer schedules compression from a terminal-specific activity token,
not from generic renderer wakes, and performs bounded incremental steps without
waiting for the terminal lock. Its benchmark separates setup, no-op,
compression, incremental compression, restoration, and memory reporting.

Transfer to NOCTTY:

- NOCTTY's accepted idle-history path already follows the important scheduling
  rule: PTY output, not cursor animation or generic redraw, resets the idle
  deadline.
- Bounded 64-row steps and a process-wide budget match the resumable-work
  principle without adding Ghostty's page architecture.
- NOCTTY should keep separate cold-access and resume-output measurements rather
  than treating memory reduction alone as success.

Not copied:

- A direct page-backed NOCTTY history experiment regressed active throughput.
  Ghostty's result depends on a page-native terminal representation designed
  around mapping retention and page-local side tables. Retrofitting only mmap
  into NOCTTY's current direct-cell/cold-row split does not inherit that design.

### WezTerm: remove blank rows below the cursor before width reflow

Pinned source:

- [`term/src/screen.rs`](https://github.com/wez/wezterm/blob/d69264df66fd96dd3323059715a06250806e01cd/term/src/screen.rs)

Before rewrapping a primary screen, WezTerm removes blank lines after the
cursor. This prevents rapid or combined width/height changes from manufacturing
scrollback and pushing meaningful content out of the viewport.

This exposed a real NOCTTY bug. In an 8x6 grid containing `A`, `B`, and `C`, a
width-changing shrink to 4x3 previously reflowed the three blank rows below the
cursor. The result was three history rows containing the real text and a fully
blank visible viewport.

Accepted NOCTTY change:

- `Grid.resizePrimaryReflow` now drops only fully default rows below the cursor.
- It refuses to drop rows with used columns, non-default cells, active wrap
  metadata, or a preceding wrapped continuation.
- The same fixture now retains zero fake history rows and displays `A`, `B`,
  and `C` in the three visible rows.

This is primarily a correctness fix, but it also avoids cold conversion,
history allocation, and row copying for blank tails during resize.

### Alacritty: carry damage across presentation boundaries

Pinned sources:

- [`alacritty/src/display/damage.rs`](https://github.com/alacritty/alacritty/blob/852e971cddfad7f820f53532d4a4944be5ee8701/alacritty/src/display/damage.rs)
- [`alacritty_terminal/src/grid/row.rs`](https://github.com/alacritty/alacritty/blob/852e971cddfad7f820f53532d4a4944be5ee8701/alacritty_terminal/src/grid/row.rs)
- [`alacritty/src/scheduler.rs`](https://github.com/alacritty/alacritty/blob/852e971cddfad7f820f53532d4a4944be5ee8701/alacritty/src/scheduler.rs)

Alacritty tracks an occupied prefix per row, preserves current and adjacent
frame damage, explicitly damages old/new cursor and selection positions, and
overdamages around cells to cover wide or overflowing glyphs. Timers are keyed
by topic and window and are removed as part of window teardown.

Transfer to NOCTTY:

- NOCTTY already tracks dirty column spans, old/new cursor cells, full-redraw
  fallback, one owned presentation callback, and centralized source teardown.
- The remaining transferable proof is mapped adjacent-frame selection and
  overflowing-glyph damage, not another damage representation.

No code was added here because the current exact renderer is pixel-stable and
its measured full-screen path is already neutral after the 14-byte cell change.

### Kitty: throughput is batching, but backpressure must not block the UI

Pinned sources:

- [`kitty/child-monitor.c`](https://github.com/kovidgoyal/kitty/blob/999cde66dbd531612e293f47396a9931a49193f6/kitty/child-monitor.c)
- [`kitty/history.c`](https://github.com/kovidgoyal/kitty/blob/999cde66dbd531612e293f47396a9931a49193f6/kitty/history.c)
- [`docs/performance.rst`](https://github.com/kovidgoyal/kitty/blob/999cde66dbd531612e293f47396a9931a49193f6/docs/performance.rst)

Kitty uses one child-monitor I/O thread for many PTYs, bounded input-delay
coalescing, a parser/render split, capped output buffers, and segmented mmap
history to avoid allocator fragmentation. Its performance documentation
separates keyboard latency, throughput, and CPU/energy rather than naming one
composite winner.

Transfer to NOCTTY:

- Keep ingestion, draw, memory, idle CPU, and marker latency separate.
- Preserve the 2 MiB drain ceiling because NOCTTY's eight/32-pane benchmark
  rejected smaller universal ceilings.
- Never turn PTY write backpressure into GTK-thread sleeping.

The final item exposed another concrete NOCTTY problem and produced the largest
new latency win in this pass; see “Nonblocking PTY writes” below.

Not copied:

- A shared I/O thread remains unjustified while GLib descriptor readiness and
  current aggregate ingestion remain above realistic agent output rates.
- Kitty's segmented mmap history is architecture-specific; NOCTTY's direct
  page-backed experiment lost its active benchmark.

### foot: measure compositor frames before replacing the renderer

Pinned sources:

- [`render.c`](https://codeberg.org/dnkl/foot/src/commit/8db88cceb758de550cd1cc17a5840d5273e844d5/render.c)
- [`fdm.c`](https://codeberg.org/dnkl/foot/src/commit/8db88cceb758de550cd1cc17a5840d5273e844d5/fdm.c)
- [`grid.h`](https://codeberg.org/dnkl/foot/src/commit/8db88cceb758de550cd1cc17a5840d5273e844d5/grid.h)

foot uses a direct epoll-based descriptor manager, lazily allocated rows,
per-cell cleanliness, Pixman regions, and Wayland presentation feedback. It
counts whether presentation took zero, one, or multiple monitor intervals.

Transfer to NOCTTY:

- The valuable next step is the same measurement boundary: count missed mapped
  frames on Plasma Wayland/X11.
- Replacing GLib readiness with custom epoll would duplicate a kernel-readiness
  service already present in the current GTK process without evidence of a
  bottleneck.
- A GPU or custom compositor path remains deferred until mapped 4K/HiDPI or
  120/144 Hz evidence shows Cairo consumes the frame budget.

### Rio, Zellij, and tmux: separate mutable terminal state from slow consumers

Pinned sources:

- [`Rio librio/src/render_state.rs`](https://github.com/raphamorim/rio/blob/497f97151beac5a318529ac81202942190068881/librio/src/render_state.rs)
- [`Zellij zellij-server/src/os_input_output_unix.rs`](https://github.com/zellij-org/zellij/blob/0e6e4404027ae9bd5f9edbc38b85a097bb986ba6/zellij-server/src/os_input_output_unix.rs)
- [`tmux window.c`](https://github.com/tmux/tmux/blob/31dccb6bc952290e91dfbd631a5e55951b4cf94f/window.c)

Rio snapshots only damaged visible terminal state into reusable render-owned
rows and styles. Zellij uses nonblocking async descriptors and requeues partial
writes. tmux disables pane reads after a parse callback until its parser path is
ready again. All three make ownership/backpressure explicit rather than
assuming every consumer is always ready.

Transfer to NOCTTY:

- NOCTTY's ABI-v2 borrowed packed rows and dirty spans already avoid an owned
  full-grid clone for every frame.
- PTY writes were the missing backpressure boundary: `Pty.writeAll` slept in a
  loop on `EAGAIN`, and native GTK input called it synchronously.
- The retained direct GLib lane now measures one flooding pane against 29 marker panes before any change to the successful 2 MiB read budget or source priority. `ReleaseSafe` delivered every marker below 2.5 ms on the retained host, so no scheduler rewrite is justified.

## Agent-Focused Findings

### cmux and Herdr: explicit notification protocols beat output guessing

Pinned sources:

- [`cmux README`](https://github.com/manaflow-ai/cmux/blob/2f4059bd32117a62495763ca0e5e9566159bedde/README.md)
- [`cmux GhosttyDesktopNotificationIngress.swift`](https://github.com/manaflow-ai/cmux/blob/2f4059bd32117a62495763ca0e5e9566159bedde/Sources/GhosttyDesktopNotificationIngress.swift)
- [`cmux AgentHookNotificationPolicy.swift`](https://github.com/manaflow-ai/cmux/blob/2f4059bd32117a62495763ca0e5e9566159bedde/CLI/AgentHookNotificationPolicy.swift)
- [`Herdr src/terminal_notify.rs`](https://github.com/herdrdev/herdr/blob/9a4ce5e13c1d156c944560124bac4879eb225d18/src/terminal_notify.rs)

cmux turns OSC 9/99/777 requests and explicit agent hooks into pane attention,
unread navigation, and desktop notifications. Its Ghostty callback ingress has
a fixed newest-wins buffer instead of creating an unbounded task per event.
Herdr emits sanitized OSC 9 or structured OSC 99 and wraps it correctly for
tmux passthrough.

Accepted NOCTTY change:

- The bounded VT string parser now recognizes non-progress OSC 9, non-query OSC 99,
  and `OSC 777;notify;...` requests.
- NOCTTY stores only a monotonic notification serial; it does not persist
  notification text or agent transcripts.
- The native host turns a new serial into a pending-input state and compact
  attention signal. Output cannot accidentally clear an unread request; focus
  or actual user input acknowledges it. Dedicated adapter event IDs keep this
  status path separate from scrollback, font, and idle-compaction callbacks.
- An unfocused pane may issue a generic freedesktop notification when desktop
  notifications are enabled. Delivery is rate-limited to one per pane per
  second, and terminal-provided text is not exposed on the desktop.
- The compact native smoke now drives an actual OSC 9 request rather than
  simulating attention only with BEL.

NOCTTY deliberately does not scan rendered terminal text for words such as
“done,” “permission,” or “waiting.” Explicit hooks and terminal protocols are
more accurate, cheaper, language-independent, and less vulnerable to false
positives from ordinary command output.

### Agent Deck: unknown activity must remain unknown

Pinned sources:

- [`internal/session/instance_display_activity_test.go`](https://github.com/asheshgoplani/agent-deck/blob/69bba27fbfcd7b27f207d0de27abecdb611df912/internal/session/instance_display_activity_test.go)
- [`cmd/agent-deck/status_stale.go`](https://github.com/asheshgoplani/agent-deck/blob/69bba27fbfcd7b27f207d0de27abecdb611df912/cmd/agent-deck/status_stale.go)
- [`internal/session/notifications.go`](https://github.com/asheshgoplani/agent-deck/blob/69bba27fbfcd7b27f207d0de27abecdb611df912/internal/session/notifications.go)

Agent Deck distinguishes a tracker's initialization time from confirmed real
activity. Its stale-session view is suggest-only, includes the evidence behind
each classification, and never auto-stops or deletes a session. Its attention
list is bounded and newest-first.

Transfer to NOCTTY:

- Process start, PTY output, explicit notification, user input, and process exit
  remain separate evidence. Startup time must not masquerade as recent agent
  activity.
- Idle-history compaction may reclaim terminal memory, but NOCTTY must not kill
  or “hibernate” an agent from an idle-output heuristic.
- If a stale-session view is added later, it should be read-only and show its
  evidence rather than claiming an agent is safe to terminate.

### Herdr and Claude Squad: persistence has distinct levels

Pinned sources:

- [`Herdr session-state.mdx`](https://github.com/herdrdev/herdr/blob/9a4ce5e13c1d156c944560124bac4879eb225d18/docs/next/website/src/content/docs/session-state.mdx)
- [`Claude Squad README`](https://github.com/smtg-ai/claude-squad/blob/2dd388e98572b28c37579b6094b7bb90c90e13e5/README.md)

Herdr cleanly separates:

1. detach/reattach where the original process stays alive;
2. layout snapshots that restart ordinary shells;
3. optional screen-history persistence with an explicit secrets warning;
4. native agent resume using an official session reference;
5. experimental live server handoff.

Claude Squad obtains a large practical win from a much smaller model: tmux for
process continuity and Git worktrees for task isolation.

Transfer to NOCTTY:

- NOCTTY's current hot-session file is correctly a layout/cwd restart model,
  not a claim that arbitrary processes survived.
- Existing tmux/Zellij launch profiles are the lowest-complexity live process
  continuity path.
- Agent-native resume IDs may be useful later, but only through explicit,
  versioned integrations and only after authenticated agent qualification.
- Terminal screen history remains memory-only by default. Persisting it would
  require a GUI privacy policy, secure permissions, retention controls, and
  clear user consent.

### cmux hibernation and Better Agent Terminal rest/wake: defer destructive magic

cmux's current hibernation planner only considers restorable agents, protects
selected sessions, checks lifecycle state, rejects unconfirmed input, requires
idle evidence, snapshots transcripts, and revalidates the exact process set
before teardown. Better Agent Terminal exposes explicit rest/wake controls.

These projects demonstrate how much machinery is required to terminate an
agent safely. NOCTTY should not infer equivalent safety from PTY silence.
Explicit tmux/Zellij continuity and idle terminal-memory release cover the
current need with far less risk.

### WaveTerm and browser-rich agent workspaces: transfer primitives, not runtime

WaveTerm's durable SSH sessions, command blocks, and workspace CLI are useful
workflow ideas. cmux's programmable workspace/socket model is similarly
powerful. Their broader browser/AI surfaces and Better Agent Terminal's
Tauri/React/Node stack do not fit NOCTTY's native runtime boundary.

The transferable subset is already visible in NOCTTY's native design:
launch profiles, recursive splits, project cwd, tags, broadcast, status,
notifications, tmux/Zellij paths, and standalone NoctEd handoff.

## Accepted Implementation: Nonblocking PTY Writes

Before this pass, `TerminalSession.write` called `Pty.writeAll`. On `EAGAIN`,
that function slept for 1 ms and retried on the caller's thread. Native key and
paste callbacks run on GTK's main thread, so a child that temporarily stopped
reading could freeze the entire workspace.

A focused probe started a shell blocked in `sleep 2` and submitted an 8 MiB
input buffer:

| Path | Caller blocking time |
| --- | ---: |
| Prior synchronous `Pty.writeAll` path | 921.618 ms |
| New `TerminalSession` enqueue path | 1.450 ms |
| Caller-latency improvement | 635.8x |

This measures time until the input is safely accepted by NOCTTY, not time until
the sleeping child consumes every byte. A single current ReleaseFast/Xvfb
regression sample retained 131.275 MiB/s at eight output panes and 136.606 MiB/s
at 32 output panes. Those samples guard the established throughput scale; they
are not an A/B result or a peer ranking.

The accepted implementation:

- owns one ordered pending-write queue per session;
- caps queued input at 64 MiB before accepting any bytes;
- attempts immediate nonblocking writes and retains the exact remainder;
- flushes from PTY pumps, a 4 ms GTK source active only while writes are
  pending, and the existing one-second maintenance safety pass;
- queues terminal protocol replies through the same ordered boundary;
- releases large queue storage after drain and retains at most 256 KiB;
- removes the pending-write source through the existing centralized teardown;
- includes a real-PTY test that fills the queue while the child sleeps and
  proves it drains after the child starts reading.

No thread, custom epoll loop, dependency, or user-facing queue setting was
added.

**Retained agent fairness and large-paste boundary.** The follow-up `terminal_agent_fairness_matrix` uses thirty production PTY/session/VT instances behind equal-priority GLib Unix-FD sources and one shared guarded pump scratch. One unbounded flood remains active while twenty-nine exact marker panes are timed. Debug retained a 2,420.079 ms marker p95 under checked-parser load; `ReleaseSafe` retained 2.377 ms p95 and 2.409 ms max. Both modes delivered every marker and exited with zero allocator/process residue.

The same runner sends an 8 MiB raw paste through the ordered queue, waits for an exact child-drained marker, and separately tears down a session while an 8 MiB paste remains queued behind a foreground sleeper. Both paths close the PTY/session and process group without retaining queue state. This direct lane does not exercise GTK widgets, the mapped 4 ms flush source, frame-clock paint, or compositor presentation; [the focused receipt](TERMINAL_AGENT_FAIRNESS_QUALIFICATION.md) owns those limits.

**Retained mapped presentation boundary.** The later `native_grid_presentation_matrix` adds 64 synthetic production key-handler-to-draw/after-paint samples per mode on live Plasma Wayland/X11. It retains frame intervals and predictions; Wayland also supplied completed GDK presentation feedback, while X11 supplied none. The start bypasses the GDK event queue and physical HID, so it is mapped handler/presentation timing rather than keyboard-device latency.

## Accepted Herdr-Inspired Workspace Features

The follow-up implementation retains Herdr's useful continuity semantics while
staying native and local-first:

- Pane information now carries an explicit continuity badge: `restartable
  shell`, `live tmux`, `live Zellij`, or a named agent resume reference.
- Users can register or clear an opt-in Claude Code/Codex resume reference from
  the command palette. IDs are bounded and reject shell metacharacters; the
  reference is persisted in workspace snapshots, never inferred from output.
- Opening a workspace presents a restore choice: restart shells, attach
  persistent tmux/Zellij sessions, or resume registered agents. Unsupported or
  missing references fail closed to a shell rather than guessing.
- The command palette can export screen history to a `.nocttyhs` file protected
  with a user-entered password, PBKDF2-HMAC-SHA256, XChaCha20-Poly1305, a random
  salt/nonce, atomic replacement, and mode `0600`. Passwords and transcript
  contents are not stored in NOCTTY state.
- OSC 99/777 payloads may request only two structured, non-automatic actions:
  focus the pane or open its project view. The action is shown as pending and
  requires an explicit “Accept pending agent action” command; arbitrary command
  actions are ignored.

This is continuity metadata and guarded restore, not a claim that arbitrary
processes survive. Live continuity still requires tmux/Zellij, and agent resume
still requires the provider CLI and a valid provider-owned session reference.

## Decisions

### Keep

- Native Zig terminal core and GTK/Cairo host.
- GLib descriptor readiness and one process for many panes.
- Shared guarded pump scratch and direct 14-byte hot cells.
- Bounded idle-only cold history with content-preserving restoration.
- Explicit OSC/hook attention rather than output-text heuristics.
- tmux/Zellij as the simple process-survival boundary.
- Separate latency, throughput, memory, CPU, and correctness evidence.

### Defer

- GPU renderer until mapped high-refresh evidence exhausts Cairo's budget.
- Custom epoll or per-pane I/O/render threads until marker-latency profiling
  proves GLib/main-thread parsing is the bottleneck.
- Page-native history or direct mmap cells after the local active regression.
- Automatic agent termination/hibernation.
- Persisted terminal transcripts or screen history.
- Browser-runtime workspace surfaces.
- Agent-native resume IDs until explicit integration and authenticated proof.

## Next Measurements

1. Extend the 8 MiB paste lane through the mapped GTK 4 ms flush source only if direct-session and real dogfood evidence diverge.
2. Measure cold-history random access and full viewport restoration separately from resume-output latency, following Ghostty's benchmark split.
3. Consider structured OSC 99 title/body/action support only if generic, privacy-preserving attention proves insufficient in real agent dogfood.

## Evidence

```text
terminal_peer_research=true pinned_repositories=14 reflow_blank_tail_fixed=true osc_agent_attention=true pty_write_queue=true write_queue_cap_mib=64 write_queue_retained_kib=256 native_write_flush_ms=4 mapped_presentation=true wayland_presentation_feedback=true dependencies_added=0 gpu_rewrite=false custom_epoll=false agent_auto_hibernation=false
```

Focused receipts and checksums are retained under
`benchmarks/terminal-peer-research-2026-08-01/`.
