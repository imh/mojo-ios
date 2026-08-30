from std.gpu import global_idx

from max.gpu.host import DeviceContext


def kernel(output: Pointer[Float32, MutAnyOrigin], value: Float32):
    output[unsafe_offset=global_idx.x] = value


@export("metal_explicit_scalar_probe")
def probe() abi("C") -> Int32:
    try:
        var context = DeviceContext(api="metal")
        var output = context.enqueue_create_buffer[DType.float32](1)
        context.enqueue_function[kernel](
            output, Float32(7), grid_dim=1, block_dim=1
        )
        context.synchronize()
        return 0
    except:
        return -1
