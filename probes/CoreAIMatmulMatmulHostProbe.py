#!/usr/bin/env python3
"""Numerically verify the AOT model's exact typed contract on the host."""

import asyncio
import sys
from pathlib import Path

import numpy as np
from coreai.authoring import AIModelAsset
from coreai.runtime import InferenceFunction, NDArray


INPUT = np.array([[1, 2, 3], [4, 5, 6]], dtype=np.float32)
FIRST_WEIGHTS = np.array(
    [[1, 0, 0, 1], [0, 1, 1, 0], [1, 1, 0, 0]], dtype=np.float32
)
SECOND_WEIGHTS = np.array(
    [[1, 0], [0, 1], [1, 0], [0, 1]], dtype=np.float32
)
EXPECTED = INPUT @ FIRST_WEIGHTS @ SECOND_WEIGHTS


async def run(asset_path: Path) -> None:
    assert AIModelAsset.is_valid(asset_path)
    asset = AIModelAsset.load(asset_path)
    async with asset.executable() as model:
        assert model.function_names == ["main"]
        function: InferenceFunction = model.load_function("main")
        assert function.desc.input_names == [
            "input_values",
            "first_weights",
            "second_weights",
        ]
        assert function.desc.output_names == ["result"]
        outputs = await function(
            {
                "input_values": NDArray(INPUT),
                "first_weights": NDArray(FIRST_WEIGHTS),
                "second_weights": NDArray(SECOND_WEIGHTS),
            }
        )
        actual = outputs["result"].numpy().copy()
        np.testing.assert_array_equal(actual, EXPECTED)


if __name__ == "__main__":
    asyncio.run(run(Path(sys.argv[1]).resolve()))
