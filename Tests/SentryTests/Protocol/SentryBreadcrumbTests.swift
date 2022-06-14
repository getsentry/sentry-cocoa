import XCTest

class SentryBreadcrumbTests: XCTestCase {

    private class Fixture {
        let breadcrumb: Breadcrumb
        let date: Date
        
        let category = "category"
        let type = "user"
        let message = "Click something"
        
        init() {
            date = Date(timeIntervalSince1970: 10)
            
            breadcrumb = Breadcrumb()
            breadcrumb.level = SentryLevel.info
            breadcrumb.timestamp = date
            breadcrumb.category = category
            breadcrumb.type = "user"
            breadcrumb.message = "Click something"
            breadcrumb.data = ["some": ["data": "data", "date": date]]
        }
        
        var dateAs8601String: String {
            get {
                return (date as NSDate).sentry_toIso8601String()
            }
        }
    }
    
    private let fixture = Fixture()

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

    func testIsEqualToOtherInstanceWithSameValues() {
        let fixture2 = Fixture()
        XCTAssertEqual(fixture.breadcrumb, fixture2.breadcrumb)
    }
    
    func testNotIsEqual() {
        testIsNotEqual { breadcrumb in breadcrumb.level = SentryLevel.error }
        testIsNotEqual { breadcrumb in breadcrumb.category = "" }
        testIsNotEqual { breadcrumb in breadcrumb.timestamp = Date() }
        testIsNotEqual { breadcrumb in breadcrumb.type = "" }
        testIsNotEqual { breadcrumb in breadcrumb.message = "" }
        testIsNotEqual { breadcrumb in breadcrumb.data?.removeAll() }
    }
    
    func testIsNotEqual(block: (Breadcrumb) -> Void ) {
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
        crumb.message = ""
        crumb.data = nil
        
        XCTAssertEqual("info", actual["level"] as? String)
        XCTAssertEqual(fixture.dateAs8601String, actual["timestamp"] as? String)
        XCTAssertEqual(fixture.category, actual["category"] as? String)
        XCTAssertEqual(fixture.type, actual["type"] as? String)
        XCTAssertEqual(fixture.message, actual["message"] as? String)
        XCTAssertEqual(["some": ["data": "data", "date": fixture.dateAs8601String]], actual["data"] as? Dictionary)
    }
    
    func testDescription() {
        let crumb = fixture.breadcrumb
        let actual = crumb.description
        
        let serialaziedString = NSString(format: "<SentryBreadcrumb: %p, %@>", crumb, crumb.serialize())
        
        XCTAssertEqual(serialaziedString, actual as NSString)
    }
}
