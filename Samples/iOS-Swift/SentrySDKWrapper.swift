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
        
        if #available(iOS 16.0, *), !SentrySDKOverrides.Other.disableSessionReplay.boolValue {
            options.sessionReplay = SentryReplayOptions(
                sessionSampleRate: 0,
                onErrorSampleRate: 1,
                maskAllText: true,
                maskAllImages: true
            )
            options.sessionReplay.quality = .high
        }
        
        if #available(iOS 15.0, *), !SentrySDKOverrides.Other.disableMetricKit.boolValue {
            options.enableMetricKit = true
            options.enableMetricKitRawPayload = true
        }

        options.tracesSampleRate = 1
        if let sampleRate = SentrySDKOverrides.Tracing.sampleRate.floatValue {
            options.tracesSampleRate = NSNumber(value: sampleRate)
        }
        if let samplerValue = SentrySDKOverrides.Tracing.samplerValue.floatValue {
            options.tracesSampler = { _ in
                return NSNumber(value: samplerValue)
            }
        }

        configureProfiling(options)

        options.enableAutoSessionTracking = !SentrySDKOverrides.Performance.disableSessionTracking.boolValue
        if let sessionTrackingIntervalMillis = env["--io.sentry.sessionTrackingIntervalMillis"] {
            options.sessionTrackingIntervalMillis = UInt((sessionTrackingIntervalMillis as NSString).integerValue)
        }

        options.add(inAppInclude: "iOS_External")

        // the benchmark test starts and stops a custom transaction using a UIButton, and automatic user interaction tracing stops the transaction that begins with that button press after the idle timeout elapses, stopping the profiler (only one profiler runs regardless of the number of concurrent transactions)
        options.enableUserInteractionTracing = !isBenchmarking && !SentrySDKOverrides.Performance.disableUITracing.boolValue

        // disable during benchmarks because we run CPU for 15 seconds at full throttle which can trigger ANRs
        options.enableAppHangTracking = !isBenchmarking && !SentrySDKOverrides.Performance.disableANRTracking.boolValue

        // UI tests generate false OOMs
        options.enableWatchdogTerminationTracking = !isUITest && !isBenchmarking && !SentrySDKOverrides.Performance.disableWatchdogTracking.boolValue

        options.enableAutoPerformanceTracing = !isBenchmarking && !SentrySDKOverrides.Performance.disablePerformanceTracing.boolValue
        options.enablePreWarmedAppStartTracing = !isBenchmarking && !SentrySDKOverrides.Performance.disablePrewarmedAppStartTracing.boolValue
        options.enableTracing = !isBenchmarking && !SentrySDKOverrides.Tracing.disableTracing.boolValue

        options.enableFileIOTracing = !SentrySDKOverrides.Performance.disableFileIOTracing.boolValue
        options.enableAutoBreadcrumbTracking = !SentrySDKOverrides.Other.disableBreadcrumbs.boolValue
        options.enableUIViewControllerTracing = !SentrySDKOverrides.Performance.disableUIVCTracing.boolValue
        options.enableNetworkTracking = !SentrySDKOverrides.Performance.disableNetworkTracing.boolValue
        options.enableCoreDataTracing = !SentrySDKOverrides.Performance.disableCoreDataTracing.boolValue
        options.enableNetworkBreadcrumbs = !SentrySDKOverrides.Other.disableNetworkBreadcrumbs.boolValue
        options.enableSwizzling = !SentrySDKOverrides.Other.disableSwizzling.boolValue
        options.enableCrashHandler = !SentrySDKOverrides.Other.disableCrashHandling.boolValue
        options.enablePersistingTracesWhenCrashing = true
        options.attachScreenshot = !SentrySDKOverrides.Other.disableAttachScreenshot.boolValue
        options.attachViewHierarchy = !SentrySDKOverrides.Other.disableAttachViewHierarchy.boolValue
        options.enableTimeToFullDisplayTracing = !SentrySDKOverrides.Performance.disableTimeToFullDisplayTracing.boolValue
        options.enablePerformanceV2 = !SentrySDKOverrides.Performance.disablePerformanceV2.boolValue
        options.enableAppHangTrackingV2 = !SentrySDKOverrides.Performance.disableAppHangTrackingV2.boolValue
        options.failedRequestStatusCodes = [ HttpStatusCodeRange(min: 400, max: 599) ]

    #if targetEnvironment(simulator)
        options.enableSpotlight = !SentrySDKOverrides.Other.disableSpotlight.boolValue
    #else
        options.enableSpotlight = false
    #endif // targetEnvironment(simulator)

        options.beforeBreadcrumb = { breadcrumb in
            //Raising notifications when a new breadcrumb is created in order to use this information
            //to validate whether proper breadcrumb are being created in the right places.
            NotificationCenter.default.post(name: .init("io.sentry.newbreadcrumb"), object: breadcrumb)
            return breadcrumb
        }
        
        options.initialScope = configureInitialScope(scope:)
        options.configureUserFeedback = configureFeedback(config:)

        // Experimental features
        options.experimental.enableFileManagerSwizzling = !SentrySDKOverrides.Other.disableFileManagerSwizzling.boolValue
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
        guard !SentrySDKOverrides.Feedback.disableAutoInject.boolValue else {
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
        
        if SentrySDKOverrides.Feedback.noWidgetText.boolValue {
            config.labelText = nil
        }
        if SentrySDKOverrides.Feedback.noWidgetIcon.boolValue {
            config.showIcon = false
        }
    }
    
    func configureFeedbackForm(config: SentryUserFeedbackFormConfiguration) {
        config.useSentryUser = !SentrySDKOverrides.Feedback.noUserInjection.boolValue
        config.formTitle = "Jank Report"
        config.isEmailRequired = SentrySDKOverrides.Feedback.requireEmail.boolValue
        config.isNameRequired = SentrySDKOverrides.Feedback.requireName.boolValue
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
        
        config.animations = !SentrySDKOverrides.Feedback.noAnimations.boolValue
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
}

// MARK: Profiling configuration
extension SentrySDKWrapper {
    func configureProfiling(_ options: Options) {
        if let sampleRate = SentrySDKOverrides.Profiling.sampleRate.floatValue {
            options.profilesSampleRate = NSNumber(value: sampleRate)
        }
        if let samplerValue = SentrySDKOverrides.Profiling.samplerValue.floatValue {
            options.profilesSampler = { _ in
                return NSNumber(value: samplerValue)
            }
        }
        options.enableAppLaunchProfiling = !SentrySDKOverrides.Profiling.disableAppStartProfiling.boolValue

        if !SentrySDKOverrides.Profiling.disableUIProfiling.boolValue {
            options.configureProfiling = {
                $0.lifecycle = SentrySDKOverrides.Profiling.manualLifecycle.boolValue ? .manual : .trace
                $0.sessionSampleRate = SentrySDKOverrides.Profiling.sessionSampleRate.floatValue ?? 1
                $0.profileAppStarts = !SentrySDKOverrides.Profiling.disableAppStartProfiling.boolValue
            }
        }
    }
}

// swiftlint:enable file_length function_body_length
