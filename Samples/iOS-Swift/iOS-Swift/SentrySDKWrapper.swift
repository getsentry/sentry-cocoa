// swiftlint:disable file_length function_body_length

import Sentry
import UIKit

struct SentrySDKWrapper {
    static let shared = SentrySDKWrapper()
    
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
            options.sessionReplay = SentryReplayOptions(
                sessionSampleRate: 0,
                onErrorSampleRate: 1,
                maskAllText: true,
                maskAllImages: true
            )
            options.sessionReplay.quality = .high
        }
        
        if #available(iOS 15.0, *), enableMetricKit {
            options.enableMetricKit = true
            options.enableMetricKitRawPayload = true
        }

        options.tracesSampleRate = 1
        if let sampleRate = SentrySDKOverrides.Tracing.sampleRate {
            options.tracesSampleRate = NSNumber(value: sampleRate)
        }
        if let samplerValue = SentrySDKOverrides.Tracing.samplerValue {
            options.tracesSampler = { _ in
                return NSNumber(value: samplerValue)
            }
        }

        configureProfiling(options)

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
        options.attachScreenshot = enableAttachScreenshot
        options.attachViewHierarchy = enableAttachViewHierarchy
        options.enableTimeToFullDisplayTracing = enableTimeToFullDisplayTracing
        options.enablePerformanceV2 = enablePerformanceV2
        options.enableAppHangTrackingV2 = enableAppHangTrackingV2
        options.failedRequestStatusCodes = [ HttpStatusCodeRange(min: 400, max: 599) ]
        
        options.beforeBreadcrumb = { breadcrumb in
            //Raising notifications when a new breadcrumb is created in order to use this information
            //to validate whether proper breadcrumb are being created in the right places.
            NotificationCenter.default.post(name: .init("io.sentry.newbreadcrumb"), object: breadcrumb)
            return breadcrumb
        }
        
        options.initialScope = configureInitialScope(scope:)
        options.configureUserFeedback = configureFeedback(config:)

        // Experimental features
        options.experimental.enableFileManagerSwizzling = true
        options.sessionReplay.enableExperimentalViewRenderer = true
        // Disable the fast view renderering, because we noticed parts (like the tab bar) are not rendered correctly
        options.sessionReplay.enableFastViewRendering = false
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
        user.username = username
        user.name = userFullName
        scope.setUser(user)
        
        if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
            scope.addAttachment(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
        }
        let data = Data("hello".utf8)
        scope.addAttachment(Attachment(data: data, filename: "log.txt"))
        return scope
    }
    
    var userFullName: String {
        let name = self.env["--io.sentry.user.name"] ?? NSFullUserName()
        guard !name.isEmpty else {
            return "cocoa developer"
        }
        return name
    }
    
    var username: String {
        let username = self.env["--io.sentry.user.username"] ?? NSUserName()
        guard !username.isEmpty else {
            return (self.env["SIMULATOR_HOST_HOME"] as? NSString)?
                .lastPathComponent ?? "cocoadev"
        }
        return username
    }
}

// MARK: User feedback configuration
extension SentrySDKWrapper {
    var layoutOffset: UIOffset { UIOffset(horizontal: 25, vertical: 75) }
    
    func configureFeedbackWidget(config: SentryUserFeedbackWidgetConfiguration) {
        guard !args.contains("--io.sentry.feedback.no-auto-inject-widget") else {
            config.autoInject = false
            return
        }
        
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
        config.layoutUIOffset = layoutOffset
        
        if args.contains("--io.sentry.feedback.no-widget-text") {
            config.labelText = nil
        }
        if args.contains("--io.sentry.feedback.no-widget-icon") {
            config.showIcon = false
        }
    }
    
    func configureFeedbackForm(config: SentryUserFeedbackFormConfiguration) {
        config.useSentryUser = !args.contains("--io.sentry.feedback.dont-use-sentry-user")
        config.formTitle = "Jank Report"
        config.isEmailRequired = args.contains("--io.sentry.feedback.require-email")
        config.isNameRequired = args.contains("--io.sentry.feedback.require-name")
        config.submitButtonLabel = "Report that jank"
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
        config.outlineStyle = .init(color: .purple)
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
            configureHooks(config: config)
            return
        }
        
        config.animations = !args.contains("--io.sentry.feedback.no-animations")
        config.useShakeGesture = true
        config.showFormForScreenshots = true
        config.configureWidget = configureFeedbackWidget(config:)
        config.configureForm = configureFeedbackForm(config:)
        config.configureTheme = configureFeedbackTheme(config:)
        configureHooks(config: config)
    }
    
    func configureHooks(config: SentryUserFeedbackConfiguration) {
        config.onFormOpen = {
            updateHookMarkers(forEvent: "onFormOpen")
        }
        config.onFormClose = {
            updateHookMarkers(forEvent: "onFormClose")
        }
        config.onSubmitSuccess = { info in
            let name = info["name"] ?? "$shakespearean_insult_name"
            let alert = UIAlertController(title: "Thanks?", message: "We have enough jank of our own, we really didn't need yours too, \(name).", preferredStyle: .alert)
            alert.addAction(.init(title: "Deal with it 🕶️", style: .default))
            UIApplication.shared.delegate?.window??.rootViewController?.present(alert, animated: true)
            
            // if there's a screenshot's Data in this dictionary, JSONSerialization crashes _even though_ there's a `try?`, so we'll write the base64 encoding of it
            var infoToWriteToFile = info
            if let attachments = info["attachments"] as? [Any], let screenshot = attachments.first as? Data {
                infoToWriteToFile["attachments"] = [screenshot.base64EncodedString()]
            }
            
            let jsonData = (try? JSONSerialization.data(withJSONObject: infoToWriteToFile, options: .sortedKeys)) ?? Data()
            updateHookMarkers(forEvent: "onSubmitSuccess", with: jsonData.base64EncodedString())
        }
        config.onSubmitError = { error in
            let alert = UIAlertController(title: "D'oh", message: "You tried to report jank, and encountered more jank. The jank has you now: \(error).", preferredStyle: .alert)
            alert.addAction(.init(title: "Derp", style: .default))
            UIApplication.shared.delegate?.window??.rootViewController?.present(alert, animated: true)
            let nserror = error as NSError
            let missingFieldsSorted = (nserror.userInfo["missing_fields"] as? [String])?.sorted().joined(separator: ";") ?? ""
            updateHookMarkers(forEvent: "onSubmitError", with: "\(nserror.domain);\(nserror.code);\(nserror.localizedDescription);\(missingFieldsSorted)")
        }
    }
    
    func updateHookMarkers(forEvent name: String, with contents: String? = nil) {
        guard let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
            print("[iOS-Swift] Couldn't retrieve path to application support directory.")
            return
        }
        
        let fm = FileManager.default
        let dir = "\(appSupportDirectory)/io.sentry/feedback"
        let isDirectory = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 1)
        isDirectory.initialize(to: ObjCBool(false))
        let exists = fm.fileExists(atPath: dir, isDirectory: isDirectory)
        if exists, !isDirectory.pointee.boolValue {
            print("[iOS-Swift] Found a file named \(dir) which is not a directory. Removing it...")
            do {
                try fm.removeItem(atPath: dir)
            } catch {
                print("[iOS-Swift] Couldn't remove existing file \(dir): \(error).")
                return
            }
        } else if !exists {
            do {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            } catch {
                print("[iOS-Swift] Couldn't create directory structure for user feedback form hook marker files: \(error).")
                return
            }
        }
        
        createHookFile(path: "\(dir)/\(name)", contents: contents)
        
        switch name {
        case "onFormOpen": removeHookFile(path: "\(dir)/onFormClose")
        case "onFormClose": removeHookFile(path: "\(dir)/onFormOpen")
        case "onSubmitSuccess": removeHookFile(path: "\(dir)/onSubmitError")
        case "onSubmitError": removeHookFile(path: "\(dir)/onSubmitSuccess")
        default: fatalError("Unexpected marker file name")
        }
    }
    
    func createHookFile(path: String, contents: String?) {
        if let contents = contents {
            do {
                try contents.write(to: URL(fileURLWithPath: path), atomically: false, encoding: .utf8)
            } catch {
                print("[iOS-Swift] Couldn't write contents into user feedback form hook marker file at \(path).")
            }
        } else if !FileManager.default.createFile(atPath: path, contents: nil) {
            print("[iOS-Swift] Couldn't create user feedback form hook marker file at \(path).")
        } else {
            print("[iOS-Swift] Created user feedback form hook marker file at \(path).")
        }
    }
    
    func removeHookFile(path: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return }
        do {
            try fm.removeItem(atPath: path)
        } catch {
            print("[iOS-Swift] Couldn't remove user feedback form hook marker file \(path): \(error).")
        }
    }
}

// MARK: Convenience access to SDK configuration via launch arg / environment variable
extension SentrySDKWrapper {
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
            return try DSNStorage.shared.getDSN() ?? SentrySDKWrapper.defaultDSN
        } catch {
            print("[iOS-Swift] Error encountered while reading stored DSN: \(error)")
        }
        return nil
    }
    
    /// Whether or not profiling benchmarks are being run; this requires disabling certain other features for proper functionality.
    var isBenchmarking: Bool { args.contains("--io.sentry.test.benchmarking") }
    var isUITest: Bool { env["--io.sentry.sdk-environment"] == "ui-tests" }
    
    func checkDisabled(with arg: String) -> Bool {
        args.contains("--io.sentry.disable-everything") || args.contains(arg)
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
    var enablePrewarmedAppStartTracing: Bool { !isBenchmarking && !checkDisabled(with: "--disable-prewarmed-app-start-tracing") }
    var enablePerformanceTracing: Bool { !isBenchmarking && !checkDisabled(with: "--disable-auto-performance-tracing") }
    var enableTracing: Bool { !isBenchmarking && !checkDisabled(with: "--disable-tracing") }
    /// - note: UI tests generate false OOMs
    var enableWatchdogTracking: Bool { !isUITest && !isBenchmarking && !checkDisabled(with: "--disable-watchdog-tracking") }
    /// - note: disable during benchmarks because we run CPU for 15 seconds at full throttle which can trigger ANRs
    var enableANRTracking: Bool { !isBenchmarking && !checkDisabled(with: "--disable-anr-tracking") }
    
    // MARK: Other features
    
    var enableTimeToFullDisplayTracing: Bool { !checkDisabled(with: "--disable-time-to-full-display-tracing")}
    var enableAttachScreenshot: Bool { !checkDisabled(with: "--disable-attach-screenshot")}
    var enableAttachViewHierarchy: Bool { !checkDisabled(with: "--disable-attach-view-hierarchy")}
    var enablePerformanceV2: Bool { !checkDisabled(with: "--disable-performance-v2")}
    var enableAppHangTrackingV2: Bool { !checkDisabled(with: "--disable-app-hang-tracking-v2")}
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
}

// MARK: Profiling configuration
extension SentrySDKWrapper {
    func configureProfiling(_ options: Options) {
        if let sampleRate = SentrySDKOverrides.Profiling.sampleRate {
            options.profilesSampleRate = NSNumber(value: sampleRate)
        }
        if let samplerValue = SentrySDKOverrides.Profiling.samplerValue {
            options.profilesSampler = { _ in
                return NSNumber(value: samplerValue)
            }
        }
        options.enableAppLaunchProfiling = SentrySDKOverrides.Profiling.profileAppStarts

        if !SentrySDKOverrides.Profiling.disableUIProfiling {
            options.configureProfiling = {
                $0.lifecycle = SentrySDKOverrides.Profiling.manualLifecycle ? .manual : .trace
                $0.sessionSampleRate = SentrySDKOverrides.Profiling.sessionSampleRate ?? 1
                $0.profileAppStarts = SentrySDKOverrides.Profiling.profileAppStarts
            }
        }
    }
}

// swiftlint:enable file_length function_body_length
