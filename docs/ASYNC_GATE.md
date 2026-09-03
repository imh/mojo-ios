# CPU language-async gate

## Normal lowering route

Application Mojo uses ordinary language syntax:

```mojo
from std.runtime._asyncrt import create_task


async def add(left: Int64, right: Int64) -> Int64:
    return left + right


async def add_two_pairs() -> Int64:
    var first = create_task(add(20, 1))
    var second = create_task(add(19, 2))
    return await first + await second
```

The route remains:

1. Mojo async function and `await` elaboration;
2. generic coroutine and frame lowering;
3. the existing AsyncRT chain ABI;
4. the embedded Apple runtime and its shared concurrent work queue.

There is no iOS import, async API, source branch, fallback, or target-specific
lowering. `create_task` and `create_raising_task` currently live in upstream's
private `std.runtime._asyncrt` module on every platform. Supporting that module
does not make it a stable public API.

## Generic compiler corrections

The source compiler needed two target-independent correctness fixes exposed by
full-debug coroutine lowering:

- a cached coroutine-frame address may be reused only within the same block,
  where it dominates, rather than across sibling state-machine blocks merely
  because they share a region;
- after a stack allocation is promoted into the coroutine frame, remaining
  users not represented in the state map, especially debug-info operations,
  must be rewritten to state-local frame addresses before the allocation is
  erased.

The LLVM-dialect module is also verified before translation so malformed
lowering fails with an assertion and IR dump instead of crashing in the LLVM
translator. These changes contain no Apple or iOS conditions.

## Embedded Apple AsyncRT

The runtime implements the unchanged chain operations:

- initialize and destroy;
- complete;
- wait and timed wait;
- execute;
- attach a continuation.

Chains use a mutex, condition variable, completion state, and FIFO continuation
list. Execute and continuation work share the same process-wide libdispatch
queue as CPU DeviceContext work. Runtime assertions enforce chain lifetime and
make incomplete-task destruction explicit.

## Supported evidence

- ordinary async, await, results, and raised errors compile for iOS device and
  Simulator at O0/full-debug and O3;
- upstream host async and raising-async suites pass;
- host chain ABI tests cover timeout, executor-thread execution, 64
  continuations, and overlap with CPU DeviceContext work;
- CompilerRT and AsyncRT pass Thread Sanitizer;
- Swift tests cover suspension/resumption, result/error propagation, real
  executor overlap, and eight concurrent Swift-owned caller threads;
- the ten-test Swift suite passes at O0/O3 on iPhone and iPad simulators;
- the O3 device smoke passes on a physical M1 iPad Pro.

## Boundary

Cancellation, async I/O, and GPU-await are not implemented by the current
general upstream task surface. They fail during normal name resolution,
elaboration, or type checking rather than through iOS-specific guards. There is
no silent detach, CPU fallback, or platform-specific replacement. Because the
pinned public surface does not expose these contracts, this project does not
design them; a later upstream revision must expose them before their iOS path is
reconsidered.
