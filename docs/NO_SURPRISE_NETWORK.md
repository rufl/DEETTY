# No Surprise Network Check

NOCTTY's public alpha promise includes no telemetry, analytics, update pings,
crash uploaders, remote feature flags, or hidden network clients.

Maintained local check:

```sh
./scripts/check_no_surprise_network.sh
```

Current retained result, 2026-08-13:

```text
no_surprise_network_check telemetry=false update_pings=false crash_uploaders=false remote_flags=false hidden_network_api=false sharing_network_api=explicit proof_boundary=static_source_scan
```

Proof boundary: this is a deterministic source/build-resource scan. It is not a
firewall, sandbox, dependency legal review, or runtime packet capture.

Allowed explicit network-adjacent behavior remains user-owned and documented:

- terminal users may run network programs inside their shell
- SSH launch profiles invoke the system `ssh` client only when the user selects
  an SSH profile
- qualification fixtures may use isolated local test transports where their
  docs say so
- the opt-in authenticated-agent qualification invokes the already-installed, already-authenticated Codex CLI for an explicit ephemeral model request; it is not part of production startup, default verification, or installed runtime behavior
- paired session sharing opens its documented TCP listener/client only after the
  user explicitly starts pairing, sharing, or receiving; authenticated
  keepalives and bounded resynchronization traffic remain on that connection
- pairing listeners emit bounded IPv4 LAN multicast/broadcast announcements
  only while that explicit listener is active; discovery receives them only
  while the user explicitly requests it
- announcements contain no identity key, terminal content, pane lifecycle,
  keepalive, or control data, and direct endpoints remain required where routed
  VPNs do not carry LAN discovery
