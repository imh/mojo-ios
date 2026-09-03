#!/usr/bin/env python3
"""Extract embedded Metal libraries from a Mach-O or archive member."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


MAGIC = b"MTLB"
FILE_SIZE_OFFSET = 16
HEADER_PREFIX_SIZE = 24


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output_directory", type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    payload = arguments.input.read_bytes()
    offsets: list[int] = []
    cursor = 0
    while True:
        offset = payload.find(MAGIC, cursor)
        if offset < 0:
            break
        offsets.append(offset)
        cursor = offset + len(MAGIC)
    if not offsets:
        raise SystemExit(f"no embedded metallib found in {arguments.input}")

    arguments.output_directory.mkdir(parents=True, exist_ok=True)
    for index, offset in enumerate(offsets):
        if offset + HEADER_PREFIX_SIZE > len(payload):
            raise SystemExit(f"truncated metallib header at offset {offset}")
        file_size = struct.unpack_from("<Q", payload, offset + FILE_SIZE_OFFSET)[0]
        if file_size < HEADER_PREFIX_SIZE or offset + file_size > len(payload):
            raise SystemExit(
                f"invalid metallib size {file_size} at offset {offset}"
            )
        output_path = arguments.output_directory / f"metal-{index}.metallib"
        output_path.write_bytes(payload[offset : offset + file_size])
        print(
            f"METALLIB_EXTRACTED index={index} offset={offset} "
            f"size={file_size} output={output_path}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
