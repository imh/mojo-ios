from std.gpu.host.info import get_gpu_target
from std.sys.info import CompilationTarget, is_triple


def _assert_metal_target_triples[
    standard_triple: StringLiteral, metal4_triple: StringLiteral
]():
    comptime assert is_triple[
        standard_triple, get_gpu_target["apple-m1"]()
    ]()
    comptime assert is_triple[
        standard_triple, get_gpu_target["apple-m2"]()
    ]()
    comptime assert is_triple[
        standard_triple, get_gpu_target["apple-m3"]()
    ]()
    comptime assert is_triple[
        standard_triple, get_gpu_target["apple-m4"]()
    ]()
    comptime assert is_triple[
        standard_triple, get_gpu_target["apple-m5"]()
    ]()
    comptime assert is_triple[
        metal4_triple, get_gpu_target["apple-m1-metal4"]()
    ]()
    comptime assert is_triple[
        metal4_triple, get_gpu_target["apple-m2-metal4"]()
    ]()
    comptime assert is_triple[
        metal4_triple, get_gpu_target["apple-m3-metal4"]()
    ]()
    comptime assert is_triple[
        metal4_triple, get_gpu_target["apple-m4-metal4"]()
    ]()
    comptime assert is_triple[
        metal4_triple, get_gpu_target["apple-m5-metal4"]()
    ]()


@export("mojo_ios_metal_target_contract")
def mojo_ios_metal_target_contract() abi("C") -> Int32:
    comptime if CompilationTarget.is_ios():
        comptime if CompilationTarget.is_simulator():
            _assert_metal_target_triples[
                "air64-apple-ios15.0-simulator",
                "air64-apple-ios27.0-simulator",
            ]()
        else:
            _assert_metal_target_triples[
                "air64-apple-ios15.0", "air64-apple-ios27.0"
            ]()
    else:
        _assert_metal_target_triples[
            "air64-apple-macosx", "air64-apple-macosx"
        ]()
    return 1
