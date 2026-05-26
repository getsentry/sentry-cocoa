// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCId) public final class SentryObjCId: NSObject {
    internal let wrapped: SentryId

    internal init(_ wrapped: SentryId) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryId()
    }

    @objc public init(uuid: UUID) {
        self.wrapped = SentryId(uuid: uuid)
    }

    @objc(initWithUUIDString:) public init(uuidString: String) {
        self.wrapped = SentryId(uuidString: uuidString)
    }

    @objc public var sentryIdString: String {
        wrapped.sentryIdString
    }

    @objc public static var empty: SentryObjCId {
        SentryObjCId(SentryId.empty)
    }
}

// swiftlint:enable missing_docs
