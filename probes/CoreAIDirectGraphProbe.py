#!/usr/bin/env python3
"""Author the smallest useful Core AI graph without routing through PyTorch."""

from argparse import ArgumentParser
from pathlib import Path
from typing import Annotated

import numpy as np

# Apple uses these operation builders in the coreai-core direct-authoring
# tutorial, but notes that their public coreai.authoring re-export is pending.
# Keep the import visibly isolated so the feasibility gate cannot mistake the
# current beta spelling for a stable interface.
from coreai._compiler.dialects import coreai as operations
from coreai._compiler.ir import Value
from coreai.authoring import AIProgram, Module, TensorSpec


INPUT_SPEC = TensorSpec(shape=[2, 3], dtype=np.float32)
OUTPUT_SPEC = TensorSpec(shape=[2, 4], dtype=np.float32, name="result")
WEIGHTS = np.array(
    [
        [1.0, -1.0, 0.5, 2.0],
        [0.0, 1.0, -0.5, 1.0],
        [2.0, 0.0, 1.0, -1.0],
    ],
    dtype=np.float32,
)


def build_program() -> tuple[AIProgram, Module]:
    """Build and verify a fixed-shape matrix multiply followed by ReLU."""
    module = Module.create()
    with module:

        @operations.graph
        def main(
            input_values: Annotated[Value, INPUT_SPEC],
        ) -> Annotated[Value, OUTPUT_SPEC]:
            multiplied = operations.batch_matmul(input_values, WEIGHTS)
            return operations.relu(multiplied)

    module.verify()
    return AIProgram(module), module


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--ir-output", type=Path)
    arguments = parser.parse_args()

    assert arguments.output.suffix == ".aimodel", (
        "Core AI source assets must have the .aimodel suffix"
    )

    program, module = build_program()
    if arguments.ir_output is not None:
        arguments.ir_output.parent.mkdir(parents=True, exist_ok=True)
        arguments.ir_output.write_text(module.as_string(), encoding="utf-8")

    asset = program.save_asset(arguments.output)
    assert asset.path == arguments.output.resolve()
    assert arguments.output.is_dir()
    print(arguments.output)


if __name__ == "__main__":
    main()
