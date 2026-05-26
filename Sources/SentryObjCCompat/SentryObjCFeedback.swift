// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif

public final class SentryObjCFeedback: NSObject {
    internal let wrapped: SentryFeedback

    internal init(_ wrapped: SentryFeedback) {
        self.wrapped = wrapped
    }

    @objc public init(message: String, name: String?, email: String?, source: SentryObjCFeedbackSource = .widget, associatedEventId: SentryObjCId? = nil, attachments: [SentryObjCAttachment]? = nil) {
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
        wrapped.message
    }

    @objc public var name: String? {
        wrapped.name
    }

    @objc public var email: String? {
        wrapped.email
    }

    @objc public var source: SentryObjCFeedbackSource {
        SentryObjCFeedbackSource(wrapped.source)
    }

    @objc public var eventId: SentryObjCId {
        SentryObjCId(wrapped.eventId)
    }

    @objc public var associatedEventId: SentryObjCId? {
        wrapped.associatedEventId.map { SentryObjCId($0) }
    }

    @objc public var attachments: [SentryObjCAttachment]? {
        wrapped.attachmentsForEnvelope().isEmpty ? nil : wrapped.attachmentsForEnvelope().map { SentryObjCAttachment($0) }
    }
}

// swiftlint:enable missing_docs
