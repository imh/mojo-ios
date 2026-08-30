from std.compile import compile_info
from std.gpu.host import get_gpu_target


def _empty_kernel():
    pass


def main():
    comptime info = compile_info[
        _empty_kernel,
        emission_kind="llvm",
        target=get_gpu_target(),
    ]()
    print(String(info.asm))
