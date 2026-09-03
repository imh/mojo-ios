# Metal O0 and debug gate

## Contract

Ordinary Mojo/MAX source selects the existing Metal `DeviceContext` and
`enqueue_function` path. Source optimization and debug selections flow through
`compile_offload`, `ObjectCompiler`, AIR legalization, Apple's Metal toolchain,
and normal AsyncRT execution without an iOS-facing API or fallback.

## Compiler behavior

The Metal backend distinguishes optimization from required legalization:

- O0 runs AIR preparation, mandatory inlining only for device helpers that use
  AIR thread/grid builtins, local CFG/SROA/EarlyCSE/InstCombine
  canonicalization, AIR ABI formation, address-space inference, pointer
  rewriting, and LLVM 17 serialization.
- O3 retains the ordinary optimized module pipeline before the same required
  AIR legalization.
- A compiler regression retains an unrelated helper call at O0, folds it at
  O3, and proves a builtin-dependent helper is legalized at both levels.
- `none`, `line-tables`, and `full` remain distinct debug modes. Full debug
  retains compile units, files, subprograms, lexical scopes, types, variables,
  expressions, and instruction locations through AIR packaging. It is not
  stripped or converted to line tables.

Full debug exposed four compatibility gaps in existing lowering paths:

1. Current LLVM debug records were handed to an older bitcode writer without
   first being converted to the intrinsic representation understood by LLVM 17
   readers.
2. The LLVM 17 writer encoded newer debug-record fields and newer GEP flags. It
   now uses LLVM 17 record layouts, preserves the valid `inbounds` flag, and
   omits only post-LLVM-17 flags.
3. Optimized debug expressions can use `DIArgList` to describe one variable
   assembled from several SSA values. The LLVM 17 value enumerator now assigns
   those lists function-local metadata IDs after their values, as required by
   the older format.
4. The fallback O0 debug adapter materialized variables as stack allocations
   with volatile stores and represented empty inlined source lines with an
   inline-assembly nop. Apple AIR uses SSA `dbg.value` locations and accepts
   neither that nop nor a standalone `dbg.label` in executable threadgroup
   kernels. The target adapter now keeps ordinary SSA variable locations and
   drops only synthetic line markers which have no executable instruction;
   real instruction, scope, and variable locations remain unchanged.

These are generic compatibility fixes in the existing downgrade and LLVM 17
writer paths. The Metal backend has no debug-only Mojo API, Apple source shim,
or target fallback.

True O0 also exposes an otherwise optimization-hidden reference to the existing
`AsyncRT_DeviceFunction_copyToConstantMemory` ABI used by standard MAX source.
The ABI is declared and supplied by the Apple runtime. Because dynamic
constant-memory mapping has no implemented Metal behavior, an actual call
returns the owned error `Metal constant-memory mapping is not implemented`.
Unused standard-library code therefore links at O0, while attempted use fails
by name rather than becoming an unresolved symbol or fallback.

## Evidence

`scripts/test-metal-o0-debug.sh` proves:

- the compiler receives distinct O0 and O3 policies;
- the complete five-kernel useful-MVP corpus builds independently at O0 and O3
  with both no debug and full debug;
- scalar, SIMD, buffer, captured aggregate, multidimensional, static/dynamic
  threadgroup-memory, helper, and multi-kernel behavior executes identically;
- emitted full-debug AIR retains Mojo source paths, compile units, subprograms,
  locations, lexical scopes, scalar/derived types, and local variables at O0;
- full-debug metallibs pass `air-validate`, produce `air-dsymutil` companions,
  and retain kernel and source identities; O3 retains the debug information
  that survives legitimate optimization;
- line-table output retains source filenames and line locations without being
  promoted to full debug; and
- no-debug and full-debug O0/O3 products execute on the Mac GPU and both ARM64
  iPhone and iPad Simulator classes.

The generic regression
`KGEN/test/kgen/object-compiler/llvm17-full-debug.ll` round-trips full-debug
compile units, scalar and pointer types, local variables, a multi-value
`DIArgList` expression, locations, and valid GEP semantics through the LLVM 17
writer. `metal-optimization-level.ll` continues to prove the distinct O0/O3
pipelines.

`scripts/test-metal-device.sh`, run with full debug at O0 and O3, signs and
executes the complete useful-MVP corpus on the physical M1 iPad Pro and receives
`metal=useful-mvp` with exit status zero.

The recorded tuple is Xcode 27.0 beta build 27A5252f, iOS/iPadOS 27 SDK, Metal
component build 27A5252f, and `metalfe-32023.921.5`.

No CPU, serial, alternate GPU, project runtime ABI, debug-mode downgrade, or
Mojo-source special case is present.
