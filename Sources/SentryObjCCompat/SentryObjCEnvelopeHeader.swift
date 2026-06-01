// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCEnvelopeHeader) public final class SentryObjCEnvelopeHeader: NSObject {
    internal let wrapped: SentryEnvelopeHeader

    internal init(_ wrapped: SentryEnvelopeHeader) {
        self.wrapped = wrapped
    }

    @objc public init(id eventId: SentryObjCId?, traceContext: SentryObjCTraceContext?) {
        self.wrapped = SentryEnvelopeHeader(
            id: eventId?.wrapped,
            traceContext: traceContext?.wrapped
        )
    }

    @objc public init(id eventId: SentryObjCId?) {
        self.wrapped = SentryEnvelopeHeader(
            id: eventId?.wrapped,
            traceContext: nil
        )
    }

    @objc public static func empty() -> SentryObjCEnvelopeHeader {
        SentryObjCEnvelopeHeader(SentryEnvelopeHeader.empty())
    }

    @objc public var eventId: SentryObjCId? {
        wrapped.eventId.map { SentryObjCId($0) }
    }

    @objc public var traceContext: SentryObjCTraceContext? {
        wrapped.traceContext.map { SentryObjCTraceContext($0) }
    }

    @objc public var sentAt: Date? {
        get { wrapped.sentAt }
        set { wrapped.sentAt = newValue }
    }
}

// swiftlint:enable missing_docs
