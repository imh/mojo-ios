# Standard MAX Core AI backend gate

## Current verdict

The backend is **not implemented**. This is an intentional architectural gate,
not an invitation to add an iOS-facing Mojo API or fixed compiler pattern.

The standard source spelling remains the intended contract:

```text
ordinary MAX tensor operations selected for target="coreai"
  -> standard MAX graph IR
  -> registered Core AI graph-backend conversion
  -> versioned AOT model resource
  -> normal runtime graph submission
```

The open-source repository contains the standard MAX graph-building API, but
the graph compiler and device driver are supplied by the closed `max._core`
module. It currently knows CPU, GPU, and NPU devices and exposes no open-source
backend registration point through which this project can add Core AI.

Consequently, `linalg.matmul[target="coreai"]` fails during compilation with a
named not-implemented diagnostic. `coreai` is not classified as a programmable
accelerator or a valid kernel target, so standard operations cannot accidentally
take GPU lowering. Dynamic `DeviceRef.CoreAI().to_device()` likewise fails by
name instead of aliasing another device.

## Prohibited shortcuts

The gate rejects all of the following:

- an iOS-only Mojo import, graph builder, wrapper, or operation;
- fixed semantic marker calls recovered later from LLVM IR;
- an LLVM pass matching one source program or one exact graph;
- a project-specific fixed graph function in AsyncRT or the public C ABI;
- packaging a hand-authored model as if it came from Mojo compilation;
- CPU, Metal, NPU, or serial fallback.

The earlier fixed two-matmul marker/pass/runtime route has been removed. The
target contract gate scans for its compiler and ABI names so it cannot return
silently.

## Required upstream extension

Implementation resumes only after the normal MAX path exposes enough of its
graph compiler and runtime driver to add a backend. The minimum extension must
support:

1. registering a distinct managed-graph target named `coreai`;
2. receiving typed graph operations before their semantics are erased;
3. operation-by-operation conversion with named unsupported diagnostics;
4. emitting and associating immutable AOT resources with compiled regions;
5. submitting regions through the normal device/runtime ownership and async
   completion contracts; and
6. composing explicitly with CPU and Metal without implicit fallback.

This should be proposed upstream as a generic backend extension, not as Apple
logic embedded in common graph passes. Once available, Core AI fills in that
extension exactly as other targets do.

## Present gates

```sh
pixi run test-coreai-target-contract
pixi run test-asyncrt-host
```

These prove distinct target recognition, compile-time rejection through the
standard operation, absence of removed fixed ABIs, and truthful behavior of the
minimal logical context. They do not prove graph execution.

The separate Apple feasibility commands in
[COREAI_FEASIBILITY_GATE.md](COREAI_FEASIBILITY_GATE.md) prove that public Core
AI authoring, AOT compilation, and physical-device execution are viable. Their
artifacts live under `build/` and are not Swift-package resources.

## Completion criterion

This gate passes only when unchanged standard Mojo/MAX tensor source lowers
through a standard MAX backend extension, packages its generated AOT resource,
executes from Swift on a physical iPad, and rejects each unsupported semantic
case explicitly. Until then, the correct result is `NotImplemented`.
