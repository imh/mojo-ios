#!/usr/bin/env python3
"""Apply explicit symbol, platform, and dependency contracts to Mach-O files."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


PLATFORMS = {"macos": "1", "ios": "2", "ios-simulator": "7"}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--expect-platform", choices=sorted(PLATFORMS))
    parser.add_argument("--require-defined", action="append", default=[])
    parser.add_argument("--require-undefined", action="append", default=[])
    parser.add_argument("--forbid-defined-regex", action="append", default=[])
    parser.add_argument("--forbid-undefined-regex", action="append", default=[])
    parser.add_argument("--require-defined-count", action="append", default=[])
    parser.add_argument("--allow-dependency-regex", action="append", default=[])
    parser.add_argument("--json-output", type=Path)
    return parser.parse_args()


def run(command: list[str], *, allow_failure: bool = False) -> str:
    completed = subprocess.run(command, check=False, capture_output=True, text=True)
    if completed.returncode != 0 and not allow_failure:
        raise RuntimeError(
            f"command failed ({completed.returncode}): {' '.join(command)}\n"
            f"{completed.stderr.strip()}"
        )
    return completed.stdout


def logical_symbol(raw_symbol: str) -> str:
    return raw_symbol[1:] if raw_symbol.startswith("_") else raw_symbol


def symbols(path: Path, undefined: bool) -> list[str]:
    arguments = ["xcrun", "nm", "-u" if undefined else "-gU", str(path)]
    output = run(arguments)
    result: list[str] = []
    for line in output.splitlines():
        fields = line.split()
        if not fields:
            continue
        candidate = fields[-1]
        if candidate.endswith(":") or candidate.startswith("("):
            continue
        result.append(logical_symbol(candidate))
    return result


def platforms(path: Path) -> list[str]:
    output = run(["xcrun", "otool", "-l", str(path)])
    return re.findall(r"^\s*platform\s+(\d+)\s*$", output, re.MULTILINE)


def dependencies(path: Path) -> list[str]:
    output = run(["xcrun", "otool", "-L", str(path)], allow_failure=True)
    result = []
    for line in output.splitlines()[1:]:
        stripped = line.strip()
        if stripped:
            result.append(stripped.split(" (compatibility version", 1)[0])
    return result


def main() -> int:
    arguments = parse_arguments()
    errors: list[str] = []
    reports = []
    count_contracts: list[tuple[str, int]] = []
    for contract in arguments.require_defined_count:
        if "=" not in contract:
            print(f"invalid --require-defined-count value: {contract}", file=sys.stderr)
            return 2
        name, raw_count = contract.rsplit("=", 1)
        if not raw_count.isdigit():
            print(f"invalid symbol count: {contract}", file=sys.stderr)
            return 2
        count_contracts.append((name, int(raw_count)))

    for path in arguments.paths:
        if not path.is_file():
            errors.append(f"missing Mach-O input: {path}")
            continue
        try:
            defined = symbols(path, False)
            undefined = symbols(path, True)
            observed_platforms = platforms(path) if arguments.expect_platform else []
            observed_dependencies = dependencies(path)
        except RuntimeError as error:
            errors.append(f"{path}: {error}")
            continue

        defined_set = set(defined)
        undefined_set = set(undefined)
        for required in arguments.require_defined:
            if required not in defined_set:
                errors.append(f"{path}: required defined symbol is missing: {required}")
        for required in arguments.require_undefined:
            if required not in undefined_set:
                errors.append(f"{path}: required undefined symbol is missing: {required}")
        for pattern_text in arguments.forbid_defined_regex:
            pattern = re.compile(pattern_text)
            for symbol in sorted(defined_set):
                if pattern.search(symbol):
                    errors.append(f"{path}: forbidden defined symbol: {symbol}")
        for pattern_text in arguments.forbid_undefined_regex:
            pattern = re.compile(pattern_text)
            for symbol in sorted(undefined_set):
                if pattern.search(symbol):
                    errors.append(f"{path}: forbidden undefined symbol: {symbol}")
        for name, expected_count in count_contracts:
            actual_count = defined.count(name)
            if actual_count != expected_count:
                errors.append(
                    f"{path}: defined symbol count mismatch for {name}: "
                    f"expected={expected_count} actual={actual_count}"
                )
        if arguments.expect_platform:
            expected_platform = PLATFORMS[arguments.expect_platform]
            if not observed_platforms:
                errors.append(f"{path}: no Mach-O platform load command found")
            unexpected = sorted(set(observed_platforms) - {expected_platform})
            if unexpected:
                errors.append(
                    f"{path}: expected platform={expected_platform}, observed={unexpected}"
                )
        if arguments.allow_dependency_regex:
            allowed_patterns = [re.compile(value) for value in arguments.allow_dependency_regex]
            for dependency in observed_dependencies:
                if not any(pattern.search(dependency) for pattern in allowed_patterns):
                    errors.append(f"{path}: unexpected dependency: {dependency}")

        reports.append(
            {
                "path": str(path),
                "defined_symbols": sorted(defined_set),
                "undefined_symbols": sorted(undefined_set),
                "platforms": observed_platforms,
                "dependencies": observed_dependencies,
            }
        )

    report = {"artifacts": reports, "errors": errors}
    if arguments.json_output:
        arguments.json_output.parent.mkdir(parents=True, exist_ok=True)
        arguments.json_output.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    if errors:
        print("Mach-O contract violations:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1
    print(f"MACHO_CONTRACT_AUDIT_PASS artifacts={len(reports)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
