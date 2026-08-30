from layout import TileTensor
from layout.tile_layout import row_major
from linalg.matmul import matmul
from max.gpu.host import DeviceContext


def main() raises:
    var input = Array[Float32, 6](uninitialized=True)
    var first_weights = Array[Float32, 15](uninitialized=True)
    var intermediate = Array[Float32, 10](uninitialized=True)
    var second_weights = Array[Float32, 10](uninitialized=True)
    var output = Array[Float32, 4](uninitialized=True)
    var input_tensor = TileTensor(input, row_major[2, 3]())
    var first_weights_tensor = TileTensor(
        first_weights, row_major[3, 5]()
    )
    var intermediate_tensor = TileTensor(
        intermediate, row_major[2, 5]()
    )
    var second_weights_tensor = TileTensor(
        second_weights, row_major[5, 2]()
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
