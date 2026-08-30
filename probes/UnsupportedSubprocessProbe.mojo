from std.subprocess import run


@export("mojo_ios_unsupported_subprocess")
def mojo_ios_unsupported_subprocess() abi("C") -> Int64:
    try:
        var output = run("true")
        return Int64(output.byte_length())
    except:
        return -1
