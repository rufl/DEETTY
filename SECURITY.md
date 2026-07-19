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
- settings/session files must recover safely from malformed or oversized data
- dependency bundles must keep ownership/license payload checks fail-closed

## Out of scope for alpha

The alpha source tree does not yet claim:

- hardened sandboxing against a malicious local shell command
- secure remote-terminal product features
- formal audit
- signed release artifact trust
- universal terminal escape security

Treat NOCTTY as a local developer tool and run untrusted commands with the same
care you would use in any terminal emulator.
