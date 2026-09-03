from std.runtime import initialize_runtime


@no_inline
def sum_values(*values: Int64) -> Int64:
    var total: Int64 = 0
    for value in values:
        total += value
    return total


@no_inline
def forward_values(*values: Int64) -> Int64:
    return sum_values(*values)


@export("mojo_ios_conformance_variadic_packs")
def mojo_ios_conformance_variadic_packs() abi("C") -> Int64:
    initialize_runtime()
    return forward_values(9, 10, 11) + sum_values(12) + sum_values()
