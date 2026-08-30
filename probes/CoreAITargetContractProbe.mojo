from std.gpu.host.info import (
    is_accelerator,
    is_coreai,
    is_cpu,
    is_gpu,
    is_npu,
    is_valid_target,
)


@export("mojo_ios_coreai_target_contract")
def mojo_ios_coreai_target_contract() abi("C") -> Int32:
    comptime assert is_coreai["coreai"]()
    comptime assert is_accelerator["coreai"]()
    comptime assert is_valid_target["coreai"]()
    comptime assert not is_cpu["coreai"]()
    comptime assert not is_gpu["coreai"]()
    comptime assert not is_npu["coreai"]()
    comptime assert not is_coreai["cpu"]()
    comptime assert not is_coreai["gpu"]()
    comptime assert not is_coreai["npu"]()
    return 1
