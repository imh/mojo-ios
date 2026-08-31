# Upstream and tracking sustainability

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **Complete source delta**: The pinned upstream delta is represented by the reviewed patch and the apply script rejects unrecorded checkout edits.
- [x] **Progressive tracker structure**: Root `AGENTS.md`, the Markdown tracker graph, staged-snapshot hook, and structural validator enforce the recursive task-list contract.
- [ ] **Reviewable patch series**: Generic coroutine/closure fixes, Darwin policy, CompilerRT, AsyncRT CPU, Metal backend/runtime, and tests remain in one patch.
- [ ] **Non-iOS regression coverage**: Map every generic patch to the relevant existing host and accelerator regression lanes.
- [ ] **Compatibility tuple CI**: Compiler, stdlib, MAX, Apple SDK, Metal toolchain, and Core AI package rebasing is not automated as one tuple.
- [x] **Tracker CI**: GitHub pull requests and pushes run the same recursive validator used by the local staged-snapshot gate.
