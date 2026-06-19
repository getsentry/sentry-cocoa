@testable import Sentry
import SentryTestUtils
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalViewHierarchyApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalViewHierarchyApiIntegrationTests.self)

    override func setUp() {
        super.setUp()
        SentrySDK.start { options in
            options.dsn = SentryInternalViewHierarchyApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    // MARK: - accessor

    func testViewHierarchy_shouldBeAccessible() {
        // -- Act --
        let viewHierarchy = SentrySDK.internal.viewHierarchy

        // -- Assert --
        XCTAssertNotNil(viewHierarchy)
    }

    // MARK: - capture

    func testCapture_whenNoWindows_shouldReturnValidJSON() throws {
        // -- Act --
        let result = try XCTUnwrap(SentrySDK.internal.viewHierarchy.capture())

        // -- Assert --
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result) as? [String: Any])
        XCTAssertEqual(json["rendering_system"] as? String, "UIKIT")
        let windows = try XCTUnwrap(json["windows"] as? [Any])
        XCTAssertEqual(windows.count, 0)
    }
}

#endif
