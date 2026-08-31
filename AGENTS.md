# Repository instructions

## Objective

Enable ordinary upstream Mojo and MAX programs to compile ahead of time for
iOS and iPadOS through their normal compiler, library, runtime, and accelerator
paths. Application authors must not need an iOS-only Mojo import, source branch,
closure convention, graph API, runtime initializer, or fallback.

Treat an upstream-compatible missing lowering, Darwin implementation, runtime
operation, target backend operation, or packaging step as the work. Do not make
an iOS special case look complete by introducing a parallel abstraction.

## Architecture requirements

- Preserve standard Mojo and MAX syntax and semantics.
- Fix generic lowering when the failure is generic; otherwise fill the normal
  target/backend/runtime extension point already used by peer targets.
- Do not invent a compiler abstraction solely for this project. If the normal
  upstream extension point does not exist, record an upstream blocker and stop
  at an explicit `NotImplemented` boundary.
- Prefer compile-time failure to runtime failure, and runtime failure to silent
  fallback. Never silently substitute CPU, serial, Metal, Core AI, or another
  backend for an unsupported operation.
- Keep CPU, programmable Metal, and Core AI graph execution as distinct normal
  paths. Apple-owned specialization is allowed, but project-owned fallback is
  not.
- Keep the shipped application AOT-only: no Mojo source, compiler, JIT support,
  or downloaded executable Mojo input.

## Progressive tracking is required

The canonical tracker root is the **Top-level coverage index** in
`docs/CAPABILITY_LEDGER.md`. The destination and tracking rules live in
`docs/ARBITRARY_AOT_MOJO_PLAN.md`; the ledger remains the current status source
until validated generated manifests replace it.

Tracking uses recursive progressive disclosure. It is intentionally not one
flat exhaustive list. Every tracker node must have a stable scope, and every
part of that scope must be accounted for by one of these dispositions:

1. **Items here**: the node contains concrete child capabilities or work items.
2. **Delegated**: the node points to one or more deeper tracker documents or
   sections that obey this same rule.
3. **Not decomposed yet**: the node explicitly says that its remaining surface
   has not been inventoried. This means no support is claimed for that surface.

A node may contain current items and also retain a `not decomposed yet`
remainder. It may not use `other`, `remaining`, `etc.`, or similarly open-ended
language unless that remainder is explicitly marked `not decomposed yet`.

The root coverage index must always cover, directly or by delegation:

- Mojo language and generic compiler lowering;
- standard library and native dependencies;
- standard MAX libraries, algorithms, graphs, and device behavior;
- CompilerRT, AsyncRT, concurrency, and async;
- Swift/C ABI and multi-library lifecycle;
- Metal programmable acceleration;
- Core AI and ANE scheduling;
- target, SDK, OS, simulator, and physical-hardware lanes;
- AOT artifacts, packaging, and App Store distribution; and
- upstream patch ownership, compatibility, and tracking evidence.

When work reveals more detail, unpack only the affected node. Replace its
`not decomposed yet` remainder with child items or a delegated tracker, while
leaving unrelated nodes at their existing level. Do not create an orphan
checklist: every new tracker must be linked from exactly one parent in the
canonical hierarchy, though other documents may cross-reference it.

When a node is unpacked into an actionable leaf, it must state—directly or in
its canonically delegated gate—enough to judge it without inference:

- the standard Mojo/MAX surface or upstream test family;
- the normal compiler/library/runtime path;
- its disposition and blocker;
- applicable target lanes;
- positive evidence, negative diagnostic, or explicit absence of evidence;
- the next completion gate; and
- upstream patch or issue ownership when known.

If one of those facts has not been established, write `not recorded yet`
instead of guessing. During the Markdown-to-manifest M0 transition, existing
summary rows may remain non-leaf nodes as long as their undecomposed remainder
or delegated evidence is explicit.

Issues and plans may schedule work, but they do not redefine support status.
Never create a second hand-maintained status source. When machine-readable
tracking lands, generated views replace Markdown status tables atomically.

Before completing tracker-related work, verify:

1. every top-level division is still present;
2. every pointer resolves;
3. every leaf is actionable, delegated, or explicitly not decomposed yet;
4. no broad parent is marked supported from evidence for only one child;
5. unsupported target-known behavior has a named normal failure and no
   fallback; and
6. documentation changes do not contradict current gates or artifacts.

Run `./scripts/verify-tracker-structure.sh` after every tracker or tracker-link
change. This is the required interim structural gate. Milestone M0 must replace
its hard-coded Markdown assertions with validation of the hierarchical
machine-readable manifests without weakening these checks.

## Incomplete implementation style

- Prefer correctness-first architecture with explicit `NotImplemented`,
  `todo!()`, or equivalent stubs over clean code for a special case.
- Make future cases explicit in switches and matches rather than hiding them in
  a wildcard or accidental default.
- Use assertions liberally while invariants are being established.
- Prefer concrete names and explicit proof over terse or clever equivalents.
- Optimize for steady-state upstream/rebase velocity, not the shortest local
  patch.
