#!/usr/bin/env python3
"""Report patched upstream surface additions and reject known project APIs."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


FORBIDDEN_ADDITION = re.compile(
    r"\b(?:ios_parallel|mojo_ios_(?:runtime|async_runtime|coreai_runtime)|"
    r"__mojo_coreai_semantic_|CoreAIRegionPass|AsyncRT_CoreAI_|"
    r"ASYNCRT_APPLE_DEVICE_CONTEXT_COREAI|is_coreai)\b"
)
MOJO_DECLARATION = re.compile(
    r"^\s*(?:(?:comptime|public)\s+)?(?:def|fn|struct|trait|alias)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)"
)
C_DECLARATION = re.compile(
    r"^\s*(?:extern\s+)?(?:[A-Za-z_][\w\s*]+\s+)?"
    r"((?:KGEN_CompilerRT_|AsyncRT_)[A-Za-z0-9_]+)\s*\("
)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Inspect the diff from pinned upstream HEAD to the patched checkout. "
            "Known project-specific public/compiler/runtime surfaces fail; all "
            "other added declarations are reported for architectural review."
        )
    )
    parser.add_argument("--upstream-root", type=Path)
    parser.add_argument("--json-output", type=Path)
    return parser.parse_args()


def run_git(upstream_root: Path, *arguments: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(upstream_root), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or "git command failed")
    return completed.stdout


def main() -> int:
    arguments = parse_arguments()
    project_root = Path(__file__).resolve().parent.parent
    upstream_root = (arguments.upstream_root or project_root / ".work/modular").resolve()
    if not (upstream_root / ".git").is_dir():
        print(f"upstream checkout is missing: {upstream_root}", file=sys.stderr)
        return 2

    try:
        diff = run_git(upstream_root, "diff", "--no-ext-diff", "--unified=0", "HEAD", "--")
    except RuntimeError as error:
        print(f"upstream surface audit: {error}", file=sys.stderr)
        return 2

    current_path = ""
    additions: list[dict[str, str | int]] = []
    forbidden: list[dict[str, str | int]] = []
    new_line_number = 0
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            current_path = line[6:]
            continue
        if line.startswith("@@"):
            match = re.search(r"\+(\d+)", line)
            new_line_number = int(match.group(1)) if match else 0
            continue
        if line.startswith("+") and not line.startswith("+++"):
            added_line = line[1:]
            record = {
                "path": current_path,
                "line": new_line_number,
                "text": added_line.strip(),
            }
            if FORBIDDEN_ADDITION.search(added_line):
                forbidden.append(record)
            if current_path.endswith(".mojo"):
                declaration = MOJO_DECLARATION.match(added_line)
                if declaration:
                    additions.append({**record, "kind": "mojo", "name": declaration.group(1)})
            elif current_path.endswith((".h", ".c", ".cc", ".cpp", ".m", ".mm")):
                declaration = C_DECLARATION.match(added_line)
                if declaration:
                    additions.append({**record, "kind": "runtime", "name": declaration.group(1)})
            new_line_number += 1
        elif line.startswith(" "):
            new_line_number += 1

    report = {
        "upstream_root": str(upstream_root),
        "added_declarations": additions,
        "forbidden_additions": forbidden,
    }
    if arguments.json_output:
        arguments.json_output.parent.mkdir(parents=True, exist_ok=True)
        arguments.json_output.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

    for addition in additions:
        print(
            f"SURFACE_ADDITION {addition['kind']} {addition['path']}:"
            f"{addition['line']} {addition['name']}"
        )
    if forbidden:
        print("forbidden project-specific upstream additions:", file=sys.stderr)
        for record in forbidden:
            print(
                f"  {record['path']}:{record['line']}: {record['text']}",
                file=sys.stderr,
            )
        return 1

    print(f"UPSTREAM_SURFACE_AUDIT_PASS reviewed_additions={len(additions)} forbidden=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
