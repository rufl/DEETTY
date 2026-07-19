#!/usr/bin/env sh
set -eu

output=$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-maintenance-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_maintenance_smoke timer=true autosave=true project_refresh=true recovery_cleanup=true descriptor_fallback=root_coalesced pane_exit_timer=false source_cleanup=centralized exited=true$'
