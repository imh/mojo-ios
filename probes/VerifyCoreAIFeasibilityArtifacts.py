#!/usr/bin/env python3
"""Verify the exact Core AI feasibility slice and its AOT specializations."""

import json
from argparse import ArgumentParser
from pathlib import Path


EXPECTED_ARCHITECTURES = {
    "h13g",
    "h14g",
    "h15g",
    "h16g",
    "h16p",
    "h17g",
    "h17p",
    "h18p",
}


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as input_file:
        value = json.load(input_file)
    assert isinstance(value, dict), f"expected a JSON object in {path}"
    return value


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("--source-inspection", type=Path, required=True)
    parser.add_argument("--m1-inspection", type=Path, required=True)
    parser.add_argument("--compiled-directory", type=Path, required=True)
    arguments = parser.parse_args()

    source = load_json(arguments.source_inspection)
    source_summary = source["summary"]
    assert source_summary["compatibilityVersion"] == "27.0"
    assert source_summary["functions"] == [
        {
            "name": "main",
            "inputs": [
                {"name": "input_values", "type": "NDArray (Float32, 2 × 3)"}
            ],
            "outputs": [
                {"name": "result", "type": "NDArray (Float32, 2 × 4)"}
            ],
        }
    ]
    operation_counts = {
        operation["name"]: operation["count"]
        for operation in source_summary["operationDistribution"]
    }
    assert operation_counts["batch_matmul"] == 1
    assert operation_counts["relu"] == 1

    compiled_architectures = {
        model_path.name.removeprefix("CoreAIDirectGraphProbe.").removesuffix(
            ".aimodelc"
        )
        for model_path in arguments.compiled_directory.glob(
            "CoreAIDirectGraphProbe.*.aimodelc"
        )
        if model_path.is_dir()
    }
    assert EXPECTED_ARCHITECTURES <= compiled_architectures, (
        f"missing iOS AOT architectures: "
        f"{sorted(EXPECTED_ARCHITECTURES - compiled_architectures)}"
    )

    m1 = load_json(arguments.m1_inspection)
    assert m1["supportedArchitectures"] == ["h13g"]
    assert m1["supportedChips"] == ["M1"]
    assert "iOS 27.0" in m1["minSupportedOSVersions"]
    assert m1["summary"]["functions"] == source_summary["functions"]

    print(
        "verified Core AI graph schema, operations, and iOS AOT architectures: "
        + ", ".join(sorted(compiled_architectures))
    )


if __name__ == "__main__":
    main()
