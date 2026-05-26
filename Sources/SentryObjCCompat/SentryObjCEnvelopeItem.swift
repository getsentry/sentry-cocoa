// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

public final class SentryObjCEnvelopeItem: NSObject {
    internal let wrapped: SentryEnvelopeItem

    internal init(_ wrapped: SentryEnvelopeItem) {
        self.wrapped = wrapped
    }

    @objc public init(type: String, data: Data?, contentType: String, itemCount: NSNumber) {
        self.wrapped = SentryEnvelopeItem(
            type: type,
            data: data,
            contentType: contentType,
            itemCount: itemCount
        )
    }

    @objc public init(type: String, data: Data?, addPlatform: Bool) {
        self.wrapped = SentryEnvelopeItem(
            type: type,
            data: data,
            addPlatform: addPlatform
        )
    }

    @objc public init(event: SentryObjCEvent) {
        self.wrapped = SentryEnvelopeItem(event: event.wrapped)
    }

    @objc public var data: Data? {
        wrapped.data
    }

    @objc public var type: String {
        wrapped.type()
    }
}

// swiftlint:enable missing_docs
