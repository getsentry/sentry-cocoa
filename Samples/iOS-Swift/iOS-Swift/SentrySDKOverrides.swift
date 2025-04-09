import Foundation

enum SentrySDKOverrides {
    static let userDefaultOverrideSuffix = "-not-overridden"
    static let defaults = UserDefaults.standard
    
    static func resetDefaults() {
        for key in Tracing.allCases.map(\.rawValue) + Profiling.allCases.map(\.rawValue) {
            defaults.removeObject(forKey: key)
            defaults.set(true, forKey: key + userDefaultOverrideSuffix)
        }
    }
    
    enum Performance: String {
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

        var set: Bool {
            get {
                getOverride(for: rawValue)
            }
            set(newValue) {
                setOverride(for: rawValue, value: newValue)
            }
        }
    }
    
    enum Other: String {
        case disableAttachScreenshot = "--disable-attach-screenshot"
        case disableAttachViewHierarchy = "--disable-attach-view-hierarchy"
        case disableSessionReplay = "--disable-session-replay"
        case disableMetricKit = "--disable-metrickit-integration"
        case disableBreadcrumbs = "--disable-automatic-breadcrumbs"
        case disableNetworkBreadcrumbs = "--disable-network-breadcrumbs"
        case disableSwizzling = "--disable-swizzling"
        case disableCrashHandling = "--disable-crash-handler"
        case disableSpotlight = "--disable-spotlight"

        var set: Bool {
            get {
                getOverride(for: rawValue)
            }
            set(newValue) {
                setOverride(for: rawValue, value: newValue)
            }
        }
    }
    
    enum Tracing: String, CaseIterable {
        case sampleRate = "--io.sentry.tracesSampleRate"
        case samplerValue = "--io.sentry.tracesSamplerValue"
        case disableTracing = "--io.sentry.disable-tracing"

        var set: Bool {
            get {
                switch self {
                case .sampleRate, .samplerValue: fatalError("Invalid")
                default: getOverride(for: rawValue)
                }
            }
            set(newValue) {
                switch self {
                case .sampleRate, .samplerValue: fatalError("Invalid")
                default: setOverride(for: rawValue, value: newValue)
                }
            }
        }

        var value: Float? {
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
    
    enum Profiling: String, CaseIterable {
        case sampleRate = "--io.sentry.profilesSampleRate"
        case samplerValue = "--io.sentry.profilesSamplerValue"
        case disableAppStartProfiling = "--io.sentry.disable-app-start-profiling"
        case manualLifecycle = "--io.sentry.profile-lifecycle-manual"
        case sessionSampleRate = "--io.sentry.profile-session-sample-rate"
        case disableUIProfiling = "--io.sentry.disable-ui-profiling"

        var set: Bool {
            get {
                switch self {
                case .sampleRate, .samplerValue, .sessionSampleRate: fatalError("Invalid")
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
        
        var value: Float? {
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
    private static func getOverride(for key: String) -> Bool {
        let args = ProcessInfo.processInfo.arguments
        
        if args.contains("--io.sentry.schema-override-precedence") {
            guard args.contains(key) else {
                return checkOverride(key) {
                    false
                }
            }
            
            return true
        }
        
        return checkOverride(key) {
            args.contains(key)
        }
    }
    
    /// If a key is not present for a bool in user defaults, it returns false, but we need to know if it's returning false because it was overridden that way, or just isn't present, so we provide a way to return a "default value" if the override isn't present in defaults at all (indicated by a "true" value stored for "default X not overridden" key to make this truthy, otherwise return the stored defaults value
    private static func checkOverride(_ key: String, defaultValue: () -> Bool) -> Bool {
        let defaults = defaults
        
        guard !defaults.bool(forKey: key + userDefaultOverrideSuffix) else {
            return defaultValue()
        }
        
        return defaults.bool(forKey: key)
    }
    
    private static func setOverride(for key: String, value: Any?) {
        defaults.set(value, forKey: key)
        defaults.set(false, forKey: key + userDefaultOverrideSuffix)
    }

    private static func getValueOverride<T>(for key: String) -> T? where T: LosslessStringConvertible {
        if ProcessInfo.processInfo.arguments.contains("--io.sentry.schema-override-precedence") {
            return ProcessInfo.processInfo.environment[key].flatMap(T.init)
        }

        return defaults.object(forKey: key) as? T
            ?? ProcessInfo.processInfo.environment[key].flatMap(T.init)
    }
}
