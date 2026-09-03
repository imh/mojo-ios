# CPU and offload closure families

Parent: [Mojo language and compiler](mojo-language-compiler.md)

Unchecked means verification is pending, not that an iOS closure implementation
is missing. These items come from `KGEN/test/mojo-parser/closures` and related
KGEN, stdlib, and MAX consumers, and are expected to preserve generic unified-
closure syntax, ownership, and lowering unchanged. CPU cases use the base O0/O3
matrix; device-passable and offload cases verify compiler transport here while
backend operation coverage remains in the Metal tracker. A blocker or
corrective patch owner will be recorded only if testing discovers one; none is
recorded yet.

## Proved slices

- [x] **Thin function values and thunks**: Thin function values, indirect calls, overload selection, and a specialized generic thunk pass the base O0/O3 matrix. [evidence](../CPU_CORE_LANGUAGE_GATE.md)
- [x] **Captured CPU parallel closure**: An ordinary captured unified closure reaches `max.algorithm.parallelize` through the normal CPU `DeviceContext` and AsyncRT path without an iOS API or serial fallback. [evidence](../CONCURRENCY_GATE.md)
- [x] **Captured Metal scalar closure**: Ordinary scalar capture reaches the existing offload/AIR/Metal path in the proved Metal slice without a project closure convention. [evidence](../METAL_FEASIBILITY_GATE.md)

## Verification backlog

- [ ] **Capture-list modes**: Verify implicit and named `{imm}`, `{mut}`, and `{var}` captures preserve generic read/write, copy/move, and destruction semantics across the applicable O0/O3 lanes.
- [ ] **Capture lifetimes and origins**: Verify borrowed, interior-origin, implicit-lifetime, and escaping captures preserve positive lifetime behavior and named upstream invalidation diagnostics.
- [ ] **Stored and returned closures**: Verify closure values in structures, optionals, collections, arguments, and returns preserve generic layout, ownership, invocation, and destruction.
- [ ] **Nested, recursive, and rebound closures**: Verify nested scopes, recursive closure calls, rebinding, and capture shadowing through generic lowering and lifetime rules.
- [ ] **Closure traits and conversions**: Verify marker traits, parametric trait constraints, implicit promotion, wrapper conformance, and rejected conversions match upstream behavior.
- [ ] **Function-pointer and C callback conversion**: Verify supported closure-to-function-pointer forms and capture-requiring rejections through the normal C ABI without a project trampoline ABI.
- [ ] **Standard-library higher-order consumers**: Verify standard algorithms accept representative capturing/noncapturing, mutable-state, error, and ownership cases through their existing APIs.
- [ ] **MAX CPU closure consumers**: Verify public MAX CPU algorithms beyond `parallelize` preserve ordinary callable inference, scheduling, result/error, and no-fallback behavior.
- [ ] **Device-passable closure transport**: Verify generic offload capture legality, aggregate layout, pointer fixups, trait checks, and named rejection of host-only captures; Metal operation coverage remains M4.
- [ ] **Closure corpus closure**: Run all executable CPU fixtures through independent base O0/O3 links, compile offload fixtures through their normal backend boundary, and verify no selected failure becomes a crash or unresolved symbol.
