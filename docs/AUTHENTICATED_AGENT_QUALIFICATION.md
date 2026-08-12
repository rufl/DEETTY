# Authenticated agent qualification

Status: passed on 2026-08-04 for installed Codex CLI 0.144.6 on this Plasma host.

## Scope

`scripts/native_grid_authenticated_agent_qualification.sh` builds isolated Debug and `ReleaseSafe` smoke binaries and runs one authenticated Codex model request in each live Plasma Wayland/X11 lane. The command uses the production command launch profile, PTY, `TerminalSession`, VT grid, GTK host, and Cairo renderer.

Each request is ephemeral, read-only, rooted at `/tmp`, and instructed not to run commands or inspect files. Codex must return the exact 29-byte response `NOCTTY_AUTHENTICATED_CODEX_OK`. The response is checked from Codex's output file while the same rendered result remains mapped for a compositor screenshot. No credential or bearer token is copied into the archive.

## Retained result

The four lanes passed:

- Debug Wayland
- Debug X11
- `ReleaseSafe` Wayland
- `ReleaseSafe` X11

Every lane retained an exact response file, process log, compositor screenshot, root/process-tree memory sample, and controlled zero exit. The stable receipt is:

```text
native_grid_authenticated_agent_matrix provider=codex version=0.144.6 authenticated=true model_requests=4 debug=true release_safe=true wayland=true x11=true production_pty=true production_vt=true production_gtk=true production_cairo=true response_exact=true compositor_pixels=true root_memory=true process_tree_memory=true controlled_exit=true ephemeral=true sandbox=read-only hid=false checksums=true scratch_clean=true
```

Evidence is checksummed under `benchmarks/authenticated-agent-2026-08-04/`.

## Boundary

This closes NCT-110's accepted one-host authenticated-agent boundary for Codex. It does not prove Claude Code, Antigravity, every Codex model/configuration, physical input, universal terminal compatibility, or multi-day stability. KWin activation and Spectacle capture are compositor automation, not HID evidence.
