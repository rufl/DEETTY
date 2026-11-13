# DINTTY Agent Notes

- Keep the runtime native: Zig plus C ABI bindings are acceptable; Electron, Node.js, Bun, React, and browser-runtime UI are not.
- Do not add telemetry, analytics, update pings, crash uploaders, or remote feature flags.
- Keep KDE Plasma, Wayland, and X11 compatibility as first-class constraints.
- Prefer GUI-configurable state models over user-facing TOML/JSON editing. File formats may exist as persistence/import/export details, but editing them manually must not be required.
- Treat `libghostty` as an isolated adapter boundary. Do not let Ghostty API churn leak into workspace, config, theme, or editor state.
- WIZP can be used for ideas around editor buffers, theme handling, PTY/session boundaries, and source-truth workflows, but do not copy its webview/Bun/VS Code parity stack into DINTTY.

