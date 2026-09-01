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

PRIVACY_MANIFEST_NAME = "PrivacyInfo.xcprivacy"
PRIVACY_MANIFEST_KEYS = {
    "NSPrivacyAccessedAPITypes",
    "NSPrivacyCollectedDataTypes",
    "NSPrivacyTracking",
    "NSPrivacyTrackingDomains",
}
PRIVACY_ACCESSED_API_TYPE_KEYS = {
    "NSPrivacyAccessedAPIType",
    "NSPrivacyAccessedAPITypeReasons",
}
REQUIRED_REASON_API_CATEGORIES = {
    "NSPrivacyAccessedAPICategoryActiveKeyboards": {
        "approved_reasons": {"3EC4.1", "54BD.1"},
        "symbol_patterns": [re.compile(r"activeInputModes", re.IGNORECASE)],
    },
    "NSPrivacyAccessedAPICategoryDiskSpace": {
        "approved_reasons": {"7D9E.1", "85F4.1", "B728.1", "E174.1"},
        "symbol_patterns": [
            re.compile(r"^_(?:fstatfs|fstatvfs|statfs|statvfs)$"),
            re.compile(r"volume(?:Available|Total)Capacity", re.IGNORECASE),
            re.compile(r"(?:systemFreeSize|systemSize)", re.IGNORECASE),
        ],
    },
    "NSPrivacyAccessedAPICategoryFileTimestamp": {
        "approved_reasons": {"0A2A.1", "3B52.1", "C617.1", "DDA9.1"},
        "symbol_patterns": [
            re.compile(r"^_(?:fstat|fstatat|lstat|stat)$"),
            re.compile(
                r"(?:contentModificationDateKey|creationDateKey|"
                r"fileModificationDate|modificationDate)",
                re.IGNORECASE,
            ),
        ],
    },
    "NSPrivacyAccessedAPICategorySystemBootTime": {
        "approved_reasons": {"35F9.1", "3D61.1", "8FFB.1"},
        "symbol_patterns": [
            re.compile(r"^_mach_absolute_time$"),
            re.compile(r"systemUptime", re.IGNORECASE),
        ],
    },
    "NSPrivacyAccessedAPICategoryUserDefaults": {
        "approved_reasons": {"1C8F.1", "AC6B.1", "C56D.1", "CA92.1"},
        "symbol_patterns": [re.compile(r"(?:NS)?UserDefaults", re.IGNORECASE)],
    },
}
AMBIGUOUS_REQUIRED_REASON_API_PATTERNS = [
    re.compile(r"^_(?:fgetattrlist|getattrlist|getattrlistat)$"),
]
REVIEWED_NON_REQUIRED_API_PATTERNS = {
    "clock_gettime": re.compile(r"^_clock_gettime$"),
    "sysctlbyname": re.compile(r"^_sysctlbyname$"),
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
    "allowed_entitlements",
    "allowed_dependencies",
    "allowed_symbols",
    "artifact_kind",
    "declared_accelerator_artifacts",
    "embedded_metal_library_counts",
    "expected_bundle_identifier",
    "expected_artifact_name",
    "expected_slices",
    "expected_team_identifier",
    "expected_toolchain",
    "lane",
    "privacy_manifest_groups",
    "privacy_manifests",
    "require_signature",
    "required_signing_authority_prefix",
    "schema_version",
    "xcode_static_framework_placeholders",
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
    if policy.get("artifact_kind") not in {
        "app_bundle",
        "xcframework",
        "xcarchive",
    }:
        raise AuditError("artifact_kind must be app_bundle, xcframework, or xcarchive")
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
    allowed_entitlements = policy.get("allowed_entitlements", [])
    if not isinstance(allowed_entitlements, list) or not all(
        isinstance(value, str) for value in allowed_entitlements
    ):
        raise AuditError("allowed_entitlements must be a list of strings")
    if len(allowed_entitlements) != len(set(allowed_entitlements)):
        raise AuditError("allowed_entitlements must not contain duplicates")
    allowed_symbols = policy.get("allowed_symbols", {})
    if not isinstance(allowed_symbols, dict) or not all(
        isinstance(path, str)
        and path
        and isinstance(symbols, list)
        and all(isinstance(symbol, str) and symbol for symbol in symbols)
        and len(symbols) == len(set(symbols))
        for path, symbols in allowed_symbols.items()
    ):
        raise AuditError("allowed_symbols must map paths to unique symbol lists")
    embedded_metal_library_counts = policy.get("embedded_metal_library_counts", {})
    if not isinstance(embedded_metal_library_counts, dict) or not all(
        isinstance(path, str)
        and path
        and isinstance(count, int)
        and not isinstance(count, bool)
        and count >= 0
        for path, count in embedded_metal_library_counts.items()
    ):
        raise AuditError(
            "embedded_metal_library_counts must map paths to nonnegative integers"
        )
    xcode_static_framework_placeholders = policy.get(
        "xcode_static_framework_placeholders", []
    )
    if not isinstance(xcode_static_framework_placeholders, list) or not all(
        isinstance(path, str) and path
        and not Path(path).is_absolute()
        and ".." not in Path(path).parts
        for path in xcode_static_framework_placeholders
    ):
        raise AuditError("xcode_static_framework_placeholders must be a relative path list")
    if len(xcode_static_framework_placeholders) != len(
        set(xcode_static_framework_placeholders)
    ):
        raise AuditError("xcode_static_framework_placeholders must be unique")
    if (
        xcode_static_framework_placeholders
        and policy["artifact_kind"] not in {"app_bundle", "xcarchive"}
    ):
        raise AuditError(
            "xcode_static_framework_placeholders apply only to app artifacts"
        )
    expected_toolchain = policy.get("expected_toolchain", {})
    allowed_toolchain_keys = {
        "iphoneos_sdk_build",
        "metal_build_version",
        "xcode_build_version",
    }
    if not isinstance(expected_toolchain, dict):
        raise AuditError("expected_toolchain must be an object")
    unknown_toolchain_keys = sorted(set(expected_toolchain) - allowed_toolchain_keys)
    if unknown_toolchain_keys:
        raise AuditError(f"unknown expected-toolchain keys: {unknown_toolchain_keys}")
    if not all(
        isinstance(value, str) and value for value in expected_toolchain.values()
    ):
        raise AuditError("expected_toolchain values must be nonempty strings")
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
    if policy["artifact_kind"] in {"app_bundle", "xcarchive"}:
        if len(expected_slices) != 1:
            raise AuditError("xcarchive policy requires one application executable")
        if expected_slices[0]["binary_type"] != "mach_o":
            raise AuditError("xcarchive application executable must be Mach-O")
        for string_key in (
            "expected_bundle_identifier",
            "expected_team_identifier",
            "required_signing_authority_prefix",
        ):
            if not isinstance(policy.get(string_key), str) or not policy[string_key]:
                raise AuditError(f"xcarchive policy requires {string_key}")
    elif policy["require_signature"]:
        for string_key in (
            "expected_team_identifier",
            "required_signing_authority_prefix",
        ):
            if not isinstance(policy.get(string_key), str) or not policy[string_key]:
                raise AuditError(
                    f"signed {policy['artifact_kind']} policy requires {string_key}"
                )
    privacy_manifests = policy.get("privacy_manifests")
    if not isinstance(privacy_manifests, dict) or not privacy_manifests:
        raise AuditError("privacy_manifests must be a nonempty path map")
    required_privacy_policy_keys = {
        "accessed_api_types",
        "collected_data_types",
        "tracking",
        "tracking_domains",
    }
    for manifest_path, manifest_policy in privacy_manifests.items():
        if (
            not isinstance(manifest_path, str)
            or not manifest_path
            or Path(manifest_path).name != PRIVACY_MANIFEST_NAME
            or Path(manifest_path).is_absolute()
            or ".." in Path(manifest_path).parts
        ):
            raise AuditError(f"invalid privacy manifest path: {manifest_path}")
        if not isinstance(manifest_policy, dict):
            raise AuditError(f"privacy manifest policy must be an object: {manifest_path}")
        if set(manifest_policy) != required_privacy_policy_keys:
            raise AuditError(
                f"privacy manifest policy has wrong keys: {manifest_path}"
            )
        accessed_api_types = manifest_policy["accessed_api_types"]
        if not isinstance(accessed_api_types, dict) or not all(
            isinstance(category, str)
            and isinstance(reasons, list)
            and reasons
            and all(isinstance(reason, str) and reason for reason in reasons)
            and len(reasons) == len(set(reasons))
            for category, reasons in accessed_api_types.items()
        ):
            raise AuditError(
                f"accessed_api_types must map categories to unique reasons: {manifest_path}"
            )
        if not isinstance(manifest_policy["collected_data_types"], list):
            raise AuditError(f"collected_data_types must be a list: {manifest_path}")
        if not isinstance(manifest_policy["tracking"], bool):
            raise AuditError(f"tracking must be a Boolean: {manifest_path}")
        if not isinstance(manifest_policy["tracking_domains"], list) or not all(
            isinstance(domain, str) and domain
            for domain in manifest_policy["tracking_domains"]
        ):
            raise AuditError(f"tracking_domains must be a string list: {manifest_path}")
    privacy_manifest_groups = policy.get("privacy_manifest_groups", [])
    if not isinstance(privacy_manifest_groups, list):
        raise AuditError("privacy_manifest_groups must be a list")
    for group in privacy_manifest_groups:
        if (
            not isinstance(group, list)
            or len(group) < 2
            or len(group) != len(set(group))
            or not all(path in privacy_manifests for path in group)
        ):
            raise AuditError(
                "each privacy manifest group must contain two or more declared unique paths"
            )
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


def count_embedded_metal_libraries(data: bytes) -> int:
    count = 0
    search_offset = 0
    while True:
        magic_offset = data.find(b"MTLB", search_offset)
        if magic_offset < 0:
            return count
        version_offset = magic_offset + 4
        if version_offset < len(data) and data[version_offset] < 0x20:
            count += 1
        search_offset = magic_offset + 1


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
        return {"signed": False, "valid": False}
    verification = run_tool(
        ["codesign", "--verify", "--strict", "--verbose=4", str(path)],
        check=False,
        combine_output=True,
    )
    signing: Dict[str, Any] = {
        "signed": True,
        "valid": verification.returncode == 0,
    }
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
        "embedded_metal_library_count": count_embedded_metal_libraries(
            path.read_bytes()
        ),
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


def canonical_privacy_manifest(
    manifest_path: Path,
    relative_path: str,
    violations: List[Violation],
) -> Optional[Dict[str, Any]]:
    try:
        manifest = plistlib.loads(manifest_path.read_bytes())
    except (OSError, plistlib.InvalidFileException) as error:
        add_violation(
            violations,
            "invalid_privacy_manifest",
            relative_path,
            str(error),
        )
        return None
    if not isinstance(manifest, dict):
        add_violation(
            violations,
            "invalid_privacy_manifest",
            relative_path,
            "privacy manifest root must be a dictionary",
        )
        return None
    unexpected_keys = sorted(set(manifest) - PRIVACY_MANIFEST_KEYS)
    if unexpected_keys:
        add_violation(
            violations,
            "invalid_privacy_manifest_keys",
            relative_path,
            f"unexpected keys: {unexpected_keys}",
        )

    tracking = manifest.get("NSPrivacyTracking")
    tracking_domains = manifest.get("NSPrivacyTrackingDomains")
    collected_data_types = manifest.get("NSPrivacyCollectedDataTypes")
    accessed_api_types = manifest.get("NSPrivacyAccessedAPITypes")
    if not isinstance(tracking, bool):
        add_violation(
            violations,
            "invalid_privacy_tracking",
            relative_path,
            "NSPrivacyTracking must be a Boolean",
        )
        return None
    if not isinstance(tracking_domains, list) or not all(
        isinstance(domain, str) and domain for domain in tracking_domains
    ):
        add_violation(
            violations,
            "invalid_privacy_tracking_domains",
            relative_path,
            "NSPrivacyTrackingDomains must be an array of nonempty strings",
        )
        return None
    if len(tracking_domains) != len(set(tracking_domains)):
        add_violation(
            violations,
            "duplicate_privacy_tracking_domain",
            relative_path,
            "NSPrivacyTrackingDomains contains duplicates",
        )
    if not tracking and tracking_domains:
        add_violation(
            violations,
            "privacy_tracking_domains_without_tracking",
            relative_path,
            "tracking domains require NSPrivacyTracking=true",
        )
    if not isinstance(collected_data_types, list):
        add_violation(
            violations,
            "invalid_privacy_collected_data",
            relative_path,
            "NSPrivacyCollectedDataTypes must be an array",
        )
        return None
    if not isinstance(accessed_api_types, list):
        add_violation(
            violations,
            "invalid_privacy_accessed_api_types",
            relative_path,
            "NSPrivacyAccessedAPITypes must be an array",
        )
        return None

    canonical_accessed_api_types: Dict[str, List[str]] = {}
    for entry_index, entry in enumerate(accessed_api_types):
        entry_subject = f"{relative_path}:NSPrivacyAccessedAPITypes[{entry_index}]"
        if not isinstance(entry, dict) or set(entry) != PRIVACY_ACCESSED_API_TYPE_KEYS:
            add_violation(
                violations,
                "invalid_privacy_accessed_api_entry",
                entry_subject,
                "entry must contain exactly API type and reasons",
            )
            continue
        category = entry["NSPrivacyAccessedAPIType"]
        reasons = entry["NSPrivacyAccessedAPITypeReasons"]
        if not isinstance(category, str) or category not in REQUIRED_REASON_API_CATEGORIES:
            add_violation(
                violations,
                "unknown_required_reason_api_category",
                entry_subject,
                f"unknown category: {category}",
            )
            continue
        if (
            not isinstance(reasons, list)
            or not reasons
            or not all(isinstance(reason, str) and reason for reason in reasons)
        ):
            add_violation(
                violations,
                "invalid_required_reason_list",
                entry_subject,
                "reasons must be a nonempty string array",
            )
            continue
        if category in canonical_accessed_api_types:
            add_violation(
                violations,
                "duplicate_required_reason_api_category",
                entry_subject,
                category,
            )
            continue
        unique_reasons = sorted(set(reasons))
        if len(unique_reasons) != len(reasons):
            add_violation(
                violations,
                "duplicate_required_reason",
                entry_subject,
                category,
            )
        approved_reasons = REQUIRED_REASON_API_CATEGORIES[category][
            "approved_reasons"
        ]
        for reason in unique_reasons:
            if reason not in approved_reasons:
                add_violation(
                    violations,
                    "unknown_required_reason",
                    entry_subject,
                    f"{category}: {reason}",
                )
        canonical_accessed_api_types[category] = unique_reasons

    return {
        "accessed_api_types": dict(sorted(canonical_accessed_api_types.items())),
        "collected_data_types": collected_data_types,
        "tracking": tracking,
        "tracking_domains": sorted(tracking_domains),
    }


def required_reason_api_observations(
    mach_o_images: Iterable[Dict[str, Any]],
    violations: List[Violation],
) -> Tuple[List[Dict[str, str]], List[Dict[str, str]]]:
    required_observations: List[Dict[str, str]] = []
    reviewed_non_required_observations: List[Dict[str, str]] = []
    for image in mach_o_images:
        symbols = sorted(
            set(image["exported_symbols"]) | set(image["undefined_symbols"])
        )
        for symbol in symbols:
            for pattern in AMBIGUOUS_REQUIRED_REASON_API_PATTERNS:
                if pattern.search(symbol):
                    add_violation(
                        violations,
                        "ambiguous_required_reason_api",
                        image["subject"],
                        f"{symbol} can expose file metadata or disk space; add an explicit operation-level classification",
                    )
            for category, category_policy in REQUIRED_REASON_API_CATEGORIES.items():
                if any(
                    pattern.search(symbol)
                    for pattern in category_policy["symbol_patterns"]
                ):
                    required_observations.append(
                        {
                            "category": category,
                            "subject": image["subject"],
                            "symbol": symbol,
                        }
                    )
            for api_name, pattern in REVIEWED_NON_REQUIRED_API_PATTERNS.items():
                if pattern.search(symbol):
                    reviewed_non_required_observations.append(
                        {
                            "api": api_name,
                            "classification": "not in Apple's current Required Reason API categories",
                            "subject": image["subject"],
                            "symbol": symbol,
                        }
                    )
    required_observations.sort(
        key=lambda observation: (
            observation["category"],
            observation["subject"],
            observation["symbol"],
        )
    )
    reviewed_non_required_observations.sort(
        key=lambda observation: (
            observation["api"],
            observation["subject"],
            observation["symbol"],
        )
    )
    return required_observations, reviewed_non_required_observations


def audit_privacy_manifests(
    artifact_root: Path,
    file_records: Iterable[Dict[str, Any]],
    mach_o_images: Iterable[Dict[str, Any]],
    policy: Dict[str, Any],
    violations: List[Violation],
) -> Dict[str, Any]:
    expected_manifests = policy["privacy_manifests"]
    actual_manifest_paths = {
        record["path"]
        for record in file_records
        if record["kind"] == "file"
        and Path(record["path"]).name == PRIVACY_MANIFEST_NAME
    }
    for missing_path in sorted(set(expected_manifests) - actual_manifest_paths):
        add_violation(
            violations,
            "missing_privacy_manifest",
            missing_path,
            "declared privacy manifest is missing",
        )
    for unexpected_path in sorted(actual_manifest_paths - set(expected_manifests)):
        add_violation(
            violations,
            "unexpected_privacy_manifest",
            unexpected_path,
            "privacy manifest is in an undeclared bundle location",
        )

    canonical_manifests: Dict[str, Dict[str, Any]] = {}
    for relative_path, expected_manifest in sorted(expected_manifests.items()):
        manifest_path = artifact_root / relative_path
        if not manifest_path.is_file():
            continue
        canonical_manifest = canonical_privacy_manifest(
            manifest_path, relative_path, violations
        )
        if canonical_manifest is None:
            continue
        canonical_manifests[relative_path] = canonical_manifest
        for key, violation_code in (
            ("accessed_api_types", "privacy_accessed_api_types_mismatch"),
            ("collected_data_types", "unexpected_privacy_data_collection"),
            ("tracking", "unexpected_privacy_tracking"),
            ("tracking_domains", "privacy_tracking_domains_mismatch"),
        ):
            expected_value = expected_manifest[key]
            if key in {"accessed_api_types", "tracking_domains"}:
                if key == "accessed_api_types":
                    expected_value = {
                        category: sorted(reasons)
                        for category, reasons in sorted(expected_value.items())
                    }
                else:
                    expected_value = sorted(expected_value)
            if canonical_manifest[key] != expected_value:
                add_violation(
                    violations,
                    violation_code,
                    relative_path,
                    f"expected {expected_value}, got {canonical_manifest[key]}",
                )

    for group in policy.get("privacy_manifest_groups", []):
        present = [path for path in group if path in canonical_manifests]
        if len(present) != len(group):
            continue
        baseline_path = group[0]
        baseline = canonical_manifests[baseline_path]
        for comparison_path in group[1:]:
            if canonical_manifests[comparison_path] != baseline:
                add_violation(
                    violations,
                    "privacy_manifest_variant_divergence",
                    comparison_path,
                    f"manifest differs from {baseline_path}",
                )

    required_observations, reviewed_non_required_observations = (
        required_reason_api_observations(mach_o_images, violations)
    )
    declared_categories = {
        category
        for manifest in canonical_manifests.values()
        for category in manifest["accessed_api_types"]
    }
    for observation in required_observations:
        if observation["category"] not in declared_categories:
            add_violation(
                violations,
                "undeclared_required_reason_api",
                observation["subject"],
                f"{observation['symbol']} requires {observation['category']}",
            )

    return {
        "manifests": dict(sorted(canonical_manifests.items())),
        "required_reason_api_observations": required_observations,
        "reviewed_non_required_api_observations": reviewed_non_required_observations,
    }


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
        allowed_symbols = set(
            policy.get("allowed_symbols", {}).get(image["container_path"], [])
        )
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
            if symbol in allowed_symbols:
                continue
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
    allowed_auxiliary_directories = (
        {"_CodeSignature"} if policy["require_signature"] else set()
    )
    for identifier in sorted(
        top_level_directories
        - set(expected_by_identifier)
        - allowed_auxiliary_directories
    ):
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


def audit_application_bundle(
    artifact_root: Path,
    app_bundle: Path,
    policy: Dict[str, Any],
    mach_o_images: List[Dict[str, Any]],
    violations: List[Violation],
) -> Set[str]:
    app_info_path = app_bundle / "Info.plist"
    if not app_info_path.is_file():
        add_violation(
            violations,
            "missing_application_info",
            app_info_path.relative_to(artifact_root).as_posix(),
            "application Info.plist is missing",
        )
        return set()
    try:
        app_info = plistlib.loads(app_info_path.read_bytes())
    except plistlib.InvalidFileException as error:
        raise AuditError(f"cannot parse application Info.plist: {error}") from error
    actual_bundle_identifier = app_info.get("CFBundleIdentifier")
    if actual_bundle_identifier != policy["expected_bundle_identifier"]:
        add_violation(
            violations,
            "wrong_bundle_identifier",
            app_info_path.relative_to(artifact_root).as_posix(),
            f"expected {policy['expected_bundle_identifier']}, got "
            f"{actual_bundle_identifier or 'not recorded'}",
        )
    executable_name = app_info.get("CFBundleExecutable")
    if not isinstance(executable_name, str) or not executable_name:
        add_violation(
            violations,
            "missing_application_executable_name",
            app_info_path.relative_to(artifact_root).as_posix(),
            "CFBundleExecutable is missing",
        )
        return set()
    executable_relative_path = (
        app_bundle.relative_to(artifact_root) / executable_name
    ).as_posix()
    expected_executable = policy["expected_slices"][0]
    if executable_relative_path != expected_executable["identifier"]:
        add_violation(
            violations,
            "wrong_application_executable",
            executable_relative_path,
            f"expected {expected_executable['identifier']}",
        )
    matching_images = [
        image
        for image in mach_o_images
        if image["archive_member"] is None
        and image["container_path"] == executable_relative_path
    ]
    if len(matching_images) != 1:
        add_violation(
            violations,
            "invalid_application_executable_count",
            executable_relative_path,
            f"expected one Mach-O executable, found {len(matching_images)}",
        )
        return set()
    application_image = matching_images[0]
    validate_image_target(application_image, expected_executable, violations)
    allowed_direct_mach_o_paths = {executable_relative_path}
    application_dependencies = set(application_image["dependencies"])
    for placeholder_path in policy.get(
        "xcode_static_framework_placeholders", []
    ):
        matching_placeholder_images = [
            image
            for image in mach_o_images
            if image["archive_member"] is None
            and image["container_path"] == placeholder_path
        ]
        if len(matching_placeholder_images) != 1:
            add_violation(
                violations,
                "invalid_xcode_static_framework_placeholder_count",
                placeholder_path,
                f"expected one Xcode static-framework placeholder, found {len(matching_placeholder_images)}",
            )
            continue
        placeholder_image = matching_placeholder_images[0]
        allowed_direct_mach_o_paths.add(placeholder_path)
        validate_image_target(placeholder_image, expected_executable, violations)
        if placeholder_image["exported_symbols"] or placeholder_image["undefined_symbols"]:
            add_violation(
                violations,
                "nonempty_xcode_static_framework_placeholder",
                placeholder_path,
                "Xcode's static-framework placeholder must expose no symbols",
            )
        framework_name = Path(placeholder_path).name
        if any(
            dependency.endswith(f"/{framework_name}")
            for dependency in application_dependencies
        ):
            add_violation(
                violations,
                "loaded_xcode_static_framework_placeholder",
                executable_relative_path,
                f"application unexpectedly loads static framework placeholder {framework_name}",
            )
    return allowed_direct_mach_o_paths


def audit_xcarchive_structure(
    artifact_root: Path,
    policy: Dict[str, Any],
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
        return set()
    return audit_application_bundle(
        artifact_root, app_bundles[0], policy, mach_o_images, violations
    )


def audit_app_bundle_structure(
    artifact_root: Path,
    policy: Dict[str, Any],
    mach_o_images: List[Dict[str, Any]],
    violations: List[Violation],
) -> Set[str]:
    if artifact_root.suffix != ".app":
        add_violation(
            violations,
            "invalid_application_bundle",
            artifact_root.name,
            "app_bundle artifact must have an .app suffix",
        )
    return audit_application_bundle(
        artifact_root, artifact_root, policy, mach_o_images, violations
    )


def artifact_signing(artifact_root: Path, artifact_kind: str) -> Dict[str, Any]:
    if artifact_kind in {"app_bundle", "xcframework"}:
        return inspect_signing(artifact_root)
    applications_root = artifact_root / "Products" / "Applications"
    app_bundles = sorted(applications_root.glob("*.app"))
    if len(app_bundles) != 1:
        return {"signed": False, "valid": False}
    return inspect_signing(app_bundles[0])


def audit_embedded_metal_libraries(
    mach_o_images: List[Dict[str, Any]],
    policy: Dict[str, Any],
    violations: List[Violation],
) -> Dict[str, int]:
    actual_counts: Dict[str, int] = {}
    for relative_path, expected_count in sorted(
        policy.get("embedded_metal_library_counts", {}).items()
    ):
        matching_images = [
            image for image in mach_o_images if image["container_path"] == relative_path
        ]
        if not matching_images:
            add_violation(
                violations,
                "missing_embedded_metal_container",
                relative_path,
                "declared embedded Metal Mach-O container is missing",
            )
            continue
        actual_count = sum(
            image["embedded_metal_library_count"] for image in matching_images
        )
        actual_counts[relative_path] = actual_count
        if actual_count != expected_count:
            add_violation(
                violations,
                "wrong_embedded_metal_library_count",
                relative_path,
                f"expected {expected_count}, got {actual_count}",
            )
    return actual_counts


def audit_signing_policy(
    signing: Dict[str, Any],
    policy: Dict[str, Any],
    violations: List[Violation],
) -> None:
    if policy["require_signature"] and not signing["signed"]:
        add_violation(
            violations,
            "missing_required_signature",
            policy["expected_artifact_name"],
            "distribution policy requires a signature",
        )
        return
    if policy["require_signature"] and not signing["valid"]:
        add_violation(
            violations,
            "invalid_required_signature",
            policy["expected_artifact_name"],
            "distribution policy requires a valid signature",
        )
    if not policy["require_signature"] or not signing["signed"]:
        return
    actual_team_identifier = signing.get("team_identifier", "not recorded")
    if actual_team_identifier != policy["expected_team_identifier"]:
        add_violation(
            violations,
            "wrong_signing_team",
            policy["expected_artifact_name"],
            f"expected {policy['expected_team_identifier']}, got "
            f"{actual_team_identifier}",
        )
    required_authority_prefix = policy["required_signing_authority_prefix"]
    actual_authorities = signing.get("authorities", [])
    if not any(
        authority.startswith(required_authority_prefix)
        for authority in actual_authorities
    ):
        add_violation(
            violations,
            "wrong_signing_authority",
            policy["expected_artifact_name"],
            f"expected authority prefix {required_authority_prefix}, got "
            f"{actual_authorities or ['not recorded']}",
        )
    actual_entitlements = signing.get("entitlements", {})
    undeclared_entitlements = sorted(
        set(actual_entitlements) - set(policy.get("allowed_entitlements", []))
    )
    for entitlement in undeclared_entitlements:
        add_violation(
            violations,
            "undeclared_entitlement",
            policy["expected_artifact_name"],
            entitlement,
        )


def audit_toolchain_policy(
    toolchain: Dict[str, Any],
    policy: Dict[str, Any],
    violations: List[Violation],
) -> None:
    actual_values = {
        "iphoneos_sdk_build": toolchain["iphoneos_sdk_build"],
        "metal_build_version": toolchain["metal_toolchain"]["build_version"],
        "xcode_build_version": toolchain["xcode_build_version"],
    }
    for field, expected_value in sorted(policy.get("expected_toolchain", {}).items()):
        if actual_values[field] != expected_value:
            add_violation(
                violations,
                "toolchain_mismatch",
                field,
                f"expected {expected_value}, got {actual_values[field]}",
            )


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
    xcode_version_lines = run_tool(["xcodebuild", "-version"]).stdout.splitlines()
    if len(xcode_version_lines) < 2 or not xcode_version_lines[1].startswith(
        "Build version "
    ):
        raise AuditError("xcodebuild -version did not report a build version")
    selected_developer_directory = os.environ.get("DEVELOPER_DIR")
    if selected_developer_directory is None:
        selected_developer_directory = run_tool(["xcode-select", "-p"]).stdout.strip()
    return {
        "apple_clang": run_tool(["xcrun", "clang", "--version"]).stdout.splitlines()[0],
        "declared_upstream_revision": declared_upstream_revision,
        "developer_directory": str(Path(selected_developer_directory).resolve()),
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
        "xcode": xcode_version_lines,
        "xcode_build_version": xcode_version_lines[1].removeprefix("Build version "),
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
    elif policy["artifact_kind"] == "xcarchive":
        allowed_direct_mach_o_paths = audit_xcarchive_structure(
            artifact_root, policy, mach_o_images, violations
        )
    else:
        allowed_direct_mach_o_paths = audit_app_bundle_structure(
            artifact_root, policy, mach_o_images, violations
        )
    audit_mach_o_policy(mach_o_images, policy, allowed_direct_mach_o_paths, violations)
    privacy = audit_privacy_manifests(
        artifact_root, files, mach_o_images, policy, violations
    )
    embedded_metal_libraries = audit_embedded_metal_libraries(
        mach_o_images, policy, violations
    )
    signing = artifact_signing(artifact_root, policy["artifact_kind"])
    audit_signing_policy(signing, policy, violations)
    toolchain = toolchain_tuple(policy_path)
    audit_toolchain_policy(toolchain, policy, violations)
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
        "embedded_metal_libraries": embedded_metal_libraries,
        "mach_o_images": mach_o_images,
        "policy": policy,
        "privacy": privacy,
        "provenance": provenance,
        "result": "pass" if not sorted_violations else "fail",
        "schema_version": 1,
        "static_archives": static_archives,
        "toolchain": toolchain,
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
