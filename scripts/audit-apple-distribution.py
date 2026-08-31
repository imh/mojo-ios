#!/usr/bin/env python3
"""Inventory and enforce explicit distribution policy for Apple artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import re
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple

PROJECT_ROOT = Path(__file__).resolve().parents[1]
MACH_O_MAGICS = {
    b"\xce\xfa\xed\xfe",
    b"\xcf\xfa\xed\xfe",
    b"\xfe\xed\xfa\xce",
    b"\xfe\xed\xfa\xcf",
    b"\xca\xfe\xba\xbe",
    b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf",
    b"\xbf\xba\xfe\xca",
}
AR_MAGIC = b"!<arch>\n"

FORBIDDEN_SOURCE_SUFFIXES = {
    ".mojo",
    ".mojopkg",
    ".mojoc",
    ".py",
    ".pyc",
    ".pyo",
}
UNDECLARED_ACCELERATOR_SUFFIXES = {
    ".air",
    ".aimodel",
    ".aimodelc",
    ".metallib",
}
FORBIDDEN_PATH_COMPONENT_PATTERNS = [
    re.compile(r"^__pycache__$", re.IGNORECASE),
    re.compile(r"^(compiler|module)[-_]?cache$", re.IGNORECASE),
    re.compile(r"^(?:mojo|modular)[-_]?cache$", re.IGNORECASE),
    re.compile(r"^lib(?:llvm|clang|mojocompiler|mojojit|python)", re.IGNORECASE),
    re.compile(r"^libkgen(?!compilerrt)", re.IGNORECASE),
    re.compile(r"^(?:mojo|modular)[-_]?compiler", re.IGNORECASE),
    re.compile(r"^mojo(?:\.exe)?$", re.IGNORECASE),
    re.compile(r"^Python\.framework$", re.IGNORECASE),
    re.compile(r"(?:mcjit|orcjit|executionengine)", re.IGNORECASE),
]

SYMBOL_POLICIES = [
    (
        "test_runtime_symbol",
        re.compile(r"AsyncRT_Test_|(?:^|_)ASYNCRT_ENABLE_TESTING(?:$|_)"),
        "test-only runtime control",
    ),
    (
        "project_coreai_symbol",
        re.compile(
            r"AsyncRT_CoreAI_|mojo_ios_coreai_|__mojo_coreai_semantic_",
            re.IGNORECASE,
        ),
        "project-specific Core AI ABI",
    ),
    (
        "private_ane_symbol",
        re.compile(
            r"ANECompiler|AppleNeuralEngine|(?:^|_)Espresso(?:$|_)|"
            r"(?:^|_)aned(?:$|_)",
            re.IGNORECASE,
        ),
        "private ANE runtime or compiler interface",
    ),
    (
        "compiler_jit_symbol",
        re.compile(
            r"LLVM.*(?:ExecutionEngine|MCJIT|OrcJIT|LLJIT)|"
            r"pthread_jit_write_protect|NSCreateObjectFileImageFromMemory|MAP_JIT",
            re.IGNORECASE,
        ),
        "compiler or JIT interface",
    ),
    (
        "python_runtime_symbol",
        re.compile(r"(?:^|_)Py(?:_|[A-Z])|Py_Initialize|Python", re.IGNORECASE),
        "Python runtime interface",
    ),
    (
        "dynamic_loading_symbol",
        re.compile(r"(?:^|_)dlopen$|(?:^|_)dlsym$|(?:^|_)NSLinkModule$"),
        "arbitrary dynamic-loading interface",
    ),
]

ALLOWED_POLICY_KEYS = {
    "allowed_dependencies",
    "artifact_kind",
    "declared_accelerator_artifacts",
    "expected_artifact_name",
    "expected_slices",
    "lane",
    "require_signature",
    "schema_version",
}
ALLOWED_SLICE_KEYS = {
    "architectures",
    "binary_type",
    "identifier",
    "minimum_os",
    "platform",
}


class AuditError(Exception):
    pass


@dataclass(frozen=True)
class Violation:
    code: str
    subject: str
    detail: str

    def as_json(self) -> Dict[str, str]:
        return {
            "code": self.code,
            "detail": self.detail,
            "subject": self.subject,
        }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--policy", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--provenance",
        action="append",
        default=[],
        metavar="KEY=VALUE",
        help="Add an explicit compatibility-tuple field",
    )
    return parser.parse_args()


def run_tool(
    arguments: Sequence[str],
    *,
    check: bool = True,
    combine_output: bool = False,
) -> subprocess.CompletedProcess[str]:
    environment = dict(os.environ)
    environment["LC_ALL"] = "C"
    completed = subprocess.run(
        list(arguments),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT if combine_output else subprocess.PIPE,
        text=True,
        env=environment,
    )
    if check and completed.returncode != 0:
        diagnostic = completed.stdout if combine_output else completed.stderr
        raise AuditError(
            f"command failed ({completed.returncode}): {' '.join(arguments)}: "
            f"{diagnostic.strip()}"
        )
    return completed


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as input_file:
        while True:
            chunk = input_file.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def repository_relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return path.name


def load_policy(path: Path) -> Dict[str, Any]:
    try:
        policy = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise AuditError(f"cannot read policy {path}: {error}") from error
    if not isinstance(policy, dict):
        raise AuditError("distribution policy must be a JSON object")
    unknown_keys = sorted(set(policy) - ALLOWED_POLICY_KEYS)
    if unknown_keys:
        raise AuditError(f"unknown distribution policy keys: {unknown_keys}")
    if policy.get("schema_version") != 1:
        raise AuditError("distribution policy schema_version must be 1")
    if policy.get("artifact_kind") not in {"xcframework", "xcarchive"}:
        raise AuditError("artifact_kind must be xcframework or xcarchive")
    if not isinstance(policy.get("expected_artifact_name"), str):
        raise AuditError("expected_artifact_name must be recorded")
    if not isinstance(policy.get("lane"), str):
        raise AuditError("lane must be recorded")
    if not isinstance(policy.get("require_signature"), bool):
        raise AuditError("require_signature must be true or false")
    for list_key in ("allowed_dependencies", "declared_accelerator_artifacts"):
        if not isinstance(policy.get(list_key), list) or not all(
            isinstance(value, str) for value in policy[list_key]
        ):
            raise AuditError(f"{list_key} must be a list of strings")
        if len(policy[list_key]) != len(set(policy[list_key])):
            raise AuditError(f"{list_key} must not contain duplicates")
    expected_slices = policy.get("expected_slices", [])
    if not isinstance(expected_slices, list):
        raise AuditError("expected_slices must be a list")
    for slice_policy in expected_slices:
        if not isinstance(slice_policy, dict):
            raise AuditError("every expected slice must be an object")
        unknown_slice_keys = sorted(set(slice_policy) - ALLOWED_SLICE_KEYS)
        if unknown_slice_keys:
            raise AuditError(f"unknown expected-slice keys: {unknown_slice_keys}")
        if set(slice_policy) != ALLOWED_SLICE_KEYS:
            missing = sorted(ALLOWED_SLICE_KEYS - set(slice_policy))
            raise AuditError(f"expected slice is missing keys: {missing}")
        if slice_policy["binary_type"] not in {"static_archive", "mach_o"}:
            raise AuditError("slice binary_type must be static_archive or mach_o")
        if not isinstance(slice_policy["architectures"], list) or not all(
            isinstance(value, str) for value in slice_policy["architectures"]
        ):
            raise AuditError("slice architectures must be a list of strings")
    identifiers = [slice_policy["identifier"] for slice_policy in expected_slices]
    if len(identifiers) != len(set(identifiers)):
        raise AuditError("expected slice identifiers must be unique")
    if policy["artifact_kind"] == "xcframework" and not expected_slices:
        raise AuditError("xcframework policy requires expected_slices")
    return policy


def parse_provenance(values: Iterable[str]) -> Dict[str, str]:
    provenance: Dict[str, str] = {}
    for value in values:
        if "=" not in value:
            raise AuditError(f"provenance must use KEY=VALUE: {value}")
        key, field_value = value.split("=", 1)
        if not key or not field_value:
            raise AuditError(f"provenance must use nonempty KEY=VALUE: {value}")
        if key in provenance:
            raise AuditError(f"duplicate provenance key: {key}")
        provenance[key] = field_value
    return dict(sorted(provenance.items()))


def enumerate_artifact_entries(
    artifact_root: Path,
) -> Tuple[List[Dict[str, Any]], List[str]]:
    file_records: List[Dict[str, Any]] = []
    all_relative_entries: List[str] = []
    for current_root, directory_names, file_names in os.walk(
        artifact_root, topdown=True, followlinks=False
    ):
        directory_names.sort()
        file_names.sort()
        current_path = Path(current_root)
        for directory_name in directory_names:
            directory_path = current_path / directory_name
            relative_path = directory_path.relative_to(artifact_root).as_posix()
            all_relative_entries.append(relative_path)
            if directory_path.is_symlink():
                file_names.append(directory_name)
        for file_name in sorted(set(file_names)):
            file_path = current_path / file_name
            relative_path = file_path.relative_to(artifact_root).as_posix()
            all_relative_entries.append(relative_path)
            file_status = file_path.lstat()
            mode = f"{stat.S_IMODE(file_status.st_mode):04o}"
            if file_path.is_symlink():
                link_target = os.readlink(file_path)
                file_records.append(
                    {
                        "kind": "symlink",
                        "link_target": link_target,
                        "mode": mode,
                        "path": relative_path,
                        "sha256": sha256_bytes(link_target.encode("utf-8")),
                        "size": len(link_target.encode("utf-8")),
                    }
                )
            elif file_path.is_file():
                file_type = run_tool(["file", "-b", str(file_path)]).stdout.strip()
                file_records.append(
                    {
                        "kind": "file",
                        "mode": mode,
                        "path": relative_path,
                        "sha256": sha256_file(file_path),
                        "size": file_status.st_size,
                        "type": file_type,
                    }
                )
            else:
                raise AuditError(f"unsupported filesystem entry: {relative_path}")
    file_records.sort(key=lambda record: record["path"])
    return file_records, sorted(set(all_relative_entries))


def parse_static_archive(path: Path) -> List[Dict[str, Any]]:
    archive_data = path.read_bytes()
    if not archive_data.startswith(AR_MAGIC):
        raise AuditError(f"not a static archive: {path}")
    offset = len(AR_MAGIC)
    member_index = 0
    members: List[Dict[str, Any]] = []
    while offset < len(archive_data):
        if offset + 60 > len(archive_data):
            raise AuditError(f"truncated archive header in {path} at offset {offset}")
        header = archive_data[offset : offset + 60]
        if header[58:60] != b"`\n":
            raise AuditError(f"invalid archive header in {path} at offset {offset}")
        raw_name = header[0:16].decode("ascii", errors="strict").rstrip()
        try:
            stored_size = int(header[48:58].decode("ascii").strip())
        except ValueError as error:
            raise AuditError(f"invalid archive member size in {path}") from error
        payload_start = offset + 60
        payload_end = payload_start + stored_size
        if payload_end > len(archive_data):
            raise AuditError(f"truncated archive member in {path}: {raw_name}")
        payload = archive_data[payload_start:payload_end]
        if raw_name.startswith("#1/"):
            try:
                name_length = int(raw_name[3:])
            except ValueError as error:
                raise AuditError(f"invalid BSD archive name in {path}") from error
            if name_length > len(payload):
                raise AuditError(f"truncated BSD archive name in {path}")
            member_name = (
                payload[:name_length].rstrip(b"\0").decode("utf-8", errors="strict")
            )
            member_data = payload[name_length:]
        else:
            member_name = raw_name.rstrip("/")
            member_data = payload
        is_symbol_table = member_name in {"", "/", "//"} or member_name.startswith(
            "__.SYMDEF"
        )
        members.append(
            {
                "data": member_data,
                "index": member_index,
                "name": member_name,
                "sha256": sha256_bytes(member_data),
                "size": len(member_data),
                "symbol_table": is_symbol_table,
            }
        )
        member_index += 1
        offset = payload_end + (stored_size % 2)
    if offset != len(archive_data):
        raise AuditError(f"invalid archive alignment in {path}")
    return members


def is_mach_o_data(data: bytes) -> bool:
    return len(data) >= 4 and data[:4] in MACH_O_MAGICS


def architectures_for(path: Path) -> List[str]:
    output = run_tool(["xcrun", "lipo", "-archs", str(path)]).stdout.strip()
    return sorted(output.split())


def parse_build_versions(path: Path) -> List[Dict[str, str]]:
    output = run_tool(["xcrun", "vtool", "-show-build", str(path)]).stdout
    versions: List[Dict[str, str]] = []
    current: Optional[Dict[str, str]] = None
    for line in output.splitlines():
        platform_match = re.match(r"\s*platform\s+(\S+)\s*$", line)
        if platform_match:
            if current is not None:
                versions.append(current)
            current = {"platform": platform_match.group(1)}
            continue
        minimum_match = re.match(r"\s*minos\s+(\S+)\s*$", line)
        if minimum_match and current is not None:
            current["minimum_os"] = minimum_match.group(1)
            continue
        sdk_match = re.match(r"\s*sdk\s+(\S+)\s*$", line)
        if sdk_match and current is not None:
            current["sdk"] = sdk_match.group(1)
    if current is not None:
        versions.append(current)
    return versions


def parse_load_commands(path: Path) -> List[str]:
    output = run_tool(["xcrun", "otool", "-l", str(path)]).stdout
    commands = {
        match.group(1)
        for line in output.splitlines()
        if (match := re.match(r"\s*cmd\s+(LC_[A-Z0-9_]+)\s*$", line))
    }
    return sorted(commands)


def parse_dependencies(path: Path) -> List[str]:
    output = run_tool(["xcrun", "otool", "-L", str(path)]).stdout
    dependencies: Set[str] = set()
    for line_number, line in enumerate(output.splitlines()):
        if line_number == 0 or not line.startswith(("\t", " ")):
            continue
        dependency_match = re.match(r"\s*(\S+)\s+\(compatibility version", line)
        if dependency_match:
            dependencies.add(dependency_match.group(1))
    install_name_output = run_tool(
        ["xcrun", "otool", "-D", str(path)], check=False
    ).stdout
    install_names = {
        line.strip()
        for line_number, line in enumerate(install_name_output.splitlines())
        if line_number > 0 and line.strip()
    }
    dependencies -= install_names
    return sorted(dependencies)


def parse_symbols(path: Path, arguments: Sequence[str]) -> List[str]:
    completed = run_tool(["xcrun", "nm", *arguments, "-j", str(path)], check=False)
    if completed.returncode not in {0, 1}:
        raise AuditError(f"nm failed for {path}: {completed.stderr.strip()}")
    return sorted(
        {
            line.strip()
            for line in completed.stdout.splitlines()
            if line.strip() and not line.rstrip().endswith(":")
        }
    )


def inspect_signing(path: Path) -> Dict[str, Any]:
    completed = run_tool(
        ["codesign", "-d", "--verbose=4", str(path)],
        check=False,
        combine_output=True,
    )
    if completed.returncode != 0:
        return {"signed": False}
    signing: Dict[str, Any] = {"signed": True}
    for line in completed.stdout.splitlines():
        for field_name, output_name in (
            ("Identifier", "identifier"),
            ("TeamIdentifier", "team_identifier"),
            ("Authority", "authority"),
            ("CDHash", "cdhash"),
        ):
            prefix = f"{field_name}="
            if line.startswith(prefix):
                value = line[len(prefix) :]
                if output_name == "authority":
                    signing.setdefault("authorities", []).append(value)
                else:
                    signing[output_name] = value
    entitlement_result = run_tool(
        ["codesign", "-d", "--entitlements", ":-", str(path)],
        check=False,
    )
    if entitlement_result.returncode == 0 and entitlement_result.stdout.strip():
        try:
            entitlements = plistlib.loads(entitlement_result.stdout.encode("utf-8"))
            signing["entitlements"] = entitlements
        except plistlib.InvalidFileException as error:
            raise AuditError(
                f"cannot parse entitlements for {path}: {error}"
            ) from error
    return signing


def inspect_mach_o(
    path: Path,
    *,
    subject: str,
    content_sha256: str,
    container_path: str,
    archive_member: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    file_type = run_tool(["file", "-b", str(path)]).stdout.strip()
    signing: Dict[str, Any] = {"signed": False}
    if archive_member is None and "object" not in file_type.lower():
        signing = inspect_signing(path)
    return {
        "architectures": architectures_for(path),
        "archive_member": archive_member,
        "build_versions": parse_build_versions(path),
        "container_path": container_path,
        "dependencies": parse_dependencies(path),
        "exported_symbols": parse_symbols(path, ["-gU"]),
        "load_commands": parse_load_commands(path),
        "sha256": content_sha256,
        "signing": signing,
        "subject": subject,
        "type": file_type,
        "undefined_symbols": parse_symbols(path, ["-u"]),
    }


def scan_binary_files(
    artifact_root: Path,
    file_records: List[Dict[str, Any]],
    temporary_root: Path,
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    static_archives: List[Dict[str, Any]] = []
    mach_o_images: List[Dict[str, Any]] = []
    for file_record in file_records:
        if file_record["kind"] != "file":
            continue
        relative_path = file_record["path"]
        file_path = artifact_root / relative_path
        with file_path.open("rb") as binary_file:
            magic = binary_file.read(8)
        if magic.startswith(AR_MAGIC):
            members = parse_static_archive(file_path)
            member_reports: List[Dict[str, Any]] = []
            for member in members:
                public_member = {
                    key: value for key, value in member.items() if key != "data"
                }
                member_reports.append(public_member)
                if member["symbol_table"] or not is_mach_o_data(member["data"]):
                    continue
                member_path = (
                    temporary_root / f"archive-member-{len(mach_o_images):04d}.o"
                )
                member_path.write_bytes(member["data"])
                member_subject = (
                    f"{relative_path}(member[{member['index']}]:{member['name']})"
                )
                mach_o_images.append(
                    inspect_mach_o(
                        member_path,
                        subject=member_subject,
                        content_sha256=member["sha256"],
                        container_path=relative_path,
                        archive_member={
                            "index": member["index"],
                            "name": member["name"],
                        },
                    )
                )
            static_archives.append(
                {
                    "architectures": architectures_for(file_path),
                    "members": member_reports,
                    "path": relative_path,
                    "sha256": file_record["sha256"],
                }
            )
        elif magic[:4] in MACH_O_MAGICS:
            mach_o_images.append(
                inspect_mach_o(
                    file_path,
                    subject=relative_path,
                    content_sha256=file_record["sha256"],
                    container_path=relative_path,
                    archive_member=None,
                )
            )
    static_archives.sort(key=lambda archive: archive["path"])
    mach_o_images.sort(key=lambda image: image["subject"])
    return static_archives, mach_o_images


def add_violation(
    violations: List[Violation], code: str, subject: str, detail: str
) -> None:
    violations.append(Violation(code=code, subject=subject, detail=detail))


def audit_paths(
    artifact_root: Path,
    all_entries: Iterable[str],
    file_records: Iterable[Dict[str, Any]],
    policy: Dict[str, Any],
    violations: List[Violation],
) -> None:
    declared_accelerator_paths = set(policy["declared_accelerator_artifacts"])
    for relative_path in all_entries:
        path = Path(relative_path)
        suffix = path.suffix.casefold()
        if suffix in FORBIDDEN_SOURCE_SUFFIXES:
            add_violation(
                violations,
                "forbidden_source_or_python_path",
                relative_path,
                f"forbidden shipped suffix {suffix}",
            )
        if suffix in UNDECLARED_ACCELERATOR_SUFFIXES and relative_path not in (
            declared_accelerator_paths
        ):
            add_violation(
                violations,
                "undeclared_accelerator_artifact",
                relative_path,
                "accelerator artifact is not declared by distribution policy",
            )
        for component in path.parts:
            for component_pattern in FORBIDDEN_PATH_COMPONENT_PATTERNS:
                if component_pattern.search(component):
                    add_violation(
                        violations,
                        "forbidden_compiler_or_cache_path",
                        relative_path,
                        f"forbidden path component {component}",
                    )
    for declared_path in sorted(declared_accelerator_paths):
        if not (artifact_root / declared_path).exists():
            add_violation(
                violations,
                "missing_declared_accelerator_artifact",
                declared_path,
                "declared accelerator artifact is missing",
            )
    resolved_artifact_root = artifact_root.resolve()
    for file_record in file_records:
        if file_record["kind"] != "symlink":
            continue
        symlink_path = artifact_root / file_record["path"]
        resolved_target = (symlink_path.parent / file_record["link_target"]).resolve()
        try:
            resolved_target.relative_to(resolved_artifact_root)
        except ValueError:
            add_violation(
                violations,
                "external_symlink",
                file_record["path"],
                f"symlink escapes artifact root: {file_record['link_target']}",
            )
        if not resolved_target.exists():
            add_violation(
                violations,
                "broken_symlink",
                file_record["path"],
                f"symlink target does not exist: {file_record['link_target']}",
            )


def dependency_is_allowed(dependency: str, allowed_dependencies: Sequence[str]) -> bool:
    return any(
        dependency == allowed or dependency.startswith(f"{allowed}/")
        for allowed in allowed_dependencies
    )


def audit_mach_o_policy(
    mach_o_images: List[Dict[str, Any]],
    policy: Dict[str, Any],
    allowed_direct_mach_o_paths: Set[str],
    violations: List[Violation],
) -> None:
    for image in mach_o_images:
        subject = image["subject"]
        if image["archive_member"] is None and image["container_path"] not in (
            allowed_direct_mach_o_paths
        ):
            add_violation(
                violations,
                "unexpected_mach_o",
                subject,
                "Mach-O image is not declared by the package structure",
            )
        symbols = sorted(
            set(image["exported_symbols"]) | set(image["undefined_symbols"])
        )
        for symbol in symbols:
            for code, pattern, policy_name in SYMBOL_POLICIES:
                if pattern.search(symbol):
                    add_violation(
                        violations,
                        code,
                        subject,
                        f"{policy_name}: {symbol}",
                    )
        for dependency in image["dependencies"]:
            if "/PrivateFrameworks/" in dependency:
                add_violation(
                    violations,
                    "private_framework_dependency",
                    subject,
                    f"private framework dependency: {dependency}",
                )
            elif not dependency_is_allowed(dependency, policy["allowed_dependencies"]):
                add_violation(
                    violations,
                    "unexpected_dependency",
                    subject,
                    f"dependency is not allowed by policy: {dependency}",
                )


def normalized_version(version: str) -> Tuple[int, ...]:
    try:
        components = [int(component) for component in version.split(".")]
    except ValueError as error:
        raise AuditError(f"invalid Apple version: {version}") from error
    while components and components[-1] == 0:
        components.pop()
    return tuple(components)


def validate_image_target(
    image: Dict[str, Any],
    expected_slice: Dict[str, Any],
    violations: List[Violation],
) -> None:
    subject = image["subject"]
    if image["architectures"] != sorted(expected_slice["architectures"]):
        add_violation(
            violations,
            "wrong_architecture",
            subject,
            f"expected {sorted(expected_slice['architectures'])}, got "
            f"{image['architectures']}",
        )
    if not image["build_versions"]:
        add_violation(
            violations,
            "missing_build_version",
            subject,
            "Mach-O image has no LC_BUILD_VERSION",
        )
        return
    for build_version in image["build_versions"]:
        actual_platform = build_version.get("platform", "not recorded")
        if actual_platform != expected_slice["platform"]:
            add_violation(
                violations,
                "wrong_platform",
                subject,
                f"expected {expected_slice['platform']}, got {actual_platform}",
            )
        actual_minimum = build_version.get("minimum_os")
        if actual_minimum is None or normalized_version(actual_minimum) != (
            normalized_version(expected_slice["minimum_os"])
        ):
            add_violation(
                violations,
                "wrong_minimum_os",
                subject,
                f"expected {expected_slice['minimum_os']}, got "
                f"{actual_minimum or 'not recorded'}",
            )


def xcframework_platform(library: Dict[str, Any]) -> str:
    platform = str(library.get("SupportedPlatform", "")).lower()
    variant = str(library.get("SupportedPlatformVariant", "")).lower()
    if platform == "ios" and not variant:
        return "IOS"
    if platform == "ios" and variant == "simulator":
        return "IOSSIMULATOR"
    return f"{platform.upper()}:{variant.upper()}" if variant else platform.upper()


def audit_xcframework_structure(
    artifact_root: Path,
    policy: Dict[str, Any],
    static_archives: List[Dict[str, Any]],
    mach_o_images: List[Dict[str, Any]],
    violations: List[Violation],
) -> Set[str]:
    info_path = artifact_root / "Info.plist"
    if not info_path.is_file():
        add_violation(
            violations, "missing_xcframework_info", "Info.plist", "file is missing"
        )
        return set()
    try:
        info = plistlib.loads(info_path.read_bytes())
    except plistlib.InvalidFileException as error:
        raise AuditError(f"cannot parse XCFramework Info.plist: {error}") from error
    available_libraries = info.get("AvailableLibraries")
    if not isinstance(available_libraries, list):
        raise AuditError("XCFramework AvailableLibraries must be a list")
    actual_by_identifier: Dict[str, Dict[str, Any]] = {}
    for library in available_libraries:
        if not isinstance(library, dict) or not isinstance(
            library.get("LibraryIdentifier"), str
        ):
            raise AuditError("every XCFramework library needs LibraryIdentifier")
        identifier = library["LibraryIdentifier"]
        if identifier in actual_by_identifier:
            raise AuditError(f"duplicate XCFramework library identifier: {identifier}")
        actual_by_identifier[identifier] = library

    expected_by_identifier = {
        expected_slice["identifier"]: expected_slice
        for expected_slice in policy["expected_slices"]
    }
    for identifier in sorted(set(expected_by_identifier) - set(actual_by_identifier)):
        add_violation(
            violations,
            "missing_slice",
            identifier,
            "expected XCFramework slice is missing",
        )
    for identifier in sorted(set(actual_by_identifier) - set(expected_by_identifier)):
        add_violation(
            violations,
            "unexpected_slice",
            identifier,
            "XCFramework Info.plist declares an unexpected slice",
        )
    top_level_directories = {
        child.name for child in artifact_root.iterdir() if child.is_dir()
    }
    for identifier in sorted(top_level_directories - set(expected_by_identifier)):
        add_violation(
            violations,
            "unexpected_slice_directory",
            identifier,
            "XCFramework contains an undeclared top-level slice directory",
        )

    archives_by_path = {archive["path"]: archive for archive in static_archives}
    images_by_container: Dict[str, List[Dict[str, Any]]] = {}
    for image in mach_o_images:
        images_by_container.setdefault(image["container_path"], []).append(image)
    allowed_direct_mach_o_paths: Set[str] = set()

    for identifier, expected_slice in sorted(expected_by_identifier.items()):
        actual_library = actual_by_identifier.get(identifier)
        if actual_library is None:
            continue
        actual_architectures = sorted(actual_library.get("SupportedArchitectures", []))
        if actual_architectures != sorted(expected_slice["architectures"]):
            add_violation(
                violations,
                "wrong_slice_architectures",
                identifier,
                f"expected {sorted(expected_slice['architectures'])}, got "
                f"{actual_architectures}",
            )
        actual_platform = xcframework_platform(actual_library)
        if actual_platform != expected_slice["platform"]:
            add_violation(
                violations,
                "wrong_slice_platform",
                identifier,
                f"expected {expected_slice['platform']}, got {actual_platform}",
            )
        binary_name = actual_library.get("BinaryPath") or actual_library.get(
            "LibraryPath"
        )
        if not isinstance(binary_name, str):
            raise AuditError(f"XCFramework slice {identifier} has no binary path")
        binary_relative_path = f"{identifier}/{binary_name}"
        binary_path = artifact_root / binary_relative_path
        if not binary_path.is_file():
            add_violation(
                violations,
                "missing_slice_binary",
                binary_relative_path,
                "slice binary is missing",
            )
            continue
        if expected_slice["binary_type"] == "static_archive":
            archive = archives_by_path.get(binary_relative_path)
            if archive is None:
                add_violation(
                    violations,
                    "wrong_slice_binary_type",
                    binary_relative_path,
                    "expected a static archive",
                )
                continue
            if archive["architectures"] != sorted(expected_slice["architectures"]):
                add_violation(
                    violations,
                    "wrong_archive_architectures",
                    binary_relative_path,
                    f"expected {sorted(expected_slice['architectures'])}, got "
                    f"{archive['architectures']}",
                )
            slice_images = images_by_container.get(binary_relative_path, [])
            if not slice_images:
                add_violation(
                    violations,
                    "empty_slice_archive",
                    binary_relative_path,
                    "static archive contains no Mach-O members",
                )
            for image in slice_images:
                validate_image_target(image, expected_slice, violations)
        else:
            allowed_direct_mach_o_paths.add(binary_relative_path)
            slice_images = images_by_container.get(binary_relative_path, [])
            if len(slice_images) != 1:
                add_violation(
                    violations,
                    "wrong_slice_binary_type",
                    binary_relative_path,
                    "expected exactly one Mach-O slice binary",
                )
            else:
                validate_image_target(slice_images[0], expected_slice, violations)
    return allowed_direct_mach_o_paths


def audit_xcarchive_structure(
    artifact_root: Path,
    mach_o_images: List[Dict[str, Any]],
    violations: List[Violation],
) -> Set[str]:
    applications_root = artifact_root / "Products" / "Applications"
    app_bundles = sorted(applications_root.glob("*.app")) if applications_root else []
    if len(app_bundles) != 1:
        add_violation(
            violations,
            "invalid_application_count",
            "Products/Applications",
            f"expected one application bundle, found {len(app_bundles)}",
        )
    return {
        image["container_path"]
        for image in mach_o_images
        if image["archive_member"] is None
        and image["container_path"].startswith("Products/Applications/")
    }


def artifact_signing(artifact_root: Path) -> Dict[str, Any]:
    return inspect_signing(artifact_root)


def toolchain_tuple(policy_path: Path) -> Dict[str, Any]:
    project_revision = run_tool(
        ["git", "-C", str(PROJECT_ROOT), "rev-parse", "HEAD"]
    ).stdout.strip()
    project_status = run_tool(
        [
            "git",
            "-C",
            str(PROJECT_ROOT),
            "status",
            "--porcelain=v1",
            "--untracked-files=normal",
        ]
    ).stdout.splitlines()
    upstream_revision_path = PROJECT_ROOT / "upstream" / "REVISION"
    declared_upstream_revision = (
        upstream_revision_path.read_text(encoding="utf-8").strip()
        if upstream_revision_path.is_file()
        else "not recorded yet"
    )
    upstream_checkout = PROJECT_ROOT / ".work" / "modular"
    checkout_revision = "not recorded yet"
    if (upstream_checkout / ".git").is_dir():
        checkout_revision = run_tool(
            ["git", "-C", str(upstream_checkout), "rev-parse", "HEAD"]
        ).stdout.strip()
    patch_records = [
        {
            "path": repository_relative(patch_path),
            "sha256": sha256_file(patch_path),
        }
        for patch_path in sorted((PROJECT_ROOT / "patches" / "modular").glob("*.patch"))
    ]
    compiler_path = (
        PROJECT_ROOT
        / ".work"
        / "modular"
        / "bazel-bin"
        / "KGEN"
        / "tools"
        / "mojo"
        / "mojo"
    )
    compiler_sha256 = (
        sha256_file(compiler_path) if compiler_path.is_file() else "not recorded yet"
    )
    metal_component_result = run_tool(
        ["xcodebuild", "-showComponent", "MetalToolchain", "-json"],
        check=False,
        combine_output=True,
    )
    metal_toolchain: Dict[str, Any]
    if metal_component_result.returncode == 0:
        try:
            metal_component = json.loads(metal_component_result.stdout)
        except json.JSONDecodeError as error:
            raise AuditError(
                "xcodebuild returned invalid MetalToolchain component JSON"
            ) from error
        required_metal_component_fields = (
            "buildVersion",
            "status",
            "toolchainIdentifier",
            "toolchainSearchPath",
        )
        missing_metal_component_fields = [
            field
            for field in required_metal_component_fields
            if not isinstance(metal_component.get(field), str)
            or not metal_component[field]
        ]
        if missing_metal_component_fields:
            raise AuditError(
                "MetalToolchain component metadata is missing: "
                + ", ".join(missing_metal_component_fields)
            )
        metal_compiler_path = (
            Path(metal_component["toolchainSearchPath"])
            / "Metal.xctoolchain"
            / "usr"
            / "bin"
            / "metal"
        )
        metal_compiler_result = run_tool(
            [str(metal_compiler_path), "--version"],
            check=False,
            combine_output=True,
        )
        metal_toolchain = {
            "build_version": metal_component["buildVersion"],
            "compiler_probe_exit_code": metal_compiler_result.returncode,
            "compiler_version": (
                metal_compiler_result.stdout.splitlines()[0]
                if metal_compiler_result.returncode == 0
                and metal_compiler_result.stdout.splitlines()
                else "not recorded yet"
            ),
            "component_query": "succeeded",
            "status": metal_component["status"],
            "toolchain_identifier": metal_component["toolchainIdentifier"],
        }
    else:
        # A component-query failure is not evidence that Metal is absent. For
        # example, xcodebuild cannot access its component registry in some
        # sandboxed environments. Preserve the observation without inferring
        # toolchain availability from it.
        metal_toolchain = {
            "build_version": "not recorded yet",
            "compiler_probe_exit_code": "not recorded yet",
            "compiler_version": "not recorded yet",
            "component_query": "failed",
            "status": "not recorded yet",
            "toolchain_identifier": "not recorded yet",
        }
    return {
        "apple_clang": run_tool(["xcrun", "clang", "--version"]).stdout.splitlines()[0],
        "declared_upstream_revision": declared_upstream_revision,
        "developer_directory": run_tool(["xcode-select", "-p"]).stdout.strip(),
        "iphoneos_sdk_build": run_tool(
            ["xcrun", "--sdk", "iphoneos", "--show-sdk-build-version"]
        ).stdout.strip(),
        "iphoneos_sdk_path": run_tool(
            ["xcrun", "--sdk", "iphoneos", "--show-sdk-path"]
        ).stdout.strip(),
        "iphoneos_sdk_version": run_tool(
            ["xcrun", "--sdk", "iphoneos", "--show-sdk-version"]
        ).stdout.strip(),
        "policy_path": repository_relative(policy_path),
        "policy_sha256": sha256_file(policy_path),
        "project_modified_paths": project_status,
        "project_revision": project_revision,
        "project_worktree_clean": not project_status,
        "source_compiler_sha256": compiler_sha256,
        "source_max_present": (upstream_checkout / "max" / "mojo" / "max").is_dir(),
        "source_stdlib_present": (
            upstream_checkout / "mojo" / "stdlib" / "std"
        ).is_dir(),
        "swift": run_tool(["xcrun", "swift", "--version"]).stdout.splitlines()[0],
        "metal_toolchain": metal_toolchain,
        "upstream_checkout_revision": checkout_revision,
        "upstream_patches": patch_records,
        "xcode": run_tool(["xcodebuild", "-version"]).stdout.splitlines(),
    }


def write_report(output_path: Path, report: Dict[str, Any]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def main() -> int:
    arguments = parse_arguments()
    artifact_root = arguments.artifact.resolve()
    policy_path = arguments.policy.resolve()
    output_path = arguments.output.resolve()
    if not artifact_root.is_dir():
        raise AuditError(f"artifact root is not a directory: {artifact_root}")
    policy = load_policy(policy_path)
    if artifact_root.name != policy["expected_artifact_name"]:
        raise AuditError(
            f"expected artifact name {policy['expected_artifact_name']}, got "
            f"{artifact_root.name}"
        )
    provenance = parse_provenance(arguments.provenance)
    violations: List[Violation] = []
    files, all_entries = enumerate_artifact_entries(artifact_root)
    with tempfile.TemporaryDirectory(prefix="mojo-ios-distribution-audit.") as temp:
        static_archives, mach_o_images = scan_binary_files(
            artifact_root, files, Path(temp)
        )
    audit_paths(artifact_root, all_entries, files, policy, violations)
    if policy["artifact_kind"] == "xcframework":
        allowed_direct_mach_o_paths = audit_xcframework_structure(
            artifact_root, policy, static_archives, mach_o_images, violations
        )
    else:
        allowed_direct_mach_o_paths = audit_xcarchive_structure(
            artifact_root, mach_o_images, violations
        )
    audit_mach_o_policy(mach_o_images, policy, allowed_direct_mach_o_paths, violations)
    signing = artifact_signing(artifact_root)
    if policy["require_signature"] and not signing["signed"]:
        add_violation(
            violations,
            "missing_required_signature",
            artifact_root.name,
            "distribution policy requires a signature",
        )
    sorted_violations = sorted(
        violations,
        key=lambda violation: (violation.code, violation.subject, violation.detail),
    )
    report = {
        "artifact": {
            "kind": policy["artifact_kind"],
            "name": artifact_root.name,
            "signing": signing,
        },
        "files": files,
        "mach_o_images": mach_o_images,
        "policy": policy,
        "provenance": provenance,
        "result": "pass" if not sorted_violations else "fail",
        "schema_version": 1,
        "static_archives": static_archives,
        "toolchain": toolchain_tuple(policy_path),
        "violations": [violation.as_json() for violation in sorted_violations],
    }
    write_report(output_path, report)
    if sorted_violations:
        for violation in sorted_violations:
            print(
                "DISTRIBUTION_AUDIT_FAIL "
                f"code={violation.code} subject={json.dumps(violation.subject)} "
                f"detail={json.dumps(violation.detail)}",
                file=sys.stderr,
            )
        print(
            f"DISTRIBUTION_AUDIT_RESULT result=fail report={output_path}",
            file=sys.stderr,
        )
        return 1
    print(
        "DISTRIBUTION_AUDIT_PASS "
        f"files={len(files)} archives={len(static_archives)} "
        f"mach_o_images={len(mach_o_images)} report={output_path}"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AuditError, OSError, UnicodeError, plistlib.InvalidFileException) as error:
        print(f"DISTRIBUTION_AUDIT_ERROR: {error}", file=sys.stderr)
        sys.exit(2)
