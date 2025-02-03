@testable import Sentry
import XCTest

class SentryBreadcrumbTests: XCTestCase {

    private class Fixture {
        let breadcrumb: Breadcrumb
        let date: Date
        
        let category = "category"
        let type = "user"
        let origin = "origin"
        let message = "Click something"
        
        init() {
            date = Date(timeIntervalSince1970: 10)
            
            breadcrumb = Breadcrumb()
            breadcrumb.level = SentryLevel.info
            breadcrumb.timestamp = date
            breadcrumb.category = category
            breadcrumb.type = type
            breadcrumb.origin = origin
            breadcrumb.message = message
            breadcrumb.data = ["some": ["data": "data", "date": date] as [String: Any]]
            breadcrumb.setValue(["foo": "bar"], forKey: "unknown")
        }
        
        var dateAs8601String: String {
            return sentry_toIso8601String(date as Date)
        }
    }
    
    private let fixture = Fixture()

    func testInitWithDictionary() {
        let dict: [AnyHashable: Any] = [
            "level": "info",
            "timestamp": fixture.dateAs8601String,
            "category": fixture.category,
            "type": fixture.type,
            "origin": fixture.origin,
            "message": fixture.message,
            "data": ["foo": "bar"],
            "foo": "bar" // Unknown
        ]
        let breadcrumb = PrivateSentrySDKOnly.breadcrumb(with: dict)
        
        XCTAssertEqual(breadcrumb.level, SentryLevel.info)
        XCTAssertEqual(breadcrumb.timestamp, fixture.date)
        XCTAssertEqual(breadcrumb.category, fixture.category)
        XCTAssertEqual(breadcrumb.type, fixture.type)
        XCTAssertEqual(breadcrumb.origin, fixture.origin)
        XCTAssertEqual(breadcrumb.message, fixture.message)
        XCTAssertEqual(breadcrumb.data as? [String: String], ["foo": "bar"])
        XCTAssertEqual(breadcrumb.value(forKey: "unknown") as? NSDictionary, ["foo": "bar"])
    }
    
    func testHash() {
        let fixture2 = Fixture()
        XCTAssertEqual(fixture.breadcrumb.hash(), fixture2.breadcrumb.hash())
        
        let breadcrumb2 = fixture2.breadcrumb
        breadcrumb2.type = "other type"
        XCTAssertNotEqual(fixture.breadcrumb.hash(), breadcrumb2.hash())
    }
    
    func testIsEqualToSelf() {
        XCTAssertEqual(fixture.breadcrumb, fixture.breadcrumb)
        XCTAssertTrue(fixture.breadcrumb.isEqual(to: fixture.breadcrumb))
    }
    
    func testIsNotEqualToOtherClass() {
        XCTAssertFalse(fixture.breadcrumb.isEqual(1))
    }
    
    func testIsNotEqualToNil() {
        XCTAssertFalse(fixture.breadcrumb.isEqual(nil))
    }
    
    func testIsNotEqualIfOriginDiffers() {
        let fixture2 = Fixture()
        fixture2.breadcrumb.origin = "origin2"
        XCTAssertNotEqual(fixture.breadcrumb, fixture2.breadcrumb)
    }

    func testIsEqualToOtherInstanceWithSameValues() {
        let fixture2 = Fixture()
        XCTAssertEqual(fixture.breadcrumb, fixture2.breadcrumb)
    }
    
    func testNotIsEqual() {
        testIsNotEqual { breadcrumb in breadcrumb.level = SentryLevel.error }
        testIsNotEqual { breadcrumb in breadcrumb.category = "" }
        testIsNotEqual { breadcrumb in breadcrumb.timestamp = Date() }
        testIsNotEqual { breadcrumb in breadcrumb.type = "" }
        testIsNotEqual { breadcrumb in breadcrumb.origin = "" }
        testIsNotEqual { breadcrumb in breadcrumb.message = "" }
        testIsNotEqual { breadcrumb in breadcrumb.data?.removeAll() }
        testIsNotEqual { breadcrumb in breadcrumb.setValue(nil, forKey: "unknown") }
    }
    
    private func testIsNotEqual(block: (Breadcrumb) -> Void ) {
        let breadcrumb = Fixture().breadcrumb
        block(breadcrumb)
        XCTAssertNotEqual(fixture.breadcrumb, breadcrumb)
    }
    
    func testSerialize() {
        let crumb = fixture.breadcrumb
        let actual = crumb.serialize()
        
        // Changing the original doesn't modify the serialized
        crumb.level = SentryLevel.debug
        crumb.timestamp = nil
        crumb.category = ""
        crumb.type = ""
        crumb.origin = ""
        crumb.message = ""
        crumb.data = nil
        crumb.setValue(nil, forKey: "unknown")
        
        XCTAssertEqual("info", actual["level"] as? String)
        XCTAssertEqual(fixture.dateAs8601String, actual["timestamp"] as? String)
        XCTAssertEqual(fixture.category, actual["category"] as? String)
        XCTAssertEqual(fixture.type, actual["type"] as? String)
        XCTAssertEqual(fixture.origin, actual["origin"] as? String)
        XCTAssertEqual(fixture.message, actual["message"] as? String)
        XCTAssertEqual(["some": ["data": "data", "date": fixture.dateAs8601String]], actual["data"] as? Dictionary)
        XCTAssertEqual("bar", actual["foo"] as? String)
    }
    
    func testDescription() {
        let crumb = fixture.breadcrumb
        let actual = crumb.description
        
        let serialaziedString = NSString(format: "<SentryBreadcrumb: %p, %@>", crumb, crumb.serialize())
        
        XCTAssertEqual(serialaziedString, actual as NSString)
    }
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let crumb = fixture.breadcrumb
        let actual = crumb.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Breadcrumb?)
        
        // Assert
        XCTAssertEqual(crumb.level, decoded.level)
        XCTAssertEqual(crumb.category, decoded.category)
        XCTAssertEqual(crumb.timestamp, decoded.timestamp)
        XCTAssertEqual(crumb.type, decoded.type)
        XCTAssertEqual(crumb.message, decoded.message)
        
        let crumbData = try XCTUnwrap(crumb.data as? NSDictionary)
        XCTAssertTrue((crumbData.isEqual(to: decoded.data as NSDictionary?)))
        XCTAssertEqual(crumb.origin, decoded.origin)
        
        // We don't decode unknown on purpose, because it's complicated to decode with
        // Swift decodable. We might fix this in the future.
        XCTAssertNil(decoded.value(forKey: "unknown"))
    }

    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let crumb = Breadcrumb()
        crumb.timestamp = fixture.date
        let actual = crumb.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Breadcrumb?)
        
        // Assert
        XCTAssertEqual(crumb, decoded)
    }
}
