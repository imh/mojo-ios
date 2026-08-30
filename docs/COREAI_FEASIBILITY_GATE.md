# Core AI feasibility gate

## Architecture

Core AI is a peer ahead-of-time graph backend, not a replacement runtime for
arbitrary Mojo:

```text
generic tensor/graph IR -> Core AI graph IR -> .aimodel
                                           -> per-architecture .aimodelc
Swift application       -> public Core AI runtime
```

Application Mojo must not import Core AI, branch on iOS, name Apple hardware,
or call a project API. A future compiler backend must accept only graph-shaped
programs representable by Core AI and reject every other operation by name at
conversion time. Selecting Metal is a separate compilation decision, never
recovery from failed Core AI conversion.

The compiler and model authoring tools run on macOS. The application ships
only static CPU objects, immutable Metal/Core AI resources, and Swift glue. It
ships no Mojo compiler or executable Mojo input.

The standard-backend architectural gate is documented in
[COREAI_MVP_GATE.md](COREAI_MVP_GATE.md).

## Proven Apple toolchain slice

The gate selects Xcode through `MOJO_IOS_COREAI_DEVELOPER_DIR`; it never changes
global `xcode-select` state. The current evidence uses:

- Xcode 27.0 build `27A5252f`;
- Metal Toolchain 27.0 build `27A5252f`;
- the iOS 27.0 SDK and `coreai-build` 3600.83.1;
- `coreai-core` 1.0.0b2 in an isolated Python 3.11 environment.

`probes/CoreAIDirectGraphProbe.py` directly constructs a fixed-shape Float32
graph with a `[2, 3]` input, constant `[3, 4]` weights, `batch_matmul`, `relu`,
and a typed `[2, 4]` result. It does not pass through PyTorch. Verification and
inspection prove the intended graph operations and schema before packaging.

`coreai-build` compiles that source model with iOS 27 as the minimum deployment
and Neural Engine as the preferred compute kind. The current toolchain emits
eight specializations: `h13g`, `h14g`, `h15g`, `h16g`, `h16p`, `h17g`, `h17p`,
and `h18p`. Inspection maps `h13g` to M1, so the current physical M1 iPad is in
the compiler's AOT architecture set.

The Apple Python runtime executes the source graph with exact numerical output
across three sequential calls, eight simultaneous calls, and a fresh second
model lifetime. A wrong-shaped input raises the expected named shape error.

`probes/CoreAISwiftRuntimeProbe.swift` uses only the public `CoreAI` framework:

- typed `NDArray` input and output;
- public async model loading and inference;
- explicit Neural Engine preference;
- result and throwing-error propagation;
- repeated and task-group calls;
- model/function descriptor assertions.

It compiles and fully links for an arm64 iOS 27 device. The resulting link
imports `/System/Library/Frameworks/CoreAI.framework/CoreAI` rather than any
private ANE framework. `CoreAIDeviceSmoke` also builds as an iOS 27 app bundle
with the source `.aimodel` copied as an explicit resource; signing is optional
for the build-only packaging gate.

## Explicit current boundaries

This is not yet a complete Phase 3 verdict:

1. Apple's direct-authoring tutorial currently imports operation builders and
   `Value` from underscored `coreai._compiler` modules and says their public
   `coreai.authoring` re-export is pending. The probe deliberately isolates
   those imports. They are feasibility evidence, not a stable production API.
2. The open-source MAX tree does not contain the graph compiler/driver extension
   required to add a real backend. Standard Core AI lowering is therefore a
   named compile-time `NotImplemented`; there is no fixed marker, LLVM pattern
   pass, or project runtime ABI.
3. The source asset, compiled specializations, and deterministic manifest are
   build-only probe outputs. They are not preserved in the Swift package or
   presented as compiler output. Release packaging belongs to a future normal
   MAX backend.
4. Xcode 27's iPhone Simulator SDK contains no `CoreAI.framework`. No CPU or
   Metal simulator substitute is permitted.
5. The standalone public Swift probe passes on the connected M1 iPad Pro
   running iPadOS 27 beta 7 (`24A5424a`). Three sequential calls and ten rounds of eight
   simultaneous calls produce exact output with no fallback. The app does not
   link Mojo or AsyncRT, so this is Apple API feasibility rather than backend
   execution evidence. Broader device-side negative and lifetime coverage
   remains to be added.
6. `--preferred-compute neural-engine` and
   `SpecializationOptions(preferredComputeUnitKind: .neuralEngine)` prove only
   that preference is represented at compile and runtime boundaries. They do
   not prove operation placement. A physical-device Core AI Instruments trace
   is still required, and even that supports only a preferred/eligible claim.

There is no public enforceable ANE-only option or per-operation placement API.
Private ANE compiler/runtime frameworks remain out of scope.

## Run the gate

Create the isolated authoring environment once:

```sh
pixi run bootstrap-coreai-authoring
```

Then run the complete reproducible gate without changing the machine's selected
Xcode:

```sh
MOJO_IOS_COREAI_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  pixi run test-coreai-feasibility
```

Build the app/resource integration without signing:

```sh
MOJO_IOS_COREAI_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  pixi run build-coreai-device-smoke
```

On an iPadOS 27 device, add the same development-team and CoreDevice variables
used by the existing physical-device tests:

```sh
MOJO_IOS_COREAI_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
MOJO_IOS_DEVELOPMENT_TEAM=YOUR_TEAM_ID \
MOJO_IOS_CORE_DEVICE_ID=YOUR_CORE_DEVICE_ID \
  pixi run test-coreai-device
```

The device script checks the OS before signing or installing. On the connected
M1 iPad Pro with iPadOS 27 beta 7 it signs, installs, runs the sequential and
concurrent numerical gate, and retrieves a nonce-bound success record from the
app container.

The current verdict is **GO** for the isolated Apple direct-graph feasibility
probe through physical iPadOS 27 execution, and **NOT IMPLEMENTED** for standard
Mojo/MAX Core AI lowering. Device negative/lifetime expansion and placement
observation also remain incomplete at the explicit boundaries above.
