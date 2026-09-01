#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import re
import shutil
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any


SCHEMA_VERSION = 1
SPDX_VERSION = "SPDX-2.3"
DATA_LICENSE = "CC0-1.0"
RELEASE_ARCHIVE_NAME = "MojoIOSCore.xcframework.zip"
PROVENANCE_NAME = "PROVENANCE.json"
SBOM_NAME = "SBOM.spdx.json"
CHECKSUMS_NAME = "SHA256SUMS"
NOTICE_NAME = "THIRD_PARTY_NOTICES.md"
PROJECT_LICENSE_NAME = "LICENSES/mojo-ios-LICENSE.txt"
MODULAR_LICENSE_NAME = "LICENSES/Modular-LICENSE.txt"
MODULAR_NOTICES_NAME = "LICENSES/Modular-Third-Party-Notices.txt"
EXPECTED_BUNDLE_FILES = {
    RELEASE_ARCHIVE_NAME,
    PROVENANCE_NAME,
    SBOM_NAME,
    CHECKSUMS_NAME,
    NOTICE_NAME,
    PROJECT_LICENSE_NAME,
    MODULAR_LICENSE_NAME,
    MODULAR_NOTICES_NAME,
}


class ReleaseError(Exception):
    pass


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as input_file:
        while chunk := input_file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ReleaseError(f"cannot read JSON {path}: {error}") from error
    if not isinstance(value, dict):
        raise ReleaseError(f"expected JSON object: {path}")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def validate_relative_path(path: str) -> PurePosixPath:
    relative_path = PurePosixPath(path)
    if (
        not path
        or relative_path.is_absolute()
        or ".." in relative_path.parts
        or "." in relative_path.parts
    ):
        raise ReleaseError(f"invalid relative path: {path!r}")
    return relative_path


def regular_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise ReleaseError(f"release input must not contain symlinks: {path}")
        if path.is_file():
            files.append(path)
        elif not path.is_dir():
            raise ReleaseError(f"unsupported release input type: {path}")
    return files


def zip_timestamp(source_date_epoch: int) -> tuple[int, int, int, int, int, int]:
    timestamp = datetime.datetime.fromtimestamp(
        source_date_epoch, tz=datetime.timezone.utc
    )
    if timestamp.year < 1980:
        timestamp = datetime.datetime(1980, 1, 1, tzinfo=datetime.timezone.utc)
    return (
        timestamp.year,
        timestamp.month,
        timestamp.day,
        timestamp.hour,
        timestamp.minute,
        timestamp.second - timestamp.second % 2,
    )


def write_deterministic_zip(
    xcframework_path: Path,
    archive_path: Path,
    source_date_epoch: int,
) -> None:
    timestamp = zip_timestamp(source_date_epoch)
    with zipfile.ZipFile(
        archive_path,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for source_path in regular_files(xcframework_path):
            relative_path = source_path.relative_to(xcframework_path).as_posix()
            archive_name = f"{xcframework_path.name}/{relative_path}"
            zip_info = zipfile.ZipInfo(archive_name, date_time=timestamp)
            zip_info.compress_type = zipfile.ZIP_DEFLATED
            zip_info.create_system = 3
            source_mode = stat.S_IMODE(source_path.stat().st_mode)
            zip_info.external_attr = (stat.S_IFREG | source_mode) << 16
            archive.writestr(zip_info, source_path.read_bytes(), compresslevel=9)


def source_file_records(xcframework_path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for path in regular_files(xcframework_path):
        relative_path = path.relative_to(xcframework_path).as_posix()
        records.append(
            {
                "fileName": f"{xcframework_path.name}/{relative_path}",
                "path": path,
                "sha256": sha256_file(path),
            }
        )
    return records


def validate_audit_matches_artifact(
    xcframework_path: Path,
    audit_report: dict[str, Any],
) -> list[dict[str, Any]]:
    if audit_report.get("schema_version") != SCHEMA_VERSION:
        raise ReleaseError("unsupported audit schema")
    if audit_report.get("result") != "pass" or audit_report.get("violations") != []:
        raise ReleaseError("release artifact audit did not pass")
    artifact = audit_report.get("artifact")
    if not isinstance(artifact, dict) or artifact.get("name") != xcframework_path.name:
        raise ReleaseError("audit artifact name does not match release input")
    signing = artifact.get("signing")
    if not isinstance(signing, dict) or not signing.get("signed") or not signing.get(
        "valid"
    ):
        raise ReleaseError("release XCFramework must have a valid signature")

    actual_records = source_file_records(xcframework_path)
    actual_hashes = {
        record["fileName"].removeprefix(f"{xcframework_path.name}/"): record[
            "sha256"
        ]
        for record in actual_records
    }
    audit_files = audit_report.get("files")
    if not isinstance(audit_files, list):
        raise ReleaseError("audit file inventory is missing")
    audited_hashes: dict[str, str] = {}
    for record in audit_files:
        if not isinstance(record, dict):
            raise ReleaseError("invalid audit file record")
        path = record.get("path")
        sha256 = record.get("sha256")
        if not isinstance(path, str) or not isinstance(sha256, str):
            raise ReleaseError("invalid audit file path or hash")
        validate_relative_path(path)
        if path in audited_hashes:
            raise ReleaseError(f"duplicate audit file path: {path}")
        audited_hashes[path] = sha256
    if actual_hashes != audited_hashes:
        raise ReleaseError("audit file inventory does not match release XCFramework")
    return actual_records


def spdx_file_id(file_name: str) -> str:
    return f"SPDXRef-File-{sha256_bytes(file_name.encode('utf-8'))[:24]}"


def spdx_file_record(file_name: str, sha256: str) -> dict[str, Any]:
    return {
        "SPDXID": spdx_file_id(file_name),
        "checksums": [{"algorithm": "SHA256", "checksumValue": sha256}],
        "copyrightText": "NOASSERTION",
        "fileName": file_name,
        "licenseConcluded": "NOASSERTION",
    }


def package_record(
    *,
    spdx_id: str,
    name: str,
    version: str,
    supplier: str,
    license_declared: str = "NOASSERTION",
    files_analyzed: bool = False,
    checksums: list[dict[str, str]] | None = None,
    external_refs: list[dict[str, str]] | None = None,
    license_comments: str | None = None,
) -> dict[str, Any]:
    package: dict[str, Any] = {
        "SPDXID": spdx_id,
        "copyrightText": "NOASSERTION",
        "downloadLocation": "NOASSERTION",
        "filesAnalyzed": files_analyzed,
        "licenseConcluded": "NOASSERTION",
        "licenseDeclared": license_declared,
        "name": name,
        "supplier": supplier,
        "versionInfo": version,
    }
    if checksums:
        package["checksums"] = checksums
    if external_refs:
        package["externalRefs"] = external_refs
    if license_comments:
        package["licenseComments"] = license_comments
    return package


def require_string(mapping: dict[str, Any], key: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value:
        raise ReleaseError(f"required string is missing: {key}")
    return value


def create_notice(
    metadata: dict[str, Any],
    upstream_revision: str,
    project_license_sha256: str,
    modular_license_sha256: str,
    modular_notices_sha256: str,
) -> str:
    return f"""# License and third-party notices

MojoIOSCore is distributed under
`{require_string(metadata, 'project_license')}`. The exact project license is
included as:

- `LICENSES/mojo-ios-LICENSE.txt` SHA-256 `{project_license_sha256}`

This release candidate contains object code derived from the Modular repository
at commit `{upstream_revision}`. Its governing license is
`{require_string(metadata, 'upstream_license')}`.

The exact upstream license and third-party notice bundle are included without
pruning because source-to-notice closure for the compiled subset has not yet
been proved:

- `LICENSES/Modular-LICENSE.txt` SHA-256 `{modular_license_sha256}`
- `LICENSES/Modular-Third-Party-Notices.txt` SHA-256 `{modular_notices_sha256}`

Apple Xcode, the iOS SDK, the Metal toolchain, and Apple system frameworks are
recorded in `SBOM.spdx.json` as build or system dependencies. They are not
redistributed by this package, so their license text is not copied into it.

The Swift package has no third-party Swift package dependencies. Project
license status: `{require_string(metadata, 'project_license_status')}`.
"""


def create_sbom(
    *,
    metadata: dict[str, Any],
    audit_report: dict[str, Any],
    upstream_revision: str,
    archive_sha256: str,
    source_date_epoch: int,
    file_records: list[dict[str, Any]],
) -> dict[str, Any]:
    toolchain = audit_report.get("toolchain")
    if not isinstance(toolchain, dict):
        raise ReleaseError("audit toolchain tuple is missing")
    project_revision = require_string(toolchain, "project_revision")
    xcode = toolchain.get("xcode")
    if not isinstance(xcode, list) or not all(isinstance(line, str) for line in xcode):
        raise ReleaseError("audit Xcode version is missing")
    metal = toolchain.get("metal_toolchain")
    if not isinstance(metal, dict):
        raise ReleaseError("audit Metal toolchain is missing")

    created = datetime.datetime.fromtimestamp(
        source_date_epoch, tz=datetime.timezone.utc
    ).strftime("%Y-%m-%dT%H:%M:%SZ")
    release_id = "SPDXRef-Package-MojoIOSCore"
    modular_id = "SPDXRef-Package-Modular"
    xcode_id = "SPDXRef-Package-Apple-Xcode"
    sdk_id = "SPDXRef-Package-Apple-iPhoneOS-SDK"
    metal_id = "SPDXRef-Package-Apple-Metal-Toolchain"
    system_id = "SPDXRef-Package-Apple-System-Libraries"

    spdx_files = [
        spdx_file_record(record["fileName"], record["sha256"])
        for record in file_records
    ]
    relationships: list[dict[str, str]] = [
        {
            "spdxElementId": "SPDXRef-DOCUMENT",
            "relationshipType": "DESCRIBES",
            "relatedSpdxElement": release_id,
        },
        {
            "spdxElementId": release_id,
            "relationshipType": "STATIC_LINK",
            "relatedSpdxElement": modular_id,
        },
        {
            "spdxElementId": release_id,
            "relationshipType": "DEPENDS_ON",
            "relatedSpdxElement": system_id,
        },
        {
            "spdxElementId": xcode_id,
            "relationshipType": "BUILD_TOOL_OF",
            "relatedSpdxElement": release_id,
        },
        {
            "spdxElementId": sdk_id,
            "relationshipType": "BUILD_TOOL_OF",
            "relatedSpdxElement": release_id,
        },
        {
            "spdxElementId": metal_id,
            "relationshipType": "BUILD_TOOL_OF",
            "relatedSpdxElement": release_id,
        },
    ]
    for file_record in spdx_files:
        relationships.append(
            {
                "spdxElementId": release_id,
                "relationshipType": "CONTAINS",
                "relatedSpdxElement": file_record["SPDXID"],
            }
        )

    packages = [
        package_record(
            spdx_id=release_id,
            name="MojoIOSCore",
            version=require_string(metadata, "version"),
            supplier=require_string(metadata, "project_supplier"),
            license_declared=require_string(metadata, "project_license"),
            files_analyzed=True,
            checksums=[{"algorithm": "SHA256", "checksumValue": archive_sha256}],
            external_refs=[
                {
                    "referenceCategory": "PACKAGE-MANAGER",
                    "referenceLocator": (
                        "pkg:github/imh/mojo-ios@" + project_revision
                    ),
                    "referenceType": "purl",
                }
            ],
            license_comments=(
                "Project distribution license status: "
                + require_string(metadata, "project_license_status")
            ),
        ),
        package_record(
            spdx_id=modular_id,
            name=require_string(metadata, "upstream_name"),
            version=upstream_revision,
            supplier="Organization: Modular, Inc.",
            license_declared=require_string(metadata, "upstream_license"),
            external_refs=[
                {
                    "referenceCategory": "PACKAGE-MANAGER",
                    "referenceLocator": (
                        "pkg:github/modular/modular@" + upstream_revision
                    ),
                    "referenceType": "purl",
                }
            ],
        ),
        package_record(
            spdx_id=xcode_id,
            name="Apple Xcode",
            version=" / ".join(xcode),
            supplier="Organization: Apple Inc.",
            license_comments="Build dependency; not redistributed.",
        ),
        package_record(
            spdx_id=sdk_id,
            name="Apple iPhoneOS SDK",
            version=(
                require_string(toolchain, "iphoneos_sdk_version")
                + " (build "
                + require_string(toolchain, "iphoneos_sdk_build")
                + ")"
            ),
            supplier="Organization: Apple Inc.",
            license_comments="Build and system dependency; not redistributed.",
        ),
        package_record(
            spdx_id=metal_id,
            name="Apple Metal Toolchain",
            version=(
                require_string(metal, "build_version")
                + " / "
                + require_string(metal, "compiler_version")
            ),
            supplier="Organization: Apple Inc.",
            license_comments="Build dependency; not redistributed.",
        ),
        package_record(
            spdx_id=system_id,
            name="Apple iOS system libraries and frameworks",
            version=require_string(toolchain, "iphoneos_sdk_build"),
            supplier="Organization: Apple Inc.",
            license_comments=(
                "Runtime dependencies; not redistributed: "
                + ", ".join(audit_report["policy"]["allowed_dependencies"])
            ),
        ),
    ]

    return {
        "SPDXID": "SPDXRef-DOCUMENT",
        "creationInfo": {
            "created": created,
            "creators": ["Tool: mojo-ios/scripts/release-provenance.py"],
        },
        "dataLicense": DATA_LICENSE,
        "documentNamespace": (
            require_string(metadata, "project_repository")
            + "/sbom/"
            + project_revision
            + "/"
            + archive_sha256
        ),
        "files": spdx_files,
        "name": f"MojoIOSCore-{require_string(metadata, 'version')}",
        "packages": packages,
        "relationships": relationships,
        "spdxVersion": SPDX_VERSION,
    }


def generate(arguments: argparse.Namespace) -> None:
    xcframework_path = arguments.xcframework.resolve()
    output_directory = arguments.output.resolve()
    if not xcframework_path.is_dir() or xcframework_path.name != "MojoIOSCore.xcframework":
        raise ReleaseError("expected a MojoIOSCore.xcframework directory")
    if output_directory.exists() and any(output_directory.iterdir()):
        raise ReleaseError(f"release output must be empty: {output_directory}")
    output_directory.mkdir(parents=True, exist_ok=True)

    metadata = read_json(arguments.metadata)
    if metadata.get("schema_version") != SCHEMA_VERSION:
        raise ReleaseError("unsupported release metadata schema")
    audit_report = read_json(arguments.audit_report)
    artifact_records = validate_audit_matches_artifact(xcframework_path, audit_report)
    upstream_revision = arguments.upstream_revision.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"[0-9a-f]{40}", upstream_revision):
        raise ReleaseError("upstream revision must be a full lowercase Git hash")
    if (
        audit_report.get("toolchain", {}).get("declared_upstream_revision")
        != upstream_revision
    ):
        raise ReleaseError("audit and declared upstream revisions differ")

    project_license_source = arguments.project_license
    modular_license_source = arguments.upstream_root / "LICENSE"
    modular_notices_source = arguments.upstream_root / "Licenses/Third-Party-Notices"
    for source in (project_license_source, modular_license_source, modular_notices_source):
        if not source.is_file():
            raise ReleaseError(f"required license or notice is missing: {source}")

    project_license_path = output_directory / PROJECT_LICENSE_NAME
    modular_license_path = output_directory / MODULAR_LICENSE_NAME
    modular_notices_path = output_directory / MODULAR_NOTICES_NAME
    modular_license_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(project_license_source, project_license_path)
    shutil.copyfile(modular_license_source, modular_license_path)
    shutil.copyfile(modular_notices_source, modular_notices_path)
    project_license_sha256 = sha256_file(project_license_path)
    modular_license_sha256 = sha256_file(modular_license_path)
    modular_notices_sha256 = sha256_file(modular_notices_path)

    provenance_path = output_directory / PROVENANCE_NAME
    shutil.copyfile(arguments.audit_report, provenance_path)
    notice_path = output_directory / NOTICE_NAME
    notice_path.write_text(
        create_notice(
            metadata,
            upstream_revision,
            project_license_sha256,
            modular_license_sha256,
            modular_notices_sha256,
        ),
        encoding="utf-8",
    )

    archive_path = output_directory / RELEASE_ARCHIVE_NAME
    write_deterministic_zip(
        xcframework_path, archive_path, arguments.source_date_epoch
    )
    archive_sha256 = sha256_file(archive_path)

    supplemental_paths = [
        project_license_path,
        modular_license_path,
        modular_notices_path,
        provenance_path,
        notice_path,
    ]
    file_records = list(artifact_records)
    for path in supplemental_paths:
        file_records.append(
            {
                "fileName": path.relative_to(output_directory).as_posix(),
                "path": path,
                "sha256": sha256_file(path),
            }
        )
    file_records.sort(key=lambda record: record["fileName"])

    sbom = create_sbom(
        metadata=metadata,
        audit_report=audit_report,
        upstream_revision=upstream_revision,
        archive_sha256=archive_sha256,
        source_date_epoch=arguments.source_date_epoch,
        file_records=file_records,
    )
    sbom_path = output_directory / SBOM_NAME
    write_json(sbom_path, sbom)

    checksummed_paths = sorted(
        path
        for path in regular_files(output_directory)
        if path.name != CHECKSUMS_NAME
    )
    checksum_lines = [
        f"{sha256_file(path)}  {path.relative_to(output_directory).as_posix()}"
        for path in checksummed_paths
    ]
    (output_directory / CHECKSUMS_NAME).write_text(
        "\n".join(checksum_lines) + "\n", encoding="utf-8"
    )
    verify_bundle(output_directory, require_clean=arguments.require_clean)
    print(
        "RELEASE_PROVENANCE_GENERATE_PASS "
        f"bundle={output_directory} files={len(checksummed_paths)} "
        f"project_license={metadata['project_license_status']}"
    )


def parse_checksums(path: Path) -> dict[str, str]:
    checksums: dict[str, str] = {}
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            raise ReleaseError(f"invalid SHA256SUMS line {line_number}")
        checksum, relative_path_text = match.groups()
        relative_path = validate_relative_path(relative_path_text).as_posix()
        if relative_path in checksums:
            raise ReleaseError(f"duplicate SHA256SUMS path: {relative_path}")
        checksums[relative_path] = checksum
    return checksums


def checksum_from_spdx(record: dict[str, Any]) -> str:
    checksums = record.get("checksums")
    if not isinstance(checksums, list):
        raise ReleaseError("SPDX file is missing checksums")
    sha256_values = [
        checksum.get("checksumValue")
        for checksum in checksums
        if isinstance(checksum, dict) and checksum.get("algorithm") == "SHA256"
    ]
    if len(sha256_values) != 1 or not isinstance(sha256_values[0], str):
        raise ReleaseError("SPDX file must have exactly one SHA256")
    return sha256_values[0]


def verify_bundle(bundle_directory: Path, *, require_clean: bool) -> None:
    if not bundle_directory.is_dir():
        raise ReleaseError(f"release bundle does not exist: {bundle_directory}")
    actual_bundle_files = {
        path.relative_to(bundle_directory).as_posix()
        for path in regular_files(bundle_directory)
    }
    if actual_bundle_files != EXPECTED_BUNDLE_FILES:
        missing = sorted(EXPECTED_BUNDLE_FILES - actual_bundle_files)
        unexpected = sorted(actual_bundle_files - EXPECTED_BUNDLE_FILES)
        raise ReleaseError(
            f"release bundle file set differs: missing={missing} unexpected={unexpected}"
        )

    checksums = parse_checksums(bundle_directory / CHECKSUMS_NAME)
    expected_checksum_paths = EXPECTED_BUNDLE_FILES - {CHECKSUMS_NAME}
    if set(checksums) != expected_checksum_paths:
        raise ReleaseError("SHA256SUMS does not cover the exact release bundle")
    for relative_path, expected_sha256 in sorted(checksums.items()):
        actual_sha256 = sha256_file(bundle_directory / relative_path)
        if actual_sha256 != expected_sha256:
            raise ReleaseError(f"release checksum mismatch: {relative_path}")

    provenance = read_json(bundle_directory / PROVENANCE_NAME)
    if provenance.get("result") != "pass" or provenance.get("violations") != []:
        raise ReleaseError("release provenance audit did not pass")
    signing = provenance.get("artifact", {}).get("signing", {})
    if not signing.get("signed") or not signing.get("valid"):
        raise ReleaseError("release provenance lacks a valid XCFramework signature")
    policy = provenance.get("policy")
    if not isinstance(policy, dict) or not isinstance(policy.get("lane"), str):
        raise ReleaseError("release provenance lacks a distribution lane")
    if signing.get("team_identifier") != policy.get("expected_team_identifier"):
        raise ReleaseError("release provenance has the wrong signing team")
    authorities = signing.get("authorities")
    required_authority_prefix = policy.get("required_signing_authority_prefix")
    if (
        not isinstance(required_authority_prefix, str)
        or not isinstance(authorities, list)
        or not any(
            isinstance(authority, str)
            and authority.startswith(required_authority_prefix)
            for authority in authorities
        )
    ):
        raise ReleaseError("release provenance has the wrong signing authority")
    toolchain = provenance.get("toolchain")
    if not isinstance(toolchain, dict):
        raise ReleaseError("release provenance lacks a toolchain tuple")
    expected_toolchain = policy.get("expected_toolchain")
    if not isinstance(expected_toolchain, dict) or set(expected_toolchain) != {
        "iphoneos_sdk_build",
        "metal_build_version",
        "xcode_build_version",
    }:
        raise ReleaseError("release policy lacks an exact toolchain tuple")
    for field_name, expected_value in expected_toolchain.items():
        if field_name == "metal_build_version":
            continue
        if toolchain.get(field_name) != expected_value:
            raise ReleaseError(
                f"release provenance has the wrong {field_name}"
            )
    metal_toolchain = toolchain.get("metal_toolchain")
    if not isinstance(metal_toolchain, dict) or metal_toolchain.get(
        "build_version"
    ) != expected_toolchain["metal_build_version"]:
        raise ReleaseError("release provenance has the wrong Metal toolchain")
    if require_clean and not provenance.get("toolchain", {}).get(
        "project_worktree_clean"
    ):
        raise ReleaseError("clean project worktree is required for release provenance")

    sbom = read_json(bundle_directory / SBOM_NAME)
    if sbom.get("spdxVersion") != SPDX_VERSION or sbom.get("dataLicense") != DATA_LICENSE:
        raise ReleaseError("unsupported SPDX document")
    packages = sbom.get("packages")
    if not isinstance(packages, list):
        raise ReleaseError("SPDX package list is missing")
    release_packages = [
        package
        for package in packages
        if isinstance(package, dict)
        and package.get("SPDXID") == "SPDXRef-Package-MojoIOSCore"
    ]
    if len(release_packages) != 1:
        raise ReleaseError("SPDX release package is missing or duplicated")
    release_package = release_packages[0]
    if release_package.get("licenseDeclared") != "Apache-2.0 WITH LLVM-exception":
        raise ReleaseError(
            "SPDX release package must declare Apache-2.0 WITH LLVM-exception"
        )
    package_checksums = release_package.get("checksums")
    if not isinstance(package_checksums, list):
        raise ReleaseError("SPDX release package checksum is missing")
    package_sha256_values = [
        checksum.get("checksumValue")
        for checksum in package_checksums
        if isinstance(checksum, dict) and checksum.get("algorithm") == "SHA256"
    ]
    archive_sha256 = sha256_file(bundle_directory / RELEASE_ARCHIVE_NAME)
    if package_sha256_values != [archive_sha256]:
        raise ReleaseError("SPDX release package checksum does not match the ZIP")
    project_revision = toolchain.get("project_revision")
    if not isinstance(project_revision, str) or not re.fullmatch(
        r"[0-9a-f]{40}", project_revision
    ):
        raise ReleaseError("release provenance project revision is invalid")
    if f"/sbom/{project_revision}/{archive_sha256}" not in sbom.get(
        "documentNamespace", ""
    ):
        raise ReleaseError("SPDX namespace does not bind revision and archive hash")

    spdx_files = sbom.get("files")
    if not isinstance(spdx_files, list):
        raise ReleaseError("SPDX file inventory is missing")
    spdx_hashes: dict[str, str] = {}
    for record in spdx_files:
        if not isinstance(record, dict) or not isinstance(record.get("fileName"), str):
            raise ReleaseError("invalid SPDX file record")
        file_name = validate_relative_path(record["fileName"]).as_posix()
        if file_name in spdx_hashes:
            raise ReleaseError(f"duplicate SPDX file: {file_name}")
        spdx_hashes[file_name] = checksum_from_spdx(record)

    archive_path = bundle_directory / RELEASE_ARCHIVE_NAME
    archive_hashes: dict[str, str] = {}
    with zipfile.ZipFile(archive_path) as archive:
        for zip_info in archive.infolist():
            archive_name = validate_relative_path(zip_info.filename).as_posix()
            if zip_info.is_dir():
                raise ReleaseError(f"release ZIP contains an unexpected directory: {archive_name}")
            if archive_name in archive_hashes:
                raise ReleaseError(f"duplicate release ZIP entry: {archive_name}")
            archive_hashes[archive_name] = sha256_bytes(archive.read(zip_info))
    if not archive_hashes or not all(
        path.startswith("MojoIOSCore.xcframework/") for path in archive_hashes
    ):
        raise ReleaseError("release ZIP must contain exactly one XCFramework root")

    supplemental_hashes = {
        path: sha256_file(bundle_directory / path)
        for path in (
            PROJECT_LICENSE_NAME,
            MODULAR_LICENSE_NAME,
            MODULAR_NOTICES_NAME,
            PROVENANCE_NAME,
            NOTICE_NAME,
        )
    }
    if spdx_hashes != archive_hashes | supplemental_hashes:
        raise ReleaseError("SPDX inventory does not match packaged files")
    notice_text = (bundle_directory / NOTICE_NAME).read_text(encoding="utf-8")
    for license_path in (
        PROJECT_LICENSE_NAME,
        MODULAR_LICENSE_NAME,
        MODULAR_NOTICES_NAME,
    ):
        license_sha256 = supplemental_hashes[license_path]
        if license_sha256 not in notice_text:
            raise ReleaseError(f"notice does not bind packaged license: {license_path}")


def verify(arguments: argparse.Namespace) -> None:
    verify_bundle(arguments.bundle.resolve(), require_clean=arguments.require_clean)
    print(
        "RELEASE_PROVENANCE_VERIFY_PASS "
        f"bundle={arguments.bundle.resolve()} clean_required={arguments.require_clean}"
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate_parser = subparsers.add_parser("generate")
    generate_parser.add_argument("--xcframework", required=True, type=Path)
    generate_parser.add_argument("--audit-report", required=True, type=Path)
    generate_parser.add_argument("--metadata", required=True, type=Path)
    generate_parser.add_argument("--output", required=True, type=Path)
    generate_parser.add_argument("--project-license", required=True, type=Path)
    generate_parser.add_argument("--source-date-epoch", required=True, type=int)
    generate_parser.add_argument("--upstream-revision", required=True, type=Path)
    generate_parser.add_argument("--upstream-root", required=True, type=Path)
    generate_parser.add_argument("--require-clean", action="store_true")
    generate_parser.set_defaults(action=generate)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("bundle", type=Path)
    verify_parser.add_argument("--require-clean", action="store_true")
    verify_parser.set_defaults(action=verify)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        arguments.action(arguments)
    except (OSError, ReleaseError, zipfile.BadZipFile) as error:
        print(f"RELEASE_PROVENANCE_FAIL detail={json.dumps(str(error))}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
