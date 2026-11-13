# Public Alpha Go/No-Go

This is the final public-source-alpha decision sheet. It does not replace the
backlog, release checklist, or dogfood log.

## Current decision

Status: **no-go for public alpha announcement** until the
NCT-125 current-build reliability recapture exists.

Reason: source/docs/gates and the minimum counted-session baseline are ready,
but no retained session exercises NCT-125's specified workflow on the final
installed source state without its historical failure markers.

## Green now

- human-readable README
- known limitations
- public alpha plan
- code map
- draft release notes
- issue/PR templates, contributor licensing terms, conduct/support policies, and private security-reporting instructions
- pinned read-only GitHub Actions source CI plus a source-publication runbook
- tracked-source hygiene guard plus a full-history Gitleaks scan reporting zero findings
- real local Git history
- clean source-copy fast build/check
- bounded public-alpha gate
- no-surprise network source scan
- current 2026-09-06 `ReleaseSafe` installed-tree screenshots from a private disposable display/session boundary
- authenticated Codex 0.144.6 mapped Wayland/X11 exact-response receipts
- installed tmux 3.7b/Zellij 0.44.3 detach/relaunch/reattach receipts
- Debug/`ReleaseSafe` Wayland/X11 hidden/visible stability-harness shakedown; the 48-hour run remains open
- seven operator-confirmed installed DEETTY sessions totaling 167.107 counted hours; the five-session and agent-use baselines are met

Current bounded gate:

```sh
./scripts/public_alpha_verify.sh
```

Current retained result:

```text
public_alpha_verify passed=true source_hygiene=true build_check=true no_surprise_network=true dogfood_logging_smoke=true docs_truth=true native_grid_smoke=true nocted_native_smoke=true full_verify=false
```

## Red now

Current dogfood status:

```text
dogfood_status counted_sessions=7 documented_sessions=7 unverified_sessions=0 not_counted_sessions=3 counted_seconds=601585 counted_hours=167.107 five_sessions=true four_pane=false agent_cli=true nocted_real_edit=true foreground_close_confirmation=false
dogfood_omp_status observed_sessions=1 qualified_sessions=0 qualified_version=none max_concurrent=5 separate_worktrees=true concurrent_streaming=true independent_input=true independent_paste=true resize_during_output=true focus_isolation=true hide_show=true close_cancel=false close_accept_isolated=false normal_exit_cleanup=false hot_restore=true output_integrity=false logs_clean=false compatible=false
```

Current DEETTY and NoctEd publication captures were refreshed without exposing
the author's desktop. They prove current rendering only and do not close
current-build workflow or physical-input gates.

Retained launcher logs prove 188.293 total DEETTY process-hours and 14.568
NoctEd process-hours on this host; those totals may overlap. Seven unique
operator-confirmed DEETTY receipts contribute 167.107 counted hours. Historical
failure/warning sessions remain documented, and uninstrumented time is not
promoted into specific interaction claims.

The retained native OMP records now expose partial evidence for four worktrees,
five concurrent processes, streaming, input, paste, resize, focus, hide/show,
and hot restore. Missing close-cancel, isolated accepted-close, normal-exit
cleanup, output-integrity, and clean contributing-log records keep the protocol
unqualified.

Do not publish broad daily-driver claims until the remaining workflow evidence
exists.

## Acceptable public-source-alpha path

A bounded source-alpha announcement becomes acceptable after NCT-125's clean
current-build workflow recapture. The minimum counted-session threshold is
already met; wording must stay narrow:

- say source alpha, not daily-driver release
- say fast gate and bounded alpha gate pass
- say the full single-job maintainer gate passes locally, while the bounded
  source-alpha gate does not run that full matrix
- say seven counted sessions establish sustained use, not complete workflow or
  compatibility coverage
- say package/signing/release operations are incomplete

## Stronger alpha path

A stronger daily-driver alpha needs:

- [x] five counted 2+ hour sessions
- [ ] one four-pane/tab session
- [x] one Pi/coding-agent session inside DEETTY
- [ ] foreground-job close confirmation
- [ ] NoctEd used for real edits in at least three sessions
- [ ] no open P0/P1 dogfood blockers

The retained stability harness is ready and its short matrix passes. The default 48-hour authenticated run remains the stronger release-evidence boundary and may run in parallel with counted dogfood.

The 2026-08-29 dogfood defect slice passes its 418-test build check, but the
managed sandbox could not create the required isolated graphical namespace.
Do not convert the scrollbar/lifecycle fixes into runtime acceptance until an
installed Plasma Wayland session runs for at least two hours and exits cleanly.
The follow-on source/behavior audit also passed its focused compile, source,
theme, and static-analysis checks. That audit's screenshot attempt failed
closed at sandbox-denied private D-Bus socket creation, so the audit added no
mapped or compositor evidence. The later captures listed above are separate
presentation evidence only.

## Decision rule

If NCT-125 remains open, public alpha is still no-go except for
private/pre-announcement review. The current count clears the minimum session
threshold but does not substitute elapsed time for the required workflow.
