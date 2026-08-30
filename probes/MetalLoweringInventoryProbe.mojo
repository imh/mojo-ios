from std.compile import compile_info
from std.gpu import global_idx
from std.gpu.host import get_gpu_target


def _inventory_kernel(
    left: Pointer[Float32, MutAnyOrigin],
    right: Pointer[Float32, MutAnyOrigin],
    output: Pointer[Float32, MutAnyOrigin],
):
    var element_index = global_idx.x
    output[unsafe_offset=element_index] = (
        left[unsafe_offset=element_index]
        + right[unsafe_offset=element_index]
    )


def main():
    comptime info = compile_info[
        _inventory_kernel,
        emission_kind="asm",
        target=get_gpu_target(),
    ]()
    print(String(info.asm))
