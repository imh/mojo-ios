from std.builtin.globals import global_constant


@export("mojo_ios_unsupported_nontrivial_global_constant")
def mojo_ios_unsupported_nontrivial_global_constant() abi("C") -> Int:
    comptime value = String("not self-contained")
    ref stored_value = global_constant[value]()
    return stored_value.byte_length()
