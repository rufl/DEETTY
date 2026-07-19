#!/usr/bin/env sh
set -eu

for path in README.md docs/TECHNICAL_STATUS.md BACKLOG.md BACKLOG_ARCHIVE.md CHANGELOG.md \
  docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md \
  docs/COMPACT_UX.md docs/NOCTED.md docs/NOCTALIA.md docs/INSTALL.md docs/RELEASE_CHECKLIST.md \
  docs/RELEASE_OPERATIONS.md docs/NO_SURPRISE_NETWORK.md docs/PUBLIC_ALPHA_RELEASE_NOTES.md \
  docs/PUBLIC_ALPHA_GO_NO_GO.md \
  scripts/public_alpha_verify.sh scripts/dogfood_status.sh \
  docs/TERMINAL_BENCHMARK.md docs/DAILY_DRIVER.md docs/DOGFOOD_RUNBOOK.md \
  .github/ISSUE_TEMPLATE/bug_report.yml .github/ISSUE_TEMPLATE/alpha_dogfood.yml \
  .github/ISSUE_TEMPLATE/config.yml .github/pull_request_template.md \
  docs/LAUNCH_PROFILES.md docs/WORKSPACE_ACTIVATION.md \
  docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md \
  docs/TERMINAL_REAL_TUI_QUALIFICATION.md \
  docs/TERMINAL_NCURSES_QUALIFICATION.md \
  docs/TERMINAL_SYSTEM_TUI_QUALIFICATION.md \
  docs/TERMINAL_SESSION_QUALIFICATION.md \
  docs/NATIVE_GRID_RENDERER_QUALIFICATION.md \
  docs/TERMINAL_PIPELINE_QUALIFICATION.md \
  docs/NOCTED_PROJECT_INDEX_QUALIFICATION.md \
  docs/NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md \
  docs/NOCTED_CORE_ENDURANCE_QUALIFICATION.md \
  docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md \
  docs/PERFORMANCE_ALGORITHM_RESEARCH.md \
  vendor/gtk-layer-shell/README.md vendor/gtk-layer-shell/.PKGINFO \
  vendor/gtk-layer-shell/LICENSE_MIT.txt; do
  test -s "$path"
done

awk '
    $0 == "## Active" {
        active = 1
        found_active = 1
        next
    }
    active && /^## / {
        active = 0
    }
    active && /^### NCT-[0-9][0-9][0-9] / && $0 !~ / — (open|partial)$/ {
        print "BACKLOG.md active task must be open or partial: " $0 > "/dev/stderr"
        bad = 1
    }
    END {
        if (!found_active) {
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

grep -F 'docs/KNOWN_LIMITATIONS.md' README.md >/dev/null
grep -F 'docs/NO_SURPRISE_NETWORK.md' README.md >/dev/null
grep -F 'docs/CODE_MAP.md' README.md >/dev/null
grep -F 'docs/PUBLIC_ALPHA_PLAN.md' README.md >/dev/null
grep -F 'docs/PUBLIC_ALPHA_GO_NO_GO.md' README.md >/dev/null
grep -F 'docs/PUBLIC_ALPHA_RELEASE_NOTES.md' README.md >/dev/null
grep -F 'docs/DOGFOOD_RUNBOOK.md' README.md >/dev/null
grep -F 'docs/DOGFOOD_LOG.md' README.md >/dev/null
grep -F 'docs/TECHNICAL_STATUS.md' README.md >/dev/null
grep -F 'docs/assets/noctty-alpha.png' README.md >/dev/null
grep -F 'docs/assets/nocted-alpha.png' README.md >/dev/null

grep -F 'docs/PITCH_AUDIT.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/INSTALL.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/RELEASE_CHECKLIST.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/RELEASE_OPERATIONS.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/ARCHITECTURE.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/NATIVE_HOST.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/NOCTED.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/NOCTED_PROJECT_INDEX_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/NOCTED_CORE_ENDURANCE_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/COMPACT_UX.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/NOCTALIA.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/TERMINAL_BENCHMARK.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/TERMINAL_REAL_TUI_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/TERMINAL_NCURSES_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/TERMINAL_SYSTEM_TUI_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/TERMINAL_SESSION_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/NATIVE_GRID_RENDERER_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/TERMINAL_PIPELINE_QUALIFICATION.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/DAILY_DRIVER.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/LAUNCH_PROFILES.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'docs/PERFORMANCE_ALGORITHM_RESEARCH.md' docs/TECHNICAL_STATUS.md >/dev/null
grep -F 'export XDG_CACHE_HOME="$verify_root/xdg-cache"' scripts/verify.sh >/dev/null
grep -F 'verify_parent="${NOCTTY_VERIFY_PARENT:-.}"' scripts/verify.sh >/dev/null
grep -F 'NOCTTY_ZIG_SINGLE_JOB' scripts/verify.sh >/dev/null
grep -F 'public_alpha_verify passed=true build_check=true no_surprise_network=true docs_truth=true native_grid_smoke=true nocted_native_smoke=true full_verify=false' scripts/public_alpha_verify.sh docs/PUBLIC_ALPHA_RELEASE_NOTES.md >/dev/null
grep -F './scripts/public_alpha_verify.sh' README.md ROADMAP.md docs/PUBLIC_ALPHA_PLAN.md >/dev/null
grep -F 'no_surprise_network_check telemetry=false update_pings=false crash_uploaders=false remote_flags=false hidden_network_api=false proof_boundary=static_source_scan' scripts/check_no_surprise_network.sh docs/NO_SURPRISE_NETWORK.md docs/KNOWN_LIMITATIONS.md >/dev/null
grep -F -- '- [x] limitations current' ROADMAP.md >/dev/null
grep -F -- '- [x] changelog has alpha note' ROADMAP.md >/dev/null
grep -F -- '- [x] license present' ROADMAP.md >/dev/null
grep -F -- '- [x] contributing/security docs present' ROADMAP.md >/dev/null
grep -F -- '- [x] public bug/dogfood issue templates and PR template present' ROADMAP.md docs/PUBLIC_ALPHA_PLAN.md >/dev/null
grep -F -- '- [x] local Git boundary and first public source baseline commit' ROADMAP.md docs/PUBLIC_ALPHA_PLAN.md >/dev/null
grep -F -- '- [x] draft public source-alpha release notes' ROADMAP.md >/dev/null
grep -F -- '- [x] bounded public-source-alpha gate: `./scripts/public_alpha_verify.sh`' ROADMAP.md docs/PUBLIC_ALPHA_PLAN.md >/dev/null
grep -F -- '- [x] Dogfood runbook' ROADMAP.md >/dev/null
grep -F 'Detailed runbook: `docs/DOGFOOD_RUNBOOK.md`.' docs/PUBLIC_ALPHA_PLAN.md >/dev/null
grep -F '[`DOGFOOD_RUNBOOK.md`](DOGFOOD_RUNBOOK.md)' docs/DOGFOOD_LOG.md >/dev/null
grep -F 'Do not count:' docs/DOGFOOD_RUNBOOK.md >/dev/null
grep -F './scripts/dogfood_status.sh' README.md docs/DOGFOOD_RUNBOOK.md docs/PUBLIC_ALPHA_PLAN.md >/dev/null
dogfood_status_output=$(./scripts/dogfood_status.sh)
printf '%s\n' "$dogfood_status_output" | grep -F 'counted_sessions=0 not_counted_sessions=2 five_sessions=false four_pane=false agent_cli=false nocted_real_edit=false foreground_close_confirmation=false' >/dev/null
grep -F 'draft public source-alpha release notes in `docs/PUBLIC_ALPHA_RELEASE_NOTES.md`' docs/PUBLIC_ALPHA_PLAN.md >/dev/null
grep -F 'go/no-go sheet in `docs/PUBLIC_ALPHA_GO_NO_GO.md`' docs/PUBLIC_ALPHA_PLAN.md >/dev/null
grep -F -- '- [x] public alpha go/no-go sheet' ROADMAP.md >/dev/null
grep -F 'Status: **no-go for public alpha announcement** until real counted dogfood exists.' docs/PUBLIC_ALPHA_GO_NO_GO.md >/dev/null
grep -F 'gate is not claimed green until it completes outside the short agent timeout.' docs/PUBLIC_ALPHA_RELEASE_NOTES.md >/dev/null
grep -F 'dogfood_status counted_sessions=0 not_counted_sessions=2 five_sessions=false four_pane=false agent_cli=false nocted_real_edit=false foreground_close_confirmation=false' docs/PUBLIC_ALPHA_RELEASE_NOTES.md >/dev/null
grep -F 'The formerly empty `.git` marker has been replaced with a real local Git boundary and first public source baseline commit.' MEMORY.md >/dev/null
grep -F 'GitHub issue templates are provided for ordinary bugs and alpha dogfood reports.' CONTRIBUTING.md >/dev/null
grep -F 'Do not file public issues for vulnerabilities' .github/ISSUE_TEMPLATE/config.yml >/dev/null
grep -F -- '- [x] package/signing status is clearly marked incomplete if not done' ROADMAP.md >/dev/null
grep -F -- '- [x] fast build/check path confirmed from a clean source copy' ROADMAP.md >/dev/null
grep -F -- '- [x] build/run instructions tested from a clean source copy' docs/PUBLIC_ALPHA_PLAN.md >/dev/null
grep -F 'Product status: the 0.1.0 Plasma and Noctalia behavior scope plus local release-source evidence contracts are implemented and verified as of 2026-07-18.' docs/TECHNICAL_STATUS.md >/dev/null
grep -F '### NCT-050 System-tray context menu and clean close — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-051 Yakuake-style main-window controls — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-052 Frictionless inline tab rename — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-053 Native button hover affordances — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-054 Yakuake-density compact tabs — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-055 Peacock-style per-tab color accents — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-056 Direct pane and Smart Tab keyboard cycling — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-057 Settings window stacking — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-058 Hold-Alt workspace-note overlays — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-059 Crash-safe hot-session recovery — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-060 Alt-wheel pane cycling feedback — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-061 Ctrl+Alt-wheel tab cycling feedback — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-062 Pane-local terminal control chords — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-063 Live Grid Layout Presets — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-064 Tab chrome contrast and close affordances — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-065 New-tab shortcut and accessible labeling — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-066 Embedded-editor clean/dirty Save state — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-067 Embedded-editor Ctrl+S atomic writeback — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-068 Unsaved editor transition guards — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-069 Whole-application unsaved-editor close guard — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-070 Graceful editor-aware shutdown routing — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-071 Rendered editor-shutdown route matrix — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-072 Exact-pane native profile selection — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-073 Live resolved-profile application and isolation — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-074 Rendered profile preset and persistence matrix — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-075 Dual-build reproducibility, version/date coherence, and scratch cleanup — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-076 Architecture-self-sufficient pinned release workflow — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-077 Honest package receipts and dependency provenance — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-078 Release-operations evidence guard — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-079 Release-operations missing-evidence diagnostics — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-080 Semantic release-evidence validation — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-081 Release-evidence scaffold templates — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-082 Architecture artifact intake guard — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-083 Signature intake guard — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-084 Publication and redistribution receipt intake guard — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-085 Compositor and Wayland HID acceptance intake guard — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-086 Native VT scrollback ring-retention polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-087 Quick-note overlay allocation polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-088 Native tick-path no-op update polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-089 Native idle-redraw suppression polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-090 Quick-note overlay font-cache polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-091 Quick-note overlay bounded-preview polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-092 Compact-tab setter dedupe polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-093 Pane status tooltip dedupe polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-094 Tab-color CSS provider dedupe polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-095 Compact-tab suffix allocation polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-096 Native performance and memory polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-097 Native leak and allocator-pressure hardening — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-098 Native allocation polish — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-099 Native deep performance and memory hardening — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-100 Reproducible split-terminal benchmark and bounded PTY drain — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-101 Native output throughput hardening — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-102 Event-driven PTY scheduling and benchmark isolation — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-103 Standalone NoctEd foundation — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-104 NoctEd daily-editing workflow parity — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-107 NoctEd configurable folding and minimap legibility — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-108 NoctEd project search and multi-file controls — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-109 Agent-session lifecycle and idle-scheduling hardening — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-113 Native pointer-driven tab reorder hardening — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-114 NoctEd new-file, Save As, and quick-open workflows — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-115 Yakuake-style active-pane information and metadata boundary — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-116 Root-coalesced descriptor fallback and source ownership — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-117 Runtime boundary, incremental editor work, and damage rendering — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-118 Bounded resource ownership and dirty-row rendering — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-120 Stable terminal lines and compact scrollback — done' BACKLOG_ARCHIVE.md >/dev/null
! grep -F '### NCT-072 ' BACKLOG.md >/dev/null
! grep -F '### NCT-073 ' BACKLOG.md >/dev/null
! grep -F '### NCT-074 ' BACKLOG.md >/dev/null
! grep -F '### NCT-075 ' BACKLOG.md >/dev/null
! grep -F '### NCT-076 ' BACKLOG.md >/dev/null
! grep -F '### NCT-077 ' BACKLOG.md >/dev/null
! grep -F '### NCT-078 ' BACKLOG.md >/dev/null
! grep -F '### NCT-079 ' BACKLOG.md >/dev/null
! grep -F '### NCT-080 ' BACKLOG.md >/dev/null
! grep -F '### NCT-081 ' BACKLOG.md >/dev/null
! grep -F '### NCT-082 ' BACKLOG.md >/dev/null
! grep -F '### NCT-083 ' BACKLOG.md >/dev/null
! grep -F '### NCT-084 ' BACKLOG.md >/dev/null
! grep -F '### NCT-085 ' BACKLOG.md >/dev/null
! grep -F '### NCT-086 ' BACKLOG.md >/dev/null
! grep -F '### NCT-087 ' BACKLOG.md >/dev/null
! grep -F '### NCT-088 ' BACKLOG.md >/dev/null
! grep -F '### NCT-089 ' BACKLOG.md >/dev/null
! grep -F '### NCT-090 ' BACKLOG.md >/dev/null
! grep -F '### NCT-091 ' BACKLOG.md >/dev/null
! grep -F '### NCT-092 ' BACKLOG.md >/dev/null
! grep -F '### NCT-093 ' BACKLOG.md >/dev/null
! grep -F '### NCT-094 ' BACKLOG.md >/dev/null
! grep -F '### NCT-095 ' BACKLOG.md >/dev/null
! grep -F '### NCT-096 ' BACKLOG.md >/dev/null
! grep -F '### NCT-097 ' BACKLOG.md >/dev/null
! grep -F '### NCT-098 ' BACKLOG.md >/dev/null
! grep -F '### NCT-099 ' BACKLOG.md >/dev/null
! grep -F '### NCT-100 ' BACKLOG.md >/dev/null
! grep -F '### NCT-101 ' BACKLOG.md >/dev/null
! grep -F '### NCT-102 ' BACKLOG.md >/dev/null
! grep -F '### NCT-103 ' BACKLOG.md >/dev/null
! grep -F '### NCT-104 ' BACKLOG.md >/dev/null
! grep -F '### NCT-107 ' BACKLOG.md >/dev/null
! grep -F '### NCT-108 ' BACKLOG.md >/dev/null
! grep -F '### NCT-109 ' BACKLOG.md >/dev/null
! grep -F '### NCT-113 ' BACKLOG.md >/dev/null
! grep -F '### NCT-114 ' BACKLOG.md >/dev/null
! grep -F '### NCT-115 ' BACKLOG.md >/dev/null
! grep -F '### NCT-116 ' BACKLOG.md >/dev/null
! grep -F '### NCT-117 ' BACKLOG.md >/dev/null
! grep -F '### NCT-118 ' BACKLOG.md >/dev/null
! grep -F '### NCT-120 ' BACKLOG.md >/dev/null
! grep -F '### NCT-105 ' BACKLOG.md >/dev/null
grep -F '### NCT-105 NoctEd syntax ecosystem compatibility — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F '### NCT-106 NoctEd stability and resource qualification — partial' BACKLOG.md >/dev/null
grep -F '### NCT-110 Modern VT and agent-TUI compatibility — partial' BACKLOG.md >/dev/null
grep -F '### NCT-111 Daily-driver session continuity and launch profiles — partial' BACKLOG.md >/dev/null
grep -F '### NCT-112 Terminal stability and agent-resource qualification — partial' BACKLOG.md >/dev/null
grep -F '### NCT-119 Terminal presentation latency and draw allocation — partial' BACKLOG.md >/dev/null
grep -F '### NCT-121 NoctEd shared worktree index and external-change engine — partial' BACKLOG.md >/dev/null
grep -F '### NCT-122 NoctEd search latency and filesystem admission — partial' BACKLOG.md >/dev/null
for id in 106 110 111 112 119 121 122; do
  grep -F "| NCT-$id |" BACKLOG.md >/dev/null
done
grep -F '| Release operations |' BACKLOG.md >/dev/null
for document in docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/TECHNICAL_STATUS.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/NOCTED.md docs/DAILY_DRIVER.md; do
  grep -F 'performance_algorithm_research=true' "$document" >/dev/null
done
for marker in \
  terminal_frame_clock=implemented \
  terminal_glyph_cache=implemented \
  terminal_resize_coalescing=implemented \
  terminal_sync_output=implemented \
  terminal_logical_lines=implemented \
  terminal_gpu_rewrite=deferred \
  terminal_per_pane_threads=deferred \
  nocted_shared_index=implemented \
  nocted_search_streaming=implemented \
  nocted_worker_priority=implemented \
  nocted_custom_rope=deferred \
  nocted_tree_sitter_default=false; do
  grep -F "$marker" docs/PERFORMANCE_ALGORITHM_RESEARCH.md >/dev/null
done
grep -F 'test "terminal grid caps scrollback without shifting retained history"' src/terminal/Vt.zig >/dev/null
grep -F 'scrollback_ring=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'note_overlay_cached=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'note_overlay_font_cached=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'note_overlay_preview_bounded=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'tab_setter_dedup=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'pane_tooltip_dedup=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'tab_color_style_dedup=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'tab_suffix_stack=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'native_perf_memory_polish=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'native_memory_leak_hardening=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'native_allocation_polish=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'syntax_theme_parse_deinit=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'git_parse_cap_before_alloc=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'smart_filter_label_stack=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'terminal_find_status_stack=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'editor_find_prereserved=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
for marker in \
  native_deep_memory_hardening=true \
  scrollback_lazy_growth=true \
  alternate_resize_safe=true \
  packed_cell_render=true \
  blank_cell_draw_skipped=true \
  idle_metadata_probe_suppressed=true \
  idle_exit_poll_throttled=true \
  native_host_callback_cleanup=true \
  tree_sitter_capture_stack=true \
  editor_find_lazy_reserve=true \
  literal_paste_single_pass=true \
  paste_session_allocator=true; do
  for document in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md; do
    grep -F "$marker" "$document" >/dev/null
  done
done
grep -F 'tick_noop_dedup=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'idle_redraw_suppressed=true' docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
for marker in split_terminal_benchmark=true yakuake_excluded=true process_tree_pss=true pty_pump_bounded_drain=true; do
  for document in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_BENCHMARK.md; do
    grep -F "$marker" "$document" >/dev/null
  done
done
for marker in native_output_throughput=true visible_grid_ring=true vt_ascii_run=true; do
  for document in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_BENCHMARK.md; do
    grep -F "$marker" "$document" >/dev/null
  done
done
for marker in pty_event_source=true timer_read_polling=false output_present_coalesced=true event_source_cleanup=true benchmark_order_isolated=true wezterm_split_ready=true; do
  for document in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_BENCHMARK.md; do
    grep -F "$marker" "$document" >/dev/null
  done
done
for marker in foreground_guard=true session_storage_released=true late_callback_guard=true popup_teardown=true root_timer_coalesced=true hidden_present_throttled=true mapped_redraw_only=true; do
  for document in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/DAILY_DRIVER.md; do
    grep -F "$marker" "$document" >/dev/null
  done
done
for marker in descriptor_fallback=root_coalesced pane_exit_timers=0 source_cleanup=centralized; do
  for document in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/DAILY_DRIVER.md docs/TERMINAL_BENCHMARK.md; do
    grep -F "$marker" "$document" >/dev/null
  done
done
for marker in render_abi=packed_rows render_abi_version=2 damage_tracking=dirty_spans glyph_batching=true glyph_cache=true frame_clock_present=true; do
  for document in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md; do
    grep -F "$marker" "$document" >/dev/null
  done
done
for document in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/ARCHITECTURE.md docs/NOCTED.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md; do
  grep -F 'nocted_worker=bounded' "$document" >/dev/null
done
for marker in tab_reorder_pointer_drag=true tab_reorder_active_identity=true tab_reorder_rollback=true tab_reorder_persistence_coalesced=true; do
  for document in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md; do
    grep -F "$marker" "$document" >/dev/null
  done
done
for document in BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_BENCHMARK.md; do
  grep -F 'writer_median_ms=66' "$document" >/dev/null
done
for document in BACKLOG_ARCHIVE.md CHANGELOG.md docs/NATIVE_HOST.md docs/RELEASE_CHECKLIST.md; do
  grep -F 'pane_close_menu_popdown=true' "$document" >/dev/null
done
test -x scripts/terminal_benchmark.sh
test -x scripts/terminal_benchmark_workload.sh
test -x scripts/process_tree_memory.sh
bash -n scripts/terminal_benchmark.sh
sh -n scripts/terminal_benchmark_workload.sh
bash -n scripts/process_tree_memory.sh
grep -F 'usage: %s PID [--details]' scripts/process_tree_memory.sh >/dev/null
grep -F '/proc/$pid/smaps_rollup' scripts/process_tree_memory.sh >/dev/null
grep -F 'pss_mib=' scripts/process_tree_memory.sh >/dev/null
grep -F '3 callbacks per second' docs/DAILY_DRIVER.md >/dev/null
grep -F 'https://learn.chatgpt.com/docs/config-file/config-sample' docs/DAILY_DRIVER.md >/dev/null
grep -F 'https://code.claude.com/docs/en/troubleshooting' docs/DAILY_DRIVER.md >/dev/null
grep -F 'https://antigravity.google/docs/cli-settings' docs/DAILY_DRIVER.md >/dev/null
grep -F 'No Yakuake process, window, D-Bus endpoint, or session was controlled' docs/DAILY_DRIVER.md >/dev/null
grep -F 'terminals=${NOCTTY_BENCH_TERMINALS:-"noctty konsole kitty wezterm terminator ghostty"}' scripts/terminal_benchmark.sh >/dev/null
grep -F 'yakuake_before=$(pgrep -x yakuake' scripts/terminal_benchmark.sh >/dev/null
grep -F '[[ "$yakuake_before" == "$yakuake_after" ]] || die "yakuake_process_set_changed"' scripts/terminal_benchmark.sh >/dev/null
grep -F 'konsole_service="org.kde.konsole-$launch_pid"' scripts/terminal_benchmark.sh >/dev/null
! grep -F 'org.kde.yakuake' scripts/terminal_benchmark.sh >/dev/null
grep -F 'wezterm_log="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wezterm/wezterm-gui-log-$launch_pid.txt"' scripts/terminal_benchmark.sh >/dev/null
grep -F 'rm -f -- "$wezterm_socket" "$wezterm_log"' scripts/terminal_benchmark.sh >/dev/null
grep -F 'inter_trial_settle_ms=${NOCTTY_BENCH_INTER_TRIAL_SETTLE_MS:-1000}' scripts/terminal_benchmark.sh >/dev/null
grep -F 'terminal_order=rotated_snake' scripts/terminal_benchmark.sh >/dev/null
grep -F 'wait_for_count "$NOCTTY_BENCH_RUN_DIR" spawned "$expected" 5000 ||' scripts/terminal_benchmark.sh >/dev/null
grep -F 'if (std.mem.eql(u8, cmd, "--native-grid-benchmark")) {' src/main.zig >/dev/null
grep -F 'const max_pump_bytes = 128 * 1024;' src/terminal/Session.zig >/dev/null
grep -F 'const output_buffer_bytes = 16 * 1024;' src/terminal/Session.zig >/dev/null
grep -F 'test "terminal session pump drains PTY bytes to a bounded per-tick budget"' src/terminal/Session.zig >/dev/null
grep -F 'test "terminal grid printable run path matches byte feeding"' src/terminal/Vt.zig >/dev/null
grep -F 'test "terminal grid rotates full-screen rows and blends viewport history"' src/terminal/Vt.zig >/dev/null
grep -F 'export fn noctty_grid_pty_fd' src/main.zig >/dev/null
grep -F 'context->pty_source = g_unix_fd_add_full(' src/gui/native_grid_host.c >/dev/null
grep -F 'context->output_present_source = gtk_widget_add_tick_callback(' src/gui/native_grid_host.c >/dev/null
grep -F 'G_PRIORITY_DEFAULT, 100, on_output_present, context, NULL);' src/gui/native_grid_host.c >/dev/null
grep -F 'context->descriptor_tick_coalesced = 1;' src/gui/native_grid_host.c >/dev/null
grep -F 'context->tick_source = g_timeout_add(16, on_tick, context);' src/gui/native_grid_host.c >/dev/null
grep -F 'root->descriptor_maintenance_fallback_seen = 1;' src/gui/native_grid_host.c >/dev/null
grep -F 'static void stop_grid_io_sources(NocttyGridContext *context) {' src/gui/native_grid_host.c >/dev/null
grep -F 'static void stop_grid_context_sources(NocttyGridContext *context) {' src/gui/native_grid_host.c >/dev/null
test "$(grep -Fc 'remove_grid_source(&context->pty_source);' src/gui/native_grid_host.c)" -eq 1
grep -F 'static void remove_output_present(NocttyGridContext *context) {' src/gui/native_grid_host.c >/dev/null
grep -F 'gtk_widget_remove_tick_callback(' src/gui/native_grid_host.c >/dev/null
! grep -F 'context->pty_source != 0 ? 1000 : 16' src/gui/native_grid_host.c >/dev/null
grep -F 'candidate->descriptor_tick_coalesced &&' src/gui/native_grid_host.c >/dev/null
grep -F 'gboolean io_ready = TRUE;' src/gui/native_grid_host.c >/dev/null
grep -F 'descriptor_fallback=root_coalesced pane_exit_timers=0 periodic_callbacks_per_second=3' src/main.zig scripts/native_grid_eight_pane_smoke.sh >/dev/null
grep -F 'descriptor_fallback=root_coalesced pane_exit_timer=false source_cleanup=centralized' src/main.zig scripts/native_grid_maintenance_smoke.sh >/dev/null
grep -F 'xdotool windowactivate --sync "$window"' scripts/native_grid_tab_reorder_smoke.sh >/dev/null
grep -F 'xdotool getactivewindow' scripts/native_grid_tab_reorder_smoke.sh >/dev/null
grep -F 'xdotool mousemove --sync --window "$window"' scripts/native_grid_tab_reorder_smoke.sh >/dev/null
grep -F 'grid_context_session_available' src/gui/native_grid_host.c >/dev/null
grep -F 'context->retiring = 1;' src/gui/native_grid_host.c >/dev/null
grep -F 'candidate->retiring = 1;' src/gui/native_grid_host.c >/dev/null
grep -F 'context->clipboard_requests++;' src/gui/native_grid_host.c >/dev/null
grep -F 'probe_retired_tab_callback' src/gui/native_grid_host.c >/dev/null
grep -F 'context.late_callback_guarded &&' src/gui/native_grid_host.c >/dev/null
grep -F 'dismiss_grid_popup_windows' src/gui/native_grid_host.c >/dev/null
grep -F 'gtk_window_get_window_type(GTK_WINDOW(window))' src/gui/native_grid_host.c >/dev/null
grep -F 'G_DEBUG=fatal-warnings' scripts/native_grid_hot_session_smoke.sh >/dev/null
grep -F 'popup_teardown=true' scripts/native_grid_hot_session_smoke.sh >/dev/null
grep -F 'pty_event_source=true' scripts/native_grid_two_pane_smoke.sh >/dev/null
grep -F 'pty_event_source=true' scripts/native_grid_pane_close_smoke.sh >/dev/null
grep -F 'G_DEBUG=fatal-warnings' scripts/native_grid_pane_close_smoke.sh >/dev/null
grep -F 'menu_popdown=true' scripts/native_grid_pane_close_smoke.sh >/dev/null
grep -F 'gtk_widget_get_ancestor(item, GTK_TYPE_MENU);' src/gui/native_grid_host.c >/dev/null
grep -F 'gtk_menu_popdown(GTK_MENU(menu));' src/gui/native_grid_host.c >/dev/null
! grep -F 'on_pump_idle' src/gui/native_grid_host.c >/dev/null
test -s benchmarks/terminal-comparison-2026-07-15-raw.csv
test -s benchmarks/terminal-comparison-2026-07-15-summary.csv
test -s benchmarks/terminal-comparison-2026-07-15-metadata.txt
test -s benchmarks/terminal-comparison-2026-07-15-pre-pump-fix-summary.csv
test -s benchmarks/terminal-comparison-2026-07-15-pre-active-output-summary.csv
test -s benchmarks/terminal-comparison-2026-07-15-pre-event-source-summary.csv
grep -F 'noctty,0.1.0,4,176,177,177,33.596,85.434,0.000,66,100.569' benchmarks/terminal-comparison-2026-07-15-summary.csv >/dev/null
grep -F 'noctty,0.1.0,4,162,900,961,31.044,85.566,0.928,7129,0.931' benchmarks/terminal-comparison-2026-07-15-pre-pump-fix-summary.csv >/dev/null
grep -F 'noctty,0.1.0,4,161,184,184,30.994,85.531,0.000,318,20.873' benchmarks/terminal-comparison-2026-07-15-pre-active-output-summary.csv >/dev/null
grep -F 'noctty,0.1.0,4,155,170,583,33.709,85.734,0.945,80,82.970' benchmarks/terminal-comparison-2026-07-15-pre-event-source-summary.csv >/dev/null
grep -F 'yakuake_untouched=true' benchmarks/terminal-comparison-2026-07-15-metadata.txt >/dev/null
grep -F 'inter_trial_settle_ms=1000 terminal_order=rotated_snake' benchmarks/terminal-comparison-2026-07-15-metadata.txt >/dev/null
grep -F 'The current 66 ms median is 17.5 percent faster' docs/TERMINAL_BENCHMARK.md >/dev/null
grep -F 'gchar *note_overlay_label;' src/gui/native_grid_host.c >/dev/null
grep -F 'const size_t capacity = 4096' src/gui/native_grid_host.c >/dev/null
grep -F 'contents, capacity, 1)' src/gui/native_grid_host.c >/dev/null
grep -F 'if (format_raw != 0) {' src/main.zig >/dev/null
grep -F 'const preview_len = @min(note.len, second_len);' src/main.zig >/dev/null
grep -F '"noctty-tab-markup-cache"' src/gui/native_grid_host.c >/dev/null
grep -F '"noctty-tab-tooltip-cache"' src/gui/native_grid_host.c >/dev/null
grep -F '"noctty-tab-color-active"' src/gui/native_grid_host.c >/dev/null
grep -F 'if (g_strcmp0(cached_markup, markup) != 0)' src/gui/native_grid_host.c >/dev/null
grep -F 'if (g_strcmp0(cached_tooltip, tooltip) != 0)' src/gui/native_grid_host.c >/dev/null
grep -F 'if (cached_rgb == rgb && (rgb == 0 || cached_active == is_active))' src/gui/native_grid_host.c >/dev/null
grep -F 'const gchar *title_ellipsis = title_prefix != NULL ? "…" : "";' src/gui/native_grid_host.c >/dev/null
grep -F 'char selection_suffix[64] = {0};' src/gui/native_grid_host.c >/dev/null
grep -F 'char pane_suffix[32] = {0};' src/gui/native_grid_host.c >/dev/null
grep -F 'char tab_color_tooltip[96] = {0};' src/gui/native_grid_host.c >/dev/null
! grep -F 'g_strconcat(title_prefix, "…", NULL)' src/gui/native_grid_host.c >/dev/null
grep -F 'char text[384];' src/gui/native_grid_host.c >/dev/null
grep -F '"noctty-pane-tooltip-cache"' src/gui/native_grid_host.c >/dev/null
grep -F 'if (g_strcmp0(cached, text) != 0)' src/gui/native_grid_host.c >/dev/null
grep -F 'PangoFontDescription *note_overlay_font;' src/gui/native_grid_host.c >/dev/null
grep -F 'root->note_overlay_label == NULL' src/gui/native_grid_host.c >/dev/null
grep -F 'root->note_overlay_font = pango_font_description_from_string("Sans 9")' src/gui/native_grid_host.c >/dev/null
grep -F 'pango_layout_set_font_description(layout, root->note_overlay_font)' src/gui/native_grid_host.c >/dev/null
grep -F 'g_clear_pointer(&context.note_overlay_font, pango_font_description_free)' src/gui/native_grid_host.c >/dev/null
grep -F 'gtk_window_get_title(GTK_WINDOW(context->window))' src/gui/native_grid_host.c >/dev/null
grep -F 'if (status_changed) {' src/gui/native_grid_host.c >/dev/null
grep -F 'int pumped = context->pump(context->userdata)' src/gui/native_grid_host.c >/dev/null
grep -F 'uint32_t cursor = context->cursor(context->userdata);' src/gui/native_grid_host.c >/dev/null
grep -F 'int selected_face = -1;' src/gui/native_grid_host.c >/dev/null
grep -F 'if (context->event != NULL && (had_output || status_changed))' src/gui/native_grid_host.c >/dev/null
grep -F 'candidate->event(candidate->event_data, candidate->pane_id, 4, 0,' src/gui/native_grid_host.c >/dev/null
grep -F 'root->event(root->event_data, active->pane_id, 19, 0, now_ms);' src/gui/native_grid_host.c >/dev/null
grep -F '(void)pump_grid_context(candidate, &exited_now);' src/gui/native_grid_host.c >/dev/null
grep -F 'stop_grid_io_sources(candidate);' src/gui/native_grid_host.c >/dev/null
grep -F 'remove_grid_source(&context.application_close_deferred_source);' src/gui/native_grid_host.c >/dev/null
grep -F 'defer if (event != 2 and event != 4) persistNativeGridHotSession(bridge);' src/main.zig >/dev/null
grep -F '4 => .{ .tick = at_ms },' src/main.zig >/dev/null
grep -F 'pub const max_editor_undo_transactions: usize = 128;' src/editor/TextBuffer.zig >/dev/null
grep -F 'trimTransactions(&self.undo_stack, self.allocator);' src/editor/TextBuffer.zig >/dev/null
grep -F 'advanceLineColumn(request.contents[idx .. idx + request.query.len]' src/editor/TextBuffer.zig >/dev/null
grep -F 'if (std.mem.eql(u8, basename, "vendor")) return true;' src/workspace/ProjectScan.zig >/dev/null
grep -F 'destroy_retired_grid_context' src/gui/native_grid_host.c >/dev/null
grep -F 'g_ptr_array_remove(root->contexts, context);' src/gui/native_grid_host.c >/dev/null
grep -F 'history_cells: []Cell,' src/terminal/Vt.zig >/dev/null
grep -F 'fn historySlot(self: Grid, slot: usize) []Cell' src/terminal/Vt.zig >/dev/null
grep -F 'const hot_history_lines = 256;' src/terminal/Vt.zig >/dev/null
grep -F 'fn maybeCompactColdHistory(self: *Grid, force: bool) !void {' src/terminal/Vt.zig >/dev/null
grep -F 'const initial_history_lines = 32;' src/terminal/Vt.zig >/dev/null
grep -F 'pub const max_history_lines = 100_000;' src/terminal/Vt.zig >/dev/null
grep -F 'const max_cached_find_matches = 1024;' src/terminal/Vt.zig >/dev/null
grep -F 'pub fn packedCell(self: Grid, column: usize, row: usize) u64' src/terminal/Vt.zig >/dev/null
grep -F 'test "terminal grid grows its bounded scrollback slab lazily"' src/terminal/Vt.zig >/dev/null
grep -F 'test "terminal grid reuses row-stable history and resizes both alternate screens"' src/terminal/Vt.zig >/dev/null
grep -F 'test "terminal grid preserves logical scrollback across column changes"' src/terminal/Vt.zig >/dev/null
grep -F 'test "terminal grid applies bounded scrollback limits without retaining excess slabs"' src/terminal/Vt.zig >/dev/null
grep -F 'test "terminal grid reports and clears terminal-owned dirty rows"' src/terminal/Vt.zig >/dev/null
grep -F 'test "terminal grid survives malformed control streams during resize churn"' src/terminal/Vt.zig >/dev/null
grep -F 'pub const max_scrollback_lines: u32 = 100_000;' src/config/Config.zig >/dev/null
grep -F 'scrollback_lines: u32 = 1000,' src/config/Config.zig >/dev/null
grep -F 'scrollback=256 scrollback_live=true' src/main.zig >/dev/null
for path in scripts/native_grid_settings_smoke.sh scripts/native_grid_hidpi_theme_smoke.sh; do
  grep -F 'scrollback=256 scrollback_live=true' "$path" >/dev/null
done
grep -F "expected='native_grid_notification_smoke tooltip=true status_border=true dbus=true delivered=true exited=true'" scripts/native_grid_notification_smoke.sh >/dev/null
grep -F 'max_attempts=3' scripts/native_grid_notification_smoke.sh >/dev/null
grep -F -- '--native-grid-notification-smoke 2>&1 || true' scripts/native_grid_notification_smoke.sh >/dev/null
grep -F 'fn applySingleEditFast(self: *TextBuffer, edit: TextEdit) !bool' src/editor/TextBuffer.zig >/dev/null
grep -F 'if (matches.items.len == 0) {' src/editor/TextBuffer.zig >/dev/null
grep -F 'const absent = try buffer.findAllAlloc(std.testing.failing_allocator, "missing", .{});' src/editor/TextBuffer.zig >/dev/null
grep -F 'var captures: [TextBuffer.max_syntax_highlight_spans]c.NocttyTreeSitterCapture = undefined;' src/editor/TreeSitter.zig >/dev/null
grep -F 'syntax_document: ?TreeSitter.Document = null,' src/app/App.zig >/dev/null
grep -F 'fn highlightEditorSyntax(self: *App, request: Editor.SyntaxHighlightRequest)' src/app/App.zig >/dev/null
grep -F 'pub fn importTokenColorsAlloc(allocator: std.mem.Allocator, name: []const u8, contents: []const u8) !SyntaxTheme' src/editor/SyntaxTheme.zig >/dev/null
grep -F 'var parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch {' src/editor/SyntaxTheme.zig >/dev/null
grep -F 'defer parsed.deinit();' src/editor/SyntaxTheme.zig >/dev/null
grep -F 'if (entries.items.len >= max_entries) {' src/workspace/ProjectScan.zig >/dev/null
grep -F 'if (nodes.items.len >= max_entries) {' src/workspace/ProjectScan.zig >/dev/null
grep -F 'test "project scan checks git caps before cloning overflow records"' src/workspace/ProjectScan.zig >/dev/null
grep -F 'char label[256];' src/gui/native_grid_host.c >/dev/null
grep -F 'const char *label_text = "Filter";' src/gui/native_grid_host.c >/dev/null
grep -F 'char status[96];' src/gui/native_grid_host.c >/dev/null
grep -F 'g_snprintf(status, sizeof(status), "%zu / %d' src/gui/native_grid_host.c >/dev/null
grep -F 'typedef uint64_t (*NocttyGridCell)(void *, int, int);' src/gui/native_grid_abi.h >/dev/null
grep -F 'typedef int (*NocttyGridDirtyRows)(void *, uint8_t *, size_t);' src/gui/native_grid_abi.h >/dev/null
grep -F 'uint64_t packed_cell =' src/gui/native_grid_host.c >/dev/null
grep -F "if ((style & 128) == 0 && codepoint >= 0x20 && codepoint != ' ')" src/gui/native_grid_host.c >/dev/null
grep -F 'if (had_output || !context->terminal_metadata_initialized)' src/gui/native_grid_host.c >/dev/null
grep -F 'now_us - context->last_exit_poll_us >= 250 * 1000' src/gui/native_grid_host.c >/dev/null
grep -F 'created->terminal_metadata_initialized = 0;' src/gui/native_grid_host.c >/dev/null
grep -F 'g_signal_connect(preset_combo, "changed", G_CALLBACK(on_preset_changed), context);' src/gui/native_host.c >/dev/null
! grep -F 'G_CALLBACK(on_preset_changed), &context);' src/gui/native_host.c >/dev/null
grep -F 'gchar *name = gtk_combo_box_text_get_active_text(combo);' src/gui/native_host.c >/dev/null
grep -F 'g_free(name);' src/gui/native_host.c >/dev/null
grep -F 'static void on_shortcut_dialog_destroy' src/gui/native_host.c >/dev/null
grep -F 'clear_smoke_sources(&context);' src/gui/native_host.c >/dev/null
grep -F 'fn prepareLiteralPasteAlloc' src/terminal/Paste.zig >/dev/null
grep -F 'test "literal paste preparation uses one owned buffer"' src/terminal/Paste.zig >/dev/null
grep -F 'preparePasteAlloc(session.allocator' src/main.zig >/dev/null
grep -F 'defer prepared.deinit(session.allocator);' src/main.zig >/dev/null
grep -F 'test "text buffer applies common single edits without rebuilding whole buffer"' src/editor/TextBuffer.zig >/dev/null
grep -F 'test "app reuses tree-sitter documents for open editor syntax"' src/app/App.zig >/dev/null
grep -F 'if (had_output) queue_grid_output_when_ready(context);' src/gui/native_grid_host.c >/dev/null
grep -F 'if (status_changed) queue_grid_draw_when_mapped(context);' src/gui/native_grid_host.c >/dev/null
grep -F 'Product-behavior and local release-source baseline: 0.1.0' docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'supported_renderer=zig_grid' scripts/ghostty_abi_smoke.sh >/dev/null
grep -F 'NCT-019 Live Terminal Resize Dimensions — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F 'NCT-020 Yakuake-style Settings Window — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F 'NCT-021 Free Window Resize And Native Tray — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F 'NCT-022 Ctrl+Wheel Font Scaling — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F 'NCT-023 Context-menu Embedded Editor And Focus-loss Safety — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F 'NCT-024 Right-click Tab Close — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F 'NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings' scripts/native_grid_pane_close_smoke.sh >/dev/null
grep -F 'NCT-025 Persistent New-tab Button — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F 'NCT-026 Pane-context Terminal Close — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F 'NCT-063 Live Grid Layout Presets — done' BACKLOG_ARCHIVE.md >/dev/null
grep -F 'categories=3 page_switch=true' scripts/native_grid_settings_smoke.sh >/dev/null
grep -F 'toolbar=true settings_button=true close_button=true order=yakuake button_pointer=true button_tooltips=true settings_activated=true close_activated=true session_stopped=true' scripts/native_grid_settings_smoke.sh >/dev/null
grep -F 'launch_profile=true launch_kind=command launch_shell=/bin/sh launch_cwd=/tmp launch_env=2 launch_scrollback=2048 launch_atomic=true launch_persisted=true launch_runtime=true' scripts/native_grid_settings_smoke.sh >/dev/null
grep -F 'launch_library=true launch_profiles=1 launch_named=true launch_saved=true launch_selected=true launch_deleted=true' scripts/native_grid_settings_smoke.sh >/dev/null
grep -F 'launch_continuity_controls=true launch_tmux=true launch_zellij=true' scripts/native_grid_settings_smoke.sh scripts/native_grid_hidpi_theme_smoke.sh >/dev/null
grep -F 'launch_library=true launch_profiles=1 launch_named=true launch_saved=true launch_selected=true launch_deleted=true' scripts/native_grid_hidpi_theme_smoke.sh >/dev/null
grep -F 'native_grid_credentialed_ssh_smoke profile=true system_client=true system_server=true credential=publickey identity_isolated=true host_key=pinned transport=stdio_proxy network_bind=false remote_marker=true exited=true' scripts/native_grid_credentialed_ssh_smoke.sh >/dev/null
grep -F 'NOCTTY_SSH_SMOKE_TARGET=' scripts/native_grid_credentialed_ssh_smoke.sh >/dev/null
grep -F 'run_smoke ./scripts/native_grid_credentialed_ssh_smoke.sh' scripts/native_release_smoke.sh >/dev/null
grep -F 'credentialed_ssh=true settings_stacking=true' scripts/native_release_smoke.sh >/dev/null
grep -F 'const config_version: u8 = 9;' src/config/Storage.zig >/dev/null
grep -F 'config_v9=true atomic=true separate_process_policy=true' src/main.zig scripts/native_grid_workspace_activation_smoke.sh BACKLOG.md docs/WORKSPACE_ACTIVATION.md >/dev/null
grep -F 'mktemp -d "$repo_root/.noctty-workspace-activation.XXXXXX"' scripts/native_grid_workspace_activation_smoke.sh >/dev/null
grep -F 'tmux = 3,' src/terminal/LaunchProfile.zig >/dev/null
grep -F 'zellij = 4,' src/terminal/LaunchProfile.zig >/dev/null
grep -F 'execlp("tmux", "tmux", "new-session", "-A", "-s", argument,' src/terminal/pty.c >/dev/null
grep -F 'execlp("zellij", "zellij", "attach", "--create", argument,' src/terminal/pty.c >/dev/null
grep -F 'pub const max_recent_workspaces: usize = 8;' src/workspace/Activation.zig >/dev/null
grep -F 'if (std.mem.startsWith(u8, uri, "noctty://"))' src/workspace/Activation.zig >/dev/null
grep -F 'if (std.mem.startsWith(u8, uri, "file://"))' src/workspace/Activation.zig >/dev/null
grep -F 'Exec=noctty --open-uri %u' resources/com.noctty.NOCTTY.desktop >/dev/null
grep -F 'MimeType=x-scheme-handler/noctty;' resources/com.noctty.NOCTTY.desktop >/dev/null
grep -F 'set_launch_profile: LaunchProfile.Profile' src/app/App.zig >/dev/null
grep -F 'save_named_launch_profile:' src/app/App.zig >/dev/null
grep -F 'pub const max_named_profiles: usize = 8;' src/terminal/LaunchProfile.zig >/dev/null
grep -F 'pub const Library = struct {' src/terminal/LaunchProfile.zig >/dev/null
grep -F 'pub fn spawnProfile(' src/terminal/Session.zig >/dev/null
grep -F 'int noctty_pty_spawn_profile(' src/terminal/pty.c >/dev/null
grep -F 'static void on_settings_launch_apply(' src/gui/native_grid_host.c >/dev/null
grep -F 'static void on_settings_launch_save(' src/gui/native_grid_host.c >/dev/null
grep -F 'static void on_settings_launch_library_changed(' src/gui/native_grid_host.c >/dev/null
grep -F 'static void on_settings_launch_delete(' src/gui/native_grid_host.c >/dev/null
for document in docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/COMPACT_UX.md docs/DAILY_DRIVER.md docs/LAUNCH_PROFILES.md docs/RELEASE_CHECKLIST.md; do
  grep -F 'launch_runtime=true' "$document" >/dev/null
  grep -F 'launch_library=true' "$document" >/dev/null
done
for document in docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/COMPACT_UX.md docs/DAILY_DRIVER.md docs/LAUNCH_PROFILES.md docs/RELEASE_CHECKLIST.md; do
  grep -F 'credentialed_ssh=true' "$document" >/dev/null
done
grep -F 'tab_bar=true compact_tabs=true add_button=true' scripts/native_grid_two_tab_smoke.sh >/dev/null
grep -F 'font_wheel=true font_pane=true font_isolated=true plain_scroll=true font_workspace_persisted=true' scripts/native_grid_compact_ux_smoke.sh >/dev/null
grep -F 'context_menu=true menu_survived=true editor_here=true editor_binary=nocted editor_handoff=true editor_process_separate=true directory_listed=true directory_navigated=true compatibility_editor=true' scripts/native_grid_project_editor_smoke.sh >/dev/null
grep -F 'recent_control=true recent_persisted=true' scripts/native_grid_project_editor_smoke.sh >/dev/null
grep -F 'run_smoke ./scripts/native_grid_workspace_activation_smoke.sh' scripts/native_release_smoke.sh >/dev/null
grep -F 'workspace_activation=true recent_workspaces=true' scripts/native_release_smoke.sh docs/TECHNICAL_STATUS.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
test -s docs/WORKSPACE_ACTIVATION.md
test -x scripts/native_grid_workspace_activation_smoke.sh
test -x scripts/native_grid_installed_activation_smoke.sh
grep -F -- '--native-grid-installed-activation-fixture' src/main.zig >/dev/null
grep -F -- '--native-grid-recent-activation-smoke' src/main.zig >/dev/null
for document in scripts/native_grid_installed_activation_smoke.sh docs/WORKSPACE_ACTIVATION.md BACKLOG.md CHANGELOG.md docs/PITCH_AUDIT.md docs/DAILY_DRIVER.md docs/RELEASE_CHECKLIST.md; do
  grep -F 'native_grid_installed_activation_contract installed_desktop=true mime_registered=true exec_open_uri=true fixture_tabs=2 production_binary=true smoke_isolated=true scratch_scoped=true' "$document" >/dev/null
done
grep -F 'scratch_parent=${NOCTTY_INSTALLED_ACTIVATION_PARENT:-$repo_root}' scripts/native_grid_installed_activation_smoke.sh >/dev/null
grep -F -- '--cache-dir "$cache"' scripts/native_grid_installed_activation_smoke.sh >/dev/null
grep -F -- '--global-cache-dir "$global_cache"' scripts/native_grid_installed_activation_smoke.sh >/dev/null
grep -F 'native_grid_installed_activation_matrix backends=%s installed_desktop=true desktop_dispatch=true recent_child=true rendered=true controlled_exit=true scratch_clean=true' scripts/native_grid_installed_activation_smoke.sh >/dev/null
grep -F './scripts/native_grid_installed_activation_smoke.sh --contract-only' docs/TECHNICAL_STATUS.md docs/INSTALL.md >/dev/null
! grep -F 'run_smoke ./scripts/native_grid_installed_activation_smoke.sh' scripts/native_release_smoke.sh >/dev/null
grep -F 'zig build --global-cache-dir .zig-cache/global install smoke-binaries' scripts/native_grid_project_editor_smoke.sh >/dev/null
grep -F './scripts/native_grid_shortcut_live_smoke.sh)' scripts/native_release_smoke.sh >/dev/null
grep -F 'rm -f "$ready" "$activated" "$output"' scripts/native_grid_shortcut_live_smoke.sh >/dev/null
grep -F 'dirty_state=true save_state=true ctrl_s=true file_switch_cancel=true file_switch_save=true file_switch_discard=true close_cancel=true close_discard=true parent_mapped=true' src/main.zig scripts/native_grid_project_editor_smoke.sh >/dev/null
for path in src/nocted/root.zig src/nocted/main.zig src/nocted/gtk.zig \
  src/nocted/Document.zig src/nocted/Folding.zig src/nocted/ProjectIndex.zig \
  src/nocted/ProjectSearch.zig src/nocted/QuickOpen.zig \
  src/nocted/MultiSelection.zig src/nocted/Session.zig \
  src/nocted/FilesystemWorker.zig src/nocted/StabilityQualification.zig \
  src/nocted/Settings.zig src/nocted/SyntaxDiscovery.zig; do
  test -s "$path"
done
test -s docs/NOCTED_STABILITY_QUALIFICATION.md
test -s docs/NOCTED_CORE_ENDURANCE_QUALIFICATION.md
test -s docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md
test -x scripts/nocted_native_smoke.sh
test -x scripts/nocted_native_matrix.sh
test -x scripts/nocted_resource_qualification.sh
test -x scripts/nocted_state_recovery_qualification.sh
test -x scripts/nocted_fuzz_race_qualification.sh
test -x scripts/nocted_core_stability_qualification.sh
test -x scripts/nocted_core_endurance_qualification.sh
test -x scripts/terminal_compatibility_qualification.sh
test -x scripts/terminal_session_qualification.sh
test -x scripts/launch_continuity_qualification.sh
test -x scripts/native_grid_renderer_qualification.sh
test -x scripts/native_grid_pipeline_qualification.sh
test -x scripts/native_grid_resource_qualification.sh
test -x scripts/terminal_history_qualification.sh
bash -n scripts/nocted_resource_qualification.sh
bash -n scripts/nocted_state_recovery_qualification.sh
bash -n scripts/nocted_fuzz_race_qualification.sh
bash -n scripts/nocted_core_stability_qualification.sh
bash -n scripts/nocted_core_endurance_qualification.sh
bash -n scripts/terminal_compatibility_qualification.sh
bash -n scripts/terminal_session_qualification.sh
bash -n scripts/launch_continuity_qualification.sh
bash -n scripts/native_grid_renderer_qualification.sh
bash -n scripts/native_grid_pipeline_qualification.sh
bash -n scripts/native_grid_resource_qualification.sh
bash -n scripts/terminal_history_qualification.sh
grep -F 'nocted_resource_smoke pass=1 cycles=8 queue_cap=64' scripts/nocted_resource_qualification.sh >/dev/null
grep -F 'nocted_resource_qualification debug=true release_safe=true cycles=8 cancellation=true duplicate_open=true atomic_save_close=true queue_bounded=true scratch_clean=true' scripts/nocted_resource_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md docs/NOCTED.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'resource_parent=${NOCTED_RESOURCE_PARENT:-"$repo_root"}' scripts/nocted_resource_qualification.sh >/dev/null
grep -F 'scratch=$(mktemp -d "$resource_parent/.nocted-resource-qualification.XXXXXX")' scripts/nocted_resource_qualification.sh >/dev/null
grep -F -- '--global-cache-dir "$global_cache"' scripts/nocted_resource_qualification.sh >/dev/null
grep -F 'nocted_resource_backend backend=$backend debug=true release_safe=true native_search_load=true native_project_lifecycle=true process_tree_memory=true scratch_clean=true' scripts/nocted_resource_qualification.sh >/dev/null
grep -F './scripts/nocted_state_recovery_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'nocted_state_recovery_matrix debug=true release_safe=true legacy_shell_parser=true malformed_state_corpus=13 oversized_fallback=true interrupted_replace=true settings_atomic=true session_atomic=true scratch_clean=true' scripts/nocted_state_recovery_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md docs/NOCTED.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'void *tree_sitter_bash_external_scanner_create(void)' vendor/tree-sitter-bash/src/scanner.c >/dev/null
grep -F 'interrupted settings replacement preserves the previous state' src/nocted/Settings.zig >/dev/null
grep -F 'interrupted session replacement preserves the previous state' src/nocted/Session.zig >/dev/null
grep -F 'error.FileNotFound, error.StreamTooLong' src/nocted/Settings.zig src/nocted/Session.zig >/dev/null
grep -F 'optimized indirect-call type' vendor/tree-sitter/LICENSES.md >/dev/null
grep -F './scripts/nocted_fuzz_race_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'nocted_fuzz_race_matrix debug=true release_safe=true document_cases=256 grammar_cases=256 external_read_race=true stable_retry=true retry_cap=3 perpetual_churn_rejected=true scratch_clean=true' scripts/nocted_fuzz_race_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md docs/NOCTED.md docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'pub const max_stable_read_attempts: usize = 3;' src/nocted/Document.zig >/dev/null
grep -F 'external rewrite during read retries to one stable generation' src/nocted/Document.zig >/dev/null
grep -F 'continuous external churn stops at the stable-read cap' src/nocted/Document.zig >/dev/null
grep -F 'deterministic invalid-file corpus stays bounded and classified' src/nocted/Document.zig >/dev/null
grep -F 'deterministic TextMate mutation corpus rejects safely or stays bounded' src/nocted/TextMateGrammar.zig >/dev/null
grep -F 'error.DocumentChangedDuringRead' src/nocted/Document.zig >/dev/null
grep -F './scripts/nocted_core_stability_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'nocted-stability-binary' build.zig docs/ARCHITECTURE.md >/dev/null
grep -F 'allocator_residual_bytes={d} checkpoint_peak_active_bytes={d}' src/nocted/StabilityQualification.zig >/dev/null
grep -F 'if (accounting.total_requested_bytes != cycle_baseline_bytes)' src/nocted/StabilityQualification.zig >/dev/null
grep -F 'nocted_core_stability_matrix debug=true release_safe=true cycles=128 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_cycles=128 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true scratch_clean=true' scripts/nocted_core_stability_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md docs/NOCTED.md docs/NOCTED_STABILITY_QUALIFICATION.md docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'const max_cycles: usize = 512;' src/nocted/StabilityQualification.zig >/dev/null
grep -F 'cycles=${NOCTED_CORE_STABILITY_CYCLES:-128}' scripts/nocted_core_stability_qualification.sh >/dev/null
grep -F './scripts/nocted_core_endurance_qualification.sh' docs/TECHNICAL_STATUS.md docs/NOCTED_CORE_ENDURANCE_QUALIFICATION.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
endurance_matrix='nocted_core_endurance_matrix debug=true release_safe=true cycles_per_mode=512 total_cycles=1024 fixture_files=128 document_round_trip=true edit_fold=true project_scan=true project_search=true quick_open=true deterministic_ranking=true ranking_queries=3 ranking_evaluations=3072 grammar_conversion=true allocator_leak_free=true latency_percentiles=true process_memory=true duration_recorded=true scratch_clean=true'
for path in scripts/nocted_core_endurance_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md \
  CHANGELOG.md docs/ARCHITECTURE.md docs/NOCTED.md \
  docs/NOCTED_STABILITY_QUALIFICATION.md \
  docs/NOCTED_CORE_ENDURANCE_QUALIFICATION.md \
  docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md \
  docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/PITCH_AUDIT.md \
  docs/DAILY_DRIVER.md \
  docs/RELEASE_CHECKLIST.md; do
  grep -F "$endurance_matrix" "$path" >/dev/null
done
grep -F 'The complete two-mode run took 459 seconds.' docs/NOCTED_CORE_ENDURANCE_QUALIFICATION.md >/dev/null
grep -F 'It does not initialize GTK, exercise the two GLib worker lanes, publish result batches to a widget, draw through a compositor, cover varied real projects, or constitute a multi-hour/multi-day native GUI soak.' docs/NOCTED_CORE_ENDURANCE_QUALIFICATION.md >/dev/null
test -s src/nocted/WorkerQualification.zig
test -x scripts/nocted_worker_qualification.sh
bash -n scripts/nocted_worker_qualification.sh
grep -F './scripts/nocted_worker_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/NOCTED.md docs/NOCTED_WORKER_QUALIFICATION.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'nocted-worker-qualification-binary' build.zig docs/ARCHITECTURE.md >/dev/null
worker_matrix='nocted_worker_matrix debug=true release_safe=true shared_admission_policy=true generation_supersession=true shared_queue_cap=64 lane_queue_cap=32 cancelled_lane_excluded=true kind_cancel=true pending_lookup=true lazy_pool_creation=true transactional_enqueue=true append_failure_safe=true push_failure_rollback=true ordered_retirement=true glib_thread_pools=true worker_lanes=2 project_scan=true search_streaming=true snapshot_first=true cooperative_cancellation=true search_batch_size=24 search_batch_cap=2 backpressure_exercised=true foreground_save_under_backpressure=true worker_drained=true allocator_leak_free=true process_memory=true scratch_clean=true'
for path in scripts/nocted_worker_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md \
  CHANGELOG.md docs/ARCHITECTURE.md docs/NOCTED.md \
  docs/NOCTED_WORKER_QUALIFICATION.md \
  docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md \
  docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/PITCH_AUDIT.md \
  docs/DAILY_DRIVER.md docs/RELEASE_CHECKLIST.md; do
  grep -F "$worker_matrix" "$path" >/dev/null
done
grep -F 'This receipt executes the real lazy `GThreadPool` lifecycle, transactional list' docs/NOCTED_WORKER_QUALIFICATION.md >/dev/null
grep -F '`App.submitWorkerJob`, `cancelWorkerJobs`, `hasWorkerJob`, shutdown, and job' docs/NOCTED_WORKER_QUALIFICATION.md >/dev/null
grep -F 'const admission = filesystem_worker.admit(self.worker_jobs.items, job);' src/nocted/main.zig >/dev/null
grep -F 'worker_pools: filesystem_worker.Pools = .{},' src/nocted/main.zig >/dev/null
grep -F 'const pending_jobs = try filesystem_worker.enqueue(' src/nocted/main.zig >/dev/null
grep -F 'return filesystem_worker.detach(&self.worker_jobs, job);' src/nocted/main.zig >/dev/null
grep -F 'filesystem_worker.cancelKind(' src/nocted/main.zig >/dev/null
grep -F 'return filesystem_worker.hasKind(self.worker_jobs.items, kind);' src/nocted/main.zig >/dev/null
grep -F 'pub fn admit(pending: []const *Job, job: *Job) Admission {' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'pub const Pools = struct {' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'pub fn commitWith(' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'pub fn enqueue(' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'pub fn detach(pending: *std.array_list.Managed(*Job), job: *Job) bool {' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'shared_admission_policy=true generation_supersession=true' src/nocted/WorkerQualification.zig scripts/nocted_worker_qualification.sh >/dev/null
grep -F 'lazy_pool_creation=true transactional_enqueue=true' src/nocted/WorkerQualification.zig scripts/nocted_worker_qualification.sh >/dev/null
grep -F 'append_failure_safe=true push_failure_rollback=true' src/nocted/WorkerQualification.zig scripts/nocted_worker_qualification.sh >/dev/null
grep -F 'checkpoint_active_bytes={d}' src/nocted/WorkerQualification.zig >/dev/null
grep -F '| Debug | project search | 1,606,833 | 1,841,936 | 2,295,680 |' docs/NOCTED_STABILITY_QUALIFICATION.md >/dev/null
grep -F '| ReleaseSafe | Quick Open | 1,073,786 | 1,170,653 | 5,159,185 |' docs/NOCTED_STABILITY_QUALIFICATION.md >/dev/null
grep -F 'ranking_fingerprint=12892608525683143802' docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md >/dev/null
test -s src/terminal/CompatibilityQualification.zig
grep -F './scripts/terminal_compatibility_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md >/dev/null
grep -F 'terminal-compatibility-binary' build.zig docs/ARCHITECTURE.md >/dev/null
grep -F 'pub fn validateGraphemeBreakCorpus(corpus: []const u8) !usize' src/terminal/Unicode.zig >/dev/null
grep -F 'const protocol_case_count: usize = 23;' src/terminal/CompatibilityQualification.zig >/dev/null
grep -F 'const malformed_case_count: usize = 128;' src/terminal/CompatibilityQualification.zig >/dev/null
grep -F 'const unicode_mutation_count: usize = 256;' src/terminal/CompatibilityQualification.zig >/dev/null
test "$(awk -F '\t' '$0 !~ /^#/ && NF { count++ } END { print count + 0 }' src/terminal/fixtures/agent-compat-vt-corpus.tsv)" -eq 23
grep -F '65d5f28ec0f2e96bd4625a0d606a0b2a156f7a5f26cafc35edc1d015fc67068f' scripts/terminal_compatibility_qualification.sh docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md >/dev/null
grep -F 'e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec' scripts/terminal_compatibility_qualification.sh docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md >/dev/null
grep -F 'terminal_compatibility_matrix debug=true release_safe=true protocol_cases=23 schedules=6 malformed_cases=128 unicode_mutations=256 grapheme_cases=766 allocator_leak_free=true scratch_clean=true' scripts/terminal_compatibility_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md docs/ARCHITECTURE.md docs/DAILY_DRIVER.md docs/NATIVE_HOST.md docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md >/dev/null
grep -F 'By itself it does not prove that Codex, Claude Code, Antigravity, ncurses applications, tmux, or zellij render and exit correctly' docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md >/dev/null
test -s src/terminal/RealTuiQualification.zig
test -x scripts/terminal_real_tui_qualification.sh
bash -n scripts/terminal_real_tui_qualification.sh
grep -F './scripts/terminal_real_tui_qualification.sh' docs/TECHNICAL_STATUS.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_REAL_TUI_QUALIFICATION.md >/dev/null
grep -F 'terminal-real-tui-qualification-binary' build.zig docs/ARCHITECTURE.md >/dev/null
grep -F 'synchronized_output_begins: u64 = 0' src/terminal/Vt.zig >/dev/null
grep -F 'test "terminal grid counts synchronized output begin transitions"' src/terminal/Vt.zig >/dev/null
grep -F 'node-MainThread' src/terminal/RealTuiQualification.zig docs/TERMINAL_REAL_TUI_QUALIFICATION.md >/dev/null
real_tui_matrix='terminal_real_tui_matrix debug=true release_safe=true applications=codex,vim,btop codex_login_surface=true codex_sync_output=true vim_alternate_screen=true vim_bracketed_paste=true btop_alternate_screen=true btop_mouse=true btop_truecolor=true unicode=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true scratch_clean=true'
for path in docs/TECHNICAL_STATUS.md BACKLOG.md BACKLOG_ARCHIVE.md CHANGELOG.md \
  docs/ARCHITECTURE.md docs/DAILY_DRIVER.md docs/NATIVE_HOST.md \
  docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/PITCH_AUDIT.md \
  docs/RELEASE_CHECKLIST.md docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md \
  docs/TERMINAL_REAL_TUI_QUALIFICATION.md \
  docs/TERMINAL_SESSION_QUALIFICATION.md; do
  grep -F "$real_tui_matrix" "$path" >/dev/null
done
grep -F 'This does not prove an authenticated Codex agent workflow, Claude Code or Antigravity, compositor-backed pixels, Plasma Wayland/X11 interaction, or multi-day stability.' docs/TERMINAL_REAL_TUI_QUALIFICATION.md >/dev/null
grep -F 'The Codex case never authenticates or submits a model request.' docs/TERMINAL_REAL_TUI_QUALIFICATION.md >/dev/null
test -s src/terminal/NcursesQualification.zig
test -x scripts/terminal_ncurses_qualification.sh
bash -n scripts/terminal_ncurses_qualification.sh
grep -F './scripts/terminal_ncurses_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_NCURSES_QUALIFICATION.md >/dev/null
grep -F 'terminal-ncurses-qualification-binary' build.zig docs/ARCHITECTURE.md >/dev/null
grep -F 'const nano_markers = [_][]const u8{ "NOCTTY_NCURSES_NANO", "Write Out" };' src/terminal/NcursesQualification.zig >/dev/null
grep -F 'const resource_observation_polls: usize = 1000;' src/terminal/NcursesQualification.zig >/dev/null
grep -F 'dialog.alternate_screen)' src/terminal/NcursesQualification.zig >/dev/null
ncurses_matrix='terminal_ncurses_matrix debug=true release_safe=true applications=nano,less,dialog nano_editor=true nano_mouse=true less_pager=true dialog_widget=true editor_pager_alternate_screen=true dialog_primary_screen=true rich_style=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true'
for path in scripts/terminal_ncurses_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md \
  docs/ARCHITECTURE.md docs/DAILY_DRIVER.md docs/NATIVE_HOST.md \
  docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/PITCH_AUDIT.md \
  docs/RELEASE_CHECKLIST.md docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md \
  docs/TERMINAL_NCURSES_QUALIFICATION.md docs/TERMINAL_REAL_TUI_QUALIFICATION.md \
  docs/TERMINAL_SESSION_QUALIFICATION.md; do
  grep -F "$ncurses_matrix" "$path" >/dev/null
done
grep -F 'Three applications are not universal ncurses compatibility.' docs/TERMINAL_NCURSES_QUALIFICATION.md >/dev/null
test -s src/terminal/SystemTuiQualification.zig
test -x scripts/terminal_system_tui_qualification.sh
bash -n scripts/terminal_system_tui_qualification.sh
grep -F './scripts/terminal_system_tui_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_SYSTEM_TUI_QUALIFICATION.md >/dev/null
grep -F 'terminal-system-tui-qualification-binary' build.zig docs/ARCHITECTURE.md >/dev/null
grep -F 'const resource_observation_polls: usize = 1000;' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F 'watch.styled_cells != 0' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F '.app = .fzf,' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F '.app = .sqlite3,' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F '.app = .glances,' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F '.app = .bash,' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F '.app = .man,' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F '.app = .sftp,' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F -- '--disable-check-update --disable-webui' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F -- '--disable-plugin ip' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F -- '--noprofile --rcfile' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F -- '--local-file' src/terminal/SystemTuiQualification.zig >/dev/null
grep -F 'sftp_server_path' src/terminal/SystemTuiQualification.zig scripts/terminal_system_tui_qualification.sh >/dev/null
grep -F 'network_bind=false' src/terminal/SystemTuiQualification.zig scripts/terminal_system_tui_qualification.sh >/dev/null
grep -F 'XDG_CACHE_HOME={s}/{s}-cache;TMPDIR={s}/{s}-cache' src/terminal/RealTuiQualification.zig >/dev/null
system_tui_matrix='terminal_system_tui_matrix debug=true release_safe=true applications=top,watch,info,whiptail,fzf,sqlite3,glances,bash,man,sftp top_monitor=true watch_refresh=true watch_plain_surface=true info_browser=true whiptail_widget=true fzf_filter=true sqlite_repl=true glances_monitor=true bash_shell=true bash_readline=true man_pager=true pager_chain=true sftp_client=true sftp_local_server=true network_bind=false rich_style=true plain_repl=true input_routed=true foreground_identity=true controlled_exit=true allocator_leak_free=true root_memory_separate=true process_tree_memory=true installed_tools=true scratch_clean=true'
for path in scripts/terminal_system_tui_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md \
  CHANGELOG.md docs/ARCHITECTURE.md docs/DAILY_DRIVER.md docs/NATIVE_HOST.md \
  docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/PITCH_AUDIT.md \
  docs/RELEASE_CHECKLIST.md docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md \
  docs/TERMINAL_NCURSES_QUALIFICATION.md \
  docs/TERMINAL_REAL_TUI_QUALIFICATION.md \
  docs/TERMINAL_SESSION_QUALIFICATION.md \
  docs/TERMINAL_SYSTEM_TUI_QUALIFICATION.md; do
  grep -F "$system_tui_matrix" "$path" >/dev/null
done
grep -F 'Ten applications are not universal TUI compatibility.' docs/TERMINAL_SYSTEM_TUI_QUALIFICATION.md >/dev/null
test -s src/terminal/SessionQualification.zig
grep -F './scripts/terminal_session_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/TERMINAL_SESSION_QUALIFICATION.md >/dev/null
grep -F 'terminal-session-qualification-binary' build.zig docs/ARCHITECTURE.md >/dev/null
grep -F 'noctty_pty_process_group_alive' src/terminal/pty.c >/dev/null
grep -F 'if (!child_running && !foreground_alive && !shell_group_alive)' src/terminal/pty.c >/dev/null
grep -F 'if (shutdown_ns < 300 * std.time.ns_per_ms)' src/terminal/SessionQualification.zig >/dev/null
grep -F 'const normal_readiness_poll_limit: usize = 20_000;' src/terminal/SessionQualification.zig >/dev/null
grep -F 'terminal_session_qualification_matrix debug=true release_safe=true normal_cycles=64 forced_cycles=8 sessions_per_mode=72 total_sessions=144 allocator_leak_free=true forced_group_shutdown=true latency_percentiles=true root_memory_separate=true process_tree_memory=true scratch_clean=true' scripts/terminal_session_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md docs/ARCHITECTURE.md docs/COMPACT_UX.md docs/DAILY_DRIVER.md docs/NATIVE_HOST.md docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_BENCHMARK.md docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md docs/TERMINAL_SESSION_QUALIFICATION.md >/dev/null
grep -F './scripts/launch_continuity_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/LAUNCH_PROFILES.md docs/SESSION_CONTINUITY.md >/dev/null
grep -F 'launch-continuity-qualification-binary' build.zig docs/ARCHITECTURE.md >/dev/null
grep -F 'const continuity_readiness_poll_limit: usize = 20_000;' src/terminal/ContinuityQualification.zig >/dev/null
continuity_matrix='launch_continuity_matrix debug=true release_safe=true kinds=tmux,zellij direct_argv=true create_or_attach=true production_pty=true cwd=true environment=true controlled_exit=true allocator_leak_free=true tool_shims=true installed_tools=false live_reattach=false scratch_clean=true'
for path in scripts/launch_continuity_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md \
  docs/ARCHITECTURE.md docs/DAILY_DRIVER.md docs/LAUNCH_PROFILES.md \
  docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md \
  docs/SESSION_CONTINUITY.md; do
  grep -F "$continuity_matrix" "$path" >/dev/null
done
grep -F 'This closes NCT-112' docs/TERMINAL_SESSION_QUALIFICATION.md >/dev/null
grep -F './scripts/native_grid_renderer_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/PITCH_AUDIT.md docs/NATIVE_GRID_RENDERER_QUALIFICATION.md >/dev/null
grep -F 'noctty-smoke-binary' build.zig docs/ARCHITECTURE.md scripts/native_grid_renderer_qualification.sh >/dev/null
grep -F 'if (std.mem.eql(u8, cmd, "--native-grid-renderer-qualification")) {' src/main.zig >/dev/null
grep -F 'static gboolean draw_grid_contents(NocttyGridContext *context,' src/gui/native_grid_host.c >/dev/null
grep -F 'return draw_grid_contents(context, cr, allocation);' src/gui/native_grid_host.c >/dev/null
grep -F 'int noctty_native_grid_renderer_qualification(' src/gui/native_grid_host.c >/dev/null
for marker in row_buffer_allocations glyph_scratch_allocations glyph_cache_builds; do
  grep -F "$marker" src/gui/native_grid_host.c >/dev/null
done
grep -F 'for scenario in idle fullscreen rich; do' scripts/native_grid_renderer_qualification.sh >/dev/null
grep -F 'warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0' scripts/native_grid_renderer_qualification.sh >/dev/null
renderer_matrix='native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true'
for path in docs/TECHNICAL_STATUS.md BACKLOG.md BACKLOG_ARCHIVE.md CHANGELOG.md \
  docs/ARCHITECTURE.md docs/COMPACT_UX.md docs/DAILY_DRIVER.md \
  docs/NATIVE_HOST.md docs/PERFORMANCE_ALGORITHM_RESEARCH.md \
  docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_BENCHMARK.md \
  docs/TERMINAL_COMPATIBILITY_QUALIFICATION.md \
  docs/TERMINAL_SESSION_QUALIFICATION.md \
  docs/NATIVE_GRID_RENDERER_QUALIFICATION.md; do
  grep -F "$renderer_matrix" "$path" >/dev/null
done
grep -F 'This synthetic lane does not initialize GTK, map a native surface, exercise a compositor or frame clock' docs/NATIVE_GRID_RENDERER_QUALIFICATION.md >/dev/null
grep -F 'cf4d7cc8b3b474c474b28c1b37340e3f6223ad0159afb92b4a94bf31f1403e37' docs/NATIVE_GRID_RENDERER_QUALIFICATION.md >/dev/null
grep -F '7ee1ee2c1c52478e9b196edd580cab3bb2b6ebecc6b7af67508c820d54554abf' docs/NATIVE_GRID_RENDERER_QUALIFICATION.md >/dev/null
grep -F 'f53d9bfffd21dbc7118c08729ebdf9ccb58ef7c0914f0bc567c026b32294f190' docs/NATIVE_GRID_RENDERER_QUALIFICATION.md >/dev/null
grep -F './scripts/native_grid_pipeline_qualification.sh' scripts/verify.sh docs/TECHNICAL_STATUS.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_PIPELINE_QUALIFICATION.md >/dev/null
grep -F 'if (std.mem.eql(u8, cmd, "--native-grid-pipeline-qualification")) {' src/main.zig >/dev/null
grep -F 'int noctty_native_grid_pipeline_qualification(' src/gui/native_grid_host.c src/gui/native_grid_abi.h >/dev/null
pipeline_matrix='native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true'
for path in scripts/native_grid_pipeline_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md \
  CHANGELOG.md docs/ARCHITECTURE.md docs/COMPACT_UX.md docs/DAILY_DRIVER.md \
  docs/NATIVE_HOST.md docs/PERFORMANCE_ALGORITHM_RESEARCH.md \
  docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/TERMINAL_BENCHMARK.md \
  docs/TERMINAL_SESSION_QUALIFICATION.md \
  docs/TERMINAL_PIPELINE_QUALIFICATION.md; do
  grep -F "$pipeline_matrix" "$path" >/dev/null
done
grep -F '6ffcf3f95517772167cb41074a4af7afdc82aa2ec9edd621ff85fd90500c55fc' CHANGELOG.md docs/TERMINAL_PIPELINE_QUALIFICATION.md >/dev/null
grep -F 'not a mapped GTK widget, frame-clock callback, compositor presentation, or visible photon' docs/TERMINAL_PIPELINE_QUALIFICATION.md >/dev/null
grep -F 'churn_cycles=8 sessions_created=32 sessions_closed=32' scripts/native_grid_resource_qualification.sh >/dev/null
grep -F 'native_grid_resource_qualification debug=true release_safe=true churn_cycles=8 sessions_created=32 sessions_closed=32 root_memory_separate=true process_tree_memory=true scratch_clean=true' scripts/native_grid_resource_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md docs/COMPACT_UX.md docs/DAILY_DRIVER.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'terminal_history_matrix debug=true release_safe=true lines=100000 compact=true reflow=true grow_shrink=true scratch_clean=true' scripts/terminal_history_qualification.sh BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F '.name = "nocted"' build.zig >/dev/null
grep -F 'nocted_mod.addImport("noctty_release", release_mod);' build.zig >/dev/null
grep -F 'linkSystemLibrary("gtksourceview-4"' build.zig >/dev/null
grep -F 'static gboolean launch_nocted' src/gui/native_grid_host.c >/dev/null
grep -F 'context->nocted_process_separate = launched;' src/gui/native_grid_host.c >/dev/null
grep -F 'g_spawn_async(' src/gui/native_grid_host.c >/dev/null
grep -F 'realPathFileAlloc' src/nocted/Document.zig >/dev/null
grep -F 'break :blk stat.permissions;' src/nocted/Document.zig >/dev/null
grep -F 'error.UnsupportedNul' src/nocted/Document.zig >/dev/null
grep -F 'gtk_source_map_set_view' src/nocted/main.zig >/dev/null
grep -F '#nocted-minimap.scrubber { background-color: rgba(143, 184, 255, 0.18); }' src/nocted/main.zig >/dev/null
grep -F 'pub const max_regions: usize = 4096;' src/nocted/Folding.zig >/dev/null
grep -F 'pub const max_results: usize = 1000;' src/nocted/ProjectSearch.zig >/dev/null
grep -F 'pub const max_results: usize = 100;' src/nocted/QuickOpen.zig >/dev/null
grep -F 'pub const Scanner = struct {' src/nocted/ProjectIndex.zig >/dev/null
grep -F 'pub fn step(self: *Scanner, max_visits: usize) !ScanProgress {' src/nocted/ProjectIndex.zig >/dev/null
grep -F 'pub const Cursor = struct {' src/nocted/ProjectSearch.zig >/dev/null
grep -F 'pub fn step(self: *Cursor, max_entries: usize) !SearchProgress {' src/nocted/ProjectSearch.zig >/dev/null
grep -F 'pub const max_pending: usize = 64;' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'while (try scanner.step(128) == .pending)' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'const progress = try cursor.step(1);' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'pending >= Job.search_batch_size or timed_flush or' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'foreground: ?*c.GThreadPool = null,' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'scan: ?*c.GThreadPool = null,' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'self.foreground = created' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'self.scan = created' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'pub const max_entries: usize = 100_000;' src/nocted/ProjectIndex.zig >/dev/null
grep -F 'pub const max_filesystem_changes: usize = 256;' src/nocted/ProjectIndex.zig >/dev/null
grep -F 'pub fn applyFilesystemChangesAlloc(' src/nocted/ProjectIndex.zig >/dev/null
grep -F 'error.ProjectDeltaRequiresRescan' src/nocted/ProjectIndex.zig src/nocted/main.zig >/dev/null
grep -F 'project_monitor_changes: std.array_list.Managed(core.project_index.FilesystemChange)' src/nocted/main.zig >/dev/null
grep -F 'self.submitProjectDelta(root)' src/nocted/main.zig >/dev/null
grep -F 'core.project_index.applyFilesystemChangesAlloc(' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'project_delta_updates=1' scripts/nocted_native_smoke.sh docs/NOCTED.md docs/NOCTED_PROJECT_INDEX_QUALIFICATION.md >/dev/null
grep -F 'nocted_project_index_matrix debug=true release_safe=true scales=4000,25000,100000 immutable_delta=true directory_rename=true replacement_conflict=true ignore_fallback=true overflow_fallback=true scan_time=true delta_time=true index_memory=true two_snapshot_peak=true process_memory=true allocator_leak_free=true scratch_clean=true' scripts/nocted_project_index_qualification.sh docs/TECHNICAL_STATUS.md BACKLOG.md CHANGELOG.md docs/NOCTED.md docs/NOCTED_PROJECT_INDEX_QUALIFICATION.md docs/PERFORMANCE_ALGORITHM_RESEARCH.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'nocted-project-index-binary' build.zig >/dev/null
grep -F 'nocted-smoke-binary' build.zig >/dev/null
grep -F 'pub const search_batch_size: usize = 24;' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'pub const max_search_batches: usize = 2;' src/nocted/FilesystemWorker.zig >/dev/null
grep -F 'fn startProjectMonitoring(self: *App) !void {' src/nocted/main.zig >/dev/null
grep -F 'g_file_monitor_directory(' src/nocted/main.zig >/dev/null
grep -F 'documents_by_path: std.StringHashMap(*Document)' src/nocted/main.zig >/dev/null
grep -F 'c.g_object_set_data(' src/nocted/main.zig >/dev/null
grep -F 'c.G_TYPE_UINT64' src/nocted/main.zig >/dev/null
grep -F 'self.project_load_source = c.g_idle_add(onProjectLoadStep, self);' src/nocted/main.zig >/dev/null
grep -F 'const end = @min(load.next_entry + 128, roots.len);' src/nocted/main.zig >/dev/null
! grep -F 'onProjectSearchStep' src/nocted/main.zig >/dev/null
! grep -F 'project_search_source' src/nocted/main.zig >/dev/null
grep -F 'self.quick_open_source = c.g_timeout_add(30, onQuickOpenUpdate, self);' src/nocted/main.zig >/dev/null
grep -F 'fn commitProjectLoad(self: *App, load: *ProjectLoad) void {' src/nocted/main.zig >/dev/null
grep -F 'project_monitor_late_callbacks: usize = 0,' src/nocted/main.zig >/dev/null
grep -F 'fn runCombinedProjectLifecycleSmoke(' src/nocted/main.zig >/dev/null
grep -F 'NOCTED_PROJECT_LIFECYCLE_ROOT' src/nocted/main.zig scripts/nocted_native_smoke.sh >/dev/null
grep -F 'NOCTED_SEARCH_LOAD_ROOT' src/nocted/main.zig scripts/nocted_native_smoke.sh >/dev/null
grep -F 'fn runSearchLoadQualification(self: *App, root: []const u8) bool {' src/nocted/main.zig >/dev/null
grep -F 'onProjectSearchTreeDraw' src/nocted/main.zig >/dev/null
grep -F 'ranking_queries=3 ranking_cycles={d} ranking_fingerprint={d}' src/nocted/StabilityQualification.zig >/dev/null
grep -F 'nocted_search_load_native_matrix x11=true wayland=true cycles=8 first_result_latency=true completion_latency=true cancellation_latency=true ui_draw_latency=true open_under_search=true save_under_refresh=true deterministic_ranking=true gtk_batch_bounded=true worker_drained=true warning_fatal=true scratch_clean=true' scripts/nocted_native_matrix.sh docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md >/dev/null
wayland_search_evidence='nocted_search_load_wayland_evidence backend=wayland optimize=Debug runs=2 cycles_per_run=8 first_result_latency=true completion_latency=true cancellation_latency=true ui_draw_latency=true open_under_search=true save_under_refresh=true deterministic_ranking=true gtk_batch_peak=2 gtk_batch_cap=2 worker_drained=true warning_fatal=true rendered=true scratch_clean=true'
for path in CHANGELOG.md docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md docs/RELEASE_CHECKLIST.md; do
  grep -F "$wayland_search_evidence" "$path" >/dev/null
done
grep -F '| A | 268 | 4,274,139 / 8,986,642 / 8,986,642 ns |' docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md >/dev/null
grep -F '| B | 267 | 4,504,595 / 8,264,545 / 8,264,545 ns |' docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md >/dev/null
grep -F 'Matching `ReleaseSafe`, X11, peak process-tree memory, and long-duration evidence remains open' docs/NOCTED_STABILITY_QUALIFICATION.md >/dev/null
! grep -F 'No new native search/load percentiles or memory samples are therefore retained' docs/NOCTED_SEARCH_LOAD_QUALIFICATION.md >/dev/null
grep -F 'actual_gio_burst=true' src/nocted/main.zig scripts/nocted_native_smoke.sh docs/NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md >/dev/null
grep -F 'overflow_admission_injected=true' src/nocted/main.zig scripts/nocted_native_smoke.sh docs/NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md >/dev/null
grep -F 'nocted_project_lifecycle_gate backend=$backend real_project=true cycles=8 gtk_tree_draw=true model_latency=true draw_latency=true monitor_burst=true burst_cycles=8 files_per_burst=12 publication_latency=true overflow_recovery=true late_callback_guard=true worker_drained=true scratch_clean=true' scripts/nocted_native_smoke.sh >/dev/null
grep -F 'pub extern fn g_source_remove(tag: c_uint) gboolean;' src/nocted/gtk.zig >/dev/null
grep -F 'pub fn packedRow(self: Grid, row: usize, output: []u64) usize {' src/terminal/Vt.zig >/dev/null
grep -F 'pub fn takeDirtyRows(self: *Grid, output: []u8) usize {' src/terminal/Vt.zig >/dev/null
grep -F 'pub fn takeDirtySpans(self: *Grid, output: []DirtySpan) usize {' src/terminal/Vt.zig >/dev/null
! grep -F 'pub fn rowHash(self: Grid, row: usize) u64 {' src/terminal/Vt.zig >/dev/null
grep -F 'export fn noctty_grid_row(' src/main.zig >/dev/null
grep -F 'export fn noctty_grid_take_dirty_rows(' src/main.zig >/dev/null
grep -F 'export fn noctty_grid_take_dirty_spans(' src/main.zig >/dev/null
! grep -F 'export fn noctty_grid_row_hash(' src/main.zig >/dev/null
grep -F '#include "native_grid_abi.h"' src/gui/native_grid_host.c >/dev/null
grep -F '#define NOCTTY_NATIVE_GRID_ABI_VERSION 2u' src/gui/native_grid_abi.h >/dev/null
grep -F 'pub const version: u32 = 2;' src/gui/NativeGridAbi.zig >/dev/null
grep -F 'typedef int (*NocttyGridDirtySpans)(void *, NocttyGridDirtySpan *, size_t);' src/gui/native_grid_abi.h >/dev/null
grep -F 'typedef int (*NocttyGridPresentationReady)(void *);' src/gui/native_grid_abi.h >/dev/null
grep -F 'static void inherit_grid_session_context(NocttyGridContext *created,' src/gui/native_grid_host.c >/dev/null
! grep -F '*created = *source;' src/gui/native_grid_host.c >/dev/null
grep -F 'queue_grid_output_when_ready(context);' src/gui/native_grid_host.c >/dev/null
grep -F 'cairo_scaled_font_text_to_glyphs' src/gui/native_grid_host.c >/dev/null
grep -F 'native_grid_renderer_smoke abi=%d row_batches=%u damage_rows=%u damage_cells=%u damage_spans=%u damage_source=dirty_spans glyph_batches=%u glyph_cells=%u glyph_cache_hits=%u' src/gui/native_grid_host.c >/dev/null
grep -F '.name = "noctty-vte"' build.zig >/dev/null
grep -F '.name = "noctty-smoke"' build.zig >/dev/null
grep -F '.name = "nocted-smoke"' build.zig >/dev/null
grep -F 'vte_options.addOption(bool, "enable_vte", true);' build.zig >/dev/null
grep -F 'runtime_options.addOption(bool, "enable_vte", false);' build.zig >/dev/null
grep -F 'return error.SmokeModeUnavailable;' src/main.zig >/dev/null
grep -F 'return error.LegacyEditorUnavailable;' src/main.zig >/dev/null
grep -F 'mandatory_vte_dependency=false' scripts/package_manifests_smoke.sh docs/INSTALL.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Find in Files...' src/nocted/main.zig docs/NOCTED.md >/dev/null
grep -F 'New File' src/nocted/main.zig docs/NOCTED.md >/dev/null
grep -F 'Save As...' src/nocted/main.zig docs/NOCTED.md >/dev/null
grep -F 'Quick Open...' src/nocted/main.zig docs/NOCTED.md >/dev/null
grep -F 'Select All Occurrences' src/nocted/main.zig docs/NOCTED.md >/dev/null
grep -F 'Open Recent' src/nocted/main.zig docs/NOCTED.md >/dev/null
grep -F 'pub const multi_selection = @import("MultiSelection.zig");' src/nocted/root.zig >/dev/null
grep -F 'pub const session = @import("Session.zig");' src/nocted/root.zig >/dev/null
grep -F 'Import TextMate JSON Grammar...' src/nocted/main.zig docs/NOCTED.md >/dev/null
grep -F 'pub const textmate_grammar = @import("TextMateGrammar.zig");' src/nocted/root.zig >/dev/null
grep -F 'fn reloadSyntaxPaths(self: *App) !void {' src/nocted/main.zig >/dev/null
grep -F 'textmate_import=1' scripts/nocted_native_smoke.sh >/dev/null
for path in scripts/nocted_native_smoke.sh BACKLOG_ARCHIVE.md CHANGELOG.md docs/NOCTED.md docs/RELEASE_CHECKLIST.md; do
  grep -F 'textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true warning_fatal=true' "$path" >/dev/null
done
grep -F 'textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true real_project=true' scripts/nocted_native_matrix.sh >/dev/null
grep -F 'project_search_activation=true' src/nocted/main.zig docs/NOCTED.md >/dev/null
for field in multi_selection multi_selection_undo multi_selection_rendered session_persist session_restore recent_project; do
  grep -F "${field}=1" scripts/nocted_native_smoke.sh >/dev/null
  grep -F "${field}=true" scripts/nocted_native_smoke.sh scripts/nocted_native_matrix.sh BACKLOG_ARCHIVE.md CHANGELOG.md docs/NOCTED.md docs/RELEASE_CHECKLIST.md >/dev/null
done
grep -F 'nocted_native_gate rendered=true folding=true minimap_overlay_translucent=true find_in_files=true project_search_activation=true multi_file_tabs=true tab_navigation=true close_other=true close_all=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true warning_fatal=true' scripts/nocted_native_smoke.sh docs/NOCTED.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'backend=$backend scratch_clean=true' scripts/nocted_native_smoke.sh >/dev/null
grep -F 'backend=x11 scratch_clean=true' docs/NOCTED.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'run_smoke ./scripts/nocted_native_matrix.sh' scripts/native_release_smoke.sh >/dev/null
grep -F 'nocted_native_matrix x11=true wayland=true folding=true find_in_files=true multi_file=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true warning_fatal=true scratch_clean=true' BACKLOG_ARCHIVE.md CHANGELOG.md >/dev/null
grep -F 'nocted_native_matrix x11=true wayland=true folding=true find_in_files=true multi_file=true untitled=true save_as=true quick_open=true quick_open_capture=true multi_selection=true multi_selection_undo=true multi_selection_rendered=true session_persist=true session_restore=true recent_project=true textmate_import=true textmate_language=true textmate_precedence=true malformed_rejected=true real_project=true lifecycle_cycles=8 gtk_tree_draw=true model_latency=true draw_latency=true monitor_burst=true burst_cycles=8 files_per_burst=12 publication_latency=true overflow_recovery=true late_callback_guard=true worker_drained=true warning_fatal=true scratch_clean=true' scripts/nocted_native_matrix.sh docs/NOCTED.md docs/NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'editor_shutdown=true nocted=true maintenance=true' scripts/native_release_smoke.sh docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'nocted_standalone=true process_separate=true' BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_CHECKLIST.md >/dev/null
for obsolete in 'Lean Editor' 'lean editor' 'lean-editor' 'lightweight editor' \
  'Open Editor Here' 'Project / Editor'; do
  ! grep -FR "$obsolete" docs/TECHNICAL_STATUS.md docs/ARCHITECTURE.md docs/NATIVE_HOST.md \
    docs/COMPACT_UX.md docs/NOCTED.md docs/PITCH_AUDIT.md \
    docs/RELEASE_CHECKLIST.md src/gui/native_grid_host.c resources packaging \
    >/dev/null
done
grep -F 'Ctrl+S' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Save/Discard/Cancel' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
for path in docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md; do
  grep -F 'whole-application Save/Discard/Cancel' "$path" >/dev/null
  grep -F 'editor_shutdown=true' "$path" >/dev/null
  grep -F 'forced SIGTERM' "$path" >/dev/null
done
test -s scripts/native_grid_editor_shutdown_smoke.sh
grep -F 'run_smoke ./scripts/native_grid_editor_shutdown_smoke.sh' scripts/native_release_smoke.sh >/dev/null
grep -F 'editor_shutdown=true' scripts/native_release_smoke.sh >/dev/null
for path in src/main.zig scripts/native_grid_editor_shutdown_smoke.sh; do
  grep -F 'native_grid_editor_shutdown_smoke contexts=2 editors=2 prompts=5 direct_prompt=true modal_deferred=true modal_depth=1 prompt_owned=true wm_cancel=true retryable=true window_alive=true editors_alive=true ptys_alive=2 tray_alive=true toolbar_retry=true save_failure=true failure_survived=true natural_cancel=true natural_retry=true natural_dwell_ms=80 already_exited=2 exit_codes=7,9 exit_codes_preserved=true active_validation=true save=true discard=true saved_file=true discarded_file=true sessions=2 sessions_stopped=2 accepted_origin=toolbar tray_unregistered=true menu_unregistered=true exited=true' "$path" >/dev/null
done
grep -F 'Ctrl+wheel' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Open NoctEd Here' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/NOCTED.md >/dev/null
grep -F 'Close Tab' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md >/dev/null
grep -F 'New Tab' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md >/dev/null
grep -F 'Close Terminal' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md >/dev/null
grep -F 'add_reopen_after_close=true fresh_context=true' scripts/native_grid_two_tab_smoke.sh >/dev/null
grep -F 'primary_pty_closed=true late_callback_guard=true remaining_tabs=1' scripts/native_grid_two_tab_smoke.sh >/dev/null
grep -F 'close_terminal=true foreground_guard=true close_confirmed=true model_closed=true rendered_closed=true primary_pty_closed=true session_storage_released=true' scripts/native_grid_pane_close_smoke.sh >/dev/null
grep -F 'layout_2x2=true panes_2x2=4 balanced_2x2=true churn_cycles=8 sessions_created=32 sessions_closed=32 layout_3x3=true panes_3x3=9 live_sessions=9 balanced_3x3=true layout_1x1=true panes_1x1=1 surplus_ptys_closed=true session_storage_released=true' scripts/native_grid_layout_preset_smoke.sh >/dev/null
test -x scripts/native_grid_tab_reorder_smoke.sh
sh -n scripts/native_grid_tab_reorder_smoke.sh
grep -F 'search --onlyvisible --pid "$pid"' scripts/native_grid_tab_reorder_smoke.sh >/dev/null
grep -F 'getwindowpid "$window"' scripts/native_grid_tab_reorder_smoke.sh >/dev/null
! grep -Fi 'yakuake' scripts/native_grid_tab_reorder_smoke.sh >/dev/null
grep -F 'native_grid_tab_reorder_smoke pointer_drag=true pointer_press=true pointer_drop=true forward=true tabs=3 active_identity=true model_order=true snapshot_order=true persistence_coalesced=true exited=true' src/main.zig scripts/native_grid_tab_reorder_smoke.sh >/dev/null
grep -F 'run_smoke ./scripts/native_grid_tab_reorder_smoke.sh' scripts/native_release_smoke.sh >/dev/null
grep -F 'tab_reorder=true tab_reorder_pointer_drag=true' scripts/native_release_smoke.sh >/dev/null
grep -F 'late_callback_guard=true popup_teardown=true' scripts/native_release_smoke.sh >/dev/null
grep -F 'Layout 2×2' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md >/dev/null
grep -F 'Layout 3×3' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md >/dev/null
grep -F 'zoom=true tab_bar_zoom=true' scripts/native_grid_compact_ux_smoke.sh >/dev/null
grep -F 'window_resize=true tray=true' scripts/native_release_smoke.sh >/dev/null
grep -F 'Close NOCTTY' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'standard arrow pointer' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F '22–24 logical pixels' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Tab Color' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Ctrl+Alt+=' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md >/dev/null
grep -F 'Ctrl+Alt+-' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md >/dev/null
grep -F 'tab_color=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md scripts/native_release_smoke.sh >/dev/null
grep -F 'native_grid_tab_color_smoke menu=true presets=8 default=true applied=blue rendered=true contrast=true shortcut_lighten=true shortcut_darken=true reversible=true workspace_dirty=true snapshot=true exited=true' scripts/native_grid_tab_color_smoke.sh >/dev/null
test -s scripts/native_grid_profile_preset_smoke.sh
grep -F 'run_smoke ./scripts/native_grid_profile_preset_smoke.sh' scripts/native_release_smoke.sh >/dev/null
for path in src/main.zig scripts/native_grid_profile_preset_smoke.sh; do
  grep -F 'native_grid_profile_preset_smoke context_menu=true submenu=true menu_survived=true presets=5 exact_target=true current=true readable=true font_size=14 isolated=true high_contrast=true rendered=true mono_no_ligatures=true workspace_dirty=true snapshot=true restored=true exited=true' "$path" >/dev/null
done
grep -F 'native_grid_profile_preset_matrix wayland=true x11=true exact_target=true isolated=true persisted=true restored=true' scripts/native_grid_profile_preset_smoke.sh >/dev/null
grep -F 'profile_presets=true' scripts/native_release_smoke.sh >/dev/null
for path in docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md; do
  grep -F 'profile_presets=true' "$path" >/dev/null
  grep -F 'Profile' "$path" >/dev/null
  grep -F 'Active pane profile' "$path" >/dev/null
  grep -F 'Mono no ligatures' "$path" >/dev/null
done
grep -F 'native_grid_profile_preset_matrix wayland=true x11=true exact_target=true isolated=true persisted=true restored=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Ctrl+Tab' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Ctrl+Shift+Tab' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Alt+wheel' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Ctrl+Alt+wheel' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Ctrl+C' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Ctrl+D' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'navigation=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md scripts/native_release_smoke.sh >/dev/null
grep -F 'native_grid_tab_navigation_smoke pane_ctrl_tab=true alt_scroll=true alt_scroll_up=true alt_scroll_down=true current_tab=true visible_panes_only=true hidden_skipped=true visual_feedback=true ctrl_alt_scroll=true tab_scroll_up=true tab_scroll_down=true tab_wraparound=true tab_visual_feedback=true tab_ctrl_shift_tab=true smart_filter_preserved=true cycle_next=true cycle_previous=true shortcut_close=true shortcut_reopen=true focus_restored=true tabs=2 exited=true' scripts/native_grid_tab_navigation_smoke.sh >/dev/null
grep -F 'native_grid_tab_navigation_matrix wayland=true x11=true alt_scroll=true ctrl_alt_scroll=true current_tab=true hidden_skipped=true pane_visual_feedback=true tab_wraparound=true tab_visual_feedback=true' scripts/native_grid_tab_navigation_smoke.sh >/dev/null
grep -F 'alt_scroll=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md scripts/native_release_smoke.sh >/dev/null
grep -F 'ctrl_alt_scroll=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md scripts/native_release_smoke.sh >/dev/null
grep -F 'native_grid_terminal_chords_smoke panes=2 broadcast=true ctrl_c=true interrupt_target=current_pane primary_interrupts=0 secondary_interrupts=1 ctrl_d=true exact_pane=true eof_forwarded=false final_pane_protected=true remaining_focused=true exited=true' scripts/native_grid_terminal_chords_smoke.sh >/dev/null
grep -F 'native_grid_terminal_chords_matrix wayland=true x11=true broadcast_on=true ctrl_c_current_pane_only=true ctrl_d_exact_pane=true eof_forwarded=false final_pane_protected=true' scripts/native_grid_terminal_chords_smoke.sh >/dev/null
grep -F 'terminal_chords=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md scripts/native_release_smoke.sh >/dev/null
grep -F 'settings_stacking=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md scripts/native_release_smoke.sh >/dev/null
grep -F 'native_grid_settings_stacking_matrix wayland=true x11=true transient_parent=true keep_above=true compositor_stack=true parent_restored=true' scripts/native_grid_settings_stacking_smoke.sh >/dev/null
grep -F 'Hold Alt' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'note_overlay=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md scripts/native_release_smoke.sh >/dev/null
grep -F 'native_grid_note_overlay_matrix wayland=true x11=true alt_hold=true visible_panes=2 compact=true hidden_on_release=true' scripts/native_grid_note_overlay_smoke.sh >/dev/null
grep -F 'hot_session=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md scripts/native_release_smoke.sh >/dev/null
grep -F 'native_grid_hot_session_matrix wayland=true x11=true atomic=true tabs=2 panes=5 ratios=true corrupt_fallback=true' scripts/native_grid_hot_session_smoke.sh >/dev/null
grep -F 'menu_registered=true watcher=true icon=true activate=true secondary=true context=true menu_layout=true close=true session_stopped=true' scripts/native_grid_window_tray_smoke.sh >/dev/null
grep -F 'tab_rename=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'tab_close=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'tab_add=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'pane_close=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'layout_presets=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'resize_overlay=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'noctalia_ipc=true' docs/TECHNICAL_STATUS.md docs/NATIVE_HOST.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Reproducible install-tree tarball:' docs/TECHNICAL_STATUS.md >/dev/null
grep -F '## Normalized Install Tarball' docs/INSTALL.md >/dev/null
grep -F 'Two isolated byte-identical tarball builds, coherent version/date surfaces, SHA-256 sidecar verification, and self-cleaning verification scratch space (NCT-075)' docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'Reproducible two-build install tarball' docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'two isolated `ReleaseSafe` install trees with separate stages and Zig caches' docs/INSTALL.md >/dev/null
grep -F 'package_tarball_reproducibility version=$version release_date=$release_date builds=2 isolated=true release_safe=true stripped=true byte_identical=true checksums_match=true archive_valid=true cli_version=true scratch_clean=true' scripts/package_tarball.sh >/dev/null
grep -F 'package_reproducibility version=$version release_date=$release_date builds=2 isolated=true byte_identical=true checksums_match=true archive_valid=true cli_version=true scratch_clean=true' scripts/package_reproducibility_smoke.sh >/dev/null
grep -F 'release_contract version=$version release_date=$release_date revision=$revision build_zon=true noctty_runtime=true nocted_runtime=true production_vte=false production_tree_sitter=false production_smoke_surface=false production_legacy_editor=false appstream=true debian=true rpm=true arch=true docs=true' scripts/release_contract_smoke.sh >/dev/null
grep -F './scripts/release_workflow_contract_smoke.sh' scripts/verify.sh >/dev/null
grep -F 'release_workflow_contract zig=0.16.0 x86_64=true aarch64=true layer_shell=true gtksourceview=true nocted=true arch_assert=true verify=true bundle=true archive_validation=true sidecar_validation=true manifest_validation=true upload=true retained_artifacts_external=true' scripts/release_workflow_contract_smoke.sh >/dev/null
grep -F 'version: 0.16.0' .github/workflows/release.yml >/dev/null
grep -F 'libgtk-layer-shell0' .github/workflows/release.yml >/dev/null
grep -F 'libgtksourceview-4-dev' .github/workflows/release.yml >/dev/null
grep -F 'Assert runner architecture' .github/workflows/release.yml >/dev/null
grep -F 'Validate release archive' .github/workflows/release.yml >/dev/null
grep -F 'sha256sum -c "$archive.sha256"' .github/workflows/release.yml >/dev/null
grep -F 'test -s "$archive.manifest"' .github/workflows/release.yml >/dev/null
grep -F "grep -F './bin/nocted'" .github/workflows/release.yml >/dev/null
grep -F "grep -F './libexec/noctty/nocted'" .github/workflows/release.yml >/dev/null
grep -F "grep -F './share/nocted/language-specs/zig.lang'" .github/workflows/release.yml >/dev/null
grep -F 'noctty-linux-${{ matrix.arch }}.tar.gz.manifest' .github/workflows/release.yml >/dev/null
grep -F 'package_manifests debian_structure=true rpm_parser=$rpm_parser arch_parser=$arch_parser x86_64_manifest=true aarch64_manifest=true layer_shell_dependency=true gtksourceview_dependency=true mandatory_vte_dependency=false nocted_launcher=true noctalia_artifacts=true bundle_script=true' scripts/package_manifests_smoke.sh >/dev/null
grep -F 'package_bundle path=$out architecture=$architecture version=$release_version manifest=true installed_files=true library_inventory=true' scripts/package_bundle.sh >/dev/null
grep -F 'zig build -Doptimize=ReleaseSafe -Dstrip=true --prefix "$stage"' scripts/package_bundle.sh >/dev/null
test -x scripts/package_bundle_licenses.sh
sh -n scripts/package_bundle_licenses.sh
test -x scripts/package_bundle_licenses_backend_smoke.sh
sh -n scripts/package_bundle_licenses_backend_smoke.sh
grep -F './scripts/package_bundle_licenses.sh "$library_sources" "$stage"' scripts/package_bundle.sh >/dev/null
grep -F 'pacman -Qqo "$library"' scripts/package_bundle_licenses.sh >/dev/null
grep -F 'dpkg-query -S "$library"' scripts/package_bundle_licenses.sh >/dev/null
grep -F './scripts/package_bundle_licenses_backend_smoke.sh' scripts/verify.sh >/dev/null
grep -F 'package_bundle_licenses_backend_smoke debian=true version=true copyright=true library_inventory=true package_inventory=true fail_closed=true scratch_clean=true' scripts/package_bundle_licenses_backend_smoke.sh BACKLOG_ARCHIVE.md CHANGELOG.md >/dev/null
grep -F 'share/licenses/noctty/dependencies' scripts/package_bundle_licenses.sh docs/TECHNICAL_STATUS.md THIRD_PARTY_NOTICES.md docs/ARCHITECTURE.md docs/INSTALL.md >/dev/null
grep -F 'all_copied_host_libraries_accounted=true' scripts/package_bundle.sh scripts/package_bundle_licenses.sh scripts/release_operations_receipt_intake.sh scripts/release_operations_status.sh docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'bundle_license_payload_complete=true' scripts/package_bundle.sh scripts/release_operations_receipt_intake.sh scripts/release_operations_status.sh docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'package_bundle_license library owner unresolved' scripts/package_bundle_licenses.sh >/dev/null
grep -F 'package_bundle_license no text for expression' scripts/package_bundle_licenses.sh >/dev/null
grep -F 'local_cache=${NOCTTY_ZIG_CACHE_DIR:-"$scratch/zig-local"}' scripts/terminal_history_qualification.sh >/dev/null
grep -F 'global_cache=${NOCTTY_ZIG_GLOBAL_CACHE_DIR:-"$scratch/zig-global"}' scripts/terminal_history_qualification.sh >/dev/null
grep -F 'history_parent=${NOCTTY_HISTORY_PARENT:-"$repo_root"}' scripts/terminal_history_qualification.sh >/dev/null
grep -F 'export NOCTTY_HISTORY_PARENT="$verify_root/tmp"' scripts/verify.sh >/dev/null
grep -F 'export XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$scratch/xdg-cache"}' scripts/terminal_history_qualification.sh >/dev/null
grep -F 'export TMPDIR="$scratch/tmp"' scripts/terminal_history_qualification.sh >/dev/null
grep -F '321 MiB workspace' BACKLOG_ARCHIVE.md CHANGELOG.md >/dev/null
for path in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/COMPACT_UX.md docs/RELEASE_CHECKLIST.md; do
  for marker in pane_info=true pane_source=pty_proc pane_refresh=coalesced pane_info_dedup=true; do
    grep -F "$marker" "$path" >/dev/null
  done
done
grep -F 'Active-pane session identity' docs/PITCH_AUDIT.md >/dev/null
grep -F 'config snapshot v4' docs/COMPACT_UX.md >/dev/null
grep -F 'stale focus-loss' BACKLOG_ARCHIVE.md CHANGELOG.md >/dev/null
grep -F 'origin-bound' BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'bounded click-focus' docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'idempotent pane-activation' BACKLOG_ARCHIVE.md CHANGELOG.md >/dev/null
grep -F '200 ms' BACKLOG_ARCHIVE.md CHANGELOG.md >/dev/null
grep -F 'package_bundle_manifest manifest=true archive=true checksum=true installed_files=true library_inventory=true package_inventory=true license_payload=true all_libraries_accounted=true gtk_layer_shell_license=LGPL-3.0-or-later redistribution_ready=true fail_closed=true scratch_clean=true' scripts/package_bundle_manifest_smoke.sh >/dev/null
grep -F './scripts/package_bundle_manifest_smoke.sh' scripts/verify.sh >/dev/null
grep -F './scripts/release_operations_artifact_intake_smoke.sh' scripts/verify.sh >/dev/null
grep -F './scripts/release_operations_signature_intake_smoke.sh' scripts/verify.sh >/dev/null
grep -F './scripts/release_operations_receipt_intake_smoke.sh' scripts/verify.sh >/dev/null
grep -F './scripts/release_operations_acceptance_intake_smoke.sh' scripts/verify.sh >/dev/null
grep -F './scripts/release_operations_scaffold_smoke.sh' scripts/verify.sh >/dev/null
grep -F './scripts/release_operations_status_smoke.sh' scripts/verify.sh >/dev/null
grep -F './scripts/release_operations_status.sh' scripts/verify.sh >/dev/null
grep -F 'release_operations_status version=$version tagged_artifacts=$tagged_artifacts signatures=$signatures publication=$publication dependency_bundle_redistribution=$dependency_bundle_redistribution compositor_acceptance=$compositor_acceptance wayland_hid_consent=$wayland_hid_consent complete=$complete external_blockers=$external_blockers' scripts/release_operations_status.sh >/dev/null
grep -F 'release_operations_issue category=tagged_artifacts path=noctty-linux-x86_64.tar.gz reason=missing' scripts/release_operations_status_smoke.sh docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_issues total=21' scripts/release_operations_status_smoke.sh docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_status_smoke missing_diagnostics=true require_complete_blocks=true complete_fixture=true checksum_verified=true semantic_receipts=true bundle_manifest_attestation=true scratch_clean=true' scripts/release_operations_status_smoke.sh >/dev/null
grep -F 'release_operations_status_smoke missing_diagnostics=true require_complete_blocks=true complete_fixture=true checksum_verified=true semantic_receipts=true bundle_manifest_attestation=true scratch_clean=true' BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_issue category=tagged_artifacts path=noctty-linux-x86_64.tar.gz reason=missing' docs/TECHNICAL_STATUS.md docs/ARCHITECTURE.md docs/INSTALL.md docs/PITCH_AUDIT.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_issues total=21' docs/RELEASE_CHECKLIST.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'manifest_digest_mismatch' docs/RELEASE_OPERATIONS.md scripts/release_operations_status.sh >/dev/null
grep -F 'receipt_field_missing' docs/RELEASE_OPERATIONS.md scripts/release_operations_status.sh >/dev/null
grep -F 'semantic_receipts=true' docs/TECHNICAL_STATUS.md docs/ARCHITECTURE.md docs/INSTALL.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_scaffold version=$version path=$out_dir receipt_templates=true compositor_templates=6 placeholder_blocking=true artifact_files=false' scripts/release_operations_scaffold.sh >/dev/null
grep -F 'release_operations_scaffold_smoke templates=true fake_artifacts=false placeholder_blocked=true require_complete_blocks=true scratch_clean=true' scripts/release_operations_scaffold_smoke.sh BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_scaffold_smoke templates=true fake_artifacts=false placeholder_blocked=true require_complete_blocks=true scratch_clean=true' docs/TECHNICAL_STATUS.md docs/INSTALL.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'artifact_files=false' docs/RELEASE_OPERATIONS.md scripts/release_operations_scaffold.sh scripts/release_operations_scaffold_smoke.sh >/dev/null
grep -F 'placeholder_blocking=true' docs/RELEASE_OPERATIONS.md scripts/release_operations_scaffold.sh scripts/release_operations_scaffold_smoke.sh >/dev/null
grep -F 'release_operations_artifact_intake version=$version arch=$arch archive=true checksum=true manifest=true digest=$digest retained=true path=$evidence_dir' scripts/release_operations_artifact_intake.sh >/dev/null
grep -F 'release_operations_artifact_intake_smoke x86_64=true aarch64=true sidecars_verified=true retained_status=true mismatch_blocked=true scratch_clean=true' scripts/release_operations_artifact_intake_smoke.sh BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_artifact_intake_smoke x86_64=true aarch64=true sidecars_verified=true retained_status=true mismatch_blocked=true scratch_clean=true' docs/TECHNICAL_STATUS.md docs/INSTALL.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'tagged_artifacts=true signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=5' scripts/release_operations_artifact_intake_smoke.sh docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_signature_intake version=$version arch=$arch target=$target_kind signature=true retained=true path=$evidence_dir' scripts/release_operations_signature_intake.sh >/dev/null
grep -F 'release_operations_signature_intake_smoke archive=true checksum=true manifest=true x86_64=true aarch64=true placeholder_blocked=true target_required=true retained_status=true scratch_clean=true' scripts/release_operations_signature_intake_smoke.sh BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_signature_intake_smoke archive=true checksum=true manifest=true x86_64=true aarch64=true placeholder_blocked=true target_required=true retained_status=true scratch_clean=true' docs/TECHNICAL_STATUS.md docs/INSTALL.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'tagged_artifacts=true signatures=true publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=4' scripts/release_operations_signature_intake_smoke.sh docs/RELEASE_OPERATIONS.md CHANGELOG.md >/dev/null
grep -F 'does not perform cryptographic verification' docs/RELEASE_OPERATIONS.md docs/INSTALL.md docs/ARCHITECTURE.md >/dev/null
grep -F 'release_operations_receipt_intake version=$version receipt=$receipt_kind semantic=true placeholder_blocking=true retained=true path=$evidence_dir' scripts/release_operations_receipt_intake.sh >/dev/null
grep -F 'release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true' scripts/release_operations_receipt_intake_smoke.sh BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true' docs/TECHNICAL_STATUS.md docs/INSTALL.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'tagged_artifacts=true signatures=true publication=true dependency_bundle_redistribution=true compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=2' scripts/release_operations_receipt_intake_smoke.sh docs/RELEASE_OPERATIONS.md CHANGELOG.md >/dev/null
grep -F 'publication_prerequisites_missing' scripts/release_operations_status.sh scripts/release_operations_receipt_intake_smoke.sh docs/RELEASE_OPERATIONS.md CHANGELOG.md >/dev/null
grep -F 'receipt-intake smoke' docs/TECHNICAL_STATUS.md docs/PITCH_AUDIT.md >/dev/null
grep -F 'release_operations_acceptance_intake version=$version receipt=compositor compositor=$compositor semantic=true placeholder_blocking=true retained=true path=$evidence_dir' scripts/release_operations_acceptance_intake.sh >/dev/null
grep -F 'release_operations_acceptance_intake version=$version receipt=wayland-hid semantic=true placeholder_blocking=true retained=true path=$evidence_dir' scripts/release_operations_acceptance_intake.sh >/dev/null
grep -F 'release_operations_acceptance_intake_smoke compositors=6 wayland_hid=true semantic=true placeholder_blocked=true compositor_mismatch_blocked=true consent_required=true complete_status=true scratch_clean=true' scripts/release_operations_acceptance_intake_smoke.sh BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'release_operations_acceptance_intake_smoke compositors=6 wayland_hid=true semantic=true placeholder_blocked=true compositor_mismatch_blocked=true consent_required=true complete_status=true scratch_clean=true' docs/TECHNICAL_STATUS.md docs/INSTALL.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'tagged_artifacts=true signatures=true publication=true dependency_bundle_redistribution=true compositor_acceptance=true wayland_hid_consent=true complete=true external_blockers=0' scripts/release_operations_acceptance_intake_smoke.sh docs/RELEASE_OPERATIONS.md CHANGELOG.md >/dev/null
grep -F 'does not create compositor sessions or bypass portal consent' docs/RELEASE_OPERATIONS.md docs/INSTALL.md >/dev/null
grep -F 'acceptance-intake smoke' docs/TECHNICAL_STATUS.md docs/PITCH_AUDIT.md >/dev/null
for path in docs/TECHNICAL_STATUS.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/ARCHITECTURE.md docs/INSTALL.md docs/PITCH_AUDIT.md docs/RELEASE_CHECKLIST.md docs/RELEASE_OPERATIONS.md; do
  grep -F 'release_operations_status version=0.1.0 tagged_artifacts=false signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=6' "$path" >/dev/null
done
grep -F 'NOCTTY_RELEASE_EVIDENCE_DIR' docs/RELEASE_OPERATIONS.md scripts/release_operations_status.sh >/dev/null
grep -F 'wayland-hid-consent-receipt.txt' docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'compositors/niri.txt' docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'gtk_layer_shell_license_source=Arch .PKGINFO and upstream README; LICENSE_MIT.txt applies to many individual source files, not the project/package as a whole' scripts/package_bundle.sh >/dev/null
grep -F 'redistribution_ready=true' docs/TECHNICAL_STATUS.md docs/RELEASE_CHECKLIST.md docs/INSTALL.md docs/PITCH_AUDIT.md docs/ARCHITECTURE.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'NCT-077 follow-through' BACKLOG.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_CHECKLIST.md >/dev/null
grep -F 'independent redistribution review' docs/TECHNICAL_STATUS.md BACKLOG.md BACKLOG_ARCHIVE.md CHANGELOG.md docs/RELEASE_CHECKLIST.md docs/RELEASE_OPERATIONS.md >/dev/null
grep -F 'License boundary: the extracted `.PKGINFO` declares `LGPL-3.0-or-later`' vendor/gtk-layer-shell/README.md >/dev/null
! grep -F 'version: master' .github/workflows/release.yml >/dev/null
! grep -F 'Normalized single-build install-tree tarball:' docs/TECHNICAL_STATUS.md docs/INSTALL.md >/dev/null
! grep -F 'One normalized install-tarball build and SHA-256 self-verification' docs/TECHNICAL_STATUS.md docs/RELEASE_CHECKLIST.md >/dev/null
for path in docs/INSTALL.md docs/RELEASE_CHECKLIST.md vendor/gtk-layer-shell/README.md; do
  grep -F '.PKGINFO' "$path" >/dev/null
  grep -F 'LGPL-3.0-or-later' "$path" >/dev/null
  grep -F 'LICENSE_MIT.txt' "$path" >/dev/null
done
echo "docs_truth_endurance nocted_core_endurance=true cycles_per_mode=512 total_cycles=1024 ranking_evaluations=3072 duration_recorded=true proof_boundary=headless"
echo "docs_truth required_docs=true links=true product_complete=true release_hardening_closed=true backlog_partition=true task_ids_unique=true tab_add=true tab_reorder=true tab_reorder_pointer_drag=true tab_reorder_active_identity=true tab_reorder_rollback=true tab_reorder_persistence_coalesced=true window_controls=true tab_rename=true tab_color=true profile_presets=true navigation=true alt_scroll=true ctrl_alt_scroll=true tab_close=true pane_close=true pane_close_menu_popdown=true foreground_guard=true session_storage_released=true late_callback_guard=true popup_teardown=true root_timer_coalesced=true hidden_present_throttled=true mapped_redraw_only=true terminal_chords=true layout_presets=true layout_churn=32 resize_overlay=true note_overlay=true hot_session=true font_wheel=true editor_here=true editor_save_safety=true editor_shutdown=true window_resize=true tray=true tray_close=true settings_categories=true settings_stacking=true scrollback_configurable=true launch_continuity_qualification=true noctalia=true release_reproducibility=true release_workflow=true package_truth=true bundle_provenance=true release_operations=true native_allocation_polish=true native_deep_memory_hardening=true split_terminal_benchmark=true process_tree_memory=true pty_pump_bounded_drain=true native_output_throughput=true visible_grid_ring=true vt_ascii_run=true pty_event_source=true timer_read_polling=false output_present_coalesced=true event_source_cleanup=true descriptor_fallback=root_coalesced pane_exit_timers=0 source_cleanup=centralized installed_activation_harness=true render_abi=packed_rows render_abi_version=2 damage_tracking=dirty_spans glyph_batching=true glyph_cache=true frame_clock_present=true native_grid_renderer_qualification=true nocted_worker=bounded nocted_worker_lanes=2 nocted_worker_qualification=true nocted_worker_admission=true nocted_worker_transaction=true nocted_project_delta=true nocted_project_scale_qualification=true nocted_project_lifecycle=true nocted_multi_selection=true nocted_session_restore=true nocted_recent_project=true terminal_history_qualification=true terminal_compatibility_qualification=true terminal_real_tui_qualification=true terminal_ncurses_qualification=true terminal_system_tui_qualification=true terminal_system_tui_applications=10 terminal_session_qualification=true resource_qualification=true pane_context_init=explicit production_vte=false production_tree_sitter=false production_smoke_surface=false production_legacy_editor=false benchmark_order_isolated=true wezterm_split_ready=true pane_info=true pane_source=pty_proc pane_refresh=coalesced pane_info_dedup=true performance_algorithm_research=true"
