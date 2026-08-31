# Capability ledger

This is the canonical current-status inventory for the goal of running
ahead-of-time Mojo in an App Store-distributed iOS or iPadOS library. Detailed
evidence remains in the feature gate documents linked from each section. The
roadmap refers to the stable capability IDs in this ledger rather than
restating support claims. The complete destination and work order are defined
in [ARBITRARY_AOT_MOJO_PLAN.md](ARBITRARY_AOT_MOJO_PLAN.md).

A **supported** row is scoped to the operations stated in that row. It is never
evidence for an unlisted language, runtime, standard-library, ABI, backend, or
distribution operation. In particular, the current supported rows do not yet
constitute an arbitrary-Mojo or App Store-release claim.

The hardware model has three peer execution routes:

1. ordinary host code lowers to AArch64 CPU code;
2. programmable accelerator kernels lower through AIR to Metal;
3. static tensor/model graphs lower to Core AI IR, allowing the public Core AI
   runtime to schedule work across CPU, GPU, and Apple Neural Engine (ANE).

Core AI is not a fallback for failed Metal lowering, and Metal is not a fallback
for failed Core AI graph conversion. A computation must satisfy the semantics
of its selected backend or fail with a named diagnostic.

## Progressive-disclosure contract

This ledger is the canonical tracker root. It covers the complete objective at
the subsystem level without pretending that every subsystem has already been
inventoried to individual operations.

Every node below has one of three tracker dispositions:

- **items here**: its table contains current child capabilities or gaps;
- **delegated**: it points to a deeper gate or tracker that owns the children;
- **not decomposed yet**: the remaining surface is explicitly unclaimed until
  work reaches that node.

A section may have current items plus a `not decomposed yet` remainder. Following
a link must eventually reach items or that explicit boundary. Deeper trackers
must remain linked from this hierarchy and may not become independent sources
of support status.

## Top-level coverage index

| Root node | Complete scope | Current expansion |
| --- | --- | --- |
| `track.mojo-language-compiler` | Mojo language semantics, frontend, elaboration, generic lowering, CPU code generation | **items here** in [Mojo language and generic compiler lowering](#mojo-language-and-generic-compiler-lowering), with an explicit undecomposed conformance remainder |
| `track.stdlib-native` | Standard library, libc, Darwin APIs, native dependencies, compile-time rejection policy | **items here and delegated** to [Standard library and native dependencies](#standard-library-and-native-dependencies) and [IOS_TARGET_POLICY_AUDIT.md](IOS_TARGET_POLICY_AUDIT.md) |
| `track.max-standard` | Standard MAX Mojo libraries, algorithms, tensor/graph operations, device selection, and runtime behavior | **items here** in [Standard MAX surface](#standard-max-surface), with explicit undecomposed Mojo-library and graph/runtime remainders |
| `track.embedded-runtime` | CompilerRT and AsyncRT ABI operations, allocation/runtime support, initialization, globals, work queues, and lifecycle | **items here** in [Embedded runtime ABI and lifecycle](#embedded-runtime-abi-and-lifecycle) |
| `track.asyncrt-concurrency` | CPU parallelism, coroutines, AsyncRT, tasks, cancellation, async I/O, accelerator await | **items here and delegated** to [Async and concurrency](#async-and-concurrency), [CONCURRENCY_GATE.md](CONCURRENCY_GATE.md), and [ASYNC_GATE.md](ASYNC_GATE.md) |
| `track.swift-abi-artifacts` | C/Swift boundary, ownership, multi-library composition, and XCFramework construction | **items here** in [AOT artifacts and Swift/C ABI](#aot-artifacts-and-swiftc-abi) |
| `track.metal` | Standard programmable GPU path, AIR lowering, Metal runtime, resources, operations, and synchronization | **items here and delegated** to [Metal programmable accelerator backend](#metal-programmable-accelerator-backend) and [METAL_FEASIBILITY_GATE.md](METAL_FEASIBILITY_GATE.md) |
| `track.coreai` | Standard MAX graph conversion, Core AI artifacts/runtime, ANE scheduling claims | **items here and delegated** to [Core AI and Apple Neural Engine](#core-ai-and-apple-neural-engine), [COREAI_MVP_GATE.md](COREAI_MVP_GATE.md), and [COREAI_FEASIBILITY_GATE.md](COREAI_FEASIBILITY_GATE.md) |
| `track.targets` | SDK, OS, deployment minimum, device/Simulator, CPU and hardware-family lanes | **items here** in [Target and hardware matrix](#target-and-hardware-matrix) |
| `track.distribution` | AOT content, privacy, public APIs, provenance, validation, TestFlight, App Review | **items here and delegated** to [App Store distribution](#app-store-distribution) and [APP_STORE_DISTRIBUTION_GATE.md](APP_STORE_DISTRIBUTION_GATE.md) |
| `track.upstream-evidence` | Patch ownership, non-iOS compatibility, compatibility tuple, gates, and tracker integrity | **items here** in [Upstream and release sustainability](#upstream-and-release-sustainability), with tracker implementation delegated to milestone M0 |

## Status vocabulary

- **supported**: inside the support contract and continuously test-gated;
- **experimental**: implemented and proven for the named slice, but not a
  general support claim;
- **project gap**: the normal architecture exists and this project must add a
  lowering, runtime operation, packaging step, or test;
- **upstream gap**: the general Mojo surface is absent, private, or unfinished;
- **platform gap**: no suitable public Apple API currently exists;
- **toolchain gated**: an available Apple SDK/toolchain is required before the
  project can implement or verify the capability;
- **explicit failure**: deliberately rejected at the earliest reliable boundary
  with the operation named in the diagnostic;
- **allowed architecture**: permitted by the support contract, but not itself
  an independently user-selectable capability;
- **hardware dependent**: public semantics are stable, but acceleration depends
  on the selected device generation;
- **not claimed**: not yet audited; use must not be inferred from nearby rows.

No status authorizes a fallback. A project, upstream, platform, or toolchain gap
must remain an explicit failure until its completion gate is met.

These labels predate the normalized tracking model. Milestone M0 will replace
the overloaded single status with independent disposition, maturity, blocker,
and target-lane fields. This Markdown ledger remains the sole status source
until the validated TOML manifests and generated views land together.

## AOT artifacts and Swift/C ABI

Tracker disposition: **items here**. Unspecified ABI families remain inside the
explicit ownership/callback and multi-library gap rows.

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `artifact.mojo-aot` | **supported** | The proved artifact compiles Mojo on macOS and ships only ahead-of-time CPU objects and accelerator artifacts. Archive-wide forbidden-content enforcement is tracked separately by `store.aot-content-audit`. |
| `artifact.static-xcframework` | **supported** | Separate ARM64 device and Simulator libraries are packaged in a static XCFramework for the current sample product. Release resource and privacy composition remain `artifact.release-package`. |
| `artifact.release-package` | **project gap** | Produce a versioned release package with release-only runtime objects, explicit Metal/Core AI resource ownership, privacy resources, notices, provenance, and reproducible hashes. |
| `artifact.signed-xcframework` | **project gap** | Sign the distributable XCFramework and verify that consumers detect a missing or changed signature. |
| `abi.swift-c` | **supported** | The current fixed-width scalar and pointer-buffer sample exports cross a deliberate C ABI. Mojo's internal ABI and `raises` effects do not cross this boundary. |
| `abi.ownership-errors-callbacks` | **project gap** | Specify and gate strings, slices, opaque handles, allocator ownership, errors, callbacks, reentrancy, Swift concurrency, and ABI versioning. |
| `abi.multi-library-composition` | **project gap** | Link and execute more than one independently compiled Mojo library without duplicate runtime symbols, conflicting global state, or ambiguous shutdown ownership. |
| `artifact.apple-specialization` | **allowed architecture** | Public Apple frameworks may specialize shipped Metal or Core AI artifacts for a device. This is system-owned implementation behavior, not Mojo JIT. |

See [SUPPORT_CONTRACT.md](SUPPORT_CONTRACT.md),
[FEASIBILITY_GATE.md](FEASIBILITY_GATE.md), and
[APP_STORE_DISTRIBUTION_GATE.md](APP_STORE_DISTRIBUTION_GATE.md).

## Embedded runtime ABI and lifecycle

Tracker disposition: **items here**. `runtime.abi-census` is the explicit
**not decomposed yet** remainder for upstream runtime operations not reached by
current probes.

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `runtime.apple-embedded` | **supported** | CompilerRT and AsyncRT implement the normal upstream ABI operations instantiated by the current CPU, parallel, async, and Metal probes without project-specific initialization exports. This is not a complete ABI census. |
| `runtime.abi-census` | **project gap — not decomposed yet** | The complete pinned CompilerRT/AsyncRT operation set has not yet been unpacked. When work reaches this node, classify each reached family as implemented, statically rejected, or dynamically error-returning through the normal ABI. No coverage beyond current probes is claimed. |
| `runtime.release-build` | **supported** | Shipped device and Simulator archives omit `ASYNCRT_ENABLE_TESTING`; artifact verification rejects every `AsyncRT_Test_` export. Instrumented overlap and TSan executables are built separately under the host test gates. |
| `runtime.lifecycle` | **project gap** | Gate repeated initialization, teardown, global destruction, executor shutdown, app suspension/background behavior, foreign-thread entry, and release-equivalent sanitizer behavior. |

See [CONCURRENCY_GATE.md](CONCURRENCY_GATE.md) and
[ASYNC_GATE.md](ASYNC_GATE.md).

## Mojo language and generic compiler lowering

Tracker disposition: **items here**. `cpu.language-conformance` and
`cpu.closure-remaining` retain the explicit undecomposed remainders.

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `cpu.language-core` | **supported** | The proved scalar, SIMD, allocation, collection, global, argument, repeated-call, and simultaneous Swift-owned-thread probes pass device and Simulator gates at O0/O3. Unlisted language families are not implied. |
| `cpu.language-conformance` | **project gap — not decomposed yet** | The remaining upstream language/compiler test families have not yet been unpacked. Progressively add ownership/destruction, generics, traits, errors, TLS, atomics, callbacks, FFI, math intrinsics, and optimization-sensitive families as corpus nodes, with host non-regression and iOS target evidence. |
| `cpu.closure-existing-paths` | **supported** | The captured closures exercised by CPU parallelism and Metal scalar capture use normal unified-closure paths. |
| `cpu.closure-remaining` | **project gap — not decomposed yet** | Closure-like standard-library, MAX, callback, and offload families beyond current probes have not yet been unpacked. Each discovered child must use the general unified-closure representation or fail at its ordinary upstream boundary. |

## Standard library and native dependencies

Tracker disposition: **items here and delegated** to
[IOS_TARGET_POLICY_AUDIT.md](IOS_TARGET_POLICY_AUDIT.md).
`stdlib.target-sensitive-remaining` is the explicit undecomposed remainder.

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `stdlib.audited-apple-surface` | **supported** | Printing, random, clocks, environment, files, directory iteration, metadata, password lookup, locks, and CPU counts are positively gated. |
| `stdlib.target-sensitive-remaining` | **project gap — not decomposed yet** | Target-sensitive standard-library, indirect libc, and native-dependency families beyond the audited surface have not yet been unpacked. Each discovered child needs a normal Darwin implementation, an operation-specific compile-time rejection, or an explicit outside-artifact disposition. |
| `stdlib.required-reason-api-audit` | **project gap** | Map every transitive Required Reason API use to an atomic capability and keep the privacy manifest synchronized with the implemented surface. |
| `interop.python` | **explicit failure** | Python interoperability is rejected at compile time for iOS. It becomes supportable only through an upstream-compatible static architecture. |
| `process.subprocess` | **explicit failure** | Subprocess creation is rejected at compile time. |
| `loader.dynamic-library` | **explicit failure** | Arbitrary dynamic-library loading is rejected at compile time. |

## Standard MAX surface

Tracker disposition: **items here**. The two remainder rows make MAX coverage
explicit without flattening the entire upstream library and graph stack now.

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `cpu.parallelize` | **supported** | Standard `max.algorithm.parallelize` uses the unchanged `sync_parallelize` → CPU `DeviceContext` → generic coroutine-lowering route with ordinary captured closures. |
| `max.mojo-library-remaining` | **not claimed — not decomposed yet** | Standard MAX Mojo libraries, algorithms, tensor operations, and device utilities beyond capabilities named elsewhere in this ledger have not yet been unpacked. Add children from upstream public surfaces and tests as work reaches them; do not infer support from `max.algorithm.parallelize` or Metal probes. |
| `max.graph-runtime-remaining` | **upstream gap — not decomposed yet** | Standard MAX graph construction, compilation, model/runtime, and backend-selection behavior has not yet been unpacked for iOS. The open graph compiler/driver is incomplete for third-party backend registration; Core AI-specific work is delegated to `coreai.mojo-graph-lowering`. No project-specific graph API or compiler abstraction is permitted. |

## Async and concurrency

Tracker disposition: **items here and delegated** to
[CONCURRENCY_GATE.md](CONCURRENCY_GATE.md) and [ASYNC_GATE.md](ASYNC_GATE.md).

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `async.language` | **supported** | Ordinary `async def`, `await`, results, raised errors, suspension, and executor-thread resumption use generic coroutine lowering and the normal AsyncRT chain ABI. |
| `async.task-public-api` | **upstream gap** | Task construction currently lives in upstream's private `_asyncrt` module. Adopt the eventual public upstream API without an Apple-specific substitute. |
| `async.cancellation` | **upstream gap** | Require upstream semantics, generic lowering, Apple AsyncRT implementation, race/lifetime assertions, and positive and negative tests. |
| `async.io` | **upstream gap** | Require a general Mojo async-I/O surface and its normal runtime operations; do not introduce an iOS API. |
| `async.gpu-await` | **upstream gap** | Require general accelerator-await semantics shared by supported backends and explicit lifetime/error propagation. |

See [ASYNC_GATE.md](ASYNC_GATE.md).

## Metal programmable accelerator backend

Tracker disposition: **items here and delegated** to
[METAL_FEASIBILITY_GATE.md](METAL_FEASIBILITY_GATE.md). Unlisted Metal resource
and operation families remain explicitly undecomposed below.

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `metal.air-codegen` | **experimental** | Apple AIR is a peer offload target; LLVM 17 bitcode is packaged as `metallib` through the normal compiler interfaces. |
| `metal.dispatch-and-indexing` | **experimental** | X/Y/Z builtins, 3D dispatch, buffers, copies, synchronization, and ordinary enqueue paths execute on Mac, Simulator, and physical iPad. |
| `metal.arguments-and-captures` | **experimental** | Direct buffers, scalar and aggregate values, nested device-pointer fixups, and captured scalar closures are gated. General variadic unified-closure inference remains a project gap. |
| `metal.multikernel` | **experimental** | Several kernels can coexist in one Mojo library without concatenating opaque archives. |
| `metal.threadgroup-memory` | **experimental** | Static and dynamic threadgroup memory have explicit AIR lowering and runtime validation. |
| `metal.argument-inference` | **project gap** | Generalize variadic unified-closure argument inference and gate every supported constant, aggregate, pointer, and buffer layout. |
| `metal.resources-remaining` | **project gap — not decomposed yet** | Textures, samplers, and other unlisted resource families have not yet been fully unpacked. Each reached child requires explicit compiler lowering, runtime ABI representation, ownership, and device tests. |
| `metal.atomics-barriers-simdgroups` | **project gap** | Add explicit AIR lowering and memory-model tests for supported atomics, barriers, simdgroup operations, and ordering semantics. |
| `metal.launch-controls` | **project gap** | Add only controls with defined Metal semantics. CUDA-only attributes continue to fail by name. |
| `metal.o0-pipeline` | **project gap** | Define and gate a distinct valid AIR O0/debug pipeline rather than aliasing or silently changing optimization semantics. |
| `metal.metal4-air2.8` | **explicit gap** | Metal 4 accelerator names are not registered by the open backend while it emits AIR 2.4 metadata. Add them only with a versioned AIR 2.8 lowering and validation matrix. |
| `metal.tensorops` | **project gap** | Add public Metal tensor and TensorOps operations through a normal backend/library abstraction, including quantized types and explicit availability checks. |
| `metal.gpu-neural-accelerator` | **hardware dependent** | TensorOps may use neural accelerators in A19/M5 GPU shader cores. This is Metal GPU execution and must never be reported as standalone ANE execution. |

See [METAL_FEASIBILITY_GATE.md](METAL_FEASIBILITY_GATE.md).

## Core AI and Apple Neural Engine

Tracker disposition: **items here and delegated** to
[COREAI_MVP_GATE.md](COREAI_MVP_GATE.md) for the standard-backend boundary and
[COREAI_FEASIBILITY_GATE.md](COREAI_FEASIBILITY_GATE.md) for the isolated Apple
feasibility evidence.

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `coreai.direct-authoring-api` | **platform gap** | Apple's documented beta tutorial still imports operation builders and `Value` from underscored `coreai._compiler` modules; production backend work requires their promised public `coreai.authoring` export or another documented stable graph-construction API. |
| `coreai.graph-export` | **experimental** | A direct fixed-shape Float32 `batch_matmul` plus `relu` graph verifies and saves as `.aimodel` without PyTorch or an iOS-facing Mojo API. This proves only the named graph. |
| `coreai.mojo-graph-lowering` | **upstream gap** | The open-source MAX tree exposes standard graph construction but not the graph compiler/driver extension needed to register a Core AI backend. The project therefore does not register `coreai` as a source-level target. Do not substitute fixed semantic markers, an LLVM pattern pass, or a project-specific Mojo API. |
| `coreai.aot-specialization` | **experimental** | Xcode 27 `coreai-build` compiles the probe for eight iOS architecture families with Neural Engine preferred; inspected `h13g` metadata names M1 and iOS 27. |
| `coreai.artifact-packaging` | **project gap** | The direct feasibility gate emits deterministic `.aimodel` and `.aimodelc` outputs under `build/`, but they are not shipped in the Swift package. Packaging belongs to a future standard MAX backend and requires versioning, ownership, and compiled-specialization selection policy. |
| `coreai.host-runtime` | **experimental** | Apple's Python runtime produces exact results for sequential, simultaneous, invalid-shape, teardown, and reload tests of the probe graph. This is development-host evidence, not the public iOS Swift runtime gate. |
| `coreai.swift-runtime` | **experimental direct probe** | A standalone app uses only public Core AI Swift APIs, loads a distinct function per request, and passes physical-device sequential and concurrent numerical tests. It does not link Mojo, AsyncRT, or a project bridge and proves no Mojo backend integration. |
| `coreai.swift-async-caller` | **upstream gap** | A future standard MAX backend must define how graph submission and completion compose with the normal runtime. The direct Swift probe is not that contract. |
| `coreai.simulator-runtime` | **platform gap** | Xcode 27's iPhone Simulator SDK has no `CoreAI.framework`; importing CoreAI fails by name. No CPU or Metal simulator substitute is permitted. |
| `coreai.apple-specialization` | **allowed architecture** | Device- and OS-specific specialization performed by the public Core AI framework is permitted. No Mojo compiler or executable Mojo input is shipped. |
| `coreai.unsupported-graph-op` | **upstream gap** | There is no Core AI graph lowering to dispatch to until the standard backend extension exists. A future backend must diagnose each unsupported operation, dtype, shape, layout, and effect during ordinary graph conversion. Runtime-selected `DeviceContext(api="coreai")` creation currently fails explicitly rather than falling back. |
| `coreai.ane-preferred` | **project gap** | AOT compilation and public Swift code represent Neural Engine preference. Retain Instruments evidence on physical iPadOS 27 hardware before claiming preferred/eligible execution. |
| `coreai.ane-only` | **platform gap** | Apple exposes neither enforceable ANE-only execution nor per-operation runtime placement. Do not claim pure ANE until both selection and observability are public. |
| `ane.direct-backend` | **platform gap** | Do not use private `ANECompiler`, `AppleNeuralEngine`, Espresso, or `aned` interfaces. Reconsider only when Apple publishes a documented, distributable compiler/runtime API. |

Core AI's documented scheduling across CPU, GPU, and ANE is part of the selected
Core AI backend's semantics. It does not turn a failed Mojo lowering into a
project-controlled fallback. Where exact ANE residency matters, the current
platform gap is an explicit unsupported capability.

See [COREAI_FEASIBILITY_GATE.md](COREAI_FEASIBILITY_GATE.md).

## Target and hardware matrix

Tracker disposition: **items here**. Add lanes progressively when a capability
requires a new OS, SDK, simulator, CPU, or hardware-family distinction.

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `matrix.ios-device-base` | **experimental** | CPU, parallel, async, and useful-Metal-MVP probes execute on the current physical M1 iPad. The final minimum and latest stable OS lanes are not yet defined. |
| `matrix.ios-simulator-arm64` | **experimental** | CPU and Metal probes run on ARM64 iPhone and iPad Simulators. Core AI remains an explicit platform gap on Simulator. |
| `matrix.physical-a-series-iphone` | **project gap** | Add a physical A-series iPhone lane before making a broad iOS CPU/Metal hardware claim. |
| `matrix.physical-m-series-ipad` | **experimental** | The useful Metal MVP executes on a physical M1 iPad. Expand to the final minimum/latest OS policy and retain exact device evidence. |
| `matrix.coreai-ios27-device` | **experimental** | The public Core AI Swift gate passes on `iPad13,9` (M1) with iPadOS 27 beta 7 build `24A5424a`, covered by the `h13g` specialization. Retain Instruments placement evidence and add another supported hardware lane before broadening the claim. |
| `matrix.base-minimum-os` | **not claimed** | iOS 15 is a feasibility target only. Select and gate the product minimum independently from Core AI's iOS 27 availability. |

## App Store distribution

Tracker disposition: **items here and delegated** to
[APP_STORE_DISTRIBUTION_GATE.md](APP_STORE_DISTRIBUTION_GATE.md).

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `store.aot-content-audit` | **project gap** | Scan the complete app archive for Mojo source/packages, compiler or JIT components, executable downloads, runtime-generated CPU code, Python import machinery, and undeclared accelerator artifacts. |
| `store.binary-public-api-audit` | **project gap** | Audit every Mach-O platform, architecture, minimum OS, load command, exported/undefined symbol, dependency, entitlement, private framework, and prohibited private runtime interface. |
| `store.privacy-manifest` | **project gap** | Package `PrivacyInfo.xcprivacy` in the correct product resource location and prove that its Required Reason API inventory matches the transitive shipped surface. |
| `store.license-sbom` | **project gap** | Emit dependency, license-notice, provenance, compatibility-tuple, and deterministic artifact-hash records for a release. |
| `store.xcode-validation` | **project gap** | Build and sign a stable-toolchain reference app archive and pass Xcode's App Store validation. Record this separately from TestFlight and App Review. |
| `store.testflight-stable` | **project gap** | Obtain App Store Connect acceptance for the stable CPU/Metal reference build in the named TestFlight lane. |
| `store.testflight-coreai-preview` | **toolchain gated** | Xcode 27 beta builds may provide preview TestFlight evidence only; do not treat it as stable App Store release evidence. |
| `store.app-review-reference` | **project gap** | Retain acceptance evidence for a reference app without implying that every consuming app, entitlement, privacy declaration, or later Apple policy is approved. |

See [APP_STORE_DISTRIBUTION_GATE.md](APP_STORE_DISTRIBUTION_GATE.md).

## Upstream and release sustainability

Tracker disposition: **items here**. Machine-readable tracker implementation
is delegated to M0 in [ROADMAP.md](ROADMAP.md#m0-truthful-tracking-foundation).

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `upstream.complete-source-delta` | **supported** | The current pinned upstream delta is completely represented by the reviewed patch and the apply script rejects unrecorded checkout edits. |
| `upstream.reviewable-patch-series` | **project gap** | Split generic coroutine/closure fixes, Darwin policy, CompilerRT, AsyncRT CPU, Metal backend/runtime, and tests into independently reviewable patches. Core AI remains a later series. |
| `upstream.non-ios-regression` | **project gap — not decomposed yet** | Generic compiler, library, and runtime changes have not yet been mapped to a complete set of existing non-iOS host and accelerator regression lanes. Add the relevant upstream test family as each patch node is unpacked; an iOS-only passing gate is insufficient for a generic-fix claim. |
| `upstream.compatibility-tuple-ci` | **project gap** | Rebase and test the compiler revision, stdlib, MAX, Apple SDK, Metal toolchain, and Core AI authoring package as one reported compatibility tuple. |
| `tracking.progressive-structure` | **supported** | Root `AGENTS.md` requires the recursive items/delegation/not-decomposed contract, and `verify-tracker-structure.sh` checks all root divisions, delegated documents, explicit remainders, canonical links, and known stale-status regressions. This interim Markdown gate is replaced, not duplicated, by M0's manifest validator. |
| `tracking.machine-readable-manifest` | **project gap** | Replace the overloaded Markdown status with validated capability, target, and gate TOML manifests plus generated ledger, gap, evidence, contract, and roadmap views. |

## Advancement rule

A capability advances to **supported** only when all applicable evidence exists:

1. the ordinary Mojo or graph API compiles without an Apple source branch;
2. unsupported neighboring operations have named compile-time diagnostics;
3. device and Simulator artifacts package and link through their normal route;
4. positive execution passes on every claimed hardware class;
5. O0/O3, concurrency, ownership, error, and sanitizer gates are added in
   proportion to the feature;
6. no CPU, Metal, Core AI, or serial fallback masks a missing implementation;
7. the upstream patch remains small, generic where possible, and contains the
   complete source delta;
8. release runtime objects contain no test-only configuration; and
9. distribution claims complete the corresponding evidence stage in
   [APP_STORE_DISTRIBUTION_GATE.md](APP_STORE_DISTRIBUTION_GATE.md).
