from std.gpu import global_idx

from max.gpu.host import DeviceContext


@export("metal_captured_scalar_probe")
def probe() abi("C") -> Int32:
    try:
        var context = DeviceContext(api="metal")
        var output = context.enqueue_create_buffer[DType.float32](1)
        var value = Float32(7)

        def kernel(output_pointer: Pointer[Float32, MutAnyOrigin]) {var value}:
            output_pointer[unsafe_offset=global_idx.x] = value

        context.enqueue_function(kernel, output, grid_dim=1, block_dim=1)
        context.synchronize()
        return 0
    except:
        return -1
