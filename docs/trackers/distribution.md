# App Store distribution

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [ ] **AOT content audit**: Scan the complete archive for Mojo source/packages, compiler/JIT components, executable downloads, Python machinery, and undeclared accelerator artifacts.
- [ ] **Binary and public-API audit**: Audit Mach-O platforms, architectures, deployment targets, load commands, symbols, dependencies, entitlements, private frameworks, and private runtime interfaces.
- [ ] **Privacy manifest**: Package `PrivacyInfo.xcprivacy` and prove Required Reason API closure against the shipped surface.
- [ ] **Licenses, SBOM, and provenance**: Emit dependency, notice, toolchain tuple, and deterministic artifact-hash records.
- [ ] **Xcode validation**: Build and sign a stable-toolchain reference archive and pass App Store validation.
- [ ] **Stable TestFlight acceptance**: Record App Store Connect acceptance separately from local validation.
- [ ] **Core AI preview submission**: Toolchain-gated; beta evidence may not be promoted to stable release support.
- [ ] **Reference App Review**: Retain acceptance evidence without implying approval of every consumer application.

See the [distribution evidence ladder](../APP_STORE_DISTRIBUTION_GATE.md).
