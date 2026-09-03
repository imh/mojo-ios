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
- [x] **Textures and samplers**: Deliberately absent — the pinned public Mojo/MAX surface exposes no general texture or sampler resource, and this project does not add one; ordinary image data remains expressible through standard buffers. [evidence](../METAL_FEASIBILITY_GATE.md)
- [ ] **Atomics, barriers, and simdgroups**: Complete AIR lowering and Metal memory-model evidence remain incomplete.
- [x] **Metal-native launch controls**: Deliberately absent — the pinned public launch surface is CUDA-shaped; `IGNORE` works and every concrete CUDA-only attribute is rejected by name, while this project adds no Metal-only public control.
- [ ] **O0/debug pipeline**: A distinct valid AIR debug pipeline remains undefined.
- [ ] **Metal 4 and AIR 2.8**: Metal 4 targets remain unregistered while the backend emits AIR 2.4 metadata.
- [ ] **Existing tensor and quantized operations**: Metal lowering and availability checks remain incomplete for tensor, TensorOps, and quantized operations already present in the pinned public surface.

See [Metal feasibility evidence](../METAL_FEASIBILITY_GATE.md).
