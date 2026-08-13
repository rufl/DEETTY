#!/usr/bin/env sh
set -eu

# Static alpha guard: production NOCTTY/NoctEd must not grow telemetry,
# update pings, crash uploaders, remote flags, or hidden network clients.
# Session sharing is the sole explicit network boundary: src/share/net.c.
# This is not a firewall or legal audit; it is a cheap source/build scan.

roots="build.zig build.zig.zon src resources"
hit_file=$(mktemp "${TMPDIR:-/tmp}/noctty-network-guard.XXXXXX")
trap 'rm -f "$hit_file"' EXIT HUP INT TERM

for pattern in \
  '\bsentry\b' '\bbugsnag\b' '\brollbar\b' '\bcrashlytics\b' \
  '\bposthog\b' '\bsegment\b' '\bamplitude\b' '\bmixpanel\b' \
  '\banalytics\b' 'telemetry_enabled\s*=\s*true' 'crash_uploader|crash-upload' \
  'update_ping|update-ping' 'remote_feature_flag|remote-feature-flag' \
  'feature_flag_service|feature-flag-service'
 do
  if rg -i --glob '!src/terminal/fixtures/**' --glob '!resources/**/*.svg' "$pattern" $roots >"$hit_file" 2>/dev/null; then
    echo "forbidden telemetry/update token found: $pattern" >&2
    cat "$hit_file" >&2
    exit 1
  fi
done

for pattern in \
  'std\.net' \
  'curl_easy_' \
  'libsoup|soup_session' \
  'g_socket_|GSocket' \
  'getaddrinfo\(' \
  'AF_INET|AF_INET6' \
  'SOCK_STREAM|SOCK_DGRAM' \
  'http_client|HttpClient'
 do
  if rg -n --glob '!src/share/net.c' --glob '!src/terminal/fixtures/**' --glob '!resources/**/*.svg' "$pattern" $roots >"$hit_file" 2>/dev/null; then
    echo "surprise network API found: $pattern" >&2
    cat "$hit_file" >&2
    exit 1
  fi
done

if ! rg -q 'noctty_share_tcp_listen|noctty_share_discovery_open' \
    src/share/net.c src/share/net.h; then
  echo "explicit session-sharing network boundary is missing" >&2
  exit 1
fi

rm -f "$hit_file"
hit_file=
printf '%s\n' 'no_surprise_network_check telemetry=false update_pings=false crash_uploaders=false remote_flags=false hidden_network_api=false sharing_network_api=explicit proof_boundary=static_source_scan'
