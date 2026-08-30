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

## Distribution and ABI

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `artifact.mojo-aot` | **supported** | The proved artifact compiles Mojo on macOS and ships only ahead-of-time CPU objects and accelerator artifacts. Archive-wide forbidden-content enforcement is tracked separately by `store.aot-content-audit`. |
| `artifact.static-xcframework` | **supported** | Separate ARM64 device and Simulator libraries are packaged in a static XCFramework for the current sample product. Release resource and privacy composition remain `artifact.release-package`. |
| `artifact.release-package` | **project gap** | Produce a versioned release package with release-only runtime objects, explicit Metal/Core AI resource ownership, privacy resources, notices, provenance, and reproducible hashes. |
| `artifact.signed-xcframework` | **project gap** | Sign the distributable XCFramework and verify that consumers detect a missing or changed signature. |
| `abi.swift-c` | **supported** | The current fixed-width scalar and pointer-buffer sample exports cross a deliberate C ABI. Mojo's internal ABI and `raises` effects do not cross this boundary. |
| `abi.ownership-errors-callbacks` | **project gap** | Specify and gate strings, slices, opaque handles, allocator ownership, errors, callbacks, reentrancy, Swift concurrency, and ABI versioning. |
| `abi.multi-library-composition` | **project gap** | Link and execute more than one independently compiled Mojo library without duplicate runtime symbols, conflicting global state, or ambiguous shutdown ownership. |
| `runtime.apple-embedded` | **supported** | CompilerRT and AsyncRT implement the normal upstream ABI operations instantiated by the current CPU, parallel, async, and Metal probes without project-specific initialization exports. This is not a complete ABI census. |
| `runtime.abi-census` | **project gap** | Inventory the complete pinned CompilerRT/AsyncRT ABI and classify every operation as implemented, statically rejected, or dynamically error-returning. |
| `runtime.release-build` | **project gap** | Build the shipped runtime without `ASYNCRT_ENABLE_TESTING` or other test hooks while retaining a distinctly named instrumented test product. |
| `runtime.lifecycle` | **project gap** | Gate repeated initialization, teardown, global destruction, executor shutdown, app suspension/background behavior, foreign-thread entry, and release-equivalent sanitizer behavior. |
| `artifact.apple-specialization` | **allowed architecture** | Public Apple frameworks may specialize shipped Metal or Core AI artifacts for a device. This is system-owned implementation behavior, not Mojo JIT. |

See [SUPPORT_CONTRACT.md](SUPPORT_CONTRACT.md) and
[FEASIBILITY_GATE.md](FEASIBILITY_GATE.md).

## CPU language, runtime, and standard library

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `cpu.language-core` | **supported** | The proved scalar, SIMD, allocation, collection, global, argument, repeated-call, and simultaneous Swift-owned-thread probes pass device and Simulator gates at O0/O3. Unlisted language families are not implied. |
| `cpu.language-conformance` | **project gap** | Cross-compile, fully link, and execute an upstream-derived corpus covering ownership/destruction, generics, traits, errors, TLS, atomics, callbacks, FFI, math intrinsics, and optimization-sensitive language families. |
| `cpu.parallelize` | **supported** | `max.algorithm.parallelize` uses the unchanged `sync_parallelize` to CPU `DeviceContext` to generic coroutine-lowering route with ordinary captured closures. |
| `cpu.closure-existing-paths` | **supported** | The captured closures exercised by CPU parallelism and Metal scalar capture use normal unified-closure paths. |
| `cpu.closure-remaining` | **project gap** | Inventory all closure-like standard-library, MAX, callback, and offload APIs. Each must use the general unified-closure representation or fail at its ordinary upstream boundary. |
| `stdlib.audited-apple-surface` | **supported** | Printing, random, clocks, environment, files, directory iteration, metadata, password lookup, locks, and CPU counts are positively gated. |
| `stdlib.target-sensitive-remaining` | **project gap** | Generate an exhaustive source inventory, including indirect libc and native dependencies. Each operation needs a normal Darwin implementation, an operation-specific compile-time rejection, or an explicit outside-artifact disposition. |
| `stdlib.required-reason-api-audit` | **project gap** | Map every transitive Required Reason API use to an atomic capability and keep the privacy manifest synchronized with the implemented surface. |
| `interop.python` | **explicit failure** | Python interoperability is rejected at compile time for iOS. It becomes supportable only through an upstream-compatible static architecture. |
| `process.subprocess` | **explicit failure** | Subprocess creation is rejected at compile time. |
| `loader.dynamic-library` | **explicit failure** | Arbitrary dynamic-library loading is rejected at compile time. |

See [CONCURRENCY_GATE.md](CONCURRENCY_GATE.md) and
[IOS_TARGET_POLICY_AUDIT.md](IOS_TARGET_POLICY_AUDIT.md).

## Async

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `async.language` | **supported** | Ordinary `async def`, `await`, results, raised errors, suspension, and executor-thread resumption use generic coroutine lowering and the normal AsyncRT chain ABI. |
| `async.task-public-api` | **upstream gap** | Task construction currently lives in upstream's private `_asyncrt` module. Adopt the eventual public upstream API without an Apple-specific substitute. |
| `async.cancellation` | **upstream gap** | Require upstream semantics, generic lowering, Apple AsyncRT implementation, race/lifetime assertions, and positive and negative tests. |
| `async.io` | **upstream gap** | Require a general Mojo async-I/O surface and its normal runtime operations; do not introduce an iOS API. |
| `async.gpu-await` | **upstream gap** | Require general accelerator-await semantics shared by supported backends and explicit lifetime/error propagation. |

See [ASYNC_GATE.md](ASYNC_GATE.md).

## Metal programmable accelerator backend

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `metal.air-codegen` | **experimental** | Apple AIR is a peer offload target; LLVM 17 bitcode is packaged as `metallib` through the normal compiler interfaces. |
| `metal.dispatch-and-indexing` | **experimental** | X/Y/Z builtins, 3D dispatch, buffers, copies, synchronization, and ordinary enqueue paths execute on Mac, Simulator, and physical iPad. |
| `metal.arguments-and-captures` | **experimental** | Direct buffers, scalar and aggregate values, nested device-pointer fixups, and captured scalar closures are gated. General variadic unified-closure inference remains a project gap. |
| `metal.multikernel` | **experimental** | Several kernels can coexist in one Mojo library without concatenating opaque archives. |
| `metal.threadgroup-memory` | **experimental** | Static and dynamic threadgroup memory have explicit AIR lowering and runtime validation. |
| `metal.argument-inference` | **project gap** | Generalize variadic unified-closure argument inference and gate every supported constant, aggregate, pointer, and buffer layout. |
| `metal.resources-remaining` | **project gap** | Textures, samplers, and every other unlisted resource class require explicit compiler lowering, runtime ABI representation, ownership, and device tests. |
| `metal.atomics-barriers-simdgroups` | **project gap** | Add explicit AIR lowering and memory-model tests for supported atomics, barriers, simdgroup operations, and ordering semantics. |
| `metal.launch-controls` | **project gap** | Add only controls with defined Metal semantics. CUDA-only attributes continue to fail by name. |
| `metal.o0-pipeline` | **project gap** | Define and gate a distinct valid AIR O0/debug pipeline rather than aliasing or silently changing optimization semantics. |
| `metal.tensorops` | **project gap** | Add public Metal tensor and TensorOps operations through a normal backend/library abstraction, including quantized types and explicit availability checks. |
| `metal.gpu-neural-accelerator` | **hardware dependent** | TensorOps may use neural accelerators in A19/M5 GPU shader cores. This is Metal GPU execution and must never be reported as standalone ANE execution. |

See [METAL_FEASIBILITY_GATE.md](METAL_FEASIBILITY_GATE.md).

## Core AI and Apple Neural Engine

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `coreai.direct-authoring-api` | **platform gap** | Apple's documented beta tutorial still imports operation builders and `Value` from underscored `coreai._compiler` modules; production backend work requires their promised public `coreai.authoring` export or another documented stable graph-construction API. |
| `coreai.graph-export` | **experimental** | A direct fixed-shape Float32 `batch_matmul` plus `relu` graph verifies and saves as `.aimodel` without PyTorch or an iOS-facing Mojo API. This proves only the named graph. |
| `coreai.mojo-graph-lowering` | **experimental** | Ordinary standard `linalg.matmul[target="coreai"]` calls form one fixed two-operation region at O0/O3 without an Apple-facing Mojo API. General operation, shape, dtype, layout, effect, and partition conversion remains a project gap; arbitrary host code is not graph input. |
| `coreai.aot-specialization` | **experimental** | Xcode 27 `coreai-build` compiles the probe for eight iOS architecture families with Neural Engine preferred; inspected `h13g` metadata names M1 and iOS 27. |
| `coreai.artifact-packaging` | **experimental** | The Swift package preserves the fixed `.aimodel` directory beside the XCFramework with deterministic hashes and toolchain provenance; eight `.aimodelc` specializations are also emitted. Release versioning and explicit compiled-specialization shipping/selection policy remain gaps. |
| `coreai.host-runtime` | **experimental** | Apple's Python runtime produces exact results for sequential, simultaneous, invalid-shape, teardown, and reload tests of the probe graph. This is development-host evidence, not the public iOS Swift runtime gate. |
| `coreai.swift-runtime` | **experimental** | The generated bridge uses the public Core AI API, caches the lightweight model, loads a distinct function per request, and completes into AsyncRT. The standard-Mojo slice passes three physical stress runs, each with ten rounds of exact eight-way concurrent results, on an M1 iPad Pro running iPadOS 27 beta 7. Broader device negative and lifetime coverage remains. |
| `coreai.swift-async-caller` | **project gap** | The current exported Mojo entry point is synchronous and passes concurrent blocking calls from GCD-owned Swift threads. Add a generated async Swift adapter before calling it directly from arbitrary Swift cooperative-executor tasks; saturating that executor with blocking `Task.detached` calls can deadlock completion. |
| `coreai.simulator-runtime` | **platform gap** | Xcode 27's iPhone Simulator SDK has no `CoreAI.framework`; importing CoreAI fails by name. No CPU or Metal simulator substitute is permitted. |
| `coreai.apple-specialization` | **allowed architecture** | Device- and OS-specific specialization performed by the public Core AI framework is permitted. No Mojo compiler or executable Mojo input is shipped. |
| `coreai.unsupported-graph-op` | **experimental** | Wrong graph cardinality, disconnected input, unsupported MVP shape, dynamic dimensions, observable effects, and unknown calls are named compile failures in the fixed region pass. Exhaustive standard-operation coverage remains a project gap. |
| `coreai.ane-preferred` | **project gap** | AOT compilation and public Swift code represent Neural Engine preference. Retain Instruments evidence on physical iPadOS 27 hardware before claiming preferred/eligible execution. |
| `coreai.ane-only` | **platform gap** | Apple exposes neither enforceable ANE-only execution nor per-operation runtime placement. Do not claim pure ANE until both selection and observability are public. |
| `ane.direct-backend` | **platform gap** | Do not use private `ANECompiler`, `AppleNeuralEngine`, Espresso, or `aned` interfaces. Reconsider only when Apple publishes a documented, distributable compiler/runtime API. |

Core AI's documented scheduling across CPU, GPU, and ANE is part of the selected
Core AI backend's semantics. It does not turn a failed Mojo lowering into a
project-controlled fallback. Where exact ANE residency matters, the current
platform gap is an explicit unsupported capability.

See [COREAI_FEASIBILITY_GATE.md](COREAI_FEASIBILITY_GATE.md).

## Target and hardware matrix

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `matrix.ios-device-base` | **experimental** | CPU, parallel, async, and useful-Metal-MVP probes execute on the current physical M1 iPad. The final minimum and latest stable OS lanes are not yet defined. |
| `matrix.ios-simulator-arm64` | **experimental** | CPU and Metal probes run on ARM64 iPhone and iPad Simulators. Core AI remains an explicit platform gap on Simulator. |
| `matrix.physical-a-series-iphone` | **project gap** | Add a physical A-series iPhone lane before making a broad iOS CPU/Metal hardware claim. |
| `matrix.physical-m-series-ipad` | **experimental** | The useful Metal MVP executes on a physical M1 iPad. Expand to the final minimum/latest OS policy and retain exact device evidence. |
| `matrix.coreai-ios27-device` | **experimental** | The public Core AI Swift gate passes on `iPad13,9` (M1) with iPadOS 27 beta 7 build `24A5424a`, covered by the `h13g` specialization. Retain Instruments placement evidence and add another supported hardware lane before broadening the claim. |
| `matrix.base-minimum-os` | **not claimed** | iOS 15 is a feasibility target only. Select and gate the product minimum independently from Core AI's iOS 27 availability. |

## App Store distribution

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

| ID | Status | Current boundary and completion gate |
| --- | --- | --- |
| `upstream.complete-source-delta` | **supported** | The current pinned upstream delta is completely represented by the reviewed patch and the apply script rejects unrecorded checkout edits. |
| `upstream.reviewable-patch-series` | **project gap** | Split generic coroutine/closure fixes, Darwin policy, CompilerRT, AsyncRT CPU, Metal backend/runtime, and tests into independently reviewable patches. Core AI remains a later series. |
| `upstream.compatibility-tuple-ci` | **project gap** | Rebase and test the compiler revision, stdlib, MAX, Apple SDK, Metal toolchain, and Core AI authoring package as one reported compatibility tuple. |
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
