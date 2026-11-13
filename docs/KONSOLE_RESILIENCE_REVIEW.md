# Konsole Resilience Review

Date: 2026-08-22.

## Purpose

This review answers a narrow question: what lets Konsole feel dependable as a
Plasma terminal, and what should transfer to DINTTY without importing Qt/KDE
Frameworks, a browser runtime, telemetry, or a larger editor product.

The source comparison used Konsole commit `a626e1b` from
`https://invent.kde.org/utilities/konsole.git`, plus the locally installed
Konsole 26.08.0 desktop metadata. Findings are implementation evidence, not a
claim that DINTTY must copy Konsole's architecture.

## What makes Konsole resilient on Plasma

| Concern | Konsole mechanism | DINTTY consequence |
| --- | --- | --- |
| Repeated launches | `KDBusService::Unique` forwards compatible launches to the existing process; explicit incompatible flags create a separate process. `src/main.cpp` | A terminal must never create an accidental second hidden/dropdown owner during a launch race. Preserve DINTTY's explicit separate-workspace policy where it protects active PTYs. |
| Wayland foreground activation | A child Konsole can obtain an `XDG_ACTIVATION_TOKEN` from its parent session, and `MainWindow::activationRequest` applies it before presenting. `src/main.cpp`, `src/MainWindow.cpp` | Showing an existing DINTTY window needs a real, protocol-correct activation path; it must not rely on X11 focus assumptions. |
| Plasma session restore | KDE session management saves session/profile state and recursive view topology; restore creates fresh sessions and reconnects the view tree. `MainWindow.cpp`, `ViewManager.cpp`, `SessionManager.cpp` | DINTTY already has the safer equivalent for its product: atomically restore layout/cwd/profile state while being explicit that ordinary shell processes restart. |
| Process lifecycle | Session, PTY, emulation, and views have explicit teardown ordering; the last detached view closes its session. `src/session/Session.cpp` | Keep DINTTY's owned PTY/session teardown and late-callback guards. Do not weaken them for desktop integration. |
| Bad launch configuration | Konsole checks the configured executable, falls back through shell candidates, and prints an in-terminal warning instead of leaving a blank window. `src/session/Session.cpp` | A broken launch profile should retain the workspace and offer a GUI-visible safe-shell fallback, never strand a user at startup. |
| Desktop discoverability | Its desktop entry has stable identity, startup metadata, searchable terminal keywords, and New Window/New Tab actions. Global shortcuts use Plasma GlobalAccel. | DINTTY needs equally complete desktop integration, but its desktop actions must map to its own workspace semantics rather than pretending tabs and windows are interchangeable. |
| Automation surface | Stable session-bus objects expose window/session operations; this makes tooling and KDE integration inspectable. `src/ViewManager.cpp`, `src/session/Session.cpp` | Keep DINTTY's control D-Bus API narrow and local. Stabilize it only after concurrency and activation semantics are proven. |

## Current DINTTY strengths

DINTTY already has more of this foundation than a feature checklist suggests:

- `com.dintty.DINTTY` exports local `GetState`, `Show`, `Hide`, and `Toggle`;
  `--hidden` waits for control registration before hiding.
- Plasma GlobalAccel has availability checking, a visible fallback when
  registration fails, and teardown. Noctalia uses the same explicit
  `dintty --toggle` contract rather than a private shell API.
- The StatusNotifier item re-registers when its watcher restarts and works on
  Wayland and X11.
- Settings, workspace snapshots, and recovery writes use versioned bounded
  formats and atomic replacement. Workspace snapshots intentionally restart
  shells while tmux/Zellij retain the live-process continuity option.
- The native host has bounded PTY queues, centralized source teardown,
  foreground-job close confirmation, and retained Wayland/X11 proof lanes.
- Desktop URI activation validates local, absolute `.dinttyws` paths before
  workspace state is replaced.

These are the correct DINTTY primitives. Replacing them with KDE framework
objects would broaden the runtime and blur the Zig/native boundaries without
solving a demonstrated problem.

## Resilience tranche status

### P0 — damaged local state no longer blocks a terminal — implemented

Settings and theme-library writes now retain one atomically replaced,
parse-validated `.bak`. A malformed primary loads that backup when possible or
keeps the app's safe built-ins. The malformed file is not overwritten during
fallback; if a later GUI save replaces it, its prior bytes are retained once as
`.rejected`. Invalid hot-workspace bytes are likewise retained before the clean
workspace snapshot replaces them. If the `.rejected` destination itself is
unusable, startup still opens a terminal but disables that run's primary
autosave so the only malformed original cannot be overwritten.

The native host presents one keyboard-accessible warning bar naming the
recovered resources, with **Open Settings** and **Dismiss** actions. No manual
configuration edit is required.

Proof:

- storage tests cover validated backup rotation, malformed-primary rejection,
  exact rejected-byte retention, and atomic replacement;
- `scripts/native_grid_state_recovery_smoke.sh` launches with all three primary
  files damaged and requires a usable visible terminal, one recovery notice,
  safe defaults, exact malformed workspace retention, preservation when the
  rejection rename is blocked, and bounded cleanup.

### P0 — one primary owner under concurrent launch — implemented

A per-user native `flock` is acquired before config, sharing identity, PTY, or
GTK state is created. Losing launchers wait up to two seconds for the winner's
D-Bus endpoint, forward an idempotent Show when appropriate, and exit without
writing the primary hot-session state. D-Bus `RequestName` conflict handling
remains a second fail-closed boundary if the filesystem lock is unavailable or
an older DINTTY process already owns the bus name.

Explicit `--new-window` and workspace/deep-link launches do not claim the
primary dropdown service. Their hot-session persistence is isolated rather
than writing the primary's default autosave.

Proof: `scripts/native_grid_single_instance_smoke.sh` starts 12 simultaneous
cold callers, requires exactly one owner, repeats a hidden/show race, verifies
one ordered visible result, then proves a separate workspace window can coexist
without taking the control name.

### P1 — Wayland activation is explicit — implemented at the GTK boundary

`ShowWithActivation` and `ToggleWithActivation` accept a one-use activation
token capped at 4,096 bytes, valid UTF-8, and no control bytes. The native
StatusNotifier `ProvideXdgActivationToken` path uses the same validator. Cold
launches carry the token across the length-delimited native ABI, while the PTY
environment builder excludes both XDG and legacy desktop startup tokens. A token is applied with
GTK3's supported `gtk_window_set_startup_id` immediately before the initial or
previously hidden window is presented, then cleared; it is never persisted.
Every hide path also discards a pending token so StatusNotifier state cannot be
attached to a later unrelated presentation.

Proof:

- unit tests retain the token boundary;
- the single-instance X11 lane verifies token handoff to an existing owner,
  actual StatusNotifier token presentation, and stale-token clearing across
  hide/show;
- `scripts/native_grid_wayland_activation_smoke.sh` passed on the live Plasma
  Wayland session for cold-start and forwarded Show, observed token application
  before visible presentation, and verified that the PTY child did not inherit
  `XDG_ACTIVATION_TOKEN`.

This is GTK/KWin activation plumbing, not physical HID or photon-level focus
proof.

### P1 — predictable desktop entry points — implemented

The startup-notification-aware application entry now has stable search
keywords, `TryExec`, window class, and **Show**, **Open New Workspace Window**,
and **Show or Hide** actions.
`resources/dinttyhere.desktop` installs a Dolphin/KIO **Open DINTTY Here**
service action with one local directory selection. Dogfood installation
rewrites both `TryExec` and service/application commands to its absolute local
prefix. `--new-window --working-directory PATH` validates a bounded,
absolute, local UTF-8 directory and starts a decorated, separate workspace
without replacing or attaching to the primary dropdown.

Proof: package/install checks retain the service-menu artifact; the workspace
activation contract checks both commands; the single-instance smoke verifies
two coexisting DINTTY processes and the fresh terminal child's exact cwd.

### P1 — first toggle does not stall Plasma — implemented

Live Plasma Wayland triage reproduced the reported symptom on the installed
dogfood path. The old logging launcher cost roughly 200–234 ms even for a
read-only control call and produced 1.4–2.2 s spikes while collecting fresh
Plasma/KWin metadata. Direct native control calls were roughly 13–25 ms on the
same host. The launcher now bypasses session receipts for existing-owner
control calls, uses the owner's held native lock instead of a redundant D-Bus
status preflight for Show/Toggle, caches Plasma/KWin versions at install time,
and enables full
GTK/GLib debug chatter only through `DINTTY_DOGFOOD_VERBOSE=1`. After the
verified dogfood install, 12 installed `--status` calls measured 17.82 ms median
and 19.66 ms maximum on the same live owner. After removing Show/Toggle's
redundant status round trip, a further 30-call installed-owner run retained
15.19 ms Show median / 18.74 ms p95 / 35.47 ms maximum and 13.80 ms Hide
median / 17.02 ms p95 / 17.62 ms maximum.

The other cold-path risk was an overlay layer surface requesting exclusive
keyboard ownership while KWin simultaneously mapped or unmapped it. DINTTY now
uses protocol-v4 on-demand keyboard mode (the live compositor advertises v5),
commits keyboard mode `NONE` before hide, and delays a zero-animation unmap by
one frame. Older layer-shell protocols retain the exclusive compatibility
fallback. Windowed mode is unchanged.

Proof is bounded to native D-Bus call timing and the live Plasma protocol path;
it is not a compositor-wide frame trace or proof against unrelated KWin/GPU
stalls. The same boot logged one KWin main-thread stall during Plasma startup,
and Sunshine was running a KWin screencast on a hybrid Intel GPU, so DINTTY does
not claim every whole-desktop freeze originates in its process.

### P2 — recovery choices explain their process boundary — remaining polish

DINTTY correctly distinguishes restartable shells, tmux/Zellij continuity, and
agent resumes. The remaining work is presentation, not automatic process
resurrection: after a crash or Plasma relogin, make the exact recovery source
and selected restore mode even more prominent before PTYs start.

## Delivery order

1. [x] **State survivability (P0)** — last-known-good fallback and notice.
2. [x] **Control ownership (P0)** — pre-state lock, D-Bus fallback, race gate.
3. [x] **Activation (P1)** — bounded GTK token handoff with live Wayland proof.
4. [x] **Desktop entry points (P1)** — New Workspace and Open Here.
5. [ ] **Restore explanation (P2)** — polish the existing honest continuity UI
   without automatic hibernation or process-resurrection claims.

## Deliberate non-goals

- Do not add a KDE Frameworks, Qt, Electron, Node.js, browser, telemetry, or
  remote-control dependency just to mimic Konsole.
- Do not claim arbitrary shell survival, universal terminal compatibility, or
  compositor activation proof before the relevant retained evidence exists.
- Do not expose a broad unauthenticated D-Bus process-control API.
- Do not turn NoctEd into a permanent terminal sidebar or a replacement IDE.
- Do not replace tmux/Zellij continuity with output-based guesses about whether
  an agent can be stopped.

## Switch-over recommendation

The two local P0 rows are closed, so DINTTY can now be the preferred
launcher/shortcut for dogfood. Leave Konsole installed as an emergency fallback
through the real-session quota and multi-day NCT-112 qualification. Record
sessions in `docs/DOGFOOD_LOG.md`; any reproducible launch, restore, focus, or
data-loss blocker still takes priority over convenience features.
