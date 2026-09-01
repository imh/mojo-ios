from std.bit import (
    bit_reverse,
    bit_width,
    byte_swap,
    count_leading_zeros,
    count_trailing_zeros,
    next_power_of_two,
    pop_count,
    prev_power_of_two,
    rotate_bits_left,
    rotate_bits_right,
)
from std.runtime import initialize_runtime


@export("mojo_ios_conformance_bit_intrinsics")
def mojo_ios_conformance_bit_intrinsics() abi("C") -> Int64:
    initialize_runtime()

    if count_leading_zeros(UInt64(1)) != 63:
        return -1
    if count_trailing_zeros(UInt64(0x100)) != 8:
        return -2
    if pop_count(UInt64(0xF0F0)) != 8:
        return -3
    if byte_swap(UInt32(0x01020304)) != UInt32(0x04030201):
        return -4
    if bit_reverse(UInt8(1)) != UInt8(0x80):
        return -5
    if bit_width(UInt32(0x100)) != 9:
        return -6
    if next_power_of_two(UInt32(65)) != 128:
        return -7
    if prev_power_of_two(UInt32(65)) != 64:
        return -8
    if rotate_bits_left[1](UInt8(0x81)) != UInt8(0x03):
        return -9
    if rotate_bits_right[1](UInt16(0x0003)) != UInt16(0x8001):
        return -10

    var bytes = SIMD[.uint8, 16](
        0, 1, 2, 3, 4, 8, 16, 32, 64, 128, 255, 15, 240, 85, 170, 127
    )
    if pop_count(bytes) != SIMD[.uint8, 16](
        0, 1, 1, 2, 1, 1, 1, 1, 1, 1, 8, 4, 4, 4, 4, 7
    ):
        return -11

    var words = SIMD[.uint16, 8](1, 2, 4, 8, 16, 32, 64, 128)
    if count_trailing_zeros(words) != SIMD[.uint16, 8](0, 1, 2, 3, 4, 5, 6, 7):
        return -12

    var dwords = SIMD[.uint32, 4](0x01020304, 0x11223344, 0xAABBCCDD, 0xFFEEDDCC)
    if byte_swap(dwords) != SIMD[.uint32, 4](0x04030201, 0x44332211, 0xDDCCBBAA, 0xCCDDEEFF):
        return -13

    var qwords = SIMD[.uint64, 2](1, 0x8000000000000000)
    if bit_reverse(qwords) != SIMD[.uint64, 2](0x8000000000000000, 1):
        return -14

    comptime compile_time_popcount = pop_count(UInt32(0xF00F))
    if compile_time_popcount != 8:
        return -15

    return 42
