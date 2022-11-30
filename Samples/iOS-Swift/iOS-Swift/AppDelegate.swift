import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    static let defaultDSN = "https://49962454dbc3404890bacf3133c30b09@crash.uu.163.com/2"
    
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
            options.profilesSampleRate = 1.0
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            options.environment = "test-app"
            options.batteryMonitoringEnabled = true
            let isBenchmarking = ProcessInfo.processInfo.arguments.contains("--io.sentry.test.benchmarking")
            options.enableAutoPerformanceTracking = !isBenchmarking

            // the benchmark test starts and stops a custom transaction using a UIButton, and automatic user interaction tracing stops the transaction that begins with that button press after the idle timeout elapses, stopping the profiler (only one profiler runs regardless of the number of concurrent transactions)
            options.enableUserInteractionTracing = !isBenchmarking
            options.enableAutoPerformanceTracking = !isBenchmarking
            options.enablePreWarmedAppStartTracking = !isBenchmarking

            // because we run CPU for 15 seconds at full throttle, we trigger ANR issues being sent. disable such during benchmarks.
            options.enableAppHangTracking = !isBenchmarking
            options.appHangTimeoutInterval = 2
            options.enableCaptureFailedRequests = true
            let httpStatusCodeRange = HttpStatusCodeRange(min: 400, max: 599)
            options.failedRequestStatusCodes = [ httpStatusCodeRange ]
        }
        
        if #available(iOS 14.0, *) {
            metricKit.receiveReports()
        }
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        if #available(iOS 14.0, *) {
            metricKit.pauseReports()
        }
    }
    
    // Workaround for 'Stored properties cannot be marked potentially unavailable with '@available''
    private var _metricKit: Any?
    @available(iOS 14.0, *)
    fileprivate var metricKit: MetricKitManager {
        if _metricKit == nil {
            _metricKit = MetricKitManager()
        }
        
        // We know the type so it's fine to force cast.
        // swiftlint:disable force_cast
        return _metricKit as! MetricKitManager
        // swiftlint:enable force_cast
    }
}
