from std.runtime import initialize_runtime


@fieldwise_init
struct RegisterPair(TrivialRegisterPassable):
    var first: Int64
    var second: Int64


@fieldwise_init
struct MemoryPair(Copyable, Movable):
    var first: Int64
    var second: Int64


@no_inline
def transform_register(value: RegisterPair) -> RegisterPair:
    return RegisterPair(value.first + 1, value.second + 1)


@no_inline
def transform_memory(var value: MemoryPair) -> MemoryPair:
    value.first += 1
    value.second += 1
    return value^


@export("mojo_ios_conformance_aggregate_calling_conventions")
def mojo_ios_conformance_aggregate_calling_conventions() abi("C") -> Int64:
    initialize_runtime()
    var register_result = transform_register(RegisterPair(10, 11))
    var memory_result = transform_memory(MemoryPair(8, 9))
    return (
        register_result.first
        + register_result.second
        + memory_result.first
        + memory_result.second
    )
