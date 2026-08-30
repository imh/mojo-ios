from std.ffi import OwnedDLHandle


@export("mojo_ios_unsupported_dynamic_loading")
def mojo_ios_unsupported_dynamic_loading() abi("C") -> Int64:
    try:
        _ = OwnedDLHandle()
        return 0
    except:
        return -1
