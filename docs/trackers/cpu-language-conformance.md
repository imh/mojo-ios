# CPU language conformance

Parent: [Mojo language and compiler](mojo-language-compiler.md)

- [x] **Independent O0/O3 corpus matrix**: Fourteen ordinary-Mojo fixtures compile and fully link independently for macOS, iOS device, and ARM64 Simulator, then execute on host, iPhone/iPad Simulator, and physical iPad without a project Mojo runtime ABI. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Ownership and destruction**: Copy, move, ordinary-scope destruction, and error-path destruction produce the expected exactly-once event traces. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Generics**: Parametric structures and generic functions specialize and execute at O0/O3 in the proved target lanes. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Traits and dispatch**: Trait-constrained generic dispatch executes at O0/O3 in the proved target lanes. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Raised errors**: Raised errors are caught with their message intact and live values are destroyed during propagation. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **C FFI**: Ordinary `std.ffi.external_call` reaches a C function through the standard C ABI from Mojo entered by Swift-owned threads. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **C callbacks**: A normal Mojo C-ABI function pointer and context cross C and return to Mojo correctly from Swift-owned threads. [evidence](../CPU_CONFORMANCE_GATE.md)
- [x] **Globals, TLS, and atomics**: Standard immutable global constants and CPU atomics pass the O0/O3 matrix, IR-ordering audit, real-worker contention/publication test, and instrumented TSan gate; mutable module globals are generically rejected and public TLS is absent upstream rather than iOS-special-cased. [evidence](../CPU_STATE_GATE.md)
- [x] **SIMD, math, and optimization-sensitive families**: Representative standard SIMD widths and dtypes, bit intrinsics, strict and approximate math edge cases, vectorized masked tails, and strict-versus-fast O0/O3 lowering pass the proved lanes; odd SIMD widths are generically rejected and exhaustive numerical coverage remains outside this declared slice. [evidence](../CPU_NUMERICS_GATE.md)
- [ ] **Remaining portable CPU families**: Upstream language-family inventory and target-safe selection remain incomplete; each discovered family must be proved through the normal lowering/runtime path or deliberately rejected by name.
