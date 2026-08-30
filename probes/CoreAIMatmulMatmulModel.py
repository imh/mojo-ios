#!/usr/bin/env python3
"""Author the fixed-shape AOT model used only by the direct Apple probe."""

from argparse import ArgumentParser
from pathlib import Path
from typing import Annotated

import numpy as np
from coreai._compiler.dialects import coreai as operations
from coreai._compiler.ir import Value
from coreai.authoring import AIProgram, Module, TensorSpec


INPUT_SPEC = TensorSpec(shape=[2, 3], dtype=np.float32)
FIRST_WEIGHTS_SPEC = TensorSpec(shape=[3, 4], dtype=np.float32)
SECOND_WEIGHTS_SPEC = TensorSpec(shape=[4, 2], dtype=np.float32)
OUTPUT_SPEC = TensorSpec(shape=[2, 2], dtype=np.float32, name="result")


def build_program() -> tuple[AIProgram, Module]:
    module = Module.create()
    with module:

        @operations.graph
        def main(
            input_values: Annotated[Value, INPUT_SPEC],
            first_weights: Annotated[Value, FIRST_WEIGHTS_SPEC],
            second_weights: Annotated[Value, SECOND_WEIGHTS_SPEC],
        ) -> Annotated[Value, OUTPUT_SPEC]:
            intermediate = operations.batch_matmul(input_values, first_weights)
            return operations.batch_matmul(intermediate, second_weights)

    module.verify()
    return AIProgram(module), module


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--ir-output", required=True, type=Path)
    arguments = parser.parse_args()
    assert arguments.output.suffix == ".aimodel"

    program, module = build_program()
    arguments.ir_output.parent.mkdir(parents=True, exist_ok=True)
    arguments.ir_output.write_text(module.as_string(), encoding="utf-8")
    asset = program.save_asset(arguments.output)
    assert asset.path == arguments.output.resolve()


if __name__ == "__main__":
    main()
