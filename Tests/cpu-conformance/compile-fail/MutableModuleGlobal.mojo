var mutable_module_global: Int64 = 0


@export("mojo_ios_unsupported_mutable_module_global")
def mojo_ios_unsupported_mutable_module_global() abi("C") -> Int64:
    mutable_module_global += 1
    return mutable_module_global
