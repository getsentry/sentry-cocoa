@_implementationOnly import _SentryPrivate
import Foundation

@objc class SentryRRWebSpanEvent: SentryRRWebCustomEvent {
    
    init(timestamp: Date, endTimestap: Date, operation: String, description: String, data: [String: Any]) {
        super.init(timestamp: timestamp, tag: "performanceSpan", payload:
                    [
                        "op": operation,
                        "description": description,
                        "startTimestamp": SentryDateUtil.millisecondsSince1970(timestamp),
                        "endTimestamp": SentryDateUtil.millisecondsSince1970(endTimestap),
                        "data": data
                    ]
        )
    }
}
