from std.python import Python


@export("mojo_ios_unsupported_python")
def mojo_ios_unsupported_python() abi("C") -> Int64:
    try:
        _ = Python.import_module("builtins")
        return 0
    except:
        return -1
