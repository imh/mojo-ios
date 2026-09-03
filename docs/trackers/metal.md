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
- [ ] **Metal resource families**: Add explicit lowering, ABI representation, ownership, diagnostics, and device evidence for textures, samplers, and other public resources.
- [ ] **Atomics, barriers, and simdgroups**: Complete AIR lowering and Metal memory-model evidence remain incomplete.
- [ ] **Metal-native launch controls**: Supported Metal equivalents have not been defined and gated.
- [ ] **O0/debug pipeline**: A distinct valid AIR debug pipeline remains undefined.
- [ ] **Metal 4 and AIR 2.8**: Metal 4 targets remain unregistered while the backend emits AIR 2.4 metadata.
- [ ] **Tensor and quantized operations**: Public tensor/TensorOps abstractions, quantized types, and availability checks remain incomplete.

See [Metal feasibility evidence](../METAL_FEASIBILITY_GATE.md).
