import Darwin
import CoreAI
import Foundation
import UIKit

@available(iOS 27.0, *)
private actor CoreAIProbeModelCache {
  static let shared = CoreAIProbeModelCache()
  private var model: AIModel?

  func loadFunctionForRequest() async throws -> InferenceFunction {
    let loadedModel: AIModel
    if let model {
      loadedModel = model
    } else {
      guard let assetURL = Bundle.main.url(
        forResource: "CoreAIMatmulMatmulF32", withExtension: "aimodel"
      ) else {
        preconditionFailure("missing direct Core AI probe resource")
      }
      let options = SpecializationOptions(
        preferredComputeUnitKind: .neuralEngine
      )
      let newModel = try await AIModel(contentsOf: assetURL, options: options)
      model = newModel
      loadedModel = newModel
    }
    guard let function = try loadedModel.loadFunction(named: "main") else {
      preconditionFailure("direct Core AI probe has no main function")
    }
    return function
  }
}

@available(iOS 27.0, *)
private enum CoreAIProbeSmoke {
  static func evaluate() async throws -> [Float] {
    let input: [Float] = [1, 2, 3, 4, 5, 6]
    let firstWeights: [Float] = [
      1, 0, 0, 1,
      0, 1, 1, 0,
      1, 1, 0, 0,
    ]
    let secondWeights: [Float] = [
      1, 0,
      0, 1,
      1, 0,
      0, 1,
    ]
    let function = try await CoreAIProbeModelCache.shared.loadFunctionForRequest()
    var outputs = try await function.run(inputs: [
      "input_values": NDArray(scalars: input, shape: [2, 3]),
      "first_weights": NDArray(scalars: firstWeights, shape: [3, 4]),
      "second_weights": NDArray(scalars: secondWeights, shape: [4, 2]),
    ])
    guard let outputValue = outputs.remove("result"),
          let output = outputValue.ndArray else {
      preconditionFailure("direct Core AI probe did not return result NDArray")
    }
    return output.view(as: Float.self).withUnsafePointer {
      pointer, shape, strides in
      precondition(shape.count == 2)
      precondition(shape[0] == 2)
      precondition(shape[1] == 2)
      precondition(strides.count == 2)
      precondition(strides[0] == 2)
      precondition(strides[1] == 1)
      return Array(UnsafeBufferPointer(start: pointer, count: 4))
    }
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
        let output = try! await CoreAIProbeSmoke.evaluate()
        precondition(output == [6, 6, 15, 15])
      }
      for _ in 0..<10 {
        try! await withThrowingTaskGroup(of: [Float].self) { taskGroup in
          for _ in 0..<8 {
            taskGroup.addTask {
              try await CoreAIProbeSmoke.evaluate()
            }
          }
          for try await output in taskGroup {
            precondition(output == [6, 6, 15, 15])
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
        + "source=direct-swift-probe graph=matmul-matmul "
        + "calls=sequential-concurrent concurrent_rounds=10 "
        + "mojo_backend=not-implemented fallback=none ane=preferred "
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
