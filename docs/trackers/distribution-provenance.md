# Distribution provenance

Parent: [App Store distribution tracker](distribution.md)

- [x] **Current XCFramework hashes**: The evidence report hashes every file, static archive, and archive member, including every Mojo/runtime-derived object.
- [x] **Current compatibility tuple**: Evidence records the project revision and worktree state, pinned upstream revision and patch hashes, source compiler hash, stdlib/MAX presence, Xcode, SDK, Swift, Clang, installed Metal-component identity and frontend probe, deployment target, and optimization level.
- [x] **Current binary dependency inventory**: Every inspected Mach-O member records its load commands and linked dependencies under the current feasibility policy.
- [ ] **Dependency SBOM**: Produce a release dependency inventory with component identities, versions, relationships, and hashes beyond the current binary evidence.
- [ ] **License notices**: Collect and package all required project, upstream, runtime, Swift-package, and Apple-toolchain notices for the release artifact.
- [ ] **Release reproducibility**: Prove release artifacts, reports, and hashes reproduce from the recorded clean compatibility tuple; deterministic reporting alone is insufficient.
