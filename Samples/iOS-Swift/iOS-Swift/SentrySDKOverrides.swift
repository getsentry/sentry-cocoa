import Foundation

public enum SentrySDKOverrides {
    private static let userDefaultOverrideSuffix = "-not-overridden"
    private static let defaults = UserDefaults.standard

    public static func resetDefaults() {
        let allKeys = Tracing.allCases.map(\.rawValue)
            + Profiling.allCases.map(\.rawValue)
            + Performance.allCases.map(\.rawValue)
            + Other.allCases.map(\.rawValue)
            + Feedback.allCases.map(\.rawValue)
        for key in allKeys {
            defaults.removeObject(forKey: key)
            defaults.set(true, forKey: key + userDefaultOverrideSuffix)
        }
    }

    enum Feedback: String, CaseIterable {
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
                setOverride(for: rawValue, value: newValue)
            }
        }
    }

    enum Performance: String, CaseIterable {
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
                setOverride(for: rawValue, value: newValue)
            }
        }
    }

    enum Other: String, CaseIterable {
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
                setOverride(for: rawValue, value: newValue)
            }
        }
    }

    public enum Tracing: String, CaseIterable {
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
                default: setOverride(for: rawValue, value: newValue)
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
                default: setOverride(for: rawValue, value: newValue)
                }
            }
        }
    }

    public enum Profiling: String, CaseIterable {
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
                default: setOverride(for: rawValue, value: newValue)
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
                default: setOverride(for: rawValue, value: newValue)
                }
            }
        }
    }
}

private extension SentrySDKOverrides {
    /// - note: This returns `false` in the default case. For anything that calls this method, design the API in such a way that by default it responds to this returning `false`, and then if it returns `true`, the override takes effect. Here's the decision tree:
    /// ```
    /// - should schema overrides take precedence
    ///     - no (default)
    ///         - is override present in user defaults
    ///             - yes: return the value stored in user defaults
    ///             - no: return whether override flag is set in schema
    ///     - yes
    ///         - is override flag in the schema
    ///             - yes: return true indicating the override should take effect
    ///             - no
    ///                 - is override present in user defaults
    ///                     - yes: return the value stored in user defaults
    ///                     - no: return false indicating that the override should not take effect
    /// ```
    static func getOverride(for key: String) -> Bool {
        let args = ProcessInfo.processInfo.arguments
        
        if args.contains("--io.sentry.schema-override-precedence") {
            guard args.contains(key) else {
                return checkDefaultsOverride(key) {
                    false
                }
            }
            
            return true
        }
        
        return checkDefaultsOverride(key) {
            args.contains(key)
        }
    }

    /// If a key is not present for a bool in user defaults, it returns false, but we need to know if it's returning false because it was overridden that way, or just isn't present, so we provide a way to return a "default value" if the override isn't present in defaults at all (indicated by a "true" value stored for "default X not overridden" key to make this truthy, otherwise return the stored defaults value
    static func checkDefaultsOverride(_ key: String, defaultValue: () -> Bool) -> Bool {
        let defaults = defaults
        
        guard !defaults.bool(forKey: key + userDefaultOverrideSuffix) else {
            return defaultValue()
        }
        
        return defaults.bool(forKey: key)
    }
    
    static func setOverride(for key: String, value: Any?) {
        defaults.set(value, forKey: key)
        defaults.set(false, forKey: key + userDefaultOverrideSuffix)
    }

    static func getValueOverride<T>(for key: String) -> T? where T: LosslessStringConvertible {
        if ProcessInfo.processInfo.arguments.contains("--io.sentry.schema-override-precedence") {
            return ProcessInfo.processInfo.environment[key].flatMap(T.init)
        }

        return defaults.object(forKey: key) as? T
            ?? ProcessInfo.processInfo.environment[key].flatMap(T.init)
    }
}
