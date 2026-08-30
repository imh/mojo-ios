import MojoIOSCore

public enum MojoIOS {
    @available(iOS 27.0, *)
    public static func coreAIMatmulMatmul(
        input: [Float], firstWeights: [Float], secondWeights: [Float]
    ) throws -> [Float] {
        guard input.count == 6 else {
            throw CoreAIError.invalidElementCount("input", input.count, 6)
        }
        guard firstWeights.count == 12 else {
            throw CoreAIError.invalidElementCount(
                "firstWeights", firstWeights.count, 12
            )
        }
        guard secondWeights.count == 8 else {
            throw CoreAIError.invalidElementCount(
                "secondWeights", secondWeights.count, 8
            )
        }
        var input = input
        var firstWeights = firstWeights
        var secondWeights = secondWeights
        var output = [Float](repeating: 0, count: 4)
        let status = input.withUnsafeMutableBufferPointer { inputBuffer in
            firstWeights.withUnsafeMutableBufferPointer { firstBuffer in
                secondWeights.withUnsafeMutableBufferPointer { secondBuffer in
                    output.withUnsafeMutableBufferPointer { outputBuffer in
                        mojo_ios_coreai_matmul_matmul_f32(
                            inputBuffer.baseAddress!,
                            firstBuffer.baseAddress!,
                            secondBuffer.baseAddress!,
                            outputBuffer.baseAddress!
                        )
                    }
                }
            }
        }
        guard status == 0 else {
            throw CoreAIError.executionFailed
        }
        return output
    }

    public enum CoreAIError: Error, Equatable {
        case invalidElementCount(String, Int, Int)
        case executionFailed
    }

    public static func add(_ left: Int64, _ right: Int64) -> Int64 {
        return mojo_ios_add(left, right)
    }

    public static func listSum(count: Int64) -> Int64 {
        precondition(count >= 0)
        return mojo_ios_list_sum(count)
    }

    public static func seededRandom(seed: Int64) -> UInt64 {
        return mojo_ios_seeded_random(seed)
    }

    public static var argumentCount: Int64 {
        return mojo_ios_argument_count()
    }

    public static func parallelSquares(count: Int) -> [Int64] {
        precondition(count >= 0)
        var output = [Int64](repeating: 0, count: count)
        output.withUnsafeMutableBufferPointer { buffer in
            mojo_ios_parallel_fill_squares(buffer.baseAddress, Int64(count))
        }
        return output
    }

    public static func asyncAwaitSum(_ left: Int64, _ right: Int64) -> Int64 {
        return mojo_ios_async_await_sum(left, right)
    }

    public static func asyncParallelSum(_ left: Int64, _ right: Int64) -> Int64 {
        return mojo_ios_async_parallel_sum(left, right)
    }

    public static func asyncErrorStatus(shouldRaise: Bool) -> Int32 {
        return mojo_ios_async_error_status(shouldRaise ? 1 : 0)
    }
}
