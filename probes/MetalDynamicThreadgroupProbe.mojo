from std.gpu import thread_idx

from max.gpu.host import DeviceContext
from max.gpu.memory import external_memory
from max.gpu.sync import barrier


def kernel(output: Pointer[Float32, MutAnyOrigin]):
    var scratch = external_memory[
        Float32, address_space=.SHARED, alignment=4
    ]()
    var index = thread_idx.x
    scratch[unsafe_offset=index] = Float32(index)
    barrier()
    output[unsafe_offset=index] = scratch[unsafe_offset=15 - index]


@export("metal_dynamic_threadgroup_probe")
def probe() abi("C") -> Int32:
    try:
        var context = DeviceContext(api="metal")
        var output = context.enqueue_create_buffer[DType.float32](16)
        context.enqueue_function[kernel](
            output,
            grid_dim=1,
            block_dim=16,
            shared_mem_bytes=16 * 4,
        )
        context.synchronize()
        return 0
    except:
        return -1
