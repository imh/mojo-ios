from std.runtime import initialize_runtime


@no_inline
def make_values(seed: Int64) -> Tuple[Int64, Int64, Int64]:
    return (seed, seed + 1, seed + 2)


@export("mojo_ios_conformance_aggregate_values")
def mojo_ios_conformance_aggregate_values() abi("C") -> Int64:
    initialize_runtime()

    var first: Int64
    var second: Int64
    var third: Int64
    (first, second, third) = make_values(12)

    var nested = (Int64(3), (Int64(4), Int64(5)))
    var selected = nested[0] if first < second else nested[1][0]
    var false_arm = Int64(1000) if first > second else Int64(0)
    return first + second + third + selected + false_arm
