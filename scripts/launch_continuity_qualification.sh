#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
scratch_parent=${DINTTY_CONTINUITY_QUALIFICATION_PARENT:-$repo_root}
case "$scratch_parent" in
    /*) ;;
    *) scratch_parent="$repo_root/$scratch_parent" ;;
esac
scratch=$(mktemp -d "$scratch_parent/.dintty-continuity.XXXXXX")
cleanup() {
    find "$scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$scratch/bin"
tool_shim="$scratch/bin/dintty-continuity-tool"
cat >"$tool_shim" <<'SHIM'
#!/usr/bin/env sh
set -eu
tool=${0##*/}
test "$PWD" = /tmp
test "${DINTTY_CONTINUITY:-}" = ready
case "$tool" in
    tmux)
        test "$#" -eq 4
        test "$1" = new-session
        test "$2" = -A
        test "$3" = -s
        test "$4" = dintty-tmux
        ;;
    zellij)
        test "$#" -eq 3
        test "$1" = attach
        test "$2" = --create
        test "$3" = dintty-zellij
        ;;
    *) exit 64 ;;
esac
printf 'DINTTY_CONTINUITY_OK:%s\n' "$tool"
SHIM
chmod +x "$tool_shim"
ln -s dintty-continuity-tool "$scratch/bin/tmux"
ln -s dintty-continuity-tool "$scratch/bin/zellij"

run_mode() {
    mode=$1
    prefix="$scratch/prefix-$mode"
    local_cache="$scratch/cache-$mode"
    global_cache="$scratch/global-cache-$mode"
    mode_tmp="$scratch/tmp-$mode"
    mode_xdg_cache="$scratch/xdg-cache-$mode"
    mkdir -p "$mode_tmp" "$mode_xdg_cache"
    TMPDIR="$mode_tmp" XDG_CACHE_HOME="$mode_xdg_cache" \
        ZIG_GLOBAL_CACHE_DIR="$global_cache" zig build launch-continuity-qualification-binary \
        -Doptimize="$mode" \
        --prefix "$prefix" \
        --cache-dir "$local_cache"

    PATH="$scratch/bin:$PATH" \
        "$prefix/bin/dintty-launch-continuity-qualification" \
        >"$scratch/output-$mode"
}

cd "$repo_root"
run_mode Debug &
debug_pid=$!
run_mode ReleaseSafe &
release_safe_pid=$!
debug_status=0
release_safe_status=0
wait "$debug_pid" || debug_status=$?
wait "$release_safe_pid" || release_safe_status=$?
if [[ "$debug_status" -ne 0 || "$release_safe_status" -ne 0 ]]; then
    exit 1
fi

for mode in Debug ReleaseSafe; do
    output=$(cat "$scratch/output-$mode")
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -F \
        "launch_continuity_qualification mode=$mode kinds=tmux,zellij tmux_argv=true zellij_argv=true create_or_attach=true production_pty=true cwd=true environment=true" \
        >/dev/null
    printf '%s\n' "$output" | grep -E \
        'output_bytes=[1-9][0-9]* controlled_exit=true allocator_leak_free=true allocator_residual_bytes=0 assertions=true' \
        >/dev/null
done

echo 'launch_continuity_matrix debug=true release_safe=true kinds=tmux,zellij direct_argv=true create_or_attach=true production_pty=true cwd=true environment=true controlled_exit=true allocator_leak_free=true tool_shims=true installed_tools=false live_reattach=false scratch_clean=true'
