#!/usr/bin/env sh
set -eu

test -s packaging/debian/control
test -x packaging/debian/rules
test -s packaging/rpm/noctty.spec
test -s packaging/arch/PKGBUILD
test -s packaging/runtime-dependencies.txt
test -s packaging/noctty-launcher
test -s packaging/nocted-launcher
grep -q '^Architecture: any$' packaging/debian/control
grep -q "arch=('x86_64' 'aarch64')" packaging/arch/PKGBUILD
grep -q 'pkgconfig(gtk+-3.0)' packaging/rpm/noctty.spec
grep -q 'pkgconfig(gtksourceview-4)' packaging/rpm/noctty.spec
grep -q '^gtksourceview4$' packaging/runtime-dependencies.txt
grep -q '^gtk-layer-shell$' packaging/runtime-dependencies.txt
grep -q "'gtk-layer-shell'" packaging/arch/PKGBUILD
grep -q "'gtksourceview4'" packaging/arch/PKGBUILD
grep -q 'libgtksourceview-4-dev' packaging/debian/control
grep -q 'libgtk-layer-shell0' packaging/debian/control
grep -q '^Requires:       gtk-layer-shell$' packaging/rpm/noctty.spec
grep -q '^Requires:       gtksourceview4$' packaging/rpm/noctty.spec
if grep -Eq '(^vte3$|libvte|vte291|pkgconfig\(vte)' \
    packaging/runtime-dependencies.txt packaging/debian/control \
    packaging/rpm/noctty.spec packaging/arch/PKGBUILD; then
  echo 'package_manifests error=mandatory_vte_dependency' >&2
  exit 1
fi
sh -n packaging/noctty-launcher
sh -n packaging/nocted-launcher
bash -n scripts/package_ztash.sh scripts/package_ztash_smoke.sh
test -x scripts/package_ztash.sh
test -x scripts/package_ztash_smoke.sh
sh -n scripts/package_bundle.sh
sh -n scripts/package_bundle_licenses.sh
sh -n scripts/package_bundle_licenses_backend_smoke.sh
rpm_parser=unavailable
arch_parser=unavailable
if command -v rpmspec >/dev/null 2>&1; then
  rpmspec -P packaging/rpm/noctty.spec >/dev/null
  rpm_parser=passed
fi
if command -v makepkg >/dev/null 2>&1; then
  (cd packaging/arch && makepkg --printsrcinfo >/dev/null)
  arch_parser=passed
fi
echo "package_manifests debian_structure=true rpm_parser=$rpm_parser arch_parser=$arch_parser x86_64_manifest=true aarch64_manifest=true layer_shell_dependency=true gtksourceview_dependency=true mandatory_vte_dependency=false nocted_launcher=true noctalia_artifacts=true bundle_script=true"
