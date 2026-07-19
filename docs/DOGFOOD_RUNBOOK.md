# NOCTTY Dogfood Runbook

Use this for counted public-alpha dogfood sessions. Do not count smoke tests,
screenshot sessions, or short launch checks.

Quick status:

```sh
./scripts/dogfood_status.sh
```

## Counted session minimum

A counted session must be real work, not a test script:

- at least 2 hours
- NOCTTY is the primary terminal workspace for the session
- problems are recorded in `docs/DOGFOOD_LOG.md`
- P0/P1 blockers are turned into backlog rows or fixed immediately

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

Those are useful proof, but not dogfood.
