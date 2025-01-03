@_implementationOnly import _SentryPrivate
import Foundation

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
    
    /// PNG data for the screenshot image
    var screenshot: Data?
    
    /// The event id that this feedback is associated with, like a crash report.
    var associatedEventId: String?

    /// - parameter screenshot Image encoded as PNG data.
    init(message: String, name: String?, email: String?, source: Source = .widget, associatedEventId: String? = nil, screenshot: Data? = nil) {
        self.eventId = SentryId()
        self.name = name
        self.email = email
        self.message = message
        self.source = source
        self.associatedEventId = associatedEventId
        self.screenshot = screenshot
        super.init()
    }
    
    func serialize() -> [String: Any] {
        let numberOfOptionalItems = (name == nil ? 0 : 1) + (email == nil ? 0 : 1) + (associatedEventId == nil ? 0 : 1)
        var dict = [String: Any](minimumCapacity: 2 + numberOfOptionalItems)
        dict["message"] = message
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
    
    func dataDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "message": message
        ]
        if let name = name {
            dict["name"] = name
        }
        if let email = email {
            dict["email"] = email
        }
        if let screenshot = screenshot {
            dict["attachments"] = [screenshot]
        }
        return dict
    }
    
    /**
     * - note: Currently there is only a single attachment possible, for the screenshot, of which there can be only one.
     */
    func attachments() -> [Attachment] {
        var items = [Attachment]()
        if let screenshot = screenshot {
            items.append(Attachment(data: screenshot, filename: "screenshot.png", contentType: "application/png"))
        }
        return items
    }
}
