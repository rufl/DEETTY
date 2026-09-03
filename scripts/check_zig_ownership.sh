#!/usr/bin/env sh
set -eu

zig_lines=0
adapter_lines=0

count_nonblank() {
  awk 'NF { count++ } END { print count + 0 }' "$1"
}

while IFS= read -r path; do
  lines=$(count_nonblank "$path")
  case "$path" in
    *.zig) zig_lines=$((zig_lines + lines)) ;;
    *.c|*.h) adapter_lines=$((adapter_lines + lines)) ;;
  esac
done <<EOF
$(find src include/noctty -type f \( -name '*.zig' -o -name '*.c' -o -name '*.h' \) -print | LC_ALL=C sort)
EOF

total_lines=$((zig_lines + adapter_lines))
test "$total_lines" -gt 0
zig_basis_points=$((zig_lines * 10000 / total_lines))
if [ "$zig_basis_points" -lt 8000 ]; then
  printf 'zig_ownership error=below_target zig_lines=%s adapter_lines=%s percentage=%d.%02d target=80.00\n' \
    "$zig_lines" "$adapter_lines" "$((zig_basis_points / 100))" "$((zig_basis_points % 100))" >&2
  exit 1
fi

printf 'zig_ownership zig_lines=%s adapter_lines=%s percentage=%s.%02d target=80.00 vendor_generated_excluded=true display_orchestration_excluded=true\n' \
  "$zig_lines" "$adapter_lines" "$((zig_basis_points / 100))" "$((zig_basis_points % 100))"
