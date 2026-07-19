#!/usr/bin/env python3
"""Generate NOCTTY's pinned Unicode terminal lookup tables."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def parse_range(value: str) -> tuple[int, int]:
    points = value.strip().split("..", 1)
    first = int(points[0], 16)
    return first, int(points[1], 16) if len(points) == 2 else first


def records(path: Path):
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        fields = [field.strip() for field in line.split(";")]
        yield parse_range(fields[0]), fields[1:]


def merge(ranges: list[tuple[int, int]]) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    for first, last in sorted(ranges):
        if result and first <= result[-1][1] + 1:
            result[-1] = (result[-1][0], max(result[-1][1], last))
        else:
            result.append((first, last))
    return result


def emit_ranges(output: list[str], name: str, ranges: list[tuple[int, int]]) -> None:
    output.append(f"pub const {name} = [_]Range{{")
    for first, last in merge(ranges):
        output.append(f"    .{{ .first = 0x{first:X}, .last = 0x{last:X} }},")
    output.append("};")
    output.append("")


def emit_property_ranges(
    output: list[str], name: str, ranges: list[tuple[int, int, str]]
) -> None:
    output.append(f"pub const {name} = [_]PropertyRange{{")
    for first, last, value in sorted(ranges):
        output.append(
            f"    .{{ .first = 0x{first:X}, .last = 0x{last:X}, .value = .{value} }},"
        )
    output.append("};")
    output.append("")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lock", type=Path, required=True)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    lock = json.loads(args.lock.read_text(encoding="utf-8"))
    paths: dict[str, Path] = {}
    for item in lock["files"]:
        path = args.input_dir / item["name"]
        if sha256(path) != item["sha256"]:
            raise SystemExit(f"hash mismatch: {path}")
        paths[item["name"]] = path

    gcb_names = {
        "CR": "cr",
        "LF": "lf",
        "Control": "control",
        "Extend": "extend",
        "ZWJ": "zwj",
        "Regional_Indicator": "regional_indicator",
        "Prepend": "prepend",
        "SpacingMark": "spacing_mark",
        "L": "l",
        "V": "v",
        "T": "t",
        "LV": "lv",
        "LVT": "lvt",
    }
    gcb: list[tuple[int, int, str]] = []
    for (first, last), fields in records(paths["GraphemeBreakProperty.txt"]):
        gcb.append((first, last, gcb_names[fields[0]]))

    incb: list[tuple[int, int, str]] = []
    for (first, last), fields in records(paths["DerivedCoreProperties.txt"]):
        if fields[0] == "InCB":
            incb.append((first, last, fields[1].lower()))

    extended: list[tuple[int, int]] = []
    emoji_presentation: list[tuple[int, int]] = []
    for bounds, fields in records(paths["emoji-data.txt"]):
        if fields[0] == "Extended_Pictographic":
            extended.append(bounds)
        elif fields[0] == "Emoji_Presentation":
            emoji_presentation.append(bounds)

    wide: list[tuple[int, int]] = []
    for bounds, fields in records(paths["EastAsianWidth.txt"]):
        if fields[0] in {"W", "F"}:
            wide.append(bounds)

    output = [
        "//! Generated from pinned Unicode 17.0.0 data. Do not edit.",
        "//! Regenerate with tools/generate_terminal_unicode.py.",
        "",
        'pub const unicode_version = "17.0.0";',
        "",
        "pub const GraphemeBreakProperty = enum(u8) {",
        "    other, cr, lf, control, extend, zwj, regional_indicator,",
        "    prepend, spacing_mark, l, v, t, lv, lvt,",
        "};",
        "",
        "pub const IndicConjunctBreak = enum(u8) { none, linker, consonant, extend };",
        "",
        "pub const Range = struct { first: u21, last: u21 };",
        "pub const PropertyRange = struct {",
        "    first: u21,",
        "    last: u21,",
        "    value: GraphemeBreakProperty,",
        "};",
        "pub const IndicRange = struct {",
        "    first: u21,",
        "    last: u21,",
        "    value: IndicConjunctBreak,",
        "};",
        "",
    ]
    emit_property_ranges(output, "grapheme_break_ranges", gcb)
    output.append("pub const indic_conjunct_ranges = [_]IndicRange{")
    for first, last, value in sorted(incb):
        output.append(
            f"    .{{ .first = 0x{first:X}, .last = 0x{last:X}, .value = .{value} }},"
        )
    output.append("};")
    output.append("")
    emit_ranges(output, "extended_pictographic_ranges", extended)
    emit_ranges(output, "emoji_presentation_ranges", emoji_presentation)
    emit_ranges(output, "wide_ranges", wide)

    rendered = "\n".join(output).encode("ascii")
    actual_output_hash = hashlib.sha256(rendered).hexdigest()
    expected_output = lock["generated_output"]
    if expected_output["name"] != "src/terminal/UnicodeData.zig":
        raise SystemExit("unexpected generated Unicode output path")
    if actual_output_hash != expected_output["sha256"]:
        raise SystemExit(
            "generated Unicode output hash mismatch: "
            f"expected {expected_output['sha256']}, got {actual_output_hash}"
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(rendered)


if __name__ == "__main__":
    main()
