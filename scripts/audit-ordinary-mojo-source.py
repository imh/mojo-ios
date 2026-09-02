#!/usr/bin/env python3
"""Reject project-facing platform paths in ordinary Mojo conformance sources."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


RULES: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "iOS target branch",
        re.compile(r"\b(?:CompilationTarget|target)\.is_ios\b"),
    ),
    ("legacy iOS parallel API", re.compile(r"\bios_parallel\b")),
    (
        "project-specific Mojo runtime ABI",
        re.compile(r"\bmojo_ios_(?:runtime|async_runtime|coreai_runtime)\b"),
    ),
    (
        "removed Core AI semantic marker ABI",
        re.compile(r"\b__mojo_coreai_semantic_\w*\b"),
    ),
)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Check ordinary Mojo fixtures for established project-facing iOS "
            "branches, compatibility APIs, and runtime ABIs. This is a source "
            "guard, not a semantic fallback proof."
        )
    )
    parser.add_argument("paths", nargs="+", type=Path)
    return parser.parse_args()


def mojo_files(paths: list[Path]) -> list[Path]:
    files: set[Path] = set()
    for path in paths:
        if path.is_dir():
            files.update(candidate for candidate in path.rglob("*.mojo") if candidate.is_file())
        elif path.is_file():
            files.add(path)
        else:
            raise ValueError(f"source path does not exist: {path}")
    if not files:
        raise ValueError("no Mojo source files were selected")
    return sorted(files)


def main() -> int:
    arguments = parse_arguments()
    try:
        files = mojo_files(arguments.paths)
    except ValueError as error:
        print(f"ordinary-Mojo source audit: {error}", file=sys.stderr)
        return 2

    violations: list[str] = []
    for path in files:
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for rule_name, pattern in RULES:
                if pattern.search(line):
                    violations.append(
                        f"{path}:{line_number}: {rule_name}: {line.strip()}"
                    )

    if violations:
        print("ordinary Mojo source policy violations:", file=sys.stderr)
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        return 1

    print(f"ORDINARY_MOJO_SOURCE_AUDIT_PASS files={len(files)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
