# Mojo language and compiler

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

## Proved slices

- [x] **Proved CPU language slice**: Scalars, SIMD, representative allocation and collection cases, immutable global constants, arguments, repeated calls, and simultaneous Swift-owned-thread entry pass the named device and Simulator gates at O0/O3.
- [x] **Existing unified-closure paths**: CPU parallelism and Metal scalar capture use normal unified closures without an iOS-facing closure API.

## Verification backlog

- [ ] **Language conformance**: Nineteen ordinary-Mojo CPU families pass; verification is still pending for portable memory, collection, iteration, reflection, and other upstream families, which are not presumed to need iOS-specific implementation. [tracker](cpu-language-conformance.md)
- [ ] **Closure families**: Thin-function, CPU-parallel, and Metal-capture slices pass; verification is still pending for the broader standard unified-closure surface, which is expected to use generic lowering unchanged. [tracker](cpu-closure-families.md)
