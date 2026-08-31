# Standard MAX

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **CPU parallelize**: Standard `max.algorithm.parallelize` follows unchanged `sync_parallelize` → CPU `DeviceContext` → generic coroutine lowering with ordinary captured closures. [evidence](../CONCURRENCY_GATE.md)
- [ ] **MAX Mojo libraries**: Classify public algorithms, tensor operations, and device utilities beyond the proved `max.algorithm.parallelize` slice.
- [ ] **MAX graph and model runtime**: Classify the public graph, compiler, model, and backend-selection surface; the open driver does not currently expose the standard backend extension needed for Core AI.
