import Dispatch
import UIKit

@_silgen_name("mojo_ios_conformance_family_count")
private func conformanceFamilyCount() -> Int64
@_silgen_name("mojo_ios_conformance_run_all")
private func runAllConformance() -> Int64

private func runConformanceCorpus() {
    precondition(conformanceFamilyCount() > 0)
    precondition(runAllConformance() == 0)
}

#if MOJO_IOS_CONFORMANCE_O0
    private let conformanceOptimization = 0
#elseif MOJO_IOS_CONFORMANCE_O3
    private let conformanceOptimization = 3
#else
    #error("A CPU conformance optimization level must be selected")
#endif

@main
@MainActor
final class CPUConformanceAppDelegate: UIResponder, UIApplicationDelegate {
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
            name: "Mojo CPU Conformance",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = CPUConformanceSceneDelegate.self
        return configuration
    }
}

@MainActor
final class CPUConformanceSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            preconditionFailure("CPU conformance requires a UIWindowScene")
        }
        runConformanceCorpus()
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            runConformanceCorpus()
        }
        print(
            "CPU_CONFORMANCE_APP_PASS optimization="
                + String(conformanceOptimization)
                + " families="
                + String(conformanceFamilyCount())
                + " foreign_threads=yes"
        )
        fflush(stdout)

        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "CPU conformance passed"
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
    }
}
