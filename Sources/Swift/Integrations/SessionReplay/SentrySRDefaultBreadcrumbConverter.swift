// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

@objc
@_spi(Private) public protocol SentryReplayBreadcrumbConverter: NSObjectProtocol {
    func convert(from breadcrumb: Breadcrumb) -> SentryRRWebEventProtocol?
}

@objcMembers
@_spi(Private) public class SentrySRDefaultBreadcrumbConverter: NSObject, SentryReplayBreadcrumbConverter {
    
    private let supportedNetworkData = Set<String>([
        "status_code",
        "method",
        "response_body_size",
        "request_body_size",
        "http.query",
        "http.fragment"]
    )
    
    /**
     * This function will convert the SDK breadcrumbs to session replay breadcrumbs in a format that the front-end understands.
     * Any deviation in the information will cause the breadcrumb or the information itself to be discarded
     * in order to avoid unknown behavior in the front-end.
     */
    public func convert(from breadcrumb: Breadcrumb) -> SentryRRWebEventProtocol? {
        guard let timestamp = breadcrumb.timestamp else { return nil }
        if breadcrumb.category == "http" {
            return networkSpan(breadcrumb)
        } else if breadcrumb.type == "navigation" {
            return navigationBreadcrumb(breadcrumb)
        } else if breadcrumb.category == "touch" {
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "ui.tap", message: breadcrumb.message)
        } else if breadcrumb.type == "connectivity" && breadcrumb.category == "device.connectivity" {
            guard let networkType = breadcrumb.data?["connectivity"] as? String, !networkType.isEmpty  else { return nil }
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "device.connectivity", data: ["state": networkType])
        } else if let action = breadcrumb.data?["action"] as? String, action == "BATTERY_STATE_CHANGE" {
            var data = breadcrumb.data?.filter({ item in item.key == "level" || item.key == "plugged" }) ?? [:]
            
            data["charging"] = data["plugged"]
            data["plugged"] = nil
            
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp,
                                              category: "device.battery",
                                              data: data)
        }
        
        let level = breadcrumb.level
        return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: breadcrumb.category, message: breadcrumb.message, level: level, data: breadcrumb.data)
    }
    
    private func navigationBreadcrumb(_ breadcrumb: Breadcrumb) -> SentryRRWebBreadcrumbEvent? {
        guard let timestamp = breadcrumb.timestamp else { return nil }
        
        if breadcrumb.category == "app.lifecycle" {
            guard let state = breadcrumb.data?["state"] else { return nil }
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "app.\(state)")
        } else if let position = breadcrumb.data?["position"] as? String, breadcrumb.category == "device.orientation" {
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "device.orientation", data: ["position": position])
        } else {
            if let to = breadcrumb.data?["screen"] as? String {
                return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "navigation", message: to, data: ["to": to])
            } else {
                return nil
            }
        }
    }
    
    private func networkSpan(_ breadcrumb: Breadcrumb) -> SentryRRWebSpanEvent? {
        guard let timestamp = breadcrumb.timestamp,
              let description = breadcrumb.data?["url"] as? String,
              let startTimestamp = breadcrumb.data?["request_start"] as? Date
        else { return nil }
        var data = [String: Any]()
        
        breadcrumb.data?.forEach({ (key, value) in
            guard supportedNetworkData.contains(key) else { return }
            let newKey = key.replacingOccurrences(of: "http.", with: "")
            data[newKey.snakeToCamelCase()] = value
        })
        
        // Serialize here (not when creating the breadcrumb) to give completionHandler time to
        // populate response data before setState(.completed) triggers breadcrumb creation.
        if let networkDetails = breadcrumb.data?[SentryReplayNetworkDetails.replayNetworkDetailsKey] as? SentryReplayNetworkDetails {
            addNetworkDetails(from: networkDetails.serialize(), to: &data)
        }
        
        //We dont have end of the request in the breadcrumb.
        return SentryRRWebSpanEvent(timestamp: startTimestamp, endTimestamp: timestamp, operation: "resource.http", description: description, data: data)
    }
    
    // Network details show up after selecting a request from the 'Network' tab of a session replay
    // If any fields here are not populated, the UI will silently omit them but not report any error.
    private func addNetworkDetails(from networkData: [String: Any], to data: inout [String: Any]) {
        // Add top-level network metadata
        if let method = networkData["method"] as? String {
            data["method"] = method
        }
        if let statusCode = networkData["statusCode"] as? NSNumber {
            data["statusCode"] = statusCode
        }
        if let requestBodySize = networkData["requestBodySize"] as? NSNumber {
            data["requestBodySize"] = requestBodySize
        }
        if let responseBodySize = networkData["responseBodySize"] as? NSNumber {
            data["responseBodySize"] = responseBodySize
        }
        
        // Process request and response details using shared logic
        if let request = networkData["request"] as? [String: Any] {
            if let requestData = processRequestOrResponseData(request), !requestData.isEmpty {
                data["request"] = requestData
            }
        }
        
        if let response = networkData["response"] as? [String: Any] {
            if let responseData = processRequestOrResponseData(response), !responseData.isEmpty {
                data["response"] = responseData
            }
        }
    }
    
    private func processRequestOrResponseData(_ sourceData: [String: Any]) -> [String: Any]? {
        var result = [String: Any]()
        
        if let size = sourceData["size"] as? NSNumber {
            result["size"] = size
        }
        
        if let body = sourceData["body"] as? [String: Any] {
            if let bodyContent = body["body"] {
                result["body"] = bodyContent
            }
            if let warnings = body["warnings"] as? [String], !warnings.isEmpty {
                result["_meta"] = ["warnings": warnings]
            }
        }
        
        if let headers = sourceData["headers"] as? [String: String], !headers.isEmpty {
            result["headers"] = headers
        }
        
        return result.isEmpty ? nil : result
    }
}
// swiftlint:enable missing_docs
