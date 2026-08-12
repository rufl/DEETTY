#!/usr/bin/env sh
set -eu

verify_parent="${NOCTTY_VERIFY_PARENT:-.}"
case "$verify_parent" in
  /*) ;;
  *) verify_parent="$(pwd -P)/$verify_parent" ;;
esac
verify_root=$(mktemp -d "$verify_parent/.noctty-verify.XXXXXX")

cleanup() {
  if [ -n "${verify_root:-}" ]; then rm -rf "$verify_root"; fi
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$verify_root/tmp" "$verify_root/xdg-cache" "$verify_root/zig-local" "$verify_root/zig-global" "$verify_root/install"
export TMPDIR="$verify_root/tmp"
export XDG_CACHE_HOME="$verify_root/xdg-cache"
export NOCTTY_ZIG_CACHE_DIR="$verify_root/zig-local"
export NOCTTY_ZIG_GLOBAL_CACHE_DIR="$verify_root/zig-global"
export NOCTTY_INSTALL_PREFIX="$verify_root/install"
export NOCTTY_BUNDLE_PARENT="$verify_root/tmp"
export NOCTTY_HISTORY_PARENT="$verify_root/tmp"
export NOCTTY_FAIRNESS_PARENT="$verify_root/tmp"
export NOCTTY_NCURSES_QUALIFICATION_PARENT="$verify_root/tmp"
export NOCTTY_SYSTEM_TUI_QUALIFICATION_PARENT="$verify_root/tmp"

run_zig_build() {
  if [ "${NOCTTY_ZIG_SINGLE_JOB:-0}" = 1 ]; then
    zig build -j1 "$@"
  else
    zig build "$@"
  fi
}

./scripts/check_terminal_unicode.sh
./scripts/terminal_compatibility_qualification.sh
./scripts/terminal_session_qualification.sh
./scripts/terminal_agent_fairness_qualification.sh
./scripts/launch_continuity_qualification.sh
./scripts/terminal_ncurses_qualification.sh
./scripts/terminal_system_tui_qualification.sh
./scripts/native_grid_renderer_qualification.sh
./scripts/native_grid_pipeline_qualification.sh
run_zig_build --cache-dir "$NOCTTY_ZIG_CACHE_DIR" --global-cache-dir "$NOCTTY_ZIG_GLOBAL_CACHE_DIR" test
run_zig_build --cache-dir "$NOCTTY_ZIG_CACHE_DIR" --global-cache-dir "$NOCTTY_ZIG_GLOBAL_CACHE_DIR" check
./scripts/nocted_lsp_smoke.sh
./scripts/nocted_task_smoke.sh
./scripts/nocted_state_recovery_qualification.sh
./scripts/nocted_fuzz_race_qualification.sh
./scripts/nocted_core_stability_qualification.sh
./scripts/nocted_worker_qualification.sh
./scripts/nocted_project_index_qualification.sh
./scripts/nocted_single_instance_smoke.sh "$PWD/zig-out/bin/nocted"
bash -n ./scripts/nocted_native_endurance_qualification.sh
bash -n ./scripts/native_grid_authenticated_agent_qualification.sh
bash -n ./scripts/native_grid_installed_continuity_qualification.sh
bash -n ./scripts/native_grid_stability_qualification.sh
sh -n ./scripts/native_grid_shortcut_live_smoke.sh
bash -n ./scripts/terminal_benchmark.sh
sh -n ./scripts/terminal_benchmark_workload.sh
./scripts/package_smoke.sh
./scripts/release_contract_smoke.sh "$NOCTTY_INSTALL_PREFIX/bin/noctty"
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
./scripts/check_docs_truth.sh
./scripts/check_native_layout.sh

verify_root_path=$verify_root
rm -rf "$verify_root_path"
verify_root=
test ! -e "$verify_root_path"
echo "verify_cleanup scratch=true cache=true install=true artifacts=true"
