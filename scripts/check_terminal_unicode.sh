#!/usr/bin/env sh
set -eu

lock=dependencies/terminal-unicode.lock.json
generated=src/terminal/UnicodeData.zig
fixture=src/terminal/fixtures/GraphemeBreakTest-17.0.0.txt
generator=tools/generate_terminal_unicode.zig
generated_expected=081ce81827afb4404fc4a6b59912e8945ec643b1406bc2ad77cb24e477a3a0ee
fixture_expected=e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec

test -s "$lock"
test -s "$generated"
test -s "$fixture"
test -s "$generator"
test ! -e tools/generate_terminal_unicode.py
grep -F '"unicode_version": "17.0.0"' "$lock" >/dev/null
grep -F "\"sha256\": \"$generated_expected\"" "$lock" >/dev/null
grep -F "\"sha256\": \"$fixture_expected\"" "$lock" >/dev/null

generated_actual=$(sha256sum "$generated")
generated_actual=${generated_actual%% *}
fixture_actual=$(sha256sum "$fixture")
fixture_actual=${fixture_actual%% *}
test "$generated_actual" = "$generated_expected"
test "$fixture_actual" = "$fixture_expected"

echo "terminal_unicode unicode=17.0.0 generator=zig generated_sha256=$generated_actual grapheme_fixture_sha256=$fixture_actual offline=true"
