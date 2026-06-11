// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

extension SentryObjCSDK {
    @objc public static let `internal` = SentryObjCInternalApi()
}
// swiftlint:enable missing_docs
