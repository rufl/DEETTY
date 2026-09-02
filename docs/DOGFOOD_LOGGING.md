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
tree and the launcher exposes that exact directory to the binaries. The first
install requires the system library. Later refreshes may reuse the staged copy
only when its SHA-256 matches the previous private build receipt; otherwise the
installer fails closed. Dropdown mode therefore remains an undecorated Wayland
layer surface if the system package is later removed.

Override the default optimization mode when debugging a local issue:

```sh
NOCTTY_DOGFOOD_OPTIMIZE=Debug ./scripts/install_dogfood.sh
```

## Logs and duration receipts

Every GUI-session launcher invocation records command arguments (capped at
512 bytes each with control bytes replaced so filenames cannot forge log
records), session/backend context, sanitized host and boot identity, the local
OS/kernel/desktop/Plasma/KWin fingerprint, staged-binary SHA-256, wall-clock and
monotonic start values, stdout, stderr, GTK/GLib warnings, timestamp, duration,
exit status, and bounded runtime warning-marker counts under:

```text
~/.local/state/noctty/logs/
```

Existing-owner `--status`, `--show`, `--hide`, and `--toggle` calls plus
`--version` bypass this setup and execute the staged binary directly; a Show or
Toggle with no owner still starts a fully logged GUI session. Show/Toggle first
consult the current owner's already-held native instance lock, avoiding a
redundant D-Bus status round trip; a D-Bus probe remains only as compatibility
fallback for older or degraded owners. This keeps external shortcut activation
latency close to one native D-Bus call instead of paying the
desktop/version/hash/log-rotation setup on every toggle. Set
`NOCTTY_DOGFOOD_VERBOSE=1` when full GTK/GLib debug messages are needed.

The launcher also atomically maintains a private `0600` receipt under:

```text
~/.local/state/noctty/dogfood-sessions/
```

The receipt is written as `state=running` before the binary starts and replaced
with `state=finished`, end time, monotonic duration, and exit status after every
ordinary zero or nonzero exit. Each dogfood install also atomically replaces a
private `dogfood-build.receipt` containing its install epoch, optimization mode,
both binary hashes, the staged Layer Shell hash, and cached Plasma/KWin
versions so later GUI launches do not execute both desktop binaries just to
build their fingerprint; local crash counts can
therefore distinguish retained historical dumps from dumps created after the
current install. If the launcher or machine is killed, the running receipt
remains visibly incomplete and is never counted as elapsed
acceptance evidence. Duration uses `/proc/uptime` while the boot ID matches and
falls back to bounded nonnegative wall-clock subtraction only when necessary.

Follow current process logs and inspect retained runtime:

```sh
tail -F ~/.local/state/noctty/logs/*.log
./scripts/dogfood_runtime_status.sh
./scripts/dogfood_runtime_status.sh --list-candidates
./scripts/dogfood_status.sh
./scripts/local_diagnostic_report.sh
NOCTTY_DEDICATED_DISPLAY=1 ./scripts/local_interaction_spike_report.sh --quick
./scripts/plasma_wayland_health.sh
NOCTTY_DEDICATED_DISPLAY=1 ./scripts/plasma_wayland_post_upgrade.sh --full
```

`local_interaction_spike_report.sh` exercises ReleaseSafe Wayland pane splits,
pane close, tab open/close, and editor open/save/search/restore paths. Full mode
also runs 16-session layout churn. It stores private bounded elapsed-time and
root/process-tree PSS/RSS receipts, compares each run with the previous run in
the same mode, and flags latency only above both 3× and +1 second or tree RSS
above both 1.5× and +64 MiB. These intentionally generous thresholds avoid
calling ordinary scheduler noise a regression.

`local_diagnostic_report.sh` produces a pasteable local receipt and retained
coredump-count summary for correlating failures with the installed binary and
Plasma/Wayland stack. It reports bounded GTK, GDK, GLib, GObject, native-grid,
and Zig-panic categories, distinguishes all sessions for the current binary
from sessions after the current install epoch, and emits at most 20 recent
binary/kernel/Plasma/KWin cohorts plus the five newest interaction receipts for
before/after upgrade comparison; it does not include log text.
`plasma_wayland_health.sh` checks the current Wayland socket, Plasma services,
KDE portal, accessibility bus, staged Layer Shell
runtime, installed dogfood binaries, and locally known package upgrades. Both
are read-only: they never refresh package databases, read terminal output,
upload anything, contact the network, or change local state. The post-upgrade
command additionally builds local test artifacts, runs the current
`ReleaseSafe` Wayland maintenance and fresh-process NoctEd restore lanes, and
writes clean `--version` receipts through the exact installed launchers. It
fails closed if installed runtime integrity is lost, if a NOCTTY/NoctEd
product or qualification-smoke coredump appeared after that install, or if
current-install receipts contain a failure, incomplete run, categorized
critical marker, or interaction spike. Review output before sharing it with a
maintainer.

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

No logs or receipts are uploaded. Reports also group finished, failed,
incomplete, and warning-bearing sessions by installed binary hash and desktop
stack, so behavior can be compared across upgrades without identifying a user
or sending data anywhere. Logging is local only and adds no telemetry or network
behavior.

When **Open NoctEd Here** starts NoctEd, the sibling installed launcher is used,
so that editor process receives its own log and duration receipt.
