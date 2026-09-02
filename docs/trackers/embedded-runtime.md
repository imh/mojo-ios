# Embedded runtime

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **Reached Apple runtime ABI**: CompilerRT and AsyncRT implement the normal operations instantiated by current CPU, parallel, async, and Metal probes without a project initializer.
- [x] **Release runtime separation**: Shipped device and Simulator archives exclude test-only AsyncRT controls; instrumented host and sanitizer products remain separate.
- [x] **Complete pinned runtime C ABI census**: All 68 pinned CompilerRT and DeviceContext operations are implemented or compile-time rejected by name; unclassified additions fail the gate. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Process-resident runtime lifecycle**: Idempotent initialization, quiescent global teardown/recreation, context and async cleanup, foreign-thread entry, iOS suspend/resume and scene transitions, and generated-Mojo ASan/TSan pass; executor shutdown is deliberately absent under upstream process-lifetime semantics. [evidence](../CPU_RUNTIME_LIFECYCLE_GATE.md)
- [x] **Same-tuple runtime composition**: Two independently compiled ordinary-Mojo libraries share exactly one process runtime in both static archive orders without force-loading, a registry, or custom initialization. [evidence](../CPU_RUNTIME_LIFECYCLE_GATE.md)
