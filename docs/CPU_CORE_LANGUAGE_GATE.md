# CPU core language and aggregate-call gate

This gate proves a bounded portable-Mojo slice through the ordinary compiler
and embedded Apple runtime paths. It does not claim that all portable language
families or the standard library are complete.

## Upstream-family routing

`config/cpu-language-family-routing.tsv` groups the pinned executable test
surface by its normal project milestone. It is a routing inventory, not a
support-status source. Current status remains exclusively in the capability
tracker.

The inventory distinguishes:

- portable language, memory, collection, and reflection families belonging to
  the M2 corpus;
- unified-closure families belonging to the separate M2 closure branch;
- Darwin- and sandbox-sensitive standard-library behavior belonging to M3;
- programmable accelerator and graph behavior belonging to M4 and M5;
- remaining pinned public async/concurrency verification belonging to M6; and
- compiler, REPL, notebook, Python, and JIT host behavior that is outside the
  shipped AOT application artifact.

`scripts/test-cpu-core-language-lowering.sh` validates that every referenced
path still exists in the exact pinned upstream checkout. A moved or removed
upstream family therefore reopens the inventory instead of silently losing
coverage.

## Ordinary-Mojo fixtures

Five independently compiled fixtures extend the existing corpus from fourteen
to nineteen families:

| Fixture | Semantic proof | Pinned upstream provenance |
| --- | --- | --- |
| `ControlFlow.mojo` | Runtime branches, `for`, `while`-`else`, `break`, `continue`, early return, and direct recursion | `KGEN/test/mojo-parser/statements/control_flow.mojo`, `KGEN/test/mojo-integration/for_range.mojo`, `early_return.mojo`, and `mojo_recursion.mojo` |
| `AggregateValues.mojo` | Tuple construction and return, runtime unpacking, nested aggregate access, and conditional values | `KGEN/test/mojo-parser/exprs/tuple_exprs.mojo` and `KGEN/test/mojo-integration/alias_unpack.mojo` |
| `VariadicPacks.mojo` | Empty, singleton, and multi-element runtime variadic packs, iteration, and forwarding | `mojo/stdlib/test/builtin/test_variadic.mojo` and `KGEN/test/mojo-integration/runtime_variadic_pack_construction.mojo` |
| `IndirectCalls.mojo` | Overload selection, thin function values, indirect calls, and a specialized generic function thunk | `KGEN/test/mojo-integration/function_ptr.mojo`, `function_overloads.mojo`, and `function_thunks.mojo` |
| `AggregateCallingConventions.mojo` | Register-passable and memory-only aggregate arguments and results | `KGEN/test/mojo-integration/conditional_register_passable_lowering.mojo` and `conditional_rp_move_behavior.mojo` |

The fixtures use standard Mojo syntax, traits, tuples, function types, and
runtime initialization. Their C-exported zero-argument test functions are only
the existing Swift harness boundary. They contain no iOS import, target branch,
project runtime API, alternate closure convention, or fallback.

All selected forms are supported through their ordinary paths. This batch did
not encounter an unsupported selected form, so it did not invent a negative
diagnostic merely to populate the gate. Any future selected family that fails
must either receive a generic lowering correction and non-iOS regression or
the same named upstream diagnostic on host and Apple targets.

## Lowering and binary evidence

The focused gate compiles every fixture to iOS LLVM IR and Mach-O at O0 and O3.
It proves:

- recursion remains a real callable function and recursive call before normal
  LLVM optimization;
- the three-element tuple remains an aggregate return with explicit extraction;
- a runtime variadic list retains its pointer-and-length representation through
  forwarding;
- the binary function value lowers to an indirect LLVM call;
- KGEN argument-convention lowering marks the ordinary `MemoryPair` argument
  and result `memoryOnly`, while `RegisterPair` remains register-passable; and
- subsequent LLVM scalar replacement at O3 is accepted as normal optimization,
  not mistaken for a Mojo calling-convention change.

Every iOS object defines exactly its expected test export. Its only undefined
symbols are the four existing standard runtime-initialization operations:

```text
KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice
KGEN_CompilerRT_AsyncRT_GetOrCreateCPUDevice
KGEN_CompilerRT_AsyncRT_ReleaseCPUDevice
KGEN_CompilerRT_GetOrCreateGlobal
```

No project-specific runtime, atomic helper, ARM emulation helper, or GNU helper
is present.

## Execution evidence

On 2026-09-02 with Xcode 27 beta build 27A5252f and the pinned source-built
Mojo compiler, the following gates passed:

```text
CPU_CORE_LANGUAGE_LOWERING_PASS fixtures=5 optimizations=0,3 routed_families=14 aggregate_conventions=register,memory-only
CPU_CONFORMANCE_BUILD_PASS families=19 variants=3 optimizations=0,3 independent_link=yes
CPU_CONFORMANCE_SIMULATOR_PASS families=19 devices=iphone,ipad optimizations=0,3
CPU_CONFORMANCE_DEVICE_PASS families=19 optimizations=0,3 foreign_threads=yes
```

The physical lane was the paired M1 iPad Pro (12.9-inch, 5th generation),
product `iPad13,9`, running iPadOS 27.0 build 24A5424a. Both device variants
were signed, installed, launched, observed through their exact pass marker, and
terminated by the shared device runner. The Swift host also invoked the full
corpus simultaneously from eight dispatch workers.

The runtime ABI census, globals/TLS boundary, numeric lowering, ordinary async,
unmodified `max.algorithm.parallelize`, Metal feasibility, shared-tooling,
patch-integrity, and tracker-structure gates passed after the new execution
matrix. No upstream patch changed in this batch.

## Remaining boundary

The routing inventory is complete at the intended family level, but M2 remains
open. Pointer and memory semantics, portable collections and iterators,
materialized compile-time/reflection behavior, and broader unified closures
still need their own normal-path evidence. Target-sensitive I/O, filesystem,
process, and time behavior remains M3 work. Accelerator and pinned public async
surfaces retain their existing later milestone ownership only where the pinned
public source exposes them; absent APIs are not future project work.

Run:

```sh
pixi run test-cpu-core-language-lowering
pixi run build-cpu-conformance
pixi run test-cpu-conformance-simulators
MOJO_IOS_CORE_DEVICE_ID=DEVICE_ID \
MOJO_IOS_DEVELOPMENT_TEAM=TEAM_ID \
  pixi run test-cpu-conformance-device
```
