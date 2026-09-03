# Async and concurrency

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

## Proved slice

- [x] **Language async**: Ordinary `async def`, `await`, results, raised errors, suspension, and executor-thread resumption use generic coroutine lowering and normal AsyncRT chains. [evidence](../ASYNC_GATE.md)

## Pinned public-surface boundary

- [x] **Public task API**: Deliberately absent — task construction is private in the pinned upstream surface and is not publicized by this project.
- [x] **Cancellation**: Deliberately absent — the pinned public surface defines no cancellation semantics, and this project does not add them.
- [x] **Async I/O**: Deliberately absent — the pinned public surface defines no Mojo async-I/O contract, and this project does not add one.
- [x] **Accelerator await**: Deliberately absent — the pinned public surface defines no cross-backend accelerator-await contract, and this project does not add one.

## Verification backlog

- [ ] **Remaining pinned public async and concurrency surface**: Verification is pending for public stdlib/MAX operations reachable by an AOT library beyond the proved language-async and `max.algorithm.parallelize` slices; no missing iOS implementation is presumed.
