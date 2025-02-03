@testable import Sentry
import XCTest

class SentryRequestTests: XCTestCase {
    func testSerialize() {
        let request = TestData.request
        
        let actual = request.serialize()

        XCTAssertEqual(request.url, actual["url"] as? String)
        XCTAssertEqual(request.queryString, actual["query_string"] as? String)
        XCTAssertEqual(request.fragment, actual["fragment"] as? String)
        XCTAssertEqual(request.cookies, actual["cookies"] as? String)
        XCTAssertEqual(request.method, actual["method"] as? String)
        XCTAssertEqual(request.bodySize, actual["body_size"] as? NSNumber)
        
        XCTAssertEqual(request.headers, actual["headers"] as? Dictionary)
    }
    
    func testNoHeaders() {
        let request = TestData.request
        request.headers = nil
        
        let actual = request.serialize()
        
        XCTAssertNil(actual["headers"])
    }
    
    func testNoBodySize() {
        let request = TestData.request
        request.bodySize = 0
        
        let actual = request.serialize()
        
        XCTAssertNil(actual["body_size"])
    }
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let request = TestData.request
        let actual = request.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryRequest?)
        
        // Assert
        XCTAssertEqual(request.bodySize, decoded.bodySize)
        XCTAssertEqual(request.cookies, decoded.cookies)
        XCTAssertEqual(request.headers, decoded.headers)
        XCTAssertEqual(request.fragment, decoded.fragment)
        XCTAssertEqual(request.method, decoded.method)
        XCTAssertEqual(request.queryString, decoded.queryString)
        XCTAssertEqual(request.url, decoded.url)
    }

    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let request = SentryRequest()
        let actual = request.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryRequest?)
        
        // Assert
        XCTAssertNil(decoded.bodySize)
        XCTAssertNil(decoded.cookies)
        XCTAssertNil(decoded.headers)
        XCTAssertNil(decoded.fragment)
        XCTAssertNil(decoded.method)
        XCTAssertNil(decoded.queryString)
        XCTAssertNil(decoded.url)
    }

    func testDecode_OnlyWithBodySize() throws {
        // Arrange
        let request = SentryRequest()
        request.bodySize = 100
        let actual = request.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))

        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryRequest?)

        // Assert
        XCTAssertEqual(request.bodySize, decoded.bodySize)
        XCTAssertNil(decoded.cookies)
        XCTAssertNil(decoded.headers)
        XCTAssertNil(decoded.fragment)
        XCTAssertNil(decoded.method)
        XCTAssertNil(decoded.queryString)
        XCTAssertNil(decoded.url)   
    }
}
