#!/usr/bin/env bash
set -euo pipefail

./scripts/require_isolated_display.sh --dedicated
export LC_ALL=C

mode=${1:---quick}
case "$mode" in
    --quick|--full) ;;
    *) echo "usage: $0 [--quick|--full]" >&2; exit 2 ;;
esac

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
receipt_dir="$state_home/noctty/interaction-qualifications"
mkdir -p "$receipt_dir"
chmod 0700 "$receipt_dir"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-interaction-spikes.XXXXXX")
receipt_new=
cleanup() {
    [[ -z "$receipt_new" ]] || rm -f "$receipt_new"
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

receipt_field() {
    awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$2"
}

safe_token() {
    local value
    value=$(printf '%s' "$1" | tr -cd 'A-Za-z0-9._:+/-' | cut -c1-128)
    [[ -n "$value" ]] && printf '%s' "$value" || printf unknown
}

latest_matching_receipt() {
    local candidate candidate_mode
    while IFS= read -r candidate; do
        [[ -f "$candidate" ]] || continue
        candidate_mode=$(receipt_field mode "$candidate")
        if [[ "$candidate_mode" == "${mode#--}" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done < <(ls -1t "$receipt_dir"/*.receipt 2>/dev/null || true)
    return 0
}

previous_receipt=$(latest_matching_receipt)
zig build noctty-smoke-binary nocted-smoke-binary \
    -Doptimize=ReleaseSafe \
    --global-cache-dir .zig-cache/global

scenario_names=()
scenario_elapsed_ms=()
scenario_root_pss_kib=()
scenario_root_rss_kib=()
scenario_tree_pss_kib=()
scenario_tree_rss_kib=()
scenario_samples=()
scenario_latency_spikes=()
scenario_memory_spikes=()
spike_detected=false

measure_scenario() {
    local name=$1 expected=$2
    shift 2
    local output="$scratch/$name.log"
    local started_ns pid root_pss root_rss tree_line tree_pss tree_rss
    local peak_root_pss=0 peak_root_rss=0 peak_tree_pss=0 peak_tree_rss=0
    local samples=0 status elapsed_ms previous_elapsed previous_tree_rss
    local latency_spike=false memory_spike=false

    started_ns=$(date +%s%N)
    env GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings GDK_BACKEND=wayland \
        "$@" >"$output" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        root_pss=$(awk '/^Pss:/ { print $2; exit }' "/proc/$pid/smaps_rollup" 2>/dev/null || true)
        root_rss=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$pid/status" 2>/dev/null || true)
        tree_line=$(./scripts/process_tree_memory.sh "$pid" 2>/dev/null || true)
        tree_pss=$(sed -n 's/.* pss_kib=\([0-9][0-9]*\).*/\1/p' <<<"$tree_line")
        tree_rss=$(sed -n 's/.* rss_kib=\([0-9][0-9]*\).*/\1/p' <<<"$tree_line")
        [[ -z "$root_pss" || "$root_pss" -le "$peak_root_pss" ]] || peak_root_pss=$root_pss
        [[ -z "$root_rss" || "$root_rss" -le "$peak_root_rss" ]] || peak_root_rss=$root_rss
        [[ -z "$tree_pss" || "$tree_pss" -le "$peak_tree_pss" ]] || peak_tree_pss=$tree_pss
        [[ -z "$tree_rss" || "$tree_rss" -le "$peak_tree_rss" ]] || peak_tree_rss=$tree_rss
        samples=$((samples + 1))
        sleep 0.02
    done
    if wait "$pid"; then status=0; else status=$?; fi
    elapsed_ms=$((($(date +%s%N) - started_ns) / 1000000))
    if [[ "$status" -ne 0 ]]; then
        printf 'local_interaction_failure scenario=%s exit_status=%s\n' "$name" "$status" >&2
        tail -n 80 "$output" >&2
        exit "$status"
    fi
    grep -F "$expected" "$output" >/dev/null
    ((samples > 0))
    ((peak_tree_pss > 0))
    ((peak_tree_rss > 0))

    previous_elapsed=0
    previous_tree_rss=0
    if [[ -n "$previous_receipt" ]]; then
        previous_elapsed=$(receipt_field "scenario_${name}_elapsed_ms" "$previous_receipt")
        previous_tree_rss=$(receipt_field "scenario_${name}_peak_tree_rss_kib" "$previous_receipt")
        [[ "$previous_elapsed" =~ ^[0-9]+$ ]] || previous_elapsed=0
        [[ "$previous_tree_rss" =~ ^[0-9]+$ ]] || previous_tree_rss=0
    fi
    # Deliberately generous bounds: both a ratio and an absolute increase are
    # required. This flags regressions rather than routine scheduler variance.
    if ((previous_elapsed > 0 && elapsed_ms > previous_elapsed * 3 && elapsed_ms > previous_elapsed + 1000)); then
        latency_spike=true
        spike_detected=true
    fi
    if ((previous_tree_rss > 0 && peak_tree_rss * 2 > previous_tree_rss * 3 && peak_tree_rss > previous_tree_rss + 65536)); then
        memory_spike=true
        spike_detected=true
    fi

    scenario_names+=("$name")
    scenario_elapsed_ms+=("$elapsed_ms")
    scenario_root_pss_kib+=("$peak_root_pss")
    scenario_root_rss_kib+=("$peak_root_rss")
    scenario_tree_pss_kib+=("$peak_tree_pss")
    scenario_tree_rss_kib+=("$peak_tree_rss")
    scenario_samples+=("$samples")
    scenario_latency_spikes+=("$latency_spike")
    scenario_memory_spikes+=("$memory_spike")
    printf 'local_interaction_spike scenario=%s elapsed_ms=%d peak_root_pss_kib=%d peak_root_rss_kib=%d peak_tree_pss_kib=%d peak_tree_rss_kib=%d samples=%d previous_elapsed_ms=%d previous_tree_rss_kib=%d latency_spike=%s memory_spike=%s passed=true\n' \
        "$name" "$elapsed_ms" "$peak_root_pss" "$peak_root_rss" \
        "$peak_tree_pss" "$peak_tree_rss" "$samples" "$previous_elapsed" \
        "$previous_tree_rss" "$latency_spike" "$memory_spike"
}

measure_scenario split_open \
    'native_grid_recursive_split_smoke panes=4 sessions=4' \
    ./zig-out/bin/noctty-smoke --native-grid-recursive-split-smoke
measure_scenario pane_close \
    'native_grid_pane_close_smoke initial_panes=2' \
    ./zig-out/bin/noctty-smoke --native-grid-pane-close-smoke
measure_scenario tab_open_close \
    'native_grid_two_tab_smoke initial_tabs=1' \
    ./zig-out/bin/noctty-smoke --native-grid-two-tab-smoke
if [[ "$mode" == --full ]]; then
    measure_scenario layout_churn \
        'native_grid_layout_preset_smoke context_menu=true' \
        ./zig-out/bin/noctty-smoke --native-grid-layout-preset-smoke
fi
measure_scenario editor_workflow \
    'nocted_search_load_native_gate search_load=true cycles=8' \
    env NOCTED_GDK_BACKEND=wayland NOCTED_SKIP_PROJECT_LIFECYCLE=1 \
    ./scripts/nocted_native_smoke.sh ./zig-out/bin/nocted-smoke

run_id="interaction-$(date +%Y%m%d-%H%M%S)-$$"
receipt="$receipt_dir/$run_id.receipt"
receipt_new="$receipt.new"
{
    printf 'interaction_receipt_version=1\n'
    printf 'run_id=%s\n' "$run_id"
    printf 'timestamp=%s\n' "$(date --iso-8601=seconds)"
    printf 'epoch=%s\n' "$(date +%s)"
    printf 'mode=%s\n' "${mode#--}"
    printf 'session_type=%s\n' "$(safe_token "${XDG_SESSION_TYPE:-unknown}")"
    printf 'kernel_release=%s\n' "$(safe_token "$(uname -r)")"
    printf 'plasma_version=%s\n' "$(safe_token "$(plasmashell --version 2>/dev/null | awk 'NR == 1 { print $NF; exit }' || printf unknown)")"
    printf 'kwin_version=%s\n' "$(safe_token "$(kwin_wayland --version 2>/dev/null | awk 'NR == 1 { print $NF; exit }' || printf unknown)")"
    printf 'noctty_smoke_sha256=%s\n' "$(sha256sum ./zig-out/bin/noctty-smoke | awk '{ print $1 }')"
    printf 'nocted_smoke_sha256=%s\n' "$(sha256sum ./zig-out/bin/nocted-smoke | awk '{ print $1 }')"
    printf 'spike_detected=%s\n' "$spike_detected"
    for ((index = 0; index < ${#scenario_names[@]}; index++)); do
        name=${scenario_names[index]}
        printf 'scenario_%s_elapsed_ms=%s\n' "$name" "${scenario_elapsed_ms[index]}"
        printf 'scenario_%s_peak_root_pss_kib=%s\n' "$name" "${scenario_root_pss_kib[index]}"
        printf 'scenario_%s_peak_root_rss_kib=%s\n' "$name" "${scenario_root_rss_kib[index]}"
        printf 'scenario_%s_peak_tree_pss_kib=%s\n' "$name" "${scenario_tree_pss_kib[index]}"
        printf 'scenario_%s_peak_tree_rss_kib=%s\n' "$name" "${scenario_tree_rss_kib[index]}"
        printf 'scenario_%s_samples=%s\n' "$name" "${scenario_samples[index]}"
        printf 'scenario_%s_latency_spike=%s\n' "$name" "${scenario_latency_spikes[index]}"
        printf 'scenario_%s_memory_spike=%s\n' "$name" "${scenario_memory_spikes[index]}"
    done
} >"$receipt_new"
chmod 0600 "$receipt_new"
mv -f "$receipt_new" "$receipt"
receipt_new=
ls -1t "$receipt_dir"/*.receipt 2>/dev/null | awk 'NR > 50' |
    while IFS= read -r stale_receipt; do rm -f "$stale_receipt"; done
printf 'local_interaction_summary version=1 mode=%s scenarios=%d spike_detected=%s no_network=true terminal_content=false editor_content=false receipt_id=%s\n' \
    "${mode#--}" "${#scenario_names[@]}" "$spike_detected" "$run_id"
[[ "$spike_detected" == false ]]
