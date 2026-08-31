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

The canonical status source is the GitHub task-list hierarchy rooted at
`docs/CAPABILITY_LEDGER.md`. The destination and milestone plan live in
`docs/ARBITRARY_AOT_MOJO_PLAN.md`, but plans and issues never redefine current
support status.

Use only this terse tracker form:

```markdown
- [x] **Capability**: Declared scope is complete. [evidence](gate.md)
- [ ] **Larger capability**: Work remains. [tracker](trackers/child.md)
  - [x] **Completed child**: This narrower scope is complete.
  - [ ] **Open child**: This narrower scope is incomplete.
```

- `[x]` means the item's declared scope is complete. Its description must say
  whether the result is supported or deliberately rejected.
- `[ ]` means the item's declared scope is not complete.
- Description text describes the capability and its current boundary. It must
  not use decomposition state as a substitute for a real description.
- Decomposition is optional structure, not a status or disposition. Add nested
  children or one linked `[tracker](...)` file only when finer tracking is
  useful. A leaf may remain broad and unchecked.
- A checked item may not have an unchecked descendant, including descendants
  in a linked tracker. An unchecked item may mix checked and unchecked
  children.
- A branch may put children directly below it or delegate to one tracker file,
  but not both. The linked file uses the same task-list form.
- Keep each tracker file glanceable. Split a branch into a linked tracker when
  the file would exceed roughly 10–15 task rows.

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

When work reveals more detail, unpack only the affected unchecked node while
leaving unrelated branches at their existing level. Every tracker file must be
reachable from exactly one parent in the canonical hierarchy. Other documents
may cross-reference it, but may not maintain a duplicate status list.

When a node becomes actionable, its description and links must expose enough to
judge it without inference:

- the standard Mojo/MAX surface or upstream test family;
- the normal compiler/library/runtime path;
- its disposition and blocker;
- applicable target lanes;
- positive evidence, negative diagnostic, or explicit absence of evidence;
- the next completion gate; and
- upstream patch or issue ownership when known.

If one of those facts has not been established, write `not recorded yet`
instead of guessing. Do not copy all metadata into every summary row; link to
the gate or narrower tracker that records it. Never create a second
hand-maintained status source.

Before completing tracker-related work, verify:

1. every top-level division is still present;
2. every pointer resolves;
3. every row has only a checkbox, a stable scoped name, a real description,
   and optional children or one tracker link;
4. no broad parent is marked supported from evidence for only one child;
5. unsupported target-known behavior has a named normal failure and no
   fallback; and
6. documentation changes do not contradict current gates or artifacts.

Run `./scripts/verify-tracker-structure.sh` after every tracker or tracker-link
change. The repository-managed pre-commit hook runs the same verifier against
the exact staged snapshot whenever tracker-related files change. On a fresh
checkout, install it with `pixi run install-git-hooks`; do not assume Git copied
or activated hooks automatically. This is the required structural gate.
Milestone M0 completes it with recursive Markdown validation and CI; it does
not introduce a parallel TOML, YAML, or generated status source.

## Incomplete implementation style

- Prefer correctness-first architecture with explicit `NotImplemented`,
  `todo!()`, or equivalent stubs over clean code for a special case.
- Make future cases explicit in switches and matches rather than hiding them in
  a wildcard or accidental default.
- Use assertions liberally while invariants are being established.
- Prefer concrete names and explicit proof over terse or clever equivalents.
- Optimize for steady-state upstream/rebase velocity, not the shortest local
  patch.
