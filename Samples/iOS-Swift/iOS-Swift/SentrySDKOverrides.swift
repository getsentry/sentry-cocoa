import Foundation

protocol OverrideKey: RawRepresentable, CaseIterable {
    var rawValue: String { get }
}

enum SentrySDKOverrides {
    static func resetDefaults() {
        for key in Tracing.Key.allCases.map(\.rawValue) + Profiling.Key.allCases.map(\.rawValue) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    enum Tracing {
        enum Key: String, OverrideKey {
            case sampleRate = "--io.sentry.tracesSampleRate"
            case samplerValue = "--io.sentry.tracesSamplerValue"
        }

        static var sampleRate: Float? {
            get {
                getValueOverride(for: Tracing.Key.sampleRate)
            }
            set(newValue) {
                UserDefaults.standard.set(newValue, forKey: Tracing.Key.sampleRate.rawValue)
            }
        }

        static var samplerValue: Float? {
            get {
                getValueOverride(for: Tracing.Key.samplerValue)
            }
            set(newValue) {
                UserDefaults.standard.set(newValue, forKey: Tracing.Key.samplerValue.rawValue)
            }
        }
    }

    enum Profiling {
        enum Key: String, OverrideKey {
            case sampleRate = "--io.sentry.profilesSampleRate"
            case samplerValue = "--io.sentry.profilesSamplerValue"
            case disableAppStartProfiling = "--io.sentry.disable-app-start-profiling"
            case manualLifecycle = "--io.sentry.profile-lifecycle-manual"
            case sessionSampleRate = "--io.sentry.profile-session-sample-rate"
            case immediatelyStopProfiler = "--io.sentry.continuous-profiler-immediate-stop"
        }

        static var sampleRate: Float? {
            get {
                getValueOverride(for: Profiling.Key.sampleRate)
            }
            set(newValue) {
                UserDefaults.standard.set(newValue, forKey: Profiling.Key.sampleRate.rawValue)
            }
        }

        static var samplerValue: Float? {
            get {
                getValueOverride(for: Profiling.Key.samplerValue)
            }
            set(newValue) {
                UserDefaults.standard.set(newValue, forKey: Profiling.Key.samplerValue.rawValue)
            }
        }

        static var sessionSampleRate: Float? {
            get {
                getValueOverride(for: Profiling.Key.sessionSampleRate)
            }
            set(newValue) {
                UserDefaults.standard.set(newValue, forKey: Profiling.Key.sessionSampleRate.rawValue)
            }
        }

        /// - note: If no other overrides are present, we set the iOS-Swift app to use trace lifecycle (the SDK default is manual)
        static var manualLifecycle: Bool {
            get {
                return getOverride(for: Profiling.Key.manualLifecycle)
            }
            set(newValue) {
                setOverride(for: Profiling.Key.manualLifecycle, value: newValue)
            }
        }

        /// - note: If no other overrides are present, we set the iOS-Swift app to use launch profiling (the SDK default is to disable it)
        static var profileAppStarts: Bool {
            get {
                !getOverride(for: Profiling.Key.disableAppStartProfiling)
            }
            set(newValue) {
                setOverride(for: Profiling.Key.disableAppStartProfiling, value: !newValue)
            }
        }

        static var immediatelyStopProfiler: Bool {
            get {
                getOverride(for: Profiling.Key.immediatelyStopProfiler)
            }
            set(newValue) {
                setOverride(for: Profiling.Key.immediatelyStopProfiler, value: newValue)
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
    private static func getOverride(for key: any OverrideKey) -> Bool {
        let args = ProcessInfo.processInfo.arguments

        if args.contains("--io.sentry.schema-override-precedence") {
            guard args.contains(key.rawValue) else {
                return checkOverride(key) {
                    false
                }
            }

            return true
        }

        return checkOverride(key) {
            args.contains(key.rawValue)
        }
    }

    /// If a key is not present for a bool in user defaults, it returns false, but we need to know if it's returning false because it was overridden that way, or just isn't present, so we provide a way to return a "default value" if the override isn't present in defaults at all, otherwise return the stored defaults value
    private static func checkOverride(_ key: any OverrideKey, defaultValue: () -> Bool) -> Bool {
        let defaults = UserDefaults.standard

        guard !defaults.bool(forKey: key.rawValue + "-overridden") else {
            return defaultValue()
        }

        return defaults.bool(forKey: key.rawValue)
    }

    private static func setOverride(for key: any OverrideKey, value: Bool) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
        UserDefaults.standard.set(true, forKey: key.rawValue + "-overridden")
    }

    private static func getValueOverride<T>(for key: any OverrideKey) -> T? where T: LosslessStringConvertible {
            if ProcessInfo.processInfo.arguments.contains("--io.sentry.schema-override-precedence") {
                return ProcessInfo.processInfo.environment[key.rawValue].flatMap(T.init)
            }

        return UserDefaults.standard.object(forKey: key.rawValue) as? T
            ?? ProcessInfo.processInfo.environment[key.rawValue].flatMap(T.init)
    }
}
