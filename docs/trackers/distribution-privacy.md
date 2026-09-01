# Distribution privacy

Parent: [App Store distribution tracker](distribution.md)

- [x] **Current Required Reason API catalog**: The audit names Apple's five current categories and rejects unknown categories and reason codes; the catalog was reviewed on 2026-08-31. [gate](../PRIVACY_MANIFEST_GATE.md)
- [x] **Current shipped API inventory**: Every member and final executable in the CPU/Metal XCFramework, archive, and export is scanned; `sysctlbyname` for CPU count and monotonic clocks are recorded as outside Apple's current Required Reason API catalog. [gate](../PRIVACY_MANIFEST_GATE.md)
- [x] **Declaration ownership**: The SDK manifest owns Mojo/runtime behavior and the app manifest owns reference-app behavior; neither may satisfy the other's declaration.
- [x] **Static framework resource packaging**: Both XCFramework variants are static frameworks containing the SDK privacy manifest, headers, and module map without changing the standard Swift or Mojo surface.
- [x] **Manifest-content closure**: Current SDK and app manifests explicitly declare no tracking, domains, collected data, or Required Reason API categories, and the audit rejects missing, extra, misplaced, or divergent declarations.
- [x] **Privacy negative gates**: Named fixtures reject missing manifests, wrong ownership, unknown reasons, unexpected tracking or collection, variant divergence, and an undeclared file-timestamp API. [gate](../../scripts/test-distribution-audit.sh)
- [x] **Archive and export preservation**: The signed archive and Apple Distribution export contain the app and embedded SDK manifests and pass the deterministic archive audit. [gate](../../scripts/test-reference-archive.sh)
- [x] **Xcode aggregate report**: Xcode 26.6 generates a one-page empty privacy report for the current empty app and SDK declarations; deterministic bundle audits separately prove both manifests were consumed into the archive.
- [x] **Current Apple server revalidation**: Xcode 26.6 server validation accepts the static-framework and privacy-manifest archive without creating a TestFlight build or review submission. [gate](../../scripts/validate-reference-archive.sh)
