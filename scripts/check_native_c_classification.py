#!/usr/bin/env python3
"""Validate the native GTK adapter ownership classification.

The C host is an effect/query/lifetime boundary.  Only an explicitly marked
remaining_policy function contributes C lines to the Zig ownership denominator;
that class is intentionally empty in a closed migration.  The exact function
inventory prevents a new C function from silently bypassing the review.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HOST = ROOT / "src/gui/native_grid_host.c"
MANIFEST = ROOT / "scripts/native_grid_c_classification.tsv"
ALLOWED_CLASSES = {
    "effect",
    "query",
    "lifetime",
    "migrated_policy",
    "orchestration",
    "remaining_policy",
}
POLICY_CLASS = "remaining_policy"


@dataclass(frozen=True)
class Function:
    name: str
    start: int
    end: int
    nonblank: int
    body: str


def mask_c_source(source: str) -> str:
    """Remove comments and literals without changing offsets or line breaks."""
    output = list(source)
    index = 0
    state = "code"
    while index < len(source):
        if state == "code":
            if source.startswith("//", index):
                output[index] = " "
                output[index + 1] = " "
                index += 2
                state = "line_comment"
                continue
            if source.startswith("/*", index):
                output[index] = " "
                output[index + 1] = " "
                index += 2
                state = "block_comment"
                continue
            if source[index] == '"':
                output[index] = " "
                index += 1
                state = "string"
                continue
            if source[index] == "'":
                output[index] = " "
                index += 1
                state = "char"
                continue
            index += 1
            continue
        if state == "line_comment":
            if source[index] == "\n":
                state = "code"
            else:
                output[index] = " "
            index += 1
            continue
        if state == "block_comment":
            if source.startswith("*/", index):
                output[index] = " "
                output[index + 1] = " "
                index += 2
                state = "code"
            else:
                if source[index] != "\n":
                    output[index] = " "
                index += 1
            continue
        if state == "string":
            if source[index] == "\\" and index + 1 < len(source):
                output[index] = " "
                output[index + 1] = " "
                index += 2
                continue
            if source[index] == '"':
                state = "code"
            if source[index] != "\n":
                output[index] = " "
            index += 1
            continue
        if state == "char":
            if source[index] == "\\" and index + 1 < len(source):
                output[index] = " "
                output[index + 1] = " "
                index += 2
                continue
            if source[index] == "'":
                state = "code"
            if source[index] != "\n":
                output[index] = " "
            index += 1
    return "".join(output)


def find_functions(source: str) -> list[Function]:
    masked = mask_c_source(source)
    source_lines = source.splitlines()
    functions: list[Function] = []
    depth = 0
    for position, character in enumerate(masked):
        if character == "{":
            if depth == 0:
                prefix = masked[max(0, position - 3000) : position]
                statement_start = max(
                    prefix.rfind(";"),
                    prefix.rfind("}"),
                    prefix.rfind("{"),
                    prefix.rfind("#"),
                ) + 1
                header = prefix[statement_start:]
                match = re.search(
                    r"([A-Za-z_][A-Za-z0-9_]*)\s*\([^()]*\)\s*$",
                    header,
                    re.DOTALL,
                )
                if match and match.group(1) not in {"if", "for", "while", "switch"}:
                    nested = 1
                    end_position = position + 1
                    while end_position < len(masked) and nested:
                        if masked[end_position] == "{":
                            nested += 1
                        elif masked[end_position] == "}":
                            nested -= 1
                        end_position += 1
                    start = masked.count("\n", 0, position) + 1
                    end = masked.count("\n", 0, end_position - 1) + 1
                    body_lines = source_lines[start - 1 : end]
                    functions.append(
                        Function(
                            name=match.group(1),
                            start=start,
                            end=end,
                            nonblank=sum(bool(line.strip()) for line in body_lines),
                            body="\n".join(body_lines),
                        )
                    )
            depth += 1
        elif character == "}":
            depth -= 1
    return functions


def read_manifest() -> dict[str, str]:
    classes: dict[str, str] = {}
    errors: list[str] = []
    for line_number, raw_line in enumerate(
        MANIFEST.read_text(encoding="utf-8").splitlines(), 1
    ):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        fields = raw_line.split("\t")
        if len(fields) != 2 or not fields[0] or not fields[1]:
            errors.append(f"manifest line {line_number}: expected function<TAB>class")
            continue
        name, category = fields
        if category not in ALLOWED_CLASSES:
            errors.append(
                f"manifest line {line_number}: unknown class {category!r} for {name}"
            )
        if name in classes:
            errors.append(f"manifest line {line_number}: duplicate function {name}")
        classes[name] = category
    if errors:
        for error in errors:
            print(f"native_c_classification error={error}", file=sys.stderr)
        raise SystemExit(1)
    return classes


def count_nonblank(path: Path) -> int:
    return sum(bool(line.strip()) for line in path.read_text(encoding="utf-8").splitlines())


def main() -> int:
    source = HOST.read_text(encoding="utf-8")
    functions = find_functions(source)
    by_name = {function.name: function for function in functions}
    if len(by_name) != len(functions):
        duplicates = sorted(
            name for name in by_name if sum(item.name == name for item in functions) > 1
        )
        print(
            "native_c_classification error=duplicate_function_definitions "
            + ",".join(duplicates),
            file=sys.stderr,
        )
        return 1

    classes = read_manifest()
    missing = sorted(set(by_name) - set(classes))
    stale = sorted(set(classes) - set(by_name))
    if missing or stale:
        if missing:
            print(
                "native_c_classification error=unclassified_functions "
                + ",".join(missing),
                file=sys.stderr,
            )
        if stale:
            print(
                "native_c_classification error=stale_manifest_functions "
                + ",".join(stale),
                file=sys.stderr,
            )
        return 1

    # A migrated-policy classification must retain a direct Zig policy call.
    # This prevents the manifest from becoming a label for unreviewed C logic.
    policy_call = re.compile(
        r"\bnoctty_grid_[A-Za-z0-9_]*(?:plan|text|label|message|policy|geometry|"
        r"ratio|clamp|route|sequence|format|valid|action|target|position|event|"
        r"feedback|name|color|status|preset|setting|mode|title|tooltip|markup|"
        r"payload|prompt|selection|scroll|split|font|orientation|direction|"
        r"shortcut|menu|control|visibility|lifecycle)[A-Za-z0-9_]*\s*\("
    )
    invalid_migrated = sorted(
        function.name
        for function in functions
        if classes[function.name] == "migrated_policy"
        and not policy_call.search(function.body)
    )
    if invalid_migrated:
        print(
            "native_c_classification error=migrated_policy_without_zig_call "
            + ",".join(invalid_migrated),
            file=sys.stderr,
        )
        return 1

    counts = {category: [0, 0] for category in sorted(ALLOWED_CLASSES)}
    for function in functions:
        category = classes[function.name]
        counts[category][0] += 1
        counts[category][1] += function.nonblank
    print(
        "native_c_classification "
        + " ".join(
            f"{category}_functions={counts[category][0]} {category}_lines={counts[category][1]}"
            for category in sorted(ALLOWED_CLASSES)
        )
        + " unclassified=0"
    )

    # C policy is counted only when it is explicitly marked remaining_policy.
    # Native effects, object queries, lifetime glue, and display orchestration
    # are outside the ownership denominator by the locked NCT-126 definition.
    c_policy_lines = counts[POLICY_CLASS][1]
    zig_lines = 0
    for path in sorted((ROOT / "src").rglob("*.zig")):
        relative = path.relative_to(ROOT)
        if any(part in {"vendor", "generated"} for part in relative.parts):
            continue
        zig_lines += count_nonblank(path)
    total_lines = zig_lines + c_policy_lines
    if total_lines <= 0:
        print("native_c_classification error=empty_policy_scope", file=sys.stderr)
        return 1
    basis_points = zig_lines * 10000 // total_lines
    if basis_points < 9000:
        print(
            "zig_ownership error=below_target "
            f"zig_lines={zig_lines} adapter_lines={c_policy_lines} "
            f"percentage={basis_points // 100}.{basis_points % 100:02d} "
            "target=90.00",
            file=sys.stderr,
        )
        return 1
    print(
        "zig_ownership "
        f"zig_lines={zig_lines} adapter_lines={c_policy_lines} "
        f"percentage={basis_points // 100}.{basis_points % 100:02d} "
        "target=90.00 policy_scope=first_party_zig_plus_remaining_c_policy "
        "vendor_generated_excluded=true display_orchestration_excluded=true "
        "headers_and_native_effects_excluded=true"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
