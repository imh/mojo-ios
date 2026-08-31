# Embedded runtime

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **Reached Apple runtime ABI**: CompilerRT and AsyncRT implement the normal operations instantiated by current CPU, parallel, async, and Metal probes without a project initializer.
- [x] **Release runtime separation**: Shipped device and Simulator archives exclude test-only AsyncRT controls; instrumented host and sanitizer products remain separate.
- [ ] **Complete runtime ABI census**: Classify every upstream CompilerRT and AsyncRT operation, including operations not reached by current probes.
- [ ] **Runtime lifecycle**: Initialization, teardown, globals destruction, executor shutdown, app lifecycle, foreign-thread entry, and release-equivalent sanitizer behavior remain incomplete.
