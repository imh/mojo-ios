# Core AI and ANE

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

## Proved feasibility and explicit dispositions

- [x] **Direct graph export feasibility**: A fixed-shape Float32 graph verifies and saves as `.aimodel`; this proves only the isolated Apple probe.
- [x] **AOT specialization feasibility**: `coreai-build` produces eight iOS architecture specializations with Neural Engine preferred.
- [x] **Host runtime feasibility**: Sequential, concurrent, error, teardown, and reload cases pass for the direct probe.
- [x] **Public Swift device feasibility**: The standalone public-API app passes physical iPad numerical and concurrency tests without claiming Mojo integration.
- [x] **Simulator disposition**: Core AI is unavailable in the current Simulator SDK and no CPU/Metal substitute is permitted.
- [x] **ANE-only disposition**: Apple exposes neither enforceable ANE-only execution nor per-operation residency; the unsupported claim is explicit.
- [x] **Private ANE backend prohibition**: Private ANECompiler, Espresso, and `aned` interfaces are deliberately rejected as an architecture.

## Verification backlog

- [ ] **ANE-preferred evidence retention**: Preserve reproducible physical-device Instruments evidence before making the preferred/eligible placement claim.

## Enablement queue — upstream-shaped MAX backend

- [ ] **General graph-backend extension**: Add a target-neutral, upstream-shaped backend extension to the open MAX graph compiler/driver; it must serve peer backends and must not be a project-only Core AI abstraction. [boundary](../COREAI_MVP_GATE.md)
- [ ] **Standard MAX graph lowering**: Implement Core AI conversion through that extension with ordinary MAX graph/tensor syntax and semantics; do not register a project graph API or Mojo source special case.
- [ ] **Preview authoring integration**: Use the proved pinned Xcode 27/Core AI authoring tuple for development while isolating its underscored beta modules behind the normal backend implementation.
- [ ] **Backend artifact packaging**: Give versioned `.aimodel`/`.aimodelc` resources explicit ownership, selection, and compatibility metadata through the normal package.
- [ ] **Async caller integration**: Compose standard graph submission/completion with the general async contract and a cooperative Swift async boundary.
- [ ] **Unsupported graph diagnostics**: Reject unsupported operations, dtypes, shapes, layouts, and effects by name during standard backend conversion.

## Externally gated release claim

- [ ] **Stable public authoring interface**: Production support remains gated on Apple replacing or stabilizing the current underscored beta authoring modules; this does not block backend development and device testing against the pinned preview tuple.

See [Core AI feasibility evidence](../COREAI_FEASIBILITY_GATE.md).
