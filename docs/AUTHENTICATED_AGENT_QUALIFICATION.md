# Launcher agent qualification

Status: maintained opt-in lane. A historical Codex receipt remains under
`benchmarks/authenticated-agent-2026-08-04/`; the current runner is
launcher-neutral.

## Scope

`scripts/native_grid_authenticated_agent_qualification.sh` builds isolated
Debug and `ReleaseSafe` smoke binaries and runs one Pi, OMP, or ZIPI launcher
request in each live Plasma Wayland/X11 lane. Select the launcher with
`DINTTY_AGENT_QUALIFICATION_LAUNCHER`; the default is `pi`. The command uses
the production command launch profile, PTY, `TerminalSession`, VT grid, GTK
host, and Cairo renderer.

Each request is ephemeral, read-only, rooted at `/tmp`, disables agent tools,
and requests the exact response `DINTTY_AGENT_QUALIFICATION_OK`. Pi and OMP
own any external-provider authentication; ZIPI is local-only. DINTTY stores no
credentials or bearer tokens.

## Current output

The runner retains one response, log, screenshot, memory sample, and controlled
launcher exit per Debug/`ReleaseSafe` Wayland/X11 lane. It emits:

```text
native_grid_agent_matrix launcher=pi model_requests=4 debug=true release_safe=true wayland=true x11=true production_pty=true production_vt=true production_gtk=true production_cairo=true response_exact=true compositor_pixels=true root_memory=true process_tree_memory=true controlled_exit=true ephemeral=true sandbox=read-only hid=false checksums=true artifact_dir=... scratch_clean=true
```

The historical Codex receipt is not evidence of Pi, OMP, or ZIPI behavior.
New runs must be evaluated against the selected launcher and its own
configuration.

## Boundary

This lane proves only DINTTY's launcher-to-PTY/VT/GTK/Cairo boundary and exact
response handling. It does not prove external-provider behavior, ZIPI model
quality, physical input, universal terminal compatibility, or multi-day
stability. KWin activation and Spectacle capture are compositor automation,
not HID evidence.
