import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    private var randomDistributionTimer: Timer?
    
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
            
            let args = ProcessInfo.processInfo.arguments
            let env = ProcessInfo.processInfo.environment
            
            var tracesSampleRate: NSNumber = 1
            if let tracesSampleRateOverride = env["--io.sentry.tracesSampleRate"] {
               tracesSampleRate = NSNumber(value: (tracesSampleRateOverride as NSString).integerValue)
            }
            options.tracesSampleRate = tracesSampleRate
            
            if let tracesSamplerValue = env["--io.sentry.tracesSamplerValue"] {
                options.tracesSampler = { _ in
                    return NSNumber(value: (tracesSamplerValue as NSString).integerValue)
                }
            }
            
            var profilesSampleRate: NSNumber = 1
            if let profilesSampleRateOverride = env["--io.sentry.profilesSampleRate"] {
               profilesSampleRate = NSNumber(value: (profilesSampleRateOverride as NSString).integerValue)
            }
            options.profilesSampleRate = profilesSampleRate
            
            if let profilesSamplerValue = env["--io.sentry.profilesSamplerValue"] {
                options.profilesSampler = { _ in
                    return NSNumber(value: (profilesSamplerValue as NSString).integerValue)
                }
            }

            options.enableAppLaunchProfiling = args.contains("--profile-app-launches")

            options.sessionTrackingIntervalMillis = 5_000
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            
#if targetEnvironment(simulator)
            options.enableSpotlight = true
            options.environment = "test-app"
#else
            options.environment = "device-tests"
            options.enableWatchdogTerminationTracking = false // The UI tests generate false OOMs
#endif
            options.enableTimeToFullDisplayTracing = true
            options.enablePerformanceV2 = true
            options.enableMetrics = true
            
            options.add(inAppInclude: "iOS_External")

            let isBenchmarking = args.contains("--io.sentry.test.benchmarking")

            // the benchmark test starts and stops a custom transaction using a UIButton, and automatic user interaction tracing stops the transaction that begins with that button press after the idle timeout elapses, stopping the profiler (only one profiler runs regardless of the number of concurrent transactions)
            options.enableUserInteractionTracing = !isBenchmarking && !args.contains("--disable-ui-tracing")
            options.enableAutoPerformanceTracing = !isBenchmarking && !args.contains("--disable-auto-performance-tracing")
            options.enablePreWarmedAppStartTracing = !isBenchmarking

            options.enableFileIOTracing = !args.contains("--disable-file-io-tracing")
            options.enableAutoBreadcrumbTracking = !args.contains("--disable-automatic-breadcrumbs")
            options.enableUIViewControllerTracing = !args.contains("--disable-uiviewcontroller-tracing")
            options.enableNetworkTracking = !args.contains("--disable-network-tracking")
            options.enableCoreDataTracing = !args.contains("--disable-core-data-tracing")
            options.enableNetworkBreadcrumbs = !args.contains("--disable-network-breadcrumbs")
            options.enableSwizzling = !args.contains("--disable-swizzling")
            options.enableCrashHandler = !args.contains("--disable-crash-handler")
            options.enableTracing = !args.contains("--disable-tracing")

            // because we run CPU for 15 seconds at full throttle, we trigger ANR issues being sent. disable such during benchmarks.
            options.enableAppHangTracking = !isBenchmarking && !args.contains("--disable-anr-tracking")
            options.enableWatchdogTerminationTracking = !isBenchmarking && !args.contains("--disable-watchdog-tracking")
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
                let processInfoEnvironment = env["io.sentry.sdk-environment"]
                
                if processInfoEnvironment != nil {
                    scope.setEnvironment(processInfoEnvironment)
                } else if isBenchmarking {
                    scope.setEnvironment("benchmarking")
                } else {
                    scope.setEnvironment("debug")
                }
                
                scope.setTag(value: "swift", key: "language")
               
                let user = User(userId: "1")
                user.email = "tony@example.com"
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
        
        SentrySDK.metrics.increment(key: "app.start", value: 1.0, tags: ["view": "app-delegate"])

    }
    //swiftlint:enable function_body_length

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("[iOS-Swift] [debug] launch arguments: \(ProcessInfo.processInfo.arguments)")
        print("[iOS-Swift] [debug] environment: \(ProcessInfo.processInfo.environment)")
        
        if ProcessInfo.processInfo.arguments.contains("--io.sentry.wipe-data") {
            removeAppData()
        }
        AppDelegate.startSentry()
        
        randomDistributionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let random = Double.random(in: 0..<1_000)
            SentrySDK.metrics.distribution(key: "random.distribution", value: random)
        }
        
        if #available(iOS 15.0, *) {
            metricKit.receiveReports()
        }
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        if #available(iOS 15.0, *) {
            metricKit.pauseReports()
        }
        
        randomDistributionTimer?.invalidate()
        randomDistributionTimer = nil
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
    
    /**
     * previously tried putting this in an AppDelegate.load override in ObjC, but it wouldn't run until
     * after a launch profiler would have an opportunity to run, since SentryProfiler.load would always run
     * first due to being dynamically linked in a framework module. it is sufficient to do it before
     * calling SentrySDK.startWithOptions to clear state for testProfiledAppLaunches because we don't make
     * any assertions on a launch profile the first launch of the app in that test
     */
    private func removeAppData() {
        print("[iOS-Swift] [debug] removing app data")
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        let cache = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        for path in [appSupport, cache] {
            guard let files = FileManager.default.enumerator(atPath: path) else { return }
            for item in files {
                try! FileManager.default.removeItem(atPath: (path as NSString).appendingPathComponent((item as! String)))
            }
        }
    }
}
