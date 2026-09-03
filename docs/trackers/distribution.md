# App Store distribution

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

The current shipped slice passes its named gates. Unchecked work here is
verification or external acceptance, not a known runtime/compiler enablement
gap.

## Verification and external acceptance

- [ ] **AOT content audit**: Scan the complete archive for Mojo source/packages, compiler/JIT components, executable downloads, Python machinery, and undeclared accelerator artifacts.
  - [x] **Current XCFramework inventory**: Every shipped file has a deterministic path, type, mode, size, and SHA-256 record. [gate](../../scripts/test-distribution-audit.sh)
  - [x] **Static archive members**: Every `.a` member has a hash; every Mach-O member records architecture, build version, load commands, dependencies, and symbols.
  - [x] **Current forbidden-content policy**: The XCFramework gate rejects Mojo/Python input, compiler/JIT/dynamic-loader symbols, test controls, private ANE interfaces, and undeclared accelerator artifacts.
  - [x] **Reference application archive content**: The complete stable CPU/Metal `.xcarchive` and Apple Distribution-exported app bundle have deterministic inventories and pass the local forbidden-content policy. [gate](../../scripts/test-reference-archive.sh)
- [ ] **Binary and public-API audit**: Audit Mach-O platforms, architectures, deployment targets, load commands, symbols, dependencies, entitlements, private frameworks, and private runtime interfaces.
  - [x] **Current XCFramework slices**: Device and Simulator archives and every member match the declared ARM64 platform and iOS 15 feasibility target.
  - [x] **Negative audit fixtures**: Named corruptions prove rejection of source, test/private/compiler/Python/dynamic-loader symbols, wrong platform/minimum OS, unexpected slices, and dependencies.
  - [x] **Reference executable, signing, and entitlements**: The ARM64 executable, embedded Metal libraries, load graph, symbols, strict signature, expected team, and entitlement allowlist pass for both the archive and distribution export. [gate](../../scripts/export-reference-app-store.sh)
- [x] **Privacy manifest**: Current package, inventory, ownership, negative, physical, Xcode-report, signed-export, and Apple server-validation gates pass for the shipped CPU/Metal surface. [tracker](distribution-privacy.md)
- [x] **Licenses, SBOM, and provenance**: The accepted M1 package emits project and upstream licenses, an SPDX dependency inventory, exact toolchain provenance, deterministic payload evidence, and artifact hashes. [tracker](distribution-provenance.md)
- [x] **Xcode validation**: The privacy-packaged stable CPU/Metal reference app builds, executes on the physical iPad, exports with Apple Distribution signing, and passes server validation for this exact archive. [tracker](distribution-validation.md)
- [ ] **Stable TestFlight acceptance**: Record App Store Connect acceptance separately from local validation.
- [ ] **Reference App Review**: Retain acceptance evidence without implying approval of every consumer application.

## Blocked

- [ ] **Core AI preview submission**: Toolchain-gated; beta evidence may not be promoted to stable release support.

See the [distribution evidence ladder](../APP_STORE_DISTRIBUTION_GATE.md).
