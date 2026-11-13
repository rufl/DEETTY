#!/usr/bin/env sh
set -eu

files='
scripts/verify.sh
scripts/install_dogfood.sh
scripts/package_tarball.sh
scripts/package_bundle.sh
scripts/package_windows.sh
scripts/package_windows_installer.sh
scripts/windows_sign_artifact.sh
scripts/terminal_benchmark.sh
scripts/run_isolated_x11.sh
scripts/run_isolated_wayland.sh
scripts/isolated_display_runner.sh
scripts/isolated_display_smoke.sh
scripts/capture_alpha_screenshots.sh
'

for file in $files; do
  test -s "$file"
  grep -F 'trap cleanup EXIT' "$file" >/dev/null
  grep -F "trap 'exit 129' HUP" "$file" >/dev/null
  grep -F "trap 'exit 130' INT" "$file" >/dev/null
  grep -F "trap 'exit 143' TERM" "$file" >/dev/null
  ! grep -F 'trap cleanup EXIT HUP INT TERM' "$file" >/dev/null
done

test_root=$(mktemp -d "${TMPDIR:-/tmp}/dintty-signal-trap.XXXXXX")
cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if TEST_ROOT="$test_root" sh -eu -c '
  cleanup() { : >"$TEST_ROOT/cleaned"; }
  trap cleanup EXIT
  trap "exit 129" HUP
  trap "exit 130" INT
  trap "exit 143" TERM
  kill -TERM $$
  : >"$TEST_ROOT/continued"
'; then
  echo 'signal_trap_contract error=term_returned_success' >&2
  exit 1
else
  status=$?
fi

test "$status" -eq 143
test -f "$test_root/cleaned"
test ! -e "$test_root/continued"

printf 'signal_trap_contract scripts=%s term_exit=143 cleanup=true continued=false\n' \
  "$(printf '%s\n' $files | wc -l | tr -d ' ')"
