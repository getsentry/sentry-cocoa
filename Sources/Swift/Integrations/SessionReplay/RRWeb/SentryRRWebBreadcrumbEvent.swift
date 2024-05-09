import Foundation

@objcMembers
class SentryRRWebBreadcrumbEvent: SentryRRWebCustomEvent {
    init(timestamp: Date, category: String, message: String?, level: Int, data: [String: Any]?) {
        
        var payload: [String: Any] = ["type": "default", "category": category, "level": level ]
        
        if let message = message {
            payload["message"] = message
        }
        
        if let data = data {
            payload["data"] = data
        }
        
        super.init(timestamp: timestamp, tag: "breadcrump", payload: payload)
    }
}
