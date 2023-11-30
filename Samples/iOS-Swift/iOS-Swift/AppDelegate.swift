import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    static let defaultDSN = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"

    //swiftlint:disable function_body_length
    static func startSentry() {
        // For testing purposes, we want to be able to change the DSN and store it to disk. In a real app, you shouldn't need this behavior.
        let dsn = DSNStorage.shared.getDSN() ?? AppDelegate.defaultDSN
        DSNStorage.shared.saveDSN(dsn: dsn)
        
        SentrySDK.start { options in
            options.dsn = dsn
            options.beforeSend = { event in
                return event
            }
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

            let isBenchmarking = ProcessInfo.processInfo.arguments.contains("--io.sentry.test.benchmarking")

            // the benchmark test starts and stops a custom transaction using a UIButton, and automatic user interaction tracing stops the transaction that begins with that button press after the idle timeout elapses, stopping the profiler (only one profiler runs regardless of the number of concurrent transactions)
            options.enableUserInteractionTracing = !isBenchmarking && !ProcessInfo.processInfo.arguments.contains("--disable-ui-tracing")
            options.enableAutoPerformanceTracing = !isBenchmarking && !ProcessInfo.processInfo.arguments.contains("--disable-auto-performance-tracing")
            options.enablePreWarmedAppStartTracing = !isBenchmarking

            options.enableFileIOTracing = !ProcessInfo.processInfo.arguments.contains("--disable-file-io-tracing")
            options.enableAutoBreadcrumbTracking = !ProcessInfo.processInfo.arguments.contains("--disable-automatic-breadcrumbs")
            options.enableUIViewControllerTracing = !ProcessInfo.processInfo.arguments.contains("--disable-uiviewcontroller-tracing")
            options.enableNetworkTracking = !ProcessInfo.processInfo.arguments.contains("--disable-network-tracking")
            options.enableCoreDataTracing = !ProcessInfo.processInfo.arguments.contains("--disable-core-data-tracing")
            options.enableNetworkBreadcrumbs = !ProcessInfo.processInfo.arguments.contains("--disable-network-breadcrumbs")
            options.enableSwizzling = !ProcessInfo.processInfo.arguments.contains("--disable-swizzling")
            options.enableCrashHandler = !ProcessInfo.processInfo.arguments.contains("--disable-crash-handler")

            // because we run CPU for 15 seconds at full throttle, we trigger ANR issues being sent. disable such during benchmarks.
            options.enableAppHangTracking = !isBenchmarking && !ProcessInfo.processInfo.arguments.contains("--disable-anr-tracking")
            options.appHangTimeoutInterval = 2
            options.enableCaptureFailedRequests = true
            let httpStatusCodeRange = HttpStatusCodeRange(min: 400, max: 599)
            options.failedRequestStatusCodes = [ httpStatusCodeRange ]
            options.beforeBreadcrumb = { breadcrumb in
                //Raising notifications when a new breadcrumb is created in order to use this information
                //to validate whether proper breadcrumb are being created in the right places.
                NotificationCenter.default.post(name: .init("io.sentry.newbreadcrumb"), object: breadcrumb)
                return breadcrumb
            }
            
            options.initialScope = { scope in
                scope.setEnvironment("debug")
                scope.setTag(value: "swift", key: "language")
               
                let user = User(userId: "1")
                user.email = "philipp@example.com"
                scope.setUser(user)

                if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
                    scope.addAttachment(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
                }
                if let data = "hello".data(using: .utf8) {
                    scope.addAttachment(Attachment(data: data, filename: "log.txt"))
                }
                return scope
            }
        }
    }
    //swiftlint:enable function_body_length

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        AppDelegate.startSentry()
        
        if #available(iOS 15.0, *) {
            metricKit.receiveReports()
        }
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        if #available(iOS 15.0, *) {
            metricKit.pauseReports()
        }
    }
    
    // Workaround for 'Stored properties cannot be marked potentially unavailable with '@available''
    private var _metricKit: Any?
    @available(iOS 15.0, *)
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
