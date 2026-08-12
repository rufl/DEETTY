# Session continuity profiles

Last refreshed: 2026-08-03.

NOCTTY exposes **Persistent tmux** and **Persistent Zellij** as first-class native launch-profile types. They use the same GUI-owned named-profile library, absolute/inherited working directory, bounded environment overrides, and new-session scrollback controls as shell, command, and SSH profiles. Users do not edit a configuration file.

The target field is a required 1–64 byte session name from the conservative shared subset `A-Z`, `a-z`, `0-9`, `.`, `_`, and `-`; a leading `-` is rejected. The PTY adapter dispatches fixed argument vectors directly:

- tmux: `tmux new-session -A -s SESSION`
- Zellij: `zellij attach --create SESSION`

No shell command is assembled from the session name. tmux and Zellij remain optional system tools rather than bundled dependencies, and their process/session state stays behind the PTY launch adapter rather than entering workspace, editor, theme, or Ghostty state.

Settings snapshot version 9 admits the two new launch kinds while retaining the version-8 byte layout and recent-workspace MRU. Versions 1–8 remain importable; a snapshot labeled as an older version cannot smuggle a new kind into the decoder.

## Verification boundary

Run:

```sh
./scripts/launch_continuity_qualification.sh
```

The self-cleaning qualification builds Debug and `ReleaseSafe`, puts exact-argv smoke-only `tmux` and `zellij` executables on a disposable `PATH`, and starts both profiles through the production `LaunchProfile` → `TerminalSession` → Zig PTY path. Each executable rejects an incorrect argument count/order, cwd, or environment; the runner requires its marker through the real PTY/VT grid, a zero exit, bounded history, and zero allocator residue.

```text
launch_continuity_matrix debug=true release_safe=true kinds=tmux,zellij direct_argv=true create_or_attach=true production_pty=true cwd=true environment=true controlled_exit=true allocator_leak_free=true tool_shims=true installed_tools=false live_reattach=false scratch_clean=true
```

This proves native configuration semantics, settings persistence/migration, exact direct dispatch, and the production PTY boundary. The separate installed-activation matrix proves mapped desktop/MIME and Recent Workspaces child launch. The later [installed continuity qualification](INSTALLED_CONTINUITY_QUALIFICATION.md) closes NCT-111 on this host with tmux 3.7b and Zellij 0.44.3 first attach, native detach, NOCTTY process exit/relaunch, reattach, preserved rendered content, and controlled cleanup in every Debug/`ReleaseSafe` Wayland/X11 lane. It does not prove arbitrary-process resurrection, remote transports, multi-day survival, or cross-host portability.
