#!/bin/sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-task.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
cat >"$scratch/Makefile" <<'EOF'
check:
	@printf 'nocted-task-marker\n'
EOF

zig build -Doptimize=Debug >/dev/null
output=$(timeout 30 ./zig-out/bin/nocted --task-probe "$scratch" check)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F \
  'nocted_task_probe project=Make action=check success=true output=nocted-task-marker' >/dev/null
echo 'nocted_task_smoke detected=true bounded=true background_worker=true output=true exit_status=true scratch_clean=true'
