# Release provenance gate

Status: **M1 provenance scope passes in the accepted Xcode 27 preview lane**.
The production-Xcode refresh is required before publishing an artifact built
with that production tuple, but is not an M1 blocker.

This gate packages the ordinary CPU/Metal XCFramework without changing its
Mojo, MAX, Swift, or C surface. It produces an Xcode 27 preview release
candidate containing:

- an Apple Developer-signed `MojoIOSCore.xcframework.zip`;
- an SPDX 2.3 SBOM;
- the complete distribution audit as `PROVENANCE.json`;
- the repository's Apache 2.0 license with LLVM exception;
- the exact pinned Modular license and upstream third-party notice bundle;
- a scope notice distinguishing redistributed code from Apple build and system
  dependencies; and
- SHA-256 coverage for every release-candidate file, compatible with Swift
  Package Manager's binary-target checksum.

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
MOJO_IOS_XCFRAMEWORK_SIGNING_IDENTITY='<identity>' \
MOJO_IOS_REQUIRE_CLEAN_RELEASE=0 \
pixi run build-release-candidate

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
MOJO_IOS_RELEASE_PROVENANCE_SKIP_BUILD=1 \
pixi run test-release-provenance
```

`MOJO_IOS_REQUIRE_CLEAN_RELEASE=0` is a development-only escape hatch. The
release command defaults to requiring a clean tree, and the verifier rejects a
dirty provenance report when `--require-clean` is selected.

## SBOM and notice scope

The SPDX document inventories every file inside the signed XCFramework and the
packaged notice/provenance files. Its component graph records:

- `MojoIOSCore` at the exact project revision;
- the pinned `modular/modular` revision and patch stack;
- Xcode, iPhoneOS SDK, and Metal toolchain as build dependencies; and
- Apple frameworks and system libraries as runtime dependencies that are not
  redistributed.

The pinned Modular checkout declares `Apache-2.0 WITH LLVM-exception`. The
release candidate conservatively includes Modular's complete license and
third-party notice bundle because notice-level reachability pruning has not
been proved. The Swift package currently has no external Swift package
dependencies.

This repository and its `MojoIOSCore` package declare
`Apache-2.0 WITH LLVM-exception`. The exact repository `LICENSE` is packaged,
hashed, named in the human-readable notice, and declared on the release package
in the SPDX document. Modular's identically named license remains a separate,
independently hashed upstream file.

## Signing and checksum evidence

The current preview candidate is signed by Apple development team
`24D3YSDU5R`. The audit requires the expected team and an `Apple Development:`
authority, and rejects unsigned and ad-hoc re-signed candidates. The generated
ZIP retains a valid signature after extraction. Its recorded SHA-256 equals
`swift package compute-checksum`.

This proves current signing and origin-verification mechanics. It does not
promote the beta toolchain to general App Store production support or define
the final public release identity; those claims remain specific to each
published release.

Apple documents the two independent consumer checks used here: the
[XCFramework signing identity](https://developer.apple.com/documentation/xcode/verifying-the-origin-of-your-xcframeworks)
and the remote Swift binary target's
[archive checksum](https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages).

## Reproducibility evidence

`pixi run test-release-reproducibility` invokes the existing source compiler,
runtime, and packaging path in two isolated build roots. The first run exposed
two nondeterministic packaging details:

1. Apple `ar` preserved archive member timestamps. Static archives now use
   Apple's supported `libtool -static -D` reproducible mode.
2. Xcode 27 emitted XCFramework `AvailableLibraries` in unstable order. A
   packaging-only normalizer now sorts variants by `LibraryIdentifier` and
   serializes the plist canonically.

After those corrections, the two unsigned XCFramework trees are byte-for-byte
identical. The current development proof recorded unsigned tree SHA-256
`4ce51f945aa0a50bad927b0526285993e06c185bf74b93851ed511d7a65580fe`.
Two timestamped Apple signatures produced the same full CodeDirectory SHA-256
`818528433c02ceb56e51d6772769fd76489b25dba41bb140c6103c881fd772b2`.

The rebuilt deterministic artifact also passes all ten Swift-package tests on
both an iPhone Simulator and iPad Simulator. On the physical M1 iPad it passes
scalar/list/global behavior, standard `parallelize`, Swift-owned foreign
threads, language async suspension/results/errors, and the useful Metal MVP.

The timestamped CMS signature envelope is deliberately excluded from
byte-for-byte reproducibility: its trusted timestamp must vary. Reproducibility
therefore means identical unsigned payload plus identical signed CodeDirectory,
while each published ZIP gets its own exact retained SHA-256.

The current proof ran from the implementation worktree and is explicitly named
`RELEASE_REPRODUCIBILITY_DEVELOPMENT_PASS`. It proves that two isolated builds
from the same source state produce identical unsigned payloads and signed
CodeDirectories. A published release must repeat the gate from its clean exact
revision and production-accepted toolchain; by project decision, that
release-time refresh is not an M1 blocker.

## Negative gates

The suite rejects:

- a corrupted XCFramework ZIP;
- a missing Modular license;
- a missing project license;
- an SPDX document that substitutes a different project license;
- dirty provenance when clean evidence is required;
- an unsigned XCFramework; and
- an ad-hoc re-signed XCFramework.

## Post-M1 publication boundary

Before publishing a production release:

1. replace the beta compatibility tuple with the production-accepted tuple;
2. run the two-build gate from the exact clean release revision; and
3. pin and verify the chosen public XCFramework signing identity in consumer
   Xcode evidence.

These are per-release publication obligations tracked under release
sustainability, not blockers for the completed M1 distribution foundation.
