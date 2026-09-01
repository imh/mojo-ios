from std.runtime import initialize_runtime


struct ErrorScope[O: MutOrigin]:
    var destruction_count: Pointer[Int64, Self.O]

    def __init__(out self, ref[Self.O] destruction_count: Int64):
        self.destruction_count = Pointer(to=destruction_count)

    def __deinit__(deinit self):
        self.destruction_count[] += 1


def raise_with_live_value(mut destruction_count: Int64) raises:
    var value = ErrorScope(destruction_count)
    _ = value
    raise Error("cpu conformance intentional error")


@export("mojo_ios_conformance_errors")
def mojo_ios_conformance_errors() abi("C") -> Int64:
    initialize_runtime()
    var destruction_count: Int64 = 0
    try:
        raise_with_live_value(destruction_count)
        return -1
    except error:
        if String(error) != "cpu conformance intentional error":
            return -2
    return 41 + destruction_count
