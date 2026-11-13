#!/usr/bin/env sh
set -eu

workflow=.github/workflows/release.yml
test -s "$workflow"

grep -F 'version: 0.17.0' "$workflow" >/dev/null
! grep -F 'version: master' "$workflow" >/dev/null
grep -F 'contents: read' "$workflow" >/dev/null
grep -F 'actions/checkout@11d5960a326750d5838078e36cf38b85af677262' "$workflow" >/dev/null
grep -F 'persist-credentials: false' "$workflow" >/dev/null
grep -F 'mlugg/setup-zig@d1434d08867e3ee9daa34448df10607b98908d29' "$workflow" >/dev/null
grep -F 'use-cache: false' "$workflow" >/dev/null
! grep -E 'uses: (actions/checkout|mlugg/setup-zig|actions/upload-artifact)@v[0-9]+' "$workflow" >/dev/null

grep -F 'runner: ubuntu-24.04' "$workflow" >/dev/null
grep -F 'arch: x86_64' "$workflow" >/dev/null
grep -F 'runner: ubuntu-24.04-arm' "$workflow" >/dev/null
grep -F 'arch: aarch64' "$workflow" >/dev/null

grep -F 'libgtk-layer-shell0' "$workflow" >/dev/null
grep -F 'libgtksourceview-4-dev' "$workflow" >/dev/null
grep -F 'bubblewrap dbus-x11 xvfb xauth openbox kwin-wayland' "$workflow" >/dev/null
grep -F 'libvte-2.91-dev' "$workflow" >/dev/null
grep -F 'libgtk-layer-shell-dev' "$workflow" >/dev/null
grep -F 'Assert runner architecture' "$workflow" >/dev/null
grep -F 'actual_arch="$(uname -m)"' "$workflow" >/dev/null
grep -F 'x86_64:x86_64|aarch64:aarch64' "$workflow" >/dev/null

grep -F './scripts/public_alpha_verify.sh' "$workflow" >/dev/null
grep -F 'scripts/isolated_display_runner.sh' "$workflow" >/dev/null
! grep -F 'run: ./scripts/verify.sh' "$workflow" >/dev/null
grep -F './scripts/package_manifests_smoke.sh' "$workflow" >/dev/null
grep -F './scripts/package_bundle.sh "deetty-linux-${{ matrix.arch }}.tar.gz"' "$workflow" >/dev/null

grep -F 'Validate release archive' "$workflow" >/dev/null
grep -F 'archive="deetty-linux-${{ matrix.arch }}.tar.gz"' "$workflow" >/dev/null
grep -F 'sha256sum -c "$archive.sha256"' "$workflow" >/dev/null
grep -F 'test -s "$archive.manifest"' "$workflow" >/dev/null
grep -F "grep -F 'bundle_manifest_version=1' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'library_inventory_begin' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'package_inventory_begin' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'license_files_begin' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'redistribution_ready=true' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'all_copied_host_libraries_accounted=true' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'bundle_license_payload_complete=true' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'gtk_layer_shell_source=system' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './bin/deetty' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './bin/nocted' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './libexec/deetty/deetty' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './libexec/deetty/nocted' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './share/nocted/language-specs/zig.lang' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './share/nocted/language-specs/svelte.lang' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './libexec/deetty/lib/libgtk-layer-shell.so.0' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './share/licenses/deetty/dependencies/packages/' >/dev/null" "$workflow" >/dev/null

grep -F 'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02' "$workflow" >/dev/null
grep -F 'deetty-linux-${{ matrix.arch }}.tar.gz.sha256' "$workflow" >/dev/null
grep -F 'deetty-linux-${{ matrix.arch }}.tar.gz.manifest' "$workflow" >/dev/null

grep -F 'windows:' "$workflow" >/dev/null
grep -F 'zig build check -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseSafe' "$workflow" >/dev/null
grep -F './scripts/package_windows.sh deetty-windows-x86_64-alpha.zip' "$workflow" >/dev/null
grep -F "grep -F 'conpty=true' deetty-windows-x86_64-alpha.zip.manifest" "$workflow" >/dev/null
grep -F "grep -F 'gtk_runtime=false' deetty-windows-x86_64-alpha.zip.manifest" "$workflow" >/dev/null
grep -F 'deetty-windows-x86_64-alpha.zip.sha256' "$workflow" >/dev/null
grep -F 'deetty-windows-x86_64-alpha.zip.manifest' "$workflow" >/dev/null
grep -F 'windows-runtime:' "$workflow" >/dev/null
grep -F 'runs-on: windows-latest' "$workflow" >/dev/null
grep -F 'WINDOWS-SMOKE.ps1 -AutomatedHost' "$workflow" >/dev/null

echo "release_workflow_contract zig=0.17.0 x86_64=true aarch64=true layer_shell=true layer_shell_source=system gtksourceview=true nocted=true arch_assert=true bounded_source_alpha=true repository_isolated_display=true private_x11_wm=true maintainer_verify=false bundle=true archive_validation=true sidecar_validation=true manifest_validation=true upload=true retained_artifacts_external=true windows_alpha=true windows_conpty=true windows_gtk=false windows_runtime_smoke=true"
