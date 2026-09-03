from std.gpu import global_idx

from max.gpu.host import DeviceContext


def tuple_kernel(values: Tuple[Int32, Float32]):
    if global_idx.x == 0:
        _ = values[0]


def main() raises:
    var context = DeviceContext(api="metal")
    context.enqueue_function[tuple_kernel](
        (Int32(1), Float32(2)), grid_dim=1, block_dim=1
    )
