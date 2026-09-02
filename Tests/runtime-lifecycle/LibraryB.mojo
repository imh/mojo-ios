from std.ffi import external_call
from std.runtime import initialize_runtime
from std.runtime._asyncrt import create_raising_task, create_task


async def lifecycle_async_add(left: Int64, right: Int64) -> Int64:
    return left + right


async def lifecycle_async_maybe_raise(should_raise: Bool) raises -> Int64:
    if should_raise:
        raise Error("intentional runtime lifecycle error")
    return 42


def lifecycle_callback(value: Int64, context: Int64) abi("C") -> Int64:
    return value + context


@export("mojo_ios_lifecycle_library_b")
def mojo_ios_lifecycle_library_b(left: Int64, right: Int64) abi("C") -> Int64:
    initialize_runtime()

    var left_task = create_task(lifecycle_async_add(left, 1))
    var right_task = create_task(lifecycle_async_add(right, 2))
    var async_result = left_task.wait() + right_task.wait()

    var callback_result = external_call[
        "mojo_ios_lifecycle_invoke_callback", Int64
    ](lifecycle_callback, Int64(20), Int64(22))

    var owned_values = List[Int64](length=3, fill=1)
    var owned_sum: Int64 = 0
    for index in range(len(owned_values)):
        owned_sum += owned_values[index]

    var raising_task = create_raising_task(lifecycle_async_maybe_raise(True))
    try:
        _ = raising_task^.wait()
        return -1
    except:
        return async_result + callback_result + owned_sum
