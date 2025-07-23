// swiftlint:disable file_length function_body_length

import Sentry

#if !os(macOS)
import UIKit
#endif // !os(macOS)

public struct SentrySDKWrapper {
    public static let shared = SentrySDKWrapper()

#if !os(macOS) && !os(tvOS) && !os(watchOS)
    public let feedbackButton = {
        let button = UIButton(type: .custom)
        button.setTitle("BYOB Feedback", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        button.accessibilityIdentifier = "io.sentry.feedback.custom-button"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
#endif // !os(macOS) && !os(tvOS)  && !os(watchOS)

    public func startSentry() {
        if SentrySDK.isEnabled {
            print("SentrySDK already enabled, closing it")
            SentrySDK.close()
        }

        if !SentrySDKOverrides.Special.skipSDKInit.boolValue {
            SentrySDK.start(configureOptions: configureSentryOptions(options:))
        }
    }

    func configureSentryOptions(options: Options) {
        options.dsn = dsn
        if let sampleRate = SentrySDKOverrides.Events.sampleRate.floatValue {
            options.sampleRate = NSNumber(value: sampleRate)
        }
        options.beforeSend = {
            guard !SentrySDKOverrides.Events.rejectAll.boolValue else { return nil }
            return $0
        }
        options.beforeSendSpan = {
            guard !SentrySDKOverrides.Other.rejectAllSpans.boolValue else { return nil }
            return $0
        }
        options.beforeCaptureScreenshot = { _ in !SentrySDKOverrides.Other.rejectScreenshots.boolValue }
        options.beforeCaptureViewHierarchy = { _ in !SentrySDKOverrides.Other.rejectViewHierarchy.boolValue }
        options.debug = !SentrySDKOverrides.Special.disableDebugMode.boolValue

#if !os(macOS) && !os(watchOS) && !os(visionOS)
        if #available(iOS 16.0, *), !SentrySDKOverrides.SessionReplay.disableSessionReplay.boolValue {
            options.sessionReplay = SentryReplayOptions(
                sessionSampleRate: SentrySDKOverrides.SessionReplay.sampleRate.floatValue ?? 0,
                onErrorSampleRate: SentrySDKOverrides.SessionReplay.onErrorSampleRate.floatValue ?? 1,
                maskAllText: !SentrySDKOverrides.SessionReplay.disableMaskAllText.boolValue,
                maskAllImages: !SentrySDKOverrides.SessionReplay.disableMaskAllImages.boolValue
            )

            let defaultReplayQuality = SentryReplayOptions.SentryReplayQuality.high
            options.sessionReplay.quality = SentryReplayOptions.SentryReplayQuality(rawValue: (SentrySDKOverrides.SessionReplay.quality.stringValue as? NSString)?.integerValue ?? defaultReplayQuality.rawValue) ?? defaultReplayQuality

            options.sessionReplay.enableViewRendererV2 = !SentrySDKOverrides.SessionReplay.disableViewRendererV2.boolValue

            // Disable the fast view rendering, because we noticed parts (like the tab bar) are not rendered correctly
            options.sessionReplay.enableFastViewRendering = SentrySDKOverrides.SessionReplay.enableFastViewRendering.boolValue
        }

#if !os(tvOS)
        if #available(iOS 15.0, *), !SentrySDKOverrides.Other.disableMetricKit.boolValue {
            options.enableMetricKit = true
            options.enableMetricKitRawPayload = !SentrySDKOverrides.Other.disableMetricKitRawPayloads.boolValue
        }
#endif // !os(tvOS)
#endif // !os(macOS) && !os(watchOS) && !os(visionOS)

        options.tracesSampleRate = 1
        if let sampleRate = SentrySDKOverrides.Tracing.sampleRate.floatValue {
            options.tracesSampleRate = NSNumber(value: sampleRate)
        }
        if let samplerValue = SentrySDKOverrides.Tracing.samplerValue.floatValue {
            options.tracesSampler = { _ in
                return NSNumber(value: samplerValue)
            }
        }

#if !os(tvOS) && !os(watchOS) && !os(visionOS)
        configureProfiling(options)
#endif // !os(tvOS) && !os(watchOS) && !os(visionOS)

        options.enableAutoSessionTracking = !SentrySDKOverrides.Performance.disableSessionTracking.boolValue
        if let sessionTrackingIntervalMillis = SentrySDKOverrides.Performance.sessionTrackingIntervalMillis.stringValue {
            options.sessionTrackingIntervalMillis = UInt((sessionTrackingIntervalMillis as NSString).integerValue)
        }

#if !os(macOS) && !os(watchOS)
        options.add(inAppInclude: "iOS_External")

        // the benchmark test starts and stops a custom transaction using a UIButton, and automatic user interaction tracing stops the transaction that begins with that button press after the idle timeout elapses, stopping the profiler (only one profiler runs regardless of the number of concurrent transactions)
        options.enableUserInteractionTracing = !isBenchmarking && !SentrySDKOverrides.Performance.disableUITracing.boolValue

        options.enablePreWarmedAppStartTracing = !isBenchmarking && !SentrySDKOverrides.Performance.disablePrewarmedAppStartTracing.boolValue
        options.enableUIViewControllerTracing = !SentrySDKOverrides.Performance.disableUIVCTracing.boolValue
        options.attachScreenshot = !SentrySDKOverrides.Other.disableAttachScreenshot.boolValue
        options.attachViewHierarchy = !SentrySDKOverrides.Other.disableAttachViewHierarchy.boolValue
      #if !SDK_V9
        options.enableAppHangTrackingV2 = !SentrySDKOverrides.Performance.disableAppHangTrackingV2.boolValue
      #endif // SDK_V9
#endif // !os(macOS) && !os(watchOS)

        // disable during benchmarks because we run CPU for 15 seconds at full throttle which can trigger ANRs
        options.enableAppHangTracking = !isBenchmarking && !SentrySDKOverrides.Performance.disableANRTracking.boolValue

        // UI tests generate false OOMs
        options.enableWatchdogTerminationTracking = !isUITest && !isBenchmarking && !SentrySDKOverrides.Performance.disableWatchdogTracking.boolValue

        options.enableAutoPerformanceTracing = !isBenchmarking && !SentrySDKOverrides.Performance.disablePerformanceTracing.boolValue
        options.enableTracing = !isBenchmarking && !SentrySDKOverrides.Tracing.disableTracing.boolValue

        options.enableNetworkTracking = !SentrySDKOverrides.Networking.disablePerformanceTracking.boolValue
        options.enableCaptureFailedRequests = !SentrySDKOverrides.Networking.disableFailedRequestTracking.boolValue
        options.enableNetworkBreadcrumbs = !SentrySDKOverrides.Networking.disableBreadcrumbs.boolValue

        options.enableFileIOTracing = !SentrySDKOverrides.Performance.disableFileIOTracing.boolValue
        options.enableAutoBreadcrumbTracking = !SentrySDKOverrides.Other.disableBreadcrumbs.boolValue
        options.enableCoreDataTracing = !SentrySDKOverrides.Performance.disableCoreDataTracing.boolValue
        options.enableSwizzling = !SentrySDKOverrides.Other.disableSwizzling.boolValue
        options.enableCrashHandler = !SentrySDKOverrides.Other.disableCrashHandling.boolValue
        options.enablePersistingTracesWhenCrashing = true
        options.enableTimeToFullDisplayTracing = !SentrySDKOverrides.Performance.disableTimeToFullDisplayTracing.boolValue
        options.enablePerformanceV2 = !SentrySDKOverrides.Performance.disablePerformanceV2.boolValue
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

        options.initialScope = { scope in
            configureInitialScope(scope: scope, options: options)
        }

#if !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
        if #available(iOS 13.0, *) {
            options.configureUserFeedback = configureFeedback(config:)
        }
#endif // !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)

        // Experimental features
        options.experimental.enableFileManagerSwizzling = !SentrySDKOverrides.Other.disableFileManagerSwizzling.boolValue
        options.experimental.enableUnhandledCPPExceptionsV2 = true
    }

    func configureInitialScope(scope: Scope, options: Options) -> Scope {
        if let environmentOverride = SentrySDKOverrides.Other.environment.stringValue {
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

        if let uiTestName = env["--io.sentry.ui-test.test-name"] {
            scope.setTag(value: uiTestName, key: "ui-test-name")
        }

        injectGitInformation(scope: scope)

        let user = User(userId: SentrySDKOverrides.Other.userID.stringValue ?? "1")
        user.email = SentrySDKOverrides.Other.userEmail.stringValue ?? "tony@example.com"
        user.username = username
        user.name = userFullName
        scope.setUser(user)

        if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
            scope.addAttachment(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
        }
        let data = Data("hello".utf8)
        scope.addAttachment(Attachment(data: data, filename: "log.txt"))

        scope.setTag(value: options.sampleRate?.stringValue ?? "0", key: "sample-rate")

        return scope
    }

    var userFullName: String {
        let name = SentrySDKOverrides.Other.userFullName.stringValue ?? NSFullUserName()
        guard !name.isEmpty else {
            return "cocoa developer"
        }
        return name
    }

    var username: String {
        let username = SentrySDKOverrides.Other.username.stringValue ?? NSUserName()
        guard !username.isEmpty else {
            return (self.env["SIMULATOR_HOST_HOME"] as? NSString)?
                .lastPathComponent ?? "cocoadev"
        }
        return username
    }
}

#if !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
// MARK: User feedback configuration
@available(iOS 13.0, *)
extension SentrySDKWrapper {
    var layoutOffset: UIOffset { UIOffset(horizontal: 25, vertical: 75) }

    func configureFeedbackWidget(config: SentryUserFeedbackWidgetConfiguration) {
        config.autoInject = !SentrySDKOverrides.Feedback.disableAutoInject.boolValue

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
        config.showIcon = !SentrySDKOverrides.Feedback.noWidgetIcon.boolValue
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
        config.useShakeGesture = !SentrySDKOverrides.Feedback.noShakeGesture.boolValue
        config.showFormForScreenshots = !SentrySDKOverrides.Feedback.noScreenshots.boolValue
        config.configureWidget = configureFeedbackWidget(config:)
        config.configureForm = configureFeedbackForm(config:)
        config.configureTheme = configureFeedbackTheme(config:)
        configureHooks(config: config)

        if SentrySDKOverrides.Feedback.useCustomFeedbackButton.boolValue {
            config.customButton = feedbackButton
        }
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
#endif // !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)

// MARK: Convenience access to SDK configuration via launch arg / environment variable
extension SentrySDKWrapper {
    public static let defaultDSN = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"

    var args: [String] {
        return ProcessInfo.processInfo.arguments
    }

    var env: [String: String] {
        return ProcessInfo.processInfo.environment
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
    var isUITest: Bool { env["--io.sentry.scope.sdk-environment"] == "ui-tests" }
}

// MARK: Profiling configuration
#if !os(tvOS) && !os(watchOS) && !os(visionOS)
extension SentrySDKWrapper {
    func configureProfiling(_ options: Options) {
      #if !SDK_V9
        if let sampleRate = SentrySDKOverrides.Profiling.sampleRate.floatValue {
            options.profilesSampleRate = NSNumber(value: sampleRate)
        }
        if let samplerValue = SentrySDKOverrides.Profiling.samplerValue.floatValue {
            options.profilesSampler = { _ in
                return NSNumber(value: samplerValue)
            }
        }
        options.enableAppLaunchProfiling = !SentrySDKOverrides.Profiling.disableAppStartProfiling.boolValue
      #endif // !SDK_V9

        if !SentrySDKOverrides.Profiling.disableUIProfiling.boolValue {
            options.configureProfiling = {
                $0.lifecycle = SentrySDKOverrides.Profiling.manualLifecycle.boolValue ? .manual : .trace
                $0.sessionSampleRate = SentrySDKOverrides.Profiling.sessionSampleRate.floatValue ?? 1
                $0.profileAppStarts = !SentrySDKOverrides.Profiling.disableAppStartProfiling.boolValue
            }
        }
    }
}
#endif // !os(tvOS) && !os(watchOS) && !os(visionOS)

// swiftlint:enable file_length function_body_length
