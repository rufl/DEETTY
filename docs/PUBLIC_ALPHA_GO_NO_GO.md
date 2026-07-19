# Public Alpha Go/No-Go

This is the final public-source-alpha decision sheet. It does not replace the
backlog, release checklist, or dogfood log.

## Current decision

Status: **no-go for public alpha announcement** until real counted dogfood exists.

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
- current screenshots

Current bounded gate:

```sh
./scripts/public_alpha_verify.sh
```

Current retained result:

```text
public_alpha_verify passed=true build_check=true no_surprise_network=true docs_truth=true native_grid_smoke=true nocted_native_smoke=true full_verify=false
```

## Red now

Current dogfood status:

```text
dogfood_status counted_sessions=0 not_counted_sessions=2 five_sessions=false four_pane=false agent_cli=false nocted_real_edit=false foreground_close_confirmation=false
```

Do not publish broad daily-driver claims until this changes.

## Acceptable public-source-alpha path

A bounded source-alpha announcement is acceptable after at least one real counted
session if the wording stays narrow:

- say source alpha, not daily-driver release
- say fast gate and bounded alpha gate pass
- say full maintainer verify still needs long local completion
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

## Decision rule

If `./scripts/dogfood_status.sh` reports `counted_sessions=0`, public alpha is
still no-go except for private/pre-announcement review.
