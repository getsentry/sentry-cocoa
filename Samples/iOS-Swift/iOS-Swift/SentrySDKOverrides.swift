import Foundation

protocol SentrySDKOverride: RawRepresentable, CaseIterable {
    var boolValue: Bool { get set }
    var floatValue: Float? { get set }
    var stringValue: String? { get set }
}

extension SentrySDKOverride {
    public var boolValue: Bool { get { false } set { } }
    public var floatValue: Float? { get { nil } set { } }
    public var stringValue: String? { get { nil } set { } }
}

public enum SentrySDKOverrides {
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

    enum Special: String, SentrySDKOverride {
        case wipeDataOnLaunch = "--io.sentry.wipe-data"
        case disableEverything = "--io.sentry.disable-everything"

        public var boolValue: Bool {
            get {
                return getBoolOverride(for: rawValue)
            }
            set(newValue) {
                setBoolOverride(for: rawValue, value: newValue)
            }
        }
    }

    enum Feedback: String, SentrySDKOverride {
        case allDefaults = "--io.sentry.feedback.all-defaults"
        case disableAutoInject = "--io.sentry.feedback.no-auto-inject-widget"
        case noWidgetText = "--io.sentry.feedback.no-widget-text"
        case noWidgetIcon = "--io.sentry.feedback.no-widget-icon"
        case noUserInjection = "--io.sentry.feedback.dont-use-sentry-user"
        case requireEmail = "--io.sentry.feedback.require-email"
        case requireName = "--io.sentry.feedback.require-name"
        case noAnimations = "--io.sentry.feedback.no-animations"

        public var boolValue: Bool {
            get {
                switch self {
                case .disableAutoInject: return getBoolOverride(for: rawValue)
                default: return getBoolOverride(for: rawValue)
                }
            }
            set(newValue) {
                setBoolOverride(for: rawValue, value: newValue)
            }
        }
    }

    enum Performance: String, SentrySDKOverride {
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

        public var boolValue: Bool {
            get {
                return getBoolOverride(for: "--io.sentry.disable-everything") || getBoolOverride(for: rawValue)
            }
            set(newValue) {
                setBoolOverride(for: rawValue, value: newValue)
            }
        }
    }

    enum Other: String, SentrySDKOverride {
        case disableAttachScreenshot = "--disable-attach-screenshot"
        case disableAttachViewHierarchy = "--disable-attach-view-hierarchy"
        case disableSessionReplay = "--disable-session-replay"
        case disableMetricKit = "--disable-metrickit-integration"
        case disableBreadcrumbs = "--disable-automatic-breadcrumbs"
        case disableNetworkBreadcrumbs = "--disable-network-breadcrumbs"
        case disableSwizzling = "--disable-swizzling"
        case disableCrashHandling = "--disable-crash-handler"
        case disableSpotlight = "--disable-spotlight"
        case disableFileManagerSwizzling = "--disable-filemanager-swizzling"
        case userName = "--io.sentry.user.name"
        case userEmail = "--io.sentry.user.email"

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

        var stringValue: String? {
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

        public static var boolValues: [Other] { [.disableAttachScreenshot, .disableAttachViewHierarchy, .disableSessionReplay, .disableMetricKit, .disableBreadcrumbs, .disableNetworkBreadcrumbs, .disableSwizzling, .disableCrashHandling, .disableSpotlight] }
        public static var stringVars: [Other] { [.userName, .userEmail] }
    }

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

        public static var boolValues: [Tracing] { [.disableTracing] }
        public static var floatValues: [Tracing] { [.sampleRate, .samplerValue] }
    }

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

        public static var boolValues: [Profiling] { [.disableUIProfiling, .disableAppStartProfiling, .manualLifecycle] }
        public static var floatValues: [Profiling] { [.sampleRate, .samplerValue, .sessionSampleRate] }
    }
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
