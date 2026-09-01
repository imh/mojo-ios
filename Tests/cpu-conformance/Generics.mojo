from std.runtime import initialize_runtime


@fieldwise_init
struct Pair[T: ImplicitlyCopyable & Deinitable]:
    var first: Self.T
    var second: Self.T


def select[T: ImplicitlyCopyable & Deinitable](
    pair: Pair[T], take_second: Bool
) -> T:
    if take_second:
        return pair.second
    return pair.first


@export("mojo_ios_conformance_generics")
def mojo_ios_conformance_generics() abi("C") -> Int64:
    initialize_runtime()
    var pair = Pair[Int64](first=19, second=42)
    return select(pair, True)
