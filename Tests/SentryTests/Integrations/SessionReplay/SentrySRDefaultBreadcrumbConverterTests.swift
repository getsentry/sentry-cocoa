import Foundation
@_spi(Private) @testable import Sentry
import XCTest

class SentrySRDefaultBreadcrumbConverterTests: XCTestCase {
    
    func testNavigationBreadcrumbAppLifecycleForeground() {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let crumb = Breadcrumb(level: .info, category: "app.lifecycle")
        crumb.type = "navigation"
        crumb.data = ["state": "foreground"]
        let result = sut.convert(from: crumb)
        
        let event = result?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]
        
        XCTAssertEqual(event?["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "app.foreground")
    }

    func testNavigationBreadcrumbAppLifecycleActive() {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let crumb = Breadcrumb(level: .info, category: "app.lifecycle")
        crumb.type = "navigation"
        crumb.data = ["state": "active"]
        let result = sut.convert(from: crumb)

        let event = result?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]

        XCTAssertEqual(event?["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "app.active")
    }

    func testNavigationBreadcrumbAppLifecycleInactive() {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let crumb = Breadcrumb(level: .info, category: "app.lifecycle")
        crumb.type = "navigation"
        crumb.data = ["state": "inactive"]
        let result = sut.convert(from: crumb)

        let event = result?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]

        XCTAssertEqual(event?["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "app.inactive")
    }

    func testNavigationBreadcrumbAppLifecycleBackground() {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let crumb = Breadcrumb(level: .info, category: "app.lifecycle")
        crumb.type = "navigation"
        crumb.data = ["state": "background"]
        let result = sut.convert(from: crumb)

        let event = result?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]

        XCTAssertEqual(event?["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "app.background")
    }
    
    func testNavigationBreadcrumbOrientation() {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let crumb = Breadcrumb(level: .info, category: "device.orientation")
        crumb.type = "navigation"
        crumb.data = ["position": "portrait"]
        let result = sut.convert(from: crumb)
        
        let event = result?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]
        let payloadData = eventPayload?["data"] as? [String: Any]
        
        XCTAssertEqual(event?["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "device.orientation")
        XCTAssertEqual(payloadData?["position"] as? String, "portrait")
    }
    
    func testNavigationBreadcrumbNavigate() {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let crumb = Breadcrumb(level: .info, category: "ui.lifecycle")
        crumb.type = "navigation"
        crumb.data = ["screen": "TestViewController"]
        let result = sut.convert(from: crumb)
        
        let event = result?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]
        let payloadData = eventPayload?["data"] as? [String: Any]
        
        XCTAssertEqual(event?["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "navigation")
        XCTAssertEqual(payloadData?["to"] as? String, "TestViewController")
    }
    
    func testHttpBreadcrumb() throws {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "http")
        let start = Date(timeIntervalSince1970: 5)
        
        breadcrumb.data = [
            "url": "https://test.com",
            "method": "GET",
            "response_body_size": 1_024,
            "http.query": "query=value",
            "http.fragment": "frag",
            "status_code": 200,
            "request_start": start
        ]
        
        let result = try XCTUnwrap(sut.convert(from: breadcrumb) as? SentryRRWebSpanEvent)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        
        XCTAssertEqual(result.timestamp, start)
        XCTAssertEqual(crumbData["tag"] as? String, "performanceSpan")
        XCTAssertEqual(payload["description"] as? String, "https://test.com")
        XCTAssertEqual(payload["op"] as? String, "resource.http")
        XCTAssertEqual(payload["startTimestamp"] as? Double, start.timeIntervalSince1970)
        XCTAssertEqual(payload["endTimestamp"] as? Double, breadcrumb.timestamp?.timeIntervalSince1970)
        XCTAssertEqual(payloadData["statusCode"] as? Int, 200)
        XCTAssertEqual(payloadData["query"] as? String, "query=value")
        XCTAssertEqual(payloadData["fragment"] as? String, "frag")
    }
    
    func testTouchBreadcrumb() throws {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "touch")
        breadcrumb.message = "TestTapped:"
        
        let result = try XCTUnwrap(sut.convert(from: breadcrumb) as? SentryRRWebBreadcrumbEvent)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        
        XCTAssertEqual(payload["category"] as? String, "ui.tap")
        XCTAssertEqual(payload["message"] as? String, "TestTapped:")
    }
    
    func testConnectivityBreadcrumb() throws {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "device.connectivity")
        breadcrumb.type = "connectivity"
        breadcrumb.data = ["connectivity": "Wifi"]
        
        let result = try XCTUnwrap(sut.convert(from: breadcrumb) as? SentryRRWebBreadcrumbEvent)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        
        XCTAssertEqual(payload["category"] as? String, "device.connectivity")
        XCTAssertEqual(payloadData["state"] as? String, "Wifi")
    }
    
    func testBatteryBreadcrumb() throws {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "device.event")
        breadcrumb.type = "system"
        breadcrumb.data = ["level": 0.5, "plugged": true, "action": "BATTERY_STATE_CHANGE"]
        
        let result = try XCTUnwrap(sut.convert(from: breadcrumb) as? SentryRRWebBreadcrumbEvent)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        
        XCTAssertEqual(payload["category"] as? String, "device.battery")
        XCTAssertEqual(payloadData["level"] as? Double, 0.5)
        XCTAssertEqual(payloadData["charging"] as? Bool, true)
    }
    
    func testCustomBreadcrumbs() throws {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "MyApp.MyBreadcrumb")
        breadcrumb.type = "interation"
        breadcrumb.data = ["SomeInfo": "Info"]
        breadcrumb.message = "Custom message"
        
        let result = try XCTUnwrap(sut.convert(from: breadcrumb) as? SentryRRWebBreadcrumbEvent)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        
        XCTAssertEqual(payload["category"] as? String, "MyApp.MyBreadcrumb")
        XCTAssertEqual(payload["message"] as? String, "Custom message")
        XCTAssertEqual(payloadData["SomeInfo"] as? String, "Info")
    }

    // MARK: - Network Details (partial data)

    /// All network detail fields are optional. These tests document the SDK's
    /// current serialization behavior — when fields on `SentryReplayNetworkDetails`
    /// are unset, they are simply omitted from the RRWebEvent payload rather than
    /// replaced with defaults or causing the details to be dropped entirely.

    func testHttpBreadcrumb_withNetworkDetails_onlyStatusCode() throws {
        let payloadData = try convertHttpBreadcrumbWithNetworkDetails { details in
            details.setResponse(statusCode: 200, size: nil, bodyData: nil, contentType: nil, allHeaders: nil, configuredHeaders: nil)
        }

        XCTAssertEqual(payloadData["statusCode"] as? Int, 200)
        XCTAssertNil(payloadData["method"], "method should be absent when not set")
        XCTAssertNil(payloadData["requestBodySize"])
        XCTAssertNil(payloadData["responseBodySize"])
        // Only statusCode should be present — nothing else leaks through.
        XCTAssertEqual(payloadData.count, 1)
    }

    func testHttpBreadcrumb_withNetworkDetails_onlyMethod() throws {
        let payloadData = try convertHttpBreadcrumbWithNetworkDetails(method: "POST") { _ in
            // method is set via the initializer; no response/request set
        }

        XCTAssertEqual(payloadData["method"] as? String, "POST")
        XCTAssertNil(payloadData["statusCode"], "statusCode should be absent when no response is set")
        XCTAssertNil(payloadData["requestBodySize"])
        XCTAssertNil(payloadData["responseBodySize"])
        // Only method should be present.
        XCTAssertEqual(payloadData.count, 1)
    }

    func testHttpBreadcrumb_withNetworkDetails_onlyResponseBodySize() throws {
        let payloadData = try convertHttpBreadcrumbWithNetworkDetails { details in
            details.setResponse(statusCode: 0, size: NSNumber(value: 512), bodyData: nil, contentType: nil, allHeaders: nil, configuredHeaders: nil)
        }

        XCTAssertEqual(payloadData["responseBodySize"] as? Int, 512)
        XCTAssertNil(payloadData["requestBodySize"])
        // Expected keys: statusCode (set to 0 by setResponse),
        // responseBodySize, and response (containing size).
        XCTAssertEqual(payloadData.count, 3)
    }

    func testHttpBreadcrumb_withNetworkDetails_onlyRequestBodySize() throws {
        let payloadData = try convertHttpBreadcrumbWithNetworkDetails { details in
            details.setRequest(size: NSNumber(value: 256), bodyData: nil, contentType: nil, allHeaders: nil, configuredHeaders: nil)
        }

        XCTAssertEqual(payloadData["requestBodySize"] as? Int, 256)
        XCTAssertNil(payloadData["responseBodySize"])
        // Expected keys: requestBodySize and request (containing size).
        XCTAssertEqual(payloadData.count, 2)
    }

    func testHttpBreadcrumb_withNetworkDetails_emptyDetails_producesNoExtraKeys() throws {
        let payloadData = try convertHttpBreadcrumbWithNetworkDetails { _ in }

        XCTAssertNil(payloadData["method"])
        XCTAssertNil(payloadData["statusCode"])
        XCTAssertNil(payloadData["requestBodySize"])
        XCTAssertNil(payloadData["responseBodySize"])
        XCTAssertNil(payloadData["request"])
        XCTAssertNil(payloadData["response"])
        XCTAssertEqual(payloadData.count, 0, "No keys should be present when details is empty")
    }

    // MARK: - Helpers

    /// Creates an HTTP breadcrumb with a `SentryReplayNetworkDetails` attached,
    /// runs it through the converter, and returns the payload data dictionary.
    ///
    /// - Parameter method: Optional HTTP method to set on the network details.
    private func convertHttpBreadcrumbWithNetworkDetails(
        method: String? = nil,
        configure: (SentryReplayNetworkDetails) -> Void
    ) throws -> [String: Any] {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "http")
        let start = Date(timeIntervalSince1970: 5)

        let networkDetails = SentryReplayNetworkDetails(method: method)
        configure(networkDetails)

        breadcrumb.data = [
            "url": "https://test.com",
            "request_start": start,
            SentryReplayNetworkDetails.replayNetworkDetailsKey: networkDetails
        ]

        let result = try XCTUnwrap(sut.convert(from: breadcrumb) as? SentryRRWebSpanEvent)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        return try XCTUnwrap(payload["data"] as? [String: Any])
    }

    func testSerializedSRBreadcrumbLevelIsString() throws {
        let sut = SentrySRDefaultBreadcrumbConverter()
        let breadcrumb = Breadcrumb()
        breadcrumb.level = .error

        let result = try XCTUnwrap(sut.convert(from: breadcrumb) as? SentryRRWebBreadcrumbEvent)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])

        XCTAssertEqual(payload["level"] as! String, "error")
    }
}
