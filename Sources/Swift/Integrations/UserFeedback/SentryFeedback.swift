import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * A user feedback item that serializes to an envelope with the format described at
 * https://develop.sentry.dev/application/feedback-architecture/#feedback-events.
 */
@objcMembers
class SentryFeedback: NSObject, SentrySerializable {
    enum Source: String {
        case widget
        case custom
    }

    var name: String?
    var email: String?
    var message: String
    var source: Source
    let eventId: SentryId
    
    /// The event id that this feedback is associated with, like a crash report.
    var associatedEventId: String?

    init(message: String, name: String?, email: String?, source: Source = .widget, associatedEventId: String? = nil) {
        self.eventId = SentryId()
        self.name = name
        self.email = email
        self.message = message
        self.source = source
        self.associatedEventId = associatedEventId
        super.init()
    }
    
    func serialize() -> [String: Any] {
        var dict: [String: Any] = [
            "message": message
        ]
        if let name = name {
            dict["name"] = name
        }
        if let email = email {
            dict["contact_email"] = email
        }
        if let associatedEventId = associatedEventId {
            dict["associated_event_id"] = associatedEventId
        }
        dict["source"] = source.rawValue
        
        return dict
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
