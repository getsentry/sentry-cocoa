@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryRRWebBreadcrumbEvent: SentryRRWebCustomEvent {
    init(timestamp: Date, category: String, message: String?, level: SentryLevel, data: [String: Any]?) {
        
        var payload: [String: Any] = ["type": "default", "category": category, "level": level.rawValue, "timestamp": timestamp.timeIntervalSince1970 ]
        
        if let message = message {
            payload["message"] = message
        }
        
        if let data = data {
            payload["data"] = data
        }
        
        super.init(timestamp: timestamp, tag: "breadcrumb", payload: payload)
    }
}
