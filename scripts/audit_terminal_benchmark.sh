#!/usr/bin/env bash
set -euo pipefail

checksums=${1:?usage: audit_terminal_benchmark.sh benchmarks/...-SHA256SUMS}
dir=$(cd "$(dirname "$checksums")" && pwd)
file=$dir/$(basename "$checksums")

(cd "$dir" && sha256sum -c "$(basename "$file")")
stem=${file%-SHA256SUMS}
raw=$stem-raw.csv
summary=$stem-summary.csv
metadata=$stem-metadata.txt
processes=$stem-processes.tsv

for artifact in "$raw" "$summary" "$metadata" "$processes"; do
    [[ -s "$artifact" ]] || { echo "benchmark_audit missing=$artifact" >&2; exit 1; }
done
native_wayland_visual=0
if grep -F 'metric_visual=unavailable_native_wayland' "$metadata" >/dev/null; then
    native_wayland_visual=1
fi


awk -v native_wayland_visual="$native_wayland_visual" -F, '
    NR == 1 { next }
    {
        common_bad = $1 == "" || $3 == "" || $4 !~ /^(1|2|4|8|16|32)$/ ||
            $6 !~ /^[0-9]+$/ || $7 !~ /^[0-9]+$/ || $8 !~ /^[0-9]+$/
        if (NF == 26) {
            if (common_bad || $12 !~ /^[1-9][0-9]*$/ ||
                $21 !~ /^[1-9][0-9]*$/ || $22 !~ /^[1-9][0-9]*$/ ||
                $23 !~ /^[1-9][0-9]*$/ || $24 !~ /^[1-9][0-9]*$/ ||
                (!native_wayland_visual && $3 == "output" && ($25 !~ /^[0-9]+([.][0-9]+)?$/ ||
                    $26 !~ /^[0-9]+$/))) bad++
        } else if (NF == 27) {
            if (common_bad || $12 !~ /^[1-9][0-9]*$/ ||
                $21 !~ /^[1-9][0-9]*$/ || $22 !~ /^[1-9][0-9]*$/ ||
                $23 !~ /^[1-9][0-9]*$/ || $24 !~ /^[1-9][0-9]*$/ ||
                (!native_wayland_visual && $3 == "output" && ($25 !~ /^[0-9]+([.][0-9]+)?$/ ||
                    $26 !~ /^[0-9]+$/ || $27 !~ /^[0-9]+([.][0-9]+)?$/))) bad++
        } else if (NF == 28) {
            if (common_bad || $9 !~ /^[0-9]+$/ || $13 !~ /^[1-9][0-9]*$/ ||
                $22 !~ /^[1-9][0-9]*$/ || $23 !~ /^[1-9][0-9]*$/ ||
                $24 !~ /^[1-9][0-9]*$/ || $25 !~ /^[1-9][0-9]*$/ ||
                (!native_wayland_visual && $3 == "output" && ($26 !~ /^[0-9]+([.][0-9]+)?$/ ||
                    $27 !~ /^[0-9]+$/ || $28 !~ /^[0-9]+([.][0-9]+)?$/))) bad++
        } else bad++
    }
    END { exit bad != 0 }
' "$raw"
awk -F, '
    NR == 1 { for (column = 1; column <= NF; column++) if ($column == "run_serial") serial_column = column; next }
    { seen[$serial_column]++ }
    END { if (!serial_column) exit 1; for (serial in seen) if (seen[serial] != 1) exit 1 }
' "$raw"
awk -F '\t' 'NR > 1 { seen[$1]++ } END { if (length(seen) == 0) exit 1 }' "$processes"
raw_fields=$(awk -F, 'NR == 1 { print NF; exit }' "$raw")
if (( native_wayland_visual == 1 )); then
    grep -F 'metric_output=writer_completion metric_visual=unavailable_native_wayland metric_visual_tail=unavailable_native_wayland' "$metadata" >/dev/null
elif (( raw_fields >= 27 )); then
    grep -F 'metric_output=writer_completion metric_visual=release_to_external_pixel_marker metric_visual_tail=writer_completion_to_external_pixel_marker' "$metadata" >/dev/null
else
    grep -F 'metric_output=writer_completion metric_visual=release_to_external_pixel_marker' "$metadata" >/dev/null
fi
grep -F 'git_commit=' "$metadata" >/dev/null

echo "terminal_benchmark_audit ok=true checksums=$file raw_rows=$(($(wc -l <"$raw") - 1))"
