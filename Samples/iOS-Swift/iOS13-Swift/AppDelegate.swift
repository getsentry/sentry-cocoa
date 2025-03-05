import Sentry
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let defaultDSN = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
    
    func startSentry() {
        // For testing purposes, we want to be able to change the DSN and store it to disk. In a real app, you shouldn't need this behavior.
        var storedDsn: String?
        do {
            storedDsn = try DSNStorage.shared.getDSN()
            try DSNStorage.shared.saveDSN(dsn: storedDsn ?? Self.defaultDSN)
        } catch {
            print("[iOS-Swift] Failed to read/write DSN: \(error)")
        }
        
        let dsn = storedDsn ?? Self.defaultDSN
        
        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = true
            if #available(iOS 15.0, *) {
                options.enableMetricKit = true
            }
            // Sampling 100% - In Production you probably want to adjust this
            options.tracesSampleRate = 1.0
            options.sessionTrackingIntervalMillis = 5_000
            options.profilesSampleRate = 1.0
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            options.environment = "test-app"
            options.enableTimeToFullDisplayTracing = true
            options.initialScope = { scope in
                scope.injectGitInformation()
                return scope
            }

            // Experimental features
            options.experimental.enableFileManagerSwizzling = true
            options.experimental.enableExperimentalViewRenderer = true
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        startSentry()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}
