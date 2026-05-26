// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCSpanId: NSObject {
    internal let wrapped: SpanId

    internal init(_ wrapped: SpanId) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SpanId()
    }

    @objc public init(uuid: UUID) {
        self.wrapped = SpanId(uuid: uuid)
    }

    @objc public init(value: String) {
        self.wrapped = SpanId(value: value)
    }

    @objc public var sentrySpanIdString: String {
        wrapped.sentrySpanIdString
    }

    @objc public static var empty: SentryObjCSpanId {
        SentryObjCSpanId(SpanId.empty)
    }
}

// swiftlint:enable missing_docs
