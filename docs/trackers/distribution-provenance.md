# Distribution provenance

Parent: [App Store distribution tracker](distribution.md)

- [x] **Current XCFramework hashes**: The evidence report hashes every file, static archive, and archive member, including every Mojo/runtime-derived object.
- [x] **Current compatibility tuple**: Evidence records the project revision and worktree state, pinned upstream revision and patch hashes, source compiler hash, stdlib/MAX presence, Xcode, SDK, Swift, Clang, installed Metal-component identity and frontend probe, deployment target, and optimization level.
- [x] **Current binary dependency inventory**: Every inspected Mach-O member records its load commands and linked dependencies under the current feasibility policy.
- [x] **Reference application evidence**: The CPU/Metal XCFramework, complete `.xcarchive`, and Apple Distribution-exported app record file hashes, executable metadata, embedded Metal counts, signatures, entitlements, and the exact stable Xcode/SDK/Metal tuple.
- [x] **Dependency SBOM**: The signed Xcode 27 preview candidate emits an SPDX 2.3 inventory of every packaged file, the pinned Modular source/runtime, and non-redistributed Apple build and system dependencies. [gate](../RELEASE_PROVENANCE_GATE.md)
- [x] **License notices**: The repository and release package declare Apache 2.0 with LLVM exception; the exact project and Modular licenses plus complete upstream notice bundle are packaged, independently hashed, and verified. [gate](../RELEASE_PROVENANCE_GATE.md)
- [x] **Release reproducibility**: Two isolated Xcode 27 preview builds produce byte-identical unsigned XCFrameworks and identical signed CodeDirectories; exact clean-revision and published-ZIP evidence is deliberately regenerated for each production release. [gate](../RELEASE_PROVENANCE_GATE.md)
