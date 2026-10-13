#!/usr/bin/env bash
set -euo pipefail

mode=full
backends=(wayland x11)
if [[ ${1:-} == --contract-only ]]; then
    mode=contract
elif [[ ${1:-} == --backend ]]; then
    case ${2:-} in
        wayland|x11) backends=("$2") ;;
        *) echo 'usage: native_grid_installed_activation_smoke.sh [--contract-only|--backend wayland|x11]' >&2; exit 2 ;;
    esac
elif [[ $# -ne 0 ]]; then
    echo 'usage: native_grid_installed_activation_smoke.sh [--contract-only|--backend wayland|x11]' >&2
    exit 2
fi
if [[ $mode == full ]]; then
    ./scripts/require_isolated_display.sh --dedicated
fi

repo_root=$(pwd -P)
scratch_parent=${NOCTTY_INSTALLED_ACTIVATION_PARENT:-$repo_root}
case "$scratch_parent" in
    /*) ;;
    *) scratch_parent="$repo_root/$scratch_parent" ;;
esac
scratch=$(mktemp -d "$scratch_parent/.noctty-installed-activation.XXXXXX")
cache="$scratch/zig-local"
global_cache="$scratch/zig-global"
mkdir -p "$scratch/tmp" "$scratch/xdg-cache" "$cache" "$global_cache"
export TMPDIR="$scratch/tmp"
export XDG_CACHE_HOME="$scratch/xdg-cache"
cleanup() {
    rm -rf -- "$scratch"
}
trap cleanup EXIT HUP INT TERM

prefix="$scratch/prefix"
data_home="$scratch/data"
config_home="$scratch/config"
smoke_home="$scratch/smoke-home"
shim="$scratch/shim"
workspace="$scratch/activation.nocttyws"
desktop_id=com.noctty.NOCTTY.desktop

mkdir -p "$data_home/applications" "$config_home" "$smoke_home" "$shim"
ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build -j1 install smoke-binaries \
    --prefix "$prefix" \
    --cache-dir "$cache"

ln -s "$prefix/bin/noctty-smoke" "$shim/noctty"
env NOCTTY_SMOKE_HOME="$smoke_home" \
    "$prefix/bin/noctty-smoke" \
    --native-grid-installed-activation-fixture "$workspace"

desktop-file-validate "$prefix/share/applications/$desktop_id"
desktop-file-install \
    --dir="$data_home/applications" \
    "$prefix/share/applications/$desktop_id"
update-desktop-database "$data_home/applications"
env XDG_DATA_HOME="$data_home" \
    XDG_DATA_DIRS="$prefix/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
    XDG_CONFIG_HOME="$config_home" \
    xdg-mime default "$desktop_id" x-scheme-handler/noctty

registered=$(env XDG_DATA_HOME="$data_home" \
    XDG_DATA_DIRS="$prefix/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
    XDG_CONFIG_HOME="$config_home" \
    xdg-mime query default x-scheme-handler/noctty)
[[ $registered == "$desktop_id" ]]
grep -F 'Exec=noctty --open-uri %u' "$data_home/applications/$desktop_id" >/dev/null
grep -F 'MimeType=x-scheme-handler/noctty;' "$data_home/applications/$desktop_id" >/dev/null
grep -F 'StartupNotify=true' "$data_home/applications/$desktop_id" >/dev/null
grep -F 'X-KDE-StartupNotify=true' "$data_home/applications/$desktop_id" >/dev/null
[[ -x $prefix/bin/noctty ]]
[[ -x $prefix/bin/noctty-smoke ]]

printf '%s\n' 'native_grid_installed_activation_contract installed_desktop=true mime_registered=true exec_open_uri=true startup_notify=true fixture_tabs=2 production_binary=true smoke_isolated=true scratch_scoped=true'
if [[ $mode == contract ]]; then
    exit 0
fi

wait_for_receipt() {
    local receipt_path=$1
    local expected=$2
    local attempts=0
    while [[ ! -s $receipt_path && $attempts -lt 200 ]]; do
        sleep 0.05
        attempts=$((attempts + 1))
    done
    if [[ ! -s $receipt_path ]]; then
        echo "activation receipt was not produced: $receipt_path" >&2
        return 1
    fi
    grep -Fx "$expected" "$receipt_path" >/dev/null
    cat "$receipt_path"
}

activation_uri="noctty://$workspace"
for backend in "${backends[@]}"; do
    desktop_receipt="$scratch/desktop-$backend.receipt"
    desktop_expected="native_grid_activation_child source=desktop backend=$backend mapped=true rendered=true tabs=2 controlled_exit=true"
    env PATH="$shim:$PATH" \
        LANG=C LC_ALL=C \
        XDG_DATA_HOME="$data_home" \
        XDG_DATA_DIRS="$prefix/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
        XDG_CONFIG_HOME="$config_home" \
        NOCTTY_SMOKE_HOME="$smoke_home" \
        NOCTTY_ACTIVATION_SOURCE=desktop \
        NOCTTY_ACTIVATION_CHILD_RECEIPT="$desktop_receipt" \
        GDK_BACKEND="$backend" \
        GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
        gio open "$activation_uri"
    wait_for_receipt "$desktop_receipt" "$desktop_expected"

    recent_receipt="$scratch/recent-$backend.receipt"
    recent_expected="native_grid_activation_child source=recent backend=$backend mapped=true rendered=true tabs=2 controlled_exit=true"
    recent_output=$(env PATH="$shim:$PATH" \
        LANG=C LC_ALL=C \
        XDG_DATA_HOME="$data_home" \
        XDG_DATA_DIRS="$prefix/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
        XDG_CONFIG_HOME="$config_home" \
        NOCTTY_SMOKE_HOME="$smoke_home" \
        NOCTTY_ACTIVATION_SOURCE=recent \
        NOCTTY_ACTIVATION_CHILD_RECEIPT="$recent_receipt" \
        NOCTTY_ACTIVATION_WORKSPACE="$workspace" \
        GDK_BACKEND="$backend" \
        GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
        "$prefix/bin/noctty-smoke" --native-grid-recent-activation-smoke)
    printf '%s\n' "$recent_output"
    grep -Fx 'native_grid_recent_workspace_activation_smoke parent_rendered=true recent_control=true click=true separate_process=true child_launch=true controlled_exit=true' <<<"$recent_output" >/dev/null
    wait_for_receipt "$recent_receipt" "$recent_expected"
    printf 'native_grid_installed_activation backend=%s desktop_dispatch=true parent_rendered=true recent_clicked=true child_rendered=true tabs=2 controlled_exit=true\n' "$backend"
done

backends_csv=$(printf ',%s' "${backends[@]}")
printf 'native_grid_installed_activation_matrix backends=%s installed_desktop=true desktop_dispatch=true recent_child=true rendered=true controlled_exit=true scratch_clean=true\n' "${backends_csv#,}"
