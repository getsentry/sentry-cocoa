import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var randomDistributionTimer: Timer?
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if args.contains("--io.sentry.wipe-data") {
            removeAppData()
        }
        if !args.contains("--skip-sentry-init") {
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

// MARK: SDK Configuration
extension AppDelegate {
    func startSentry() {
        SentrySDK.start(configureOptions: configureSentryOptions(options:))
    }
    
    func configureSentryOptions(options: Options) {
        options.dsn = dsn
        options.beforeSend = { $0 }
        options.beforeSendSpan = { $0 }
        options.beforeCaptureScreenshot = { _ in true }
        options.beforeCaptureViewHierarchy = { _ in true }
        options.debug = true
        
        if #available(iOS 16.0, *), enableSessionReplay {
            options.sessionReplay = SentryReplayOptions(sessionSampleRate: 0, onErrorSampleRate: 1, maskAllText: true, maskAllImages: true)
            options.sessionReplay.quality = .high
        }
        
        if #available(iOS 15.0, *), enableMetricKit {
            options.enableMetricKit = true
            options.enableMetricKitRawPayload = true
        }
        
        options.tracesSampleRate = tracesSampleRate
        options.tracesSampler = tracesSampler
        options.profilesSampleRate = profilesSampleRate
        options.profilesSampler = profilesSampler
        options.enableAppLaunchProfiling = enableAppLaunchProfiling

        options.enableAutoSessionTracking = enableSessionTracking
        if let sessionTrackingIntervalMillis = env["--io.sentry.sessionTrackingIntervalMillis"] {
            options.sessionTrackingIntervalMillis = UInt((sessionTrackingIntervalMillis as NSString).integerValue)
        }
        
        options.add(inAppInclude: "iOS_External")

        options.enableUserInteractionTracing = enableUITracing
        options.enableAppHangTracking = enableANRTracking
        options.enableWatchdogTerminationTracking = enableWatchdogTracking
        options.enableAutoPerformanceTracing = enablePerformanceTracing
        options.enablePreWarmedAppStartTracing = enablePrewarmedAppStartTracing
        options.enableFileIOTracing = enableFileIOTracing
        options.enableAutoBreadcrumbTracking = enableBreadcrumbs
        options.enableUIViewControllerTracing = enableUIVCTracing
        options.enableNetworkTracking = enableNetworkTracing
        options.enableCoreDataTracing = enableCoreDataTracing
        options.enableNetworkBreadcrumbs = enableNetworkBreadcrumbs
        options.enableSwizzling = enableSwizzling
        options.enableCrashHandler = enableCrashHandling
        options.enableTracing = enableTracing
        options.enablePersistingTracesWhenCrashing = true
        options.attachScreenshot = true
        options.attachViewHierarchy = true
        options.enableTimeToFullDisplayTracing = true
        options.enablePerformanceV2 = true
        options.failedRequestStatusCodes = [ HttpStatusCodeRange(min: 400, max: 599) ]
        
        options.beforeBreadcrumb = { breadcrumb in
            //Raising notifications when a new breadcrumb is created in order to use this information
            //to validate whether proper breadcrumb are being created in the right places.
            NotificationCenter.default.post(name: .init("io.sentry.newbreadcrumb"), object: breadcrumb)
            return breadcrumb
        }
        
        options.initialScope = configureInitialScope(scope:)
        options.configureUserFeedback = configureFeedback(config:)
    }
    
    func configureInitialScope(scope: Scope) -> Scope {
        if let environmentOverride = self.env["--io.sentry.sdk-environment"] {
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
        user.email = self.env["--io.sentry.user.email"] ?? "tony@example.com"
        // first check if the username has been overridden in the scheme for testing purposes; then try to use the system username so each person gets an automatic way to easily filter things on the dashboard; then fall back on a hardcoded value if none of these are present
        let username = self.env["--io.sentry.user.username"] ?? (self.env["SIMULATOR_HOST_HOME"] as? NSString)?
            .lastPathComponent ?? "cocoadev"
        user.username = username
        user.name = self.env["--io.sentry.user.name"] ?? "cocoa developer"
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

// MARK: User feedback configuration
extension AppDelegate {
    var layoutOffset: UIOffset { UIOffset(horizontal: 25, vertical: 75) }
    
    func configureFeedbackWidget(config: SentryUserFeedbackWidgetConfiguration) {
        if args.contains("--io.sentry.feedback.auto-inject-widget") {
            if Locale.current.languageCode == "ar" { // arabic
                config.labelText = "﷽"
            } else if Locale.current.languageCode == "ur" { // urdu
                config.labelText = "نستعلیق"
            } else if Locale.current.languageCode == "he" { // hebrew
                config.labelText = "עִבְרִית‎"
            } else if Locale.current.languageCode == "hi" { // Hindi
                config.labelText = "नागरि"
            } else {
                config.labelText = "Report Jank"
            }
            config.widgetAccessibilityLabel = "io.sentry.iOS-Swift.button.report-jank"
            config.layoutUIOffset = layoutOffset
        } else {
            config.autoInject = false
        }
        if args.contains("--io.sentry.feedback.no-widget-text") {
            config.labelText = nil
        }
        if args.contains("--io.sentry.feedback.no-widget-icon") {
            config.showIcon = false
        }
    }
    
    func configureFeedbackForm(config: SentryUserFeedbackFormConfiguration) {
        config.formTitle = "Jank Report"
        config.isEmailRequired = args.contains("--io.sentry.feedback.require-email")
        config.isNameRequired = args.contains("--io.sentry.feedback.require-name")
        config.submitButtonLabel = "Report that jank"
        config.addScreenshotButtonLabel = "Show us the jank"
        config.removeScreenshotButtonLabel = "Oof too nsfl"
        config.cancelButtonLabel = "What, me worry?"
        config.messagePlaceholder = "Describe the nature of the jank. Its essence, if you will."
        config.namePlaceholder = "Yo name"
        config.emailPlaceholder = "Yo email"
        config.messageLabel = "Thy complaint"
        config.emailLabel = "Thine email"
        config.nameLabel = "Thy name"
    }
    
    func configureFeedbackTheme(config: SentryUserFeedbackThemeConfiguration) {
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
        config.fontFamily = fontFamily
        config.outlineStyle = .init(outlineColor: .purple)
        config.foreground = .purple
        config.background = .init(red: 0.95, green: 0.9, blue: 0.95, alpha: 1)
        config.submitBackground = .orange
        config.submitForeground = .purple
        config.buttonBackground = .purple
        config.buttonForeground = .white
    }
    
    func configureFeedback(config: SentryUserFeedbackConfiguration) {
        guard !args.contains("--io.sentry.feedback.all-defaults") else {
            config.configureWidget = { widget in
                widget.layoutUIOffset = self.layoutOffset
            }
            return
        }
        
        config.useSentryUser = args.contains("--io.sentry.feedback.use-sentry-user")
        config.animations = !args.contains("--io.sentry.feedback.no-animations")
        config.useShakeGesture = true
        config.showFormForScreenshots = true
        config.configureWidget = configureFeedbackWidget(config:)
        config.configureForm = configureFeedbackForm(config:)
        config.configureTheme = configureFeedbackTheme(config:)
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
}

// MARK: Convenience access to SDK configuration via launch arg / environment variable
extension AppDelegate {
    static let defaultDSN = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
    
    var args: [String] {
        let args = ProcessInfo.processInfo.arguments
        print("[iOS-Swift] [debug] launch arguments: \(args)")
        return args
    }
    
    var env: [String: String] {
        let env = ProcessInfo.processInfo.environment
        print("[iOS-Swift] [debug] environment: \(env)")
        return env
    }
    
    /// For testing purposes, we want to be able to change the DSN and store it to disk. In a real app, you shouldn't need this behavior.
    var dsn: String? {
        do {
            if let dsn = env["--io.sentry.dsn"] {
                try DSNStorage.shared.saveDSN(dsn: dsn)
            }
            return try DSNStorage.shared.getDSN() ?? AppDelegate.defaultDSN
        } catch {
            print("[iOS-Swift] Error encountered while reading stored DSN: \(error)")
        }
        return nil
    }
    
    /// Whether or not profiling benchmarks are being run; this requires disabling certain other features for proper functionality.
    var isBenchmarking: Bool { args.contains("--io.sentry.test.benchmarking") }
    var isUITest: Bool { env["--io.sentry.sdk-environment"] == "ui-tests" }
    
    func checkDisabled(with arg: String) -> Bool {
        args.contains("--disable-everything") || args.contains(arg)
    }
    
    // MARK: features that care about simulator vs device, ui tests and profiling benchmarks
    var enableSpotlight: Bool {
#if targetEnvironment(simulator)
        !checkDisabled(with: "--disable-spotlight")
#else
        false
#endif // targetEnvironment(simulator)
    }
    
    /// - note: the benchmark test starts and stops a custom transaction using a UIButton, and automatic user interaction tracing stops the transaction that begins with that button press after the idle timeout elapses, stopping the profiler (only one profiler runs regardless of the number of concurrent transactions)
    var enableUITracing: Bool { !isBenchmarking && !checkDisabled(with: "--disable-ui-tracing") }
    var enablePrewarmedAppStartTracing: Bool { !isBenchmarking }
    var enablePerformanceTracing: Bool { !isBenchmarking && !checkDisabled(with: "--disable-auto-performance-tracing") }
    var enableTracing: Bool { !isBenchmarking && !checkDisabled(with: "--disable-tracing") }
    /// - note: UI tests generate false OOMs
    var enableWatchdogTracking: Bool { !isUITest && !isBenchmarking && !checkDisabled(with: "--disable-watchdog-tracking") }
    /// - note: disable during benchmarks because we run CPU for 15 seconds at full throttle which can trigger ANRs
    var enableANRTracking: Bool { !isBenchmarking && !checkDisabled(with: "--disable-anr-tracking") }
    
    // MARK: Other features
    
    var enableSessionReplay: Bool { !checkDisabled(with: "--disable-session-replay") }
    var enableMetricKit: Bool { !checkDisabled(with: "--disable-metrickit-integration") }
    var enableSessionTracking: Bool { !checkDisabled(with: "--disable-automatic-session-tracking") }
    var enableFileIOTracing: Bool { !checkDisabled(with: "--disable-file-io-tracing") }
    var enableBreadcrumbs: Bool { !checkDisabled(with: "--disable-automatic-breadcrumbs") }
    var enableUIVCTracing: Bool { !checkDisabled(with: "--disable-uiviewcontroller-tracing") }
    var enableNetworkTracing: Bool { !checkDisabled(with: "--disable-network-tracking") }
    var enableCoreDataTracing: Bool { !checkDisabled(with: "--disable-core-data-tracing") }
    var enableNetworkBreadcrumbs: Bool { !checkDisabled(with: "--disable-network-breadcrumbs") }
    var enableSwizzling: Bool { !checkDisabled(with: "--disable-swizzling") }
    var enableCrashHandling: Bool { !checkDisabled(with: "--disable-crash-handler") }
    
    var tracesSampleRate: NSNumber {
        guard let tracesSampleRateOverride = env["--io.sentry.tracesSampleRate"] else {
            return 1
        }
        return NSNumber(value: (tracesSampleRateOverride as NSString).integerValue)
    }
    
    var tracesSampler: ((SamplingContext) -> NSNumber?)? {
        guard let tracesSamplerValue = env["--io.sentry.tracesSamplerValue"] else {
            return nil
        }
        
        return { _ in
            return NSNumber(value: (tracesSamplerValue as NSString).integerValue)
        }
    }
    
    var profilesSampleRate: NSNumber? {
        if args.contains("--io.sentry.enableContinuousProfiling") {
            return nil
        } else if let profilesSampleRateOverride = env["--io.sentry.profilesSampleRate"] {
            return NSNumber(value: (profilesSampleRateOverride as NSString).integerValue)
        } else {
            return 1
        }
    }
    
    var profilesSampler: ((SamplingContext) -> NSNumber?)? {
        guard let profilesSamplerValue = env["--io.sentry.profilesSamplerValue"] else {
            return nil
        }
        
        return { _ in
            return NSNumber(value: (profilesSamplerValue as NSString).integerValue)
        }
    }
    
    var enableAppLaunchProfiling: Bool { args.contains("--profile-app-launches") }
}
