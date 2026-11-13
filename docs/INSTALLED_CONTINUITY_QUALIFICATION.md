# Installed tmux and Zellij continuity qualification

Status: passed on 2026-08-04 for tmux 3.7b and Zellij 0.44.3 on this Plasma host.

## Scope

`scripts/native_grid_installed_continuity_qualification.sh` builds isolated Debug and `ReleaseSafe` smoke binaries and exercises the product's native **Persistent tmux** and **Persistent Zellij** launch profiles on live Plasma Wayland and X11.

For each tool, build mode, and backend, the lane:

1. starts a fresh DINTTY process through the production create-or-attach argv;
2. writes and renders a tool-specific marker in the live session;
3. retains a compositor screenshot;
4. routes the tool's detach chord through DINTTY's production PTY write path;
5. waits for the first DINTTY process to exit while the multiplexer session remains;
6. launches a second DINTTY process with the same profile and session name;
7. requires the prior marker to remain visible;
8. retains the reattached screenshot, detaches cleanly, and removes the disposable session.

The matrix contains 16 mapped screenshots and 16 controlled process logs. Zellij uses an isolated generated configuration with startup tips and release notes disabled so qualification reaches the terminal pane without mutating the user's configuration.

## Retained result

```text
native_grid_installed_continuity_matrix tmux_version=3.7b zellij_version=0.44.3 debug=true release_safe=true wayland=true x11=true first_attach=true detached=true dintty_relaunch=true reattach=true content_preserved=true production_pty=true production_vt=true production_gtk=true production_cairo=true compositor_pixels=true controlled_exit=true hid=false checksums=true scratch_clean=true
```

Evidence is checksummed under `benchmarks/installed-continuity-2026-08-04/`.

## Boundary

This closes NCT-111's installed one-host detach/relaunch/reattach boundary. The two binaries were installed under the user's local prefix from signature-verified Arch packages; they are not DINTTY runtime dependencies. The synthetic detach chord and compositor activation are not physical-input proof, and the matrix does not establish multi-day survival, remote tmux/Zellij transports, or cross-host portability.
