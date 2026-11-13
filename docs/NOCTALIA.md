# Noctalia Shell Support

Last verified: 2026-07-31.

## Scope

DINTTY supports Noctalia Shell as a first-class Wayland target alongside KDE Plasma. Noctalia describes itself as a desktop shell rather than a compositor or full desktop environment, so the integration follows its ownership boundary: Noctalia supplies bars, panels, notifications, launchers, and theming, while Niri, Hyprland, Sway, Scroll, Labwc, or MangoWC owns global keybindings and window policy.

Both Noctalia generations are usable. The current v5 native shell and the Quickshell-based v4 shell share the same application-side contract because the compositor launches `dintty --toggle`; DINTTY does not depend on either shell's private or changing plugin ABI.

Official references:

- [Noctalia overview and supported compositors](https://github.com/noctalia-dev/noctalia-shell)
- [Noctalia v5 IPC and compositor-owned keybinds](https://docs.noctalia.dev/v5/ipc/)
- [Noctalia v5 compositor settings](https://docs.noctalia.dev/v5/compositor-settings/niri/)
- [Noctalia v5 application theming](https://docs.noctalia.dev/v5/theming/app-theming/)

## Runtime Contract

The primary native grid host takes a per-user lock before loading mutable state, owns the session-bus name `com.dintty.DINTTY`, and exports `Toggle`, `Show`, `Hide`, `GetState`, plus bounded one-use activation-token variants at `/com/dintty/DINTTY`. The matching native commands are:

```sh
dintty --status
dintty --show
dintty --hide
dintty --toggle
```

`dintty --toggle` shows a running instance or starts a visible instance when none exists. Compositor autostart uses `dintty --hidden`, which hides only after the D-Bus endpoint is ready. A normal launcher invocation remains visible, preventing an unconfigured first run from becoming unreachable.

In Noctalia sessions, dropdown mode uses a dependency-free GTK Wayland toplevel. DINTTY exposes the stable `com.dintty.DINTTY` app ID and a `DINTTY Dropdown — …` title prefix so compositor rules can distinguish dropdown surfaces from windowed and zen modes. It deliberately does not load GTK Layer Shell. This avoids requiring `libgtk-layer-shell.so.0` while retaining D-Bus activation, compositor-owned shortcuts, focus-loss hiding, bounded dimensions, and native mode transitions. The managed Niri window rule sets `draw-border-with-background false`; otherwise Niri's focused-window ring uses an opaque backing rectangle that masks terminal translucency until a dialog takes focus. Plasma retains the layer-shell path for exact client-owned top-edge placement.

Clipboard, drag/drop, file dialogs, HiDPI, IME, and desktop notifications use GTK and freedesktop protocols rather than KDE-only APIs. Noctalia's notification daemon can therefore receive DINTTY completion notifications through `org.freedesktop.Notifications`.

## Shortcut Setup

Noctalia's documentation intentionally keeps global shortcuts in the compositor configuration. The default binding is F10 and always executes:

```sh
dintty --toggle
```

The native Settings dialog records the supported shortcut model. Plasma re-registers a successful capture immediately; on a Noctalia-compatible session, the same recorder persists the key and updates the generated compositor plan. Print the current persisted binding and autostart command with:

```sh
dintty --noctalia-plan niri
dintty --noctalia-plan hyprland
dintty --noctalia-plan sway
dintty --noctalia-plan scroll
dintty --noctalia-plan labwc
dintty --noctalia-plan mango
```

Ready-to-merge F10 fragments are installed under `share/dintty/noctalia/`:

- `niri.kdl`, including F10/autostart plus the required floating top-edge window rule for dependency-free dropdowns
- `hyprland.lua` for current v5 guidance and `hyprland.conf` for v4/traditional configurations
- `sway.conf`
- `scroll.conf`
- `labwc-rc.xml` and `labwc-autostart`
- `mango.conf`

An optional compact Noctalia v5 `custom_button` fragment is provided as `noctalia-v5-widget.toml`. It uses Noctalia's `[widget.dintty.actions]` table with `exec dintty --toggle` for left-click and `exec dintty --show` for right-click. It does not require a DINTTY plugin or background service.

## Detection

The Zig backend detects the supported compositor family from standard session names and native IPC markers such as `NIRI_SOCKET`, `HYPRLAND_INSTANCE_SIGNATURE`, and `SWAYSOCK`. Explicit `DINTTY_DESKTOP_SHELL=noctalia` and `DINTTY_COMPOSITOR=<name>` overrides support unusual launch environments without changing persistence files.

Detected Noctalia sessions receive:

- Theme Library discovery of installed `colorschemes/*/*.json` files with explicit Dark/Light selection;
- a dependency-free Wayland toplevel dropdown;
- compositor-owned shortcut transport;
- D-Bus external activation;
- freedesktop notifications;
- Wayland clipboard, drag/drop, native dialogs, and HiDPI.

## Verification Boundary

`scripts/noctalia_integration_smoke.sh` verifies v4-compatible/v5 plans, all six compositor serializers, environment detection, installed artifacts, external-activation and notification capability routing, and the recorded-shortcut model.

`scripts/native_grid_noctalia_ipc_smoke.sh` is the live Wayland gate for D-Bus status/show/hide/toggle transitions, single-instance routing, dependency-free toplevel fallback, and clean terminal exit. The rendered Settings gate separately proves shortcut capture, persistence, and fresh-process reload.

The current machine runs Plasma Wayland, so the live Plasma gate proves the layer-shell, D-Bus, GTK, and freedesktop protocols. Noctalia's dependency-free toplevel fallback is covered by the isolated Wayland gate and the backend plan. The generated Niri/Hyprland/Sway/Scroll/Labwc/Mango syntax is source-checked against each documented contract; final release acceptance on each compositor still requires that compositor to be present.
