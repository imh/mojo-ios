#!/usr/bin/env python3

import argparse
import plistlib
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("xcframework", type=Path)
    arguments = parser.parse_args()

    xcframework_path = arguments.xcframework.resolve()
    if (
        not xcframework_path.is_dir()
        or xcframework_path.suffix != ".xcframework"
    ):
        print("expected an XCFramework directory", file=sys.stderr)
        return 2
    info_path = xcframework_path / "Info.plist"
    try:
        info = plistlib.loads(info_path.read_bytes())
    except (OSError, plistlib.InvalidFileException) as error:
        print(f"cannot read XCFramework Info.plist: {error}", file=sys.stderr)
        return 1
    libraries = info.get("AvailableLibraries")
    if not isinstance(libraries, list) or not libraries:
        print("XCFramework AvailableLibraries must be a nonempty list", file=sys.stderr)
        return 1
    identifiers = []
    for library in libraries:
        if not isinstance(library, dict) or not isinstance(
            library.get("LibraryIdentifier"), str
        ):
            print("every XCFramework library needs an identifier", file=sys.stderr)
            return 1
        identifiers.append(library["LibraryIdentifier"])
    if len(identifiers) != len(set(identifiers)):
        print("XCFramework library identifiers must be unique", file=sys.stderr)
        return 1

    info["AvailableLibraries"] = sorted(
        libraries, key=lambda library: library["LibraryIdentifier"]
    )
    normalized = plistlib.dumps(info, fmt=plistlib.FMT_XML, sort_keys=True)
    temporary_path = info_path.with_suffix(".plist.tmp")
    temporary_path.write_bytes(normalized)
    temporary_path.replace(info_path)
    print(
        "XCFRAMEWORK_NORMALIZE_PASS "
        f"path={xcframework_path} variants={len(libraries)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
