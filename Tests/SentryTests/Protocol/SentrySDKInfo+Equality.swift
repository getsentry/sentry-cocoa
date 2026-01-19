@testable import Sentry

extension SentrySdkInfo {
    public static func == (lhs: Sentry.SentrySdkInfo, rhs: Sentry.SentrySdkInfo) -> Bool {
        return lhs.name == rhs.name &&
        lhs.version == rhs.version &&
        Set(lhs.integrations) == Set(rhs.integrations) &&
        Set(lhs.features) == Set(rhs.features) &&
        Set(lhs.packages) == Set(rhs.packages) &&
        lhs.settings == rhs.settings
    }
}

#if compiler(>=6.0)
extension SentrySdkInfo: @retroactive Equatable { }
#else
extension SentrySdkInfo: Equatable { }
#endif
