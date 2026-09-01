from std.ffi import external_call
from std.runtime import initialize_runtime


def conformance_callback(value: Int64, context: Int64) abi("C") -> Int64:
    return value + context


@export("mojo_ios_conformance_callbacks")
def mojo_ios_conformance_callbacks() abi("C") -> Int64:
    initialize_runtime()
    return external_call["mojo_ios_conformance_invoke_callback", Int64](
        conformance_callback, Int64(20), Int64(22)
    )
