from std.runtime._asyncrt import create_task


async def async_add(left: Int64, right: Int64) -> Int64:
    return left + right


async def async_await_sum(left: Int64, right: Int64) -> Int64:
    var left_task = create_task(async_add(left, 1))
    var right_task = create_task(async_add(right, 2))
    return await left_task + await right_task


@export("mojo_ios_async_await_probe")
def mojo_ios_async_await_probe() abi("C") -> Int64:
    var task = create_task(async_await_sum(20, 19))
    return task.wait()
