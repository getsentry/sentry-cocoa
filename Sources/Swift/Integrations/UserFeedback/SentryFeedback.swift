@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
public final class SentryFeedback: NSObject {
    @objc public enum SentryFeedbackSource: Int {
        public var serialize: String {
            switch self {
            case .widget: return "widget"
            case .custom: return "custom"
            }
        }
        
        case widget
        case custom
    }
    
    var name: String?
    var email: String?
    var message: String
    var source: SentryFeedbackSource
    @_spi(Private) public let eventId: SentryId

    /// Attachments for this feedback submission, like a screenshot.
    private var attachments: [Attachment]?

    /// The event id that this feedback is associated with, like a crash report.
    var associatedEventId: SentryId?

    /// - parameters:
    ///   - associatedEventId The ID for an event you'd like associated with the feedback.
    ///   - attachments Attachment objects for any files to include with the feedback.
    @objc public init(message: String, name: String?, email: String?, source: SentryFeedbackSource = .widget, associatedEventId: SentryId? = nil, attachments: [Attachment]? = nil) {
        self.eventId = SentryId()
        self.name = name
        self.email = email
        self.message = message
        self.source = source
        self.associatedEventId = associatedEventId
        self.attachments = attachments
        super.init()
    }
}

extension SentryFeedback: SentrySerializable { }

extension SentryFeedback {

    public func serialize() -> [String: Any] {
        return internalSerialize()
    }

    private func internalSerialize() -> [String: Any] {
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
            dict["associated_event_id"] = associatedEventId.sentryIdString
        }
        dict["source"] = source.serialize
        
        return dict
    }
}
 
// MARK: Public
extension SentryFeedback {
    /// - note: This dictionary is to pass to the block `SentryUserFeedbackConfiguration.onSubmitSuccess`, describing the contents submitted. This is different from the serialized form of the feedback for envelope transmission, because there are some internal details in that serialization that are irrelevant to the consumer and are not available at the time `onSubmitSuccess` is called.
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
        if let attachments = attachments {
            dict["attachments"] = attachments.map { $0.dataDictionary() }
        }
        return dict
    }
    
    /**
     * Returns all attachments for inclusion in the feedback envelope.
     */
    @_spi(Private) public func attachmentsForEnvelope() -> [Attachment] {
        return attachments ?? []
    }
}

// MARK: Attachment Serialization
extension Attachment {
    func dataDictionary() -> [String: Any] {
        var attDict: [String: Any] = ["filename": filename]
        if let data = data {
            attDict["data"] = data
        }
        if let path = path {
            attDict["path"] = path
        }
        if let contentType = contentType {
            attDict["contentType"] = contentType
        }
        return attDict
    }
}
