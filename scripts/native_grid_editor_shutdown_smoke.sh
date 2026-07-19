#!/usr/bin/env sh
set -eu

zig build --global-cache-dir .zig-cache/global smoke-binaries
smoke_binary=./zig-out/bin/noctty-smoke
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    if ! output=$(GTK_MODULES= "$smoke_binary" \
        --native-grid-editor-shutdown-smoke 2>&1); then
        printf '%s\n' "$output"
        exit 1
    fi
else
    if ! output=$(dbus-run-session -- env GTK_MODULES= \
        "$smoke_binary" --native-grid-editor-shutdown-smoke 2>&1); then
        printf '%s\n' "$output"
        exit 1
    fi
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_editor_shutdown_smoke contexts=2 editors=2 prompts=5 direct_prompt=true modal_deferred=true modal_depth=1 prompt_owned=true wm_cancel=true retryable=true window_alive=true editors_alive=true ptys_alive=2 tray_alive=true toolbar_retry=true save_failure=true failure_survived=true natural_cancel=true natural_retry=true natural_dwell_ms=80 already_exited=2 exit_codes=7,9 exit_codes_preserved=true active_validation=true save=true discard=true saved_file=true discarded_file=true sessions=2 sessions_stopped=2 accepted_origin=toolbar tray_unregistered=true menu_unregistered=true exited=true$'
