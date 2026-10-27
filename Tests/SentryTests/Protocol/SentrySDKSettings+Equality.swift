#if SWIFT_PACKAGE
#if !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
#else
@testable import Sentry
#endif

extension SentrySDKSettings {
    public static func == (lhs: SentrySDKSettings, rhs: SentrySDKSettings) -> Bool {
        lhs.autoInferIP == rhs.autoInferIP
    }
}

#if compiler(>=6.0) && !SWIFT_PACKAGE
extension SentrySDKSettings: @retroactive Equatable { }
#else
extension SentrySDKSettings: Equatable { }
#endif
