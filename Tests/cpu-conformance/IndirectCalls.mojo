from std.runtime import initialize_runtime


@no_inline
def add_values(left: Int64, right: Int64) -> Int64:
    return left + right


@no_inline
def invoke_binary(
    operation: def(Int64, Int64) thin -> Int64,
    left: Int64,
    right: Int64,
) -> Int64:
    return operation(left, right)


def overloaded_value(value: Int64) -> Int64:
    return value


def overloaded_value(value: Bool) -> Int64:
    if value:
        return 2
    return 0


def identity[T: ImplicitlyCopyable & Deinitable](value: T) -> T:
    return value


@export("mojo_ios_conformance_indirect_calls")
def mojo_ios_conformance_indirect_calls() abi("C") -> Int64:
    initialize_runtime()
    var binary: def(Int64, Int64) thin -> Int64 = add_values
    var unary: def(Int64) thin -> Int64 = identity[Int64]
    return (
        invoke_binary(binary, 19, 20)
        + overloaded_value(True)
        + overloaded_value(Int64(0))
        + unary(1)
    )
