# Terminal Agent Fairness Qualification

Status: bounded NCT-119 GLib PTY-fairness and large-paste tranche passed on 2026-08-03. Mapped GTK presentation is retained separately.

## Qualified boundary

`scripts/terminal_agent_fairness_qualification.sh` builds the production `TerminalSession`, PTY, VT grid, shared 128 KiB pump scratch, and GLib Unix-FD source path in Debug and `ReleaseSafe`.

The fairness lane starts thirty real shell sessions. One pane runs an unbounded `yes` flood. After that pane has delivered at least 256 KiB, the other twenty-nine panes receive distinct OSC title markers and exits. Every descriptor uses equal-priority GLib readiness dispatch, every callback calls the unchanged bounded production pump, and all marker latencies are measured while flood bytes continue to arrive.

The same runner exercises two 8 MiB paste paths:

- a raw, echo-disabled child reads the complete paste through the ordered nonblocking queue, emits a drained marker, exits, and tears down; and
- a foreground child that is not reading input leaves paste bytes queued, then session teardown must discard the queue and remove the complete process group within the retained bound.

Both modes require all markers, shared-scratch serialization, queue exercise and drain, idempotent session closure, zero process residue, zero allocator residue, and trap-cleaned build/output scratch.

## Retained result

| Mode | Flood bytes while measuring | Marker p50 / p95 / p99 / max | 8 MiB enqueue / drain | Pending-paste teardown |
|---|---:|---:|---:|---:|
| Debug | 6,301,550 | 2,419.845 / 2,420.079 / 2,420.107 / 2,420.107 ms | 10.005 / 265.042 ms | 208.845 ms |
| ReleaseSafe | 675,169 | 0.611 / 2.377 / 2.409 / 2.409 ms | 4.561 / 551.238 ms | 15.039 ms |

These are one-host observations, not release thresholds. Debug intentionally pays checked-parser and allocator costs; the production-relevant `ReleaseSafe` lane retained all twenty-nine markers below 2.5 ms while the flood continued. No scheduler or 2 MiB pump-ceiling change was justified by this result.

A 2026-08-26 follow-up corrected PTY shutdown's grace accounting: the existing
50-iteration cap now also observes its intended 500 ms monotonic deadline, so
scheduler-stretched 10 ms sleeps cannot turn the grace period into seconds.
The exact aggregate subsequently retained 12.948 ms Debug and 12.698 ms
`ReleaseSafe` pending-paste teardown and completed with clean scratch. The
process-group signals, grace ceiling, forced cleanup, and two-second
qualification threshold were not weakened.

Stable contract:

```text
terminal_agent_fairness_matrix debug=true release_safe=true panes=30 flood_panes=1 marker_panes=29 all_markers=true shared_pump_scratch=true glib_fd_sources=true large_paste_bytes=8388608 paste_queue_exercised=true paste_drained=true paste_pending_teardown=true allocator_leak_free=true process_residual=0 scratch_clean=true
```

## Proof boundary

This is direct production PTY/session/VT behavior scheduled by GLib Unix-FD sources. It does not create GTK widgets, request frame-clock paint, archive compositor pixels, inject physical input, run authenticated agents, or establish multi-day fairness. The separate [mapped presentation receipt](NATIVE_GRID_PRESENTATION_QUALIFICATION.md) crosses GTK draw/frame-clock and Wayland presentation timing, and the [full-stack receipt](NATIVE_GRID_FULL_STACK_QUALIFICATION.md) retains live idle/fullscreen pixels, memory, and wakeups. Together they close NCT-119 without broadening this fairness lane.

The lane intentionally retains the existing one-callback/2 MiB pump ceiling and equal GLib priority. Change either only if a later mapped distribution shows marker starvation or presentation regressions.

## Reproduce

```sh
./scripts/terminal_agent_fairness_qualification.sh
```

Use `NOCTTY_FAIRNESS_PARENT=/dev/shm` when repository-backed cache writes would contend with unrelated host dirty pages.
