from std.runtime import initialize_runtime

from max.algorithm import parallelize


@export("mojo_ios_lifecycle_library_a")
def mojo_ios_lifecycle_library_a(
    output: Pointer[Int64, MutUntrackedOrigin], count: Int64
) abi("C") -> Int64:
    initialize_runtime()
    if count <= 0:
        return -1

    var element_count = Int(count)
    var owned_values = List[Int64](length=element_count, fill=0)
    for index in range(element_count):
        owned_values[index] = Int64(index + 1)

    def store_square(index: Int) {imm}:
        var value = Int64(index)
        output.unsafe_store(index, value * value)

    parallelize(store_square, element_count)

    var result: Int64 = 0
    for index in range(element_count):
        result += owned_values[index]
        result += output.unsafe_load(index)
    return result
