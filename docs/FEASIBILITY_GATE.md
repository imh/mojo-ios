# Feasibility gate

The verdict is intentionally narrower than “all Mojo works on iOS.”

## Reproducible baseline

- [x] Packaged Mojo is locked and the open-source compiler revision is pinned.
- [x] The source compiler and stdlib pass a host smoke test.
- [x] One reviewed patch reproduces the entire upstream delta.
- [x] The embedded CompilerRT and AsyncRT targets build with upstream Bazel.

## Swift integration

- [x] Mojo emits valid ARM64 iOS device and Simulator objects.
- [x] A static XCFramework contains separate device and simulator variants.
- [x] Swift 6 builds against both variants.
- [x] Ten tests pass on iPhone and iPad simulators at O0 and O3.
- [x] The full O3 smoke matrix passes on a paired physical M1 iPad Pro.

## Runtime and stdlib

- [x] CompilerRT owns allocation, globals, argv, CPU counts, diagnostics, and
      normal CPU-runtime lifecycle.
- [x] AsyncRT owns the CPU DeviceContext implementation.
- [x] Shared Apple SDK ABIs use named Darwin backends, not macOS fallthroughs.
- [x] Locks, files, metadata, directory iteration, `pwd`, time, and environment
      calls compile and link through normal stdlib paths.
- [x] Python, subprocess, and dynamic loading fail explicitly at compile time.
- [x] Ordinary language async lowers for device and simulator at O0/O3.
- [x] Suspension/resumption, results, raised errors, and Swift-owned caller
      threads pass against the embedded Apple AsyncRT implementation.
- [x] No project-specific runtime symbol is present in either library slice.

## CPU concurrency

- [x] Mojo calls upstream `max.algorithm.parallelize` directly.
- [x] `sync_parallelize` and CPU `DeviceContext` remain unchanged; two generic
      coroutine-frame correctness fixes contain no iOS policy or API.
- [x] Context and coroutine ownership are asserted and tested.
- [x] A rendezvous proves at least two wrapper coroutines overlap.
- [x] Repeated and Swift-foreign-thread calls pass.
- [x] CompilerRT and AsyncRT pass Thread Sanitizer.

## Result

**GO** for CPU-only Mojo libraries behind a deliberate C ABI, delivered as
static ARM64 device and Simulator XCFramework variants. Captured-closure CPU
parallelism through the normal MAX API and ordinary CPU language async through
the existing upstream task substrate are supported.

**DELIBERATELY ABSENT FROM THE PINNED PUBLIC SURFACE**: stable public task
construction, cancellation, async I/O, GPU-await, textures, samplers, and
Metal-native launch controls. They are not iOS exclusions and are not API work
for this project.

**NOT YET SUPPORTED OR FULLY VERIFIED**: production-wide coverage of existing
public Metal/GPU and MAX operations, Python, subprocesses, arbitrary dynamic
loading, Core AI graph/runtime integration, ANE-only execution, a Mojo compiler
or JIT in the app, and stdlib surfaces not yet audited or explicitly gated.
Public Apple framework specialization of shipped Metal or Core AI artifacts is
compatible with the AOT architecture and is not Mojo JIT.

Metal has passed a narrower architecture feasibility gate: an ordinary Mojo
kernel compiles and links for iOS, and the same path executes on Mac and M4
iPad Simulator GPUs and on a physical M1 iPad Pro GPU. See
`METAL_FEASIBILITY_GATE.md`; the named feature boundaries remain experimental.

The ordered work plan and cross-feature statuses live in `ROADMAP.md` and
`CAPABILITY_LEDGER.md`.
