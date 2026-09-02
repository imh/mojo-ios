# CPU runtime lifecycle and composition gate

This gate proves process-lifetime runtime ownership and same-compiler-tuple
composition for two independently compiled ordinary-Mojo libraries. It does
not define an iOS lifecycle API or a second runtime contract.

## Lifecycle contract

The normal upstream entry convention is preserved: every exported Mojo entry
point called by a non-Mojo host calls `std.runtime.initialize_runtime()`.
Initialization is idempotent, and the initialized CompilerRT/AsyncRT instance
remains process-resident. There is intentionally no iOS shutdown API.

The ownership boundaries are:

- the process owns the single CompilerRT/AsyncRT instance and Apple work queue;
- each `DeviceContext`, async chain, continuation, allocation, and Mojo value
  has an explicit shorter lifetime;
- `KGEN_CompilerRT_DestroyGlobals()` is a quiescent test and `atexit` hygiene
  boundary, not an application persistence guarantee;
- scene backgrounding is not runtime teardown; and
- iOS process suspension pauses work but must preserve state for resumption.

Concurrent global destruction with live Mojo execution is unsupported because
upstream provides no such contract. iOS may terminate an app without graceful
cleanup, so application correctness must not depend on global destructors.

## Ordinary-Mojo libraries

`Tests/runtime-lifecycle/LibraryA.mojo` and `LibraryB.mojo` are compiled
independently and expose only a C ABI to their Swift host.

- Library A initializes the standard runtime, owns and destroys a `List`, and
  uses a captured unified closure through standard
  `max.algorithm.parallelize`.
- Library B initializes the standard runtime, runs ordinary async functions
  with results and a raised error, owns and destroys a `List`, and crosses the
  standard C function-pointer-plus-context callback ABI.

The fixtures contain no iOS import or target branch, alternate closure
convention, project runtime initializer, lifecycle hook, executor, or fallback.
Task creation continues to use the pinned stdlib's existing internal AsyncRT
bridge because that revision does not expose public task construction; the
async language functions and coroutine lowering are unchanged.

Each library archive deliberately contains its own copy of the same pinned
runtime members. The final app is linked normally in both orders:

```text
LibraryA -> LibraryB -> runtime
LibraryB -> LibraryA -> runtime
```

No `-all_load`, `-force_load`, registry, custom initializer, or archive-order
contract is used. Link maps and symbol audits require exactly one selected
`KGEN_CompilerRT_Initialize` implementation, no unresolved runtime operation,
and no test or project runtime ABI in the product.

This proves same-version composition only. Cross-version runtime coexistence,
ABI negotiation, and the broader production Swift ownership contract remain
open.

## Stress and evidence

The host starts eight Swift/C-owned pthreads. Each thread enters both libraries
sixteen times, while the normal CPU executor supplies overlapping parallel and
async work. The gate additionally proves:

- repeated process-wide initialization through both libraries;
- one shared CPU runtime pointer across foreign callers;
- 64 CPU `DeviceContext` create/retain/synchronize/release cycles;
- async completion and error cleanup;
- continuations registered before and after completion through the existing
  AsyncRT tests;
- exact task completion and destruction at synchronization;
- contended global initialization, destruction of losing initializations,
  exactly-once destruction of the installed value, and recreation after a
  quiescent global teardown; and
- successful calls after all temporary contexts and globals are released.

The application starts live executor work, is suspended and resumed by device
tooling, waits for the original work, backgrounds and foregrounds through an
iOS scene transition, then re-enters both libraries. It does not claim that
work progresses while the process is suspended.

On 2026-09-01 with Xcode 27 beta build 27A5252f, the following passed:

```text
RUNTIME_LIFECYCLE_BUILD_PASS libraries=2 link_orders=ab,ba variants=3 optimizations=0,3 runtime_instances=1
RUNTIME_LIFECYCLE_SANITIZER_PASS sanitizers=asan,tsan optimizations=0,3 link_orders=ab,ba mojo_instrumented=yes test_controls=no
RUNTIME_LIFECYCLE_SIMULATOR_PASS devices=iphone,ipad link_orders=ab,ba optimizations=0,3 suspend_resume=yes foreground_background=yes
RUNTIME_LIFECYCLE_DEVICE_PASS device=ipad link_orders=ab,ba optimizations=0,3 suspend_resume=yes foreground_background=yes
```

The build matrix independently compiles and fully links macOS ARM64, iOS ARM64,
and ARM64 Simulator artifacts at O0/O3. macOS, iPhone Simulator, iPad
Simulator, and the paired M1 iPad Pro execute the meaningful cases. ASan and
TSan instrument the generated Mojo objects and the actual embedded runtime
sources; passing a sanitized wrapper around uninstrumented code is rejected.
Release runtime objects do not enable test controls.

## Defects corrected at their normal layer

The gate found two correctness defects that unsanitized allocation happened to
hide:

1. generic POP canonicalization retained a zero-bit `None` store through an
   unmaterialized empty coroutine result pointer; the generic canonicalizer now
   erases non-volatile, non-atomic stores of `None` and empty structures, with
   a non-iOS KGEN regression; and
2. the embedded Apple AsyncRT chain initializer incorrectly asserted that its
   destination was pre-zeroed, while the upstream ABI placement-constructs into
   uninitialized storage; the Apple implementation now matches that contract,
   and the runtime test initializes deliberately poisoned storage.

Neither correction adds an iOS Mojo surface, compiler abstraction, or fallback.

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/build-runtime-lifecycle.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-runtime-lifecycle-sanitizers.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-runtime-lifecycle-simulators.sh
MOJO_IOS_CORE_DEVICE_ID=00008103-000C79121123001E \
MOJO_IOS_DEVELOPMENT_TEAM=24D3YSDU5R \
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./scripts/test-runtime-lifecycle-device.sh
```
