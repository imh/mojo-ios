import Darwin
import Dispatch
import MojoIOSCore
import UIKit

@_silgen_name("KGEN_CompilerRT_DestroyGlobals")
private func destroyMojoGlobalsForTesting()

#if MOJO_IOS_ENABLE_METAL_SMOKE
    @_silgen_name("mojo_ios_metal_vector_add")
    private func mojoIOSMetalVectorAdd(
        _ left: UnsafePointer<Float>,
        _ right: UnsafePointer<Float>,
        _ output: UnsafeMutablePointer<Float>,
        _ count: Int64
    ) -> Int32

    @_silgen_name("mojo_ios_metal_feature_matrix")
    private func mojoIOSMetalFeatureMatrix(
        _ output: UnsafeMutablePointer<Float>
    ) -> Int32

    @_silgen_name("mojo_ios_metal_reject_cuda_launch_attribute")
    private func mojoIOSMetalRejectCUDALaunchAttribute() -> Int32
#endif

@main
@MainActor
final class DeviceSmokeAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Mojo iOS device smoke",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = DeviceSmokeSceneDelegate.self
        return configuration
    }
}

@MainActor
final class DeviceSmokeSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            preconditionFailure("Device smoke requires a UIWindowScene")
        }
        let smokeWindow = UIWindow(windowScene: windowScene)
        smokeWindow.rootViewController = UIViewController()
        smokeWindow.makeKeyAndVisible()
        window = smokeWindow

        let additionResult = mojo_ios_add(20, 22)
        precondition(additionResult == 42, "Mojo returned \(additionResult); expected 42")

        for _ in 0..<1_000 {
            let listSumResult = mojo_ios_list_sum(100)
            precondition(listSumResult == 4_950, "Mojo List sum returned \(listSumResult); expected 4950")
        }

        let firstRandomResult = mojo_ios_seeded_random(42)
        destroyMojoGlobalsForTesting()
        let secondRandomResult = mojo_ios_seeded_random(42)
        precondition(firstRandomResult == secondRandomResult)

        precondition(mojo_ios_argument_count() == 1)
        mojo_ios_print_diagnostic()

        var concurrencyDiagnostic = [Int64](repeating: 0, count: 256)
        concurrencyDiagnostic.withUnsafeMutableBufferPointer { buffer in
            mojo_ios_parallel_fill_squares(
                buffer.baseAddress, Int64(buffer.count)
            )
        }
        precondition(concurrencyDiagnostic[0] == 0)
        precondition(concurrencyDiagnostic[1] == 1)
        precondition(concurrencyDiagnostic[255] == 65_025)

        DispatchQueue.concurrentPerform(iterations: 4) { workerIndex in
            var squares = [Int64](repeating: 0, count: 1_024)
            squares.withUnsafeMutableBufferPointer { buffer in
                mojo_ios_parallel_fill_squares(
                    buffer.baseAddress, Int64(buffer.count)
                )
            }
            precondition(squares[0] == 0)
            precondition(squares[workerIndex] == Int64(workerIndex * workerIndex))
            precondition(squares[1_023] == 1_046_529)
        }

        precondition(mojo_ios_async_await_sum(20, 19) == 42)
        precondition(mojo_ios_async_parallel_sum(20, 19) == 42)
        precondition(mojo_ios_async_error_status(0) == 0)
        precondition(mojo_ios_async_error_status(1) == -1)
        DispatchQueue.concurrentPerform(iterations: 8) { workerIndex in
            let left = Int64(workerIndex)
            precondition(mojo_ios_async_await_sum(left, 39 - left) == 42)
        }

        #if MOJO_IOS_ENABLE_METAL_SMOKE
            let metalLeft: [Float] = [1, -2, 3.5, 4, 9, 0.25, -8, 2]
            let metalRight: [Float] = [2, 5, -1.5, 0.5, 1, 0.75, 3, -4]
            let metalExpected: [Float] = [3, 3, 2, 4.5, 10, 1, -5, -2]
            var metalOutput = [Float](repeating: 0, count: metalExpected.count)
            let metalStatus = metalLeft.withUnsafeBufferPointer { leftBuffer in
                metalRight.withUnsafeBufferPointer { rightBuffer in
                    metalOutput.withUnsafeMutableBufferPointer { outputBuffer in
                        mojoIOSMetalVectorAdd(
                            leftBuffer.baseAddress!,
                            rightBuffer.baseAddress!,
                            outputBuffer.baseAddress!,
                            Int64(outputBuffer.count)
                        )
                    }
                }
            }
            precondition(metalStatus == 0, "Mojo Metal probe returned \(metalStatus)")
            precondition(
                metalOutput == metalExpected,
                "Mojo Metal output \(metalOutput); expected \(metalExpected)"
            )

            var metalFeatureOutput = [Float](repeating: 0, count: 64)
            let metalFeatureStatus = metalFeatureOutput.withUnsafeMutableBufferPointer {
                outputBuffer in
                mojoIOSMetalFeatureMatrix(outputBuffer.baseAddress!)
            }
            let metalFeatureExpected = (0..<64).map { Float(2 * $0 + 15) }
            precondition(
                metalFeatureStatus == 0,
                "Mojo Metal feature matrix returned \(metalFeatureStatus)"
            )
            precondition(
                metalFeatureOutput == metalFeatureExpected,
                "Mojo Metal feature output \(metalFeatureOutput); "
                    + "expected \(metalFeatureExpected)"
            )
            precondition(
                mojoIOSMetalRejectCUDALaunchAttribute() == 0,
                "Metal did not explicitly reject a CUDA-only launch attribute"
            )
            let metalMarker = " metal=useful-mvp"
        #else
            let metalMarker = ""
        #endif

        print(
            "MOJO_IOS_DEVICE_SMOKE_PASS result=42 list_sum=4950 "
                + "iterations=1000 globals=recreated process=integrated "
                + "parallel_api=passed foreign_threads=passed "
                + "async=suspend-resume-errors" + metalMarker
        )
        exit(EXIT_SUCCESS)
    }
}
