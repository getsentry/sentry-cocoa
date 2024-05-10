import Foundation
import Nimble
@testable import Sentry
import XCTest

class SentryBreadcrumbReplayConverterTests: XCTestCase {
    func testReplayBreadcrumbsWithEmptyArray() {
        let sut = SentryBreadcrumbReplayConverter()
        let result = sut.replayBreadcrumbs(from: [])
        expect(result.isEmpty) == true
    }
    
    func testReplayBreadcrumbWithNilTimestamp() {
        let sut = SentryBreadcrumbReplayConverter()
        let breadcrumb = Breadcrumb(level: .debug, category: "BreadCrumb")
        let result = sut.replayBreadcrumbs(from: [breadcrumb])
        expect(result) == nil
    }
    
    func testNavigationBreadcrumb() {
        let sut = SentryBreadcrumbReplayConverter()
        let crumb = Breadcrumb(level: .info, category: "app.lifecycle")
        crumb.data = ["state": "foreground"]
        let result = sut.replayBreadcrumbs(from: [crumb])
        
        expect(result.count) == 1
        let event = result.first?.serialize()
        let eventData = event?["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]
        let payloadData = eventPayload?["data"] as? [String: Any]
        
        expect(event?["type"] as? Int) == 5
        expect(event?["type"] as? Int) == 5
        expect(eventData?["tag"] as? String) == "breadcrumb"
        expect(payloadData?["state"] as? String) == "foreground"
        expect(eventPayload?["category"] as? String) == "app.lifecycle"
    }
}
