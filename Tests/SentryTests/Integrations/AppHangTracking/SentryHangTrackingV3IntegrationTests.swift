@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryHangTrackingV3IntegrationTests: XCTestCase {

    // MARK: - Test Helpers

    private var mockTracker: MockAppHangTracker!
    private var testClient: TestClient!

    override func setUp() {
        super.setUp()
        mockTracker = MockAppHangTracker()
        testClient = TestClient(options: Options())
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    private func makeSUT(
        enableV3: Bool = true,
        includeClient: Bool = true,
        extensionIdentifier: String? = nil
    ) -> SentryHangTrackingV3Integration<MockIntegrationDependencies>? {
        let options = Options()
        options.experimental.appHangs.enableV3 = enableV3
        options.experimental.appHangs.threshold = 2.0

        let infoPlistWrapper = TestInfoPlistWrapper()
        if let extensionIdentifier {
            infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
                forKey: "NSExtension",
                value: ["NSExtensionPointIdentifier": extensionIdentifier]
            )
        } else {
            infoPlistWrapper.mockGetAppValueDictionaryThrowError(
                forKey: "NSExtension",
                error: SentryInfoPlistError.keyNotFound(key: "NSExtension")
            )
        }

        let deps = MockIntegrationDependencies(
            appHangTracker: mockTracker,
            client: includeClient ? testClient : nil,
            hub: StubHub(),
            extensionDetector: SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)
        )
        return SentryHangTrackingV3Integration(with: options, dependencies: deps)
    }

    private func makeHang(state: SentryAppHang.State, duration: TimeInterval = 2.0) -> SentryAppHang {
        SentryAppHang(duration: duration, state: state)
    }

    // MARK: - Init Tests

    func testInit_whenEnableV3IsFalse_returnsNil() {
        let sut = makeSUT(enableV3: false)
        XCTAssertNil(sut)
    }

    func testInit_whenEnableV3IsTrue_succeeds() {
        let sut = makeSUT(enableV3: true)
        XCTAssertNotNil(sut)
    }

    func testInit_inDisabledExtension_returnsNil() {
        let sut = makeSUT(extensionIdentifier: "com.apple.widgetkit-extension")
        XCTAssertNil(sut)
    }

    func testInit_inNonDisabledExtension_succeeds() {
        let sut = makeSUT(extensionIdentifier: "com.apple.keyboard-service")
        XCTAssertNotNil(sut)
    }

    // MARK: - State Filter Tests

    func testHangStarted_doesNotCaptureEvent() {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .started))
        XCTAssertTrue(testClient.captureEventInvocations.isEmpty, "Expected no events on .started")
    }

    func testHangEnded_capturesEvent() {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        XCTAssertEqual(testClient.captureEventInvocations.count, 1)
    }

    // MARK: - Event Content Tests

    func testHangEnded_capturesEventWithWarningLevel() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        XCTAssertEqual(event.level, .warning)
    }

    func testHangEnded_capturesEventWithAppHangingExceptionType() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        XCTAssertEqual(event.exceptions?.first?.type, "App Hanging")
    }

    func testHangEnded_exceptionValueContainsDuration() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended, duration: 3.5))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let exceptionValue = try XCTUnwrap(event.exceptions?.first?.value)
        XCTAssertTrue(exceptionValue.contains("3.5"), "Exception value should include duration, got: \(exceptionValue)")
    }

    func testHangEnded_capturesEventWithAppHangMechanism() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let mechanism = try XCTUnwrap(event.exceptions?.first?.mechanism)
        XCTAssertEqual(mechanism.type, "AppHang")
        XCTAssertEqual(mechanism.handled, NSNumber(value: true))
        XCTAssertEqual(mechanism.synthetic, NSNumber(value: true))
    }

    func testHangEnded_capturesEventWithMainThread() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let thread = try XCTUnwrap(event.threads?.first)
        XCTAssertEqual(thread.threadId, NSNumber(value: 0))
        XCTAssertEqual(thread.name, "main")
        XCTAssertEqual(thread.crashed, NSNumber(value: false))
        XCTAssertEqual(thread.current, NSNumber(value: true))
        XCTAssertEqual(thread.isMain, NSNumber(value: true))
    }

    // MARK: - No Client Tests

    func testHangEnded_withNoClient_doesNotCaptureAndDoesNotCrash() {
        let sut = makeSUT(includeClient: false)
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        XCTAssertTrue(testClient.captureEventInvocations.isEmpty)
    }

    // MARK: - Name Tests

    func testName_shouldReturnCorrectName() {
        XCTAssertEqual(
            SentryHangTrackingV3Integration<MockIntegrationDependencies>.name,
            "SentryHangTrackingV3Integration"
        )
    }
}

// MARK: - Mock Infrastructure

private class MockAppHangTracker: SentryAppHangTracker {
    private var observers = [UUID: (SentryAppHang) -> Void]()

    func addObserver(threshold: TimeInterval, handler: @escaping (SentryAppHang) -> Void) -> UUID {
        let token = UUID()
        observers[token] = handler
        return token
    }

    func removeObserver(token: UUID) {
        observers.removeValue(forKey: token)
    }

    func simulateHang(_ hang: SentryAppHang) {
        for handler in observers.values {
            handler(hang)
        }
    }
}

private struct StubHub: Hub {
    func configureScope(_ callback: @escaping (Scope) -> Void) {}
    func storeEnvelope(_ envelope: SentryEnvelope) {}
    func captureEnvelope(_ envelope: SentryEnvelope) {}
    func setTrace(_ traceId: SentryId, spanId: SpanId) {}
    var options: Options { Options() }
}

private struct MockIntegrationDependencies: SentryHangTrackingV3IntegrationDependencies {
    let appHangTracker: SentryAppHangTracker
    let client: SentryClientInternal?
    let hub: Hub
    var extensionDetector: SentryExtensionDetector
    var threadInspector: SentryThreadInspector { SentryThreadInspector(options: nil) }
    var debugImageProvider: SentryDebugImageProvider { SentryDebugImageProvider() }
}
