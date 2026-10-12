#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <kof-distribution-root> [kof-source-root]" >&2
  exit 2
fi

kof_root=$(CDPATH= cd -- "$1" && pwd)
kof_source=${2:-$kof_root}
kof_source=$(CDPATH= cd -- "$kof_source" && pwd)
nocted_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
kof_bin="$kof_root/bin/kof"
nocted_bin="$nocted_root/zig-out/bin/nocted"

for required in \
  "$kof_root/editor/kof.tmLanguage.json" \
  "$kof_root/tooling/README.md" \
  "$kof_root/bin/kof" \
  "$kof_root/lib/kof.jar" \
  "$kof_source/editor/kof.tmLanguage.json"; do
  test -f "$required" || {
    echo "KOF4J qualification prerequisite missing: $required" >&2
    exit 2
  }
done
test -x "$kof_bin" || {
  echo "KOF4J launcher is not executable: $kof_bin" >&2
  exit 2
}

command -v jq >/dev/null 2>&1 || {
  echo "KOF4J qualification requires jq" >&2
  exit 2
}
command -v sha256sum >/dev/null 2>&1 || {
  echo "KOF4J qualification requires sha256sum" >&2
  exit 2
}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-kof4j.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

cat >"$scratch/Main.kf" <<'EOF'
main() {
    println("NoctEd Kof")
}
EOF
cp "$scratch/Main.kf" "$scratch/Main.kof"
mkdir -p "$scratch/bin" "$scratch/lib" "$scratch/fallback"
cat >"$scratch/bin/kof" <<EOF
#!/bin/sh
exec "$kof_bin" "\$@"
EOF
chmod +x "$scratch/bin/kof"
ln -s "$kof_root/lib/kof.jar" "$scratch/lib/kof.jar"
cp "$scratch/Main.kf" "$scratch/fallback/Main.kf"
cp "$scratch/Main.kof" "$scratch/fallback/Main.kof"

info=$($kof_bin info --json)
printf '%s\n' "$info" | jq -e '.lsp == true and .editorSupport == true and (.kof | length > 0)' >/dev/null
kof_version=$(printf '%s\n' "$info" | jq -r '.kof')

check_kf=$($kof_bin check "$scratch/Main.kf" --json)
printf '%s\n' "$check_kf" | jq -e '.success == true and .filesChecked == 1 and .errorCount == 0' >/dev/null
check_kof=$($kof_bin check "$scratch/Main.kof" --json)
printf '%s\n' "$check_kof" | jq -e '.success == true and .filesChecked == 1 and .errorCount == 0' >/dev/null

kof_test_kf=$($kof_bin test "$scratch/Main.kf" --target jvm)
printf '%s\n' "$kof_test_kf" | grep -F '1 passed, 0 failed' >/dev/null
kof_test_kof=$($kof_bin test "$scratch/Main.kof" --target jvm)
printf '%s\n' "$kof_test_kof" | grep -F '1 passed, 0 failed' >/dev/null

$kof_bin fmt "$scratch/Main.kf" >/dev/null

zig build -Doptimize=Debug >/dev/null
test -x "$nocted_bin"
timeout_bin=$(command -v timeout)
local_path_probe=$(PATH=/usr/bin:/bin "$timeout_bin" 30 "$nocted_bin" --lsp-probe "$scratch/Main.kf")
export PATH="$(dirname "$kof_bin"):$PATH"
lsp_kf=$(timeout 30 "$nocted_bin" --lsp-probe "$scratch/Main.kf")
lsp_kof=$(timeout 30 "$nocted_bin" --lsp-probe "$scratch/Main.kof")
lsp_fallback=$(timeout 30 "$nocted_bin" --lsp-probe "$scratch/fallback/Main.kf")
for probe in "$local_path_probe" "$lsp_kf" "$lsp_kof" "$lsp_fallback"; do
  printf '%s\n' "$probe" | grep -F 'language=kof response=main' >/dev/null
done

kof_revision=$(git -C "$kof_source" rev-parse HEAD 2>/dev/null || printf 'unavailable')
nocted_commit=$(git -C "$nocted_root" rev-parse HEAD)
if git -C "$nocted_root" diff --quiet && git -C "$nocted_root" diff --cached --quiet; then
  nocted_tree_dirty=false
else
  nocted_tree_dirty=true
fi
grammar_sha=$(jq -S -c . "$kof_source/editor/kof.tmLanguage.json" | sha256sum | cut -d' ' -f1)
vendored_grammar_sha=$(jq -S -c . "$nocted_root/resources/nocted/language-specs/kof.tmLanguage.json" | sha256sum | cut -d' ' -f1)
test "$grammar_sha" = "$vendored_grammar_sha"
grep -F '<language id="kof" name="Kof"' "$nocted_root/resources/nocted/language-specs/kof.lang" >/dev/null
grep -F '<property name="globs">*.kf;*.kof</property>' "$nocted_root/resources/nocted/language-specs/kof.lang" >/dev/null
jar_sha=$(sha256sum "$kof_root/lib/kof.jar" | cut -d' ' -f1)

printf 'nocted_kof4j_qualification status=partial languages_fixture=2/2 grammar_source_match=true grammar_xml=true linter_clean=2/2 formatter=1/1 lsp_symbols=2/2 lifecycle=false native_smoke=not_run fixture_manifest=false kof_version=%s kof_revision=%s grammar_sha=%s kof_jar_sha=%s nocted_commit=%s nocted_tree_dirty=%s scratch_clean=true\n' \
  "$kof_version" "$kof_revision" "$grammar_sha" "$jar_sha" "$nocted_commit" "$nocted_tree_dirty"
