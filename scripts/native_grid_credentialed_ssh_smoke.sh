#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

ssh_client=$(command -v ssh)
ssh_server=$(command -v sshd)
ssh_keygen=$(command -v ssh-keygen)
login_name=$(id -un)
project_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d -p /tmp noctty-credentialed-ssh.XXXXXX)

cleanup() {
  case "$scratch" in
    /tmp/noctty-credentialed-ssh.*) rm -rf -- "$scratch" ;;
    *) printf 'refusing unsafe SSH smoke cleanup: %s\n' "$scratch" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

"$ssh_keygen" -q -t ed25519 -N '' -f "$scratch/host_key"
"$ssh_keygen" -q -t ed25519 -N '' -f "$scratch/client_key"
cp "$scratch/client_key.pub" "$scratch/authorized_keys"
chmod 600 "$scratch/authorized_keys"
host_public_key=$("$ssh_keygen" -y -f "$scratch/host_key")
printf 'noctty-credential-smoke %s\n' "$host_public_key" > "$scratch/known_hosts"

mkdir "$scratch/bin"
wrapper="$scratch/bin/ssh"
{
  printf '%s\n' '#!/usr/bin/env sh'
  printf 'exec %s -F /dev/null -T -i %s -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=%s -o "ProxyCommand=%s -i -e -f /dev/null -h %s -o UsePAM=no -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o PubkeyAuthentication=yes -o AuthorizedKeysFile=%s -o StrictModes=no -o AllowUsers=%s -o PermitRootLogin=yes" "$@"\n' \
    "$ssh_client" "$scratch/client_key" "$scratch/known_hosts" \
    "$ssh_server" "$scratch/host_key" "$scratch/authorized_keys" "$login_name"
} > "$wrapper"
chmod 700 "$wrapper"

receipt='native_grid_credentialed_ssh_smoke profile=true system_client=true system_server=true credential=publickey identity_isolated=true host_key=pinned transport=stdio_proxy network_bind=false remote_marker=true exited=true'
output=$(PATH="$scratch/bin:$PATH" \
  NOCTTY_SSH_SMOKE_TARGET="$login_name@noctty-credential-smoke" \
  zig build -j1 smoke-run \
  --cache-dir "$project_dir/.zig-cache" \
  --global-cache-dir "$project_dir/.zig-cache/global" \
  -- --native-grid-credentialed-ssh-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q "^${receipt}$"

printf '%s\n' 'native_grid_credentialed_ssh_contract real_openssh=true publickey_auth=true product_pty=true target_validated=true local_stdio_transport=true scratch_clean=true'
