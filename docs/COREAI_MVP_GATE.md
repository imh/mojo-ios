# Standard-Mojo Core AI MVP gate

## Supported preview slice

This gate proves one deliberately fixed vertical slice:

```text
ordinary linalg.matmul[target="coreai"] calls
  -> backend-neutral semantic markers
  -> generic Core AI region formation
  -> fixed AsyncRT region submission
  -> public Swift Core AI runtime
  -> packaged .aimodel resource
```

The source fixture uses `TileTensor`, `row_major`, `linalg.matmul`,
`DeviceContext(api="coreai")`, and `synchronize()`. It contains no Apple import,
iOS branch, graph-builder API, project accelerator wrapper, or fallback.

The current region is exactly two connected, fixed-shape, contiguous Float32
matmuls: `[2,3] x [3,4]`, followed by `[2,4] x [4,2]`. It is a preview MVP,
not a general tensor-graph support claim.

## Compiler and runtime invariants

- `coreai` is a distinct valid accelerator target, not an alias for `gpu` or
  `npu`.
- Region formation is target-independent compiler machinery and runs at O0 and
  O3 for iOS device and Simulator object generation.
- The semantic markers must be completely consumed. Generated objects must
  import the fixed Core AI AsyncRT operation and contain no Metal, AIR, or
  residual marker symbol.
- A disconnected single operation and an unsupported shape fail compilation
  with a `Core AI region formation:` diagnostic.
- The logical Core AI context orders submissions, propagates errors, and owns
  host staging buffers. Raw kernels, device functions, launch dimensions,
  threadgroup memory, and other programmable-device operations fail by name.
- No CPU or Metal implementation is used when Core AI submission is unavailable
  or fails.

## Artifact and Swift bridge

`build-coreai-mvp-resources` directly authors the matching two-operation graph,
verifies its IR, compiles eight iOS 27 specializations with Neural Engine
preferred, executes exact host numerical comparison, and writes deterministic
resource hashes and toolchain provenance.

The Swift package preserves `CoreAIMatmulMatmulF32.aimodel` as a directory
resource. Its device build uses only the public `CoreAI` API, caches the loaded
function, constructs typed NDArrays, submits asynchronously, and completes the
AsyncRT request. The Simulator SDK has no Core AI module, so that slice builds
an explicit unavailable error path; it never computes the result elsewhere.

The unsigned iOS 27 smoke app links the static Mojo library, the Swift bridge,
and the resource. On supported hardware it checks exact `[6, 6, 15, 15]`
results across sequential and simultaneous calls.

## Commands

```sh
pixi run test-coreai-target-contract
pixi run test-asyncrt-host

MOJO_IOS_COREAI_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  pixi run build-coreai-mvp-resources

pixi run build-source-core

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  pixi run build-swift-smoke

MOJO_IOS_COREAI_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  pixi run build-coreai-device-smoke
```

Physical execution additionally requires an iOS/iPadOS 27 device, development
team, and CoreDevice identifier. `test-coreai-device` passes on the connected
M1 iPad Pro (`iPad13,9`) running iPadOS 27 beta 7 (`24A5424a`). It verifies
three sequential calls followed by ten rounds of eight simultaneous calls from
GCD-owned Swift threads, exact `[6, 6, 15, 15]` results, process exit status,
and a nonce-bound result copied back from the app data container. The bridge
caches the lightweight `AIModel` but loads a distinct `InferenceFunction` per
request; sharing one function instance produced intermittent zero outputs in
the beta runtime.

The exported Mojo entry point is synchronous. Blocking enough
`Task.detached` callers can exhaust Swift's cooperative executor while the
Core AI bridge still needs that executor for async completion. The physical
concurrency gate therefore uses GCD-owned threads. A generated async Swift
adapter that suspends instead of blocking remains a separate integration gap;
the runtime must not disguise it with serial or CPU fallback.

## Completion boundary

The compiler, runtime, AOT resource, Swift package, signed device app, and
physical iPad execution portions of this fixed MVP are implemented. Instruments
placement evidence remains a separate observational gate.

General Core AI support remains incremental: each new operation, shape policy,
dtype, layout, mutation/effect form, and graph composition rule needs an
explicit semantic lowering and named negative tests. Apple still owns actual
CPU/GPU/ANE placement; this project claims only submission to Core AI with the
Neural Engine preferred.
