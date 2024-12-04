import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    private var randomDistributionTimer: Timer?
    
    var window: UIWindow?

    static let defaultDSN = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"

    //swiftlint:disable function_body_length cyclomatic_complexity
    func startSentry() {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        
        // For testing purposes, we want to be able to change the DSN and store it to disk. In a real app, you shouldn't need this behavior.
        var dsn: String?
        do {
            if let dsn = env["--io.sentry.dsn"] {
                try DSNStorage.shared.saveDSN(dsn: dsn)
            }
            dsn = try DSNStorage.shared.getDSN() ?? AppDelegate.defaultDSN
        } catch {
            print("[iOS-Swift] Error encountered while reading stored DSN: \(error)")
        }
        
        SentrySDK.start(configureOptions: { options in
            options.dsn = dsn
            options.beforeSend = { event in
                return event
            }
            options.beforeSendSpan = { span in
                return span
            }
            options.beforeCaptureScreenshot = { _ in
                return true
            }
            options.beforeCaptureViewHierarchy = { _ in
                return true
            }
            options.debug = true
            
            if #available(iOS 16.0, *), !args.contains("--disable-session-replay") {
                options.experimental.sessionReplay = SentryReplayOptions(sessionSampleRate: 0, onErrorSampleRate: 1, maskAllText: true, maskAllImages: true)
                options.experimental.sessionReplay.quality = .high
            }
            
            if #available(iOS 15.0, *), !args.contains("--disable-metrickit-integration") {
                options.enableMetricKit = true
                options.enableMetricKitRawPayload = true
            }
            
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
            
            var profilesSampleRate: NSNumber? = 1
            if args.contains("--io.sentry.enableContinuousProfiling") {
                profilesSampleRate = nil
            } else if let profilesSampleRateOverride = env["--io.sentry.profilesSampleRate"] {
               profilesSampleRate = NSNumber(value: (profilesSampleRateOverride as NSString).integerValue)
            }
            options.profilesSampleRate = profilesSampleRate
            
            if let profilesSamplerValue = env["--io.sentry.profilesSamplerValue"] {
                options.profilesSampler = { _ in
                    return NSNumber(value: (profilesSamplerValue as NSString).integerValue)
                }
            }

            options.enableAppLaunchProfiling = args.contains("--profile-app-launches")

            options.enableAutoSessionTracking = !args.contains("--disable-automatic-session-tracking")
            if let sessionTrackingIntervalMillis = env["--io.sentry.sessionTrackingIntervalMillis"] {
                options.sessionTrackingIntervalMillis = UInt((sessionTrackingIntervalMillis as NSString).integerValue)
            }
            options.attachScreenshot = true
            options.attachViewHierarchy = true
       
#if targetEnvironment(simulator)
            options.enableSpotlight = !args.contains("--disable-spotlight")
#else
            options.enableWatchdogTerminationTracking = false // The UI tests generate false OOMs
#endif
            options.enableTimeToFullDisplayTracing = true
            options.enablePerformanceV2 = true
            
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
            options.enablePersistingTracesWhenCrashing = true

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
                if let environmentOverride = env["--io.sentry.sdk-environment"] {
                    scope.setEnvironment(environmentOverride)
                } else if isBenchmarking {
                    scope.setEnvironment("benchmarking")
                } else {
        #if targetEnvironment(simulator)
                    scope.setEnvironment("simulator")
        #else
                    scope.setEnvironment("device")
        #endif // targetEnvironment(simulator)
                }
                
                scope.setTag(value: "swift", key: "language")
                
                scope.injectGitInformation()
                                               
                let user = User(userId: "1")
                user.email = env["--io.sentry.user.email"] ?? "tony@example.com"
                // first check if the username has been overridden in the scheme for testing purposes; then try to use the system username so each person gets an automatic way to easily filter things on the dashboard; then fall back on a hardcoded value if none of these are present
                let username = env["--io.sentry.user.username"] ?? (env["SIMULATOR_HOST_HOME"] as? NSString)?
                    .lastPathComponent ?? "cocoa developer"
                user.username = username
                scope.setUser(user)

                if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
                    scope.addAttachment(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
                }
                if let data = "hello".data(using: .utf8) {
                    scope.addAttachment(Attachment(data: data, filename: "log.txt"))
                }
                return scope
            }
            
            options.configureUserFeedback = { config in
                let layoutOffset = UIOffset(horizontal: 25, vertical: 75)
                guard !args.contains("--io.sentry.feedback.all-defaults") else {
                    config.configureWidget = { widget in   
                        widget.layoutUIOffset = layoutOffset
                    }
                    return
                }
                config.animations = !args.contains("--io.sentry.feedback.no-animations")
                config.useShakeGesture = true
                config.showFormForScreenshots = true
                config.configureWidget = { widget in
                    if args.contains("--io.sentry.feedback.auto-inject-widget") {
                        if Locale.current.languageCode == "ar" { // arabic
                            widget.labelText = "﷽"
                        } else if Locale.current.languageCode == "ur" { // urdu
                            widget.labelText = "نستعلیق"
                        } else if Locale.current.languageCode == "he" { // hebrew
                            widget.labelText = "עִבְרִית‎"
                        } else if Locale.current.languageCode == "hi" { // Hindi
                            widget.labelText = "नागरि"
                        } else {
                            widget.labelText = "Report Jank"
                        }
                        widget.widgetAccessibilityLabel = "io.sentry.iOS-Swift.button.report-jank"
                        widget.layoutUIOffset = layoutOffset
                    } else {
                        widget.autoInject = false
                    }
                    if args.contains("--io.sentry.feedback.no-widget-text") {
                        widget.labelText = nil
                    }
                    if args.contains("--io.sentry.feedback.no-widget-icon") {
                        widget.showIcon = false
                    }
                }
                config.configureForm = { uiForm in
                    uiForm.formTitle = "Jank Report"
                    uiForm.isEmailRequired = true
                    uiForm.submitButtonLabel = "Report that jank"
                    uiForm.addScreenshotButtonLabel = "Show us the jank"
                    uiForm.messagePlaceholder = "Describe the nature of the jank. Its essence, if you will."
                }
                config.configureTheme = { theme in
                    let fontFamily: String
                    if Locale.current.languageCode == "ar" { // arabic; ar_EG
                        fontFamily = "Damascus"
                    } else if Locale.current.languageCode == "ur" { // urdu; ur_PK
                        fontFamily = "NotoNastaliq"
                    } else if Locale.current.languageCode == "he" { // hebrew; he_IL
                        fontFamily = "Arial Hebrew"
                    } else if Locale.current.languageCode == "hi" { // Hindi; hi_IN
                        fontFamily = "DevanagariSangamMN"
                    } else {
                        fontFamily = "ChalkboardSE-Regular"
                    }
                    theme.fontFamily = fontFamily
                    theme.outlineStyle = .init(outlineColor: .purple)
                    theme.foreground = .purple
                    theme.background = .init(red: 0.95, green: 0.9, blue: 0.95, alpha: 1)
                    theme.submitBackground = .orange
                    theme.submitForeground = .purple
                    theme.buttonBackground = .purple
                    theme.buttonForeground = .white
                }
                config.onSubmitSuccess = { info in
                    let name = info["name"] ?? "$shakespearean_insult_name"
                    let alert = UIAlertController(title: "Thanks?", message: "We have enough jank of our own, we really didn't need yours too, \(name).", preferredStyle: .alert)
                    alert.addAction(.init(title: "Deal with it 🕶️", style: .default))
                    self.window?.rootViewController?.present(alert, animated: true)
                }
                config.onSubmitError = { error in
                    let alert = UIAlertController(title: "D'oh", message: "You tried to report jank, and encountered more jank. The jank has you now: \(error).", preferredStyle: .alert)
                    alert.addAction(.init(title: "Derp", style: .default))
                    self.window?.rootViewController?.present(alert, animated: true)
                }
            }
        })

    }
    //swiftlint:enable function_body_length cyclomatic_complexity

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("[iOS-Swift] [debug] launch arguments: \(ProcessInfo.processInfo.arguments)")
        print("[iOS-Swift] [debug] environment: \(ProcessInfo.processInfo.environment)")
        
        if ProcessInfo.processInfo.arguments.contains("--io.sentry.wipe-data") {
            removeAppData()
        }
        if !ProcessInfo.processInfo.arguments.contains("--skip-sentry-init") {
            startSentry()
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
        let cache = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        guard let files = FileManager.default.enumerator(atPath: cache) else { return }
        for item in files {
            try! FileManager.default.removeItem(atPath: (cache as NSString).appendingPathComponent((item as! String)))
        }
    }
}
