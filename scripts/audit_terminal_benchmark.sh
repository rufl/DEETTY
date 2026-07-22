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

awk -F, '
    NR == 1 { next }
    NF != 27 || $1 == "" || $3 == "" || $4 !~ /^(1|2|4|8)$/ ||
        $6 !~ /^[0-9]+$/ || $7 !~ /^[0-9]+$/ || $12 !~ /^[1-9][0-9]*$/ ||
        $21 !~ /^[1-9][0-9]*$/ || $22 !~ /^[1-9][0-9]*$/ ||
        $23 !~ /^[1-9][0-9]*$/ || $24 !~ /^[1-9][0-9]*$/ ||
        ($3 == "output" && ($25 !~ /^[0-9]+([.][0-9]+)?$/ || $26 !~ /^[0-9]+$/ ||
            $27 !~ /^[0-9]+([.][0-9]+)?$/)) { bad++ }
    END { exit bad != 0 }
' "$raw"
awk -F, 'NR > 1 { seen[$13]++ } END { for (serial in seen) if (seen[serial] != 1) exit 1 }' "$raw"
awk -F '\t' 'NR > 1 { seen[$1]++ } END { if (length(seen) == 0) exit 1 }' "$processes"
grep -F 'metric_output=writer_completion metric_visual=release_to_external_pixel_marker metric_visual_tail=writer_completion_to_external_pixel_marker' "$metadata" >/dev/null
grep -F 'git_commit=' "$metadata" >/dev/null

echo "terminal_benchmark_audit ok=true checksums=$file raw_rows=$(($(wc -l <"$raw") - 1))"
