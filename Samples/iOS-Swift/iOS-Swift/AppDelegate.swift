import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    static let defaultDSN = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // For testing purposes, we want to be able to change the DSN and store it to disk. In a real app, you shouldn't need this behavior.
        let dsn = DSNStorage.shared.getDSN() ?? AppDelegate.defaultDSN
        DSNStorage.shared.saveDSN(dsn: dsn)
        
        SentrySDK.start { options in
            options.dsn = dsn
            options.beforeSend = { event in
                return event
            }
            options.debug = true
            // Sampling 100% - In Production you probably want to adjust this
            options.tracesSampleRate = 1.0
            options.sessionTrackingIntervalMillis = 5_000
            options.enableFileIOTracking = true
            options.enableCoreDataTracking = true
            options.enableProfiling = true
            options.attachScreenshot = true

            if !ProcessInfo.processInfo.arguments.contains("--io.sentry.test.benchmarking") {
                // the benchmark test starts and stops a custom transaction using a UIButton, and automatic user interaction tracing stops the transaction that begins with that button press after the idle timeout elapses, stopping the profiler (only one profiler runs regardless of the number of concurrent transactions)
                options.enableUserInteractionTracing = true

                // because we run CPU for 15 seconds at full throttle, we trigger ANR issues being sent. disable such during benchmarks.
                options.enableAppHangTracking = true
                options.appHangTimeoutInterval = 2
            }
        }
        
        return true
    }
}
