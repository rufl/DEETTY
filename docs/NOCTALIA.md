# Noctalia Shell Support

Last verified: 2026-07-31.

## Scope

NOCTTY supports Noctalia Shell as a first-class Wayland target alongside KDE Plasma. Noctalia describes itself as a desktop shell rather than a compositor or full desktop environment, so the integration follows its ownership boundary: Noctalia supplies bars, panels, notifications, launchers, and theming, while Niri, Hyprland, Sway, Scroll, Labwc, or MangoWC owns global keybindings and window policy.

Both Noctalia generations are usable. The current v5 native shell and the Quickshell-based v4 shell share the same application-side contract because the compositor launches `noctty --toggle`; NOCTTY does not depend on either shell's private or changing plugin ABI.

Official references:

- [Noctalia overview and supported compositors](https://github.com/noctalia-dev/noctalia-shell)
- [Noctalia v5 IPC and compositor-owned keybinds](https://docs.noctalia.dev/v5/ipc/)
- [Noctalia v5 compositor settings](https://docs.noctalia.dev/v5/compositor-settings/niri/)
- [Noctalia v5 application theming](https://docs.noctalia.dev/v5/theming/app-theming/)

## Runtime Contract

The native grid host owns the session-bus name `com.noctty.NOCTTY` and exports `Toggle`, `Show`, `Hide`, and `GetState` at `/com/noctty/NOCTTY`. The matching native commands are:

```sh
noctty --status
noctty --show
noctty --hide
noctty --toggle
```

`noctty --toggle` shows a running instance or starts a visible instance when none exists. Compositor autostart uses `noctty --hidden`, which hides only after the D-Bus endpoint is ready. A normal launcher invocation remains visible, preventing an unconfigured first run from becoming unreachable.

Dropdown mode uses `gtk-layer-shell` with the namespace `noctty-dropdown`, overlay layer, top/left/right anchors, no exclusive zone, exclusive keyboard focus while mapped, and symmetric width margins recomputed whenever the configured percentage or pixel width changes. Automatic Plasma shortcut startup keeps that exclusive surface hidden until the user shows it instead of briefly mapping it while KGlobalAccel registration is pending. Distribution packages provide the runtime; dependency bundles and dogfood installs stage the pinned private copy when needed. `noctty-window` and `noctty-zen` namespaces cover live mode changes from that surface. Ordinary windowed and zen launches remain native toplevel/fullscreen windows.

Clipboard, drag/drop, file dialogs, HiDPI, IME, and desktop notifications use GTK and freedesktop protocols rather than KDE-only APIs. Noctalia's notification daemon can therefore receive NOCTTY completion notifications through `org.freedesktop.Notifications`.

## Shortcut Setup

Noctalia's documentation intentionally keeps global shortcuts in the compositor configuration. The default binding is F10 and always executes:

```sh
noctty --toggle
```

The native Settings dialog records the supported shortcut model. Plasma re-registers a successful capture immediately; on a Noctalia-compatible session, the same recorder persists the key and updates the generated compositor plan. Print the current persisted binding and autostart command with:

```sh
noctty --noctalia-plan niri
noctty --noctalia-plan hyprland
noctty --noctalia-plan sway
noctty --noctalia-plan scroll
noctty --noctalia-plan labwc
noctty --noctalia-plan mango
```

Ready-to-merge F10 fragments are installed under `share/noctty/noctalia/`:

- `niri.kdl`
- `hyprland.lua` for current v5 guidance and `hyprland.conf` for v4/traditional configurations
- `sway.conf`
- `scroll.conf`
- `labwc-rc.xml` and `labwc-autostart`
- `mango.conf`

An optional compact Noctalia v5 `custom_button` fragment is provided as `noctalia-v5-widget.toml`. It invokes the same stable command and does not require a NOCTTY plugin or background service.

## Detection

The Zig backend detects the supported compositor family from standard session names and native IPC markers such as `NIRI_SOCKET`, `HYPRLAND_INSTANCE_SIGNATURE`, and `SWAYSOCK`. Explicit `NOCTTY_DESKTOP_SHELL=noctalia` and `NOCTTY_COMPOSITOR=<name>` overrides support unusual launch environments without changing persistence files.

Detected Noctalia sessions receive:

- the `noctalia_wayland` backend and exact compositor identity;
- layer-shell dropdown placement;
- compositor-owned shortcut transport;
- D-Bus external activation;
- freedesktop notifications;
- Wayland clipboard, drag/drop, native dialogs, and HiDPI.

## Verification Boundary

`scripts/noctalia_integration_smoke.sh` verifies v4-compatible/v5 plans, all six compositor serializers, environment detection, installed artifacts, external-activation and notification capability routing, and the recorded-shortcut model.

`scripts/native_grid_noctalia_ipc_smoke.sh` is the live Wayland gate. It proves the layer-shell namespace, hidden-ready startup, D-Bus status/show/hide/toggle transitions, single-instance routing, and clean terminal exit. The rendered Settings gate separately proves shortcut capture, persistence, and fresh-process reload.

The current machine runs Plasma Wayland, so this proves the shared Wayland layer-shell, D-Bus, GTK, and freedesktop protocols live. The generated Niri/Hyprland/Sway/Scroll/Labwc/Mango syntax is source-checked against each documented contract; final release acceptance on each compositor still requires that compositor to be present. NOCTTY does not mislabel the current Plasma run as six separate compositor sessions.
