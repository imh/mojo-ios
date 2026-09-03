# Standard MAX

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

## Proved slices

- [x] **CPU parallelize**: Standard `max.algorithm.parallelize` follows unchanged `sync_parallelize` → CPU `DeviceContext` → generic coroutine lowering with ordinary captured closures. [evidence](../CONCURRENCY_GATE.md)

## Verification backlog

- [ ] **MAX Mojo libraries**: Verification is pending for public algorithms, tensor operations, and device utilities beyond the proved `max.algorithm.parallelize` slice; no iOS defect is presumed.

## Enablement queue

- [ ] **MAX graph and model runtime**: Expose the normal internal backend hook needed to lower existing public graph operations, then implement Core AI through it without a new graph API or Mojo source special case.
