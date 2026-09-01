# CPU static-state and atomic gate

This gate closes the current standard-Mojo immutable-global and CPU-atomic
surface without adding an iOS API, compiler abstraction, runtime ABI, or
fallback. It does not claim mutable module globals or thread-local storage;
neither is a public language or standard-library surface in the pinned
upstream revision.

## Ordinary source surface

Three independent fixtures extend the CPU conformance corpus:

| Family | Standard surface | Semantic proof | Upstream provenance |
| --- | --- | --- | --- |
| Global constants | `std.builtin.globals.global_constant` | Scalar, SIMD, and fixed-array values use immutable static storage and execute repeatedly | `mojo/docs/code/manual/metaprogramming/materialization/global_constant.mojo` |
| Atomic operations | `std.atomic.Atomic`, `Ordering`, and `fence` | Int32/Int64 load, store, add, subtract, min, max, compare-exchange, and valid explicit orderings | `mojo/stdlib/test/atomic/test_atomic.mojo` |
| Atomic concurrency | `std.atomic.Atomic` plus `max.algorithm.parallelize` | Exact 4,096-operation contention count, forced two-worker rendezvous, and release/acquire publication | `mojo/stdlib/test/runtime/test_locks.mojo` |

Each fixture calls the normal `std.runtime.initialize_runtime()` entry point.
The concurrent fixture follows the already-proved standard MAX CPU path:
`parallelize` to CPU `DeviceContext`, generic coroutine lowering, and Apple
AsyncRT. It refuses to run the overlap test with fewer than two workers; it
does not accept serial execution as evidence.

## Lowering evidence

`scripts/build-cpu-conformance.sh` emits iOS LLVM IR at O0 and O3 and asserts:

- `global_constant` becomes an internal LLVM constant and does not add
  `llvm.global_ctors`;
- relaxed, acquire, release, acquire-release, and sequentially consistent
  operations retain their requested orderings;
- add/sub read-modify-write, compare-exchange, and fence operations remain
  atomic in LLVM IR;
- the concurrent publication flag contains a release store and acquire load;
  and
- naturally aligned 32-bit and 64-bit CPU atomics do not acquire an external
  atomic-helper dependency.

Execution alone would not establish the memory ordering, so both IR and
runtime evidence are required.

## Generic absent surfaces

`scripts/test-cpu-state-boundaries.sh` compiles two upstream-shaped negative
fixtures for macOS, iOS device, and iOS Simulator triples at O0/O3:

- a mutable module variable receives the generic `global variables are not
  supported` language diagnostic; and
- `global_constant[String]` receives the standard trivial-copy-and-destroy
  constraint failure.

The gate also verifies that the pinned standard library does not expose a
`ThreadLocal` or `thread_local` API. There is therefore no normal Mojo TLS
extension point to implement for iOS. Internal MLIR operations and C-owned TLS
would not count. If upstream introduces a public TLS surface, this absence gate
fails and the capability must be reopened and tested normally.

These are upstream-wide boundaries. No diagnostic tests an iOS target, and no
iOS-specific rejection was added.

## Execution and sanitizer evidence

On 2026-09-01 with Xcode 27 beta build 27A5252f:

```text
CPU_CONFORMANCE_BUILD_PASS families=9 variants=3 optimizations=0,3 independent_link=yes
CPU_CONFORMANCE_SIMULATOR_PASS families=9 devices=iphone,ipad optimizations=0,3
CPU_CONFORMANCE_DEVICE_PASS families=9 optimizations=0,3 foreign_threads=yes
CPU_STATE_BOUNDARY_PASS mutable_globals=generic-rejection tls=absent-upstream-api targets=3 optimizations=0,3
CPU_STATE_TSAN_PASS mojo_instrumented=yes foreign_threads=8
```

The physical lane is the paired M1 iPad Pro on iPadOS 27. The TSan gate builds
the Mojo fixture itself with `--sanitize=thread`, verifies the generated object
references TSan instrumentation, builds the actual CompilerRT/AsyncRT sources
with TSan, and invokes the fixture concurrently from eight pthreads. A
sanitized wrapper around uninstrumented Mojo would fail the gate.

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/build-cpu-conformance.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-conformance-simulators.sh
MOJO_IOS_CORE_DEVICE_ID=DEVICE_ID MOJO_IOS_DEVELOPMENT_TEAM=TEAM_ID DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-conformance-device.sh
./scripts/test-cpu-state-boundaries.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-state-tsan.sh
```

This is targeted atomic-race evidence. Broad release-equivalent runtime TSan,
runtime lifecycle, additional portable language families, minimum/latest OS
lanes, and physical A-series hardware remain separate open capabilities.
No compiler, standard-library, MAX, CompilerRT, or AsyncRT correction was
needed for this batch, so the upstream patch stack is unchanged.
