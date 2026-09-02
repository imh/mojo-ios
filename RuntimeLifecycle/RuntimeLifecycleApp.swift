import Darwin
import Dispatch
import UIKit

@_silgen_name("mojo_ios_lifecycle_run_all")
private func runAllLifecycleTests() -> Int32
@_silgen_name("mojo_ios_lifecycle_begin_suspension_probe")
private func beginSuspensionProbe() -> Int32
@_silgen_name("mojo_ios_lifecycle_finish_suspension_probe")
private func finishSuspensionProbe() -> Int32

#if MOJO_IOS_LIFECYCLE_O0
    private let lifecycleOptimization = 0
#elseif MOJO_IOS_LIFECYCLE_O3
    private let lifecycleOptimization = 3
#else
    #error("A runtime lifecycle optimization level must be selected")
#endif

#if MOJO_IOS_LIFECYCLE_LINK_ORDER_ab
    private let lifecycleLinkOrder = "ab"
#elseif MOJO_IOS_LIFECYCLE_LINK_ORDER_ba
    private let lifecycleLinkOrder = "ba"
#else
    #error("A runtime lifecycle link order must be selected")
#endif

private func lifecycleMarker(_ event: String) -> String {
    "RUNTIME_LIFECYCLE_" + event
        + " optimization=" + String(lifecycleOptimization)
        + " link_order=" + lifecycleLinkOrder
}

private func emitLifecycleMarker(_ marker: String) {
    print(marker)
    fflush(stdout)
}

@main
@MainActor
final class RuntimeLifecycleAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Mojo runtime lifecycle",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = RuntimeLifecycleSceneDelegate.self
        return configuration
    }
}

@MainActor
final class RuntimeLifecycleSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var initialActivation = true
    private var backgroundTransitionCount = 0

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            preconditionFailure("Runtime lifecycle requires a UIWindowScene")
        }
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Runtime lifecycle probe running"
        statusLabel.textAlignment = .center
        viewController.view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
        ])
        let applicationWindow = UIWindow(windowScene: windowScene)
        applicationWindow.rootViewController = viewController
        applicationWindow.makeKeyAndVisible()
        window = applicationWindow

        precondition(runAllLifecycleTests() == 0)
        precondition(beginSuspensionProbe() == 0)
        emitLifecycleMarker(
            lifecycleMarker("APP_READY") + " pid=" + String(getpid())
                + " runtime=process-resident"
        )

        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            let finishStatus = finishSuspensionProbe()
            let repeatedStatus = runAllLifecycleTests()
            Task { @MainActor in
                precondition(finishStatus == 0)
                precondition(repeatedStatus == 0)
                statusLabel.text = "Runtime lifecycle passed"
                emitLifecycleMarker(
                    lifecycleMarker("APP_PASS")
                        + " suspension_probe=completed foreign_threads=8"
                )
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if initialActivation {
            initialActivation = false
            return
        }
        precondition(runAllLifecycleTests() == 0)
        emitLifecycleMarker(
            lifecycleMarker("FOREGROUND_PASS")
                + " transitions=" + String(backgroundTransitionCount)
        )
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        backgroundTransitionCount += 1
        emitLifecycleMarker(
            lifecycleMarker("BACKGROUND")
                + " transitions=" + String(backgroundTransitionCount)
        )
    }
}
