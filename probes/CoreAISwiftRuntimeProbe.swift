import CoreAI
import Foundation

@available(iOS 27.0, *)
enum CoreAISwiftRuntimeProbeError: Error {
  case invalidInputAccepted
  case missingFunction(String)
  case missingOutput(String)
  case outputIsNotNDArray(String)
}

@available(iOS 27.0, *)
enum CoreAISwiftRuntimeProbe {
  private static let inputValues: [Float] = [
    1.0, 2.0, 3.0,
    -1.0, 0.5, 2.0,
  ]

  private static let expectedResult: [Float] = [
    7.0, 1.0, 2.5, 1.0,
    3.0, 1.5, 1.25, 0.0,
  ]

  static func run(assetURL: URL) async throws {
    let specializationOptions = SpecializationOptions(
      preferredComputeUnitKind: .neuralEngine
    )
    precondition(specializationOptions.preferredComputeUnitKind == .neuralEngine)
    precondition(specializationOptions.allowedComputeUnitKinds.contains(.neuralEngine))

    let model = try await AIModel(
      contentsOf: assetURL,
      options: specializationOptions
    )
    precondition(model.functionNames == ["main"])

    guard let function = try model.loadFunction(named: "main") else {
      throw CoreAISwiftRuntimeProbeError.missingFunction("main")
    }
    precondition(function.descriptor.inputNames == ["input_values"])
    precondition(function.descriptor.outputNames == ["result"])

    for _ in 0..<3 {
      try await evaluate(function: function)
    }

    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
      for _ in 0..<8 {
        taskGroup.addTask {
          try await evaluate(function: function)
        }
      }
      try await taskGroup.waitForAll()
    }

    do {
      let invalidInput = NDArray(
        scalars: [Float](repeating: 0, count: 4),
        shape: [2, 2]
      )
      _ = try await function.run(inputs: ["input_values": invalidInput])
      throw CoreAISwiftRuntimeProbeError.invalidInputAccepted
    } catch let probeError as CoreAISwiftRuntimeProbeError {
      throw probeError
    } catch {
      // The native Core AI shape error is the expected outcome.
    }
  }

  private static func evaluate(function: InferenceFunction) async throws {
    let input = NDArray(scalars: inputValues, shape: [2, 3])
    var outputs = try await function.run(inputs: ["input_values": input])
    precondition(outputs.count == 1)
    precondition(Array(outputs.names) == ["result"])

    guard let outputValue = outputs.remove("result") else {
      throw CoreAISwiftRuntimeProbeError.missingOutput("result")
    }
    guard let output = outputValue.ndArray else {
      throw CoreAISwiftRuntimeProbeError.outputIsNotNDArray("result")
    }
    precondition(output.shape == [2, 4])
    precondition(output.scalarType == .float32)

    let outputView = output.view(as: Float.self)
    let actualResult = outputView.withUnsafePointer { pointer, shape, strides in
      precondition(shape.count == 2)
      precondition(shape[0] == 2)
      precondition(shape[1] == 4)
      precondition(strides.count == 2)
      precondition(strides[0] == 4)
      precondition(strides[1] == 1)
      return Array(UnsafeBufferPointer(start: pointer, count: 8))
    }
    precondition(actualResult == expectedResult)
  }
}
