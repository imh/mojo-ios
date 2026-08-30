from std.random import random_ui64, seed
from std.runtime import initialize_runtime
from std.runtime._asyncrt import create_raising_task, create_task
from std.sys import argv

from max.algorithm import parallelize


def _initialize_runtime():
    initialize_runtime()


def _parallel_fill_squares(
    output: Pointer[Int64, MutUntrackedOrigin],
    count: Int64,
):
    def store_square(work_item_index: Int) {imm}:
        var value = Int64(work_item_index)
        output.unsafe_store(work_item_index, value * value)

    parallelize(store_square, Int(count))


async def _async_add(left: Int64, right: Int64) -> Int64:
    return left + right


async def _async_await_sum(left: Int64, right: Int64) -> Int64:
    var left_task = create_task(_async_add(left, 1))
    var right_task = create_task(_async_add(right, 2))
    return await left_task + await right_task


async def _async_maybe_raise(should_raise: Bool) raises -> Int64:
    if should_raise:
        raise Error("intentional Mojo async error")
    return 42


@export("mojo_ios_add")
def mojo_ios_add(left: Int64, right: Int64) abi("C") -> Int64:
    _initialize_runtime()
    return left + right


@export("mojo_ios_list_sum")
def mojo_ios_list_sum(count: Int64) abi("C") -> Int64:
    _initialize_runtime()
    if count < 0:
        return -1

    var values = List[Int64]()
    for index in range(Int(count)):
        values.append(Int64(index))

    var result: Int64 = 0
    for index in range(len(values)):
        result += values[index]
    return result


@export("mojo_ios_seeded_random")
def mojo_ios_seeded_random(seed_value: Int64) abi("C") -> UInt64:
    _initialize_runtime()
    seed(Int(seed_value))
    return random_ui64(0, UInt64.MAX)


@export("mojo_ios_argument_count")
def mojo_ios_argument_count() abi("C") -> Int64:
    _initialize_runtime()
    return Int64(len(argv()))


@export("mojo_ios_print_diagnostic")
def mojo_ios_print_diagnostic() abi("C"):
    _initialize_runtime()
    print("MOJO_IOS_PRINT_DIAGNOSTIC")


@export("mojo_ios_parallel_fill_squares")
def mojo_ios_parallel_fill_squares(
    output: Pointer[Int64, MutUntrackedOrigin], count: Int64
) abi("C"):
    _initialize_runtime()
    assert count >= 0, "count must not be negative"
    _parallel_fill_squares(output, count)


@export("mojo_ios_async_await_sum")
def mojo_ios_async_await_sum(left: Int64, right: Int64) abi("C") -> Int64:
    _initialize_runtime()
    var task = create_task(_async_await_sum(left, right))
    return task.wait()


@export("mojo_ios_async_parallel_sum")
def mojo_ios_async_parallel_sum(left: Int64, right: Int64) abi("C") -> Int64:
    _initialize_runtime()
    var left_task = create_task(_async_add(left, 1))
    var right_task = create_task(_async_add(right, 2))
    return left_task.wait() + right_task.wait()


@export("mojo_ios_async_error_status")
def mojo_ios_async_error_status(should_raise: Int32) abi("C") -> Int32:
    _initialize_runtime()
    var task = create_raising_task(_async_maybe_raise(should_raise != 0))
    try:
        var result = task^.wait()
        assert result == 42
        return 0
    except:
        return -1
