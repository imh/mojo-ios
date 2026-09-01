# Privacy manifest gate

Status: **passed for the current stable CPU/Metal reference surface**.

This gate covers the currently shipped stable CPU/Metal reference artifact. It
does not claim that every future standard-library or MAX operation has already
been audited. Adding a native call or dependency requires extending the API
inventory and either declaring its exact Apple-approved reason or rejecting the
artifact before packaging.

## Current public API boundary

Apple's public Required Reason API catalog was reviewed on 2026-08-31. The
auditor models the five current categories explicitly:

- file timestamps;
- system boot time;
- disk space;
- active keyboards; and
- user defaults.

The shipped Mojo/runtime objects call `sysctlbyname` only for physical CPU
counts and use monotonic clocks for waits and timeouts. Neither operation is in
Apple's current Required Reason API catalog. The current SDK and reference app
therefore both declare empty accessed-API and collected-data arrays, no
tracking, and no tracking domains. This is a positive declaration of the
current behavior, not an absent manifest or an exemption for consuming apps.

The catalog is deliberately closed. Unknown categories or reason codes fail the
audit; changes to Apple's catalog require an explicit policy and fixture update.

## Ownership and packaging

Mojo, MAX, CompilerRT, AsyncRT, and Apple backend behavior belongs to the SDK
manifest. Reference-app behavior belongs to the app manifest. The audit does
not permit one bundle's manifest to satisfy the other bundle's calls.

Static archives cannot carry discoverable bundle resources. Each device and
Simulator XCFramework variant is therefore a static `MojoIOSCore.framework`
whose root contains:

- the static Mojo/runtime archive;
- public headers and a framework module map;
- `Info.plist`; and
- `PrivacyInfo.xcprivacy`.

This is Apple packaging around the existing static ABI. It adds no Mojo import,
target-specific source path, runtime initializer, graph API, or fallback.

The consuming Xcode project identifies the artifact with Xcode's
`wrapper.framework.static` file type. Xcode 26.6 omits the source static archive
because the implementation is already linked into the app, then emits an empty
signed Mach-O placeholder at the framework executable path. The archive audit
requires exactly that native result: no symbols, the declared target, only
allowed system dependencies, and no application load command for the
placeholder. A copied archive, implementation-bearing dylib, or project-owned
resource carrier fails.

## Evidence

`pixi run test-distribution-audit` checks both XCFramework variants and runs 16
named negative fixtures. `pixi run test-reference-archive` checks the signed
archive and runs nine named archive corruptions. The same policy audits the
Apple Distribution export. The current CPU, language-async, and standard Mojo
Metal paths still execute on the physical M1 iPad.

Xcode 26.6 generated a one-page empty aggregate privacy report, which is the
expected rendering for the two empty declarations. Because that rendering alone
cannot prove which input manifests Xcode found, the deterministic archive audit
separately requires the app-root and embedded SDK paths and their exact content.

Xcode 26.6 server validation accepts the current static-framework and
privacy-manifest archive. The validation-only method did not create a TestFlight
build or submit the app for review. Validation remains distinct from TestFlight
acceptance and App Review.
