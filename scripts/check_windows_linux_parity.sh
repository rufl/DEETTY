#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

english=docs/WINDOWS_LINUX_PARITY.md
chinese=docs/WINDOWS_LINUX_PARITY.zh-CN.md
[ -s "$english" ]
[ -s "$chinese" ]

rows='terminal-io tabs recursive-splits focus selection-scrolling profiles themes persistence smart-tabs dropdown-hotkey nocted sharing status-strip'
row_count=0
for row in $rows; do
  grep -F "| \`$row\` |" "$english" >/dev/null
  grep -F "| \`$row\` |" "$chinese" >/dev/null
  row_count=$((row_count + 1))
done

grep -F 'physical-open' "$english" >/dev/null
grep -F 'external-open' "$english" >/dev/null
grep -F 'remote_deployment=not_performed' "$english" >/dev/null

grep -F 'physical-open' "$chinese" >/dev/null
grep -F 'external-open' "$chinese" >/dev/null
grep -F 'remote_deployment=not_performed' "$chinese" >/dev/null

git_commit=$(git rev-parse --verify HEAD)
printf 'windows_linux_parity commit=%s rows=%s physical_windows=OPEN cross_machine=OPEN release_operations=SEPARATE bilingual=true\n' \
  "$git_commit" "$row_count"
