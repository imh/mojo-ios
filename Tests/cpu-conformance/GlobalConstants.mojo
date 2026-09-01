from std.builtin.globals import global_constant
from std.runtime import initialize_runtime


def scalar_constant() -> Int64:
    comptime value: Int64 = 7
    return global_constant[value]()


def simd_constant() -> Int64:
    comptime values = SIMD[DType.int64, 4](2, 3, 5, 7)
    ref stored_values = global_constant[values]()
    return (
        stored_values[0]
        + stored_values[1]
        + stored_values[2]
        + stored_values[3]
    )


def array_constant() -> Int64:
    comptime values: Array[Int64, 4] = [1, 4, 6, 8]
    ref stored_values = global_constant[values]()
    return (
        stored_values[0]
        + stored_values[1]
        + stored_values[2]
        + stored_values[3]
    )


@export("mojo_ios_conformance_global_constants")
def mojo_ios_conformance_global_constants() abi("C") -> Int64:
    initialize_runtime()
    return scalar_constant() + simd_constant() + array_constant()
