@testable import Sentry

extension SentrySDKSettings {
    public static func == (lhs: Sentry.SentrySDKSettings, rhs: Sentry.SentrySDKSettings) -> Bool {
        lhs.autoInferIP == rhs.autoInferIP
    }
}

#if compiler(>=6.0)
extension SentrySDKSettings: @retroactive Equatable { }
#else
extension SentrySDKSettings: Equatable { }
#endif
