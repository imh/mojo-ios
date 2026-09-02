# Arbitrary AOT Mojo on iOS and iPadOS

This is the canonical implementation plan for making ordinary ahead-of-time
Mojo libraries usable from Swift in App Store-distributed iOS and iPadOS apps.
It defines the destination, the gap taxonomy, the evidence model, and the order
of work. The GitHub task-list hierarchy rooted at
[CAPABILITY_LEDGER.md](CAPABILITY_LEDGER.md) is the canonical current-status
inventory. [ROADMAP.md](ROADMAP.md) is the shorter execution view of the
milestones in this document.

## Objective

Any well-typed, ahead-of-time Mojo library whose transitive language, standard
library, FFI, runtime, and accelerator capabilities are declared supported
must:

1. compile without an iOS branch or iOS-specific application API;
2. follow the normal upstream lowering and runtime path for every operation;
3. link into the published Apple artifact with no unresolved runtime contract;
4. execute correctly on every claimed target and hardware lane;
5. satisfy the repository's distribution gates; and
6. fail explicitly at the earliest normal boundary for every unsupported
   capability.

This is the project's precise meaning of **arbitrary Mojo**. It does not mean
that every Mojo facility is meaningful or permitted on iOS. Python
interoperability, subprocess creation, arbitrary dynamic loading, and other
unavailable facilities remain named compile-time failures until an
upstream-compatible static architecture exists.

App Store compliance is an evidence ladder, not a property inferred from
successful compilation. The project distinguishes architecture compliance,
local archive validation, TestFlight acceptance, and actual App Review
acceptance. Only Apple can produce the final result.

## Architectural destination

```text
ordinary Mojo host functions -> LLVM/AArch64 -> static Apple library -> CPU
programmable Mojo kernels     -> AIR/Metal    -> shipped metallib     -> GPU
representable tensor graphs   -> Core AI IR  -> shipped aimodel      -> Apple scheduler
```

All three routes may be composed into one versioned Swift package, but they
remain semantically distinct:

- ordinary host code is not graph input and does not become an ANE program;
- an unrepresentable Core AI operation is a conversion error, not a request to
  fall back to Metal or CPU;
- Metal is selected deliberately for programmable accelerator kernels;
- Core AI is selected deliberately for representable graphs and is the only
  accepted public route to standalone ANE scheduling;
- system specialization of shipped Metal and Core AI artifacts is allowed, but
  the app ships no Mojo compiler, JIT, or downloadable executable Mojo input.

Backend and deployment selection belongs in compiler, packaging, or Swift
integration configuration. It never requires a Mojo author to write an iOS
source branch, use a custom closure API, or call a project-specific runtime
initializer.

## Architectural invariants

Every milestone preserves these invariants:

1. **Normal paths only.** Fix generic lowering or add a normal target backend;
   do not add an iOS-only Mojo surface.
2. **Failure before fallback.** Target-known unsupported operations fail during
   compilation with the operation named. Runtime errors are reserved for
   inherently dynamic selections.
3. **One public ABI.** Swift crosses a deliberate C ABI. Mojo's internal ABI,
   ownership types, and `raises` effects do not leak across it.
4. **AOT distribution.** No Mojo source, `.mojopkg`, compiler, JIT support, or
   downloaded executable code is present in the shipped application.
5. **Evidence is scoped.** A passing probe supports only the operations and
   target lanes it instantiates.
6. **Apple hardware paths stay distinct.** Metal GPU neural features are never
   reported as standalone ANE execution.
7. **Upstream-shaped ownership.** Generic compiler fixes, Darwin target policy,
   Apple runtimes, and Metal/Core AI integration remain separable for review.

## Current baseline

The current repository proves useful but deliberately narrow slices:

- ARM64 device and Simulator object generation and static XCFramework
  packaging;
- a fixed-width Swift/C boundary for the sample exports;
- embedded Apple CompilerRT and AsyncRT operations reached by the probes;
- scalar, SIMD, allocation, collections, globals, printing, random, clocks,
  environment, files, Darwin metadata, directory iteration, locks, password
  lookup, and CPU-count examples;
- ordinary captured-closure CPU parallelism through
  `max.algorithm.parallelize` and the normal CPU DeviceContext path;
- ordinary language async, suspension/resumption, results, and raised errors;
- a useful Metal MVP with scalar captures, 3D dispatch, multiple kernels, and
  static and dynamic threadgroup memory;
- a fixed direct Core AI graph feasibility slice with AOT artifacts and public
  Swift device compile/link, explicitly separate from Mojo/MAX integration.

These are scoped proofs, not whole-category claims. The complete pinned
CompilerRT and DeviceContext C ABI is classified, and same-tuple independently
compiled Mojo libraries share one process-resident runtime across host,
Simulator, and physical-iPad lifecycle gates. Cross-version runtime composition
and the broader production Swift ABI remain open. Shipped runtime archives
exclude test-only AsyncRT controls, while instrumented host and sanitizer
products remain separate.

## Gap workstreams

The scoped branches in [CAPABILITY_LEDGER.md](CAPABILITY_LEDGER.md) identify
the current promises. Work is grouped into the following tracks.

### 1. Compiler and CPU language conformance

Build a cross-target conformance corpus rather than accumulating only feature
examples. It must cover ownership and destruction, generics, traits, unified
closures, errors, globals, thread-local state, atomics, SIMD and math
intrinsics, C interoperability, optimization-sensitive constructs, and every
other upstream language family that can reach target-specific code generation.

For each case:

- compile and fully link for device and Simulator at O0 and O3;
- run where the semantics are executable on the target;
- compare against the host result where equality is meaningful;
- retain a reduced compiler test for every generic compiler correction; and
- classify unsupported facilities rather than allowing link-time surprises.

### 2. Runtime ABI closure

Inventory the complete CompilerRT and AsyncRT ABI exported by the pinned
upstream revision. Every operation must be implemented, rejected before code
generation, or return a named error when its support decision is dynamic.

The runtime work includes initialization, repeated initialization, quiescent
global destruction, allocation alignment, task and chain lifetime,
process-resident executor ownership, app suspension/background behavior,
foreign-thread entry, sanitizer coverage, symbol visibility, dead stripping,
and composition of more than one Mojo library without duplicate runtime
ownership.

Release runtime objects must be built without testing hooks. Instrumented
runtime objects remain a separate test-only artifact.

### 3. Standard library, standard MAX, and native dependencies

Maintain separate progressively expanded inventories for target-sensitive
standard-library surfaces and standard MAX Mojo/graph/device surfaces,
including indirect libc calls and host-only native dependencies. Give each
reached operation exactly one disposition:

1. normal Darwin implementation;
2. operation-specific compile-time rejection; or
3. intentionally uninstantiated and outside the artifact.

Group the inventory by subsystem: memory, math, atomics, time, randomness,
files, paths, environment, process, dynamic loading, networking, locale and
Unicode, diagnostics, reflection, compile-time facilities, Python, and
accelerator host APIs. Audit every implemented system call for deployment
availability, sandbox behavior, and Required Reason API consequences.

The MAX branch begins with `max.algorithm.parallelize` and the backend-specific
Metal and Core AI branches. Broader public MAX libraries, algorithms,
tensor/graph operations, device selection, and runtime behavior remain one
unchecked scope until finer tracking is useful. Do not infer broad MAX support
from a neighboring passing operation.

### 4. Swift/C ABI and library composition

Turn the sample scalar ABI into a reusable library contract:

- fixed-width scalars and explicitly laid-out structures;
- pointer-plus-length buffers with checked bounds;
- strings with explicit encoding and lifetime;
- opaque handles with matching retain/release or create/destroy functions;
- allocate/free pairs that never cross allocator ownership accidentally;
- stable error codes and owned diagnostic messages;
- callback function pointer plus context conventions;
- reentrancy and Swift concurrency requirements;
- exported symbol versioning and visibility; and
- defined behavior when several Mojo libraries are linked into one app.

Headers are the source of truth. Mojo `raises` and internal layout never cross
the ABI.

### 5. Artifact and package composition

Produce a release package, not merely a smoke-test archive:

- static device and ARM64 Simulator variants;
- release and instrumented runtimes as distinct products;
- explicit Metal and Core AI resource ownership;
- conditional availability for the iOS 27 Core AI feature without a Simulator
  fallback;
- a privacy manifest where required;
- signed XCFramework distribution and provenance checking;
- license notices and a dependency/SBOM inventory;
- deterministic artifact hashes and pinned compiler/stdlib/MAX/SDK inputs; and
- archive-level checks for symbols, load commands, minimum OS, architectures,
  entitlements, private APIs, and forbidden executable inputs.

### 6. Async and concurrency

Preserve the implemented generic language async and CPU parallelism routes.
Track public task construction, cancellation, async I/O, GPU-await, and
abandoned-task behavior separately. When general upstream semantics exist, add
their normal lowering and Apple AsyncRT operation; do not create an iOS task or
I/O API.

### 7. Metal programmable accelerator coverage

Advance one explicit operation family at a time:

- general variadic unified-closure argument inference;
- complete constant and buffer layouts;
- textures and samplers;
- atomics, barriers, simdgroups, and memory-order semantics;
- Metal-native launch controls with named rejection of CUDA-only attributes;
- a valid AIR O0/debug pipeline;
- public tensor and TensorOps abstractions;
- quantized types and availability diagnostics; and
- complete resource, error, synchronization, and lifetime tests.

Every increment retains Mac, Simulator, physical-device, multi-kernel,
negative-diagnostic, and no-fallback gates. The physical matrix must include an
A-series iPhone and an M-series iPad before making a broad iOS/iPadOS claim.

### 8. Core AI and ANE coverage

The direct graph gate proves feasibility only. A production backend requires:

- a documented stable graph-authoring API;
- selection of the highest generic tensor/graph IR in the ordinary Mojo/MAX
  pipeline;
- operation-by-operation conversion with dtype, shape, state, dynamic-shape,
  and availability diagnostics;
- a named conversion failure for every unrepresentable operation;
- explicit composition with deliberately selected Metal custom operations;
- versioned `.aimodel` and `.aimodelc` resource selection and ownership;
- public Swift execution on iOS/iPadOS 27 hardware;
- numerical, error, concurrency, and lifetime evidence; and
- an Instruments trace supporting only the placement claim Apple exposes.

ANE-only selection and per-operation residency remain platform gaps until Apple
provides both public control and observability. Private ANE compiler or runtime
interfaces are prohibited.

### 9. App Store distribution

[APP_STORE_DISTRIBUTION_GATE.md](APP_STORE_DISTRIBUTION_GATE.md) defines the
evidence ladder. The gate includes forbidden-content scans, privacy-manifest
coverage, public-API and binary audits, release signing, archive validation,
TestFlight acceptance, and eventual App Review evidence.

The stable CPU/Metal lane and the preview Core AI lane remain separate. Xcode 27
beta acceptance for TestFlight does not promote the Core AI product to an App
Store release claim.

### 10. Upstream patch ownership

Split the current single patch into reviewable changes with independent tests:

1. generic coroutine and unified-closure fixes;
2. explicit iOS/Darwin target classification and stdlib policy;
3. dependency-light Apple CompilerRT;
4. Apple AsyncRT CPU work queue and DeviceContext;
5. Metal target registration, AIR legalization, packaging, and runtime; and
6. upstream regression and conformance tests.

Core AI graph conversion must be a separate later series. Rebase automation
must pin and report the compiler revision, standard library, MAX sources, Apple
SDK, Metal toolchain, and Core AI authoring package as one compatibility tuple.

## Target and hardware lanes

Tracker evidence must name target lanes instead of using an unqualified
`device tested` flag.

| Lane | Purpose | Initial requirement |
| --- | --- | --- |
| `ios-device-base-min` | Oldest supported CPU/Metal contract | ARM64 physical device at the selected minimum OS |
| `ios-device-base-latest` | Current CPU/Metal contract | Current stable Xcode/SDK and newest stable OS |
| `ios-simulator-base` | ARM64 Simulator ABI and execution | iPhone and iPad Simulator at O0/O3 |
| `ios-metal-a-series` | iPhone GPU behavior | Physical A-series iPhone |
| `ipados-metal-m-series` | iPad GPU behavior | Physical M-series iPad |
| `ios-coreai-preview` | Core AI/ANE feasibility | iOS/iPadOS 27 device and Xcode 27 toolchain |
| `host-sanitized` | Runtime race and ownership evidence | ASan/TSan host tests for release-equivalent code |

The base minimum OS is still a policy decision. Core AI's iOS 27 availability
must not raise the base CPU/Metal minimum silently.

## Tracking model

Tracking is a recursive progressive-disclosure hierarchy, not a flat exhaustive
inventory. The only status source is Markdown rooted at
[CAPABILITY_LEDGER.md](CAPABILITY_LEDGER.md), using this form:

```markdown
- [x] **Capability**: The declared scope is complete. [evidence](GATE.md)
- [ ] **Capability family**: The declared scope is incomplete. [tracker](trackers/family.md)
  - [x] **Narrow child**: This child is complete.
  - [ ] **Narrow child**: This child is incomplete.
```

`[x]` means the declared scope is complete, whether supported or deliberately
rejected; the description says which. `[ ]` means it is incomplete. The
description always describes the real capability and current boundary.
Decomposition is optional structure, never a third state: add nested items or
one linked tracker only when finer tracking is useful. A broad unchecked leaf
is valid and can be unpacked later.

A checked parent cannot contain an unchecked descendant. An unchecked parent
may mix checked and unchecked children, so its row gives the answer without
opening its tracker while its children explain why. Each tracker file has one
canonical parent and remains small enough to scan at a glance. Issues, plans,
gates, and cross-references do not duplicate status.

As a branch becomes actionable, its row or linked gate should progressively
record the standard Mojo/MAX surface, normal compiler/library/runtime path,
blocker, applicable lanes, evidence or diagnostic, next completion gate, and
upstream ownership. Missing facts are written as `not recorded yet`, not
guessed. Summary rows link to detail instead of repeating all metadata.

The validator must fail on malformed task rows, broken pointers, orphan or
multiply-parented tracker files, cycles, checked parents with unchecked
descendants, duplicate sibling names, absent top-level coverage divisions, or
oversized tracker files. The pre-commit hook validates the exact staged
snapshot; CI must run the same command. No TOML, YAML, database, or generated
status view shadows the Markdown hierarchy.

## Milestones

### M0: truthful tracking foundation

- Keep the root task list at a complete, glanceable subsystem division.
- Split current detail into small, singly-parented Markdown task trackers.
- Validate task syntax, links, graph structure, status roll-up, and root
  coverage recursively.
- Run the same validator against the exact staged snapshot and in CI.
- Link current positive and negative gates from the affected branches as those
  branches are unpacked.

Exit: there is one status source, every present claim is scoped to its evidence,
and fresh sessions cannot silently bypass or fork the tracker hierarchy.

### M1: stable distribution gate

- Build a signed CPU/Metal reference archive through the selected Apple
  toolchain lane.
- Add forbidden-content, public-API, privacy, architecture, signing, license,
  and dependency audits.
- Validate the archive through Xcode.
- Record TestFlight acceptance separately from local validation.

Exit: the base CPU/Metal package passes its declared privacy and provenance
gates, and the same archive path passes stable-Xcode App Store validation,
without making a Core AI claim. The project accepts Xcode 27 preview
reproducibility and provenance as sufficient M1 evidence; every published
release must still rerun the gates against its exact production tuple.

### M2: CPU compiler and runtime closure

- Establish the upstream language conformance corpus.
- Complete CompilerRT/AsyncRT ABI census and link closure.
- Fill generic compiler, Darwin stdlib, and Apple runtime gaps.
- Add multiple-library, lifecycle, O0/O3, ASan, and TSan gates.

Exit: every portable CPU language/runtime family is either proved in every base
lane or rejected with a named diagnostic.

### M3: standard library and production ABI

- Classify the complete target-sensitive stdlib/MAX inventory.
- Add positive and negative subsystem gates.
- Define ownership, errors, callbacks, handles, and allocator rules.
- Complete Swift concurrency and multi-library composition tests.

Exit: a library author can determine support mechanically from transitive
capabilities and can expose production C/Swift APIs without relying on sample
conventions.

### M4: general Metal backend

- Complete argument inference, resources, synchronization, launch controls, and
  O0/debug semantics.
- Add tensor, TensorOps, and quantized operation families.
- Prove the A-series iPhone and M-series iPad lanes.

Exit: the declared Metal capability set is broad, operation-indexed, and
release-gated; unlisted operations fail by name.

### M5: upstream-shaped Core AI backend

- Select the generic graph IR and implement explicit conversion.
- Add resource/package composition and unrepresentable-operation gates.
- Execute on iOS/iPadOS 27 hardware and retain Instruments evidence.

Exit: the declared Core AI graph subset executes through public APIs with no
fallback and with placement claims limited to observable evidence.

### M6: remaining general async

- Adopt public task construction, cancellation, async I/O, and GPU-await as
  upstream semantics become available.
- Implement only their normal lowering and AsyncRT operations.

Exit: every public upstream async capability is classified and the supported
subset passes lifetime, cancellation, error, and race gates.

### M7: upstream and release sustainability

- Split and submit the patch series by ownership.
- Add rebase and compatibility-tuple CI.
- Sign release artifacts and publish reproducible hashes and notices.
- Exercise the full release matrix before every support-contract change.

Exit: the project can follow upstream without reconstructing a private fork and
can publish a repeatable release artifact.

## Overall completion condition

The broad project objective is complete only when:

1. every upstream language and standard-library surface reachable by an iOS
   library has a tracked disposition;
2. every supported CPU capability passes the complete base target matrix;
3. the declared Metal and Core AI operation sets pass their hardware matrices;
4. no missing operation is hidden by CPU, serial, Metal, or Core AI fallback;
5. the public C/Swift ABI has complete ownership and error semantics;
6. the release artifact passes the App Store distribution gate;
7. unsupported operations fail at their earliest normal boundary; and
8. the complete source delta remains represented by an upstream-shaped,
   continuously rebased patch series.

The next implementation milestone is **M2**, CPU compiler and runtime closure.
M0 and M1 are complete. No additional isolated accelerator feature should be
promoted to supported unless those foundations describe and release-gate it
accurately.
