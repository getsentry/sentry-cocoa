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

/// This enum contains nested enums, to group feature flags by any kind of category you choose, whether it's feature area, or just a kitchen sink of otherwise unclassifiable flags (like Special/Other).
///
/// The parent enum has a case for each child enum type, to help dynamically access them when driving a table view (see
public enum SentrySDKOverrides: String, CaseIterable {
    public static func resetDefaults() {
        for override in SentrySDKOverrides.allCases {
            for flag in override.featureFlags {
                UserDefaults.standard.removeObject(forKey: flag.rawValue)
            }
        }
    }

    public static var schemaPrecedenceForEnvironmentVariables: Bool {
        ProcessInfo.processInfo.arguments.contains("--io.sentry.schema-environment-variable-precedence")
    }

    /// Helps quickly traverse using an NSIndexPath for driving a table view.
    var featureFlags: [any SentrySDKOverride] {
        switch self {
        case .special: return SentrySDKOverrides.Special.allCases
        case .feedback: return SentrySDKOverrides.Feedback.allCases
        case .performance: return SentrySDKOverrides.Performance.allCases
        case .sessionReplay: return SentrySDKOverrides.SessionReplay.allCases
        case .other: return SentrySDKOverrides.Other.allCases
        case .tracing: return SentrySDKOverrides.Tracing.allCases
        case .profiling: return SentrySDKOverrides.Profiling.allCases
        case .networking: return SentrySDKOverrides.Networking.allCases
        }
    }

    public enum Special: String, SentrySDKOverride {
        case wipeDataOnLaunch  = "--io.sentry.wipe-data"
        case disableEverything = "--io.sentry.disable-everything"
        case skipSDKInit       = "--io.sentry.skip-sentry-init"
        case disableDebugMode  = "--io.sentry.disable-debug-mode"
        case dsn               = "--io.sentry.dsn"
    }
    case special = "Special"

    public enum Feedback: String, SentrySDKOverride {
        case allDefaults                = "--io.sentry.feedback.all-defaults"
        case disableAutoInject          = "--io.sentry.feedback.no-auto-inject-widget"
        case noWidgetText               = "--io.sentry.feedback.no-widget-text"
        case noWidgetIcon               = "--io.sentry.feedback.no-widget-icon"
        case noUserInjection            = "--io.sentry.feedback.dont-use-sentry-user"
        case requireEmail               = "--io.sentry.feedback.require-email"
        case requireName                = "--io.sentry.feedback.require-name"
        case noAnimations               = "--io.sentry.feedback.no-animations"
        case injectScreenshot           = "--io.sentry.feedback.inject-screenshot"
        case useCustomFeedbackButton    = "--io.sentry.feedback.use-custom-feedback-button"
        case noScreenshots              = "--io.sentry.feedback.no-screenshots"
        case noShakeGesture             = "--io.sentry.feedback.no-shake-gesture"
    }
    case feedback = "Feedback"

    public enum Performance: String, SentrySDKOverride {
        case disableTimeToFullDisplayTracing    = "--io.sentry.performance.disable-time-to-full-display-tracing"
        case disablePerformanceV2               = "--io.sentry.performance.disable-performance-v2"
        case disableAppHangTrackingV2           = "--io.sentry.performance.disable-app-hang-tracking-v2"
        case disableSessionTracking             = "--io.sentry.performance.disable-automatic-session-tracking"
        case disableFileIOTracing               = "--io.sentry.performance.disable-file-io-tracing"
        case disableUIVCTracing                 = "--io.sentry.performance.disable-uiviewcontroller-tracing"
        case disableCoreDataTracing             = "--io.sentry.performance.disable-core-data-tracing"
        case disableANRTracking                 = "--io.sentry.performance.disable-anr-tracking"
        case disableWatchdogTracking            = "--io.sentry.performance.disable-watchdog-tracking"
        case disableUITracing                   = "--io.sentry.performance.disable-ui-tracing"
        case disablePrewarmedAppStartTracing    = "--io.sentry.performance.disable-prewarmed-app-start-tracing"
        case disablePerformanceTracing          = "--io.sentry.performance.disable-auto-performance-tracing"
        case sessionTrackingIntervalMillis      = "--io.sentry.performance.sessionTrackingIntervalMillis"
    }
    case performance = "Performance"

    public enum SessionReplay: String, SentrySDKOverride {
        case disableSessionReplay      = "--io.sentry.session-replay.disable-session-replay"
        case disableViewRendererV2     = "--io.sentry.session-replay.disableViewRendereV2"
        case enableFastViewRendering   = "--io.sentry.session-replay.enableFastViewRendering"
        case sampleRate                = "--io.sentry.session-replay.sessionReplaySampleRate"
        case onErrorSampleRate         = "--io.sentry.session-replay.sessionReplayOnErrorSampleRate"
        case quality                   = "--io.sentry.session-replay.sessionReplayQuality"
        case disableMaskAllText        = "--io.sentry.session-replay.disable-mask-all-text"
        case disableMaskAllImages      = "--io.sentry.session-replay.disable-mask-all-images"
    }
    case sessionReplay = "Session Replay"

    public enum Networking: String, SentrySDKOverride {
        case disableBreadcrumbs            = "--io.sentry.networking.disable-breadcrumbs"
        case disablePerformanceTracking    = "--io.sentry.networking.disable-tracking"
        case disableFailedRequestTracking  = "--io.sentry.networking.disable-failed-request-tracking"
    }
    case networking = "Networking"

    public enum Other: String, SentrySDKOverride {
        case disableAttachScreenshot        = "--io.sentry.other.disable-attach-screenshot"
        case disableAttachViewHierarchy     = "--io.sentry.other.disable-attach-view-hierarchy"
        case rejectAllEvents                = "--io.sentry.other.reject-all-events"
        case rejectAllSpans                 = "--io.sentry.other.reject-all-spans"
        case rejectScreenshots              = "--io.sentry.other.reject-screenshots-in-before-capture-screenshot"
        case rejectViewHierarchy            = "--io.sentry.other.reject-view-hierarchy-in-before-capture-view-hierarchy"
        case disableMetricKit               = "--io.sentry.other.disable-metrickit-integration"
        case disableMetricKitRawPayloads    = "--io.sentry.other.disable-metrickit-raw-payloads"
        case disableBreadcrumbs             = "--io.sentry.other.disable-automatic-breadcrumbs"
        case disableSwizzling               = "--io.sentry.other.disable-swizzling"
        case disableCrashHandling           = "--io.sentry.other.disable-crash-handler"
        case disableSpotlight               = "--io.sentry.other.disable-spotlight"
        case disableFileManagerSwizzling    = "--io.sentry.other.disable-filemanager-swizzling"
        case base64AttachmentData           = "--io.sentry.other.base64-attachment-data"
        case disableHttpTransport           = "--io.sentry.other.disable-http-transport"
        case username                       = "--io.sentry.scope.user.username"
        case userFullName                   = "--io.sentry.scope.user.name"
        case userEmail                      = "--io.sentry.scope.user.email"
        case userID                         = "--io.sentry.scope.user.id"
        case environment                    = "--io.sentry.scope.sdk-environment"
    }
    case other = "Other"

    public enum Tracing: String, SentrySDKOverride {
        case sampleRate      = "--io.sentry.tracing.tracesSampleRate"
        case samplerValue    = "--io.sentry.tracing.tracesSamplerValue"
        case disableTracing  = "--io.sentry.tracing.disable-tracing"
    }
    case tracing = "Tracing"

    public enum Profiling: String, SentrySDKOverride {
      #if !SDK_V9
        case sampleRate                 = "--io.sentry.profiling.profilesSampleRate"
        case samplerValue               = "--io.sentry.profiling.profilesSamplerValue"
     #endif // !SDK_V9
        case disableAppStartProfiling   = "--io.sentry.profiling.disable-app-start-profiling"
        case manualLifecycle            = "--io.sentry.profiling.profile-lifecycle-manual"
        case sessionSampleRate          = "--io.sentry.profiling.profile-session-sample-rate"
        case disableUIProfiling         = "--io.sentry.profiling.disable-ui-profiling"
        case slowLoadMethod             = "--io.sentry.profiling.slow-load-method"
        case immediateStop              = "--io.sentry.profiling.continuous-profiler-immediate-stop"
    }
    case profiling = "Profiling"
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

extension SentrySDKOverrides.Profiling {
    public var overrideType: OverrideType {
        switch self {
          #if SDK_V9
        case .sessionSampleRate: return .float
          #else
        case .sampleRate, .samplerValue, .sessionSampleRate: return .float
          #endif // !SDK_V9
        case .disableAppStartProfiling, .manualLifecycle, .disableUIProfiling, .slowLoadMethod, .immediateStop: return .boolean
        }
    }
}

extension SentrySDKOverrides.Tracing {
    public var overrideType: OverrideType {
        switch self {
        case .sampleRate, .samplerValue: return .float
        case .disableTracing: return .boolean
        }
    }
}

extension SentrySDKOverrides.Networking {
    public var overrideType: OverrideType {
        switch self {
        case .disableBreadcrumbs, .disablePerformanceTracking, .disableFailedRequestTracking: return .boolean
        }
    }
}

extension SentrySDKOverrides.Other {
    public var overrideType: OverrideType {
        switch self {
        case .disableAttachScreenshot, .disableAttachViewHierarchy, .rejectScreenshots, .rejectViewHierarchy, .disableMetricKit, .disableMetricKitRawPayloads, .disableBreadcrumbs, .disableSwizzling, .disableCrashHandling, .disableSpotlight, .disableFileManagerSwizzling, .rejectAllSpans, .rejectAllEvents, .base64AttachmentData, .disableHttpTransport: return .boolean
        case .username, .userFullName, .userEmail, .userID, .environment: return .string
        }
    }
}

extension SentrySDKOverrides.Performance {
    public var overrideType: OverrideType {
        switch self {
        case .disableTimeToFullDisplayTracing, .disablePerformanceV2, .disableAppHangTrackingV2, .disableSessionTracking, .disableFileIOTracing, .disableUIVCTracing, .disableCoreDataTracing, .disableANRTracking, .disableWatchdogTracking, .disableUITracing, .disablePrewarmedAppStartTracing, .disablePerformanceTracing: return .boolean
        case .sessionTrackingIntervalMillis: return .string
        }
    }
}

extension SentrySDKOverrides.SessionReplay {
    public var overrideType: OverrideType {
        switch self {
        case .disableSessionReplay, .disableViewRendererV2, .enableFastViewRendering, .disableMaskAllText, .disableMaskAllImages: return .boolean
        case .onErrorSampleRate, .sampleRate: return .float
        case .quality: return .string
        }
    }
}

extension SentrySDKOverrides.Feedback {
    public var overrideType: OverrideType {
        switch self {
        case .allDefaults, .disableAutoInject, .noWidgetText, .noWidgetIcon, .noUserInjection, .requireEmail, .requireName, .noAnimations, .injectScreenshot, .useCustomFeedbackButton, .noScreenshots, .noShakeGesture: return .boolean
        }
    }
}

extension SentrySDKOverrides.Special {
    public var overrideType: OverrideType {
        switch self {
        case .wipeDataOnLaunch, .disableEverything, .skipSDKInit, .disableDebugMode: return .boolean
        case .dsn: return .string
        }
    }
}

// MARK: Disable Everything Helper

// These are listed exhaustively, without using default cases, so that when new cases are added to the enums above, the compiler helps remind you to annotate what type it is down here.

extension SentrySDKOverrides.Profiling {
    public var ignoresDisableEverything: Bool {
        switch self {
          #if SDK_V9
        case .sessionSampleRate, .manualLifecycle, .slowLoadMethod, .immediateStop: return true
          #else
        case .sampleRate, .samplerValue, .sessionSampleRate, .manualLifecycle, .slowLoadMethod, .immediateStop: return true
          #endif // SDK_V9
        case .disableAppStartProfiling, .disableUIProfiling: return false
        }
    }
}

extension SentrySDKOverrides.Tracing {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .sampleRate, .samplerValue: return false
        case .disableTracing: return true
        }
    }
}

extension SentrySDKOverrides.Networking {
    public var ignoresDisableEverything: Bool { return false }
}

extension SentrySDKOverrides.Other {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .rejectScreenshots, .rejectViewHierarchy, .rejectAllSpans, .rejectAllEvents, .username, .userFullName, .userEmail, .userID, .environment, .base64AttachmentData: return true
        case .disableAttachScreenshot, .disableAttachViewHierarchy, .disableMetricKit, .disableMetricKitRawPayloads, .disableBreadcrumbs, .disableSwizzling, .disableCrashHandling, .disableSpotlight, .disableFileManagerSwizzling, .disableHttpTransport: return false
        }
    }
}

extension SentrySDKOverrides.Performance {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .disableTimeToFullDisplayTracing, .disablePerformanceV2, .disableAppHangTrackingV2, .disableSessionTracking, .disableFileIOTracing, .disableUIVCTracing, .disableCoreDataTracing, .disableANRTracking, .disableWatchdogTracking, .disableUITracing, .disablePrewarmedAppStartTracing, .disablePerformanceTracing: return false
        case .sessionTrackingIntervalMillis: return true
        }
    }
}

extension SentrySDKOverrides.SessionReplay {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .disableSessionReplay: return false
        case .disableViewRendererV2, .enableFastViewRendering, .disableMaskAllText, .disableMaskAllImages, .onErrorSampleRate, .sampleRate, .quality: return true
        }
    }
}

extension SentrySDKOverrides.Feedback {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .allDefaults, .disableAutoInject, .noWidgetText, .noWidgetIcon, .noUserInjection, .requireEmail, .requireName, .noAnimations, .injectScreenshot, .useCustomFeedbackButton, .noScreenshots, .noShakeGesture: return true
        }
    }
}

extension SentrySDKOverrides.Special {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .wipeDataOnLaunch, .disableEverything, .skipSDKInit, .disableDebugMode, .dsn: return true
        }
    }
}
