# CPU language conformance

Parent: [Mojo language and compiler](mojo-language-compiler.md)

- [x] **Independent O0/O3 corpus matrix**: Six ordinary-Mojo fixtures compile and fully link independently for macOS, iOS device, and ARM64 Simulator, then execute on host, iPhone/iPad Simulator, and physical iPad without a project Mojo runtime ABI. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Ownership and destruction**: Copy, move, ordinary-scope destruction, and error-path destruction produce the expected exactly-once event traces. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Generics**: Parametric structures and generic functions specialize and execute at O0/O3 in the proved target lanes. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Traits and dispatch**: Trait-constrained generic dispatch executes at O0/O3 in the proved target lanes. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Raised errors**: Raised errors are caught with their message intact and live values are destroyed during propagation. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **C FFI**: Ordinary `std.ffi.external_call` reaches a C function through the standard C ABI from Mojo entered by Swift-owned threads. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **C callbacks**: A normal Mojo C-ABI function pointer and context cross C and return to Mojo correctly from Swift-owned threads. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Globals, TLS, and atomics**: Standard immutable global constants and CPU atomics pass the O0/O3 matrix, IR-ordering audit, real-worker contention/publication test, and instrumented TSan gate; mutable module globals are generically rejected and public TLS is absent upstream rather than iOS-special-cased. [evidence](../CPU_STATE_GATE.md)
- [ ] **SIMD, math, and optimization-sensitive families**: Broad vector widths, intrinsics, numerical edge cases, and lowering-sensitive O0/O3 families lack the complete base-matrix evidence; the next gate must add upstream-family fixtures or named target diagnostics.
- [ ] **Remaining portable CPU families**: Upstream language-family inventory and target-safe selection remain incomplete; each discovered family must be proved through the normal lowering/runtime path or deliberately rejected by name.
