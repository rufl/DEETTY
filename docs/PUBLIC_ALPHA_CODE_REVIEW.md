# Public Alpha Code Review

Review date: 2026-07-29.

Scope: source-level public-alpha review of NOCTTY and NoctEd, focused on what is
still needed before publishing an honest open-source alpha. This is not a formal
security audit.

## Summary

NOCTTY/NoctEd does not look like throwaway code. It has extensive bounded proof
work, careful release boundaries, and a strong native-runtime philosophy. The
main public-alpha risk is not missing features; it is complexity and
maintainability. Several production and smoke paths are large enough that a new
contributor will need a simpler map before they can help confidently.

The project is now source-alpha ready except for the deliberately unfilled dogfood evidence. The public promise must stay small: Linux-native terminal workspace plus companion editor, not a mature IDE or universal terminal replacement.

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
A fresh 2026-07-30 single-job run completed successfully with final
scratch/cache/install cleanup. A bounded source-alpha gate still exists as
`./scripts/public_alpha_verify.sh` and deliberately reports `full_verify=false`
because it does not execute the full matrix itself.

Recommended alpha action:

- Use the documented lightweight contributor gate, `zig build check`, and the bounded source-alpha gate, `./scripts/public_alpha_verify.sh`.
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

NoctEd has enough surface for useful quick edits. The original review deferred LSP,
plugins, debugging, and VS Code parity. Dogfood requirements later added a bounded,
on-demand local LSP client; NoctEd still does not implement an LSP server, plugin
runtime, debugger, or parity layer.

Recommended alpha action:

- Dogfood real edit/search/save and local language-service workflows.
- Fix data-loss, crash, save, search, protocol-boundary, and severe usability bugs.
- Keep persistent LSP sessions, DAP, and plugin work post-alpha.

## What still needs to be done

### Must do before source-public alpha

1. Add first counted entries to `docs/DOGFOOD_LOG.md` from real sessions.
2. Keep package/signing language clearly incomplete.
3. Keep the fresh full `./scripts/verify.sh` receipt green when changing shared runtime, package, or proof surfaces.

Already closed for source-alpha prep: screenshots, `docs/CODE_MAP.md`, clean source-copy fast build/check, public alpha release notes, no-surprise network guard, GitHub issue/PR templates, local Git baseline, and the bounded `./scripts/public_alpha_verify.sh` gate.

### Should do before announcing broadly

1. Complete at least five dogfood sessions.
2. Fix any P0/P1 dogfood blockers.
3. Capture one NOCTTY + Pi/coding-agent session.
4. Capture one NoctEd real edit/save/search session.
5. Run display-backed smoke on the intended Plasma Wayland/X11 environment.
6. Create a small alpha release note in `CHANGELOG.md`.

### Defer until after alpha

- persistent/IDE-parity LSP sessions and DAP in NoctEd
- plugin systems
- VS Code/Zed/Sublime parity claims
- broad terminal compatibility claims
- Windows/macOS
- tmux/Zellij live reattach proof unless already needed for dogfood
- GPU renderer rewrite
- major file/module refactors

## Suggested immediate code/doc next steps

1. Start dogfood session 1 and log bugs instead of adding features.
2. Fix only P0/P1 dogfood blockers.
3. Re-run `./scripts/public_alpha_verify.sh` before publishing or tagging.

## Alpha grade

Current grade: **yellow / source-alpha ready except dogfood**.

Reason: docs, screenshots, code map, local Git baseline, bounded gates, release wording, and no-surprise network checks are in place. The remaining honest blocker is counted dogfood evidence; do not mark public announcement green while `./scripts/dogfood_status.sh` reports `counted_sessions=0`.
