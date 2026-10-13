#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@testable import Sentry
#endif

extension SentrySDKSettings {
    public static func == (lhs: SentrySDKSettings, rhs: SentrySDKSettings) -> Bool {
        lhs.autoInferIP == rhs.autoInferIP
    }
}

#if compiler(>=6.0)
extension SentrySDKSettings: @retroactive Equatable { }
#else
extension SentrySDKSettings: Equatable { }
#endif
