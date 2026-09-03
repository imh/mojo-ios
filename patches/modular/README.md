# Modular patch stack

The stack contains one upstream-oriented patch:

`0001-add-apple-embedded-runtime-and-ios-target-policy.patch`

It adds explicit iOS/Darwin stdlib policy, dependency-light Apple embedded
CompilerRT/AsyncRT targets, Apple AIR/Metal lowering, generic unified-closure
offload fixes, generic packed masked-intrinsic operand lowering, and the
ordinary MAX Metal DeviceContext ABI.
The Metal backend honors true O0 separately from required AIR legalization and
preserves line-table and full debug information through LLVM 17 AIR bitcode,
Apple Metal packaging, and dSYM generation.

Application Mojo continues to use standard APIs. Verified Darwin ABI sharing
is named explicitly; unimplemented target-known operations use
`CompilationTarget.unsupported_target_error()`; runtime-selected unsupported
operations return explicit errors. Metal never falls back to CPU, and the
offload compiler returns the entry-point name actually emitted into each
artifact instead of asking the host to reconstruct it independently.

Apply and verify the patch idempotently with
`scripts/apply-upstream-patches.sh`. The script rejects any checkout change not
represented by the reviewed patch.
