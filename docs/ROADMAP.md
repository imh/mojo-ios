# Roadmap

The objective is ordinary ahead-of-time Mojo usable from Swift in App
Store-distributed iOS and iPadOS apps, with CPU, programmable Metal, and Core AI
tensor-graph execution through upstream-shaped compiler and runtime paths.

- [ARBITRARY_AOT_MOJO_PLAN.md](ARBITRARY_AOT_MOJO_PLAN.md) is the canonical
  destination, gap taxonomy, tracking design, and milestone definition.
- [CAPABILITY_LEDGER.md](CAPABILITY_LEDGER.md) is the canonical current-status
  task-list hierarchy.
- [APP_STORE_DISTRIBUTION_GATE.md](APP_STORE_DISTRIBUTION_GATE.md) defines the
  release evidence ladder.

This document is the compact execution view. It deliberately does not restate
the detailed status of each capability.

## Architecture held constant

```text
ordinary Mojo host code       -> LLVM/AArch64 -> static Apple library
programmable Mojo kernels     -> AIR/Metal    -> metallib
representable tensor graphs   -> Core AI IR   -> aimodel
```

Swift owns the public integration boundary. Backend-specific knowledge stays in
compiler, runtime, packaging, and deployment layers rather than application
Mojo source. Metal and Core AI are deliberately selected peer paths; neither is
a fallback for the other or for CPU lowering.

No milestone may introduce an iOS Mojo import, application source branch,
custom closure API, serial/CPU fallback, project-specific runtime ABI, private
ANE interface, shipped Mojo JIT, or public Mojo/MAX capability absent from the
pinned upstream surface. New internal target/backend plumbing is allowed only
to execute existing public syntax and semantics.

## Milestone status

| Milestone | Status | Exit gate |
| --- | --- | --- |
| M0: truthful tracking foundation | **complete** | One recursively validated Markdown task-list hierarchy with no lost current evidence |
| M1: stable distribution gate | **complete** | Stable CPU/Metal App Store validation plus accepted Xcode 27 preview provenance, privacy, signing, and reproducibility evidence |
| M2: CPU compiler and runtime closure | **verification deferred** | Portable CPU language/runtime corpus is proved or explicitly rejected across the base matrix |
| M3: standard library and production ABI | **mixed enablement and verification** | Complete target-sensitive inventory and production ownership/error/callback contract |
| M4: general Metal backend | **next actionable enablement** | Declared Metal operation set passes A-series iPhone and M-series iPad release gates |
| M5: Core AI backend for existing MAX graphs | **actionable enablement; Apple probe passes** | Add the internal MAX backend hook needed by existing public graph operations, then convert and execute the declared subset through the proved Core AI path |
| M6: pinned public async | **verification deferred** | Existing `async def`/`await` semantics pass; broader pinned public coverage remains to inventory |
| M7: upstream and release sustainability | **pending** | Reviewable patch series, compatibility-tuple CI, signed reproducible releases |

## Enablement-first execution sequence

Milestones group dependency and completion gates; they are not a strict queue.
The canonical status remains in
[CAPABILITY_LEDGER.md](CAPABILITY_LEDGER.md). Current work is selected by class:

1. Repair regressions in already proved behavior.
2. Complete actionable known gaps in the normal
   [Metal backend](trackers/metal.md), in tracker order: current Metal/AIR
   targets, then existing public tensor and quantized operations.
3. Complete the known missing production ownership, error, and composition
   contracts in the [Swift/C ABI](trackers/swift-abi-artifacts.md).
4. Select and encode the base minimum/latest OS policy in
   [targets and hardware](trackers/targets.md) before broadening availability
   claims.
5. Split and regression-gate the existing source changes, then automate the
   compatibility tuple in
   [upstream sustainability](trackers/upstream-evidence.md).
6. Implement the [Core AI backend](trackers/coreai.md): add the internal MAX
   backend hook needed to lower existing public graph
   operations, plus Core AI conversion, artifact ownership, diagnostics, and
   runtime composition against the proved preview tuple.
7. Only after actionable enablement is exhausted or externally blocked, resume broad
   expected-to-pass verification: remaining
   [portable CPU families](trackers/cpu-portable-remaining.md),
   [closure families](trackers/cpu-closure-families.md), pinned public
   [async/concurrency](trackers/async-concurrency.md), target-sensitive stdlib/MAX
   inventories, additional hardware lanes, and distribution stages.

Core AI graph integration remains in scope only as backend plumbing for
existing public MAX graph operations and existing device-selection machinery.
Focused verification that is necessary to complete or prevent regressions in
an enablement change travels with that change; this policy defers broad
exploratory verification, not correctness evidence.

## M0: truthful tracking foundation

Work in order:

1. Keep a complete, glanceable root task list for the project's major scopes.
2. Move current detail into small Markdown trackers linked from exactly one
   canonical parent.
3. Validate task syntax, pointers, graph structure, checked-parent roll-up,
   root coverage, and file size recursively.
4. Run the validator against the exact staged snapshot in the repository's
   pre-commit hook.
5. Run the same validator in authoritative CI.
6. Link gates, target lanes, compatibility tuples, artifacts, and diagnostics
   from branches as those branches are progressively unpacked.

Markdown remains the only status store. M0 must not add a TOML, YAML, database,
or generated status view beside it.

## M1: stable distribution gate

1. Add archive-wide forbidden Mojo/compiler/JIT content checks.
2. Audit Mach-O platforms, architectures, minimum OS, load commands, symbols,
   dependencies, entitlements, and private APIs.
3. Generate and verify Required Reason API and privacy-manifest coverage.
4. Add license notices, dependency/SBOM inventory, provenance, artifact hashes,
   and XCFramework signing.
5. Build and sign a reference CPU/Metal application with the stable accepted
   Xcode/SDK, then pass Xcode App Store validation.
6. Record TestFlight acceptance as a distinct later evidence stage.

The current package, manifest ownership, negative-audit, physical-device,
privacy-report, signed-export, and Apple server-validation gates pass. SPDX,
project and upstream notices, signed-XCFramework, and two-build reproducibility
machinery pass in the Xcode 27 preview lane. The project license is Apache 2.0
with LLVM exception. By project decision, that combined evidence completes M1;
rerunning the gates on production Xcode 27 is release maintenance, not an M1
blocker.

Core AI remains outside this stable release gate until its Apple toolchain is
accepted for production submission and its own device/package gates pass.

## M2: CPU compiler and runtime closure

1. Inventory upstream language test families and select or adapt a target-safe
   cross-compilation corpus.
2. Cover ownership/destruction, generics, traits, unified closures, errors,
   globals, TLS, atomics, SIMD/math intrinsics, callbacks, FFI, and
   optimization-sensitive cases.
3. Compile and fully link device and ARM64 Simulator artifacts at O0 and O3.
4. Execute every meaningful case on the minimum/latest base lanes and compare
   host results where appropriate.
5. Census the complete pinned CompilerRT/AsyncRT ABI and classify every
   operation.
6. Gate initialization, quiescent global teardown, process-resident executor
   ownership, app lifecycle, foreign-thread entry, same-tuple multiple Mojo
   libraries, ASan, and TSan.
7. Reduce every generic compiler correction to an upstream regression test.

## M3: standard library and production ABI

1. Generate the complete target-sensitive stdlib/MAX/native-dependency
   inventory, including indirect libc calls.
2. Give every operation a normal Darwin implementation, a named compile-time
   rejection, or an explicit outside-artifact disposition.
3. Audit deployment availability, sandbox behavior, and Required Reason API
   consequences.
4. Define strings, slices, structures, handles, allocator pairs, errors,
   callbacks, reentrancy, Swift concurrency, symbol versioning, and visibility.
5. Prove several separately compiled Mojo libraries can coexist in one app.

## M4: general Metal backend

Advance one explicit operation family at a time:

1. valid AIR optimization and debug lowering;
2. current Metal/AIR target registration;
3. existing public tensor, TensorOps, and quantized operation families;
4. complete synchronization, error, and lifetime behavior for that surface;
   and
5. verification of atomics, barriers, simdgroups, and memory ordering.

Every increment retains Mac, Simulator, physical-device, multi-kernel,
negative-diagnostic, and no-fallback gates. A broad iOS/iPadOS claim requires a
physical A-series iPhone and M-series iPad lane.

## M5: Core AI backend for existing MAX graphs

Direct Apple graph authoring, AOT specialization, host execution, and signed
physical iPadOS 27 execution pass. They prove Apple feasibility, not Mojo/MAX
integration. The former fixed two-matmul compiler pass and private runtime ABI
were removed: they bypassed the normal MAX graph compiler and could not grow
into an upstream backend. Standard Core AI lowering now fails explicitly because
the pinned MAX implementation exposes no internal backend hook. The work is to
expose the smallest upstream-reviewable internal hook in the normal MAX path and
implement Core AI through it. The accepted `coreai` spelling is only a new
backend value in existing generic target selection; this milestone may not add
a graph type, operation, builder, annotation, or pseudo-context.

1. Expose the smallest target-neutral internal graph-backend hook needed to
   lower existing public MAX graph operations, not a public or project-only
   Core AI graph abstraction.
2. Use the pinned preview authoring interface for development and device gates;
   keep production release claims separately gated on Apple's stable public
   interface.
3. Select the highest generic tensor/graph IR in the ordinary Mojo/MAX pipeline.
4. Add explicit operation, dtype, shape, state, dynamic-shape, and availability
   conversions.
5. Reject every unrepresentable operation by name at conversion time.
6. Package versioned `.aimodel`/`.aimodelc` resources with explicit selection
   and ownership.
7. Preserve existing standard custom-operation composition when the pinned
   public surface exposes it; otherwise record it as absent, without fallback.
8. Expand the passing physical numerical and concurrent gate with device-side
   error and pending-work lifetime cases.
9. Generate an async Swift adapter that suspends cooperative-executor callers
   instead of blocking them in `DeviceContext.synchronize()`.
10. Retain an Instruments trace and claim only the placement Apple makes public.

The iOS 27 Simulator's lack of Core AI remains an explicit platform gap. ANE
only selection and per-operation residency remain platform gaps; private
interfaces are prohibited.

## M6: pinned public async

Ordinary public `async def`, `await`, results, errors, suspension, and resumption
pass through generic coroutine lowering and normal Apple AsyncRT. The pinned
public stdlib/MAX async and concurrency surface beyond that proved slice remains
verification, not presumed enablement.

## M7: upstream and release sustainability

1. Split generic coroutine/closure fixes, Darwin policy, CompilerRT, AsyncRT
   CPU, Metal backend/runtime, and tests into independent reviewable patches.
2. Keep Core AI graph conversion in a later separate patch series.
3. Rebase the compiler revision, stdlib, MAX, Apple SDK, Metal toolchain, and
   Core AI package as one reported compatibility tuple.
4. Sign release artifacts and publish deterministic hashes, notices, and a
   release support statement linked to the canonical tracker.
5. Run the complete release matrix before changing the support contract.

## Work selection rule

Choose regressions first, then the first actionable enablement item in the
sequence above. Verification needed by that change is part of its gate. Broad
verification does not outrank a confirmed missing normal path merely because
its milestone number is lower. Never select blocked work until its recorded
prerequisite changes, and never weaken architectural invariants to bypass a
blocker.

The next actionable implementation work is current Metal/AIR target
registration. Atomics, barriers, and simdgroups are verification work until
execution exposes a concrete missing normal path.
The remaining M2 CPU and closure inventory is deliberately parked as
verification debt, not treated as evidence of missing iOS implementations.

## Toolchain policy

Keep Apple toolchains side by side and select them with project-scoped
environment variables. Do not change global `xcode-select` as part of a gate.

- The stable base lane uses the Xcode/SDK generation Apple currently accepts
  for production App Store submission.
- Core AI authoring and execution use the Xcode 27 and iOS/iPadOS 27 generation
  in a separate preview lane until production submission is available.
- Every gate asserts its developer directory, SDK, compiler, Metal toolchain,
  runtime destination, and minimum OS before doing work.
- The base CPU/Metal deployment minimum is a separate unresolved policy. Core
  AI availability must not raise it implicitly.

The current M1 iPad proves the useful Metal MVP and the standalone public-Core-AI
probe on iPadOS 27 beta 7, and is covered by the Core AI `h13g`
specialization. It does not prove Mojo-to-Core-AI lowering.
