# NOCTTY Agent Notes

- Keep the runtime native: Zig plus C ABI bindings are acceptable; Electron, Node.js, Bun, React, and browser-runtime UI are not.
- Do not add telemetry, analytics, update pings, crash uploaders, or remote feature flags.
- Keep KDE Plasma, Wayland, and X11 compatibility as first-class constraints.
- Prefer GUI-configurable state models over user-facing TOML/JSON editing. File formats may exist as persistence/import/export details, but editing them manually must not be required.
- Treat `libghostty` as an isolated adapter boundary. Do not let Ghostty API churn leak into workspace, config, theme, or editor state.
- WIZP can be used for ideas around editor buffers, theme handling, PTY/session boundaries, and source-truth workflows, but do not copy its webview/Bun/VS Code parity stack into NOCTTY.

<!-- lichforge-display-test-policy:start -->
## Golden rule: focused and contained tests

- During implementation, run only the smallest test or test group that proves the behavior being changed. Do not run a full repository, platform, browser, device, or graphical matrix.
- Any test that needs a display must run inside a disposable isolated display environment, such as headless browser mode, Xvfb with a lightweight window manager inside a private socket namespace, or a dedicated container/VM compositor. Plain Xvfb alone is insufficient because it can still inherit host Wayland and session-bus sockets. It must never use, replace, reconfigure, capture, or inject input into the developer's active X11/Wayland session, desktop compositor, or physical monitors.
- Display-test wrappers must fail closed when isolation is unavailable. Use `overzeer-isolated-display` or a reviewed repository wrapper that provides equivalent private display/session sockets, bounded timeouts, serialized graphical runs, and complete spawned-process-tree cleanup.
- A full test matrix is allowed only as final pre-commit verification. It must still use isolated displays, remain pressure-gated and serialized, and must not run against the main display. In Pi sessions, the user must grant the one-shot `/precommit-matrix` permit first.
<!-- lichforge-display-test-policy:end -->
