# CPU conformance and runtime ABI gate

This gate establishes the first repeatable M2 proof slice. It does not claim
that arbitrary portable CPU Mojo is complete.

## Ordinary-Mojo corpus

The corpus in `tests/cpu-conformance` contains nine independent fixtures. Each
uses standard Mojo syntax, standard-library imports, and the normal
`std.runtime.initialize_runtime()` entry convention. None imports an iOS
module, tests an iOS target flag, calls a project runtime API, or uses a custom
closure convention.

| Family | Semantic proof | Upstream provenance |
| --- | --- | --- |
| Ownership | Copy, move, and exactly-once destruction event trace | `mojo/stdlib/test/traits/test_trivial.mojo` |
| Generics | Parametric structure and function specialization | `mojo/docs/code/reference/cheat-sheets/test_compile_time.mojo` |
| Traits | Generic trait-constrained dispatch | `mojo/docs/code/reference/trait-declarations/tests.mojo` |
| Errors | Raised-error propagation and destruction of a live value | `mojo/stdlib/test/builtin/test_error.mojo` |
| FFI | Mojo-to-C call through `std.ffi.external_call` | `mojo/stdlib/test/ffi/test_external_call.mojo` |
| Callbacks | C-to-Mojo function pointer with an explicit context value | `mojo/docs/code/reference/lambda-expressions/tests.mojo` |
| Global constants | Immutable scalar, SIMD, and fixed-array static storage | `mojo/docs/code/manual/metaprogramming/materialization/global_constant.mojo` |
| Atomics | Integer operations, ordering, compare-exchange, and fences | `mojo/stdlib/test/atomic/test_atomic.mojo` |
| Atomic concurrency | Contention and release/acquire publication through standard CPU parallelism | `mojo/stdlib/test/runtime/test_locks.mojo` |

The final three families and the generic mutable-global/TLS boundary are
detailed in [CPU_STATE_GATE.md](CPU_STATE_GATE.md).

`tests/cpu-conformance/manifest.tsv` is the machine-readable build inventory,
expected-result record, and provenance input. It is not a support-status
source.

## Build and execution matrix

`scripts/build-cpu-conformance.sh` compiles every fixture independently at O0
and O3 for macOS ARM64, iOS ARM64, and iOS Simulator ARM64. Each object is then
fully linked by itself against the same embedded Apple CompilerRT, KGEN
AsyncRT, work queue, and CPU DeviceContext sources used by the distributable
library. The gate rejects remaining embedded-runtime undefined symbols and any
project-specific Mojo runtime ABI. It also executes the same source on macOS
at O0/O3 as the reference result.

`scripts/test-cpu-conformance-simulators.sh` executes every fixture in one test
host on both an ARM64 iPhone Simulator and ARM64 iPad Simulator at O0/O3.
`scripts/test-cpu-conformance-device.sh` does the same on the physical iPad and
repeats the complete corpus from simultaneous Swift-owned dispatch threads.
The Swift app is only the C-ABI test host; it does not change the Mojo
semantics.

On 2026-09-01, using Xcode 27 beta build 27A5252f, all matrix gates passed:

```text
CPU_CONFORMANCE_BUILD_PASS families=9 variants=3 optimizations=0,3 independent_link=yes
CPU_CONFORMANCE_SIMULATOR_PASS families=9 devices=iphone,ipad optimizations=0,3
CPU_CONFORMANCE_DEVICE_PASS families=9 optimizations=0,3 foreign_threads=yes
RUNTIME_ABI_CENSUS_PASS total=68 compilerrt=49 device_context=19 compile_time_rejected=7 implemented=61
```

The physical lane was the paired M1 iPad Pro (12.9-inch, 5th generation) on
iPadOS 27. No physical A-series iPhone or minimum-OS lane is implied.

## Complete pinned runtime C ABI census

`scripts/runtime-abi-census.py` derives the contract from the pinned upstream
CompilerRT implementation sources and `DeviceContextCAPI.h`, then compares it
with the normal embedded Apple CompilerRT, AsyncRT, CPU DeviceContext, and
Metal DeviceContext implementations. Every contract operation must be in
exactly one disposition; a new or unclassified operation fails the gate.
The contract is the compiler-facing C ABI: KGEN CompilerRT (including its
AsyncRT chain operations) plus `DeviceContextCAPI`. Private Apple work-queue
helpers and test-only controls are implementation details, not contract
operations.

The current 68-operation result is:

- 61 implemented by the normal embedded Apple ABI;
- 1 Python setup operation rejected at compile time by the existing iOS target
  policy; and
- 6 AsyncRT time-trace operations rejected at compile time by the normal MAX
  tracing target policy because the embedded Apple runtime does not implement
  that backend.

The disabled profiling-range ABI is implemented with the same semantics as
upstream when profiling is not compiled in: operation IDs remain unique,
recording predicates return false, and range recording operations are no-ops.
This is ABI completion, not a serial or backend fallback. `TraceLevel.ALWAYS`
can select the AsyncRT time-trace path, so the gate includes a negative standard
MAX probe proving that this selection fails by name during iOS compilation
instead of becoming an unresolved symbol or silently disabling tracing.

The generated `build/runtime-abi-census.tsv` records every operation, source
surface, disposition, reason, implementation, and semantic-test or diagnostic
evidence. Every implemented operation must map to exactly one executed runtime
test or the executed Metal gate. The checked-in
`config/runtime-abi-dispositions.tsv` contains only operations absent from the
Apple implementation. `scripts/test-runtime-abi-census.sh` also deletes a
required disposition and proves that the census fails rather than accepting
an unknown symbol.

## Remaining boundary

This batch did not expose a compiler-lowering defect, so it adds no artificial
iOS compiler patch or generic regression test. M2 remains open for broader
SIMD/math and optimization-sensitive language families,
minimum/latest target lanes, runtime lifecycle, multi-library composition,
ASan, and release-equivalent TSan coverage. Those capabilities must be proved
through the same normal paths or rejected by name without fallback.

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/build-cpu-conformance.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-conformance-simulators.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-conformance-device.sh
./scripts/test-runtime-abi-census.sh
./scripts/test-cpu-state-boundaries.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-cpu-state-tsan.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-source-target-policy.sh
```
