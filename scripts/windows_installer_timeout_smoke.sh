#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/dintty-windows-installer-timeout.XXXXXX")
cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT HUP INT TERM
fake_bin="$scratch/bin"
mkdir -p "$fake_bin"
installer="$scratch/dintty-setup.exe"
printf 'installer fixture\n' >"$installer"
(
  cd "$scratch"
  sha256sum "$(basename "$installer")" >"$(basename "$installer").sha256"
)
cat >"$installer.manifest" <<'EOF'
windows_installer_manifest_version=2
signed=false
scope=per-user
open_with_only=true
user_data_preserved_on_uninstall=true
EOF
cat >"$fake_bin/wineboot" <<'EOF'
#!/usr/bin/env sh
sleep 5
EOF
for command in wine winepath wineserver; do
  cat >"$fake_bin/$command" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF
  chmod +x "$fake_bin/$command"
done
chmod +x "$fake_bin/wineboot"

start=$(date +%s)
set +e
output=$(PATH="$fake_bin:$PATH" \
  DINTTY_WINE="$fake_bin/wine" \
  DINTTY_WINEBOOT="$fake_bin/wineboot" \
  DINTTY_WINEPATH="$fake_bin/winepath" \
  DINTTY_WINESERVER="$fake_bin/wineserver" \
  DINTTY_WINE_STEP_TIMEOUT_SECONDS=1 \
  DINTTY_WINE_CLEANUP_TIMEOUT_SECONDS=1 \
  ./scripts/windows_installer_smoke.sh "$installer" 2>&1)
status=$?
set -e
elapsed=$(($(date +%s) - start))
[ "$status" -eq 124 ]
printf '%s\n' "$output" |
  grep -F 'windows_installer_smoke error=step_failed stage=wineboot status=124' >/dev/null
[ "$elapsed" -le 8 ]

echo "windows_installer_timeout_smoke step_timeout=true cleanup_timeout=true stage_reported=true status_preserved=true elapsed_seconds=$elapsed"
