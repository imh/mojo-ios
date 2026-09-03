# CPU memory and pointers

Parent: [Remaining portable CPU families](cpu-portable-remaining.md)

These verification scopes come from `mojo/stdlib/test/memory`. Unchecked means
not yet tested across the Apple matrix, not known unsupported. The expected
result is unchanged normal lowering. Each item needs ordinary-Mojo O0/O3
evidence and matching upstream diagnostics for invalid forms. A generic fix,
Darwin implementation, blocker, or upstream patch owner will be recorded only
if testing discovers one; none is recorded yet.

## Verification backlog

- [ ] **Raw pointer operations**: Verify normal `std.memory` lowering and execution for pointer construction, null values, loads/stores, indexing, arithmetic, comparison, and subtraction.
- [ ] **Address-space semantics**: Verify typed address spaces and legal conversions preserve their normal IR, while mismatched comparison/subtraction keeps its upstream diagnostic.
- [ ] **Allocation and layout**: Verify allocation, deallocation, size, alignment, over-alignment, and zero-sized-layout behavior through the existing allocator/runtime path.
- [ ] **Initialization state**: Verify `MaybeUninit`, write/take/drop, partial initialization, and uninitialized-use checks preserve normal lifetime and poison/checking behavior.
- [ ] **Owned pointers**: Verify `OwnedPointer` creation, transfer, mutation, destruction, and error-path cleanup produce exactly-once ownership behavior under O0/O3.
- [ ] **Atomic reference counting**: Verify standard ARC retain/release, copy/move, concurrent ownership, and final destruction through the normal runtime with real-worker sanitizer coverage.
- [ ] **Unsafe address and bitcast boundary**: Verify raw-address construction, representable bitcasts, overflow behavior, and illegal-conversion diagnostics match the target width and upstream semantics without a shim.
- [ ] **Memory failure semantics**: Verify bounds, alignment, address-space, and nontrivial-write failures retain their upstream compile-time, assertion, or abort disposition rather than becoming link errors or fallback.
- [ ] **Memory corpus closure**: Run the selected unchanged memory fixtures through independent host, device, and Simulator O0/O3 links, dependency audits, and applicable generated-Mojo ASan/TSan instrumentation.
