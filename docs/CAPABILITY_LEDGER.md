# Capability tracker

This is the canonical status root for ordinary ahead-of-time Mojo and MAX on
iOS and iPadOS. It uses GitHub task-list syntax so the whole project can be
scanned without opening child trackers.

- `[x]` means the declared scope is complete. The description says whether it
  is supported or deliberately rejected.
- `[ ]` means the declared scope is not complete.
- A checked parent may not have an unchecked descendant.
- Children are optional detail, not another status. Large branches link to
  another Markdown tracker using the same syntax.

- [ ] **Mojo language and compiler**: Ownership, generics, traits, errors, C FFI, and callbacks pass the initial O0/O3 matrix; broad upstream conformance remains incomplete. [tracker](trackers/mojo-language-compiler.md)
- [ ] **Standard library and native dependencies**: The audited Darwin slice works; broad target-sensitive coverage remains incomplete. [tracker](trackers/stdlib-native.md)
- [ ] **Standard MAX**: `max.algorithm.parallelize` works normally; broad public MAX coverage remains incomplete. [tracker](trackers/max-standard.md)
- [ ] **Embedded runtime**: The complete pinned CompilerRT/DeviceContext C ABI is classified; lifecycle closure remains. [tracker](trackers/embedded-runtime.md)
- [ ] **Async and concurrency**: Ordinary language async works; public tasks, cancellation, async I/O, and accelerator await remain upstream gaps. [tracker](trackers/async-concurrency.md)
- [ ] **Swift ABI and AOT artifacts**: The sample C ABI and static XCFramework work; production ownership, composition, signing, and release packaging remain. [tracker](trackers/swift-abi-artifacts.md)
- [ ] **Metal**: A useful standard-path feasibility slice works on Mac, Simulator, and iPad; general backend coverage remains. [tracker](trackers/metal.md)
- [ ] **Core AI and ANE**: Direct Apple feasibility works; standard MAX graph integration remains upstream-blocked. [tracker](trackers/coreai.md)
- [ ] **Targets and hardware**: Current M-series iPad and ARM64 Simulator feasibility lanes pass; product minimum/latest and A-series coverage remain. [tracker](trackers/targets.md)
- [ ] **App Store distribution**: The audited CPU/Metal archive passes privacy, provenance, signing, export, and Apple server validation; TestFlight, review, and broader audit closure remain. [tracker](trackers/distribution.md)
- [ ] **Upstream and tracking sustainability**: The source delta and tracker gates are complete; patch splitting, non-iOS regression coverage, and compatibility automation remain. [tracker](trackers/upstream-evidence.md)
