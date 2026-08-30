from std.gpu import thread_idx
from std.memory import unsafe_stack_allocation

from max.gpu.host import DeviceContext
from max.gpu.sync import barrier


def kernel(output: Pointer[Float32, MutAnyOrigin]):
    var scratch = unsafe_stack_allocation[
        16, Float32, address_space=.SHARED
    ]()
    var index = thread_idx.x
    scratch[unsafe_offset=index] = Float32(index)
    barrier()
    output[unsafe_offset=index] = scratch[unsafe_offset=15 - index]


@export("metal_static_threadgroup_probe")
def probe() abi("C") -> Int32:
    try:
        var context = DeviceContext(api="metal")
        var output = context.enqueue_create_buffer[DType.float32](16)
        context.enqueue_function[kernel](
            output, grid_dim=1, block_dim=16
        )
        context.synchronize()
        return 0
    except:
        return -1
