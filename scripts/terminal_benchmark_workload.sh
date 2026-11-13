#!/usr/bin/env sh
set -eu

: "${DINTTY_BENCH_RUN_DIR:?}"
: "${DINTTY_BENCH_TITLE:?}"
: "${DINTTY_BENCH_MODE:?}"

run_dir=$DINTTY_BENCH_RUN_DIR
control="$run_dir/control.$$"

cleanup() {
    rm -f "$control"
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM

mkfifo "$control"
printf '\033]2;%s\007DINTTY_BENCH_READY\n' "$DINTTY_BENCH_TITLE"
: >"$run_dir/spawned.$$"

while [ ! -e "$run_dir/go" ]; do
    [ ! -e "$run_dir/abort" ] || exit 1
    sleep 0.01
done

stty size >"$run_dir/geometry.$$"

if [ "$DINTTY_BENCH_MODE" = output ]; then
    : "${DINTTY_BENCH_PAYLOAD:?}"
    cat "$DINTTY_BENCH_PAYLOAD"
    printf '\033[0mDINTTY_BENCH_OUTPUT_DONE\n'
    awk 'BEGIN {
        printf "\033[2J\033[H\033[48;2;18;52;86m"
        for (row = 0; row < 100; row++) {
            for (column = 0; column < 160; column++) printf " "
            printf "\n"
        }
    }'
fi
: >"$run_dir/done.$$"

IFS= read -r _ <"$control" || true
