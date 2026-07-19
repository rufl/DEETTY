# Public Alpha Code Review

Review date: 2026-07-19.

Scope: source-level public-alpha review of NOCTTY and NoctEd, focused on what is
still needed before publishing an honest open-source alpha. This is not a formal
security audit.

## Summary

NOCTTY/NoctEd does not look like throwaway code. It has extensive bounded proof
work, careful release boundaries, and a strong native-runtime philosophy. The
main public-alpha risk is not missing features; it is complexity and
maintainability. Several production and smoke paths are large enough that a new
contributor will need a simpler map before they can help confidently.

The project is close to a publishable source alpha if the public promise stays
small: Linux-native terminal workspace plus companion editor, not a mature IDE
or universal terminal replacement.

## What looks strong

- Native runtime boundary is clear: production `noctty`/`nocted` avoid Electron,
  Node, Bun, browser UI, telemetry, and surprise network behavior.
- The split between NOCTTY terminal workspace and standalone NoctEd is the right
  product boundary for alpha.
- The terminal core has real attention to bounded parsing, scrollback,
  grapheme/Unicode handling, process groups, teardown, and PTY lifecycle.
- NoctEd has the correct small-editor foundation: project tree, tabs, save/Save
  As, search, quick open, folding, minimap, dirty-close handling.
- Release claims are already proof-bounded in the backlog and detailed docs.
- `docs/KNOWN_LIMITATIONS.md`, `ROADMAP.md`, and `MEMORY.md` now give a public
  reader a smaller truth surface.

## Main risks before public alpha

### 1. Very large files block contributor readability

Largest current surfaces include:

- `src/gui/native_grid_host.c` (~15k lines)
- `src/main.zig` (~7k lines)
- `src/nocted/main.zig` (~6k lines)
- `src/app/App.zig` (~4k lines)
- `src/workspace/Workspace.zig` (~3.7k lines)
- `src/terminal/Vt.zig` (~3.6k lines)

This is not automatically wrong, but public readers will struggle. For alpha,
do not rewrite these. Instead add architecture maps and extract only the most
obvious low-risk seams later.

Recommended alpha action:

- Add `docs/CODE_MAP.md` with module responsibilities and entry points.
- Add short comments at top of the largest files explaining their ownership.
- Defer large refactors until after dogfood.

### 2. Smoke/qualification code is mixed into production entry surfaces

`src/main.zig`, `src/nocted/main.zig`, and build targets carry many smoke and
qualification paths. This is valuable evidence, but it makes the source feel
heavier and harder to reason about.

Recommended alpha action:

- Keep current behavior, but document the distinction clearly in `docs/CODE_MAP.md`.
- After alpha, consider moving smoke command dispatch into dedicated modules so
  `main.zig` is easier to read.

### 3. Verification is strong but currently heavy/fragile for contributors

The full `./scripts/verify.sh` is authoritative but long and environment-heavy.
During this pass, one normal run hit a Zig compile `SEGV`; a single-job retry
progressed further but exceeded a 180s harness timeout.

Recommended alpha action:

- Add a documented lightweight contributor gate, e.g. `zig build check` or a
  new `./scripts/quick_check.sh`, if one already exists or can be added cheaply.
- Keep `./scripts/verify.sh` as the maintainer gate.
- Document that display-backed and long qualification lanes are maintainer/host
  specific.

### 4. Release operation blockers remain real

The source tree may be publishable before polished binaries are. Do not bundle
or announce signed/installable release artifacts until evidence exists.

Still open:

- signing
- publication receipts
- independent dependency-bundle redistribution review
- retained architecture artifacts/signatures
- compositor acceptance receipts
- consented Wayland HID/input evidence

Recommended alpha action:

- Publish source alpha first.
- Mark packages/bundles experimental/local until release-operation rows close.

### 5. NoctEd should stay small for alpha

NoctEd has enough surface for useful quick edits. The temptation will be LSP,
plugins, debugging, or VS Code parity. Defer that.

Recommended alpha action:

- Dogfood real edit/search/save workflows.
- Fix only data-loss, crash, save, search, and severe usability bugs.
- Keep LSP/DAP/plugin work post-alpha.

## What still needs to be done

### Must do before source-public alpha

1. Add screenshots or GIFs to the README.
2. Add `docs/CODE_MAP.md` for human code navigation.
3. Add first entries to `docs/DOGFOOD_LOG.md` from real sessions.
4. Record current verify status honestly: pass, timeout, or toolchain failure.
5. Confirm clean source checkout build instructions on the target machine.
6. Decide repository name and GitHub org paths under Lichforge.
7. Keep package/signing language clearly incomplete.

### Should do before announcing broadly

1. Complete at least five dogfood sessions.
2. Fix any P0/P1 dogfood blockers.
3. Capture one NOCTTY + Pi/coding-agent session.
4. Capture one NoctEd real edit/save/search session.
5. Run display-backed smoke on the intended Plasma Wayland/X11 environment.
6. Create a small alpha release note in `CHANGELOG.md`.

### Defer until after alpha

- LSP/DAP in NoctEd
- plugin systems
- VS Code/Zed/Sublime parity claims
- broad terminal compatibility claims
- Windows/macOS
- tmux/Zellij live reattach proof unless already needed for dogfood
- GPU renderer rewrite
- major file/module refactors

## Suggested immediate code/doc next steps

1. Create `docs/CODE_MAP.md`.
2. Add screenshots/GIF placeholders to README if assets are not ready.
3. Add `scripts/quick_check.sh` only if it can wrap existing cheap checks.
4. Start dogfood session 1 and log bugs instead of adding features.

## Alpha grade

Current grade: **yellow / promising alpha candidate**.

Reason: core docs and proof discipline are strong, but public alpha still needs
screenshots, dogfood evidence, contributor code map, and a clean/current gate
story.
