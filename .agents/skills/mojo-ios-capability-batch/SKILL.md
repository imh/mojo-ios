---
name: mojo-ios-capability-batch
description: Work on ordinary Mojo/MAX support for iOS or iPadOS in this repository. Use when planning, implementing, testing, reviewing, or reporting capability gaps; compiler, stdlib, runtime, ABI, Xcode, Metal, Core AI, Simulator, device, packaging, evidence, or tracker work all trigger it. Do not use for unrelated application features.
---

# Mojo iOS capability batch

Extend the proved ordinary-Mojo/MAX surface without creating an iOS-facing
Mojo API, compiler abstraction, runtime ABI, or fallback.

## Establish live scope

1. Read the repository `AGENTS.md` completely.
2. Inspect the working tree and preserve unrelated changes.
3. Read `docs/CAPABILITY_LEDGER.md`, `docs/ROADMAP.md`, and only the child
   tracker and gate documents relevant to the requested branch.
4. Treat the tracker hierarchy as the only status source. Never copy current
   support status into this skill.
5. Inspect the pinned upstream source and current patch before deciding where
   a missing capability belongs. Do not answer from remembered Mojo, MAX, or
   Apple behavior when the repository or installed toolchain can establish it.

## Define a bounded batch

Unless the user selects another scope, choose work in this order:

1. a regression in already proved behavior;
2. a reproduced or source-confirmed **enablement** gap with actionable normal
   implementation or upstream architecture work;
3. verification narrowly required to complete that enablement; then
4. broad **verification** expected to pass unchanged.

Never classify work as **blocked** only because the correction belongs upstream
or must add a general upstream contract or extension point that this project
has explicitly taken into scope. Reserve blocked for a prerequisite outside
the project's chosen implementation scope that cannot presently be advanced.
Do not let milestone numbering or an unchecked verification row outrank
actionable enablement. If verification discovers a concrete failure,
reclassify that scope as enablement before expanding the fix.

For the selected batch, state:

- the ordinary upstream Mojo/MAX surface being tested;
- its normal compiler, library, runtime, and backend path;
- positive fixtures and explicit negative diagnostics;
- host, Simulator, physical-device, optimization, and sanitizer lanes that
  materially apply;
- completion criteria and intentionally excluded adjacent capabilities; and
- the expected upstream ownership of any correction.

Do not use elapsed-time estimates as the batch definition.

## Implement through normal paths

- Keep Mojo fixtures free of iOS imports, target branches, project runtime
  calls, alternate closure conventions, and fallback behavior.
- Compile and fully link fixtures independently so one combined artifact
  cannot hide a missing lowering or runtime dependency.
- Fix a target-independent defect generically and add a non-iOS regression.
- Fill an existing Darwin, CompilerRT, AsyncRT, MAX, or accelerator extension
  point when the defect is target-specific.
- If upstream has no appropriate extension point, either implement a genuinely
  general upstream-shaped extension when that architecture work is in scope,
  or record a precise external blocker and stop at an explicit unsupported
  boundary. Never add a project-only parallel abstraction.
- Prefer a named compile-time failure. Use an owned runtime error only when the
  support decision is inherently dynamic. Never accept an unresolved symbol
  or silent fallback as a disposition.
- Keep every upstream checkout edit represented by the repository patch stack.

When writing Mojo, verify syntax against the pinned compiler and current
stdlib/MAX sources rather than relying on older examples.

## Produce evidence

Use the existing `pixi.toml` tasks and repository scripts before adding a new
runner. For executable portable CPU work, the default proof matrix is macOS
ARM64, iOS device ARM64, and ARM64 Simulator at O0 and O3, with execution on
both iPhone and iPad Simulators and meaningful physical hardware. Narrow or
expand that matrix only when the capability itself justifies it.

Evidence should cover, where applicable:

- host-result or semantic comparison;
- Swift-owned-thread entry and concurrency;
- generated-Mojo and real-runtime sanitizer instrumentation;
- undefined symbols, external dependencies, platform metadata, and absence of
  project-specific ABI;
- operation-specific unsupported diagnostics; and
- regression of already proved CPU, async, Metal, packaging, and tracker gates.

Follow `AGENTS.md` for Xcode selection and Metal-toolchain discovery. Never
infer hardware or framework absence from a sandboxed probe.

## Keep mechanics deterministic

Put repeated executable behavior in repository scripts, not prose or
skill-local scripts. Humans and CI must be able to run the same operations.
Avoid a universal runner whose options hide the capability being proved.

Use these shared tools instead of reproducing their mechanics:

- Before an Apple build, source `scripts/lib/apple-toolchain.sh` and call
  `mojo_ios_select_apple_toolchain`. Call
  `mojo_ios_discover_metal_frontend` when Metal is required. Use
  `scripts/resolve-apple-toolchain.sh` for a standalone preflight.
- Run the pinned source-built compiler through `scripts/run-source-mojo.sh`,
  or source `scripts/lib/source-mojo.sh` when one gate needs several compiler
  calls. Keep target, optimization, sanitizer, include, and output arguments
  explicit at the call site.
- Build embedded CompilerRT/AsyncRT objects with
  `scripts/build-embedded-apple-runtime.sh`. Do not copy its canonical source
  list or build flags into a new gate.
- Use `scripts/run-simulator-app.sh` and `scripts/run-device-app.sh` for normal
  install-launch-marker-cleanup execution. Use `scripts/wait-for-marker.sh`
  inside special lifecycle or instrumentation sequences. Leaving an app alive
  must be explicit.
- Run `scripts/audit-ordinary-mojo-source.py` on positive Mojo fixtures.
- Run `scripts/audit-upstream-surface.py` whenever the upstream patch changes;
  inspect every reported declaration, even when the forbidden-name gate passes.
- Use `scripts/audit-macho-contract.py` for object and linked-artifact symbol,
  platform, and dependency assertions. Keep the expected contract in the
  capability gate or its concise config file.
- Use `scripts/record-gate-evidence.py` for mechanical run receipts under
  `build/evidence`. Receipts are evidence, never support status.

Continue to use the existing patch verifier, runtime ABI census, distribution
auditor, packaging tools, release-provenance tools, and tracker validator for
their established scopes. Do not create replacements for them.

## Close the batch truthfully

1. Record exact evidence and remaining boundaries in one gate document.
2. Update only the affected canonical tracker branch after its gates pass.
3. Check that no broad parent becomes complete from evidence for one child.
4. Run `./scripts/verify-tracker-structure.sh`, patch verification, relevant
   focused and nonregression gates, and `git diff --check`.
5. Report exact target lanes, pass/fail results, generic fixes, explicit
   blockers, and remaining work.
6. Do not commit, push, upload, submit, or otherwise mutate external state
   unless the user requests it.
