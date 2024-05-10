@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryBreadcrumbReplayConverter: NSObject {
    
    private let supportedNetworkData = Set<String>([
        "status_code",
        "method",
        "response_content_length",
        "request_content_length",
        "http.query",
        "http.fragment"]
    )
    
    func replayBreadcrumbs(from breadcrumbs: [Breadcrumb]) -> [SentryRRWebEvent] {
        breadcrumbs.compactMap { replayBreadcrumb(from: $0) }
    }
    
    private func replayBreadcrumb(from breadcrumb: Breadcrumb) -> SentryRRWebEvent? {
        guard let timestamp = breadcrumb.timestamp else { return nil }
        if breadcrumb.category == "http" {
            return networkSpan(breadcrumb)
        } else if breadcrumb.type == "navigation" {
            return navigationBreadcrumb(breadcrumb)
        } else if breadcrumb.category == "ui.click" {
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "ui.tap", message: "", level: .none, data: nil)
        } else if breadcrumb.type == "system" && breadcrumb.category == "network.event" {
            if breadcrumb.data?["action"] as? String == "NETWORK_LOST" {
                return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "device.connectivity", message: nil, level: .none, data: ["state": "offline"])
            }
            guard let networkType = breadcrumb.data?["network_type"] as? String, !networkType.isEmpty  else { return nil }
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "device.connectivity", message: nil, level: .none, data: ["state": networkType])
        } else if let action = breadcrumb.data?["action"] as? String, action == "BATTERY_CHANGED" {
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp,
                                              category: "device.battery",
                                              message: nil,
                                              level: .none,
                                              data: breadcrumb.data?.filter({ item in item.key == "level" || item.key == "charging" }) ?? [:])
        }
        
        let level = getLevel(breadcrumb: breadcrumb)
        return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: breadcrumb.category, message: breadcrumb.message, level: level, data: breadcrumb.data)
    }
    
    private func navigationBreadcrumb(_ breadcrumb: Breadcrumb) -> SentryRRWebBreadcrumbEvent? {
        guard let timestamp = breadcrumb.timestamp else { return nil }
        
        if breadcrumb.category == "app.lifecycle" {
            guard let state = breadcrumb.data?["state"] else { return nil }
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "app.\(state)", message: nil, level: .none, data: nil)
        } else if let position = breadcrumb.data?["position"] as? String, breadcrumb.category == "device.orientation" && (position == "landscape" || position == "portrait") {
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "device.orientation", message: nil, level: .none, data: ["position": position])
        } else {
            if breadcrumb.data?["state"] as? String == "resumed" {
                guard let screen = breadcrumb.data?["screen"] as? String, let screenIndex = (breadcrumb.data?["screen"] as? String)?.lastIndex(of: ".") else { return nil }
                return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "navigation", message: nil, level: .none, data: ["to": screen[screenIndex...]])
            } else if let to = breadcrumb.data?["screen"] as? String {
                return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "navigation", message: to, level: .none, data: ["to": to])
            } else {
                return nil
            }
        }
    }
    
    private func networkSpan(_ breadcrumb: Breadcrumb) -> SentryRRWebSpanEvent? {
        guard let timestamp = breadcrumb.timestamp, let description = breadcrumb.data?["url"] as? String else { return nil }
        var data = [String: Any]()
        
        breadcrumb.data?.forEach({
            guard supportedNetworkData.contains($0.key) else { return }
            let newKey = $0.key == "response_body_size" ? "bodySize" : $0.key.replacingOccurrences(of: "http.", with: "")
            data[newKey.snakeToCamelCase()] = $0.value
        })
        
        //We dont have end of the request in the breadcrumb.
        return SentryRRWebSpanEvent(timestamp: timestamp, endTimestap: timestamp, operation: "resource.http", description: description, data: data)
    }
    
    private  func getLevel(breadcrumb: Breadcrumb) -> SentryLevel {
        let selector = NSSelectorFromString("level")
        if breadcrumb.responds(to: selector) {
            return (breadcrumb.perform(selector)?.toOpaque() as? SentryLevel) ?? .none
        }
        return .none
    }
}
