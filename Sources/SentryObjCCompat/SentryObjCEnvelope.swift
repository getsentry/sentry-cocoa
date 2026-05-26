// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

public final class SentryObjCEnvelope: NSObject {
    internal let wrapped: SentryEnvelope

    internal init(_ wrapped: SentryEnvelope) {
        self.wrapped = wrapped
    }

    @objc public init(header: SentryObjCEnvelopeHeader, items: [SentryObjCEnvelopeItem]) {
        self.wrapped = SentryEnvelope(
            header: header.wrapped,
            items: items.map { $0.wrapped }
        )
    }

    @objc public init(header: SentryObjCEnvelopeHeader, singleItem item: SentryObjCEnvelopeItem) {
        self.wrapped = SentryEnvelope(
            header: header.wrapped,
            singleItem: item.wrapped
        )
    }

    @objc public init(id: SentryObjCId?, singleItem item: SentryObjCEnvelopeItem) {
        self.wrapped = SentryEnvelope(
            id: id?.wrapped,
            singleItem: item.wrapped
        )
    }

    @objc public init(id: SentryObjCId?, items: [SentryObjCEnvelopeItem]) {
        self.wrapped = SentryEnvelope(
            id: id?.wrapped,
            items: items.map { $0.wrapped }
        )
    }

    @objc public var header: SentryObjCEnvelopeHeader {
        SentryObjCEnvelopeHeader(wrapped.header)
    }

    @objc public var items: [SentryObjCEnvelopeItem] {
        wrapped.items.map { SentryObjCEnvelopeItem($0) }
    }
}

// swiftlint:enable missing_docs
