import Foundation
@testable import Sentry
import XCTest

class SentryBreadcrumbReplayConverterTests: XCTestCase {
    func testReplayBreadcrumbsWithEmptyArray() {
        let sut = SentryBreadcrumbReplayConverter()
        let result = sut.replayBreadcrumbs(from: [])
        XCTAssertTrue(result.isEmpty)
    }
    
    func testReplayBreadcrumbWithNilTimestamp() {
        let sut = SentryBreadcrumbReplayConverter()
        let breadcrumb = Breadcrumb(level: .debug, category: "Breadcrumb")
        breadcrumb.timestamp = nil
        let result = sut.replayBreadcrumbs(from: [breadcrumb])
        XCTAssertEqual(result.count, 0)
    }
    
    func testNavigationBreadcrumbAppLifecycle() {
        let sut = SentryBreadcrumbReplayConverter()
        let crumb = Breadcrumb(level: .info, category: "app.lifecycle")
        crumb.type = "navigation"
        crumb.data = ["state": "foreground"]
        let result = sut.replayBreadcrumbs(from: [crumb])
        
        XCTAssertEqual(result.count, 1)
        let event = result.first?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]
        
        XCTAssertEqual(event?["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "app.foreground")
    }
    
    func testNavigationBreadcrumbOrientation() {
        let sut = SentryBreadcrumbReplayConverter()
        let crumb = Breadcrumb(level: .info, category: "device.orientation")
        crumb.type = "navigation"
        crumb.data = ["position": "portrait"]
        let result = sut.replayBreadcrumbs(from: [crumb])
        
        XCTAssertEqual(result.count, 1)
        let event = result.first?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]
        let payloadData = eventPayload?["data"] as? [String: Any]
        
        XCTAssertEqual(event?["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "device.orientation")
        XCTAssertEqual(payloadData?["position"] as? String, "portrait")
    }
    
    func testNavigationBreadcrumbNavigate() {
        let sut = SentryBreadcrumbReplayConverter()
        let crumb = Breadcrumb(level: .info, category: "ui.lifecycle")
        crumb.type = "navigation"
        crumb.data = ["screen": "TestViewController"]
        let result = sut.replayBreadcrumbs(from: [crumb])
        
        XCTAssertEqual(result.count, 1)
        let event = result.first?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]
        let payloadData = eventPayload?["data"] as? [String: Any]
        
        XCTAssertEqual(event?["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "navigation")
        XCTAssertEqual(payloadData?["to"] as? String, "TestViewController")
    }
    
    func testHttpBreadcrumb() throws {
        let sut = SentryBreadcrumbReplayConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "http")
        
        breadcrumb.data = [
            "url": "https://test.com",
            "method": "GET",
            "response_body_size": 1_024,
            "http.query": "query=value",
            "http.fragment": "frag",
            "status_code": 200
        ]
        
        let result = try XCTUnwrap(sut.replayBreadcrumbs(from: [breadcrumb]).first)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        
        XCTAssertEqual(result.timestamp, breadcrumb.timestamp)
        XCTAssertEqual(crumbData["tag"] as? String, "performanceSpan")
        XCTAssertEqual(payload["description"] as? String, "https://test.com")
        XCTAssertEqual(payload["op"] as? String, "resource.http")
        XCTAssertEqual(payloadData["statusCode"] as? Int, 200)
        XCTAssertEqual(payloadData["query"] as? String, "query=value")
        XCTAssertEqual(payloadData["fragment"] as? String, "frag")
    }
    
    func testTouchBreadcrumb() throws {
        let sut = SentryBreadcrumbReplayConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "touch")
        breadcrumb.message = "TestTapped:"
        
        let result = try XCTUnwrap(sut.replayBreadcrumbs(from: [breadcrumb]).first)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        
        XCTAssertEqual(payload["category"] as? String, "ui.tap")
        XCTAssertEqual(payload["message"] as? String, "TestTapped:")
    }
    
    func testConnectivityBreadcrumb() throws {
        let sut = SentryBreadcrumbReplayConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "device.connectivity")
        breadcrumb.type = "connectivity"
        breadcrumb.data = ["connectivity": "Wifi"]
        
        let result = try XCTUnwrap(sut.replayBreadcrumbs(from: [breadcrumb]).first)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        
        XCTAssertEqual(payload["category"] as? String, "device.connectivity")
        XCTAssertEqual(payloadData["state"] as? String, "Wifi")
    }
    
    func testBatteryBreadcrumb() throws {
        let sut = SentryBreadcrumbReplayConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "device.event")
        breadcrumb.type = "system"
        breadcrumb.data = ["level": 0.5, "plugged": true, "action": "BATTERY_STATE_CHANGE"]
        
        let result = try XCTUnwrap(sut.replayBreadcrumbs(from: [breadcrumb]).first)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        
        XCTAssertEqual(payload["category"] as? String, "device.battery")
        XCTAssertEqual(payloadData["level"] as? Double, 0.5)
        XCTAssertEqual(payloadData["charging"] as? Bool, true)
    }
    
    func testCustomBreadcrumbs() throws {
        let sut = SentryBreadcrumbReplayConverter()
        let breadcrumb = Breadcrumb(level: .info, category: "MyApp.MyBreadcrumb")
        breadcrumb.type = "interation"
        breadcrumb.data = ["SomeInfo": "Info"]
        breadcrumb.message = "Custom message"
        
        let result = try XCTUnwrap(sut.replayBreadcrumbs(from: [breadcrumb]).first)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        
        XCTAssertEqual(payload["category"] as? String, "MyApp.MyBreadcrumb")
        XCTAssertEqual(payload["message"] as? String, "Custom message")
        XCTAssertEqual(payloadData["SomeInfo"] as? String, "Info")
    }
}
