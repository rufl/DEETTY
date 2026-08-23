#!/bin/sh
set -eu

prefix=${1:-"$HOME/.local"}
optimize=${NOCTTY_DOGFOOD_OPTIMIZE:-ReleaseFast}
stage=$(mktemp -d "${TMPDIR:-/tmp}/noctty-dogfood-install.XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM

zig build -Doptimize="$optimize" --prefix "$stage"

runtime_dir="$prefix/libexec/noctty-dogfood"
mkdir -p "$prefix/bin" "$runtime_dir/lib"
cp -a "$stage/share" "$prefix/"
install -m 0755 "$stage/bin/noctty" "$runtime_dir/noctty-bin.new"
install -m 0755 "$stage/bin/nocted" "$runtime_dir/nocted-bin.new"
mv -f "$runtime_dir/noctty-bin.new" "$runtime_dir/noctty-bin"
mv -f "$runtime_dir/nocted-bin.new" "$runtime_dir/nocted-bin"
rm -f "$runtime_dir/noctty" "$runtime_dir/nocted"

layer_shell=$(ldconfig -p 2>/dev/null | awk '/libgtk-layer-shell\.so\.0 / { print $NF; exit }')
if [ -z "$layer_shell" ] && [ "$(uname -m)" = "x86_64" ]; then
  layer_shell=vendor/gtk-layer-shell/usr/lib/libgtk-layer-shell.so.0.10.1
fi
test -f "$layer_shell" || {
  echo "dogfood install requires libgtk-layer-shell.so.0" >&2
  exit 1
}
install -m 0644 "$layer_shell" "$runtime_dir/lib/libgtk-layer-shell.so.0.new"
mv -f "$runtime_dir/lib/libgtk-layer-shell.so.0.new" \
  "$runtime_dir/lib/libgtk-layer-shell.so.0"

install -m 0755 scripts/dogfood_launch.sh "$runtime_dir/launch.new"
mv -f "$runtime_dir/launch.new" "$runtime_dir/launch"
ln -sfn launch "$runtime_dir/nocted"
ln -sfn ../libexec/noctty-dogfood/launch "$prefix/bin/noctty"
ln -sfn ../libexec/noctty-dogfood/launch "$prefix/bin/nocted"

# Desktop launchers do not consistently inherit ~/.local/bin in PATH.
for desktop in "$prefix/share/applications/com.noctty.NOCTTY.desktop" "$prefix/share/applications/com.noctty.NoctEd.desktop"; do
  test -f "$desktop" || continue
  sed -i "s|^Exec=noctty |Exec=$prefix/bin/noctty |; s|^Exec=nocted |Exec=$prefix/bin/nocted |" "$desktop"
done

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$prefix/share/applications" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 &&
  gtk-update-icon-cache -q -f -t "$prefix/share/icons/hicolor" || true

"$runtime_dir/noctty-bin" --version
"$runtime_dir/nocted-bin" --version
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
state_dir="$state_home/noctty"
mkdir -p "$state_dir"
build_receipt="$state_dir/dogfood-build.receipt"
build_receipt_new="$build_receipt.new.$$"
{
  printf 'build_receipt_version=1\n'
  printf 'install_timestamp=%s\n' "$(date --iso-8601=seconds)"
  printf 'install_epoch=%s\n' "$(date +%s)"
  printf 'optimize=%s\n' "$optimize"
  printf 'noctty_sha256=%s\n' "$(sha256sum "$runtime_dir/noctty-bin" | awk '{ print $1 }')"
  printf 'nocted_sha256=%s\n' "$(sha256sum "$runtime_dir/nocted-bin" | awk '{ print $1 }')"
  printf 'layer_shell_sha256=%s\n' "$(sha256sum "$runtime_dir/lib/libgtk-layer-shell.so.0" | awk '{ print $1 }')"
} >"$build_receipt_new"
chmod 0600 "$build_receipt_new"
mv -f "$build_receipt_new" "$build_receipt"
printf 'dogfood_install prefix=%s binaries=true wrappers=true desktop_entries=true layer_shell=true logs=%s/noctty/logs receipts=%s/noctty/dogfood-sessions build_receipt=%s optimize=%s retained_logs_per_app=100 retained_receipts_per_app=500\n' \
  "$prefix" "$state_home" "$state_home" "$build_receipt" "$optimize"
