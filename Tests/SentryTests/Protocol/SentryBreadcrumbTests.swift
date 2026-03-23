@_spi(Private) @testable import Sentry
import SentryTestUtils
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
            "data": ["foo": "bar"]
        ]
        let breadcrumb = PrivateSentrySDKOnly.breadcrumb(with: dict)
        
        XCTAssertEqual(breadcrumb.level, SentryLevel.info)
        XCTAssertEqual(breadcrumb.timestamp, fixture.date)
        XCTAssertEqual(breadcrumb.category, fixture.category)
        XCTAssertEqual(breadcrumb.type, fixture.type)
        XCTAssertEqual(breadcrumb.origin, fixture.origin)
        XCTAssertEqual(breadcrumb.message, fixture.message)
        XCTAssertEqual(breadcrumb.data as? [String: String], ["foo": "bar"])
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
        
        XCTAssertEqual("info", actual["level"] as? String)
        XCTAssertEqual(fixture.dateAs8601String, actual["timestamp"] as? String)
        XCTAssertEqual(fixture.category, actual["category"] as? String)
        XCTAssertEqual(fixture.type, actual["type"] as? String)
        XCTAssertEqual(fixture.origin, actual["origin"] as? String)
        XCTAssertEqual(fixture.message, actual["message"] as? String)
        XCTAssertEqual(["some": ["data": "data", "date": fixture.dateAs8601String]], actual["data"] as? Dictionary)
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
        let data = try XCTUnwrap(SentrySerializationSwift.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as BreadcrumbDecodable?)
        
        // Assert
        XCTAssertEqual(crumb.level, decoded.level)
        XCTAssertEqual(crumb.category, decoded.category)
        XCTAssertEqual(crumb.timestamp, decoded.timestamp)
        XCTAssertEqual(crumb.type, decoded.type)
        XCTAssertEqual(crumb.message, decoded.message)
        
        let crumbData = try XCTUnwrap(crumb.data as? NSDictionary)
        let decodedData = try XCTUnwrap(decoded.data as? NSDictionary)

        XCTAssertEqual(crumbData, decodedData)
        XCTAssertEqual(crumb.origin, decoded.origin)
    }

    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let crumb = Breadcrumb()
        crumb.timestamp = fixture.date
        let actual = crumb.serialize()
        let data = try XCTUnwrap(SentrySerializationSwift.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as BreadcrumbDecodable?)
        
        // Assert
        XCTAssertEqual(crumb, decoded)
    }

    // MARK: - Thread Safety

    func testSerialize_whenPropertiesMutatedConcurrently_shouldNotCrash() {
        let breadcrumb = Breadcrumb(level: .info, category: "test")
        breadcrumb.message = "initial"
        breadcrumb.data = ["key": "value"]

        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 1_000) { i in
            breadcrumb.message = "message \(i)"
            breadcrumb.data = ["key\(i % 10)": "value\(i)"]
            breadcrumb.category = "cat\(i % 10)"
            breadcrumb.type = "type\(i % 10)"
            _ = breadcrumb.serialize()
        }
    }

    func testDataProperty_whenAssignedMutableDictionary_shouldDeepCopy() {
        let innerMutable = NSMutableDictionary(dictionary: ["inner": "original"])
        let mutableData = NSMutableDictionary(dictionary: [
            "key": "value",
            "nested": innerMutable
        ])

        let breadcrumb = Breadcrumb(level: .info, category: "test")
        // Use KVC to bypass Swift bridging and exercise the ObjC setter directly.
        breadcrumb.setValue(mutableData, forKey: "data")

        mutableData["key"] = "modified"
        mutableData["newKey"] = "newValue"
        innerMutable["inner"] = "modified"

        XCTAssertEqual(breadcrumb.data?["key"] as? String, "value")
        XCTAssertNil(breadcrumb.data?["newKey"])
        let nested = breadcrumb.data?["nested"] as? NSDictionary
        XCTAssertEqual(nested?["inner"] as? String, "original")
    }

    func testSerialize_whenDataContainsConcurrentlyMutatedNestedDict_shouldNotCrash() {
        // nonisolated(unsafe) silences the Sendable warning — this test intentionally
        // mutates the dictionary from multiple threads to verify deep-copy safety.
        nonisolated(unsafe) let nestedMutable = NSMutableDictionary()
        for i in 0..<50 {
            nestedMutable["key\(i)"] = "value\(i)"
        }

        let breadcrumb = Breadcrumb(level: .info, category: "test")
        breadcrumb.data = ["nested": nestedMutable]

        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let expectation = expectation(description: "concurrent")
        expectation.expectedFulfillmentCount = 6

        // Multiple threads serialize concurrently — reads only the deep-copied data.
        for _ in 0..<5 {
            queue.async {
                for _ in 0..<1_000 { _ = breadcrumb.serialize() }
                expectation.fulfill()
            }
        }

        // One thread mutates the original dictionary.
        queue.async {
            for i in 0..<1_000 {
                nestedMutable["dynamic\(i % 50)"] = "value\(i)"
                if i % 2 == 0 {
                    nestedMutable.removeObject(forKey: "dynamic\(i % 50)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }

    func testSerialize_whenDataContainsConcurrentlyMutatedArray_shouldNotCrash() {
        // nonisolated(unsafe) silences the Sendable warning — this test intentionally
        // mutates the array from multiple threads to verify deep-copy safety.
        nonisolated(unsafe) let mutableArray = NSMutableArray()
        for i in 0..<50 {
            mutableArray.add("item\(i)")
        }

        let breadcrumb = Breadcrumb(level: .info, category: "test")
        breadcrumb.data = ["items": mutableArray]

        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let expectation = expectation(description: "concurrent")
        expectation.expectedFulfillmentCount = 6

        // Multiple threads serialize concurrently — reads only the deep-copied data.
        for _ in 0..<5 {
            queue.async {
                for _ in 0..<1_000 { _ = breadcrumb.serialize() }
                expectation.fulfill()
            }
        }

        // One thread mutates the original array.
        queue.async {
            for i in 0..<1_000 {
                mutableArray.add("new\(i)")
                if mutableArray.count > 100 {
                    mutableArray.removeObject(at: 0)
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }

    func testSerialize_whenDataReassignedConcurrently_shouldNotCrash() {
        let breadcrumb = Breadcrumb(level: .info, category: "test")
        breadcrumb.data = ["initial": "value"]

        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 1_000) { i in
            breadcrumb.data = ["key\(i % 20)": "value\(i)", "extra": ["nested": "dict\(i)"]]
            _ = breadcrumb.serialize()
        }
    }
}
