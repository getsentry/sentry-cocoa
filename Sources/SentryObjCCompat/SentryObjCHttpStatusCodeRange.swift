// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCHttpStatusCodeRange) public final class SentryObjCHttpStatusCodeRange: NSObject {
    internal let wrapped: HttpStatusCodeRange

    internal init(_ wrapped: HttpStatusCodeRange) {
        self.wrapped = wrapped
    }

    @objc public init(min: Int, max: Int) {
        self.wrapped = HttpStatusCodeRange(min: min, max: max)
    }

    @objc public init(statusCode: Int) {
        self.wrapped = HttpStatusCodeRange(statusCode: statusCode)
    }

    @objc public var min: Int {
        wrapped.min
    }

    @objc public var max: Int {
        wrapped.max
    }
}

// swiftlint:enable missing_docs
