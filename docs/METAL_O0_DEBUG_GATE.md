# Metal O0 and debug gate

## Contract

Ordinary Mojo/MAX source selects the existing Metal `DeviceContext` and
`enqueue_function` path. The source optimization and debug selections flow
through `compile_offload`, `ObjectCompiler`, AIR legalization, Apple's Metal
toolchain, and normal AsyncRT execution without an iOS-facing API or fallback.

## Compiler behavior

The Metal backend now distinguishes optimization from required legalization:

- O0 runs AIR preparation, mandatory inlining only for device helpers that use
  AIR thread/grid builtins, local CFG/SROA/EarlyCSE/InstCombine
  canonicalization, AIR ABI formation, address-space inference, pointer
  rewriting, and LLVM 17 serialization.
- O3 retains the ordinary optimized module pipeline before the same required
  AIR legalization.
- A compiler regression retains an unrelated helper call at O0, folds it at
  O3, and proves a builtin-dependent helper is legalized at both levels.
- Full debug is deliberately rejected before invoking Apple tools with
  `Metal full debug information is not implemented`; it is never silently
  converted to line tables or no debug.

True O0 exposed an otherwise optimization-hidden reference to the existing
`AsyncRT_DeviceFunction_copyToConstantMemory` ABI used by standard MAX source.
The ABI is now declared and supplied by the Apple runtime. Because dynamic
constant-memory mapping has no implemented Metal behavior, an actual call
returns the owned error `Metal constant-memory mapping is not implemented`.
Unused standard-library code therefore links at O0, while attempted use fails
by name rather than becoming an unresolved symbol or fallback.

## Evidence

`scripts/test-metal-o0-debug.sh` proves:

- the compiler receives distinct O0 and O3 policies;
- the complete useful-MVP kernel corpus builds independently at O0 and O3;
- both products execute with identical results on the Mac GPU;
- the O0 product executes on ARM64 iPhone and iPad Simulators;
- O0 line-table IR retains source filenames and line locations;
- all five embedded metallibs pass `air-validate`, produce `air-dsymutil`
  companions, retain kernel names, and collectively retain the Mojo source
  path; and
- full debug produces its stable compiler diagnostic even when the configured
  Apple Metal executable is `/usr/bin/false`, proving rejection occurs before
  Apple tool invocation.

`scripts/test-metal-device.sh` additionally signs and executes the full O0
useful-MVP corpus on the physical M1 iPad Pro and receives
`metal=useful-mvp` with exit status zero.

The recorded tuple is Xcode 27.0 beta build 27A5252f, iOS/iPadOS 27 SDK,
Metal component build 27A5252f, and `metalfe-32023.921.5`. O0 and line tables
are complete for the declared slice. Full debug remains a narrow enablement
gap: the current generated full-debug AIR crashes Apple's `air-lld`, so the
stable pre-tool diagnostic remains required until full AIR debug metadata is
lowered and packaged correctly.

No CPU, serial, alternate GPU, project runtime ABI, or Mojo-source special case
is present.
