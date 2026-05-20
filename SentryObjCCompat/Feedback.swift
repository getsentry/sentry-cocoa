internal import SentrySwift
import Foundation

/// User feedback gathered manually and forwarded to Sentry.
@objc(SOCSentryFeedback)
public final class Feedback: NSObject {
    internal let wrapped: SentrySwift.SentryFeedback

    internal init(_ wrapped: SentrySwift.SentryFeedback) {
        self.wrapped = wrapped
        super.init()
    }

    /// - parameter associatedEventId: optional ID of the event this feedback relates to.
    /// - parameter attachments: optional files (e.g. screenshots) to include.
    @objc public init(
        message: String,
        name: String?,
        email: String?,
        source: SentryFeedbackSource,
        associatedEventId: SentryId?,
        attachments: [Attachment]?
    ) {
        self.wrapped = SentrySwift.SentryFeedback(
            message: message,
            name: name,
            email: email,
            source: source.underlying,
            associatedEventId: associatedEventId?.wrapped,
            attachments: attachments?.map { $0.wrapped }
        )
        super.init()
    }
}
