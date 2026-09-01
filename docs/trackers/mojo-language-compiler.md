# Mojo language and compiler

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **Proved CPU language slice**: Scalars, SIMD, allocation, collections, immutable global constants, arguments, repeated calls, and simultaneous Swift-owned-thread entry pass the named device and Simulator gates at O0/O3.
- [x] **Existing unified-closure paths**: CPU parallelism and Metal scalar capture use normal unified closures without an iOS-facing closure API.
- [ ] **Language conformance**: The initial ordinary-Mojo CPU families pass, while target-sensitive and optimization-sensitive upstream families remain. [tracker](cpu-language-conformance.md)
- [ ] **Closure families**: Prove standard-library, MAX, callback, and offload closure families beyond the current CPU-parallel and Metal-capture probes.
