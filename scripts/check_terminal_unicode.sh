#!/usr/bin/env sh
set -eu

lock=dependencies/terminal-unicode.lock.json
generated=src/terminal/UnicodeData.zig
fixture=src/terminal/fixtures/GraphemeBreakTest-17.0.0.txt
generated_expected=5aba2870c5c8c73680a7567ab6cc389c39d49a9fc8d1dcdb8835533d0e8e3263
fixture_expected=e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec

test -s "$lock"
test -s "$generated"
test -s "$fixture"
grep -F '"unicode_version": "17.0.0"' "$lock" >/dev/null
grep -F "\"sha256\": \"$generated_expected\"" "$lock" >/dev/null
grep -F "\"sha256\": \"$fixture_expected\"" "$lock" >/dev/null

generated_actual=$(sha256sum "$generated")
generated_actual=${generated_actual%% *}
fixture_actual=$(sha256sum "$fixture")
fixture_actual=${fixture_actual%% *}
test "$generated_actual" = "$generated_expected"
test "$fixture_actual" = "$fixture_expected"

echo "terminal_unicode unicode=17.0.0 generated_sha256=$generated_actual grapheme_fixture_sha256=$fixture_actual offline=true"
