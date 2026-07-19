# Native launch profiles

Last refreshed: 2026-07-18.

NOCTTY has a GUI-managed launch-profile library for new terminal sessions. It is fixed-capacity native Zig product state persisted through the versioned binary settings file; users do not edit TOML or JSON. Running sessions are never restarted when the active profile changes.

## Settings workflow

Open **Settings → Behavior → Launch profiles**. Choose a saved profile or the custom current entry, edit its fields, set the new-session scrollback limit, and then:

- **Apply to new sessions** validates the form as an unnamed custom current profile.
- **Save named profile** adds or replaces a name and selects that profile for new sessions.
- **Delete selected profile** removes the saved name while deliberately leaving its current launch values active as an unnamed custom profile.

The library holds at most eight profiles. Names are valid UTF-8 of 1–64 bytes, trimmed, single-line, and unique without regard to ASCII case. All mutations validate a complete copied library before replacing live state, so an invalid name or field, a ninth entry, or a partial form never mutates the prior profile/library.

The current launch types are:

- **Shell** starts the configured absolute shell path interactively. A blank shell field inherits the process `SHELL`, falling back to `/bin/sh`.
- **Command** runs one configured command line through the selected shell with `-lc` and exits when that command exits.
- **SSH** starts the system `ssh` client with one validated `[user@]host`-style target. NOCTTY does not store passwords, keys, agent tokens, or remote credentials.
- **Persistent tmux** directly runs `tmux new-session -A -s SESSION` with a required conservative session name.
- **Persistent Zellij** directly runs `zellij attach --create SESSION` with the same required session-name grammar.

The working-directory field must be blank or absolute. Blank inherits the source pane directory; a configured directory becomes the stored cwd of a newly created pane. Environment overrides use `NAME=value;SECOND=value`, allow at most 16 unique valid names inside a 2048-byte bound, and are applied before launch. NOCTTY still advertises its tested `TERM=xterm-256color` and `COLORTERM=truecolor` capability values. The profile scrollback limit is independently bounded from 0 through 100000 lines.

Fresh workspaces and newly created tabs/splits use the active launch profile, whether custom or selected from the library. Hot-session reconstruction intentionally restarts each saved pane in its saved directory instead, preserving the recovery snapshot rather than replacing it with a later profile cwd or command. This is layout and cwd recovery, not live-process resurrection.

## Persistence and safety

Settings snapshot version 7 added the bounded named library and selected-profile identity after the version-6 active launch fields. Version 8 retained that state and appended the bounded recent-workspace MRU described in [WORKSPACE_ACTIVATION.md](WORKSPACE_ACTIVATION.md). Version 9 preserves that byte layout and admits the tmux/Zellij launch kinds. Versions 1–8 remain importable; a snapshot labeled version 8 or earlier rejects the new kind values. Invalid names, duplicate names, paths, control characters, duplicate environment keys, option-shaped SSH targets, invalid or option-shaped session names, excessive lengths, excessive library size, invalid selection indices, and out-of-range scrollback values are rejected before state mutation.

The PTY boundary accepts a validated launch kind and bounded strings. Shell mode uses an interactive shell, command mode uses the explicitly selected shell command path, SSH mode invokes the system `ssh` program with one direct target argument, and continuity modes invoke tmux/Zellij with fixed direct argument vectors. No browser runtime, network service, credential manager, telemetry, or remote feature flag was added.

## Verification boundary

Zig unit tests cover profile/library validation and atomic mutations, version-9 continuity round trips and version-kind admission, version-8 recent-workspace migration, version-7 recent-list migration, version-6 launch-profile migration, version-1 through version-5 defaults, and a real PTY command launch that proves cwd, environment, exit status, and per-profile history. The rendered Settings lane drives the actual GTK controls, applies a custom profile, saves two names, deletes one, reselects the survivor, reloads settings, and then starts a fresh PTY from that selected profile. It requires:

```text
launch_profile=true launch_kind=command launch_shell=/bin/sh launch_cwd=/tmp launch_env=2 launch_scrollback=2048 launch_atomic=true launch_persisted=true launch_runtime=true launch_library=true launch_profiles=1 launch_named=true launch_saved=true launch_selected=true launch_deleted=true launch_continuity_controls=true launch_tmux=true launch_zellij=true
```

`scripts/native_grid_credentialed_ssh_smoke.sh` separately retains the credentialed SSH case through the same validated profile and product PTY. It creates disposable Ed25519 client/host keys, pins the host key, uses the host's real OpenSSH client and server, authenticates public-key credentials, executes a remote-shell marker, observes exit, and trap-cleans the isolated identity material:

```text
native_grid_credentialed_ssh_smoke profile=true system_client=true system_server=true credential=publickey identity_isolated=true host_key=pinned transport=stdio_proxy network_bind=false remote_marker=true exited=true
```

The smoke-only `ssh` shim supplies isolated client options and starts `sshd` in inetd/stdin-stdout mode because the managed test environment cannot bind a listening socket. It never enters the production binary or user configuration. The receipt proves local OpenSSH public-key credential handling through NOCTTY (`credentialed_ssh=true`); it does not prove remote-network reachability, passwords, an agent or hardware key, arbitrary SSH configuration, or survival of a live process across a NOCTTY crash.

`scripts/launch_continuity_qualification.sh` separately validates both continuity profiles in Debug and `ReleaseSafe` through exact-argv smoke-only executables and the production PTY/VT path:

```text
launch_continuity_matrix debug=true release_safe=true kinds=tmux,zellij direct_argv=true create_or_attach=true production_pty=true cwd=true environment=true controlled_exit=true allocator_leak_free=true tool_shims=true installed_tools=false live_reattach=false scratch_clean=true
```

See [SESSION_CONTINUITY.md](SESSION_CONTINUITY.md) for the exact proof boundary. The current host lacks installed tmux/Zellij, so this receipt does not prove session-server survival, cross-process reattachment, or rendered Plasma behavior.

Installed activation is now separately covered by `scripts/native_grid_installed_activation_smoke.sh`: the headless contract validates the production desktop/MIME install and exact `%u` route, while full mode must retain mapped two-tab child receipts for both the installed `gio` dispatch and the native Recent Workspaces button on accessible Plasma Wayland/X11. The contract passes here; compositor access is unavailable, so the full activation receipts and live-process continuity boundary remain in NCT-111.
