# Public Alpha Go/No-Go

This is the final public-source-alpha decision sheet. It does not replace the
backlog, release checklist, or dogfood log.

## Current decision

Status: **no-go for public alpha announcement** until real counted dogfood, the
NCT-125 current-build reliability recapture, and current screenshots exist.

Reason: source/docs/gates are ready enough for a bounded public-source alpha, but
`docs/DOGFOOD_LOG.md` still has zero counted sessions.

## Green now

- human-readable README
- known limitations
- public alpha plan
- code map
- draft release notes
- issue/PR templates
- real local Git history
- clean source-copy fast build/check
- bounded public-alpha gate
- no-surprise network source scan
- retained 2026-07-19 baseline screenshots, with their stale boundary documented
- authenticated Codex 0.144.6 mapped Wayland/X11 exact-response receipts
- installed tmux 3.7b/Zellij 0.44.3 detach/relaunch/reattach receipts
- Debug/`ReleaseSafe` Wayland/X11 hidden/visible stability-harness shakedown; the 48-hour run remains open

Current bounded gate:

```sh
./scripts/public_alpha_verify.sh
```

Current retained result:

```text
public_alpha_verify passed=true build_check=true no_surprise_network=true dogfood_logging_smoke=true docs_truth=true native_grid_smoke=true nocted_native_smoke=true full_verify=false
```

## Red now

Current dogfood status:

```text
dogfood_status counted_sessions=0 documented_sessions=0 unverified_sessions=0 not_counted_sessions=3 counted_seconds=0 counted_hours=0.000 five_sessions=false four_pane=false agent_cli=false nocted_real_edit=false foreground_close_confirmation=false
dogfood_omp_status observed_sessions=0 qualified_sessions=0 qualified_version=none max_concurrent=0 separate_worktrees=false concurrent_streaming=false independent_input=false independent_paste=false resize_during_output=false focus_isolation=false hide_show=false close_cancel=false close_accept_isolated=false normal_exit_cleanup=false hot_restore=false output_integrity=false logs_clean=false compatible=false
```

Current NOCTTY and NoctEd screenshots are also open release work. The retained
images predate the current UI, and this sandbox could not create the isolated
display/session sockets required for a safe recapture.

Retained launcher logs separately prove 20.945 NOCTTY process-hours and 8.082
NoctEd process-hours on this host. Those values may overlap. The clean 2.699-hour
NOCTTY and 3.203-hour NoctEd candidates lack recorded real-work context, so they
remain uncounted.

Do not publish broad daily-driver claims until this changes.

## Acceptable public-source-alpha path

A bounded source-alpha announcement is acceptable after at least one real counted
session if the wording stays narrow:

- say source alpha, not daily-driver release
- say fast gate and bounded alpha gate pass
- say the full single-job maintainer gate passes locally, while the bounded
  source-alpha gate does not run that full matrix
- say dogfood evidence has started, not completed
- say package/signing/release operations are incomplete

## Stronger alpha path

A stronger daily-driver alpha needs:

- five counted 2+ hour sessions
- one four-pane/tab session
- one Pi/coding-agent session inside NOCTTY
- foreground-job close confirmation
- NoctEd used for real edits in at least three sessions
- no open P0/P1 dogfood blockers

The retained stability harness is ready and its short matrix passes. The default 48-hour authenticated run remains the stronger release-evidence boundary and may run in parallel with counted dogfood.

The 2026-08-29 dogfood defect slice passes its 418-test build check, but the
managed sandbox could not create the required isolated graphical namespace.
Do not convert the scrollbar/lifecycle fixes into runtime acceptance until an
installed Plasma Wayland session runs for at least two hours and exits cleanly.
The follow-on source/behavior audit also passes its focused compile, source,
theme, and static-analysis checks. Current screenshot capture still failed
closed at sandbox-denied private D-Bus socket creation, so it adds no mapped or
compositor evidence.

## Decision rule

If `./scripts/dogfood_status.sh` reports `counted_sessions=0`, public alpha is
still no-go except for private/pre-announcement review.
