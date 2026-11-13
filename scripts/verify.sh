#!/usr/bin/env sh
set -eu

verify_parent="${DINTTY_VERIFY_PARENT:-.}"
case "$verify_parent" in
  /*) ;;
  *) verify_parent="$(pwd -P)/$verify_parent" ;;
esac
verify_root=$(mktemp -d "$verify_parent/.dintty-verify.XXXXXX")
visible_root=

cleanup() {
  if [ -n "${verify_root:-}" ]; then rm -rf "$verify_root"; fi
  if [ -n "${visible_root:-}" ]; then rm -rf "$visible_root"; fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
visible_root=$(mktemp -d "$PWD/.dintty-verify-visible.XXXXXX")

mkdir -p "$verify_root/tmp" "$verify_root/xdg-cache" "$verify_root/zig-local" "$verify_root/zig-global" "$verify_root/install"
export TMPDIR="$verify_root/tmp"
export XDG_CACHE_HOME="$verify_root/xdg-cache"
export DINTTY_ZIG_CACHE_DIR="$verify_root/zig-local"
export DINTTY_ZIG_GLOBAL_CACHE_DIR="$verify_root/zig-global"
export DINTTY_INSTALL_PREFIX="$verify_root/install"
export ZIG_GLOBAL_CACHE_DIR="$DINTTY_ZIG_GLOBAL_CACHE_DIR"
export DINTTY_HISTORY_PARENT="$verify_root/tmp"
export DINTTY_FAIRNESS_PARENT="$verify_root/tmp"
export DINTTY_NCURSES_QUALIFICATION_PARENT="$verify_root/tmp"
export DINTTY_SYSTEM_TUI_QUALIFICATION_PARENT="$verify_root/tmp"

run_zig_build() {
  if [ "${DINTTY_ZIG_SINGLE_JOB:-0}" = 1 ]; then
    zig build -j1 "$@"
  else
    zig build "$@"
  fi
}

run_pressure_gated_display() {
  attempt=1
  while [ "$attempt" -le 6 ]; do
    if "$@"; then return 0; else status=$?; fi
    if [ "$status" -ne 75 ] || [ "$attempt" -eq 6 ]; then return "$status"; fi
    printf 'verify_display_retry attempt=%s status=deferred\n' "$attempt" >&2
    attempt=$((attempt + 1))
    sleep 10
  done
}

./scripts/check_public_source_hygiene.sh
./scripts/check_terminal_unicode.sh
./scripts/check_signal_traps.sh
# Admit isolated graphical proof before process/build qualification raises the
# pressure signal. Status-75 deferrals remain bounded and fail closed.
./scripts/check_display_isolation.sh
run_pressure_gated_display ./scripts/isolated_display_smoke.sh
run_pressure_gated_display ./scripts/native_grid_pane_close_smoke.sh
run_zig_build --cache-dir "$DINTTY_ZIG_CACHE_DIR" test
run_zig_build --cache-dir "$DINTTY_ZIG_CACHE_DIR" check
run_zig_build --prefix "$visible_root" --cache-dir "$DINTTY_ZIG_CACHE_DIR"
./scripts/cli_smoke.sh "$visible_root/bin/dintty" "$visible_root/bin/nocted"
run_pressure_gated_display ./scripts/nocted_single_instance_smoke.sh \
  "$visible_root/bin/nocted"
run_pressure_gated_display ./scripts/native_grid_single_instance_smoke.sh \
  "$visible_root/bin/dintty"
run_pressure_gated_display ./scripts/native_grid_state_recovery_smoke.sh \
  "$visible_root/bin/dintty"
./scripts/package_smoke.sh
# The shared bubble deliberately masks /dev/shm. Exercise the package installed
# below the scoped verify root through the reviewed private-socket fallback.
DINTTY_LEGACY_DISPLAY_RUNNER=1 ./scripts/native_grid_single_instance_smoke.sh \
  "$DINTTY_INSTALL_PREFIX/bin/dintty"
DINTTY_LEGACY_DISPLAY_RUNNER=1 ./scripts/native_grid_state_recovery_smoke.sh \
  "$DINTTY_INSTALL_PREFIX/bin/dintty"
./scripts/native_grid_wayland_activation_smoke.sh "$DINTTY_INSTALL_PREFIX/bin/dintty"

./scripts/terminal_compatibility_qualification.sh
# Keep the latency-sensitive fairness lane ahead of the 144-process lifecycle
# qualification so one proof lane does not distort the next through teardown churn.
./scripts/terminal_agent_fairness_qualification.sh
./scripts/terminal_session_qualification.sh
./scripts/launch_continuity_qualification.sh
./scripts/terminal_ncurses_qualification.sh
./scripts/terminal_system_tui_qualification.sh
./scripts/native_grid_renderer_qualification.sh
./scripts/native_grid_pipeline_qualification.sh
./scripts/nocted_lsp_smoke.sh
./scripts/nocted_task_smoke.sh
./scripts/nocted_state_recovery_qualification.sh
./scripts/nocted_fuzz_race_qualification.sh
./scripts/nocted_core_stability_qualification.sh
./scripts/nocted_worker_qualification.sh
./scripts/nocted_project_index_qualification.sh
bash -n ./scripts/nocted_native_endurance_qualification.sh
bash -n ./scripts/native_grid_authenticated_agent_qualification.sh
bash -n ./scripts/native_grid_installed_continuity_qualification.sh
bash -n ./scripts/native_grid_stability_qualification.sh
sh -n ./scripts/native_grid_shortcut_live_smoke.sh
sh -n ./scripts/native_grid_single_instance_smoke.sh
sh -n ./scripts/native_grid_state_recovery_smoke.sh
sh -n ./scripts/native_grid_wayland_activation_smoke.sh
sh -n ./scripts/local_diagnostic_report.sh
bash -n ./scripts/local_interaction_spike_report.sh
sh -n ./scripts/plasma_wayland_health.sh
bash -n ./scripts/plasma_wayland_post_upgrade.sh
bash -n ./scripts/terminal_benchmark.sh
sh -n ./scripts/terminal_benchmark_workload.sh
./scripts/release_contract_smoke.sh "$DINTTY_INSTALL_PREFIX/bin/dintty"
./scripts/package_manifests_smoke.sh
./scripts/release_workflow_contract_smoke.sh
./scripts/package_bundle_licenses_backend_smoke.sh
./scripts/package_bundle_manifest_smoke.sh
./scripts/release_operations_artifact_intake_smoke.sh
./scripts/release_operations_signature_intake_smoke.sh
./scripts/release_operations_receipt_intake_smoke.sh
./scripts/release_operations_acceptance_intake_smoke.sh
./scripts/release_operations_scaffold_smoke.sh
./scripts/release_operations_status_smoke.sh
./scripts/release_operations_status.sh
./scripts/noctalia_integration_smoke.sh
./scripts/package_reproducibility_smoke.sh
./scripts/ghostty_abi_smoke.sh
sh ./scripts/ghostty_upstream_surface_probe.sh
sh ./scripts/pty_smoke.sh
sh ./scripts/vt_smoke.sh
sh ./scripts/terminal_session_smoke.sh
./scripts/terminal_history_qualification.sh
./scripts/dogfood_logging_smoke.sh
./scripts/install_dogfood_smoke.sh
./scripts/windows_installer_timeout_smoke.sh
./scripts/check_docs_truth.sh
./scripts/check_native_layout.sh

verify_root_path=$verify_root
visible_root_path=$visible_root
rm -rf "$verify_root_path" "$visible_root_path"
verify_root=
visible_root=
test ! -e "$verify_root_path"
test ! -e "$visible_root_path"
echo "verify_cleanup scratch=true visible_staging=true cache=true install=true artifacts=true"
