# Swift ABI and AOT artifacts

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **Mojo AOT artifact**: The proved product ships ahead-of-time CPU objects and accelerator artifacts with no Mojo compiler or JIT.
- [x] **Static XCFramework**: Separate ARM64 device and Simulator libraries package successfully for the current sample.
- [x] **Sample Swift/C ABI**: Fixed-width scalar exports and pointer-buffer samples cross an explicit C ABI; Mojo internal ABI and `raises` do not cross it.
- [x] **Apple specialization policy**: Public Apple frameworks may specialize shipped Metal/Core AI artifacts; project-owned executable generation remains prohibited.
- [ ] **Production ownership and errors**: Strings, slices, structures, handles, allocators, diagnostics, callbacks, reentrancy, Swift concurrency, and ABI versioning remain incomplete.
- [ ] **Multiple Mojo libraries**: Duplicate runtime ownership, global state, shutdown, and symbol composition remain unproved.
- [ ] **Release package**: Versioned resources, privacy files, notices, provenance, and deterministic hashes remain incomplete.
- [ ] **Signed XCFramework**: Distribution signing and consumer verification remain incomplete.
