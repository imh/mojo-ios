from std.runtime import initialize_runtime


@no_inline
def recursive_factorial(value: Int64) -> Int64:
    if value <= 1:
        return 1
    return value * recursive_factorial(value - 1)


@no_inline
def early_choice(primary: Int64, fallback: Int64, take_primary: Bool) -> Int64:
    if take_primary:
        return primary
    return fallback


@export("mojo_ios_conformance_control_flow")
def mojo_ios_conformance_control_flow() abi("C") -> Int64:
    initialize_runtime()

    var for_total: Int64 = 0
    for value in range(0, 7, 1):
        if value == 2:
            continue
        if value == 6:
            break
        for_total += Int64(value)

    var while_total: Int64 = 0
    var countdown: Int64 = 2
    while countdown > 0:
        while_total += countdown
        countdown -= 1
    else:
        while_total += 1

    return (
        recursive_factorial(4)
        + for_total
        + while_total
        + early_choice(1, 1000, True)
        + early_choice(1000, 0, False)
    )
