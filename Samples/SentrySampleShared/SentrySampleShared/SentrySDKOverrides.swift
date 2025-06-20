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
        }
    }

    public enum Special: String, SentrySDKOverride {
        case wipeDataOnLaunch = "--io.sentry.wipe-data"
        case disableEverything = "--io.sentry.disable-everything"
        case skipSDKInit = "--skip-sentry-init"
        case disableDebugMode = "--io.sentry.disable-debug-mode"
    }
    case special = "Special"

    public enum Feedback: String, SentrySDKOverride {
        case allDefaults = "--io.sentry.feedback.all-defaults"
        case disableAutoInject = "--io.sentry.feedback.no-auto-inject-widget"
        case noWidgetText = "--io.sentry.feedback.no-widget-text"
        case noWidgetIcon = "--io.sentry.feedback.no-widget-icon"
        case noUserInjection = "--io.sentry.feedback.dont-use-sentry-user"
        case requireEmail = "--io.sentry.feedback.require-email"
        case requireName = "--io.sentry.feedback.require-name"
        case noAnimations = "--io.sentry.feedback.no-animations"
        case injectScreenshot = "--io.sentry.feedback.inject-screenshot"
        case useCustomFeedbackButton = "--io.sentry.feedback.use-custom-feedback-button"
        case noScreenshots = "--io.sentry.feedback.no-screenshots"
        case noShakeGesture = "--io.sentry.feedback.no-shake-gesture"
    }
    case feedback = "Feedback"

    public enum Performance: String, SentrySDKOverride {
        case disableTimeToFullDisplayTracing = "--disable-time-to-full-display-tracing"
        case disablePerformanceV2 = "--disable-performance-v2"
        case disableAppHangTrackingV2 = "--disable-app-hang-tracking-v2"
        case disableSessionTracking = "--disable-automatic-session-tracking"
        case disableFileIOTracing = "--disable-file-io-tracing"
        case disableUIVCTracing = "--disable-uiviewcontroller-tracing"
        case disableNetworkTracing = "--disable-network-tracking"
        case disableCoreDataTracing = "--disable-core-data-tracing"
        case disableANRTracking = "--disable-anr-tracking"
        case disableWatchdogTracking = "--disable-watchdog-tracking"
        case disableUITracing = "--disable-ui-tracing"
        case disablePrewarmedAppStartTracing = "--disable-prewarmed-app-start-tracing"
        case disablePerformanceTracing = "--disable-auto-performance-tracing"
        case sessionTrackingIntervalMillis = "--io.sentry.sessionTrackingIntervalMillis"
    }
    case performance = "Performance"

    public enum SessionReplay: String, SentrySDKOverride {
        case disableSessionReplay = "--disable-session-replay"
        case disableViewRendererV2 = "--io.sentry.session-replay.disableViewRendereV2"
        case enableFastViewRendering = "--io.sentry.session-replay.enableFastViewRendering"
        case sampleRate = "--io.sentry.sessionReplaySampleRate"
        case onErrorSampleRate = "--io.sentry.sessionReplayOnErrorSampleRate"
        case quality = "--io.sentry.sessionReplayQuality"
        case disableMaskAllText = "--io.sentry.session-replay.disable-mask-all-text"
        case disableMaskAllImages = "--io.sentry.session-replay.disable-mask-all-images"
    }
    case sessionReplay = "Session Replay"

    public enum Screenshot: String, SentrySDKOverride {
        case disableViewRendererV2 = "--io.sentry.screenshot.disable-view-renderer-v2"
        case enableFastViewRendering = "--io.sentry.screenshot.enable-fast-view-rendering"
        case disableMaskAllImages = "--io.sentry.screenshot.disable-mask-all-images"
        case disableMaskAllText = "--io.sentry.screenshot.disable-mask-all-text"

        public var boolValue: Bool {
            get {
                switch self {
                default: return getBoolOverride(for: "--io.sentry.disable-everything") || getBoolOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                default: setBoolOverride(for: rawValue, value: newValue)
                }
            }
        }

        public var floatValue: Float? {
            get {
                switch self {
                case .disableViewRendererV2, .enableFastViewRendering, .disableMaskAllImages, .disableMaskAllText: fatalError(
                    "Use boolValue to get the value of this override"
                )
                }
            }
            set(newValue) {
                switch self {
                case .disableViewRendererV2, .enableFastViewRendering, .disableMaskAllImages, .disableMaskAllText: fatalError("Use boolValue to get the value of this override")
                }
            }
        }

        public static var boolValues: [Self] { [.disableViewRendererV2, .enableFastViewRendering, .disableMaskAllText, .disableMaskAllImages] }
        public static var floatValues: [Self] { [] }
    }

    public enum SessionReplay: String, SentrySDKOverride {
        case disable = "--io.sentry.session-replay.disable"
        
        case onErrorSampleRate = "--io.sentry.session-replay.on-error-sample-rate"
        case sessionSampleRate = "--io.sentry.session-replay.session-sample-rate"

        case disableViewRendererV2 = "--io.sentry.session-replay.disable-view-renderer-v2"
        case enableFastViewRendering = "--io.sentry.session-replay.enable-fast-view-rendering"
        
        case disableMaskAllImages = "--io.sentry.session-replay.disable-mask-all-images"
        case disableMaskAllText = "--io.sentry.session-replay.disable-mask-all-text"

        public var boolValue: Bool {
            get {
                switch self {
                case .onErrorSampleRate, .sessionSampleRate: fatalError("Use floatValue to get the value of this override")
                default: return getBoolOverride(for: "--io.sentry.disable-everything") || getBoolOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .onErrorSampleRate, .sessionSampleRate: fatalError("Use floatValue to get the value of this override")
                default: setBoolOverride(for: rawValue, value: newValue)
                }
            }
        }

        public var floatValue: Float? {
            get {
                switch self {
                case .disable, .disableViewRendererV2, .enableFastViewRendering, .disableMaskAllImages, .disableMaskAllText: fatalError(
                    "Use boolValue to get the value of this override")
                case .onErrorSampleRate, .sessionSampleRate: return getFloatValueOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .disable, .disableViewRendererV2, .enableFastViewRendering, .disableMaskAllImages, .disableMaskAllText: fatalError("Use boolValue to get the value of this override")
                case .onErrorSampleRate, .sessionSampleRate: setFloatOverride(for: rawValue, value: newValue)
                }
            }
        }

        public static var boolValues: [Self] {
            [.disableViewRendererV2, .enableFastViewRendering, .disableMaskAllText, .disableMaskAllImages]
        }
        public static var floatValues: [Self] { [.onErrorSampleRate, .sessionSampleRate] }
    }

    public enum Other: String, SentrySDKOverride {
        case disableAttachScreenshot = "--disable-attach-screenshot"
        case disableAttachViewHierarchy = "--disable-attach-view-hierarchy"
        case rejectAllEvents = "--reject-all-events"
        case rejectAllSpans = "--reject-all-spans"
        case rejectScreenshots = "--reject-screenshots-in-before-capture-screenshot"
        case rejectViewHierarchy = "--reject-view-hierarchy-in-before-capture-view-hierarchy"
        case disableMetricKit = "--disable-metrickit-integration"
        case disableMetricKitRawPayloads = "--disable-metrickit-raw-payloads"
        case disableBreadcrumbs = "--disable-automatic-breadcrumbs"
        case disableNetworkBreadcrumbs = "--disable-network-breadcrumbs"
        case disableSwizzling = "--disable-swizzling"
        case disableCrashHandling = "--disable-crash-handler"
        case disableSpotlight = "--disable-spotlight"
        case disableFileManagerSwizzling = "--disable-filemanager-swizzling"
        case username = "--io.sentry.user.username"
        case userFullName = "--io.sentry.user.name"
        case userEmail = "--io.sentry.user.email"
        case userID = "--io.sentry.user.id"
        case environment = "--io.sentry.sdk-environment"

        public var boolValue: Bool {
            get {
                switch self {
                case .userName, .userEmail: fatalError("Use stringValue to get the value of this override")
                default: return getBoolOverride(for: "--io.sentry.disable-everything") || getBoolOverride(for: rawValue)
                }
            }
            set(newValue) {
                setBoolOverride(for: rawValue, value: newValue)
            }
        }

        public var stringValue: String? {
            get {
                switch self {
                case .userName, .userEmail: return getStringValueOverride(for: rawValue)
                default: fatalError("Use boolValue to get the value of this override")
                }
            }
            set(newValue) {
                switch self {
                case .userName, .userEmail: return setStringOverride(for: rawValue, value: newValue)
                default: fatalError("Use boolValue to get the value of this override")
                }
            }
        }

        public static var boolValues: [Other] { [.disableAttachScreenshot, .disableAttachViewHierarchy, .disableMetricKit, .disableBreadcrumbs, .disableNetworkBreadcrumbs, .disableSwizzling, .disableCrashHandling, .disableSpotlight, .disableFileManagerSwizzling] }
        public static var stringVars: [Other] { [.userName, .userEmail] }
    }
    case other = "Other"

    public enum Tracing: String, SentrySDKOverride {
        case sampleRate = "--io.sentry.tracesSampleRate"
        case samplerValue = "--io.sentry.tracesSamplerValue"
        case disableTracing = "--io.sentry.disable-tracing"
    }
    case tracing = "Tracing"

    public enum Profiling: String, SentrySDKOverride {
        case sampleRate = "--io.sentry.profilesSampleRate"
        case samplerValue = "--io.sentry.profilesSamplerValue"
        case disableAppStartProfiling = "--io.sentry.disable-app-start-profiling"
        case manualLifecycle = "--io.sentry.profile-lifecycle-manual"
        case sessionSampleRate = "--io.sentry.profile-session-sample-rate"
        case disableUIProfiling = "--io.sentry.disable-ui-profiling"
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
        case .sampleRate, .samplerValue, .sessionSampleRate: return .float
        case .disableAppStartProfiling, .manualLifecycle, .disableUIProfiling: return .boolean
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

extension SentrySDKOverrides.Other {
    public var overrideType: OverrideType {
        switch self {
        case .disableAttachScreenshot, .disableAttachViewHierarchy, .rejectScreenshots, .rejectViewHierarchy, .disableMetricKit, .disableMetricKitRawPayloads, .disableBreadcrumbs, .disableNetworkBreadcrumbs, .disableSwizzling, .disableCrashHandling, .disableSpotlight, .disableFileManagerSwizzling, .rejectAllSpans, .rejectAllEvents: return .boolean
        case .username, .userFullName, .userEmail, .userID, .environment: return .string
        }
    }
}

extension SentrySDKOverrides.Performance {
    public var overrideType: OverrideType {
        switch self {
        case .disableTimeToFullDisplayTracing, .disablePerformanceV2, .disableAppHangTrackingV2, .disableSessionTracking, .disableFileIOTracing, .disableUIVCTracing, .disableNetworkTracing, .disableCoreDataTracing, .disableANRTracking, .disableWatchdogTracking, .disableUITracing, .disablePrewarmedAppStartTracing, .disablePerformanceTracing: return .boolean
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
        }
    }
}

// MARK: Disable Everything Helper

// These are listed exhaustively, without using default cases, so that when new cases are added to the enums above, the compiler helps remind you to annotate what type it is down here.

extension SentrySDKOverrides.Profiling {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .sampleRate, .samplerValue, .sessionSampleRate, .manualLifecycle: return true
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

extension SentrySDKOverrides.Other {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .rejectScreenshots, .rejectViewHierarchy, .rejectAllSpans, .rejectAllEvents, .username, .userFullName, .userEmail, .userID, .environment: return true
        case .disableAttachScreenshot, .disableAttachViewHierarchy, .disableMetricKit, .disableMetricKitRawPayloads, .disableBreadcrumbs, .disableNetworkBreadcrumbs, .disableSwizzling, .disableCrashHandling, .disableSpotlight, .disableFileManagerSwizzling: return false
        }
    }
}

extension SentrySDKOverrides.Performance {
    public var ignoresDisableEverything: Bool {
        switch self {
        case .disableTimeToFullDisplayTracing, .disablePerformanceV2, .disableAppHangTrackingV2, .disableSessionTracking, .disableFileIOTracing, .disableUIVCTracing, .disableNetworkTracing, .disableCoreDataTracing, .disableANRTracking, .disableWatchdogTracking, .disableUITracing, .disablePrewarmedAppStartTracing, .disablePerformanceTracing: return false
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
        case .wipeDataOnLaunch, .disableEverything, .skipSDKInit, .disableDebugMode: return true
        }
    }
}

// swiftlint:enable file_length
