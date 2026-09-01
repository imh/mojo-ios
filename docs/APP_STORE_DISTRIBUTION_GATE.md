# App Store distribution gate

Status: **in progress; current privacy-packaged CPU/Metal archive passes local,
physical, signed-export, and Apple server-validation gates**.

This gate defines the evidence required before describing a Mojo iOS/iPadOS
artifact as App Store-ready. It complements compiler and runtime correctness;
it does not replace them. A successful local validation is not App Review
approval, and approval of one reference app does not approve every consuming
app's behavior, privacy declarations, entitlements, or content.

Apple's current public requirements are the authority:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Submitting apps](https://developer.apple.com/app-store/submitting/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Distributing apps for testing and release](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Verifying XCFramework origin](https://developer.apple.com/documentation/xcode/verifying-the-origin-of-your-xcframeworks)

The gate must be reviewed whenever Apple changes its SDK, upload, privacy, or
review requirements.

## Distribution lanes

### Stable base lane

The CPU and supported Metal artifact is built with an Apple toolchain accepted
for App Store production submission. It targets the selected base minimum OS
and includes device and ARM64 Simulator variants.

### Core AI preview lane

Core AI currently requires the Xcode 27 and iOS/iPadOS 27 generation. Beta
toolchain acceptance for internal or external TestFlight testing is recorded as
preview evidence only. It does not satisfy the stable App Store release gate.

The two lanes may share source and package architecture, but they never share a
release status implicitly.

## Current partial evidence

`pixi run test-distribution-audit` audits the current feasibility XCFramework.
`pixi run test-reference-archive` applies the same machinery to the complete
development-signed stable CPU/Metal reference `.xcarchive`, including its app
executable, signature, entitlements, embedded Metal libraries, app and SDK
privacy manifests, and nine named corruptions. `pixi run
export-reference-app-store` additionally produces and audits an Apple
Distribution-signed IPA with `get-task-allow=false`.

The Xcode 26.6 `validation` method is server-backed and requires
`destination=upload`. On 2026-08-31, Apple first rejected the reference app's
uncompiled asset catalog with named missing-icon and `CFBundleIconName`
diagnostics. After packaging the catalog through the normal Xcode resources
phase, `pixi run validate-reference-archive` succeeded for App Store Connect
app `6806924512`. App Store Connect still reported `No Builds` in TestFlight
and `Prepare for Submission` for the draft version, proving this validation
did not upload a distributable build or submit the app for review. That result
predates the static-framework privacy packaging and is not evidence for the
current archive. After correcting the consumer to Xcode's native static
framework file type, the current local archive, physical-device, Xcode privacy
report, distribution export, and Apple server revalidation all pass.

The current Required Reason API classification, ownership, packaging, and
negative evidence are recorded in the [privacy manifest
gate](PRIVACY_MANIFEST_GATE.md).

The Xcode 27 preview release-candidate SBOM, project and upstream notices,
signing, checksum, and two-build evidence are recorded in the [release
provenance gate](RELEASE_PROVENANCE_GATE.md). Together with the stable Xcode 26
archive and server validation, the project accepts this as complete M1
evidence. Each published release must still regenerate provenance from its
exact clean production tuple.

## Gate A: AOT and forbidden-content audit

The final app archive must contain no:

- Mojo source files;
- `.mojopkg` or compiler cache files;
- Mojo compiler or host compiler libraries;
- JIT support intended to generate executable host code;
- downloaded executable Mojo input;
- runtime path that creates new executable CPU code;
- Python runtime or import-time Mojo compilation machinery; or
- unapproved arbitrary dynamic-loading path.

The audit must inspect the complete archive, not only the XCFramework. Shipped
Metal and Core AI artifacts are listed and hashed explicitly. Specialization by
their public Apple frameworks is allowed system behavior, not Mojo JIT.

Required evidence:

- a machine-readable archive file inventory;
- forbidden extension and path scan;
- executable Mach-O inventory;
- dependency and load-command inventory; and
- hashes for every Mojo, runtime, Metal, and Core AI-derived artifact.

## Gate B: binary and public-API audit

For every Mach-O object and final executable:

- assert the intended platform and architecture;
- assert the declared minimum OS;
- enumerate undefined and exported symbols;
- reject project test hooks from release artifacts;
- reject accidental project-specific runtime ABI exports;
- enumerate linked dylibs and Apple frameworks;
- reject private frameworks and known private runtime/compiler interfaces;
- verify dead stripping and duplicate-symbol behavior; and
- retain the exact compiler, stdlib, MAX, SDK, Metal toolchain, and Core AI
  authoring compatibility tuple.

This source-level audit supplements Apple's validator. It does not claim to
predict every private-API review rule.

## Gate C: runtime release configuration

The release runtime must:

- be compiled without `ASYNCRT_ENABLE_TESTING` or equivalent test-only APIs;
- contain assertions required by the support contract;
- retain no probe entry points or marker strings that are not production API;
- initialize through the normal upstream runtime interface;
- define process-wide or package-wide singleton ownership explicitly;
- compose correctly when more than one Mojo library is linked; and
- pass release-equivalent O0/O3, lifecycle, foreign-thread, and sanitizer
  tests before the uninstrumented artifact is built.

Instrumented runtime archives are test products and must have distinct paths
and names so they cannot be packaged accidentally.

## Gate D: privacy and sandbox audit

Generate an inventory of every system API reached transitively by the Mojo
standard library, MAX library, Apple runtime, Swift wrapper, Metal runtime, and
any future standard Core AI backend runtime.

For every Required Reason API category:

- identify the exact calling capability;
- determine whether the SDK or consuming app must declare the reason;
- select only an Apple-approved reason justified by actual behavior;
- add the declaration to `PrivacyInfo.xcprivacy`; and
- add a test that fails when the API inventory and manifest diverge.

The manifest must also describe data collection performed by the distributed
library, if any. A reference manifest cannot absolve a consuming application
from its own declarations.

Filesystem tests must operate inside permitted containers. Networking,
background execution, files, environment access, and other sandbox-sensitive
surfaces require operation-specific execution and negative tests.

## Gate E: package, signing, and provenance

- Package device and Simulator variants with no invalid slice.
- Package resource ownership explicitly; do not rely on a static archive to
  discover adjacent resources.
- Include the privacy manifest in the correct app, framework, or Swift package
  resource location.
- Sign distributable XCFrameworks and record the expected signer or certificate
  fingerprint.
- Generate license notices and a dependency/SBOM inventory.
- Record deterministic artifact hashes and the source revision.
- Verify the consuming project detects a changed or missing XCFramework
  signature.
- Sign the reference application with a distribution-capable identity and
  provisioning configuration appropriate to the validation lane.

## Gate F: archive validation ladder

Record each stage independently:

1. **architecture-compliant**: local audits A through E pass;
2. **xcode-validated**: the signed archive passes Xcode's App Store validation;
3. **testflight-accepted**: App Store Connect accepts the build for the named
   internal or external TestFlight lane;
4. **app-review-accepted**: Apple accepts a reference application using the
   artifact; and
5. **release-supported**: the capability manifest names exactly the features,
   target lanes, toolchain tuple, and artifact hashes covered by the release.

No earlier stage may be described using the name of a later stage. Xcode
validation is explicitly a limited automated check. App Review acceptance is
external evidence and can change with the consuming app or later Apple policy.

## Required negative gates

The distribution suite must prove that it rejects at least:

- an archive containing a `.mojo` or `.mojopkg` file;
- a compiler or JIT-linked Mach-O image;
- a release runtime built with test hooks;
- an undeclared Required Reason API category;
- a private framework or prohibited ANE runtime symbol;
- an unexpected dynamic library dependency;
- a mismatched platform, architecture, or minimum OS;
- an unsigned or unexpectedly re-signed distributable XCFramework;
- a missing Metal or Core AI resource declared by the package manifest; and
- evidence generated with a mismatched toolchain compatibility tuple.

Each failure must name the offending file, symbol, capability, or manifest
entry.

## Completion criteria

The stable base lane passes when:

- all local audits and their negative tests pass;
- the release runtime is distinct from instrumented test artifacts;
- a signed CPU/Metal reference app archive passes Xcode validation;
- its exact capability and target matrix is recorded; and
- no documentation describes Core AI preview evidence as part of that stable
  release.

The Core AI lane advances independently after an Apple production submission
toolchain exists, package resource composition is complete, public device
execution passes, and the corresponding signed archive completes the same
validation ladder.
