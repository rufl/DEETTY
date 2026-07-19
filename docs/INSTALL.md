# Install and Package

Verified baseline: 2026-07-18.

Canonical release contract: version 0.1.0, source baseline 2026-07-14, package revision 1.

## Prerequisites

Building requires:

- Zig 0.16.x or newer;
- `pkg-config`;
- GTK 3 development files;
- GtkSourceView 4 development files;
- `gtk-layer-shell` at runtime for Wayland drop-down placement.

VTE 2.91 development files are required only for `zig build check`, smoke binaries, or the optional `noctty-vte` fallback. The production `noctty` and `nocted` build does not link VTE or Tree-sitter, and the distribution runtime manifests do not require VTE. Runtime package names are mapped in `packaging/runtime-dependencies.txt`.

## Run from the Checkout

```sh
./scripts/verify.sh
zig build run
```

Optional modes:

```sh
zig build run -- --native-grid-windowed
zig build run -- --native-grid-zen
zig build run -- --native-grid-two-pane
zig build run-nocted -- --project . --open src/nocted/main.zig
zig build vte-fallback
./zig-out/bin/noctty-vte --native-host
zig build run -- --noctalia-plan niri
```

Native single-instance controls used by Noctalia compositor bindings are `noctty --status`, `--show`, `--hide`, and `--toggle`. Use `noctty --hidden` only from compositor autostart after installing the matching F10 binding.

The optional split-terminal comparison is not a runtime dependency. It requires Konsole, Kitty, WezTerm, Terminator, Ghostty, `xdotool`, and `qdbus` in an interactive KDE display session. `./scripts/terminal_benchmark.sh` keeps Yakuake excluded and writes machine-local CSV/metadata artifacts under `benchmarks/`; methodology and limits are in [TERMINAL_BENCHMARK.md](TERMINAL_BENCHMARK.md).

## Dogfood Debug Install

For unstripped local binaries with per-launch stdout/stderr, GTK/GLib debug,
exit-status, and crash-log capture:

```sh
./scripts/install_dogfood.sh
```

This installs logging launchers as `~/.local/bin/noctty` and
`~/.local/bin/nocted`, keeps the Debug binaries under
`~/.local/libexec/noctty-dogfood/`, updates the installed desktop entries, and
retains the newest 20 logs per app under `~/.local/state/noctty/logs/`. See
[DOGFOOD_LOGGING.md](DOGFOOD_LOGGING.md).

## Local Prefix Install

```sh
zig build -Doptimize=ReleaseSafe --prefix "$HOME/.local"
```

The default install tree contains only production binaries and resources:

- `bin/noctty`
- `bin/nocted`
- `share/applications/com.noctty.NOCTTY.desktop`
- `share/applications/com.noctty.NoctEd.desktop`
- `share/metainfo/com.noctty.NOCTTY.metainfo.xml`
- `share/metainfo/com.noctty.NoctEd.metainfo.xml`
- `share/icons/hicolor/scalable/apps/com.noctty.NOCTTY.svg`
- `share/icons/hicolor/scalable/apps/com.noctty.NoctEd.svg`
- `share/icons/hicolor/48x48/apps/com.noctty.NOCTTY.png`
- `share/icons/hicolor/128x128/apps/com.noctty.NOCTTY.png`
- `share/noctty/noctalia/{niri.kdl,hyprland.lua,hyprland.conf,sway.conf,scroll.conf,labwc-rc.xml,labwc-autostart,mango.conf}`
- `share/noctty/noctalia/noctalia-v5-widget.toml`
- `share/nocted/language-specs/zig.lang`
- `share/nocted/styles/nocted-dark.xml`
- `share/licenses/noctty/LICENSE`

The optional `noctty-vte`, the `noctty-smoke`/`nocted-smoke` verification binaries, and the `nocted-core-stability`, `nocted-project-index-qualification`, `noctty-terminal-compatibility`, and `noctty-terminal-session-qualification` runners are non-default build artifacts and are excluded from normalized release archives.

If `$HOME/.local/bin` is not already on `PATH`, add it before launching `noctty` or `nocted`. Both desktop entries become available after the desktop environment refreshes its application cache.

The installed workspace-URL contract can be checked without modifying user desktop state:

```sh
./scripts/native_grid_installed_activation_smoke.sh --contract-only
```

On an accessible Plasma session, omit `--contract-only` to dispatch the disposable installed desktop entry through `gio` and drive the Recent Workspaces child on both Wayland and X11. The full lane fails when a backend is inaccessible and does not substitute headless registration for rendered compositor proof.

## Normalized Install Tarball

```sh
./scripts/package_tarball.sh /tmp/noctty-local.tar.gz
sha256sum -c /tmp/noctty-local.tar.gz.sha256
```

This command creates two isolated `ReleaseSafe` install trees with separate stages and Zig caches, normalizes archive ordering, timestamps, ownership, and gzip metadata, requires byte-identical archives with matching SHA-256 values, then publishes the requested archive and verified SHA-256 sidecar. Scratch stages, caches, and temporary publish paths are removed after the receipt is emitted; the requested output archive and sidecar are preserved. The archive expects target-system runtime libraries.

## Dependency Bundle

```sh
./scripts/package_bundle.sh /tmp/noctty-linux-bundle.tar.gz
sha256sum -c /tmp/noctty-linux-bundle.tar.gz.sha256
```

The bundle:

- builds `ReleaseSafe` for the current architecture;
- includes the production binaries without VTE, Tree-sitter, smoke commands, or the legacy embedded-editor command surface;
- moves both real binaries under `libexec/noctty` and copies their combined linked runtime libraries into `libexec/noctty/lib`;
- explicitly copies the dynamically loaded `libgtk-layer-shell.so.0`;
- installs thin `noctty` and `nocted` launchers that set the bundle-local library path;
- verifies both `noctty --version` and `nocted --version`;
- normalizes archive ownership, ordering, timestamps, and gzip metadata;
- emits and verifies a SHA-256 sidecar.

It remains architecture-local and still expects Linux, a compatible kernel/display session, and desktop services such as Plasma GlobalAccel or a Noctalia compositor binding, session D-Bus, and a freedesktop notification service.

## Distribution Manifests

- Debian: `packaging/debian/`
- RPM: `packaging/rpm/noctty.spec`
- Arch Linux: `packaging/arch/PKGBUILD`
- Runtime dependency contract: `packaging/runtime-dependencies.txt`
- x86_64/aarch64 release matrix: `.github/workflows/release.yml`

`./scripts/package_manifests_smoke.sh` checks manifest structure, syntax-checks the launcher/bundle scripts, and reports RPM and Arch parser lanes as `passed` or `unavailable` instead of promoting unavailable tools to success. `./scripts/package_bundle.sh` emits `.tar.gz`, `.sha256`, and `.manifest` sidecars. The manifest records version, release date, architecture, Zig compiler, source revision when available, archive digest, byte count, sorted installed files and bundled libraries, per-library ownership/license records, dependency package inventory, and SHA-256-indexed notice files.

The reproducible tarball and same-architecture dependency bundle both compile `ReleaseSafe` with `-Dstrip=true`. This removes debug/symbol sections from shipped executables. The bundle's `redistribution_ready=true` field is separately fail-closed on exact library ownership plus a complete embedded license payload.

The vendored `gtk-layer-shell` fallback is reconciled as `LGPL-3.0-or-later`: the extracted `.PKGINFO`, Arch package page, and upstream README agree on that project/package license, while `LICENSE_MIT.txt` applies to many individual source files. For every copied host library, the Arch/pacman or Debian/dpkg backend stores the owning package/version/expression/source and copies package-installed notices/copyright files plus available canonical SPDX license/exception texts into `share/licenses/noctty/dependencies`. A package with no resolvable ownership or retained text aborts the bundle. The synthetic Debian backend smoke validates multiarch ownership, version, copyright, inventory, and unowned-library rejection; the Ubuntu release workflow validates the actual bundle payload before upload. This automated readiness gate is not legal advice or an independent release review.

The release workflow is configured for x86_64 and aarch64 runners, pinned to Zig `0.16.0`, and locally guarded by `scripts/release_workflow_contract_smoke.sh`. Each job provisions `libgtk-layer-shell.so.0`, asserts the runner architecture matches the artifact label, and validates the generated archive plus SHA-256 sidecar before upload. Tagged architecture artifacts, checksums, manifests, and signatures must still be run and retained before release.

`./scripts/release_operations_status.sh` tracks the external release evidence boundary. The current local receipt is `release_operations_status version=0.1.0 tagged_artifacts=false signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=6`; `--list-missing` emits deterministic issue rows such as `release_operations_issue category=tagged_artifacts path=noctty-linux-x86_64.tar.gz reason=missing`. The focused smoke reports `semantic_receipts=true`, so retained manifests and receipts must include the expected fields before `--require-complete` can pass. The required retained files and `NOCTTY_RELEASE_EVIDENCE_DIR` override are documented in [RELEASE_OPERATIONS.md](RELEASE_OPERATIONS.md).

`./scripts/release_operations_scaffold.sh /path/to/evidence` can create receipt templates. It reports `artifact_files=false`, and its smoke receipt is `release_operations_scaffold_smoke templates=true fake_artifacts=false placeholder_blocked=true require_complete_blocks=true scratch_clean=true`, so template directories stay blocked until real evidence replaces TODO values.

`./scripts/release_operations_artifact_intake.sh <arch> <archive.tar.gz> /path/to/evidence` retains tagged architecture artifacts only after the adjacent `.sha256` and `.manifest` sidecars verify. Its smoke receipt is `release_operations_artifact_intake_smoke x86_64=true aarch64=true sidecars_verified=true retained_status=true mismatch_blocked=true scratch_clean=true`.

`./scripts/release_operations_signature_intake.sh <arch> <archive|checksum|manifest> <signature-file> /path/to/evidence` retains signatures only after the matching canonical retained target exists. Its smoke receipt is `release_operations_signature_intake_smoke archive=true checksum=true manifest=true x86_64=true aarch64=true placeholder_blocked=true target_required=true retained_status=true scratch_clean=true`. The local guard does not perform cryptographic verification or publication.

`./scripts/release_operations_receipt_intake.sh <publication|dependency-bundle-redistribution> <receipt-file> /path/to/evidence` retains publication and redistribution receipts only after semantic fields validate and placeholder text is absent. Its smoke receipt is `release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true`. Publication also requires retained tagged artifacts and signatures before status can mark it true.

`./scripts/release_operations_acceptance_intake.sh compositor <name> <receipt-file> /path/to/evidence` and `./scripts/release_operations_acceptance_intake.sh wayland-hid <receipt-file> /path/to/evidence` retain compositor acceptance and Wayland HID consent receipts only after semantic fields validate. Its smoke receipt is `release_operations_acceptance_intake_smoke compositors=6 wayland_hid=true semantic=true placeholder_blocked=true compositor_mismatch_blocked=true consent_required=true complete_status=true scratch_clean=true`. This local guard does not create compositor sessions or bypass portal consent.

Signing and publication are intentionally not performed by local verification; they require release credentials and are listed in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).
