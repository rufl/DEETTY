# Security Policy

NOCTTY is pre-public Linux alpha. Security handling is intentionally simple and
local-first until public project infrastructure exists.

## Supported versions

No public stable version is supported yet. The current source tree is alpha
work-in-progress.

## Reporting a vulnerability

Until Lichforge public security channels are created, report privately to the
maintainer through the private contact channel used for the repository. Do not
open a public issue for vulnerabilities involving:

- command execution
- terminal escape handling that can read/write outside expected bounds
- unsafe URI/workspace activation
- local file overwrite/data loss
- credential exposure
- unexpected network behavior
- dependency-bundle or packaging trust issues

Once the GitHub organization is public, this file should be updated with a real
security contact or GitHub private vulnerability reporting instructions.

## Security boundaries

NOCTTY should maintain these boundaries:

- no telemetry, analytics, update pings, crash uploaders, or remote feature flags
- no surprise network activity
- workspace URI activation must validate paths before creating PTYs
- terminal escape handling must keep bounded parser/string/reply limits
- OSC 52 clipboard behavior remains blocked unless a future explicit user-owned
  policy changes it
- launch profiles must avoid shell-string construction for structured actions
- PTY children must reject relative launch paths and close inherited descriptors before exec
- runtime shared libraries must not load from current-directory or caller-selected override paths; dependency-bundle and dogfood launchers may expose only their own trusted private runtime directory
- release temporary files and retained evidence must use private staging plus atomic replacement
- settings/session files must recover safely from malformed or oversized data;
  NoctEd dirty-buffer snapshots and encrypted `.nocttyhs` history exports use
  atomic private (`0600`) storage
- agent resume references are opaque, bounded, provider-limited, and never
  inferred from terminal output; restore actions require explicit user choice
- dependency bundles must keep ownership/license payload checks fail-closed

## Out of scope for alpha

The alpha source tree does not yet claim:

- hardened sandboxing against a malicious local shell command
- secure remote-terminal product features
- formal audit
- signed release artifact trust
- universal terminal escape security
- provider-owned agent resume correctness beyond validated Claude Code/Codex
  command construction

Treat NOCTTY as a local developer tool and run untrusted commands with the same
care you would use in any terminal emulator.

The retained repository-owned static network/privacy gate is:

```sh
./scripts/check_no_surprise_network.sh
```

No repository Semgrep configuration is currently maintained. A future SAST
configuration must be checked in and reviewed before its results are treated as
release evidence; downloading an unpinned remote ruleset is not an equivalent
gate.
