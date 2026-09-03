# Upstream and tracking sustainability

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

## Proved infrastructure

- [x] **Complete source delta**: The pinned upstream delta is represented by the reviewed patch and the apply script rejects unrecorded checkout edits.
- [x] **Progressive tracker structure**: Root `AGENTS.md`, the Markdown tracker graph, staged-snapshot hook, and structural validator enforce the recursive task-list contract.
- [x] **Tracker CI**: GitHub pull requests and pushes run the same recursive validator used by the local staged-snapshot gate.

## Enablement queue — known maintenance gaps

Work these after capability enablement so each resulting compiler/runtime
change can be split with its complete regression evidence.

- [ ] **Reviewable patch series**: Generic coroutine/closure fixes, Darwin policy, CompilerRT, AsyncRT CPU, Metal backend/runtime, and tests remain in one patch.
- [ ] **Non-iOS regression coverage**: Packed masked-intrinsic operand lowering has a generic KGEN regression; remaining generic patches still need mapping to the relevant existing host and accelerator regression lanes.
- [ ] **Compatibility tuple CI**: Compiler, stdlib, MAX, Apple SDK, Metal toolchain, and Core AI package rebasing is not automated as one tuple.
