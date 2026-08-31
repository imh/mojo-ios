# Mojo for iOS and iPadOS

This project builds ordinary ahead-of-time Mojo libraries for Swift apps as a
static XCFramework with distinct ARM64 device and simulator variants. The
compiler runs on macOS; no compiler, JIT, or downloaded executable code runs in
the app.

The current repository proves a useful feasibility surface; it does not yet
claim arbitrary Mojo coverage or an App Store-validated release artifact. The
canonical completion plan is
[docs/ARBITRARY_AOT_MOJO_PLAN.md](docs/ARBITRARY_AOT_MOJO_PLAN.md), with current
scoped status in [docs/CAPABILITY_LEDGER.md](docs/CAPABILITY_LEDGER.md) and the
distribution evidence ladder in
[docs/APP_STORE_DISTRIBUTION_GATE.md](docs/APP_STORE_DISTRIBUTION_GATE.md).

The architecture deliberately keeps platform knowledge out of application
Mojo. Library authors use the normal APIs:

- `std.runtime.initialize_runtime()` at exported shared-library entry points;
- explicit `@export` C ABI functions;
- `max.algorithm.parallelize` for synchronous captured-closure CPU work;
- ordinary `async def` and `await` syntax through the standard coroutine and
  AsyncRT lowering path;
- `DeviceContext(api="metal")` and ordinary Mojo kernels for the experimental
  Metal feasibility slice;
- ordinary supported stdlib APIs.

There is no iOS parallel API, closure bridge, runtime-initialization export, or
serial fallback. Apple-specific behavior is confined to upstream-shaped
CompilerRT, AsyncRT, and Darwin stdlib backends in the pinned Modular patch.

## Current boundary

Supported and gated now:

- scalar code, allocation, collections, globals, arguments, printing, random,
  environment access, clocks, files, Darwin filesystem metadata and directory
  iteration, password lookup, locks, and CPU-count queries;
- `max.algorithm.parallelize` through its unchanged `sync_parallelize` → CPU
  `DeviceContext` → generic coroutine-lowering route;
- CPU async functions, suspension/resumption, results, and raised errors through
  generic coroutine lowering and the normal AsyncRT ABI;
- simultaneous calls from Swift-owned threads;
- iPhone/iPadOS device and ARM64 Simulator slices at O0 and O3.

The Metal feasibility slice uses the same `DeviceContext`, `DeviceBuffer`,
kernel compilation, and enqueue APIs as other accelerators. Its useful MVP now
supports explicit and captured scalar values, X/Y/Z builtins and 3D launches,
several kernels in one Mojo library, and static/dynamic threadgroup memory. The
same lowering and embedded AsyncRT Metal runtime execute correctly against a
Mac GPU, an M4 iPad Simulator GPU, and a physical M1 iPad Pro GPU.

Core AI currently has a deliberately separate Apple feasibility probe, not a
Mojo backend. Direct graph authoring, eight iOS AOT specializations, host
numerical execution, public-Swift device builds, and physical M1 iPad execution
pass. The probe demonstrates the public Apple toolchain and runtime only; it is
not shipped in the Mojo XCFramework or Swift package. The project does not
register `target="coreai"`, a public Core AI device label,
or a pseudo-context ahead of the generic graph-compiler/driver extension needed
for a real backend. Runtime-selected Core AI context creation fails explicitly.
There is no fixed-graph compiler pass, project-specific runtime ABI, or
CPU/Metal fallback.

Deliberately unsupported target-sensitive calls fail during compilation with
the operation named in the diagnostic:

- Python interoperability;
- subprocesses;
- arbitrary dynamic-library loading.

The current upstream task construction APIs are private and unfinished even on
host platforms. This project supports the existing `_asyncrt` task substrate
without changing its Mojo-facing interface or claiming it as a stable public
API. Cancellation, async I/O, and GPU-await have no implemented general Mojo
surface yet; attempts to use them fail during normal source analysis rather
than at an iOS-specific branch. Destroying an incomplete task is asserted
instead of silently detaching it.

Concrete launch attributes in the current upstream API are CUDA-only. Metal
accepts `IGNORE` and rejects every other identifier by name before dispatch.
Unimplemented Metal resource classes and operations remain explicit boundaries.
There is no CPU fallback.

Unsupported runtime-selected DeviceContext APIs and attributes return explicit
owned errors because their support decision is inherently dynamic.

## Upstream ownership

`patches/modular/0001-add-apple-embedded-runtime-and-ios-target-policy.patch`
contains the complete upstream delta:

- explicit iOS and shared Darwin target classification;
- Darwin ABI reuse only where the Apple SDKs prove the layout/API is shared;
- compile-time rejection at unimplemented stdlib/runtime boundaries;
- Apple AIR target registration, intrinsic lowering, LLVM 17 bitcode emission,
  and `metallib` packaging behind the normal offload backend interfaces;
- dependency-light embedded Apple CompilerRT and CPU/Metal DeviceContext
  targets.

The generated iOS objects import the same standard runtime ABI as other
targets. Metal adds a normal target backend and AIR legalization pipeline; it
does not add an iOS Mojo API.

## Build and verify

On a fresh checkout:

```sh
pixi run checkout-upstream
pixi run build-upstream-compiler
pixi run test-source-compiler-host
pixi run test-upstream-runtime-build
```

Build and test the mobile artifact:

```sh
pixi run test-supported-runtime-surface
pixi run test-unsupported-ios-targets
pixi run test-language-async
pixi run test-upstream-parallelize-lowering
MOJO_IOS_METAL_COMPILER_PATH=/path/to/metal \
MOJO_IOS_METAL_SIMULATOR_ID=BOOTED_SIMULATOR_UDID \
  pixi run test-metal-feasibility
pixi run test-compilerrt-host
pixi run test-asyncrt-host
pixi run test-compilerrt-tsan
pixi run test-asyncrt-tsan
pixi run build-source-core
pixi run verify-core
pixi run build-swift-smoke
pixi run test-swift-simulators
```

The Core AI gate uses Xcode 27 side by side and leaves global `xcode-select`
unchanged:

```sh
pixi run bootstrap-coreai-authoring
MOJO_IOS_COREAI_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  pixi run test-coreai-feasibility
pixi run test-coreai-target-contract
MOJO_IOS_COREAI_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  pixi run build-coreai-mvp-resources
MOJO_IOS_COREAI_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  pixi run build-coreai-device-smoke
```

The default artifact is O3. Use
`MOJO_IOS_OPTIMIZATION_LEVEL=0 pixi run build-source-core` for the debug gate.

The physical-device gate requires a development team and CoreDevice ID:

```sh
MOJO_IOS_DEVELOPMENT_TEAM=YOUR_TEAM_ID pixi run build-device-smoke
MOJO_IOS_DEVELOPMENT_TEAM=YOUR_TEAM_ID \
MOJO_IOS_CORE_DEVICE_ID=YOUR_CORE_DEVICE_ID \
  pixi run test-swift-device

MOJO_IOS_METAL_COMPILER_PATH=/path/to/metal \
MOJO_IOS_DEVELOPMENT_TEAM=YOUR_TEAM_ID \
MOJO_IOS_CORE_DEVICE_ID=YOUR_CORE_DEVICE_ID \
  pixi run test-metal-device

MOJO_IOS_COREAI_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
MOJO_IOS_DEVELOPMENT_TEAM=YOUR_TEAM_ID \
MOJO_IOS_CORE_DEVICE_ID=YOUR_CORE_DEVICE_ID \
  pixi run test-coreai-device
```

See `docs/SUPPORT_CONTRACT.md` for the contract,
`docs/FEASIBILITY_GATE.md` for the CPU evidence boundary, and
`docs/ASYNC_GATE.md` for language-async architecture and evidence,
`docs/METAL_FEASIBILITY_GATE.md` for the experimental Metal slice,
`docs/COREAI_FEASIBILITY_GATE.md` for the experimental Core AI slice,
`docs/COREAI_MVP_GATE.md` for the standard-backend architectural gate,
`docs/CAPABILITY_LEDGER.md` for the canonical gap inventory, and
`docs/ARBITRARY_AOT_MOJO_PLAN.md` for the canonical end-to-end plan,
`docs/APP_STORE_DISTRIBUTION_GATE.md` for the release evidence ladder, and
`docs/ROADMAP.md` for the compact milestone order and Xcode toolchain policy.
