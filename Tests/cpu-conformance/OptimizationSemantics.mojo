from std.builtin.simd import FastMathFlag
from std.runtime import initialize_runtime


@no_inline
@export("mojo_ios_numeric_strict_add")
def mojo_ios_numeric_strict_add(a: Float32, b: Float32) abi("C") -> Float32:
    return a + b


@no_inline
@export("mojo_ios_numeric_strict_div")
def mojo_ios_numeric_strict_div(a: Float32, b: Float32) abi("C") -> Float32:
    return a / b


@no_inline
@export("mojo_ios_numeric_explicit_fma")
def mojo_ios_numeric_explicit_fma(a: Float32, b: Float32, c: Float32) abi("C") -> Float32:
    return a.fma(c, b)


@no_inline
@export("mojo_ios_numeric_fast_fma")
def mojo_ios_numeric_fast_fma(a: Float32, b: Float32, c: Float32) abi("C") -> Float32:
    return a.fma[FastMathFlag.FAST](c, b)


@no_inline
@export("mojo_ios_numeric_wrapping_add")
def mojo_ios_numeric_wrapping_add(value: UInt8) abi("C") -> UInt8:
    return value + UInt8(1)


@export("mojo_ios_conformance_optimization_semantics")
def mojo_ios_conformance_optimization_semantics() abi("C") -> Int64:
    initialize_runtime()

    if mojo_ios_numeric_strict_add(1.25, 2.5) != 3.75:
        return -1
    if mojo_ios_numeric_strict_div(7, 2) != 3.5:
        return -2
    if mojo_ios_numeric_explicit_fma(2, 4, 3) != 10:
        return -3
    if mojo_ios_numeric_fast_fma(2, 4, 3) != 10:
        return -4

    var signed_value = Int8(from_bits=UInt8(0xFF))
    if signed_value != -1 or UInt8(from_bits=signed_value) != 255:
        return -5
    if Int32(-7) // Int32(3) != -3 or Int32(-7) % Int32(3) != 2:
        return -6
    if not all(SIMD[.int32, 4](1, 2, 3, 4).lt(SIMD[.int32, 4](2, 3, 4, 5))):
        return -7
    if mojo_ios_numeric_wrapping_add(UInt8.MAX) != UInt8.MIN:
        return -8
    if Int8.MAX + Int8(1) != Int8.MIN:
        return -9

    return 42
