// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCNSError) public final class SentryObjCNSError: NSObject {
    internal let wrapped: SentryNSError

    internal init(_ wrapped: SentryNSError) {
        self.wrapped = wrapped
    }

    @objc public init(domain: String, code: Int) {
        self.wrapped = SentryNSError(domain: domain, code: code)
    }

    @objc public var domain: String {
        get { wrapped.domain }
        set { wrapped.domain = newValue }
    }

    @objc public var code: Int {
        get { wrapped.code }
        set { wrapped.code = newValue }
    }
}

// swiftlint:enable missing_docs
