# CPU numeric conformance gate

This gate proves one portable CPU-language slice through ordinary Mojo source:
SIMD primitives, integer bit operations, standard math, vectorized memory, and
optimization-sensitive semantics. It adds no iOS import, numerical API,
runtime entry point, fallback, or target-specific source branch.

## Standard surfaces and provenance

The five independently compiled fixtures extend the corpus described in
[CPU_CONFORMANCE_GATE.md](CPU_CONFORMANCE_GATE.md):

| Family | Standard surface and proved scope | Pinned upstream provenance |
| --- | --- | --- |
| SIMD primitives | Integer, Boolean, Float16, BFloat16, Float32, and Float64 vectors; native, overwide, and unsupported odd widths; construction, casts, bit reinterpretation, indexing, insertion, shuffle, masks, reductions, comparisons, and arithmetic | `mojo/stdlib/test/builtin/test_simd.mojo` |
| Bit intrinsics | Leading/trailing zero count, population count, byte swap, bit reverse, rotations, bit width, and power-of-two helpers for scalar and SIMD 8/16/32/64-bit integers, including compile-time evaluation | `mojo/stdlib/test/bit/test_bit.mojo` |
| Strict math | Integer min/max; floating abs/copy-sign/rounding/sqrt/rsqrt/fma; exp/log/sin/cos/tanh/erf; Float16, BFloat16, Float32, Float64, vector math, NaN, infinities, signed zero, subnormal, overflow, and underflow | `mojo/stdlib/test/math/test_math.mojo` |
| Vectorized memory | `std.algorithm.vectorize`, unrolling, aligned and unaligned loads/stores, masked loads/stores, a 19-element odd tail, and generated-Mojo ASan instrumentation | `mojo/stdlib/test/algorithm/test_vectorize.mojo` |
| Optimization semantics | Integer casts, wrapping operations, comparisons, strict division/addition, default contraction, explicit FMA, and explicit fast FMA at O0/O3 | `mojo/stdlib/test/builtin/test_simd_fastmath.mojo` |

`tests/cpu-conformance/manifest.tsv` records whether each fixture's internal
oracle is exact, tolerance-based, classification-based, IR-backed, or
sanitizer-backed. Exact integer, mask, bit-pattern, and memory results compare
directly. Approximate functions use tolerances shaped by the corresponding
upstream implementation. Exceptional floating-point cases compare IEEE
classifications or explicit signed-zero bit patterns instead of requiring
cross-platform NaN payload identity.

The ordinary-Mojo source rejects odd-width `SIMD[..., 3]` with the same
upstream diagnostic for macOS, iOS device, and iOS Simulator at O0/O3:

```text
SIMD vector length must be a power of two
CPU_NUMERICS_BOUNDARY_PASS odd_width=generic-rejection targets=3 optimizations=0,3
```

This is a generic language boundary, not an iOS limitation.

## Generic lowering correction

The vectorized-memory fixture exposed a target-independent POP-to-LLVM defect:
when LLVM intrinsic operands arrived in a `kgen.struct`, extracting a field
during dialect conversion could hide an alignment constant behind a temporary
aggregate extraction. Masked load/store lowering then incorrectly diagnosed a
runtime alignment.

`LowerPOPToLLVM.cpp` now preserves compile-time constants while expanding
packed operands and recovers an alignment from the original
`kgen.struct.create` field while conversion is in progress. The correction is
generic and is covered by the existing non-iOS
`KGEN/test/kgen/pop-to-llvm/masked_intrinsics.mlir` suite for packed masked
load, store, gather, and scatter. It does not mention or branch on iOS.

## LLVM and dependency evidence

`scripts/test-cpu-numerics-lowering.sh` emits iOS LLVM IR and objects for all
five fixtures at O0/O3 and checks that:

- integer, half, bfloat, and floating SIMD types remain vectors before normal
  LLVM legalization, including a wider-than-NEON-width vector;
- signed and unsigned SIMD widening retain distinct sign- and zero-extension,
  and fixed-width wrapping addition carries no incorrect `nsw`/`nuw` promise;
- bit operations use the normal LLVM count, population, swap, and reverse
  intrinsics;
- masked loads/stores retain their lane mask, odd-tail bound, and declared
  pointer alignment;
- strict helpers have no unintended fast-math flags when contraction is
  disabled, while default contraction, explicit FMA, and explicit fast FMA
  retain their requested LLVM properties; and
- no `__atomic_*`, `__aeabi_*`, `__gnu_*`, or project numerical helper ABI is
  introduced.

Legal target splitting or scalarization of overwide vectors is ordinary LLVM
legalization and is allowed. This gate does not claim one Mojo SIMD value maps
to one NEON instruction.

The only newly reached non-CompilerRT/AsyncRT symbols are enumerated in
`config/cpu-numeric-external-symbols.tsv`: standard libSystem math operations
used by `std.math`, plus the standard diagnostic-stream operations reachable
from masked-load poison checking. Any symbol not in that attribution fails the
gate.

```text
CPU_NUMERICS_LOWERING_PASS fixtures=5 optimizations=0,3 strict_fp=yes external_symbols=attributed
```

## Sanitizer evidence

`scripts/test-cpu-numerics-asan.sh` compiles the actual
`VectorizedMemory.mojo` object with Mojo's address sanitizer instrumentation,
verifies the object contains ASan load/store hooks, compiles the embedded Apple
runtime objects with the same sanitizer toolchain, and executes the 19-element
masked tail.

Mojo's generated object currently requires the upstream LLVM ASan v8 ABI.
Xcode 27 beta's Apple clang runtime advertises a vendor-specific version symbol,
so the gate selects a clang whose runtime proves the matching
`___asan_version_mismatch_check_v8` export. On 2026-09-01 that was Homebrew
clang 22.1.8. The gate fails before linking if the selected runtime is
incompatible; a sanitized C wrapper around uninstrumented Mojo does not count.

```text
CPU_NUMERICS_ASAN_PASS mojo_instrumented=yes masked_tail=yes
```

## Build and execution lanes

On 2026-09-01, with Xcode 27 beta build 27A5252f, the expanded 14-family
corpus compiled and fully linked independently for macOS ARM64, iOS ARM64, and
iOS Simulator ARM64 at O0/O3. The corpus passed on macOS, ARM64 iPhone and iPad
Simulators, and the paired M1 iPad Pro on iPadOS 27. The device host also ran
the complete corpus simultaneously from Swift-owned threads.

```text
CPU_CONFORMANCE_BUILD_PASS families=14 variants=3 optimizations=0,3 independent_link=yes
CPU_CONFORMANCE_SIMULATOR_PASS families=14 devices=iphone,ipad optimizations=0,3
CPU_CONFORMANCE_DEVICE_PASS families=14 optimizations=0,3 foreign_threads=yes
```

The proved lane does not imply physical A-series iPhone coverage, minimum-OS
coverage, or exhaustive numerical conformance for every dtype, width, math
operation, rounding mode, or optimization policy.

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/build-cpu-conformance.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-conformance-simulators.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-conformance-device.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-numerics-lowering.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-numerics-boundaries.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-numerics-asan.sh
```
