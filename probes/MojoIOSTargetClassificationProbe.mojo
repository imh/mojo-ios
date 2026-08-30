from std.sys import CompilationTarget


@export("mojo_ios_target_classification")
def mojo_ios_target_classification() abi("C") -> Int64:
    comptime if CompilationTarget.is_linux():
        return 1
    elif CompilationTarget.is_macos():
        return 2
    elif CompilationTarget.is_ios():
        return 3
    else:
        return 0
