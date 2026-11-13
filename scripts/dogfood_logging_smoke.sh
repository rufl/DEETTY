#!/usr/bin/env sh
set -eu

command -v flock >/dev/null
scratch=$(mktemp -d "${TMPDIR:-/tmp}/deetty-dogfood-logging.XXXXXX")
locker_pid=
cleanup() {
  if [ -n "$locker_pid" ]; then
    kill -TERM "-$locker_pid" 2>/dev/null || kill -TERM "$locker_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM
runtime="$scratch/runtime"
state="$scratch/state"
mkdir -p "$runtime/lib" "$state/deetty/logs"
install -m 0755 scripts/dogfood_launch.sh "$runtime/launch"
ln -s launch "$runtime/deetty"
ln -s launch "$runtime/nocted"

cat >"$runtime/deetty-bin" <<'EOF'
#!/usr/bin/env sh
printf 'stub_deetty_output\n'
printf 'dogfood_event session=%s event=omp_detected pane=1 value=1 detail=1111111111111111111111111111111111111111111111111111111111111111\n' \
  "$DEETTY_DOGFOOD_SESSION_ID"
exit 0
EOF
cat >"$runtime/nocted-bin" <<'EOF'
#!/usr/bin/env sh
case "${1:-}" in
  --version|--help|-h)
    printf 'stub_nocted_version\n'
    exit 0
    ;;
esac
printf '%s\n' 'Gtk-CRITICAL fixture' >&2
printf '%s\n' 'Gdk-CRITICAL fixture' >&2
printf '%s\n' 'GLib-CRITICAL fixture' >&2
printf '%s\n' 'GObject-CRITICAL fixture' >&2
printf '%s\n' 'native_grid_fixture_failed' >&2
printf '%s\n' 'thread 7 panic: fixture' >&2
printf '%s\n' 'Gdk-WARNING **: Tried to map a popup with a non-top most parent' >&2
exit 7
EOF
chmod +x "$runtime/deetty-bin" "$runtime/nocted-bin"

fast_status=$(XDG_STATE_HOME="$state" "$runtime/deetty" --status)
printf '%s\n' "$fast_status" | grep -F 'stub_deetty_output' >/dev/null
[ ! -d "$state/deetty/dogfood-sessions" ]
fast_version=$(XDG_STATE_HOME="$state" "$runtime/nocted" --version)
printf '%s\n' "$fast_version" | grep -F 'stub_nocted_version' >/dev/null
[ ! -d "$state/deetty/dogfood-sessions" ]
for app in deetty nocted; do
  for option in --help -h; do
    XDG_STATE_HOME="$state" "$runtime/$app" "$option" >/dev/null
    [ ! -d "$state/deetty/dogfood-sessions" ]
  done
done

home="$scratch/home"
instance_lock="$home/.local/state/deetty/instance.lock"
mkdir -p "$(dirname "$instance_lock")"
setsid sh -c '
  exec 9>"$1"
  flock -x 9
  : >"$2"
  while [ ! -e "$3" ]; do sleep 0.01; done
' sh "$instance_lock" "$scratch/lock-ready" "$scratch/lock-stop" &
locker_pid=$!
while [ ! -e "$scratch/lock-ready" ]; do sleep 0.01; done
fast_show=$(HOME="$home" XDG_STATE_HOME="$state" "$runtime/deetty" --show)
printf '%s\n' "$fast_show" | grep -F 'stub_deetty_output' >/dev/null
[ ! -d "$state/deetty/dogfood-sessions" ]
: >"$scratch/lock-stop"
wait "$locker_pid"
locker_pid=

fixture_argument=$(printf '%s\n%s' '--fixture' 'forged_log_line=true')
XDG_STATE_HOME="$state" XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE \
  WAYLAND_DISPLAY=wayland-fixture GDK_BACKEND=wayland \
  "$runtime/deetty" "$fixture_argument"
set +e
XDG_STATE_HOME="$state" XDG_SESSION_TYPE=x11 GDK_BACKEND=x11 \
  "$runtime/nocted" --fixture
nocted_status=$?
set -e
[ "$nocted_status" -eq 7 ]

deetty_receipt=$(printf '%s\n' "$state"/deetty/dogfood-sessions/deetty-*.receipt)
nocted_receipt=$(printf '%s\n' "$state"/deetty/dogfood-sessions/nocted-*.receipt)
[ -f "$deetty_receipt" ]
[ -f "$nocted_receipt" ]
[ "$(stat -c '%a' "$deetty_receipt")" = 600 ]
[ "$(stat -c '%a' "$nocted_receipt")" = 600 ]
grep -Fx 'receipt_version=3' "$deetty_receipt" >/dev/null
grep -Fx 'state=finished' "$deetty_receipt" >/dev/null
grep -Fx 'exit_status=0' "$deetty_receipt" >/dev/null
grep -Fx 'runtime_warning_markers=0' "$deetty_receipt" >/dev/null
grep -Fx 'desktop_session=wayland' "$deetty_receipt" >/dev/null
grep -Fx 'desktop_name=KDE' "$deetty_receipt" >/dev/null
grep -Fx 'wayland_display=wayland-fixture' "$deetty_receipt" >/dev/null
grep -E '^binary_sha256=([0-9a-f]{64}|unknown)$' "$deetty_receipt" >/dev/null
grep -Fx 'backend=wayland' "$deetty_receipt" >/dev/null
grep -Fx 'state=finished' "$nocted_receipt" >/dev/null
grep -Fx 'exit_status=7' "$nocted_receipt" >/dev/null
grep -Fx 'runtime_warning_markers=7' "$nocted_receipt" >/dev/null
grep -Fx 'gtk_critical_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'gdk_critical_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'glib_critical_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'gobject_critical_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'native_grid_failure_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'panic_markers=1' "$nocted_receipt" >/dev/null
grep -Fx 'desktop_session=x11' "$nocted_receipt" >/dev/null

deetty_log=$(printf '%s\n' "$state"/deetty/logs/deetty-*.log)
nocted_log=$(printf '%s\n' "$state"/deetty/logs/nocted-*.log)
grep -F 'dogfood_launch app=deetty session_id=' "$deetty_log" >/dev/null
grep -F 'args= --fixture?forged_log_line=true' "$deetty_log" >/dev/null
! grep -Fx 'forged_log_line=true' "$deetty_log" >/dev/null
grep -F ' omp_version=deferred ' "$deetty_log" >/dev/null
grep -F 'dogfood_exit app=deetty session_id=' "$deetty_log" >/dev/null
grep -F 'duration_seconds=' "$deetty_log" >/dev/null
grep -F 'runtime_warning_markers=0' "$deetty_log" >/dev/null
grep -F 'native_grid_fixture_failed' "$nocted_log" >/dev/null
grep -F 'event=omp_log_review pane=0 value=1 detail=clean' "$deetty_log" >/dev/null
grep -F 'event=omp_version pane=0 value=1 detail=' "$deetty_log" >/dev/null

cat >"$runtime/deetty-bin" <<'EOF'
#!/usr/bin/env sh
kill -9 "$PPID"
exit 0
EOF
chmod +x "$runtime/deetty-bin"
set +e
XDG_STATE_HOME="$state" "$runtime/deetty" --killed-fixture 2>/dev/null
killed_status=$?
set -e
[ "$killed_status" -ne 0 ]
running_count=$(grep -lFx 'state=running' \
  "$state"/deetty/dogfood-sessions/deetty-*.receipt | wc -l)
[ "$running_count" -eq 1 ]

deetty_hash=$(awk -F= '$1 == "binary_sha256" { print $2; exit }' "$deetty_receipt")
nocted_hash=$(awk -F= '$1 == "binary_sha256" { print $2; exit }' "$nocted_receipt")
{
  printf 'build_receipt_version=1\n'
  printf 'install_epoch=4102444800\n'
  printf 'deetty_sha256=%s\n' "$deetty_hash"
  printf 'nocted_sha256=%s\n' "$nocted_hash"
} >"$state/deetty/dogfood-build.receipt"
chmod 0600 "$state/deetty/dogfood-build.receipt"
mkdir -p "$state/deetty/interaction-qualifications"
cat >"$state/deetty/interaction-qualifications/interaction-fixture.receipt" <<'EOF'
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
chmod 0600 "$state/deetty/interaction-qualifications/interaction-fixture.receipt"
malformed_receipt="$state/deetty/dogfood-sessions/deetty-malformed.receipt"
sed \
  -e 's/^session_id=.*/session_id=deetty-malformed/' \
  -e 's/^exit_status=.*/exit_status=0invalid/' \
  "$deetty_receipt" >"$malformed_receipt"
chmod 0600 "$malformed_receipt"

cat >"$state/deetty/logs/deetty-legacy-two-hour.log" <<'EOF'
dogfood_launch app=deetty timestamp=2026-08-01T10:00:00+00:00 epoch=1785578400
legacy fixture
dogfood_exit app=deetty timestamp=2026-08-01T12:00:00+00:00 epoch=1785585600 duration_seconds=7200 status=1
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
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_crashes inventory=true install_baseline=true retained_deetty=0 retained_nocted=0 retained_deetty_smoke=0 retained_nocted_smoke=0 since_install_deetty=0 since_install_nocted=0 since_install_deetty_smoke=0 since_install_nocted_smoke=0' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_summary app=deetty sessions=2 finished=1 failed=0 incomplete=1 runtime_warning_sessions=0' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_build app=deetty sessions=1 finished=1 failed=0 incomplete=0 runtime_warning_sessions=0' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_build app=nocted sessions=1 finished=1 failed=1 incomplete=0 runtime_warning_sessions=1' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_errors app=nocted gtk_critical=1 gdk_critical=1 glib_critical=1 gobject_critical=1 native_grid_failed=1 panic=1' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_install app=deetty sessions=0 finished=0 failed=0 incomplete=0 runtime_warning_sessions=0' >/dev/null
printf '%s\n' "$diagnostic_report" | grep -F 'local_diagnostic_current_install_errors app=deetty gtk_critical=0 gdk_critical=0 glib_critical=0 gobject_critical=0 native_grid_failed=0 panic=0' >/dev/null
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
printf '%s\n' "$status" | grep -F 'deetty_sessions=3' >/dev/null
printf '%s\n' "$status" | grep -F 'deetty_finished=2' >/dev/null
printf '%s\n' "$status" | grep -F 'deetty_incomplete=1' >/dev/null
printf '%s\n' "$status" | grep -F 'deetty_two_hour_candidates=1' >/dev/null
printf '%s\n' "$status" | grep -F 'nocted_finished=1' >/dev/null
printf '%s\n' "$status" | grep -F 'nocted_failed=1' >/dev/null

cat >"$scratch/DOGFOOD_LOG.md" <<'EOF'
# Fixture

## 2026-08-01 — counted fixture

- Duration: derived from receipt
- Dogfood receipt: `deetty-legacy-two-hour`
- Work performed: operator-confirmed daily terminal work
- Panes/tabs used: 4
- Agent/TUI apps used: OMP 17.3.3
- NoctEd used: yes; edit/save/find/quick open
- Foreground-job close confirmation passed

## 2026-08-02 — duplicate fixture

- Duration: derived from receipt
- Dogfood receipt: `deetty-legacy-two-hour`
- Panes/tabs used: 4
EOF
cat >"$state/deetty/logs/deetty-omp-preflight-a.log" <<'EOF'
dogfood_launch app=deetty session_id=omp-preflight-a omp_version=deferred args=
dogfood_event session=omp-preflight-a event=omp_version pane=0 value=1 detail=omp/17.3.3
dogfood_event session=omp-preflight-a event=omp_detected pane=1 value=1 detail=1111111111111111111111111111111111111111111111111111111111111111
deetty_dogfood_event session_id=omp-preflight-a event=omp_detected pane=2 value=1 detail=2222222222222222222222222222222222222222222222222222222222222222 monotonic_ms=1
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
cat >"$state/deetty/logs/deetty-omp-preflight-b.log" <<'EOF'
dogfood_launch app=deetty session_id=omp-preflight-b omp_version=deferred args=
dogfood_event session=omp-preflight-b event=omp_version pane=0 value=1 detail=omp/17.3.3
dogfood_event session=omp-preflight-b event=omp_detected pane=1 value=1 detail=1111111111111111111111111111111111111111111111111111111111111111
deetty_dogfood_event session_id=omp-preflight-b event=omp_detected pane=2 value=1 detail=2222222222222222222222222222222222222222222222222222222222222222 monotonic_ms=2
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

negative_state="$scratch/negative-state"
mkdir -p "$negative_state/deetty/logs"
cat >"$negative_state/deetty/logs/deetty-negative-two-hour.log" <<'EOF'
dogfood_launch app=deetty timestamp=2026-08-03T10:00:00+00:00 epoch=1785751200
dogfood_exit app=deetty timestamp=2026-08-03T12:00:00+00:00 epoch=1785758400 duration_seconds=7200 status=0
EOF
cat >"$negative_state/deetty/logs/deetty-missing-context.log" <<'EOF'
dogfood_launch app=deetty timestamp=2026-08-04T10:00:00+00:00 epoch=1785837600
dogfood_exit app=deetty timestamp=2026-08-04T12:00:00+00:00 epoch=1785844800 duration_seconds=7200 status=0
EOF
cat >"$scratch/DOGFOOD_LOG_NEGATIVE.md" <<'EOF'
# Negative evidence fixture

## 2026-08-03 — counted session with unavailable feature evidence

- Dogfood receipt: `deetty-negative-two-hour`
- Work performed: operator-confirmed daily terminal work
- Panes/tabs used: not recorded
- Agent/TUI apps used: not recorded
- NoctEd used: no
- Foreground-job close confirmation not tested

## 2026-08-04 — session missing work context

- Dogfood receipt: `deetty-missing-context`
- Agent/TUI apps used: OMP
EOF
negative=$(./scripts/dogfood_status.sh "$scratch/DOGFOOD_LOG_NEGATIVE.md" "$negative_state")
printf '%s\n' "$negative" | grep -F 'counted_sessions=1' >/dev/null
printf '%s\n' "$negative" | grep -F 'documented_sessions=2' >/dev/null
printf '%s\n' "$negative" | grep -F 'unverified_sessions=1' >/dev/null
printf '%s\n' "$negative" | grep -F 'four_pane=false' >/dev/null
printf '%s\n' "$negative" | grep -F 'agent_cli=false' >/dev/null
printf '%s\n' "$negative" | grep -F 'nocted_real_edit=false' >/dev/null
printf '%s\n' "$negative" | grep -F 'foreground_close_confirmation=false' >/dev/null

partial_state="$scratch/partial-state"
mkdir -p "$partial_state/deetty/logs"
cat >"$scratch/DOGFOOD_LOG_PARTIAL.md" <<'EOF'
# Partial fixture

## 2026-08-03 — incomplete OMP preflight (not counted)

## 2026-08-04 — independently incomplete OMP preflight (not counted)
EOF
cat >"$partial_state/deetty/logs/deetty-omp-partial-a.log" <<'EOF'
dogfood_launch app=deetty session_id=omp-partial-a omp_version=deferred args=
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
cat >"$partial_state/deetty/logs/deetty-omp-partial-b.log" <<'EOF'
dogfood_launch app=deetty session_id=omp-partial-b omp_version=deferred args=
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


printf 'dogfood_logging_smoke fast_control=true instance_lock_fast_control=true log_arguments_bounded=true atomic_receipts=true desktop_fingerprint=true categorized_errors=true upgrade_cohorts=true interaction_spikes=true local_diagnostic_report=true coredump_query_fail_closed=true malformed_receipt_rejected=true monotonic_duration=true nonzero_exit=true incomplete_launch=true private_mode=true legacy_import=true runtime_hours=true omp_extraction=true omp_fail_closed=true\n'
