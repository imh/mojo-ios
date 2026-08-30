# Metal feasibility gate

## Architecture

Mojo authors use the existing accelerator path:

1. Write an ordinary Mojo kernel using `std.gpu` builtins.
2. Construct `DeviceContext(api="metal")`.
3. Allocate `DeviceBuffer` values and enqueue copies.
4. Call `enqueue_function` and `synchronize`.

There is no iOS import, platform branch, kernel wrapper, runtime symbol, or CPU
fallback in Mojo source. Target-specific work is confined to the compiler's
normal offload interfaces and the standard AsyncRT C ABI.

## Implemented compiler slice

- Apple AIR targets are registered as peer offload targets.
- Standard X/Y/Z GPU index builtins lower to explicit AIR intrinsics and then
  the corresponding AIR kernel arguments.
- Pointer-buffer, scalar, and aggregate arguments receive explicit AIR address
  spaces and metadata. Captured scalar closures use the ordinary value-taking
  `enqueue_function` path.
- Static shared allocations and dynamic `external_memory` lower to Metal
  threadgroup storage.
- Legalized modules are written as LLVM 17 bitcode.
- Object emission invokes Apple's Metal compiler to package AIR as a
  `metallib`; `MOJO_METAL_COMPILER_PATH` overrides the normal `xcrun` lookup.
- Interprocedural Metal compilation emits one `metallib` object per offload
  unit and rejects invalid opaque-library concatenation.
- `compile_offload` returns the symbol actually emitted into the artifact;
  callers do not independently reconstruct a potentially target-dependent
  linkage name.
- Unsupported AIR archive creation and unsupported target operating systems
  fail explicitly.

## Implemented runtime slice

The embedded Apple AsyncRT target implements the existing symbols used by
`DeviceContext`, `DeviceBuffer`, and `DeviceFunction`:

- Metal device and command-queue creation;
- buffer allocation and reference counting;
- queue-ordered host/device copies;
- `metallib` loading and compute-pipeline creation;
- existing `MetalEnqueueFunctionArgs` decoding;
- direct buffers, inline scalar/aggregate values, and nested device-pointer
  fixups;
- three-dimensional grid/block dispatch;
- static and dynamic threadgroup-memory validation and binding;
- exact ABI validation for launch attributes, accepting `IGNORE` and rejecting
  every CUDA-only value by name;
- compute dispatch and synchronization.

The CPU and Metal implementations share the normal DeviceContext entry points.
Dynamic requests for unavailable devices or unimplemented features return
owned errors; they never fall back to CPU.

## Useful-MVP boundary

The gated slice now includes explicit and captured scalars, X/Y/Z indexing,
three-dimensional launches, several kernels in one Mojo library, and both
static and dynamic threadgroup memory. Launch attributes remain CUDA-shaped in
the upstream API: Metal accepts `IGNORE` and returns a named error for every
concrete CUDA-only attribute. It never silently ignores one.

Still outside this boundary are textures/samplers and other unlisted resource
classes, target-specific launch controls with no Metal semantic mapping,
general variadic unified-closure argument inference, and a distinct AIR O0
pipeline. These must gain an explicit lowering or remain an explicit failure;
there is no CPU fallback.

## Evidence and remaining gate

With `MOJO_IOS_METAL_SIMULATOR_ID` set to a booted arm64 simulator,
`scripts/test-metal-feasibility.sh` proves that:

- Apple's Metal compiler accepts the generated AIR;
- the arm64 iOS Mojo object contains `MTLB` data;
- the iOS probe fully links with no unresolved AsyncRT symbols;
- the arm64 iOS Simulator and Mac GPU execute explicit/captured scalars, 3D
  dispatch, multi-kernel composition, and static/dynamic threadgroup memory;
- both also prove that a CUDA-only cooperative launch attribute returns the
  exact named error before dispatch;
- the signed device smoke app executes the same complete matrix on a physical
  M1 iPad Pro GPU through `scripts/test-metal-device.sh`.

This completes the useful Metal MVP. It is not a general production iOS Metal
support claim: add remaining resource classes and GPU operations one explicit
lowering at a time while retaining the Mac, Simulator, physical-device,
negative-diagnostic, and no-fallback gates.
