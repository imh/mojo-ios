#!/usr/bin/env python3
"""Record a mechanical, non-status receipt for one capability gate run."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import platform
import subprocess
import sys
from pathlib import Path


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gate", required=True)
    parser.add_argument("--result", required=True, choices=("pass", "fail"))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--field", action="append", default=[])
    parser.add_argument("--artifact", action="append", default=[], type=Path)
    parser.add_argument("--command", action="append", default=[])
    return parser.parse_args()


def command_output(command: list[str], cwd: Path) -> str | None:
    completed = subprocess.run(command, cwd=cwd, check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        return None
    return completed.stdout.strip()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    arguments = parse_arguments()
    project_root = Path(__file__).resolve().parent.parent
    fields: dict[str, str] = {}
    for field in arguments.field:
        if "=" not in field:
            print(f"invalid --field value: {field}", file=sys.stderr)
            return 2
        key, value = field.split("=", 1)
        if not key or key in fields:
            print(f"invalid or duplicate evidence field: {key}", file=sys.stderr)
            return 2
        fields[key] = value

    artifact_records = []
    for artifact in arguments.artifact:
        resolved = artifact.resolve()
        if not resolved.is_file():
            print(f"evidence artifact is missing or not a file: {artifact}", file=sys.stderr)
            return 2
        artifact_records.append(
            {"path": str(resolved), "size": resolved.stat().st_size, "sha256": sha256(resolved)}
        )

    upstream_revision_path = project_root / "upstream/REVISION"
    patch_records = []
    for patch_path in sorted((project_root / "patches/modular").glob("*.patch")):
        patch_records.append(
            {"path": str(patch_path.relative_to(project_root)), "sha256": sha256(patch_path)}
        )
    repository_revision = command_output(["git", "rev-parse", "HEAD"], project_root)
    repository_status = command_output(["git", "status", "--porcelain"], project_root)
    xcode_version = None
    if os.environ.get("DEVELOPER_DIR"):
        xcode_version = command_output(["xcodebuild", "-version"], project_root)

    receipt = {
        "schema": 1,
        "kind": "mojo-ios-gate-evidence",
        "gate": arguments.gate,
        "result": arguments.result,
        "recorded_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "repository": {
            "revision": repository_revision,
            "dirty": bool(repository_status),
        },
        "upstream": {
            "revision": upstream_revision_path.read_text(encoding="utf-8").strip()
            if upstream_revision_path.is_file()
            else None,
            "patches": patch_records,
        },
        "host": {"system": platform.system(), "release": platform.release(), "machine": platform.machine()},
        "apple_toolchain": {
            "developer_directory": os.environ.get("DEVELOPER_DIR"),
            "xcode_version": xcode_version.splitlines() if xcode_version else None,
        },
        "fields": dict(sorted(fields.items())),
        "commands": arguments.command,
        "artifacts": artifact_records,
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"GATE_EVIDENCE_RECORDED gate={arguments.gate} result={arguments.result} output={arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
