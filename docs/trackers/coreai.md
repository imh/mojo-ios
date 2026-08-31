# Core AI and ANE

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [ ] **Public authoring interface**: Apple's documented beta flow still relies on underscored authoring modules; a stable public interface is required.
- [x] **Direct graph export feasibility**: A fixed-shape Float32 graph verifies and saves as `.aimodel`; this proves only the isolated Apple probe.
- [ ] **Standard MAX graph lowering**: The open MAX graph compiler/driver lacks the normal extension point needed for a Core AI backend; no source-level `coreai` target or project graph API is registered. [boundary](../COREAI_MVP_GATE.md)
- [x] **AOT specialization feasibility**: `coreai-build` produces eight iOS architecture specializations with Neural Engine preferred.
- [ ] **Backend artifact packaging**: Versioned `.aimodel`/`.aimodelc` ownership and selection remain unavailable without the standard MAX backend.
- [x] **Host runtime feasibility**: Sequential, concurrent, error, teardown, and reload cases pass for the direct probe.
- [x] **Public Swift device feasibility**: The standalone public-API app passes physical iPad numerical and concurrency tests without claiming Mojo integration.
- [ ] **Async caller integration**: Standard graph submission/completion semantics and a cooperative Swift async boundary remain undefined.
- [x] **Simulator disposition**: Core AI is unavailable in the current Simulator SDK and no CPU/Metal substitute is permitted.
- [x] **ANE-only disposition**: Apple exposes neither enforceable ANE-only execution nor per-operation residency; the unsupported claim is explicit.
- [x] **Private ANE backend prohibition**: Private ANECompiler, Espresso, and `aned` interfaces are deliberately rejected as an architecture.
- [ ] **Unsupported graph diagnostics**: Operation, dtype, shape, layout, and effect diagnostics depend on the future standard backend conversion.
- [ ] **ANE-preferred evidence retention**: Preserve reproducible physical-device Instruments evidence before making the preferred/eligible placement claim.

See [Core AI feasibility evidence](../COREAI_FEASIBILITY_GATE.md).
