import Foundation

protocol OverrideKey: RawRepresentable, CaseIterable {
    var rawValue: String { get }
}

enum SentrySDKOverrides {
    static let defaultSuiteName = "io.sentry.iOS-Swift"

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
            case launchProfiling = "--io.sentry.profile-app-launches"
            case continuousProfilingV1 = "--io.sentry.enableContinuousProfiling"
            case useProfilingV2 = "--io.sentry.profile-options-v2"
            case traceLifecycle = "--io.sentry.profile-lifecycle-trace"
            case sessionSampleRate = "--io.sentry.profile-session-sample-rate"
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

        static var lifecycle: SentryProfileOptions.SentryProfileLifecycle {
            get {
                getOverride(for: Profiling.Key.traceLifecycle) ? .trace : .manual
            }
            set(newValue) {
                UserDefaults.standard.set(newValue.rawValue, forKey: Profiling.Key.traceLifecycle.rawValue)
            }
        }

        static var profileAppStarts: Bool {
            get {
                getOverride(for: Profiling.Key.launchProfiling)
            }
            set(newValue) {
                UserDefaults.standard.set(newValue, forKey: Profiling.Key.launchProfiling.rawValue)
            }
        }

        static var useContinuousProfilingV1: Bool {
            get {
                getOverride(for: Profiling.Key.continuousProfilingV1)
            }
            set(newValue) {
                UserDefaults.standard.set(newValue, forKey: Profiling.Key.continuousProfilingV1.rawValue)
            }
        }

        static var useProfilingV2: Bool {
            get {
                getOverride(for: Profiling.Key.useProfilingV2)
            }
            set(newValue) {
                UserDefaults.standard.set(newValue, forKey: Profiling.Key.useProfilingV2.rawValue)
            }
        }
    }

    private static func getOverride(for key: any OverrideKey) -> Bool {
        if let value = UserDefaults.standard.object(forKey: key.rawValue), let bool = value as? Bool {
            return bool
        }

        return ProcessInfo.processInfo.arguments.contains(key.rawValue)
    }

    private static func getValueOverride<T>(for key: any OverrideKey) -> T? where T: LosslessStringConvertible {
        UserDefaults.standard.object(forKey: key.rawValue) as? T
            ?? ProcessInfo.processInfo.environment[key.rawValue].flatMap(T.init)
    }
}
