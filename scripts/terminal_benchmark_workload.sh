#!/usr/bin/env sh
set -eu

: "${DEETTY_BENCH_RUN_DIR:?}"
: "${DEETTY_BENCH_TITLE:?}"
: "${DEETTY_BENCH_MODE:?}"

run_dir=$DEETTY_BENCH_RUN_DIR
control="$run_dir/control.$$"

cleanup() {
    rm -f "$control"
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM

mkfifo "$control"
printf '\033]2;%s\007DEETTY_BENCH_READY\n' "$DEETTY_BENCH_TITLE"
: >"$run_dir/spawned.$$"

while [ ! -e "$run_dir/go" ]; do
    [ ! -e "$run_dir/abort" ] || exit 1
    sleep 0.01
done

stty size >"$run_dir/geometry.$$"

if [ "$DEETTY_BENCH_MODE" = output ]; then
    : "${DEETTY_BENCH_PAYLOAD:?}"
    cat "$DEETTY_BENCH_PAYLOAD"
    printf '\033[0mDEETTY_BENCH_OUTPUT_DONE\n'
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
