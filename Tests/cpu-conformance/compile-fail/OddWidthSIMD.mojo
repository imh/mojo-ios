def main():
    var values = SIMD[DType.int32, 3](1, 2, 3)
    _ = values + values
