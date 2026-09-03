# Metal

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

## Proved slices

- [x] **AIR feasibility codegen**: Apple AIR is a peer offload target and LLVM 17 bitcode packages as `metallib` through normal compiler interfaces.
- [x] **Dispatch and indexing slice**: X/Y/Z builtins, 3D dispatch, buffers, copies, synchronization, and ordinary enqueue execute on Mac, Simulator, and physical iPad.
- [x] **Arguments and captures slice**: Direct buffers, scalar and aggregate values, nested device-pointer fixups, and captured scalar closures pass named gates.
- [x] **Multiple kernels**: Several kernels coexist in one Mojo library without concatenating opaque archives.
- [x] **Threadgroup memory slice**: Static and dynamic threadgroup memory have explicit AIR lowering and runtime validation.
- [x] **CUDA-only launch attributes**: Metal accepts `IGNORE` and deliberately rejects concrete CUDA-only attributes by name before dispatch.

## Enablement queue — known backend gaps

Work these dependency-ordered items from top to bottom, retaining the existing
Mac, Simulator, physical-device, negative-diagnostic, and no-fallback gates for
every increment.

- [x] **General argument inference**: Fixed-arity unified closures infer through the normal heterogeneous pack trait; scalar, SIMD, padded struct, repeated/multiple buffer, offset, and nested global-pointer layouts pass Mac, Simulator, and physical-iPad gates. Runtime `Tuple` and nested generic pointers are deliberately rejected by name. [evidence](../METAL_FEASIBILITY_GATE.md)
- [x] **O0 and debug information**: True O0 uses only required AIR legalization; line tables and full debug retain source information, package as validated metallibs with dSYM companions, and pass O0/O3 execution on Mac, both Simulator classes, and the physical iPad without optimization or debug-mode downgrades. [evidence](../METAL_O0_DEBUG_GATE.md)
- [ ] **Metal 4 and AIR 2.8**: Metal 4 targets remain unregistered while the backend emits AIR 2.4 metadata.
- [ ] **Existing tensor and quantized operations**: Metal lowering and availability checks remain incomplete for tensor, TensorOps, and quantized operations already present in the pinned public surface.

## Verification queue

- [ ] **Atomics, barriers, and simdgroups**: Verification — the pinned atomic-reduction source, including global atomics, threadgroup compare-exchange, and `barrier()`, compiles through Apple Metal at O3; true-O0, runtime memory-model, and simdgroup coverage remain unproved.

See [Metal feasibility evidence](../METAL_FEASIBILITY_GATE.md).
