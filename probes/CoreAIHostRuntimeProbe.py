#!/usr/bin/env python3
"""Execute the direct Core AI graph and prove its typed numerical contract."""

import asyncio
from argparse import ArgumentParser
from pathlib import Path

import numpy as np
from coreai.authoring import AIModelAsset
from coreai.runtime import InferenceFunction, NDArray


INPUT_VALUES = np.array(
    [
        [1.0, 2.0, 3.0],
        [-1.0, 0.5, 2.0],
    ],
    dtype=np.float32,
)
EXPECTED_RESULT = np.array(
    [
        [7.0, 1.0, 2.5, 1.0],
        [3.0, 1.5, 1.25, 0.0],
    ],
    dtype=np.float32,
)


async def run(asset_path: Path) -> None:
    assert AIModelAsset.is_valid(asset_path), f"invalid Core AI asset: {asset_path}"
    asset = AIModelAsset.load(asset_path)
    all_results: list[np.ndarray] = []
    for session_index in range(2):
        async with asset.executable() as model:
            assert model.function_names == ["main"]
            function: InferenceFunction = model.load_function("main")
            assert function.desc.input_names == ["input_values"]
            assert function.desc.output_names == ["result"]

            async def evaluate() -> np.ndarray:
                outputs = await function({"input_values": NDArray(INPUT_VALUES)})
                assert list(outputs) == ["result"]
                return outputs["result"].numpy().copy()

            if session_index == 0:
                all_results.extend([await evaluate() for _ in range(3)])
                all_results.extend(
                    await asyncio.gather(*(evaluate() for _ in range(8)))
                )
                invalid_input = np.zeros((2, 2), dtype=np.float32)
                try:
                    await function({"input_values": NDArray(invalid_input)})
                except RuntimeError as error:
                    assert str(error) == (
                        "input_values has an invalid shape: [2, 2], "
                        "expected: [2, 3]"
                    )
                else:
                    raise AssertionError("wrong-shape Core AI input was accepted")
            else:
                all_results.append(await evaluate())

    assert len(all_results) == 12
    for result in all_results:
        assert result.shape == EXPECTED_RESULT.shape
        assert result.dtype == EXPECTED_RESULT.dtype
        np.testing.assert_array_equal(result, EXPECTED_RESULT)
    print(all_results[0])


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("asset", type=Path)
    arguments = parser.parse_args()
    asyncio.run(run(arguments.asset))


if __name__ == "__main__":
    main()
