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

cat >"$runtime_dir/launch" <<'EOF'
#!/bin/sh
app=$(basename "$0")
case "$app" in
  noctty|nocted) ;;
  *) echo "unknown NOCTTY dogfood launcher: $app" >&2; exit 64 ;;
esac

state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
log_dir="$state_home/noctty/logs"
mkdir -p "$log_dir"
log="$log_dir/$app-$(date +%Y%m%d-%H%M%S)-$$.log"

# Keep logging useful without allowing unattended dogfood logs to grow forever.
ls -1t "$log_dir/$app"-*.log 2>/dev/null | awk 'NR > 20' | xargs -r rm -f

export G_MESSAGES_DEBUG=all
ulimit -c unlimited 2>/dev/null || true
{
  printf 'dogfood_launch app=%s timestamp=%s pid=%s session=%s backend=%s args=' \
    "$app" "$(date --iso-8601=seconds)" "$$" "${XDG_SESSION_TYPE:-unknown}" "${GDK_BACKEND:-auto}"
  printf ' %s' "$@"
  printf '\n'
} >>"$log"

launcher=$(readlink -f "$0")
runtime_dir=$(dirname "$launcher")
export LD_LIBRARY_PATH="$runtime_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$runtime_dir/$app-bin" "$@" >>"$log" 2>&1
status=$?
printf 'dogfood_exit app=%s timestamp=%s status=%s log=%s\n' \
  "$app" "$(date --iso-8601=seconds)" "$status" "$log" >>"$log"
exit "$status"
EOF
chmod +x "$runtime_dir/launch"
ln -sfn launch "$runtime_dir/nocted"
ln -sfn ../libexec/noctty-dogfood/launch "$prefix/bin/noctty"
ln -sfn ../libexec/noctty-dogfood/launch "$prefix/bin/nocted"

# Desktop launchers do not consistently inherit ~/.local/bin in PATH.
for desktop in "$prefix/share/applications/com.noctty.NOCTTY.desktop" "$prefix/share/applications/com.noctty.NoctEd.desktop"; do
  test -f "$desktop" || continue
  sed -i "s|^Exec=noctty |Exec=$prefix/bin/noctty |; s|^Exec=nocted |Exec=$prefix/bin/nocted |" "$desktop"
done

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$prefix/share/applications" || true

"$runtime_dir/noctty-bin" --version
"$runtime_dir/nocted-bin" --version
printf 'dogfood_install prefix=%s binaries=true wrappers=true desktop_entries=true layer_shell=true logs=%s/noctty/logs optimize=%s retained_logs_per_app=20\n' \
  "$prefix" "${XDG_STATE_HOME:-$HOME/.local/state}" "$optimize"
