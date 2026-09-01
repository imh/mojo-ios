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
ANE interface, or shipped Mojo JIT.

## Milestone status

| Milestone | Status | Exit gate |
| --- | --- | --- |
| M0: truthful tracking foundation | **complete** | One recursively validated Markdown task-list hierarchy with no lost current evidence |
| M1: stable distribution gate | **in progress** | Stable-toolchain CPU/Metal release archive passes privacy, provenance, local, and Xcode validation gates |
| M2: CPU compiler and runtime closure | **pending** | Portable CPU language/runtime corpus is proved or explicitly rejected across the base matrix |
| M3: standard library and production ABI | **pending** | Complete target-sensitive inventory and production ownership/error/callback contract |
| M4: general Metal backend | **pending** | Declared Metal operation set passes A-series iPhone and M-series iPad release gates |
| M5: upstream-shaped Core AI backend | **upstream blocked; Apple probe passes** | A standard MAX graph-backend extension is available, then the declared subset converts and executes through public iOS/iPadOS 27 APIs |
| M6: remaining general async | **upstream gated** | Every public upstream async surface is classified and its supported subset is race/lifetime gated |
| M7: upstream and release sustainability | **pending** | Reviewable patch series, compatibility-tuple CI, signed reproducible releases |

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
privacy-report, signed-export, and Apple server-validation gates pass. The
remaining provenance work is open.

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
6. Gate initialization, teardown, global destruction, executor shutdown, app
   lifecycle, foreign-thread entry, multiple Mojo libraries, ASan, and TSan.
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

1. general variadic unified-closure argument inference;
2. complete constant, aggregate, pointer, and buffer layouts;
3. textures and samplers;
4. atomics, barriers, simdgroups, and memory ordering;
5. Metal-native launch controls and named CUDA-only rejection;
6. valid AIR O0/debug lowering;
7. tensor, TensorOps, and quantized operation families; and
8. complete resource, synchronization, error, and lifetime behavior.

Every increment retains Mac, Simulator, physical-device, multi-kernel,
negative-diagnostic, and no-fallback gates. A broad iOS/iPadOS claim requires a
physical A-series iPhone and M-series iPad lane.

## M5: upstream-shaped Core AI backend

Direct Apple graph authoring, AOT specialization, host execution, and signed
physical iPadOS 27 execution pass. They prove Apple feasibility, not Mojo/MAX
integration. The former fixed two-matmul compiler pass and private runtime ABI
were removed: they bypassed the normal MAX graph compiler and could not grow
into an upstream backend. Standard Core AI lowering now fails explicitly until
the open-source MAX graph compiler/driver offers a backend extension point.

1. Require a documented stable authoring interface.
2. Select the highest generic tensor/graph IR in the ordinary Mojo/MAX pipeline.
3. Add explicit operation, dtype, shape, state, dynamic-shape, and availability
   conversions.
4. Reject every unrepresentable operation by name at conversion time.
5. Package versioned `.aimodel`/`.aimodelc` resources with explicit selection
   and ownership.
6. Define deliberate Metal custom-operation composition without fallback.
7. Expand the passing physical numerical and concurrent gate with device-side
   error and pending-work lifetime cases.
8. Generate an async Swift adapter that suspends cooperative-executor callers
   instead of blocking them in `DeviceContext.synchronize()`.
9. Retain an Instruments trace and claim only the placement Apple makes public.

The iOS 27 Simulator's lack of Core AI remains an explicit platform gap. ANE
only selection and per-operation residency remain platform gaps; private
interfaces are prohibited.

## M6: remaining general async

Adopt public task construction, cancellation, async I/O, GPU-await, and
abandoned-task semantics only as their general upstream Mojo contracts become
available. Implement their normal generic lowering and Apple AsyncRT operation,
with lifetime, error, cancellation, and race gates. Do not create an iOS
substitute.

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

Choose the first unfinished item in the earliest milestone unless:

- an upstream or Apple blocker makes useful progress impossible; or
- preserving an already proved capability requires an urgent compatibility
  correction.

When a milestone is blocked, record the precise capability and blocker, then
advance only work that does not weaken architectural invariants. Do not broaden
support claims merely because a neighboring feature passes.

The next implementation work is M1's stable distribution gate. Additional
isolated accelerator features wait until they fit the tracker and release
evidence structure established by M0.

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
