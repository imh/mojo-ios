# Capability tracker

This is the canonical status root for ordinary ahead-of-time Mojo and MAX on
iOS and iPadOS. It uses GitHub task-list syntax so the whole project can be
scanned without opening child trackers.

- `[x]` means the declared scope is complete. The description says whether it
  is supported or deliberately rejected.
- `[ ]` means the declared scope is not complete; it does not by itself mean
  the capability is broken or needs target-specific implementation.
- Delegated trackers distinguish actionable **enablement**, expected-to-pass
  **verification**, and externally **blocked** work. Work that belongs upstream
  remains enablement when this project owns contributing it. Project work
  selects enablement before broad verification; root order remains a stable
  coverage index rather than a priority queue.
- A checked parent may not have an unchecked descendant.
- Children are optional detail, not another status. Large branches link to
  another Markdown tracker using the same syntax.

- [ ] **Mojo language and compiler**: Verification — Nineteen ordinary-Mojo families pass the O0/O3 matrix; broad expected-to-work CPU and closure conformance remains unverified. [tracker](trackers/mojo-language-compiler.md)
- [ ] **Standard library and native dependencies**: Verification — The audited Darwin slice works; broad target-sensitive coverage remains unclassified. [tracker](trackers/stdlib-native.md)
- [ ] **Standard MAX**: Mixed — `max.algorithm.parallelize` works; broader Mojo libraries need verification and Core AI needs a general upstream-shaped graph-backend extension plus its Apple backend. [tracker](trackers/max-standard.md)
- [x] **Embedded runtime**: The complete pinned CompilerRT/DeviceContext C ABI and same-tuple process-lifecycle contract are implemented or rejected explicitly. [tracker](trackers/embedded-runtime.md)
- [ ] **Async and concurrency**: Enablement — Ordinary language async works; public tasks, cancellation, async I/O, and accelerator await require general upstream contracts and their normal generic/Apple runtime implementations. [tracker](trackers/async-concurrency.md)
- [ ] **Swift ABI and AOT artifacts**: Enablement — The sample ABI and static package work, but production ownership/error conventions and cross-version composition are known missing contracts. [tracker](trackers/swift-abi-artifacts.md)
- [ ] **Metal**: Enablement — General value/buffer argument inference and layout pass host, Simulator, and physical-iPad gates; resource, synchronization, launch, debug, and current-AIR paths still need normal backend implementation. [tracker](trackers/metal.md)
- [ ] **Core AI and ANE**: Enablement — Direct Apple feasibility works; the remaining work is a general upstream-shaped MAX graph-backend extension, Core AI conversion, packaging, and normal runtime composition. [tracker](trackers/coreai.md)
- [ ] **Targets and hardware**: Mixed — Current M-series iPad and ARM64 Simulator lanes pass; product policy needs enablement decisions and broader hardware lanes need verification. [tracker](trackers/targets.md)
- [ ] **App Store distribution**: Verification — The audited CPU/Metal archive passes current gates; TestFlight, review, and broader future-surface audits remain evidence work. [tracker](trackers/distribution.md)
- [ ] **Upstream and tracking sustainability**: Enablement — The source delta is tracked, but the monolithic patch series and absent compatibility automation are known maintenance gaps. [tracker](trackers/upstream-evidence.md)
