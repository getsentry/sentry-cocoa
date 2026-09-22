#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@testable import Sentry
#endif

extension SentrySdkInfo {
    public static func == (lhs: SentrySdkInfo, rhs: SentrySdkInfo) -> Bool {
        return lhs.name == rhs.name &&
        lhs.version == rhs.version &&
        Set(lhs.integrations) == Set(rhs.integrations) &&
        Set(lhs.features) == Set(rhs.features) &&
        Set(lhs.packages) == Set(rhs.packages) &&
        lhs.settings == rhs.settings
    }
}

#if compiler(>=6.0) && !SWIFT_PACKAGE
extension SentrySdkInfo: @retroactive Equatable { }
#else
extension SentrySdkInfo: Equatable { }
#endif
