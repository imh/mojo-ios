# App Store distribution

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [ ] **AOT content audit**: Scan the complete archive for Mojo source/packages, compiler/JIT components, executable downloads, Python machinery, and undeclared accelerator artifacts.
  - [x] **Current XCFramework inventory**: Every shipped file has a deterministic path, type, mode, size, and SHA-256 record. [gate](../../scripts/test-distribution-audit.sh)
  - [x] **Static archive members**: Every `.a` member has a hash; every Mach-O member records architecture, build version, load commands, dependencies, and symbols.
  - [x] **Current forbidden-content policy**: The XCFramework gate rejects Mojo/Python input, compiler/JIT/dynamic-loader symbols, test controls, private ANE interfaces, and undeclared accelerator artifacts.
  - [ ] **Final application archive content**: Apply the same inventory and policy to the complete release `.xcarchive`, including its app and resources.
- [ ] **Binary and public-API audit**: Audit Mach-O platforms, architectures, deployment targets, load commands, symbols, dependencies, entitlements, private frameworks, and private runtime interfaces.
  - [x] **Current XCFramework slices**: Device and Simulator archives and every member match the declared ARM64 platform and iOS 15 feasibility target.
  - [x] **Negative audit fixtures**: Named corruptions prove rejection of source, test/private/compiler/Python/dynamic-loader symbols, wrong platform/minimum OS, unexpected slices, and dependencies.
  - [ ] **Final executable, signing, and entitlements**: Audit the release app executable, embedded code, load graph, signature, entitlements, exports, and undefined symbols.
- [ ] **Privacy manifest**: Package `PrivacyInfo.xcprivacy` and prove Required Reason API closure against the shipped surface.
- [ ] **Licenses, SBOM, and provenance**: Emit dependency, notice, toolchain tuple, and deterministic artifact-hash records. [tracker](distribution-provenance.md)
- [ ] **Xcode validation**: Build and sign a stable-toolchain reference archive and pass App Store validation.
- [ ] **Stable TestFlight acceptance**: Record App Store Connect acceptance separately from local validation.
- [ ] **Core AI preview submission**: Toolchain-gated; beta evidence may not be promoted to stable release support.
- [ ] **Reference App Review**: Retain acceptance evidence without implying approval of every consumer application.

See the [distribution evidence ladder](../APP_STORE_DISTRIBUTION_GATE.md).
