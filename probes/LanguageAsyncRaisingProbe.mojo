from std.runtime._asyncrt import create_raising_task


async def async_maybe_raise(should_raise: Bool) raises -> Int64:
    if should_raise:
        raise Error("intentional async error")
    return 42


@export("mojo_ios_async_raising_probe")
def mojo_ios_async_raising_probe(should_raise: Int32) abi("C") -> Int32:
    var task = create_raising_task(async_maybe_raise(should_raise != 0))
    try:
        var result = task^.wait()
        assert result == 42
        return 0
    except:
        return -1
