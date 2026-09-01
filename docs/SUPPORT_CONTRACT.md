# Initial support contract

This contract describes the currently proved feasibility surface. It is not yet
an arbitrary-Mojo or App Store-release contract. The work required to reach
those claims is defined in
[ARBITRARY_AOT_MOJO_PLAN.md](ARBITRARY_AOT_MOJO_PLAN.md), and current scoped
status is recorded in [CAPABILITY_LEDGER.md](CAPABILITY_LEDGER.md).

## Definition of working

A library author writes ordinary CPU Mojo, exports a deliberate C ABI, compiles
ahead of time on macOS, packages a static XCFramework, and calls it from Swift
on ARM64 iOS/iPadOS devices and simulators.

The author follows Mojo’s normal shared-library pattern by calling
`std.runtime.initialize_runtime()` at exported entry points. No iOS import,
branch, custom parallel API, or custom runtime initialization function is
required.

## Supported

- Scalars, SIMD, allocation, collections, argv, printing, random,
  clocks, environment, files, directory iteration, filesystem metadata,
  password lookup, locks, and CPU counts.
- Fixed-width C-compatible exports and pointer-based buffers.
- `max.algorithm.parallelize` with ordinary captured closures.
- The standard `sync_parallelize` → CPU `DeviceContext` → generic coroutine
  lowering route.
- Ordinary CPU `async def`, `await`, results, and raised errors through generic
  coroutine lowering and the standard AsyncRT chain ABI.
- Suspension and resumption on executor threads, including calls entered from
  Swift-owned threads.
- Repeated calls and simultaneous entry from Swift-owned threads.
- Copy/move/destruction, generics, trait dispatch, raised-error unwinding, C
  FFI, and C callbacks in the O0/O3 host, ARM64 Simulator, and physical-iPad
  conformance lanes.
- Standard immutable scalar, SIMD, and fixed-array `global_constant` storage.
- Standard Int32/Int64 CPU atomics, explicit memory ordering, fences,
  compare-exchange, real-worker contention, and release/acquire publication.
- All 68 operations in the pinned CompilerRT and DeviceContext C ABI have an
  implemented or compile-time-rejected disposition.
- Static device and simulator XCFramework variants.

Each item is limited to the operations instantiated by the positive gates. An
unlisted language, runtime, standard-library, ABI, Metal, or Core AI operation
must not be inferred from a nearby item.

## Explicitly unsupported

- Mutable module-level Mojo globals and public standard-library TLS are absent
  from the pinned upstream language surface. Mutable globals receive the same
  generic language diagnostic on host and iOS; this project does not add an
  iOS state API or C-owned substitute.
- Stable public task construction, cancellation, async I/O, and GPU-await. The
  upstream task substrate is currently private and these remaining operations
  are absent or unfinished generally; there is no iOS-specific substitute or
  rejection. Destroying an incomplete task asserts instead of detaching it.
- Production-wide Metal/GPU execution. The useful experimental MVP supports
  scalar captures, 3D dispatch, multi-kernel Mojo libraries, and static/dynamic
  threadgroup memory on Mac, Simulator, and physical iPad, but unlisted Metal
  resource classes and operations remain outside the support claim.
- General Core AI graph export, model packaging, and runtime integration. A
  fixed-shape direct-authoring/AOT/public-Swift feasibility slice passes with
  Xcode 27, including physical iPadOS 27 execution, but it is deliberately not
  linked to Mojo. The open-source MAX graph compiler/driver has no backend
  extension point for Core AI, so this project does not register a source-level
  Core AI target. Runtime-selected Core AI context creation fails explicitly,
  and no Core AI resource is part of the supported package.
- ANE-only execution. Core AI can prefer ANE but currently cannot require it or
  report per-operation residency. Private ANE compiler/runtime APIs are not an
  acceptable substitute.
- Python interoperability and subprocesses.
- Arbitrary dynamic-library loading.
- MAX AsyncRT time tracing. Standard `Trace` syntax that selects this backend
  fails with a named compile-time iOS diagnostic; other supported CPU async and
  Metal paths do not substitute for it.
- A Mojo compiler or JIT in the app, downloaded executable Mojo code, or
  runtime generation of new Mojo executable code. Device specialization of a
  shipped Metal or Core AI artifact by its public Apple framework is permitted
  system behavior and is not Mojo JIT.
- Unaudited target-sensitive stdlib surfaces.
- Production allocator, handle, reentrancy, and multi-library composition rules
  beyond the currently proved ownership, error, FFI, and callback slice.
- TestFlight acceptance, App Review acceptance, or release-support status.

Where the target determines support, an unsupported call must fail at compile
time. Runtime errors are reserved for inherently dynamic choices such as a
DeviceContext API string, device ID, or attribute. Silent fallback is never
permitted.

## ABI rules

- The public boundary is C, not Mojo’s internal ABI.
- Exported names are explicit and versionable.
- Public integers have fixed widths.
- Complex values cross as opaque handles or pointer-plus-length structures
  with documented ownership.
- The C header is the source of truth consumed by Swift.
- A Mojo `raises` effect never crosses the C ABI.

## Distribution status

The architecture is designed for ahead-of-time distribution: the app is not
intended to ship a Mojo compiler, JIT, or downloaded executable Mojo input.
That property is enforced by the current signed-archive audit.

[APP_STORE_DISTRIBUTION_GATE.md](APP_STORE_DISTRIBUTION_GATE.md) defines five
distinct stages: architecture-compliant, Xcode-validated, TestFlight-accepted,
App-Review-accepted, and release-supported. The current CPU/Metal artifact
passes local archive auditing, signing, export, privacy aggregation, provenance
checks, and Apple server validation. It has not been selected for TestFlight or
App Review. Core AI remains a separate Xcode 27/iOS 27 lane and is not part of
that distributed artifact.

iOS 15.0 is the current CPU/Metal feasibility deployment target, not yet a
final product minimum. The experimental public Core AI route requires iOS 27.
