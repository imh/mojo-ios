# CPU collections and iteration

Parent: [Remaining portable CPU families](cpu-portable-remaining.md)

These verification scopes come from `mojo/stdlib/test/collections`, `iter`, and
`itertools`. Unchecked means not yet tested across the Apple matrix, not known
unsupported. These largely generic facilities are expected to work unchanged.
Each item needs ordinary O0/O3 fixtures, upstream-equivalent failure behavior,
and explicit native dependencies. A blocker or corrective patch owner will be
recorded only if testing discovers one; none is recorded yet.

## Verification backlog

- [ ] **Fixed arrays**: Verify `Array` and inline fixed-size construction, indexing, mutation, iteration, copy/move, and destruction through ordinary generic lowering.
- [ ] **Lists**: Verify `List` growth, reserve, insertion, removal, slicing, mutation, negative indexing, ownership, and destruction through the existing allocator-backed path.
- [ ] **Spans and views**: Verify `Span` and borrowed-view slicing, address spaces, mutation, aliasing, bounds, and origin-invalidation diagnostics preserve upstream behavior.
- [ ] **Dictionaries**: Verify `Dict` lookup, insertion, replacement, removal, iteration, hashing, equality, and owned key/value lifetimes through ordinary stdlib code.
- [ ] **Sets and keyed utilities**: Verify `Set`, `Counter`, and `TypeDict` preserve standard hashing/type-key semantics and invalid-key diagnostics.
- [ ] **Deque and linked list**: Verify end operations, indexed access, insertion/removal, negative indices, iteration, and node/value destruction through ordinary stdlib code.
- [ ] **Binary heap**: Verify heap construction, ordering, push/pop/peek, ownership, and empty-operation failure semantics through the normal path.
- [ ] **Small value collections**: Verify `Optional`, `Conditional`, `Interval`, and `BitSet` construction, access, mutation, iteration, and invalid-access behavior.
- [ ] **Strings and UTF-8**: Verify `String` storage, byte/codepoint access, slicing, search, mutation, numeric conversion, and valid/invalid UTF-8 behavior while attributing any native dependencies.
- [ ] **Unicode and graphemes**: Verify codepoint, Unicode-property, grapheme-segmentation, and `StringSpan` semantics from upstream conformance cases without platform-library substitution.
- [ ] **Iterator protocols**: Verify `Iterator`, `Iterable`, `next`, `nth`, reference iteration, and ownership of yielded values through ordinary generic dispatch.
- [ ] **Iterator adapters**: Verify `map`, `chain`, `zip`, `enumerate`, `peek`, `once`, and `empty` preserve lazy state, exhaustion, nesting, and captured-callable semantics.
- [ ] **Itertools sequences**: Verify `count`, `cycle`, `repeat`, `take`, `drop`, predicate variants, and Cartesian product preserve termination, state ownership, and negative-count behavior.
- [ ] **Collections corpus closure**: Run the selected unchanged collection/iterator fixtures through independent host, device, and Simulator O0/O3 links, dependency audits, failure checks, and applicable generated-Mojo ASan coverage.
