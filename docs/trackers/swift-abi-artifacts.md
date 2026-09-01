# Swift ABI and AOT artifacts

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **Mojo AOT artifact**: The proved product ships ahead-of-time CPU objects and accelerator artifacts with no Mojo compiler or JIT.
- [x] **Static XCFramework**: Separate ARM64 device and Simulator static-framework variants package successfully with headers, module maps, and SDK privacy resources for the current sample.
- [x] **Sample Swift/C ABI**: Fixed-width scalar exports and pointer-buffer samples cross an explicit C ABI; Mojo internal ABI and `raises` do not cross it.
- [x] **Apple specialization policy**: Public Apple frameworks may specialize shipped Metal/Core AI artifacts; project-owned executable generation remains prohibited.
- [ ] **Production ownership and errors**: Strings, slices, structures, handles, allocators, diagnostics, callbacks, reentrancy, Swift concurrency, and ABI versioning remain incomplete.
- [ ] **Multiple Mojo libraries**: Duplicate runtime ownership, global state, shutdown, and symbol composition remain unproved.
- [ ] **Release package**: A versioned Xcode 27 preview ZIP contains privacy resources, SPDX provenance, project and Modular licenses/notices, and deterministic hashes; final publication identity and exact clean production-tuple evidence remain per-release work. [gate](../RELEASE_PROVENANCE_GATE.md)
- [ ] **Signed XCFramework**: The preview candidate is Apple Developer-signed and rejects unsigned or ad-hoc replacements; final public identity pinning and consumer-Xcode evidence remain. [gate](../RELEASE_PROVENANCE_GATE.md)
