import MojoIOSCore
import UIKit

@main
@MainActor
final class ReferenceAppDelegate: UIResponder, UIApplicationDelegate {
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
      name: "Mojo iOS Reference",
      sessionRole: connectingSceneSession.role
    )
    configuration.delegateClass = ReferenceSceneDelegate.self
    return configuration
  }
}

@MainActor
final class ReferenceSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else {
      preconditionFailure("Reference application requires a UIWindowScene")
    }

    precondition(mojo_ios_add(20, 22) == 42)
    precondition(mojo_ios_async_await_sum(20, 19) == 42)

    let left: [Float] = [1, -2, 3.5, 4]
    let right: [Float] = [2, 5, -1.5, 0.5]
    var output = [Float](repeating: 0, count: left.count)
    let metalStatus = left.withUnsafeBufferPointer { leftBuffer in
      right.withUnsafeBufferPointer { rightBuffer in
        output.withUnsafeMutableBufferPointer { outputBuffer in
          mojo_ios_metal_vector_add(
            leftBuffer.baseAddress!,
            rightBuffer.baseAddress!,
            outputBuffer.baseAddress!,
            Int64(outputBuffer.count)
          )
        }
      }
    }
    precondition(metalStatus == 0)
    precondition(output == [3, 3, 2, 4.5])
    print("MOJO_IOS_REFERENCE_APP_PASS cpu=yes async=yes metal=yes")

    let viewController = UIViewController()
    viewController.view.backgroundColor = .systemBackground
    let statusLabel = UILabel()
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.text = "Mojo CPU and Metal passed"
    statusLabel.textAlignment = .center
    viewController.view.addSubview(statusLabel)
    NSLayoutConstraint.activate([
      statusLabel.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
      statusLabel.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
    ])

    let referenceWindow = UIWindow(windowScene: windowScene)
    referenceWindow.rootViewController = viewController
    referenceWindow.makeKeyAndVisible()
    window = referenceWindow
  }
}
