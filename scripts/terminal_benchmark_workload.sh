#!/usr/bin/env sh
set -eu

: "${NOCTTY_BENCH_RUN_DIR:?}"
: "${NOCTTY_BENCH_TITLE:?}"
: "${NOCTTY_BENCH_MODE:?}"

run_dir=$NOCTTY_BENCH_RUN_DIR
control="$run_dir/control.$$"

cleanup() {
    rm -f "$control"
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM

mkfifo "$control"
printf '\033]2;%s\007NOCTTY_BENCH_READY\n' "$NOCTTY_BENCH_TITLE"
: >"$run_dir/spawned.$$"

while [ ! -e "$run_dir/go" ]; do
    [ ! -e "$run_dir/abort" ] || exit 1
    sleep 0.01
done

if [ "$NOCTTY_BENCH_MODE" = output ]; then
    : "${NOCTTY_BENCH_PAYLOAD:?}"
    cat "$NOCTTY_BENCH_PAYLOAD"
    printf '\033[0mNOCTTY_BENCH_OUTPUT_DONE\n'
fi
: >"$run_dir/done.$$"

IFS= read -r _ <"$control" || true
