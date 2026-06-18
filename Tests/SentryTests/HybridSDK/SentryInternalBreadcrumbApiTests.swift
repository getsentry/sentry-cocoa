@testable import Sentry
import SentryTestUtils
import XCTest

class SentryInternalBreadcrumbApiTests: XCTestCase {

    private var sut: SentryInternalBreadcrumbApi { SentrySDK.internal.breadcrumbs }

    override func setUp() {
        super.setUp()
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: SentryInternalBreadcrumbApiTests.self)
            $0.removeAllIntegrations()
        }
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testFromDictionary_whenPopulated_shouldMapFields() {
        // -- Arrange --
        let dict: [String: Any] = [
            "message": "test breadcrumb",
            "category": "navigation",
            "level": "info",
            "type": "default"
        ]

        // -- Act --
        let breadcrumb = sut.fromDictionary(dict)

        // -- Assert --
        XCTAssertEqual(breadcrumb.message, "test breadcrumb")
        XCTAssertEqual(breadcrumb.category, "navigation")
        XCTAssertEqual(breadcrumb.type, "default")
    }

    func testFromDictionary_whenEmpty_shouldReturnBreadcrumb() {
        // -- Arrange --
        let dict: [String: Any] = [:]

        // -- Act --
        let breadcrumb = sut.fromDictionary(dict)

        // -- Assert --
        XCTAssertNotNil(breadcrumb)
    }

    func testFromDictionary_whenDataPresent_shouldIncludeData() {
        // -- Arrange --
        let dict: [String: Any] = [
            "message": "click",
            "data": ["url": "https://example.com"]
        ]

        // -- Act --
        let breadcrumb = sut.fromDictionary(dict)

        // -- Assert --
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://example.com")
    }
}
