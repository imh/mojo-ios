# Remaining portable CPU families

Parent: [CPU language conformance](cpu-language-conformance.md)

An unchecked child means verification is pending, not that the capability is
known broken or needs iOS-specific code. The expected first result is that the
normal Mojo compiler and standard-library path works unchanged. Each gate must
use ordinary Mojo, preserve host semantics, independently link device and ARM64
Simulator artifacts, and execute on the applicable base lanes. Only an observed
failure creates implementation work: fix generic defects generically, fill an
existing Darwin extension point when genuinely target-specific, or preserve a
named upstream rejection without a project ABI or fallback. No unresolved
blocker or patch owner is recorded yet.

## Verification backlog

- [ ] **Memory and pointer semantics**: Verify that standard allocation, pointer, address-space, initialization, and managed-ownership behavior follows its normal lowering and runtime paths unchanged. [tracker](cpu-memory-pointers.md)
- [ ] **Collections and iteration**: Verify that standard containers, strings, views, iterator protocols, and lazy adapters compose from their normal generic and runtime paths unchanged. [tracker](cpu-collections-iteration.md)
- [ ] **Compile-time materialization and reflection**: Verify that standard compile-time values, AOT materialization, and public reflection metadata remain target-independent and introduce no shipped compiler/JIT dependency. [tracker](cpu-comptime-reflection.md)
- [ ] **Integrated portable-corpus closure**: After the three verification branches pass, rescan the pinned portable KGEN and stdlib families, classify every newly exposed family, and run the combined independent-link O0/O3 matrix; this remains open for any unclassified normal-path surface.
