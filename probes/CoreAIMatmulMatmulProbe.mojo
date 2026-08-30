from layout import TileTensor
from layout.tile_layout import row_major
from linalg.matmul import matmul
from max.gpu.host import DeviceContext


def main() raises:
    var input: Array[Float32, 6] = [1, 2, 3, 4, 5, 6]
    var first_weights: Array[Float32, 12] = [
        1, 0, 0, 1,
        0, 1, 1, 0,
        1, 1, 0, 0,
    ]
    var second_weights: Array[Float32, 8] = [
        1, 0,
        0, 1,
        1, 0,
        0, 1,
    ]
    var intermediate = Array[Float32, 8](uninitialized=True)
    var output = Array[Float32, 4](uninitialized=True)

    var input_tensor = TileTensor(input, row_major[2, 3]())
    var first_weights_tensor = TileTensor(
        first_weights, row_major[3, 4]()
    )
    var intermediate_tensor = TileTensor(
        intermediate, row_major[2, 4]()
    )
    var second_weights_tensor = TileTensor(
        second_weights, row_major[4, 2]()
    )
    var output_tensor = TileTensor(output, row_major[2, 2]())
    var context = DeviceContext(api="coreai")

    matmul[target="coreai"](
        intermediate_tensor,
        input_tensor,
        first_weights_tensor,
        context,
    )
    matmul[target="coreai"](
        output_tensor,
        intermediate_tensor,
        second_weights_tensor,
        context,
    )
    context.synchronize()
