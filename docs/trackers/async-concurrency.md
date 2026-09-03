# Async and concurrency

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

## Proved slice

- [x] **Language async**: Ordinary `async def`, `await`, results, raised errors, suspension, and executor-thread resumption use generic coroutine lowering and normal AsyncRT chains. [evidence](../ASYNC_GATE.md)

## Enablement queue — general upstream contracts and normal Apple lowering

- [ ] **Public task API**: Turn the existing private upstream task construction path into a general public contract, then preserve that contract unchanged on iOS; no iOS substitute is permitted.
- [ ] **Cancellation**: Define and contribute general semantics and lowering, then implement normal Apple AsyncRT cancellation with race and lifetime evidence.
- [ ] **Async I/O**: Add the general public Mojo async-I/O contract and its normal Darwin implementation rather than an iOS-only surface.
- [ ] **Accelerator await**: Define general cross-backend await semantics and lifetime/error propagation, then implement the Apple accelerator operations through that path.
