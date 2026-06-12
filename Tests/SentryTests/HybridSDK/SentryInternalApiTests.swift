@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryInternalApiTests: XCTestCase {

    private var sut: SentryInternalApi { SentrySDK.internal }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - setTrace

    func testSetTrace_shouldUpdatePropagationContext() {
        // -- Arrange --
        let traceId = SentryId()
        let spanId = SpanId()
        let scope = Scope()
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)

        // -- Act --
        sut.setTrace(traceId, spanId: spanId)

        // -- Assert --
        XCTAssertEqual(scope.propagationContext.traceId, traceId)
        XCTAssertEqual(scope.propagationContext.spanId, spanId)
    }

    // MARK: - options

    func testOptions_whenClientConfigured_shouldReturnClientOptions() {
        // -- Arrange --
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryInternalApiTests")
        let client = TestClient(options: options)
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))

        // -- Act --
        let result = sut.options

        // -- Assert --
        XCTAssertEqual(result, options)
    }

    func testOptions_whenNoClient_shouldReturnDefaults() {
        // -- Act --
        let result = sut.options

        // -- Assert --
        XCTAssertNotNil(result)
        XCTAssertNil(result.dsn)
        XCTAssertTrue(result.enabled)
    }

    // MARK: - options(fromDictionary:)

    func testOptionsFromDictionary_whenValidDsn_shouldParseOptions() throws {
        // -- Arrange --
        let dict: [String: Any] = [
            "dsn": TestConstants.dsnAsString(username: "SentryInternalApiTests")
        ]

        // -- Act --
        let options = try sut.options(fromDictionary: dict)

        // -- Assert --
        XCTAssertNotNil(options.dsn)
    }

    func testOptionsFromDictionary_whenEmpty_shouldReturnDefaults() throws {
        // -- Act --
        let options = try sut.options(fromDictionary: [:])

        // -- Assert --
        XCTAssertNotNil(options)
        XCTAssertNil(options.dsn)
    }

    // MARK: - Sub-object accessors

    func testSubObjects_shouldAllBeAccessible() {
        // -- Assert --
        XCTAssertNotNil(sut.sdk)
        XCTAssertNotNil(sut.debug)
        XCTAssertNotNil(sut.envelope)
        XCTAssertNotNil(sut.breadcrumbs)
        XCTAssertNotNil(sut.user)
        XCTAssertNotNil(sut.appStart)
        XCTAssertNotNil(sut.swizzle)
        #if os(iOS) || os(tvOS)
        XCTAssertNotNil(sut.replay)
        XCTAssertNotNil(sut.performance)
        XCTAssertNotNil(sut.screenshot)
        XCTAssertNotNil(sut.viewHierarchy)
        XCTAssertNotNil(sut.screen)
        #endif
    }
}
