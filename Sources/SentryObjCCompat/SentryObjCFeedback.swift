// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCFeedback) public final class SentryObjCFeedback: NSObject {
    internal let wrapped: SentryFeedback

    // Store init values locally since SentryFeedback properties are internal
    private let _message: String
    private let _name: String?
    private let _email: String?
    private let _source: SentryObjCFeedbackSource
    private let _associatedEventId: SentryObjCId?

    internal init(_ wrapped: SentryFeedback, message: String, name: String?, email: String?, source: SentryObjCFeedbackSource, associatedEventId: SentryObjCId?) {
        self.wrapped = wrapped
        self._message = message
        self._name = name
        self._email = email
        self._source = source
        self._associatedEventId = associatedEventId
    }

    @objc public init(message: String, name: String?, email: String?, source: SentryObjCFeedbackSource = .widget, associatedEventId: SentryObjCId? = nil, attachments: [SentryObjCAttachment]? = nil) {
        self._message = message
        self._name = name
        self._email = email
        self._source = source
        self._associatedEventId = associatedEventId
        self.wrapped = SentryFeedback(
            message: message,
            name: name,
            email: email,
            source: source.underlying,
            associatedEventId: associatedEventId?.wrapped,
            attachments: attachments?.map { $0.wrapped }
        )
    }

    @objc public var message: String {
        _message
    }

    @objc public var name: String? {
        _name
    }

    @objc public var email: String? {
        _email
    }

    @objc public var source: SentryObjCFeedbackSource {
        _source
    }

    @objc public var eventId: SentryObjCId {
        SentryObjCId(wrapped.eventId)
    }

    @objc public var associatedEventId: SentryObjCId? {
        _associatedEventId
    }

    @objc public var attachments: [SentryObjCAttachment]? {
        wrapped.attachmentsForEnvelope().isEmpty ? nil : wrapped.attachmentsForEnvelope().map { SentryObjCAttachment($0) }
    }
}

// swiftlint:enable missing_docs
