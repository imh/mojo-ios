# Async and concurrency

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **Language async**: Ordinary `async def`, `await`, results, raised errors, suspension, and executor-thread resumption use generic coroutine lowering and normal AsyncRT chains. [evidence](../ASYNC_GATE.md)
- [ ] **Public task API**: Upstream task construction remains private; no iOS substitute is permitted.
- [ ] **Cancellation**: Upstream semantics, generic lowering, Apple AsyncRT behavior, and race/lifetime evidence remain unavailable.
- [ ] **Async I/O**: No general public Mojo async-I/O surface exists to implement normally on iOS.
- [ ] **Accelerator await**: General cross-backend await semantics and lifetime/error propagation remain upstream gaps.
