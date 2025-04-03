import Foundation

enum SentrySDKTestConfiguration {
    enum Profiling {
        enum Key: String {
            case sampleRate = "--io.sentry.profilesSampleRate"
            case samplerValue = "--io.sentry.profilesSamplerValue"
            case launchProfilingV1 = "--io.sentry.profile-app-launches"
            case continuousProfilingV1 = "--io.sentry.enableContinuousProfiling"
        }

        static func getSampleRate() -> Float? {
            return getConfiguredValue(for: .sampleRate)
        }

        static func getSamplerValue() -> Float? {
            return getConfiguredValue(for: .samplerValue)
        }

        private static func getConfiguredValue<T>(for key: Key) -> T? where T: LosslessStringConvertible {
            UserDefaults.standard.object(forKey: key.rawValue) as? T
                ?? ProcessInfo.processInfo.environment[key.rawValue].flatMap(T.init)
        }
    }
}
