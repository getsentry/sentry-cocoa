import Foundation

public protocol SentrySDKOverride: RawRepresentable, CaseIterable {
    var boolValue: Bool { get set }
    var floatValue: Float? { get set }
    var stringValue: String? { get set }
}

extension SentrySDKOverride {
    public var boolValue: Bool { get { false } set { } }
    public var floatValue: Float? { get { nil } set { } }
    public var stringValue: String? { get { nil } set { } }
}

public enum SentrySDKOverrides: String, CaseIterable {
    private static let defaults = UserDefaults.standard

    public static var schemaPrecedenceForEnvironmentVariables: Bool {
        ProcessInfo.processInfo.arguments.contains("--io.sentry.schema-environment-variable-precedence")
    }

    public static func resetDefaults() {
        let allKeys = Tracing.allCases.map(\.rawValue)
            + Profiling.allCases.map(\.rawValue)
            + Performance.allCases.map(\.rawValue)
            + Other.allCases.map(\.rawValue)
            + Feedback.allCases.map(\.rawValue)
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }
    }

    public enum Special: String, SentrySDKOverride {
        case wipeDataOnLaunch = "--io.sentry.wipe-data"
        case disableEverything = "--io.sentry.disable-everything"
        case skipSDKInit = "--skip-sentry-init"

        public var boolValue: Bool {
            get {
                return getBoolOverride(for: rawValue)
            }
            set(newValue) {
                setBoolOverride(for: rawValue, value: newValue)
            }
        }
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

        public var boolValue: Bool {
            get {
                return getBoolOverride(for: rawValue)
            }
            set(newValue) {
                setBoolOverride(for: rawValue, value: newValue)
            }
        }
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

        public var boolValue: Bool {
            get {
                switch self {
                case .sessionTrackingIntervalMillis: fatalError("This override doesn't correspond to a boolean value.")
                default: return getBoolOverride(for: "--io.sentry.disable-everything") || getBoolOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .sessionTrackingIntervalMillis: fatalError("This override doesn't correspond to a boolean value.")
                default: setBoolOverride(for: rawValue, value: newValue)
                }
            }
        }

        public var stringValue: String? {
            get {
                switch self {
                case .sessionTrackingIntervalMillis: return getStringValueOverride(for: rawValue)
                default: fatalError("This override doesn't correspond to a string value.")
                }
            }
            set(newValue) {
                switch self {
                case .sessionTrackingIntervalMillis: setStringOverride(for: rawValue, value: newValue)
                default: fatalError("This override doesn't correspond to a string value.")
                }
            }
        }
    }
    case performance = "Performance"

    public enum SessionReplay: String, SentrySDKOverride {
        case disableSessionReplay = "--disable-session-replay"
        case disableViewRendererV2 = "--io.sentry.session-replay.disableViewRendereV2"
        case enableFastViewRendering = "--io.sentry.session-replay.enableFastViewRendering"
        case sessionReplaySampleRate = "--io.sentry.sessionReplaySampleRate"
        case sessionReplayOnErrorSampleRate = "--io.sentry.sessionReplayOnErrorSampleRate"
        case sessionReplayQuality = "--io.sentry.sessionReplayQuality"
        case disableMaskAllText = "--io.sentry.session-replay.disable-mask-all-text"
        case disableMaskAllImages = "--io.sentry.session-replay.disable-mask-all-images"

        public var booleanValue: Bool {
            get {
                switch self {
                case .sessionReplaySampleRate, .sessionReplayOnErrorSampleRate, .sessionReplayQuality: fatalError("This override doesn't correspond to a boolean value.")
                default: return getBoolOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .sessionReplaySampleRate, .sessionReplayOnErrorSampleRate, .sessionReplayQuality: fatalError("This override doesn't correspond to a boolean value.")
                default: setBoolOverride(for: rawValue, value: newValue)
                }
            }
        }

        public var floatValue: Float? {
            get {
                switch self {
                case .sessionReplaySampleRate, .sessionReplayOnErrorSampleRate: return getFloatValueOverride(for: rawValue)
                default: fatalError("This override doesn't correspond to a float value.")
                }
            }
            set(newValue) {
                switch self {
                case .sessionReplaySampleRate, .sessionReplayOnErrorSampleRate: setFloatOverride(for: rawValue, value: newValue)
                default: fatalError("This override doesn't correspond to a float value.")
                }
            }
        }

        public var stringValue: String? {
            get {
                switch self {
                case .sessionReplayQuality: return getStringValueOverride(for: rawValue)
                default: fatalError("This override doesn't correspond to a string value.")
                }
            }
            set(newValue) {
                switch self {
                case .sessionReplayQuality: setStringOverride(for: rawValue, value: newValue)
                default: fatalError("This override doesn't correspond to a string value.")
                }
            }
        }
    }
    case sessionReplay = "Session Replay"

    public enum Other: String, SentrySDKOverride {
        case disableAttachScreenshot = "--disable-attach-screenshot"
        case disableAttachViewHierarchy = "--disable-attach-view-hierarchy"
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
        case environment = "--io.sentry.sdk-environment"

        public var boolValue: Bool {
            get {
                switch self {
                case .username, .userFullName, .userEmail, .environment: fatalError("Use stringValue to get the value of this override")
                default: return getBoolOverride(for: "--io.sentry.disable-everything") || getBoolOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .username, .userFullName, .userEmail, .environment: fatalError("Use stringValue to get the value of this override")
                default: setBoolOverride(for: rawValue, value: newValue)
                }
            }
        }

        public var stringValue: String? {
            get {
                switch self {
                case .username, .userFullName, .userEmail, .environment: return getStringValueOverride(for: rawValue)
                default: fatalError("Use boolValue to get the value of this override")
                }
            }
            set(newValue) {
                switch self {
                case .username, .userFullName, .userEmail, .environment: return setStringOverride(for: rawValue, value: newValue)
                default: fatalError("Use boolValue to get the value of this override")
                }
            }
        }
    }
    case other = "Other"

    public enum Tracing: String, SentrySDKOverride {
        case sampleRate = "--io.sentry.tracesSampleRate"
        case samplerValue = "--io.sentry.tracesSamplerValue"
        case disableTracing = "--io.sentry.disable-tracing"

        public var boolValue: Bool {
            get {
                switch self {
                case .sampleRate, .samplerValue: fatalError("Use floatValue to get the value of this override")
                default: return getBoolOverride(for: "--io.sentry.disable-everything") || getBoolOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .sampleRate, .samplerValue: fatalError("Use floatValue to get the value of this override")
                default: setBoolOverride(for: rawValue, value: newValue)
                }
            }
        }

        public var floatValue: Float? {
            get {
                switch self {
                case .disableTracing: fatalError("Use boolValue to get the value of this override")
                default: return getFloatValueOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .disableTracing: fatalError("Use boolValue to get the value of this override")
                default: setFloatOverride(for: rawValue, value: newValue)
                }
            }
        }
    }
    case tracing = "Tracing"

    public enum Profiling: String, SentrySDKOverride {
        case sampleRate = "--io.sentry.profilesSampleRate"
        case samplerValue = "--io.sentry.profilesSamplerValue"
        case disableAppStartProfiling = "--io.sentry.disable-app-start-profiling"
        case manualLifecycle = "--io.sentry.profile-lifecycle-manual"
        case sessionSampleRate = "--io.sentry.profile-session-sample-rate"
        case disableUIProfiling = "--io.sentry.disable-ui-profiling"

        public var boolValue: Bool {
            get {
                switch self {
                case .sampleRate, .samplerValue, .sessionSampleRate: fatalError("Use floatValue to get the value of this override")
                case .disableUIProfiling, .disableAppStartProfiling: return getBoolOverride(for: "--io.sentry.disable-everything") || getBoolOverride(for: rawValue)
                default: return getBoolOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .sampleRate, .samplerValue, .sessionSampleRate: fatalError("Use floatValue to get the value of this override")
                default: setBoolOverride(for: rawValue, value: newValue)
                }
            }
        }

        public var floatValue: Float? {
            get {
                switch self {
                case .disableUIProfiling, .disableAppStartProfiling, .manualLifecycle: fatalError("Use boolValue to get the value of this override")
                default: return getFloatValueOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .disableUIProfiling, .disableAppStartProfiling, .manualLifecycle: fatalError("Use boolValue to get the value of this override")
                default: setFloatOverride(for: rawValue, value: newValue)
                }
            }
        }
    }
    case profiling = "Profiling"
}

private extension SentrySDKOverrides {
    static func getBoolOverride(for key: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(key) || defaults.bool(forKey: key)
    }

    static func setBoolOverride(for key: String, value: Bool) {
        defaults.set(value, forKey: key)
    }

    static func setFloatOverride(for key: String, value: Float?) {
        guard let value = value else {
            defaults.removeObject(forKey: key)
            return
        }
        
        setStringOverride(for: key, value: String(format: "%f", value))
    }

    static func setStringOverride(for key: String, value: String?) {
        defaults.set(value, forKey: key)
    }

    static func getFloatValueOverride(for key: String) -> Float? {
        (getStringValueOverride(for: key) as? NSString)?.floatValue
    }

    static func getStringValueOverride(for key: String) -> String? {
        var schemaEnvironmentVariable: String?
        if let value = ProcessInfo.processInfo.environment[key] {
            schemaEnvironmentVariable = value
        }

        let defaultsValue = defaults.string(forKey: key)

        if schemaPrecedenceForEnvironmentVariables {
            return schemaEnvironmentVariable ?? defaultsValue
        } else {
            return defaultsValue ?? schemaEnvironmentVariable
        }
    }
}

// MARK: UITableViewDataSource adaptation

extension SentrySDKOverrides {
    var rowsForSection: Int {
        switch self {
        case .profiling: return Profiling.allCases.count
        case .tracing: return Tracing.allCases.count
        case .sessionReplay: return SessionReplay.allCases.count
        case .other: return Other.allCases.count
        case .feedback: return Feedback.allCases.count
        case .performance: return Performance.allCases.count
        case .special: return Special.allCases.count
        }
    }
}

protocol SentrySDKOverrideType {
    static var boolValues: [Self] { get }
    static var floatValues: [Self] { get }
    static var stringValues: [Self] { get }
}

extension SentrySDKOverrideType {
    public static var boolValues: [Self] { [] }
    public static var floatValues: [Self] { [] }
    public static var stringValues: [Self] { [] }
}

extension SentrySDKOverrides.Profiling: SentrySDKOverrideType {
    public static var boolValues: [SentrySDKOverrides.Profiling] { [.disableUIProfiling, .disableAppStartProfiling, .manualLifecycle] }
    public static var floatValues: [SentrySDKOverrides.Profiling] { [.sampleRate, .samplerValue, .sessionSampleRate] }
}

extension SentrySDKOverrides.Tracing: SentrySDKOverrideType {
    public static var boolValues: [SentrySDKOverrides.Tracing] { [.disableTracing] }
    public static var floatValues: [SentrySDKOverrides.Tracing] { [.sampleRate, .samplerValue] }
}

extension SentrySDKOverrides.Other: SentrySDKOverrideType {
    public static var boolValues: [SentrySDKOverrides.Other] { [.disableAttachScreenshot, .disableAttachViewHierarchy, .disableMetricKit, .disableBreadcrumbs, .disableNetworkBreadcrumbs, .disableSwizzling, .disableCrashHandling, .disableSpotlight, .disableFileManagerSwizzling, .disableMetricKitRawPayloads] }
    public static var stringVars: [SentrySDKOverrides.Other] { [.username, .userFullName, .userEmail, .environment] }
}

extension SentrySDKOverrides.Performance: SentrySDKOverrideType {
}

extension SentrySDKOverrides.SessionReplay: SentrySDKOverrideType {
}

extension SentrySDKOverrides.Feedback: SentrySDKOverrideType {
}

extension SentrySDKOverrides.Special: SentrySDKOverrideType {
}
