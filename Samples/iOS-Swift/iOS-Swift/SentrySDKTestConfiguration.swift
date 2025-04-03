import Foundation

enum SentrySDKTestConfiguration {
    enum Profiling {
        enum Key: String {
            case sampleRate = "--io.sentry.profilesSampleRate"
            case samplerValue = "--io.sentry.profilesSamplerValue"
            case launchProfiling = "--io.sentry.profile-app-launches"
            case continuousProfilingV1 = "--io.sentry.enableContinuousProfiling"
            case useProfilingV2 = "--io.sentry.profile-options-v2"
            case traceLifecycle = "--io.sentry.profile-lifecycle-trace"
            case sessionSampleRate = "--io.sentry.profile-session-sample-rate"
        }

        static func getSampleRate() -> Float? {
            return getConfiguredValue(for: .sampleRate)
        }

        static func getSamplerValue() -> Float? {
            return getConfiguredValue(for: .samplerValue)
        }

        static func getSessionSampleRate() -> Float {
            return getConfiguredValue(for: .sessionSampleRate) ?? 0
        }

        static func getLifecycle() -> SentryProfileOptions.SentryProfileLifecycle {
            getConfiguredBoolValue(for: .traceLifecycle) ? .trace : .manual
        }

        static func shouldProfileLaunches() -> Bool {
            getConfiguredBoolValue(for: .launchProfiling)
        }

        private static func getConfiguredBoolValue(for key: Key) -> Bool {
            if let value = UserDefaults.standard.object(forKey: key.rawValue), let bool = value as? Bool {
                return bool
            }

            return ProcessInfo.processInfo.arguments.contains(key.rawValue)
        }

        private static func getConfiguredValue<T>(for key: Key) -> T? where T: LosslessStringConvertible {
            UserDefaults.standard.object(forKey: key.rawValue) as? T
                ?? ProcessInfo.processInfo.environment[key.rawValue].flatMap(T.init)
        }
    }
}
