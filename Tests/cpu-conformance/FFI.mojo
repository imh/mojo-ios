from std.ffi import external_call
from std.runtime import initialize_runtime


@export("mojo_ios_conformance_ffi")
def mojo_ios_conformance_ffi() abi("C") -> Int64:
    initialize_runtime()
    return external_call["mojo_ios_conformance_c_add", Int64](20, 22)
