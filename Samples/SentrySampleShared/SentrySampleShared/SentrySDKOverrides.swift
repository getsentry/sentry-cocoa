// swiftlint:disable file_length

import Foundation

public enum OverrideType {
    case boolean
    case float
    case string
}

/// This protocol defines the typed value access for a specific feature flag.
public protocol SentrySDKOverride: RawRepresentable, CaseIterable where Self.RawValue == String {
    var overrideType: OverrideType { get }
    var ignoresDisableEverything: Bool { get }

    var boolValue: Bool { get set }
    var floatValue: Float? { get set }
    var stringValue: String? { get set }
}

/// This enum contains nested enums, grouped by the SDK integration or option area they configure.
public enum SentrySDKOverrides: String, CaseIterable {
    public static func resetDefaults() {
        for override in SentrySDKOverrides.allCases {
            for flag in override.featureFlags {
                UserDefaults.standard.removeObject(forKey: flag.rawValue)
            }
        }
    }

    public static var schemaPrecedenceForEnvironmentVariables: Bool {
        ProcessInfo.processInfo.arguments.contains("--io.sentry.special.schema-environment-variable-precedence")
    }

    /// Helps quickly traverse using an NSIndexPath for driving a table view.
    var featureFlags: [any SentrySDKOverride] {
        switch self {
        case .special: return SentrySDKOverrides.Special.allCases
        case .events: return SentrySDKOverrides.Events.allCases
        case .performance: return SentrySDKOverrides.Performance.allCases
        case .appStart: return SentrySDKOverrides.AppStart.allCases
        case .session: return SentrySDKOverrides.Session.allCases
        case .replay: return SentrySDKOverrides.Replay.allCases
        case .screenshot: return SentrySDKOverrides.Screenshot.allCases
        case .viewHierarchy: return SentrySDKOverrides.ViewHierarchy.allCases
        case .feedback: return SentrySDKOverrides.Feedback.allCases
        case .profiling: return SentrySDKOverrides.Profiling.allCases
        case .networkTracking: return SentrySDKOverrides.NetworkTracking.allCases
        case .uiEventTracking: return SentrySDKOverrides.UIEventTracking.allCases
        case .uiViewControllerTracing: return SentrySDKOverrides.UIViewControllerTracing.allCases
        case .fileIO: return SentrySDKOverrides.FileIO.allCases
        case .coreData: return SentrySDKOverrides.CoreData.allCases
        case .appHangs: return SentrySDKOverrides.AppHangs.allCases
        case .watchdogTerminations: return SentrySDKOverrides.WatchdogTerminations.allCases
        case .breadcrumbs: return SentrySDKOverrides.Breadcrumbs.allCases
        case .crash: return SentrySDKOverrides.Crash.allCases
        case .metricKit: return SentrySDKOverrides.MetricKit.allCases
        case .metrics: return SentrySDKOverrides.Metrics.allCases
        case .logs: return SentrySDKOverrides.Logs.allCases
        case .spotlight: return SentrySDKOverrides.Spotlight.allCases
        case .swizzling: return SentrySDKOverrides.Swizzling.allCases
        case .transport: return SentrySDKOverrides.Transport.allCases
        case .attachments: return SentrySDKOverrides.Attachments.allCases
        case .spans: return SentrySDKOverrides.Spans.allCases
        case .scope: return SentrySDKOverrides.Scope.allCases
        }
    }

    public enum Special: String, SentrySDKOverride {
        case wipeDataOnLaunch  = "--io.sentry.special.wipe-data"
        case disableEverything = "--io.sentry.special.disable-everything"
        case skipSDKInit       = "--io.sentry.special.skip-sentry-init"
        case disableDebugMode  = "--io.sentry.special.disable-debug-mode"
        case dsn               = "--io.sentry.special.dsn"
    }
    case special = "Special"

    public enum Events: String, SentrySDKOverride {
        case sampleRate       = "--io.sentry.events.sample-rate"
        case rejectAll        = "--io.sentry.events.reject-all"
        case attachAllThreads = "--io.sentry.events.attach-all-threads"
    }
    case events = "Events"

    public enum Performance: String, SentrySDKOverride {
        case sampleRate                       = "--io.sentry.performance.traces-sample-rate"
        case samplerValue                     = "--io.sentry.performance.traces-sampler-value"
        case disableTracing                   = "--io.sentry.performance.disable-tracing"
        case disableAutoTracing               = "--io.sentry.performance.disable-auto-tracing"
        case disableTimeToFullDisplayTracing  = "--io.sentry.performance.disable-time-to-full-display-tracing"
    }
    case performance = "Performance"

    public enum AppStart: String, SentrySDKOverride {
        case disablePrewarmedTracing = "--io.sentry.app-start.disable-prewarmed-tracing"
        case enableStandaloneTracing = "--io.sentry.app-start.enable-standalone-tracing"
        case extendLaunchDelay       = "--io.sentry.app-start.extend-launch-delay"
    }
    case appStart = "App Start"

    public enum Session: String, SentrySDKOverride {
        case disableTracking        = "--io.sentry.session.disable-tracking"
        case trackingIntervalMillis = "--io.sentry.session.tracking-interval-millis"
    }
    case session = "Session"

    public enum Replay: String, SentrySDKOverride {
        case disable = "--io.sentry.replay.disable"

        case onErrorSampleRate = "--io.sentry.replay.on-error-sample-rate"
        case sessionSampleRate = "--io.sentry.replay.session-sample-rate"
        case quality = "--io.sentry.replay.quality"

        case disableViewRendererV2 = "--io.sentry.replay.disable-view-renderer-v2"
        case enableFastViewRendering = "--io.sentry.replay.enable-fast-view-rendering"

        case disableMaskAllImages = "--io.sentry.replay.disable-mask-all-images"
        case disableMaskAllText = "--io.sentry.replay.disable-mask-all-text"
        case disableNetworkDetailsCapturing = "--io.sentry.replay.disable-network-details-capturing"
    }
    case replay = "Replay"

    public enum Screenshot: String, SentrySDKOverride {
        case disableAttachment = "--io.sentry.screenshot.disable-attachment"
        case rejectInBeforeCapture = "--io.sentry.screenshot.reject-in-before-capture"
        case disableViewRendererV2 = "--io.sentry.screenshot.disable-view-renderer-v2"
        case enableFastViewRendering = "--io.sentry.screenshot.enable-fast-view-rendering"
        case disableMaskAllImages = "--io.sentry.screenshot.disable-mask-all-images"
        case disableMaskAllText = "--io.sentry.screenshot.disable-mask-all-text"
    }
    case screenshot = "Screenshot"

    public enum ViewHierarchy: String, SentrySDKOverride {
        case disableAttachment = "--io.sentry.view-hierarchy.disable-attachment"
        case rejectInBeforeCapture = "--io.sentry.view-hierarchy.reject-in-before-capture"
    }
    case viewHierarchy = "View Hierarchy"

    public enum Feedback: String, SentrySDKOverride {
        case allDefaults             = "--io.sentry.feedback.all-defaults"
        case disableAutoInject       = "--io.sentry.feedback.no-auto-inject-widget"
        case noWidgetText            = "--io.sentry.feedback.no-widget-text"
        case noWidgetIcon            = "--io.sentry.feedback.no-widget-icon"
        case noUserInjection         = "--io.sentry.feedback.dont-use-sentry-user"
        case requireEmail            = "--io.sentry.feedback.require-email"
        case requireName             = "--io.sentry.feedback.require-name"
        case noAnimations            = "--io.sentry.feedback.no-animations"
        case injectScreenshot        = "--io.sentry.feedback.inject-screenshot"
        case useCustomFeedbackButton = "--io.sentry.feedback.use-custom-feedback-button"
        case noScreenshots           = "--io.sentry.feedback.no-screenshots"
        case noShakeGesture          = "--io.sentry.feedback.no-shake-gesture"
    }
    case feedback = "User Feedback"

    public enum Profiling: String, SentrySDKOverride {
        case disableAppStartProfiling = "--io.sentry.profiling.disable-app-start-profiling"
        case manualLifecycle          = "--io.sentry.profiling.profile-lifecycle-manual"
        case sessionSampleRate        = "--io.sentry.profiling.profile-session-sample-rate"
        case disableUIProfiling       = "--io.sentry.profiling.disable-ui-profiling"
        case slowLoadMethod           = "--io.sentry.profiling.slow-load-method"
        case immediateStop            = "--io.sentry.profiling.continuous-profiler-immediate-stop"
    }
    case profiling = "Profiling"

    public enum NetworkTracking: String, SentrySDKOverride {
        case disableBreadcrumbs           = "--io.sentry.network.disable-breadcrumbs"
        case disablePerformanceTracking   = "--io.sentry.network.disable-tracking"
        case disableFailedRequestTracking = "--io.sentry.network.disable-failed-request-tracking"
    }
    case networkTracking = "Network Tracking"

    public enum UIEventTracking: String, SentrySDKOverride {
        case disableTracing = "--io.sentry.ui-events.disable-tracing"
    }
    case uiEventTracking = "UI Event Tracking"

    public enum UIViewControllerTracing: String, SentrySDKOverride {
        case disable = "--io.sentry.uiviewcontroller-tracing.disable"
    }
    case uiViewControllerTracing = "UIViewController Tracing"

    public enum FileIO: String, SentrySDKOverride {
        case disableTracing = "--io.sentry.file-io.disable-tracing"
        case disableFileManagerSwizzling = "--io.sentry.file-io.disable-file-manager-swizzling"
    }
    case fileIO = "File IO"

    public enum CoreData: String, SentrySDKOverride {
        case disableTracing = "--io.sentry.core-data.disable-tracing"
    }
    case coreData = "Core Data"

    public enum AppHangs: String, SentrySDKOverride {
        case disableTracking = "--io.sentry.app-hangs.disable-tracking"
    }
    case appHangs = "App Hangs"

    public enum WatchdogTerminations: String, SentrySDKOverride {
        case disableTracking = "--io.sentry.watchdog-terminations.disable-tracking"
        case disableV2       = "--io.sentry.watchdog-terminations.disable-v2"
    }
    case watchdogTerminations = "Watchdog Terminations"

    public enum Breadcrumbs: String, SentrySDKOverride {
        case disableAutomatic = "--io.sentry.breadcrumbs.disable-automatic"
    }
    case breadcrumbs = "Breadcrumbs"

    public enum Crash: String, SentrySDKOverride {
        case disableHandler = "--io.sentry.crash.disable-handler"
        case disablePersistingTracesWhenCrashing = "--io.sentry.crash.disable-persisting-traces"
        case disableUnhandledCPPExceptionsV2     = "--io.sentry.crash.disable-unhandled-cpp-exceptions-v2"
        case disableUncaughtNSExceptionReporting = "--io.sentry.crash.disable-uncaught-ns-exception-reporting"
    }
    case crash = "Crash"

    public enum MetricKit: String, SentrySDKOverride {
        case disable = "--io.sentry.metric-kit.disable"
        case disableRawPayloads = "--io.sentry.metric-kit.disable-raw-payloads"
    }
    case metricKit = "MetricKit"

    public enum Metrics: String, SentrySDKOverride {
        case enable = "--io.sentry.metrics.enable"
    }
    case metrics = "Metrics"

    public enum Logs: String, SentrySDKOverride {
        case disable = "--io.sentry.logs.disable"
    }
    case logs = "Logs"

    public enum Spotlight: String, SentrySDKOverride {
        case disable = "--io.sentry.spotlight.disable"
        case enable = "--io.sentry.spotlight.enable"
    }
    case spotlight = "Spotlight"

    public enum Swizzling: String, SentrySDKOverride {
        case disable = "--io.sentry.swizzling.disable"
    }
    case swizzling = "Swizzling"

    public enum Transport: String, SentrySDKOverride {
        case disableHttpTransport = "--io.sentry.transport.disable-http"
    }
    case transport = "Transport"

    public enum Attachments: String, SentrySDKOverride {
        case base64Data = "--io.sentry.attachments.base64-data"
    }
    case attachments = "Attachments"

    public enum Spans: String, SentrySDKOverride {
        case rejectAll = "--io.sentry.spans.reject-all"
    }
    case spans = "Spans"

    public enum Scope: String, SentrySDKOverride {
        case username     = "--io.sentry.scope.user.username"
        case userFullName = "--io.sentry.scope.user.name"
        case userEmail    = "--io.sentry.scope.user.email"
        case userID       = "--io.sentry.scope.user.id"
        case environment  = "--io.sentry.scope.sdk-environment"
    }
    case scope = "Scope"
}

// MARK: Public flag/variable value access

public extension SentrySDKOverride {
    var boolValue: Bool {
        get {
            guard overrideType == .boolean else { fatalError("Unsupported bool override: \(self.rawValue)") }

            if !ignoresDisableEverything {
                return Self.getBoolOverride(for: SentrySDKOverrides.Special.disableEverything.rawValue) || Self.getBoolOverride(for: rawValue)
            }

            return Self.getBoolOverride(for: rawValue)
        }
        set(newValue) {
            guard overrideType == .boolean else { fatalError("Unsupported bool override: \(self.rawValue)") }
            Self.setBoolOverride(for: rawValue, value: newValue)
        }
    }

    var floatValue: Float? {
        get {
            guard overrideType == .float else { fatalError("Unsupported float override: \(self.rawValue)") }
            return Self.getFloatValueOverride(for: rawValue)
        }
        set(newValue) {
            guard overrideType == .float else { fatalError("Unsupported float override: \(self.rawValue)") }
            Self.setFloatOverride(for: rawValue, value: newValue)
        }
    }

    var stringValue: String? {
        get {
            guard overrideType == .string else { fatalError("Unsupported string override: \(self.rawValue)") }
            return Self.getStringValueOverride(for: rawValue)
        }
        set(newValue) {
            guard overrideType == .string else { fatalError("Unsupported string override: \(self.rawValue)") }
            Self.setStringOverride(for: rawValue, value: newValue)
        }
    }
}

// MARK: Private flag/variable value access helpers

private extension SentrySDKOverride {
    static func getBoolOverride(for key: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(key) || UserDefaults.standard.bool(forKey: key)
    }

    static func setBoolOverride(for key: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func setFloatOverride(for key: String, value: Float?) {
        guard let value = value else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

        setStringOverride(for: key, value: String(format: "%f", value))
    }

    static func setStringOverride(for key: String, value: String?) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func getFloatValueOverride(for key: String) -> Float? {
        (getStringValueOverride(for: key) as? NSString)?.floatValue
    }

    static func getStringValueOverride(for key: String) -> String? {
        var schemaEnvironmentVariable: String?
        if let value = ProcessInfo.processInfo.environment[key] {
            schemaEnvironmentVariable = value
        }

        let defaultsValue = UserDefaults.standard.string(forKey: key)

        if SentrySDKOverrides.schemaPrecedenceForEnvironmentVariables {
            return schemaEnvironmentVariable ?? defaultsValue
        } else {
            return defaultsValue ?? schemaEnvironmentVariable
        }
    }
}

// MARK: Feature flag types

// These are listed exhaustively, without using default cases, so that when new cases are added to the enums above, the compiler helps remind you to annotate what type it is down here.

extension SentrySDKOverrides.Special {
    public var overrideType: OverrideType {
        switch self {
        case .wipeDataOnLaunch, .disableEverything, .skipSDKInit, .disableDebugMode: return .boolean
        case .dsn: return .string
        }
    }
}

extension SentrySDKOverrides.Events {
    public var overrideType: OverrideType {
        switch self {
        case .rejectAll, .attachAllThreads: return .boolean
        case .sampleRate: return .float
        }
    }
}

extension SentrySDKOverrides.Performance {
    public var overrideType: OverrideType {
        switch self {
        case .disableTracing, .disableAutoTracing, .disableTimeToFullDisplayTracing: return .boolean
        case .sampleRate, .samplerValue: return .float
        }
    }
}

extension SentrySDKOverrides.AppStart {
    public var overrideType: OverrideType {
        switch self {
        case .disablePrewarmedTracing, .enableStandaloneTracing: return .boolean
        case .extendLaunchDelay: return .float
        }
    }
}

extension SentrySDKOverrides.Session {
    public var overrideType: OverrideType {
        switch self {
        case .disableTracking: return .boolean
        case .trackingIntervalMillis: return .string
        }
    }
}

extension SentrySDKOverrides.Replay {
    public var overrideType: OverrideType {
        switch self {
        case .disable, .disableViewRendererV2, .enableFastViewRendering, .disableMaskAllText,
             .disableMaskAllImages, .disableNetworkDetailsCapturing:
            return .boolean
        case .onErrorSampleRate, .sessionSampleRate: return .float
        case .quality: return .string
        }
    }
}

extension SentrySDKOverrides.Screenshot {
    public var overrideType: OverrideType {
        switch self {
        case .disableAttachment, .rejectInBeforeCapture, .disableViewRendererV2,
             .enableFastViewRendering, .disableMaskAllText, .disableMaskAllImages:
            return .boolean
        }
    }
}

extension SentrySDKOverrides.ViewHierarchy {
    public var overrideType: OverrideType {
        switch self {
        case .disableAttachment, .rejectInBeforeCapture: return .boolean
        }
    }
}

extension SentrySDKOverrides.Feedback {
    public var overrideType: OverrideType {
        switch self {
        case .allDefaults, .disableAutoInject, .noWidgetText, .noWidgetIcon, .noUserInjection,
             .requireEmail, .requireName, .noAnimations, .injectScreenshot,
             .useCustomFeedbackButton, .noScreenshots, .noShakeGesture:
            return .boolean
        }
    }
}

extension SentrySDKOverrides.Profiling {
    public var overrideType: OverrideType {
        switch self {
        case .sessionSampleRate: return .float
        case .disableAppStartProfiling, .manualLifecycle, .disableUIProfiling, .slowLoadMethod,
             .immediateStop:
            return .boolean
        }
    }
}

extension SentrySDKOverrides.NetworkTracking {
    public var overrideType: OverrideType {
        switch self {
        case .disableBreadcrumbs, .disablePerformanceTracking, .disableFailedRequestTracking:
            return .boolean
        }
    }
}

extension SentrySDKOverrides.UIEventTracking {
    public var overrideType: OverrideType {
        switch self {
        case .disableTracing: return .boolean
        }
    }
}

extension SentrySDKOverrides.UIViewControllerTracing {
    public var overrideType: OverrideType {
        switch self {
        case .disable: return .boolean
        }
    }
}

extension SentrySDKOverrides.FileIO {
    public var overrideType: OverrideType {
        switch self {
        case .disableTracing, .disableFileManagerSwizzling: return .boolean
        }
    }
}

extension SentrySDKOverrides.CoreData {
    public var overrideType: OverrideType {
        switch self {
        case .disableTracing: return .boolean
        }
    }
}

extension SentrySDKOverrides.AppHangs {
    public var overrideType: OverrideType {
        switch self {
        case .disableTracking: return .boolean
        }
    }
}

extension SentrySDKOverrides.WatchdogTerminations {
    public var overrideType: OverrideType {
        switch self {
        case .disableTracking, .disableV2: return .boolean
        }
    }
}

extension SentrySDKOverrides.Breadcrumbs {
    public var overrideType: OverrideType {
        switch self {
        case .disableAutomatic: return .boolean
        }
    }
}

extension SentrySDKOverrides.Crash {
    public var overrideType: OverrideType {
        switch self {
        case .disableHandler, .disablePersistingTracesWhenCrashing,
             .disableUnhandledCPPExceptionsV2, .disableUncaughtNSExceptionReporting:
            return .boolean
        }
    }
}

extension SentrySDKOverrides.MetricKit {
    public var overrideType: OverrideType {
        switch self {
        case .disable, .disableRawPayloads: return .boolean
        }
    }
}

extension SentrySDKOverrides.Metrics {
    public var overrideType: OverrideType {
        switch self {
        case .enable: return .boolean
        }
    }
}

extension SentrySDKOverrides.Logs {
    public var overrideType: OverrideType {
        switch self {
        case .disable: return .boolean
        }
    }
}

extension SentrySDKOverrides.Spotlight {
    public var overrideType: OverrideType {
        switch self {
        case .disable, .enable: return .boolean
        }
    }
}

extension SentrySDKOverrides.Swizzling {
    public var overrideType: OverrideType {
        switch self {
        case .disable: return .boolean
        }
    }
}

extension SentrySDKOverrides.Transport {
    public var overrideType: OverrideType {
        switch self {
        case .disableHttpTransport: return .boolean
        }
    }
}

extension SentrySDKOverrides.Attachments {
    public var overrideType: OverrideType {
        switch self {
        case .base64Data: return .boolean
        }
    }
}

extension SentrySDKOverrides.Spans {
    public var overrideType: OverrideType {
        switch self {
        case .rejectAll: return .boolean
        }
    }
}

extension SentrySDKOverrides.Scope {
    public var overrideType: OverrideType {
        switch self {
        case .username, .userFullName, .userEmail, .userID, .environment: return .string
        }
    }
}

// MARK: Disable Everything Helper

// These are listed exhaustively, without using default cases, so that when new cases are added to the enums above, the compiler helps remind you to annotate what type it is down here.

extension SentrySDKOverrides.Special {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .wipeDataOnLaunch, .disableEverything, .skipSDKInit, .disableDebugMode, .dsn:
            return true
        }
    }
}

extension SentrySDKOverrides.Events {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .rejectAll, .sampleRate: return false
        case .attachAllThreads: return true
        }
    }
}

extension SentrySDKOverrides.Performance {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .sampleRate, .samplerValue, .disableTracing: return true
        case .disableAutoTracing, .disableTimeToFullDisplayTracing: return false
        }
    }
}

extension SentrySDKOverrides.AppStart {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .disablePrewarmedTracing: return false
        case .enableStandaloneTracing, .extendLaunchDelay: return true
        }
    }
}

extension SentrySDKOverrides.Session {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .disableTracking: return false
        case .trackingIntervalMillis: return true
        }
    }
}

extension SentrySDKOverrides.Replay {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .disable: return false
        case .disableViewRendererV2, .enableFastViewRendering, .disableMaskAllText,
             .disableMaskAllImages, .onErrorSampleRate, .sessionSampleRate, .quality,
             .disableNetworkDetailsCapturing:
            return true
        }
    }
}

extension SentrySDKOverrides.Screenshot {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .disableAttachment, .disableViewRendererV2, .disableMaskAllText,
             .disableMaskAllImages:
            return false
        case .rejectInBeforeCapture, .enableFastViewRendering: return true
        }
    }
}

extension SentrySDKOverrides.ViewHierarchy {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .disableAttachment: return false
        case .rejectInBeforeCapture: return true
        }
    }
}

extension SentrySDKOverrides.Feedback {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .allDefaults, .disableAutoInject, .noWidgetText, .noWidgetIcon, .noUserInjection,
             .requireEmail, .requireName, .noAnimations, .injectScreenshot,
             .useCustomFeedbackButton, .noScreenshots, .noShakeGesture:
            return true
        }
    }
}

extension SentrySDKOverrides.Profiling {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .sessionSampleRate, .manualLifecycle, .slowLoadMethod, .immediateStop:
            return true
        case .disableAppStartProfiling, .disableUIProfiling: return false
        }
    }
}

extension SentrySDKOverrides.NetworkTracking {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.UIEventTracking {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.UIViewControllerTracing {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.FileIO {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.CoreData {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.AppHangs {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.WatchdogTerminations {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.Breadcrumbs {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.Crash {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.MetricKit {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.Metrics {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .enable: return true
        }
    }
}

extension SentrySDKOverrides.Logs {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.Spotlight {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .disable: return false
        case .enable: return true
        }
    }
}

extension SentrySDKOverrides.Swizzling {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.Transport {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.Attachments {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .base64Data: return true
        }
    }
}

extension SentrySDKOverrides.Spans {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .rejectAll: return true
        }
    }
}

extension SentrySDKOverrides.Scope {
    public var ignoresDisableEverything: Bool { return true }
}
// swiftlint:enable file_length
