from std.random import random_ui64, seed


@export("mojo_ios_random_probe")
def mojo_ios_random_probe(seed_value: Int64) abi("C") -> UInt64:
    seed(Int(seed_value))
    return random_ui64(0, UInt64.MAX)
