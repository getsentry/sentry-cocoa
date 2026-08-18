import Sentry
import UIKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        OS27PrewarmProbe.shared.record(
            name: "application.didFinishLaunching.begin",
            applicationState: application.applicationState,
            details: [
                "launchOptionKeys": launchOptions?.keys.map(\.rawValue).sorted() ?? []
            ]
        )

        SentrySDK.start { options in
            options.dsn = Bundle.main.object(forInfoDictionaryKey: "OS27PrewarmDSN") as? String
            options.debug = false
            options.tracesSampleRate = 1
            options.enablePreWarmedAppStartTracing = true
            options.enableMetricKit = false
            options.environment = "os-27-prewarm"
            options.releaseName = "os-27-prewarm@\(OS27PrewarmProbe.shared.buildLabel)"
            options.initialScope = { scope in
                scope.setTag(value: OS27PrewarmProbe.shared.buildLabel, key: "os27-prewarm-build")
                scope.setTag(value: OS27PrewarmProbe.shared.sdkGeneration, key: "os27-prewarm-sdk-generation")
                scope.setTag(
                    value: String(OS27PrewarmProbe.shared.standaloneTracingEnabled),
                    key: "os27-prewarm-standalone"
                )
                return scope
            }
            options.beforeSendSpan = { span in
                OS27PrewarmProbe.shared.recordSentrySpan(span)
                return span
            }

            #if SDK_V10
                options.beforeSendTransaction = { transaction in
                    OS27PrewarmProbe.shared.recordSentryTransaction(transaction)
                    return transaction
                }
            #else
                options.beforeSend = { event in
                    if let transaction = event as? Transaction {
                        OS27PrewarmProbe.shared.recordSentryTransaction(transaction)
                    }
                    return event
                }
                options.enableStandaloneAppStartTracing = OS27PrewarmProbe.shared.standaloneTracingEnabled
            #endif
        }

        OS27PrewarmProbe.shared.record(
            name: "application.didFinishLaunching.end",
            applicationState: application.applicationState
        )
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        OS27PrewarmProbe.shared.record(
            name: "application.configurationForConnectingScene",
            applicationState: application.applicationState,
            details: ["role": connectingSceneSession.role.rawValue]
        )
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        OS27PrewarmProbe.shared.record(
            name: "application.didRegisterForRemoteNotifications",
            applicationState: application.applicationState,
            details: ["deviceToken": token],
            persistImmediately: true
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        OS27PrewarmProbe.shared.record(
            name: "application.didFailToRegisterForRemoteNotifications",
            applicationState: application.applicationState,
            details: ["error": String(describing: error)],
            persistImmediately: true
        )
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        OS27PrewarmProbe.shared.record(
            name: "application.didReceiveRemoteNotification",
            applicationState: application.applicationState,
            details: ["userInfoKeys": userInfo.keys.map { String(describing: $0) }.sorted()],
            persistImmediately: true
        )
        completionHandler(.noData)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        OS27PrewarmProbe.shared.record(
            name: "application.didEnterBackground",
            applicationState: application.applicationState,
            persistImmediately: true
        )
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        OS27PrewarmProbe.shared.record(
            name: "application.willEnterForeground",
            applicationState: application.applicationState
        )
    }

    func applicationWillTerminate(_ application: UIApplication) {
        OS27PrewarmProbe.shared.record(
            name: "application.willTerminate",
            applicationState: application.applicationState,
            persistImmediately: true
        )
    }
}
