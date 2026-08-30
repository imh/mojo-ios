#!/usr/bin/env python3
"""Generate deterministic resource hashes and toolchain provenance."""

from argparse import ArgumentParser
from hashlib import sha256
import json
from pathlib import Path


def hash_tree(root: Path) -> list[dict[str, str]]:
    return [
        {
            "path": str(path.relative_to(root)),
            "sha256": sha256(path.read_bytes()).hexdigest(),
        }
        for path in sorted(root.rglob("*"))
        if path.is_file()
    ]


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("--asset", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--compiler-revision", required=True)
    parser.add_argument("--xcode-version", required=True)
    parser.add_argument("--xcode-build", required=True)
    parser.add_argument("--coreai-build-version", required=True)
    parser.add_argument("--authoring-version", required=True)
    arguments = parser.parse_args()

    asset = arguments.asset.resolve()
    assert asset.is_dir()
    manifest = {
        "format_version": 1,
        "region": "matmul_matmul_f32_2x3x4x2",
        "producer": "direct-coreai-authoring-probe",
        "mojo_backend": "not-implemented",
        "runtime_resource": asset.name,
        "minimum_os": "iOS/iPadOS 27.0",
        "placement_contract": "submitted-to-coreai-neural-engine-preferred",
        "fallback": "none",
        "inputs": {
            "input_values": {"dtype": "float32", "shape": [2, 3]},
            "first_weights": {"dtype": "float32", "shape": [3, 4]},
            "second_weights": {"dtype": "float32", "shape": [4, 2]},
        },
        "outputs": {"result": {"dtype": "float32", "shape": [2, 2]}},
        "toolchain": {
            "compiler_revision": arguments.compiler_revision,
            "xcode_version": arguments.xcode_version,
            "xcode_build": arguments.xcode_build,
            "coreai_build_version": arguments.coreai_build_version,
            "coreai_authoring_version": arguments.authoring_version,
        },
        "files": hash_tree(asset),
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
