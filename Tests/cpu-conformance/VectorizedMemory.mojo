from std.algorithm import vectorize
from std.math import iota
from std.runtime import initialize_runtime
from std.sys.intrinsics import masked_load, masked_store


@export("mojo_ios_conformance_vectorized_memory")
def mojo_ios_conformance_vectorized_memory() abi("C") -> Int64:
    initialize_runtime()

    comptime element_count = 19
    var storage = Array[Float32, element_count](uninitialized=True)
    var values = Span(storage)
    for index in range(element_count):
        values[index] = Float32(index)

    @always_inline
    def add_three[width: Int](index: Int, active_lanes: Int) {var values}:
        var pointer = values.unsafe_ptr().unsafe_offset(index)
        var lane_indices = iota[.int32, width]()
        var mask = lane_indices.lt(Int32(active_lanes))
        var loaded = masked_load[width](
            pointer, mask, SIMD[.float32, width](from_int=0)
        )
        masked_store[width](loaded + Float32(3), pointer, mask)

    vectorize[4, unroll_factor=2](element_count, add_three)
    for index in range(element_count):
        if values[index] != Float32(index + 3):
            return -1

    var unaligned_storage = Array[Float32, 9](uninitialized=True)
    var unaligned_values = Span(unaligned_storage)
    for index in range(9):
        unaligned_values[index] = Float32(index * 2)
    var unaligned = unaligned_values.unsafe_ptr().unsafe_offset(1).unsafe_load[width=4]()
    if unaligned != SIMD[.float32, 4](2, 4, 6, 8):
        return -2
    unaligned_values.unsafe_ptr().unsafe_offset(1).unsafe_store(SIMD[.float32, 4](9, 8, 7, 6))
    if unaligned_values[1] != 9 or unaligned_values[4] != 6:
        return -3

    return 42
