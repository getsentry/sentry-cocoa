import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        OS27PrewarmProbe.shared.record(
            name: "scene.willConnect",
            applicationState: UIApplication.shared.applicationState,
            details: [
                "notificationResponse": connectionOptions.notificationResponse != nil,
                "role": session.role.rawValue,
                "urlContextCount": connectionOptions.urlContexts.count,
                "userActivityCount": connectionOptions.userActivities.count
            ]
        )

        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = OS27PrewarmViewController()
        self.window = window
        window.makeKeyAndVisible()
        OS27PrewarmProbe.shared.startFirstDisplayLinkTracking()
    }

    func sceneWillEnterForeground(_: UIScene) {
        OS27PrewarmProbe.shared.record(
            name: "scene.willEnterForeground",
            applicationState: UIApplication.shared.applicationState
        )
    }

    func sceneDidBecomeActive(_: UIScene) {
        OS27PrewarmProbe.shared.record(
            name: "scene.didBecomeActive",
            applicationState: UIApplication.shared.applicationState
        )
    }

    func sceneWillResignActive(_: UIScene) {
        OS27PrewarmProbe.shared.record(
            name: "scene.willResignActive",
            applicationState: UIApplication.shared.applicationState,
            persistImmediately: true
        )
    }

    func sceneDidEnterBackground(_: UIScene) {
        OS27PrewarmProbe.shared.record(
            name: "scene.didEnterBackground",
            applicationState: UIApplication.shared.applicationState,
            persistImmediately: true
        )
    }
}
