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

# This qualification is intentionally local and operator-initiated. Pacman is
# queried only against its existing local database; no package refresh occurs.
./scripts/plasma_wayland_health.sh
./scripts/check_no_surprise_network.sh
zig build check -j1 --summary all
./scripts/dogfood_logging_smoke.sh
./scripts/local_interaction_spike_report.sh "$mode"

if [[ "$mode" == --full ]]; then
    env GTK_MODULES= NO_AT_BRIDGE=1 GDK_BACKEND=wayland \
        ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run \
        -Doptimize=ReleaseSafe \
        -- --native-grid-maintenance-smoke
    ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build nocted-smoke-binary \
        -Doptimize=ReleaseSafe
    NOCTED_GDK_BACKEND=wayland \
        NOCTED_SKIP_PROJECT_LIFECYCLE=1 \
        ./scripts/nocted_native_smoke.sh ./zig-out/bin/nocted-smoke
fi

# Exercise the exact installed wrappers after the source gates. These bounded
# invocations create current-install receipts without opening a GUI or reading
# terminal content.
"$HOME/.local/bin/noctty" --version
"$HOME/.local/bin/nocted" --version

report=$(./scripts/local_diagnostic_report.sh)
printf '%s\n' "$report"
crash_line=$(printf '%s\n' "$report" | grep '^local_diagnostic_crashes ')
grep -F 'install_baseline=true' <<<"$crash_line" >/dev/null
grep -F 'since_install_noctty=0' <<<"$crash_line" >/dev/null
grep -F 'since_install_nocted=0' <<<"$crash_line" >/dev/null
grep -F 'since_install_noctty_smoke=0' <<<"$crash_line" >/dev/null
grep -F 'since_install_nocted_smoke=0' <<<"$crash_line" >/dev/null
for app in noctty nocted; do
    install_line=$(grep "^local_diagnostic_current_install app=$app " <<<"$report")
    grep -E ' sessions=[1-9][0-9]* ' <<<"$install_line" >/dev/null
    grep -F ' failed=0 ' <<<"$install_line" >/dev/null
    grep -F ' incomplete=0 ' <<<"$install_line" >/dev/null
    grep -F ' runtime_warning_sessions=0' <<<"$install_line" >/dev/null
    grep -Fx "local_diagnostic_current_install_errors app=$app gtk_critical=0 gdk_critical=0 glib_critical=0 gobject_critical=0 native_grid_failed=0 panic=0" \
        <<<"$report" >/dev/null
done
./scripts/plasma_wayland_health.sh

printf 'plasma_wayland_post_upgrade mode=%s passed=true no_network=true build_check=true logging=true current_install_crashes=0 qualification_crashes=0 current_install_errors=0 interaction_spikes=0 release_safe_wayland=%s\n' \
    "${mode#--}" "$([[ "$mode" == --full ]] && printf true || printf false)"
