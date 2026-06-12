@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class SentryInternalScreenApiTests: XCTestCase {

    private var sut: SentryInternalScreenApi { SentrySDK.internal.screen }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - setCurrent

    func testSetCurrent_whenScreenName_shouldUpdateScope() {
        // -- Arrange --
        let scope = Scope()
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)

        // -- Act --
        sut.setCurrent("HomeScreen")

        // -- Assert --
        XCTAssertEqual(scope.currentScreen, "HomeScreen")
    }

    func testSetCurrent_whenNil_shouldClearScope() {
        // -- Arrange --
        let scope = Scope()
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)
        sut.setCurrent("HomeScreen")

        // -- Act --
        sut.setCurrent(nil)

        // -- Assert --
        XCTAssertNil(scope.currentScreen)
    }

    func testSetCurrent_whenCalledMultipleTimes_shouldReflectLatest() {
        // -- Arrange --
        let scope = Scope()
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)

        // -- Act --
        sut.setCurrent("ScreenA")
        sut.setCurrent("ScreenB")

        // -- Assert --
        XCTAssertEqual(scope.currentScreen, "ScreenB")
    }
}

#endif
