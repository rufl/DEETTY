# NOCTTY Dogfood Runbook

Use this for counted public-alpha dogfood sessions. Do not count smoke tests,
screenshot sessions, or short launch checks.

Install the logging-enabled optimized builds, then inspect quota and raw runtime
evidence:

```sh
./scripts/install_dogfood.sh
./scripts/dogfood_status.sh
./scripts/dogfood_runtime_status.sh --list-candidates

# Optional safety-check build:
NOCTTY_DOGFOOD_OPTIMIZE=ReleaseSafe ./scripts/install_dogfood.sh
```

The default install is `ReleaseFast`, atomically replaces the staged binaries,
and includes the private GTK Layer Shell runtime used by the undecorated
Wayland dropdown. Fully close already-running NOCTTY/NoctEd processes after an
install so the next launch uses the replaced binary and launcher environment.

Logs are documented in `docs/DOGFOOD_LOGGING.md`.

## Counted session minimum

A counted session must be real work, not a test script:

- at least 2 hours in one finished primary `noctty` launcher receipt
- NOCTTY is the primary terminal workspace for the session
- the unique `noctty-…` receipt ID is recorded in `docs/DOGFOOD_LOG.md`
- problems are recorded in `docs/DOGFOOD_LOG.md`
- P0/P1 blockers are turned into backlog rows or fixed immediately

`dogfood_status.sh` counts a documented session only when its receipt is unique,
finished, and at least 7,200 seconds. A nonzero exit may still count when the
session was real work and the failure is documented. A running/incomplete
receipt, runtime-only candidate, duplicate receipt, smoke run, or missing work
description does not count.

## First-session target

For the first counted session, cover the smallest useful slice:

1. Launch NOCTTY from this checkout or installed local prefix.
2. Use at least two tabs or panes for real Lichforge work.
3. Run Pi or another coding-agent CLI inside NOCTTY.
4. Open NoctEd on the NOCTTY checkout.
5. Edit, save, find in file, find in project, and quick-open at least one real file.
6. Use copy/paste/search/scrollback during real work.
7. Test hide/show or normal exit/restore.
8. Record blockers and rough edges in `docs/DOGFOOD_LOG.md`.

## Four-pane session target

One of the five counted sessions must use four or more panes/tabs for real work.
Suggested layout:

- pane 1: shell/git/build commands
- pane 2: Pi/coding-agent session
- pane 3: logs or test output
- pane 4: manual app launch/smoke checks

## Multi-OMP compatibility target

Use the installed logging build; the result is extracted from its process logs,
not transcribed into `docs/DOGFOOD_LOG.md`.

1. Install the current source with `./scripts/install_dogfood.sh`.
2. Launch installed `noctty`, create four panes, enter four distinct worktrees,
   and start the same installed `omp` version in every pane.
3. Trigger visible output in all four OMP sessions concurrently. With broadcast
   input disabled, focus every pane, type in one pane, paste in one pane, and
   confirm the other three sessions remain independently usable.
4. While one OMP pane has produced output within the preceding two seconds,
   resize its pane or window.
5. Hide NOCTTY for several minutes, show it again, and confirm all four OMP
   sessions remain active.
6. Close NOCTTY normally while the four-pane layout exists, relaunch it, start
   OMP again from the same four restored panes/worktrees, and exercise each
   session. This supplies the correlated hot-restore receipt.
7. Attempt to close one OMP pane. Choose **Keep Open** first, then retry and
   choose **Close Anyway**; the three neighboring sessions must remain active.
8. Exit a different OMP process normally after it has rendered output, then
   leave NOCTTY normally so the launcher can finish its log review.
9. Run `./scripts/dogfood_status.sh`. `compatible=true` is the only accepted
   qualification result; a missing event remains false rather than requesting
   a manual assertion.

The status script correlates launcher invocations only when their hashed pane
identity set matches one restored workspace. It never combines independently
keyed partial preflights.

## Close-confirmation target

One counted session must check foreground-job protection:

1. Start a visible long-running foreground command in a pane, for example
   `sleep 600`.
2. Attempt to close that pane/window.
3. Confirm that NOCTTY asks before terminating the foreground job.
4. Record whether the prompt, cancel path, and accepted close behaved as expected.

## NoctEd target

At least three sessions should use NoctEd for real project edits. Each should
record:

- files opened
- edit/save or Save As path
- find-in-file or find-in-project query
- quick-open query
- dirty-close behavior if exercised

## What not to count

Do not count:

- `zig build check`
- `./scripts/public_alpha_verify.sh`
- screenshot capture only
- native smoke scripts only
- agent work running in this Pi harness instead of inside NOCTTY
- a launcher runtime receipt without a matching real-work log entry

Those are useful proof, but not dogfood.
