@testable import Sentry
import SentryTestUtils
import XCTest

class SentryInternalDebugApiIntegrationTests: XCTestCase {

    private var sut: SentryInternalDebugApi { SentrySDK.internal.debug }

    override func setUp() {
        super.setUp()
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: SentryInternalDebugApiIntegrationTests.self)
            $0.removeAllIntegrations()
        }
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    func testImages_shouldReturnArray() {
        // -- Act --
        let images = sut.images

        // -- Assert --
        XCTAssertNotNil(images)
    }

    func testImagesForAddresses_whenEmptyAddresses_shouldReturnEmpty() {
        // -- Act --
        let result = sut.images(forAddresses: [])

        // -- Assert --
        XCTAssertTrue(result.isEmpty)
    }
}
