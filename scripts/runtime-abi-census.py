#!/usr/bin/env python3
"""Classify the complete pinned CompilerRT and DeviceContext C ABI."""

from __future__ import annotations

import argparse
import csv
import fnmatch
import pathlib
import re
import sys


KGEN_SYMBOL = re.compile(r"\b(KGEN_CompilerRT_[A-Za-z0-9_]+)\s*\(")
DEVICE_SYMBOL = re.compile(
    r"\b(AsyncRT_Device(?:Context|Buffer|Function)_[A-Za-z0-9_]+)\s*\("
)
REFERENCE_SYMBOL = re.compile(r"\bKGEN_CompilerRT_[A-Za-z0-9_]+\b")
METAL_SEMANTIC_SYMBOLS = {
    "AsyncRT_DeviceBuffer_bytesize",
    "AsyncRT_DeviceBuffer_release",
    "AsyncRT_DeviceBuffer_retain",
    "AsyncRT_DeviceContext_DtoH_async",
    "AsyncRT_DeviceContext_HtoD_async",
    "AsyncRT_DeviceContext_createBuffer_async",
    "AsyncRT_DeviceContext_enqueueFunctionDirect",
    "AsyncRT_DeviceContext_loadFunction",
    "AsyncRT_DeviceFunction_release",
    "AsyncRT_DeviceFunction_retain",
    "AsyncRT_DeviceFunction_copyToConstantMemory",
}


def read_text(path: pathlib.Path) -> str:
    assert path.is_file(), f"missing ABI source: {path}"
    return path.read_text(encoding="utf-8")


def mentioned_symbols(paths: list[pathlib.Path], pattern: re.Pattern[str]) -> set[str]:
    result: set[str] = set()
    for path in paths:
        result.update(pattern.findall(read_text(path)))
    return result


def defined_symbols(paths: list[pathlib.Path], pattern: re.Pattern[str]) -> set[str]:
    result: set[str] = set()
    for path in paths:
        source = read_text(path)
        for match in pattern.finditer(source):
            opening_parenthesis = source.find("(", match.end(1))
            assert opening_parenthesis >= 0
            depth = 0
            closing_parenthesis = -1
            for index in range(opening_parenthesis, len(source)):
                character = source[index]
                if character == "(":
                    depth += 1
                elif character == ")":
                    depth -= 1
                    assert depth >= 0, f"unbalanced declaration in {path}"
                    if depth == 0:
                        closing_parenthesis = index
                        break
            assert closing_parenthesis >= 0, f"unterminated declaration in {path}"
            following = source[closing_parenthesis + 1 :].lstrip()
            if following.startswith("{"):
                result.add(match.group(1))
    return result


def load_dispositions(path: pathlib.Path, project_root: pathlib.Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    expected_fields = {"pattern", "disposition", "reason", "evidence"}
    assert rows, "runtime ABI disposition file must not be empty"
    assert set(rows[0]) == expected_fields, "unexpected runtime ABI disposition columns"
    allowed = {"statically_unreachable", "compile_time_rejected", "runtime_rejected"}
    seen_patterns: set[str] = set()
    for row in rows:
        assert row["pattern"] not in seen_patterns, f"duplicate pattern: {row['pattern']}"
        seen_patterns.add(row["pattern"])
        assert row["disposition"] in allowed, f"unknown disposition: {row['disposition']}"
        assert row["reason"], f"missing reason for {row['pattern']}"
        evidence = project_root / row["evidence"]
        assert evidence.exists(), f"missing evidence for {row['pattern']}: {evidence}"
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=pathlib.Path, default=None)
    parser.add_argument("--upstream-root", type=pathlib.Path, default=None)
    parser.add_argument("--dispositions", type=pathlib.Path, default=None)
    parser.add_argument("--output", type=pathlib.Path, default=None)
    arguments = parser.parse_args()

    project_root = (arguments.project_root or pathlib.Path(__file__).resolve().parent.parent).resolve()
    upstream_root = (arguments.upstream_root or project_root / ".work/modular").resolve()
    disposition_path = (
        arguments.dispositions
        or project_root / "config/runtime-abi-dispositions.tsv"
    ).resolve()
    output_path = (
        arguments.output or project_root / "build/runtime-abi-census.tsv"
    ).resolve()

    compiler_rt_root = upstream_root / "KGEN/lib/CompilerRT"
    compiler_rt_contract_paths = sorted(compiler_rt_root.glob("*.cpp"))
    compiler_rt_contract_paths.append(compiler_rt_root / "Memory.h")
    kgen_contract = defined_symbols(compiler_rt_contract_paths, KGEN_SYMBOL)

    device_header = upstream_root / "AsyncRT/include/AsyncRT/Runtime/DeviceContextCAPI.h"
    device_contract = mentioned_symbols([device_header], DEVICE_SYMBOL)
    contract = kgen_contract | device_contract
    assert kgen_contract, "empty CompilerRT contract"
    assert device_contract, "empty DeviceContext contract"

    apple_paths = [
        upstream_root / "KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c",
        upstream_root / "KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c",
        upstream_root / "KGEN/lib/CompilerRT/Embedded/Globals.c",
        upstream_root / "AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c",
        upstream_root / "AsyncRT/lib/Runtime/Apple/MetalDeviceContextCAPI.m",
    ]
    implemented = defined_symbols(apple_paths, KGEN_SYMBOL) | defined_symbols(
        apple_paths, DEVICE_SYMBOL
    )
    unexpected_implementations = implemented - contract
    assert not unexpected_implementations, (
        "Apple runtime exports absent from pinned ABI contract: "
        + ", ".join(sorted(unexpected_implementations))
    )

    reference_roots = [
        upstream_root / "KGEN",
        upstream_root / "mojo",
        upstream_root / "max/mojo",
        upstream_root / "max/kernels/src",
    ]
    referenced: set[str] = set()
    for reference_root in reference_roots:
        for path in reference_root.rglob("*"):
            if not path.is_file() or path.suffix not in {".c", ".cpp", ".h", ".td", ".mojo"}:
                continue
            if compiler_rt_root in path.parents:
                continue
            try:
                referenced.update(REFERENCE_SYMBOL.findall(path.read_text(encoding="utf-8")))
            except UnicodeDecodeError:
                continue
    referenced &= kgen_contract

    dispositions = load_dispositions(disposition_path, project_root)
    semantic_test_paths = [
        project_root / "Tests/EmbeddedCompilerRTTests.c",
        project_root / "Tests/MojoIOSAsyncRTTests.c",
    ]
    semantic_test_sources = {
        path: read_text(path) for path in semantic_test_paths
    }
    metal_gate = project_root / "docs/METAL_FEASIBILITY_GATE.md"
    assert metal_gate.is_file(), f"missing Metal semantic gate: {metal_gate}"

    classified_rows: list[tuple[str, str, str, str, str, str]] = []
    matched_patterns: set[str] = set()
    for symbol_name in sorted(contract):
        surface = "CompilerRT" if symbol_name.startswith("KGEN_") else "DeviceContext"
        if symbol_name in implemented:
            disposition = "implemented"
            reason = "normal embedded Apple ABI implementation"
            implementation_evidence = next(
                str(path.relative_to(project_root))
                for path in apple_paths
                if symbol_name
                in defined_symbols(
                    [path], KGEN_SYMBOL if surface == "CompilerRT" else DEVICE_SYMBOL
                )
            )
            semantic_matches = [
                str(path.relative_to(project_root))
                for path, source in semantic_test_sources.items()
                if symbol_name in source
            ]
            if symbol_name in METAL_SEMANTIC_SYMBOLS:
                semantic_matches.append(str(metal_gate.relative_to(project_root)))
            assert len(semantic_matches) == 1, (
                f"{symbol_name} has {len(semantic_matches)} semantic evidence sources; "
                "expected exactly one"
            )
            semantic_evidence = semantic_matches[0]
        else:
            matches = [row for row in dispositions if fnmatch.fnmatchcase(symbol_name, row["pattern"])]
            assert len(matches) == 1, (
                f"{symbol_name} has {len(matches)} explicit dispositions; expected exactly one"
            )
            match = matches[0]
            matched_patterns.add(match["pattern"])
            disposition = match["disposition"]
            reason = match["reason"]
            implementation_evidence = ""
            semantic_evidence = match["evidence"]
        if symbol_name in referenced:
            reason += "; referenced by pinned compiler/library sources"
        classified_rows.append(
            (
                symbol_name,
                surface,
                disposition,
                reason,
                implementation_evidence,
                semantic_evidence,
            )
        )

    unused_patterns = {row["pattern"] for row in dispositions} - matched_patterns
    assert not unused_patterns, "disposition patterns match no ABI symbol: " + ", ".join(sorted(unused_patterns))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(
            (
                "symbol",
                "surface",
                "disposition",
                "reason",
                "implementation_evidence",
                "semantic_evidence",
            )
        )
        writer.writerows(classified_rows)

    disposition_counts: dict[str, int] = {}
    for _, _, disposition, _, _, _ in classified_rows:
        disposition_counts[disposition] = disposition_counts.get(disposition, 0) + 1
    count_text = " ".join(
        f"{name}={count}" for name, count in sorted(disposition_counts.items())
    )
    print(
        f"RUNTIME_ABI_CENSUS_PASS total={len(contract)} "
        f"compilerrt={len(kgen_contract)} device_context={len(device_contract)} {count_text}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"RUNTIME_ABI_CENSUS_FAIL {error}", file=sys.stderr)
        raise SystemExit(1)
