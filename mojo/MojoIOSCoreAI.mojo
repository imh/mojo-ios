from std.runtime import initialize_runtime

from layout import TileTensor
from layout.tile_layout import row_major
from linalg.matmul import matmul
from max.gpu.host import DeviceContext


@export("mojo_ios_coreai_matmul_matmul_f32")
def mojo_ios_coreai_matmul_matmul_f32(
    input: Pointer[Float32, MutUntrackedOrigin],
    first_weights: Pointer[Float32, MutUntrackedOrigin],
    second_weights: Pointer[Float32, MutUntrackedOrigin],
    output: Pointer[Float32, MutUntrackedOrigin],
) abi("C") -> Int32:
    """Executes the fixed-shape Core AI MVP through standard MAX operations."""
    initialize_runtime()
    try:
        var intermediate = Array[Float32, 8](uninitialized=True)
        var input_tensor = TileTensor(ptr=input, layout=row_major[2, 3]())
        var first_weights_tensor = TileTensor(
            ptr=first_weights, layout=row_major[3, 4]()
        )
        var intermediate_tensor = TileTensor(
            intermediate, row_major[2, 4]()
        )
        var second_weights_tensor = TileTensor(
            ptr=second_weights, layout=row_major[4, 2]()
        )
        var output_tensor = TileTensor(ptr=output, layout=row_major[2, 2]())
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
        return 0
    except:
        return -1
