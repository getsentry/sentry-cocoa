import Foundation

/// Adds additional information about what happened to an event.
/// @deprecated Use `SentryFeedback`.
@objc(SentryUserFeedback)
@available(*, deprecated, message: "Use SentryFeedback.")
public class SentryUserFeedback: NSObject, SentrySerializable {
    
    /// The eventId of the event to which the user feedback is associated.
    @objc public private(set) var eventId: SentryId
    
    /// The name of the user.
    @objc public var name: String
    
    /// The email of the user.
    @objc public var email: String
    
    /// Comments of the user about what happened.
    @objc public var comments: String
    
    /// Initializes SentryUserFeedback and sets the required eventId.
    /// - Parameter eventId: The eventId of the event to which the user feedback is associated.
    @objc public init(eventId: SentryId) {
        self.eventId = eventId
        self.email = ""
        self.name = ""
        self.comments = ""
        super.init()
    }
    
    public func serialize() -> [String: Any] {
        return [
            "event_id": eventId.sentryIdString,
            "email": email,
            "name": name,
            "comments": comments
        ]
    }
} 
