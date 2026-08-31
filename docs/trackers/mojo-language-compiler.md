# Mojo language and compiler

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **Proved CPU language slice**: Scalars, SIMD, allocation, collections, globals, arguments, repeated calls, and simultaneous Swift-owned-thread entry pass the named device and Simulator gates at O0/O3.
- [x] **Existing unified-closure paths**: CPU parallelism and Metal scalar capture use normal unified closures without an iOS-facing closure API.
- [ ] **Language conformance**: Prove or explicitly reject ownership/destruction, generics, traits, errors, TLS, atomics, callbacks, FFI, math intrinsics, and optimization-sensitive upstream families.
- [ ] **Closure families**: Prove standard-library, MAX, callback, and offload closure families beyond the current CPU-parallel and Metal-capture probes.
