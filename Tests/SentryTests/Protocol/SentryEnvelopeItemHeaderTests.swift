@testable import Sentry
import SentryTestUtils
import XCTest

class SentryEnvelopeItemHeaderTests: XCTestCase {
 
    func test_SentryEnvelopeItemHeaderSerialization_DefaultInit() {
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10)

        let data = header.serialize()
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertNil(data["filename"])
        XCTAssertNil(data["content_type"])
        XCTAssertEqual(data.count, 2)
    }
    
    func test_SentryEnvelopeItemHeaderSerialization_WithContentType() {
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, contentType: "text/html")

        let data = header.serialize()
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertNil(data["filename"])
        XCTAssertEqual(data["content_type"] as? String, "text/html")
        XCTAssertEqual(data.count, 3)
    }
    
    func test_SentryEnvelopeItemHeaderSerialization_WithItemCount() {
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, contentType: "text/html", itemCount: NSNumber(value: 3))
        
        let data = header.serialize()
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertNil(data["filename"])
        XCTAssertEqual(data["content_type"] as? String, "text/html")
        XCTAssertEqual(data["item_count"] as? NSNumber, NSNumber(value: 3))
        XCTAssertEqual(data.count, 4)
    }
    
    func test_SentryEnvelopeItemHeaderSerialization_WithFilename() {
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, filenname: "SomeFileName", contentType: "text/html")
        
        let data = header.serialize()
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertEqual(data["filename"] as? String, "SomeFileName")
        XCTAssertEqual(data["content_type"] as? String, "text/html")
        XCTAssertEqual(data.count, 4)
    }
}
