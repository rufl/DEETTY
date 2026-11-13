#!/bin/sh
set -eu

prefix=${1:-"$HOME/.local"}
optimize=${DEETTY_DOGFOOD_OPTIMIZE:-ReleaseFast}
stage=$(mktemp -d "${TMPDIR:-/tmp}/deetty-dogfood-install.XXXXXX")
cleanup() { rm -rf "$stage"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

zig build -Doptimize="$optimize" --prefix "$stage"

runtime_dir="$prefix/libexec/deetty-dogfood"
layer_shell=$(ldconfig -p 2>/dev/null | awk '/libgtk-layer-shell\.so\.0 / { print $NF; exit }')
if [ ! -f "$layer_shell" ]; then
  retained_layer_shell="$runtime_dir/lib/libgtk-layer-shell.so.0"
  retained_receipt="${XDG_STATE_HOME:-"$HOME/.local/state"}/deetty/dogfood-build.receipt"
  retained_expected=$(awk -F= '$1 == "layer_shell_sha256" { print $2; exit }' \
    "$retained_receipt" 2>/dev/null || true)
  retained_actual=$(sha256sum "$retained_layer_shell" 2>/dev/null |
    awk 'NR == 1 { print $1; exit }' || true)
  case "$retained_expected" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*)
      if [ "${#retained_expected}" -eq 64 ] &&
         [ "$retained_actual" = "$retained_expected" ]; then
        layer_shell=$retained_layer_shell
      fi
      ;;
  esac
fi
test -f "$layer_shell" || {
  echo "dogfood install requires a system libgtk-layer-shell.so.0 or the checksum-matching runtime from the previous dogfood receipt" >&2
  exit 1
}
mkdir -p "$prefix/bin" "$runtime_dir/lib"
cp -a "$stage/share" "$prefix/"
install -m 0755 "$stage/bin/deetty" "$runtime_dir/deetty-bin.new"
install -m 0755 "$stage/bin/nocted" "$runtime_dir/nocted-bin.new"
mv -f "$runtime_dir/deetty-bin.new" "$runtime_dir/deetty-bin"
mv -f "$runtime_dir/nocted-bin.new" "$runtime_dir/nocted-bin"
rm -f "$runtime_dir/deetty" "$runtime_dir/nocted"

install -m 0644 "$layer_shell" "$runtime_dir/lib/libgtk-layer-shell.so.0.new"
mv -f "$runtime_dir/lib/libgtk-layer-shell.so.0.new" \
  "$runtime_dir/lib/libgtk-layer-shell.so.0"

install -m 0755 scripts/dogfood_launch.sh "$runtime_dir/launch.new"
mv -f "$runtime_dir/launch.new" "$runtime_dir/launch"
ln -sfn launch "$runtime_dir/nocted"
ln -sfn ../libexec/deetty-dogfood/launch "$prefix/bin/deetty"
ln -sfn ../libexec/deetty-dogfood/launch "$prefix/bin/nocted"

# Plasma and Dolphin launchers do not consistently inherit ~/.local/bin in PATH.
for desktop in \
  "$prefix/share/applications/com.deetty.DEETTY.desktop" \
  "$prefix/share/applications/com.deetty.NoctEd.desktop" \
  "$prefix/share/kio/servicemenus/deettyhere.desktop"
do
  test -f "$desktop" || continue
  sed -i \
    -e "s|^TryExec=deetty$|TryExec=$prefix/bin/deetty|" \
    -e "s|^Exec=deetty |Exec=$prefix/bin/deetty |" \
    -e "s|^Exec=nocted |Exec=$prefix/bin/nocted |" \
    "$desktop"
done

grep -Fx "TryExec=$prefix/bin/deetty" \
  "$prefix/share/applications/com.deetty.DEETTY.desktop" >/dev/null
grep -Fx "Exec=$prefix/bin/deetty --open-uri %u" \
  "$prefix/share/applications/com.deetty.DEETTY.desktop" >/dev/null
grep -Fx "TryExec=$prefix/bin/deetty" \
  "$prefix/share/kio/servicemenus/deettyhere.desktop" >/dev/null
grep -Fx "Exec=$prefix/bin/deetty --new-window --working-directory %f" \
  "$prefix/share/kio/servicemenus/deettyhere.desktop" >/dev/null

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$prefix/share/applications" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 &&
  gtk-update-icon-cache -q -f -t "$prefix/share/icons/hicolor" || true

"$runtime_dir/deetty-bin" --version
"$runtime_dir/nocted-bin" --version
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
state_dir="$state_home/deetty"
mkdir -p "$state_dir"
build_receipt="$state_dir/dogfood-build.receipt"
build_receipt_new="$build_receipt.new.$$"
plasma_version=$(plasmashell --version 2>/dev/null | awk 'NR == 1 { print $NF; exit }' || true)
kwin_version=$(kwin_wayland --version 2>/dev/null | awk 'NR == 1 { print $NF; exit }' || true)
[ -n "$plasma_version" ] || plasma_version=unknown
[ -n "$kwin_version" ] || kwin_version=unknown
{
  printf 'build_receipt_version=1\n'
  printf 'install_timestamp=%s\n' "$(date --iso-8601=seconds)"
  printf 'install_epoch=%s\n' "$(date +%s)"
  printf 'optimize=%s\n' "$optimize"
  printf 'deetty_sha256=%s\n' "$(sha256sum "$runtime_dir/deetty-bin" | awk '{ print $1 }')"
  printf 'nocted_sha256=%s\n' "$(sha256sum "$runtime_dir/nocted-bin" | awk '{ print $1 }')"
  printf 'layer_shell_sha256=%s\n' "$(sha256sum "$runtime_dir/lib/libgtk-layer-shell.so.0" | awk '{ print $1 }')"
  printf 'plasma_version=%s\n' "$plasma_version"
  printf 'kwin_version=%s\n' "$kwin_version"
} >"$build_receipt_new"
chmod 0600 "$build_receipt_new"
mv -f "$build_receipt_new" "$build_receipt"
printf 'dogfood_install prefix=%s binaries=true wrappers=true desktop_entries=true layer_shell=true logs=%s/deetty/logs receipts=%s/deetty/dogfood-sessions build_receipt=%s optimize=%s retained_logs_per_app=100 retained_receipts_per_app=500\n' \
  "$prefix" "$state_home" "$state_home" "$build_receipt" "$optimize"
