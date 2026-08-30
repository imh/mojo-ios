from std.gpu import global_idx

from max.gpu.host import DeviceContext


def kernel(output: Pointer[Int32, MutAnyOrigin]):
    var x = global_idx.x
    var y = global_idx.y
    var z = global_idx.z
    output[unsafe_offset=z * 16 + y * 4 + x] = Int32(x + y + z)


@export("metal_multidimensional_probe")
def probe() abi("C") -> Int32:
    try:
        var context = DeviceContext(api="metal")
        var output = context.enqueue_create_buffer[DType.int32](64)
        context.enqueue_function[kernel](
            output, grid_dim=(2, 2, 2), block_dim=(2, 2, 2)
        )
        context.synchronize()
        return 0
    except:
        return -1
