#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
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
