# Session continuity profiles

Last refreshed: 2026-07-18.

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

The self-cleaning qualification builds Debug and `ReleaseSafe`, puts exact-argv smoke-only `tmux` and `zellij` executables on a disposable `PATH`, and starts both profiles through the production `LaunchProfile` → `TerminalSession` → C PTY adapter. Each executable rejects an incorrect argument count/order, cwd, or environment; the runner requires its marker through the real PTY/VT grid, a zero exit, bounded history, and zero allocator residue.

```text
launch_continuity_matrix debug=true release_safe=true kinds=tmux,zellij direct_argv=true create_or_attach=true production_pty=true cwd=true environment=true controlled_exit=true allocator_leak_free=true tool_shims=true installed_tools=false live_reattach=false scratch_clean=true
```

This proves native configuration semantics, settings persistence/migration, exact direct dispatch, and the production PTY boundary. It does not prove that an installed tmux or Zellij server survives a NOCTTY close/crash, that a later NOCTTY process reattaches to its live session, or that the flow renders correctly on Plasma Wayland/X11. NCT-111 remains open for those installed-tool and compositor receipts.
