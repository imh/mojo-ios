import Dispatch
import MojoIOSCore
import XCTest
@testable import MojoIOS

@_silgen_name("KGEN_CompilerRT_DestroyGlobals")
private func destroyMojoGlobalsForTesting()

final class MojoIOSTests: XCTestCase {
    func testMojoAddition() {
        XCTAssertEqual(MojoIOS.add(20, 22), 42)
    }

    func testRepeatedMojoListAllocationAndDestruction() {
        for _ in 0..<1_000 {
            XCTAssertEqual(MojoIOS.listSum(count: 100), 4_950)
        }
    }

    func testGlobalRandomStateCanBeDestroyedAndRecreated() {
        let firstResult = MojoIOS.seededRandom(seed: 42)
        destroyMojoGlobalsForTesting()
        let secondResult = MojoIOS.seededRandom(seed: 42)
        XCTAssertEqual(firstResult, secondResult)
    }

    func testEmbeddedProcessAndDiagnosticIntegration() {
        XCTAssertEqual(MojoIOS.argumentCount, 1)
        mojo_ios_print_diagnostic()
    }

    func testMojoParallelSquares() {
        let result = MojoIOS.parallelSquares(count: 256)
        XCTAssertEqual(result.count, 256)
        XCTAssertEqual(result[0], 0)
        XCTAssertEqual(result[1], 1)
        XCTAssertEqual(result[255], 65_025)
    }

    func testParallelMojoCallsFromSwiftOwnedThreads() {
        DispatchQueue.concurrentPerform(iterations: 4) { workerIndex in
            let result = MojoIOS.parallelSquares(count: 1_024)
            precondition(result[0] == 0)
            precondition(result[workerIndex] == Int64(workerIndex * workerIndex))
            precondition(result[1_023] == 1_046_529)
        }
    }

    func testMojoAsyncSuspendsResumesAndReturnsAResult() {
        XCTAssertEqual(MojoIOS.asyncAwaitSum(20, 19), 42)
    }

    func testMojoAsyncParallelSum() {
        XCTAssertEqual(MojoIOS.asyncParallelSum(20, 19), 42)
    }

    func testMojoAsyncRaisedErrorsReachTheSynchronousBoundary() {
        XCTAssertEqual(MojoIOS.asyncErrorStatus(shouldRaise: false), 0)
        XCTAssertEqual(MojoIOS.asyncErrorStatus(shouldRaise: true), -1)
    }

    func testAsyncMojoCallsFromSwiftOwnedThreads() {
        DispatchQueue.concurrentPerform(iterations: 8) { workerIndex in
            let left = Int64(workerIndex)
            let result = MojoIOS.asyncAwaitSum(left, 39 - left)
            precondition(result == 42)
        }
    }
}
