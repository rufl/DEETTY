# Install and Package

NOCTTY is an early source alpha. Start with a checkout build or a local prefix
install; dependency bundles and signed releases have additional requirements.

## Prerequisites

Building requires:

- Zig 0.17.x (CI pins 0.17.0; other minor versions are rejected);
- libepoxy development files discoverable through `pkg-config` for the
  optional OpenGL presentation path;
- `pkg-config`;
- GTK 3 development files;
- GtkSourceView 4 development files;
- system `gtk-layer-shell` is required for the first dogfood install, dependency
  bundle creation, and Plasma layer-shell dropdown placement; a later dogfood
  refresh may reuse only the checksum-matching private copy recorded by the
  previous install receipt. Noctalia sessions can use the ordinary Wayland
  toplevel path.

Install `gtk-layer-shell` on Arch Linux or `libgtk-layer-shell0` on
Debian/Ubuntu before the first dogfood install or any bundle build.

VTE 2.91 development files are required only for `zig build check`, smoke binaries, or the optional `noctty-vte` fallback. Production `noctty` links neither VTE nor Tree-sitter. Production `nocted` statically includes its vendored Tree-sitter parsers and adds no Tree-sitter runtime package; distribution manifests do not require VTE. Runtime package names are mapped in `packaging/runtime-dependencies.txt`.

- Install Zig 0.17.0 from [ziglang.org](https://ziglang.org/download/) and put its
  `zig` executable on `PATH`; distribution packages may provide a different
  minor version. Then install the native production-build dependencies:

```sh
# Debian/Ubuntu
sudo apt-get install build-essential pkg-config libgtk-3-dev libepoxy-dev libgtksourceview-4-dev libgtk-layer-shell0

# Arch Linux (alternative, not an additional step)
sudo pacman -S --needed base-devel gtk3 libepoxy gtksourceview4 gtk-layer-shell
```

For `zig build check`, additionally install `libvte-2.91-dev` on Debian/Ubuntu
or `vte3` on Arch. The default production build needs no downloaded Zig
packages or Tree-sitter generator: the native parser sources and generated
Unicode tables are included. No OVERZEER installation or authenticated agent
CLI is needed to build or launch.

## Run from the Checkout

```sh
zig build -j1
./zig-out/bin/noctty --native-grid-windowed
```

Run this from the repository root in a Linux desktop session. It builds both
production binaries and installs their resources into `zig-out`; it does not
run the maintainer verification matrix or install into your home directory.
To launch the editor, use `./zig-out/bin/nocted --open README.md`.
These are ordinary application launches, not graphical test commands.

The non-graphical contributor gate is `zig build check -j1 --summary all`;
see [Contributing](../CONTRIBUTING.md#before-opening-a-change) for focused
checks and the separate, environment-dependent graphical gate.

Optional modes:

```sh
zig build run -- --native-grid-windowed
zig build run -- --native-grid-zen
zig build run -- --native-grid-two-pane
zig build run-nocted -- --open src/nocted/main.zig
zig build vte-fallback
./zig-out/bin/noctty-vte --native-host
zig build run -- --noctalia-plan niri
```

Native single-instance controls used by Noctalia compositor bindings are `noctty --status`, `--show`, `--hide`, and `--toggle`. Use `noctty --hidden` only from compositor autostart after installing the matching F10 binding.

The optional split-terminal comparison is not a runtime dependency. It requires the selected peer terminals, `xdotool`, and `qdbus`. `NOCTTY_BENCH_OFFSCREEN=1 ./scripts/terminal_benchmark.sh` uses the reviewed private display runner; a compositor-backed run requires `NOCTTY_DEDICATED_DISPLAY=1` in a disposable X11/XWayland session. The harness stops Yakuake before and after a run and writes machine-local artifacts under `benchmarks/`; methodology and limits are in [TERMINAL_BENCHMARK.md](TERMINAL_BENCHMARK.md).

## Dogfood Install

For unstripped `ReleaseFast` binaries with private GUI-session stdout/stderr,
GTK/GLib warnings, exit status, crash-log capture, and atomic duration receipts:

```sh
./scripts/install_dogfood.sh
```

This installs logging launchers as `~/.local/bin/noctty` and
`~/.local/bin/nocted`, keeps the staged binaries under
`~/.local/libexec/noctty-dogfood/`, copies the installed system GTK Layer Shell runtime into its private library directory for undecorated Wayland dropdowns, and updates the installed desktop
entries. If the system package is later removed, a refresh accepts only that
private library when its SHA-256 still matches the previous private build
receipt; missing or modified retained runtimes fail closed. It retains the
newest 100 verbose logs per app under
`~/.local/state/noctty/logs/` and 500 compact `0600` duration receipts per app
under `~/.local/state/noctty/dogfood-sessions/`. Existing-instance control and
version calls bypass receipt setup so external shortcuts do not pay the roughly
200 ms logging-launcher setup cost; Show/Toggle still use the logged path when
they must cold-start the GUI. Set `NOCTTY_DOGFOOD_VERBOSE=1` only when full
GTK/GLib debug chatter is needed, and `NOCTTY_DOGFOOD_OPTIMIZE=Debug` for a
debugging build. The installer rewrites application and Dolphin service-menu
`TryExec`/`Exec` entries to the absolute dogfood prefix so Plasma does not
depend on its inherited `PATH`. See
[DOGFOOD_LOGGING.md](DOGFOOD_LOGGING.md).

## Local Prefix Install

```sh
zig build -j1 -Doptimize=ReleaseSafe --prefix "$HOME/.local"
```

The default install tree contains only production binaries and resources:

- `bin/noctty`
- `bin/nocted`
- `share/applications/com.noctty.NOCTTY.desktop`
- `share/applications/com.noctty.NoctEd.desktop`
- `share/kio/servicemenus/nocttyhere.desktop`
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
- `share/licenses/noctty/THIRD_PARTY_NOTICES.md`
- `share/licenses/noctty/UNICODE-LICENSE.txt`
- `share/licenses/noctty/vendor/` with the linked Tree-sitter license texts

The optional `noctty-vte`, the `noctty-smoke`/`nocted-smoke` verification binaries, and the `nocted-core-stability`, `nocted-project-index-qualification`, `noctty-terminal-compatibility`, and `noctty-terminal-session-qualification` runners are non-default build artifacts and are excluded from normalized release archives.

If `$HOME/.local/bin` is not already on `PATH`, add it before launching `noctty` or `nocted`. Both desktop entries and Dolphin's **Open NOCTTY Here** directory action become available after Plasma refreshes its service/application cache.

The installed workspace-URL contract can be checked without modifying user desktop state:

```sh
./scripts/native_grid_installed_activation_smoke.sh --contract-only
```

Only in a disposable dedicated Plasma VM/session, omit `--contract-only` to
dispatch the disposable installed desktop entry through `gio` and drive the
Recent Workspaces child on both Wayland and X11. Never run this lane on your
active desktop. The full lane fails when a backend is inaccessible and does
not substitute headless registration for rendered compositor proof.

## Source Archives

The `.paths` allowlist in `build.zig.zon` includes first-party build tools,
scripts, dependency provenance, packaging definitions, contributor documents,
and retained documentation evidence as well as source, resources, and vendored
licenses. It excludes local build caches, installed binaries, and private
agent state. This allowlist controls Zig package contents; it does not filter
GitHub's Git-based source archives. Review tracked files before publishing
either form.

An extracted source archive can use the same production build and
`zig build check` commands as a checkout. Git-aware source-hygiene checks
require a Git checkout; neither source builds nor local prefix installs
require release artifacts, signatures, or compositor acceptance receipts.

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

## ZTASH Dogfood Packages

```sh
./scripts/package_ztash.sh
./scripts/package_ztash_smoke.sh
```

The ignored `dist/ztash/` directory is rebuilt atomically with Linux and
Windows target-bound archives, `SHA256SUMS`, and `ztash-release.json`. Each
archive uses the OVERZEER root contract:

- Linux: `noctty-<version>-linux-x86_64/noctty`, `README.md`, `LICENSE`;
- Windows: `noctty-<version>-windows-x86_64/noctty.exe`, `README.txt`,
  `LICENSE`.

The packages are unsigned build-only dogfood artifacts. Physical Windows
qualification, signing, public publication, and receiver activation remain
separate evidence boundaries. Use the OVERZEER ZTASH bridge for preview-first
deployment; it verifies the manifest and archive digests before invoking the
authenticated DDJARIN/CHOPPER fleet lane.

The bundle:

- builds `ReleaseSafe` for the current architecture;
- includes production `noctty` without VTE, Tree-sitter, or smoke commands, plus `nocted` with statically vendored Tree-sitter parsing;
- moves both real binaries under `libexec/noctty` and copies their combined linked runtime libraries into `libexec/noctty/lib`;
- explicitly copies the dynamically loaded `libgtk-layer-shell.so.0`;
- installs thin `noctty` and `nocted` launchers that set the bundle-local library path;
- verifies both `noctty --version` and `nocted --version`;
- normalizes archive ownership, ordering, timestamps, and gzip metadata;
- emits and verifies a SHA-256 sidecar.

It remains architecture-local and still expects Linux, a compatible kernel/display session, and desktop services such as Plasma GlobalAccel or a Noctalia compositor binding, session D-Bus, and a freedesktop notification service.

NOCTTY's MIT license covers its first-party code, not the copied host
libraries. Vendored parser and Unicode licenses are retained in ordinary
installs; bundle-specific host-library notices are additional. Review
[Third-party notices](../THIRD_PARTY_NOTICES.md) before redistributing.

## Distribution Manifests

Historical packaging baseline: 2026-07-18; release contract version 0.1.0,
source baseline 2026-07-14, package revision 1. These are retained packaging
metadata, not evidence that a fresh checkout has passed release qualification.

- Debian: `packaging/debian/`
- RPM: `packaging/rpm/noctty.spec`
- Arch Linux: `packaging/arch/PKGBUILD`
- Runtime dependency contract: `packaging/runtime-dependencies.txt`
- x86_64/aarch64 release matrix: `.github/workflows/release.yml`

`./scripts/package_manifests_smoke.sh` checks manifest structure, syntax-checks the launcher/bundle scripts, and reports RPM and Arch parser lanes as `passed` or `unavailable` instead of promoting unavailable tools to success. `./scripts/package_bundle.sh` emits `.tar.gz`, `.sha256`, and `.manifest` sidecars. `./scripts/package_ztash.sh` emits target-bound Linux/Windows dogfood archives plus `SHA256SUMS` and `ztash-release.json`; `./scripts/package_ztash_smoke.sh` validates their archive roots, required files, digests, and the Linux headless deployment smoke. The bundle manifest records version, release date, architecture, Zig compiler, source revision when available, archive digest, byte count, sorted installed files and bundled libraries, per-library ownership/license records, dependency package inventory, and SHA-256-indexed notice files.

The reproducible tarball and same-architecture dependency bundle both compile `ReleaseSafe` with `-Dstrip=true`. This removes debug/symbol sections from shipped executables. The bundle's `redistribution_ready=true` field is separately fail-closed on exact library ownership plus a complete embedded license payload.

The repository does not redistribute an unverified `gtk-layer-shell` fallback. A first dogfood install requires the system `libgtk-layer-shell.so.0`; a later dogfood refresh and dependency-bundle build may reuse only the checksum-matching private copy from the previous dogfood receipt when the system library is absent. Bundles copy the current host-package library when present, or the receipt-matched private copy otherwise, and record that retained-runtime source explicitly. For every copied host library, the Arch/pacman or Debian/dpkg backend stores the owning package/version/expression/source and copies package-installed notices/copyright files plus available canonical SPDX license/exception texts into `share/licenses/noctty/dependencies`. A package with no resolvable ownership or retained text aborts the bundle. The synthetic Debian backend smoke validates multiarch ownership, version, copyright, inventory, and license receipts.

- The release workflow is configured for x86_64 and aarch64 runners, pinned to Zig `0.17.0`, and locally guarded by `scripts/release_workflow_contract_smoke.sh`. Each job provisions `libgtk-layer-shell.so.0`, asserts the runner architecture matches the artifact label, and validates the generated archive plus SHA-256 sidecar before upload. Tagged architecture artifacts, checksums, manifests, and signatures must still be run and retained before release.

`./scripts/release_operations_status.sh` tracks the external release evidence boundary. The current local receipt is `release_operations_status version=0.1.0 tagged_artifacts=false signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=6`; `--list-missing` emits deterministic issue rows such as `release_operations_issue category=tagged_artifacts path=noctty-linux-x86_64.tar.gz reason=missing`. The focused smoke reports `semantic_receipts=true`, so retained manifests and receipts must include the expected fields before `--require-complete` can pass. The required retained files and `NOCTTY_RELEASE_EVIDENCE_DIR` override are documented in [RELEASE_OPERATIONS.md](RELEASE_OPERATIONS.md).

`./scripts/release_operations_scaffold.sh /path/to/evidence` can create receipt templates. It reports `artifact_files=false`, and its smoke receipt is `release_operations_scaffold_smoke templates=true fake_artifacts=false placeholder_blocked=true require_complete_blocks=true scratch_clean=true`, so template directories stay blocked until real evidence replaces TODO values.

`./scripts/release_operations_artifact_intake.sh <arch> <archive.tar.gz> /path/to/evidence` retains tagged architecture artifacts only after the adjacent `.sha256` and `.manifest` sidecars verify. Its smoke receipt is `release_operations_artifact_intake_smoke x86_64=true aarch64=true sidecars_verified=true retained_status=true mismatch_blocked=true scratch_clean=true`.

`./scripts/release_operations_signature_intake.sh <arch> <archive|checksum|manifest> <signature-file> /path/to/evidence` retains signatures only after the matching canonical retained target exists. Its smoke receipt is `release_operations_signature_intake_smoke archive=true checksum=true manifest=true x86_64=true aarch64=true placeholder_blocked=true target_required=true retained_status=true scratch_clean=true`. The local guard does not perform cryptographic verification or publication.

`./scripts/release_operations_receipt_intake.sh <publication|dependency-bundle-redistribution> <receipt-file> /path/to/evidence` retains publication and redistribution receipts only after semantic fields validate and placeholder text is absent. Its smoke receipt is `release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true`. Publication also requires retained tagged artifacts and signatures before status can mark it true.

`./scripts/release_operations_acceptance_intake.sh compositor <name> <receipt-file> /path/to/evidence` and `./scripts/release_operations_acceptance_intake.sh wayland-hid <receipt-file> /path/to/evidence` retain compositor acceptance and Wayland HID consent receipts only after semantic fields validate. Its smoke receipt is `release_operations_acceptance_intake_smoke compositors=6 wayland_hid=true semantic=true placeholder_blocked=true compositor_mismatch_blocked=true consent_required=true complete_status=true scratch_clean=true`. This local guard does not create compositor sessions or bypass portal consent.

Signing and publication are intentionally not performed by local verification; they require release credentials and are listed in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).
