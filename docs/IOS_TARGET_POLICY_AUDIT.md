# iOS target-policy audit

Every target-sensitive operation has one of three states:

1. implemented by its normal stdlib/runtime interface;
2. rejected at compile time with an operation-specific diagnostic;
3. uninstantiated and irrelevant to the artifact.

Architecture or “non-Linux” fallthrough is never a platform policy.

## Corrections in the upstream patch

- `CompilationTarget.is_ios()` identifies iOS/iPadOS explicitly.
- `CompilationTarget.is_darwin()` names the shared Apple ABI family.
- `platform_map(..., darwin=...)` is used only for verified Darwin constants.
- Darwin C integer, errno, `pwd`, `stat`, and `dirent` layouts are selected by
  operating-system ABI, never by ARM/NEON architecture.
- Linux layout branches now require an explicit Linux target.
- time, file-descriptor, and directory paths use explicit Darwin/Linux
  branches and reject other targets.

The iPhoneOS and macOS SDK headers were compared before sharing the Darwin
`stat`, `dirent`, and `passwd` layouts.

## Deliberate compile-time failures

The first support boundary rejects:

- arbitrary dynamic-library loading;
- subprocess execution;
- Python interoperability.

Each category has a compile-fail probe. A passing negative gate requires a
nonzero compiler exit and a diagnostic containing both the expected operation
and iOS. Undefined symbols at link time do not count.

## Positive surface gate

`SupportedAppleRuntimeSurfaceProbe.mojo` compiles and fully links for device
and simulator while instantiating normal runtime initialization, SpinWaiter,
CPU counts, Darwin `pwd`, files, `stat`, `listdir`, clocks, and environment
access. This prevents a compile-time rejection from hiding an accidental
internal dependency or a missing runtime symbol.

The language-async gate is positive, not an iOS exception. Ordinary async,
await, result, and raised-error probes must lower for device and simulator at
O0/O3 and import the standard AsyncRT chain ABI. The generic coroutine fixes
contain no target checks. Cancellation, async I/O, and GPU-await remain absent
from the pinned public upstream surface, require no iOS policy branch, and are
not API work for this project.

CPU compilation retains the upstream lowering pipeline. The experimental Metal
slice adds a peer AIR target backend and explicit AIR legalization passes, plus
the standard AsyncRT Metal C ABI implementation required by the emitted
objects. It does not add a platform-specific Mojo surface.
