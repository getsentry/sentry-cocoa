import Foundation

@_spi(Private) public final class SentryRRWebBreadcrumbEvent: SentryRRWebCustomEvent {
    public convenience init(timestamp: Date, category: String, message: String? = nil, data: [String: Any]? = nil) {
        self.init(timestamp: timestamp, category: category, message: message, level: .none, data: data)
    }

    public init(timestamp: Date, category: String, message: String? = nil, level: SentryLevel, data: [String: Any]? = nil) {
        
        var payload: [String: Any] = ["type": "default", "category": category, "level": level.description, "timestamp": timestamp.timeIntervalSince1970 ]

        if let message = message {
            payload["message"] = message
        }
        
        if let data = data {
            payload["data"] = data
        }
        
        super.init(timestamp: timestamp, tag: "breadcrumb", payload: payload)
    }
}
