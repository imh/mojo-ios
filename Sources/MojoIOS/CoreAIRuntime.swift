import Foundation

public typealias CoreAICompletion = @convention(c) @Sendable (
  UnsafeMutableRawPointer?, UnsafePointer<CChar>?
) -> Void

private var mojoIOSCoreAIResourceBundle: Bundle {
#if SWIFT_PACKAGE
  Bundle.module
#else
  Bundle.main
#endif
}

#if canImport(CoreAI)
import CoreAI

@available(iOS 27.0, *)
private actor MojoIOSCoreAIModelCache {
  static let shared = MojoIOSCoreAIModelCache()
  private var model: AIModel?

  func loadFunctionForRequest() async throws -> InferenceFunction {
    let loadedModel: AIModel
    if let model {
      loadedModel = model
    } else {
      guard let assetURL = mojoIOSCoreAIResourceBundle.url(
        forResource: "CoreAIMatmulMatmulF32", withExtension: "aimodel"
      ) else {
        throw MojoIOSCoreAIError.missingModelResource
      }
      let options = SpecializationOptions(
        preferredComputeUnitKind: .neuralEngine
      )
      let newModel = try await AIModel(contentsOf: assetURL, options: options)
      model = newModel
      loadedModel = newModel
    }
    guard let loadedFunction = try loadedModel.loadFunction(named: "main") else {
      throw MojoIOSCoreAIError.missingFunction
    }
    precondition(loadedFunction.descriptor.inputNames == [
      "input_values", "first_weights", "second_weights",
    ])
    precondition(loadedFunction.descriptor.outputNames == ["result"])
    return loadedFunction
  }
}

@available(iOS 27.0, *)
private enum MojoIOSCoreAIError: Error {
  case missingModelResource
  case missingFunction
  case missingOutput
  case outputIsNotNDArray
}

@_cdecl("MojoIOSCoreAI_executeMatmulMatmulF32_2x3x4x2")
public func MojoIOSCoreAIExecuteMatmulMatmulF32(
  input: UnsafePointer<Float>?,
  firstWeights: UnsafePointer<Float>?,
  secondWeights: UnsafePointer<Float>?,
  output: UnsafeMutablePointer<Float>?,
  request: UnsafeMutableRawPointer?,
  completion: @escaping CoreAICompletion
) {
  guard #available(iOS 27.0, *) else {
    "Core AI requires iOS or iPadOS 27".withCString {
      completion(request, $0)
    }
    return
  }
  guard let input, let firstWeights, let secondWeights, let output else {
    "Core AI received a null tensor pointer".withCString {
      completion(request, $0)
    }
    return
  }

  let inputAddress = UInt(bitPattern: input)
  let firstWeightsAddress = UInt(bitPattern: firstWeights)
  let secondWeightsAddress = UInt(bitPattern: secondWeights)
  let outputAddress = UInt(bitPattern: output)
  let requestAddress = request.map(UInt.init(bitPattern:))

  Task {
    do {
      let function = try await MojoIOSCoreAIModelCache.shared
        .loadFunctionForRequest()
      let inputPointer = UnsafePointer<Float>(bitPattern: inputAddress)!
      let firstWeightsPointer = UnsafePointer<Float>(
        bitPattern: firstWeightsAddress
      )!
      let secondWeightsPointer = UnsafePointer<Float>(
        bitPattern: secondWeightsAddress
      )!
      let outputPointer = UnsafeMutablePointer<Float>(
        bitPattern: outputAddress
      )!
      let requestPointer = requestAddress.flatMap(
        UnsafeMutableRawPointer.init(bitPattern:)
      )

      let inputs: [String: NDArray] = [
        "input_values": NDArray(
          scalars: Array(UnsafeBufferPointer(start: inputPointer, count: 6)),
          shape: [2, 3]
        ),
        "first_weights": NDArray(
          scalars: Array(
            UnsafeBufferPointer(start: firstWeightsPointer, count: 12)
          ),
          shape: [3, 4]
        ),
        "second_weights": NDArray(
          scalars: Array(
            UnsafeBufferPointer(start: secondWeightsPointer, count: 8)
          ),
          shape: [4, 2]
        ),
      ]
      var outputs = try await function.run(inputs: inputs)
      guard let outputValue = outputs.remove("result") else {
        throw MojoIOSCoreAIError.missingOutput
      }
      guard let result = outputValue.ndArray else {
        throw MojoIOSCoreAIError.outputIsNotNDArray
      }
      precondition(result.shape == [2, 2])
      precondition(result.scalarType == .float32)
      result.view(as: Float.self).withUnsafePointer { pointer, shape, strides in
        precondition(shape.count == 2)
        precondition(shape[0] == 2)
        precondition(shape[1] == 2)
        precondition(strides.count == 2)
        precondition(strides[0] == 2)
        precondition(strides[1] == 1)
        outputPointer.update(from: pointer, count: 4)
      }
      completion(requestPointer, nil)
    } catch {
      let message = "Core AI inference failed: \(String(describing: error))"
      let requestPointer = requestAddress.flatMap(
        UnsafeMutableRawPointer.init(bitPattern:)
      )
      message.withCString { completion(requestPointer, $0) }
    }
  }
}
#else
@_cdecl("MojoIOSCoreAI_executeMatmulMatmulF32_2x3x4x2")
public func MojoIOSCoreAIExecuteMatmulMatmulF32Unavailable(
  input: UnsafePointer<Float>?,
  firstWeights: UnsafePointer<Float>?,
  secondWeights: UnsafePointer<Float>?,
  output: UnsafeMutablePointer<Float>?,
  request: UnsafeMutableRawPointer?,
  completion: CoreAICompletion
) {
  _ = (input, firstWeights, secondWeights, output)
  "Core AI is unavailable in this Apple SDK or destination".withCString {
    completion(request, $0)
  }
}
#endif
