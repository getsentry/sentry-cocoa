@_implementationOnly import _SentryPrivate
import Foundation

@objc
enum SentryRRWebEventType: Int {
    case none = 0
    case meta = 4
    case custom = 5
}

@objcMembers
class SentryRRWebEvent: NSObject {
    let type: SentryRRWebEventType
    let timestamp: Date
    let data: [String: Any]?
    
    init(type: SentryRRWebEventType, timestamp: Date, data: [String: Any]?) {
        self.type = type
        self.timestamp = timestamp
        self.data = data
    }
    
    func serialize() -> [String: Any] {
        var result: [String: Any] = [
            "type": type.rawValue,
            "timestamp": SentryDateUtil.millisecondsSince1970(timestamp)
        ]
        
        if let data = data {
            result["data"] = data
        }
        
        return result
    }
}

@objcMembers
class SentryRRWebMetaEvent: SentryRRWebEvent {
    init(timestamp: Date, height: Int, width: Int) {
        super.init(type: .meta, timestamp: timestamp, data: ["href": "", "height": height, "width": width])
    }
}

@objcMembers
class SentryRRWebCustomEvent: SentryRRWebEvent {
    let tag: String
    
    init(timestamp: Date, tag: String, payload: [String: Any]) {
        self.tag = tag
        super.init(type: .custom, timestamp: timestamp, data: ["tag": tag, "payload": payload])
    }
    
}

@objcMembers
class SentryRRWebVideoEvent: SentryRRWebCustomEvent {
    init(timestamp: Date, segmentId: Int, size: Int, duration: TimeInterval, encoding: String, container: String, height: Int, width: Int, frameCount: Int, frameRateType: String, frameRate: Int, left: Int, top: Int) {
        
        super.init(timestamp: timestamp, tag: "video", payload: [
            "segmentId": segmentId,
            "size": size,
            "duration": duration,
            "encoding": encoding,
            "container": container,
            "height": height,
            "width": width,
            "frameCount": frameCount,
            "frameRateType": frameRateType,
            "frameRate": frameRate,
            "left": left,
            "top": top
        ])
    }
}

@objcMembers
class SentryRRWebBreadcrumbEvent: SentryRRWebCustomEvent {
    init(timestamp: Date, category: String, message: String?, level: SentryLevel, data: [String: Any]?) {
        
        var payload: [String: Any] = ["type": "default", "category": category, "level": level.rawValue ]
        
        if let message = message {
            payload["message"] = message
        }
        
        if let data = data {
            payload["data"] = data
        }
        
        super.init(timestamp: timestamp, tag: "breadcrump", payload: payload)
    }
}
