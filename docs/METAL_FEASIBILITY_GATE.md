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
- The existing offload representation carries every declared argument type
  through `compile_offload` and `kgen.offload.pointee_types`; AIR buffer element
  types no longer depend on inspecting incidental LLVM loads and stores.
- Pointer-buffer, scalar, SIMD, padded aggregate, and nested device-pointer
  arguments receive explicit AIR address spaces, sizes, alignments, and access
  metadata. `DevicePointer.device_type` denotes standard global device memory.
- Fixed-arity unified closures satisfy the existing heterogeneous TypeList-pack
  callable trait, so captured closures and explicit arguments use the ordinary
  value-taking `enqueue_function` path without another overload or ABI.
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

The gated slice now includes heterogeneous variadic argument packs; explicit
and captured scalar, SIMD, and padded-struct values; multiple and repeated
buffers; offset and nested global `DevicePointer` values; X/Y/Z indexing;
three-dimensional launches; several kernels in one Mojo library; and both
static and dynamic threadgroup memory. Host encoding, runtime fixups, AIR
layout metadata, and numerical results are checked together. Launch attributes
remain CUDA-shaped in the upstream API: Metal accepts `IGNORE` and returns a
named error for every concrete CUDA-only attribute. It never silently ignores
one.

Ordinary runtime `Tuple` is not yet an accepted launch value because upstream
`Tuple` does not conform to `DevicePassable`; the compiler reports that normal
trait failure on host and iOS. A raw generic pointer nested inside a constant
argument is also rejected by name: nested device pointers must denote standard
`AddressSpace.GLOBAL` memory. The pinned public Mojo/MAX surface has no general
texture, sampler, or Metal-native launch-control API, so this project
deliberately adds none; ordinary image data remains usable through standard
buffers. Still outside this boundary are existing public atomics, barriers,
simdgroups, tensor operations, and a distinct AIR O0 pipeline. They must gain an
explicit lowering or remain an explicit failure; there is no CPU fallback.

## Evidence and remaining gate

With `MOJO_IOS_METAL_SIMULATOR_ID` set to a booted arm64 simulator,
`scripts/test-metal-feasibility.sh` proves that:

- Apple's Metal compiler accepts the generated AIR;
- the arm64 iOS Mojo object contains `MTLB` data;
- the iOS probe fully links with no unresolved AsyncRT symbols;
- the arm64 iOS Simulator and Mac GPU execute the heterogeneous argument and
  capture matrix, nested pointer fixups, 3D dispatch, multi-kernel composition,
  and static/dynamic threadgroup memory;
- both also prove that a CUDA-only cooperative launch attribute returns the
  exact named error before dispatch;
- the signed device smoke app executes the same complete matrix on a physical
  M1 iPad Pro GPU through `scripts/run-device-app.sh`, emits the full
  `metal=useful-mvp` completion marker, and exits successfully.

`scripts/test-metal-argument-lowering.sh` additionally inspects emitted AIR
LLVM and proves global nested-pointer fields, constant sizes and alignments,
read/write access metadata, and the named host/iOS rejection boundaries. The
generic fixed-closure-to-pack adaptor has a parser regression in
`KGEN/test/mojo-parser/closures/unified_closure_variadic_trait.mojo`; the Metal
encoder independently checks nested buffer registration and byte offsets.

This completes the useful Metal MVP. It is not a general production iOS Metal
support claim: lower remaining existing pinned public GPU operations one family
at a time while retaining the Mac, Simulator, physical-device,
negative-diagnostic, and no-fallback gates. Do not add resource classes absent
from the pinned public surface.
