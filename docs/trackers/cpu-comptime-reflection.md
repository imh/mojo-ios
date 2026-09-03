# CPU compile-time materialization and reflection

Parent: [Remaining portable CPU families](cpu-portable-remaining.md)

These verification scopes come from the pinned KGEN compile-time integration
tests and `mojo/stdlib/test/reflection`. Unchecked means not yet tested for AOT
iOS, not known target-dependent. These compiler facilities are expected to work
unchanged. Each item needs generic compiler evidence plus artifact checks where
a value or metadata object reaches runtime. A blocker or corrective patch owner
will be recorded only if testing discovers one; none is recorded yet.

## Verification backlog

- [ ] **Compile-time control and diagnostics**: Verify compile-time assertions, conditionals, dead branches, evaluation failures, and diagnostics remain generic and agree for host and iOS compilation.
- [ ] **Compile-time tuples and lists**: Verify construction, indexing, iteration, specialization, and conversion of compile-time tuple/list values through normal elaboration and AOT materialization.
- [ ] **Compile-time dictionaries and sets**: Verify key semantics, duplicate handling, membership, set operations, and deterministic specialization against pinned upstream behavior.
- [ ] **Compile-time strings**: Verify standard compile-time string construction, concatenation, formatting-relevant values, and storage transitions produce deterministic artifacts.
- [ ] **Runtime materialization boundary**: Verify compile-time values captured into runtime constants, arguments, aggregates, and generic specializations become ordinary target data with no compiler/JIT dependency.
- [ ] **Type and trait reflection**: Verify public type information, trait queries, field/type metadata, and reflection-driven generics through ordinary stdlib execution.
- [ ] **Function and source-location reflection**: Verify function metadata and `SourceLocation` values have deterministic, privacy-auditable AOT behavior under an explicit path/provenance policy.
- [ ] **Compile-time/reflection corpus closure**: Run runtime-bearing fixtures through independent base O0/O3 links, audit emitted constants/metadata and dependencies, and verify compile-only cases retain generic diagnostics.
