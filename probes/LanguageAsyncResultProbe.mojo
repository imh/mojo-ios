from std.runtime._asyncrt import create_task


async def async_add(left: Int64, right: Int64) -> Int64:
    return left + right


@export("mojo_ios_async_result_probe")
def mojo_ios_async_result_probe() abi("C") -> Int64:
    var task = create_task(async_add(20, 22))
    return task.wait()
