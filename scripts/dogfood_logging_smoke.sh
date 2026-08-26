#!/usr/bin/env sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-dogfood-logging.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
runtime="$scratch/runtime"
state="$scratch/state"
mkdir -p "$runtime/lib" "$state/noctty/logs"
install -m 0755 scripts/dogfood_launch.sh "$runtime/launch"
ln -s launch "$runtime/noctty"
ln -s launch "$runtime/nocted"

cat >"$runtime/noctty-bin" <<'EOF'
#!/usr/bin/env sh
printf 'stub_noctty_output\n'
printf 'dogfood_event session=%s event=omp_detected pane=1 value=1 detail=1111111111111111111111111111111111111111111111111111111111111111\n' \
  "$NOCTTY_DOGFOOD_SESSION_ID"
exit 0
EOF
cat >"$runtime/nocted-bin" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' 'Gtk-CRITICAL fixture' >&2
printf '%s\n' 'Gdk-CRITICAL fixture' >&2
printf '%s\n' 'GLib-CRITICAL fixture' >&2
printf '%s\n' 'GObject-CRITICAL fixture' >&2
printf '%s\n' 'native_grid_fixture_failed' >&2
printf '%s\n' 'thread 7 panic: fixture' >&2
exit 7
EOF
chmod +x "$runtime/noctty-bin" "$runtime/nocted-bin"

fast_status=$(XDG_STATE_HOME="$state" "$runtime/noctty" --status)
printf '%s\n' "$fast_status" | grep -F 'stub_noctty_output' >/dev/null
[ ! -d "$state/noctty/dogfood-sessions" ]

fixture_argument=$(printf '%s\n%s' '--fixture' 'forged_log_line=true')
XDG_STATE_HOME="$state" XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE \
  WAYLAND_DISPLAY=wayland-fixture GDK_BACKEND=wayland \
  "$runtime/noctty" "$fixture_argument"
set +e
XDG_STATE_HOME="$state" XDG_SESSION_TYPE=x11 GDK_BACKEND=x11 \
  "$runtime/nocted" --fixture
nocted_status=$?
set -e
[ "$nocted_status" -eq 7 ]

noctty_receipt=$(printf '%s\n' "$state"/noctty/dogfood-sessions/noctty-*.receipt)
nocted_receipt=$(printf '%s\n' "$state"/noctty/dogfood-sessions/nocted-*.receipt)
[ -f "$noctty_receipt" ]
[ -f "$nocted_receipt" ]
[ "$(stat -c '%a' "$noctty_receipt")" = 600 ]
[ "$(stat -c '%a' "$nocted_receipt")" = 600 ]
grep -Fx 'receipt_version=3' "$noctty_receipt" >/dev/null
grep -Fx 'state=finished' "$noctty_receipt" >/dev/null
grep -Fx 'exit_status=0' "$noctty_receipt" >/dev/null
grep -Fx 'runtime_warning_markers=0' "$noctty_receipt" >/dev/null
grep -Fx 'desktop_session=wayland' "$noctty_receipt" >/dev/null
grep -Fx 'desktop_name=KDE' "$noctty_receipt" >/dev/null
grep -Fx 'wayland_display=wayland-fixture' "$noctty_receipt" >/dev/null
grep -E '^binary_sha256=([0-9a-f]{64}|unknown)$' "$noctty_receipt" >/dev/null
grep -Fx 'backend=wayland' "$noctty_receipt" >/dev/null
grep -Fx 'state=finished' "$nocted_receipt" >/dev/null
grep -Fx 'exit_status=7' "$nocted_receipt" >/dev/null
grep -Fx 'runtime_warning_markers=6' "$nocted_receipt" >/dev/null
grep -Fx 'gtk_critical_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'gdk_critical_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'glib_critical_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'gobject_critical_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'native_grid_failure_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'panic_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'desktop_session=x11' "$nocted_receipt" >/dev/null

noctty_log=$(printf '%s\n' "$state"/noctty/logs/noctty-*.log)
nocted_log=$(printf '%s\n' "$state"/noctty/logs/nocted-*.log)
grep -F 'dogfood_launch app=noctty session_id=' "$noctty_log" >/dev/null
grep -F 'args= --fixture?forged_log_line=true' "$noctty_log" >/dev/null
! grep -Fx 'forged_log_line=true' "$noctty_log" >/dev/null
grep -F ' omp_version=deferred ' "$noctty_log" >/dev/null
grep -F 'dogfood_exit app=noctty session_id=' "$noctty_log" >/dev/null
grep -F 'duration_seconds=' "$noctty_log" >/dev/null
grep -F 'runtime_warning_markers=0' "$noctty_log" >/dev/null
grep -F 'native_grid_fixture_failed' "$nocted_log" >/dev/null
grep -F 'event=omp_log_review pane=0 value=1 detail=clean' "$noctty_log" >/dev/null
grep -F 'event=omp_version pane=0 value=1 detail=' "$noctty_log" >/dev/null

cat >"$runtime/noctty-bin" <<'EOF'
#!/usr/bin/env sh
kill -9 "$PPID"
exit 0
EOF
chmod +x "$runtime/noctty-bin"
set +e
XDG_STATE_HOME="$state" "$runtime/noctty" --killed-fixture 2>/dev/null
killed_status=$?
set -e
[ "$killed_status" -ne 0 ]
running_count=$(grep -lFx 'state=running' \
  "$state"/noctty/dogfood-sessions/noctty-*.receipt | wc -l)
[ "$running_count" -eq 1 ]

noctty_hash=$(awk -F= '$1 == "binary_sha256" { print $2; exit }' "$noctty_receipt")
nocted_hash=$(awk -F= '$1 == "binary_sha256" { print $2; exit }' "$nocted_receipt")
{
  printf 'build_receipt_version=1\n'
  printf 'install_epoch=4102444800\n'
  printf 'noctty_sha256=%s\n' "$noctty_hash"
  printf 'nocted_sha256=%s\n' "$nocted_hash"
} >"$state/noctty/dogfood-build.receipt"
chmod 0600 "$state/noctty/dogfood-build.receipt"
mkdir -p "$state/noctty/interaction-qualifications"
cat >"$state/noctty/interaction-qualifications/interaction-fixture.receipt" <<'EOF'
interaction_receipt_version=1
run_id=interaction-fixture
epoch=4102444800
mode=quick
spike_detected=false
scenario_split_open_elapsed_ms=1200
scenario_split_open_peak_tree_rss_kib=131072
scenario_split_open_latency_spike=false
scenario_split_open_memory_spike=false
EOF
chmod 0600 "$state/noctty/interaction-qualifications/interaction-fixture.receipt"
malformed_receipt="$state/noctty/dogfood-sessions/noctty-malformed.receipt"
sed \
  -e 's/^session_id=.*/session_id=noctty-malformed/' \
  -e 's/^exit_status=.*/exit_status=0invalid/' \
  "$noctty_receipt" >"$malformed_receipt"
chmod 0600 "$malformed_receipt"

cat >"$state/noctty/logs/noctty-legacy-two-hour.log" <<'EOF'
dogfood_launch app=noctty timestamp=2026-08-01T10:00:00+00:00 epoch=1785578400
legacy fixture
dogfood_exit app=noctty timestamp=2026-08-01T12:00:00+00:00 epoch=1785585600 duration_seconds=7200 status=1
EOF

mkdir -p "$scratch/tools"
cat >"$scratch/tools/coredumpctl" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' 'No coredumps found.' >&2
exit 1
EOF
chmod +x "$scratch/tools/coredumpctl"
diagnostic_report=$(PATH="$scratch/tools:$PATH" \
  ./scripts/local_diagnostic_report.sh "$state")
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_report version=4 no_network=true terminal_content=false' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_crashes inventory=true install_baseline=true retained_noctty=0 retained_nocted=0 retained_noctty_smoke=0 retained_nocted_smoke=0 since_install_noctty=0 since_install_nocted=0 since_install_noctty_smoke=0 since_install_nocted_smoke=0' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_summary app=noctty sessions=2 finished=1 failed=0 incomplete=1 runtime_warning_sessions=0' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_build app=noctty sessions=1 finished=1 failed=0 incomplete=0 runtime_warning_sessions=0' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_build app=nocted sessions=1 finished=1 failed=1 incomplete=0 runtime_warning_sessions=1' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_errors app=nocted gtk_critical=1 gdk_critical=1 glib_critical=1 gobject_critical=1 native_grid_failed=1 panic=1' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_install app=noctty sessions=0 finished=0 failed=0 incomplete=0 runtime_warning_sessions=0' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_install_errors app=noctty gtk_critical=0 gdk_critical=0 glib_critical=0 gobject_critical=0 native_grid_failed=0 panic=0' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -E 'local_diagnostic_cohort app=nocted binary_sha256=[0-9a-f]{64} .* sessions=1 finished=1 failed=1 incomplete=0 runtime_warning_sessions=1' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_receipt session_id=' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_interaction receipt_id=interaction-fixture mode=quick epoch=4102444800 scenario=split_open elapsed_ms=1200 peak_tree_rss_kib=131072 latency_spike=false memory_spike=false run_spike=false' >/dev/null
cat >"$scratch/tools/coredumpctl" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' 'fixture query failure' >&2
exit 2
EOF
failed_inventory=$(PATH="$scratch/tools:$PATH" \
  ./scripts/local_diagnostic_report.sh "$state")
printf '%s\n' "$failed_inventory" | grep -F \
  'local_diagnostic_crashes inventory=false install_baseline=false' >/dev/null
rm -f "$malformed_receipt"

status=$(./scripts/dogfood_runtime_status.sh "$state")
printf '%s\n' "$status" | grep -F 'receipt_sessions=3' >/dev/null
printf '%s\n' "$status" | grep -F 'legacy_sessions=1' >/dev/null
printf '%s\n' "$status" | grep -F 'noctty_sessions=3' >/dev/null
printf '%s\n' "$status" | grep -F 'noctty_finished=2' >/dev/null
printf '%s\n' "$status" | grep -F 'noctty_incomplete=1' >/dev/null
printf '%s\n' "$status" | grep -F 'noctty_two_hour_candidates=1' >/dev/null
printf '%s\n' "$status" | grep -F 'nocted_finished=1' >/dev/null
printf '%s\n' "$status" | grep -F 'nocted_failed=1' >/dev/null

cat >"$scratch/DOGFOOD_LOG.md" <<'EOF'
# Fixture

## 2026-08-01 — counted fixture

- Duration: derived from receipt
- Dogfood receipt: `noctty-legacy-two-hour`
- Panes/tabs used: 4
- Agent/TUI apps used: Pi
- NoctEd used: yes; edit/save/find/quick open
- Foreground-job close confirmation passed

## 2026-08-02 — duplicate fixture

- Duration: derived from receipt
- Dogfood receipt: `noctty-legacy-two-hour`
- Panes/tabs used: 4
EOF
cat >"$state/noctty/logs/noctty-omp-preflight-a.log" <<'EOF'
dogfood_launch app=noctty session_id=omp-preflight-a omp_version=deferred args=
dogfood_event session=omp-preflight-a event=omp_version pane=0 value=1 detail=omp/17.3.3
dogfood_event session=omp-preflight-a event=omp_detected pane=1 value=1 detail=1111111111111111111111111111111111111111111111111111111111111111
dogfood_event session=omp-preflight-a event=omp_detected pane=2 value=1 detail=2222222222222222222222222222222222222222222222222222222222222222
dogfood_event session=omp-preflight-a event=omp_detected pane=3 value=1 detail=3333333333333333333333333333333333333333333333333333333333333333
dogfood_event session=omp-preflight-a event=omp_detected pane=4 value=1 detail=4444444444444444444444444444444444444444444444444444444444444444
dogfood_event session=omp-preflight-a event=omp_concurrency pane=0 value=4 detail=active
dogfood_event session=omp-preflight-a event=omp_workspace pane=0 value=4 detail=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
dogfood_event session=omp-preflight-a event=omp_concurrent_streaming pane=0 value=4 detail=two_second_window
dogfood_event session=omp-preflight-a event=omp_independent_input pane=1 value=1 detail=observed
dogfood_event session=omp-preflight-a event=omp_independent_paste pane=1 value=1 detail=observed
dogfood_event session=omp-preflight-a event=omp_resize_during_output pane=1 value=1 detail=observed
dogfood_event session=omp-preflight-a event=omp_focus pane=1 value=1 detail=observed
dogfood_event session=omp-preflight-a event=omp_focus pane=2 value=1 detail=observed
dogfood_event session=omp-preflight-a event=omp_focus pane=3 value=1 detail=observed
dogfood_event session=omp-preflight-a event=omp_focus pane=4 value=1 detail=observed
dogfood_event session=omp-preflight-a event=omp_hide pane=0 value=4 detail=active
dogfood_event session=omp-preflight-a event=omp_show_after_hide pane=0 value=4 detail=active
dogfood_event session=omp-preflight-a event=omp_log_review pane=0 value=1 detail=clean
EOF
cat >"$state/noctty/logs/noctty-omp-preflight-b.log" <<'EOF'
dogfood_launch app=noctty session_id=omp-preflight-b omp_version=deferred args=
dogfood_event session=omp-preflight-b event=omp_version pane=0 value=1 detail=omp/17.3.3
dogfood_event session=omp-preflight-b event=omp_detected pane=1 value=1 detail=1111111111111111111111111111111111111111111111111111111111111111
dogfood_event session=omp-preflight-b event=omp_detected pane=2 value=1 detail=2222222222222222222222222222222222222222222222222222222222222222
dogfood_event session=omp-preflight-b event=omp_detected pane=3 value=1 detail=3333333333333333333333333333333333333333333333333333333333333333
dogfood_event session=omp-preflight-b event=omp_detected pane=4 value=1 detail=4444444444444444444444444444444444444444444444444444444444444444
dogfood_event session=omp-preflight-b event=omp_workspace pane=0 value=4 detail=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
dogfood_event session=omp-preflight-b event=omp_hot_restore pane=0 value=4 detail=restored
dogfood_event session=omp-preflight-b event=omp_close_cancel pane=0 value=1 detail=pane
dogfood_event session=omp-preflight-b event=omp_close_accept_isolated pane=4 value=3 detail=session_stopped
dogfood_event session=omp-preflight-b event=omp_normal_exit_cleanup pane=3 value=0 detail=sources_stopped
dogfood_event session=omp-preflight-b event=omp_output_integrity pane=3 value=4096 detail=pty_bytes_fed_once
dogfood_event session=omp-preflight-b event=omp_log_review pane=0 value=1 detail=clean
EOF
qualified=$(./scripts/dogfood_status.sh "$scratch/DOGFOOD_LOG.md" "$state")
printf '%s\n' "$qualified" | grep -F 'counted_sessions=1' >/dev/null
printf '%s\n' "$qualified" | grep -F 'documented_sessions=2' >/dev/null
printf '%s\n' "$qualified" | grep -F 'unverified_sessions=1' >/dev/null
printf '%s\n' "$qualified" | grep -F 'counted_seconds=7200' >/dev/null
printf '%s\n' "$qualified" | grep -F 'counted_hours=2.000' >/dev/null
printf '%s\n' "$qualified" | grep -F 'four_pane=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'agent_cli=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'nocted_real_edit=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'foreground_close_confirmation=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'dogfood_omp_status observed_sessions=1 qualified_sessions=1 qualified_version=omp/17.3.3 max_concurrent=4' >/dev/null
printf '%s\n' "$qualified" | grep -F 'separate_worktrees=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'concurrent_streaming=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'independent_input=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'independent_paste=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'resize_during_output=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'focus_isolation=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'hide_show=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'close_cancel=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'close_accept_isolated=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'normal_exit_cleanup=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'hot_restore=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'output_integrity=true' >/dev/null
printf '%s\n' "$qualified" | grep -F 'logs_clean=true compatible=true' >/dev/null

partial_state="$scratch/partial-state"
mkdir -p "$partial_state/noctty/logs"
cat >"$scratch/DOGFOOD_LOG_PARTIAL.md" <<'EOF'
# Partial fixture

## 2026-08-03 — incomplete OMP preflight (not counted)

## 2026-08-04 — independently incomplete OMP preflight (not counted)
EOF
cat >"$partial_state/noctty/logs/noctty-omp-partial-a.log" <<'EOF'
dogfood_launch app=noctty session_id=omp-partial-a omp_version=deferred args=
dogfood_event session=omp-partial-a event=omp_version pane=0 value=1 detail=omp/17.3.3
dogfood_event session=omp-partial-a event=omp_detected pane=11 value=1 detail=1111111111111111111111111111111111111111111111111111111111111111
dogfood_event session=omp-partial-a event=omp_detected pane=12 value=1 detail=2222222222222222222222222222222222222222222222222222222222222222
dogfood_event session=omp-partial-a event=omp_detected pane=13 value=1 detail=3333333333333333333333333333333333333333333333333333333333333333
dogfood_event session=omp-partial-a event=omp_detected pane=14 value=1 detail=4444444444444444444444444444444444444444444444444444444444444444
dogfood_event session=omp-partial-a event=omp_workspace pane=0 value=4 detail=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
dogfood_event session=omp-partial-a event=omp_concurrency pane=0 value=4 detail=active
dogfood_event session=omp-partial-a event=omp_concurrent_streaming pane=0 value=4 detail=two_second_window
dogfood_event session=omp-partial-a event=omp_independent_input pane=11 value=1 detail=observed
dogfood_event session=omp-partial-a event=omp_independent_paste pane=11 value=1 detail=observed
dogfood_event session=omp-partial-a event=omp_resize_during_output pane=11 value=1 detail=observed
dogfood_event session=omp-partial-a event=omp_hide pane=0 value=4 detail=active
dogfood_event session=omp-partial-a event=omp_show_after_hide pane=0 value=4 detail=active
dogfood_event session=omp-partial-a event=omp_close_cancel pane=0 value=1 detail=pane
dogfood_event session=omp-partial-a event=omp_close_accept_isolated pane=14 value=3 detail=session_stopped
dogfood_event session=omp-partial-a event=omp_normal_exit_cleanup pane=13 value=0 detail=sources_stopped
dogfood_event session=omp-partial-a event=omp_hot_restore pane=0 value=4 detail=restored
dogfood_event session=omp-partial-a event=omp_output_integrity pane=13 value=1024 detail=pty_bytes_fed_once
dogfood_event session=omp-partial-a event=omp_log_review pane=0 value=1 detail=clean
EOF
cat >"$partial_state/noctty/logs/noctty-omp-partial-b.log" <<'EOF'
dogfood_launch app=noctty session_id=omp-partial-b omp_version=deferred args=
dogfood_event session=omp-partial-b event=omp_version pane=0 value=1 detail=omp/17.3.3
dogfood_event session=omp-partial-b event=omp_detected pane=21 value=1 detail=1111111111111111111111111111111111111111111111111111111111111111
dogfood_event session=omp-partial-b event=omp_detected pane=22 value=1 detail=2222222222222222222222222222222222222222222222222222222222222222
dogfood_event session=omp-partial-b event=omp_detected pane=23 value=1 detail=3333333333333333333333333333333333333333333333333333333333333333
dogfood_event session=omp-partial-b event=omp_detected pane=24 value=1 detail=4444444444444444444444444444444444444444444444444444444444444444
dogfood_event session=omp-partial-b event=omp_workspace pane=0 value=4 detail=cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
dogfood_event session=omp-partial-b event=omp_concurrency pane=0 value=4 detail=active
dogfood_event session=omp-partial-b event=omp_concurrent_streaming pane=0 value=4 detail=two_second_window
dogfood_event session=omp-partial-b event=omp_independent_input pane=21 value=1 detail=observed
dogfood_event session=omp-partial-b event=omp_independent_paste pane=21 value=1 detail=observed
dogfood_event session=omp-partial-b event=omp_resize_during_output pane=21 value=1 detail=observed
dogfood_event session=omp-partial-b event=omp_focus pane=21 value=1 detail=observed
dogfood_event session=omp-partial-b event=omp_focus pane=22 value=1 detail=observed
dogfood_event session=omp-partial-b event=omp_focus pane=23 value=1 detail=observed
dogfood_event session=omp-partial-b event=omp_focus pane=24 value=1 detail=observed
dogfood_event session=omp-partial-b event=omp_hide pane=0 value=4 detail=active
dogfood_event session=omp-partial-b event=omp_show_after_hide pane=0 value=4 detail=active
dogfood_event session=omp-partial-b event=omp_close_cancel pane=0 value=1 detail=pane
dogfood_event session=omp-partial-b event=omp_close_accept_isolated pane=24 value=3 detail=session_stopped
dogfood_event session=omp-partial-b event=omp_normal_exit_cleanup pane=23 value=0 detail=sources_stopped
dogfood_event session=omp-partial-b event=omp_hot_restore pane=0 value=4 detail=restored
dogfood_event session=omp-partial-b event=omp_output_integrity pane=23 value=1024 detail=pty_bytes_fed_once
dogfood_event session=omp-partial-b event=omp_log_review pane=0 value=0 detail=error_detected
EOF
partial=$(./scripts/dogfood_status.sh "$scratch/DOGFOOD_LOG_PARTIAL.md" "$partial_state")
printf '%s\n' "$partial" | grep -F 'dogfood_omp_status observed_sessions=2 qualified_sessions=0 qualified_version=none max_concurrent=4' >/dev/null
printf '%s\n' "$partial" | grep -F 'focus_isolation=true' >/dev/null
printf '%s\n' "$partial" | grep -F 'logs_clean=true compatible=false' >/dev/null


printf 'dogfood_logging_smoke fast_control=true log_arguments_bounded=true atomic_receipts=true desktop_fingerprint=true categorized_errors=true upgrade_cohorts=true interaction_spikes=true local_diagnostic_report=true coredump_query_fail_closed=true malformed_receipt_rejected=true monotonic_duration=true nonzero_exit=true incomplete_launch=true private_mode=true legacy_import=true runtime_hours=true omp_extraction=true omp_fail_closed=true\n'
