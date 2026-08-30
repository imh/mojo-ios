import Darwin
import Foundation
import UIKit

@_silgen_name("mojo_ios_coreai_matmul_matmul_f32")
private func mojoIOSCoreAIMatmulMatmul(
  _ input: UnsafeMutablePointer<Float>,
  _ firstWeights: UnsafeMutablePointer<Float>,
  _ secondWeights: UnsafeMutablePointer<Float>,
  _ output: UnsafeMutablePointer<Float>
) -> Int32

private enum CoreAIMojoSmoke {
  static func evaluate() -> [Float] {
    var input: [Float] = [1, 2, 3, 4, 5, 6]
    var firstWeights: [Float] = [
      1, 0, 0, 1,
      0, 1, 1, 0,
      1, 1, 0, 0,
    ]
    var secondWeights: [Float] = [
      1, 0,
      0, 1,
      1, 0,
      0, 1,
    ]
    var output = [Float](repeating: .nan, count: 4)
    let status = input.withUnsafeMutableBufferPointer { inputBuffer in
      firstWeights.withUnsafeMutableBufferPointer { firstBuffer in
        secondWeights.withUnsafeMutableBufferPointer { secondBuffer in
          output.withUnsafeMutableBufferPointer { outputBuffer in
            mojoIOSCoreAIMatmulMatmul(
              inputBuffer.baseAddress!,
              firstBuffer.baseAddress!,
              secondBuffer.baseAddress!,
              outputBuffer.baseAddress!
            )
          }
        }
      }
    }
    precondition(status == 0, "Mojo Core AI call failed with status \(status)")
    precondition(
      output == [6, 6, 15, 15],
      "Core AI output \(output); expected [6, 6, 15, 15]"
    )
    return output
  }
}

@main
@MainActor
final class CoreAIDeviceSmokeAppDelegate: UIResponder, UIApplicationDelegate {
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
      name: "Core AI device smoke",
      sessionRole: connectingSceneSession.role
    )
    configuration.delegateClass = CoreAIDeviceSmokeSceneDelegate.self
    return configuration
  }
}

@MainActor
final class CoreAIDeviceSmokeSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else {
      preconditionFailure("Core AI device smoke requires a UIWindowScene")
    }
    let smokeWindow = UIWindow(windowScene: windowScene)
    smokeWindow.rootViewController = UIViewController()
    smokeWindow.makeKeyAndVisible()
    window = smokeWindow

    Task {
      for _ in 0..<3 {
        _ = await Task.detached { CoreAIMojoSmoke.evaluate() }.value
      }
      for _ in 0..<10 {
        await withCheckedContinuation { continuation in
          DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.concurrentPerform(iterations: 8) { _ in
              precondition(CoreAIMojoSmoke.evaluate() == [6, 6, 15, 15])
            }
            continuation.resume()
          }
        }
      }
      guard let executionNonce = ProcessInfo.processInfo.environment[
        "MOJO_IOS_COREAI_EXECUTION_NONCE"
      ], !executionNonce.isEmpty else {
        preconditionFailure("Core AI device smoke requires an execution nonce")
      }
      let passMarker =
        "MOJO_IOS_COREAI_DEVICE_SMOKE_PASS "
        + "source=standard-mojo graph=matmul-matmul "
        + "calls=sequential-concurrent concurrent_rounds=10 "
        + "fallback=none ane=preferred "
        + "execution_nonce=\(executionNonce)\n"
      let resultURL = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
      ).preconditionOnlyElement.appendingPathComponent(
        "CoreAIDeviceSmokeResult.txt"
      )
      try! Data(passMarker.utf8).write(to: resultURL, options: .atomic)
      passMarker.withCString { markerBytes in
        let markerByteCount = strlen(markerBytes)
        let writtenByteCount = Darwin.write(
          STDOUT_FILENO,
          markerBytes,
          markerByteCount
        )
        precondition(writtenByteCount == markerByteCount)
      }
      exit(EXIT_SUCCESS)
    }
  }
}

private extension Array {
  var preconditionOnlyElement: Element {
    precondition(count == 1)
    return self[0]
  }
}
