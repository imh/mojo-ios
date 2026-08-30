# CPU concurrency gate

## Normal Mojo API

Library authors use `max.algorithm.parallelize` directly:

```mojo
from max.algorithm import parallelize


def fill_squares(
    output: Pointer[Int64, MutUntrackedOrigin], count: Int
):
    def work_item(index: Int) {imm}:
        var value = Int64(index)
        output.unsafe_store(index, value * value)

    parallelize(work_item, count)
```

Captured state works. There is no platform branch, `ios_parallel` layer,
closure trampoline, or serial fallback.

## Preserved lowering route

The implementation retains the upstream route:

1. `max.algorithm.parallelize` coalesces work into chunks.
2. `sync_parallelize` constructs a CPU `DeviceContext`.
3. `DeviceContext.enqueue_cpu_range` creates non-suspending wrapper
   coroutines and transfers their handles.
4. Generic compiler lowering emits the resume and destroy functions.
5. The embedded Apple AsyncRT target copies the handles, dispatches them on a
   concurrent queue, resumes and destroys each exactly once, and records each
   task in the context completion group.
6. `DeviceContext.synchronize()` waits before captured storage leaves scope.

The same source compiles for device and simulator at O0 and O3. Two
target-independent coroutine-frame fixes are in the patch stack: cached frame
addresses are reused only when they dominate in the same block, and remaining
debug-info users of promoted stack allocations are rewritten before erasure.
Neither fix contains an iOS test or changes the Mojo API.

## Runtime ownership

The runtime code is owned by the upstream components whose ABI it implements:

- `KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c` provides CPU-runtime
  lifecycle, parallelism-level, SpinWaiter, and language AsyncRT chain symbols;
- `AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c` owns the one process-wide
  concurrent Apple work queue shared by CPU DeviceContext and language async;
- `AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c` provides the standard CPU
  DeviceContext C ABI.

Only the `cpu` API and device 0 are accepted. Unsupported runtime-selected
attributes return an owned error. The enqueue ABI takes ownership of coroutine
handles, not the temporary Mojo list containing them.

The language runtime implements the existing chain ABI: initialize, destroy,
complete, wait, timed wait, execute, and continuation scheduling. Ordinary
async functions suspend and resume on the shared executor. The upstream task
construction surface is still private and unfinished; this project does not
invent a public or iOS-specific replacement.

## Evidence

The gate covers:

- unmodified MAX lowering for device and simulator at O0/O3;
- an undefined-symbol inventory containing only the standard runtime ABI;
- strict C17 and upstream Bazel builds;
- 64 transferred handles with completion and destruction checks;
- a forced two-task rendezvous proving actual overlap;
- CompilerRT and AsyncRT Thread Sanitizer runs;
- ten Swift tests at O0/O3 on both iPhone and iPad simulators;
- eight simultaneous async calls from Swift-owned threads;
- async result/error propagation and a forced two-task async rendezvous;
- an O3 run on a physical M1 iPad Pro.
