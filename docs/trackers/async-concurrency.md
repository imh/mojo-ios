# Async and concurrency

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

## Proved slice

- [x] **Language async**: Ordinary `async def`, `await`, results, raised errors, suspension, and executor-thread resumption use generic coroutine lowering and normal AsyncRT chains. [evidence](../ASYNC_GATE.md)

## Verification backlog

- [ ] **Remaining pinned public async and concurrency surface**: Verification is pending for public stdlib/MAX operations reachable by an AOT library beyond the proved language-async and `max.algorithm.parallelize` slices; no missing iOS implementation is presumed.
