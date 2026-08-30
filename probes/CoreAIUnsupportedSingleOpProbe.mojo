from layout import TileTensor
from layout.tile_layout import row_major
from linalg.matmul import matmul
from max.gpu.host import DeviceContext


def main() raises:
    var input = Array[Float32, 6](uninitialized=True)
    var weights = Array[Float32, 12](uninitialized=True)
    var output = Array[Float32, 8](uninitialized=True)
    var input_tensor = TileTensor(input, row_major[2, 3]())
    var weights_tensor = TileTensor(weights, row_major[3, 4]())
    var output_tensor = TileTensor(output, row_major[2, 4]())
    var context = DeviceContext(api="coreai")

    matmul[target="coreai"](
        output_tensor,
        input_tensor,
        weights_tensor,
        context,
    )
    context.synchronize()
