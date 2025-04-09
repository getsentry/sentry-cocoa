import Foundation

protocol SentrySDKOverride: RawRepresentable, CaseIterable {
    var set: Bool { get set }
    var value: Float? { get set }
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

        public var set: Bool {
            get {
                getOverride(for: rawValue)
            }
            set(newValue) {
                setUserDefaultOverride(for: rawValue, value: newValue)
            }
        }

        var value: Float? {
            get {
                fatalError("Invalid")
            }
            set(newValue) {
                fatalError("Invalid")
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

        public var set: Bool {
            get {
                switch self {
                case .disableAutoInject: getOverride(for: "--io.sentry.disable-everything") || getOverride(for: rawValue)
                default: getOverride(for: rawValue)
                }
            }
            set(newValue) {
                setUserDefaultOverride(for: rawValue, value: newValue)
            }
        }

        var value: Float? {
            get {
                fatalError("Invalid")
            }
            set(newValue) {
                fatalError("Invalid")
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

        public var set: Bool {
            get {
                getOverride(for: "--io.sentry.disable-everything") || getOverride(for: rawValue)
            }
            set(newValue) {
                setUserDefaultOverride(for: rawValue, value: newValue)
            }
        }

        var value: Float? {
            get {
                fatalError("Invalid")
            }
            set(newValue) {
                fatalError("Invalid")
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

        public var set: Bool {
            get {
                getOverride(for: "--io.sentry.disable-everything") || getOverride(for: rawValue)
            }
            set(newValue) {
                setUserDefaultOverride(for: rawValue, value: newValue)
            }
        }

        var value: Float? {
            get {
                fatalError("Invalid")
            }
            set(newValue) {
                fatalError("Invalid")
            }
        }
    }

    public enum Tracing: String, SentrySDKOverride {
        case sampleRate = "--io.sentry.tracesSampleRate"
        case samplerValue = "--io.sentry.tracesSamplerValue"
        case disableTracing = "--io.sentry.disable-tracing"

        public var set: Bool {
            get {
                switch self {
                case .sampleRate, .samplerValue: fatalError("Invalid")
                default: getOverride(for: "--io.sentry.disable-everything") || getOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .sampleRate, .samplerValue: fatalError("Invalid")
                default: setUserDefaultOverride(for: rawValue, value: newValue)
                }
            }
        }

        public var value: Float? {
            get {
                switch self {
                case .disableTracing: fatalError("Invalid")
                default: getValueOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .disableTracing: fatalError("Invalid")
                default: setUserDefaultOverride(for: rawValue, value: newValue)
                }
            }
        }

        public static var args: [Tracing] { [.disableTracing] }
        public static var vars: [Tracing] { [.sampleRate, .samplerValue] }
    }

    public enum Profiling: String, SentrySDKOverride {
        case sampleRate = "--io.sentry.profilesSampleRate"
        case samplerValue = "--io.sentry.profilesSamplerValue"
        case disableAppStartProfiling = "--io.sentry.disable-app-start-profiling"
        case manualLifecycle = "--io.sentry.profile-lifecycle-manual"
        case sessionSampleRate = "--io.sentry.profile-session-sample-rate"
        case disableUIProfiling = "--io.sentry.disable-ui-profiling"

        public var set: Bool {
            get {
                switch self {
                case .sampleRate, .samplerValue, .sessionSampleRate: fatalError("Invalid")
                case .disableUIProfiling, .disableAppStartProfiling: getOverride(for: "--io.sentry.disable-everything") || getOverride(for: rawValue)
                default: getOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .sampleRate, .samplerValue, .sessionSampleRate: fatalError("Invalid")
                default: setUserDefaultOverride(for: rawValue, value: newValue)
                }
            }
        }

        public var value: Float? {
            get {
                switch self {
                case .disableUIProfiling, .disableAppStartProfiling, .manualLifecycle: fatalError("Invalid")
                default: getValueOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .disableUIProfiling, .disableAppStartProfiling, .manualLifecycle: fatalError("Invalid")
                default: setUserDefaultOverride(for: rawValue, value: newValue)
                }
            }
        }

        public static var args: [Profiling] { [.disableUIProfiling, .disableAppStartProfiling, .manualLifecycle] }
        public static var vars: [Profiling] { [.sampleRate, .samplerValue, .sessionSampleRate] }
    }
}

private extension SentrySDKOverrides {
    static func getOverride(for key: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(key) || defaults.bool(forKey: key)
    }
    
    static func setUserDefaultOverride(for key: String, value: Any?) {
        defaults.set(value, forKey: key)
    }

    static func getValueOverride<T>(for key: String) -> T? where T: LosslessStringConvertible {
        var schemaEnvironmentVariable: T?
        if let value = ProcessInfo.processInfo.environment[key] {
            schemaEnvironmentVariable = value as? T
        }
        let defaultsValue = defaults.object(forKey: key) as? T
        if schemaPrecedenceForEnvironmentVariables {
            return schemaEnvironmentVariable ?? defaultsValue
        } else {
            return defaultsValue ?? schemaEnvironmentVariable
        }
    }
}
