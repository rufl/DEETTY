#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-install-dogfood-smoke.XXXXXX")
cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT HUP INT TERM
fake_bin="$scratch/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/zig" <<'EOF'
#!/usr/bin/env sh
set -eu
prefix=
while [ "$#" -gt 0 ]; do
  if [ "$1" = --prefix ]; then
    shift
    prefix=$1
  fi
  shift
done
test -n "$prefix"
mkdir -p "$prefix/bin" "$prefix/share/applications" \
  "$prefix/share/kio/servicemenus" "$prefix/share/icons/hicolor"
cat >"$prefix/bin/noctty" <<'BIN'
#!/usr/bin/env sh
printf 'noctty 0.1.0\n'
BIN
cat >"$prefix/bin/nocted" <<'BIN'
#!/usr/bin/env sh
printf 'nocted 0.1.0\n'
BIN
chmod +x "$prefix/bin/noctty" "$prefix/bin/nocted"
cat >"$prefix/share/applications/com.noctty.NOCTTY.desktop" <<'DESKTOP'
TryExec=noctty
Exec=noctty --open-uri %u
DESKTOP
cat >"$prefix/share/applications/com.noctty.NoctEd.desktop" <<'DESKTOP'
Exec=nocted --open %f
DESKTOP
cat >"$prefix/share/kio/servicemenus/nocttyhere.desktop" <<'DESKTOP'
TryExec=noctty
Exec=noctty --new-window --working-directory %f
DESKTOP
EOF
cat >"$fake_bin/ldconfig" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF
for command in plasmashell kwin_wayland update-desktop-database gtk-update-icon-cache; do
  cat >"$fake_bin/$command" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF
  chmod +x "$fake_bin/$command"
done
chmod +x "$fake_bin/zig" "$fake_bin/ldconfig"

valid_home="$scratch/valid-home"
valid_state="$scratch/valid-state"
valid_prefix="$scratch/valid-prefix"
valid_runtime="$valid_prefix/libexec/noctty-dogfood"
mkdir -p "$valid_home" "$valid_state/noctty" "$valid_runtime/lib"
printf 'retained layer shell fixture\n' >"$valid_runtime/lib/libgtk-layer-shell.so.0"
valid_digest=$(sha256sum "$valid_runtime/lib/libgtk-layer-shell.so.0" | awk '{print $1}')
printf 'build_receipt_version=1\nlayer_shell_sha256=%s\n' "$valid_digest" \
  >"$valid_state/noctty/dogfood-build.receipt"
valid_output=$(PATH="$fake_bin:$PATH" HOME="$valid_home" XDG_STATE_HOME="$valid_state" \
  ./scripts/install_dogfood.sh "$valid_prefix")
printf '%s\n' "$valid_output" | grep -F 'dogfood_install ' >/dev/null
grep -Fx "layer_shell_sha256=$valid_digest" \
  "$valid_state/noctty/dogfood-build.receipt" >/dev/null
test -x "$valid_runtime/noctty-bin"
test -x "$valid_runtime/nocted-bin"
test -x "$valid_runtime/launch"
test "$(readlink "$valid_prefix/bin/noctty")" = ../libexec/noctty-dogfood/launch

invalid_home="$scratch/invalid-home"
invalid_state="$scratch/invalid-state"
invalid_prefix="$scratch/invalid-prefix"
invalid_runtime="$invalid_prefix/libexec/noctty-dogfood"
mkdir -p "$invalid_home" "$invalid_state/noctty" "$invalid_runtime/lib"
printf 'existing binary must survive\n' >"$invalid_runtime/noctty-bin"
printf 'modified retained library\n' >"$invalid_runtime/lib/libgtk-layer-shell.so.0"
printf 'build_receipt_version=1\nlayer_shell_sha256=%064d\n' 0 \
  >"$invalid_state/noctty/dogfood-build.receipt"
if PATH="$fake_bin:$PATH" HOME="$invalid_home" XDG_STATE_HOME="$invalid_state" \
    ./scripts/install_dogfood.sh "$invalid_prefix" >/dev/null 2>&1; then
  echo 'install_dogfood_smoke error=mismatched_runtime_accepted' >&2
  exit 1
fi
grep -Fx 'existing binary must survive' "$invalid_runtime/noctty-bin" >/dev/null
test ! -e "$invalid_prefix/share"

echo 'install_dogfood_smoke retained_runtime=true checksum_required=true preflight_before_mutation=true binaries=true launchers=true receipt=true'
