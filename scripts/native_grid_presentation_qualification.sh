#!/usr/bin/env bash
set -euo pipefail

./scripts/require_isolated_display.sh --dedicated
export LC_ALL=C

scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-presentation-qualification.XXXXXX")
cleanup() {
    rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

for mode in Debug ReleaseSafe; do
    prefix="$scratch/$mode"
    ZIG_GLOBAL_CACHE_DIR="$scratch/global-cache" zig build deetty-smoke-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$scratch/cache-$mode"
    for backend in wayland x11; do
        output=$(env GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
            GDK_BACKEND="$backend" timeout 30 \
            "$prefix/bin/deetty-smoke" \
            --native-grid-presentation-qualification)
        printf '%s\n' "$output"
        printf '%s\n' "$output" | grep -E \
            "^native_grid_presentation_qualification backend=$backend samples=64 key_to_draw_p50_ns=[1-9][0-9]* key_to_draw_p95_ns=[1-9][0-9]* key_to_draw_p99_ns=[1-9][0-9]* key_to_frame_p50_ns=[1-9][0-9]* key_to_frame_p95_ns=[1-9][0-9]* key_to_frame_p99_ns=[1-9][0-9]* frame_interval_p50_ns=[1-9][0-9]* frame_interval_p95_ns=[1-9][0-9]* frame_interval_p99_ns=[1-9][0-9]* predicted_samples=64 key_to_predicted_p50_ns=[1-9][0-9]* key_to_predicted_p95_ns=[1-9][0-9]* key_to_predicted_p99_ns=[1-9][0-9]* presentation_feedback_samples=[0-9]+ key_to_present_p50_ns=[0-9]+ key_to_present_p95_ns=[0-9]+ key_to_present_p99_ns=[0-9]+ missed_deadlines=[0-9]+ mapped_surface=true frame_clock=true synthetic_gtk_keys=true gdk_event_queue=false hid=false passed=true$" >/dev/null
        if [ "$backend" = wayland ]; then
            printf '%s\n' "$output" | grep -E \
                'presentation_feedback_samples=[1-9][0-9]*' >/dev/null
        fi
        printf '%s\n' "$output" | grep -F \
            'native_grid_presentation_host gtk=true mapped=true pty=true vt=true exited=true' >/dev/null
    done
done

echo 'native_grid_presentation_matrix debug=true release_safe=true wayland=true x11=true samples_per_run=64 production_pty=true production_vt=true production_gtk=true mapped_surface=true key_to_draw=true key_to_frame=true frame_intervals=true wayland_presentation_feedback=true x11_presentation_feedback_optional=true synthetic_gtk_keys=true gdk_event_queue=false hid=false scratch_clean=true'