# Dogfood Install and Logging

Install unstripped `ReleaseFast` binaries plus local logging launchers:

```sh
./scripts/install_dogfood.sh
```

Default prefix: `~/.local`.

Installed commands:

```text
~/.local/bin/noctty
~/.local/bin/nocted
```

The commands and installed desktop entries run the staged binaries from:

```text
~/.local/libexec/noctty-dogfood/noctty-bin
~/.local/libexec/noctty-dogfood/nocted-bin
```

The installer also stages `libgtk-layer-shell.so.0` in the same private runtime
tree and the launcher exposes that exact directory to the binaries. Dropdown
mode therefore uses an undecorated Wayland layer surface even when the host has
not installed GTK Layer Shell system-wide.

Override the default optimization mode when debugging a local issue:

```sh
NOCTTY_DOGFOOD_OPTIMIZE=Debug ./scripts/install_dogfood.sh
```

## Logs and duration receipts

Every launcher invocation records command arguments, session/backend context,
host and boot identity, wall-clock and monotonic start values, stdout, stderr,
GTK/GLib debug messages, timestamp, duration, and exit status under:

```text
~/.local/state/noctty/logs/
```

The launcher also atomically maintains a private `0600` receipt under:

```text
~/.local/state/noctty/dogfood-sessions/
```

The receipt is written as `state=running` before the binary starts and replaced
with `state=finished`, end time, monotonic duration, and exit status after every
ordinary zero or nonzero exit. If the launcher or machine is killed, the
running receipt remains visibly incomplete and is never counted as elapsed
acceptance evidence. Duration uses `/proc/uptime` while the boot ID matches and
falls back to bounded nonnegative wall-clock subtraction only when necessary.

Follow current process logs and inspect retained runtime:

```sh
tail -F ~/.local/state/noctty/logs/*.log
./scripts/dogfood_runtime_status.sh
./scripts/dogfood_runtime_status.sh --list-candidates
./scripts/dogfood_status.sh
```

`dogfood_runtime_status.sh` imports both version-1 receipts and older
`dogfood_launch`/`dogfood_exit` logs. Its hours are runtime-only evidence:
NOCTTY and NoctEd may overlap and must not be summed as unique wall-clock work.
A two-hour runtime candidate counts toward the public-alpha quota only after one
real-work entry in `docs/DOGFOOD_LOG.md` names that unique NOCTTY receipt.

`dogfood_status.sh` derives `dogfood_omp_status` from the retained NOCTTY
process logs. Do not copy manual `pass`/`fail` claims into
`docs/DOGFOOD_LOG.md`. After the native host has detected an OMP process, the
launcher records the locally installed `omp/X.Y.Z` version and gives the native
host its receipt session ID and log path. The host writes one-line records with

```text
dogfood_event session=ID event=omp_NAME pane=ID value=INTEGER detail=TOKEN
```

All values are space-free allowlisted tokens. `omp_detected` is emitted only
when the PTY foreground-process basename is exactly `omp`; its detail is the
SHA-256 digest of that process working directory, not the directory text.
`omp_workspace` hashes the active OMP pane IDs so a normal-exit/relaunch pair
can be correlated to one restored workspace without combining unrelated
partial sessions.

The native action path emits concurrency, concurrent-output, independent
input, independent paste, resize-during-output, focus, hide/show,
close-cancel, isolated accepted-close, normal-exit cleanup, hot-restore, and
PTY-byte delivery records. After ordinary process exit, the launcher emits
`omp_log_review value=1` only when that invocation contains OMP detection and
no native fatal/error marker. `compatible=true` requires one correlated
workspace, one valid unchanged OMP version, at least four distinct
working-directory digests and focused panes, at least four concurrent OMP
processes, every required action record, clean logs for every contributing
launcher invocation, and a successful hot-restore correlation. Missing,
malformed, dirty, version-mismatched, or independently keyed partial logs
remain unqualified.

The launcher retains the newest 100 verbose logs and 500 compact receipts per
app. It enables core dumps when the session permits them; systemd-managed crash
details can then be inspected with:

```sh
coredumpctl info noctty-bin
coredumpctl info nocted-bin
```

No logs or receipts are uploaded. Logging is local only and adds no telemetry
or network behavior.

When **Open NoctEd Here** starts NoctEd, the sibling installed launcher is used,
so that editor process receives its own log and duration receipt.
