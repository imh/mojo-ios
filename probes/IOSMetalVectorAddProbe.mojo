from std.collections import List
from std.gpu import global_idx, thread_idx
from std.memory import unsafe_stack_allocation
from std.runtime import initialize_runtime

from max.gpu.host import DeviceContext, LaunchAttribute
from max.gpu.host.launch_attribute import (
    LaunchAttributeID,
    LaunchAttributeValue,
)
from max.gpu.memory import external_memory
from max.gpu.sync import barrier


comptime FEATURE_MATRIX_ELEMENT_COUNT = 64
comptime FEATURE_MATRIX_WIDTH = 8


def _vector_add_kernel(
    left: Pointer[Float32, MutAnyOrigin],
    right: Pointer[Float32, MutAnyOrigin],
    output: Pointer[Float32, MutAnyOrigin],
):
    var element_index = global_idx.x
    output[unsafe_offset=element_index] = (
        left[unsafe_offset=element_index]
        + right[unsafe_offset=element_index]
    )


def _three_dimensional_add_kernel(
    output: Pointer[Float32, MutAnyOrigin], delta: Float32
):
    var x = global_idx.x
    var y = global_idx.y
    var z = global_idx.z
    var element_index = z * 16 + y * 4 + x
    output[unsafe_offset=element_index] += delta


def _static_threadgroup_reverse_kernel(
    output: Pointer[Float32, MutAnyOrigin],
):
    var scratch = unsafe_stack_allocation[
        FEATURE_MATRIX_ELEMENT_COUNT, Float32, address_space=.SHARED
    ]()
    var element_index = thread_idx.x
    scratch[unsafe_offset=element_index] = output[
        unsafe_offset=element_index
    ]
    barrier()
    output[unsafe_offset=element_index] = scratch[
        unsafe_offset=FEATURE_MATRIX_ELEMENT_COUNT - 1 - element_index
    ]


def _dynamic_threadgroup_reverse_and_add_kernel(
    output: Pointer[Float32, MutAnyOrigin], delta: Float32
):
    var scratch = external_memory[
        Float32, address_space=.SHARED, alignment=4
    ]()
    var element_index = thread_idx.x
    scratch[unsafe_offset=element_index] = output[
        unsafe_offset=element_index
    ]
    barrier()
    output[unsafe_offset=element_index] = (
        scratch[
            unsafe_offset=FEATURE_MATRIX_ELEMENT_COUNT - 1 - element_index
        ]
        + delta
    )


def _vector_add_on_metal(
    left: Pointer[Float32, MutUntrackedOrigin],
    right: Pointer[Float32, MutUntrackedOrigin],
    output: Pointer[Float32, MutUntrackedOrigin],
    count: Int64,
) raises:
    assert count >= 0, "count must not be negative"

    var context = DeviceContext(api="metal")
    var element_count = Int(count)
    var left_buffer = context.enqueue_create_buffer[DType.float32](element_count)
    var right_buffer = context.enqueue_create_buffer[DType.float32](element_count)
    var output_buffer = context.enqueue_create_buffer[DType.float32](element_count)

    context.enqueue_copy(left_buffer, left.as_imm())
    context.enqueue_copy(right_buffer, right.as_imm())
    context.enqueue_function[_vector_add_kernel](
        left_buffer,
        right_buffer,
        output_buffer,
        grid_dim=element_count,
        block_dim=1,
    )
    context.enqueue_copy(output, output_buffer)
    context.synchronize()


def _run_metal_feature_matrix(
    output: Pointer[Float32, MutUntrackedOrigin],
) raises:
    var context = DeviceContext(api="metal")
    var output_buffer = context.enqueue_create_buffer[DType.float32](
        FEATURE_MATRIX_ELEMENT_COUNT
    )

    # Use the value-taking unified-closure overload. This encodes the ordinary
    # scalar captures as the closure value and the output buffer as its normal
    # explicit argument, exercising both Metal DevicePassable paths together.
    var scale = Float32(2)
    var bias = Float32(3)
    var width = Int32(FEATURE_MATRIX_WIDTH)

    def captured_affine_kernel(
        output_pointer: Pointer[Float32, MutAnyOrigin],
    ) {
        var scale, var bias, var width
    }:
        var x = global_idx.x
        var y = global_idx.y
        var element_index = y * Int(width) + x
        output_pointer[unsafe_offset=element_index] = (
            Float32(element_index) * scale + bias
        )

    context.enqueue_function(
        captured_affine_kernel,
        output_buffer,
        grid_dim=(2, 2),
        block_dim=(4, 4),
    )

    # A genuinely three-dimensional launch proves all X/Y/Z index families and
    # all launch dimensions.  The explicit scalar is a separate constant-buffer
    # argument rather than part of the closure environment above.
    context.enqueue_function[_three_dimensional_add_kernel](
        output_buffer,
        Float32(5),
        grid_dim=(2, 2, 2),
        block_dim=(2, 2, 2),
    )

    context.enqueue_function[_static_threadgroup_reverse_kernel](
        output_buffer,
        grid_dim=1,
        block_dim=FEATURE_MATRIX_ELEMENT_COUNT,
    )
    context.enqueue_function[_dynamic_threadgroup_reverse_and_add_kernel](
        output_buffer,
        Float32(7),
        grid_dim=1,
        block_dim=FEATURE_MATRIX_ELEMENT_COUNT,
        shared_mem_bytes=FEATURE_MATRIX_ELEMENT_COUNT * 4,
    )

    context.enqueue_copy(output, output_buffer)
    context.synchronize()


@export("mojo_ios_metal_vector_add")
def mojo_ios_metal_vector_add(
    left: Pointer[Float32, MutUntrackedOrigin],
    right: Pointer[Float32, MutUntrackedOrigin],
    output: Pointer[Float32, MutUntrackedOrigin],
    count: Int64,
) abi("C") -> Int32:
    initialize_runtime()
    if count < 0:
        return -1
    if count == 0:
        return 0

    try:
        _vector_add_on_metal(left, right, output, count)
        return 0
    except error:
        print("Metal vector-add probe failed:", error)
        return -2


@export("mojo_ios_metal_feature_matrix")
def mojo_ios_metal_feature_matrix(
    output: Pointer[Float32, MutUntrackedOrigin],
) abi("C") -> Int32:
    initialize_runtime()
    try:
        _run_metal_feature_matrix(output)
        return 0
    except error:
        print("Metal feature-matrix probe failed:", error)
        return -1


@export("mojo_ios_metal_reject_cuda_launch_attribute")
def mojo_ios_metal_reject_cuda_launch_attribute() abi("C") -> Int32:
    initialize_runtime()
    try:
        var context = DeviceContext(api="metal")
        var output = context.enqueue_create_buffer[DType.float32](1)
        var attributes = List[LaunchAttribute]()
        attributes.append(
            LaunchAttribute(
                LaunchAttributeID.COOPERATIVE, LaunchAttributeValue(True)
            )
        )
        try:
            context.enqueue_function[_three_dimensional_add_kernel](
                output,
                Float32(0),
                grid_dim=1,
                block_dim=1,
                attributes=attributes^,
            )
        except error:
            if (
                "Metal launch attribute COOPERATIVE is CUDA-only"
                in String(error)
            ):
                return 0
            print("Metal returned the wrong launch-attribute error:", error)
            return -2
        print("Metal silently accepted a CUDA-only launch attribute")
        return -3
    except error:
        print("Metal launch-attribute rejection probe failed:", error)
        return -1
