from std.runtime import initialize_runtime


@no_inline
def signed_extend(values: SIMD[.int8, 4]) -> SIMD[.int16, 4]:
    return values.cast[.int16]()


@no_inline
def unsigned_extend(values: SIMD[.uint8, 4]) -> SIMD[.uint16, 4]:
    return values.cast[.uint16]()


@export("mojo_ios_conformance_simd_primitives")
def mojo_ios_conformance_simd_primitives() abi("C") -> Int64:
    initialize_runtime()

    var int8_values = SIMD[.int8, 16](
        -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7
    )
    if int8_values + Int8(1) != SIMD[.int8, 16](
        -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8
    ):
        return -1

    var int16_values = SIMD[.int16, 8](1, 2, 3, 4, 5, 6, 7, 8)
    if int16_values * Int16(3) != SIMD[.int16, 8](3, 6, 9, 12, 15, 18, 21, 24):
        return -2

    var int32_values = SIMD[.int32, 4](100, 101, 102, 103)
    if int32_values.shuffle[3, 2, 1, 0]() != SIMD[.int32, 4](103, 102, 101, 100):
        return -3
    if int32_values.reduce_add() != 406:
        return -4

    var int64_values = SIMD[.int64, 2](-9, 11)
    if int64_values.reduce_min() != -9 or int64_values.reduce_max() != 11:
        return -5

    var overwide = SIMD[.int32, 8](0, 1, 2, 3, 4, 5, 6, 7)
    if overwide.reduce_add() != 28:
        return -6

    var float16_values = SIMD[.float16, 8](1, 2, 3, 4, 5, 6, 7, 8)
    if float16_values / Float16(2) != SIMD[.float16, 8](0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4):
        return -7

    var bfloat16_values = SIMD[.bfloat16, 8](1, 2, 3, 4, 5, 6, 7, 8)
    if bfloat16_values + BFloat16(1) != SIMD[.bfloat16, 8](2, 3, 4, 5, 6, 7, 8, 9):
        return -8

    var float32_values = SIMD[.float32, 4](1.0, -2.0, 3.5, -4.5)
    var float32_bits = float32_values.to_bits()
    if SIMD[.float32, 4](from_bits=float32_bits) != float32_values:
        return -9

    var float64_values = SIMD[.float64, 2](1.25, -2.5)
    if float64_values.cast[.int64]() != SIMD[.int64, 2](1, -2):
        return -10

    var mask = int32_values.gt(Int32(101))
    if mask.select(int32_values, SIMD[.int32, 4](-1)) != SIMD[.int32, 4](-1, -1, 102, 103):
        return -11

    var inserted = SIMD[.int32, 4](0, 1, 2, 3).insert[offset=2](SIMD[.int32, 2](9, 8))
    if inserted != SIMD[.int32, 4](0, 1, 9, 8):
        return -12

    var scalar_lane = SIMD[.int32, 1](7)
    if scalar_lane[0] != 7 or scalar_lane + Int32(2) != SIMD[.int32, 1](9):
        return -13

    if signed_extend(SIMD[.int8, 4](-1, 0, 1, 127)) != SIMD[.int16, 4](-1, 0, 1, 127):
        return -14
    if unsigned_extend(SIMD[.uint8, 4](0, 127, 128, 255)) != SIMD[.uint16, 4](0, 127, 128, 255):
        return -15

    return 42
