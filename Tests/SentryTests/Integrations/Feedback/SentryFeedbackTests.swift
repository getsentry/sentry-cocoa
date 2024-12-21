import Foundation
@testable import Sentry
import XCTest

class SentryFeedbackTests: XCTestCase {
    func testSerializeWithAllFields() throws {
        let sut = SentryFeedback(message: "Test feedback message", name: "Test feedback provider", email: "test-feedback-provider@sentry.io", source: .widget, associatedEventId: nil, screenshotPNGData: Data())
        
        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertEqual(try XCTUnwrap(serialization["name"] as? String), "Test feedback provider")
        XCTAssertEqual(try XCTUnwrap(serialization["contact_email"] as? String), "test-feedback-provider@sentry.io")
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "widget")
        
        let attachments = sut.attachments()
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(try XCTUnwrap(attachments.first).filename, "screenshot.png")
        XCTAssertEqual(try XCTUnwrap(attachments.first).contentType, "application/png")
    }
    
    func testSerializeWithNoOptionalFields() throws {
        let sut = SentryFeedback(message: "Test feedback message", name: nil, email: nil, source: .widget, associatedEventId: nil, screenshotPNGData: nil)
        
        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertNil(serialization["name"])
        XCTAssertNil(serialization["contact_email"])
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "widget")
        
        let attachments = sut.attachments()
        XCTAssertEqual(attachments.count, 0)
    }
}
