# No Surprise Network Check

NOCTTY's public alpha promise includes no telemetry, analytics, update pings,
crash uploaders, remote feature flags, or hidden network clients.

Maintained local check:

```sh
./scripts/check_no_surprise_network.sh
```

Current retained result, 2026-07-19:

```text
no_surprise_network_check telemetry=false update_pings=false crash_uploaders=false remote_flags=false hidden_network_api=false proof_boundary=static_source_scan
```

Proof boundary: this is a deterministic source/build-resource scan. It is not a
firewall, sandbox, dependency legal review, or runtime packet capture.

Allowed explicit network-adjacent behavior remains user-owned and documented:

- terminal users may run network programs inside their shell
- SSH launch profiles invoke the system `ssh` client only when the user selects
  an SSH profile
- qualification fixtures may use isolated local test transports where their
  docs say so
