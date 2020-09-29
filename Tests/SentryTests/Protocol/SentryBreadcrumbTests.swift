import XCTest

class SentryBreadcrumbTests: XCTestCase {

    private class Fixture {
        let breadcrumb: Breadcrumb
        let date: Date
        
        init() {
            date = Date(timeIntervalSince1970: 10)
            
            breadcrumb = Breadcrumb()
            breadcrumb.level = SentryLevel.info
            breadcrumb.timestamp = date
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
}
