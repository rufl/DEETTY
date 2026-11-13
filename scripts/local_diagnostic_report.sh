#!/usr/bin/env sh
set -eu
export LC_ALL=C

# This report deliberately reads only local dogfood receipts. It never reads
# terminal output, contacts a network service, or changes local state.
state_home=${1:-${XDG_STATE_HOME:-"$HOME/.local/state"}}
receipt_dir="$state_home/deetty/dogfood-sessions"
interaction_dir="$state_home/deetty/interaction-qualifications"
build_receipt="$state_home/deetty/dogfood-build.receipt"
records=$(mktemp "${TMPDIR:-/tmp}/deetty-local-diagnostic-report.XXXXXX")
trap 'rm -f "$records"' EXIT HUP INT TERM
: >"$records"

safe_token() {
  value=$(printf '%s' "$1" | tr -cd 'A-Za-z0-9._:+/-' | cut -c1-128)
  if [ -n "$value" ]; then printf '%s' "$value"; else printf 'unknown'; fi
}

receipt_field() {
  awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$2"
}

kernel_release=$(safe_token "$(uname -r 2>/dev/null || printf unknown)")
os_id=$(safe_token "$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release 2>/dev/null || printf unknown)")
plasma_version=$(safe_token "$(plasmashell --version 2>/dev/null | awk 'NR == 1 { print $NF; exit }' || printf unknown)")
kwin_version=$(safe_token "$(kwin_wayland --version 2>/dev/null | awk 'NR == 1 { print $NF; exit }' || printf unknown)")
printf 'local_diagnostic_report version=4 no_network=true terminal_content=false receipt_directory_present=%s os_id=%s kernel_release=%s plasma_version=%s kwin_version=%s\n' \
  "$([ -d "$receipt_dir" ] && printf true || printf false)" "$os_id" "$kernel_release" "$plasma_version" "$kwin_version"

coredump_inventory=false
coredump_baseline=false
deetty_coredumps=0
nocted_coredumps=0
deetty_smoke_coredumps=0
nocted_smoke_coredumps=0
deetty_coredumps_since_install=0
nocted_coredumps_since_install=0
deetty_smoke_coredumps_since_install=0
nocted_smoke_coredumps_since_install=0
install_epoch=$(receipt_field install_epoch "$build_receipt" 2>/dev/null || true)
case "$install_epoch" in ''|*[!0-9]*) install_epoch=0 ;; esac
if command -v coredumpctl >/dev/null 2>&1; then
  if coredumps=$(coredumpctl --json=short --no-pager \
    list deetty-bin nocted-bin deetty-smoke nocted-smoke 2>&1); then
    coredump_inventory=true
  elif [ "$coredumps" = "No coredumps found." ]; then
    coredumps=
    coredump_inventory=true
  else
    coredumps=
  fi
  deetty_coredumps=$(printf '%s\n' "$coredumps" | grep -o '/deetty-bin"' | wc -l)
  nocted_coredumps=$(printf '%s\n' "$coredumps" | grep -o '/nocted-bin"' | wc -l)
  deetty_smoke_coredumps=$(printf '%s\n' "$coredumps" | grep -o '/deetty-smoke"' | wc -l)
  nocted_smoke_coredumps=$(printf '%s\n' "$coredumps" | grep -o '/nocted-smoke"' | wc -l)
  if [ "$coredump_inventory" = true ] && [ "$install_epoch" -gt 0 ]; then
    if recent_coredumps=$(coredumpctl --json=short --no-pager \
      --since="@$install_epoch" \
      list deetty-bin nocted-bin deetty-smoke nocted-smoke 2>&1); then
      coredump_baseline=true
    elif [ "$recent_coredumps" = "No coredumps found." ]; then
      recent_coredumps=
      coredump_baseline=true
    else
      recent_coredumps=
    fi
    deetty_coredumps_since_install=$(printf '%s\n' "$recent_coredumps" |
      grep -o '/deetty-bin"' | wc -l)
    nocted_coredumps_since_install=$(printf '%s\n' "$recent_coredumps" |
      grep -o '/nocted-bin"' | wc -l)
    deetty_smoke_coredumps_since_install=$(printf '%s\n' "$recent_coredumps" |
      grep -o '/deetty-smoke"' | wc -l)
    nocted_smoke_coredumps_since_install=$(printf '%s\n' "$recent_coredumps" |
      grep -o '/nocted-smoke"' | wc -l)
  fi
fi
printf 'local_diagnostic_crashes inventory=%s install_baseline=%s retained_deetty=%s retained_nocted=%s retained_deetty_smoke=%s retained_nocted_smoke=%s since_install_deetty=%s since_install_nocted=%s since_install_deetty_smoke=%s since_install_nocted_smoke=%s historical_may_precede_current_binary=true\n' \
  "$coredump_inventory" "$coredump_baseline" "$deetty_coredumps" \
  "$nocted_coredumps" "$deetty_smoke_coredumps" "$nocted_smoke_coredumps" \
  "$deetty_coredumps_since_install" "$nocted_coredumps_since_install" \
  "$deetty_smoke_coredumps_since_install" \
  "$nocted_smoke_coredumps_since_install"

if [ -d "$receipt_dir" ]; then
  for receipt in "$receipt_dir"/*.receipt; do
    [ -f "$receipt" ] || continue
    receipt_version=$(safe_token "$(receipt_field receipt_version "$receipt")")
    session_id=$(safe_token "$(receipt_field session_id "$receipt")")
    app=$(safe_token "$(receipt_field app "$receipt")")
    state=$(safe_token "$(receipt_field state "$receipt")")
    exit_status=$(safe_token "$(receipt_field exit_status "$receipt")")
    warnings=$(safe_token "$(receipt_field runtime_warning_markers "$receipt")")
    desktop_session=$(safe_token "$(receipt_field desktop_session "$receipt")")
    backend=$(safe_token "$(receipt_field backend "$receipt")")
    receipt_os=$(safe_token "$(receipt_field os_id "$receipt")")
    receipt_build=$(safe_token "$(receipt_field os_build "$receipt")")
    receipt_kernel=$(safe_token "$(receipt_field kernel_release "$receipt")")
    receipt_plasma=$(safe_token "$(receipt_field plasma_version "$receipt")")
    receipt_kwin=$(safe_token "$(receipt_field kwin_version "$receipt")")
    binary_sha256=$(safe_token "$(receipt_field binary_sha256 "$receipt")")
    start_epoch=$(safe_token "$(receipt_field start_epoch "$receipt")")
    gtk_critical=$(safe_token "$(receipt_field gtk_critical_markers "$receipt")")
    gdk_critical=$(safe_token "$(receipt_field gdk_critical_markers "$receipt")")
    glib_critical=$(safe_token "$(receipt_field glib_critical_markers "$receipt")")
    gobject_critical=$(safe_token "$(receipt_field gobject_critical_markers "$receipt")")
    native_grid_failed=$(safe_token "$(receipt_field native_grid_failure_markers "$receipt")")
    panic=$(safe_token "$(receipt_field panic_markers "$receipt")")
    # Receipt v2 predates categorized marker counts. Preserve its bounded
    # outcome evidence while treating only those known-legacy fields as zero.
    case "$receipt_version" in
      2)
        [ "$gtk_critical" != unknown ] || gtk_critical=0
        [ "$gdk_critical" != unknown ] || gdk_critical=0
        [ "$glib_critical" != unknown ] || glib_critical=0
        [ "$gobject_critical" != unknown ] || gobject_critical=0
        [ "$native_grid_failed" != unknown ] || native_grid_failed=0
        [ "$panic" != unknown ] || panic=0
        ;;
      3)
        case "$gtk_critical:$gdk_critical:$glib_critical:$gobject_critical:$native_grid_failed:$panic" in
          *unknown*) continue ;;
        esac
        ;;
      *) continue ;;
    esac
    case "$app" in deetty|nocted) ;; *) continue ;; esac
    case "$warnings:$start_epoch:$gtk_critical:$gdk_critical:$glib_critical:$gobject_critical:$native_grid_failed:$panic" in
      *[!0-9:]*) continue ;;
    esac
    case "$state" in
      running)
        [ "$exit_status" = -1 ] || continue
        ;;
      finished)
        case "$exit_status" in ''|*[!0-9]*) continue ;; esac
        ;;
      *) continue ;;
    esac
    if [ "${#binary_sha256}" -ne 64 ]; then continue; fi
    case "$binary_sha256" in *[!0-9a-f]*) continue ;; esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$session_id" "$app" "$state" "$exit_status" "$warnings" "$desktop_session" \
      "$backend" "$receipt_os" "$receipt_build" "$receipt_kernel" "$receipt_plasma" \
      "$receipt_kwin" "$binary_sha256" "$start_epoch" "$gtk_critical" \
      "$gdk_critical" "$glib_critical" "$gobject_critical" \
      "$native_grid_failed" "$panic" >>"$records"
  done
fi

awk -F '\t' '
  {
    app = $2
    sessions[app]++
    if ($3 == "finished") {
      finished[app]++
      if ($4 != "0") failed[app]++
    } else {
      incomplete[app]++
    }
    if ($5 != "0") warning_sessions[app]++
  }
  END {
    for (app_name in sessions) {
      printf "local_diagnostic_summary app=%s sessions=%d finished=%d failed=%d incomplete=%d runtime_warning_sessions=%d\n", \
        app_name, sessions[app_name], finished[app_name] + 0, failed[app_name] + 0, \
        incomplete[app_name] + 0, warning_sessions[app_name] + 0
    }
  }
' "$records" | sort

current_deetty_sha256=$(receipt_field deetty_sha256 "$build_receipt" 2>/dev/null || true)
current_nocted_sha256=$(receipt_field nocted_sha256 "$build_receipt" 2>/dev/null || true)
awk -F '\t' \
  -v deetty_hash="$current_deetty_sha256" \
  -v nocted_hash="$current_nocted_sha256" \
  -v install_epoch="$install_epoch" '
  BEGIN {
    expected["deetty"] = deetty_hash
    expected["nocted"] = nocted_hash
  }
  {
    app = $2
    if (length(expected[app]) != 64 || $13 != expected[app]) next
    sessions[app]++
    if ($3 == "finished") {
      finished[app]++
      if ($4 != "0") failed[app]++
    } else {
      incomplete[app]++
    }
    if ($5 != "0") warning_sessions[app]++
    gtk_critical[app] += $15
    gdk_critical[app] += $16
    glib_critical[app] += $17
    gobject_critical[app] += $18
    native_grid_failed[app] += $19
    panic[app] += $20
    if (install_epoch > 0 && $14 >= install_epoch) {
      install_sessions[app]++
      if ($3 == "finished") {
        install_finished[app]++
        if ($4 != "0") install_failed[app]++
      } else {
        install_incomplete[app]++
      }
      if ($5 != "0") install_warning_sessions[app]++
      install_gtk_critical[app] += $15
      install_gdk_critical[app] += $16
      install_glib_critical[app] += $17
      install_gobject_critical[app] += $18
      install_native_grid_failed[app] += $19
      install_panic[app] += $20
    }
  }
  END {
    app_names[1] = "deetty"
    app_names[2] = "nocted"
    for (app_index = 1; app_index <= 2; app_index++) {
      app = app_names[app_index]
      printf "local_diagnostic_current_build app=%s sessions=%d finished=%d failed=%d incomplete=%d runtime_warning_sessions=%d\n", \
        app, sessions[app] + 0, finished[app] + 0, failed[app] + 0, \
        incomplete[app] + 0, warning_sessions[app] + 0
      printf "local_diagnostic_current_errors app=%s gtk_critical=%d gdk_critical=%d glib_critical=%d gobject_critical=%d native_grid_failed=%d panic=%d\n", \
        app, gtk_critical[app] + 0, gdk_critical[app] + 0, \
        glib_critical[app] + 0, gobject_critical[app] + 0, \
        native_grid_failed[app] + 0, panic[app] + 0
      printf "local_diagnostic_current_install app=%s sessions=%d finished=%d failed=%d incomplete=%d runtime_warning_sessions=%d\n", \
        app, install_sessions[app] + 0, install_finished[app] + 0, \
        install_failed[app] + 0, install_incomplete[app] + 0, \
        install_warning_sessions[app] + 0
      printf "local_diagnostic_current_install_errors app=%s gtk_critical=%d gdk_critical=%d glib_critical=%d gobject_critical=%d native_grid_failed=%d panic=%d\n", \
        app, install_gtk_critical[app] + 0, install_gdk_critical[app] + 0, \
        install_glib_critical[app] + 0, install_gobject_critical[app] + 0, \
        install_native_grid_failed[app] + 0, install_panic[app] + 0
    }
  }
' "$records"

# Keep at most 20 recent binary/desktop-stack cohorts. These bounded summaries
# make before/after upgrade comparisons possible without exposing log content.
awk -F '\t' '
  {
    key = $2 SUBSEP $13 SUBSEP $10 SUBSEP $11 SUBSEP $12
    sessions[key]++
    if ($3 == "finished") {
      finished[key]++
      if ($4 != "0") failed[key]++
    } else {
      incomplete[key]++
    }
    if ($5 != "0") warning_sessions[key]++
    if ($14 > latest[key]) latest[key] = $14
    app[key] = $2
    binary[key] = $13
    kernel[key] = $10
    plasma[key] = $11
    kwin[key] = $12
  }
  END {
    for (key in sessions) {
      printf "%d\tlocal_diagnostic_cohort app=%s binary_sha256=%s kernel_release=%s plasma_version=%s kwin_version=%s sessions=%d finished=%d failed=%d incomplete=%d runtime_warning_sessions=%d\n", \
        latest[key], app[key], binary[key], kernel[key], plasma[key], kwin[key], \
        sessions[key], finished[key] + 0, failed[key] + 0, incomplete[key] + 0, \
        warning_sessions[key] + 0
    }
  }
' "$records" | sort -t "$(printf '\t')" -k1,1nr | head -n 20 | cut -f2-

# The newest receipts are sufficient to correlate a local error report with
# this exact desktop stack and staged binary, without exposing terminal bytes.
if [ -d "$receipt_dir" ]; then
  ls -1t "$receipt_dir"/*.receipt 2>/dev/null | head -n 20 | while IFS= read -r receipt; do
    session_id=$(safe_token "$(receipt_field session_id "$receipt")")
    record=$(awk -F '\t' -v id="$session_id" '$1 == id { print; exit }' "$records")
    [ -n "$record" ] || continue
    tab=$(printf '\t')
    IFS="$tab" read -r _ app state exit_status warnings desktop_session backend receipt_os receipt_build receipt_kernel receipt_plasma receipt_kwin binary_sha256 start_epoch gtk_critical gdk_critical glib_critical gobject_critical native_grid_failed panic <<EOF
$record
EOF
    printf 'local_diagnostic_receipt session_id=%s app=%s state=%s exit_status=%s runtime_warning_markers=%s gtk_critical=%s gdk_critical=%s glib_critical=%s gobject_critical=%s native_grid_failed=%s panic=%s desktop_session=%s backend=%s os_id=%s os_build=%s kernel_release=%s plasma_version=%s kwin_version=%s binary_sha256=%s\n' \
      "$session_id" "$app" "$state" "$exit_status" "$warnings" \
      "$gtk_critical" "$gdk_critical" "$glib_critical" "$gobject_critical" \
      "$native_grid_failed" "$panic" "$desktop_session" "$backend" \
      "$receipt_os" "$receipt_build" "$receipt_kernel" "$receipt_plasma" \
      "$receipt_kwin" "$binary_sha256"
  done
fi

# Retain only bounded numeric operation/resource evidence in the report. The
# scenario receipts never contain terminal or editor content.
if [ -d "$interaction_dir" ]; then
  ls -1t "$interaction_dir"/*.receipt 2>/dev/null | head -n 5 |
    while IFS= read -r interaction_receipt; do
      [ "$(receipt_field interaction_receipt_version "$interaction_receipt")" = 1 ] || continue
      interaction_id=$(safe_token "$(receipt_field run_id "$interaction_receipt")")
      interaction_mode=$(safe_token "$(receipt_field mode "$interaction_receipt")")
      interaction_epoch=$(safe_token "$(receipt_field epoch "$interaction_receipt")")
      interaction_spike=$(safe_token "$(receipt_field spike_detected "$interaction_receipt")")
      case "$interaction_mode" in quick|full) ;; *) continue ;; esac
      case "$interaction_epoch" in ''|*[!0-9]*) continue ;; esac
      case "$interaction_spike" in true|false) ;; *) continue ;; esac
      for scenario in split_open pane_close tab_open_close layout_churn editor_workflow; do
        elapsed=$(safe_token "$(receipt_field "scenario_${scenario}_elapsed_ms" "$interaction_receipt")")
        tree_rss=$(safe_token "$(receipt_field "scenario_${scenario}_peak_tree_rss_kib" "$interaction_receipt")")
        latency_spike=$(safe_token "$(receipt_field "scenario_${scenario}_latency_spike" "$interaction_receipt")")
        memory_spike=$(safe_token "$(receipt_field "scenario_${scenario}_memory_spike" "$interaction_receipt")")
        [ "$elapsed" != unknown ] || continue
        case "$elapsed:$tree_rss" in *[!0-9:]*) continue ;; esac
        case "$latency_spike:$memory_spike" in
          true:true|true:false|false:true|false:false) ;;
          *) continue ;;
        esac
        printf 'local_diagnostic_interaction receipt_id=%s mode=%s epoch=%s scenario=%s elapsed_ms=%s peak_tree_rss_kib=%s latency_spike=%s memory_spike=%s run_spike=%s\n' \
          "$interaction_id" "$interaction_mode" "$interaction_epoch" "$scenario" \
          "$elapsed" "$tree_rss" "$latency_spike" "$memory_spike" "$interaction_spike"
      done
    done
fi
