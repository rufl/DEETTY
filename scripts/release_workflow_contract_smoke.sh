#!/usr/bin/env sh
set -eu

workflow=.github/workflows/release.yml
test -s "$workflow"

grep -F 'version: 0.16.0' "$workflow" >/dev/null
! grep -F 'version: master' "$workflow" >/dev/null

grep -F 'runner: ubuntu-24.04' "$workflow" >/dev/null
grep -F 'arch: x86_64' "$workflow" >/dev/null
grep -F 'runner: ubuntu-24.04-arm' "$workflow" >/dev/null
grep -F 'arch: aarch64' "$workflow" >/dev/null

grep -F 'libgtk-layer-shell0' "$workflow" >/dev/null
grep -F 'libgtksourceview-4-dev' "$workflow" >/dev/null
grep -F 'Assert runner architecture' "$workflow" >/dev/null
grep -F 'actual_arch="$(uname -m)"' "$workflow" >/dev/null
grep -F 'x86_64:x86_64|aarch64:aarch64' "$workflow" >/dev/null

grep -F './scripts/verify.sh' "$workflow" >/dev/null
grep -F './scripts/package_manifests_smoke.sh' "$workflow" >/dev/null
grep -F './scripts/package_bundle.sh "noctty-linux-${{ matrix.arch }}.tar.gz"' "$workflow" >/dev/null

grep -F 'Validate release archive' "$workflow" >/dev/null
grep -F 'archive="noctty-linux-${{ matrix.arch }}.tar.gz"' "$workflow" >/dev/null
grep -F 'sha256sum -c "$archive.sha256"' "$workflow" >/dev/null
grep -F 'test -s "$archive.manifest"' "$workflow" >/dev/null
grep -F "grep -F 'bundle_manifest_version=1' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'library_inventory_begin' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'package_inventory_begin' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'license_files_begin' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'redistribution_ready=true' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'all_copied_host_libraries_accounted=true' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "grep -F 'bundle_license_payload_complete=true' \"\$archive.manifest\" >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './bin/noctty' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './bin/nocted' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './libexec/noctty/noctty' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './libexec/noctty/nocted' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './share/nocted/language-specs/zig.lang' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './share/nocted/language-specs/svelte.lang' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './libexec/noctty/lib/libgtk-layer-shell.so.0' >/dev/null" "$workflow" >/dev/null
grep -F "tar -tzf \"\$archive\" | grep -F './share/licenses/noctty/dependencies/packages/' >/dev/null" "$workflow" >/dev/null

grep -F 'actions/upload-artifact@v4' "$workflow" >/dev/null
grep -F 'noctty-linux-${{ matrix.arch }}.tar.gz.sha256' "$workflow" >/dev/null
grep -F 'noctty-linux-${{ matrix.arch }}.tar.gz.manifest' "$workflow" >/dev/null

echo "release_workflow_contract zig=0.16.0 x86_64=true aarch64=true layer_shell=true gtksourceview=true nocted=true arch_assert=true verify=true bundle=true archive_validation=true sidecar_validation=true manifest_validation=true upload=true retained_artifacts_external=true"
