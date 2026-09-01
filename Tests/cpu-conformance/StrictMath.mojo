from std.math import (
    ceil,
    copysign,
    cos,
    erf,
    exp,
    floor,
    fma,
    log,
    max,
    min,
    round,
    rsqrt,
    sin,
    sqrt,
    tanh,
    trunc,
)
from std.runtime import initialize_runtime
from std.utils.numerics import inf, isfinite, isinf, isnan, nan


def close(actual: Float64, expected: Float64, tolerance: Float64) -> Bool:
    return abs(actual - expected) <= tolerance


@export("mojo_ios_conformance_strict_math")
def mojo_ios_conformance_strict_math() abi("C") -> Int64:
    initialize_runtime()

    if min(Int32(-3), Int32(4)) != -3 or max(Int32(-3), Int32(4)) != 4:
        return -1
    if copysign(Float32(1), Float32(-0.0)).to_bits() != 0xBF800000:
        return -2
    if ceil(Float64(1.25)) != 2 or floor(Float64(-1.25)) != -2:
        return -3
    if trunc(Float64(-1.75)) != -1 or round(Float64(1.6)) != 2:
        return -4
    if sqrt(Float32(9)) != 3 or rsqrt(Float32(4)) != 0.5:
        return -5
    if fma(Float32(2), Float32(3), Float32(4)) != 10:
        return -6

    if not close(Float64(exp(Float64(1))), 2.718281828459045, 1.0e-12):
        return -7
    if not close(Float64(log(Float64(2))), 0.6931471805599453, 1.0e-12):
        return -8
    if not close(Float64(sin(Float64(1))), 0.8414709848078965, 1.0e-12):
        return -9
    if not close(Float64(cos(Float64(1))), 0.5403023058681398, 1.0e-12):
        return -10
    if not close(Float64(tanh(Float64(1))), 0.7615941559557649, 1.0e-12):
        return -11
    if not close(Float64(erf(Float64(1))), 0.8427007, 1.0e-6):
        return -12

    var vector_input = SIMD[.float32, 4](0, 0.5, 1, 1.5)
    var vector_sine = sin(vector_input)
    if abs(vector_sine[0]) > 1.0e-6 or abs(vector_sine[2] - Float32(0.84147096)) > 1.0e-6:
        return -13

    if not isinf(inf[.float32]()) or isfinite(inf[.float32]()):
        return -14
    if not isnan(nan[.float64]()) or isinf(nan[.float64]()):
        return -15
    if not isinf(exp(Float32(100))):
        return -16
    if exp(Float32(-200)) != 0:
        return -17

    var smallest_subnormal = Float32(from_bits=UInt32(1))
    if not isfinite(smallest_subnormal) or smallest_subnormal == 0:
        return -18
    if Float16(1.5) + Float16(0.5) != Float16(2):
        return -19
    if BFloat16(1.5) + BFloat16(0.5) != BFloat16(2):
        return -20
    if not close(Float64(exp(Float16(1))), 2.71875, 1.0e-3):
        return -21
    if not close(Float64(exp(BFloat16(1))), 2.71875, 1.0e-2):
        return -22

    return 42
