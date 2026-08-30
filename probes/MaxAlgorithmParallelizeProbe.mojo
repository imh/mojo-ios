from max.algorithm import parallelize


@export("mojo_ios_max_algorithm_parallelize_probe")
def mojo_ios_max_algorithm_parallelize_probe(
    output: Pointer[Int64, MutUntrackedOrigin], count: Int64
) abi("C"):
    assert count >= 0, "count must not be negative"

    def store_square(work_item_index: Int) {imm}:
        var value = Int64(work_item_index)
        output.unsafe_store(work_item_index, value * value)

    parallelize(store_square, Int(count))
