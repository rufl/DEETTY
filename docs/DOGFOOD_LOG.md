# NOCTTY Dogfood Log

Use this file to record real daily-driver sessions before public alpha. Keep it
honest: failures and annoyances are useful. Session rules live in
[`DOGFOOD_RUNBOOK.md`](DOGFOOD_RUNBOOK.md).

## Session template

```markdown
## YYYY-MM-DD — session title

- Duration:
- Desktop/session: Plasma Wayland / Plasma X11 / other
- NOCTTY command:
- Work performed:
- Panes/tabs used:
- Agent/TUI apps used:
- NoctEd used: yes/no; for what files?

### What worked

-

### Problems

- [ ] P0/P1/P2: description, reproduction, expected behavior

### Resource notes

- CPU/memory observation if measured:
- Any visible jank/hangs:

### Follow-up

-
```

## Alpha dogfood checklist

- [ ] Five sessions of at least two hours each
- [ ] One session with four or more panes/tabs
- [ ] One Pi/Codex/Claude/agent CLI session inside NOCTTY
- [ ] Hide/show tested during real work
- [ ] close confirmation tested with foreground job
- [ ] hot-session restore tested after normal exit
- [ ] copy/paste/search/scrollback used during real work
- [ ] NoctEd used for real project edits in at least three sessions

## Sessions

## 2026-07-19 — public-alpha repository prep (not counted toward dogfood quota)

- Duration: Pi-assisted prep session
- Desktop/session: not verified as a NOCTTY-hosted GUI dogfood session
- NOCTTY command: not launched for this entry
- Work performed: public-alpha documentation pass, source code map, screenshot capture automation, README screenshots, verification-status note
- Panes/tabs used: not measured
- Agent/TUI apps used: Pi coding-agent harness
- NoctEd used: no

### What worked

- The repository now has a public-readable alpha path and a contributor code map.
- The current verification uncertainty is recorded instead of being hidden.
- Automated screenshot capture produced real Plasma Wayland NOCTTY and NoctEd PNGs.

### Problems

- [ ] P1: Real NOCTTY/NoctEd dogfood sessions still need to be captured before counting alpha readiness as green.
- [x] P1: `zig build run-nocted -- --project . --open README.md` aborted in a worker because the project index path expected an absolute path. Fixed on 2026-07-19: NoctEd now resolves relative project/document CLI paths to absolute real paths before worker admission, and the relative launch was re-tested without panic/assertion.

### Resource notes

- CPU/memory observation if measured: not measured
- Any visible jank/hangs: not applicable

### Follow-up

- Run a real NOCTTY session and a real NoctEd edit/search/save session, then add the first counted dogfood entry below this one.
- Continue with a real counted NOCTTY + NoctEd dogfood session; the relative-path CLI assertion is fixed.

## 2026-07-19 — dogfood preflight smoke hardening (not counted toward dogfood quota)

- Duration: focused preflight slice
- Desktop/session: managed X11 and Wayland smoke backends
- NOCTTY command: `./scripts/native_grid_smoke.sh`
- Work performed: pre-dogfood native-grid smoke rerun before starting counted sessions
- Panes/tabs used: smoke fixture only
- Agent/TUI apps used: Pi coding-agent harness
- NoctEd used: smoke fixture only; `./scripts/nocted_native_smoke.sh` passed

### What worked

- NoctEd native smoke passed with project tree, search/load, quick open, Save As, session restore, recent project, and worker/lifecycle receipts.
- After fixture timing hardening, native-grid smoke passed on both X11 and Wayland with synchronized-output normal release and deadman release evidence.

### Problems

- [x] P1: `./scripts/native_grid_smoke.sh` initially failed because the synchronized-output smoke command's timing could miss either the normal DECSET 2026 release or the deadman release under current backend scheduling. Fixed by lengthening only the smoke fixture's synchronized-output windows; production behavior unchanged.

### Resource notes

- CPU/memory observation if measured: not measured beyond smoke receipts.
- Any visible jank/hangs: none observed by the smoke after the timing fix.

### Follow-up

- Start the first counted two-hour NOCTTY/NoctEd dogfood session.

_Add new counted entries here._
