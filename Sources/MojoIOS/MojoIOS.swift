import MojoIOSCore

public enum MojoIOS {
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
