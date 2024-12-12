import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * A user feedback item that serializes to an envelope with the format described at
 * https://develop.sentry.dev/application-architecture/feedback-architecture/#feedback-events.
 * - seealso: Reference implementation: https://github.com/getsentry/sentry-javascript/blob/be9edf161f72bb0b9ccf38d70297b798054b3ce3/packages/feedback/src/core/sendFeedback.ts#L77-L116
 *
 * Schema of the event envelope:
 *
 ```
     event[”contexts”][”feedback”] = {
     "name": <user-provided>,
     "contact_email": <user-provided>,
     "message": <user-provided>,
     "url": <referring web page>,
     "source": <developer-provided, ex: "widget">,
     "associated_event_id": <developer-provided, should be a valid error event in the same project>
 ```
 * A more complete example from the javascript reference implementation:
 ```
   {
     "type": "feedback",
     "event_id": "d2132d31b39445f1938d7e21b6bf0ec4",
     "timestamp": 1597977777.6189718,
     "dist": "1.12",
     "platform": "javascript",
     "environment": "production",
     "release": 42,
     "tags": {"transaction": "/organizations/:orgId/performance/:eventSlug/"},
     "sdk": {"name": "name", "version": "version"},
     "user": {
         "id": "123",
         "username": "user",
         "email": "user@site.com",
         "ip_address": "192.168.11.12",
     },
     "request": {
         "url": None,
         "headers": {
             "user-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15"
         },
     },
     "contexts": {
         "feedback": {
             "message": "test message",
             "contact_email": "test@example.com",
             "type": "feedback",
         },
         "trace": {
             "trace_id": "4C79F60C11214EB38604F4AE0781BFB2",
             "span_id": "FA90FDEAD5F74052",
             "type": "trace",
         },
         "replay": {
             "replay_id": "e2d42047b1c5431c8cba85ee2a8ab25d",
         },
     },
   }
 ```
 * - note: screenshots are provided as envelope attachments, at most 1 per feedback.
}
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
    
    /**
     * - note: Currently there is only a single attachment possible, for the screenshot, of which there can be only one.
     * - seealso: Reference implementation: https://github.com/getsentry/sentry-javascript/blob/be9edf161f72bb0b9ccf38d70297b798054b3ce3/packages/feedback/src/screenshot/integration.ts#L31-L36
     ```
        const attachment: Attachment = {
           data,
           filename: 'screenshot.png',
           contentType: 'application/png',
           // attachmentType?: string;
         };
     ```
     */
    func attachments() -> [Attachment] {
        var items = [Attachment]()
        if let screenshot = screenshot {
            items.append(Attachment(data: screenshot, filename: "screenshot.png", contentType: "application/png"))
        }
        return items
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
