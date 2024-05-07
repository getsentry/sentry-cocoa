import Foundation

@objc
class SentryBreadcrumbReplayConverter: NSObject {
    
    func replayBreadcrumbs(from breadcrumbs: [Breadcrumb]) -> [Breadcrumb] {
        breadcrumbs.compactMap { replayBreadcrumb(from: $0) }
    }
    
    private func replayBreadcrumb(from breadcrumb: Breadcrumb) -> Breadcrumb? {
        let newBreadcrumb = breadcrumb.copy()
//        if newBreadcrumb.category == "http" {
//            
//        } else if newBreadcrumb.type == "navigation" {
//            if newBreadcrumb.category == "app.orientation" {
//                guard let state = newBreadcrumb.data?["state"] else { return nil }
//                newBreadcrumb.category = "app.\(state)"
//            } else if let position = newBreadcrumb.data?["position"] as? String, newBreadcrumb.category == "device.orientation" && position != "landscape" && position != "portrait" {
//                return nil
//            } else {
//                if newBreadcrumb.data?["state"] as? String == "resumed" {
//                    guard let screen = newBreadcrumb.data?["screen"] as? String, let screenIndex = (newBreadcrumb.data?["screen"] as? String)?.lastIndex(of: ".") else { return nil }
//                    newBreadcrumb.data?["to"] = screen[screenIndex...]
//                } else if newBreadcrumb.data?["to"] == nil {
//                    return nil
//                }
//            }
//        } else if newBreadcrumb.category == "ui.click" {
//            newBreadcrumb.category = "ui.tap"
//            newBreadcrumb.message = "" // todo: Build message for ui tap
//        } else if newBreadcrumb.type == "system" && newBreadcrumb.category == "network.event" {
//            newBreadcrumb.category = "device.connectivity"
//            if newBreadcrumb.data?["action"] as? String == "NETWORK_LOST" {
//                newBreadcrumb.data?["state"] = "offline"
//            } else if let networkType = newBreadcrumb.data?["network_type"] as? String, !networkType.isEmpty {
//                newBreadcrumb.data?["state"] = networkType
//            } else {
//                return nil
//            }
//        } else if let action = newBreadcrumb.data?["action"] as? String, action == "BATTERY_CHANGED" {
//            newBreadcrumb.category = "device.battery"
//            newBreadcrumb.data = newBreadcrumb.data?.filter({ item in
//                item.key == "level" || item.key == "charging"
//            })
//        }
        
        return newBreadcrumb
    }
}
