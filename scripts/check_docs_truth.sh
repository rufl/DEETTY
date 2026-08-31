#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

required_files='
README.md
BACKLOG.md
BACKLOG_ARCHIVE.md
CHANGELOG.md
CONTRIBUTING.md
MEMORY.md
ROADMAP.md
SECURITY.md
docs/ARCHITECTURE.md
docs/CODE_MAP.md
docs/COMPACT_UX.md
docs/DAILY_DRIVER.md
docs/DOGFOOD_LOG.md
docs/DOGFOOD_LOGGING.md
docs/DOGFOOD_RUNBOOK.md
docs/INSTALL.md
docs/KNOWN_LIMITATIONS.md
docs/NATIVE_HOST.md
docs/NOCTED.md
docs/NO_SURPRISE_NETWORK.md
docs/PUBLIC_ALPHA_GO_NO_GO.md
docs/PUBLIC_ALPHA_PLAN.md
docs/PUBLIC_ALPHA_RELEASE_NOTES.md
docs/RELEASE_CHECKLIST.md
docs/RELEASE_OPERATIONS.md
docs/TECHNICAL_STATUS.md
scripts/dogfood_launch.sh
scripts/dogfood_logging_smoke.sh
scripts/dogfood_runtime_status.sh
scripts/dogfood_status.sh
scripts/install_dogfood.sh
scripts/public_alpha_verify.sh
scripts/verify.sh
'
printf '%s\n' "$required_files" | while IFS= read -r path; do
  [ -n "$path" ] || continue
  test -s "$path" || {
    echo "docs_truth missing required file: $path" >&2
    exit 1
  }
done

awk '
  $0 == "## Active" { active = 1; found = 1; next }
  active && /^## / { active = 0 }
  active && /^### NCT-[0-9][0-9][0-9] / && $0 !~ / — (open|partial)$/ {
    print "BACKLOG.md active task must be open or partial: " $0 > "/dev/stderr"
    bad = 1
  }
  END {
    if (!found) {
      print "BACKLOG.md is missing the Active section" > "/dev/stderr"
      bad = 1
    }
    exit bad
  }
' BACKLOG.md

awk '
  /^### NCT-[0-9][0-9][0-9] .* — (open|partial)$/ {
    print "BACKLOG_ARCHIVE.md contains an unfinished primary task: " $0 > "/dev/stderr"
    bad = 1
  }
  END { exit bad }
' BACKLOG_ARCHIVE.md

awk '
  /^### NCT-[0-9][0-9][0-9] .* — (open|partial|done|closed)/ {
    id = $2
    if (++seen[id] > 1) {
      print "duplicate primary backlog task ID " id " at " FILENAME ":" FNR > "/dev/stderr"
      bad = 1
    }
  }
  END { exit bad }
' BACKLOG.md BACKLOG_ARCHIVE.md

find . \
  -path './.git' -prune -o \
  -path './.pi' -prune -o \
  -path './vendor' -prune -o \
  -type f -name '*.md' -print |
while IFS= read -r document; do
  grep -oE '!?(\[[^][]*\])\([^)]+\)' "$document" 2>/dev/null |
  while IFS= read -r markdown_link; do
    target=${markdown_link#*](}
    target=${target%)}
    target=${target#<}
    target=${target%>}
    case "$target" in
      ''|'#'*|http://*|https://*|mailto:*) continue ;;
    esac
    target=${target%%#*}
    target=${target%%\?*}
    resolved=$(dirname "$document")/$target
    if [ ! -e "$resolved" ] && [ ! -e "$target" ]; then
      echo "docs_truth broken link: $document -> $target" >&2
      exit 1
    fi
  done
done

grep -F 'Current public-readiness status: **early source alpha; public announcement not yet approved**.' README.md >/dev/null
grep -F 'Status: **no-go for public alpha announcement** until real counted dogfood, the' \
  docs/PUBLIC_ALPHA_GO_NO_GO.md >/dev/null
grep -F 'full_verify=false' scripts/public_alpha_verify.sh \
  docs/PUBLIC_ALPHA_GO_NO_GO.md docs/PUBLIC_ALPHA_RELEASE_NOTES.md >/dev/null
grep -F 'proof_boundary=static_source_scan' scripts/check_no_surprise_network.sh \
  docs/NO_SURPRISE_NETWORK.md docs/KNOWN_LIMITATIONS.md >/dev/null
grep -F 'NOCTTY_DOGFOOD_OPTIMIZE:-ReleaseFast' scripts/install_dogfood.sh >/dev/null
grep -F 'NOCTTY_ZIG_SINGLE_JOB' scripts/verify.sh >/dev/null
grep -F 'verify_cleanup scratch=true cache=true install=true artifacts=true' \
  README.md MEMORY.md docs/PUBLIC_ALPHA_PLAN.md docs/PUBLIC_ALPHA_RELEASE_NOTES.md >/dev/null

test ! -e src/editor
test ! -e scripts/native_grid_editor_shutdown_smoke.sh
! grep -R -n -E 'Installed Debug dogfood|unstripped Debug binaries|keeps the Debug binaries|repository-owned local SAST check' \
  README.md MEMORY.md ROADMAP.md SECURITY.md docs >/dev/null
! grep -R -n -E 'enable_legacy_editor|noctty_build_options|production_legacy_editor=true' \
  README.md MEMORY.md ROADMAP.md SECURITY.md docs src build.zig scripts >/dev/null

current_abi_docs='docs/ARCHITECTURE.md docs/DAILY_DRIVER.md docs/NATIVE_HOST.md docs/TECHNICAL_STATUS.md'
for document in $current_abi_docs; do
  grep -F 'ABI v6' "$document" >/dev/null
  ! grep -E 'ABI v2|render_abi_version=2' "$document" >/dev/null
done
grep -F 'ABI v4 packed-row fetches' docs/RELEASE_CHECKLIST.md >/dev/null

dogfood_status=$(./scripts/dogfood_status.sh)
printf '%s\n' "$dogfood_status" | grep -F 'dogfood_status counted_sessions=' >/dev/null
printf '%s\n' "$dogfood_status" | grep -F 'five_sessions=' >/dev/null
printf '%s\n' "$dogfood_status" | grep -F 'dogfood_omp_status observed_sessions=' >/dev/null
printf '%s\n' "$dogfood_status" | grep -F 'compatible=' >/dev/null

echo 'docs_truth required_docs=true links=true backlog_partition=true task_ids_unique=true claims_bounded=true stale_surfaces=false abi_current=true dogfood_status=true omp_status=true'
