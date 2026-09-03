from std.builtin.device_passable import DevicePassable, DeviceTypeEncoder
from std.gpu import global_idx

from max.gpu.host import DeviceContext, DevicePointer


@fieldwise_init
struct GenericPointerDevice(ImplicitlyCopyable, TrivialRegisterPassable):
    var pointer: Pointer[Float32, MutUntrackedOrigin]
    var sentinel: Int32


@fieldwise_init
struct NestedGenericPointer[
    origin: Origin[mut=True],
](DevicePassable, ImplicitlyCopyable, TrivialRegisterPassable):
    var pointer: DevicePointer[.float32, Self.origin]
    var sentinel: Int32

    comptime device_type: AnyType = GenericPointerDevice

    def _to_device_type(
        self, mut encoder: Some[DeviceTypeEncoder], target: MutOpaquePointer[_]
    ):
        encoder.encode_fields[Self.device_type](self, target)

    @staticmethod
    def get_type_name() -> String:
        return "NestedGenericPointer"


def generic_pointer_kernel(value: GenericPointerDevice):
    if global_idx.x == 0:
        value.pointer[unsafe_offset=0] = Float32(value.sentinel)


def main() raises:
    var context = DeviceContext(api="metal")
    var buffer = context.enqueue_create_buffer[DType.float32](1)
    context.enqueue_function[generic_pointer_kernel](
        NestedGenericPointer(buffer.device_ptr(), 1), grid_dim=1, block_dim=1
    )
